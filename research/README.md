# KAG Engine Research

Project entry point: [START_HERE.md](../START_HERE.md). Follow
[GOAL_HANDOFF.md](../GOAL_HANDOFF.md) for the runtime pause and current priorities.
The source/contract-check goal below is historical: source-text behavioral tests
were retired. [RUNTIME_TESTING.md](../RUNTIME_TESTING.md) owns current evidence
policy; offline tests validate tools, and AngelScript requires visible KAG.

This directory contains clean-room tooling and derived observations used to
make Builder-AI development faster and more measurable. It must not contain a
copy of `KAG.exe`, a companion debug file, bulk strings, disassembly, or bulk
decompiler output.

## Goal

Build a tight Builder-AI loop with three progressively stronger gates:

1. sub-second source/contract checks for every edit;
2. a persistent visible KAG session that rebuilds scripts and reruns one focused
   canonical scenario without paying process startup on each edit;
3. reproducible behavior/quality batches whose records distinguish AI failure
   from an engine-wide simulation stall.

Gate 2 is now operational on build 4762. Base's `AutoRebuild.as` confirms that
`rebuild()` is the supported development path. The research loop keeps one
visible localhost process, sends a client rules command to a research-only
server bridge, calls the real server-side `CRules.RestartRules()`, and receives
explicit TCPR ACK/state/verdict records. It does not use the console file as a
completion authority.

The first native trace corrected an important assumption: the localhost
console file can stop growing while rules ticks and the target script hook keep
executing. See `notes/BUILD_4762_TICK_TRACE.md`. The explicit server TCPR
channel now supplies the missing non-file completion boundary. A stopped log
remains an observation failure, not proof of a stopped simulation.

## Ordinary Builder pathing result

The current Builder does not normally delegate its route to native `CBrain`.
CTF and AIBTest load `Pathing/PathingNodes.as`; `AIB_GoTo` therefore uses the
mod's `BrainPath` A* implementation and writes runner inputs through
`CBlob.setKeyPressed`. Native `CBrain.SetPathTo`/`SetSuggestedKeys` is an
isolated fallback when the custom node map/path is unavailable or unusable.
Specialized recovery and mining controllers can own keys directly.

The clean-room native dispatch map, callback ordering, exact runtime cohorts,
working-mod comparison, and uncertainties are in
`notes/BUILD_4762_BUILDER_PATHING_MAP.md`. The machine-readable selected cohort
is `generated/pathing_evidence_summary.json`; raw run records stay ignored in
`research/private/fast_loop/runs.ndjson`.

To reproduce only the final selected cohort from the local raw records:

```powershell
$runIds = @(
  '0cbf13f25328','ec1590929a98','9db84e5ca32c',
  'a3a459407f76','c31a1722445a','ba90d9fd400b',
  '61ce3b2c9f5c','eb516cd1b31f','8fb773b8676d',
  '06f43f2255b9','bf18e7695c5f','ebed9e0f4fa1'
)
.\research\tools\Get-AIBPathRunSummary.ps1 -RunId $runIds -Aggregate
```

The space-heavy Ghidra project, JDK, and raw exporter output remain under
`E:\Tools\KAGResearch`; only focused exporters and derived findings live here.
The next engine phase is `CBlob` lifecycle and attachment/ownership, not a
broader claim that engine research is finished.

## Fast focused loop

From the mod root:

```powershell
# One visible cold setup; leaves only this research-owned KAG process open.
.\research\tools\Invoke-PersistentAIBTest.ps1 -Action Start -Scenario strategic_remaining_material_cost

# After an edit: rebuild scripts and run a fresh server-side focused fixture.
.\research\tools\Invoke-PersistentAIBTest.ps1 -Action Run -Scenario strategic_remaining_material_cost

# Always finish the active iteration session this way.
.\research\tools\Invoke-PersistentAIBTest.ps1 -Action Stop
```

The final same-PID edit proof started bridge protocol 1, changed the source and
client expectation to protocol 2 while PID 21240 remained open, then returned
an exact protocol-2 server PASS. That hot run took 2.2 seconds wall-clock:
`rebuild()` returned in 156 ms, the server acknowledged the restart request in
484 ms, and the fresh verdict arrived 594 ms after the request. A separate
same-PID scenario switch returned the newly selected scenario in 2.0 seconds,
ruling out replay of the prior frozen result.

The final clean smoke after all guards were enabled recorded 3.969 seconds for
the one-time cold setup and 1.219 seconds internally for a hot rebuild plus
scenario switch (`2.0` seconds including PowerShell/tool startup). The hot
record had `compile_stream_checked=true`, rebuild 141 ms, and a fresh exact
server verdict 578 ms after request.

The controller enables full TCPR forwarding only for the owned research
process so the bounded `rebuild()` transaction is also observable. A controlled
syntax error in `AIBFastServerBridge.as` was rejected in 1.8 seconds with four
exact compiler errors, before a server restart or verdict was accepted. The
failure path closed KAG and restored `sv_tcpr_everything = false`.

Machine-readable measurements append to ignored
`research/private/fast_loop/runs.ndjson`; successful, scenario-failure, and
compile-failure records retain wall-clock/rebuild/server timing as applicable.
Run the offline wiring regression with:

```powershell
Validate the loop by launching visible KAG and observing an authoritative TCPR ACK, in-game verdict, and clean CTF handoff; source-text inspection is not runtime evidence.
```

## Boundaries

- Never modify the KAG `Base` directory or the installed executable/libraries.
- Runtime tests stay visible.
- Close every research-started KAG process after an evidence run, then verify
  it is gone before restoring CTF startup settings.
- Treat native pseudocode and string proximity as hypotheses. Promote a claim
  to `KAG_ENGINE_QUIRKS.md` only after a reliable behavioral reproduction.
- Keep raw native-analysis artifacts in `research/private/`, which is ignored.
- Derived API names, signatures already published by KAG's generated manual,
  hashes, measurements, and clean-room behavioral notes may live in the
  tracked part of this directory.

## Layout

- `tools/` — reproducible inventory, fingerprint, and loop utilities.
- `runtime/` — research-only KAG launch/rules bridge files.
- `generated/` — deterministic, non-proprietary derived reports.
- `notes/` — hypotheses, evidence records, and loop design decisions.
- `private/` — ignored small local records/traces; space-heavy native projects
  and raw output belong under `E:\Tools\KAGResearch` on this installation.

## Current static footholds

- The installed executable is a stripped 64-bit PE built with MinGW tooling.
- It retains a `.gnu_debuglink` naming `KAG.exe.debug`, although that companion
  file is not installed.
- The installation contains generated AngelScript interface documentation for
  build 4762 under `Manual/interface`; this is the authoritative declaration
  catalog for the installed build.
- The executable retains engine source-path and declaration strings, allowing
  targeted binding analysis even without the companion debug file.
- Irrlicht and Box2D are linked into the engine. Their precise upstream versions
  are not yet established; KAG wrapper behavior remains the relevant contract.

Run the safe static reports from the mod root:

```powershell
python .\research\tools\build_api_inventory.py
.\research\tools\Get-KagEngineFingerprint.ps1
```
