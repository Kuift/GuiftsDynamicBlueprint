# Persistent AIBTest Loop Design

## Baseline bottlenecks

`Tools/run_aib_tests.ps1` is a safe cold launcher, but it is intentionally not
an edit loop. Each invocation:

1. edits the AIBTest selection in `gamemode.cfg`;
2. temporarily disables the colliding mod CTF `gamemode.cfg`;
3. launches a new visible `KAG.exe` and loads the map/client/rules;
4. polls every 500 ms and rereads each candidate console log in full;
5. waits for the final `DONE` record and leaves KAG open by default;
6. restores files, while KAG may later rewrite root `autoconfig.cfg` on exit.

The fixed startup and map load dominate fast strategic fixtures that resolve in
one or two game ticks. Repeated full-log reads add avoidable host-side work.

## Validated loop

One research-owned visible AIBTest process remains alive only during an active
iteration session:

```text
edit -> authenticated TCPR rebuild()
     -> bounded full-TCPR compile transaction / error gate
     -> client CRules.SendCommand("aibfast server restart")
     -> research server bridge: CRules.RestartRules()
     -> canonical AIBTest cleanup/setup
     -> explicit TCPR SERVER_ACK / SERVER_STATE / SERVER_DONE
```

The controller must:

- validate the scenario name against `AIBT_SCENARIOS`;
- snapshot every temporarily changed file and record the exact owned PID;
- authenticate before sending expressions and prove the explicit TCPR channel
  with a unique request marker;
- prove full forwarding is active, then reject any mod compiler/rules error
  observed between the rebuild trigger and fresh server verdict;
- accept a verdict only after a fresh server epoch ACK;
- require exact server scenario, PASS/FAIL status, and bridge protocol version;
- distinguish connection, protocol, rebuild, missing server ACK, timeout,
  scenario failure, and version mismatch;
- stop the owned process before restoring CTF settings;
- restore blank AIBTest selection plus CTF/blank-cycle/shuffle-true handoff;
- support a debounced watch mode only after manual one-shot reruns are proven.

The console file is diagnostic only and is not read by the persistent runner.
Metrics append as schema-4 NDJSON under
`research/private/fast_loop/runs.ndjson`; compile failures retain the bounded
compiler diagnostics as well as wall/rebuild timing.

## Runtime answers on build 4762 (2026-07-15)

- `sv_tcpr_everything = false` does not forward ordinary `print()` output.
  Explicit `tcpr(...)` records work in selective mode. The research controller
  starts its owned process with full forwarding so compiler diagnostics are
  visible, then restores selective mode at handoff; trying to toggle the
  already-running listener did not begin forwarding ordinary prints.
- An inbound localhost TCPR expression observes the client `CRules`; directly
  calling `LoadRules(...)` produced a client BOOTING rules object but did not
  start the server-only runner.
- `RestartRules()` is not a useful global console expression. The working API
  is the server-side method `CRules.RestartRules()`, reached through a normal
  rules command.
- A server restart resets the AIBTest rule clock: the final edit-proof run ACKed
  at game time 692 and completed the fresh fixture at game time 6.
- Same-PID source consumption is proven. PID 21240 started with bridge protocol
  1; the bridge and client expectation were changed to protocol 2 while it
  stayed open; the hot run returned protocol 2 and an exact server PASS.
- That edit-to-verdict run took 2.2 seconds wall-clock. `rebuild()` returned in
  156 ms; request-to-ACK was 484 ms; ACK-to-DONE was 110 ms; total server
  request-to-DONE was 594 ms.
- A same-PID switch from `strategic_remaining_material_cost` to
  `tree_selection_toggle_filtering` returned the new exact server scenario in
  2.0 seconds, so the controller did not replay the frozen prior verdict.
- A deliberate missing-expression compile fault in the research bridge emitted
  four exact AngelScript errors, returned compile-failure exit code 7 in 1.8
  seconds, skipped the server restart, closed KAG, and restored CTF/selective
  TCPR settings.
- The final guarded smoke recorded 3.969 seconds internally for cold setup and
  1.219 seconds for a hot rebuild plus scenario switch (2.0 seconds including
  PowerShell/tool startup). The hot record checked the compile stream, rebuilt
  in 141 ms, and received the fresh exact server verdict 578 ms after request.

The remaining calibration task is broader physical/canonical coverage: run a
representative long movement or construction fixture across repeated hot
epochs and compare its final world fingerprint. The basic edit/rebuild/server
restart/verdict mechanism is no longer hypothetical.

## Build-4762 observation correction (2026-07-15)

Do not equate a stopped console file with a stopped simulation. In a visible
minimal localhost run, the file ended after `Waiting for scripts...` and an
`[AIBMIN]` heartbeat at game time 30. Read-only native traces taken afterward
showed all of the following while the file remained unchanged:

- the main engine callback had its pause byte clear;
- the active rules object stayed initialized and enabled;
- the rules tick field advanced from 905 through 912;
- the network/state-stream scheduler callback remained enabled;
- the compiled `aibresearchminimalprobe` `onTick` hook remained non-null,
  error-free, and was passed to the per-script dispatcher on consecutive
  cycles.

The previous log-only classifier therefore cannot prove a global simulation
stall. It can prove only that the observation channel stopped. Treat old
focused results that ended at the last log heartbeat as inconclusive unless a
separate physical/state outcome also stopped.

The validated server bridge is the independent state channel. A ConfigFile
side-channel prototype compiled but did not produce the expected Cache file
and was removed; do not repeat it without first establishing the autostart
callback/write-path lifecycle.

## Metric layers

- Harness latency: edit/trigger to compile result, fixture start, and verdict.
- Engine health: game-time advance, heartbeat advance, log advance, process and
  window responsiveness.
- AI intent: state, target, path, keys, reservation, and controller ownership.
- Physical outcome: displacement, tile/blob mutation, inventory/resource delta,
  damage, completion, and elapsed advancing ticks.
- Quality: success rate and cost distributions within identical canonical
  fixture/version/seed cohorts. Never compare records across unmatched world
  fingerprints.
