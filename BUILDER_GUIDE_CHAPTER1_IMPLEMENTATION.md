# Builder Guide Chapter 1 implementation contract

Source: <https://deynarde.github.io/kag-builder-guide/builder-i-the-basics.html>

This document is the point-by-point contract for applying chapter 1 to the
autonomous Builder.  Advice that is a player control, combat-unit operation,
or economy action outside the Builder's authority is recorded explicitly
rather than represented by a decorative blueprint that cannot execute it.

## Point-by-point subsection audit

“Preserved” means the production AI already had the required behavior and this
work deliberately keeps it. “Implemented” means this chapter pass added or
changed production behavior. “Catalog only” means a human blueprint can request
the object and the AI can fund/build it, but the director does not choose it
without a role that can use it.

| Guide point | Production disposition |
| --- | --- |
| 1.1 Builder class | Implemented home-first defense, protected services, resource work, and progressive construction. Capturing flags and operating combat units remain outside the worker role. |
| 1.2 Getting materials | Preserved bounded inventory/resource episodes and base return. Eligible loose wood/stone/gold is collected instead of being left to decay. |
| 1.2.1 Stone | Preserved natural-stone mining, thick/ordinary engine yields, reusable shaft routing, local loose-stone collection, and bedrock rejection. |
| 1.2.2 Gold | Preserved line-of-sight gold discovery and immediate delivery to the assigned base. A global “minimap” ore scan is intentionally not simulated because it would bypass terrain knowledge and existing safety limits. |
| 1.2.3 Wood | Preserved full tree/log episodes; implemented one-empty-tile nursery spacing on the worker's current barrier side and delivery of logs to an existing safe powered saw. |
| 1.2.4 Resupplies | Implemented timed AI resupply and a physical base visit. The installed CTF values override the guide's stale warm-up numbers. |
| 1.3 Building menu/coins | Preserved all eleven current menu identities in the blueprint catalog. Material conservation is authoritative; synthetic coin awards are not added because the AI has no coin wallet. |
| 1.3.1 Stone block | Preserved 10-stone cost and use as the principal defensive shell. |
| 1.3.2 Stone backwall | Preserved 2-stone cost and early support phase; implemented explicit fire/collapse backing in guide prefabs. |
| 1.3.3 Stone door | Preserved 50-stone cost and solid-neighbor validation; limited strategic use to one of the tower's six lower door cells. |
| 1.3.4 Wood block | Preserved 10-wood cost; strategic wood is confined to supported, firebroken middle layers rather than exposed outer defense. |
| 1.3.5 Wood backwall | Preserved 2-wood catalog support, but guide defenses prefer stone backing because wood backing propagates fire. |
| 1.3.6 Wood door | Preserved 30-wood cost; implemented a 2-stone-backed composite so the backing cannot be skipped or double charged. |
| 1.3.7 Trapblock/team bridge | Preserved catalog and executor support at 30 wood. The director does not add one to ordinary friendly routes where the one-way behavior could impede movement. |
| 1.3.8 Ladder | Preserved 10-wood cost and rotation; implemented alternating centers with exactly one empty tile and no more than ten rungs in guide access. |
| 1.3.9 Platform | Preserved 15-wood cost/rotation; implemented a 2-stone-backed composite for protected tower cover. |
| 1.3.10 Workshop | Implemented typed-shop construction as one atomic base-workshop-plus-conversion payment, with the production clear-volume/foundation validator. |
| 1.3.11 Spikes | Preserved 30-stone catalog/executor support. Guide director prefabs omit them because they can hurt teammates; a human-authored blueprint may still request them. |
| 1.4 Workshops, items, siege | Implemented stone-backed shop siting because enemies can use captured shops. Shop conversion requirements are included in every typed cost. |
| 1.4.1 Builder Shop | Preserved base-scoped Builder Shop creation and overflow crates; implemented its use as an eligible resupply point. Existing safe saws receive logs. Lanterns, buckets, sponges, boulders, trampolines, drills, and saw purchase/movement require item/coin controllers that this worker does not have. |
| 1.4.2 Quarters | Catalog only, with full 200-wood workshop-plus-conversion cost. The worker has no class-change, sleep, food-purchase, or healing role. |
| 1.4.3 Knight Shop | Implemented in a protected, stone-backed service prefab away from the flag. Mine purchase/deployment remains excluded because it needs coins and combat-safe arming logic. |
| 1.4.4 Archer Shop | Implemented in the protected service prefab; special-arrow purchase is irrelevant to a Builder worker. |
| 1.4.5 Naval Shop | Catalog only with the full installed cost; implemented hard rejection on dry land. Boat purchase, unpacking, capture, rowing, and weapon use require vehicle roles. |
| 1.4.6 Siege/Vehicle Shop | Catalog only with its full installed wood/gold cost. Catapult/ballista purchase, unpacking, immobilization, ammunition, upgrades, and operation require coins and a siege role. |
| 1.4.7 Storage | Implemented in the quarry service prefab and preserved grounded base crates/accessible-stock accounting. |
| 1.4.8 Tunnel | Implemented two distinct one-shot stations: home first, then frontline; each pays full installed wood/stone/gold cost. |
| 1.4.9 Quarry | Implemented late Quarry-over-Storage geometry, one-team-Quarry suppression in both strategic and direct creation, full funding, and preserved automatic wood fueling/stone collection. |
| 1.5 Building a base | Implemented as small terrain-adaptive plans rather than one brittle megablueprint, so useful stages can complete independently. |
| 1.5.1 Front tower | Implemented three layers, five reinforced wood doors plus one stone door, fourth-course firebreaks, redundant stone backing, spaced ladders, and protected platform cover. Protected class shops and the frontline Tunnel are separate nearby stages. |
| 1.5.2 Flag rooms | Implemented home-floor, elevated-enemy, and ladder/hatch entrances; a thick stone shell/backing; a clear central channel around KAG's flag no-build sector; and predominantly wood doors. Mines are excluded for the coin/deployment reason above. |
| 1.5.3 Tunnels | Implemented a protected home endpoint followed by a distinct protected frontline endpoint. A saw trap is not fabricated without a carried-saw safety/deployment model. |
| 1.5.4 Tree farm | Implemented natural-ground planting with one empty tile between tree centers and safe use of an existing saw; class swapping and moving the saw are excluded. |
| 1.5.5 Shops | Implemented redundant protected shops outside the flag room, stone backing, a protected two-cell home entrance, an independent two-cell reinforced roof hatch with gapped ladder access, and rebuild-after-destruction behavior. |
| 1.6 Block support | Preserved engine-aware support validation; guide prefabs use wood for longer spans and stone/backwall chains for grounded defense. |
| 1.7 Repair | Implemented full-cost quiet-window tile repair, immediate critical repair, stale-observation reset, and destroy-before-rebuild blob handling. |
| 1.8.1 Open shops | Implemented protected siting; an unsafe completed shop is never treated as adequate guide infrastructure. |
| 1.8.2 Stone-door overuse | Implemented exact door-material counts in the tower and predominantly reinforced wood doors elsewhere. |
| 1.8.3 Wood without stone backing | Implemented atomic reinforced door/platform composites and stone-backed workshop cells. |
| 1.8.4 Awkward top doors | Implemented side/floor entrances and ladder access to the deliberate flag-room roof hatch. |
| 1.8.5 Awkward movement | Preserved route validation and implemented clear home-side approaches; the frontline Tunnel sits beside the semantic tower area rather than at a remote arbitrary point. |
| 1.8.6 Too few doors | Implemented three independent flag-room entrances, the guide's exact six-cell tower base, and two independent protected-service exits: a controlled home entrance plus a reinforced roof hatch. Every route preserves the player's full 2x2/four-cell volume; the director rejects a merely 1x2 aperture. No exposed ground-level enemy door is added. |
| 1.8.7 Knight Shop low/near flag | Implemented a separate protected service prefab and excludes it from the flag-room footprint. |
| 1.8.8 Saw in flag room | Implemented an explicit ten-tile friendly-flag exclusion for saw log delivery. |
| 1.9 Progressing to victory | Implemented a deterministic one-shot guide sequence: flag room, frontline tower, protected shops, home Tunnel, frontline Tunnel, then Quarry/Storage. A real frontline collapse may still override it with an emergency barrier. Offensive fighting remains with combat roles. |

## 1.1 Role

- Base and flag defense: the director first builds the three-entrance flag room,
  then the three-layer frontline tower, whenever each stage has a valid site.
- Shops and team infrastructure: protected class-shop, home-Tunnel,
  frontline-Tunnel, and Quarry/Storage prefabs are production candidates, not
  raw tile schedules. They follow the tower in that exact order.
- Legacy gatehouse, archer-perch, and access-route templates are excluded from
  production selection. They remain opt-in only for their historical fixtures.
- A genuine frontline collapse may still override the guide sequence with an
  emergency barrier.

## 1.2 Materials and resupply

- Dirt and bedrock behavior remains owned by the existing stone-route and
  obstruction rules: dirt may be cleared, bedrock is never selected as a
  mineable/build-replaceable tile.
- Loose wood, stone, and visible gold continue to be collected and returned to
  base-scoped storage before the next resource episode.
- Autonomous Builders receive the installed CTF resupply values (not the old
  values printed in the guide): 250 wood/80 stone every 40 seconds in warm-up,
  and 100 wood/30 stone every 20 seconds during play.
- During play, an autonomous Builder claims a due resupply only at a same-team
  tent or base-scoped Builder Shop.  It starts the visit only at a target-free
  episode boundary, so harvesting, mining, and construction are not abandoned.

## 1.3 Blocks and structures

- Guide prefabs use stone for the defensive shell and backwall reinforcement.
- Wooden doors and platform cover that require fire-safe backing use dedicated
  reinforced catalog entries.  Their full wood plus stone cost is paid.
- The frontline tower has three material layers: stone outer and inner faces,
  a wood middle with periodic stone firebreaks, and six lower door cells with
  five reinforced wooden doors and one stone door.
- Vertical guide access uses the guide's one-empty-tile ladder spacing.  Routes
  are still subjected to the production phase/reachability validator. Its route
  nodes occupy two columns across two rows, matching the player's four-cell
  volume rather than treating the player as a point.
- Every door is scheduled only after adjacent shell support exists.
- Strategic prefabs do not put spikes in friendly traffic.
- Boat Shop blueprint placement is legal only at a water-adjacent site.

## 1.4 Workshops

- Class shops are stone-backed and enclosed in the protected-workshops prefab;
  the Knight Shop is not placed at the bottom of, or inside, the flag room.
- The protected workshop has two independent routes. Its one-course home wall
  uses two vertical reinforced door cells beside a clear interior column; its
  one-course roof uses two horizontal reinforced hatch cells with clear rows
  above and below. Both therefore preserve a full 2x2 body volume and the
  director rejects a boxed 1x2 imitation. Gapped ladders reach the hatch, and
  there is deliberately no exposed ground-level enemy entrance.
- Protected home and frontline Tunnels are distinct mixed-material prefabs so
  the two-end network is built in order and its stone/gold conversion costs
  cannot be hidden inside nominal wood-only tasks.
- A late quarry/storage prefab stacks the Quarry above Storage with a clear
  falling-output column and one-tile vertical gap.  A live same-team Quarry
  suppresses this candidate, preserving KAG's one-Quarry-per-team limit.
- Tunnel and Quarry candidates are published before the team already owns their
  required gold. Outstanding gold cost creates stone-miner demand because that
  role discovers and returns visible gold; requiring stored gold before planning
  would otherwise leave the director with no plan capable of requesting it.
- All directly created typed shops pay the installed base workshop cost plus
  their current conversion requirements.  This also applies to user-authored
  blueprint tasks.
- Saw use is behavioral: when a safe same-team saw already exists near the
  resource base, a worker may deliver a harvested log to it instead of chopping
  the log manually.  The director does not fabricate a saw or siege engine from
  team materials because those are carried, non-grid items whose safe purchase,
  transport, and deployment are not represented by the blueprint task model.

## 1.5 Example base

- Early flag-room access is reachable with no more than the guide's ten-ladder
  budget and uses stone backing.
- The flag room has home-side floor access, an elevated enemy-side entrance,
  and a top ladder/hatch route. The two-course roof is opened across two columns
  in both rows, so the hatch is four reinforced door cells rather than a 1x2
  shaft. Its doors are predominantly wood rather than stone-door spam. Its
  central no-build channel remains task-free around the actual `ctf_flag`
  sector.
- The frontline wall carries full three-layer thickness above its six lower
  door cells, a firebroken middle layer, redundant backing, and reinforced
  one-way platform cover.
- Protected shop, home Tunnel, frontline Tunnel, and quarry/storage plans are
  separate one-shot stages so the first defense can become useful without
  waiting for a megaproject or repeatedly rebuilding the same station.
- A completed stage triggers the next director heartbeat immediately; it is not
  held behind the old 300-tick completed-plan delay or match-start transition.
- Nursery planting prefers natural ground positions separated by one empty
  tile; this keeps a reusable horizontal tree line instead of overlapping trees
  or vertically crowding them.

Mines, trampoline timing, saw traps, and wheeled siege placement remain player
actions.  The current AI has no coin account, carried-item deployment task, or
siege-operation role; silently spawning those objects would bypass the chapter's
economy and would not be a faithful Builder behavior.

## 1.6 Support

- Stone is used for short, grounded defensive spans.  Long access/cover spans
  use wood or are split by stone supports; guide templates never rely on an
  unsupported long stone beam.
- Generated foreground support continues to be a paid backwall dependency and
  is placed in an earlier phase.

## 1.7 Repair

- Foreground and backwall tiles are repaired at full material cost.
- A tile whose damage is still changing is deferred until it reaches its final
  damage stage; if attacks stop, ordinary damage becomes repairable after a
  quiet window.
- Doors, platforms, bridges, ladders, shops, and other blob structures are not
  healed in place.  Their completed task stays recorded as damaged while the
  object lives, and is reactivated for a full-cost rebuild only after it is
  destroyed.

## 1.8 Common mistakes

- Exposed shops are rejected in favor of the stone-backed protected prefab.
- Stone-door spam is prevented by explicit door-count/material invariants.
- Wood is restricted to supported access, firebroken middle layers, and
  reinforced one-way cover rather than the exposed shell.
- Home-side doors stay at floor level; the enemy-side flag-room entrance is
  deliberately elevated.
- Knight Shops and saws are absent from the flag-room prefab.
- Blueprint task reservations cover active approach/build work only. An
  ordinary Builder releases its lease before collecting missing materials, and
  every worker releases stale/no-longer-needed targets so multiple workers
  cannot form a reservation-expiry loop.

## 1.9 Playstyles

- The ordinary one-shot order is flag room, frontline tower, protected shops,
  home Tunnel, frontline Tunnel, then Quarry/Storage. This is a hard stage gate,
  not a score bonus that lets obsolete templates win.
- If the earliest unfinished stage has no valid site, the director tries the
  next valid guide stage instead of stalling. A real collapse may still select
  the emergency barrier immediately.
- Offensive combat and siege operation remain Knight/Archer/vehicle concerns;
  the Builder contributes through safe infrastructure rather than receiving a
  fabricated combat controller.

## Evidence scenarios

The runtime suite contains one focused scenario for each new contract:

1. flag-room entrance and material invariants, including all three 2x2 player
   volumes and the four-cell hatch through both roof courses;
2. three-layer tower, firebreak, door, ladder, cover, and 2x2 lower-passage
   invariants;
3. protected-shop backing, safe role placement, two independent 2x2 exits, and
   production-director rejection of a boxed 1x2 aperture;
4. protected Tunnel geometry and 2x2 entrance, mixed cost, zero-gold publication, and gold-driven
   stone-miner demand;
5. Quarry-over-Storage geometry, 2x2 entrance, and mixed cost;
6. exact guide-stage order, production legacy exclusion, immediate completed-plan
   replacement, zero-gold progression, and emergency override retained;
7. warm-up/match resupply amounts, location gate, and safe-boundary visit;
8. quiet/critical tile repair plus destroy-before-rebuild blob policy;
9. natural-ground tree spacing and delivery to an existing safe saw;
10. installed typed-shop cost matrix plus atomic multi-material payment and
    conservation;
11. Boat Shop land rejection and water-site acceptance;
12. one-shot home Tunnel, then distinct frontline Tunnel, then quarry/storage
    staging at zero gold, including no-spend suppression in both planner and
    direct creation when the team already owns a Quarry;
13. material-trip reservation release and two-Autobuilder contention on one
    physical task, including loser retarget and zero final reservations.

## Validation status

- The source registers 78 unique scenarios and loads 75 strategy-weight keys.
- All retained offline parser, comparator, generator, and abstract-simulator
  regressions passed after the Chapter 1 changes. These checks do not count as
  AngelScript behavior evidence.
- Guide scenarios 65–70 emitted individual visible-KAG PASS records in
  `console-26-07-20-07-05-25.txt`.
- Guide scenarios 71–76 were then run as the affected focused range and ended
  with `[AIBTEST] DONE passed=6 failed=0` in
  `console-26-07-20-07-33-30.txt`.
- The affected workshop siting pair ended with
  `[AIBTEST] DONE passed=2 failed=0` in
  `console-26-07-20-07-33-14.txt`.
- The corrected flag no-build channel, two-exit protected workshop, zero-gold
  Tunnel/miner demand, hard guide progression, and zero-gold two-Tunnel network
  each emitted a focused PASS in `console-26-07-20-08-30-22.txt`.
- The four-cell player-volume correction ran only cases 65–69. Flag, tower, and
  the initial workshop assertion passed in `console-26-07-20-09-03-40.txt`;
  Quarry/Storage passed in `console-26-07-20-09-04-26.txt`; Tunnel passed with a
  separately flushed `DONE` in `console-26-07-20-09-05-47.txt`. The strengthened
  workshop case then proved the production director rejects a boxed 1x2 aperture
  as `friendly_route` in `console-26-07-20-09-08-54.txt`.
- The reservation-contention case passed through the visible persistent TCPR
  loop as strengthened run `68d8e2cd8af1` at tick 8 with the waiting orb's
  retarget explicitly observed and zero final reservations. The preceding
  cold attempt in `console-26-07-20-08-37-43.txt` stopped advancing after archive
  and is retained as 0/0 no-verdict engine-stall evidence, not a failure.
- No full 78-scenario run is claimed. The user requested affected cases only,
  and the unrelated experimental stone-route re-entry fixture remains a known
  red case in `GOAL_HANDOFF.md`.
- The long harvest regression remains inconclusive on the current fixture:
  `console-26-07-20-07-26-01.txt` reached real tree/log processing, built the
  base shop and crate, emitted a 350-wood delivery, and retained no Gym flags,
  but the old stock assertion failed because the same 350 wood paid those two
  structures. Subsequent focused launches stopped advancing mid-log processing
  before a verdict. This is recorded as engine-run evidence, not a pass.
- Fresh normal-CTF runs on official `Ferrezinhre_Totally_Transcendent` are
  recorded in `console-26-07-20-09-56-34.txt` and
  `console-26-07-20-09-59-19.txt`. They are direct-map evidence, not AIBTest
  verdicts. At tick 30 the director published, provisioned, and assigned work
  for both teams; every base-scoped candidate used Tent-level ground row 73.
- The exact map still has one open protected-shop fit edge. The compact shell
  at `(52,73)` preserves both 5x3 shops, the two-cell home entry, and the 2x2
  roof hatch, but its optional terrain-leveling stair reaches the flag-base
  no-build cell `(39,78)` and is rejected. The safe next change is adaptive
  home access that stops before that sector and must still pass the existing
  full-2x2 route validator. No completion claim is made for this edge.
- Runtime iteration was paused at the user's request. Do not run the AIBTest
  suite on resume; use a fresh visible normal-CTF session on the exact official
  map unless the user explicitly changes that direction.
