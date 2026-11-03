#!/usr/bin/env python3
"""Codex と TensorFold の間に立つ、namespace 型の道具の変換の中継。

Codex は MCP サーバーの道具を、Responses API の要求の `tools` に `type: "namespace"` の項目で
包んで送る。TensorFold の窓口は `type: "function"` の道具しか受け付けない。この中継は 127.0.0.1 で
待ち受け、行きは namespace の道具を function の道具に直し、帰りはモデルの道具の呼び出しを
Codex が分かる形 (`name` と `namespace` の組) に戻す。

Python の標準ライブラリだけで書く。起動の台本が macOS の `/usr/bin/python3` (3.9) で動かすので、
3.9 で動く書き方にする (`match` 文と実行時の `X | Y` の型を使わない)。
"""

from __future__ import annotations

import argparse
import contextlib
import http.client
import http.server
import json
import os
import select
import shutil
import signal
import socket
import sys
import threading
import time
import urllib.parse
from typing import Any

DEFAULT_UPSTREAM = "http://10.0.1.60:8000"

# 接続ごとの見出し。中継は流さない (本文の長さと接続の扱いは中継が決め直す)。
HOP_BY_HOP = frozenset(
    {
        "connection",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailer",
        "transfer-encoding",
        "upgrade",
        "content-length",
        # 中継自身が付けるので、上流のものは流さない (二重になる)
        "server",
        "date",
    }
)

# 利用者の道具を持たない namespace の説明の定型文。道具の説明の頭には足さない。
BOILERPLATE_DESCRIPTION = "Tools in the {} namespace."


class RelayError(Exception):
    """要求を直せない。中継が 400 で、この文を返す。"""


def flat_name(namespace: str, name: str) -> str:
    """Codex が MCP の道具に付ける平らな名前と同じ組み方 (端の `_` を詰め、`__` でつなぐ)。"""
    return namespace.rstrip("_") + "__" + name.lstrip("_")


def _merged_description(namespace: dict[str, Any], tool: dict[str, Any]) -> Any:
    ns_desc = namespace.get("description")
    own = tool.get("description")
    if not isinstance(ns_desc, str) or not ns_desc.strip():
        return own
    if ns_desc.strip() == BOILERPLATE_DESCRIPTION.format(namespace.get("name")):
        return own
    if not isinstance(own, str) or not own:
        return ns_desc
    return ns_desc + "\n\n" + own


ENCRYPTED_REASONING = "reasoning.encrypted_content"


def _wants_encrypted_reasoning(body: dict[str, Any]) -> bool:
    include = body.get("include")
    return isinstance(include, list) and ENCRYPTED_REASONING in include


def rewrite_request(body: dict[str, Any]) -> tuple[dict[str, Any], dict[str, tuple[str, str]], int]:
    """要求の本文を直す。(直した本文, 対応表, 直した namespace の道具の数) を返す。

    対応表はこの要求の中身だけから作る。`body` は書き換えない。
    """
    new = dict(body)
    table: dict[str, tuple[str, str]] = {}
    count = 0

    # TensorFold は思考を平文で返し、暗号化しないので、この指定を 400 で断る。値だけ外す
    if _wants_encrypted_reasoning(body):
        new["include"] = [x for x in body["include"] if x != ENCRYPTED_REASONING]

    tools = body.get("tools")
    if isinstance(tools, list):
        top_names = {
            t["name"]
            for t in tools
            if isinstance(t, dict)
            and t.get("type") == "function"
            and isinstance(t.get("name"), str)
        }
        out_tools: list[Any] = []
        for tool in tools:
            if not (isinstance(tool, dict) and tool.get("type") == "namespace"):
                out_tools.append(tool)
                continue
            inner = tool.get("tools")
            ns_name = tool.get("name")
            convertible = (
                isinstance(ns_name, str)
                and isinstance(inner, list)
                and all(isinstance(x, dict) and x.get("type") == "function" for x in inner)
            )
            if not convertible:
                # function 以外が混じる namespace は直さず残す (TensorFold が断り、理由が見える)
                out_tools.append(tool)
                continue
            for item in inner:
                inner_name = item.get("name")
                if not isinstance(inner_name, str):
                    raise RelayError(f"namespace {ns_name!r} に、名前のない道具があります")
                flat = flat_name(ns_name, inner_name)
                if flat in top_names or flat in table:
                    raise RelayError(
                        f"namespace {ns_name!r} の道具 {inner_name!r} を直すと {flat!r} になり、"
                        "同じ名前の道具がすでにあります。名前がぶつかるので、中継は要求を断ります"
                    )
                fixed = dict(item)
                fixed["name"] = flat
                description = _merged_description(tool, item)
                if description is not None:
                    fixed["description"] = description
                out_tools.append(fixed)
                table[flat] = (ns_name, inner_name)
                count += 1
        new["tools"] = out_tools

    items = body.get("input")
    if isinstance(items, list):
        out_items: list[Any] = []
        for item in items:
            if (
                isinstance(item, dict)
                and item.get("type") == "function_call"
                and "namespace" in item
            ):
                item = dict(item)
                namespace = item.pop("namespace")
                if isinstance(namespace, str) and namespace and isinstance(item.get("name"), str):
                    item["name"] = flat_name(namespace, item["name"])
            elif isinstance(item, dict) and item.get("type") == "function_call_output":
                if "namespace" in item:
                    item = {k: v for k, v in item.items() if k != "namespace"}
            out_items.append(item)
        new["input"] = out_items

    choice = body.get("tool_choice")
    if isinstance(choice, dict) and choice.get("type") == "function" and "namespace" in choice:
        choice = dict(choice)
        namespace = choice.pop("namespace")
        if isinstance(namespace, str) and namespace and isinstance(choice.get("name"), str):
            choice["name"] = flat_name(namespace, choice["name"])
        new["tool_choice"] = choice

    return new, table, count


def _restore_call(item: Any, table: dict[str, tuple[str, str]]) -> bool:
    """`function_call` の項目を、表にある名前だけ `name` と `namespace` の組に戻す。"""
    if not isinstance(item, dict) or not isinstance(item.get("name"), str):
        return False
    target = table.get(item["name"])
    if target is None:
        return False
    item["namespace"], item["name"] = target
    return True


def _restore_output(output: Any, table: dict[str, tuple[str, str]]) -> int:
    restored = 0
    if isinstance(output, list):
        for item in output:
            if isinstance(item, dict) and item.get("type") == "function_call":
                restored += _restore_call(item, table)
    return restored


def restore_response_object(obj: dict[str, Any], table: dict[str, tuple[str, str]]) -> int:
    """ストリーミングでない応答の本文 (または `response` の中身) の `output[]` を戻す。"""
    return _restore_output(obj.get("output"), table)


def restore_event(event: dict[str, Any], table: dict[str, tuple[str, str]]) -> tuple[bool, int]:
    """1つのイベントを戻す。(書き換えたか, 数えるべき道具の呼び出しの数) を返す。

    数えるのは `response.output_item.done` だけ (同じ呼び出しを `completed` の `output[]` でも
    戻すが、二重に数えない)。
    """
    if not table:
        return False, 0
    changed = False
    counted = 0
    kind = event.get("type")
    item = event.get("item")
    is_call = isinstance(item, dict) and item.get("type") == "function_call"
    if is_call and _restore_call(item, table):
        changed = True
        counted = 1 if kind == "response.output_item.done" else 0
    arguments_events = (
        "response.function_call_arguments.delta",
        "response.function_call_arguments.done",
    )
    if kind in arguments_events and _restore_call(event, table):
        changed = True
    response = event.get("response")
    if isinstance(response, dict) and _restore_output(response.get("output"), table):
        changed = True
    return changed, counted


def restore_sse_line(line: bytes, table: dict[str, tuple[str, str]]) -> tuple[bytes, int]:
    """Server-Sent Events の1行を戻す。`data:` の行で、直す所があるときだけ作り直す。"""
    if not table or not line.startswith(b"data:"):
        return line, 0
    payload = line[len(b"data:") :].strip()
    if not payload or payload == b"[DONE]":
        return line, 0
    try:
        event = json.loads(payload)
    except ValueError:
        return line, 0
    if not isinstance(event, dict):
        return line, 0
    changed, counted = restore_event(event, table)
    if not changed:
        return line, 0
    ending = b"\r\n" if line.endswith(b"\r\n") else b"\n"
    return b"data: " + json.dumps(event, ensure_ascii=False).encode("utf-8") + ending, counted


def restore_body(raw: bytes, table: dict[str, tuple[str, str]]) -> tuple[bytes, int]:
    """ストリーミングでない応答の本文を戻す。"""
    if not table:
        return raw, 0
    try:
        obj = json.loads(raw)
    except ValueError:
        return raw, 0
    if not isinstance(obj, dict):
        return raw, 0
    restored = restore_response_object(obj, table)
    if not restored:
        return raw, 0
    return json.dumps(obj, ensure_ascii=False).encode("utf-8"), restored


class Relay:
    """中継の設定と記録。"""

    def __init__(self, upstream: str, log_path: str | None) -> None:
        parsed = urllib.parse.urlsplit(upstream)
        if parsed.scheme != "http" or not parsed.hostname:
            raise ValueError(f"上流は http://host:port の形で指定してください: {upstream}")
        self.host = parsed.hostname
        self.port = parsed.port or 80
        self.prefix = parsed.path.rstrip("/")
        self.log_path = log_path
        self._lock = threading.Lock()

    @property
    def netloc(self) -> str:
        return f"{self.host}:{self.port}"

    def log(
        self,
        method: str,
        path: str,
        fixed: int,
        restored: int,
        status: Any,
        include_stripped: int = 0,
    ) -> None:
        """要求ごとに1行。本文は書かない (会話の中身が入るため)。"""
        if not self.log_path:
            return
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        line = (
            f"{stamp} {method} {path} namespace_tools_fixed={fixed} "
            f"tool_calls_restored={restored} include_stripped={include_stripped} "
            f"status={status} upstream={self.netloc}\n"
        )
        with self._lock, open(self.log_path, "a", encoding="utf-8") as handle:
            handle.write(line)


class ClientWatch:
    """利用者側の接続が閉じたら、上流への接続をすぐ閉じる見張り。

    上流が前置きの読み込みで何も返さない間も、TensorFold に切ったことを知らせて生成を止めさせる。
    TensorFold 自身も、接続の `MSG_PEEK` が 0 バイトなら切れたと見て生成を止める。
    """

    def __init__(self, client: socket.socket) -> None:
        self._client = client
        self._upstream: socket.socket | None = None
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self.closed = False
        self._thread = threading.Thread(target=self._run, daemon=True)

    def attach(self, upstream: socket.socket | None) -> None:
        """上流の接続を預かる (`getresponse()` のあとは接続の側から外れるので、先に預ける)。"""
        with self._lock:
            self._upstream = upstream
            if self.closed:
                # 接続が通る前に、利用者がすでに切っていた
                self._shutdown_upstream()

    def _shutdown_upstream(self) -> None:
        if self._upstream is not None:
            with contextlib.suppress(OSError):
                self._upstream.shutdown(socket.SHUT_RDWR)

    def __enter__(self) -> ClientWatch:
        self._thread.start()
        return self

    def __exit__(self, *_: Any) -> None:
        self._stop.set()
        self._thread.join(timeout=2)

    def _client_gone(self) -> bool:
        try:
            ready, _, _ = select.select([self._client], [], [], 0.2)
            if not ready:
                return False
            return self._client.recv(1, socket.MSG_PEEK) == b""
        except (OSError, ValueError):
            return True

    def _run(self) -> None:
        while not self._stop.is_set():
            if self._client_gone():
                if self._stop.is_set():
                    return
                with self._lock:
                    self.closed = True
                    self._shutdown_upstream()
                return
            # 読める (追加のバイトがある) のに閉じていないときは、busy loop を避ける
            self._stop.wait(0.2)


def make_handler(relay: Relay) -> type[http.server.BaseHTTPRequestHandler]:
    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
            return

        def do_GET(self) -> None:
            self._handle()

        do_HEAD = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_GET

        def do_POST(self) -> None:
            self._handle()

        # -- 内部 --

        def _read_body(self) -> bytes:
            length = int(self.headers.get("Content-Length") or 0)
            return self.rfile.read(length) if length else b""

        def _drain_and_close(self) -> None:
            """読み残しがあるまま閉じると返事が RST で消えるので、書き終えてから少し読み捨てる。"""
            with contextlib.suppress(OSError):
                self.wfile.flush()
                self.connection.shutdown(socket.SHUT_WR)
                self.connection.settimeout(1.0)
                remaining = 1 << 20
                while remaining > 0:
                    chunk = self.connection.recv(65536)
                    if not chunk:
                        break
                    remaining -= len(chunk)

        def _is_chunked_without_length(self) -> bool:
            encoding = (self.headers.get("Transfer-Encoding") or "").lower()
            return "chunked" in encoding and self.headers.get("Content-Length") is None

        def _is_responses_post(self) -> bool:
            path = urllib.parse.urlsplit(self.path).path.rstrip("/")
            return self.command == "POST" and path.endswith("/responses")

        def _reply_error(self, status: int, message: str) -> None:
            payload = json.dumps(
                {"error": {"message": message, "type": "invalid_request_error"}},
                ensure_ascii=False,
            ).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(payload)

        def _handle(self) -> None:
            if self._is_chunked_without_length():
                # 本文の長さが分からない要求は読まない。空の本文として流すことはしない
                self.close_connection = True
                self._reply_error(
                    411,
                    "中継は Transfer-Encoding: chunked の要求を読めません。"
                    "Content-Length を付けて送ってください",
                )
                relay.log(self.command, self.path, 0, 0, 411)
                self._drain_and_close()
                return
            body = self._read_body()
            table: dict[str, tuple[str, str]] = {}
            fixed = 0
            include_stripped = 0
            if self._is_responses_post() and body and not self.headers.get("Content-Encoding"):
                try:
                    parsed = json.loads(body)
                except ValueError:
                    parsed = None
                if isinstance(parsed, dict):
                    include_stripped = int(_wants_encrypted_reasoning(parsed))
                    try:
                        rewritten, table, fixed = rewrite_request(parsed)
                    except RelayError as error:
                        self._reply_error(400, str(error))
                        relay.log(self.command, self.path, 0, 0, 400)
                        return
                    if rewritten != parsed:
                        body = json.dumps(rewritten, ensure_ascii=False).encode("utf-8")

            headers = {
                k: v
                for k, v in self.headers.items()
                if k.lower() not in HOP_BY_HOP and k.lower() not in ("host", "accept-encoding")
            }
            headers["Host"] = relay.netloc
            headers["Accept-Encoding"] = "identity"
            if body or self.command in ("POST", "PUT", "PATCH"):
                headers["Content-Length"] = str(len(body))

            # 生成は長くかかるので、時間切れは付けない
            connection = http.client.HTTPConnection(relay.host, relay.port, timeout=None)
            restored = 0
            status: Any = "-"
            watch = ClientWatch(self.connection)
            try:
                with watch:
                    try:
                        connection.connect()
                        watch.attach(connection.sock)
                        if watch.closed:
                            # 接続の途中で切られた。要求は上流へ送らない
                            raise ConnectionResetError("client closed")
                        connection.request(
                            self.command,
                            relay.prefix + self.path,
                            body=body or None,
                            headers=headers,
                        )
                        response = connection.getresponse()
                    except (OSError, http.client.HTTPException) as error:
                        if watch.closed:
                            raise ConnectionResetError("client closed") from error
                        self._reply_error(502, f"上流 {relay.netloc} につながりません: {error}")
                        status = 502
                        return
                    status = response.status
                    restored = self._relay_response(response, table)
                if watch.closed:
                    raise ConnectionResetError("client closed")
            except (BrokenPipeError, ConnectionResetError):
                status = f"{status}(client-closed)"
                self.close_connection = True
            except (OSError, http.client.HTTPException):
                if not watch.closed:
                    raise
                status = f"{status}(client-closed)"
                self.close_connection = True
            finally:
                connection.close()
                relay.log(self.command, self.path, fixed, restored, status, include_stripped)

        def _relay_response(self, response: http.client.HTTPResponse, table: dict) -> int:
            out_headers = [(k, v) for k, v in response.getheaders() if k.lower() not in HOP_BY_HOP]
            content_type = response.getheader("Content-Type", "") or ""
            is_events = content_type.startswith("text/event-stream")
            convert = self._is_responses_post() and response.status < 400 and bool(table)
            restored = 0

            if convert and not is_events:
                raw = response.read()
                raw, restored = restore_body(raw, table)
                self.send_response(response.status)
                for k, v in out_headers:
                    self.send_header(k, v)
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                if self.command != "HEAD":
                    self.wfile.write(raw)
                return restored

            declared = response.getheader("Content-Length")
            self.send_response(response.status)
            for k, v in out_headers:
                self.send_header(k, v)
            if declared is not None and not is_events:
                self.send_header("Content-Length", declared)
            else:
                # 長さが分からない応答は、閉じるまでを本文とする
                self.send_header("Connection", "close")
                self.close_connection = True
            self.end_headers()
            if self.command == "HEAD":
                return 0

            if is_events:
                # ためずに1行ずつ流す
                while True:
                    line = response.readline()
                    if not line:
                        break
                    if convert:
                        line, counted = restore_sse_line(line, table)
                        restored += counted
                    self.wfile.write(line)
                    self.wfile.flush()
            else:
                while True:
                    chunk = (
                        response.read1(65536)
                        if hasattr(response, "read1")
                        else response.read(65536)
                    )
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
            return restored

    return Handler


def parent_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def write_port_file(path: str, port: int) -> None:
    """書きかけを読まれないよう、一時のファイルに書いて名前を変える。"""
    temp = f"{path}.{os.getpid()}.tmp"
    with open(temp, "w", encoding="utf-8") as handle:
        handle.write(f"{port}\n")
    os.replace(temp, path)


def remove_work_dir(path: str | None) -> None:
    """台本が作った一時のフォルダを消す。別のフォルダを消さないよう、名前を確かめる。"""
    if path and os.path.basename(os.path.normpath(path)).startswith("codex-spark."):
        shutil.rmtree(path, ignore_errors=True)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="namespace 型の道具を function 型に直す中継")
    parser.add_argument("--upstream", default=DEFAULT_UPSTREAM, help="行き先 (既定: %(default)s)")
    parser.add_argument("--port", type=int, default=0, help="待ち受けの番号 (0 で OS が選ぶ)")
    parser.add_argument("--port-file", required=True, help="選ばれた番号を書くファイル")
    parser.add_argument("--log", default=None, help="記録を追記するファイル")
    parser.add_argument("--parent-pid", type=int, default=None, help="この親がいなくなったら止まる")
    parser.add_argument(
        "--work-dir",
        default=None,
        help="止まるときに消す一時のフォルダ (名前が codex-spark. で始まるものだけ)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    relay = Relay(args.upstream, args.log)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(relay))
    server.daemon_threads = True

    # 止めるのは親 (codex) の終わりか信号。Ctrl-C は同じプロセスのまとまりに届くので無視する。
    # SIGHUP は端末を閉じたときに届くので、SIGTERM と同じく静かに止まる
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    for number in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(
            number, lambda *_: threading.Thread(target=server.shutdown, daemon=True).start()
        )

    if args.parent_pid is not None:

        def watch() -> None:
            while parent_alive(args.parent_pid):
                time.sleep(0.5)
            server.shutdown()

        threading.Thread(target=watch, daemon=True).start()

    write_port_file(args.port_file, server.server_address[1])
    try:
        server.serve_forever()
    finally:
        server.server_close()
        remove_work_dir(args.work_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
