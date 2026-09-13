#!/usr/bin/env python3
"""Bridge KAG moderator chat commands to non-interactive Codex runs over TCPR."""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import getpass
import os
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


REQUEST_RE = re.compile(r"CODEX_REQUEST\|([^|\r\n]+)\|([^\r\n]+)")
CONTROL_RE = re.compile(r"CODEX_CONTROL\|([^|\r\n]+)\|(status|cancel)")
MAX_REQUEST_LENGTH = 1000


@dataclass(frozen=True)
class Request:
    username: str
    text: str


class Bridge:
    def __init__(self, args: argparse.Namespace, password: str) -> None:
        self.args = args
        self.password = password
        self.queue: asyncio.Queue[Request] = asyncio.Queue(maxsize=args.max_queue)
        self.writer: asyncio.StreamWriter | None = None
        self.active: Request | None = None
        self.process: asyncio.subprocess.Process | None = None
        self.write_lock = asyncio.Lock()

    async def send_console(self, expression: str) -> None:
        writer = self.writer
        if writer is None or writer.is_closing():
            return
        async with self.write_lock:
            writer.write((expression + "\n").encode("utf-8"))
            await writer.drain()

    @staticmethod
    def as_string(value: str) -> str:
        value = value.replace("\\", "\\\\").replace("'", "\\'")
        return value.replace("\r", " ").replace("\n", " ")[:240]

    async def chat(self, message: str) -> None:
        safe = self.as_string("[Codex] " + message)
        await self.send_console(f"getNet().server_SendMsg('{safe}')")

    async def handle_line(self, line: str) -> None:
        match = REQUEST_RE.search(line)
        if match:
            request = Request(match.group(1).strip(), match.group(2).strip())
            if not request.text or len(request.text) > MAX_REQUEST_LENGTH:
                await self.chat("request rejected: it must contain 1-1000 characters")
            elif self.queue.full():
                await self.chat("request queue is full")
            else:
                await self.queue.put(request)
                position = self.queue.qsize() + (1 if self.active else 0)
                await self.chat(f"queued request from {request.username} (position {position})")
            return

        match = CONTROL_RE.search(line)
        if not match:
            return
        username, command = match.groups()
        if command == "status":
            if self.active:
                await self.chat(
                    f"working on {self.active.username}'s request; {self.queue.qsize()} queued"
                )
            else:
                await self.chat(f"idle; {self.queue.qsize()} queued")
        elif self.process and self.process.returncode is None:
            self.process.terminate()
            await self.chat(f"active request cancelled by {username}")
        else:
            await self.chat("nothing is currently running")

    async def worker(self) -> None:
        while True:
            request = await self.queue.get()
            self.active = request
            try:
                await self.run_codex(request)
            except Exception as exc:
                await self.chat(f"bridge error: {type(exc).__name__}: {exc}")
            finally:
                self.process = None
                self.active = None
                self.queue.task_done()

    async def run_codex(self, request: Request) -> None:
        await self.chat(f"starting request from {request.username}")
        prompt = (
            "Implement the following request in the current King Arthur's Gold mod. "
            "Obey AGENTS.md, preserve unrelated dirty-worktree changes, edit only this mod, "
            "and verify the change as far as practical. Do not launch KAG.\n\n"
            f"In-game request from {request.username}:\n{request.text}"
        )

        fd, output_name = tempfile.mkstemp(prefix="kag-codex-", suffix=".txt")
        os.close(fd)
        output_path = Path(output_name)
        command = [
            self.args.codex, "exec", "--ephemeral", "--color", "never",
            "--sandbox", "workspace-write",
            "--cd", str(self.args.mod_dir), "--output-last-message", str(output_path), "-",
        ]
        try:
            self.process = await asyncio.create_subprocess_exec(
                *command,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.PIPE,
            )
            _, stderr = await self.process.communicate(prompt.encode("utf-8"))
            returncode = self.process.returncode
            summary = output_path.read_text(encoding="utf-8", errors="replace").strip()
            summary = " ".join(summary.split())

            if returncode == 0:
                await self.chat(summary[:180] if summary else "changes completed")
                await self.chat("rebuilding scripts")
                await self.send_console("rebuild()")
            else:
                error = stderr.decode("utf-8", errors="replace").strip().splitlines()
                detail = error[-1] if error else f"exit code {returncode}"
                await self.chat(f"request failed: {detail}")
        finally:
            output_path.unlink(missing_ok=True)

    async def connect_once(self) -> None:
        print(f"Connecting to TCPR at {self.args.host}:{self.args.port}...")
        reader, writer = await asyncio.open_connection(self.args.host, self.args.port)
        self.writer = writer
        writer.write((self.password + "\n").encode("utf-8"))
        await writer.drain()
        print("Connected. Use !codex <request> in moderator chat.")
        await self.chat("bridge connected")
        try:
            while data := await reader.readline():
                await self.handle_line(data.decode("utf-8", errors="replace"))
        finally:
            self.writer = None
            writer.close()
            with contextlib.suppress(Exception):
                await writer.wait_closed()

    async def run(self) -> None:
        asyncio.create_task(self.worker())
        delay = 1
        while True:
            try:
                await self.connect_once()
                delay = 1
            except (ConnectionError, OSError) as exc:
                print(f"TCPR unavailable ({exc}); retrying in {delay}s", file=sys.stderr)
            await asyncio.sleep(delay)
            delay = min(delay * 2, 15)


def parse_args() -> argparse.Namespace:
    default_mod = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=50301)
    parser.add_argument("--mod-dir", type=Path, default=default_mod)
    parser.add_argument("--codex", default=shutil.which("codex") or "codex")
    parser.add_argument("--max-queue", type=int, default=5)
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    password = os.environ.get("KAG_TCPR_PASSWORD") or getpass.getpass("KAG TCPR password: ")
    if not password:
        raise SystemExit("A TCPR password is required")
    await Bridge(args, password).run()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
