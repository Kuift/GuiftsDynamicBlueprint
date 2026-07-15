#!/usr/bin/env python3
"""Send authenticated local KAG TCPR console expressions without echoing secrets."""

from __future__ import annotations

import argparse
import re
import socket
import sys
import time
from pathlib import Path


def config_value(text: str, name: str) -> str | None:
    match = re.search(rf"(?m)^\s*{re.escape(name)}\s*=\s*([^#\r\n]*)", text)
    return match.group(1).strip() if match else None


def connect_when_ready(
    host: str,
    port: int,
    timeout_seconds: float,
    retry_delay_seconds: float,
) -> socket.socket:
    """Connect once TCPR is accepting connections, within one overall deadline."""
    deadline = time.monotonic() + timeout_seconds
    attempts = 0
    last_error: OSError | None = None
    while True:
        attempts += 1
        remaining = deadline - time.monotonic()
        if remaining <= 0.0:
            detail = f": {last_error}" if last_error is not None else ""
            raise TimeoutError(
                f"TCPR at {host}:{port} was not ready within "
                f"{timeout_seconds:g}s after {attempts - 1} attempt(s){detail}"
            )
        try:
            return socket.create_connection(
                (host, port),
                timeout=max(0.05, min(1.0, remaining)),
            )
        except OSError as error:
            last_error = error
            remaining = deadline - time.monotonic()
            if remaining <= 0.0:
                continue
            time.sleep(min(retry_delay_seconds, remaining))


def connect_when_stable(
    host: str,
    port: int,
    timeout_seconds: float,
    retry_delay_seconds: float,
    stability_seconds: float,
) -> socket.socket:
    """Return a TCPR socket that has survived the requested startup window.

    KAG opens TCPR before its localhost client/rules restart is necessarily
    complete. That restart can reset an otherwise successful early connection.
    Peek without consuming output and reconnect inside the original deadline
    until one socket remains live for the full stability window.
    """
    deadline = time.monotonic() + timeout_seconds
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0.0:
            raise TimeoutError(
                f"TCPR at {host}:{port} did not remain stable for "
                f"{stability_seconds:g}s within {timeout_seconds:g}s"
            )
        connection = connect_when_ready(
            host,
            port,
            remaining,
            retry_delay_seconds,
        )
        if stability_seconds <= 0.0:
            return connection

        stable_until = time.monotonic() + stability_seconds
        reset = False
        connection.settimeout(0.2)
        while time.monotonic() < stable_until:
            try:
                if connection.recv(1, socket.MSG_PEEK) == b"":
                    reset = True
                    break
            except socket.timeout:
                pass
            except OSError:
                reset = True
                break
            time.sleep(0.05)
        if not reset:
            return connection
        connection.close()
        remaining = deadline - time.monotonic()
        if remaining > 0.0:
            time.sleep(min(retry_delay_seconds, remaining))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int)
    parser.add_argument(
        "--connect-timeout-seconds",
        type=float,
        default=5.0,
        help="Overall readiness deadline; connection attempts are retried until it expires",
    )
    parser.add_argument("--retry-delay-ms", type=int, default=200)
    parser.add_argument(
        "--stability-seconds",
        type=float,
        default=0.0,
        help="Require the connected socket to survive this startup window before sending",
    )
    parser.add_argument("--delay-ms", type=int, default=250)
    parser.add_argument("--command", action="append", required=True)
    parser.add_argument("--listen-seconds", type=float, default=0.0)
    parser.add_argument(
        "--transcript",
        type=Path,
        help="Persist received TCPR output incrementally as UTF-8 text",
    )
    parser.add_argument("--expect", help="Regular expression that must appear in TCPR output")
    parser.add_argument(
        "--fail",
        help="Regular expression that ends listening immediately with exit code 3",
    )
    args = parser.parse_args()

    if args.connect_timeout_seconds <= 0.0:
        parser.error("--connect-timeout-seconds must be positive")
    if args.retry_delay_ms < 0:
        parser.error("--retry-delay-ms cannot be negative")
    if args.stability_seconds < 0.0:
        parser.error("--stability-seconds cannot be negative")
    if args.listen_seconds < 0.0:
        parser.error("--listen-seconds cannot be negative")
    if args.transcript is not None:
        args.transcript.parent.mkdir(parents=True, exist_ok=True)
        args.transcript.write_text("", encoding="utf-8")

    text = args.config.read_text(encoding="utf-8", errors="replace")
    password = config_value(text, "sv_rconpassword")
    if not password:
        raise SystemExit("sv_rconpassword is missing or blank")
    port = args.port or int(config_value(text, "sv_port") or "50301")

    retry_delay_seconds = args.retry_delay_ms / 1000.0
    try:
        connection = connect_when_stable(
            args.host,
            port,
            args.connect_timeout_seconds,
            retry_delay_seconds,
            args.stability_seconds,
        )
    except TimeoutError as error:
        print(error, file=sys.stderr)
        return 4

    with connection:
        connection.settimeout(0.2)
        connection.sendall((password + "\n").encode("utf-8"))
        time.sleep(max(args.delay_ms, 0) / 1000.0)
        for command in args.command:
            if "\n" in command or "\r" in command:
                raise SystemExit("TCPR commands must be single-line expressions")
            connection.sendall((command + "\n").encode("utf-8"))
            time.sleep(max(args.delay_ms, 0) / 1000.0)
        expected = re.compile(args.expect) if args.expect else None
        failed = re.compile(args.fail) if args.fail else None
        listen_seconds = args.listen_seconds
        if (expected is not None or failed is not None) and listen_seconds <= 0.0:
            listen_seconds = 10.0
        deadline = time.monotonic() + max(listen_seconds, 0.0)
        received = ""
        while time.monotonic() < deadline:
            try:
                data = connection.recv(65536)
            except socket.timeout:
                continue
            if not data:
                break
            text = data.decode("utf-8", errors="replace")
            received += text
            if args.transcript is not None:
                with args.transcript.open("a", encoding="utf-8", newline="") as stream:
                    stream.write(text)
                    stream.flush()
            print(text, end="", flush=True)
            if failed is not None and failed.search(received):
                print(f"Failure TCPR pattern was observed: {args.fail}")
                return 3
            if expected is not None and expected.search(received):
                break
        if expected is not None and expected.search(received) is None:
            print(f"Expected TCPR pattern was not observed: {args.expect}")
            return 2
    print(f"Sent {len(args.command)} authenticated TCPR command(s) to {args.host}:{port}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
