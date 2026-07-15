# Runtime testing policy

AngelScript behavior and compilation are validated inside a visible KAG process. The local TCPR bridge carries compiler diagnostics, authoritative scenario acknowledgements, progress metrics, and final verdicts. Do not recreate source-text/regex “contract tests” as substitutes for loading and exercising the code in KAG.

`AIB_TEST_AUDIT.md` records the claim strength and runtime status of every current scenario. Keep focused passes, source-inspected assertions, and unresolved weak fixtures distinct.

Use the persistent visible loop for focused work:

```powershell
& .\research\tools\Invoke-PersistentAIBTest.ps1 -Action Start -Scenario <name> -TimeoutSeconds 120
& .\research\tools\Invoke-PersistentAIBTest.ps1 -Action Run -Scenario <name> -TimeoutSeconds 120
& .\research\tools\Invoke-PersistentAIBTest.ps1 -Action Stop
```

The first command starts visible KAG. `Run` rebuilds/restarts rules in the same owned process and reports in-game compiler errors through TCPR. Always stop the owned process after the evidence run and restore the required CTF handoff. A failed start/run already performs that cleanup.

Map-scoped optimization episodes run in visible CTF with `Scripts/aib_gym_autostart.as`, which loads the first existing map in the real CTF rotation without generated fixture terrain. Arm them through `!aib_gym resources ...` or the equivalent local TCPR rule properties. A 180-second episode emits `resource_collection_180s`; shorter development runs emit `resource_collection_smoke` and are not comparable. See `AIB_GYM_METRICS.md` for field semantics and the exact per-map cohort key.

Local metric collection should give `research/tools/tcpr_send.py` a unique `--transcript` path. Final `[AIBGYMR]` and `[AIBGYMB]` rows use explicit TCPR as well as `print()`, because KAG's console file can stop growing while the simulation and explicit socket channel continue.

For one owned resource episode, use the wrapper so launch, transcript validation, process shutdown, and post-exit handoff restoration are one transaction:

```powershell
& .\research\tools\Invoke-AIBGymResourceRun.ps1 -RunId <unique-id> -Variant control -BuilderCount 1 -Order wood -DurationTicks 5400
& .\research\tools\Invoke-AIBGymResourceRun.ps1 -RunId <unique-id> -Variant candidate -BuilderCount 4 -Order mixed -DurationTicks 5400
```

It refuses to launch over an existing KAG process and never restores `autoconfig.cfg` until its owned visible process is gone. The wrapper requires the authenticated socket to remain live for three seconds before sending the transaction; an accepted socket during early build-4762 startup can otherwise reset before the first benchmark command. Add `-CompilerForwarding` for the first run after an AngelScript edit; identical print/TCPR rows are safe because the comparator deduplicates by run id.

For path/state diagnosis, use `-Variant diagnostic -EventLog`. The switch is deliberately rejected for `control` and `candidate` runs so formatted event traffic cannot contaminate a comparator cohort. Diagnostic runs may use shorter durations and are always labeled `resource_collection_smoke`; retain their event log, failure/window artifacts, and result row as focused evidence only.

For one owned physical flag-gatehouse episode, use the infrastructure wrapper:

```powershell
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Team 0 -CompilerForwarding
```

It publishes and executes the normal production plan, then emits `[AIBGYMI]` schema 1 only after checking every physical task, plan counters/archive, reservations/work layer, both team doors, and a real friendly passage. Summarize exact same-map/side cohorts with `Tools/summarize_aib_infrastructure_results.ps1`. Do not interpret its ally probe as enemy-breach or combat-survival evidence.

Four-worker provisioning is part of the evidence contract. A clear body volume with solid ground is insufficient on real maps: candidates must belong to the resource home's conservative grounded-reachability flood, and the complete separated spawn set is selected by deterministic backtracking. Keep the emitted `SPAWN_SET` line with the result and reject an episode if any stable slot is absent or unproductive because of fixture placement.

Resource episodes are also fail-closed against CTF contamination. Production AI builders cannot pick up flags through the shared collision predicate. The gym independently detects any carried `ctf_flag`, restores that exact flag to its matching base, emits `AIBGYM|CONTAMINATION`, and aborts without a comparable result. Never include an episode in which a resource worker captured or returned a flag.

The reusable-route AIBTest fixture proves route choice, bounded destruction, and physical mining; it does not by itself prove a quota-complete miner can return from a deep shaft. Use a sustained visible CTF diagnostic with EventLog for `stone_return_anchor`, `stone_return_direct`, `stone_return_exit`, and a later confirmed delivery, then use three EventLog-off 5,400-tick episodes for throughput acceptance. Two fresh reusable-route attempts on 2026-07-15 froze at game tick 125 before `PASS`/`DONE`; they are inconclusive despite showing successful mining interactions and must not replace the CTF evidence.

## What a scenario name may claim

- Target selection or a non-zero destination is intent, not pathing success.
- A few pixels of displacement proves only initial movement. A route test must reach its named boundary or target.
- Stationary chopping, mining, building, and engine wait states are legitimate progress. Observe successful interactions, target health/world mutation, or explicit wait state instead of demanding movement.
- A tree episode is not complete until the tree falls, logs appear, logs are processed, wood is acquired, and the claimed delivery occurs.
- A recovery test must prove the recovery branch occurred and caused the required crossing. Merely reaching the far side by another route is not a pass.
- A delivery test must observe material inside the named destination and conservation where costs are involved. Returning toward the base is not yet delivery.
- A physical-completion test must verify every world object/tile, task state, reservation, work-layer, and archive condition named by the fixture.
- Timeouts must not fail an actor that is still making goal-directed progress. The gym monitor should catch genuine bounded stalls; scenario deadlines are a final safety bound.

## Evidence classes

1. **KAG runtime:** authoritative in-game compile plus a focused physical/state outcome. This is the normal evidence for AngelScript.
2. **Manual/multiplayer runtime:** real process restart, client join, visibility, camera, UI, and team/spectator transport checks that a localhost fixture cannot prove.
3. **Offline tool test:** executes a parser, comparator, generator, or abstract simulator against controlled data. It validates only that offline tool, never KAG behavior.

The retained `Tools/test_*.ps1` files are class 3 tests. Source-inspection contracts were removed on 2026-07-15 because a green regex/source-order check could be mistaken for compiled or behavioral evidence.

## High-value focused runtime cases

| Area | Focused scenario/evidence |
|---|---|
| Full tree episode | `gym_tree_order_harvests_and_delivers_selected_tree` |
| Stone route selection and physical mining | `stone_route_prefers_reusable_open_corridor` |
| Exposed stone delivery | `stone_order_mines_exposed_stone_and_delivers` |
| Supported recovery ladder | `kag_path_builds_supported_ladder_chain` (currently fails because the fixture crosses without creating a ladder; redesign required) |
| Mirrored corner recovery | `stone_corner_escape_from_mirrored_upper_overhangs` |
| Generated blueprint support | `blueprint_builds_generated_backwall_support` |
| Physical repair | `damaged_owned_tile_is_repaired_without_replacing_neighbors` |
| Overflow storage | `full_crate_creates_grounded_overflow_storage` |
| Representative director execution | scenarios 54–64 in `Scripts/AIBTestScenarios.as` |
| Late-join state sync | real mid-match client join; no single-process fixture is sufficient |
| Editor visibility/authority | two teams plus spectator in a real multiplayer session |
| Blueprint disk round trip | save, terminate KAG, restart, reload, and compare the exact footprint |
| Wave identity/fingerprint | fresh canonical control/plan pairs, then `Tools/compare_aib_wave_results.ps1` |
