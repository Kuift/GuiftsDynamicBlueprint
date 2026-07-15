# AIBTest claim audit

This ledger audits what each of the 65 scenario names actually claims and what its current verdict proves. It is not a substitute for an in-game run. `Runtime pass` means a visible build-4762 KAG verdict exists; `aligned, runtime pending` means the assertion matches the narrow name on source inspection but still needs KAG evidence; `weak` means the name or proof remains stronger than the observed condition.

| # | Scenario | Audit status | Current proof or remaining gap |
|---:|---|---|---|
| 0 | `flat_harvest_processes_logs_and_delivers_to_base_storage` | Runtime pass, 2026-07-15 | Requires real tree targeting/felling, a live log, wood acquisition, and material inside base storage. Final pass: 659 ticks, 50 wood delivered after storage costs. |
| 1 | `carried_wood_builds_grounded_storage_and_delivers` | Runtime pass, 2026-07-15 | Requires a valid grounded production workshop, a production-tagged grounded crate, and completed delivery. Pass: 25 ticks, 40 wood stored after 200 wood of construction costs. |
| 2 | `8x_gloryhill_leftmost_tree_uses_hill_route` | Runtime pass, 2026-07-15 | Rejects a direct shortcut, requires the selected tree and a physical health-reducing hit. Pass: 179 ticks after 239 px horizontal and 78 px vertical net travel. |
| 3 | `selected_trees_override_distance` | Aligned, runtime pending | Narrow target-selection contract; does not claim travel or harvesting. |
| 4 | `no_selected_trees_uses_home_priority` | Aligned, runtime pending | Narrow target-priority contract. |
| 5 | `barrier_rejects_inaccessible_tree` | Aligned, runtime pending | Requires the across-barrier candidate to be rejected. |
| 6 | `enemy_safety_rejects_right_knight_open_threat` | Aligned, runtime pending | Narrow resource-rejection contract. |
| 7 | `enemy_safety_rejects_left_knight_open_threat` | Aligned, runtime pending | Mirrored narrow resource-rejection contract. |
| 8 | `enemy_safety_rejects_right_archer_open_threat` | Aligned, runtime pending | Narrow resource-rejection contract. |
| 9 | `knight_fear_interrupts_work` | Weak | Proves target/work interruption but not goal-directed flee displacement or attribution to the fear branch. |
| 10 | `wall_blocks_knight_fear` | Aligned, runtime pending | Requires work to remain uninterrupted behind terrain; does not claim route completion. |
| 11 | `pathing_reaches_obstacle_region` | Narrowed, prior runtime pass | Formerly claimed recovery and accepted a destination at tick 2. Now requires physical entry into the region; three prior passes reached it at tick 45. It does not claim a recovery branch. |
| 12 | `no_home_does_not_drop_locally` | Strengthened, runtime pending | Now sustains `return_wood` for 90 ticks, requires explicit home-wait status, and verifies the material remains held. |
| 13 | `tree_selection_toggle_filtering` | Aligned, runtime pending | Tests the simulated selection/filter state, not real mouse/UI delivery. |
| 14 | `kag_path_moves_to_tree_over_hill` | Runtime pass, 2026-07-15 | Requires selected target observation, physical felling, and a live spawned log. Pass: 393 ticks. |
| 15 | `kag_path_builds_supported_ladder_chain` | Broken fixture | The predicate requires support-before-ladder, a post-placement path probe, preserved dirt, and crossing. Runtime instead crossed without creating a ladder; the arena does not force the named branch. Redesign required. |
| 16 | `blueprint_collects_home_materials` | Aligned, runtime pending | Requires actual withdrawal of both named materials from base storage into the builder. |
| 17 | `blueprint_waits_for_late_blueprint` | Strengthened, runtime pending | The former pass-by-still-waiting fallback was removed; it must acquire the tile added after startup. |
| 18 | `strategic_auto_director_heartbeat_end_to_end` | Aligned, runtime pending | Exercises the named director heartbeat pipeline; keep it distinct from physical build completion. |
| 19 | `wood_builder_buys_nursery_seed_with_stone` | Weak | Observes the purchase result but does not strongly attribute the consumed stone and purchase to the intended worker/action boundary. |
| 20 | `wood_builder_builds_and_feeds_quarry_when_stone_unsafe` | Physical PASS marker, range completion stalled, 2026-07-15 | `console-26-07-15-15-22-08.txt` recorded production `build_quarry` with 200 wood, `feed_quarry` with 100 wood/fuel, and PASS at tick 23. The following case froze before the range emitted DONE, so retain this as a focused case pass rather than a completed two-case range. |
| 21 | `stone_builder_collects_loose_stone_near_quarry_when_tiles_unsafe` | Runtime pass, 2026-07-15 | The isolated visible run in `console-26-07-15-15-26-12.txt` emitted PASS/DONE at tick 12 with 80 injected local loose stone collected, `return_wood`, no target, and `gym=none`. It does not claim the quarry generated the injected output. |
| 22 | `multiple_builders_store_resources_in_shared_crates` | Weak | The evaluator assists state progression and the conservation bound is loose; strengthen before treating it as independent multi-worker proof. |
| 23 | `stone_job_stays_active_without_safe_stone` | Renamed honestly, runtime pending | Sustains the active no-target state for 90 ticks; it does not claim that multiple retries occurred. |
| 24 | `wood_builder_builds_nursery_buys_and_plants_tree` | Aligned, runtime pending | Requires nursery existence, a tagged planted seed, and the production wait state. |
| 25 | `blueprint_team_isolation` | In-game data contract, runtime pending | Narrow team-layer isolation assertion; no physical build claim. |
| 26 | `strategic_human_ai_layers_preserved` | In-game data contract, runtime pending | Layer preservation assertion. |
| 27 | `strategic_completed_plan_history` | In-game data contract, runtime pending | Plan history/archive assertion. |
| 28 | `strategic_remaining_material_cost` | In-game data contract, runtime pending | Exact remaining-cost arithmetic assertion. |
| 29 | `strategic_reservations_and_phases` | In-game data contract, runtime pending | Reservation/phase state assertion. |
| 30 | `strategic_catalog_doors_platforms` | In-game data contract, runtime pending | Catalog metadata assertion, not physical creation. |
| 31 | `strategic_stale_human_delta_rejected` | In-game data contract, runtime pending | Version-authority assertion. |
| 32 | `strategic_hard_rejects_barrier` | In-game data contract, runtime pending | Planner rejection assertion. |
| 33 | `human_blueprint_reservation_exclusive` | In-game data contract, runtime pending | Reservation exclusivity assertion. |
| 34 | `blueprint_builds_wooden_door` | Weak | Creation is observed, but the full named production episode, cost, support, and stable completion are not all proved. |
| 35 | `blueprint_builds_platform` | Weak | Creation-only evidence; strengthen cost/support/stable completion before claiming the whole build episode. |
| 36 | `construction_menu_has_nursery_and_quarry` | Aligned, runtime pending | Narrow menu/catalog presence contract. |
| 37 | `strategic_template_phases_and_passage` | In-game data contract, runtime pending | Template phase/passage metadata assertion. |
| 38 | `strategic_hard_rejects_human_overlap` | In-game data contract, runtime pending | Planner overlap rejection assertion. |
| 39 | `strategic_replan_hysteresis` | In-game data contract, runtime pending | Replan identity/hysteresis assertion. |
| 40 | `strategic_destroyed_task_reactivated` | In-game data contract, runtime pending | Task-state reactivation assertion. |
| 41 | `strategic_candidate_intent_anchor_footprint` | In-game data contract, runtime pending | Candidate anchor/footprint assertion. |
| 42 | `stone_miner_discovers_mines_and_delivers_visible_gold` | Strong physical assertion, runtime pending | Requires LOS discovery, real ore removal, cluster exhaustion, delivery, and occluded negative control. |
| 43 | `stone_corner_escape_from_mirrored_upper_overhangs` | Runtime pass, 2026-07-15 | Fresh visible diagonal-only mirrored traps passed at tick 138 with both full 36-tick escapes, both cooldown latches, one-tile displacement on each side, and intact castle traps. Earlier ceiling-plus-diagonal hot passes remain separate evidence. |
| 44 | `storage_workshop_skips_obstructed_tent_sites` | Strong physical assertion, runtime pending | Requires a production-created, fully supported, clear workshop beyond blocked near sites. |
| 45 | `storage_workshop_requires_full_hall_foundation` | Strong physical assertion, runtime pending | Requires all five support columns and a farther valid site. |
| 46 | `stone_route_prefers_reusable_open_corridor` | Runtime pass, 2026-07-15 | Real target mined; planned dirt only was destroyed; off-route dirt, bedrock, and castle controls remained. |
| 47 | `strategic_bootstrap_respects_mode_and_existing_worker` | Weak/oversized | A large fixture directly mutates and calls production helpers. Split it so each name identifies one independently observed lifecycle. |
| 48 | `strategic_bootstrap_is_one_time_and_releases_reservation` | Weak | The fixture can acquire the reservation through a test helper, so release is not yet proof of a production-acquired reservation episode. |
| 49 | `stone_order_mines_exposed_stone_and_delivers` | Runtime pass, 2026-07-15 | Requires selected real tile, tile destruction, acquired stone, and material inside the crate. Pass: 140 ticks, 24 stone delivered. |
| 50 | `gym_tree_order_harvests_and_delivers_selected_tree` | Runtime pass, 2026-07-15 | Requires accepted order, selected tree, felling, a live log, processed wood, and completed delivery with no gym flags. Pass: 1,032 ticks, 350 wood delivered. |
| 51 | `blueprint_builds_generated_backwall_support` | Strong physical assertion, runtime pending | Requires support first, foreground completion, costs, task state, and no partial-side-effect pass. |
| 52 | `full_crate_creates_grounded_overflow_storage` | Runtime pass, 2026-07-15 | Pass: two distinct grounded crates, 100 stone stored, 150 wood paid, total material conserved. |
| 53 | `damaged_owned_tile_is_repaired_without_replacing_neighbors` | Prior focused runtime pass | Existing focused evidence is recorded in `console-26-07-10-17-32-06.txt`; rerun after repair changes. |
| 54 | `strategic_mirrored_sides_physically_complete_safe_inward_plans` | Strong physical assertion, runtime pending | Requires both mirrored production plans to complete and archive exactly. |
| 55 | `strategic_uneven_right_edge_fallback_physically_completes` | Strong physical assertion, runtime pending | Requires blocked-primary fallback and exact physical/task completion. |
| 56 | `strategic_scarcity_penalizes_unfunded_large_plan` | Aligned scoring assertion, runtime pending | Exact shortage-pressure scoring; no physical build claim. |
| 57 | `strategic_collapse_pressure_prefers_emergency_barrier` | Aligned selection assertion, runtime pending | Emergency candidate selection under the named pressure. |
| 58 | `strategic_damaged_front_reactivates_without_plan_replacement` | Strong lifecycle assertion, runtime pending | Requires same plan identity and safe damaged-front reactivation. |
| 59 | `strategic_autobuilder_physically_completes_selected_plan` | Strong physical assertion, runtime pending | Requires production executor completion, work-layer clearing, reservations, and archive state. |
| 60 | `strategic_bootstrap_rejects_sealed_cave_spawn` | Strong rejection assertion, runtime pending | Requires the sealed locally clear pocket to be rejected. |
| 61 | `strategic_no_build_primary_falls_back_and_physically_completes` | Strong physical assertion, runtime pending | Requires exact no-build rejection, fallback, and full production completion. |
| 62 | `strategic_occupied_primary_falls_back_and_physically_completes` | Strong physical assertion, runtime pending | Requires protected/occupied rejection, fallback, and full completion. |
| 63 | `strategic_barrier_primary_falls_back_and_physically_completes` | Strong physical assertion, runtime pending | Requires active-barrier rejection, fallback, and full completion. |
| 64 | `strategic_blocked_bootstrap_cools_down_and_round_reset_recovers_both_sides` | Weak lifecycle proof | Calls the round-reset helper directly rather than observing an actual round transition. The cooldown checks are useful, but the round-reset claim still needs a real lifecycle event. |

## Current conclusions

- A full-suite green verdict has not been recorded. Focused passes above must not be presented as `65 passed`.
- Scenario 15 is the highest-priority broken fixture because its name claims a recovery branch that the arena does not exercise.
- Scenarios 9, 19, 20, 22, 34, 35, 47, 48, and 64 still need stronger attribution or lifecycle proof.
- Source-text/regex contract scripts were removed. AngelScript compilation and behavior are validated in visible KAG through TCPR; retained offline tests validate only parsers, comparators, generators, and the abstract simulator.
