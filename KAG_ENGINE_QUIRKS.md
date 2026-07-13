# KAG Engine Quirks Ledger

This is the durable record of engine behavior that can make correct-looking KAG mod code fail or produce misleading test evidence. Add an entry when a quirk is reproduced; include the symptom, the unsafe conclusion, a reliable check, and the workaround. Do not turn guesses into rules.

## Runtime And Test Process

### Visible `RunLocalhost` may stop the entire simulation mid-action

- Symptom: the builder appears to work for roughly 1.5-3 seconds and then freezes mid-swing; the test heartbeat and every other server event stop at the same game tick.
- Evidence rule: distinguish an AI stall from a simulation stall. If blob deltas, heartbeats, and game time all stop, do not diagnose the builder state machine from the frozen pose.
- Current workaround: retain the visible scene for human inspection, report the automated result as inconclusive, and use normal CTF/manual play for longer behavior checks. Do not extend the timeout when game time itself is not advancing.
- Diagnostic requirement: harvesting fixtures emit change-only blob deltas for tree health/growth/support, logs, loose resources, carried resources, inventory, and crate storage.
- Scope confirmed in manual testing: a builder that freezes before completing tree work in the AIBTest environment can chop the same kind of tree normally in an actual CTF game. Do not transfer an AIBTest-only freeze into production AI code without reproducing it in CTF.
- Acceptance boundary: use AIBTest for short deterministic assertions and scene-delta diagnostics. Use visible CTF for sustained harvesting, mining, navigation, construction, and director acceptance until the AIBTest runtime freeze is independently eliminated.

### Final AIBTest verdicts intentionally freeze their fixture

- Symptom: a builder stops mid-task immediately after the overlay changes to `FAIL - FROZEN` or `PASS - FROZEN`.
- Cause: `AIBT_FreezeFinalFixture()` deliberately disables the fixture after the final verdict so humans can inspect it.
- Do not conclude: the production brain chose to stop. Check the overlay and final verdict first.
- Test-design rule: deadlines must cover the complete physical action. A tree fixture now receives 1,800 in-game ticks and cannot fail at the old short chopping deadline.

### Per-tick `print()` telemetry can make a visible localhost session severely laggy

- Symptom: the game becomes visibly very laggy while the console receives many full structured strings, especially aim changes from every player.
- Reproduced case: the first `AIBPlayerActionLog.as` implementation printed a complete `[AIBEVT]` line for each sampled input/aim change and periodic frame; the user observed severe lag in the live CTF check.
- Do not conclude: because transition logging is smaller than full snapshots, it is cheap enough for public play. Formatting and console I/O dominate.
- Workaround: collect numeric deltas in memory, batch them, and print one compact transport record at a coarse interval. Never use per-player/per-tick strings for production telemetry.

### A client bubble can lag behind server-authoritative completion

- Symptom: the visible builder still shows a suggestion/reservation wait bubble after the server has placed the requested blocks and emitted a completion verdict.
- Do not conclude: the stale bubble proves the builder is still paused or the placement failed.
- Reliable check: inspect the actual map tiles, resource delta, AI state transition, and server verdict together. A screenshot is scene evidence, not sufficient state-machine evidence by itself.
- Reproduced case: the unattended CTF generated-support smoke placed castle backwall and castle foreground, consumed exactly 12 stone, and passed while the captured client still displayed a suggestion-paused bubble.

### Rules command IDs are a limited resource

- Symptom: rules startup prints `Too many commands added ... results will be bad!` even though the game continues loading.
- Observed on build 4762: the current CTF rules report this for `clearBlueprintLayer` and `SendChatMessage` during initialization.
- Do not conclude: another `addCommandID` is harmless because command names are strings or because compilation succeeds.
- Workaround: reuse existing commands, consolidate related operations behind one command plus a compact opcode, and remove duplicate registrations before adding new IDs. Treat this startup warning as a correctness risk requiring a separate command-table audit.

### Visible `RunLocalhost()` can stop advancing

- Symptom: the KAG process and window remain alive, but game time, `[AIBTEST]` heartbeats, and the console log stop changing.
- Do not conclude: a scenario failed, timed out in its own state machine, or reached later assertions.
- Reliable check: compare game time and log length over time. `Tools/run_aib_tests.ps1` reports this as a distinct stale-simulation/log condition after 25 seconds.
- Workaround: keep focused scenarios short, use exact/range runs, and preserve the last advancing heartbeat as partial evidence only. A PASS without the final `[AIBTEST] DONE` is not a completed run.

### Adjacent final-verdict `print()` calls are not an atomic completion boundary

- Symptom: a focused run writes its final `PASS` and then stops before the immediately following event/DONE prints in the same rules tick.
- Reproduced in the pinned-order gym case on build 4762.
- Workaround: freeze the final fixture first, then emit final PASS/FAIL plus DONE counts in one physical console line. Parsers must recognize both tokens on that line.

### KAG rewrites root `autoconfig.cfg` when it exits

- Symptom: restoring startup settings while a test instance is alive is undone when that instance later closes.
- Do not conclude: a successful file edit means the handoff configuration will remain correct.
- Reliable check: close the agent-started AIBTest process first, then inspect the root configuration after exit.
- Workaround: shutdown AIBTest before restoring CTF. Finish with `sv_gamemode = CTF`, blank `sv_mapcycle`, and `sv_mapcycle_shuffle = true`.

### CTF plus the AIBTest one-map cycle can restart recursively

- Symptom: a black or repeatedly restarting game window after CTF starts.
- Cause: CTF's map-vote path reloads `Rules/AIBTest/aibtest_mapcycle.cfg` when that temporary cycle is left in root startup settings.
- Workaround: never leave CTF paired with the AIBTest cycle. A blank root cycle lets CTF load `Rules/CTF/mapcycle.cfg`.

## Camera And Observation

### Camera state/logs do not prove the displayed view

- Symptom: `AIBTestCamera.as` reports the intended target/view while the human-visible camera sticks upper-left, recenters to map middle, jitters, loses follow, or blocks manual movement.
- Do not conclude: `CAMERA_TARGET` or `CAMERA_VIEW` records prove camera correctness.
- Reliable check: human observation of the visible client is authoritative.
- Workaround: keep camera correctness out of automated pass claims. Minimize competing camera owners and manually verify changes.

### Fixed home-relative destinations can resolve inside terrain

- Symptom: a builder repeatedly jumps/repaths at the home and never reaches a nominal storage point such as `home - 9 tiles, -8 px`.
- Do not conclude: the generic pathfinder or jump recovery is necessarily broken.
- Reliable check: inspect the destination tile, both body-clearance tiles, and the tile below it in the live map.
- Workaround: search outward on both sides of the home for a clear standing cell with solid support, and use the first deterministic legal result. The corrected CTF run chose `108,404` and completed storage delivery.

### Director reassignment can interrupt a physically valid resource episode

- Symptom: a worker chops a tree, collects one material stack, then immediately abandons the remaining logs for blueprint work.
- Cause: strategic role recalculation can occur more frequently than a physical harvest pipeline completes.
- Workaround: defer desired job changes until a safe boundary. For wood, that is after the selected tree's logs and loose wood are exhausted and the held resources are returned; use equivalent target-free boundaries for stone and blueprint pipelines.

### A barrier-safe tree may still be practically unreachable

- Symptom: a builder selects a legal tree, approaches partway, then alternates path replans, ladder recovery, and corner escape without ever reducing tree health.
- Reproduced CTF geometry: worker at roughly `40,479`, target hit point `96,432`, next to the left map edge; the world and log continued advancing for 1,800 ticks.
- Do not conclude: a selected blob or non-empty path proves physical reachability. Also do not impose a fixed total chopping deadline, because a reachable mature tree may legitimately need many hits.
- Workaround: track two kinds of progress—meaningful distance reduction and tree-health reduction. Temporarily blacklist only after 300 advancing ticks with neither; every successful hit resets the timer. The cooldown lets selection try another tree without permanently discarding the resource.

### Unsupported blueprint foreground may be buildable via generated backwall

- Symptom: validation reports “no support” for a floating foreground tile even though a builder could connect it to terrain by placing backwalls.
- Do not conclude: direct foreground support is the only legal dependency.
- Workaround: planner and executor must share the same generated-support rule. Build the matching material backwall chain first, then place the foreground block, and account for both costs.

## AngelScript Compatibility

### Normal CTF compilation does not compile AIBTest-only call sites

- Symptom: production CTF launches cleanly, but a focused AIBTest launch partially fails rules initialization on a stale helper signature inside `AIBTestScenarios.as`.
- Reproduced case: `AIBS_CandidateHasDependencySupport` gained required world context; production callers were updated, while a test-only template contract still used the old one-argument call.
- Do not conclude: a successful CTF smoke proves every test script compiles, or a textual search for production callers covers test-only branches.
- Workaround: after changing a shared function signature, search the entire mod for its symbol and live-compile one focused AIBTest scenario as well as CTF. The runner should surface a newly created console log even when it contains no `[AIBTEST]` marker so compile failures are reported immediately.

### `const Vec2f` operands can reject otherwise normal vector operators

- Symptom: live KAG compilation rejects vector arithmetic that looks valid in conventional AngelScript/C++.
- Reproduced case: bootstrap provisioning initially used three `const Vec2f` operands; replacing them with mutable `Vec2f` values compiled.
- Workaround: when KAG reports a non-const vector operator mismatch, copy the operand into a non-const `Vec2f` before arithmetic. A textual/static check cannot substitute for live KAG compilation.

### Ordinary-looking identifiers may be reserved by KAG's AngelScript dialect

- Symptom: live compilation reports `Illegal variable name` even though the identifier looks harmless in C++ or another AngelScript host.
- Reproduced case: `const u16 keys` in `AIBPlayerActionLog.as` failed on KAG build 4762; renaming it to `inputMask` fixed that compile error.
- Workaround: rename the identifier instead of trying type or scope changes, record the exact rejected word here, and re-run a live compile because repository text checks do not know KAG's reserved-word table.

### A tree must be grown during initialization, not relabelled afterward

- Symptom: a test tree looks like a seedling but passes an AI maturity check, then produces no logs when destroyed.
- Cause: setting `grown_times` after `server_CreateBlob()` changes the exposed value without constructing the tree segments used by normal mature-tree harvesting.
- Workaround: copy the Base map-loader lifecycle: `server_CreateBlobNoInit("tree_pine")`, add the `startbig` tag, set its position, and call `Init()`.
- Test rule: visually confirm that harvesting fixtures are full-grown and root them in the empty tile immediately above solid ground; a maturity property alone is not valid fixture evidence.

## AI Movement And Pathing

### Solid terrain is a legal backwall-support anchor

- Symptom: a blueprint above dirt or grass reports missing support even though a player can place a backwall chain from that terrain; the worker may retain noisy jump input while no build target is acquired.
- Cause: a mod-side support helper rejected `isTileGrass` and `isTileGroundStuff` before checking `isTileSolid`, so generated dependencies had no legal starting anchor.
- Rule: empty tiles and ground background do not provide support; solid terrain, built foreground, and valid wood/stone backwalls do.
- Evidence requirement: inspect state acquisition separately from movement. In the live CTF trace, the worker entered `find_blueprint_block` at tick 300 but never emitted a target/state transition afterward, proving selection/support classification—not path following—was the first failure.

### Engine pathing and direct movement can fight each other

- Symptom: builders jump in place, oscillate between surface and shaft nodes, or repeatedly replan near a valid destination.
- Cause: generic obstruction recovery, ladder/jump behavior, `CBrain.SetPathTo` suggestions, and a specialized direct shaft/tunnel controller can issue conflicting intent.
- Workaround: give specialized movement explicit ownership while active. Suppress generic jumps/recovery ladders during dedicated tunnel movement, clear stale paths on state/target changes, and hand off only at a deterministic proximity/visibility boundary.

### A path request is not evidence of progress

- Symptom: `SetPathTo` succeeds or path nodes exist, but the builder's displacement and task state do not advance.
- Do not conclude: a non-empty path means the goal is reachable or the movement controller is following it.
- Reliable check: gym assertions must track displacement, distance-to-goal trend, state age, repeated jumps, replan count, and task-side effects.
- Workaround: diagnose intent, motion, and outcome separately. Emit a bounded timeline around the first progress violation.

### A short corner escape can feed the worker straight back into the trap

- Symptom: exact mirrored-overhang detection fires correctly, but every event reports nearly the same position; after a short walk away, path control immediately returns the worker beneath the ceiling.
- Reproduced CTF return route: worker stayed around `239,368` while targeting storage `132,316`, alternating five-waypoint paths, obstruction replans, and rightward escapes for more than 1,500 advancing ticks.
- Do not conclude: detecting the correct escape direction proves recovery completed.
- Workaround: the geometry-specific direct controller owns movement for 36 ticks to create a real run-up, followed by a 90-tick recovery cooldown. Judge success by displacement and eventual task progress, not by the escape event itself.

### `CInventory.isFull()` can lag same-tick server insertions

- Symptom: a fixture loops on `!inventory.isFull()` while calling `server_PutInInventory`, queues more items than the configured slot count, then the visible localhost simulation freezes during replication.
- Reproduced case: a 3x3 crate accepted/queued 18 material blobs in one setup tick before the loop observed fullness.
- Do not conclude: `isFull()` is a synchronous postcondition for inventory mutations queued in the same tick.
- Workaround: when constructing a deterministic fixture, use the configured slot count (nine for `Crate.cfg`) or spread inserts across ticks. Production code should judge the return value of each insertion and re-evaluate capacity on later ticks.

### Newly placed recovery structures may not immediately solve routing

- Symptom: after the AI places a backwall/ladder chain, it keeps selecting the same mineable obstruction or replanning instead of traversing it.
- Current status: this is still visible in `kag_path_mines_dirt_plug`; the exact cache/update behavior is not yet proven.
- Workaround: log the low-level next path node, chosen mineable block, support chain, and post-placement walkability. Do not add blind delays until the first tick on which the pathfinder recognizes the structure is measured.

## Evidence Rules For Future Entries

Each new quirk should state:

1. Minimal reproduction and affected KAG build if known.
2. Human-visible symptom and machine-visible symptom.
3. Misleading evidence that future agents must not trust.
4. Reliable verification and workaround.
5. Source/test/log reference and whether the issue is fixed, mitigated, or open.
