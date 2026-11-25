#!/usr/bin/env python3
"""scripts/upstream_guard.py の判定の表。ネットワークも git も使わない。

nrslib 宛ての例は、ここで文字列として判定の関数に渡すだけで、実行はしない。
"""

from __future__ import annotations

import json
import os
import sys
import unittest
from typing import ClassVar

sys.path.insert(
    0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")
)

import upstream_guard as ug

R = ug.Remote
REPOS: dict[str, ug.RepoInfo | None] = {
    # takt の実物と同じ形: origin は自分、upstream は上流で push の URL は DISABLED、set-default は origin
    "/w/takt": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/takt",),
                ("https://github.com/j5ik2o/takt",),
                "base",
            ),
            "upstream": R(("https://github.com/nrslib/takt.git",), ("DISABLED",)),
        },
        default_push_remote="origin",
    ),
    "/w/takt/sub": None,  # 使わない（cd の解決の確認用）
    "/w/takt-unresolved": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/takt",), ("https://github.com/j5ik2o/takt",)
            ),
            "upstream": R(
                ("https://github.com/nrslib/takt.git",),
                ("https://github.com/nrslib/takt.git",),
            ),
        },
        default_push_remote="origin",
    ),
    "/w/clone": ug.RepoInfo(
        remotes={
            "origin": R(
                ("git@github.com:NRSLib/takt.git",), ("git@github.com:NRSLib/takt.git",)
            )
        },
        default_push_remote="origin",
    ),
    "/w/pushurl": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/x",), ("ssh://git@github.com/nrslib/x.git",)
            )
        },
        default_push_remote="origin",
    ),
    "/w/pushdefault": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/takt",), ("https://github.com/j5ik2o/takt",)
            ),
            "up": R(
                ("https://github.com/nrslib/takt",), ("https://github.com/nrslib/takt",)
            ),
        },
        default_push_remote="up",
    ),
    "/w/mine": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/dotfiles.git",),
                ("https://github.com/j5ik2o/dotfiles.git",),
            )
        },
        default_push_remote="origin",
    ),
    "/w/corp": ug.RepoInfo(
        remotes={
            "origin": R(
                ("git@github.com:ideo-plus/app.git",),
                ("git@github.com:ideo-plus/app.git",),
            )
        },
        default_push_remote="origin",
    ),
    "/w/alias": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/takt",),
                ("https://github.com/j5ik2o/takt",),
                "base",
            ),
            "upstream": R(
                ("https://github.com/nrslib/takt",), ("https://github.com/nrslib/takt",)
            ),
        },
        default_push_remote="origin",
        git_aliases={"pu": "push upstream", "sh": "!git push upstream", "st": "status"},
    ),
    "/w/nodefault": ug.RepoInfo(
        remotes={
            "a": R(("https://github.com/j5ik2o/a",), ("https://github.com/j5ik2o/a",))
        },
        default_push_remote=None,
    ),
    "/w/notrepo": None,
    "/w/up-nodefault": ug.RepoInfo(
        remotes={
            "up": R(
                ("https://github.com/NrsLib/takt",), ("https://github.com/NrsLib/takt",)
            )
        },
        default_push_remote=None,
    ),
    "--git-dir=/w/takt-unresolved/.git": None,
    "--git-dir=/w/clone/.git": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/nrslib/takt",), ("https://github.com/nrslib/takt",)
            )
        },
        default_push_remote="origin",
    ),
    "--git-dir=/w/mine/.git": ug.RepoInfo(
        remotes={
            "origin": R(
                ("https://github.com/j5ik2o/dotfiles.git",),
                ("https://github.com/j5ik2o/dotfiles.git",),
            )
        },
        default_push_remote="origin",
    ),
}


class Repos(dict):
    def get(self, key, default=None):
        return super().get(key, default)


ENV = {"HOME": "/home/u", "PATH": "/usr/bin"}

D, A, W = (
    "deny",
    "allow",
    "warn",
)  # W: 宛先を判定できず、禁止の宛先の語も無いので警告して通す

# (期待, コマンド, 作業ディレクトリ, 追加の環境変数)
CASES: list[tuple[str, str, str | None, dict[str, str]]] = [
    # --- gh pr merge -------------------------------------------------------
    (D, "gh pr merge 12 -R nrslib/takt", "/w/mine", {}),
    (D, "gh pr merge -R nrslib/takt 12 --squash", "/w/mine", {}),
    (D, "gh pr merge --repo nrslib/takt 12", "/w/mine", {}),
    (D, "gh pr merge --repo=nrslib/takt 12", "/w/mine", {}),
    (D, "gh pr merge -Rnrslib/takt 12", "/w/mine", {}),
    (D, "gh pr merge 12 --repo github.com/nrslib/takt", "/w/mine", {}),
    (D, "gh pr merge https://github.com/nrslib/takt/pull/12", "/w/mine", {}),
    (
        D,
        "gh pr merge https://github.com/NRSLIB/takt/pull/12 --auto --squash",
        "/w/mine",
        {},
    ),
    (D, "gh pr merge 12 --admin -R nrslib/takt", "/w/mine", {}),
    (D, "gh pr merge 12 --auto", "/w/clone", {}),
    (D, "gh pr merge 12", "/w/takt-unresolved", {}),
    (D, "gh pr merge 12", "/w/mine", {"GH_REPO": "nrslib/takt"}),
    (D, "GH_REPO=nrslib/takt gh pr merge 12", "/w/mine", {}),
    (D, "env GH_REPO=nrslib/takt gh pr merge 12", "/w/mine", {}),
    (D, "export GH_REPO=nrslib/takt; gh pr merge 12", "/w/mine", {}),
    (D, "cd /w/clone && gh pr merge 12 -m", "/w/mine", {}),
    (D, "gh pr merge 12 -t 'subject' -b 'body' -R nrslib/takt", "/w/mine", {}),
    (D, "gh pr update-branch 12 -R nrslib/takt", "/w/mine", {}),
    (A, "gh pr merge 12", "/w/takt", {}),  # set-default が origin（j5ik2o/takt）
    (A, "gh pr merge 12 -R j5ik2o/takt --squash --auto", "/w/takt", {}),
    (A, "gh pr merge https://github.com/j5ik2o/takt/pull/3", "/w/clone", {}),
    (A, "gh pr merge 3 --squash", "/w/corp", {}),
    (A, "gh pr merge 3", "/w/mine", {}),
    # --- gh pr / issue の書き込み以外 ---------------------------------------
    (A, "gh pr create -R nrslib/takt --draft --title t --body b", "/w/takt", {}),
    (A, "gh pr comment 12 -R nrslib/takt --body 'thanks'", "/w/mine", {}),
    (A, "gh pr ready 12 -R nrslib/takt", "/w/mine", {}),
    (
        A,
        "gh pr view 12 -R nrslib/takt --json mergeable,mergeStateStatus",
        "/w/mine",
        {},
    ),
    (A, "gh pr checks 12 -R nrslib/takt", "/w/mine", {}),
    (A, "gh pr diff 12 -R nrslib/takt", "/w/mine", {}),
    (A, "gh pr review 12 -R nrslib/takt --approve", "/w/mine", {}),
    (A, "gh pr view 12", "/w/takt-unresolved", {}),
    (A, "gh issue create -R nrslib/takt --title t --body b", "/w/mine", {}),
    (A, "gh issue comment 5 -R nrslib/takt --body 'merge later'", "/w/mine", {}),
    (A, "gh repo view nrslib/takt", "/w/mine", {}),
    (A, "gh pr list -R nrslib/takt --search 'is:merged'", "/w/mine", {}),
    # --- gh api（REST） ----------------------------------------------------
    (D, "gh api -X PUT repos/nrslib/takt/pulls/12/merge", "/w/mine", {}),
    (
        D,
        "gh api --method PUT /repos/nrslib/takt/pulls/12/merge -f merge_method=squash",
        "/w/mine",
        {},
    ),
    (D, "gh api repos/nrslib/takt/merges -f base=main -f head=feat", "/w/mine", {}),
    (
        D,
        "gh api -X POST repos/nrslib/takt/git/refs -f ref=refs/heads/x -f sha=abc",
        "/w/mine",
        {},
    ),
    (
        D,
        "gh api -X PATCH repos/nrslib/takt/git/refs/heads/main -f sha=abc -F force=true",
        "/w/mine",
        {},
    ),
    (D, "gh api -X DELETE repos/nrslib/takt/git/refs/heads/feat", "/w/mine", {}),
    (
        D,
        "gh api -X PUT repos/nrslib/takt/contents/README.md -f message=m -f content=Y29udGVudA==",
        "/w/mine",
        {},
    ),
    (D, "gh api -XPUT repos/nrslib/takt/pulls/1/merge", "/w/mine", {}),
    (
        D,
        "gh api -X put https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        "/w/mine",
        {},
    ),
    (D, "gh api repos/nrslib/takt/releases -f tag_name=v1", "/w/mine", {}),
    (
        D,
        "gh api -X POST repos/nrslib/takt/merge-upstream -f branch=main",
        "/w/mine",
        {},
    ),
    (D, "gh api -X PUT 'repos/{owner}/{repo}/pulls/1/merge'", "/w/clone", {}),
    (W, "gh api -X PUT repos/$OWNER/takt/pulls/1/merge", "/w/mine", {}),
    (
        D,
        "gh api -X PUT repos/nrslib/takt/pulls/1/merge --input body.json",
        "/w/mine",
        {},
    ),
    (A, "gh api repos/nrslib/takt/pulls/12", "/w/mine", {}),
    (A, "gh api repos/nrslib/takt/contents/README.md", "/w/mine", {}),
    (A, "gh api -X GET repos/nrslib/takt/git/refs/heads/main", "/w/mine", {}),
    (
        A,
        "gh api repos/nrslib/takt/issues/5/comments -f body='push later'",
        "/w/mine",
        {},
    ),
    (A, "gh api -X PUT repos/j5ik2o/takt/pulls/12/merge", "/w/mine", {}),
    (
        A,
        "gh api -X POST repos/j5ik2o/takt/git/refs -f ref=refs/heads/x -f sha=abc",
        "/w/mine",
        {},
    ),
    (A, "gh api repos/nrslib/takt/pulls/1/reviews -f event=APPROVE", "/w/mine", {}),
    # --- gh api graphql ----------------------------------------------------
    (
        W,
        "gh api graphql -f query='mutation { enablePullRequestAutoMerge(input:{pullRequestId:\"PR_x\"}) { clientMutationId } }'",
        "/w/mine",
        {},
    ),
    (
        W,
        "gh api graphql -f query='mutation($id:ID!){ mergePullRequest(input:{pullRequestId:$id}){ clientMutationId } }' -f id=PR_x",
        "/w/mine",
        {},
    ),
    (
        W,
        "gh api graphql -f query='mutation { enqueuePullRequest(input:{pullRequestId:\"PR_x\"}) { clientMutationId } }'",
        "/w/mine",
        {},
    ),
    # 中身を読めないクエリは、コマンドの中に mutation の名前が無ければ通す（ボットのスレッドの解決を止めない）。
    # 読めるファイルの中に mutation があれば止める（Hook.test_graphql_query_file_is_read）
    (A, "gh api graphql -F query=@merge.graphql", "/w/mine", {}),
    (A, 'gh api graphql -f query="$(cat q.graphql)"', "/w/mine", {}),
    (W, 'gh api graphql -f query="$(echo mutation{mergePullRequest})"', "/w/mine", {}),
    (
        A,
        'gh api graphql -f query=\'{ repository(owner:"nrslib", name:"takt") { pullRequest(number:1) { mergeable } } }\'',
        "/w/mine",
        {},
    ),
    # --- gh repo sync / release / repo delete ------------------------------
    (D, "gh repo sync nrslib/takt", "/w/mine", {}),
    (D, "gh repo sync nrslib/takt --source j5ik2o/takt --force", "/w/mine", {}),
    (A, "gh repo sync j5ik2o/takt --source nrslib/takt", "/w/mine", {}),
    (A, "gh repo sync", "/w/takt", {}),
    (D, "gh release create v1.0.0 -R nrslib/takt --notes x", "/w/mine", {}),
    (D, "gh release upload v1 dist.tgz", "/w/clone", {}),
    (D, "gh release delete v1 -R nrslib/takt -y", "/w/mine", {}),
    (A, "gh release view v1 -R nrslib/takt", "/w/mine", {}),
    (A, "gh release create v1 -R j5ik2o/takt --notes x", "/w/mine", {}),
    (D, "gh repo delete nrslib/takt --yes", "/w/mine", {}),
    # --- git push ----------------------------------------------------------
    (
        D,
        "git push upstream main",
        "/w/takt",
        {},
    ),  # push の URL は DISABLED でも fetch が上流
    (D, "git push upstream HEAD:refs/heads/x --force", "/w/takt", {}),
    (D, "git push https://github.com/nrslib/takt.git main", "/w/mine", {}),
    (
        D,
        "git push https://x-access-token:abc@github.com/nrslib/takt main",
        "/w/mine",
        {},
    ),
    (D, "git push git@github.com:nrslib/takt.git HEAD", "/w/mine", {}),
    (D, "git push ssh://git@github.com/NrsLib/takt main", "/w/mine", {}),
    (D, "git push github.com:nrslib/takt main", "/w/mine", {}),
    (D, "git push", "/w/clone", {}),
    (D, "git push origin --tags", "/w/clone", {}),
    (D, "git push --mirror origin", "/w/clone", {}),
    (D, "git push --delete origin feat", "/w/clone", {}),
    (D, "git push origin", "/w/pushurl", {}),  # fetch は自分、push の URL だけ上流
    (D, "git push", "/w/pushdefault", {}),  # remote.pushDefault が上流
    (D, "git -C /w/takt push upstream main", "/w/mine", {}),
    (D, "git -C ../takt push upstream main", "/w/mine", {}),
    (D, "git -C /w -C takt push upstream", "/w/mine", {}),
    (D, "git --git-dir=/w/clone/.git push origin main", "/w/mine", {}),
    (D, "git --git-dir /w/clone/.git push", "/w/mine", {}),
    (D, "GIT_DIR=/w/clone/.git git push", "/w/mine", {}),
    (D, "cd /w/takt && git push upstream", "/w/mine", {}),
    (D, "cd ../takt; git push upstream", "/w/mine", {}),
    (D, "git push --repo=upstream", "/w/takt", {}),
    (D, "git push -o ci.skip upstream main", "/w/takt", {}),
    (
        D,
        "git -c remote.origin.pushurl=https://github.com/nrslib/takt push origin",
        "/w/mine",
        {},
    ),
    (D, "/usr/bin/git push upstream", "/w/takt", {}),
    (D, "command git push upstream", "/w/takt", {}),
    (D, r"\git push upstream", "/w/takt", {}),
    (D, "g\\it pu\\sh upstream", "/w/takt", {}),
    (D, "'git' 'push' \"upstream\"", "/w/takt", {}),
    (D, "git push $'\\x75pstream' main", "/w/takt", {}),
    (D, "git pu", "/w/alias", {}),  # git のエイリアス: pu = push upstream
    (D, "git sh", "/w/alias", {}),  # git のエイリアス: !git push upstream
    (D, "git -c alias.zz='push upstream' zz", "/w/takt", {}),
    (D, "git subtree push --prefix=docs upstream main", "/w/takt", {}),
    (D, "git send-pack https://github.com/nrslib/takt main", "/w/mine", {}),
    (D, "git-push upstream", "/w/takt", {}),
    (A, "git push origin main", "/w/takt", {}),
    (A, "git push", "/w/takt", {}),
    (A, "git push -u origin feat --force-with-lease", "/w/takt", {}),
    (A, "git push https://github.com/j5ik2o/takt.git main", "/w/clone", {}),
    (A, "git push", "/w/mine", {}),
    (A, "git push origin", "/w/corp", {}),
    (A, "git push ../backup main", "/w/clone", {}),
    (A, "git -C /w/mine push", "/w/clone", {}),
    (A, "git st", "/w/alias", {}),
    (A, "git fetch upstream", "/w/takt", {}),
    (A, "git pull upstream main", "/w/takt", {}),
    (A, "git log --oneline upstream/main", "/w/takt", {}),
    (A, "git remote -v", "/w/clone", {}),
    (
        A,
        "git merge upstream/main",
        "/w/takt",
        {},
    ),  # 手元のマージ（リポジトリには書かない）
    (A, "git commit -m 'push fix'", "/w/clone", {}),
    # --- 連結・入れ子 ------------------------------------------------------
    (D, "git status && git push upstream main", "/w/takt", {}),
    (D, "git status; git push upstream", "/w/takt", {}),
    (D, "git status || git push upstream", "/w/takt", {}),
    (D, "echo ok | git push upstream", "/w/takt", {}),
    (D, "(cd /w/takt && git push upstream)", "/w/mine", {}),
    (D, "{ git push upstream; }", "/w/takt", {}),
    (D, "bash -c 'git push upstream main'", "/w/takt", {}),
    (D, 'sh -c "gh pr merge 12 -R nrslib/takt"', "/w/mine", {}),
    (D, "zsh -lc 'cd /w/takt && git push upstream'", "/w/mine", {}),
    (D, "bash -c \"bash -c 'git push upstream'\"", "/w/takt", {}),
    (D, "env -i PATH=/usr/bin git push upstream", "/w/takt", {}),
    (D, "env -C /w/takt git push upstream", "/w/mine", {}),
    (D, "env -S 'git push upstream'", "/w/takt", {}),
    (D, "FOO=1 BAR=2 git push upstream", "/w/takt", {}),
    (D, "git status\ngit push upstream main\n", "/w/takt", {}),
    (D, "git status \\\n && git push upstream", "/w/takt", {}),
    (D, "echo $(git push upstream)", "/w/takt", {}),
    (D, "echo `gh pr merge 1 -R nrslib/takt`", "/w/mine", {}),
    (D, 'x="$(gh pr merge 1 -R nrslib/takt)"', "/w/mine", {}),
    (D, "eval 'git push upstream'", "/w/takt", {}),
    (D, "timeout 60 git push upstream", "/w/takt", {}),
    (D, "nohup git push upstream &", "/w/takt", {}),
    (D, "sudo -u me git push upstream", "/w/takt", {}),
    (D, "mise exec -- gh pr merge 1 -R nrslib/takt", "/w/mine", {}),
    (D, "if true; then git push upstream; fi", "/w/takt", {}),
    (D, "for i in 1; do git push upstream; done", "/w/takt", {}),
    (D, "bash <<'EOF'\ngit push upstream main\nEOF", "/w/takt", {}),
    (D, "bash <<< 'git push upstream'", "/w/takt", {}),
    (D, "echo 'git push upstream' | bash", "/w/takt", {}),
    (D, "find . -name x -exec git push upstream \\;", "/w/takt", {}),
    (D, "echo upstream | xargs git push", "/w/takt", {}),
    (D, "R=upstream; git push $R", "/w/takt", {}),
    (D, 'R=nrslib/takt; gh pr merge 1 -R "$R"', "/w/mine", {}),
    (D, "gh pr merge 1 -R ${REPO}", "/w/mine", {"REPO": "nrslib/takt"}),
    (A, "git status && git push origin main", "/w/takt", {}),
    (A, "(cd /w/clone && git status) && git push", "/w/mine", {}),
    (A, "bash -c 'gh pr view 1 -R nrslib/takt'", "/w/mine", {}),
    (A, "echo 'git push upstream'", "/w/takt", {}),
    (A, 'echo "gh pr merge 1 -R nrslib/takt" > notes.txt', "/w/mine", {}),
    (A, "grep -rn 'git push' docs/", "/w/takt", {}),
    (A, "cat <<'EOF' > memo.md\ngit push upstream\nEOF", "/w/takt", {}),
    (A, "ls -la && make test", "/w/mine", {}),
    # --- curl / 他の経路 ---------------------------------------------------
    (
        D,
        "curl -X PUT -H 'Authorization: token x' https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (
        D,
        'curl -sS -d \'{"ref":"refs/heads/x"}\' https://api.github.com/repos/nrslib/takt/git/refs',
        None,
        {},
    ),
    (
        D,
        "curl --request PATCH https://api.github.com/repos/nrslib/takt/git/refs/heads/main -d @b.json",
        None,
        {},
    ),
    (
        W,
        'curl -d \'{"query":"mutation{mergePullRequest(input:{pullRequestId:\\"x\\"}){clientMutationId}}"}\' https://api.github.com/graphql',
        None,
        {},
    ),
    (
        D,
        "curl -X POST https://github.com/nrslib/takt.git/git-receive-pack --data-binary @pack",
        None,
        {},
    ),
    (
        D,
        'python3 -c \'import subprocess; subprocess.run(["git","push","upstream"])\'',
        "/w/takt",
        {},
    ),
    (
        D,
        "node -e \"require('child_process').execSync('gh pr merge 1 -R nrslib/takt')\"",
        "/w/mine",
        {},
    ),
    (A, "curl -sS https://api.github.com/repos/nrslib/takt/pulls/1", None, {}),
    (A, "curl -X PUT https://api.github.com/repos/j5ik2o/takt/pulls/1/merge", None, {}),
    (A, "curl -sS https://example.com/upload -d x=1", None, {}),
    (A, "python3 -c 'print(1)'", "/w/mine", {}),
    (A, "python3 scripts/foo.py", "/w/mine", {}),
    # --- 解析できない・宛先を決められない ------------------------------------
    (D, "git push upstream 'main", "/w/takt", {}),  # 閉じていない引用符で push の気配
    (D, 'gh pr merge 1 -R "nrslib/takt', "/w/mine", {}),
    (A, "echo 'unterminated", "/w/mine", {}),  # 解析できないが push/merge でない
    (D, "git push $REMOTE main", "/w/takt", {}),  # 変数が決まらない
    (D, 'git push "$(git remote | head -1)"', "/w/takt", {}),
    (W, "$GIT push origin", "/w/mine", {}),  # 実行ファイルが決まらない
    (W, "gh pr merge 1 -R $R", "/w/mine", {}),
    (W, "gh pr merge 1", "/w/notrepo", {}),  # git の設定を読めない
    (W, "gh pr merge 1", None, {}),  # 作業ディレクトリが分からない
    (W, "git push", "/w/notrepo", {}),
    (W, "git push", "/w/nodefault", {}),  # 既定の push 先が決まらない
    (D, "git push nosuchremote main", "/w/takt", {}),
    (W, "git -C $DIR push", "/w/mine", {}),
    (W, "cd $DIR && git push", "/w/mine", {}),
    (D, "git $SUB upstream", "/w/takt", {}),
    (W, "gh $CMD merge 1", "/w/mine", {}),
    (W, "git --git-dir=/w/takt-unresolved/.git push", "/w/mine", {}),
    (A, "$EDITOR notes.txt", "/w/mine", {}),
    (A, "cd $DIR && ls", "/w/mine", {}),
    (A, "git status", "/w/notrepo", {}),
    (A, "", "/w/mine", {}),
    # --- 独立レビューで見つかったすり抜け ------------------------------------
    (D, "gh pr merge feature/foo", "/w/clone", {}),  # ブランチ名の / は宛先ではない
    (D, "gh pr update-branch fix/x", "/w/clone", {}),
    (
        D,
        "git remote set-url origin https://github.com/nrslib/takt && git push origin",
        "/w/mine",
        {},
    ),
    (D, "git config remote.pushDefault upstream && git push", "/w/takt-unresolved", {}),
    (D, "gh repo set-default nrslib/takt && gh pr merge 1", "/w/takt", {}),
    (
        D,
        "git config alias.pp 'push https://github.com/nrslib/takt' && git pp",
        "/w/mine",
        {},
    ),
    (D, "git -c remote.pushDefault=upstream push", "/w/takt-unresolved", {}),
    (D, "git -c branch.main.pushRemote=upstream push", "/w/takt-unresolved", {}),
    (W, 'git -c "remote.origin.pushurl=$U" push origin', "/w/mine", {}),
    (
        D,
        "git -c url.https://github.com/nrslib/.insteadOf=https://github.com/j5ik2o/ push https://github.com/j5ik2o/takt",
        "/w/mine",
        {},
    ),
    (
        D,
        "PU=https://github.com/nrslib/takt git --config-env=remote.origin.pushurl=PU push origin",
        "/w/mine",
        {},
    ),
    (
        W,
        "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.pushurl GIT_CONFIG_VALUE_0=x git push origin",
        "/w/mine",
        {},
    ),
    (D, "git push https://github.com/j5ik2o/../nrslib/takt", "/w/mine", {}),
    (D, "git push https://github.com/%6Erslib/takt", "/w/mine", {}),
    (D, "cd /w/mine | true; git push origin", "/w/clone", {}),
    (D, "cd /w/mine &\ngit push origin", "/w/clone", {}),
    (D, "gh -R nrslib/takt pr merge 1", "/w/mine", {}),
    (D, "gh --repo nrslib/takt pr merge 1", "/w/mine", {}),
    (D, "gh -R nrslib/takt release create v1", "/w/mine", {}),
    (D, "curl -sXPUT https://api.github.com/repos/nrslib/takt/pulls/1/merge", None, {}),
    (
        D,
        "curl -sX PUT https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (D, "curl -X PUT https://API.GITHUB.COM/repos/nrslib/takt/pulls/1/merge", None, {}),
    (D, "curl -X PUT HTTPS://api.github.com/repos/nrslib/takt/pulls/1/merge", None, {}),
    (
        D,
        "curl -X PUT https://x:tok@api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (
        D,
        "curl -X PUT https://api.github.com/repos/j5ik2o/x/../../nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (
        D,
        "curl -X POST -T a.zip 'https://uploads.github.com/repos/nrslib/takt/releases/1/assets?name=a.zip'",
        None,
        {},
    ),
    (D, "env --chdir=/w/clone git push origin", "/w/mine", {}),
    (D, "function f { git push origin; }; f", "/w/clone", {}),
    (D, "coproc git push origin", "/w/clone", {}),
    (D, "trap 'git push origin' EXIT", "/w/clone", {}),
    (D, "bash -c -- 'git push origin'", "/w/clone", {}),
    (D, "$(echo git push origin)", "/w/clone", {}),
    (D, "X=$(echo git push origin); $X", "/w/clone", {}),
    (D, "cat <<EOF\n$(git push origin)\nEOF", "/w/clone", {}),
    (D, "echo $(( $(git push origin) ))", "/w/clone", {}),
    (D, "echo ${u:-$(git push origin)}", "/w/clone", {}),
    (W, "git push https://github.com/nrsli{b..b}/takt", "/w/mine", {}),
    (W, "gh pr merge 1 -R nrsli{b..b}/takt", "/w/mine", {}),
    (D, "gh pr merge 1 -R{x,nrslib}/takt", "/w/mine", {}),
    (D, "R=nrs; R+=lib/takt; gh pr merge 1 -R $R", "/w/mine", {}),
    (D, "export GH_REPO=nrs; GH_REPO+=lib/takt; gh pr merge 1", "/w/mine", {}),
    (D, "export GIT_DIR=/w/clone/.git; git push origin", "/w/mine", {}),
    (D, "hub api -X PUT repos/nrslib/takt/pulls/1/merge", "/w/mine", {}),
    (W, "gh api -X PUT repositories/123456/pulls/1/merge", "/w/mine", {}),
    (D, "gh api -X PUT repos/nrslib/takt/pulls/1/%6Derge", "/w/mine", {}),
    (D, "uv run gh pr merge 1 -R nrslib/takt", "/w/mine", {}),
    (D, "nix develop -c gh pr merge 1 -R nrslib/takt", "/w/mine", {}),
    (D, "mise exec -c 'gh pr merge 1 -R nrslib/takt'", "/w/mine", {}),
    (D, "awk 'BEGIN{system(\"gh pr merge 1 -R nrslib/takt\")}'", "/w/mine", {}),
    (D, "parallel gh pr merge ::: 1 2 -R nrslib/takt", "/w/mine", {}),
    # --- orca の本文の引数（2026-11-25 の誤った拒否の 2 件目） ------------------
    (
        A,
        'cd /w/mine && "${ORCA_CLI_COMMAND:-orca}" bot item comment 264 --text "マージと push は止めた。nrslib 宛ての git push upstream と gh pr merge -R nrslib/takt は拒否。dotfiles にブランチができた" 2>&1 | tail -1',
        "/w/home",
        {},
    ),
    (
        A,
        '"${ORCA_CLI_COMMAND:-orca}" bot item comment 264 --text "push merge マージ nrslib git push upstream gh pr merge -R nrslib/takt"',
        "/w/mine",
        {},
    ),
    (
        A,
        'orca bot item comment 264 --text "push merge マージ nrslib git push upstream gh pr merge -R nrslib/takt" 2>&1 | tail -1',
        "/w/mine",
        {},
    ),
    (
        A,
        'cd /w/mine && orca orchestration send --from s --type status --subject "merge と push の件" --body "git push upstream と gh pr merge -R nrslib/takt は使わない" 2>&1 | tail -1',
        "/w/mine",
        {},
    ),
    (
        A,
        '"${ORCA_CLI_COMMAND:-orca}" orchestration send --to x --subject "push の件" --body "nrslib へ git push しない"',
        "/w/mine",
        {},
    ),
    (
        A,
        'orca orchestration reply --id m1 --body "gh pr merge -R nrslib/takt はマージしない。push もしない"',
        "/w/mine",
        {},
    ),
    (
        A,
        '"${ORCA_CLI_COMMAND:-orca}" orchestration reply --id m1 --body "git push upstream main は拒否された" 2>&1 | tail -1',
        "/w/mine",
        {},
    ),
    (
        A,
        'orca bot reply --text "マージと push は上流のメンテナが行う。nrslib/takt の gh pr merge は使わない"',
        "/w/mine",
        {},
    ),
    (
        A,
        'cd /w/mine && "${ORCA_CLI_COMMAND:-orca}" bot reply --text "git push upstream / gh pr merge -R nrslib/takt" 2>&1 | tail -1',
        "/w/mine",
        {},
    ),
    (A, '"$ORCA_CLI_COMMAND" bot item comment 1 --text "push と merge"', "/w/mine", {}),
    (
        D,
        '"${GIT:-git}" push https://github.com/nrslib/takt main',
        "/w/mine",
        {},
    ),  # 名前は変数でも、語の位置が push
    (D, "$GH pr merge 1 -R nrslib/takt", "/w/mine", {}),
    # --- 文やデータに語句があるだけのものは通す（2026-11-25 の誤った拒否） -----
    (
        A,
        "python3 - <<'EOF'\nfrom pathlib import Path\np = Path('MEMORY.md')\np.write_text(p.read_text() + '- 事故: git push が走った。nrslib 宛てのマージと push を実行前に拒否する（gh pr merge は使わない）\\n')\nEOF",
        "/w/mine",
        {},
    ),
    (
        A,
        "python3 -c \"open('memo.md','a').write('nrslib/takt へ git push しない。gh pr merge -R nrslib/takt も使わない')\"",
        "/w/mine",
        {},
    ),
    (
        A,
        "node -e \"require('fs').appendFileSync('m.md', 'git push upstream と gh pr merge は nrslib 宛てに使わない')\"",
        "/w/mine",
        {},
    ),
    (
        A,
        "orca orchestration send --to x --subject 'merge の件' --body '… gh pr merge は使わない。nrslib/takt へ git push しない …'",
        "/w/mine",
        {},
    ),
    (
        A,
        "gh issue comment 5 -R j5ik2o/takt --body 'nrslib/takt へ git push しない'",
        "/w/mine",
        {},
    ),
    (A, "git commit -m 'docs: git push upstream を禁止（nrslib）'", "/w/takt", {}),
    (
        A,
        "cat > notes.md <<'EOF'\ngh pr merge -R nrslib/takt 12\ngit push upstream main\nEOF",
        "/w/takt",
        {},
    ),
    (A, "tee notes.md <<'EOF'\ngh pr merge -R nrslib/takt 12\nEOF", "/w/takt", {}),
    (A, "echo 'gh pr merge -R nrslib/takt 12' >> notes.md", "/w/mine", {}),
    (
        A,
        "printf '%s\\n' 'git push https://github.com/nrslib/takt main' > notes.md",
        "/w/mine",
        {},
    ),
    (A, "awk '{print \"git push nrslib\"}' notes.md", "/w/mine", {}),
    (A, "sed -i 's/gh pr merge/gh pr view/' notes.md", "/w/mine", {}),
    (
        D,
        "python3 -c \"import subprocess; subprocess.run(['gh','pr','merge','1','-R','nrslib/takt'])\"",
        "/w/mine",
        {},
    ),
    (
        D,
        "node -e \"require('child_process').execSync('git push https://github.com/nrslib/takt.git main')\"",
        "/w/mine",
        {},
    ),
    (
        D,
        "python3 - <<'EOF'\nimport os\nos.system('gh pr merge 1 -R nrslib/takt')\nEOF",
        "/w/mine",
        {},
    ),
    (
        D,
        "python3 -c \"import requests; requests.put('https://api.github.com/repos/nrslib/takt/pulls/1/merge')\"",
        None,
        {},
    ),
    (D, "ruby -e 'system(\"git push upstream\")'", "/w/takt", {}),
    (
        D,
        "bash -c 'gh pr merge 1 -R nrslib/takt'",
        "/w/mine",
        {},
    ),  # 文字列を実行する形は中を見る
    (D, 'eval "gh pr merge 1 -R nrslib/takt"', "/w/mine", {}),
    (D, "echo 1 | xargs gh pr merge -R nrslib/takt", "/w/mine", {}),
    (
        D,
        "awk 'BEGIN{system(\"git push https://github.com/nrslib/takt\")}'",
        "/w/mine",
        {},
    ),
    (D, "cd /w/mine; cd -; git push origin", "/w/clone", {}),
    # 二重引用符の中のバッククォートは、シェルが先に実行する
    (
        D,
        "node -e \"require('fs').writeFileSync('d.md', '`git push upstream` は使わない')\"",
        "/w/takt",
        {},
    ),
    # Markdown のバッククォートを含む文を python で書く（2026-11-25 の誤った拒否の 3 件目）
    (
        A,
        "python3 - <<'PYEOF'\nopen('d.md','a').write('- `git push \"$REMOTE\"` と `gh pr merge -R nrslib/takt` は止める\\n')\nPYEOF",
        "/w/mine",
        {},
    ),
    (
        A,
        # 単一引用符の中なので、シェルはバッククォートを実行しない
        'node -e \'require("fs").writeFileSync("d.md", "`git push upstream` は使わない")\'',
        "/w/mine",
        {},
    ),
    (D, "ruby -e 'puts `git push https://github.com/nrslib/takt`'", "/w/mine", {}),
    (D, "perl -e 'print `gh pr merge 1 -R nrslib/takt`'", "/w/mine", {}),
    # ヒアドキュメントの本文に区切りの行が入っていると、そこで閉じて残りの行がコマンドになる
    # （2026-11-25 の独立レビューで、試験の入力をこの形でシェルに渡して git push が走った）
    (
        D,
        "cat > cases.txt <<'EOF'\nfirst line\nEOF\ngit push origin\nEOF",
        "/w/clone",
        {},
    ),
    (
        D,
        "cat > cases.txt <<'EOF'\n(D, \"x\")\nEOF\n$(git push origin)\n(( 1 +\nEOF",
        "/w/clone",
        {},
    ),
    (
        A,
        "cat > cases.txt <<'EOF'\ngit push origin\n$(git push origin)\nEOF",
        "/w/clone",
        {},
    ),
    (
        A,
        "cat > cases.txt <<'END'\nEOF\ngit push origin\nEND\necho done",
        "/w/clone",
        {},
    ),
    (D, "diff <(git push origin) x", "/w/clone", {}),  # プロセス置換の中も実行される
    (A, "diff <(head -2 a.txt) b.txt && echo merge-ok", "/w/clone", {}),
    # --- 独立レビューで見つかった誤った拒否（通す） --------------------------
    (
        A,
        "git commit -m \"$(cat <<'EOF'\nfix(x): don't drop it\nEOF\n)\" && git push origin HEAD",
        "/w/mine",
        {},
    ),
    (
        A,
        "gh pr create --body \"$(cat <<'EOF'\nIt's fine\nEOF\n)\" && gh pr merge --auto 3",
        "/w/mine",
        {},
    ),
    (
        A,
        "gh pr view 5 -R nrslib/takt --json mergeable,title | python3 -c 'import json,sys; print(1)'",
        "/w/mine",
        {},
    ),
    (
        A,
        "gh api repos/nrslib/takt/contents/README.md | python3 -c 'print(1)'",
        "/w/mine",
        {},
    ),
    (A, "gh release view -R nrslib/takt v1 | python3 -c 'print(1)'", "/w/mine", {}),
    (A, "gh pr merge feature/foo", "/w/mine", {}),
    (A, "git config --get remote.origin.url && git push origin", "/w/mine", {}),
    # --- PR #229 のレビューの指摘（入力は指摘のまま） ------------------------
    # B-1: gh repo rename の引数は新しい名前で、宛先は -R か既定のリポジトリ
    (A, "gh repo rename nrslib-fork", "/w/mine", {}),
    (A, "gh repo rename takt2 -R j5ik2o/takt", "/w/clone", {}),
    (D, "gh repo rename x -R nrslib/takt", "/w/mine", {}),
    (D, "gh repo rename x", "/w/clone", {}),
    # B-2: HEAD は読み取り
    (A, "gh api --method HEAD repos/nrslib/takt/contents/README.md", "/w/mine", {}),
    (A, "gh api -X HEAD repos/nrslib/takt/pulls/1/merge", "/w/mine", {}),
    # A-1: eval は同じシェルの cd を引き継ぐ。bash -c は引き継がない
    (D, "eval 'cd /w/clone'; git push origin", "/w/mine", {}),
    (D, "eval cd /w/clone && git push origin", "/w/mine", {}),
    (A, "bash -c 'cd /w/clone'; git push origin", "/w/mine", {}),
    # A-2: 引用されていない変数の展開は、コマンドの位置で単語に分かれる
    (D, "X='git push origin'; $X", "/w/clone", {}),
    (D, "P='gh pr merge'; $P 1 -R nrslib/takt", "/w/mine", {}),
    (A, "X='echo hi'; $X", "/w/clone", {}),
    (A, 'X="git push origin"; echo "$X"', "/w/clone", {}),
    (A, "X='git push origin'; $X", "/w/mine", {}),
    # A-3: env -u と env -i で消した環境変数は、判定でも消す
    (D, "env -u GH_REPO gh pr merge 1", "/w/clone", {"GH_REPO": "j5ik2o/x"}),
    (D, "env -i gh pr merge 1", "/w/clone", {"GH_REPO": "j5ik2o/x"}),
    (D, "env -u GIT_DIR git push", "/w/clone", {"GIT_DIR": "/w/mine/.git"}),
    (A, "git push", "/w/clone", {"GIT_DIR": "/w/mine/.git"}),
    # A-4: curl の -O は値を取らない
    (
        D,
        "curl -X PUT -O https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    # A-5: {owner} と {repo} は片方ずつ置き換える
    (D, "gh api -X PUT repos/nrslib/{repo}/pulls/1/merge", "/w/mine", {}),
    (A, "gh api -X PUT repos/j5ik2o/{repo}/pulls/1/merge", "/w/clone", {}),
    # A-6: gh は :owner と :repo も置き換える（gh 2.105.0 の正規表現で確認）
    (D, "gh api -X PUT repos/:owner/:repo/pulls/1/merge", "/w/clone", {}),
    (D, "gh api -X PUT repos/nrslib/:repo/pulls/1/merge", "/w/mine", {}),
    (A, "gh api -X PUT repos/j5ik2o/:repo/pulls/1/merge", "/w/clone", {}),
    # A-7: -R と --repo が両方あれば、どれか 1 つでも禁止の宛先なら止める
    (D, "gh pr merge 1 --repo nrslib/takt -R j5ik2o/takt", "/w/mine", {}),
    (D, "gh pr merge 1 -R nrslib/takt -R j5ik2o/takt", "/w/mine", {}),
    # A-8: curl --next は転送ごとにメソッドと本文を分ける
    (
        D,
        "curl -X GET https://api.github.com/repos/nrslib/takt --next -d x https://api.github.com/repos/nrslib/takt/git/refs",
        None,
        {},
    ),
    (
        A,
        "curl -X PUT https://api.github.com/repos/j5ik2o/x/pulls/1/merge --next https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    # A-9: 相対の --git-dir と GIT_DIR は、-C の後の場所で解決する
    (D, "git --git-dir=.git -C /w/clone push origin", "/w/mine", {}),
    (D, "GIT_DIR=.git git -C /w/clone push origin", "/w/mine", {}),
    (D, "git -C /w/clone --git-dir=.git push origin", "/w/mine", {}),
    # A-10: busybox sh -c の中も見る
    (D, "busybox sh -c 'git push origin'", "/w/clone", {}),
    (A, "busybox sh -c 'git push origin'", "/w/mine", {}),
    # A-11: ヒアドキュメントが 2 つあると、シェルが読むのは最後
    (D, "bash <<'A' <<'B'\nls\nA\ngit push origin\nB", "/w/clone", {}),
    (A, "bash <<'A' <<'B'\ngit push origin\nA\nls\nB", "/w/clone", {}),
    # F-1、F-2: 2026-11-25 11:04 の誤った拒否（ほかのボットのレビューへの返信と解決）
    (
        A,
        "for id in 1 2; do gh api -X POST repos/j5ik2o/takt/pulls/1025/comments/$id/replies -F body=@$d/$id --jq .id; done",
        "/w/mine",
        {},
    ),
    (
        D,
        "for n in 1; do gh api -X PUT repos/nrslib/takt/pulls/$n/merge; done",
        "/w/mine",
        {},
    ),
    (W, "gh api -X PUT repos/$O/takt/pulls/1/merge", "/w/mine", {}),
    (
        A,
        'q=$(python3 -c "print(\'mutation{r0: resolveReviewThread(input:{threadId:\\"T\\"}){thread{isResolved}}}\')"); gh api graphql -f query="$q"',
        "/w/mine",
        {},
    ),
    (
        A,
        "python3 -c \"open('/tmp/r.graphql','w').write('mutation{resolveReviewThread(input:{threadId:1}){thread{isResolved}}}')\"; gh api graphql -F query=@/tmp/r.graphql --jq '[.data[]] | length'",
        "/w/mine",
        {},
    ),
    (
        W,
        'q=$(python3 -c "print(\'mutation{mergePullRequest(input:{pullRequestId:1}){clientMutationId}}\')"); gh api graphql -f query="$q"',
        "/w/mine",
        {},
    ),
    (
        W,
        "python3 -c \"open('/tmp/m.graphql','w').write('mutation{enablePullRequestAutoMerge(input:{pullRequestId:1}){clientMutationId}}')\"; gh api graphql -F query=@/tmp/m.graphql",
        "/w/mine",
        {},
    ),
    # --- 宛先を判定できないときの倒し方（2026-11-25 元帥の判断） ----------------
    # 禁止の宛先の語が、コマンド・作業ディレクトリの remote・GH_ と GIT_ の環境変数のどこにも無ければ、警告して通す
    (W, 'cd "$WT" && git push origin HEAD', "/w/mine", {}),
    (W, 'git push "$REMOTE" HEAD', "/w/mine", {}),
    (W, "for r in a b; do git push $r; done", "/w/mine", {}),
    (
        W,
        "git push",
        "/w/notrepo",
        {},
    ),  # リポジトリでない場所（どのみち git が失敗する）
    (W, "gh pr merge 3 --squash", "/w/notrepo", {}),
    (
        W,
        "gh api graphql -f query='mutation{mergePullRequest(input:{pullRequestId:\"PR_kwDO1\"}){clientMutationId}}'",
        "/w/mine",
        {},
    ),
    (
        W,
        'gh api graphql -f query=\'mutation{updateRef(input:{refId:"REF_1",oid:"abc"}){clientMutationId}}\'',
        "/w/corp",
        {},
    ),
    # 中身の見えないクエリで、マージや ref の mutation の名前も無いものは、これまでどおり通す（スレッドの解決など）
    (A, 'gh api graphql -F query=@"$Q"', "/w/mine", {}),
    # 禁止の宛先の語がどこかにあれば、これまでどおり拒否する
    (
        D,
        "gh pr merge 1 -R $R",
        "/w/mine",
        {"GH_REPO": "nrslib/takt"},
    ),  # 変数の宛先＋ GH_REPO に nrslib
    (D, 'cd "$WT" && gh pr merge 3', "/w/mine", {"GH_REPO": "NRSLIB/takt"}),
    (
        D,
        "git push",
        "/w/up-nodefault",
        {},
    ),  # remote に nrslib がある場所での宛先なしの push
    (D, 'git push "$R" main', "/w/takt", {}),  # takt の upstream は nrslib
    (
        D,
        'gh api graphql -f query=\'query{repository(owner:"nrslib",name:"takt"){id}} mutation{mergePullRequest(input:{pullRequestId:"x"}){clientMutationId}}\'',
        "/w/mine",
        {},
    ),
    (D, "git push $(echo https://github.com/nrslib/takt) main", "/w/mine", {}),
    (D, 'U=https://github.com/NRSLIB/takt; git push "$U"', "/w/mine", {}),
    (
        D,
        "git push $R; git -C /w/clone push origin",
        "/w/mine",
        {},
    ),  # 決まらない拒否の後ろの、決まった拒否を見逃さない
    # --- PR #229 の 2 回目のレビューの指摘（入力は指摘のまま） ----------------
    # E-7: unset で消した変数は、後ろのコマンドの判定でも消す
    (D, "unset GH_REPO; gh pr merge 12", "/w/clone", {"GH_REPO": "j5ik2o/takt"}),
    (D, "unset -v GH_REPO; gh pr merge 12", "/w/clone", {"GH_REPO": "j5ik2o/takt"}),
    (A, "unset FOO; gh pr merge 12", "/w/clone", {"GH_REPO": "j5ik2o/takt"}),
    # E-9: シェル形式の git のエイリアスは、-C で選んだ場所で判定する
    (D, "git -C /w/clone -c 'alias.ship=!git push origin' ship", "/w/takt", {}),
    (A, "git -C /w/mine -c 'alias.ship=!git push origin' ship", "/w/clone", {}),
    # E-5: 値の決まらない -X は、GET とみなさない
    (
        D,
        'curl -X "$(cat method.txt)" https://api.github.com/repos/nrslib/takt/pulls/12/merge',
        None,
        {},
    ),
    (
        A,
        'curl -X "$(cat method.txt)" https://api.github.com/repos/j5ik2o/takt/pulls/12',
        None,
        {},
    ),
    (A, "curl -sS https://api.github.com/repos/j5ik2o/takt/pulls/12", None, {}),
    # E-4: wget の --post-file と --body-file は本文の指定
    (
        D,
        "wget --post-file=payload.json --header=Content-Type:application/json https://api.github.com/repos/nrslib/takt/git/refs",
        None,
        {},
    ),
    (
        D,
        "wget --post-file payload.json https://api.github.com/repos/nrslib/takt/git/refs",
        None,
        {},
    ),
    (
        D,
        "wget --method=PUT --body-file=b.json https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    (
        A,
        "wget --post-file=payload.json https://api.github.com/repos/j5ik2o/takt/git/refs",
        None,
        {},
    ),
    # E-3: xargs の、値を取る長い形式のオプション
    (D, "printf main | xargs --max-args 1 git push upstream", "/w/takt", {}),
    (
        D,
        "printf main | xargs --max-procs 2 --delimiter , git push upstream",
        "/w/takt",
        {},
    ),
    (A, "printf main | xargs --max-args 1 git push origin", "/w/takt", {}),
    # --- PR #229 の 3 回目のレビューの指摘（入力は指摘のまま） ----------------
    # A-2: push 先に効かない git config の後の push は止めない
    (A, "git config user.name Bot; git push origin", "/w/takt", {}),
    (
        A,
        "git config --global user.email bot@example.com && git push origin main",
        "/w/takt",
        {},
    ),
    (
        D,
        "git config remote.origin.url https://github.com/x/y; git push origin",
        "/w/takt",
        {},
    ),
    (D, "git config $KEY x; git push origin", "/w/takt", {}),
    # A-3: curl -G／--get は、本文の指定があっても GET
    (
        A,
        "curl -G --data-urlencode 'ref=main' https://api.github.com/repos/nrslib/takt/contents/README.md",
        None,
        {},
    ),
    (
        A,
        "curl --get --data-urlencode 'ref=main' https://api.github.com/repos/nrslib/takt/contents/README.md",
        None,
        {},
    ),
    (
        A,
        "curl -sG -d per_page=100 https://api.github.com/repos/nrslib/takt/git/refs",
        None,
        {},
    ),
    (
        D,
        "curl -G -X PUT https://api.github.com/repos/nrslib/takt/pulls/1/merge",
        None,
        {},
    ),
    # E-6: curl の URL の glob は展開しない。書き込みなら宛先を決められないものとして扱う
    (
        D,
        "curl -X POST 'https://api.github.com/repos/{j5ik2o,nrslib}/takt/git/refs' -d @payload.json",
        None,
        {},
    ),
    (
        W,
        "curl -X POST 'https://api.github.com/repos/j5ik2o/takt[1-3]/git/refs' -d @payload.json",
        None,
        {},
    ),
    (
        A,
        "curl -g -X POST 'https://api.github.com/repos/j5ik2o/takt/git/refs?x={a}' -d @p.json",
        None,
        {},
    ),
    (A, "curl 'https://api.github.com/repos/{j5ik2o,nrslib}/takt/pulls'", None, {}),
    # E-10: find の -execdir と -okdir は、一致した場所で実行される（作業場所は決まらない）
    (
        D,
        "find /w -name .git -type d -execdir git push origin ';'",
        "/w/takt",
        {},
    ),  # takt に nrslib の remote
    (W, "find /w -name .git -type d -execdir git push origin ';'", "/w/mine", {}),
    (A, "find . -name '*.md' -execdir grep -l push {} +", "/w/mine", {}),
    # D-3: 拒否の例と同じ起動の形で、宛先だけが禁止でないもの
    (
        A,
        "python3 -c \"import subprocess; subprocess.run(['gh','pr','merge','1','-R','j5ik2o/takt'])\"",
        "/w/mine",
        {},
    ),
    (
        A,
        "node -e \"require('child_process').execSync('git push https://github.com/j5ik2o/takt.git main')\"",
        "/w/mine",
        {},
    ),
]


class DecideTable(unittest.TestCase):
    def test_table(self):
        failures = []
        for expected, command, cwd, extra in CASES:
            verdict = ug.decide(
                command, cwd, {**ENV, **extra}, ("nrslib",), Repos(REPOS)
            )
            got = verdict.kind
            if got != expected:
                failures.append(
                    f"{expected} を期待して {got}: {command!r} (cwd={cwd})\n    {verdict.reason}"
                )
            if got == W and (not verdict.warning or "\n" in verdict.warning):
                failures.append(
                    f"警告の形が違う（1 行で書く）: {command!r}: {verdict.warning!r}"
                )
            if not verdict.allowed:
                lines = verdict.reason.splitlines()
                if not (1 <= len(lines) <= 3) or "副元帥" not in verdict.reason:
                    failures.append(
                        f"拒否のメッセージの形が違う: {command!r}: {verdict.reason!r}"
                    )
        self.assertEqual(failures, [], "\n".join(failures))


class Blocked(unittest.TestCase):
    def test_owner_and_repo_entries_ignore_case(self):
        self.assertEqual(ug.blocked_entry("nrslib/takt", ("NRSLIB",)), "NRSLIB")
        self.assertEqual(
            ug.blocked_entry("j5ik2o/ci-gate-sandbox", ("j5ik2o/CI-Gate-Sandbox",)),
            "j5ik2o/CI-Gate-Sandbox",
        )
        self.assertIsNone(ug.blocked_entry("j5ik2o/takt", ("j5ik2o/ci-gate-sandbox",)))

    def test_repo_entry_blocks_only_that_repo(self):
        repos = Repos(REPOS)
        blocked = ("nrslib", "j5ik2o/ci-gate-sandbox")
        self.assertFalse(
            ug.decide(
                "gh pr merge 1 -R j5ik2o/ci-gate-sandbox",
                "/w/mine",
                ENV,
                blocked,
                repos,
            ).allowed
        )
        self.assertTrue(
            ug.decide(
                "gh pr merge 1 -R j5ik2o/takt", "/w/mine", ENV, blocked, repos
            ).allowed
        )

    def test_opaque_code_matches_whole_repo_entry(self):
        blocked = ("nrslib", "j5ik2o/ci-gate-sandbox")
        code = "python3 -c 'print(\"/Users/j5ik2o/x: push の判定\")'"
        self.assertTrue(ug.decide(code, "/w/mine", ENV, blocked, Repos(REPOS)).allowed)
        code = 'python3 -c \'subprocess.run("j5ik2o/ci-gate-sandbox", "push")\''
        self.assertFalse(ug.decide(code, "/w/mine", ENV, blocked, Repos(REPOS)).allowed)

    def test_overrides_only_add(self, tmp_home="/nonexistent-home"):
        self.assertEqual(ug.load_blocked({}, tmp_home), ("nrslib",))
        added = ug.load_blocked(
            {ug.EXTRA_BLOCKED_ENV: "j5ik2o/ci-gate-sandbox, foo"}, tmp_home
        )
        self.assertEqual(added, ("nrslib", "j5ik2o/ci-gate-sandbox", "foo"))
        self.assertIn("nrslib", ug.load_blocked({ug.EXTRA_BLOCKED_ENV: ""}, tmp_home))
        self.assertIn(
            "nrslib",
            ug.load_blocked({ug.EXTRA_BLOCKED_ENV: "-nrslib !nrslib"}, tmp_home),
        )


class Hook(unittest.TestCase):
    def payload(self, command, cwd="/nonexistent"):
        return json.dumps(
            {"tool_name": "Bash", "tool_input": {"command": command}, "cwd": cwd}
        )

    def test_does_nothing_outside_orca_sessions(self):
        code, msg = ug.hook_main(
            self.payload("git push https://github.com/nrslib/takt main"), {"HOME": "/x"}
        )
        self.assertEqual((code, msg), (0, ""))

    def test_blocks_in_orca_sessions(self):
        env = {"HOME": "/x", "ORCA_AGENT_SESSION_ID": "s"}
        code, msg = ug.hook_main(
            self.payload("git push https://github.com/nrslib/takt main"), env
        )
        self.assertEqual(code, 2)
        self.assertIn("nrslib/takt", msg)

    def test_monitor_commands_are_checked(self):
        env = {"HOME": "/x", "ORCA_AGENT_SESSION_ID": "s"}
        payload = json.dumps(
            {
                "tool_name": "Monitor",
                "tool_input": {"command": "git push git@github.com:nrslib/t"},
            }
        )
        self.assertEqual(ug.hook_main(payload, env)[0], 2)

    def test_other_tools_pass(self):
        env = {"HOME": "/x", "ORCA_AGENT_SESSION_ID": "s"}
        payload = json.dumps({"tool_name": "Read", "tool_input": {"file_path": "/x"}})
        self.assertEqual(ug.hook_main(payload, env), (0, ""))

    def run_wrapper(self, target: str, env: dict[str, str]):
        import subprocess

        cmd = ug.HOOK_COMMAND.replace(ug.HOOK_BIN, target)
        return subprocess.run(
            ["sh", "-c", cmd],
            input=self.payload("ls"),
            capture_output=True,
            text=True,
            env={"PATH": "/usr/bin:/bin", **env},
            check=False,
        )

    def test_wrapper_warns_without_blocking_when_binary_is_missing_or_broken(self):
        import tempfile

        tmp = tempfile.mkdtemp()
        broken = os.path.join(tmp, "broken")
        with open(broken, "w") as f:
            f.write("#!/bin/sh\nexit 1\n")
        os.chmod(broken, 0o755)
        dangling = os.path.join(tmp, "dangling")
        os.symlink(os.path.join(tmp, "gone"), dangling)
        # 無いときと、0・2 以外で終わったとき（終了コードつき）は、別の文にする
        for target, expected in (
            (os.path.join(tmp, "missing"), "実行ファイルが無いため"),
            (dangling, "実行ファイルが無いため"),
            (broken, "判定が終了コード 1 で失敗したため"),
        ):
            r = self.run_wrapper(target, {"ORCA_AGENT_SESSION_ID": "s"})
            self.assertEqual(r.returncode, 0, target)
            out = json.loads(r.stdout)
            context = out["hookSpecificOutput"]["additionalContext"]
            self.assertIn(expected, context)
            self.assertIn(expected, out["systemMessage"])
            self.assertIn("判定をしていません", context)
            owner = self.run_wrapper(target, {})
            self.assertEqual((owner.returncode, owner.stdout), (0, ""))

    def test_wrapper_passes_through_the_verdict(self):
        import tempfile

        tmp = tempfile.mkdtemp()
        deny = os.path.join(tmp, "deny")
        with open(deny, "w") as f:
            f.write("#!/bin/sh\necho stopped >&2\nexit 2\n")
        os.chmod(deny, 0o755)
        r = self.run_wrapper(deny, {"ORCA_AGENT_SESSION_ID": "s"})
        self.assertEqual((r.returncode, r.stderr.strip()), (2, "stopped"))

    def test_internal_error_fails_closed_for_push(self):
        self.assertFalse(ug._fallback("git push upstream").allowed)
        self.assertTrue(ug._fallback("ls -la").allowed)

    def test_graphql_query_file_is_read(self):
        # F-2 と、宛先を判定できないときの倒し方: 読めるクエリのファイルにマージの mutation があり、
        # 禁止の宛先の語もあれば止める。語が無ければ警告して通す
        files = {
            "/w/mine/merge.graphql": "mutation{mergePullRequest(input:{pullRequestId:1}){clientMutationId}}",
            "/w/mine/up.graphql": 'query{repository(owner:"NRSLIB",name:"takt"){id}} mutation{mergePullRequest(input:{pullRequestId:1}){clientMutationId}}',
            "/w/mine/resolve.graphql": "mutation{resolveReviewThread(input:{threadId:1}){thread{isResolved}}}",
        }
        repos = Repos(REPOS)
        for command, expected in (
            ("gh api graphql -F query=@merge.graphql", "warn"),
            ("gh api graphql --input merge.graphql", "warn"),
            ("gh api graphql -F query=@up.graphql", "deny"),
            ("gh api graphql --input up.graphql", "deny"),
            ("gh api graphql -F query=@resolve.graphql", "allow"),
            ("gh api graphql -F query=@/w/mine/resolve.graphql", "allow"),
        ):
            v = ug.decide(command, "/w/mine", ENV, ("nrslib",), repos, files)
            self.assertEqual(v.kind, expected, command)

    def test_check_reads_graphql_query_files(self):
        # E-1: 本番の経路（check() と LazyFiles）でも、クエリのファイルを読む
        import tempfile

        d = tempfile.mkdtemp()
        with open(os.path.join(d, "merge.graphql"), "w") as f:
            f.write(
                'query{repository(owner:"nrslib",name:"takt"){id}} mutation{mergePullRequest(input:{pullRequestId:"x"}){clientMutationId}}'
            )
        with open(os.path.join(d, "resolve.graphql"), "w") as f:
            f.write(
                'mutation{r0: resolveReviewThread(input:{threadId:"PRRT_x"}){thread{isResolved}}}'
            )
        with open(os.path.join(d, "threads.graphql"), "w") as f:
            f.write(
                'query{repository(owner:"j5ik2o",name:"dotfiles"){pullRequest(number:229){reviewThreads(first:80){nodes{id isResolved}}}}}'
            )
        env = {"HOME": d, "PATH": os.environ.get("PATH", "")}
        verdict = ug.check("gh api graphql -F query=@merge.graphql", d, env)
        self.assertEqual(verdict.kind, "deny")
        # レビューの返信、スレッドの解決と読み取りは、ファイル・変数・直接の 3 通りとも通す
        daily = [
            "gh api graphql -F query=@resolve.graphql --jq '[.data[]] | length'",
            "gh api graphql -F query=@threads.graphql",
            "gh api graphql --input resolve.graphql",
            'q=$(cat resolve.graphql); gh api graphql -f query="$q"',
            "gh api graphql -f query='mutation{r0: resolveReviewThread(input:{threadId:\"PRRT_x\"}){thread{isResolved}}}'",
            'gh api graphql -f query=\'query{repository(owner:"j5ik2o",name:"dotfiles"){pullRequest(number:229){reviewThreads(first:80){nodes{id}}}}}\'',
            "for id in 1 2; do gh api -X POST repos/j5ik2o/dotfiles/pulls/229/comments/$id/replies -F body=@r.md; done",
        ]
        for command in daily:
            self.assertEqual(ug.check(command, d, env).kind, "allow", command)

    def test_no_secret_reaches_the_log_or_the_model(self):
        # Authorization・Cookie・トークンに見える値と、URL の //…@ を、記録とモデルへの理由の両方で伏せる
        import tempfile

        state = tempfile.mkdtemp()
        env = {
            "HOME": "/x",
            "ORCA_AGENT_SESSION_ID": "s",
            "UPSTREAM_GUARD_STATE": state,
        }
        secrets = [
            "SECRETA1",
            "SECRETB2",
            "ghp_SECRETC3abcdefghij",
            "SECRETD4",
            "SECRETE5",
        ]
        commands = [
            "git -c 'http.https://github.com/nrslib/.extraheader=AUTHORIZATION: basic SECRETA1' push origin",
            "git -c remote.origin.pushurl=https://x-access-token:SECRETB2@github.com/nrslib/takt push origin",
            "git -c 'url.https://github.com/nrslib/.insteadOf=ghp_SECRETC3abcdefghij' push origin",
            "git -c 'http.https://github.com/nrslib/.cookiefile=Cookie: session=SECRETD4' push origin",
            "git -c 'http.https://github.com/nrslib/.extraheader=Authorization: Bearer SECRETE5' push origin",
        ]
        for command in commands:
            code, message = ug.hook_main(self.payload(command, "/nonexistent"), env)
            self.assertEqual(code, 2, command)
            for secret in secrets:
                self.assertNotIn(secret, message, command)
        with open(os.path.join(state, "denials.log")) as f:
            text = f.read()
        for secret in secrets:
            self.assertNotIn(secret, text)
        self.assertEqual(len(text.splitlines()), len(commands))

    def test_url_credentials_with_token_like_text_are_masked(self):
        # URL のパスワードに token= などがあっても、URL の資格情報を先に伏せる
        import tempfile

        state = tempfile.mkdtemp()
        env = {
            "HOME": "/x",
            "ORCA_AGENT_SESSION_ID": "s",
            "UPSTREAM_GUARD_STATE": state,
        }
        for command in (
            "git -c remote.origin.pushurl=https://user:TOPSECRET-token=abc@github.com/nrslib/takt push origin",
            "git -c remote.origin.pushurl=https://user:TOPSECRET-cookie=abc@github.com/nrslib/takt push origin",
        ):
            code, message = ug.hook_main(self.payload(command, "/nonexistent"), env)
            self.assertEqual(code, 2)
            self.assertNotIn("TOPSECRET", message)
        with open(os.path.join(state, "denials.log")) as f:
            self.assertNotIn("TOPSECRET", f.read())

    def test_concurrent_rotation_keeps_the_old_history(self):
        # 複数のフックが同時に上限超過を見ても、ローテーションは 1 回だけで、古い履歴を .1 に残す
        import subprocess
        import tempfile

        state = tempfile.mkdtemp()
        path = os.path.join(state, "denials.log")
        old = "old-history\n" * 50
        with open(path, "w") as f:
            f.write(old)
        script = (
            "import sys; sys.path.insert(0, sys.argv[1]); import upstream_guard as ug; ug.LOG_MAX_BYTES = 100; "
            "ug._append_private(sys.argv[2], sys.argv[3] + chr(10))"
        )
        scripts_dir = os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "..", "scripts"
        )
        procs = [
            subprocess.Popen(
                [sys.executable, "-c", script, scripts_dir, path, f'{{"n": {i}}}']
            )
            for i in range(12)
        ]
        for proc in procs:
            self.assertEqual(proc.wait(), 0)
        with open(path + ".1") as f:
            self.assertEqual(f.read(), old)
        with open(path) as f:
            self.assertEqual(len(f.read().splitlines()), 12)

    def test_log_files_are_private_and_bounded(self):
        # 記録のファイルは 0600、置き場は 0700。すでに在る 0644 のファイルも、書く時に 0600 に直す。大きさに上限
        import stat
        import tempfile

        state = os.path.join(tempfile.mkdtemp(), "state")
        os.makedirs(state, mode=0o755)
        os.chmod(state, 0o755)
        existing = os.path.join(state, "denials.log")
        with open(existing, "w") as f:
            f.write("x" * (ug.LOG_MAX_BYTES + 10) + "\n")
        os.chmod(existing, 0o644)
        env = {
            "HOME": "/x",
            "ORCA_AGENT_SESSION_ID": "s",
            "UPSTREAM_GUARD_STATE": state,
        }
        self.assertEqual(
            ug.hook_main(self.payload("gh pr merge 1 -R nrslib/takt"), env)[0], 2
        )
        self.assertEqual(
            ug.hook_main(self.payload('git push "$R"', "/nonexistent"), env)[0], 0
        )
        self.assertEqual(stat.S_IMODE(os.stat(state).st_mode), 0o700)
        for name in ("denials.log", "warnings.log", "denials.log.1"):
            self.assertEqual(
                stat.S_IMODE(os.stat(os.path.join(state, name)).st_mode), 0o600, name
            )
        # 上限を超えた古い分は .1 に移り、新しいファイルは今回の 1 件だけ
        with open(existing) as f:
            self.assertEqual(len(f.read().splitlines()), 1)
        self.assertLessEqual(os.path.getsize(existing + ".1"), ug.LOG_MAX_BYTES + 11)

    def test_log_keeps_no_secret_from_quoted_assignments_or_urls(self):
        # C-4: 引用符つきの代入の値を先頭の語にしない。C-5: 理由の中の URL の資格情報を伏せる
        import tempfile

        state = tempfile.mkdtemp()
        env = {
            "HOME": "/x",
            "ORCA_AGENT_SESSION_ID": "s",
            "UPSTREAM_GUARD_STATE": state,
        }
        first = self.payload("KEY='a secretpart' gh pr merge 1 -R nrslib/takt")
        self.assertEqual(ug.hook_main(first, env)[0], 2)
        second = self.payload(
            "git -c remote.origin.pushurl=https://user:tok123@github.com/nrslib/takt push origin"
        )
        self.assertEqual(ug.hook_main(second, env)[0], 2)
        with open(os.path.join(state, "denials.log")) as f:
            text = f.read()
        records = [json.loads(line) for line in text.splitlines()]
        self.assertEqual(records[0]["head"], "gh")
        self.assertNotIn("secretpart", text)
        self.assertNotIn("tok123", text)

    def test_input_json_body_is_checked(self):
        # C-7: gh api --input は JSON の本文を取る。query の中の mutation と禁止の宛先の語を拾う
        files = {
            "/w/mine/up.json": json.dumps(
                {
                    "query": 'query{repository(owner:"nrslib",name:"takt"){id}} mutation{mergePullRequest(input:{pullRequestId:"x"}){clientMutationId}}'
                }
            ),
            "/w/mine/merge.json": json.dumps(
                {
                    "query": "mutation($id:ID!){mergePullRequest(input:{pullRequestId:$id}){clientMutationId}}",
                    "variables": {"id": "PR_x"},
                }
            ),
            "/w/mine/resolve.json": json.dumps(
                {
                    "query": 'mutation{resolveReviewThread(input:{threadId:"T"}){thread{isResolved}}}'
                }
            ),
        }
        for name, expected in (
            ("up.json", "deny"),
            ("merge.json", "warn"),
            ("resolve.json", "allow"),
        ):
            v = ug.decide(
                f"gh api graphql --input {name}",
                "/w/mine",
                ENV,
                ("nrslib",),
                Repos(REPOS),
                files,
            )
            self.assertEqual(v.kind, expected, name)

    def test_log_head_drops_leading_assignments(self):
        # 記録の先頭の語に、前置きの代入（トークンなど）を入れない
        import tempfile

        state = tempfile.mkdtemp()
        env = {
            "HOME": "/x",
            "ORCA_AGENT_SESSION_ID": "s",
            "UPSTREAM_GUARD_STATE": state,
        }
        payload = self.payload(
            "GH_TOKEN=ghp_review_fake_secret FOO=1 gh pr merge 1 -R nrslib/takt"
        )
        self.assertEqual(ug.hook_main(payload, env)[0], 2)
        with open(os.path.join(state, "denials.log")) as f:
            text = f.read()
        self.assertNotIn("ghp_review_fake_secret", text)
        self.assertEqual(json.loads(text)["head"], "gh")

    def test_warn_reaches_the_model_and_both_kinds_are_logged_without_the_command(self):
        # 1 と 7: 警告は additionalContext と systemMessage で返し、警告と拒否を 1 行 1 件で残す
        import tempfile

        state = tempfile.mkdtemp()
        env = {
            "HOME": "/x",
            "ORCA_AGENT_SESSION_ID": "sess-1",
            "UPSTREAM_GUARD_STATE": state,
        }
        secret = "SECRET-TOKEN-123"
        code, out = ug.hook_main(
            self.payload(f'git push "$REMOTE" HEAD # {secret}', "/nonexistent"), env
        )
        self.assertEqual(code, 0)
        warning = json.loads(out)
        self.assertIn(
            "判定できませんでした", warning["hookSpecificOutput"]["additionalContext"]
        )
        self.assertEqual(
            warning["systemMessage"], warning["hookSpecificOutput"]["additionalContext"]
        )
        code, _ = ug.hook_main(
            self.payload(f"gh pr merge 1 -R nrslib/takt # {secret}"), env
        )
        self.assertEqual(code, 2)
        self.assertEqual(ug.hook_main(self.payload("ls -la"), env), (0, ""))
        with open(os.path.join(state, "warnings.log")) as f:
            warns = [json.loads(line) for line in f]
        with open(os.path.join(state, "denials.log")) as f:
            denials = [json.loads(line) for line in f]
        self.assertEqual((len(warns), len(denials)), (1, 1))
        for record, kind in ((warns[0], "warn"), (denials[0], "deny")):
            self.assertEqual(record["verdict"], kind)
            self.assertEqual(record["session"], "sess-1")
            self.assertIn(record["head"], ("git", "gh"))
            self.assertIn(record["looks_like"], ("push", "merge"))
            self.assertTrue(record["time"] and record["reason"])
        self.assertEqual(denials[0]["looks_like"], "merge")
        with (
            open(os.path.join(state, "warnings.log")) as f1,
            open(os.path.join(state, "denials.log")) as f2,
        ):
            self.assertNotIn(secret, f1.read() + f2.read())

    def test_hook_command_matches_the_shellchecked_script(self):
        # D-1: 登録するシェルの行は scripts/upstream-guard-hook.sh と同じ（そちらに shellcheck が掛かる）
        path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..",
            "scripts",
            "upstream-guard-hook.sh",
        )
        with open(path, encoding="utf-8") as f:
            lines = [
                line.rstrip("\n")
                for line in f
                if line.strip() and not line.startswith("#")
            ]
        self.assertEqual(lines, [ug.HOOK_COMMAND])

    def test_failing_extra_blocked_list_still_uses_the_default_list(self):
        # A-13 と D-4: 追加の一覧を読めなくても、既定の一覧で decide() まで通す
        env = {"HOME": "/x", "ORCA_AGENT_SESSION_ID": "s"}
        original = ug.load_blocked

        def broken(*_args):
            raise UnicodeDecodeError("utf-8", b"\xff", 0, 1, "壊れた一覧")

        ug.load_blocked = broken
        try:
            push = self.payload("git push https://github.com/nrslib/takt main")
            self.assertEqual(ug.hook_main(push, env)[0], 2)
            # 推測だけの _fallback では通ってしまい、decide() なら止まる形
            merge = self.payload("G=gh; $G pr merge 1 -R nrslib/takt")
            self.assertTrue(ug._fallback("G=gh; $G pr merge 1 -R nrslib/takt").allowed)
            self.assertEqual(ug.hook_main(merge, env)[0], 2)
            read = self.payload("gh pr view 1 -R nrslib/takt")
            self.assertEqual(ug.hook_main(read, env), (0, ""))
            note = self.payload(
                "orca bot reply --text 'git push と gh pr merge は使わない'"
            )
            self.assertEqual(ug.hook_main(note, env), (0, ""))
        finally:
            ug.load_blocked = original


class RealGitConfig(unittest.TestCase):
    """D-2: 一時リポジトリの実際の git の設定を読む。git は手元の設定だけを読み、ネットワークに出ない。"""

    def setUp(self):
        import tempfile

        # A-7: git のフックの中などで走らせても別のリポジトリに触れないよう、引き継いだ GIT_* を外す
        names = (
            "GIT_CONFIG_GLOBAL",
            "GIT_CONFIG_NOSYSTEM",
            "GIT_DIR",
            "GIT_COMMON_DIR",
            "GIT_WORK_TREE",
            "GIT_INDEX_FILE",
        )
        self.saved = {k: os.environ.get(k) for k in names}
        for k in names:
            os.environ.pop(k, None)
        os.environ["GIT_CONFIG_GLOBAL"] = os.devnull
        os.environ["GIT_CONFIG_NOSYSTEM"] = "1"
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def repo(self, *configs: tuple[str, ...]) -> str:
        import subprocess
        import tempfile

        path = tempfile.mkdtemp(dir=self.dir)
        subprocess.run(["git", "init", "-q", "-b", "main", path], check=True)
        for args in configs:
            subprocess.run(["git", "-C", path, *args], check=True)
        return path

    def verdict(self, command: str, cwd: str) -> str:
        env = {"HOME": self.dir, "PATH": os.environ.get("PATH", "")}
        return ug.check(command, cwd, env).kind  # C-8: warn を allow に丸めない

    def test_push_targets_come_from_the_real_config(self):
        mine = self.repo(("remote", "add", "origin", "https://github.com/j5ik2o/takt"))
        self.assertEqual(self.verdict("git push", mine), "allow")
        self.assertEqual(self.verdict("git push origin main", mine), "allow")
        pushurl = self.repo(
            ("remote", "add", "origin", "https://github.com/j5ik2o/takt"),
            ("remote", "set-url", "--push", "origin", "git@github.com:nrslib/takt.git"),
        )
        self.assertEqual(self.verdict("git push origin", pushurl), "deny")
        rewritten = self.repo(
            ("config", "url.https://github.com/nrslib/.insteadOf", "up:"),
            ("remote", "add", "origin", "up:takt"),
        )
        self.assertEqual(self.verdict("git push origin", rewritten), "deny")
        push_remote = self.repo(
            ("remote", "add", "origin", "https://github.com/j5ik2o/takt"),
            ("remote", "add", "up", "https://github.com/nrslib/takt"),
            ("config", "branch.main.pushRemote", "up"),
        )
        self.assertEqual(self.verdict("git push", push_remote), "deny")
        self.assertEqual(self.verdict("git push origin", push_remote), "allow")

    def test_gh_default_repo_follows_set_default(self):
        both = (
            ("remote", "add", "origin", "https://github.com/j5ik2o/takt"),
            ("remote", "add", "upstream", "https://github.com/nrslib/takt.git"),
        )
        unresolved = self.repo(*both)
        self.assertEqual(self.verdict("gh pr merge 3", unresolved), "deny")
        resolved = self.repo(*both, ("config", "remote.origin.gh-resolved", "base"))
        self.assertEqual(self.verdict("gh pr merge 3", resolved), "allow")

    def test_unreadable_push_urls_make_the_target_unknown(self):
        # A-12: push の URL を読めなかった remote は、空の一覧ではなく「決まらない」
        mine = self.repo(("remote", "add", "origin", "https://github.com/j5ik2o/takt"))
        original = ug._git

        def flaky(location, *args):
            if args[:3] == ("remote", "get-url", "--push"):
                return None
            return original(location, *args)

        ug._git = flaky
        try:
            info = ug.read_repo_info(mine)
            self.assertFalse(info.remotes["origin"].readable)
            v = ug.decide("git push origin", mine, {}, ("nrslib",), {mine: info})
            self.assertEqual(v.kind, "warn")  # 決まらないが、禁止の宛先の語は無い
            up = self.repo(
                ("remote", "add", "origin", "https://github.com/nrslib/takt")
            )
            info = ug.read_repo_info(up)
            v = ug.decide("git push origin", up, {}, ("nrslib",), {up: info})
            self.assertEqual(v.kind, "deny")  # fetch の URL に禁止の宛先の語がある
        finally:
            ug._git = original


class CheckCommand(unittest.TestCase):
    def test_check_entry_returns_warn_with_exit_zero(self):
        # 9: 宛先を判定できず、禁止の宛先の語も無いときは、1 行目が warn で終了コードは 0
        import contextlib
        import io

        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ug.main(
                [
                    "upstream-guard",
                    "check",
                    "--cwd",
                    "/nonexistent",
                    "--",
                    'git push "$REMOTE"',
                ]
            )
        self.assertEqual(code, 0)
        lines = out.getvalue().splitlines()
        self.assertEqual(lines[0], "warn")
        self.assertIn("判定できませんでした", lines[1])

    def test_check_entry_returns_verdict_without_running(self):
        import contextlib
        import io

        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ug.main(
                [
                    "upstream-guard",
                    "check",
                    "--cwd",
                    "/nonexistent",
                    "--",
                    "gh pr merge 1 -R nrslib/takt",
                ]
            )
        self.assertEqual(code, 2)
        self.assertTrue(out.getvalue().startswith("deny"))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(
                ug.main(
                    ["upstream-guard", "check", "--", "gh pr view 1 -R nrslib/takt"]
                ),
                0,
            )


class Install(unittest.TestCase):
    ORCA_GROUP: ClassVar[dict] = {
        "hooks": [
            {
                "type": "command",
                "command": ": orca-agent-hook-form=2; true",
                "timeout": 10,
            }
        ]
    }

    def setUp(self):
        import tempfile

        self.home = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.home, ".claude"))
        os.makedirs(os.path.join(self.home, ".codex"))
        self.files = {
            ".claude/settings.json": json.dumps(
                {"model": "x", "hooks": {"PreToolUse": [self.ORCA_GROUP]}}, indent=2
            )
            + "\n",
            ".codex/hooks.json": json.dumps(
                {"hooks": {"PreToolUse": [self.ORCA_GROUP]}}, indent=2
            )
            + "\n",
            ".codex/config.toml": 'model = "m"\n\n[hooks.state."x:pre_tool_use:0:0"]\nenabled = true\n',
        }
        for rel, text in self.files.items():
            with open(os.path.join(self.home, rel), "w") as f:
                f.write(text)

    def read(self, rel):
        with open(os.path.join(self.home, rel)) as f:
            return f.read()

    def test_install_is_idempotent_and_uninstall_restores(self):
        ug.apply_install(self.home, True, "t1")
        settings = json.loads(self.read(".claude/settings.json"))
        self.assertEqual(settings["hooks"]["PreToolUse"][0], self.ORCA_GROUP)
        self.assertEqual(
            settings["hooks"]["PreToolUse"][1]["hooks"][0]["command"], ug.HOOK_COMMAND
        )
        hooks_path = os.path.realpath(os.path.join(self.home, ".codex/hooks.json"))
        config = self.read(".codex/config.toml")
        self.assertIn(f'[hooks.state."{hooks_path}:pre_tool_use:1:0"]', config)
        self.assertIn(ug.codex_trusted_hash(ug._hook_group(ug.CODEX_MATCHER)), config)
        first = {rel: self.read(rel) for rel in self.files}
        ug.apply_install(self.home, True, "t2")
        self.assertEqual({rel: self.read(rel) for rel in self.files}, first)
        self.assertFalse(
            any("t2" in n for n in os.listdir(os.path.join(self.home, ".codex")))
        )
        ug.apply_install(self.home, False, "t3")
        self.assertEqual({rel: self.read(rel) for rel in self.files}, self.files)
        self.assertTrue(
            os.path.exists(
                os.path.join(self.home, ".claude/settings.json.bak-upstream-guard-t1")
            )
        )

    def test_install_creates_missing_settings_and_reports_missing_agents(self):
        # C-1: 設定ファイルが無ければ作り、エージェントの置き場が無ければ登録できなかったと返す
        import shutil
        import tempfile

        os.remove(os.path.join(self.home, ".claude/settings.json"))
        result = ug.apply_install(self.home, True, "t1")
        settings = json.loads(self.read(".claude/settings.json"))
        self.assertEqual(
            settings["hooks"]["PreToolUse"][0]["hooks"][0]["command"], ug.HOOK_COMMAND
        )
        self.assertEqual(result.skipped, [])
        bare = tempfile.mkdtemp()
        os.makedirs(os.path.join(bare, ".claude"))
        result = ug.apply_install(bare, True, "t1")
        self.assertEqual(len(result.skipped), 1)
        self.assertIn("Codex", result.skipped[0])
        shutil.rmtree(bare)

    def test_uninstall_keeps_other_hooks_in_the_same_group(self):
        # C-2: 同じグループにあるほかのフックは消さない
        other = {"type": "command", "command": "other-hook", "timeout": 5}
        group = {
            "matcher": "Bash",
            "hooks": [other, ug._hook_group("Bash")["hooks"][0]],
        }
        path = os.path.join(self.home, ".claude/settings.json")
        with open(path, "w") as f:
            json.dump({"hooks": {"PreToolUse": [group]}}, f)
        ug.apply_install(self.home, False, "t1")
        groups = json.loads(self.read(".claude/settings.json"))["hooks"]["PreToolUse"]
        self.assertEqual(groups, [{"matcher": "Bash", "hooks": [other]}])

    def test_trust_key_escapes_the_path(self):
        # C-3: パスに " や \\ があっても config.toml が読める
        import tempfile
        import tomllib

        home = os.path.join(tempfile.mkdtemp(), 'we"ird\\home')
        os.makedirs(os.path.join(home, ".codex"))
        os.makedirs(os.path.join(home, ".claude"))
        ug.apply_install(home, True, "t1")
        with open(os.path.join(home, ".codex/config.toml"), "rb") as f:
            state = tomllib.load(f)["hooks"]["state"]
        real = os.path.join(
            os.path.realpath(os.path.join(home, ".codex")), "hooks.json"
        )
        self.assertIn(f"{real}:pre_tool_use:0:0", state)

    def test_codex_files_are_written_together_or_not_at_all(self):
        # C-4: config.toml を書けなければ、hooks.json も元のまま
        real_replace = os.replace

        def failing_replace(src, dst):
            if str(dst).endswith("config.toml"):
                raise OSError("置き換えに失敗")
            return real_replace(src, dst)

        ug.os.replace = failing_replace
        try:
            with self.assertRaises(OSError):
                ug.apply_install(self.home, True, "t1")
        finally:
            ug.os.replace = real_replace
        self.assertEqual(
            self.read(".codex/hooks.json"), self.files[".codex/hooks.json"]
        )
        self.assertEqual(
            self.read(".codex/config.toml"), self.files[".codex/config.toml"]
        )

    def test_partial_write_is_restored(self):
        # E-2: 書き込みの途中で失敗し、切り詰められたファイルも元に戻る
        import builtins

        real_open = builtins.open

        class Failing:
            def __init__(self, f):
                self.f = f

            def __enter__(self):
                return self

            def __exit__(self, *a):
                self.f.close()

            def write(self, text):
                self.f.write(text[: len(text) // 2])
                raise OSError("ディスクが一杯")

        def fake_open(path, mode="r", *args, **kwargs):
            f = real_open(path, mode, *args, **kwargs)
            if (
                "w" in mode
                and "config.toml" in str(path)
                and "bak-upstream-guard" not in str(path)
            ):
                return Failing(f)
            return f

        ug.open = fake_open
        try:
            with self.assertRaises(OSError):
                ug.apply_install(self.home, True, "t1")
        finally:
            del ug.open
        self.assertEqual(
            self.read(".codex/config.toml"), self.files[".codex/config.toml"]
        )
        self.assertEqual(
            self.read(".codex/hooks.json"), self.files[".codex/hooks.json"]
        )

    def codex_setup(self, groups, config_tail=""):
        real = os.path.join(
            os.path.realpath(os.path.join(self.home, ".codex")), "hooks.json"
        )
        with open(os.path.join(self.home, ".codex/hooks.json"), "w") as f:
            json.dump({"hooks": {"PreToolUse": groups}}, f)
        with open(os.path.join(self.home, ".codex/config.toml"), "w") as f:
            f.write('model = "m"\n' + config_tail.replace("REAL", real))
        return real

    def trust(self):
        import tomllib

        with open(os.path.join(self.home, ".codex/config.toml"), "rb") as f:
            return tomllib.load(f)["hooks"]["state"]

    def test_reinstall_keeps_the_position_and_other_trust_keys(self):
        # A-1: 入れ直しで自分の位置を変えず、後ろのほかの Codex フックの信頼の値をずらさない
        later = {
            "matcher": "Edit",
            "hooks": [{"type": "command", "command": "later-hook", "timeout": 5}],
        }
        ours = ug._hook_group(ug.CODEX_MATCHER)
        real = self.codex_setup(
            [self.ORCA_GROUP, ours, later],
            '\n[hooks.state."REAL:pre_tool_use:2:0"]\nenabled = true\ntrusted_hash = "sha256:later"\n',
        )
        ug.apply_install(self.home, True, "t1")
        groups = json.loads(self.read(".codex/hooks.json"))["hooks"]["PreToolUse"]
        self.assertEqual(groups[1]["hooks"][0]["command"], ug.HOOK_COMMAND)
        self.assertEqual(groups[2], later)
        state = self.trust()
        self.assertEqual(
            state[f"{real}:pre_tool_use:2:0"]["trusted_hash"], "sha256:later"
        )
        self.assertIn(f"{real}:pre_tool_use:1:0", state)
        # 外すときは、後ろのフックのキーを 1 つ前へ追従させる
        ug.apply_install(self.home, False, "t2")
        groups = json.loads(self.read(".codex/hooks.json"))["hooks"]["PreToolUse"]
        self.assertEqual(groups, [self.ORCA_GROUP, later])
        state = self.trust()
        self.assertEqual(
            state[f"{real}:pre_tool_use:1:0"]["trusted_hash"], "sha256:later"
        )
        self.assertNotIn(f"{real}:pre_tool_use:2:0", state)

    def test_trust_header_with_trailing_comment_is_not_duplicated(self):
        # A-5: 見出しの行末にコメントがある同じ表を、重ねて書かない
        real = self.codex_setup(
            [self.ORCA_GROUP, ug._hook_group(ug.CODEX_MATCHER)],
            '\n[hooks.state."REAL:pre_tool_use:1:0"]  # 手で足した\nenabled = true\ntrusted_hash = "sha256:old"\n',
        )
        ug.apply_install(self.home, True, "t1")
        state = self.trust()  # 読めること（重ねると tomllib が失敗する）
        self.assertEqual(
            state[f"{real}:pre_tool_use:1:0"]["trusted_hash"],
            ug.codex_trusted_hash(ug._hook_group(ug.CODEX_MATCHER)),
        )

    def test_unreadable_toml_result_is_not_written(self):
        # A-5: 書き換えた結果を tomllib で読めなければ、書かずに失敗させる
        self.codex_setup([self.ORCA_GROUP], "\n[broken\n")
        before = self.read(".codex/config.toml")
        with self.assertRaises(ValueError):
            ug.apply_install(self.home, True, "t1")
        self.assertEqual(self.read(".codex/config.toml"), before)
        self.assertEqual(
            json.loads(self.read(".codex/hooks.json"))["hooks"]["PreToolUse"],
            [self.ORCA_GROUP],
        )

    def test_permissions_are_kept_and_backups_are_private(self):
        # A-4: 0600 の設定ファイルを 0644 に広げない。写しは 0600
        import stat

        for rel in (".claude/settings.json", ".codex/hooks.json", ".codex/config.toml"):
            os.chmod(os.path.join(self.home, rel), 0o600)
        ug.apply_install(self.home, True, "t1")
        for rel in (".claude/settings.json", ".codex/hooks.json", ".codex/config.toml"):
            path = os.path.join(self.home, rel)
            self.assertEqual(stat.S_IMODE(os.stat(path).st_mode), 0o600, rel)
            self.assertEqual(
                stat.S_IMODE(os.stat(path + ".bak-upstream-guard-t1").st_mode),
                0o600,
                rel,
            )

    def test_existing_unmarked_trust_table_is_replaced_not_duplicated(self):
        # 管理の印の無い、同じキーの信頼の表（前の版の形）があっても、重ねて書かない
        import tomllib

        real = os.path.join(
            os.path.realpath(os.path.join(self.home, ".codex")), "hooks.json"
        )
        old_handler = {
            "type": "command",
            "command": '"$HOME/.local/bin/upstream-guard" hook',
            "timeout": 10,
        }
        with open(os.path.join(self.home, ".codex/hooks.json"), "w") as f:
            json.dump(
                {
                    "hooks": {
                        "PreToolUse": [
                            self.ORCA_GROUP,
                            {"matcher": "Bash", "hooks": [old_handler]},
                        ]
                    }
                },
                f,
            )
        with open(os.path.join(self.home, ".codex/config.toml"), "w") as f:
            f.write(
                f'model = "m"\n\n[hooks.state."{real}:pre_tool_use:1:0"]\nenabled = true\ntrusted_hash = "sha256:old"\n\n[other]\nx = 1\n'
            )
        ug.apply_install(self.home, True, "t1")
        with open(os.path.join(self.home, ".codex/config.toml"), "rb") as f:
            config = tomllib.load(f)
        state = config["hooks"]["state"][f"{real}:pre_tool_use:1:0"]
        self.assertEqual(
            state["trusted_hash"],
            ug.codex_trusted_hash(ug._hook_group(ug.CODEX_MATCHER)),
        )
        self.assertEqual(config["other"], {"x": 1})

    def test_trusted_hash_matches_what_codex_accepted(self):
        # codex 0.167.2 の exec が、この値を config.toml に書いたフックを実行した（2026-11-25 に確認）
        group = {
            "matcher": "Bash",
            "hooks": [
                {
                    "type": "command",
                    "command": "/private/tmp/claude-501/-Users-j5ik2o-orca-workspaces-dotfiles-bot-upstream-guard/"
                    "acace11a-89f5-4d10-97c8-12b3e44a00fe/scratchpad/codexhook.sh",
                    "timeout": 10,
                }
            ],
        }
        self.assertEqual(
            ug.codex_trusted_hash(group),
            "sha256:dd90b162a34b0711d2b5d9f9482e1524380931b69d4536644bb96de561a943ac",
        )


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    print(f"判定の表: {len(CASES)} 件")
    sys.exit(0 if result.wasSuccessful() else 1)
