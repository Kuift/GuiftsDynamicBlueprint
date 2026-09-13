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
- Reconfirmed on build 4762 (2026-07-17): starting the persistent controller directly on `strategic_uneven_right_edge_fallback_physically_completes` let its cold auto-run mutate terrain before the authoritative TCPR restart. Starting on `strategic_replan_hysteresis` and hot-running the uneven case once from the pristine map produced authoritative run `4c18821b5b16`, which completed and archived all 27 tasks at tick 854. Use the non-mutating-bootstrap pattern for the mirrored and fallback physical cases as well.
- Suite-runner refinement (2026-07-18): scenario transitions and initial cold/hot startup now enter a bounded settle phase that requires the exact captured tile hash, no remaining tagged fixture/bootstrap handles, and no temporary no-build sectors before setup. It reissues cleanup at most eight times and still fails through the canonical guard if the engine never settles. This fixed ordinary suite/persistent teardown races; it does not make a physical cold preflight a safe canonical bootstrap, so the non-mutating-start rule above still applies.

### A tile-clear path probe can still spawn a runner inside collision geometry

- Symptom: the retained-shaft continuation fixture alternated between a complete physical pass and a worker ejected up/left to about `(2543,448)`, after which it rebuilt paths toward `(2564,452)` without entering the shaft. Full-suite logs `console-26-07-18-11-33-09.txt` and `console-26-07-18-11-49-32.txt` captured the timeout, while focused runs from the same source sometimes passed.
- Reproduced cause on build 4762 (2026-07-18): the worker was centred in tile row 58 while row 59 was solid. The policy probe checked its route foot/head cells, but the real runner body needed the same extra empty row beneath its centre that the normal AIBTest arena provides. Spawn collision resolution, not the route controller, chose the intermittent up/left displacement.
- Do not conclude: a nonzero path, two tile-clear samples, or an intermittent focused pass proves a deterministic physical fixture volume; nor does this ejection demonstrate failure of the retained-route policy.
- Workaround and evidence: encode the full runner body volume before spawn, keep any policy-only discriminator outside that body, and let `server_SetTile` settle before re-enabling movement. A later full-suite-only failure showed that creating the castle-blocked abort actor in the same callback as its terrain writes could still kill or displace it even when the focused case passed. The fixture now pauses only that uniquely tagged test actor for two complete ticks, then resumes its brain and requires the production abort state plus physical surfacing. Authoritative hot run `86e2ec208e27` and the complete suite in `console-26-07-18-16-07-39.txt` both passed the route case at tick 463. This is fixture stabilization, not production route assistance.

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
- Reconfirmed again on build 4762 in `console-26-07-18-17-15-57.txt`: the stone-delivery rejection helper failed on `const Vec2f rejectedRoute != Vec2f_zero`; changing only that local to mutable compiled and passed the focused runtime fixture.
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

### Changing a connected player's numeric team does not perform a CTF team transfer

- Symptom: a connected localhost player appears to receive a new numeric team, but CTF respawn restores the old team, no stable target-team character holder appears, or killing the old holder leaves the physical probe without a player body.
- Reproduced on build 4762 (2026-07-17): protected-workshop diagnostics `_011` through `_013` respectively ended as `workshop_probe_holder_lost`, an invalid early-transfer start, and `workshop_probe_team_settle_timeout` after direct team-number changes. `gloryhill_protected_workshops_diagnostic_014` used `RulesCore.ChangePlayerTeam`, waited for the new respawn holder, required 30 stable ticks, then completed the right-side home route, knight and archer class changes, and return in 566 traversal ticks.
- Do not conclude: `CPlayer.server_setTeamNum(...)` updates RulesCore membership, the CTF respawn queue, and the current character holder as one atomic gameplay operation.
- Workaround: use the active rules core's `ChangePlayerTeam` path, allow the normal respawn lifecycle to create the holder, and require a bounded stable-holder window before driving it. Treat holder loss or team reversion as a failed fixture, not as traversal evidence.

### A blob created this tick may not be visible to spatial queries until a later tick

- Symptom: a fixture calls `server_CreateBlob`, receives a non-null live blob, and immediately asks a radius, overlap-list, or anchored-plan query to find it; that spatial query can still miss the blob in the creation callback.
- Reproduced on build 4762 (2026-07-17): `strategic_occupied_primary_falls_back_and_physically_completes` spawned crate 4 at `(492,540)` in `console-26-07-17-21-02-51.txt`, but the same-tick planner reported `rejected=false`. Deferring only the occupied-site validation one rules tick made the primary reject as `building_overlap`; authoritative run `83789b38e031` preserved the crate and physically completed the distinct 18-task fallback.
- Reconfirmed on build 4762 (2026-07-20): the Chapter 1 fixtures received non-null seed, Builder, and wooden-door handles but same-callback spatial checks reported `overlap_rejected=false`, `match_grant=false`, and `live_damaged=false` in `console-26-07-20-07-05-25.txt`. Staging those exact checks after engine initialization produced the physical resupply, tree-overlap rejection, and live/destroyed blob-policy passes in `console-26-07-20-07-33-30.txt`.
- Do not conclude: a non-null newly created blob has already entered every map spatial/overlap index or reached its final anchor, angle, and initial-health state.
- Workaround: split fixture creation and spatial/post-initialization validation across callbacks. Production code should still validate live blobs normally; this is a setup-order rule, not permission to ignore overlap or structure identity.

### Radius queries include blob shape intersections, not just center-distance hits

- Symptom: a 20-pixel protected-building radius query reports a tent whose center is 40 pixels from the candidate task, so a legal tangential site is rejected as `building_overlap`.
- Reproduced on build 4762 (2026-07-17): `console-26-07-17-21-18-02.txt` rejected the emergency barrier at anchor 106 with `tent:1:distance=40`. After strict expanded actual-bounds confirmation, runs `console-26-07-17-21-20-07.txt` and `console-26-07-17-21-21-29.txt` no longer rejected that tangent, while the genuinely overlapping anchor 102 continued to report `distance=8`; the legal emergency barrier was then selected.
- Do not conclude: every blob returned by `getBlobsInRadius` has its center inside the supplied radius, or that the broad query alone defines the planner's clearance contract.
- Workaround: use the radius call as a conservative broad phase, then apply strict candidate-cell versus expanded blob-bounds intersection. Preserve a diagnostic with blob identity and center distance for real overlaps.

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
- Workshop reconfirmation (2026-07-17): `gloryhill_protected_workshops_diagnostic_003` completed and archived its plan but later retained only 67/68 physical matches and no valid return gate. The final template gives the home door solid adjacent support, adds upper cover, and uses a solid three-cell enemy wall instead of a second unsupported door. Diagnostic `_005` and all retained six-run workshop cohorts preserved every task through the full class-use-and-return probe.

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

### BrainPath can exhaust after partial progress before reaching an unchanged destination

- Symptom: `BrainPath.SetPath` initially returns a usable route and the runner advances, but the low path later becomes empty more than 32 pixels from the goal. A caller that suppresses `SetPath` because the destination vector has not changed never recovers.
- Reproduced on build 4762 (2026-07-17), official 8x_Gloryhill: `gloryhill_protected_workshops_postplanner_left_001` built and archived all 69 workshop tasks, then the connected probe advanced 42.34 pixels before ending as `workshop_brain_path_unavailable`. The destination was unchanged, so the prior change-only request guard did not search again.
- Do not conclude: an unchanged high-level destination implies the existing low-level path is still populated or executable.
- Workaround and evidence: when the low path is exhausted and the actor remains outside the completion radius, permit a bounded fresh `SetPath` from the actor's current position. The workshop probe retries no more often than every 15 ticks. `gloryhill_protected_workshops_postplanner_left_002` then reached the landing, used both exact shops through stock class commands, and returned in 407 traversal ticks; the corresponding final right smoke passed in 566 ticks.

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

### A saved stone-route corner is a tile origin, not the two-column shaft body center

- Symptom: a quota-complete miner reaches the saved cross-tunnel corner but then remains motionless or alternates horizontal and upward intent instead of entering and climbing the two-wide shaft. Centering the target only at the final shaft lip does not repair a bad corner rejoin.
- Reproduced cause on build 4762 (2026-07-18), official Gloryhill: the canonical route corner stores the left tile origin. Treating `routeCorner.x` as the runner center drives the body against one side of the two-column opening. At the same time, unconditional below-corner `key_up` ownership can fight the horizontal rejoin while the runner is still far from the shaft.
- Do not conclude: reaching the corner's x coordinate means the runner is centered in the shaft, or that a below-corner worker should always press up. A saved route cell and a physical runner center are different coordinate contracts.
- Workaround: rejoin at `anchor.x + tileSize / 2`, require half-tile horizontal proximity before declaring the corner rejoined, and explicitly own `up` only while below the lower-body band and within 1.5 tiles horizontally. Far rejoin remains horizontal and may use only ordinary geometry-qualified obstacle scaling.
- Evidence: `Artifacts/aib_gym/gloryhill_4b_centered_bounded_corner_diag_20260718.tcpr.txt` ran 3,000 ticks, collected and delivered all 1,608 material (`590` wood, `938` stone, `80` gold), kept all four slots productive, and ended with zero deaths and `failure_flags=0`. Worker `60` progressed assist `2424` -> rejoin `2432` -> wall hold `2435` -> surface `2444` -> exit `2462`; worker `62` progressed assist `2502` -> rejoin `2524` -> wall hold `2529` -> surface/exit `2536`. The centered-only predecessor still left worker `60` without a relevant outcome for 1,646 ticks, while an above-surface ore gate regressed to `638/638` with flags `33`; both variants were rejected. This is focused routing evidence, not an exact throughput cohort.

### Reusing or statically toggling a just-surfaced fixture actor contaminates a second shaft-climb test

- Symptom: the production return controller physically surfaces the castle-blocked abort actor, but an added fixture immediately teleports that same actor back to the shaft bottom. It records a valid stale-corner bypass, then fails to climb, drifts out of the fixture, and can die from the fall.
- Reproduced boundary on build 4762 (2026-07-18): persistent hot runs `c82bbd79df8b`, `84fc0b8d5988`, and `70af87518007` restaged the same actor two ticks after its first wall climb and lost it before a second surface. Run `20f08130c780` waited 90 ticks but held the same shape static, then made it dynamic at resume; the actor again captured the bypass but ended near `(3177,568)` without resurfacing. In the same run the original fresh abort actor climbed identical shaft geometry from about `(3144,501)` to `(3144,455)` in 25 ticks, so the added failures do not isolate production shaft geometry.
- Do not conclude: a teleported actor retains fresh runner wall-contact/jump state, or that `CShape.SetStatic(true)` followed later by `SetStatic(false)` recreates a newly spawned dynamic runner. A valid AI state and detected wall mask are not sufficient fixture-state proof.
- Safe workaround: reject reused/static-body outcomes as fixture failures. Preserve the first actor's real surface result, then test re-entry with a fresh dynamically spawned AI builder in a full body-clear shaft, pause only its brain for the normal two-tick collision settle, and require physical resurfacing. This fresh-actor design is the next pending test and must pass before the experimental production change is accepted.

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
- Reconfirmed on build 4762 (2026-07-18): persistent run `b02763eda88d` entered the authoritative restart while two frozen preflight fixture handles still existed. Counting the handles, including those already tagged `dead`, correctly failed the canonical guard as `fixture_leak blobs=2`. Routing initial startup through the bounded settle phase made the same non-mutating preflight pass as `e9fdec301220`.
- Do not conclude: calling `server_Die()` makes live-blob scans in that same callback authoritative post-death state.
- Workaround: issue owned cleanup, return, and validate on a later tick. When isolation requires physical disappearance, count non-null tagged handles rather than filtering out the `dead` tag. Only remove explicitly tagged fixture/bootstrap actors; reject remaining unowned AI contamination.

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
- Current status: the old fixture could cross a nominal threshold without a ladder, so it did not establish which recovery side effect helped. Production places paid missing backwalls in a separate simulation phase and refuses to spawn the ladder until `hasSupportAtPos` recognizes support. The redesigned fixture uses a seven-tile preserved two-column dirt plug, withholds its 100 wood until the runner physically reaches the obstruction face, and pulses the obstruction threshold only when production's exact uphill-node, low-motion, saved-peak, and face predicates are true. Production still owns validation, payment, staged support, ladder creation, path probing, and traversal. Authoritative hot run `eb3a6c62b0d8` and the complete suite in `console-26-07-18-16-07-39.txt` both passed at tick 288 with three paid backwalls, support before ladder tile `349,68`, an accepted later path probe, 84 post-ladder wood, the unchanged plug, and physical crossing. This validates the separated refresh sequence for this fixture; it is not a claim that every newly built route will be traversable.
- Workaround: keep support and ladder creation separated by a simulation boundary. Charge only newly missing backwall cells so cache lag cannot double-charge the chain. The one-shot post-ladder probe records low/waypoint counts, next node, ray obstruction, the hypothetical `AIB_GetMineablePathBlock` result, and pathfinder acceptance. Require actual crossing while the obstruction remains intact; neither a non-empty probe nor a ladder by itself is movement proof. After recovery ownership changes, retain the mirrored-corner gate: hot run `033932ab1f1f` completed both 36-tick escape cycles, latched the 90-tick cooldowns, displaced at least one tile on both sides, and preserved both traps.

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

### Player-bound runner keys can be overwritten before scripted benchmark movement

- Symptom: a connected player is successfully rebound to a freshly spawned runner, but scripted `setKeyPressed` calls never produce horizontal motion. The same rules-level key controller moves an unbound friendly probe normally.
- Reproduced on build 4762 (2026-07-17), official 8x_Gloryhill: `breach_compile_left_20260717a.tcpr.txt` bound the enemy builder at about `(511.7,328.3)` but rules-level client keys yielded zero server-observed input, zero damage, and the identical final x after 900 ticks. `breach_gate_left_20260717b.tcpr.txt` then used server runner keys on the bound body; its x again stayed `511.7`, while four client-originated production pickaxe commands destroyed the reachable enemy-facing door and reduced blocker count from two to one.
- Cause boundary: the player input lifecycle clears or overwrites blob key state around the script callbacks used by this rules benchmark. Binding and attack-command delivery were independently live, so stationary position is not evidence that `server_SetPlayer` failed.
- Do not conclude: a player-bound blob with scripted pressed keys received executable human-equivalent movement, or that a valid client attack command proves the body can traverse after the first blocker falls.
- Workaround: keep attacks on the existing client-authoritative class command and observe them server-side without changing the payload. For a bounded infrastructure probe only, hold the body static on the one-tile enemy landing while more than the home-side blocker remains, then use low server velocity and let ordinary collision own the route. Report `server_static_outer_stance_then_bounded_velocity` explicitly and require actual entry/crossing coordinates. This is a benchmark workaround, not a production AI movement technique.
- Validated boundary (2026-07-17): all twelve final fixture-v3 gatehouse control/candidate rows passed across three runs per variant on both sides, with real damage and crossing. The fixture-v4 workshop treatment then passed all twelve admitted control/candidate rows: one-column controls crossed in `364` left / `298` right ticks, while two-column candidates crossed in `616` left / `562` right ticks after destroying all seven blockers. These runs validate the disclosed measurement controller and client attack stream; they do not validate scripted keys on player-bound runners or generalize to production AI movement.

### Rules `onBlobDie` may fire more than once for the same blob

- Symptom: a fixed seven-attacker bomb wave reported 10 or 12 enemy deaths even though the fixture created no replacement attackers. Adding spawn-index diagnostics showed repeated rules death callbacks rather than extra actors.
- Reproduced on build 4762 (2026-07-18): the visible right-side run `wave_v4_outcomefix_plan_right_bomb_s101_20260718` spawned seven attackers and resolved exactly two crossings plus five unique deaths, while also recording five duplicate `onBlobDie` callbacks. The unguarded predecessor had reported ten deaths for the same seed/side/variant class. The corrected transcript is `Artifacts/aib_gym/wave_v4_outcomefix_plan_right_bomb_s101_20260718.tcpr.txt`.
- Do not conclude: incrementing a counter once per `onBlobDie` invocation counts unique dead blobs, or that `crossings + death_callbacks >= spawned` proves every attacker reached a distinct terminal outcome.
- Workaround: assign each bounded fixture actor a unique spawn index and store rules-side bit masks for first death callback and terminal outcome. Make crossing and death mutually exclusive, diagnose later callbacks separately, and stop counting before fixture cleanup kills remaining actors. Apply the same first-callback mask to tagged bombs. The wave comparator rejects v4 rows unless `crossings + enemy_deaths == outcomes_resolved <= spawned` and detonations do not exceed throws.

### An underground stone retarget can erase its route and loop against dirt forever

- Symptom: one or more stone workers stand in an already mined underground pocket, repeatedly run toward a dirt/stone band leading to nearby ore, never swing at the band, never reach the ore, and never use their retained shaft to return to the surface. Root `untitled.png` is the human-visible capture.
- Reproduced on build 4762 (2026-07-18), official `8x_Gloryhill2`, final production code: `Artifacts/aib_gym/gloryhill_4b_return_final_stalldiag_20260718.tcpr.txt`. Workers `60` and `62` retained surface anchor `180,288` and last valid local corner `192,376`, then retargeted from ore `224,376` to deeper nearby ore `224,392`. Starting at ticks `2927/2928`, both selected direct destination `228,396`; from tick `3005` through the 5,400-tick episode end they repeatedly reported `stone_route_obstruction`, usually with next node `216,368`, and returned to the same pocket around `200,368`. No corresponding dirt hit, ore outcome, quota return, or surface exit occurred.
- Cause boundary: this is not native `CBrain::idle` and not merely a pre-behavior monitor false positive. `AIB_RetargetExistingStoneRoute` runs a fresh route search whose surface-approach precondition can fail after the worker is already underground, then stores the zero result as the mutable mining corner. `AIB_GetStoneRouteDestination` falls back to the raw ore target. With no route corner, `AIB_ShouldAvoidDirtClearance` correctly rejects dirt as off-route, while dedicated-stone obstruction recovery clears and rebuilds the same custom `BrainPath` and intentionally suppresses generic ladders. Those individually safe guards compose into a live-lock.
- Do not conclude: repeated non-empty `BrainPath` waypoints prove the ore is reachable; a changing obstruction counter/corner-escape event proves useful recovery; or the worker should be allowed to mine arbitrary dirt in generic travel. The monitor's earlier 40-tick bit-1 windows are separate recoverable return pockets; the screenshot trace is a multi-thousand-tick outbound mining deadlock.
- Implemented workaround: retain the last nonzero local shaft for an underground nearby-ore retarget and extend it to the new target depth only if the complete two-wide shaft/two-high cross-tunnel still passes the existing traversable, barrier, no-build, bedrock, and castle checks. If no legal continuation exists, preserve the measured surface anchor and last valid return corner, abandon the ore target, and enter `return_wood` below quota so the specialized return controller physically surfaces. `stone_route_continue` and `stone_route_abort` are change-only; dirt mining remains limited to exact validated route cells. `AIB_TunnelToStone` applies the same fail-closed check as a safety net.
- Validated fix boundary (2026-07-18): the current fixture proves retained continuation selection, deeper route excavation and stone acquisition, bounded destruction, and a castle-blocked abort that physically surfaces while preserving its target/control tiles. Its uniquely tagged abort actor is paused for two full ticks after terrain/spawn writes, then production owns the actual abort and surfacing. Authoritative hot run `86e2ec208e27` and the complete suite in `console-26-07-18-16-07-39.txt` both passed at tick 463. Mandatory mirrored-overhang run `033932ab1f1f` separately passed both complete 36-tick cycles and both 90-tick cooldowns at tick 138.
- Real-map follow-up: `Artifacts/aib_gym/gloryhill_4b_route_continue_diag_20260718.tcpr.txt` contains live `stone_route_continue` and `stone_route_abort` boundaries, fully delivered 1,466 material with zero deaths, and contains none of the old `destination=228,396`, `next=216,368`, `next=192,384`, or `tile=224,392` deadlock signatures. The later centered/bounded-corner diagnostic described above fully delivered 1,608 material with zero deaths and no gym flags. These close the reproduced outbound route-erasure and return-corner locks. Neither single diagnostic is a throughput cohort.

### Successful delivery cleanup can erase a live stone-route rejection

- Symptom: a miner correctly abandons a bad ore/gold route and records a 900-tick rejection, returns to base, then selects the same target again long before the rejection expires. This looks like a selector/cooldown failure even though the rejection was written correctly.
- Reproduced on build 4762 (2026-07-18), official Gloryhill: `console-26-07-18-17-08-35.txt` recorded builder 60 aborting target `96,344` at tick 3284 with `retry=4184`, then aborting the same target again at tick 3406. Further premature attempts occurred at 3514, 3684, and 3793 across the stone workers.
- Cause boundary: successful resource delivery called the full navigation/ownership cleanup before returning to `find_stone`. That cleanup intentionally clears route rejection state for a real manual order or role change, but it also erased the still-valid rejection at this same-job episode boundary.
- Do not conclude: a valid `retry=` value in the abort event proves the cooldown survives the later delivery boundary, or that the selector ignored a live rejection.
- Workaround: `AIBM_ClearDeliveredResourceEpisodeIntent` snapshots and restores only an unexpired rejection when the completed job is stone. Manual ownership transfer and real role cleanup still use `AIBM_ClearNavigationIntent` and clear it. The focused stone-route fixture runtime-checks both halves. In post-fix `console-26-07-18-17-20-17.txt`, target `96,344` aborted once at tick 4337 with `retry=5237` and was not immediately selected again.

### A shaft-to-cross-tunnel handoff can bounce without useful route progress

- Symptom: a miner reaches the ore-depth lip of an unsupported cave crossing, alternates direct shaft and ordinary `BrainPath` ownership, and bounces roughly one runner width while never entering the cross-tunnel. Total displacement and recurring paths make the worker look active, but the passive monitor eventually reports path thrash.
- Reproduced on build 4762 (2026-07-18), official Gloryhill: `console-26-07-18-17-20-17.txt` latched builder 62 at tick 5219 with target `264,360`, position `(199,376)`, only 10 pixels of window displacement, and six replans. The diagnostic fingerprint was `w1-3142477075-210x66-1570756837-4872-3945193546-1025-53-3684685722-3060991973-2466050567`; it collected/delivered 1,316 and ended with failure flags 5.
- Cause boundary: lateral wall-bounce displacement was initially accepted as shaft progress. After progress became directional, the controller still returned ownership before observing the best position inside the one-tile target-row band, so later bounces could reset from a stale, worse vertical sample.
- Do not conclude: eight pixels of arbitrary displacement is shaft progress, a non-empty path means the open cave leg is walkable, or shortening the complete shaft watchdog is safe. The rejected all-shaft 30-tick variant in `console-26-07-18-17-55-50.txt` aborted valid supported/approach motion, collected only 1,240, and introduced a real return motion-stall flag.
- Workaround: measure progress only as reduced vertical error toward the cross-tunnel row (successful mining also resets the clock), observe first entry into the one-tile handoff band before releasing direct ownership, retain 120 ticks for ordinary shaft motion, and use the 30-tick bound only while the runner remains at that handoff seam. Because the controller has ownership gaps, the event reports both configured threshold and actual elapsed wall time.
- Exact validation: `console-26-07-18-18-01-45.txt` reproduced the same fingerprint and identical 1,316/1,316 resource outcome. The same target/corner aborted at tick 4817 with `phase=handoff`, `elapsed=40`, and `threshold=30`; no gym failure was emitted and the aggregate flags changed 5 to 0. `Artifacts/aib_gym/gloryhill_4b_handoff_band_diag_20260718.{tcpr.txt,failures.ndjson,windows.ndjson}` retains the transcript and empty parsed failure/window files.

### Lateral shaft bounce can masquerade as stone-return progress

- Symptom: a miner in `return_wood` repeatedly alternates `stone_return_wall_hold` and `stone_return_wall_release` in the same underground shaft pocket. Its position and total travel keep changing, but it does not reduce the vertical distance to the saved surface anchor.
- Reproduced on build 4762 (2026-07-18), official Gloryhill: `Artifacts/aib_gym/gloryhill_4b_base_supply_route_diag_20260718.tcpr.txt` entered builder 62's return at tick 2489 near `(71,336)` with anchor `(68,280)`, then did not emit `stone_return_surface` until tick 5144: 2,655 ticks. The repeated cycle moved between roughly x=63..78 and y=316..335. It still ended with all 1,456 collected material delivered and `failure_flags=0`; both parsed monitor artifacts are empty.
- Cause boundary: the return watchdog accepted any four-pixel Euclidean displacement as progress, so lateral recenter/ejection motion continually refreshed it. The wall detector also sampled at `currentX +/- (radius + tileSize)`; two pixels of body jitter could move that sample into another map cell and alternate the perceived wall mask. These two individually plausible measurements composed into an unbounded latch/release loop.
- Do not conclude: a large travel total, changing position, recurring controller events, or zero passive-monitor flags proves that an underground return is approaching the surface. The monitor correctly observed motion under its existing contract and must not be weakened to hide this controller error.
- Workaround: before the cross-tunnel corner is rejoined, count only reduced distance to the canonical two-column rejoin point; afterward, count only reduced vertical error to the saved surface anchor. Reset the return progress sample when the phase changes. Sample the two outer shaft walls from the canonical anchor/topology rather than the jittering body x coordinate.
- Exact validation: `Artifacts/aib_gym/gloryhill_4b_return_phase_progress_diag_20260718.tcpr.txt` used the identical complete fingerprint and completed 12 measured underground returns with a maximum of 115 ticks; bounded stalls retried and surfaced. It delivered all 1,314 collected material with zero deaths and flags, and its parsed failure/window files are empty. The aggregate total differs from the 1,456-material diagnostic, so this is causal lock evidence, not a throughput claim. Focused log `console-26-07-18-18-41-45.txt` and complete regression `console-26-07-18-18-49-07.txt` passed `return_progress_requires_phase_advance=true` and `return_wall_samples_stable=true`; the latter ended `65/0` with `DONE` and retained the complete mirrored-overhang gate.

### A locally valid base workshop side can still be unreachable from the home side

- Open symptom: a target-free stone worker in `find_stone` repeatedly paths toward a base-supply destination but cycles between the same terrain pocket and wall instead of reaching the source. The local workshop/quarry foundation and at least one side approach may all be valid; that does not establish connectivity from the exact resource home.
- Current reproduction on build 4762 (2026-07-18), official Gloryhill: `console-26-07-18-18-09-10.txt` latched builder 60 at tick 3264 in state 7 at `(104,319)`, with no ore target, destination `(220,308)`, zero displacement, and two replans. Its retained window cycles between about x=79 and x=104 through tick 3325. The episode stopped gaining resources after tick 2700 and ended at 1,484/1,484 with failure flag 1. Parsed evidence is `Artifacts/aib_gym/gloryhill_4b_handoff_candidates_20260718.{failures.ndjson,windows.ndjson}`.
- Identity confirmation: EventLog diagnostic `Artifacts/aib_gym/gloryhill_4b_base_supply_route_diag_20260718.tcpr.txt` created the exact local `buildershop` at `(220,308)` at tick 894 and subsequently emitted stone-worker paths to that exact destination. The post-fix identical-fingerprint diagnostic created the same local shop at tick 1251. The destination is therefore the base workshop wait point, not a remote quarry/source inference.
- Do not conclude: five-column foundation support plus either grounded side approach proves a normal builder can reach the site from its pinned home, or that weakening the passive 40-tick motion-stall classifier is an acceptable fix.
- Remaining evidence boundary: both EventLog diagnostics selected reachable loose ore shortly after their `(220,308)` paths, so neither reproduced the original terminal base-approach pocket after the upstream return lock was fixed. The original failure remains valid evidence, but it is not yet proof that the current shop approach independently stalls.
- Next verification: force or naturally reproduce a target-free workshop-supply approach after the return fix, record the exact pinned home, grounded approach side, and low-level `BrainPath` nodes, then test a home-facing approach/connectivity gate in visible KAG. Keep the existing barrier, 28-tile base envelope, building/no-build clearance, payment, conservation, and remote-shop exclusions intact. No production siting change is accepted for this open case yet.

### A blueprint reservation must not survive the reserving builder's material trip

- Symptom: with several AI Builders or Autobuilders assigned to one blueprint, workers can repeatedly show `Waiting for another builder's blueprint reservation` even though no worker is actively approaching or building that tile. The apparent cooperation becomes a lease-expiry loop instead of useful parallel work.
- Reproduced on build 4762 (2026-07-20), live CTF on `FG_Forelands`: `console-26-07-20-07-53-18.txt` emitted the passive monitor's accessible-blueprint-resource deadlock flag (`f=128`) for builder 36 at tick 3114 and builder 37 at tick 12087, both in state 12 (`collect_blueprint_resources`).
- Cause boundary: blueprint selection reserved a task before checking whether an ordinary builder had its material. Transitioning to `collect_blueprint_resources` cleared the target but retained the task lease. Other workers then waited until expiration; after ownership changed, the original builder could return expecting work that another worker now owned. A builder could also retain one reservation while selecting another through the loose/explicit reservation paths.
- Do not conclude: every brief reservation wait is a deadlock. Waiting is correct while the owner is actively approaching or building, and the monitor's `f=128` evidence must not be weakened to hide a lifecycle bug.
- Workaround: a reservation covers only active approach/build work. Release it before any material-collection trip, whenever a target disappears or no longer needs work, and before the same builder claims any other loose or explicit task. Keep the invariant that one builder owns at most one blueprint lease.
- Validated fix boundary: focused visible-KAG TCPR run `68d8e2cd8af1` passed `blueprint_material_trip_releases_reservation_for_competing_builders` in 8 ticks. The unfunded ordinary builder released its lease on entry to material collection, two Autobuilders contended for the same task, one completed it, the explicitly observed waiting orb retargeted, and the plan ended with zero reservations before the old 150-tick lease expiry. This is the focused contention/lifecycle proof, not a multi-plan throughput claim.

### A solid top map border is not a usable terrain surface

- Symptom: every strategic candidate is generated at row `0`, becomes an `empty_plan`, and the director appears stuck in planning even though the visible map has ordinary ground much lower down.
- Reproduced on build 4762 (2026-07-20), official `Ferrezinhre_Totally_Transcendent`: `console-26-07-20-09-23-59.txt` loaded the real PNG and rejected both teams' flag room, tower, workshop, Tunnel, and Quarry candidates at `anchor=...,0 reason=empty_plan`. A live tile query confirmed the map's solid type-106 upper border while row 33 was open and the relevant lower terrain was solid.
- Cause: the old top-down scan returned the first solid tile in a column. On a map with a solid ceiling/border, that tile is not walkable ground.
- Do not conclude: the map has no buildable space, is all black, or lacks compatible prefabs merely because a first-solid scan returns row zero.
- Workaround: tactical surface discovery must skip the upper border and accept a solid tile only when both body-height cells immediately above it are open. `AIBS_FindWalkableSurfaceAt` applies that two-cell requirement during static build and refresh.

### Tactical top surface and resource-home floor are different placement contracts

- Symptom: after rejecting the solid ceiling, a protected workshop can still appear on a high shelf (observed anchor row `51`) even though its resource Tent and normal base traffic are on ground row `73`.
- Reproduced on build 4762 (2026-07-20), official `Ferrezinhre_Totally_Transcendent`: the first corrected live query reported `plan0=38,51 ... template0=protected_workshops`. Fresh normal-CTF logs `console-26-07-20-09-56-34.txt` and `console-26-07-20-09-59-19.txt` subsequently generated every protected-workshop candidate for this base at row `73`; the same run provisioned from the real home at `(108,564)` and published/assigned work at tick 30.
- Do not conclude: the highest walkable surface in a column is the correct base floor. It is useful for towers/frontline terrain, but it may be a roof or isolated ledge above the Tent.
- Workaround: Tent/Hall-scoped workshop, home-Tunnel, and Quarry/Storage anchors use the first solid ground at or below the exact resource-home position (`AIBS_GroundBelowPosition`). Frontline/tactical structures retain the walkable-surface model. Active base plans at a different resource-floor row are invalidated.

### Hot-reloading strategic includes can leave live path-node neighbors null

- Symptom: an already-running CTF session compiles a strategic/template edit, then ordinary AI pathing emits repeated `canNodesConnect(...): Null pointer access` exceptions even though the edited scripts compiled successfully.
- Reproduced on build 4762 (2026-07-20): after hot-reloading the compact-workshop/template changes into the active exact-map session, `console-26-07-20-09-46-19.txt` began repeating the exception at line 1035 from `PathingNodesCommon.as:183` and continued until the process was closed.
- Do not conclude: those post-reload path exceptions prove the new prefab or planner logic is invalid. The active node graph crossed a reload boundary and is not valid behavior evidence.
- Workaround: after changing strategic includes, templates, world-surface code, or shared pathing dependencies, close KAG and use a fresh visible process. Do not cite behavior collected after this exception begins.

## Evidence Rules For Future Entries

Each new quirk should state:

1. Minimal reproduction and affected KAG build if known.
2. Human-visible symptom and machine-visible symptom.
3. Misleading evidence that future agents must not trust.
4. Reliable verification and workaround.
5. Source/test/log reference and whether the issue is fixed, mitigated, or open.
