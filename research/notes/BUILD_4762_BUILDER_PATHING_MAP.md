# Build 4762 Ordinary-Builder Pathing Map

This is a clean-room behavior map for the installed 64-bit KAG build 4762
(`KAG.exe` SHA-256 `59956793616fb1722713cbfa864e15e92fb82453dbb508ab4e0331f3ee54efcf`).
It covers the path from `AIBuilderBrain.as` through the engine interfaces that
affect ordinary runner movement. Raw Ghidra output stays on `E:` and is not part
of the mod.

## Primary result

Ordinary AI builders do not normally use native `CBrain` pathfinding in the
current CTF or AIBTest configuration. `AIB_GoTo` first uses the mod's
`BrainPath` implementation whenever the rules have a non-empty `node_map`.
Both gamemodes load `Pathing/PathingNodes.as`, so that is the normal route.

The custom route:

1. `AIBuilderBrain.onTick` selects the state-specific target or destination.
2. `AIB_GoTo` calls `AIB_GoToBrainPath`.
3. `BrainPath.SetPath`, `Tick`, `SetSuggestedKeys`, and `SetSuggestedAimPos`
   perform the high/low AngelScript A* and controller work.
4. `CMap` queries provide tile solidity, rays, blob overlap, ladders, water,
   barriers, and threats.
5. `CBlob.setKeyPressed` writes the runner input bits consumed by the normal
   movement/physics pipeline.
6. When a custom route is created or replaced, `brain.EndPath()` clears native
   path state so the two controllers do not compete.

`AIB_GoToFallback` is the only branch that calls native `CBrain.SetPathTo`,
inspects `CBrain::has_path/stuck/wrong_path`, and calls native
`CBrain.SetSuggestedKeys`. It is reached when the custom `BrainPath`/`node_map`
is unavailable, or when a custom search yields no usable path while the goal is
more than 24 px away. No required runtime cohort exercised that fallback, so
its concrete behavior remains an explicit uncertainty.

## Script trace

The relevant production path is:

```text
AIBuilderBrain.onTick
  -> AIB_Find*/AIB_Chop*/AIB_ReturnWood (state-specific goal)
  -> AIB_GoTo
     -> AIB_GoToBrainPath (normal CTF/AIBTest route)
        -> BrainPath.SetPath / Tick
        -> CMap tile, ray, and blob queries
        -> BrainPath.SetSuggestedKeys
        -> CBlob.setKeyPressed
        -> AIB_ScaleObstacles
     -> AIB_GoToFallback (only without a usable node_map/custom path)
        -> CBrain.SetPathTo / getState / SetSuggestedKeys
        -> CBlob.setKeyPressed via direct shortcuts and obstacle scaling
  -> RunnerMovement / contact handling / linked Box2D collision
  -> next observable CBlob position, old position, and contact flags
```

The wood path calls this controller when a tree is more than 32 px away, a log
is more than 28 px away, loose wood is more than 18 px away, or storage is more
than 34 px away. State transitions clear native and custom paths, stale keys,
targets, and destination state.

`PathingNodes.as` builds a 32-pixel high-level grid and an 8-pixel low-level
grid. In AIBTest, `onSetTile` returns early while a named scenario is active, so
dynamic node-map updates are intentionally suppressed during those fixtures.
That matters when interpreting tests which place recovery structures.

## AngelScript-to-native dispatch map

Addresses are preferred-image addresses for this exact executable and must not
be treated as a stable ABI.

| AngelScript API | Build-4762 native route | Focused interpretation |
|---|---|---|
| `CBrain.SetPathTo(Vec2f,bool)` | virtual member slot `+0xe8` | Native fallback path request. Concrete dynamic target is unresolved. |
| `CBrain.SetPathTo(Vec2f,int)` | virtual member slot `+0xf0` | Search-style overload; not used by this AI. |
| `CBrain.getPathPosition()` through `getPathPositionAtIndex()` | slots `+0xf8`, `+0x100`, `+0x108`, `+0x110` | Native path inspection used only by fallback. |
| `CBrain.SetSuggestedKeys()` | virtual member slot `+0x118` | Native path-to-input conversion used only by fallback. |
| `CBrain.getState()` | virtual member slot `+0x120` | Reports native brain state, not custom `BrainPath` state. |
| `CBrain.EndPath()` | direct target `0x14017f360` | Clears/frees native path containers and metadata. No input-bit write is visible in focused pseudocode; runtime proof of that negative claim is still absent. |
| `CBlob.getPosition()` | `0x1401655c0` | Direct read of the movement position snapshot. |
| `CBlob.getOldPosition()` | `0x1401655f0` | Direct read of the adjacent prior-position snapshot. |
| `CBlob.getVelocity()` | `0x1401656c0`, then movement virtual dispatch | Velocity remains movement-component owned. |
| `CBlob.setKeyPressed()` | `0x140165d70` | Immediate 16-bit read/modify/write of the input mask. |
| `CBlob.isKeyPressed()` | `0x140165cd0` | Immediate read/test of the same input mask. |
| `CBlob.isOnGround/Ladder/Wall()` | `0x140165a20`, `0x140165a60`, `0x140165ad0` | Direct reads of three adjacent movement contact bytes. |
| `CMap.getTile(Vec2f)` | `0x1401997f0` | World-to-tile conversion followed by a tile-record copy. |
| `CMap.isTileSolid(Vec2f)` | `0x1401a5780` | World-to-tile conversion and direct solidity-bit test. |
| `CMap.getBlobsInBox()` | `0x1401aae60` -> `0x1407ca4c0` | AngelScript array wrapper around an engine spatial/broadphase query. |
| `CMap.rayCastSolid()` | `0x1401acc90` -> `0x1401ac820` | Thin wrapper over the engine ray traversal; precise cache/reentrancy behavior remains untested. |

The `CBrain` registrar stores MinGW virtual-member encodings one greater than
their byte offsets (`0xe9`, `0xf1`, ..., `0x121`). This establishes the dispatch
slots but not the concrete vtable implementation selected by every brain
factory.

## Tick/callback ordering reproduced at runtime

The research bridge is a passive `CRules` script listed after
`AIBTestRunner.as`. The custom `path_set` event is emitted inside the builder's
brain callback before `BrainPath.Tick()` and `SetSuggestedKeys()`.

Across three final hill hot restarts, every run produced this sequence:

```text
game tick 6: CBrain callback emits custom path_set; later in that callback it writes keys
game tick 7: next CRules observer sample first sees destination and movement input
game tick 8: observer-to-observer horizontal displacement is first non-zero
```

This shows that, for these configured hooks, the rules observer for a tick runs
before the builder brain callback carrying the same `getGameTime()` value.
Input written by that brain callback is visible to the following rules sample;
horizontal physics is visible one further observer sample later. Spawn-time
`getOldPosition()` deltas were excluded because a new blob can begin with an
unrepresentative old snapshot.

Practical consequence: a rules-side monitor must correlate AI intent with the
next one or two samples. Treating “no displacement in the same rules tick” as a
stall would be an ordering bug. This result is scoped to the tested server-side
rules/brain/movement configuration; it is not a claim about every client hook
or networking callback.

## Repeatability evidence

All rows below are hot restarts with compile-stream checking. Cold setup runs
are excluded. Exact run IDs and machine-readable aggregates are in
`research/generated/pathing_evidence_summary.json`.

| Scenario | Result | Physical/controller measurements per run |
|---|---|---|
| `kag_path_moves_to_tree_over_hill` | 3/3 pass, 11 elapsed ticks | -13.6 px net x, 16.6 px total, 9 intent ticks, 8 horizontal-motion ticks, 0 stalls, 1 destination/state change, 10 obstruction-value changes (max 9), 1 custom path set/repath, native brain idle for 12/12 samples. |
| `flat_harvest_delivers_to_tent` | 3/3 pass, 21 elapsed ticks | -41.5 px net x, 44.5 px total, 19 intent ticks, 20 motion ticks, 0 stalls, 1 destination/state change, 18 obstruction-value changes (max 9), 1 custom path set/repath, native brain idle for 22/22 samples. |
| corrected `pathing_obstacle_recovery` | 3/3 pass, 45 elapsed ticks | +108.4 px net x, 111.4 px total, 43 intent ticks, 44 motion ticks, 0 stalls, 1 destination/state change, 23 obstruction-value changes (max 7), 1 custom path set/repath, native brain idle for 46/46 samples. |
| `stone_corner_escape_from_mirrored_upper_overhangs` | 3/3 independent hot passes, 37 elapsed ticks | +64.9 px tracked-side net x, 97.3 px total, full 36-tick direct escape/cooldown cycle, 4 isolated stall samples (longest 2), no destination/state/obstruction/path changes, native brain idle for 38/38 samples. |

After extending the detector to isolated one-sided upper diagonals, a fresh
visible process passed the revised mirrored fixture at tick 138 on 2026-07-15.
It observed both 36-tick direct drives, both 90-tick cooldown latches, at least
one tile of displacement on each side, and intact diagonal-only castle traps.
This supplements rather than replaces the earlier ceiling-plus-diagonal cohort.

The delivery cohort's 21-tick duration comes from the correlated passive
observer interval (`end_t - start_t = 26 - 5`) because those three older raw
records did not retain the adjacent textual fixture-verdict line. Their exact
server outcome, scenario, frozen PASS status, 22 samples, and physical metrics
are present in every record. The other three cohorts retain the explicit
fixture-verdict tick field. `Get-AIBPathRunSummary.ps1` reports the source of
each duration instead of treating a missing textual line as zero.

The corner fixture mutates terrain. A direct cold start or an immediate second
hot restart was rejected by the canonical hash guard before behavior began.
The three behavior runs therefore used separate clean processes: start on the
non-mutating hill fixture, then hot-switch once to the corner fixture. The
guard failure is setup evidence, not a recovery failure.

## Test conclusions and limitations

- The old `pathing_obstacle_recovery` verdict accepted a non-zero destination.
  Three pre-fix hot runs passed at elapsed tick 2 with zero horizontal movement
  and zero movement-intent samples; their only 0.4 px change was vertical blob
  settling. The fixture now requires physical entry into the obstacle region,
  and its three corrected runs are the cohort reported above.
- One exploratory `kag_path_builds_supported_ladder_chain` run travelled
  109.4 px and crossed the nominal far-side threshold without creating a
  recovery ladder or emitting a replan. It failed the fixture after 224
  samples. This does not validate path-cache refresh after ladder placement;
  the expected recovery branch was never exercised.
- A custom path event plus an idle native `CBrain` state distinguishes the
  normal controller from native fallback. The corner cohort shows the third
  mode: direct geometry-specific keys with neither pathfinder active.
- Native `CBrain` fallback still needs a dedicated isolated fixture that
  withholds `node_map` without changing production AI behavior.
- Renderer/camera behavior, network authority, and detailed Box2D contact
  resolution are outside this focused pathing result.

## Working-mod comparison

- `KAG_PATH-main` is the direct design ancestor of `Pathing/BrainPathing.as`;
  its example `KnightBrain.as` calls `BrainPath.Tick()` and custom
  `SetSuggestedKeys()` just like the normal Builder route.
- Base `BrainCommon.as`/`MigrantBrain.as` and installed `BAI` use the conventional
  native loop: `SetPathTo`, inspect `CBrain` state, and call
  `CBrain.SetSuggestedKeys()` only in `has_path`.
- `Hunter4D`, `Easy3D`, `Easy3DExampleMod`, and `EasyUI` contain no comparable
  2D `CBrain.SetPathTo`/`SetSuggestedKeys` use. They remain useful for their 3D,
  renderer, mesh, and UI domains, but they are not pathing evidence.

## Reusable artifacts

- `research/tools/ghidra/ExportKagPathingBindings.java` — focused declaration,
  xref, and registrar export.
- `research/tools/ghidra/ExportKagNativePathingTargets.java` — focused binding
  pointer/target export.
- `research/runtime/AIBFastServerBridge.as` — passive per-run path metrics and
  correlated TCPR verdict bridge.
- `research/tools/tcpr_aib_run.py` — schema-4 record collector.
- `research/tools/Get-AIBPathRunSummary.ps1` — local NDJSON detail/aggregate
  report with exact run-ID selection and explicit tick-source reporting.
- `research/tools/test_aib_path_evidence.ps1` — guards physical outcome and
  passive instrumentation contracts.

Raw native exports remain under `E:\Tools\KAGResearch\outputs`; the Ghidra
project is `E:\Tools\KAGResearch\projects\KAG-4762.gpr` plus its `.rep`
directory, and the Ghidra/JDK installations are also on `E:`. None of those
proprietary/raw artifacts are tracked or redistributed.

## Next focused investigation

This completes only the ordinary-pathing phase. The next engine-side target is
`CBlob` lifecycle plus attachment/ownership: map creation/`Init()` ordering,
brain/script activation, inventory transitions, `server_AttachTo` and detach
callbacks, carried-blob ownership, death/removal visibility, and which state is
observable in later rules ticks. Start with a small lifecycle probe and focused
bindings for only those APIs; do not broaden into the inventory-synchronization
phase until the lifecycle ordering is reproducible.
