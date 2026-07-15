# KAG Engine Quirks Ledger

This is the durable record of engine behavior that can make correct-looking KAG mod code fail or produce misleading test evidence. Add an entry when a quirk is reproduced; include the symptom, the unsafe conclusion, a reliable check, and the workaround. Do not turn guesses into rules.

## Runtime And Test Process

### Visible `RunLocalhost` can look frozen when its console observation stops

- Symptom: the builder appears to stop mid-action and the console file stops after a heartbeat or `Waiting for scripts...`.
- Corrected build-4762 evidence (2026-07-15): after a minimal localhost console stopped at game time 30, read-only native traces showed the main pause byte clear, the initialized rules tick advancing from 905 through 912, the network callback enabled, and the error-free `aibresearchminimalprobe` `onTick` hook entering the per-script dispatcher on consecutive cycles.
- Do not conclude: an unchanged console file, missing heartbeat, or frozen-looking client pose proves that the entire simulation stopped. The old log-only classification conflated an observation-channel stall with a simulation stall.
- Reliable check: require a non-console state or physical outcome to stop as well. Native rules-tick sampling is a diagnostic option; normal test evidence should use a directly readable state/verdict channel once one is validated.
- Current workaround: classify a stopped file log by itself as `observation_stalled` and report the automated result as inconclusive. Use visible CTF/manual play for sustained harvesting, mining, navigation, construction, and director acceptance, and do not transfer an AIBTest-only apparent freeze into production AI code without reproducing the behavior in CTF.
- Diagnostic requirement: harvesting fixtures emit change-only blob deltas for tree health/growth/support, logs, loose resources, carried resources, inventory, and crate storage, but those records are still unavailable if the console transport itself stops.

### Final AIBTest verdicts intentionally freeze their fixture

- Symptom: a builder stops mid-task immediately after the overlay changes to `FAIL - FROZEN` or `PASS - FROZEN`.
- Cause: `AIBT_FreezeFinalFixture()` deliberately disables the fixture after the final verdict so humans can inspect it.
- Do not conclude: the production brain chose to stop. Check the overlay and final verdict first.
- Test-design rule: deadlines must cover the complete physical action. A tree fixture now receives 1,800 in-game ticks and cannot fail at the old short chopping deadline.

### A terrain-mutating fixture can invalidate the next hot restart before behavior begins

- Symptom: a direct cold start or an immediate second hot restart of `stone_corner_escape_from_mirrored_upper_overhangs` freezes as `FAIL` at elapsed tick 1 with `canonical_fixture_reset_failed tile_hash_mismatch expected=3810503333 actual=3332178581`.
- Reproduced on build 4762 (2026-07-15): the first clean hill-to-corner hot switch passed its full recovery cycle, while the immediate corner-to-corner rebuild produced the same hash mismatch. Starting directly on the corner fixture reproduced the mismatch during the controller restart. No movement intent or displacement preceded either failure.
- Do not conclude: this verdict is an AI recovery failure. It is the canonical map guard rejecting setup state before the behavior window.
- Uncertainty: the exact terrain mutation that survives that rebuild boundary is not yet isolated; do not weaken the canonical hash or silently recapture the modified map.
- Workaround: for repeatability evidence, start a fresh visible process on a non-mutating fixture, hot-switch once into the terrain-mutating fixture, then close the process. Record setup-guard failures separately from behavior outcomes.

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
- Observed on build 4762: the current CTF rules reported this for `clearBlueprintLayer`, the original `aib telemetry notice`, and `SendChatMessage` during initialization. The telemetry notice now renders client-side from the synced capture flag and does not allocate a command ID.
- Do not conclude: another `addCommandID` is harmless because command names are strings or because compilation succeeds.
- Workaround: reuse existing commands, consolidate related operations behind one command plus a compact opcode, and remove duplicate registrations before adding new IDs. Treat this startup warning as a correctness risk requiring a separate command-table audit.

### An early typed-property read can defeat an `exists()` initialization guard

- Symptom: CTF telemetry resolves an enabled policy and `gamemode_name = CTF`, but its rules boolean is already present and false when the owning script initializes.
- Reproduced on build 4762: director boundary code read `get_bool("aib player action log enabled")` before `AIBPlayerActionLog.as::onInit`; the later `exists("aib player action log enabled")` returned true and suppressed the configured `true` default. The runtime line recorded `policy_loaded=true`, `default=true`, and `enabled=false`.
- Do not conclude: `exists()` proves that an administrator or an earlier owner intentionally assigned the value.
- Workaround: use a dedicated owner-controlled initialization sentinel. Apply the policy when that sentinel is false, then set it true; round restarts preserve both the sentinel and moderator override, while a newly created rules object receives the configured default.

### A stopped localhost console file is not a simulation clock

- Symptom: the KAG process and window remain alive, while `[AIBTEST]` heartbeats and the console file stop changing.
- Do not conclude: the scenario clock necessarily stopped. Build-4762 native evidence above proves that rules ticks and script dispatch can continue after the file stops.
- Reliable check: log length is only logger health. A completed automated run still needs a fresh correlated verdict, but a missing verdict must be classified as observation failure unless an independent state/physical clock also stops.
- Workaround: preserve the last console heartbeat as partial evidence only. The existing `Tools/run_aib_tests.ps1` stale diagnostic remains useful operationally, but its wording must not be treated as native proof of a stopped simulation. A PASS without final `DONE` is still not a completed run.

### Selective TCPR does not forward ordinary `print()` output

- Symptom: an authenticated TCPR socket accepts a console `print()` expression but receives no bytes, even though the same connection remains open.
- Reproduced on build 4762 (2026-07-15): with `sv_tcpr = true`, `sv_tcpr_everything = false`, and `sv_tcpr_timestamp = false`, a runtime-assembled `print()` marker produced no TCPR record during a bounded 15-second receive window. Replacing only the expression with runtime-assembled `tcpr(...)` returned the exact marker on the same port/protocol.
- Do not conclude: a silent socket means TCPR authentication, the listener, or the simulation failed. In selective mode it means the expression did not use an explicitly forwarded channel.
- Additional evidence: sending the console command `sv_tcpr_everything 1` to an already-running listener did not make a subsequent assembled `print()` marker observable. Treat forwarding scope as a listener-start setting, not a reliable runtime toggle.
- Workaround: keep production `sv_tcpr_everything = false` and emit only compact, intentional `tcpr(...)` records. The research controller temporarily writes `true` before launching its owned process so the bounded rebuild compiler transaction is visible, still uses explicit READY/server ACK/state/DONE records for protocol boundaries, and restores `false` only after KAG exits.

### An early TCPR accept can reset before the listener is ready for a transaction

- Symptom: the controller opens an authenticated socket during visible KAG startup, then the first command fails with a connection reset and the run produces no metric row.
- Reproduced on build 4762 (2026-07-15): `gloryhill_downpath_candidate_1b_001` reached the listener during its startup transition, lost that socket before the benchmark arm transaction, and was excluded rather than counted as a physical episode. A fresh retry after requiring one connection to remain live for three seconds completed normally.
- Do not conclude: the first successful TCP connect proves the rules listener is stable enough for a multi-command benchmark transaction, or that an aborted transport is a zero-score episode.
- Workaround: `tcpr_send.py --stability-seconds 3` reconnects within the bounded connect deadline until one authenticated socket survives the stability window. `Invoke-AIBGymResourceRun.ps1` uses that setting, requires exactly one aggregate result plus the expected worker rows, and restores CTF only after its owned KAG process exits.

### Localhost TCPR expressions observe client rules; server work needs a rules command

- Symptom: `getRules()` queries through TCPR retain client-local unsynced values, and a direct `LoadRules(...)` expression creates a BOOTING client rules object while the server-only AIBTest runner never advances it.
- Reproduced on build 4762 (2026-07-15): direct client rules loading remained `done=0`, `scenario=boot`, `status=AIBTEST: BOOTING` while game time advanced to 1,785. Earlier queries also retained the client-local `aibfast_armed` scenario after the server-synced final status had changed to PASS.
- Do not conclude: an inbound RCON/TCPR expression using `getRules()` automatically runs in authoritative server script context merely because the TCP listener belongs to the localhost server.
- Workaround: register a research-only `CRules` command on both sides, send it from the client rules object, validate it in `onCommand` with `isServer()`, and perform the privileged action on that server callback. Verdict fields should be read and emitted by the server bridge, not reconstructed from unsynced client properties.

### Rules restart is a server `CRules` method, not a global console primitive

- Symptom: sending global `RestartRules()` leaves a uniquely armed rules state unchanged while game time and TCPR queries continue normally.
- Reproduced on build 4762 (2026-07-15): the armed state remained intact through a 60-second bound and game time 2,301. Base/working-mod source uses `this.RestartRules()` on a `CRules` object; no working global `RestartRules()` call was found.
- Reliable path: the research server bridge acknowledges a client rules command, calls `this.RestartRules()`, and emits the exact server verdict for the same epoch. A controlled run ACKed at game time 692 and completed after the restarted rules clock reached game time 6.
- Same-PID rebuild proof: PID 21240 loaded bridge protocol 1, the source was changed to protocol 2 while it stayed open, and the next `rebuild()`/server-restart run returned protocol 2 plus an exact PASS. The hot controller took 2.2 seconds wall-clock; rebuild return was 156 ms and server request-to-DONE was 594 ms.
- Compile-failure proof: with full forwarding enabled at process start, a deliberate missing expression in `AIBFastServerBridge.as` produced four exact compiler errors. The controller returned compile-failure exit code 7 in 1.8 seconds, did not accept a server verdict, closed KAG, and restored CTF plus `sv_tcpr_everything = false`.
- Workaround: use the research `CRules.SendCommand` bridge plus server `this.RestartRules()` for focused iteration. Do not use direct client `LoadRules`, global `RestartRules()`, or file-log growth as the completion mechanism.

### A CTF pressure wave in staging is not valid evidence

- Symptom: the harness spawns all 12 enemy units and reaches its 1,200-tick result, but records zero crossings, deaths, flag approaches, or damage while the client still says there are not enough players to start.
- Reproduced on build 4762: `console-26-07-14-08-34-31.txt` emitted a complete `wave_result`; a TCPR count confirmed 12 tagged knights, with the first still at enemy-side x=1447.69. The visible client remained in `Staging` and the pre-match barrier prevented a representative attack.
- Do not conclude: a structurally complete result record is a trustworthy control trial.
- Workaround: require `CRules.isMatchRunning()` before measurement capture. Abort with `match_not_running` while staging, then start the match with real players/bots and use a fresh canonical map before collecting the trial.

### Directly driven runners retain buttons and do not scale terrain automatically

- Symptom: a wave runner advances from its spawn and then remains motionless with its horizontal movement key still pressed; a completed trial can therefore report 12 living attackers and zero pressure outcomes.
- Reproduced on build 4762: in `console-26-07-14-08-57-28.txt`, a directly spawned team-1 knight was dynamic, unattached, outside inventory, and had a brain, but was not bound to a player or bot. One leftward velocity/input advanced it from x=1580 to x=1447.69, where it remained with `left=true`. Giving its brain the opposing tent as a target did not move it. Holding jump for one second cleared the obstruction to x=1442.69, after which ordinary left input advanced it to x=1391.24 before the next obstruction.
- Do not conclude: a pressed horizontal key, forced velocity, a non-null `CBrain`, or a path target proves that an unbound runner can traverse representative CTF terrain. Also do not assume buttons clear when the rules script stops driving them.
- Additional evidence: the first speed-based recovery advanced all 12 runners from x=1580 to x=983 in `console-26-07-14-09-10-55.txt`, but they converged at the next blocker. The rules-side forced velocity was not a reliable stall signal because intent velocity could remain nonzero while collision prevented displacement.
- The displacement-based retry compiled and ran in `console-26-07-14-09-20-52.txt`, but all 12 runners fell into Gloryhill's central pit and converged at approximately `(983,400)`. A later clear/grounded home-relative spawn experiment in `console-26-07-14-09-33-31.txt` selected another pit at `(340,380)` and stalled near `(280,368)`; it was reverted rather than promoted to production.
- Workaround: the wave controller measures forward x displacement, holds jump for a bounded interval when that progress stalls, releases before a bounded retry, and explicitly clears synthetic controls when the trial finishes. It aborts `no_pressure_outcome` rather than emitting a comparable zero-pressure record. A future alternate spawn must prove route connectivity, not merely clear volume and solid ground. Keys and velocity are intent evidence, not motion evidence.

### `const Vec2f` can lose ordinary vector operators in AngelScript

- Symptom: code that reads a rules vector into `const Vec2f` fails compilation on equality with `Vec2f_zero` and addition with a temporary `Vec2f`, even though the same operators work on a mutable local.
- Reproduced on build 4762: `console-26-07-14-09-30-43.txt` rejected `spawn == Vec2f_zero`, `spawn + Vec2f(0, yOffset)`, and a second `const Vec2f` zero comparison while compiling the wave harness/arm helper.
- Reconfirmed on build 4762 in `console-26-07-15-16-44-10.txt`: the physical infrastructure benchmark rejected both `feet +/- Vec2f(...)` and `start + Vec2f(...)` solely because `feet` and `start` were `const Vec2f` locals. The compile failed before the benchmark START boundary; making those locals mutable is the runtime-verified workaround under test.
- Do not conclude: C++-style const qualification is transparent to KAG's AngelScript operator overload resolution.
- Workaround: keep local `Vec2f` values mutable when they need engine-defined equality or arithmetic operators. Const scalar components remain safe.

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

### A custom one-map CTF cycle can also restart recursively

- Symptom: visible CTF repeatedly reloads the same ordinary CTF PNG at game time zero, emits `MAP WAS NEVER LOADED`, and never reaches gameplay.
- Reproduced case: the developer launcher pointed CTF at a unique one-entry cycle containing `Maps/Official/CTF/HearthPlains.png`; the log repeatedly re-entered `PostGameMapVotes.as`/`LoadNextMap()` despite the map itself being valid in the normal rotation.
- Do not conclude: a unique cycle filename alone makes one-map CTF startup safe; the recursion is not specific to the AIBTest cycle's basename.
- Workaround: leave `sv_mapcycle` blank so CTF loads `Rules/CTF/mapcycle.cfg`. For repeatable fresh launches, disable shuffle and use the rotation's first map rather than replacing the rotation with a one-map file.

### A test-map basename can override an official CTF map

- Symptom: CTF requests `Maps/Official/CTF/8x_Gloryhill.png`, but the log reports that it loaded `../Mods/GuiftsDynamicBlueprint_vDev/Maps/AIBTest/8x_Gloryhill.png` and the visible terrain is the test copy.
- Cause: KAG's mod resolver matches colliding asset basenames across folders; a copied reference PNG inside the mod overrides the official map even though its directory is different.
- Reliable check: use the `LOADING PNG MAP` log record and visually confirm the terrain. The configured mapcycle path alone is not evidence of which asset won resolution.
- Workaround: every mod-owned reference/test map must have a basename that cannot collide with a public map. The copied reference is named `aib_reference_8x_Gloryhill.png`.

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

### Wooden platforms normalize to an unstable numeric neutral-team sentinel

- Symptom: a healthy director-built `wooden_platform` matches in its creation tick, then a team-aware verifier reports task damage even though the platform remains present.
- Cause: base `WoodenPlatform.as` deliberately calls `server_setTeamNum(-1)` so anyone can break the platform. Across AngelScript API boundaries that neutral team can be observed as signed `-1` or unsigned `255`; comparing either numeric value is not a stable identity contract.
- Reproduced evidence: `../../Logs/console-26-07-14-05-21-18.txt` completed team-1 platform `(178,36)` at tick 2410, reported damage at 2430, rebuilt it at 2442, and reported damage again at 2460. A first attempted signed-`-1` exception reproduced the exact failures in `../../Logs/console-26-07-14-05-42-21.txt`. After matching neutral ownership by catalog block type, `../../Logs/console-26-07-14-05-46-02.txt` completed `(178,36)` at tick 2410 and `(176,36)` at tick 2434 with no platform damage through tick 3690.
- Do not conclude: a team mismatch means a platform disappeared or belongs to an opponent. Also do not generalize team-agnostic matching to doors, bridges, workshops, or other team-bearing blobs.
- Workaround: declare `AIBP_PLATFORM` neutral by catalog identity and ignore its mutable engine team only when matching that exact block type. Store a separate originating-team property on director-created blobs so planner overlap checks can distinguish adjacent friendly blueprint work from other structures.

### Doors need adjacent solid foreground before the delayed collapse check

- Symptom: a newly placed door completes and remains visible, then the director reports the same task damaged roughly 300 ticks later and rebuilds it repeatedly.
- Cause: base `CollapseMissingAdjacent.as` waits ten seconds before making a door non-static when it has no adjacent solid foreground. Backwall support is sufficient for initial placement but does not satisfy this durability rule.
- Reproduced evidence: `../../Logs/console-26-07-14-05-46-02.txt` completed stone door `(175,39)` at tick 2444, then reported damage at ticks 2940 and 3660. In `../../Logs/console-26-07-14-07-03-51.txt`, both doors were deferred until the side-wall shell existed, completed at ticks 3133 and 3141, archived the plan as completed, and produced no damage through tick 3630.
- Do not conclude: successful placement or short-term identity matching proves a door is structurally durable.
- Workaround: put doors in a closure phase after their adjacent foreground shell. Verify for more than the ten-second/300-tick collapse delay before accepting the result.

### A grounded runner cannot engage a ladder through a one-tile opening

- Symptom: a builder standing above a valid ladder repeatedly replans a short downward route, or stops replanning after a direct controller takes over but remains motionless while holding `key_down`.
- Cause: `DetectLadder.as` uses `Script::tick_not_onground`, and `RunnerMovement.as` applies ladder force only when `blob.isOnLadder()` is already true. A runner is wider than one eight-pixel tile, so solid/platform cells on both sides of a one-tile opening keep it grounded; pressing down crouches instead of entering the ladder.
- Reproduced evidence: `../../Logs/console-26-07-14-06-46-11.txt` entered phase 4 at tick 2585 from `(1422,280)` and then repeated three-waypoint replans to `(1420,300)`. A placed-ladder-owned controller suppressed those replans in `../../Logs/console-26-07-14-06-53-30.txt`, but the task still made no progress through tick 3630. After the platform and roof openings were widened toward team home, `../../Logs/console-26-07-14-07-03-51.txt` crossed the former platform bottleneck and completed both closure tasks.
- Do not conclude: a nearby ladder blob, a pressed down key, or a non-empty suggested path proves the character can enter the ladder state.
- Workaround: keep a two-tile runner-width opening at the ladder, orient the open side toward home, approach the midpoint of that opening, and let the direct controller own centering/descent until normal build range resumes.

### Engine pathing and direct movement can fight each other

- Symptom: builders jump in place, oscillate between surface and shaft nodes, or repeatedly replan near a valid destination.
- Cause: generic obstruction recovery, ladder/jump behavior, custom `BrainPath`
  suggestions (or native `CBrain` suggestions in fallback), and a specialized
  direct shaft/tunnel controller can issue conflicting intent.
- Workaround: give specialized movement explicit ownership while active. Suppress generic jumps/recovery ladders during dedicated tunnel movement, clear stale paths on state/target changes, and hand off only at a deterministic proximity/visibility boundary.

### Normal AI Builder travel uses custom AngelScript pathing while native `CBrain` stays idle

- Scope: this is the current mod/engine integration on build 4762, not a claim that KAG's native pathfinder is globally unused.
- Cause: `AIB_GoTo` prefers `AIB_GoToBrainPath`; CTF and AIBTest both load `PathingNodes.as`, so a non-empty `node_map` normally drives `BrainPath.SetPath/Tick/SetSuggestedKeys` and `CBlob.setKeyPressed`. A new custom route clears native state with `CBrain.EndPath()`. Only `AIB_GoToFallback` calls native `CBrain.SetPathTo` and `CBrain.SetSuggestedKeys`; it is reached when the node map/custom path is unavailable or a custom search yields no usable route while the goal is still distant.
- Reproduced evidence (2026-07-15): three hot runs each of hill travel, storage delivery, and the corrected physical obstacle fixture all moved and passed with exactly one custom `path_set`/repath. Native `CBrain.getState()` remained `idle` for every observer sample: 12/12, 22/22, and 46/46 respectively.
- Do not conclude: native `CBrain::idle` means the ordinary builder has no path or movement controller. It can mean the custom path deliberately cleared native state and is writing blob keys itself.
- Workaround: report controller ownership explicitly (`custom BrainPath`, `native CBrain fallback`, or specialized direct keys). Diagnose custom waypoint/low-path state and blob input before investigating native `CBrain` state. Test native fallback only in an isolated fixture that withholds `node_map`; do not remove the production node map merely to make a test use native pathing.

### Rules-side movement observers see Builder brain intent and horizontal motion on later samples

- Reproduced on build 4762 (2026-07-15): in three identical hill hot restarts, the server Builder brain emitted custom `path_set` at game tick 6. The passive `CRules` observer first saw the destination and movement input at tick 7, then first saw observer-to-observer horizontal displacement at tick 8. Each run finished at elapsed tick 11 with 13.6 px net leftward movement and zero stalled-intent samples.
- Native support: focused binding analysis maps `CBlob.setKeyPressed` to an immediate input-bit read/modify/write and `isKeyPressed` to a read of that same mask. The runtime lag is callback/physics ordering, not deferred property storage.
- Do not conclude: no displacement in the rules callback carrying the same game-time value as an AI decision is a motion stall. New-blob `getOldPosition()` can also contain a spawn snapshot unsuitable for first-tick progress proof.
- Reliable ordering for this configuration: rules observer at tick N; later Builder `CBrain.onTick` at tick N writes intent; the next rules sample observes that intent; horizontal movement is observable by the following sample. This is scoped to the tested server rules/brain/movement hooks, not all client/network callbacks.
- Workaround: correlate intent with a one-to-two-sample future window and require horizontal or goal-directed displacement, not any position delta. Keep gravity settling separate from path progress.

### A path request is not evidence of progress

- Symptom: `SetPathTo` succeeds or path nodes exist, but the builder's displacement and task state do not advance.
- Do not conclude: a non-empty path means the goal is reachable or the movement controller is following it.
- Reliable check: gym assertions must track displacement, distance-to-goal trend, state age, repeated jumps, replan count, and task-side effects.
- Workaround: diagnose intent, motion, and outcome separately. Emit a bounded timeline around the first progress violation.
- Reproduced test pitfall (2026-07-15): the former `pathing_obstacle_recovery` fixture, now named `pathing_reaches_obstacle_region`, previously accepted either physical entry into the obstacle region or a non-zero destination. Three hot runs passed at elapsed tick 2 with zero horizontal displacement and zero movement-intent samples; the only 0.4 px delta was vertical spawn settling. The fixture now requires physical entry and then passed three hot runs at elapsed tick 45 after 108.4 px net horizontal travel, with 43 intent ticks and zero stalls. It does not claim that a recovery branch ran.

### A fallen log can retain a nominal path while making no physical progress

- Symptom: after processing most logs from a felled tree, a builder targets a final log that has rolled or settled behind obstructing terrain. `BrainPath` continues returning a non-empty short route and obstruction recovery repeatedly replans it, but the builder does not approach or hit the log.
- Reproduced on build 4762 (2026-07-15), official 8x_Gloryhill map hash `3142477075`: in `gloryhill_log_path_trace_001`, the builder acquired log 66 at game tick 1177, retained a three-waypoint route to `(174,316)`, and replanned every 21 ticks while staying near `(152,288)`. The gym latched a motion stall with only 6 px maximum displacement and zero interactions. The target was abandoned at tick 1478, 301 ticks after acquisition, and the worker then returned 190 wood.
- Do not conclude: a live log target and a non-empty `BrainPath` route mean the log remains economically reachable, or that the pre-target tree-to-log spawn wait is responsible. This case begins only after the log entity exists and is selected.
- Mitigation evidence: changing only the post-target log no-progress window from 300 to 90 ticks left the separate `find_log` spawn wait unchanged. In `gloryhill_log_watchdog_candidate_001`, an obstructed log acquired at tick 832 was abandoned at tick 923 after 91 ticks without an 8 px approach gain or a hit; the worker continued to another log and had collected/delivered 190 wood by episode tick 900, with zero latched failures at tick 1200. The control delivered the same 190 only at episode tick 1200 and latched one failure.
- Full-cohort result: three exact-map 5,400-tick controls at 300 ticks collected an average of 630 wood; three 90-tick candidates averaged 546.667. Both sides had zero deaths and all three runs latched a failure. The candidate therefore failed the throughput/quality gate despite the focused timing improvement.
- Subsequent route-recovery result: with the watchdog restored to 300, the current vertical-node/overhang candidate collected 800/550/550 wood (mean 633.333) against the retained 850/550/490 controls (mean 630). Deaths remained zero and failure-flagged runs improved from 3/3 to 0/3. `Tools/compare_aib_gym_results.ps1 -RequireImprovement` reported `AcceptancePassed=true`; the +3.333 throughput delta is marginal, while the reliability change is the material result.
- Workaround: keep the log-specific post-target watchdog separate, reset it on meaningful approach progress or a successful hit, cool down only the unproductive log, and continue the tree episode. Production remains at 300 ticks because the 90-tick change itself lost its cohort; the later route win does not retroactively validate that timeout. Never shorten or reinterpret `AIB_LOG_WAIT`, because waiting for the engine to create the first log is intentional no-target time.

### BrainPath can return a vertical node that ordinary runner keys cannot enact directly

- Down-node symptom: `BrainPath` can repeatedly return a node directly below a supported runner. There is no useful ordinary `key_down` action in that state, so path keys and jump scaling can leave the runner balanced on the lip.
- Reproduced on build 4762 (2026-07-15), official 8x_Gloryhill: `gloryhill_vertical_descent_trace_001` retained next node `(152,304)` from position `(152,288)` while targeting a log at `(174,316)` and finished with zero delivered material plus a motion-stall flag. The bounded lateral walk-off candidate crossed the lip, removed the log at tick 1094, delivered 240 wood at tick 1181, and finished without a failure. Later current-code diagnostics retained real open-drop events and delivered 250 wood by tick 1200.
- Up-node symptom: in the central Gloryhill shaft, a path repeatedly requested approximately `(1048,368)` from a runner near `(1047,383)`. Generic jumping/replanning oscillated at the shaft bottom. A bounded up-plus-away controller that keys off the current left/right wall made sustained return progress and removed the focused failure, but the focused 3,900-tick run ended while the load was still in transit; treat its throughput effect as cohort evidence, not a standalone delivery claim.
- Do not conclude: a vertical low-level node is a physically executable character action, or that suppressing `AIB_ScaleObstacles` is safe for every nominal down node.
- Workaround: after confirmed obstruction, ordinary travel may temporarily own keys for a straight-down open walk-off or a straight-up wall-assisted climb. Dedicated stone-route movement, ladders, and water remain excluded. Direct ownership is bounded and emits change-only start/turn/release events; normal `BrainPath` keys and obstacle scaling resume outside those exact geometries.

### A far-side wall can mean either a blocked ledge or a valid narrow drop

- Blocked-ledged reproduction: while approaching a tree at `(1012,336)`, a runner near `(909,284)` received a nominal node around `(904,304)` and initially walked toward a two-high thickstone/bedrock wall. A probe that looked two tiles ahead rejected the required run-up entirely and stranded the worker at `(904,288)`, causing 21-tick replans and sequential tree abandonment. That version was rejected.
- Current blocked-side evidence: the adjacent-body probe in `gloryhill_downclear_trace_003` emitted `path_downward_release reason=blocked_side` at tick 2784, corner recovery engaged 13 ticks later, and the runner crossed, felled the target tree, and processed its logs without a gym failure.
- Narrow-drop reproduction: `gloryhill_verticalpath_candidate_1b_008` later stalled in `chop_log` near `(1289,336)` for a log at `(1303,401)`. The official map has an open adjacent drop at tile 162 and an opposite wall at tile 163, so treating every far-side solid sample as a blocked ledge suppresses the correct walk-off.
- Workaround: release direct descent only when the adjacent side is blocked or lacks open body/below space. If the far probe is solid but the adjacent column fits the runner and remains open one tile below, retain bounded walk-off ownership as a narrow shaft. The first three current-code full episodes produced 800/550/550 with zero failure-flagged runs; no event-logged replay landed the identical deep log, so keep the exact narrow-shaft branch under future focused observation rather than claiming a matched replay.

### An isolated upper diagonal can trap a runner without a solid sample directly overhead

- Symptom: from `(40,255)`, Gloryhill repeatedly returned the rightward node `(56,256)` while the runner's head caught the upper-right diagonal. The old corner detector required `ceiling && upperDiagonal && !bodySide`, so it never recognized this diagonal-only shape and two log targets exhausted their 300-tick watchdogs.
- Do not broaden the detector to symmetric headroom: tunnels with both upper sides solid are not one-sided escape corners.
- Workaround and evidence: accept a diagonal-only overhang only when the opposite upper sample and the body-height escape side are open. The visible `stone_corner_escape_from_mirrored_upper_overhangs` fixture now builds mirrored diagonal-only castle traps and passed at tick 138 with both 36-tick drives, both 90-tick cooldown latches, at least one tile of displacement on each side, and intact traps. The prior ceiling-plus-diagonal geometry also passed under the same production code before the fixture was narrowed to this new case.

### A resource worker with the player tag can capture a CTF flag by collision

- Symptom: an AI builder following a resource route touches the enemy flag, becomes its carrier, and returns it to the friendly base even though it has no capture order.
- Reproduced on build 4762 (2026-07-15), official 8x_Gloryhill: the user visibly observed the capture during `gloryhill_4b_scoped_baseline_002`; the fail-closed gym guard then emitted `AIBGYM|CONTAMINATION|kind=worker_flag_pickup|slot=2|worker=59|flag=48|restored=true` in `console-26-07-15-15-34-29.txt` and aborted the episode before a result row.
- Cause: ordinary AI builders retain KAG's `player` tag for class behavior, so the shared CTF `canPickupFlag` collision predicate accepted them like human players.
- Do not conclude: returning to base proves the worker intentionally selected the flag, or that a resource score collected during the contaminated episode is comparable.
- Workaround and evidence: the mod override `Base/Entities/Special/CTF/CTF_FlagCommon.as` rejects `aibuilder` and `autobuilder` in `canPickupFlag` while leaving normal players unchanged. The gym independently restores the exact flag to its matching base and aborts if contamination ever recurs. Two full post-fix controls and all three full candidate episodes completed without contamination.

### A stone miner needs its shaft controller after switching to return_wood

- Symptom: a miner finishes a load underground, changes from `tunnel_to_stone` to `return_wood`, and then spends the rest of the episode near the bottom of its own two-wide shaft. A non-zero ordinary destination does not make that return physically executable.
- Reproduced on build 4762 (2026-07-15), official 8x_Gloryhill: all three four-builder controls latched stone failures around `(63,327)` or `(58,280)`. Stone slots stopped after one delivery at 156 and 120 material. The initial return candidate also stalled at `(71,336)` because it demanded one-pixel horizontal centering before pressing up; a half-tile-only revision fell into the adjacent column because it did not hold wall direction and up together.
- Cause: the production route deliberately uses a dedicated shaft/cross-tunnel controller only in state 10. Reaching quota changes to state 6 before the miner has climbed out, handing an open vertical shaft back to ordinary `BrainPath`.
- Workaround: record the canonical surface entry column and height when `find_stone` commits to a route. During `return_wood`, drive horizontally through the already-open cross-tunnel, then hold both direction into the shaft wall and `key_up` until the runner is within the surface margin. Clear the anchor with every normal navigation/ownership handoff.
- Evidence and remaining limitation: `gloryhill_4b_stone_return_candidate_trace_003` in `console-26-07-15-16-05-06.txt` recorded repeated `stone_return_direct`/`stone_return_exit` transitions from y=336/344 to y=281-290 and delivered 888 stone plus 80 gold by 2,400 ticks. The exact 3x3 full cohort increased mean delivery from 942.667 to 1,574.000 (+631.333, +67.0%) with zero deaths on both sides. All candidate runs still latched recoverable motion-stall windows during slow cross-tunnel returns, so the fix is a throughput win, not failure-free pathing.

### A pre-behavior observer can mistake stationary chopping for a motion stall

- Symptom: a builder is visibly hitting a tree and the tree is falling, but AIBTest aborts with `gym_progress_violation kind=motion_stall`, zero sampled interactions, and a still-populated approach destination.
- Cause: `AIBG_Tick` runs before the AI behavior for that tick. Sampling action keys there can miss `key_action2` and `server_Hit` performed later in `AIB_ChopTree`; retaining the completed approach destination simultaneously looks like movement intent even though standing still is correct.
- Reproduced on build 4762 (2026-07-15): `gym_tree_order_harvests_and_delivers_selected_tree` first failed after 184 scenario ticks while visibly chopping/felling the tree. After close-range tree/log branches ended the approach path and successful `AIB_HitTarget` calls explicitly recorded an interaction, the same visible KAG scenario passed at tick 1032 with the tree felled, logs processed, 350 wood acquired and delivered, and `gym_flags=none`.
- The same observer gap applied to `AIB_MineTile`: the reusable-shaft fixture showed successful dirt/stone destruction but no explicit interaction record, producing a state-stall bit. Successful tile destruction now calls `AIBG_RecordInteraction`, and a motion-stall bit is removed only when the same window contains a confirmed interaction or material/plan outcome; independent jump-loop and path-thrash bits remain.
- The same stale-intent class occurred at base storage: `carried_wood_returns_to_grounded_storage` reached the interaction radius and transferred/spent part of its material, but retained the approach destination and failed at tick 143 as a motion stall. Ending the path at the storage radius removed the false gym verdict; the corrected production fixture, `carried_wood_builds_grounded_storage_and_delivers`, then passed at tick 25 with a valid grounded workshop, a distinct grounded resource crate, and 40 wood delivered after storage costs.
- Do not conclude: zero displacement while chopping, mining, building, or waiting for an engine-spawned object is a navigation failure.
- Workaround: clear stale navigation intent at the interaction boundary, record successful production interactions explicitly, and exempt declared engine waits such as `find_log` before the log-spawn deadline. End-to-end tree tests must wait for the tree to fall, logs to appear, logs to be processed, and delivery to finish.

### A short corner escape can feed the worker straight back into the trap

- Symptom: exact mirrored-overhang detection fires correctly, but every event reports nearly the same position; after a short walk away, path control immediately returns the worker beneath the ceiling.
- Reproduced CTF return route: worker stayed around `239,368` while targeting storage `132,316`, alternating five-waypoint paths, obstruction replans, and rightward escapes for more than 1,500 advancing ticks.
- Do not conclude: detecting the correct escape direction proves recovery completed.
- Workaround: the geometry-specific direct controller owns movement for 36 ticks to create a real run-up, followed by a 90-tick recovery cooldown. Judge success by displacement and eventual task progress, not by the escape event itself.

### Inventory fullness is asynchronous and `canPutItem` depends on candidate ownership

- Symptom: a fixture loops on `!inventory.isFull()` while calling `server_PutInInventory`, queues more items than the configured slot count, then the visible localhost simulation freezes during replication.
- Reproduced cases: a 3x3 crate accepted/queued 18 material blobs in one setup tick before the loop observed fullness; later, a crate with nine settled 1x1 entries still reported `isFull() == false` in `console-26-07-14-10-04-11.txt`.
- Additional build-4762 evidence (2026-07-15): `stone_order_mines_exposed_stone_and_delivers` reached an alive, grounded, same-team, unpacked empty crate with a valid inventory and 24 stone still in the builder inventory. `crateInventory.canPutItem(stone)` returned false, so the preflight selector rejected the otherwise eligible crate for more than 600 ticks. Replacing that held-item preflight with the real remove/insert/restore transaction made the same scenario pass at tick 140 with all 24 stone in the crate. `full_crate_creates_grounded_overflow_storage` then passed at tick 23 with two grounded crates, 100 stone stored, the 150-wood cost paid, and material conservation intact.
- Do not conclude: `isFull()` is a synchronous postcondition, or that `canPutItem(item)` predicts insertion while `item` is still owned by a different inventory.
- Workaround: use the configured slot count and item footprints when constructing deterministic full fixtures, and let queued mutations settle before evaluating them. In production transfer code, take the exact material out of the source inventory, use the destination's `server_PutInInventory` return as the capacity decision, and restore the item to the source on failure. Temporarily tag a rejected crate and retry it after a cooldown so capacity freed by a player is discovered. A `boulder` is one blob but occupies the full 3x3 crate footprint, so it cannot stand in for a one-slot filler.

### `server_Die()` is finalized after the current rules callback

- Symptom: setup kills a tagged bootstrap worker and immediately still counts it as a live contaminating actor in the same callback; a query on the next tick finds no worker.
- Reproduced on build 4762 (2026-07-15): the first two `gloryhill_r*_smoke` gym requests aborted as `contaminated_ai_actors`. TCPR then showed the tagged production-bootstrap builder was gone and both director modes were off. Splitting canonicalization and contamination validation across callbacks allowed `gloryhill_r3_smoke` to start and finish normally.
- Do not conclude: calling `server_Die()` makes live-blob scans in that same callback authoritative post-death state.
- Workaround: issue owned cleanup, return, and validate on a later tick. Only remove explicitly tagged fixture/bootstrap actors; reject remaining unowned AI contamination.

### Clear volume plus solid ground does not prove a resource-worker spawn is connected

- Symptom: a four-worker gym episode starts with four live actors, but one stable slot produces zero material because its nominally grounded spawn is inside a sealed shelf or pocket.
- Reproduced on build 4762 (2026-07-15), official 8x_Gloryhill: the original four-builder control placed a stone worker near `(119,340)`. Static map inspection and the visible run showed a clear two-tile body volume with ground below but no route to the team's home-connected surface; that episode is invalid and must not enter a cohort.
- Do not conclude: `!isTileSolid(body/head) && isTileSolid(below)` is a navigable spawn contract, or that four live worker blobs mean all four slots received an executable task.
- Workaround and evidence: seed a conservative grounded-cell flood from the exact resource home, build deterministic per-slot candidate sets only from reachable cells, then backtrack the full spawn set so separation constraints cannot make an early greedy choice strand a later slot. Current Gloryhill episodes audit `positions=140,292;52,284;36,292;20,300`; all four slots were productive in every retained control and candidate result.

### Engine pickup may move a material directly into inventory without a carried-blob observation

- Symptom: a worker visibly harvests and later confirms hundreds of material delivered, but an acquisition hook that accepts only `getCarriedBlob() is resource` records zero collection.
- Reproduced on build 4762 (2026-07-15): schema-v2 `gloryhill_control_1b_001` confirmed 1,120 wood delivered and 920 accessible stock while the carried-only collection field stayed zero. The production wood pickup path calls `server_Pickup`, after which KAG may expose the item through `isInInventory()` rather than as the carried blob. Schema v4 accepts either authoritative ownership state and reconciles confirmed per-worker delivery as a conservative collection lower bound; `gloryhill_control_1b_002` then recorded 850 collected and 850 delivered.
- Do not conclude: failure to observe a carried attachment means the pickup failed, or that an empty worker inventory proves no resource was collected earlier in the episode.
- Workaround: check both inventory ownership and carried attachment after pickup, tag counted material blobs to prevent double attribution, and keep gross collection, confirmed transfer, and final accessible stock as separate metrics.

### A delayed runtime world fingerprint is audit evidence, not stable map identity

- Symptom: repeated fresh loads of the same official map, dimensions, and team side emit different terrain/world manifest hashes, preventing any cohort if the complete delayed fingerprint is used as the grouping key.
- Reproduced on build 4762 (2026-07-15): visible 8x_Gloryhill gym starts all reported map hash `3142477075` and `210x66`, while initial terrain hashes differed as normal CTF startup scripts and timing mutated transient state before arming.
- Do not conclude: different delayed manifests necessarily mean a different map file, or that they may be pooled across different map names.
- Workaround: group optimization scores by stable map hash/dimensions, team side, metric, actor configuration, and duration. Retain the full initial fingerprint and terrain hash on every raw record for stratification and freshness audits; never compare different map hashes or optimize mapcycle choice.

### Newly placed recovery structures may not immediately solve routing

- Symptom: after the AI places a backwall/ladder chain, it keeps selecting the same mineable obstruction or replanning instead of traversing it.
- Current status: the previous fixture accepted a mined plug, any nearby ladder, or merely reaching the far side independently, so it could not establish which recovery side effect helped. Production source now places paid missing backwalls in a separate simulation phase and refuses to spawn the ladder until `hasSupportAtPos` recognizes support. The revised AngelScript compiles on build 4762, but one focused run travelled 109.4 px and crossed the nominal far-side threshold without creating a recovery ladder or emitting a recovery replan; it failed after 224 observer samples. The intended ladder branch was never exercised, so this is still not evidence that KAG refreshes routing correctly.
- Workaround: keep support and ladder creation separated by a simulation boundary. Charge only newly missing backwall cells so cache lag cannot double-charge the chain. The one-shot post-ladder probe records low/waypoint counts, next node, ray obstruction, the hypothetical `AIB_GetMineablePathBlock` result, and pathfinder acceptance. The focused fixture additionally requires actual crossing while the dirt plug remains intact; do not treat the probe or ladder alone as movement proof.

### The runtime CTF flag blob is named `ctf_flag`, not `flag`

- Symptom: a flag-relative planner appears to run, but its reported strategic anchor is the tent/resource home rather than the visible flag. On official Gloryhill the wrong path selected roughly `(12,35)` while the actual team-0 flag was `(43,38)`.
- Reproduced on build 4762 (2026-07-15): the early physical-infrastructure diagnostics found no blob named `flag`; after switching to `ctf_flag`, `gloryhill_flag_gatehouse_diagnostic_006` reported the real flag at `(43,38)`, and the later left/right cohorts constructed around the mirrored real flags.
- Do not conclude: a non-null strategic home proves the flag lookup worked. The director intentionally falls back to tent/hall, which makes this name error look superficially valid.
- Workaround: use `getBlobsByName("ctf_flag", ...)` and spawn `ctf_flag` in CTF fixtures. Keep resource-home selection (`tent`, then `hall`) separate. The collision guard must also inspect the carried `ctf_flag` identity.

### Uneven gatehouse terrain can create a foundation/access dependency cycle

- Symptom: locally clear gatehouse candidates fail as `unsupported_tasks`, even though the intended access platform would support the rejected backing after construction. On Gloryhill, the original 7/10/13-tile offsets also overlapped no-build terrain or an uneven surface.
- Reproduced on build 4762 (2026-07-15): `gloryhill_flag_gatehouse_diagnostic_009` isolated four top-row stone backwalls above access platforms as the unsupported foundation tasks. After moving those backing cells to the access phase and generating paid level foundation cells across the shell plus landings, diagnostic `_010` found valid sites from 16 tiles onward. Diagnostic `_012` then physically completed all 36 tasks at the 16-tile site.
- Do not conclude: a cell that will be supported by a later phase is valid in an earlier phase, or that one fixed flag offset is portable across both sides and real maps.
- Workaround: derive the gatehouse ground from the highest surface under the shell and one-tile landings, add only missing air cells as paid foundation, put platform-dependent backing in the access phase, and use a bounded deterministic offset list. The planner and executor must still validate the selected site normally.

### Generic jumping can invalidate a level gate-passage probe

- Symptom: a completed gatehouse has two healthy team doors and the friendly probe enters the rear door, but it climbs the internal ladder instead of exiting the front, producing a false traversal failure.
- Reproduced on build 4762 (2026-07-15): `gloryhill_flag_gatehouse_diagnostic_011` built and archived 36/36 tasks but failed front exit after the probe's generic jump logic took the ladder. With level horizontal-only passage control, diagnostic `_012` crossed both doors in 43 ticks; all six retained left/right physical runs then passed.
- Do not conclude: failure to reach the front x-coordinate proves the doors or ally permissions are broken when the probe was allowed to choose a different vertical route.
- Workaround: give a level door-passage probe horizontal ownership without generic jump, and assert rear entry plus front exit separately. Use another explicit probe when vertical ladder traversal is the behavior under test.

## Evidence Rules For Future Entries

Each new quirk should state:

1. Minimal reproduction and affected KAG build if known.
2. Human-visible symptom and machine-visible symptom.
3. Misleading evidence that future agents must not trust.
4. Reliable verification and workaround.
5. Source/test/log reference and whether the issue is fixed, mitigated, or open.
