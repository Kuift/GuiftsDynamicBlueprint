# AI Blueprint Director Implementation Status

Updated: 2026-07-14

## Executive Status

The deterministic utility-based director is implemented and now exercises the real production loop in automated KAG coverage. Normal CTF defaults to autonomous mode: the server observes the world, selects a production template, publishes active AI work without a player drawing a blueprint, and assigns AI builders when they become available.

Estimated completion against the full design contract: **82%**.

This is not yet a claim that the director makes consistently good strategic decisions across real maps and attacks. Core planning and construction plumbing are strong; representative in-engine evaluation and evidence-driven tuning remain the largest gaps.

Final no-popup checkpoint (2026-07-10): the consolidated offline/static batch passed 15/15 checks, covering the 58-scenario registry, canonical reset and representative fixtures, 68-key shared weights, wave identity/matrix/comparison, compact telemetry and episode tools, and the expanded passive gym monitor/failure-window parsers. No KAG process is running. The latest AngelScript telemetry, weight-loader, canonical-fixture, and gym-window paths remain runtime-uncompiled and must not be presented as live evidence.

Incremental no-popup checkpoint (2026-07-13): work through home-connected bootstrap siting is committed as `0b1fac7`, exact no-build/occupied fallback completion as `ce8e1ed`, barrier fallback completion as `ddfd168`, simultaneous mirrored completion as `1379119`, configurable CTF director policy as `3b0c1d5`, public telemetry operations as `27d2cf4`, stable runner allocation as `132e5c1`, executor-aligned accessible stock as `bc64244`, multi-home assignment identity as `231f169`, durable manual ownership as `68a3e1a`, cross-barrier stock exclusion as `c7a5f36`, pre-mutation worker-opcode validation as `7014a20`, and safe no-work retirement as `afb41fb`. Overflow conservation, mirrored corner recovery, shared world-manifest identity, damaged-front retention, full selected-plan completion, schema-v3 boundaries, bootstrap siting/lifecycle, exact fallback completion, configurable public policies, demand-aware stable multi-builder allocation, live safety invalidation of pending repairs, split strategic/resource-home lifecycle handling, barrier-safe accessible stock, multi-home assignment identity, durable manual ownership transfer, pre-mutation overseer-opcode validation, safe no-work assignment retirement, and brain-side deferred-role handoff now have static coverage. The current 65-scenario registry and complete offline batch pass 31/31 checks. Runtime evidence is unchanged because KAG was not launched.

Current no-popup checkpoint (2026-07-14): existing storage workshops are now selected within the exact resource home's bounded production envelope and active-barrier side instead of through a runner-global team lookup. The workshop fixture retains a remote same-team shop and requires local-base selection. Overflow-crate funding now counts only spendable inventory, commits the builder leg first, and refunds it if the home leg fails; home withdrawal preflights the full accessible amount before mutation. Public builder job/state/active values now force-publish at creation and receive a coarse staggered resync for bounded late-join HUD recovery. Live human blueprint deltas are idempotent at the authoritative layer and their tile/snapshot payloads are sent only to same-team players and spectators rather than broadcast to enemies and discarded client-side. Blueprint saving now owns a committed rectangle independent of tree, stone, and overseer gestures, rejects saving before a selection, and preserves inclusive/asymmetric dimensions through both load paths and authoritative placement. Static contracts cover the storage transaction, public-state, editor-authority, and selection round-trip paths, and the complete offline batch passes 34/34 checks. Visible KAG compilation, a real mid-match client join, a two-team/spectator editor session, a process-restart PNG round trip, and focused overflow/retrieval verdicts remain pending.

| Area | Weight | Earned | Evidence |
| --- | ---: | ---: | --- |
| Blueprint authority, layers, catalog, history | 20 | 20 | Shared server APIs, durable human-wins ownership, desired/work split, task archives |
| World model, candidates, validation, scoring | 20 | 17 | Five procedural templates, terrain/threat observations, hard validation and explanations; map diversity remains narrow |
| Autonomous publication, jobs, construction | 20 | 19 | CTF auto default, pre-builder planning, guarded first-worker provisioning, deterministic assignment, reservations/phases, real task completion, safer workshop siting, and low-destruction stone execution |
| Deterministic and component verification | 15 | 15 | Source defines 65 scenarios; the earlier 44-scenario suite passed in full, scenarios 42-46 passed together, and production bootstrap, repair, and gym cases have focused passes |
| Representative in-engine evaluation/tuning | 15 | 3 | Instrumentation and wave harness exist, but no trustworthy paired dataset or production-weight tuning result is recorded |
| Operational defaults, documentation, handoff | 10 | 8 | Visible localhost runner supports exact/range selection, stale-progress detection, and safe file restoration; the displayed test camera remains unreliable and manual multi-map acceptance remains |
| **Total** | **100** | **82** | |

## Latest Implemented Milestone

- Blueprint selection/save/load now has an isolated round-trip contract. The editor commits normalized inclusive bounds into a dedicated save rectangle; tree, stone, and overseer interactions may continue sharing `mouseSelect` for rendering without silently changing the saved footprint. Restart/team changes and a new drag invalidate the cached selection, a single tile is valid, and saving before selection is rejected instead of capturing the old default rectangle. Asymmetric widths, heights, x/y data orientation, packet order, and center anchoring are pinned through runtime memory, PNG decoding, client serialization, server reconstruction, and `AIBP_ApplyHumanPlacement` by `Tools/test_aib_blueprint_selection_roundtrip.ps1`. Static checks pass; an actual disk reload after process restart remains runtime evidence.
- Live editor publication now respects the blueprint visibility boundary at transport time. The server remains authoritative for active-sender identity, team/overseer permission, rate, catalog/bounds validation, human priority, compatibility-layer rebuild, versions, and action boundaries. `syncBlueprintBlock` and `giveAllBlocks` payloads now use targeted rules commands for same-team recipients and spectators instead of broadcasting another team's contents for enemy clients to ignore. Repeated same-value tile packets return before mutation, so held-paint retransmits cannot advance the version or emit false telemetry. `Tools/test_aib_editor_delta_authority.ps1` pins the recipient policy, targeted overloads, absence of broadcast sends, idempotence ordering, permission/rate boundary, and client filter. Static checks pass; KAG compilation and a two-team-plus-spectator delivery/non-delivery test remain.
- Public AI-builder HUD state now has bounded late-join recovery. Brain creation force-publishes `"ai builder state"`, `"ai builder job"`, and `"ai builder job active"`; authoritative orders and transitions retain their immediate syncs; and the server brain republishes the trio on a network-ID-staggered five-second cadence. The resource counters continue to derive wood/stone/blueprint roles from the canonical job enum and ignore idle state, avoiding a duplicate role property. `Tools/test_aib_public_state_sync.ps1` pins initialization, heartbeat placement before attached early-exit, all three fields, immediate order-path sync, and the HUD consumer. Static checks pass; this AngelScript heartbeat still needs compilation and a real mid-match client join before it is runtime evidence.
- Existing builder-shop reuse is now tied to the exact resource base. Storage delivery and stone-supply waiting share a deterministic selector that rejects enemy, dead, packed, cross-barrier, and more-than-28-tile-away shops, then scores eligible shops against the grounded storage point with a network-ID tie-break. `storage_workshop_skips_obstructed_tent_sites` now leaves a remote same-team shop alive, forces construction past the blocked local band, and requires the bounded selector to choose that local production shop. Overflow-crate affordability no longer counts carried wood that inventory payment cannot spend; mixed funding confirms the builder inventory leg first and refunds it if the home-storage leg becomes unavailable. `Tools/test_aib_overflow_storage_contract.ps1` pins both regressions. Static checks pass; the changed AngelScript path and runtime-ready assertions remain uncompiled in KAG.
- Manual AI-builder orders now have a single server-side ownership boundary. Both the close-range blob buttons and an accepted overseer wood/stone/blueprint opcode release the current blueprint reservation, director assignment and deferred role, engine/custom paths, movement/action keys, specialized stone recovery state, and resource-home pin before applying the requested job. Unknown worker opcodes are rejected before blob lookup and before `AIBM_TakeManualControl`, so a malformed authenticated packet cannot silently cancel director ownership without accepting a replacement job. The durable manual latch excludes the runner from automatic role assignment without making it disappear from bootstrap live-worker counts; a manual Autobuilder still enforces director isolation. Explicitly turning auto direction on through the UI, strategy/test chat paths, or a planned wave releases the team latch for reassignment. The expanded guard fixture proves a pending director role cannot reclaim the manual runner, then proves explicit release permits a newly pinned assignment. `Tools/test_aib_manual_order_ownership.ps1` pins validation-before-mutation ordering and the limited command-ID count. All offline contracts pass; the AngelScript path remains runtime-uncompiled.
- Director shortage pressure no longer credits arbitrary same-team inventories. `AIBHomeResourceCommon.as` defines the production-accessible stock set once: loose material near the selected tent/hall resource home and unpacked same-team crates near the deterministic grounded storage point. While the red barrier is active, loose stacks, the chosen storage point, and every recognized crate must be on the resource home's side; cross-barrier stock can no longer suppress a collector that cannot retrieve it. The normalized zone helper now lives in the shared module, and the AI brain delegates both outside-strip and same-side resource checks to it instead of carrying a divergent brain-local implementation. Both world observation and the AI builder's count/take/get paths use that contract; the server publishes change-only wood/stone totals for the advanced UI, including while automatic direction is disabled. Director-owned runners also carry the selected resource home's network identity, so a runner standing beside a different friendly tent cannot retrieve from an inventory that the director did not count. Manual orders keep nearest-home fallback, invalid pins are ignored, assignment cleanup clears the pin, and Autobuilders remain home-independent. The expanded bootstrap-guard fixture requires 130 accessible wood while excluding 570 remote wood and pins a runner beside a secondary tent to the primary flag-selected home. `Tools/test_aib_accessible_stock.ps1` additionally mirrors cross-barrier loose/crate exclusion and pins the self-contained shared helper; `Tools/test_aib_resource_home_identity.ps1` pins identity. Static checks pass; this AngelScript integration remains runtime-uncompiled.
- Three representative production-path scenarios close the documented no-build, occupied-base, and active-barrier source gap. Each starts with a valid primary gatehouse, introduces one exact obstacle, requires `no_build`, `building_overlap`, or `barrier`, selects and publishes a distinct fallback, assigns the production Autobuilder, and requires every task to complete physically with no reservations/work left and a completed archive. The original no-build tile/sector, static crate, or barrier-crossed tile must survive. The barrier fixture forces collapse pressure and requires every selected task to stay on the home side. Owner-tracked temporary sectors are removed before canonical validation. Static contracts pass; all three scenarios remain runtime-uncompiled.
- `strategic_mirrored_sides_physically_complete_safe_inward_plans` upgrades the former selection-only mirror. Both teams select, validate, and publish inward plans before either Autobuilder exists, preserving ordinary approach/reachability checks. Two team-specific Autobuilders then run concurrently, and each plan must physically complete with exact task/counter/layer/archive state, zero reservations, an untouched human layer, stable identity, and observed progress. Static ordering and completion contracts pass; the stronger AngelScript path remains runtime-uncompiled.
- `strategic_uneven_right_edge_fallback_physically_completes` upgrades the former selection-only edge case. It proves the primary valid before adding a two-tile castle step, selects a distinct inward fallback with no Autobuilder present so ordinary reachability is enforced, publishes it, and then requires the production Autobuilder to physically complete every task. Exact task/counter/layer/archive identity, terrain variance, route safety, and preservation of both obstruction tiles are required; compatible already-matching stone reuse is legal. Static contracts pass; the stronger AngelScript path remains runtime-uncompiled.
- Bootstrap provisioning no longer treats a locally clear grounded pocket as sufficient. Each spawn attempt now flood-fills a bounded set of two-tile standing cells from the nearest home terrain cell, constrained to the correct barrier side, and requires the final three-column spawn envelope to belong to that set. Blocker bounds and reachability are each built once rather than inside the roughly 950-candidate loop. `strategic_bootstrap_rejects_sealed_cave_spawn` proves mirrored sealed envelopes are locally valid but rejected while an open surface and the production-selected spawn remain reachable. The offline mirror contract passes; the new AngelScript code and scenario still need a visible KAG compile.
- `strategic_blocked_bootstrap_cools_down_and_round_reset_recovers_both_sides` exercises the remaining lifecycle contract for both team directions. Static crates cover every legal 6-24-tile spawn distance; the failed production attempt must return no worker and set exactly `AIBS_BOOTSTRAP_RETRY_TICKS`. Removing blockers cannot bypass that deadline. `AIBS_ResetBootstrapForRound` must preserve the enabled policy, clear both provisioned latch and retry deadline, allow one safe assigned worker, and suppress a second attempt. The source contract also pins the director's `onRestart` call to this helper. Static checks pass; KAG compilation and runtime behavior remain unverified.
- Two production-path scenarios close the remaining representative fixture gap. `strategic_damaged_front_reactivates_without_plan_replacement` requires two damaged owned tasks to reactivate while one healthy task stays complete and plan identity remains stable. `strategic_autobuilder_physically_completes_selected_plan` observes the world, selects and publishes a production candidate, assigns the real Autobuilder executor, and requires every task to match physically with zero reservation metadata, an empty work layer, stable plan identity, and a completed archive. Static contracts pass; both scenarios remain runtime-uncompiled.
- Physical repair is now a production construction outcome rather than only task reactivation. Healthy autotile families count as complete; damaged matching wood/stone tiles and damaged same-team blueprint blobs remain valid repair occupants; plan invalidation no longer replaces a repairable plan; builders spend the block cost, restore health/tile state directly, preserve neighbors, and emit a compact `repair` event. `damaged_owned_tile_is_repaired_without_replacing_neighbors` completed with `[AIBTEST] DONE passed=1 failed=0` in `console-26-07-10-17-32-06.txt`.
- Overflow storage now revalidates stale full-crate tags, searches grounded/distinct two-sided sites, protects both crate body cells from no-build sectors, and can pay the 150-wood cost from builder plus base storage. Full inventories only advertise merge capacity when a matching material stack is below `maxQuantity`; a full 250-material stack no longer traps delivery in repeated retries. Crates are created before charging, while workshop spawn failure refunds its exact paid cost. The focused verdict now requires 100 stone inside base crates, exactly 100 stored/live wood after the 150-wood purchase, two grounded distinct crates, and whole-world stone conservation. `Tools/test_aib_overflow_storage_contract.ps1` passes, but the corrected fixture still needs its focused KAG runtime run.
- `Tools/run_aib_tests.ps1` now reports fresh mod compile/rules errors even if `AIBTestRunner` never emits `[AIBTEST]`. This corrected a wasted full timeout caused by a stale test-only shared-helper call.
- Exact overhang escape ownership increased from 12 to 36 ticks with a 90-tick cooldown after a normal-CTF return route repeatedly escaped correctly but re-entered the same corner. The change compiled but the failing geometry has not been rerun.
- The mirrored overhang fixture can no longer pass from a transient three-pixel nudge while direct recovery is still active. It now requires both 36-tick escape cycles to finish, both 90-tick cooldowns to latch, at least one tile of mirrored displacement, suppressed jump/ladder input, and intact castle traps. `Tools/test_aib_corner_recovery_contract.ps1` protects the production-controller ownership and fixture assertions. This remains static evidence until the focused fixture and real CTF delivery route are rerun.

- A fully unattended normal-CTF smoke test now verifies the cross-system behavior that was unreliable in AIBTest. In `console-26-07-10-17-03-04.txt`, worker 22 completed the entire selected tree/log episode, returned and stored the wood at the grounded base site, accepted the deferred blueprint job, retrieved stone, placed generated castle backwall followed by castle foreground, and passed exact material accounting:

```text
[AIBEVT] t=700 ... from=find_log to=return_wood reason=no logs left and wood held
[AIBEVT] t=762 ... from=return_wood to=find_tree reason=wood delivered
[AIBEVT] t=764 ... from=collect_blueprint_resources to=find_blueprint_block
[AIBDEV] PASS generated_backwall_support builder=22 x=14 target_y=49 support_y=50 remaining_stone=138
```

- The accompanying real-client screenshot is `Artifacts/aib_ctf_generated_backwall_pass.png`. The scene and placed structure are visible, but the client bubble is stale; server tile/resource/state deltas are the authoritative completion proof.
- Base delivery no longer uses the invalid fixed `home - 9 tiles` destination. It deterministically searches both sides for grounded body clearance; the same live run used `108,404`, constructed storage, and completed delivery instead of jumping indefinitely.
- Director job changes are deferred while a builder is inside an active wood, stone, or blueprint pipeline. The live CTF run proves the requested blueprint handoff occurred only after every log from the selected tree was processed and the wood was returned.
- Unsupported foreground construction now generates a matching backwall support chain. Candidate validation and physical execution use the same rule, preventing the previous “no support” rejection for buildable plans.
- Repeated resource/candidate rejection messages are delta/rate-limited and reservations log only on a new claim, removing another source of visible-session lag.
- Bootstrap blocker blobs are now collected once per spawn attempt rather than rescanned for every candidate. The former nested search could perform about 950 `getBlobs()` world scans in one director heartbeat. Live CTF compilation and provisioning succeeded after the optimization (`console-26-07-10-17-09-48.txt`).
- A real CTF edge-map run exposed a reachable-by-filter but physically stalled tree target (`console-26-07-10-17-09-48.txt`). Tree work now abandons a target only after 300 advancing ticks with neither meaningful approach nor health damage, and cools that target down for 900 ticks. The next live run (`console-26-07-10-17-13-46.txt`) compiled the fix and proved successful tree hits keep resetting it: the builder felled the tree at tick 256, processed all five logs through tick 1,018, stored the wood, and accepted blueprint work at tick 1,021. The localhost simulation stopped at tick 1,022, so no placement verdict is claimed for that run.

- Normal CTF live telemetry was decoded successfully from
  `console-26-07-10-16-39-16.txt`: 258 schema-v1 action records across five
  compact base64 delta batches, including episode, join, spawn, input, aim, and
  motion changes without player names, IP addresses, chat, or per-frame state
  strings.
- Sustained behavior acceptance is now explicitly separated from the unstable
  AIBTest runtime. Human observation confirmed normal CTF tree chopping works;
  the AIBTest-only stop was a premature final-fixture freeze, not production AI
  behavior. The tree fixture now uses a genuinely mature, grounded tree and an
  1,800-tick full-pipeline deadline.
- Scene diagnostics now emit only changed tree/log/wood/inventory/crate fields,
  and the blueprint material fixture now begins with wood and stone inside the
  recognized base-storage crate rather than loose world stacks.

### KAG Gym and public-server demonstration foundation

- Generic ladder recovery no longer creates an unsupported ladder in the same tick as a generated backwall chain. It charges only newly missing support cells, places them as a separate phase, and waits until a later obstruction cycle observes engine support before paying for and spawning the ladder. A one-shot probe attached to that ladder records the next BrainPath node, low/waypoint counts, ray obstruction, hypothetical mineable path block, and pathfinder acceptance without per-tick logging. `kag_path_builds_supported_ladder_chain` now rejects the old partial outcomes and requires support-before-spawn, a later accepted path, actual traversal, and an untouched dirt plug. `Tools/test_aib_recovery_ladder_contract.ps1` passes; the production and fixture changes remain runtime-uncompiled.
- `kag_gym.md` now defines the deterministic fixture/driver/observation/assertion/evaluator architecture, failure classifiers, cost vector, scenario matrix, tiered execution plan, privacy boundary, optimization workflow, and public-readiness gates.
- `KAG_ENGINE_QUIRKS.md` is the durable evidence ledger for engine behavior that invalidates ordinary assumptions. `AGENTS.md` requires future runtime/pathing/camera/test work to consult and extend it.
- `Scripts/AIBPlayerActionLog.as` runs server-side in CTF and packs schema-versioned episode/join/spawn, button/aim, build selection/carry, and periodic authoritative motion deltas into an in-memory byte batch. It emits one base64 `[AIBACT]` envelope per 300 ticks or 2 KiB rather than per-player strings. It excludes usernames, IPs, and chat.
- `AIBTelemetryPolicy.cfg` controls CTF startup capture and a built-in once-per-connection privacy notice. `!aib_telemetry on|off|status` gives moderators runtime control that now survives round restarts. Disable flushes the current batch; a later enable starts a distinct episode and notices connected players who have not seen the disclosure. `Tools/parse_aib_player_actions.ps1` exports the server console evidence to NDJSON and has a deterministic parser regression.
- `PUBLIC_SERVER_OPERATIONS.md` defines preflight notice/status checks plus raw-console access, rotation, retention, export, deletion, capture-gap, and loss-record handling. This is necessarily host-owned because ordinary KAG log lines outside `[AIBACT]` can contain identity or chat.
- Ordinary runner assignment now gives a lone collector to the dominant wood/stone shortage instead of unconditionally preferring wood, retains a construction slot when the active roster permits, and preserves already-correct roles before deterministic network-ID filling. Assignment also requires an active pending plan with a non-empty AI work layer: completed, cancelled, suggestion-only, or absent work retires Autobuilders and target-free runners immediately instead of reclaiming them into an empty blueprint job. A runner inside a resource episode receives a retirement latch, and the brain consumes it at the first target-free role boundary before selecting another target; new work or ownership cleanup clears it. Normal role changes now use the same boundary guarantee: the director can update the pending role during an episode, but the brain applies only the latest valid wood/stone/blueprint role before the old find state can start another episode. Shared application clears stale reservations, paths/controllers, targets, and pressed actions while retaining director ownership and resource-home identity. The bootstrap guard publishes an explicit team-5 stock plan rather than relying on empty-plan assignment, proves a blueprint-to-stone change is held then applied at the boundary and restored by active demand, and adds runtime-ready immediate/deferred retirement assertions for teams 6/7. The focused demand/stability/lifecycle matrix passes; the revised AngelScript path remains runtime-uncompiled.
- Active repairable work now passes current barrier, no-build, and protected-building safety gates before it can preserve a plan. Already-complete matching work still remains stable, and the existing safe damaged-front fixture continues to prohibit gratuitous replacement. The focused invalidation-order contract passes; runtime compilation is pending.
- Active-plan invalidation now reconstructs the published plan and reuses production dependency-support validation, so newly blocked implicit backwall chains cannot leave a foreground task pending forever. The focused contract mirrors open chains and later no-build, protected-blob, and barrier obstruction; the AngelScript path remains runtime-uncompiled.
- Unsafe active plans are now cancelled even when selection finds no valid replacement or replacement publication fails. Cancellation archives the plan, cancels pending tasks, releases director task reservations, clears both live AI layers, and stops only director-assigned workers; manual orders remain owned by the player. The focused lifecycle contract passes, while runtime compilation remains pending. Production round restart now archives unfinished work, clears human/AI layers, task metadata, counters, and registered loose reservations, advances the human edit version, and preserves mode, plan-version continuity, and history. Stale loose-reservation release also leaves a newer owner’s lease intact. Human edits made after AI publication now cancel the conflicting AI task—including completed repair ownership—clear its work and lease, update exact counters, and close fully superseded plans as `human_override`; the existing layer scenario now exercises the dynamic path.
- The world model now distinguishes the strategic home anchor (`flag`, then `tent`/`hall`) from the resource home required by ordinary runners (`tent`, then `hall`). Free provisioning and its bounded spawn search use the resource home. If only a flag survives, the active plan and inventory-free Autobuilder work remain valid while ordinary director runners stop and release reservations; losing every strategic home archives/cancels the plan as `home_lost`, clears live AI layers, stops assignments, and leaves an immediate recovery replan trigger. The existing bootstrap guard scenario now covers both loss modes; the AngelScript path remains runtime-uncompiled.
- `Rules/CommonScripts/AIBDirectorPolicy.cfg` makes CTF's default mode and guarded free-bootstrap policy administrator-configurable. `!aib_bootstrap on|off|status` provides a moderator-only team override while preserving the consumed-round latch and retry deadline. The focused policy contract passes; the loader and command still need their first KAG compile.
- Telemetry schema v3 retains compact attributed outcomes and adds accepted human blueprint/director actions, director-workshop purchases, and production plan publish/archive/task reserve/complete/damage boundaries through a bounded numeric rules queue. Queue overflow produces a loss record and large drains split at the normal batch limit. The parser remains backward compatible with v1/v2. `Tools/summarize_aib_player_episodes.ps1` counts accepted player boundaries while keeping classification and idle time explicitly heuristic. Parser, summarizer, and boundary contracts pass, but the v3 AngelScript path has not been KAG-runtime compiled because visible windows are currently prohibited.
- `Rules/CommonScripts/AIBStrategyWeights.cfg` is now the shared source for 68 production scoring and abstract-template keys. `AIBPlacementPlanner.as` and `aib_strategy_abstract_sim.ps1` both consume it; the shared-key contract and deterministic abstract-simulator regression pass. Wood/stone beyond current team storage now receives a separate shortage penalty, so future harvesting remains possible but unfunded large plans no longer score as if paid. The AngelScript config loader still requires live compilation before this is runtime evidence.
- Wave result identity now includes fixture id/version, team, left/right side, scenario, seed, canonical pre-warm-up fingerprint, and post-warm-up measurement fingerprint. The comparator groups within complete fixture/team cohorts, requires exactly one control/plan record per seed, and rejects fewer than three distinct seeds by default. Seed affects cadence and formation for knight, archer, bomb, and mixed waves. Static identity and comparator regressions pass; the AngelScript changes and a real paired dataset remain unverified.
- Initial and measurement fingerprints now use the same `w1` world-manifest implementation in `AIBWorldFingerprint.as`; fixture identity advanced to version 3. The order-stable manifest covers terrain and solid counts, the complete tile-level no-build mask, all live world blobs, owner-tied inventory contents, health/quantity/orientation, tree growth, AI job/state, barriers, director modes, all three blueprint layers, plan/task state, reservation presence, and Autobuilder speed. It deliberately excludes usernames, network ids, and game time. Both boundaries emit their component hashes for audit, and `Tools/test_aib_world_manifest_contract.ps1` passes. This closes the narrow/different-algorithm source gap, but still needs its first KAG compile and paired fresh-reset records.
- `Tools/new_aib_wave_matrix.ps1` emits the exact default 48-trial/24-pair NDJSON schedule and requires a fresh canonical reset for every trial. Its deterministic regression covers pair uniqueness, ordering, both sides, four scenarios, three seeds, and undersampling rejection. It is a collection contract, not KAG reset/run automation.
- Task summaries now retain attribution-weighted outcomes, low-confidence counts, and a coarse privacy-safe context key. `Tools/compare_aib_task_episodes.ps1` requires three baseline and candidate episodes per identical context and reports raw success/cost/motion/death/material/confidence deltas; enforcement is opt-in. Deterministic regressions pass, but no real human/AI matched cohort exists and the context/cost model remains heuristic.
- Static API audit against installed KAG Base/mod scripts confirms the exact `onSetTile(CMap@, u32, TileType, TileType)` callback shape, damage-owner/recent-damage player accessors, `CPlayer.getCoins`, and `ConfigFile.loadFile`/`CFileMatcher` usage. This reduces dialect uncertainty but does not prove that the new callbacks/loaders execute correctly in the assembled CTF rules stack.
- AIBTest now snapshots the loaded map tile array once, restores all terrain deltas after every scenario, and fails the next setup on dimension/hash, live fixture/bootstrap tag, plan-id, or director-mode leakage. This closes contamination from real builder construction that was not registered through fixture-only tile helpers. Both the two-team mirrored case and the uneven near-edge case now continue from ordinary-reachable production selection through plan publication and full physical completion. Static lifecycle/fixture contracts pass; neither scenario has run in KAG.
- Additional production-planner fixtures verify the exact stored-resource shortage score delta and require collapse pressure from six nearby enemy knights to select an emergency barrier with an urgency reason. These are static source contracts until KAG runtime testing is permitted.
- `AIBGymMonitor.as` now latches 16-bit failure evidence for active-job/no-intent, no-side-effect state stalls, target thrash without outcomes, accessible-resource deadlocks, stale/dead reservation ownership, and repeated invalid-build attempts in addition to motion/jump/path failures. Blueprint placement revalidation/creation failures feed compact counters rather than logs. A static contract proves the monitor contains no behavior-mutating calls; runtime false-positive calibration remains.
- Public CTF now emits one compact numeric `[AIBGYM]` v1 record on each builder's first latched failure. `Tools/parse_aib_gym_failures.ps1` strictly validates and exports those lines to NDJSON; its regression passes. This provides persistent AI-failure evidence without per-tick strings, but the AngelScript emission path is not live-compiled.
- The monitor also retains a staggered numeric ring and emits one `[AIBGYMW]` v1 binary/base64 trajectory with up to 30 pre-failure and 12 post-failure samples. The strict parser validates byte length/schema and reconstructs ticks, positions, targets, state, keys, and target ids. AIBTest defers a latched failure only through the short post tail. Static/parser regressions pass; runtime memory/performance and callback integration remain unverified.
- Live KAG build 4762 validation found and corrected one dialect quirk (`keys` is an illegal variable name). The first verbose implementation then demonstrated unacceptable live log volume and user-visible lag; that evidence caused the compact batch redesign. The clean compact run in `../../Logs/console-26-07-10-15-42-21.txt` has no compile/partial-rules error and emits one batch per 300 ticks (24 startup records, then 10 steady-state records per batch). Startup slow-tick messages end after initial asset loading rather than continuing with telemetry output.
- `!aib_director_test` now gives an interactive moderator test a same-team AI builder automatically when none exists and switches the team to automatic direction. The automated production heartbeat remains stricter and proves safe production bootstrap rather than using this test helper.

### Autonomous first-worker provisioning and focused verification

- `Scripts/AIBStrategicJobs.as` and `Scripts/AIBStrategicDirector.as`
  - CTF enables a guarded bootstrap policy by default; other modes do not inherit it.
  - An auto team with a tent/hall resource home, an active non-empty plan, and no live AI builder may receive exactly one free server-spawned bootstrap worker per round.
  - Spawn selection searches both sides of that resource home and requires a grounded three-column/two-tile body envelope, barrier safety, map bounds, and no important/collidable blob overlap. Failed searches cool down for 300 ticks.
  - Builders are assigned in deterministic network-ID order. An AI-builder death immediately releases its task reservation, while the provisioned latch prevents a death/respawn fountain.
- `Scripts/AIBTestScenarios.as`
  - The suite now contains 65 scenarios, including damaged-front plan retention, full planner-selected plan execution by the production Autobuilder path, mirrored sealed-bootstrap rejection, mirrored blocked-site cooldown/round-reset provisioning, and full no-build/occupied/barrier fallback completion.
  - `strategic_auto_director_heartbeat_end_to_end` begins with a tent, stocked crate, and no builder. Production code publishes a plan, provisions one safe worker, assigns it, claims work, and physically completes director tasks.
  - Two guard scenarios cover existing-worker, suggest-mode, no-home, one-time provisioning, and reservation-release contracts. The first guard has a focused pass; the second was started but did not reach its director heartbeat before the known KAG simulation stall.

Latest focused production evidence:

```text
[AIBTEST] PASS strategic_auto_director_heartbeat_end_to_end ticks=156
default_ctf_auto=true planned_without_builders=true auto_bootstrap=true
safe_spawn=true one_time_count=1 template=archer_perch desired=18
assigned=1 build_jobs=1 task_claimed=true completed=3

[AIBTEST] PASS strategic_bootstrap_respects_mode_and_existing_worker ticks=65
existing_worker_suppressed=true suggest_suppressed=true
no_home_suppressed=true team0_builders=1 team1_builders=0 team2_builders=0
```

Logs: `../../Logs/console-26-07-09-23-00-07.txt` and `../../Logs/console-26-07-09-23-03-31.txt`. The exact heartbeat run reported `1 passed, 0 failed` but KAG stalled after the verdict and before `DONE`. The two-case range stalled during `strategic_bootstrap_is_one_time_and_releases_reservation`; that scenario is unverified, not failed.

### AI-builder execution and earlier focused verification

- `Base/Entities/Characters/AIBuilder/AIBuilderBrain.as` and `Scripts/AIBStoneRouteCommon.as`
  - Stone routes prefer reusable open shafts and minimize dirt destruction, reject blocked/protected approaches, and mine only exact route clearance.
  - On the final validated two-tile approach, builders switch to direct shaft alignment instead of oscillating between surface and underground path nodes; this movement-only takeover cannot expand the planned dig route.
  - Mirrored upper-corner recovery suppresses the stuck jump and drives away from the overhang.
  - Stone miners discover line-of-sight gold, finish the visible cluster, and switch immediately to base return; no-build gold remains protected.
- Base storage workshop construction now searches nearby legal ground instead of spawning on top of a tent or hall. It requires full footprint clearance, full foundation support, building/home separation, a grounded approach, and no-build safety.
- `Tools/run_aib_tests.ps1`, `Scripts/AIBTestRunner.as`, `Scripts/aib_test_autostart.as`, and `Scripts/AIBTestCamera.as`
  - The 65-scenario suite can run as a whole, as one exact scenario, or as a named contiguous range.
  - Stale log/heartbeat progress is detected and reported with scenario, game time, PID, and partial results.
  - Tests run through visible `RunLocalhost()` and completed fixtures receive a 15-tick visual hold. `AIBTestCamera.as` intends to follow the active fixture, but user-visible testing reports upper-left/middle recentering, jitter, loss of follow, and disabled manual movement. `CAMERA_TARGET`/`CAMERA_VIEW` logs do not prove what is actually displayed.
  - The launcher requires the actual `[AIBTEST] DONE` marker instead of treating matching START/PASS counts as final cleanup.

Latest targeted visible localhost evidence:

```text
[AIBTEST] PASS stone_miner_discovers_mines_and_delivers_visible_gold
[AIBTEST] PASS stone_corner_escape_from_mirrored_upper_overhangs
[AIBTEST] PASS storage_workshop_skips_obstructed_tent_sites
[AIBTEST] PASS storage_workshop_requires_full_hall_foundation
[AIBTEST] PASS stone_route_prefers_reusable_open_corridor
[AIBTEST] DONE passed=5 failed=0
```

Log: `../../Logs/console-26-07-09-22-06-03.txt`. This is targeted evidence for scenarios 42-46, not a full current-suite pass. Camera transition logs from that run are not visual verification.

After the deterministic shaft-handoff fix, `../../Logs/console-26-07-09-22-33-34.txt` recorded the exact route scenario passing in 133 ticks with `destroyed_dirt=1`; it entered direct control from 15 px away, a position the former 8 px gate rejected. That client was closed before `DONE`, so this is supporting scenario evidence rather than a replacement completed-suite claim.

### Production autonomy contract

- `Scripts/AIBStrategicJobs.as`
  - Adds `AIBS_DefaultModeForGamemode`.
  - CTF defaults to `auto_mode`.
  - AIBTest defaults to `off`; individual scenarios explicitly opt in.
  - Other modes remain conservative and default to `suggest`.
  - Adds a separate CTF-only bootstrap default, safe both-side home spawn search, one-worker-per-round latch, retry cooldown, and deterministic assignment order.
- `Scripts/AIBStrategicDirector.as`
  - Uses the shared default-mode policy.
  - Plans for a team as soon as a team home exists; it no longer requires an AI builder to exist before selecting/publishing a plan.
  - In auto mode, an active pending plan can provision the first worker under the guarded bootstrap contract; later builders are still assigned normally.
  - AI-builder death releases any task reservation immediately.
- `Scripts/AIBTestScenarios.as`
  - Replaces the synthetic manual publish/assign mode check with `strategic_auto_director_heartbeat_end_to_end`.
  - The scenario starts with a team tent, a stocked crate, no AI builder, and auto mode, then waits for the real 30-tick `AIBStrategicDirector.onTick` path.
  - It verifies a production template, score reasons, desired/work layers, untouched human layer, and plan timestamps.
  - Production code provisions exactly one safe worker, assigns it on the heartbeat, claims a task, and physically completes director work without a fixture spawning or funding the builder.

Historical pre-bootstrap production-autonomy evidence (the old test manually deployed three builders):

```text
[AIBTEST] PASS strategic_auto_director_heartbeat_end_to_end ticks=72
default_ctf_auto=true planned_without_builders=true template=archer_perch
desired=18 assigned=3 build_jobs=3 task_claimed=true completed=4
```

Log: `../../Logs/console-26-07-09-19-57-48.txt`.

## Implemented Foundation

- Server-authoritative human and AI blueprint layers.
- Immutable AI desired plan plus consumable AI work grid.
- Human priority and team isolation.
- Shared block catalog used by editor, network/data validation, planning, costing, rendering, and builder placement.
- Doors, platforms, ladders, backwalls, blocks, and supported workshop/blob placement.
- Storage-workshop siting with home/building separation, clear footprints, complete foundations, grounded access, and lifecycle validation.
- Plan/task metadata, versions, phases, reservations, completion/damage state, and plan history.
- Material-aware collection and coordinated wood/stone/construction jobs.
- Guarded CTF first-worker provisioning with safe grounded siting, deterministic assignment, retry cooldown, one-per-round latching, and reservation cleanup on death. This is a free bootstrap spawn, not an economic workshop purchase.
- Low-dirt stone routing with reusable corridors, exact-route clearance, direct shaft movement, mirrored corner recovery, and line-of-sight gold delivery.
- World observation for strategic/resource homes, frontline, combat composition, production-accessible home stock, pressure, explosives/fire, terrain surface, lane width, wall height, and chokepoints.
- Procedural gatehouse, frontline tower, emergency barrier, archer perch, and access-route templates with multiple anchors.
- Bounds, terrain, bedrock, protected-blob, no-build, red-barrier, human-overlap, support, approach, route, sight-line, duplicate, and planning-horizon validation.
- Explainable utility scoring, near-best deterministic variation, template cooldown, continuity, hysteresis, invalidation, and emergency replacement.
- Off/suggest/auto controls and UI rendering of active strategy metadata.
- Seeded abstract simulator, scripted-wave instrumentation, result parser/comparator, and deterministic regression scripts.

## Verification State

Verified on 2026-07-09:

- `Tools/test_aib_strategy_abstract_sim.ps1`: pass.
- `Tools/test_compare_aib_wave_results.ps1`: pass.
- `git diff --check`: pass apart from expected CRLF conversion warnings.
- Visible KAG compilation: pass after replacing three `const Vec2f` operands that KAG's non-const vector operators rejected in the first provisioning launch.
- Production bootstrap heartbeat: focused pass at 156 ticks with one safe worker, one build assignment, a task claim, and three physically completed director tasks (`../../Logs/console-26-07-09-23-00-07.txt`).
- Bootstrap guard case: focused pass at 65 ticks; existing worker, suggest mode, and no-home teams did not provision (`../../Logs/console-26-07-09-23-03-31.txt`).
- The suite currently contains 65 scenarios.
- Prior full-suite evidence, when the source contained 44 scenarios: `44 passed, 0 failed`, with `[AIBTEST] DONE` at game tick 599 in `../../Logs/console-26-07-09-19-57-48.txt`.
- Latest focused evidence for scenarios 42-46: `5 passed, 0 failed`, with `[AIBTEST] DONE` in `../../Logs/console-26-07-09-22-06-03.txt`. This does not verify the displayed camera.
- Post-fix exact route evidence: `[AIBTEST] PASS stone_route_prefers_reusable_open_corridor ... destroyed_dirt=1` in `../../Logs/console-26-07-09-22-33-34.txt`; no `DONE` claim is made for that operator-closed client.

Do not describe the current 65-scenario source as fully passing. A final exact attempt of `strategic_bootstrap_is_one_time_and_releases_reservation` live-compiled the earlier post-audit source and reached tick 30: plan 1 was published, bootstrap worker 10 was created at `2036,572`, and it received blueprint job/state `2/12`. KAG then stopped advancing before the test runner could reserve and kill the worker, so the death/release assertions still did not execute (`../../Logs/console-26-07-09-23-14-01.txt`).

After the earlier runtime logs, a final source audit corrected director ownership of already-working builders, changed fixture material grants to legal 250-unit stacks, stored the original bootstrap spawn for assertions, fixed the reservation assertion to recognize `reserved` state, latched transient claim evidence, and strengthened suggest/no-home/death-release checks. Static regressions and structure checks pass, and the exact attempt above proves the revised source compiles and executes through provisioning/assignment. It does not prove the later death cleanup assertions.

## What Is Not Yet Proven

1. Strategic effectiveness across representative CTF maps.
   - Current fixtures prove mechanics and invariants, not that selected structures consistently improve defense.
2. Trustworthy paired control-versus-plan waves.
   - No completed multi-seed dataset is recorded.
   - Empty-plan rejection, archer ammunition/fire pulses, censored breach handling, fingerprint mismatch rejection, and semantic comparator gates exist in source/regression tests, but have no live-wave validation.
   - Canonical fingerprints are captured before the variant-divergent warmup and must match within each pair; a separate full measurement-start fingerprint now records the realized post-warm-up state without incorrectly requiring control and treatment states to be identical.
   - Pairing now includes fixture id/version, team, side, scenario, and seed and requires three seeds per cohort by default. It is statically verified but has no live records, canonical reset automation, or both-side dataset.
3. Production-weight tuning from real outcomes.
   - Production and the abstract simulator now consume the same 68-key configuration, but the AngelScript loader is not live-compiled and no paired KAG outcome dataset exists. Do not tune from the abstract simulator alone.
4. Full-plan completion and damage/replan behavior on uneven live maps.
   - Static fixtures now require exact damaged-front reactivation without replacement, physical completion of every task in a planner-selected plan, and a distinct fully completed fallback around an uneven near-edge obstruction. They still need their first KAG compile and runtime verdict on the canonical fixture, followed by representative live-map evidence.
5. Bootstrap economy and representative-map safety.
   - The server currently grants one free worker rather than purchasing it through the workshop economy. Administrators can now select CTF's startup mode and disable that grant globally, while moderators can override it per team without resetting its safety latches. Economy balance and the new policy path still need live CTF acceptance.
   - Source fixtures cover both team directions, blocked-home sites, exact retry cooldown, and round-reset reprovisioning; all still need live end-to-end evidence, and uneven live homes remain uncovered.
   - Spawn search can still test as many as 950 positions, but blocker bounds and one bounded home-surface reachability map are now computed once per attempt. Local clearance is no longer enough: a mirrored sealed-pocket fixture requires the candidate to be terrain-connected to the nearest standing cell at home. This remains runtime-uncompiled.
   - Strategic flag anchoring and tent/hall resource capability are now separate in source: flag-only teams preserve plans and Autobuilders but suspend ordinary runners, while total home loss cancels the plan. The split-home guard remains runtime-uncompiled.
6. Test-scene camera correctness.
   - User-visible behavior remains authoritative: the view has stuck upper-left, recentered, jittered, lost scene follow, and prevented manual movement despite logs claiming exact target/view coordinates.
7. Complete player-action/outcome learning episodes.
   - Input/equipment/motion capture and schema-v1 export are live-verified. Schema v3 adds statically tested outcomes, accepted blueprint/director actions, director-shop purchases, and plan/task boundaries, but is not live-compiled. Generic direct hit, explicit pickup/drop, non-director shop purchases, and the full AI-equivalent cost vector remain.
   - Built-in player notice, persistent moderator control, and the host retention/rotation runbook are implemented and statically contracted. They still need a visible KAG compile plus public-server policy review; the `[AIBACT]` format deliberately does not record identity or chat.
8. Full-crate overflow after the final fixture correction.
   - Production code compiles and the scenario now models nine actual occupied slots. Earlier evidence is either an engine stall from 18 queued same-tick items or a valid failure showing identical materials merged rather than filling slots. Run the corrected exact scenario only when visible KAG windows are permitted.
9. Return-path recovery on the reproduced normal-CTF overhang.
   - `console-26-07-10-17-28-51.txt` records worker 68 stuck around `239,368` while returning to `132,316` for more than 1,500 advancing ticks. The 36/90 escape timing fix compiles but has no post-fix reproduction evidence.

## Gym / Learning Decision

Do **not** build or train an RL agent yet. A trainable gym would currently optimize a surrogate whose assumptions are not validated against KAG.

The next useful “gym” is a replayable deterministic KAG evaluation environment, not a learned policy:

1. Export real KAG world snapshots, generated candidates, validation results, selected plan, score terms, and final wave outcomes.
2. Put production scoring weights and template metadata in one shared configuration consumed by both the director and offline evaluator.
3. Run pristine paired control/plan fixtures over both team directions, four wave types, and at least three meaningful seeds. The minimum useful matrix is 48 trials / 24 pairs.
4. Add semantic gates such as fewer crossings, later breach, acceptable friendly-route penalty, and bounded builder losses.
5. Only after the environment predicts real results should weight search, Bayesian optimization, or a contextual bandit be considered. Full reinforcement learning remains unnecessary unless deterministic utility scoring demonstrably plateaus.

## Next Milestones

### Milestone A — trustworthy end-to-end evaluation

- Add asymmetric fixtures for both team directions, uneven terrain, map edges, barriers, occupied bases, no-build sectors, scarce resources, and collapsing frontlines.
- Require safe plan publication and at least one physically completed task in each representative fixture.
- Use the implemented exact/range scenario selection and stale-progress report to verify long/late acceptance scenarios independently when necessary.

### Milestone B — paired wave hardening

- Reset every trial automatically to a canonical fixture; retain the implemented canonical and measurement-start fingerprints.
- Runtime-validate the implemented fixture/version/team/side/scenario/seed pairing contract.
- Retain the implemented seed-dependent cadence/formation and three-seed minimum while collecting both sides.
- Preserve the implemented empty-plan rejection, archer ammunition/fire pulses, censored breach handling, and semantic gates while collecting the first real 48-trial / 24-pair dataset.

### Milestone C — evidence-driven tuning

- Runtime-validate the centralized scoring-weight loader, then tune the shared configuration from recorded KAG outcomes.
- Fit/tune them from recorded KAG outcomes while preserving hard safety constraints.
- Document before/after paired metrics and only then revisit optional adaptive learning.

## Exact Resume Commands

From the mod root:

```powershell
& .\Tools\test_aib_strategy_abstract_sim.ps1
& .\Tools\test_compare_aib_wave_results.ps1
& .\Tools\run_aib_tests.ps1 -Scenario strategic_bootstrap_is_one_time_and_releases_reservation
& .\Tools\run_aib_tests.ps1 -StartScenario strategic_bootstrap_respects_mode_and_existing_worker -EndScenario strategic_bootstrap_is_one_time_and_releases_reservation
git diff --check
rg -n "ERROR .*GuiftsDynamicBlueprint_vDev|\[AIBTEST\] (PASS|FAIL|DONE)" ..\..\Logs -g "console-*.txt"
```

For KAG, follow `AGENTS.md`: launch visibly, do not hide the window, and leave it running unless the user explicitly requests a compile-only/short-run workflow. The AIBTest launch temporarily moves `Rules/CTF/gamemode.cfg`; always restore it immediately after startup and verify that no `.aibtest-disabled` file remains.

## Current Runtime / Worktree Handoff

- The user currently needs the computer; visible KAG pop-ups are disruptive. Do not launch KAG until explicitly permitted.
- `Tools/run_aib_tests.ps1` launches a visible localhost client and leaves KAG running by default after completion, timeout, or stale-progress detection. Use `-StopAfterRun` only when shutdown is intended.
- At this handoff, no KAG process is running.
- `Rules/CTF/gamemode.cfg` is present; no disabled rename should remain.
- Do not use `CAMERA_TARGET` or `CAMERA_VIEW` log records as proof of the displayed camera. Fix/verify camera behavior by human observation in the visible client or leave it explicitly unresolved.
- `AIB_DEBUG` must remain `false` outside focused debugging.
- Root startup is CTF with blank mapcycle and shuffle enabled. All AIBTest selectors are blank.
- The worktree contains pre-existing unrelated edits and untracked files. Review scope carefully and do not commit the whole tree indiscriminately.
- Core current-milestone files are `Scripts/AIBStrategicDirector.as`, `Scripts/AIBStrategicJobs.as`, `Scripts/AIBWorldModel.as`, `Scripts/AIBHomeResourceCommon.as`, `Scripts/AIBManualOrderCommon.as`, `Scripts/AIBTestScenarios.as`, `README.md`, this status file, and `AI_BLUEPRINT_DIRECTOR_HANDOFF.md`.

## Acceptance Gate For “Complete”

Do not mark the director complete until all of the following are evidenced:

- Current deterministic suite coverage is reproducible, including the production heartbeat scenario.
- Autonomous plans safely begin and materially progress on representative maps for both team directions.
- At least one multi-seed paired wave dataset shows useful defense without unacceptable friendly-route or builder-loss regressions.
- Scoring changes are tied to measured outcomes rather than intuition alone.
- Manual visible CTF play confirms that default auto behavior is understandable, stable, and fun.
