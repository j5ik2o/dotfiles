#!/usr/bin/env python3
"""ボットとワーカーの環境で、禁止の宛先へのマージと push を実行前に止める。

decide() がネットワークも git も使わない判定の本体。作業ディレクトリの remote は
呼び出し側が読み、RepoInfo の値として渡す。hook_main() は Claude Code と Codex の
PreToolUse から呼ばれる入口で、Orca が起動したセッション（ORCA_AGENT_SESSION_ID）の
ときだけ判定する。
"""

from __future__ import annotations

import json
import os
import posixpath
import re
import shlex
import subprocess
import sys
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field, replace
from urllib.parse import unquote

DEFAULT_BLOCKED = ("nrslib",)
EXTRA_BLOCKED_ENV = "UPSTREAM_GUARD_EXTRA_BLOCKED"
EXTRA_BLOCKED_FILE = "~/.config/upstream-guard/extra-blocked"
ADVICE = "上流の PR のマージと push は、上流のメンテナが行います。必要なら副元帥へ。"


# ---------------------------------------------------------------------------
# 値の型
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Remote:
    fetch_urls: tuple[str, ...] = ()
    push_urls: tuple[str, ...] = ()
    gh_resolved: str | None = None  # remote.<name>.gh-resolved（gh repo set-default）


@dataclass(frozen=True)
class RepoInfo:
    remotes: Mapping[str, Remote] = field(default_factory=dict)
    # git push を引数なしで打ったときの宛先（remote 名か URL）。決まらなければ None
    default_push_remote: str | None = None
    git_aliases: Mapping[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class Verdict:
    allowed: bool
    reason: str = ""


ALLOW = Verdict(True)

# 場所の鍵。作業ディレクトリはそのままの絶対パス、--git-dir は接頭辞つき
GIT_DIR_PREFIX = "--git-dir="


class ParseError(Exception):
    """コマンドの文字列を解析できない。"""


# ---------------------------------------------------------------------------
# 宛先
# ---------------------------------------------------------------------------

_SCP_LIKE = re.compile(r"^(?:[^@/\s]+@)?[^/:\s]+:(?!//)(.+)$")
_URL = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*://(?:[^@/]*@)?[^/]+/(.+)$")


def repo_from_url(url: str) -> str | None:
    """URL・ssh の形・owner/repo から "owner/repo"（小文字）を取り出す。"""
    url = unquote(url.strip())
    m = _URL.match(url)
    path = m.group(1) if m else None
    if path is None:
        m = _SCP_LIKE.match(url)
        path = m.group(1) if m else None
    if path is None:
        return None
    parts = [p for p in posixpath.normpath("/" + path).split("/") if p]
    if len(parts) < 2:
        return None
    owner, repo = parts[0], parts[1]
    repo = repo.removesuffix(".git")
    if not owner or not repo:
        return None
    return f"{owner}/{repo}".lower()


def repo_from_gh_arg(value: str) -> str | None:
    """gh の -R / GH_REPO の値（[HOST/]OWNER/REPO か URL）。"""
    if "://" in value or "@" in value:
        return repo_from_url(value)
    parts = [p for p in value.strip().split("/") if p]
    if len(parts) == 2:
        return f"{parts[0]}/{parts[1].removesuffix('.git')}".lower()
    if len(parts) == 3:
        return f"{parts[1]}/{parts[2].removesuffix('.git')}".lower()
    return None


def blocked_entry(repo: str, blocked: tuple[str, ...]) -> str | None:
    owner = repo.split("/")[0]
    for entry in blocked:
        e = entry.lower()
        if e == repo or e == owner:
            return entry
    return None


def normalize_blocked(entries) -> tuple[str, ...]:
    out: list[str] = []
    for raw in entries:
        e = raw.strip().strip("/").lower()
        if e and e not in out:
            out.append(e)
    return tuple(out)


def looks_like_url(value: str) -> bool:
    return (
        "://" in value
        or bool(_SCP_LIKE.match(value))
        and not value.startswith(("/", "."))
    )


def looks_like_path(value: str) -> bool:
    return value.startswith(("/", "./", "../", "~")) or value in (".", "..")


# ---------------------------------------------------------------------------
# シェルの字句解析
# ---------------------------------------------------------------------------


@dataclass
class Word:
    # 部品: ("lit", 文字列) / ("var", 名前) / ("sub", コマンド置換の中身)
    parts: list[tuple[str, str]]
    raw: str = ""


@dataclass
class Op:
    value: str


@dataclass
class Redirect:
    op: str
    target: Word | None
    heredoc: str | None = None
    expands: bool = (
        False  # 区切りに引用符がないヒアドキュメントは、本文の $(...) を実行する
    )


_OPERATORS = ("&&", "||", ";;", "|&", ";", "&", "|", "(", ")", "\n")
_ANSI_ESCAPES = {
    "n": "\n",
    "t": "\t",
    "r": "\r",
    "a": "\a",
    "b": "\b",
    "e": "\x1b",
    "E": "\x1b",
    "f": "\f",
    "v": "\v",
    "\\": "\\",
    "'": "'",
    '"': '"',
    "?": "?",
}


def _read_balanced(s: str, i: int, open_ch: str, close_ch: str) -> int:
    """s[i] は open_ch の次。対応する close_ch の位置を返す（引用符を考慮）。"""
    depth = 1
    pending: list[tuple[str, bool]] = []
    while i < len(s):
        c = s[i]
        if c == "\\":
            i += 2
            continue
        if c == "\n" and pending:
            i = _skip_heredoc_bodies(s, i + 1, pending)
            continue
        m = (
            re.match(r"<<(-?)[ \t]*(['\"]?)([A-Za-z0-9_.-]+)\2", s[i:])
            if c == "<"
            else None
        )
        if m and not s.startswith("<<<", i):
            pending.append((m.group(3), m.group(1) == "-"))
            i += len(m.group(0))
            continue
        if c == "'":
            j = s.find("'", i + 1)
            if j < 0:
                raise ParseError("閉じていない引用符")
            i = j + 1
            continue
        if c == '"':
            i = _skip_double(s, i + 1)
            continue
        if c == "`":
            j = s.find("`", i + 1)
            if j < 0:
                raise ParseError("閉じていないバッククォート")
            i = j + 1
            continue
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ParseError(f"閉じていない {open_ch}")


def _skip_heredoc_bodies(s: str, i: int, pending: list[tuple[str, bool]]) -> int:
    for delim, strip_tabs in pending:
        while i < len(s):
            j = s.find("\n", i)
            line = s[i:] if j < 0 else s[i:j]
            i = len(s) if j < 0 else j + 1
            if (line.lstrip("\t") if strip_tabs else line) == delim:
                break
    pending.clear()
    return i


def _skip_double(s: str, i: int) -> int:
    while i < len(s):
        c = s[i]
        if c == "\\":
            i += 2
            continue
        if c == '"':
            return i + 1
        if c == "$" and s.startswith("$(", i):
            i = _read_balanced(s, i + 2, "(", ")") + 1
            continue
        if c == "`":
            j = s.find("`", i + 1)
            if j < 0:
                raise ParseError("閉じていないバッククォート")
            i = j + 1
            continue
        i += 1
    raise ParseError("閉じていない引用符")


def _read_dollar(s: str, i: int, parts: list[tuple[str, str]]) -> int:
    """s[i] は "$"。部品を足して、次の位置を返す。"""
    nxt = s[i + 1] if i + 1 < len(s) else ""
    if s.startswith("$((", i):
        end = _read_balanced(s, i + 3, "(", ")")
        parts.append(("var", "$((…))"))
        if "$(" in s[i + 3 : end] or "`" in s[i + 3 : end]:
            parts.append(("sub", s[i + 3 : end]))
        return end + 2 if s[end + 1 : end + 2] == ")" else end + 1
    if nxt == "(":
        end = _read_balanced(s, i + 2, "(", ")")
        parts.append(("sub", s[i + 2 : end]))
        return end + 1
    if nxt == "{":
        end = _read_balanced(s, i + 2, "{", "}")
        inner = s[i + 2 : end]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", inner):
            parts.append(("var", inner))
        else:
            parts.append(("var", "${" + inner + "}"))
            if "$(" in inner or "`" in inner:
                parts.append(("sub", inner))
        return end + 1
    if nxt == "'":
        return _read_ansi_c(s, i + 2, parts)
    if nxt == '"':
        return i + 1  # $"..." は "..." と同じに扱う
    m = re.match(r"[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-]", s[i + 1 :])
    if m:
        parts.append(("var", m.group(0)))
        return i + 1 + len(m.group(0))
    parts.append(("lit", "$"))
    return i + 1


def _read_ansi_c(s: str, i: int, parts: list[tuple[str, str]]) -> int:
    out = []
    while i < len(s):
        c = s[i]
        if c == "'":
            parts.append(("lit", "".join(out)))
            return i + 1
        if c == "\\" and i + 1 < len(s):
            e = s[i + 1]
            if e in _ANSI_ESCAPES:
                out.append(_ANSI_ESCAPES[e])
                i += 2
                continue
            m = re.match(
                r"x([0-9a-fA-F]{1,2})|u([0-9a-fA-F]{1,4})|U([0-9a-fA-F]{1,8})|([0-7]{1,3})",
                s[i + 1 :],
            )
            if m:
                h = next(g for g in m.groups() if g is not None)
                out.append(chr(int(h, 8 if m.group(4) else 16)))
                i += 1 + len(m.group(0))
                continue
            out.append(e)
            i += 2
            continue
        out.append(c)
        i += 1
    raise ParseError("閉じていない $'")


def tokenize(s: str) -> list:
    tokens: list = []
    pending_heredocs: list[tuple[Redirect, str, bool]] = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c in " \t":
            i += 1
            continue
        if c == "\\" and s.startswith("\\\n", i):
            i += 2
            continue
        if c == "#":
            j = s.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == "\n":
            tokens.append(Op("\n"))
            i += 1
            if pending_heredocs:
                i = _read_heredocs(s, i, pending_heredocs)
            continue
        if s.startswith(("<(", ">("), i):  # プロセス置換も中身を実行する
            end = _read_balanced(s, i + 2, "(", ")")
            tokens.append(Word([("sub", s[i + 2 : end])], s[i : end + 1]))
            i = end + 1
            continue
        m = re.match(r"(\d*)(<<<|<<-|<<|>>|>&|<&|&>>|&>|>\||<>|>|<)", s[i:])
        if m:
            op = m.group(2)
            i += len(m.group(0))
            while i < n and s[i] in " \t":
                i += 1
            if op in ("<<", "<<-"):
                word, i = _read_word(s, i)
                delim = "".join(t for _, t in word.parts)
                red = Redirect(op, None)
                red.expands = not any(q in word.raw for q in "'\"\\")
                pending_heredocs.append((red, delim, op == "<<-"))
                tokens.append(red)
                continue
            if op in (">&", "<&") and re.match(r"\d|-", s[i : i + 1]):
                i += 1
                tokens.append(Redirect(op, None))
                continue
            word, i = _read_word(s, i)
            tokens.append(Redirect(op, word))
            continue
        op = next((o for o in _OPERATORS if s.startswith(o, i)), None)
        if op:
            tokens.append(Op(op))
            i += len(op)
            continue
        word, i = _read_word(s, i)
        tokens.append(word)
    if pending_heredocs:
        _read_heredocs(s, n, pending_heredocs)
    return tokens


def _read_heredocs(s: str, i: int, pending: list[tuple[Redirect, str, bool]]) -> int:
    for red, delim, strip_tabs in pending:
        body = []
        while i <= len(s):
            j = s.find("\n", i)
            line = s[i:] if j < 0 else s[i:j]
            i = len(s) + 1 if j < 0 else j + 1
            check = line.lstrip("\t") if strip_tabs else line
            if check == delim:
                break
            body.append(line)
        red.heredoc = "\n".join(body)
    pending.clear()
    return min(i, len(s))


_BRACE = re.compile(r"\{[^{}\s]*(?:,|\.\.)[^{}\s]*\}")


def _read_word(s: str, i: int) -> tuple[Word, int]:
    parts: list[tuple[str, str]] = []
    unquoted: list[str] = []
    start = i
    n = len(s)
    while i < n:
        c = s[i]
        if c in " \t\n;&|()<>":
            break
        if c == "\\":
            if i + 1 < n:
                if s[i + 1] != "\n":
                    parts.append(("lit", s[i + 1]))
                i += 2
            else:
                i += 1
            continue
        if c == "'":
            j = s.find("'", i + 1)
            if j < 0:
                raise ParseError("閉じていない引用符")
            parts.append(("lit", s[i + 1 : j]))
            i = j + 1
            continue
        if c == '"':
            i = _read_double(s, i + 1, parts)
            continue
        if c == "$":
            i = _read_dollar(s, i, parts)
            continue
        if c == "`":
            j = s.find("`", i + 1)
            if j < 0:
                raise ParseError("閉じていないバッククォート")
            parts.append(("sub", s[i + 1 : j]))
            i = j + 1
            continue
        parts.append(("lit", c))
        unquoted.append(c)
        i += 1
    if not parts and i == start:
        raise ParseError(f"解析できない文字: {s[i : i + 1]!r}")
    if _BRACE.search("".join(unquoted)):
        parts.append(("var", "{ブレース展開}"))  # 展開した結果は読まない
    return Word(parts, s[start:i]), i


def _read_double(s: str, i: int, parts: list[tuple[str, str]]) -> int:
    n = len(s)
    while i < n:
        c = s[i]
        if c == '"':
            return i + 1
        if c == "\\" and i + 1 < n:
            e = s[i + 1]
            if e in '$`"\\':
                parts.append(("lit", e))
            elif e != "\n":
                parts.append(("lit", "\\" + e))
            i += 2
            continue
        if c == "$":
            i = _read_dollar(s, i, parts)
            continue
        if c == "`":
            j = s.find("`", i + 1)
            if j < 0:
                raise ParseError("閉じていないバッククォート")
            parts.append(("sub", s[i + 1 : j]))
            i = j + 1
            continue
        parts.append(("lit", c))
        i += 1
    raise ParseError("閉じていない引用符")


# ---------------------------------------------------------------------------
# 判定
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Arg:
    value: str
    resolved: bool


_OPAQUE_STRONG = re.compile(
    r"git\b[^\n]*\bpush\b|\bpush\b[^\n]*(?:github\.com|origin|upstream)|gh\b[^\n]*\bpr\b[^\n]*\bmerge\b"
    r"|pulls/[^/\s]+/(?:merge|update-branch)|/merges\b|/merge-upstream\b|git/refs|/contents/"
    r"|enablePullRequestAutoMerge|mergePullRequest|enqueuePullRequest|git-receive-pack",
    re.IGNORECASE,
)
_WRITE_HINT = re.compile(r"push|merge|refs|contents/|enqueue", re.IGNORECASE)
_GRAPHQL_WRITES = re.compile(
    r"\b(enablePullRequestAutoMerge|mergePullRequest|enqueuePullRequest|mergeBranch|createRef|updateRefs?"
    r"|deleteRef|createCommitOnBranch|updatePullRequestBranch|revertPullRequest|createRelease|updateRelease"
    r"|deleteRelease)\b",
    re.IGNORECASE,
)
_REST_WRITE_PATH = re.compile(
    r"^(?:pulls/[^/]+/(?:merge|update-branch)|merges|merge-upstream|git/(?:refs|tags|commits|trees|blobs)(?:/.*)?"
    r"|contents(?:/.*)?|releases(?:/.*)?|branches/[^/]+/rename|transfer|tags(?:/.*)?|)$"
)
_SHELLS = {"bash", "sh", "zsh", "dash", "ksh", "fish", "mksh", "busybox"}
_INTERPRETERS = {
    "python",
    "python3",
    "node",
    "nodejs",
    "deno",
    "bun",
    "ruby",
    "perl",
    "php",
    "osascript",
    "lua",
    "tclsh",
    "pwsh",
}
_RESERVED = {
    "!",
    "{",
    "}",
    "then",
    "do",
    "else",
    "elif",
    "if",
    "while",
    "until",
    "fi",
    "done",
    "time",
    "esac",
}
_UV_RUN_WITH_VALUE = {
    "--with",
    "--python",
    "-p",
    "--project",
    "--directory",
    "--package",
    "--extra",
    "--group",
    "--env-file",
    "--with-requirements",
}
_ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\+?=(.*)$", re.DOTALL)


@dataclass
class Ctx:
    cwd: str | None
    env: dict[str, str]
    vars: dict[str, str]
    blocked: tuple[str, ...]
    repos: Mapping[str, RepoInfo | None]
    depth: int = 0
    # 値が決まらない変数の、代入の元の文字列（コマンド置換の出力がコマンドになる形を見るため）
    opaque: dict[str, str] = field(default_factory=dict)
    # 同じコマンドの中で git や gh の設定を書き換えた印。書き換え後の宛先は読めない
    dirty: set[str] = field(default_factory=set)
    git_aliases: dict[str, str] = field(
        default_factory=dict
    )  # 同じコマンドの中で定義したもの


def _child(ctx: Ctx, **changes) -> Ctx:
    changes.setdefault("vars", dict(ctx.vars))
    changes.setdefault("depth", ctx.depth + 1)
    return replace(ctx, **changes)


UNKNOWN = "\0"  # 値が決まらないことを表す印


@dataclass
class Cmd:
    words: list[Word]
    redirects: list[Redirect]
    stdin_piped: bool
    pipeline_text: str
    in_pipeline: bool = False
    background: bool = False


@dataclass(frozen=True)
class Stdin:
    """コマンドの標準入力。ヒアドキュメントの本文、パイプなどで中身が分からないか、元のコマンド。"""

    text: str | None = None
    unknown: bool = False
    cmd: Cmd | None = None


def decide(
    command: str,
    cwd: str | None,
    env: Mapping[str, str],
    blocked: tuple[str, ...],
    repos: Mapping[str, RepoInfo | None],
) -> Verdict:
    """コマンドの文字列を見て、禁止の宛先へのマージと push なら拒否する。"""
    blocked = normalize_blocked(blocked)
    ctx = Ctx(cwd=cwd, env=dict(env), vars={}, blocked=blocked, repos=repos)
    try:
        return _decide_script(command, ctx)
    except ParseError as e:
        return _unparsed(command, ctx, f"コマンドを解析できない（{e}）")
    except RecursionError:
        return _unparsed(command, ctx, "入れ子が深すぎる")


def _deny(op: str, repo: str, entry: str) -> Verdict:
    return Verdict(
        False,
        f"upstream-guard: {op}を実行前に止めました。宛先 {repo} は禁止の宛先（{entry}）です。\n{ADVICE}",
    )


def _deny_unresolved(op: str, why: str) -> Verdict:
    return Verdict(
        False,
        f"upstream-guard: {op}を実行前に止めました。{why}ため、宛先が禁止の宛先でないと確かめられません。\n"
        f"宛先を明示して（-R owner/repo や remote 名など）実行し直してください。{ADVICE}",
    )


def _opaque(text: str, ctx: Ctx, why: str) -> Verdict:
    """中身を解析できない部分。マージや push の気配があるときだけ止める。"""
    lowered = text.lower()
    # owner/repo の項目は、owner だけの一致では当てない
    names = any(b in lowered for b in ctx.blocked)
    if (names and _WRITE_HINT.search(text)) or _OPAQUE_STRONG.search(text):
        return _deny_unresolved("マージか push に見えるコマンド", why)
    return ALLOW


# コードの中で、子プロセスを起動するか HTTP で外へ出る形
_LAUNCH = re.compile(
    r"subprocess|os\.(?:system|popen|exec|spawn)|pty\.spawn|commands\.getoutput|child_process|execSync"
    r"|execFileSync|spawnSync|\bspawn\(|\bexec(?:File)?\(|\bsystem\s*\(|\bpopen|Open3|IO\.popen|%x[({\[]"
    r"|\bqx[({\[/]|Deno\.Command|Bun\.spawn|\$\.run|\bsh\(|\bzx\b|\$`"
    r"|\bfetch\(|requests\.|urllib|http\.client|httpx|aiohttp|octokit|axios|got\(|Net::HTTP|LWP|HTTP::Tiny",
    re.IGNORECASE,
)


# Ruby と Perl だけは、バッククォートで子プロセスを起動する
_BACKTICK_LAUNCH = re.compile(r"`[^`\n]*\b(?:git|gh|hub|curl)\b[^`\n]*`")


def _opaque_code(code: str, ctx: Ctx, why: str, name: str = "") -> Verdict:
    """インタープリタのコード。文やデータに語句があるだけなら通す。

    止めるのは、子プロセスの起動か HTTP の形があり、かつ禁止の宛先の文字列か、
    push・マージのはっきりした形があるときだけ。
    """
    backtick = name.startswith(("ruby", "perl")) and _BACKTICK_LAUNCH.search(code)
    if not (_LAUNCH.search(code) or backtick):
        return ALLOW
    lowered = code.lower()
    if any(b in lowered for b in ctx.blocked) or _OPAQUE_STRONG.search(code):
        return _deny_unresolved("マージか push に見えるコマンド", why)
    return ALLOW


def _decide_script(script: str, ctx: Ctx) -> Verdict:
    if ctx.depth > 8:
        raise ParseError("入れ子が深すぎる")
    tokens = tokenize(script)
    cwd_stack: list[str | None] = []
    vars_stack: list[dict[str, str]] = []
    pipeline: list[Cmd] = []
    cur_words: list[Word] = []
    cur_redirects: list[Redirect] = []
    piped = False
    for tok in tokens + [Op("\n")]:
        if isinstance(tok, Word):
            cur_words.append(tok)
            continue
        if isinstance(tok, Redirect):
            cur_redirects.append(tok)
            continue
        # 演算子で、ここまでの単純コマンドを閉じる
        if cur_words or cur_redirects:
            pipeline.append(Cmd(cur_words, cur_redirects, piped, script))
        cur_words, cur_redirects = [], []
        if tok.value in ("|", "|&"):
            piped = True
            continue
        for cmd in pipeline:
            cmd.in_pipeline = len(pipeline) > 1
            cmd.background = tok.value == "&"
            v = _decide_cmd(cmd, ctx)
            if not v.allowed:
                return v
        pipeline, piped = [], False
        if tok.value == "(":
            cwd_stack.append(ctx.cwd)
            vars_stack.append(dict(ctx.vars))
        elif tok.value == ")" and cwd_stack:
            ctx.cwd = cwd_stack.pop()
            ctx.vars = vars_stack.pop()
    return ALLOW


def _expand(
    word: Word, ctx: Ctx, cmd_env: Mapping[str, str] | None = None
) -> tuple[Arg, Verdict]:
    out = []
    resolved = True
    verdict = ALLOW
    for i, (kind, text) in enumerate(word.parts):
        if kind == "lit":
            if (
                i == 0
                and text == "~"
                and (len(word.parts) == 1 or word.parts[1][1].startswith("/"))
            ):
                home = ctx.env.get("HOME")
                if home:
                    out.append(home)
                    continue
            out.append(text)
        elif kind == "var":
            value = None
            if cmd_env and text in cmd_env:
                value = cmd_env[text]
            elif text in ctx.vars:
                value = ctx.vars[text]
            elif text in ctx.env:
                value = ctx.env[text]
            if value is None or UNKNOWN in value:
                resolved = False
                out.append(UNKNOWN)
            else:
                out.append(value)
        else:  # コマンド置換の中も実行されるので判定する
            v = _decide_script(text, _child(ctx))
            if not v.allowed and verdict.allowed:
                verdict = v
            resolved = False
            out.append("\0")
    return Arg("".join(out), resolved), verdict


def _decide_cmd(cmd: Cmd, ctx: Ctx) -> Verdict:
    args: list[Arg] = []
    for w in cmd.words:
        a, v = _expand(w, ctx)
        if not v.allowed:
            return v
        args.append(a)
    for r in cmd.redirects:
        if r.target is not None:
            _, v = _expand(r.target, ctx)
            if not v.allowed:
                return v
        if r.heredoc is not None and r.expands:
            parts: list[tuple[str, str]] = []
            _read_double(r.heredoc.replace('"', "'") + '"', 0, parts)
            _, v = _expand(Word(parts), ctx)
            if not v.allowed:
                return v
    stdin_text = next((r.heredoc for r in cmd.redirects if r.heredoc is not None), None)
    if stdin_text is None:
        here = next((r for r in cmd.redirects if r.op == "<<<" and r.target), None)
        if here is not None:
            stdin_text = _expand(here.target, ctx)[0].value
    stdin_redirected = any(r.op in ("<", "<>") for r in cmd.redirects)

    # 先頭の代入。コマンドが続かなければシェルの変数になる
    cmd_env: dict[str, str] = {}
    words = list(cmd.words)
    while args and _ASSIGN.match(words[0].raw):
        name = _ASSIGN.match(words[0].raw).group(1)
        value = args[0].value.split("=", 1)[1] if args[0].resolved else UNKNOWN
        if not args[0].resolved:
            ctx.opaque[name] = words[0].raw
        if "+=" in words[0].raw.split("=", 1)[0] + "=":
            value = _lookup(name, ctx, cmd_env) + value
        cmd_env[name] = value
        args, words = args[1:], words[1:]
    if not args:
        ctx.vars.update(cmd_env)
        return ALLOW
    stdin = Stdin(stdin_text, cmd.stdin_piped or stdin_redirected, cmd)
    return _decide_argv(args, ctx, cmd_env, stdin=stdin)


def _lookup(name: str, ctx: Ctx, cmd_env: Mapping[str, str]) -> str:
    for scope in (cmd_env, ctx.vars, ctx.env):
        if name in scope:
            return scope[name]
    return ""


def _base(value: str) -> str:
    return value.rsplit("/", 1)[-1]


# 引数を読み飛ばして、後ろのコマンドをそのまま実行するもの（名前 → 値を取るオプション）
_PREFIX_WRAPPERS: dict[str, set[str]] = {
    "command": {"-a", "-n", "-w"},
    "builtin": set(),
    "nohup": set(),
    "exec": {"-a"},
    "time": set(),
    "nice": {"-n"},
    "chronic": set(),
    "unbuffer": set(),
    "caffeinate": {"-w"},
    "sudo": {"-u", "-g", "-C", "-D", "-h", "-p", "-U", "-r", "-t", "-T"},
    "doas": {"-u", "-C"},
    "stdbuf": {"-i", "-o", "-e"},
    "watch": {"-n", "-d", "--interval"},
    "xargs": {"-I", "-L", "-n", "-P", "-s", "-d", "-E", "-a", "-i", "-l"},
    "timeout": {"-s", "-k", "--signal", "--kill-after"},
    "gtimeout": {"-s", "-k", "--signal", "--kill-after"},
}
_AWKS = {"awk", "gawk", "mawk", "nawk"}


def _shell_builtin(
    name: str, rest: list[Arg], ctx: Ctx, cmd: Cmd | None
) -> Verdict | None:
    """シェルの状態を変える組み込み。該当しなければ None。"""
    if name in ("export", "readonly", "local", "declare", "typeset"):
        for a in rest:
            m = _ASSIGN.match(a.value) if a.resolved else None
            if m:
                prior = _lookup(m.group(1), ctx, {}) if "+=" in a.value else ""
                ctx.vars[m.group(1)] = prior + m.group(2)
            elif not a.resolved and "=" in a.value:
                ctx.vars[a.value.split("=", 1)[0]] = UNKNOWN
        return ALLOW
    if name == "trap" and rest:
        if not rest[0].resolved:
            return _opaque(rest[0].value, ctx, "trap の中身が変数で決まる")
        return _decide_script(rest[0].value, _child(ctx))
    if name in ("cd", "pushd"):
        # パイプの中と & で後ろに回した cd は、いまのシェルの場所を変えない
        if cmd is not None and (cmd.stdin_piped or cmd.in_pipeline or cmd.background):
            return ALLOW
        target = next((a for a in rest if not a.value.startswith("-")), None)
        if any(a.value == "-" for a in rest):
            ctx.cwd = None  # cd - の行き先は、前の場所の記録しだいで決まらない
        elif target is None:
            ctx.cwd = ctx.env.get("HOME")
        elif not target.resolved:
            ctx.cwd = None
        else:
            ctx.cwd = _join(ctx.cwd, target.value)
        return ALLOW
    if name == "eval":
        if not all(a.resolved for a in rest):
            return _opaque(
                " ".join(a.value for a in rest), ctx, "eval の中身が変数で決まる"
            )
        return _decide_script(
            " ".join(a.value for a in rest), _child(ctx, vars=ctx.vars)
        )
    return None


def _index_of(args: list[Arg], *values: str) -> int | None:
    return next((i for i, a in enumerate(args) if a.value in values), None)


def _unwrap_tool(name: str, rest: list[Arg], ctx: Ctx) -> list[Arg] | Verdict | None:
    """mise exec・uv run・nix develop/shell の中のコマンド。該当しなければ None。"""
    sub = rest[0].value if rest else None
    if name == "mise" and sub in ("exec", "x"):
        dc = _index_of(rest, "-c", "--command")
        if dc is not None and dc + 1 < len(rest):
            if not rest[dc + 1].resolved:
                return _opaque(
                    rest[dc + 1].value, ctx, "mise exec -c の中身が変数で決まる"
                )
            return _decide_script(rest[dc + 1].value, _child(ctx))
        dd = _index_of(rest, "--")
        return ALLOW if dd is None else rest[dd + 1 :]
    if name == "uv" and sub == "run":
        return _skip_opts(rest[1:], with_value=_UV_RUN_WITH_VALUE)
    if name == "nix" and sub in ("develop", "shell"):
        dc = _index_of(rest, "-c", "--command")
        return ALLOW if dc is None else rest[dc + 1 :]
    return None


def _unresolved_head(args: list[Arg], ctx: Ctx, cmd: Cmd | None) -> Verdict:
    """実行ファイルの名前が決まらないとき。引数の文ではなく、語の位置と変数の中身で見る。

    止めるのは、(a) 先頭の語（サブコマンドの位置）が push・merge などの形のとき、
    (b) 名前を決める変数やコマンド置換の中身が git や gh の push・マージに見えるとき。
    """
    why = "実行ファイルの名前が変数やコマンド置換で決まる"
    words = [a.value for a in args[1:] if not a.value.startswith("-")][:3]
    if any(w in ("push", "send-pack", "merge") for w in words) or words[:1] == ["api"]:
        return _deny_unresolved("マージか push に見えるコマンド", why)
    head_raw = ""
    if cmd is not None and len(cmd.words) >= len(args):
        head_raw = cmd.words[len(cmd.words) - len(args)].raw
    names = re.findall(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)", head_raw)
    text = "\n".join([head_raw] + [ctx.opaque[n] for n in names if n in ctx.opaque])
    if _OPAQUE_STRONG.search(text):
        return _deny_unresolved("マージか push に見えるコマンド", why)
    return ALLOW


# 解析できなかった文字列の中で、git・gh・hub・curl がコマンドの位置に現れうるところ
_COMMAND_POSITION = re.compile(
    r"(?:^|[;&|(\n`{]|\$\()\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*"
    r"(?:(?:sudo|env|command|exec|nohup|time|xargs|timeout\s+\S+)\s+)*(?:\S*/)?(?:git|gh|hub|curl)\b"
)


def _unparsed(text: str, ctx: Ctx, why: str) -> Verdict:
    """解析に失敗したとき。git や gh が実行ファイルとして現れうる場合に限って止める。"""
    for m in _COMMAND_POSITION.finditer(text):
        tail = text[m.start() :]
        if re.search(r"\b(push|merge|api|send-pack|graphql)\b", tail):
            return _deny_unresolved("マージか push に見えるコマンド", why)
    return ALLOW


def _decide_argv(
    args: list[Arg],
    ctx: Ctx,
    cmd_env: dict[str, str],
    *,
    stdin: Stdin | None = None,
    args_unknown: bool = False,
) -> Verdict:
    stdin = stdin or Stdin()
    cmd = stdin.cmd
    while args:
        head = args[0]
        if not head.resolved:
            return _unresolved_head(args, ctx, cmd)
        name = _base(head.value)
        rest = args[1:]
        if head.value in _RESERVED or head.value == "coproc":
            args = rest
            continue
        if head.value == "function":
            args = rest[1:]  # function NAME { ... }
            continue
        builtin = _shell_builtin(name, rest, ctx, cmd)
        if builtin is not None:
            return builtin
        if name == "env":
            args, chdir, split = _strip_env(rest, cmd_env)
            if chdir is not None:
                ctx = _with_cwd(ctx, chdir)
            if split is not None:
                sub = _child(ctx)
                sub.vars.update(cmd_env)
                return _decide_script(
                    split + " " + " ".join(shlex.quote(a.value) for a in args), sub
                )
            continue
        if name in _PREFIX_WRAPPERS:
            args = _skip_opts(rest, with_value=_PREFIX_WRAPPERS[name])
            if name in ("timeout", "gtimeout"):
                args = args[1:]  # DURATION
            args_unknown = args_unknown or name == "xargs"
            continue
        unwrapped = _unwrap_tool(name, rest, ctx)
        if isinstance(unwrapped, Verdict):
            return unwrapped
        if unwrapped is not None:
            args = unwrapped
            continue
        return _decide_tool(name, args, ctx, cmd_env, stdin, args_unknown)
    return ALLOW


def _decide_tool(
    name: str,
    args: list[Arg],
    ctx: Ctx,
    cmd_env: dict[str, str],
    stdin: Stdin,
    args_unknown: bool,
) -> Verdict:
    """包みを剥がしたあとの、実際に動くコマンドを判定する。"""
    rest = args[1:]
    if name == "parallel":  # 引数をコマンドとして実行する
        return _opaque(
            " ".join(a.value for a in rest), ctx, "parallel の中身は解析しない"
        )
    if name in _AWKS:
        text = " ".join(a.value for a in rest)
        # awk が外のコマンドを起動するのは system() と、print | "cmd"、"cmd" | getline
        launch = re.search(r"system\s*\(|\|\s*\"|\"\s*\|\s*getline|\|&", text)
        return _opaque(text, ctx, f"{name} の中身は解析しない") if launch else ALLOW
    if name in ("find", "fd"):
        return _decide_find(rest, ctx, cmd_env)
    if name in _SHELLS:
        return _decide_shell(rest, ctx, cmd_env, stdin)
    if name in _INTERPRETERS or re.fullmatch(r"python3(\.\d+)?|ruby\d*|perl\d*", name):
        return _decide_interpreter(name, rest, ctx, stdin)
    if name in ("git", "hub") or name.startswith("git-"):
        return _decide_git(args, ctx, cmd_env, args_unknown)
    if name == "gh":
        return _decide_gh(rest, ctx, cmd_env, args_unknown)
    if name in ("curl", "wget", "http", "https", "xh", "xhs"):
        return _decide_http(name, rest, ctx, stdin.text)
    return ALLOW


_INLINE_CODE_FLAGS = {"-c", "-e", "-E", "-r", "--eval", "-p", "--print", "eval"}


def _decide_interpreter(
    name: str,
    args: list[Arg],
    ctx: Ctx,
    stdin: Stdin,
) -> Verdict:
    why = f"{name} のコードの中は解析しない"
    inline = any(a.value in _INLINE_CODE_FLAGS for a in args)
    if inline:
        return _opaque_code(" ".join(a.value for a in args), ctx, why, name)
    script = next((a for a in args if not a.value.startswith("-")), None)
    if script is not None and script.value != "-":
        return ALLOW  # スクリプトのファイルの中身は読まない（残る穴）
    code = " ".join(a.value for a in args)
    if stdin.text:
        code += "\n" + stdin.text
    elif stdin.unknown and stdin.cmd is not None:
        code += "\n" + stdin.cmd.pipeline_text
    return _opaque_code(code, ctx, why, name)


def _join(cwd: str | None, path: str) -> str | None:
    if path.startswith("/"):
        return os.path.normpath(path)
    if cwd is None:
        return None
    return os.path.normpath(os.path.join(cwd, path))


def _with_cwd(ctx: Ctx, path: str | None) -> Ctx:
    cwd = None if path is None else _join(ctx.cwd, path)
    return replace(ctx, cwd=cwd)


def _skip_opts(args: list[Arg], with_value: set[str]) -> list[Arg]:
    i = 0
    while i < len(args):
        v = args[i].value
        if v == "--":
            return args[i + 1 :]
        if not v.startswith("-") or v == "-":
            break
        if v in with_value:
            i += 2
            continue
        i += 1
    return args[i:]


def _strip_env(
    args: list[Arg], cmd_env: dict[str, str]
) -> tuple[list[Arg], str | None, str | None]:
    chdir: str | None = None
    split: str | None = None
    i = 0
    while i < len(args):
        v = args[i].value
        if v == "--":
            i += 1
            break
        if v in ("-u", "--unset") and i + 1 < len(args):
            cmd_env.pop(args[i + 1].value, None)
            i += 2
            continue
        if v in ("-C", "--chdir") and i + 1 < len(args):
            chdir = args[i + 1].value if args[i + 1].resolved else None
            i += 2
            continue
        if v.startswith("--chdir="):
            chdir = v.split("=", 1)[1] if args[i].resolved else None
            i += 1
            continue
        if v in ("-S", "--split-string") and i + 1 < len(args):
            split = args[i + 1].value
            i += 2
            continue
        if v.startswith("-S") and len(v) > 2:
            split = v[2:]
            i += 1
            continue
        if v.startswith("-"):
            i += 1
            continue
        m = _ASSIGN.match(v) if args[i].resolved else None
        if m:
            cmd_env[m.group(1)] = m.group(2)
            i += 1
            continue
        break
    rest = args[i:]
    if split is not None:
        return rest, chdir, split
    return rest, chdir, None


def _decide_find(args: list[Arg], ctx: Ctx, cmd_env: dict[str, str]) -> Verdict:
    i = 0
    while i < len(args):
        if args[i].value in (
            "-exec",
            "-execdir",
            "-ok",
            "-okdir",
            "-x",
            "--exec",
            "-X",
            "--exec-batch",
        ):
            j = i + 1
            while j < len(args) and args[j].value not in (";", "+"):
                j += 1
            v = _decide_argv(args[i + 1 : j], ctx, dict(cmd_env), args_unknown=True)
            if not v.allowed:
                return v
            i = j
        i += 1
    return ALLOW


def _decide_shell(
    args: list[Arg],
    ctx: Ctx,
    cmd_env: dict[str, str],
    stdin: Stdin,
) -> Verdict:
    i = 0
    script: str | None = None
    script_file: Arg | None = None
    while i < len(args):
        v = args[i].value
        if v in ("-o", "+o", "-O", "+O"):
            i += 2
            continue
        if v.startswith("-") and len(v) > 1 and not v.startswith("--") and "c" in v[1:]:
            if i + 1 < len(args) and args[i + 1].value == "--":
                i += 1
            if i + 1 < len(args):
                if not args[i + 1].resolved:
                    return _opaque(
                        args[i + 1].value, ctx, "シェルに渡す文字列が変数で決まる"
                    )
                script = args[i + 1].value
            break
        if v.startswith(("-", "+")):
            i += 1
            continue
        script_file = args[i]
        break
    sub = _child(ctx)
    sub.vars.update(cmd_env)
    if script is not None:
        return _decide_script(script, sub)
    if script_file is not None:
        return ALLOW  # スクリプトのファイルの中身は読まない（残る穴）
    if stdin.text is not None:
        return _decide_script(stdin.text, sub)
    if stdin.unknown and stdin.cmd is not None:
        why = "シェルへ標準入力で流し込むコマンドは解析しない"
        return _opaque(stdin.cmd.pipeline_text, ctx, why)
    return ALLOW


# --- git -------------------------------------------------------------------

_GIT_GLOBAL_WITH_VALUE = {
    "-C",
    "-c",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--config-env",
    "--exec-path",
}


@dataclass
class GitCall:
    """git の 1 回の呼び出しで、宛先を決めるのに使う値。"""

    location: str | None
    location_unknown: bool
    info: RepoInfo | None
    inline_config: list[str]
    cmd_env: Mapping[str, str]

    def unreadable(self) -> Verdict | None:
        if self.location_unknown or self.location is None:
            return _deny_unresolved("git push", "作業ディレクトリを決められない")
        if self.info is None:
            where = self.location.removeprefix(GIT_DIR_PREFIX)
            return _deny_unresolved("git push", f"{where} の git の設定を読めない")
        return None


def _parse_git_globals(
    rest: list[Arg], ctx: Ctx, cmd_env: Mapping[str, str]
) -> tuple[GitCall, list[Arg]]:
    """git の前置きのオプション（-C、--git-dir、-c）を読み、残りを返す。"""
    location: str | None = ctx.cwd
    git_dir = cmd_env.get("GIT_DIR", ctx.vars.get("GIT_DIR", ctx.env.get("GIT_DIR")))
    location_unknown = git_dir is not None and UNKNOWN in git_dir
    inline_config: list[str] = []
    if git_dir is not None:
        location = _join(ctx.cwd, git_dir)
        location = None if location is None else GIT_DIR_PREFIX + location
    i = 0
    while i < len(rest) and rest[i].value.startswith("-"):
        key, eq, val = rest[i].value.partition("=")
        resolved = rest[i].resolved
        if key in _GIT_GLOBAL_WITH_VALUE and not eq:
            if i + 1 >= len(rest):
                break
            val, resolved = rest[i + 1].value, rest[i + 1].resolved
            i += 1
        i += 1
        if key in ("-C", "--git-dir") and not resolved:
            location_unknown = True
        elif (
            key == "-C"
            and location is not None
            and not location.startswith(GIT_DIR_PREFIX)
        ):
            location = _join(location, val)
        elif key == "--git-dir":
            base = (
                ctx.cwd if location is None else location.removeprefix(GIT_DIR_PREFIX)
            )
            p = _join(base, val)
            location = None if p is None else GIT_DIR_PREFIX + p
        elif key in ("-c", "--config-env"):
            inline_config.append(val if resolved else UNKNOWN + val)
            if key == "--config-env":
                inline_config.append(UNKNOWN + "config-env")
    info = None if location_unknown or location is None else ctx.repos.get(location)
    return GitCall(location, location_unknown, info, inline_config, cmd_env), rest[i:]


def _expand_git_alias(sub: list[Arg], call: GitCall, ctx: Ctx) -> list[Arg] | Verdict:
    """git のエイリアスを展開する（設定、-c alias.x=...、同じコマンドの中での定義）。"""
    aliases = {**(call.info.git_aliases if call.info else {}), **ctx.git_aliases}
    for c in call.inline_config:
        k, _, val = c.partition("=")
        if k.lower().startswith("alias."):
            aliases[k[6:]] = val
    seen = set()
    while (
        sub and sub[0].resolved and sub[0].value in aliases and sub[0].value not in seen
    ):
        seen.add(sub[0].value)
        expansion = aliases[sub[0].value]
        if expansion.startswith("!"):
            script = (
                expansion[1:] + " " + " ".join(shlex.quote(a.value) for a in sub[1:])
            )
            return _decide_script(script, _child(ctx))
        try:
            sub = [Arg(w, True) for w in shlex.split(expansion)] + sub[1:]
        except ValueError:
            return _deny_unresolved("git のエイリアス", "エイリアスを解析できない")
    return sub


def _decide_git(
    args: list[Arg], ctx: Ctx, cmd_env: dict[str, str], args_unknown: bool
) -> Verdict:
    name = _base(args[0].value)
    call, sub = _parse_git_globals(args[1:], ctx, cmd_env)
    if name.startswith("git-") and name != "git-receive-pack":
        sub = [Arg(name[4:], True)] + args[1:]
    expanded = _expand_git_alias(sub, call, ctx)
    if isinstance(expanded, Verdict):
        return expanded
    sub = expanded
    if not sub:
        return ALLOW
    if not sub[0].resolved:
        return _deny_unresolved("git のコマンド", "git のサブコマンドが変数で決まる")
    op = sub[0].value
    second = sub[1].value if len(sub) > 1 else None
    if name == "hub" and op == "api":
        return _decide_gh(sub, ctx, cmd_env, args_unknown)
    _mark_git_config_write(op, sub[1:], ctx)
    if op == "push":
        return _decide_git_push(sub[1:], ctx, call, args_unknown)
    if op == "subtree" and second == "push":
        return _decide_git_push(sub[2:], ctx, call, args_unknown, subtree=True)
    if op == "send-pack" or (op == "lfs" and second == "push"):
        label = "git send-pack" if op == "send-pack" else "git lfs push"
        positional = [
            a
            for a in sub[1 if op == "send-pack" else 2 :]
            if not a.value.startswith("-")
        ]
        if not positional:
            return _deny_unresolved(label, "宛先が書かれていない")
        risk = _push_config_risk(call.inline_config, cmd_env, ctx)
        return (
            risk if not risk.allowed else _check_push_target(positional[0], ctx, call)
        )
    return ALLOW


_PUSH_WITH_VALUE = {"--repo", "-o", "--push-option", "--receive-pack", "--exec"}
_GIT_CONFIG_READ = {
    "--get",
    "--get-all",
    "--get-regexp",
    "--get-urlmatch",
    "--list",
    "-l",
    "get",
    "list",
}
_PUSH_CONFIG_KEY = re.compile(r"^(remote|branch|url|alias)\.", re.IGNORECASE)


def _mark_git_config_write(op: str, args: list[Arg], ctx: Ctx) -> None:
    """同じコマンドの中で、push 先に効く設定を書き換えたら印を付ける。"""
    values = [a.value for a in args]
    if op == "config" and not any(v in _GIT_CONFIG_READ for v in values):
        positional = [v for v in values if not v.startswith("-")]
        if positional[:1] == ["set"]:
            positional = positional[1:]
        if len(positional) >= 2 and positional[0].lower().startswith("alias."):
            ctx.git_aliases[positional[0][6:]] = positional[1]
        if len(positional) >= 2 or "--unset" in values:
            ctx.dirty.add("git config")
    if op == "remote" and values[:1] and values[0] in ("add", "set-url", "rename"):
        ctx.dirty.add("git remote " + values[0])


def _push_config_risk(
    inline_config: list[str], cmd_env: Mapping[str, str], ctx: Ctx
) -> Verdict:
    """-c や環境変数や同じコマンドの中での設定の書き換えで、push 先が変わりうるか。"""
    for c in inline_config:
        lowered = c.lower()
        entry = next((b for b in ctx.blocked if b in lowered), None)
        if entry:
            return _deny("git push", c.lstrip(UNKNOWN).partition("=")[2] or c, entry)
        if c.startswith(UNKNOWN) or _PUSH_CONFIG_KEY.match(c):
            return _deny_unresolved(
                "git push", "git -c で push 先に効く設定を差し替えている"
            )
    for scope in (cmd_env, ctx.vars, ctx.env):
        if any(k in scope for k in ("GIT_CONFIG_COUNT", "GIT_CONFIG_PARAMETERS")):
            return _deny_unresolved("git push", "GIT_CONFIG_* で設定を差し替えている")
    if ctx.dirty:
        why = (
            f"同じコマンドの中で設定を書き換えている（{', '.join(sorted(ctx.dirty))}）"
        )
        return _deny_unresolved("git push", why)
    return ALLOW


def _split_push_args(args: list[Arg], subtree: bool) -> tuple[list[Arg], Arg | None]:
    """git push の引数から、位置引数と --repo の値を取り出す。"""
    repo_arg: Arg | None = None
    positional: list[Arg] = []
    i = 0
    while i < len(args):
        v = args[i].value
        if v == "--":
            positional.extend(args[i + 1 :])
            break
        key, eq, val = v.partition("=")
        if key == "--repo":
            if eq:
                repo_arg = Arg(val, args[i].resolved)
            elif i + 1 < len(args):
                repo_arg = args[i + 1]
                i += 1
        elif (subtree and key in ("-P", "--prefix", "-m", "--message") and not eq) or (
            key in _PUSH_WITH_VALUE and not eq
        ):
            i += 1
        elif not v.startswith("-") or v == "-":
            positional.append(args[i])
        i += 1
    return positional, repo_arg


def _decide_git_push(
    args: list[Arg], ctx: Ctx, call: GitCall, args_unknown: bool, subtree: bool = False
) -> Verdict:
    positional, repo_arg = _split_push_args(args, subtree)
    risk = _push_config_risk(call.inline_config, call.cmd_env, ctx)
    if not risk.allowed:
        return risk
    target = positional[0] if positional else repo_arg
    if target is None and args_unknown:
        return _deny_unresolved("git push", "宛先が標準入力などから渡される")
    if target is None:
        unreadable = call.unreadable()
        if unreadable is not None:
            return unreadable
        if call.info.default_push_remote is None:
            return _deny_unresolved("git push", "既定の push 先を決められない")
        target = Arg(call.info.default_push_remote, True)
    return _check_push_target(target, ctx, call)


def _check_push_target(target: Arg, ctx: Ctx, call: GitCall) -> Verdict:
    if not target.resolved:
        return _deny_unresolved("git push", "宛先が変数やコマンド置換で決まる")
    value = target.value
    if looks_like_url(value):
        repo = repo_from_url(value)
        if repo is None:
            return _deny_unresolved("git push", f"URL {value} から宛先を読めない")
        entry = blocked_entry(repo, ctx.blocked)
        return _deny("git push", repo, entry) if entry else ALLOW
    if looks_like_path(value):
        return ALLOW  # 手元のディレクトリへの push
    unreadable = call.unreadable()
    if unreadable is not None:
        return unreadable
    remote = call.info.remotes.get(value)
    if remote is None:
        return _deny_unresolved("git push", f"remote {value} が見つからない")
    for url in remote.fetch_urls + remote.push_urls:
        repo = repo_from_url(url)
        entry = repo and blocked_entry(repo, ctx.blocked)
        if entry:
            return _deny(f"git push（remote {value}）", repo, entry)
    return ALLOW


# --- gh --------------------------------------------------------------------

_GH_WITH_VALUE = {
    "-R", "--repo", "-X", "--method", "-f", "--raw-field", "-F", "--field", "-H", "--header", "--input",
    "-q", "--jq", "-t", "--template", "--cache", "-p", "--preview", "--hostname", "-b", "--body",
    "--subject", "--body-file", "--match-head-commit", "-A", "--author-email", "--title", "-B", "--base",
    "--head", "-a", "--assignee", "-l", "--label", "-m", "--milestone", "--notes", "--notes-file",
    "--target", "-n", "--notes-start-tag", "--discussion-category", "-s", "--source", "-r", "--reviewer",
    "-e", "--editor", "--json", "-L", "--limit", "-S", "--search", "--state", "--branch", "-c", "--comment",
    "-w", "--web",
}  # fmt: skip
_GH_BOOL = {"-w", "--web", "-c", "--comment", "-e", "--editor"}


@dataclass
class GhArgs:
    positional: list[Arg]
    flags: dict[str, list[Arg]]


def _parse_gh(args: list[Arg], group: str | None = None) -> GhArgs:
    positional: list[Arg] = []
    flags: dict[str, list[Arg]] = {}
    i = 0
    while i < len(args):
        v = args[i].value
        if v == "--":
            positional.extend(args[i + 1 :])
            break
        if v.startswith("--") and "=" in v:
            k, _, val = v.partition("=")
            flags.setdefault(k, []).append(Arg(val, args[i].resolved))
            i += 1
            continue
        if (
            v.startswith("-")
            and len(v) > 2
            and not v.startswith("--")
            and v[:2] in ("-R", "-X", "-f", "-F", "-H")
        ):
            flags.setdefault(v[:2], []).append(Arg(v[2:], args[i].resolved))
            i += 1
            continue
        if v.startswith("-") and v != "-":
            takes = v in _GH_WITH_VALUE and v not in _GH_BOOL
            if group == "pr" and v in (
                "-d",
                "--delete-branch",
                "--auto",
                "--admin",
                "--squash",
                "--merge",
                "--rebase",
                "-s",
                "-m",
                "-r",
                "--disable-auto",
            ):
                takes = False
            if group == "pr" and v in (
                "-t",
                "--subject",
                "-b",
                "--body",
                "-F",
                "--body-file",
                "-A",
            ):
                takes = True
            if takes and i + 1 < len(args):
                flags.setdefault(v, []).append(args[i + 1])
                i += 2
            else:
                flags.setdefault(v, []).append(Arg("", True))
                i += 1
            continue
        positional.append(args[i])
        i += 1
    return GhArgs(positional, flags)


def _gh_flag(p: GhArgs, *names: str) -> Arg | None:
    for n in names:
        if n in p.flags:
            return p.flags[n][-1]
    return None


def _gh_target(
    p: GhArgs, ctx: Ctx, cmd_env: dict[str, str], op: str, explicit: Arg | None = None
) -> Verdict:
    """gh の宛先を決めて判定する。"""
    candidates: list[str] = []
    if explicit is not None:
        if not explicit.resolved:
            return _deny_unresolved(op, "宛先が変数やコマンド置換で決まる")
        r = repo_from_gh_arg(explicit.value)
        if r is None:
            return _deny_unresolved(op, f"{explicit.value} から宛先を読めない")
        candidates = [r]
    if not candidates:
        flag = _gh_flag(p, "-R", "--repo")
        if flag is not None:
            if not flag.resolved:
                return _deny_unresolved(op, "-R の値が変数やコマンド置換で決まる")
            r = repo_from_gh_arg(flag.value)
            if r is None:
                return _deny_unresolved(op, f"-R {flag.value} から宛先を読めない")
            candidates = [r]
    if not candidates:
        candidates_or_verdict = _gh_default(ctx, cmd_env, op)
        if isinstance(candidates_or_verdict, Verdict):
            return candidates_or_verdict
        candidates = candidates_or_verdict
    for r in candidates:
        e = blocked_entry(r, ctx.blocked)
        if e:
            return _deny(op, r, e)
    return ALLOW


def _gh_default(ctx: Ctx, cmd_env: dict[str, str], op: str) -> list[str] | Verdict:
    if ctx.dirty:
        why = (
            f"同じコマンドの中で設定を書き換えている（{', '.join(sorted(ctx.dirty))}）"
        )
        return _deny_unresolved(op, why)
    gh_repo = cmd_env.get("GH_REPO", ctx.vars.get("GH_REPO", ctx.env.get("GH_REPO")))
    if gh_repo:
        r = repo_from_gh_arg(gh_repo)
        if r is None:
            return _deny_unresolved(op, f"GH_REPO={gh_repo} から宛先を読めない")
        return [r]
    if ctx.cwd is None:
        return _deny_unresolved(op, "作業ディレクトリを決められない")
    info = ctx.repos.get(ctx.cwd)
    if info is None:
        return _deny_unresolved(op, f"{ctx.cwd} の git の設定を読めない")
    return gh_default_repos(info) or _deny_unresolved(
        op, "作業ディレクトリに GitHub の remote がない"
    )


def gh_default_repos(info: RepoInfo) -> list[str]:
    """gh が既定にする宛先の候補。set-default があればそれ、なければ全 remote。"""
    for remote in info.remotes.values():
        if remote.gh_resolved:
            if remote.gh_resolved == "base":
                repos = [repo_from_url(u) for u in remote.fetch_urls]
            else:
                repos = [repo_from_gh_arg(remote.gh_resolved)]
            found = [r for r in repos if r]
            if found:
                return found
    out = []
    for remote in info.remotes.values():
        for u in remote.fetch_urls:
            r = repo_from_url(u)
            if r and r not in out:
                out.append(r)
    return out


def _decide_gh(
    args: list[Arg], ctx: Ctx, cmd_env: dict[str, str], args_unknown: bool
) -> Verdict:
    first_pass = _parse_gh(args)
    if not first_pass.positional:
        return ALLOW
    first = first_pass.positional[0]
    if not first.resolved:
        return _deny_unresolved("gh のコマンド", "gh のサブコマンドが変数で決まる")
    group = first.value
    p = _parse_gh(args, group)
    pos = p.positional
    sub = pos[1].value if len(pos) > 1 else None
    if group == "repo" and sub == "set-default":
        ctx.dirty.add("gh repo set-default")
        return ALLOW
    if group == "pr" and sub in ("merge", "update-branch"):
        op = "gh pr merge" if sub == "merge" else "gh pr update-branch"
        explicit = None
        # 番号とブランチ名は既定の宛先の PR を指す。URL のときだけ URL の宛先
        if (
            len(pos) > 2
            and (
                "://" in pos[2].value or pos[2].value.lower().startswith("github.com/")
            )
            or len(pos) > 2
            and not pos[2].resolved
            and _gh_flag(p, "-R", "--repo") is None
        ):
            explicit = pos[2]
        if args_unknown and len(pos) <= 2:
            explicit = Arg("", False) if _gh_flag(p, "-R", "--repo") is None else None
        return _gh_target(p, ctx, cmd_env, op, explicit)
    if group == "repo" and sub == "sync":
        if len(pos) > 2:
            return _gh_target(p, ctx, cmd_env, "gh repo sync", pos[2])
        return ALLOW  # 宛先がなければ手元のリポジトリだけを更新する
    if group == "repo" and sub in ("delete", "rename", "archive"):
        return _gh_target(
            p, ctx, cmd_env, f"gh repo {sub}", pos[2] if len(pos) > 2 else None
        )
    if group == "release" and sub in (
        "create",
        "edit",
        "delete",
        "upload",
        "delete-asset",
    ):
        return _gh_target(p, ctx, cmd_env, f"gh release {sub}")
    if group == "api":
        return _decide_gh_api(p, ctx, cmd_env)
    return ALLOW


def _decide_gh_api(p: GhArgs, ctx: Ctx, cmd_env: dict[str, str]) -> Verdict:
    if len(p.positional) < 2:
        return ALLOW
    endpoint = p.positional[1]
    method_arg = _gh_flag(p, "-X", "--method")
    fields = [
        a for k in ("-f", "--raw-field", "-F", "--field") for a in p.flags.get(k, [])
    ]
    has_body = bool(fields) or "--input" in p.flags
    if method_arg is None:
        method: str | None = "POST" if has_body else "GET"
    else:
        method = method_arg.value.upper() if method_arg.resolved else None
    if not endpoint.resolved:
        if method == "GET":
            return ALLOW
        return _deny_unresolved(
            "gh api の書き込み", "エンドポイントが変数やコマンド置換で決まる"
        )
    path = _api_path(endpoint.value)
    if path == "graphql":
        query_fields = [a for a in fields if a.value.startswith("query=")]
        if "--input" in p.flags or not query_fields:
            return _deny_unresolved(
                "gh api graphql", "クエリが入力ファイルから渡され中身を見られない"
            )
        for q in query_fields:
            text = q.value[len("query=") :]
            if not q.resolved or text.startswith("@"):
                return _deny_unresolved(
                    "gh api graphql", "クエリが変数やファイルで渡され中身を見られない"
                )
            m = _GRAPHQL_WRITES.search(text)
            if m:
                return _deny_unresolved(
                    f"GraphQL の {m.group(1)}", "GraphQL はノード ID で宛先を指す"
                )
        return ALLOW
    if method == "GET":
        return ALLOW
    return _check_rest_write(path, method, ctx, cmd_env, "gh api")


def _api_path(value: str) -> str:
    v = unquote(value.strip())
    v = re.sub(r"^https?://[^/]+?(?:/api/v3)?(?=/|$)", "", v, flags=re.IGNORECASE)
    v = v.split("?", 1)[0].split("#", 1)[0]
    return posixpath.normpath("/" + v).strip("/")


def _api_host(url: str) -> str | None:
    m = re.match(r"^(?:https?://)?(?:[^@/]*@)?([^/:?#]+)", url.strip(), re.IGNORECASE)
    return m.group(1).lower() if m else None


def _check_rest_write(
    path: str, method: str | None, ctx: Ctx, cmd_env: dict[str, str], op_name: str
) -> Verdict:
    by_id = re.match(r"^repositories/[^/]+(?:/(.*))?$", path)
    if by_id and _REST_WRITE_PATH.match(by_id.group(1) or ""):
        return _deny_unresolved(
            f"{op_name} の {method or '書き込み'} {path}",
            "リポジトリを数値の ID で指している",
        )
    m = re.match(r"^repos/([^/]+)/([^/]+)(?:/(.*))?$", path)
    if not m:
        return ALLOW
    owner, repo, rest = m.group(1), m.group(2), m.group(3) or ""
    if not _REST_WRITE_PATH.match(rest):
        return ALLOW
    if rest == "" and method not in ("PATCH", "DELETE", None):
        return ALLOW
    op = f"{op_name} の {method or '書き込み'} {path}"
    if "{" in owner or "{" in repo:
        default = _gh_default(ctx, cmd_env, op)
        if isinstance(default, Verdict):
            return default
        candidates = default
    elif "\0" in owner or "\0" in repo:
        return _deny_unresolved(op, "owner や repo が変数で決まる")
    else:
        candidates = [f"{owner}/{repo}".lower()]
    for r in candidates:
        e = blocked_entry(r, ctx.blocked)
        if e:
            return _deny(op, r, e)
    return ALLOW


# --- curl / wget -----------------------------------------------------------

_CURL_WITH_VALUE = {
    "-X", "--request", "-d", "--data", "--data-raw", "--data-binary", "--data-urlencode", "--json", "-F",
    "--form", "-T", "--upload-file", "-H", "--header", "-o", "--output", "-u", "--user", "-A", "--user-agent",
    "-e", "--referer", "-b", "--cookie", "-c", "--cookie-jar", "-K", "--config", "--max-time", "-m",
    "--connect-timeout", "-w", "--write-out", "--url", "--method", "--post-data", "--body-data", "-O",
}  # fmt: skip


_CURL_SHORT_WITH_VALUE = set("XdFTHouAebcKmwE")


def _split_short_flags(args: list[Arg]) -> list[Arg]:
    """curl の -sXPUT のようにまとめた短いフラグを、1 つずつに分ける。"""
    out: list[Arg] = []
    for a in args:
        v = a.value
        if not (v.startswith("-") and not v.startswith("--") and len(v) > 2):
            out.append(a)
            continue
        letters = v[1:]
        for j, ch in enumerate(letters):
            out.append(Arg("-" + ch, a.resolved))
            if ch in _CURL_SHORT_WITH_VALUE:
                if letters[j + 1 :]:
                    out.append(Arg(letters[j + 1 :], a.resolved))
                break
    return out


def _decide_http(
    name: str, args: list[Arg], ctx: Ctx, stdin_text: str | None
) -> Verdict:
    method: str | None = None
    body: list[str] = []
    urls: list[Arg] = []
    unresolved_body = False
    i = 0
    positional_method = name in ("http", "https", "xh", "xhs")
    args = _split_short_flags(args)
    while i < len(args):
        a = args[i]
        v = a.value
        key, eq, val = v.partition("=") if v.startswith("--") else (v, "", "")
        if key in _CURL_WITH_VALUE and (eq or i + 1 < len(args)):
            arg = Arg(val, a.resolved) if eq else args[i + 1]
            i += 1 if eq else 2
            if key in ("-X", "--request", "--method"):
                method = arg.value.upper() if arg.resolved else None
            elif key in (
                "-d",
                "--data",
                "--data-raw",
                "--data-binary",
                "--data-urlencode",
                "--json",
                "-F",
                "--form",
                "--post-data",
                "--body-data",
            ):
                body.append(arg.value)
                unresolved_body |= not arg.resolved or arg.value.startswith("@")
                method = method or "POST"
            elif key in ("-T", "--upload-file"):
                method = method or "PUT"
            elif key == "--url":
                urls.append(arg)
            continue
        if v.startswith("-"):
            i += 1
            continue
        if positional_method and re.fullmatch(r"[A-Za-z]+", v) and not urls:
            method = v.upper()
        else:
            urls.append(a)
        i += 1
    if stdin_text:
        body.append(stdin_text)
    for u in urls:
        if not u.resolved:
            if method not in (None, "GET", "HEAD"):
                return _deny_unresolved(
                    f"{name} の書き込み", "URL が変数やコマンド置換で決まる"
                )
            continue
        url = u.value
        if "git-receive-pack" in url:
            repo = repo_from_url(url.split("/git-receive-pack")[0])
            e = repo and blocked_entry(repo, ctx.blocked)
            if e:
                return _deny(f"{name} での push", repo, e)
            continue
        host = _api_host(url)
        if not host or not (
            host.startswith(("api.", "uploads.")) or "/api/" in url.lower()
        ):
            continue
        path = _api_path(url if "://" in url else "https://" + url)
        if path == "graphql":
            text = "\n".join(body)
            if unresolved_body:
                return _deny_unresolved(
                    f"{name} での GraphQL",
                    "本文が変数やファイルで渡され中身を見られない",
                )
            m = _GRAPHQL_WRITES.search(text)
            if m:
                return _deny_unresolved(
                    f"GraphQL の {m.group(1)}", "GraphQL はノード ID で宛先を指す"
                )
            continue
        eff = method or ("POST" if body else "GET")
        if eff in ("GET", "HEAD"):
            continue
        v = _check_rest_write(path, eff, ctx, {}, name)
        if not v.allowed:
            return v
    return ALLOW


# ---------------------------------------------------------------------------
# 入口（ここから下だけが外界を読む）
# ---------------------------------------------------------------------------


def load_blocked(environ: Mapping[str, str], home: str) -> tuple[str, ...]:
    """既定の一覧に、環境変数と設定ファイルの分を足す。減らす手段は持たない。"""
    entries = list(DEFAULT_BLOCKED)
    entries += re.split(r"[\s,]+", environ.get(EXTRA_BLOCKED_ENV, ""))
    path = EXTRA_BLOCKED_FILE.replace("~", home, 1)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            entries += [line.split("#", 1)[0] for line in f]
    return normalize_blocked(entries)


def _git(location: str, *args: str) -> list[str] | None:
    if location.startswith(GIT_DIR_PREFIX):
        base = ["git", location]
    else:
        base = ["git", "-C", location]
    try:
        out = subprocess.run(
            base + list(args),
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
            env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    return out.stdout.splitlines()


def read_repo_info(location: str) -> RepoInfo | None:
    """git の設定だけを読む（ネットワークに出ない）。"""
    if _git(location, "rev-parse", "--git-dir") is None:
        return None
    config = (
        _git(
            location, "config", "--get-regexp", r"^(remote\..*\.gh-resolved|alias\..*)$"
        )
        or []
    )
    names = _git(location, "remote") or []
    remotes = {}
    gh_resolved = {}
    aliases = {}
    for line in config:
        k, _, v = line.partition(" ")
        if k.startswith("alias."):
            aliases[k[6:]] = v
        elif k.endswith(".gh-resolved"):
            gh_resolved[k[len("remote.") : -len(".gh-resolved")]] = v
    for name in names:
        fetch = tuple(_git(location, "remote", "get-url", "--all", name) or ())
        push = tuple(_git(location, "remote", "get-url", "--push", "--all", name) or ())
        remotes[name] = Remote(fetch, push, gh_resolved.get(name))
    branch = (_git(location, "symbolic-ref", "--short", "-q", "HEAD") or [None])[0]
    default = None
    keys = ([f"branch.{branch}.pushRemote"] if branch else []) + ["remote.pushDefault"]
    keys += [f"branch.{branch}.remote"] if branch else []
    for key in keys:
        value = _git(location, "config", "--get", key)
        if value:
            default = value[0]
            break
    if default is None and "origin" in remotes:
        default = "origin"
    if default is None and len(remotes) == 1:
        default = next(iter(remotes))
    return RepoInfo(remotes=remotes, default_push_remote=default, git_aliases=aliases)


class LazyRepos(Mapping):
    def __init__(self, reader: Callable[[str], RepoInfo | None] = read_repo_info):
        self._reader = reader
        self._cache: dict[str, RepoInfo | None] = {}

    def __getitem__(self, key: str) -> RepoInfo | None:
        if key not in self._cache:
            self._cache[key] = self._reader(key)
        return self._cache[key]

    def __iter__(self):
        return iter(self._cache)

    def __len__(self) -> int:
        return len(self._cache)


def _fallback(command: str) -> Verdict:
    ctx = Ctx(cwd=None, env={}, vars={}, blocked=DEFAULT_BLOCKED, repos={})
    return _unparsed(command, ctx, "判定の途中で失敗した")


def check(command: str, cwd: str | None, environ: Mapping[str, str]) -> Verdict:
    home = environ.get("HOME", os.path.expanduser("~"))
    try:
        return decide(command, cwd, environ, load_blocked(environ, home), LazyRepos())
    except Exception:  # noqa: BLE001  判定の失敗でマージと push を通さない
        return _fallback(command)


def hook_main(stdin: str, environ: Mapping[str, str]) -> tuple[int, str]:
    """PreToolUse の入口。(終了コード, stderr) を返す。2 で拒否。"""
    if not environ.get("ORCA_AGENT_SESSION_ID"):
        return 0, ""  # オーナーの対話のセッションでは何もしない
    try:
        payload = json.loads(stdin)
    except ValueError:
        return 0, ""
    # Bash と Monitor（Claude）、Bash（Codex）。シェルのコマンドを持つものはすべて見る
    tool_input = payload.get("tool_input")
    command = tool_input.get("command") if isinstance(tool_input, dict) else None
    if not isinstance(command, str):
        return 0, ""
    verdict = check(command, payload.get("cwd") or None, environ)
    if verdict.allowed:
        return 0, ""
    return 2, verdict.reason


# ---------------------------------------------------------------------------
# 設置と取り外し（~/.claude/settings.json と ~/.codex/hooks.json に 1 項目ずつ）
# ---------------------------------------------------------------------------

HOOK_BIN = "$HOME/.local/bin/upstream-guard"
_MISSING_WARNING = (
    "upstream-guard: 実行ファイルが無いため、このコマンドのマージと push の判定をしていません。"
    "副元帥へ知らせてください。"
)
# オーナーの対話のセッションでは Python を起動せずに終える。実行ファイルが無い・壊れた
# （リンク切れ、GC、make apply の途中）ときは、コマンドを止めずに警告だけを渡す。
HOOK_COMMAND = (
    f'G="{HOOK_BIN}"; [ -z "${{ORCA_AGENT_SESSION_ID-}}" ] && exit 0; '
    'if [ -x "$G" ]; then "$G" hook; c=$?; case $c in 0|2) exit $c;; esac; fi; '
    "printf '%s\\n' '"
    + json.dumps(
        {
            "systemMessage": _MISSING_WARNING,
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": _MISSING_WARNING,
            },
        },
        ensure_ascii=False,
    )
    + "'"
)
HOOK_TIMEOUT = 10
TOML_MARK = "# upstream-guard: managed block"


CLAUDE_MATCHER = "Bash|Monitor"  # Monitor もシェルのコマンドを走らせる
CODEX_MATCHER = "Bash"


def _hook_group(matcher: str) -> dict:
    return {
        "matcher": matcher,
        "hooks": [
            {"type": "command", "command": HOOK_COMMAND, "timeout": HOOK_TIMEOUT}
        ],
    }


def _is_ours(group: dict) -> bool:
    # 前の版の形（実行ファイルを直接呼ぶもの）も自分の項目として扱う
    return any(
        ".local/bin/upstream-guard" in h.get("command", "")
        for h in group.get("hooks", [])
    )


def set_pre_tool_use(doc: dict, present: bool, matcher: str) -> tuple[dict, int | None]:
    """PreToolUse から自分の項目を除き、present なら末尾に足す。足した位置を返す。"""
    hooks = doc.setdefault("hooks", {})
    groups = [g for g in hooks.get("PreToolUse", []) if not _is_ours(g)]
    index = None
    if present:
        index = len(groups)
        groups.append(_hook_group(matcher))
    if groups:
        hooks["PreToolUse"] = groups
    else:
        hooks.pop("PreToolUse", None)
    return doc, index


def codex_trusted_hash(group: dict) -> str:
    """Codex の hooks.state の trusted_hash（Orca の hook-trust-promotion と同じ算出）。"""
    import hashlib

    h = group["hooks"][0]
    handler = {
        "type": "command",
        "command": h["command"],
        "timeout": h.get("timeout", 600),
        "async": False,
    }
    node = {
        "event_name": "pre_tool_use",
        "hooks": [handler],
        "matcher": group["matcher"],
    }
    text = json.dumps(node, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(text.encode()).hexdigest()


def set_codex_trust(config_text: str, key: str | None, trusted_hash: str | None) -> str:
    """config.toml から自分の区画（印の行と続く 3 行）を除き、key があれば末尾に足す。"""
    lines = config_text.split("\n")
    out: list[str] = []
    i = 0
    while i < len(lines):
        if lines[i] == TOML_MARK:
            if out and out[-1] == "":
                out.pop()
            i += 4
            continue
        out.append(lines[i])
        i += 1
    text = "\n".join(out).rstrip("\n") + "\n"
    if key is not None:
        text += f'\n{TOML_MARK}\n[hooks.state."{key}"]\nenabled = true\ntrusted_hash = "{trusted_hash}"\n'
    return text


def _rewrite(path: str, new_text: str, stamp: str) -> None:
    with open(path, encoding="utf-8") as f:
        old = f.read()
    if old == new_text:
        return
    with open(f"{path}.bak-upstream-guard-{stamp}", "w", encoding="utf-8") as f:
        f.write(old)
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text)


def apply_install(home: str, present: bool, stamp: str) -> list[str]:
    """present=True で設置、False で取り外し。書き換えたファイルを返す。"""
    done = []
    claude = os.path.join(home, ".claude", "settings.json")
    if os.path.exists(claude):
        with open(claude, encoding="utf-8") as f:
            doc = json.load(f)
        doc, _ = set_pre_tool_use(doc, present, CLAUDE_MATCHER)
        _rewrite(claude, json.dumps(doc, indent=2, ensure_ascii=False) + "\n", stamp)
        done.append(claude)
    codex_hooks = os.path.join(home, ".codex", "hooks.json")
    codex_config = os.path.join(home, ".codex", "config.toml")
    if os.path.exists(codex_hooks) and os.path.exists(codex_config):
        with open(codex_hooks, encoding="utf-8") as f:
            doc = json.load(f)
        doc, index = set_pre_tool_use(doc, present, CODEX_MATCHER)
        _rewrite(
            codex_hooks, json.dumps(doc, indent=2, ensure_ascii=False) + "\n", stamp
        )
        key = (
            None
            if index is None
            else f"{os.path.realpath(codex_hooks)}:pre_tool_use:{index}:0"
        )
        with open(codex_config, encoding="utf-8") as f:
            config_text = f.read()
        trusted = codex_trusted_hash(_hook_group(CODEX_MATCHER))
        _rewrite(codex_config, set_codex_trust(config_text, key, trusted), stamp)
        done += [codex_hooks, codex_config]
    return done


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "hook":
        code, message = hook_main(sys.stdin.read(), os.environ)
        if message:
            print(message, file=sys.stderr)
        return code
    if len(argv) >= 3 and argv[1] == "check":
        # 判定だけを返す入口。コマンドは実行せず、読むのは作業ディレクトリの git の設定だけ。
        #   upstream-guard check [--cwd <dir>] [--] '<command>'
        rest = argv[2:]
        cwd = os.getcwd()
        if rest[:1] == ["--cwd"] and len(rest) >= 2:
            cwd, rest = os.path.abspath(rest[1]), rest[2:]
        if rest[:1] == ["--"]:
            rest = rest[1:]
        if len(rest) != 1:
            print(
                "usage: upstream-guard check [--cwd <dir>] [--] '<command>'",
                file=sys.stderr,
            )
            return 64
        verdict = check(rest[0], cwd, os.environ)
        print("allow" if verdict.allowed else "deny\n" + verdict.reason)
        return 0 if verdict.allowed else 2
    if len(argv) == 2 and argv[1] in ("install", "uninstall"):
        import time

        home = os.path.expanduser("~")
        for path in apply_install(
            home, argv[1] == "install", time.strftime("%Y%m%d%H%M%S")
        ):
            print(f"{argv[1]}: {path}")
        return 0
    print(
        "usage: upstream-guard hook < payload.json | check [--cwd <dir>] [--] '<command>' | install | uninstall",
        file=sys.stderr,
    )
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
