#!/usr/bin/env python3
"""Trigger and observe one fresh focused AIBTest run through authenticated TCPR."""

from __future__ import annotations

import argparse
import json
import re
import socket
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path

from tcpr_send import config_value, connect_when_ready


EXPECTED_BRIDGE_VERSION = 3
REBUILD_FAILURE_RE = re.compile(
    r"(?im)^.*(?:ERROR .*GuiftsDynamicBlueprint_vDev.*\.as:|"
    r"Rules partially failed initialization|Script .* has errors).*$"
)


@dataclass(frozen=True)
class State:
    phase: str
    query: int
    done: bool
    scenario: str
    status: str
    game_time: int


class TCPRChannel:
    def __init__(self, connection: socket.socket) -> None:
        self.connection = connection
        self.received = ""

    def send(self, expression: str) -> None:
        if "\r" in expression or "\n" in expression:
            raise ValueError("TCPR expressions must be single-line")
        self.connection.sendall((expression + "\n").encode("utf-8"))

    def wait_for(self, pattern: re.Pattern[str], deadline: float) -> re.Match[str] | None:
        while time.monotonic() < deadline:
            match = pattern.search(self.received)
            if match is not None:
                return match
            remaining = deadline - time.monotonic()
            self.connection.settimeout(max(0.01, min(0.15, remaining)))
            try:
                data = self.connection.recv(65536)
            except socket.timeout:
                continue
            if not data:
                raise ConnectionError("TCPR closed the connection")
            self.received += data.decode("utf-8", errors="replace")
            if len(self.received) > 1_000_000:
                self.received = self.received[-500_000:]
        return pattern.search(self.received)


def marker_expression(kind: str, run_id: str) -> str:
    # Assemble the record at runtime so an echoed command cannot satisfy it.
    return f'tcpr("AIBFAST" + "|{kind}|id={run_id}")'


def state_expression(run_id: str, phase: str, query: int) -> str:
    prefix = f"|STATE|id={run_id}|phase={phase}|q={query}|done="
    return (
        f'tcpr("AIBFAST" + "{prefix}" + '
        '(getRules().get_bool("aib tests done") ? "1" : "0") + '
        '"|scenario=" + getRules().get_string("aib test scenario") + '
        '"|status=" + getRules().get_string("aib test display status") + '
        '"|t=" + getGameTime())'
    )


def state_pattern(run_id: str, phase: str, query: int) -> re.Pattern[str]:
    return re.compile(
        rf"AIBFAST\|STATE\|id={re.escape(run_id)}"
        rf"\|phase={re.escape(phase)}\|q={query}"
        r"\|done=([01])\|scenario=([^|\r\n]*)"
        r"\|status=([^|\r\n]*)\|t=(\d+)"
    )


def query_state(
    channel: TCPRChannel,
    run_id: str,
    phase: str,
    query: int,
    deadline: float,
    response_seconds: float,
) -> State | None:
    channel.send(state_expression(run_id, phase, query))
    response_deadline = min(deadline, time.monotonic() + response_seconds)
    match = channel.wait_for(state_pattern(run_id, phase, query), response_deadline)
    if match is None:
        return None
    return State(
        phase=phase,
        query=query,
        done=match.group(1) == "1",
        scenario=match.group(2),
        status=match.group(3),
        game_time=int(match.group(4)),
    )


def wait_for_state(
    channel: TCPRChannel,
    run_id: str,
    phase: str,
    deadline: float,
    poll_seconds: float,
    predicate,
) -> State:
    query = 0
    last_state: State | None = None
    while time.monotonic() < deadline:
        state = query_state(
            channel,
            run_id,
            phase,
            query,
            deadline,
            max(0.25, poll_seconds * 2.0),
        )
        query += 1
        if state is not None:
            last_state = state
            if predicate(state):
                return state
        remaining = deadline - time.monotonic()
        if remaining > 0.0:
            time.sleep(min(poll_seconds, remaining))
    detail = "no state response" if last_state is None else (
        f"last state done={int(last_state.done)} scenario={last_state.scenario!r} "
        f"status={last_state.status!r} t={last_state.game_time}"
    )
    raise TimeoutError(f"timed out waiting for {phase} state ({detail})")


def append_metric(path: Path | None, record: dict[str, object]) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(record, separators=(",", ":")) + "\n")


def parse_path_metrics(
    text: str,
    epoch: int,
    bridge_version: int,
    scenario: str,
) -> dict[str, int] | None:
    pattern = re.compile(
        rf"AIBFAST\|PATH_METRICS\|epoch={epoch}\|bridge={bridge_version}"
        rf"\|scenario={re.escape(scenario)}\|([^\r\n]*)"
    )
    match = pattern.search(text)
    if match is None:
        return None
    result: dict[str, int] = {}
    for field in match.group(1).split("|"):
        if "=" not in field:
            continue
        key, value = field.split("=", 1)
        if re.fullmatch(r"-?\d+", value):
            result[key] = int(value)
    return result


def parse_ai_path_events(text: str, scenario: str) -> dict[str, int | None]:
    prefix = (
        rf"\[AIBEVT\] t=(\d+)[^\r\n]*\bscenario={re.escape(scenario)}\b"
        rf"[^\r\n]*\bsource=ai action="
    )
    path_set_ticks = [int(value) for value in re.findall(prefix + r"path_set\b", text)]
    path_replan_ticks = [
        int(value) for value in re.findall(prefix + r"path_replan\b", text)
    ]
    return {
        "path_set_count": len(path_set_ticks),
        "path_replan_event_count": len(path_replan_ticks),
        "first_path_set_tick": path_set_ticks[0] if path_set_ticks else None,
        "first_path_replan_tick": path_replan_ticks[0]
        if path_replan_ticks
        else None,
    }


def parse_fixture_verdict(text: str, scenario: str) -> dict[str, object]:
    passed = re.search(
        rf"\[AIBTEST\] PASS {re.escape(scenario)} ticks=(\d+)"
        r"([^\r\n]*?)\s*\[AIBTEST\] DONE\b",
        text,
    )
    if passed is not None:
        return {
            "ticks": int(passed.group(1)),
            "details": passed.group(2).strip(),
            "failure": None,
        }
    failed = re.search(
        rf"\[AIBTEST\] FAIL {re.escape(scenario)} reason="
        r"([^\r\n]*?)\s*\[AIBTEST\] DONE\b",
        text,
    )
    if failed is not None:
        return {"ticks": None, "details": "", "failure": failed.group(1).strip()}
    return {"ticks": None, "details": "", "failure": "verdict_text_not_observed"}


def derive_scenario_ticks(
    path_metrics: dict[str, int], fixture_verdict: dict[str, object]
) -> tuple[int | None, str | None]:
    verdict_ticks = fixture_verdict.get("ticks")
    if isinstance(verdict_ticks, int):
        return verdict_ticks, "fixture_verdict"
    start_tick = path_metrics.get("start_t")
    end_tick = path_metrics.get("end_t")
    if start_tick is not None and end_tick is not None and end_tick >= start_tick:
        return end_tick - start_tick, "path_metrics_interval"
    return None, None


def compile_failures(text: str) -> list[str]:
    return [match.group(0).strip() for match in REBUILD_FAILURE_RE.finditer(text)]


def emit_compile_failure(
    args: argparse.Namespace,
    run_id: str,
    wall_start: float,
    connected_at: float,
    ready_at: float,
    rebuild_ms: float | None,
    failures: list[str],
) -> None:
    record: dict[str, object] = {
        "schema": 4,
        "run_id": run_id,
        "mode": "hot",
        "scenario": args.scenario,
        "outcome": "compile_error",
        "total_ms": round((time.monotonic() - wall_start) * 1000.0, 1),
        "connect_ms": round((connected_at - wall_start) * 1000.0, 1),
        "ready_ms": round((ready_at - wall_start) * 1000.0, 1),
        "rebuild_ms": None if rebuild_ms is None else round(rebuild_ms, 1),
        "compile_stream_checked": True,
        "compile_errors": failures[-12:],
    }
    append_metric(args.metrics, record)
    print("AIBFAST_RESULT " + json.dumps(record, separators=(",", ":")))
    print("AIBFAST COMPILE_ERROR", file=sys.stderr)
    for line in failures[-12:]:
        print(line, file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int)
    parser.add_argument("--connect-timeout-seconds", type=float, default=60.0)
    parser.add_argument("--rules-ready-timeout-seconds", type=float, default=45.0)
    parser.add_argument("--timeout-seconds", type=float, default=90.0)
    parser.add_argument("--auth-delay-ms", type=int, default=300)
    parser.add_argument("--rebuild", action="store_true")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--metrics", type=Path)
    args = parser.parse_args()

    if not args.scenario.strip():
        parser.error("--scenario cannot be blank")
    if args.connect_timeout_seconds <= 0.0:
        parser.error("--connect-timeout-seconds must be positive")
    if args.rules_ready_timeout_seconds <= 0.0:
        parser.error("--rules-ready-timeout-seconds must be positive")
    if args.timeout_seconds <= 0.0:
        parser.error("--timeout-seconds must be positive")
    if args.auth_delay_ms < 0:
        parser.error("auth delay cannot be negative")

    run_id = args.run_id or uuid.uuid4().hex[:12]
    if re.fullmatch(r"[A-Za-z0-9_-]{1,48}", run_id) is None:
        parser.error("--run-id must contain only letters, digits, underscore, or hyphen")

    config_text = args.config.read_text(encoding="utf-8", errors="replace")
    password = config_value(config_text, "sv_rconpassword")
    if not password:
        raise SystemExit("sv_rconpassword is missing or blank")
    port = args.port or int(config_value(config_text, "sv_port") or "50301")

    wall_start = time.monotonic()
    try:
        connection = connect_when_ready(
            args.host,
            port,
            args.connect_timeout_seconds,
            0.2,
        )
    except TimeoutError as error:
        print(f"AIBFAST CONNECT_ERROR {error}", file=sys.stderr)
        return 4

    connected_at = time.monotonic()
    with connection:
        channel = TCPRChannel(connection)
        connection.settimeout(0.15)
        connection.sendall((password + "\n").encode("utf-8"))
        time.sleep(args.auth_delay_ms / 1000.0)

        try:
            channel.send(marker_expression("READY", run_id))
            ready_pattern = re.compile(
                rf"AIBFAST\|READY\|id={re.escape(run_id)}"
            )
            ready_deadline = time.monotonic() + 10.0
            if channel.wait_for(ready_pattern, ready_deadline) is None:
                print("AIBFAST PROTOCOL_ERROR explicit READY was not returned", file=sys.stderr)
                return 6
            ready_at = time.monotonic()

            channel.send(f'print("AIBFAST" + "|FULL|id={run_id}")')
            full_pattern = re.compile(
                rf"AIBFAST\|FULL\|id={re.escape(run_id)}"
            )
            if channel.wait_for(full_pattern, time.monotonic() + 10.0) is None:
                print(
                    "AIBFAST PROTOCOL_ERROR full TCPR forwarding is unavailable",
                    file=sys.stderr,
                )
                return 6

            preflight_deadline = time.monotonic() + args.rules_ready_timeout_seconds
            preflight = wait_for_state(
                channel,
                run_id,
                "pre",
                preflight_deadline,
                0.25,
                lambda _state: True,
            )

            rebuild_ms: float | None = None
            rebuild_offset: int | None = None
            if args.rebuild:
                rebuild_start = time.monotonic()
                rebuild_offset = len(channel.received)
                channel.send("rebuild()")
                channel.send(marker_expression("REBUILT", run_id))
                rebuilt_pattern = re.compile(
                    rf"AIBFAST\|REBUILT\|id={re.escape(run_id)}"
                )
                if channel.wait_for(rebuilt_pattern, time.monotonic() + 30.0) is None:
                    print("AIBFAST REBUILD_ERROR completion marker was not returned", file=sys.stderr)
                    return 7
                rebuild_ms = (time.monotonic() - rebuild_start) * 1000.0
                failures = compile_failures(channel.received[rebuild_offset:])
                if failures:
                    emit_compile_failure(
                        args,
                        run_id,
                        wall_start,
                        connected_at,
                        ready_at,
                        rebuild_ms,
                        failures,
                    )
                    return 7

            request_at = time.monotonic()
            run_stream_offset = len(channel.received)
            channel.send(marker_expression("SERVER_REQUEST", run_id))
            request_pattern = re.compile(
                rf"AIBFAST\|SERVER_REQUEST\|id={re.escape(run_id)}"
            )
            if channel.wait_for(request_pattern, time.monotonic() + 10.0) is None:
                print("AIBFAST PROTOCOL_ERROR request marker was not returned", file=sys.stderr)
                return 6
            channel.send(
                'getRules().SendCommand(getRules().getCommandID('
                '"aibfast server restart"), CBitStream())'
            )

            run_deadline = request_at + args.timeout_seconds
            ack_pattern = re.compile(
                r"AIBFAST\|SERVER_ACK\|epoch=(\d+)\|bridge=(\d+)\|t=(\d+)"
            )
            ack = channel.wait_for(ack_pattern, run_deadline)
            if ack is None:
                print(
                    "AIBFAST SERVER_ERROR restart command produced no server ACK",
                    file=sys.stderr,
                )
                return 9
            ack_at = time.monotonic()
            epoch = int(ack.group(1))
            bridge_version = int(ack.group(2))
            ack_game_time = int(ack.group(3))
            if bridge_version != EXPECTED_BRIDGE_VERSION:
                print(
                    f"AIBFAST VERSION_ERROR expected bridge {EXPECTED_BRIDGE_VERSION}, "
                    f"received {bridge_version}",
                    file=sys.stderr,
                )
                return 10

            done_pattern = re.compile(
                rf"AIBFAST\|SERVER_DONE\|epoch={epoch}\|bridge={bridge_version}"
                r"\|outcome=(pass|fail)\|scenario=([^|\r\n]*)"
                r"\|status=([^|\r\n]*)\|t=(\d+)"
            )
            done = channel.wait_for(done_pattern, run_deadline)
            if done is None:
                states = re.findall(
                    rf"AIBFAST\|SERVER_STATE\|epoch={epoch}\|bridge={bridge_version}"
                    r"\|done=([01])\|scenario=([^|\r\n]*)"
                    r"\|status=([^|\r\n]*)\|t=(\d+)",
                    channel.received,
                )
                detail = "no server state" if not states else (
                    f"last done={states[-1][0]} scenario={states[-1][1]!r} "
                    f"status={states[-1][2]!r} t={states[-1][3]}"
                )
                print(
                    f"AIBFAST TIMEOUT no server verdict after "
                    f"{args.timeout_seconds:g}s; {detail}",
                    file=sys.stderr,
                )
                return 5

            done_at = time.monotonic()
            outcome = done.group(1)
            server_scenario = done.group(2)
            status = done.group(3)
            server_game_time = int(done.group(4))
            run_stream = channel.received[run_stream_offset:]
            path_metrics = parse_path_metrics(
                run_stream,
                epoch,
                bridge_version,
                server_scenario,
            )
            if path_metrics is None:
                print(
                    "AIBFAST PROTOCOL_ERROR server verdict had no correlated path metrics",
                    file=sys.stderr,
                )
                return 6
            path_events = parse_ai_path_events(run_stream, server_scenario)
            fixture_verdict = parse_fixture_verdict(run_stream, server_scenario)
            scenario_ticks, scenario_ticks_source = derive_scenario_ticks(
                path_metrics, fixture_verdict
            )
            if rebuild_offset is not None:
                failures = compile_failures(channel.received[rebuild_offset:])
                if failures:
                    emit_compile_failure(
                        args,
                        run_id,
                        wall_start,
                        connected_at,
                        ready_at,
                        rebuild_ms,
                        failures,
                    )
                    return 7
            expected_pass = f"PASS - FROZEN: {args.scenario}"
            expected_fail = f"FAIL - FROZEN: {args.scenario}"
            record: dict[str, object] = {
                "schema": 4,
                "run_id": run_id,
                "mode": "hot" if args.rebuild else "cold",
                "scenario": args.scenario,
                "outcome": outcome,
                "total_ms": round((done_at - wall_start) * 1000.0, 1),
                "connect_ms": round((connected_at - wall_start) * 1000.0, 1),
                "ready_ms": round((ready_at - wall_start) * 1000.0, 1),
                "rebuild_ms": None if rebuild_ms is None else round(rebuild_ms, 1),
                "compile_stream_checked": args.rebuild,
                "request_to_ack_ms": round((ack_at - request_at) * 1000.0, 1),
                "ack_to_done_ms": round((done_at - ack_at) * 1000.0, 1),
                "request_to_done_ms": round((done_at - request_at) * 1000.0, 1),
                "server_epoch": epoch,
                "bridge_version": bridge_version,
                "server_ack_game_time": ack_game_time,
                "server_done_game_time": server_game_time,
                "status": status,
                "server_scenario": server_scenario,
                "preflight_status": preflight.status,
                "scenario_ticks": scenario_ticks,
                "scenario_ticks_source": scenario_ticks_source,
                "path_metrics": path_metrics,
                "path_events": path_events,
                "fixture_verdict": fixture_verdict,
            }
            append_metric(args.metrics, record)
            print("AIBFAST_RESULT " + json.dumps(record, separators=(",", ":")))
            if outcome == "pass" and server_scenario == args.scenario and status == expected_pass:
                return 0
            if outcome == "fail" and server_scenario == args.scenario and status == expected_fail:
                return 3
            print(
                "AIBFAST STATE_ERROR server verdict did not match the requested scenario",
                file=sys.stderr,
            )
            return 8
        except (ConnectionError, OSError, TimeoutError, ValueError) as error:
            print(f"AIBFAST PROTOCOL_ERROR {error}", file=sys.stderr)
            return 6


if __name__ == "__main__":
    raise SystemExit(main())
