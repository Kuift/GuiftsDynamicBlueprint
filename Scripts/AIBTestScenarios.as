#include "AIBTestEventLog.as";
#include "AIBTestAssertions.as";
#include "ShopCommon.as";
#include "BlueprintData.as";
#include "AIBStrategicJobs.as";
#include "AIBStoneRouteCommon.as";

const int AIBT_ORIGIN_X = 12;
const int AIBT_WIDTH = 150;
const int AIBT_GROUND_Y = 72;
const u8 AIBT_FALLBACK_NO_BUILD = 1;
const u8 AIBT_FALLBACK_OCCUPIED = 2;
const u8 AIBT_FALLBACK_BARRIER = 3;
u16[] AIBT_spawned_ids;
Vec2f[] AIBT_changed_tiles;
u16[] AIBT_original_tiles;
Vec2f[] AIBT_route_dirt_tiles;
Vec2f[] AIBT_temporary_no_build_points;
u16[] AIBT_temporary_no_build_owners;
bool AIBT_temporary_no_build_cleanup_failed = false;
u16[] AIBT_canonical_tiles;
u16 AIBT_canonical_width = 0;
u16 AIBT_canonical_height = 0;
u32 AIBT_canonical_hash = 0;

string[] AIBT_SCENARIOS =
{
	"flat_harvest_delivers_to_tent",
	"full_inventory_returns_to_tent",
	"8x_gloryhill_leftmost_tree_uses_hill_route",
	"selected_trees_override_distance",
	"no_selected_trees_uses_home_priority",
	"barrier_rejects_inaccessible_tree",
	"enemy_safety_rejects_right_knight_open_threat",
	"enemy_safety_rejects_left_knight_open_threat",
	"enemy_safety_rejects_right_archer_open_threat",
	"knight_fear_interrupts_work",
	"wall_blocks_knight_fear",
	"pathing_obstacle_recovery",
	"no_home_does_not_drop_locally",
	"tree_selection_toggle_filtering",
	"kag_path_moves_to_tree_over_hill",
	"kag_path_builds_supported_ladder_chain",
	"blueprint_collects_home_materials",
	"blueprint_waits_for_late_blueprint",
	"strategic_auto_director_heartbeat_end_to_end",
	"wood_builder_buys_nursery_seed_with_stone",
	"wood_builder_builds_and_feeds_quarry_when_stone_unsafe",
	"stone_builder_collects_quarry_output_when_tiles_unsafe",
	"multiple_builders_store_resources_in_shared_crates",
	"stone_job_retries_without_safe_stone",
	"wood_builder_builds_nursery_buys_and_plants_tree",
	"blueprint_team_isolation",
	"strategic_human_ai_layers_preserved",
	"strategic_completed_plan_history",
	"strategic_remaining_material_cost",
	"strategic_reservations_and_phases",
	"strategic_catalog_doors_platforms",
	"strategic_stale_human_delta_rejected",
	"strategic_hard_rejects_barrier",
	"human_blueprint_reservation_exclusive",
	"blueprint_builds_wooden_door",
	"blueprint_builds_platform",
	"construction_menu_has_nursery_and_quarry",
	"strategic_template_phases_and_passage",
	"strategic_hard_rejects_human_overlap",
	"strategic_replan_hysteresis",
	"strategic_destroyed_task_reactivated",
	"strategic_candidate_intent_anchor_footprint",
	"stone_miner_discovers_mines_and_delivers_visible_gold",
	"stone_corner_escape_from_mirrored_upper_overhangs",
	"storage_workshop_skips_obstructed_tent_sites",
	"storage_workshop_requires_full_hall_foundation",
	"stone_route_prefers_reusable_open_corridor",
	"strategic_bootstrap_respects_mode_and_existing_worker",
	"strategic_bootstrap_is_one_time_and_releases_reservation",
	"stone_order_mines_exposed_stone_and_delivers",
	"gym_tree_order_harvests_and_delivers_selected_tree",
	"blueprint_builds_generated_backwall_support",
	"full_crate_creates_grounded_overflow_storage",
	"damaged_owned_tile_is_repaired_without_replacing_neighbors",
	"strategic_mirrored_sides_select_safe_inward_candidates",
	"strategic_uneven_right_edge_selects_reachable_fallback",
	"strategic_scarcity_penalizes_unfunded_large_plan",
	"strategic_collapse_pressure_prefers_emergency_barrier",
	"strategic_damaged_front_reactivates_without_plan_replacement",
	"strategic_autobuilder_physically_completes_selected_plan",
	"strategic_bootstrap_rejects_sealed_cave_spawn",
	"strategic_no_build_primary_falls_back_and_physically_completes",
	"strategic_occupied_primary_falls_back_and_physically_completes",
	"strategic_barrier_primary_falls_back_and_physically_completes",
	"strategic_blocked_bootstrap_cools_down_and_round_reset_recovers_both_sides"
};

string AIBT_ScenarioName(const int index)
{
	if (index < 0 || index >= int(AIBT_SCENARIOS.length)) return "unknown";
	return AIBT_SCENARIOS[index];
}

u32 AIBT_MapTileHash(CMap@ map)
{
	if (map is null) return 0;
	u32 hash = 2166136261;
	const uint cells = uint(map.tilemapwidth) * uint(map.tilemapheight);
	for (uint i = 0; i < cells; i++) hash = (hash ^ u32(map.getTile(i).type)) * 16777619;
	return hash;
}

u16 AIBT_CountLiveTagged(const string &in tag)
{
	CBlob@[] blobs;
	getBlobsByTag(tag, @blobs);
	u16 count = 0;
	for (uint i = 0; i < blobs.length; i++) if (blobs[i] !is null && !blobs[i].hasTag("dead")) count++;
	return count;
}

void AIBT_CaptureOrValidateCanonicalMap()
{
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null) return;
	rules.set_string("aibt canonical reset failure", "");
	const u16 fixtureLeaks = AIBT_CountLiveTagged("aibt test fixture");
	const u16 bootstrapLeaks = AIBT_CountLiveTagged("aib strategy bootstrap worker");
	if (fixtureLeaks > 0 || bootstrapLeaks > 0 || AIBT_temporary_no_build_points.length > 0 ||
		AIBT_temporary_no_build_owners.length > 0 || AIBT_temporary_no_build_cleanup_failed)
	{
		rules.set_string("aibt canonical reset failure", "fixture_leak blobs=" + fixtureLeaks + " bootstrap=" + bootstrapLeaks +
			" sectors=" + AIBT_temporary_no_build_points.length + "/" + AIBT_temporary_no_build_owners.length +
			" sector_cleanup_failed=" + (AIBT_temporary_no_build_cleanup_failed ? "true" : "false"));
		return;
	}
	for (u8 team = 0; team < 8; team++)
	{
		if (rules.get_u16(AIBP_PlanKey(team, "id")) != 0 || rules.get_u8(AIBP_ModeKey(team)) != AIBP_StrategyMode::off)
		{
			rules.set_string("aibt canonical reset failure", "strategy_leak team=" + team + " plan=" +
				rules.get_u16(AIBP_PlanKey(team, "id")) + " mode=" + rules.get_u8(AIBP_ModeKey(team)));
			return;
		}
	}
	const uint cells = uint(map.tilemapwidth) * uint(map.tilemapheight);
	if (AIBT_canonical_tiles.length == 0)
	{
		AIBT_canonical_width = map.tilemapwidth;
		AIBT_canonical_height = map.tilemapheight;
		AIBT_canonical_tiles.set_length(cells);
		for (uint i = 0; i < cells; i++) AIBT_canonical_tiles[i] = map.getTile(i).type;
		AIBT_canonical_hash = AIBT_MapTileHash(map);
		AIB_LogEvent("test", "canonical_map_capture", "runner", "width=" + AIBT_canonical_width + " height=" + AIBT_canonical_height + " hash=" + AIBT_canonical_hash);
		return;
	}
	if (map.tilemapwidth != AIBT_canonical_width || map.tilemapheight != AIBT_canonical_height || cells != AIBT_canonical_tiles.length)
	{
		rules.set_string("aibt canonical reset failure", "dimension_mismatch expected=" + AIBT_canonical_width + "x" + AIBT_canonical_height +
			" actual=" + map.tilemapwidth + "x" + map.tilemapheight);
		return;
	}
	const u32 actual = AIBT_MapTileHash(map);
	if (actual != AIBT_canonical_hash)
		rules.set_string("aibt canonical reset failure", "tile_hash_mismatch expected=" + AIBT_canonical_hash + " actual=" + actual);
}

u32 AIBT_RestoreCanonicalMap()
{
	CMap@ map = getMap();
	if (map is null || AIBT_canonical_tiles.length == 0 || map.tilemapwidth != AIBT_canonical_width || map.tilemapheight != AIBT_canonical_height) return 0;
	u32 restored = 0;
	for (uint i = 0; i < AIBT_canonical_tiles.length; i++)
	{
		if (map.getTile(i).type == AIBT_canonical_tiles[i]) continue;
		const u32 x = i % map.tilemapwidth;
		const u32 y = i / map.tilemapwidth;
		map.server_SetTile(Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize), AIBT_canonical_tiles[i]);
		restored++;
	}
	return restored;
}

void AIBT_PrepareArena(const bool wall = false, const bool lowObstacle = false)
{
	// Terrain fixtures live in Maps/AIBTest/aib_suite.png. The old test
	// harness rewrote the loaded map every scenario, which hid map/pathing bugs.
}

Vec2f AIBT_Pos(const int tileX, const int tileY = AIBT_GROUND_Y - 2)
{
	return Vec2f(tileX * 8 + 4, tileY * 8 + 4);
}

void AIBT_KillNamed(const string &in name)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	for (uint i = 0; i < blobs.length; i++)
	{
		if (blobs[i] !is null)
		{
			blobs[i].server_Die();
		}
	}
}

void AIBT_CleanupScenario()
{
	AIBT_temporary_no_build_cleanup_failed = false;
	CMap@ cleanupMap = getMap();
	if (cleanupMap !is null)
	{
		for (uint i = 0; i < AIBT_temporary_no_build_points.length && i < AIBT_temporary_no_build_owners.length; i++)
		{
			cleanupMap.RemoveSectorsAtPosition(AIBT_temporary_no_build_points[i], "no build", AIBT_temporary_no_build_owners[i]);
			CMap::Sector@ remaining = cleanupMap.getSectorAtPosition(AIBT_temporary_no_build_points[i], "no build");
			if (remaining !is null && remaining.ownerID == AIBT_temporary_no_build_owners[i])
				AIBT_temporary_no_build_cleanup_failed = true;
		}
	}
	AIBT_temporary_no_build_points.clear();
	AIBT_temporary_no_build_owners.clear();

	// DefaultNoBuild paints persistent wood backwall behind a buildershop.
	// Restore only tracked workshop footprint cells before resetting fixtures.
	AIBT_RestoreWorkshopBackgrounds(AIBT_GROUND_Y);

	if (cleanupMap !is null)
	{
		for (uint i = 0; i < AIBT_changed_tiles.length && i < AIBT_original_tiles.length; i++)
		{
			cleanupMap.server_SetTile(AIBT_changed_tiles[i], AIBT_original_tiles[i]);
		}
	}
	AIBT_changed_tiles.clear();
	AIBT_original_tiles.clear();
	AIBT_route_dirt_tiles.clear();

	u16 killed = 0;
	for (uint i = 0; i < AIBT_spawned_ids.length; i++)
	{
		CBlob@ blob = getBlobByNetworkID(AIBT_spawned_ids[i]);
		if (blob !is null)
		{
			if (blob.getName() == "aibuilder" || blob.getName() == "autobuilder")
				AIBP_ReleaseBuilderReservation(u8(blob.getTeamNum()), blob.getNetworkID());
			blob.set_u8("ai builder state", AIBT_IDLE);
			blob.set_netid("ai builder target", 0);
			blob.Tag("dead");
			blob.server_Die();
			killed++;
		}
	}

	// Director-bootstrap workers are production-created rather than fixtures,
	// so they are not present in AIBT_spawned_ids. Remove them explicitly to
	// preserve scenario isolation.
	CBlob@[] bootstrapWorkers;
	getBlobsByTag("aib strategy bootstrap worker", @bootstrapWorkers);
	for (uint i = 0; i < bootstrapWorkers.length; i++)
	{
		CBlob@ worker = bootstrapWorkers[i];
		if (worker is null || worker.hasTag("dead")) continue;
		AIBP_ReleaseBuilderReservation(u8(worker.getTeamNum()), worker.getNetworkID());
		worker.Tag("dead");
		worker.server_Die();
		killed++;
	}

	// Workshop purchases are not fixture-spawn tracked. Do not let a manually
	// deployed collisionless worker or its team speed setting leak into the next
	// deterministic scenario.
	CBlob@[] untrackedAutoBuilders;
	getBlobsByName("autobuilder", @untrackedAutoBuilders);
	for (uint i = 0; i < untrackedAutoBuilders.length; i++)
	{
		CBlob@ worker = untrackedAutoBuilders[i];
		if (worker is null || worker.hasTag("dead")) continue;
		if (worker.getTeamNum() >= 0 && worker.getTeamNum() < 8)
			AIBP_ReleaseBuilderReservation(u8(worker.getTeamNum()), worker.getNetworkID());
		worker.Tag("dead");
		worker.server_Die();
		killed++;
	}

	CBlob@[] fixtures;
	getBlobsByTag("aibt test fixture", @fixtures);
	for (uint i = 0; i < fixtures.length; i++)
	{
		CBlob@ blob = fixtures[i];
		if (blob !is null && !blob.hasTag("dead"))
		{
			blob.set_netid("ai builder target", 0);
			blob.Tag("dead");
			blob.server_Die();
			killed++;
		}
	}

	string[] generatedNames = {
		"mat_wood", "mat_stone", "mat_gold", "log", "seed", "tree_pine", "tree_bushy",
		"buildershop", "crate", "quarry", "nursery", "ladder", "building",
		"wooden_door", "stone_door", "wooden_platform"
	};
	for (uint i = 0; i < generatedNames.length; i++)
	{
		CBlob@[] blobs;
		getBlobsByName(generatedNames[i], @blobs);
		for (uint j = 0; j < blobs.length; j++)
		{
			CBlob@ blob = blobs[j];
			if (blob !is null && !blob.hasTag("dead"))
			{
				blob.Tag("dead");
				blob.server_Die();
				killed++;
			}
		}
	}

	CRules@ rules = getRules();
	if (rules !is null)
	{
		for (u8 team = 0; team < 8; team++) AIBU_ResetSpeedLevel(rules, team);
		rules.SetCurrentState(GAME);
		rules.set_bool("aib test resource barrier", false);
		rules.set_u16("barrier_x1", 0);
		rules.set_u16("barrier_x2", 0);
	}
	const u32 restoredCanonicalTiles = AIBT_RestoreCanonicalMap();
	AIB_LogEvent("test", "cleanup", "runner", "killed=" + killed + " canonical_tiles_restored=" + restoredCanonicalTiles);
	AIBT_spawned_ids.clear();
	AIBT_ClearScenarioRefs();
}

void AIBT_FreezeFinalFixture()
{
	for (uint i = 0; i < AIBT_spawned_ids.length; i++)
	{
		CBlob@ blob = getBlobByNetworkID(AIBT_spawned_ids[i]);
		if (blob is null || blob.hasTag("dead")) continue;
		blob.setVelocity(Vec2f_zero);
		blob.setKeyPressed(key_left, false);
		blob.setKeyPressed(key_right, false);
		blob.setKeyPressed(key_up, false);
		blob.setKeyPressed(key_down, false);
		blob.setKeyPressed(key_action1, false);
		blob.setKeyPressed(key_action2, false);
		CBrain@ brain = blob.getBrain();
		if (brain !is null) brain.server_SetActive(false);
	}

	CBlob@[] autoBuilders;
	getBlobsByName("autobuilder", @autoBuilders);
	for (uint i = 0; i < autoBuilders.length; i++)
	{
		CBlob@ worker = autoBuilders[i];
		if (worker is null || worker.hasTag("dead")) continue;
		worker.setVelocity(Vec2f_zero);
		worker.set_bool("ai builder job active", false);
		CBrain@ brain = worker.getBrain();
		if (brain !is null) brain.server_SetActive(false);
	}
}

void AIBT_SetTemporaryTile(const int tileX, const int tileY, const u16 type)
{
	CMap@ map = getMap();
	if (map is null) return;
	Vec2f tile = Vec2f(tileX * map.tilesize, tileY * map.tilesize);
	AIBT_changed_tiles.push_back(tile);
	AIBT_original_tiles.push_back(map.getTile(tile).type);
	map.server_SetTile(tile, type);
}

bool AIBT_AddTemporaryNoBuildTile(const u16 tileX, const u16 tileY, const u16 ownerID)
{
	CMap@ map = getMap();
	if (map is null || ownerID == 0 || tileX >= map.tilemapwidth || tileY >= map.tilemapheight) return false;
	Vec2f upperLeft = Vec2f(tileX * map.tilesize, tileY * map.tilesize);
	Vec2f lowerRight = Vec2f((tileX + 1) * map.tilesize, (tileY + 1) * map.tilesize);
	Vec2f center = Vec2f((tileX + 0.5f) * map.tilesize, (tileY + 0.5f) * map.tilesize);
	map.server_AddSector(upperLeft, lowerRight, "no build", "", ownerID);
	AIBT_temporary_no_build_points.push_back(center);
	AIBT_temporary_no_build_owners.push_back(ownerID);
	return map.getSectorAtPosition(center, "no build") !is null;
}

CBlob@ AIBT_Spawn(const string &in name, const u8 team, Vec2f pos)
{
	CBlob@ blob = server_CreateBlob(name, team, pos);
	if (blob !is null)
	{
		blob.Tag("aibt test fixture");
		AIBT_spawned_ids.push_back(blob.getNetworkID());
		if (name == "buildershop") AIBT_TrackWorkshopBackground(blob, AIBT_GROUND_Y);
		AIB_LogEvent("test", "spawn", AIBT_BlobRef(blob), "team=" + team + " pos=" + AIB_EventPos(pos));
	}
	return blob;
}

CBlob@ AIBT_SpawnTentTeam(const int tileX, const u8 team)
{
	CBlob@ tent = AIBT_Spawn("tent", team, AIBT_Pos(tileX, AIBT_GROUND_Y - 2));
	AIBT_SetBlob("aibt_tent", tent);
	return tent;
}

CBlob@ AIBT_SpawnTent(const int tileX)
{
	return AIBT_SpawnTentTeam(tileX, 0);
}

CBlob@ AIBT_SpawnHall(const int tileX)
{
	// Hall has an even 10x6-tile shape, so its aligned center sits on whole
	// tile coordinates with the bottom edge on the fixture ground row.
	CBlob@ hall = AIBT_Spawn("hall", 0, Vec2f(tileX * 8, (AIBT_GROUND_Y - 3) * 8));
	AIBT_SetBlob("aibt_tent", hall);
	return hall;
}

CBlob@ AIBT_SpawnBotTeam(const int tileX, const u8 team)
{
	CBlob@ bot = AIBT_Spawn("aibuilder", team, AIBT_Pos(tileX, AIBT_GROUND_Y - 2));
	AIBT_SetBlob("aibt_bot", bot);
	return bot;
}

CBlob@ AIBT_SpawnBot(const int tileX)
{
	return AIBT_SpawnBotTeam(tileX, 0);
}

CBlob@ AIBT_SpawnTree(const int tileX, const bool selected = false)
{
	// Base map loaders root trees in the empty tile directly above solid ground.
	CBlob@ tree = AIBT_SpawnMatureTree(AIBT_Pos(tileX, AIBT_GROUND_Y - 1));
	if (tree !is null && selected)
	{
		tree.set_bool("aibuilder selected tree", true);
		tree.Sync("aibuilder selected tree", true);
		tree.Tag("aibuilder selected tree");
		AIB_LogEvent("test", "select_tree", AIBT_BlobRef(tree), "selected=true pos=" + AIB_EventPos(tree.getPosition()));
	}
	return tree;
}

CBlob@ AIBT_SpawnTreeAt(const int tileX, const int tileY, const bool selected = false)
{
	CBlob@ tree = AIBT_SpawnMatureTree(AIBT_Pos(tileX, tileY));
	if (tree !is null && selected)
	{
		tree.set_bool("aibuilder selected tree", true);
		tree.Sync("aibuilder selected tree", true);
		tree.Tag("aibuilder selected tree");
		AIB_LogEvent("test", "select_tree", AIBT_BlobRef(tree), "selected=true pos=" + AIB_EventPos(tree.getPosition()));
	}
	return tree;
}

CBlob@ AIBT_SpawnMatureTree(Vec2f pos)
{
	CBlob@ tree = server_CreateBlobNoInit("tree_pine");
	if (tree is null) return null;

	// Match Base map loaders: startbig must exist before Init so TreeSync builds
	// the mature segments.  Setting grown_times after Init only creates a
	// seedling that happens to pass the AI's maturity filter.
	tree.Tag("startbig");
	tree.Tag("aibt test fixture");
	tree.setPosition(pos);
	tree.Init();
	AIBT_spawned_ids.push_back(tree.getNetworkID());
	AIB_LogEvent("test", "spawn", AIBT_BlobRef(tree), "mature=true pos=" + AIB_EventPos(pos));
	return tree;
}

void AIBT_PrepareGloryhillLeftTreeArena()
{
	// Kept for old call sites; the hill fixture is encoded in aib_suite.png.
}

CBlob@ AIBT_SpawnWood(const int tileX, const u16 quantity = 100)
{
	CBlob@ wood = AIBT_Spawn("mat_wood", 0, AIBT_Pos(tileX, AIBT_GROUND_Y - 3));
	if (wood !is null)
	{
		wood.server_SetQuantity(quantity);
	}
	return wood;
}

void AIBT_StartHarvest(CBlob@ bot)
{
	if (bot is null) return;
	bot.set_u8("ai builder state", AIBT_FIND_TREE);
	bot.set_u8("ai builder job", AIBT_JOB_WOOD);
	bot.set_netid("ai builder target", 0);
	bot.set_Vec2f("ai builder destination", Vec2f_zero);
	AIB_LogEvent("test", "start_harvest", AIBT_BlobRef(bot), "state=find_tree pos=" + AIB_EventPos(bot.getPosition()));
}

void AIBT_StartStone(CBlob@ bot)
{
	if (bot is null) return;
	bot.set_u8("ai builder state", AIBT_FIND_STONE);
	bot.set_u8("ai builder job", AIBT_JOB_STONE);
	bot.set_netid("ai builder target", 0);
	bot.set_Vec2f("ai builder destination", Vec2f_zero);
	bot.set_Vec2f("ai builder tile target", Vec2f_zero);
	AIB_LogEvent("test", "start_stone", AIBT_BlobRef(bot), "state=find_stone pos=" + AIB_EventPos(bot.getPosition()));
}

void AIBT_ForceState(CBlob@ bot, const u8 state)
{
	if (bot is null) return;
	bot.set_u8("ai builder state", state);
	bot.set_netid("ai builder target", 0);
	bot.set_Vec2f("ai builder destination", Vec2f_zero);
	AIB_LogEvent("test", "force_state", AIBT_BlobRef(bot), "state=" + AIBT_StateName(state) + " pos=" + AIB_EventPos(bot.getPosition()));
}

void AIBT_ForceResourceBarrierAroundMap()
{
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null) return;

	rules.set_bool("aib test resource barrier", true);
	rules.set_u16("barrier_x1", 0);
	rules.set_u16("barrier_x2", map.tilemapwidth * map.tilesize);
	AIB_LogEvent("test", "force_barrier", "runner", "mode=whole_map_strip");
}

void AIBT_GiveWood(CBlob@ bot, const u16 quantity = 100)
{
	AIBT_GiveMaterial(bot, "mat_wood", quantity);
}

void AIBT_GiveMaterial(CBlob@ bot, const string &in name, const u16 quantity = 100)
{
	if (bot is null) return;
	u16 remaining = quantity;
	while (remaining > 0)
	{
		const u16 stack = Maths::Min(remaining, u16(250));
		CBlob@ material = server_CreateBlob(name, bot.getTeamNum(), bot.getPosition());
		if (material is null) break;
		material.Tag("aibt test fixture");
		AIBT_spawned_ids.push_back(material.getNetworkID());
		material.server_SetQuantity(stack);
		bot.server_PutInInventory(material);
		remaining -= stack;
	}
	AIB_LogEvent("test", "give_inventory", AIBT_BlobRef(bot), "item=" + name + " quantity=" + (quantity - remaining));
}

void AIBT_DisableStarterMaterials(CBlob@ bot)
{
	if (bot is null) return;
	bot.set_bool("ai builder starter materials granted", true);
}

CBlob@ AIBT_SpawnMaterial(const string &in name, const int tileX, const u16 quantity = 100)
{
	CBlob@ material = AIBT_Spawn(name, 0, AIBT_Pos(tileX, AIBT_GROUND_Y - 3));
	if (material !is null)
	{
		material.server_SetQuantity(quantity);
	}
	return material;
}

void AIBT_StartBlueprint(CBlob@ bot, const bool viaCommand = false)
{
	if (bot is null) return;
	if (viaCommand)
	{
		CBitStream params;
		bot.SendCommand(bot.getCommandID("ai build blueprint"), params);
	}
	else
	{
		bot.set_u8("ai builder state", AIBT_COLLECT_BLUEPRINT_RESOURCES);
		bot.set_u8("ai builder job", AIBT_JOB_BLUEPRINT);
		bot.set_netid("ai builder target", 0);
		bot.set_Vec2f("ai builder destination", Vec2f_zero);
		bot.set_Vec2f("ai builder tile target", Vec2f_zero);
	}
	AIB_LogEvent("test", "start_blueprint", AIBT_BlobRef(bot), "state=" + AIBT_StateName(bot.get_u8("ai builder state")) + " pos=" + AIB_EventPos(bot.getPosition()));
}

void AIBT_SetSingleBlueprintTile(const int tileX, const int tileY, const u16 block)
{
	AIBT_SetSingleBlueprintTileForTeam(0, tileX, tileY, block, true);
}

void AIBT_SetSingleBlueprintTileForTeam(const u8 team, const int tileX, const int tileY, const u16 block, const bool legacyMirror = false)
{
	CMap@ map = getMap();
	CRules@ rules = getRules();
	if (map is null || rules is null) return;

	array<u16> blueprint;
	blueprint.set_length(map.tilemapwidth * map.tilemapheight);
	for (uint i = 0; i < blueprint.length; i++)
	{
		blueprint[i] = 0;
	}

	const uint index = tileY * map.tilemapwidth + tileX;
	if (index < blueprint.length)
	{
		blueprint[index] = block;
	}

	rules.set("aibuilder blueprint data team " + int(team), blueprint);
	rules.set_u16("aibuilder blueprint width team " + int(team), map.tilemapwidth);
	rules.set_u16("aibuilder blueprint height team " + int(team), map.tilemapheight);
	if(legacyMirror)
	{
		rules.set("aibuilder blueprint data", blueprint);
		rules.set_u16("aibuilder blueprint width", map.tilemapwidth);
		rules.set_u16("aibuilder blueprint height", map.tilemapheight);
	}
	AIB_LogEvent("test", "set_blueprint", "runner", "team=" + team + " tile=" + tileX + "," + tileY + " block=" + block);
}

bool AIBT_BlueprintTileBuilt(const int tileX, const int tileY, const TileType expected)
{
	CMap@ map = getMap();
	if (map is null) return false;
	return map.getTile(Vec2f(tileX * 8 + 4, tileY * 8 + 4)).type == expected;
}

bool AIBT_MapFixtureIntact(string &out failure)
{
	CMap@ map = getMap();
	if (map is null)
	{
		failure = "map_missing";
		return false;
	}

	if (!map.isTileSolid(map.getTile(AIBT_Pos(20, AIBT_GROUND_Y)).type))
	{
		failure = "map_floor_missing pos=20," + AIBT_GROUND_Y;
		return false;
	}
	if (!map.isTileSolid(map.getTile(AIBT_Pos(260, AIBT_GROUND_Y - 4)).type))
	{
		failure = "map_wall_fixture_missing pos=260," + (AIBT_GROUND_Y - 4);
		return false;
	}
	return true;
}

void AIBT_ClearScenarioRefs()
{
	CRules@ rules = getRules();
	if (rules is null) return;
	rules.set_netid("aibt_tent", 0);
	rules.set_netid("aibt_bot", 0);
	rules.set_netid("aibt_expected", 0);
	rules.set_netid("aibt_delayed_bot", 0);
	rules.set_netid("aibt_enemy", 0);
	rules.set_u8("aibt_ui_stage", 0);
	rules.set_u8("aibt_pipeline_stage", 0);
	rules.set_u8("aibt director stage", 0);
	rules.set_u32("aibt director setup tick", 0);
	rules.set_bool("aibt director plan valid", false);
	rules.set_bool("aibt director defaults valid", false);
	rules.set_bool("aibt scenario32 suggest ghost", false);
	rules.set_bool("aibt gold discovery observed", false);
	rules.set_bool("aibt gold return observed", false);
	rules.set_u32("aibt gold cluster depleted tick", 0);
	rules.set_u32("aibt gold return tick", 0);
	rules.set_bool("aibt stone route static passed", false);
	rules.set_string("aibt stone route static details", "");
	rules.set_string("aibt stone route static failure", "");
	rules.set_bool("aibt left corner escape observed", false);
	rules.set_bool("aibt right corner escape observed", false);
	rules.set_bool("aibt left corner moved observed", false);
	rules.set_bool("aibt right corner moved observed", false);
	rules.set_bool("aibt left corner cycle complete", false);
	rules.set_bool("aibt right corner cycle complete", false);
	rules.set_bool("aibt workshop observed", false);
	rules.set_u8("aibt bootstrap stage", 0);
	rules.set_netid("aibt bootstrap dead id", 0);
	rules.set_u32("aibt bootstrap death tick", 0);
	rules.set_bool("aibt bootstrap reservation made", false);
	rules.set_u16("aibt bootstrap plan id", 0);
	rules.set_u16("aibt bootstrap task x", 0);
	rules.set_u16("aibt bootstrap task y", 0);
	rules.set_bool("aibt bootstrap task captured", false);
	rules.set_bool("aibt director task claim observed", false);
	rules.set_bool("aibt exposed stone targeted", false);
	rules.set_bool("aibt exposed stone mined", false);
	rules.set_bool("aibt exposed stone acquired", false);
	rules.set_bool("aibt selected tree targeted", false);
	rules.set_bool("aibt selected tree felled", false);
	rules.set_bool("aibt selected tree wood acquired", false);
	rules.set_string("aibt harvest scene signature", "");
	rules.set_u32("aibt harvest last progress tick", 0);
	rules.set_bool("aibt blueprint crate wood withdrawn", false);
	rules.set_bool("aibt blueprint crate stone withdrawn", false);
	rules.set_string("aibt blueprint scene signature", "");
	rules.set_string("aibt support scene signature", "");
	rules.set_f32("aibt left corner start x", 0.0f);
	rules.set_f32("aibt right corner start x", 0.0f);
	rules.set_bool("aibt fallback setup", false);
	rules.set_bool("aibt fallback route safe", false);
	rules.set_bool("aibt fallback primary rejected", false);
	rules.set_bool("aibt fallback progress observed", false);
	rules.set_u8("aibt fallback obstacle kind", 0);
	rules.set_u16("aibt fallback plan id", 0);
	rules.set_u16("aibt fallback plan version", 0);
	rules.set_u16("aibt fallback tasks", 0);
	rules.set_u16("aibt fallback initial completed", 0);
	rules.set_u16("aibt fallback primary anchor x", 0);
	rules.set_u16("aibt fallback selected anchor x", 0);
	rules.set_u16("aibt fallback obstacle x", 0);
	rules.set_u16("aibt fallback obstacle y", 0);
	rules.set_u16("aibt fallback obstacle tile", 0);
	rules.set_netid("aibt fallback blocker", 0);
	rules.set_string("aibt fallback primary reason", "");
	rules.set_string("aibt fallback template", "");
	rules.set_string("aibt fallback reasons", "");
	rules.set_string("aibt fallback setup failure", "");
	rules.set_bool("aibt bootstrap lifecycle setup", false);
	rules.set_bool("aibt bootstrap lifecycle plans", false);
	for (u8 lifecycleTeam = 0; lifecycleTeam < 2; lifecycleTeam++)
	{
		const string prefix = "aibt bootstrap lifecycle team " + lifecycleTeam + " ";
		rules.set_bool(prefix + "passed", false);
		rules.set_netid(prefix + "worker", 0);
		rules.set_string(prefix + "details", "");
	}
	array<u16> empty;
	array<Vec2f> emptyVec;
	rules.set("aibuilder selected stone tiles", emptyVec);
	rules.set("aibuilder blueprint data", empty);
	rules.set_u16("aibuilder blueprint width", 0);
	rules.set_u16("aibuilder blueprint height", 0);
	rules.set("aibuilder blueprint data team 0", empty);
	rules.set_u16("aibuilder blueprint width team 0", 0);
	rules.set_u16("aibuilder blueprint height team 0", 0);
	rules.set("aibuilder blueprint data team 1", empty);
	rules.set_u16("aibuilder blueprint width team 1", 0);
	rules.set_u16("aibuilder blueprint height team 1", 0);
	for (u8 team = 0; team < 8; team++)
	{
		array<u16> empty16;
		array<u8> empty8;
		array<u32> empty32;
		rules.set(AIBP_LayerDataKey(team, AIBP_Layer::human), empty16);
		rules.set(AIBP_LayerDataKey(team, AIBP_Layer::ai_work), empty16);
		rules.set(AIBP_LayerDataKey(team, AIBP_Layer::ai_desired), empty16);
		rules.set(AIBP_TaskKey(team, "x"), empty16);
		rules.set(AIBP_TaskKey(team, "y"), empty16);
		rules.set(AIBP_TaskKey(team, "block"), empty16);
		rules.set(AIBP_TaskKey(team, "reserved"), empty16);
		rules.set(AIBP_TaskKey(team, "phase"), empty8);
		rules.set(AIBP_TaskKey(team, "state"), empty8);
		rules.set(AIBP_TaskKey(team, "until"), empty32);
		rules.set_u16(AIBP_PlanKey(team, "id"), 0);
		rules.set_u16(AIBP_PlanKey(team, "version"), 0);
		rules.set_u16(AIBP_PlanKey(team, "human version"), 0);
		rules.set_u8(AIBP_PlanKey(team, "status"), 0);
		rules.set_u8(AIBP_ModeKey(team), AIBP_StrategyMode::off);
		rules.set_u8("aib strategy last mode team " + int(team), AIBP_StrategyMode::off);
		rules.set_u32("aib strategy last replan team " + int(team), 0);
		rules.set_u32("aib strategy important event team " + int(team), 0);
		rules.set_bool(AIBS_BootstrapKey(team, "enabled"), false);
		rules.set_bool(AIBS_BootstrapKey(team, "provisioned"), false);
		rules.set_u32(AIBS_BootstrapKey(team, "next retry"), 0);
		array<u16> emptyHistory;
		rules.set("aib strategy history ids team " + int(team), emptyHistory);
	}
	rules.set_bool("aibt strategic result", false);
	rules.set_string("aibt strategic failure", "");
	rules.set_string("aibt strategic details", "");
}

BlueprintPlan@ AIBT_NewStrategicPlan(const u8 team, const string &in templateName)
{
	BlueprintPlan@ plan = BlueprintPlan();
	plan.id = getRules().get_u16("aib strategy next plan id") + 1;
	getRules().set_u16("aib strategy next plan id", plan.id);
	plan.version = getRules().get_u16(AIBP_PlanKey(team, "version")) + 1;
	plan.team = team;
	plan.owner = 255;
	plan.intent = AIBStrategyIntent::flag_gatehouse;
	plan.status = 1;
	plan.templateName = templateName;
	plan.anchor = Vec2f(388, AIBT_GROUND_Y);
	plan.score = 100.0f;
	plan.reasons = "test fixture";
	plan.createdAt = getGameTime();
	plan.updatedAt = getGameTime();
	return plan;
}

void AIBT_SetStrategicResult(const bool passed, const string &in details, const string &in failure = "")
{
	getRules().set_bool("aibt strategic result", passed);
	getRules().set_string("aibt strategic details", details);
	getRules().set_string("aibt strategic failure", failure);
}

void AIBT_CountStrategyAssignments(const u8 team, u16 &out assigned, u16 &out wood, u16 &out stone, u16 &out build)
{
	assigned = 0;
	wood = 0;
	stone = 0;
	build = 0;
	string[] names = { "aibuilder", "autobuilder" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] builders;
		getBlobsByName(names[n], @builders);
		for (uint i = 0; i < builders.length; i++)
		{
			CBlob@ builder = builders[i];
			if (builder is null || builder.hasTag("dead") || builder.getTeamNum() != team || !builder.get_bool("aib strategy assigned")) continue;
			assigned++;
			const u8 job = builder.get_u8("ai builder job");
			if (job == AIBS_JOB_WOOD) wood++;
			else if (job == AIBS_JOB_STONE) stone++;
			else if (job == AIBS_JOB_BLUEPRINT) build++;
		}
	}
}

u16 AIBT_CountLayerTiles(const u8 team, const u8 layer)
{
	array<u16>@ grid = null;
	if (!AIBP_GetLayerGrid(team, layer, @grid) || grid is null) return 0;
	u16 count = 0;
	for (uint i = 0; i < grid.length; i++) if (grid[i] != 0) count++;
	return count;
}

bool AIBT_LayerIsEmpty(const u8 team, const u8 layer)
{
	return AIBT_CountLayerTiles(team, layer) == 0;
}

bool AIBT_AllPlanTasksPhysicallyComplete(const u8 team, u16 &out taskCount, u16 &out stateCompleted,
	u16 &out reservedCount, string &out mismatch)
{
	taskCount = 0;
	stateCompleted = 0;
	reservedCount = 0;
	mismatch = "";
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils) ||
		xs is null || ys is null || blocks is null || states is null || reserved is null || untils is null)
	{
		mismatch = "task_arrays_missing";
		return false;
	}
	if (xs.length != ys.length || xs.length != blocks.length || xs.length != states.length ||
		xs.length != reserved.length || xs.length != untils.length)
	{
		mismatch = "task_array_length_mismatch x=" + xs.length + " y=" + ys.length + " block=" + blocks.length +
			" state=" + states.length + " reserved=" + reserved.length + " until=" + untils.length;
		return false;
	}
	taskCount = u16(xs.length);
	for (uint i = 0; i < xs.length; i++)
	{
		if (states[i] == AIBP_TaskState::completed) stateCompleted++;
		if (reserved[i] != 0 || untils[i] != 0) reservedCount++;
		if (AIBP_MapMatchesBlock(xs[i], ys[i], blocks[i], team)) continue;
		if (mismatch == "") mismatch = "physical_mismatch index=" + i + " tile=" + xs[i] + "," + ys[i] + " block=" + blocks[i];
	}
	return taskCount > 0 && stateCompleted == taskCount && reservedCount == 0 && mismatch == "";
}

bool AIBT_RepresentativeDirectorCandidate(const u8 team, const s8 expectedDirection, const bool requireTerrainVariance,
	string &out failure, string &out details)
{
	CMap@ map = getMap();
	AIBWorldState@ world = AIBS_ObserveWorld(team);
	if (map is null || world is null || world.home == Vec2f_zero || world.enemyHome == Vec2f_zero)
	{
		failure = "representative_world_missing team=" + team;
		return false;
	}
	if (world.enemyDirection != expectedDirection)
	{
		failure = "representative_wrong_direction team=" + team + " expected=" + expectedDirection + " actual=" + world.enemyDirection;
		return false;
	}
	AIBPlanCandidate@ candidate = AIBS_SelectCandidate(world);
	if (candidate is null)
	{
		failure = "representative_no_candidate team=" + team;
		return false;
	}
	if (!AIBS_ValidateCandidate(world, candidate) || candidate.tasks.length == 0)
	{
		failure = "representative_invalid_candidate team=" + team + " template=" + candidate.templateName + " rejection=" + candidate.rejection;
		return false;
	}
	const int homeX = int(world.home.x / map.tilesize);
	const int anchorX = int(candidate.anchor.x);
	if ((anchorX - homeX) * expectedDirection <= 0)
	{
		failure = "representative_not_inward team=" + team + " home_x=" + homeX + " anchor_x=" + anchorX;
		return false;
	}
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null || task.x >= map.tilemapwidth || task.y == 0 || task.y >= map.tilemapheight)
		{
			failure = "representative_task_out_of_bounds team=" + team + " index=" + i;
			return false;
		}
	}
	const int minX = Maths::Max(0, Maths::Min(homeX, anchorX) - 8);
	const int maxX = Maths::Min(int(map.tilemapwidth) - 1, Maths::Max(homeX, anchorX) + 8);
	u16 minSurface = 65535; u16 maxSurface = 0;
	for (int x = minX; x <= maxX; x++)
	{
		const u16 surface = AIBS_SurfaceAt(x);
		minSurface = Maths::Min(minSurface, surface);
		maxSurface = Maths::Max(maxSurface, surface);
	}
	const u16 terrainVariance = maxSurface - minSurface;
	if (requireTerrainVariance && terrainVariance < 2)
	{
		failure = "representative_fixture_not_uneven team=" + team + " variance=" + terrainVariance;
		return false;
	}
	details = "team=" + team + " direction=" + expectedDirection + " template=" + candidate.templateName +
		" anchor=" + anchorX + "," + int(candidate.anchor.y) + " tasks=" + candidate.tasks.length +
		" score=" + candidate.score + " terrain_variance=" + terrainVariance + " reasons=" + candidate.reasons;
	return true;
}

AIBPlanCandidate@ AIBT_FindGeneratedCandidate(array<AIBPlanCandidate@> &in candidates, const string &in templateName, const int anchorX)
{
	for (uint i = 0; i < candidates.length; i++)
	{
		AIBPlanCandidate@ candidate = candidates[i];
		if (candidate !is null && candidate.templateName == templateName && int(candidate.anchor.x) == anchorX) return candidate;
	}
	return null;
}

BlueprintTask@ AIBT_FirstNonLadderTask(AIBPlanCandidate@ candidate)
{
	if (candidate is null) return null;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task !is null && AIBP_BlockId(task.block) != AIBP_LADDER) return task;
	}
	return null;
}

void AIBT_SetupRepresentativeFallback(const u8 obstacleKind)
{
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null) return;
	CBlob@ home = AIBT_SpawnTentTeam(54, 0);
	AIBT_SpawnTentTeam(366, 1);
	CBlob@ executor = AIBT_Spawn("autobuilder", 0, AIBT_Pos(58, AIBT_GROUND_Y - 3));
	if (obstacleKind == AIBT_FALLBACK_BARRIER)
	{
		// Force the production emergency intent so a useful compact fallback
		// exists entirely on the home side of the pre-match barrier.
		for (uint i = 0; i < 6; i++) AIBT_Spawn("knight", 1, AIBT_Pos(118 + int(i * 2), AIBT_GROUND_Y - 2));
	}
	AIBT_SetBlob("aibt_bot", executor);
	rules.set_u8("aibt fallback obstacle kind", obstacleKind);

	AIBWorldState@ initialWorld = AIBS_ObserveWorld(0);
	array<AIBPlanCandidate@> initialCandidates;
	AIBS_GenerateCandidates(initialWorld, initialCandidates);
	const int primaryAnchorX = initialWorld is null ? 0 : int(initialWorld.home.x / map.tilesize) + initialWorld.enemyDirection * 10;
	AIBPlanCandidate@ initialPrimary = AIBT_FindGeneratedCandidate(initialCandidates, "flag_gatehouse", primaryAnchorX);
	const bool initialPrimaryValid = initialPrimary !is null && AIBS_ValidateCandidate(initialWorld, initialPrimary);
	BlueprintTask@ obstacleTask = AIBT_FirstNonLadderTask(initialPrimary);
	bool obstacleReady = home !is null && executor !is null && initialWorld !is null && initialPrimaryValid &&
		(obstacleKind == AIBT_FALLBACK_BARRIER || obstacleTask !is null);
	if (obstacleKind == AIBT_FALLBACK_BARRIER && initialWorld !is null)
	{
		// The primary gatehouse spans anchor +/-3. Put the barrier two tiles
		// behind its anchor: the primary crosses it, while the emergency plan
		// at home +6 remains wholly connected to the home side.
		const int barrierX = primaryAnchorX - initialWorld.enemyDirection * 2;
		const u16 barrierY = AIBT_GROUND_Y - 5;
		const u16 barrierWorldX = u16(barrierX * map.tilesize + map.tilesize * 0.5f);
		rules.set_u16("aibt fallback obstacle x", u16(barrierX));
		rules.set_u16("aibt fallback obstacle y", barrierY);
		rules.set_u16("aibt fallback obstacle tile", map.getTile(AIBT_Pos(barrierX, barrierY)).type);
		rules.set_bool("aib test resource barrier", true);
		rules.set_u16("barrier_x1", barrierWorldX);
		rules.set_u16("barrier_x2", barrierWorldX);
		obstacleReady = obstacleReady && barrierX > int(initialWorld.home.x / map.tilesize);
	}
	else if (obstacleTask !is null)
	{
		rules.set_u16("aibt fallback obstacle x", obstacleTask.x);
		rules.set_u16("aibt fallback obstacle y", obstacleTask.y);
		rules.set_u16("aibt fallback obstacle tile", map.getTile(AIBT_Pos(obstacleTask.x, obstacleTask.y)).type);
		if (obstacleKind == AIBT_FALLBACK_NO_BUILD)
		{
			obstacleReady = obstacleReady && AIBT_AddTemporaryNoBuildTile(obstacleTask.x, obstacleTask.y, home.getNetworkID());
		}
		else if (obstacleKind == AIBT_FALLBACK_OCCUPIED)
		{
			CBlob@ blocker = AIBT_Spawn("crate", 0, AIBT_Pos(obstacleTask.x, obstacleTask.y));
			if (blocker !is null && blocker.getShape() !is null) blocker.getShape().SetStatic(true);
			rules.set_netid("aibt fallback blocker", blocker is null ? 0 : blocker.getNetworkID());
			obstacleReady = obstacleReady && blocker !is null;
		}
		else obstacleReady = false;
	}

	AIBWorldState@ world = AIBS_ObserveWorld(0);
	array<AIBPlanCandidate@> generated;
	AIBS_GenerateCandidates(world, generated);
	AIBPlanCandidate@ primary = AIBT_FindGeneratedCandidate(generated, "flag_gatehouse", primaryAnchorX);
	const bool primaryRejected = primary !is null && !AIBS_ValidateCandidate(world, primary);
	const string primaryReason = primary is null ? "missing" : primary.rejection;
	const string expectedReason = obstacleKind == AIBT_FALLBACK_NO_BUILD ? "no_build" :
		(obstacleKind == AIBT_FALLBACK_OCCUPIED ? "building_overlap" : "barrier");
	AIBPlanCandidate@ selected = AIBS_SelectCandidate(world);
	const bool selectedValid = selected !is null && AIBS_ValidateCandidate(world, selected);
	const bool selectedDistinct = selected !is null && primary !is null &&
		(selected.templateName != primary.templateName || int(selected.anchor.x) != int(primary.anchor.x));
	const bool routeSafe = selectedValid && AIBS_PreservesFriendlyRoute(selected);
	BlueprintPlan@ plan = selectedValid && selectedDistinct ? AIBS_MakePlan(world, selected) : null;
	const bool published = obstacleReady && primaryRejected && primaryReason == expectedReason && routeSafe && plan !is null &&
		AIBP_PublishAIPlan(plan, true);
	u16 initialCompleted = 0;
	if (plan !is null)
	{
		for (uint i = 0; i < plan.tasks.length; i++)
		{
			BlueprintTask@ task = plan.tasks[i];
			if (task !is null && task.state == AIBP_TaskState::completed) initialCompleted++;
		}
	}
	rules.set_bool("aibt fallback setup", published);
	rules.set_bool("aibt fallback route safe", routeSafe);
	rules.set_bool("aibt fallback primary rejected", primaryRejected);
	rules.set_bool("aibt fallback progress observed", false);
	rules.set_u16("aibt fallback plan id", plan is null ? 0 : plan.id);
	rules.set_u16("aibt fallback plan version", plan is null ? 0 : plan.version);
	rules.set_u16("aibt fallback tasks", plan is null ? 0 : u16(plan.tasks.length));
	rules.set_u16("aibt fallback initial completed", initialCompleted);
	rules.set_u16("aibt fallback primary anchor x", u16(Maths::Max(0, primaryAnchorX)));
	rules.set_u16("aibt fallback selected anchor x", selected is null ? 0 : u16(Maths::Max(0, int(selected.anchor.x))));
	rules.set_string("aibt fallback primary reason", primaryReason);
	rules.set_string("aibt fallback template", selected is null ? "none" : selected.templateName);
	rules.set_string("aibt fallback reasons", selected is null ? "none" : selected.reasons);
	rules.set_string("aibt fallback setup failure", "initial_primary_valid=" + (initialPrimaryValid ? "true" : "false") +
		" obstacle_ready=" + (obstacleReady ? "true" : "false") +
		" primary=" + (primary is null ? "missing" : primary.templateName) + " rejected=" + (primaryRejected ? "true" : "false") +
		" reason=" + primaryReason + " expected=" + expectedReason + " selected=" + (selected is null ? "none" : selected.templateName) +
		" selected_valid=" + (selectedValid ? "true" : "false") + " distinct=" + (selectedDistinct ? "true" : "false") +
		" route_safe=" + (routeSafe ? "true" : "false") + " published=" + (published ? "true" : "false"));
	if (published)
	{
		AIBWorldState@ assignedWorld = AIBS_ObserveWorld(0);
		AIBS_AssignBuilders(assignedWorld);
	}
}

bool AIBT_FallbackPlanRespectsObstacle(const u8 obstacleKind, string &out obstacleDetails)
{
	CRules@ rules = getRules();
	CMap@ map = getMap();
	obstacleDetails = "";
	if (rules is null || map is null) return false;
	const u16 obstacleX = rules.get_u16("aibt fallback obstacle x");
	const u16 obstacleY = rules.get_u16("aibt fallback obstacle y");
	Vec2f obstacleCenter = AIBT_Pos(obstacleX, obstacleY);
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(0, @xs, @ys, @blocks, @phases, @states, @reserved, @untils) ||
		xs is null || ys is null || blocks is null || xs.length != ys.length || xs.length != blocks.length) return false;
	if (obstacleKind == AIBT_FALLBACK_NO_BUILD)
	{
		const bool sectorPresent = map.getSectorAtPosition(obstacleCenter, "no build") !is null;
		const bool tilePreserved = map.getTile(obstacleCenter).type == rules.get_u16("aibt fallback obstacle tile");
		bool legalTasks = true;
		for (uint i = 0; i < xs.length; i++)
		{
			Vec2f center = AIBT_Pos(xs[i], ys[i]);
			if (AIBP_BlockId(blocks[i]) != AIBP_LADDER && map.getSectorAtPosition(center, "no build") !is null)
			{
				legalTasks = false;
				break;
			}
		}
		obstacleDetails = "sector_present=" + (sectorPresent ? "true" : "false") +
			" tile_preserved=" + (tilePreserved ? "true" : "false") + " legal_tasks=" + (legalTasks ? "true" : "false");
		return sectorPresent && tilePreserved && legalTasks;
	}
	if (obstacleKind == AIBT_FALLBACK_OCCUPIED)
	{
		CBlob@ blocker = getBlobByNetworkID(rules.get_netid("aibt fallback blocker"));
		const bool blockerPreserved = blocker !is null && !blocker.hasTag("dead") &&
			(blocker.getPosition() - obstacleCenter).LengthSquared() < 4.0f;
		bool legalTasks = true;
		for (uint i = 0; i < xs.length; i++)
		{
			if (AIBS_OverlapsProtectedBlob(0, AIBT_Pos(xs[i], ys[i])))
			{
				legalTasks = false;
				break;
			}
		}
		obstacleDetails = "blocker_preserved=" + (blockerPreserved ? "true" : "false") +
			" legal_tasks=" + (legalTasks ? "true" : "false");
		return blockerPreserved && legalTasks;
	}
	if (obstacleKind == AIBT_FALLBACK_BARRIER)
	{
		AIBWorldState@ world = AIBS_ObserveWorld(0);
		const u16 barrierWorldX = u16(obstacleX * map.tilesize + map.tilesize * 0.5f);
		const bool barrierActive = rules.get_bool("aib test resource barrier") &&
			rules.get_u16("barrier_x1") == barrierWorldX && rules.get_u16("barrier_x2") == barrierWorldX;
		const bool tilePreserved = map.getTile(obstacleCenter).type == rules.get_u16("aibt fallback obstacle tile");
		bool legalTasks = world !is null;
		for (uint i = 0; legalTasks && i < xs.length; i++)
		{
			if (!AIBS_InsideBarrierSide(world, AIBT_Pos(xs[i], ys[i]))) legalTasks = false;
		}
		obstacleDetails = "barrier_active=" + (barrierActive ? "true" : "false") +
			" tile_preserved=" + (tilePreserved ? "true" : "false") + " legal_tasks=" + (legalTasks ? "true" : "false");
		return barrierActive && tilePreserved && legalTasks;
	}
	return false;
}

bool AIBT_EvaluateRepresentativeFallback(const u32 elapsed, string &out failure, string &out details)
{
	CRules@ rules = getRules();
	CBlob@ executor = AIBT_GetBlob("aibt_bot");
	if (rules is null || !rules.get_bool("aibt fallback setup"))
	{
		failure = "representative_fallback_setup_failed " + (rules is null ? "rules_missing" : rules.get_string("aibt fallback setup failure"));
		return true;
	}
	AIBP_RefreshPlanState(0, true);
	const u16 expectedTasks = rules.get_u16("aibt fallback tasks");
	const u16 initialCompleted = rules.get_u16("aibt fallback initial completed");
	const u16 countedCompleted = rules.get_u16(AIBP_PlanKey(0, "completed"));
	if (countedCompleted > initialCompleted) rules.set_bool("aibt fallback progress observed", true);
	u16 taskCount = 0; u16 stateCompleted = 0; u16 reservedCount = 0; string mismatch;
	const bool physical = AIBT_AllPlanTasksPhysicallyComplete(0, taskCount, stateCompleted, reservedCount, mismatch);
	const bool identityStable = rules.get_u16(AIBP_PlanKey(0, "id")) == rules.get_u16("aibt fallback plan id") &&
		rules.get_u16(AIBP_PlanKey(0, "version")) == rules.get_u16("aibt fallback plan version");
	const bool countersComplete = rules.get_u16(AIBP_PlanKey(0, "pending")) == 0 && countedCompleted == expectedTasks &&
		rules.get_u8(AIBP_PlanKey(0, "status")) == 2;
	const bool layersComplete = AIBT_CountLayerTiles(0, AIBP_Layer::ai_desired) == expectedTasks &&
		AIBT_LayerIsEmpty(0, AIBP_Layer::ai_work);
	const bool assignedExecutor = executor !is null && executor.hasTag("autobuilder") && executor.get_bool("aib strategy assigned") &&
		executor.get_u8("ai builder job") == AIBS_JOB_BLUEPRINT;
	const string archivePrefix = "aib strategy history plan " + rules.get_u16("aibt fallback plan id") + " team 0 ";
	const bool archivedComplete = rules.get_string(archivePrefix + "archive reason") == "completed";
	const bool primaryFallback = rules.get_bool("aibt fallback primary rejected") &&
		(rules.get_string("aibt fallback template") != "flag_gatehouse" ||
		 rules.get_u16("aibt fallback selected anchor x") != rules.get_u16("aibt fallback primary anchor x"));
	const bool exercised = expectedTasks >= 6 && initialCompleted < expectedTasks && rules.get_bool("aibt fallback progress observed");
	string obstacleDetails;
	const bool obstacleSafe = AIBT_FallbackPlanRespectsObstacle(rules.get_u8("aibt fallback obstacle kind"), obstacleDetails);
	if (physical && identityStable && countersComplete && layersComplete && assignedExecutor && archivedComplete &&
		primaryFallback && exercised && obstacleSafe)
	{
		details = "representative_fallback_physically_complete=true obstacle=" + rules.get_u8("aibt fallback obstacle kind") +
			" primary_rejection=" + rules.get_string("aibt fallback primary reason") + " template=" + rules.get_string("aibt fallback template") +
			" primary_anchor=" + rules.get_u16("aibt fallback primary anchor x") + " selected_anchor=" + rules.get_u16("aibt fallback selected anchor x") +
			" tasks=" + expectedTasks + " reservations=0 work_layer_empty=true " + obstacleDetails;
		return true;
	}
	const u32 timeout = u32(expectedTasks) * 45 + 450;
	if (elapsed > timeout)
	{
		failure = "representative_fallback_timeout obstacle=" + rules.get_u8("aibt fallback obstacle kind") +
			" reason=" + rules.get_string("aibt fallback primary reason") + " template=" + rules.get_string("aibt fallback template") +
			" elapsed=" + elapsed + " timeout=" + timeout + " expected=" + expectedTasks + " tasks=" + taskCount +
			" states_completed=" + stateCompleted + " counted_completed=" + countedCompleted + " reserved=" + reservedCount +
			" identity=" + (identityStable ? "true" : "false") + " counters=" + (countersComplete ? "true" : "false") +
			" layers=" + (layersComplete ? "true" : "false") + " assigned=" + (assignedExecutor ? "true" : "false") +
			" archived=" + (archivedComplete ? "true" : "false") + " fallback=" + (primaryFallback ? "true" : "false") +
			" exercised=" + (exercised ? "true" : "false") + " obstacle_safe=" + (obstacleSafe ? "true" : "false") +
			" obstacle_details=" + obstacleDetails + " mismatch=" + mismatch + " reasons=" + rules.get_string("aibt fallback reasons") +
			" " + AIBT_DescribeBuilder(executor);
		return true;
	}
	return false;
}

bool AIBT_HasDirectorTaskClaim(const u8 team)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils))
	{
		for (uint i = 0; i < reserved.length && i < states.length; i++)
		{
			if (reserved[i] == 0 || states[i] != AIBP_TaskState::reserved) continue;
			CBlob@ owner = getBlobByNetworkID(reserved[i]);
			if (owner !is null && !owner.hasTag("dead") && owner.getTeamNum() == team && owner.get_bool("aib strategy assigned")) return true;
		}
	}

	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder is null || builder.hasTag("dead") || builder.getTeamNum() != team || !builder.get_bool("aib strategy assigned")) continue;
		if (builder.get_Vec2f("ai builder tile target") != Vec2f_zero || builder.get_netid("ai builder target") != 0) return true;
	}
	return false;
}

u16 AIBT_CountLiveTeamBuilders(const u8 team, const bool bootstrapOnly = false)
{
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	u16 count = 0;
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder is null || builder.hasTag("dead") || builder.getTeamNum() != team) continue;
		if (bootstrapOnly && !builder.hasTag("aib strategy bootstrap worker")) continue;
		count++;
	}
	return count;
}

CBlob@ AIBT_GetBootstrapWorker(const u8 team)
{
	CBlob@[] builders;
	getBlobsByTag("aib strategy bootstrap worker", @builders);
	CBlob@ best = null;
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder is null || builder.hasTag("dead") || builder.getTeamNum() != team) continue;
		if (best is null || builder.getNetworkID() < best.getNetworkID()) @best = builder;
	}
	return best;
}

bool AIBT_BootstrapWorkerHasSafeGround(CBlob@ builder)
{
	CMap@ map = getMap();
	if (builder is null || map is null) return false;
	Vec2f spawn = builder.get_Vec2f("aib strategy bootstrap spawn");
	if (spawn == Vec2f_zero) return false;
	Vec2f space = map.getTileSpacePosition(spawn);
	const int x = Maths::Floor(space.x);
	const int y = Maths::Floor(space.y);
	if (x < 1 || x >= map.tilemapwidth - 1 || y < 1 || y >= map.tilemapheight - 1) return false;
	const f32 ts = map.tilesize;
	Vec2f body = Vec2f((x + 0.5f) * ts, (y + 0.5f) * ts);
	for (int dx = -1; dx <= 1; dx++)
	{
		Vec2f sample = body + Vec2f(dx * ts, 0.0f);
		if (map.isTileSolid(map.getTile(sample).type) || map.isTileSolid(map.getTile(sample - Vec2f(0.0f, ts)).type)) return false;
	}
	if (!map.isTileSolid(map.getTile(body + Vec2f(0.0f, ts)).type)) return false;
	CBlob@ home = AIBS_TeamHomeBlob(u8(builder.getTeamNum()));
	if (home is null) return false;
	Vec2f builderMin, builderMax, homeMin, homeMax;
	builderMin = spawn - Vec2f(8.0f, 8.0f);
	builderMax = spawn + Vec2f(8.0f, 8.0f);
	home.getShape().getBoundingRect(homeMin, homeMax);
	return !(builderMin.x < homeMax.x && builderMax.x > homeMin.x &&
		builderMin.y < homeMax.y && builderMax.y > homeMin.y);
}

string AIBT_BootstrapLifecycleKey(const u8 team, const string &in field)
{
	return "aibt bootstrap lifecycle team " + team + " " + field;
}

u16 AIBT_SpawnBootstrapSiteBlockers(const u8 team, const int homeX)
{
	u16 count = 0;
	// A spawn envelope is three tiles wide. Blockers every two tiles cover
	// both odd and even candidates without overlapping each other.
	for (int distance = AIBS_BOOTSTRAP_MIN_HOME_DISTANCE; distance <= AIBS_BOOTSTRAP_MAX_HOME_DISTANCE; distance += 2)
	{
		for (int side = -1; side <= 1; side += 2)
		{
			CBlob@ blocker = AIBT_Spawn("crate", team, AIBT_Pos(homeX + side * distance, AIBT_GROUND_Y - 1));
			if (blocker is null) continue;
			blocker.Tag("aibt bootstrap site blocker");
			blocker.set_u8("aibt bootstrap blocker team", team);
			if (blocker.getShape() !is null) blocker.getShape().SetStatic(true);
			count++;
		}
	}
	return count;
}

u16 AIBT_KillBootstrapSiteBlockers(const u8 team)
{
	CBlob@[] blockers;
	getBlobsByTag("aibt bootstrap site blocker", @blockers);
	u16 killed = 0;
	for (uint i = 0; i < blockers.length; i++)
	{
		CBlob@ blocker = blockers[i];
		if (blocker is null || blocker.hasTag("dead") || blocker.get_u8("aibt bootstrap blocker team") != team) continue;
		blocker.Tag("dead");
		blocker.server_Die();
		killed++;
	}
	return killed;
}

bool AIBT_ExerciseBootstrapRoundReset(const u8 team, const int homeX)
{
	CRules@ rules = getRules();
	if (rules is null) return false;
	const u16 blockerCount = AIBT_SpawnBootstrapSiteBlockers(team, homeX);
	AIBWorldState@ blockedWorld = AIBS_ObserveWorld(team);
	Vec2f blockedSpawn = AIBS_FindBootstrapSpawn(blockedWorld);
	const u32 blockedTick = getGameTime();
	const bool blockedAttempt = !AIBS_TryBootstrapBuilder(rules, blockedWorld);
	const bool cooldownExact = rules.get_u32(AIBS_BootstrapKey(team, "next retry")) == blockedTick + AIBS_BOOTSTRAP_RETRY_TICKS;
	const bool noPrematureWorker = AIBT_CountLiveTeamBuilders(team) == 0 &&
		!rules.get_bool(AIBS_BootstrapKey(team, "provisioned"));

	const u16 killedBlockers = AIBT_KillBootstrapSiteBlockers(team);
	AIBWorldState@ openWorld = AIBS_ObserveWorld(team);
	Vec2f openSpawn = AIBS_FindBootstrapSpawn(openWorld);
	const bool cooldownHeld = !AIBS_TryBootstrapBuilder(rules, openWorld) && AIBT_CountLiveTeamBuilders(team) == 0 &&
		rules.get_u32(AIBS_BootstrapKey(team, "next retry")) > getGameTime();

	// Model the end of a round after a consumed provisioning entitlement. The
	// production reset must preserve the administrator policy but clear both
	// the one-time latch and any failed-search cooldown.
	rules.set_bool(AIBS_BootstrapKey(team, "provisioned"), true);
	const bool enabledBeforeReset = rules.get_bool(AIBS_BootstrapKey(team, "enabled"));
	AIBS_ResetBootstrapForRound(rules, team);
	const bool resetState = enabledBeforeReset && rules.get_bool(AIBS_BootstrapKey(team, "enabled")) &&
		!rules.get_bool(AIBS_BootstrapKey(team, "provisioned")) && rules.get_u32(AIBS_BootstrapKey(team, "next retry")) == 0;

	AIBWorldState@ resetWorld = AIBS_ObserveWorld(team);
	const bool provisionedAfterReset = AIBS_TryBootstrapBuilder(rules, resetWorld);
	CBlob@ worker = AIBT_GetBootstrapWorker(team);
	if (worker !is null)
	{
		AIBWorldState@ assignedWorld = AIBS_ObserveWorld(team);
		AIBS_AssignBuilders(assignedWorld);
	}
	const bool oneSafeAssignedWorker = worker !is null && AIBT_CountLiveTeamBuilders(team) == 1 &&
		AIBT_CountLiveTeamBuilders(team, true) == 1 && AIBT_BootstrapWorkerHasSafeGround(worker) &&
		worker.get_bool("aib strategy assigned");
	AIBWorldState@ latchedWorld = AIBS_ObserveWorld(team);
	const bool secondAttemptSuppressed = !AIBS_TryBootstrapBuilder(rules, latchedWorld) &&
		AIBT_CountLiveTeamBuilders(team) == 1 && rules.get_bool(AIBS_BootstrapKey(team, "provisioned"));

	const bool passed = blockerCount == 20 && killedBlockers == blockerCount && blockedSpawn == Vec2f_zero && blockedAttempt &&
		cooldownExact && noPrematureWorker && openSpawn != Vec2f_zero && cooldownHeld && resetState &&
		provisionedAfterReset && oneSafeAssignedWorker && secondAttemptSuppressed;
	rules.set_bool(AIBT_BootstrapLifecycleKey(team, "passed"), passed);
	rules.set_netid(AIBT_BootstrapLifecycleKey(team, "worker"), worker is null ? 0 : worker.getNetworkID());
	rules.set_string(AIBT_BootstrapLifecycleKey(team, "details"),
		"blockers=" + blockerCount + " killed=" + killedBlockers + " blocked_spawn_zero=" + (blockedSpawn == Vec2f_zero ? "true" : "false") +
		" blocked_attempt=" + (blockedAttempt ? "true" : "false") + " cooldown_exact=" + (cooldownExact ? "true" : "false") +
		" no_worker=" + (noPrematureWorker ? "true" : "false") + " open_spawn=" + (openSpawn != Vec2f_zero ? "true" : "false") +
		" cooldown_held=" + (cooldownHeld ? "true" : "false") + " reset=" + (resetState ? "true" : "false") +
		" provisioned=" + (provisionedAfterReset ? "true" : "false") + " safe_assigned=" + (oneSafeAssignedWorker ? "true" : "false") +
		" second_suppressed=" + (secondAttemptSuppressed ? "true" : "false"));
	return passed;
}

bool AIBT_HasReservationBy(const u8 team, const u16 builderID)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return false;
	for (uint i = 0; i < reserved.length; i++) if (reserved[i] == builderID) return true;
	return false;
}

bool AIBT_GetReservationBy(const u8 team, const u16 builderID, u16 &out taskX, u16 &out taskY)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return false;
	for (uint i = 0; i < reserved.length && i < xs.length && i < ys.length; i++)
	{
		if (reserved[i] != builderID) continue;
		taskX = xs[i];
		taskY = ys[i];
		return true;
	}
	return false;
}

bool AIBT_TaskIsPendingUnowned(const u8 team, const u16 taskX, const u16 taskY)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return false;
	for (uint i = 0; i < xs.length && i < ys.length && i < states.length && i < reserved.length && i < untils.length; i++)
	{
		if (xs[i] == taskX && ys[i] == taskY)
			return states[i] == AIBP_TaskState::pending && reserved[i] == 0 && untils[i] == 0;
	}
	return false;
}

bool AIBT_ReserveFirstActiveTask(const u8 team, const u16 builderID)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return false;
	const u8 activePhase = AIBP_CurrentTaskPhase(team);
	for (uint i = 0; i < xs.length && i < ys.length && i < phases.length && i < states.length; i++)
	{
		if (phases[i] == activePhase && states[i] != AIBP_TaskState::completed && states[i] != AIBP_TaskState::cancelled)
			return AIBP_ReserveTask(team, xs[i], ys[i], builderID);
	}
	return false;
}

void AIBT_ToggleTreesInRect(const u16 x1, const u16 y1, const u16 x2, const u16 y2)
{
	CBlob@[] trees;
	getBlobsByTag("tree", @trees);
	u16 changed = 0;
	for (uint i = 0; i < trees.length; i++)
	{
		CBlob@ tree = trees[i];
		if (tree is null) continue;

		Vec2f pos = tree.getPosition();
		const u16 tx = u16(pos.x / 8);
		const u16 ty = u16(pos.y / 8);
		if (tx < x1 || tx > x2 || ty < y1 || ty > y2) continue;

		const bool selected = !tree.get_bool("aibuilder selected tree");
		tree.set_bool("aibuilder selected tree", selected);
		tree.Sync("aibuilder selected tree", true);
		if (selected)
		{
			tree.Tag("aibuilder selected tree");
		}
		else
		{
			tree.Untag("aibuilder selected tree");
		}
		changed++;
		AIB_LogEvent("ui", "toggle_tree", AIBT_BlobRef(tree), "selected=" + (selected ? "true" : "false") + " rect=" + x1 + "," + y1 + "," + x2 + "," + y2);
	}
	AIB_LogEvent("ui", "select_trees_rect", "test-ui", "rect=" + x1 + "," + y1 + "," + x2 + "," + y2 + " changed=" + changed);
}

u16 AIBT_CountSelectedTrees()
{
	CBlob@[] trees;
	getBlobsByTag("tree", @trees);
	u16 selected = 0;
	for (uint i = 0; i < trees.length; i++)
	{
		CBlob@ tree = trees[i];
		if (tree !is null && tree.get_bool("aibuilder selected tree")) selected++;
	}
	return selected;
}

bool AIBT_ShopHasBlob(CBlob@ shop, const string &in blobName)
{
	if (shop is null) return false;

	ShopItem[]@ items;
	if (!shop.get("shop array", @items) || items is null) return false;
	for (uint i = 0; i < items.length; i++)
	{
		if (items[i].blobName == blobName) return true;
	}
	return false;
}

u16 AIBT_CountSeedsNear(Vec2f pos, const f32 radius)
{
	return AIBT_CountBlobsNear("seed", pos, radius);
}

s16 AIBT_GetQuarryFuelNear(Vec2f pos, const f32 radius)
{
	CBlob@[] quarries;
	getBlobsByName("quarry", @quarries);
	for (uint i = 0; i < quarries.length; i++)
	{
		CBlob@ quarry = quarries[i];
		if (quarry is null || quarry.hasTag("dead")) continue;
		if ((quarry.getPosition() - pos).Length() <= radius)
		{
			return quarry.get_s16("fuel_level");
		}
	}
	return -1;
}

u16 AIBT_FillCrateWithWood(CBlob@ crate)
{
	if (crate is null) return 0;
	CInventory@ inv = crate.getInventory();
	if (inv is null) return 0;
	CBlob@ wood = AIBT_Spawn("mat_wood", crate.getTeamNum(), crate.getPosition());
	if (wood is null) return 0;
	wood.server_SetQuantity(250);
	if (!crate.server_PutInInventory(wood)) return 0;

	// Materials merge, so nine wood blobs do not occupy nine slots. Keep one
	// real funding stack and fill the other eight 3x3 crate slots with distinct,
	// non-stackable base items. The 150-wood purchase reduces the wood quantity
	// but does not free its slot, forcing a genuine secondary crate.
	string[] fillers = { "seed", "bomb", "waterbomb", "mine", "lantern", "bucket", "sponge", "boulder" };
	u8 inserted = 0;
	for (uint i = 0; i < fillers.length; i++)
	{
		CBlob@ item = AIBT_Spawn(fillers[i], crate.getTeamNum(), crate.getPosition());
		if (item is null) break;
		if (!crate.server_PutInInventory(item))
		{
			item.server_Die();
			break;
		}
		inserted++;
	}
	getRules().set_u8("aibt overflow fillers", inserted);
	return 250;
}

bool AIBT_OverflowCratesAreGroundedAndDistinct(CBlob@ home, u8 &out count, string &out detail)
{
	count = 0;
	detail = "";
	CMap@ map = getMap();
	if (home is null || map is null) { detail = "missing_home_or_map"; return false; }
	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	array<Vec2f> positions;
	for (uint i = 0; i < crates.length; i++)
	{
		CBlob@ crate = crates[i];
		if (crate is null || crate.hasTag("dead") || crate.getTeamNum() != home.getTeamNum()) continue;
		if ((crate.getPosition() - home.getPosition()).Length() > 160.0f) continue;
		Vec2f pos = crate.getPosition();
		if (map.isTileSolid(map.getTile(pos).type) ||
			!map.isTileSolid(map.getTile(pos + Vec2f(0.0f, map.tilesize)).type) ||
			map.getSectorAtPosition(pos, "no build") !is null)
		{
			detail = "ungrounded_or_blocked crate=" + crate.getNetworkID() + " pos=" + int(pos.x) + "," + int(pos.y);
			return false;
		}
		for (uint p = 0; p < positions.length; p++)
		{
			if ((positions[p] - pos).Length() < 14.0f)
			{
				detail = "overlapping_crates pos=" + int(pos.x) + "," + int(pos.y);
				return false;
			}
		}
		positions.push_back(pos);
		count++;
	}
	detail = "grounded_distinct_crates=" + count;
	return count >= 2;
}

void AIBT_SetupScenario(const int index)
{
	AIBT_CleanupScenario();
	AIBT_CaptureOrValidateCanonicalMap();
	getRules().set_string("aib test scenario", AIBT_ScenarioName(index));

	AIBT_PrepareArena(false, false);

	CBlob@ bot;
	switch (index)
	{
		case 0:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			AIBT_SpawnWood(56, 120);
			AIBT_ForceState(bot, AIBT_FIND_WOOD);
			break;
		}

		case 1:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			CBlob@ selected = AIBT_SpawnTree(64, true);
			AIB_LogEvent("test", "simulate_tree_target", AIBT_BlobRef(bot), "target=" + AIBT_BlobRef(selected));
			AIB_LogEvent("test", "simulate_tree_cut", AIBT_BlobRef(bot), "target=" + AIBT_BlobRef(selected));
			AIB_LogEvent("test", "simulate_log_cut", AIBT_BlobRef(bot), "item=mat_wood quantity=120");
			AIBT_GiveWood(bot, 120);
			AIBT_StartHarvest(bot);
			break;
		}

		case 2:
		{
			AIBT_PrepareGloryhillLeftTreeArena();
			AIBT_SpawnTent(160);
			@bot = AIBT_SpawnBot(158);
			CBlob@ selected = AIBT_SpawnTreeAt(124, 61, true);
			AIBT_SetBlob("aibt_expected", selected);
			AIBT_StartHarvest(bot);
			break;
		}

		case 3:
		{
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(68);
			AIBT_SpawnTree(72, false);
			CBlob@ selected = AIBT_SpawnTree(92, true);
			AIBT_SetBlob("aibt_expected", selected);
			AIBT_StartHarvest(bot);
			break;
		}

		case 4:
		{
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(88);
			CBlob@ best = AIBT_SpawnTree(50, false);
			AIBT_SpawnTree(96, false);
			AIBT_SetBlob("aibt_expected", best);
			AIBT_StartHarvest(bot);
			break;
		}

		case 5:
		{
			getRules().set_bool("aib test resource barrier", true);
			getRules().set_u16("barrier_x1", 82 * 8);
			getRules().set_u16("barrier_x2", 86 * 8);
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(54);
			CBlob@ sameSide = AIBT_SpawnTree(68, false);
			AIBT_SpawnTree(100, false);
			AIBT_SetBlob("aibt_expected", sameSide);
			AIBT_StartHarvest(bot);
			break;
		}

		case 6:
		{
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(54);
			AIBT_SpawnTree(64, false);
			CBlob@ safe = AIBT_SpawnTree(96, false);
			AIBT_Spawn("knight", 1, AIBT_Pos(66, AIBT_GROUND_Y - 2));
			AIBT_SetBlob("aibt_expected", safe);
			AIBT_SetBlob("aibt_delayed_bot", bot);
			break;
		}

		case 7:
		{
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(74);
			AIBT_SpawnTree(52, false);
			CBlob@ safe = AIBT_SpawnTree(96, false);
			AIBT_Spawn("knight", 1, AIBT_Pos(50, AIBT_GROUND_Y - 2));
			AIBT_SetBlob("aibt_expected", safe);
			AIBT_SetBlob("aibt_delayed_bot", bot);
			break;
		}

		case 8:
		{
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(54);
			AIBT_SpawnTree(64, false);
			CBlob@ safe = AIBT_SpawnTree(96, false);
			AIBT_Spawn("archer", 1, AIBT_Pos(66, AIBT_GROUND_Y - 2));
			AIBT_SetBlob("aibt_expected", safe);
			AIBT_SetBlob("aibt_delayed_bot", bot);
			break;
		}

		case 9:
		{
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(54);
			AIBT_SpawnTree(70, false);
			AIBT_StartHarvest(bot);
			AIBT_SetBlob("aibt_enemy", AIBT_Spawn("knight", 1, AIBT_Pos(58, AIBT_GROUND_Y - 2)));
			break;
		}

		case 10:
		{
			AIBT_SpawnTent(238);
			@bot = AIBT_SpawnBot(250);
			CBlob@ wallSafe = AIBT_SpawnTree(272, false);
			AIBT_Spawn("knight", 1, AIBT_Pos(266, AIBT_GROUND_Y - 2));
			AIBT_SetBlob("aibt_expected", wallSafe);
			AIBT_StartHarvest(bot);
			break;
		}

		case 11:
		{
			AIBT_SpawnTent(292);
			@bot = AIBT_SpawnBot(304);
			CBlob@ obstacleTree = AIBT_SpawnTree(334, false);
			AIBT_SetBlob("aibt_expected", obstacleTree);
			AIBT_StartHarvest(bot);
			break;
		}

		case 12:
		{
			@bot = AIBT_SpawnBot(54);
			AIBT_GiveWood(bot, 120);
			AIBT_ForceState(bot, AIBT_RETURN_WOOD);
			break;
		}

		case 13:
		{
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(68);
			AIBT_SpawnTree(72, false);
			CBlob@ selected = AIBT_SpawnTree(92, false);
			AIBT_SetBlob("aibt_expected", selected);
			AIB_LogEvent("ui", "select_trees_open", "test-ui", "simulated=true");
			AIBT_ToggleTreesInRect(90, 67, 94, 71);
			AIB_LogEvent("ui", "select_trees_confirm", "test-ui", "simulated=true");
			AIBT_StartHarvest(bot);
			break;
		}

		case 14:
		{
			AIBT_SpawnTent(160);
			@bot = AIBT_SpawnBot(158);
			CBlob@ selected = AIBT_SpawnTreeAt(124, 61, true);
			AIBT_SetBlob("aibt_expected", selected);
			AIBT_StartHarvest(bot);
			break;
		}

		case 15:
		{
			AIBT_SpawnTent(338);
			@bot = AIBT_SpawnBot(344);
			CBlob@ tree = AIBT_SpawnTree(360, false);
			AIBT_SetBlob("aibt_expected", tree);
			AIBT_StartHarvest(bot);
			break;
		}

		case 16:
		{
			AIBT_SpawnTent(382);
			@bot = AIBT_SpawnBot(386);
			AIBT_DisableStarterMaterials(bot);
			// Production base storage is centred nine tiles left of the home.
			CBlob@ crate = AIBT_Spawn("crate", 0, AIBT_Pos(373, AIBT_GROUND_Y - 2));
			if (crate !is null)
			{
				crate.Tag("aibuilder resource crate");
				AIBT_GiveMaterial(crate, "mat_wood", 80);
				AIBT_GiveMaterial(crate, "mat_stone", 80);
			}
			AIBT_SetBlob("aibt_expected", crate);
			AIBP_SetHumanTile(0, 394, AIBT_GROUND_Y - 1, AIBP_STONE_BLOCK);
			AIBP_SetHumanTile(0, 395, AIBT_GROUND_Y - 1, AIBP_WOOD_BLOCK);
			AIBT_StartBlueprint(bot, false);
			break;
		}

		case 17:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			AIBT_StartBlueprint(bot, false);
			break;
		}

		case 18:
		{
			AIBT_SpawnTent(382);
			CBlob@ crate = AIBT_Spawn("crate", 0, AIBT_Pos(392, AIBT_GROUND_Y - 2));
			if (crate !is null) crate.Tag("aibuilder resource crate");
			AIBT_GiveMaterial(crate, "mat_wood", 600);
			AIBT_GiveMaterial(crate, "mat_stone", 600);
			CRules@ rules = getRules();
			rules.set_bool("aibt director defaults valid",
				AIBS_DefaultModeForGamemode("CTF") == AIBP_StrategyMode::auto_mode &&
				AIBS_DefaultModeForGamemode("AIBTest") == AIBP_StrategyMode::off &&
				AIBP_IsDirectorEnabled(AIBP_StrategyMode::auto_mode) &&
				!AIBP_IsDirectorEnabled(AIBP_StrategyMode::off) &&
				!AIBP_IsDirectorEnabled(AIBP_StrategyMode::suggest) &&
				AIBP_ToggleDirectorMode(AIBP_StrategyMode::auto_mode) == AIBP_StrategyMode::off &&
				AIBP_ToggleDirectorMode(AIBP_StrategyMode::off) == AIBP_StrategyMode::auto_mode &&
				AIBP_ToggleDirectorMode(AIBP_StrategyMode::suggest) == AIBP_StrategyMode::auto_mode &&
				AIBS_DefaultBootstrapForGamemode("CTF") && !AIBS_DefaultBootstrapForGamemode("AIBTest"));
			rules.set_bool(AIBS_BootstrapKey(0, "enabled"), true);
			rules.set_bool(AIBS_BootstrapKey(0, "provisioned"), false);
			rules.set_u32(AIBS_BootstrapKey(0, "next retry"), 0);
			rules.set_u8(AIBP_ModeKey(0), AIBP_StrategyMode::auto_mode);
			rules.set_u8("aib strategy last mode team 0", AIBP_StrategyMode::off);
			rules.set_u32("aib strategy last replan team 0", 0);
			rules.set_u32("aib strategy important event team 0", getGameTime());
			rules.set_u32("aibt director setup tick", getGameTime());
			break;
		}

		case 19:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			AIBT_DisableStarterMaterials(bot);
			AIBT_Spawn("nursery", 0, AIBT_Pos(58, AIBT_GROUND_Y - 2));
			AIBT_SpawnMaterial("mat_stone", 54, 80);
			AIBT_ForceState(bot, AIBT_RETURN_WOOD);
			break;
		}

		case 20:
		{
			AIBT_ForceResourceBarrierAroundMap();
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			AIBT_DisableStarterMaterials(bot);
			AIBT_SpawnMaterial("mat_wood", 54, 350);
			AIBT_ForceState(bot, AIBT_RETURN_WOOD);
			break;
		}

		case 21:
		{
			AIBT_ForceResourceBarrierAroundMap();
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			AIBT_DisableStarterMaterials(bot);
			AIBT_Spawn("quarry", 0, AIBT_Pos(58, AIBT_GROUND_Y - 2));
			AIBT_SpawnMaterial("mat_stone", 58, 80);
			AIBT_StartStone(bot);
			break;
		}

		case 22:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(52);
			CBlob@ second = AIBT_SpawnBot(56);
			AIBT_DisableStarterMaterials(bot);
			AIBT_DisableStarterMaterials(second);
			AIBT_SetBlob("aibt_bot", bot);
			AIBT_SetBlob("aibt_delayed_bot", second);
			AIBT_GiveWood(bot, 240);
			AIBT_GiveWood(second, 240);
			AIBT_ForceState(bot, AIBT_RETURN_WOOD);
			AIBT_ForceState(second, AIBT_RETURN_WOOD);
			break;
		}

		case 23:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			getRules().set_bool("aib test resource barrier", true);
			getRules().set_u16("barrier_x1", 52 * 8);
			getRules().set_u16("barrier_x2", 56 * 8);
			AIB_LogEvent("test", "force_barrier", "runner", "mode=local_builder_strip");
			AIBT_DisableStarterMaterials(bot);
			AIBT_StartStone(bot);
			break;
		}

		case 24:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			AIBT_DisableStarterMaterials(bot);
			AIBT_SpawnMaterial("mat_wood", 54, 120);
			AIBT_SpawnMaterial("mat_stone", 55, 30);
			AIBT_StartHarvest(bot);
			break;
		}

		case 25:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			AIBT_SetSingleBlueprintTileForTeam(1, 60, AIBT_GROUND_Y - 1, 48, false);
			bot.set_u8("ai builder state", AIBT_FIND_BLUEPRINT_BLOCK);
			bot.set_u8("ai builder job", AIBT_JOB_BLUEPRINT);
			bot.set_Vec2f("ai builder tile target", Vec2f_zero);
			break;
		}

		case 26:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			const u16 y = AIBT_GROUND_Y - 1;
			const bool humanSet = AIBP_SetHumanTile(0, 386, y, AIBP_WOOD_BLOCK);
			BlueprintPlan@ plan = AIBT_NewStrategicPlan(0, "layer_test");
			plan.tasks.push_back(BlueprintTask(387, y, AIBP_STONE_BLOCK, AIBP_Phase::shell));
			const bool published = AIBP_PublishAIPlan(plan, true);
			BlueprintPlan@ otherPlan = AIBT_NewStrategicPlan(1, "layer_test_other_team");
			otherPlan.tasks.push_back(BlueprintTask(388, y, AIBP_WOOD_BACKWALL, AIBP_Phase::foundation));
			const bool otherPublished = AIBP_PublishAIPlan(otherPlan, true);
			getRules().set_u8(AIBP_ModeKey(0), AIBP_StrategyMode::suggest);
			AIBP_SetAIWorkEnabled(0, false);
			bot.set_u8("ai builder job", AIBT_JOB_BLUEPRINT);
			bot.set_bool("aib strategy assigned", false);
			const bool suggestionAccepted = AIBP_ActivateSuggestedWorkForManualBuilder(bot);
			array<u16>@ merged = null; array<u16>@ otherMerged = null;
			AIBP_GetCompatibilityGrid(0, @merged); AIBP_GetCompatibilityGrid(1, @otherMerged);
			const uint humanIndex = y * getMap().tilemapwidth + 386;
			const uint aiIndex = y * getMap().tilemapwidth + 387;
			const uint otherIndex = y * getMap().tilemapwidth + 388;
			const bool preserved = merged !is null && otherMerged !is null &&
				merged[humanIndex] == AIBP_WOOD_BLOCK && merged[aiIndex] == AIBP_STONE_BLOCK && merged[otherIndex] == 0 &&
				otherMerged[aiIndex] == 0 && otherMerged[otherIndex] == AIBP_WOOD_BACKWALL;
			const bool metadata = getRules().get_u16(AIBP_PlanKey(0, "id")) == plan.id &&
				getRules().get_u16(AIBP_PlanKey(0, "version")) == plan.version && getRules().get_u8(AIBP_PlanKey(0, "owner")) == 255;
			AIBT_SetStrategicResult(humanSet && published && otherPublished && suggestionAccepted && preserved && metadata,
				"human_priority=true ai_published=true suggestion_manual_accept=true team_isolation=true metadata=true", "layer_merge_team_or_metadata_failed");
			break;
		}

		case 27:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			const u16 y = AIBT_GROUND_Y - 1;
			BlueprintPlan@ plan = AIBT_NewStrategicPlan(0, "history_test");
			plan.tasks.push_back(BlueprintTask(388, y, AIBP_WOOD_BLOCK, AIBP_Phase::shell));
			const bool published = AIBP_PublishAIPlan(plan, true);
			AIBP_ClearConsumableTile(0, 388, y);
			array<u16>@ desired = null; array<u16>@ work = null; array<u8>@ states = null;
			array<u16>@ history = null; array<u16>@ archivedDesired = null;
			AIBP_GetLayerGrid(0, AIBP_Layer::ai_desired, @desired);
			AIBP_GetLayerGrid(0, AIBP_Layer::ai_work, @work);
			getRules().get(AIBP_TaskKey(0, "state"), @states);
			getRules().get("aib strategy history ids team 0", @history);
			getRules().get("aib strategy history plan " + plan.id + " team 0 desired", @archivedDesired);
			const uint at = y * getMap().tilemapwidth + 388;
			const bool historyValid = published && desired !is null && desired[at] == AIBP_WOOD_BLOCK && work !is null && work[at] == 0 &&
				states !is null && states.length == 1 && states[0] == AIBP_TaskState::completed && getRules().get_u8(AIBP_PlanKey(0, "status")) == 2 &&
				history !is null && history.length == 1 && history[0] == plan.id && archivedDesired !is null && archivedDesired[at] == AIBP_WOOD_BLOCK;
			AIBT_SetStrategicResult(historyValid, "desired_retained=true task_completed=true archived=true", "history_not_preserved");
			break;
		}

		case 28:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			const u16 y = AIBT_GROUND_Y - 1;
			AIBP_SetHumanTile(0, 388, y, AIBP_WOOD_DOOR);
			const u16 wood = AIBP_RemainingMaterialCost(0, "mat_wood");
			const u16 stone = AIBP_RemainingMaterialCost(0, "mat_stone");
			AIBT_SetStrategicResult(wood == 30 && stone == 0, "wood=30 stone=0", "remaining_cost_wrong wood=" + wood + " stone=" + stone);
			break;
		}

		case 29:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			CBlob@ second = AIBT_SpawnBot(385); AIBT_SetBlob("aibt_delayed_bot", second);
			const u16 y = AIBT_GROUND_Y - 1;
			BlueprintPlan@ plan = AIBT_NewStrategicPlan(0, "reservation_test");
			plan.tasks.push_back(BlueprintTask(388, y, AIBP_WOOD_BACKWALL, AIBP_Phase::foundation));
			plan.tasks.push_back(BlueprintTask(389, y, AIBP_WOOD_BLOCK, AIBP_Phase::shell));
			const bool published = AIBP_PublishAIPlan(plan, true);
			const bool first = AIBP_ReserveTask(0, 388, y, bot.getNetworkID());
			const bool duplicate = AIBP_ReserveTask(0, 388, y, second.getNetworkID());
			const bool shellAvailable = AIBP_TaskAvailableForBuilder(0, 389, y, second.getNetworkID());
			AIBT_SetStrategicResult(published && first && !duplicate && !shellAvailable, "exclusive=true phase_gate=true", "reservation_or_phase_failed");
			break;
		}

		case 30:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			const bool catalog = AIBP_IsCatalogBlock(AIBP_STONE_DOOR) && AIBP_IsCatalogBlock(AIBP_WOOD_DOOR) && AIBP_IsCatalogBlock(AIBP_PLATFORM) &&
				AIBP_BlockBlobName(AIBP_STONE_DOOR) == "stone_door" && AIBP_BlockBlobName(AIBP_WOOD_DOOR) == "wooden_door" &&
				AIBP_BlockBlobName(AIBP_PLATFORM) == "wooden_platform" && AIBP_BlockCost(AIBP_STONE_DOOR) == 50 &&
				AIBP_BlockCost(AIBP_WOOD_DOOR) == 30 && AIBP_BlockCost(AIBP_PLATFORM) == 15 &&
				AIBP_IsPrefabSizeValid(64, 64) && !AIBP_IsPrefabSizeValid(65, 1) && !AIBP_IsPrefabSizeValid(64, 65);
			uint16[][] source(2, uint16[](2, AIBP_WOOD_BACKWALL));
			const bool batch = AIBP_ApplyHumanPlacement(0, 390, AIBT_GROUND_Y - 2, 2, 2, source);
			const bool oneVersion = getRules().get_u16(AIBP_PlanKey(0, "human version")) == 1;
			uint16[][] invalid(1, uint16[](1, 999));
			const bool invalidRejected = !AIBP_ApplyHumanPlacement(0, 392, AIBT_GROUND_Y - 2, 1, 1, invalid) &&
				getRules().get_u16(AIBP_PlanKey(0, "human version")) == 1;
			AIBT_SetStrategicResult(catalog && batch && oneVersion && invalidRejected,
				"doors_platforms_catalogued=true prefab_capped=true batch_version=1 invalid_atomic=true", "catalog_prefab_or_batch_failed");
			break;
		}

		case 31:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			const u16 y = AIBT_GROUND_Y - 1;
			const bool first = AIBP_SetHumanTile(0, 388, y, AIBP_WOOD_BLOCK, 0);
			const bool stale = AIBP_SetHumanTile(0, 388, y, AIBP_STONE_BLOCK, 0);
			array<u16>@ human = null; AIBP_GetLayerGrid(0, AIBP_Layer::human, @human);
			const uint at = y * getMap().tilemapwidth + 388;
			AIBT_SetStrategicResult(first && !stale && human !is null && human[at] == AIBP_WOOD_BLOCK, "stale_rejected=true", "stale_delta_applied");
			break;
		}

		case 36:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			CBlob@ building = AIBT_Spawn("building", 0, AIBT_Pos(58, AIBT_GROUND_Y - 2));
			AIBT_SetBlob("aibt_expected", building);
			break;
		}

		case 34:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(394); AIBT_DisableStarterMaterials(bot);
			AIBT_GiveMaterial(bot, "mat_wood", 60);
			AIBP_SetHumanTile(0, 394, AIBT_GROUND_Y - 1, AIBP_EncodeBlock(AIBP_WOOD_DOOR, 1));
			AIBT_StartBlueprint(bot, false);
			break;
		}

		case 33:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			const u16 firstBuilder = 60001;
			const u16 secondBuilder = 60002;
			const u16 y = AIBT_GROUND_Y - 1;
			const bool set = AIBP_SetHumanTile(0, 388, y, AIBP_WOOD_BLOCK);
			const bool first = AIBP_ReserveTask(0, 388, y, firstBuilder);
			const bool duplicate = AIBP_ReserveTask(0, 388, y, secondBuilder);
			AIBP_ReleaseBuilderReservation(0, firstBuilder);
			const bool afterRelease = AIBP_ReserveTask(0, 388, y, secondBuilder);
			AIBT_SetStrategicResult(set && first && !duplicate && afterRelease, "human_reservation_exclusive=true",
				"human_reservation_failed");
			break;
		}

		case 37:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			AIBWorldState@ world = AIBWorldState();
			world.team = 0; world.home = AIBT_Pos(382); world.enemyDirection = 1;
			AIBPlanCandidate@ candidate = AIBS_GatehouseTemplate(388, AIBT_GROUND_Y);
			bool hasFoundation = false; bool hasAccess = false; bool hasShell = false;
			bool hasDoor = false; bool hasPlatform = false;
			for (uint i = 0; i < candidate.tasks.length; i++)
			{
				BlueprintTask@ task = candidate.tasks[i];
				if (task is null) continue;
				hasFoundation = hasFoundation || task.phase == AIBP_Phase::foundation;
				hasAccess = hasAccess || task.phase == AIBP_Phase::access;
				hasShell = hasShell || task.phase == AIBP_Phase::shell;
				hasDoor = hasDoor || AIBP_BlockId(task.block) == AIBP_WOOD_DOOR;
				hasPlatform = hasPlatform || AIBP_BlockId(task.block) == AIBP_PLATFORM;
			}
			AIBPlanCandidate@ blocked = AIBPlanCandidate(); blocked.anchor = Vec2f(400, AIBT_GROUND_Y);
			for (int y = AIBT_GROUND_Y - 6; y < AIBT_GROUND_Y; y++) AIBS_AddTask(blocked, 400, y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
			const bool route = AIBS_PreservesFriendlyRoute(candidate) && !AIBS_PreservesFriendlyRoute(blocked);
			const f32 routePenalty = AIBS_FriendlyRoutePenalty(candidate);
			const bool routeMetric = routePenalty < 1.0f && AIBS_FriendlyRoutePenalty(blocked) >= 1.0f;
			const bool dependency = AIBS_CandidateHasDependencySupport(world, candidate);
			const bool approach = AIBS_AllTasksHaveReachableApproach(candidate);
			const bool buildable = dependency && approach;
			AIBT_SetStrategicResult(hasFoundation && hasAccess && hasShell && hasDoor && hasPlatform && route && routeMetric && buildable,
				"phases=true friendly_passage=true route_metric=" + routePenalty + " support=true reachable=true", "template_phase_route_or_dependency_failed");
			if (!(hasFoundation && hasAccess && hasShell && hasDoor && hasPlatform && route && routeMetric && buildable))
			{
				getRules().set_string("aibt strategic failure", "template_phase_route_or_dependency_failed foundation=" + (hasFoundation ? "true" : "false") +
					" access=" + (hasAccess ? "true" : "false") + " shell=" + (hasShell ? "true" : "false") +
					" door=" + (hasDoor ? "true" : "false") + " platform=" + (hasPlatform ? "true" : "false") +
					" route=" + (route ? "true" : "false") + " route_metric=" + (routeMetric ? "true" : "false") +
					" penalty=" + routePenalty + " dependency=" + (dependency ? "true" : "false") +
					" approach=" + (approach ? "true" : "false") + " buildable=" + (buildable ? "true" : "false"));
			}
			break;
		}

		case 38:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			AIBWorldState@ world = AIBWorldState();
			world.team = 0; world.home = AIBT_Pos(382); world.enemyDirection = 1;
			AIBPlanCandidate@ candidate = AIBS_GatehouseTemplate(388, AIBT_GROUND_Y);
			BlueprintTask@ overlap = candidate.tasks[0];
			const bool set = overlap !is null && AIBP_SetHumanTile(0, overlap.x, overlap.y, AIBP_WOOD_BLOCK);
			const bool valid = AIBS_ValidateCandidate(world, candidate);
			AIBT_SetStrategicResult(set && !valid && candidate.rejection == "human_plan",
				"human_overlap_rejected=true", "wrong_rejection=" + candidate.rejection);
			break;
		}

		case 39:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			AIBWorldState@ world = AIBWorldState(); world.team = 0;
			AIBPlanCandidate@ candidate = AIBPlanCandidate();
			candidate.intent = AIBStrategyIntent::flag_gatehouse; candidate.score = 114.0f;
			getRules().set_u16(AIBP_PlanKey(0, "id"), 42);
			getRules().set_f32(AIBP_PlanKey(0, "score"), 100.0f);
			getRules().set_u32(AIBP_PlanKey(0, "updated"), getGameTime());
			getRules().set_u8(AIBP_PlanKey(0, "status"), 1);
			getRules().set_u8(AIBP_PlanKey(0, "intent"), AIBStrategyIntent::flag_gatehouse);
			const bool committed = !AIBS_ShouldReplacePlan(world, candidate);
			world.frontlineCollapsing = true;
			candidate.intent = AIBStrategyIntent::emergency_barrier;
			const bool emergency = AIBS_ShouldReplacePlan(world, candidate);
			AIBT_SetStrategicResult(committed && emergency, "commitment=true emergency_override=true", "hysteresis_failed");
			break;
		}

		case 40:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			const u16 y = AIBT_GROUND_Y - 5;
			BlueprintPlan@ plan = AIBT_NewStrategicPlan(0, "damage_test");
			plan.tasks.push_back(BlueprintTask(388, y, AIBP_WOOD_BLOCK, AIBP_Phase::shell));
			const bool published = AIBP_PublishAIPlan(plan, true);
			AIBP_ClearConsumableTile(0, 388, y);
			AIBP_RefreshPlanState(0, true);
			array<u8>@ states = null; array<u16>@ work = null;
			getRules().get(AIBP_TaskKey(0, "state"), @states);
			AIBP_GetLayerGrid(0, AIBP_Layer::ai_work, @work);
			const uint at = y * getMap().tilemapwidth + 388;
			const bool reactivated = published && states !is null && states.length == 1 && states[0] == AIBP_TaskState::pending &&
				work !is null && work[at] == AIBP_WOOD_BLOCK && getRules().get_u16(AIBP_PlanKey(0, "damaged")) == 1 &&
				getRules().get_u8(AIBP_PlanKey(0, "status")) == 1;
			AIBT_SetStrategicResult(reactivated, "damaged=1 task_reactivated=true", "destroyed_task_not_reactivated");
			break;
		}

		case 41:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			AIBWorldState@ world = AIBWorldState();
			world.team = 0; world.home = AIBT_Pos(382); world.frontline = AIBT_Pos(405); world.enemyDirection = 1;
			array<AIBPlanCandidate@> candidates;
			AIBS_GenerateCandidates(world, candidates);
			AIBPlanCandidate@ gate = null;
			if (candidates.length > 0) @gate = candidates[0];
			bool footprint = gate !is null && gate.tasks.length > 0;
			if (gate !is null)
			{
				for (uint i = 0; i < gate.tasks.length; i++)
				{
					BlueprintTask@ task = gate.tasks[i];
					if (task is null || task.x >= getMap().tilemapwidth || task.y >= getMap().tilemapheight) { footprint = false; break; }
				}
			}
			const bool anchored = gate !is null && gate.intent == AIBStrategyIntent::flag_gatehouse && int(gate.anchor.x) == 392;
			const bool route = gate !is null && AIBS_PreservesFriendlyRoute(gate);
			bool hasTower = false; bool hasPerch = false; bool hasAccess = false;
			for (uint i = 0; i < candidates.length; i++)
			{
				hasTower = hasTower || candidates[i].intent == AIBStrategyIntent::frontline_tower;
				hasPerch = hasPerch || candidates[i].intent == AIBStrategyIntent::archer_perch;
				hasAccess = hasAccess || candidates[i].intent == AIBStrategyIntent::access_route;
			}
			if (gate !is null) AIBS_ScoreCandidate(world, gate);
			const bool explained = gate !is null && gate.reasons.find("defense=") >= 0 && gate.reasons.find("choke=") >= 0 && gate.reasons.find("route_penalty=") >= 0;
			const bool terrainFeatures = AIBS_LaneWidthAt(392) > 0 && AIBS_WallHeightAt(260) > 0;
			const bool generated = anchored && footprint && route && candidates.length >= 9 && hasTower && hasPerch && hasAccess && explained && terrainFeatures;
			AIBT_SetStrategicResult(generated,
				"intent=gatehouse anchor=392 footprint=true route=true competing_templates=true explained=true",
				"candidate_generation_failed anchored=" + (anchored ? "true" : "false") + " footprint=" + (footprint ? "true" : "false") +
				" route=" + (route ? "true" : "false") + " count=" + candidates.length + " tower=" + (hasTower ? "true" : "false") +
				" perch=" + (hasPerch ? "true" : "false") + " access=" + (hasAccess ? "true" : "false") +
				" explained=" + (explained ? "true" : "false") + " terrain_features=" + (terrainFeatures ? "true" : "false"));
			break;
		}

		case 32:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			AIBT_ForceResourceBarrierAroundMap();
			AIBWorldState@ world = AIBWorldState();
			world.team = 0; world.home = AIBT_Pos(382); world.enemyDirection = 1;
			AIBPlanCandidate@ candidate = AIBS_GatehouseTemplate(392, AIBT_GROUND_Y);
			const bool valid = AIBS_ValidateCandidate(world, candidate);
			AIBT_SetStrategicResult(!valid && candidate.rejection == "barrier", "barrier_rejected=true",
				"wrong_rejection=" + candidate.rejection);
			break;
		}

		case 35:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(392); AIBT_DisableStarterMaterials(bot);
			AIBT_GiveMaterial(bot, "mat_wood", 40);
			CMap@ map = getMap();
			if (map !is null) map.server_SetTile(AIBT_Pos(394, AIBT_GROUND_Y - 1), CMap::tile_wood_back);
			AIBP_SetHumanTile(0, 394, AIBT_GROUND_Y - 1, AIBP_PLATFORM);
			AIBT_StartBlueprint(bot, false);
			break;
		}

		case 43:
		{
			const int x = 320;
			const int mirrorX = 336;
			const int y = AIBT_GROUND_Y - 2;
			AIBT_SpawnTent(300);
			@bot = AIBT_SpawnBot(x);
			AIBT_DisableStarterMaterials(bot);

			// Normalize two complete, non-overlapping arenas.  The static suite map
			// has an inherited wall at x=320; assigning every local air/foundation/
			// trap cell once keeps both mirrored cases identical and lets cleanup
			// restore the original map exactly.
			for (int trap = 0; trap < 2; trap++)
			{
				const int centerX = trap == 0 ? x : mirrorX;
				for (int tileX = centerX - 7; tileX <= centerX + 7; tileX++)
				{
					for (int tileY = y - 4; tileY <= AIBT_GROUND_Y; tileY++)
					{
						u16 type = tileY == AIBT_GROUND_Y ? CMap::tile_ground : CMap::tile_empty;
						const bool anchor = trap == 0 ? tileX == centerX - 2 : tileX == centerX + 2;
						const bool ceiling = tileY == y - 1 && (tileX == centerX ||
							(trap == 0 ? tileX == centerX - 1 : tileX == centerX + 1));
						if ((anchor && tileY >= y - 1) || ceiling) type = CMap::tile_castle;
						if (tileX == (trap == 0 ? centerX - 6 : centerX + 6) && tileY == y - 3) type = CMap::tile_stone;
						AIBT_SetTemporaryTile(tileX, tileY, type);
					}
				}
			}

			// Real mirrored traps: a castle ceiling plus one castle upper
			// diagonal, joined to a castle column down into the foundation.  These
			// non-mineable cells cannot collapse or be accidentally dug during the
			// few ticks needed to observe recovery.  Body-height escape space stays
			// open, and no obstruction/recovery state is preloaded.
			bot.setPosition(AIBT_Pos(x, y));
			bot.set_u8("ai builder job", AIBT_JOB_STONE);
			bot.set_u8("ai builder state", AIBT_TUNNEL_TO_STONE);
			bot.set_Vec2f("ai builder tile target", AIBT_Pos(x - 6, y - 3));

			CBlob@ mirror = AIBT_Spawn("aibuilder", 0, AIBT_Pos(mirrorX, y));
			AIBT_DisableStarterMaterials(mirror);
			AIBT_SetBlob("aibt_expected", mirror);
			mirror.setPosition(AIBT_Pos(mirrorX, y));
			mirror.set_u8("ai builder job", AIBT_JOB_STONE);
			mirror.set_u8("ai builder state", AIBT_TUNNEL_TO_STONE);
			mirror.set_Vec2f("ai builder tile target", AIBT_Pos(mirrorX + 6, y - 3));

			getRules().set_f32("aibt left corner start x", bot.getPosition().x);
			getRules().set_f32("aibt right corner start x", mirror.getPosition().x);
			break;
		}

		case 42:
		{
			const int homeX = 39;
			const int storageX = homeX - 9;
			AIBT_SpawnTent(homeX);
			@bot = AIBT_SpawnBot(48);
			AIBT_DisableStarterMaterials(bot);
			// Isolate ore behavior from purchasing: storage already exists, while
			// the two gold blocks are real map tiles discovered by production LOS.
			// Keep the delayed tent/workshop no-build sectors well left of both the
			// ore and its surface route; the crate remains at the production storage
			// offset so delivery still exercises real base storage.
			AIBT_Spawn("buildershop", 0, AIBT_Pos(20, AIBT_GROUND_Y - 2));
			CBlob@ crate = AIBT_Spawn("crate", 0, AIBT_Pos(storageX, AIBT_GROUND_Y - 2));
			if (crate !is null) crate.Tag("aibuilder resource crate");
			AIBT_SetBlob("aibt_expected", crate);
			AIBT_SetTemporaryTile(51, AIBT_GROUND_Y - 2, CMap::tile_gold);
			AIBT_SetTemporaryTile(52, AIBT_GROUND_Y - 2, CMap::tile_gold);
			// A nearby gold tile behind a three-high castle occluder is the LOS
			// negative control; it must not join the visible cluster.
			AIBT_SetTemporaryTile(53, AIBT_GROUND_Y - 4, CMap::tile_castle);
			AIBT_SetTemporaryTile(53, AIBT_GROUND_Y - 3, CMap::tile_castle);
			AIBT_SetTemporaryTile(53, AIBT_GROUND_Y - 2, CMap::tile_castle);
			AIBT_SetTemporaryTile(55, AIBT_GROUND_Y - 3, CMap::tile_gold);
			AIBT_SetTemporaryTile(55, AIBT_GROUND_Y - 2, CMap::tile_ground);
			AIBT_SetTemporaryTile(56, AIBT_GROUND_Y - 2, CMap::tile_stone);
			for (int x = 51; x <= 56; x++) AIBT_SetTemporaryTile(x, AIBT_GROUND_Y - 1, CMap::tile_ground);
			bot.set_u8("ai builder job", AIBT_JOB_STONE);
			bot.set_u8("ai builder state", AIBT_TUNNEL_TO_STONE);
			bot.set_bool("ai builder mining gold", false);
			bot.set_Vec2f("ai builder tile target", AIBT_Pos(56, AIBT_GROUND_Y - 2));
			break;
		}

		case 44:
		{
			const int homeX = 210;
			AIBT_SpawnTent(homeX);
			// Base storage starts nine tiles left of the home.  Begin there so
			// this scenario measures siting, not return-path travel.
			@bot = AIBT_SpawnBot(homeX - 9);
			AIBT_DisableStarterMaterials(bot);
			AIBT_GiveWood(bot, 240);

			// A tent and workshop are each five tiles wide.  Six tiles of
			// edge clearance makes +/-11 the nearest legal flat-ground anchor.
			// A solid tile at +/-13 intersects every 5-wide footprint through
			// distance 15, so production must continue its search to >=16.
			AIBT_SetTemporaryTile(homeX - 13, AIBT_GROUND_Y - 2, CMap::tile_ground);
			AIBT_SetTemporaryTile(homeX + 13, AIBT_GROUND_Y - 2, CMap::tile_ground);
			AIBT_ForceState(bot, AIBT_RETURN_WOOD);
			break;
		}

		case 45:
		{
			const int homeX = 230;
			AIBT_SpawnHall(homeX);
			// Match the production base-storage x offset; this stays within the
			// immediate store radius even with the taller hall's center height.
			@bot = AIBT_SpawnBot(homeX - 9);
			AIBT_DisableStarterMaterials(bot);
			AIBT_GiveWood(bot, 240);

			// The even-width hall is centered on a whole tile while the odd-width
			// workshop is centered on a half tile.  Adjacent support holes at
			// +/-15 and +/-16 cover that asymmetry: every legal anchor through
			// search distance 18 loses at least one of its five foundation columns.
			// A center-only support check can still accept the near anchors; the
			// complete foundation check must continue to search distance 19.
			AIBT_SetTemporaryTile(homeX - 15, AIBT_GROUND_Y, CMap::tile_empty);
			AIBT_SetTemporaryTile(homeX - 16, AIBT_GROUND_Y, CMap::tile_empty);
			AIBT_SetTemporaryTile(homeX + 15, AIBT_GROUND_Y, CMap::tile_empty);
			AIBT_SetTemporaryTile(homeX + 16, AIBT_GROUND_Y, CMap::tile_empty);
			AIBT_ForceState(bot, AIBT_RETURN_WOOD);
			break;
		}

		case 46:
		{
			const int startX = 280;
			const int startY = 54;
			const int targetX = 288;
			const int targetY = 62;
			@bot = AIBT_SpawnBot(startX);
			AIBT_DisableStarterMaterials(bot);
			bot.setPosition(AIBT_Pos(startX, startY));

			// Begin with a solid controlled rectangle.  Only two valid mineable
			// routes remain: the dirt-heavy shaft at x=280 and a mostly pre-open,
			// reusable shaft at x=284.  Cheaper-looking x=286/x=290 alternatives
			// contain bedrock/castle and must be rejected by production policy.
			for (int y = 53; y <= targetY; y++)
			{
				for (int x = 268; x <= 292; x++)
				{
					u16 type = CMap::tile_ground;
					// The builder has a 7.5 px radius, so its tile-280 spawn overlaps
					// column 279.  Keep that body-width edge open; otherwise collision
					// resolution can nudge identical runs to opposite sides of the
					// direct-shaft handoff threshold before the first movement tick.
					const bool surfaceCorridor = x >= 279 && x <= 285 && (y == 53 || y == 54);
					const bool reusableShaft = (x == 284 || x == 285);
					const bool bedrockShaft = (x == 286 || x == 287);
					const bool structureShaft = (x == 289 || x == 290);
					const bool openCross = (y == targetY || y == targetY - 1) && x >= 285 && x <= 290;
					if (surfaceCorridor || reusableShaft || bedrockShaft || structureShaft || openCross) type = CMap::tile_empty;
					if (x == 284 && y == 58) type = CMap::tile_ground;
					if (x == 286 && y == 58) type = CMap::tile_bedrock;
					if (x == 290 && y == 58) type = CMap::tile_castle;
					if (x == targetX && y == targetY) type = CMap::tile_stone;
					AIBT_SetTemporaryTile(x, y, type);
					if (type == CMap::tile_ground) AIBT_route_dirt_tiles.push_back(AIBT_Pos(x, y));
				}
			}
			for (int y = targetY + 1; y <= AIBT_GROUND_Y; y++)
			{
				for (int x = 268; x <= 292; x++)
				{
					AIBT_SetTemporaryTile(x, y, CMap::tile_ground);
					AIBT_route_dirt_tiles.push_back(AIBT_Pos(x, y));
				}
			}

			CMap@ map = getMap();
			Vec2f target = AIBT_Pos(targetX, targetY);
			Vec2f directCorner = Vec2f(startX * map.tilesize, targetY * map.tilesize);
			Vec2f bedrockCorner = Vec2f(286 * map.tilesize, targetY * map.tilesize);
			Vec2f structureCorner = Vec2f(290 * map.tilesize, targetY * map.tilesize);
			Vec2f inaccessibleCorner = Vec2f(294 * map.tilesize, targetY * map.tilesize);
			Vec2f chosen = AIB_GetBestStoneRouteCorner(bot, target);
			const u16 directDirt = AIB_CountDirtOnStoneRoute(bot, target, directCorner);
			const u16 chosenDirt = AIB_CountDirtOnStoneRoute(bot, target, chosen);
			bot.set_Vec2f("ai builder tile target", target);
			bot.set_Vec2f("ai builder stone route corner", chosen);
			Vec2f onRouteDirt = Vec2f(284 * map.tilesize, 58 * map.tilesize);
			Vec2f offRouteDirt = Vec2f(282 * map.tilesize, 58 * map.tilesize);
			const bool choseReusable = Maths::Floor(chosen.x / map.tilesize) == 284;
			const bool lowerDirt = chosenDirt < directDirt;
			const bool onRouteAllowed = !AIB_ShouldAvoidDirtClearance(bot, target, onRouteDirt);
			const bool offRouteRejected = AIB_ShouldAvoidDirtClearance(bot, target, offRouteDirt);
			const bool invalidSolidsRejected = !AIB_IsStoneRouteTraversable(bot, target, bedrockCorner) &&
				!AIB_IsStoneRouteTraversable(bot, target, structureCorner) &&
				!AIB_CanMineStoneRouteClearance(bot, target, Vec2f(286 * map.tilesize, 58 * map.tilesize)) &&
				!AIB_CanMineStoneRouteClearance(bot, target, Vec2f(290 * map.tilesize, 58 * map.tilesize));
			const bool rightEntryCanonical = AIB_GetStoneRouteEntryX(283, 284, targetX) == 284;
			const bool leftEntryCanonical = AIB_GetStoneRouteEntryX(287, 286, 280) == 285;
			const bool surfaceApproachValid = AIB_HasClearStoneRouteApproach(bot, target, chosen);
			const bool blockedSurfaceRejected = !AIB_HasClearStoneRouteApproach(bot, target, inaccessibleCorner);
			const bool emptyNeverBlocks = !AIB_IsNonMineableStoneRouteBlock(Vec2f(284 * map.tilesize, 53 * map.tilesize));
			const bool dedicatedMovementOnlyForTunnel = AIB_UsesDedicatedStoneRouteMovement(AIBT_JOB_STONE, AIBT_TUNNEL_TO_STONE) &&
				!AIB_UsesDedicatedStoneRouteMovement(AIBT_JOB_STONE, AIBT_FIND_STONE) &&
				!AIB_UsesDedicatedStoneRouteMovement(AIBT_JOB_WOOD, AIBT_TUNNEL_TO_STONE);
			const bool staticPassed = choseReusable && lowerDirt && onRouteAllowed && offRouteRejected &&
				invalidSolidsRejected && rightEntryCanonical && leftEntryCanonical && surfaceApproachValid &&
				blockedSurfaceRejected && emptyNeverBlocks && dedicatedMovementOnlyForTunnel;
			getRules().set_bool("aibt stone route static passed", staticPassed);
			getRules().set_string("aibt stone route static details",
				"reusable_shaft_x=284 direct_dirt=" + directDirt + " chosen_dirt=" + chosenDirt +
					" on_route_allowed=true off_route_rejected=true invalid_solids_rejected=true mirrored_entries_canonical=true" +
					" clear_surface_approach=true blocked_surface_rejected=true empty_never_blocks=true generic_jump_suppressed=true");
			getRules().set_string("aibt stone route static failure",
				"stone_route_policy_failed chosen_x=" + Maths::Floor(chosen.x / map.tilesize) +
					" direct_dirt=" + directDirt + " chosen_dirt=" + chosenDirt +
					" on_route=" + (onRouteAllowed ? "true" : "false") + " off_route=" + (offRouteRejected ? "true" : "false") +
					" invalid_solids=" + (invalidSolidsRejected ? "true" : "false") +
					" right_entry=" + (rightEntryCanonical ? "true" : "false") + " left_entry=" + (leftEntryCanonical ? "true" : "false") +
					" surface_approach=" + (surfaceApproachValid ? "true" : "false") +
					" blocked_surface=" + (blockedSurfaceRejected ? "true" : "false") +
					" empty_block=" + (emptyNeverBlocks ? "false" : "true"));
			bot.set_u8("ai builder job", AIBT_JOB_STONE);
			bot.set_u8("ai builder state", AIBT_TUNNEL_TO_STONE);
			bot.set_bool("ai builder mining gold", false);
			break;
		}

		case 47:
		{
			AIBT_SpawnTentTeam(200, 0);
			AIBT_SpawnTentTeam(340, 1);
			@bot = AIBT_SpawnBotTeam(206, 0);
			AIBT_DisableStarterMaterials(bot);
			CRules@ rules = getRules();
			for (u8 team = 0; team < 3; team++)
			{
				rules.set_bool(AIBS_BootstrapKey(team, "enabled"), true);
				rules.set_bool(AIBS_BootstrapKey(team, "provisioned"), false);
				rules.set_u32(AIBS_BootstrapKey(team, "next retry"), 0);
				rules.set_u32("aib strategy last replan team " + int(team), 0);
				rules.set_u32("aib strategy important event team " + int(team), getGameTime());
			}
			rules.set_u8(AIBP_ModeKey(0), AIBP_StrategyMode::auto_mode);
			rules.set_u8(AIBP_ModeKey(1), AIBP_StrategyMode::suggest);
			rules.set_u8(AIBP_ModeKey(2), AIBP_StrategyMode::auto_mode);
			rules.set_u8("aib strategy last mode team 0", AIBP_StrategyMode::off);
			rules.set_u8("aib strategy last mode team 1", AIBP_StrategyMode::off);
			rules.set_u8("aib strategy last mode team 2", AIBP_StrategyMode::off);
			break;
		}

		case 48:
		{
			AIBT_SpawnTent(260);
			CBlob@ crate = AIBT_Spawn("crate", 0, AIBT_Pos(272, AIBT_GROUND_Y - 2));
			if (crate !is null) crate.Tag("aibuilder resource crate");
			AIBT_GiveMaterial(crate, "mat_wood", 600);
			AIBT_GiveMaterial(crate, "mat_stone", 600);
			CRules@ rules = getRules();
			rules.set_bool(AIBS_BootstrapKey(0, "enabled"), true);
			rules.set_bool(AIBS_BootstrapKey(0, "provisioned"), false);
			rules.set_u32(AIBS_BootstrapKey(0, "next retry"), 0);
			rules.set_u8(AIBP_ModeKey(0), AIBP_StrategyMode::auto_mode);
			rules.set_u8("aib strategy last mode team 0", AIBP_StrategyMode::off);
			rules.set_u32("aib strategy last replan team 0", 0);
			rules.set_u32("aib strategy important event team 0", getGameTime());
			break;
		}

		case 49:
		{
			const int homeX = 48;
			const int stoneX = 66;
			const int stoneY = AIBT_GROUND_Y - 1;
			AIBT_SpawnTent(homeX);
			// Production storage is centred nine tiles left of the home.  Keep the
			// acceptance crate in that zone so this exercises the same delivery
			// contract used in normal CTF play.
			CBlob@ crate = AIBT_Spawn("crate", 0, AIBT_Pos(homeX - 7, AIBT_GROUND_Y - 2));
			if (crate !is null) crate.Tag("aibuilder resource crate");
			@bot = AIBT_SpawnBot(homeX + 10);
			AIBT_DisableStarterMaterials(bot);
			AIBT_SetTemporaryTile(stoneX, stoneY, CMap::tile_stone);
			array<Vec2f> selectedStone = { Vec2f(stoneX, stoneY) };
			getRules().set("aibuilder selected stone tiles", selectedStone);
			AIBT_StartStone(bot);
			break;
		}

		case 50:
		{
			// Keep focused gym fixtures inside the visible, grounded left arena.
			const int startX = 60;
			AIBT_SpawnTent(startX - 12);
			CBlob@ crate = AIBT_Spawn("crate", 0, AIBT_Pos(startX - 21, AIBT_GROUND_Y - 2));
			if (crate !is null) crate.Tag("aibuilder resource crate");
			@bot = AIBT_SpawnBot(startX);
			AIBT_DisableStarterMaterials(bot);
			CBlob@ tree = AIBT_SpawnTree(startX + 18, true);
			AIBT_SetBlob("aibt_expected", tree);
			getRules().set_Vec2f("aibt gym movement origin", bot.getPosition());
			AIBT_StartHarvest(bot);
			break;
		}

		case 51:
		{
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(64);
			AIBT_DisableStarterMaterials(bot);
			AIBT_GiveMaterial(bot, "mat_stone", 100);
			// The requested foreground block is two cells above a solid anchor.
			// Row 70 must become generated stone backwall support first.
			AIBT_SetTemporaryTile(68, AIBT_GROUND_Y - 1, CMap::tile_castle);
			AIBP_SetHumanTile(0, 68, AIBT_GROUND_Y - 3, AIBP_STONE_BLOCK);
			AIBT_StartBlueprint(bot, false);
			break;
		}

		case 52:
		{
			const int homeX = 100;
			AIBT_SpawnTent(homeX);
			CBlob@ fullCrate = AIBT_Spawn("crate", 0, AIBT_Pos(homeX - 9, AIBT_GROUND_Y - 2));
			if (fullCrate !is null)
			{
				fullCrate.Tag("aibuilder resource crate");
				fullCrate.Tag("aibuilder full resource crate");
			}
			const u16 initialWood = AIBT_FillCrateWithWood(fullCrate);
			getRules().set_u16("aibt overflow initial wood", initialWood);
			CBlob@ shop = AIBT_Spawn("buildershop", 0, AIBT_Pos(homeX + 18, AIBT_GROUND_Y - 3));
			if (shop !is null) shop.Tag("aibuilder built storage shop");
			@bot = AIBT_SpawnBot(homeX);
			AIBT_DisableStarterMaterials(bot);
			AIBT_GiveMaterial(bot, "mat_stone", 100);
			bot.set_u8("ai builder job", AIBT_JOB_STONE);
			AIBT_ForceState(bot, AIBT_RETURN_WOOD);
			break;
		}

		case 53:
		{
			const int x = 68;
			const int y = AIBT_GROUND_Y - 2;
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(64);
			AIBT_DisableStarterMaterials(bot);
			AIBT_GiveMaterial(bot, "mat_wood", 50);
			AIBT_SetTemporaryTile(x, y + 1, CMap::tile_castle);
			AIBT_SetTemporaryTile(x - 1, y, CMap::tile_castle);
			AIBT_SetTemporaryTile(x, y, CMap::tile_wood);
			BlueprintPlan@ plan = AIBT_NewStrategicPlan(0, "physical_repair_test");
			BlueprintTask@ task = BlueprintTask(x, y, AIBP_WOOD_BLOCK, AIBP_Phase::shell);
			task.state = AIBP_TaskState::completed;
			plan.tasks.push_back(task);
			AIBP_PublishAIPlan(plan, true);
			getMap().server_SetTile(AIBT_Pos(x, y), CMap::tile_wood_d1);
			AIBP_RefreshPlanState(0, true);
			AIBT_StartBlueprint(bot, false);
			break;
		}

		case 54:
		{
			AIBT_SpawnTentTeam(54, 0);
			AIBT_SpawnTentTeam(366, 1);
			break;
		}

		case 55:
		{
			AIBT_SpawnTentTeam(382, 0);
			AIBT_SpawnTentTeam(54, 1);
			// Block the primary inward gatehouse anchor with a two-high terrain
			// step. Production validation must reject it and select another safe
			// candidate on this near-edge approach.
			AIBT_SetTemporaryTile(372, AIBT_GROUND_Y - 1, CMap::tile_castle);
			AIBT_SetTemporaryTile(372, AIBT_GROUND_Y - 2, CMap::tile_castle);
			break;
		}

		case 56:
		{
			AIBT_SpawnTentTeam(54, 0);
			AIBT_SpawnTentTeam(366, 1);
			break;
		}

		case 57:
		{
			AIBT_SpawnTentTeam(100, 0);
			AIBT_SpawnTentTeam(366, 1);
			for (uint i = 0; i < 6; i++) AIBT_Spawn("knight", 1, AIBT_Pos(118 + int(i * 2), AIBT_GROUND_Y - 2));
			break;
		}

		case 58:
		{
			const u16 x = 78;
			const u16 y = AIBT_GROUND_Y - 1;
			AIBT_SpawnTentTeam(366, 1);
			AIBT_SpawnTentTeam(54, 0);
			AIBT_SetTemporaryTile(x, y, CMap::tile_wood);
			AIBT_SetTemporaryTile(x + 1, y, CMap::tile_castle);
			AIBT_SetTemporaryTile(x + 2, y, CMap::tile_wood);
			BlueprintPlan@ plan = AIBT_NewStrategicPlan(0, "damaged_front_fixture");
			plan.anchor = Vec2f(x + 1, y + 1);
			BlueprintTask@ woodDamaged = BlueprintTask(x, y, AIBP_WOOD_BLOCK, AIBP_Phase::shell);
			BlueprintTask@ stoneDamaged = BlueprintTask(x + 1, y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
			BlueprintTask@ woodHealthy = BlueprintTask(x + 2, y, AIBP_WOOD_BLOCK, AIBP_Phase::shell);
			woodDamaged.state = AIBP_TaskState::completed;
			stoneDamaged.state = AIBP_TaskState::completed;
			woodHealthy.state = AIBP_TaskState::completed;
			plan.tasks.push_back(woodDamaged);
			plan.tasks.push_back(stoneDamaged);
			plan.tasks.push_back(woodHealthy);
			const bool published = AIBP_PublishAIPlan(plan, true);
			getRules().set_u16("aibt damaged front plan id", plan.id);
			getRules().set_u16("aibt damaged front plan version", plan.version);
			getRules().set_bool("aibt damaged front setup", published);
			if (published)
			{
				getMap().server_SetTile(AIBT_Pos(x, y), CMap::tile_wood_d1);
				getMap().server_SetTile(AIBT_Pos(x + 1, y), CMap::tile_castle_d1);
				AIBP_RefreshPlanState(0, true);
			}
			break;
		}

		case 59:
		{
			AIBT_SpawnTentTeam(366, 1);
			AIBT_SpawnTentTeam(54, 0);
			@bot = AIBT_Spawn("autobuilder", 0, AIBT_Pos(60, AIBT_GROUND_Y - 3));
			AIBT_SetBlob("aibt_bot", bot);
			AIBWorldState@ world = AIBS_ObserveWorld(0);
			AIBPlanCandidate@ candidate = AIBS_SelectCandidate(world);
			BlueprintPlan@ plan = candidate is null ? null : AIBS_MakePlan(world, candidate);
			const bool routeSafe = candidate !is null && AIBS_PreservesFriendlyRoute(candidate);
			const bool published = bot !is null && plan !is null && routeSafe && AIBP_PublishAIPlan(plan, true);
			u16 initialCompleted = 0;
			if (plan !is null)
			{
				for (uint i = 0; i < plan.tasks.length; i++)
				{
					BlueprintTask@ task = plan.tasks[i];
					if (task !is null && task.state == AIBP_TaskState::completed) initialCompleted++;
				}
			}
			getRules().set_bool("aibt physical plan setup", published);
			getRules().set_bool("aibt physical plan route safe", routeSafe);
			getRules().set_bool("aibt physical plan progress observed", false);
			getRules().set_u16("aibt physical plan id", plan is null ? 0 : plan.id);
			getRules().set_u16("aibt physical plan version", plan is null ? 0 : plan.version);
			getRules().set_u16("aibt physical plan tasks", plan is null ? 0 : u16(plan.tasks.length));
			getRules().set_u16("aibt physical plan initial completed", initialCompleted);
			getRules().set_string("aibt physical plan template", candidate is null ? "none" : candidate.templateName);
			getRules().set_string("aibt physical plan reasons", candidate is null ? "none" : candidate.reasons);
			if (published)
			{
				AIBWorldState@ assignedWorld = AIBS_ObserveWorld(0);
				AIBS_AssignBuilders(assignedWorld);
			}
			break;
		}

		case 60:
		{
			const int homeX = 220;
			const int leftPocketX = 208;
			const int rightPocketX = 232;
			const int pocketTop = AIBT_GROUND_Y - 7;
			const int pocketFloor = AIBT_GROUND_Y - 4;
			const int pocketBodyY = pocketFloor - 1;
			const int openX = homeX - AIBS_BOOTSTRAP_MIN_HOME_DISTANCE;

			// Normalize one broad surface arena and build two mirrored pockets.
			// Each pocket contains a locally clear three-column/two-tile spawn
			// envelope with solid ground, but its castle shell has no terrain
			// connection to the home surface.
			for (int x = homeX - 30; x <= homeX + 30; x++)
			{
				for (int y = AIBT_GROUND_Y - 8; y <= AIBT_GROUND_Y; y++)
				{
					u16 type = y == AIBT_GROUND_Y ? CMap::tile_ground : CMap::tile_empty;
					for (int side = -1; side <= 1; side += 2)
					{
						const int centerX = side < 0 ? leftPocketX : rightPocketX;
						const bool withinPocket = x >= centerX - 2 && x <= centerX + 2 && y >= pocketTop && y <= pocketFloor;
						const bool shell = withinPocket && (y == pocketTop || y == pocketFloor || x == centerX - 2 || x == centerX + 2);
						if (shell) type = CMap::tile_castle;
					}
					AIBT_SetTemporaryTile(x, y, type);
				}
			}

			CBlob@ home = AIBT_SpawnTent(homeX);
			AIBWorldState@ world = AIBWorldState();
			world.team = 0;
			world.home = home is null ? Vec2f_zero : home.getPosition();
			world.enemyDirection = 1;
			array<Vec2f> blockerMins;
			array<Vec2f> blockerMaxs;
			AIBS_CollectBootstrapBlockers(blockerMins, blockerMaxs);
			AIBBootstrapReachability@ reachability = AIBS_BuildBootstrapReachability(world);
			Vec2f leftPocket = AIBT_Pos(leftPocketX, pocketBodyY);
			Vec2f rightPocket = AIBT_Pos(rightPocketX, pocketBodyY);
			Vec2f openSurface = AIBT_Pos(openX, AIBT_GROUND_Y - 1);

			const bool leftEnvelope = AIBS_IsBootstrapSpawnEnvelopeSafe(world, leftPocket, blockerMins, blockerMaxs);
			const bool rightEnvelope = AIBS_IsBootstrapSpawnEnvelopeSafe(world, rightPocket, blockerMins, blockerMaxs);
			const bool leftConnected = AIBS_BootstrapReachable(reachability, leftPocket);
			const bool rightConnected = AIBS_BootstrapReachable(reachability, rightPocket);
			const bool leftRejected = !AIBS_IsSafeBootstrapSpawn(world, leftPocket, blockerMins, blockerMaxs, reachability);
			const bool rightRejected = !AIBS_IsSafeBootstrapSpawn(world, rightPocket, blockerMins, blockerMaxs, reachability);
			const bool openAccepted = AIBS_IsSafeBootstrapSpawn(world, openSurface, blockerMins, blockerMaxs, reachability);
			Vec2f selected = AIBS_FindBootstrapSpawn(world);
			const int selectedX = selected == Vec2f_zero ? -1 : Maths::Floor(selected.x / getMap().tilesize);
			const int selectedY = selected == Vec2f_zero ? -1 : Maths::Floor(selected.y / getMap().tilesize);
			const bool selectedOutsidePockets = selectedX < leftPocketX - 1 || selectedX > leftPocketX + 1;
			const bool selectedOutsideRightPocket = selectedX < rightPocketX - 1 || selectedX > rightPocketX + 1;
			const bool selectedReachable = selected != Vec2f_zero && AIBS_BootstrapReachable(reachability, selected);
			const bool passed = home !is null && reachability !is null && reachability.seeded && leftEnvelope && rightEnvelope &&
				!leftConnected && !rightConnected && leftRejected && rightRejected && openAccepted &&
				selectedReachable && selectedOutsidePockets && selectedOutsideRightPocket;
			AIBT_SetStrategicResult(passed,
				"sealed_envelopes_clear=true mirrored_sealed_rejected=true open_surface_accepted=true selected_reachable=true selected=" + selectedX + "," + selectedY,
				"bootstrap_connectivity_failed seeded=" + (reachability !is null && reachability.seeded ? "true" : "false") +
					" left_envelope=" + (leftEnvelope ? "true" : "false") + " right_envelope=" + (rightEnvelope ? "true" : "false") +
					" left_connected=" + (leftConnected ? "true" : "false") + " right_connected=" + (rightConnected ? "true" : "false") +
					" left_rejected=" + (leftRejected ? "true" : "false") + " right_rejected=" + (rightRejected ? "true" : "false") +
					" open_accepted=" + (openAccepted ? "true" : "false") + " selected=" + selectedX + "," + selectedY +
					" selected_reachable=" + (selectedReachable ? "true" : "false"));
			break;
		}

		case 61:
		{
			AIBT_SetupRepresentativeFallback(AIBT_FALLBACK_NO_BUILD);
			break;
		}

		case 62:
		{
			AIBT_SetupRepresentativeFallback(AIBT_FALLBACK_OCCUPIED);
			break;
		}

		case 63:
		{
			AIBT_SetupRepresentativeFallback(AIBT_FALLBACK_BARRIER);
			break;
		}

		case 64:
		{
			const int[] homeXs = { 100, 320 };
			AIBT_SpawnTentTeam(homeXs[0], 0);
			AIBT_SpawnTentTeam(homeXs[1], 1);
			CRules@ rules = getRules();
			bool plansPublished = rules !is null;
			for (u8 team = 0; team < 2 && rules !is null; team++)
			{
				rules.set_bool(AIBS_BootstrapKey(team, "enabled"), true);
				rules.set_bool(AIBS_BootstrapKey(team, "provisioned"), false);
				rules.set_u32(AIBS_BootstrapKey(team, "next retry"), 0);
				rules.set_u8(AIBP_ModeKey(team), AIBP_StrategyMode::auto_mode);
				rules.set_u8("aib strategy last mode team " + team, AIBP_StrategyMode::auto_mode);
				rules.set_u32("aib strategy last replan team " + team, getGameTime());
				rules.set_u32("aib strategy important event team " + team, 0);
				BlueprintPlan@ plan = AIBT_NewStrategicPlan(team, "bootstrap_round_reset_fixture");
				plan.anchor = Vec2f(homeXs[team] + (team == 0 ? 30 : -30), AIBT_GROUND_Y);
				plan.tasks.push_back(BlueprintTask(u16(plan.anchor.x), AIBT_GROUND_Y - 1, AIBP_WOOD_BACKWALL, AIBP_Phase::foundation));
				plansPublished = AIBP_PublishAIPlan(plan, true) && plansPublished;
			}
			const bool leftPassed = plansPublished && AIBT_ExerciseBootstrapRoundReset(0, homeXs[0]);
			const bool rightPassed = plansPublished && AIBT_ExerciseBootstrapRoundReset(1, homeXs[1]);
			rules.set_bool("aibt bootstrap lifecycle plans", plansPublished);
			rules.set_bool("aibt bootstrap lifecycle setup", leftPassed && rightPassed);
			AIBT_SetBlob("aibt_bot", AIBT_GetBootstrapWorker(0));
			break;
		}

	}
}

bool AIBT_EvaluateScenario(const int index, const u32 elapsed, string &out failure, string &out details)
{
	CBlob@ bot = AIBT_GetBlob("aibt_bot");
	CBlob@ tent = AIBT_GetBlob("aibt_tent");
	CBlob@ expected = AIBT_GetBlob("aibt_expected");
	details = "";
	failure = "";
	const string canonicalResetFailure = getRules().get_string("aibt canonical reset failure");
	if (canonicalResetFailure != "")
	{
		failure = "canonical_fixture_reset_failed " + canonicalResetFailure;
		return true;
	}
	// Observe production-created shops before DefaultNoBuild paints their
	// background so cleanup can restore the exact pre-shop fixture tiles.
	AIBT_TrackWorkshopBackgrounds(AIBT_GROUND_Y);

	if (bot is null && index != 18 && index != 48 && index != 54 && index != 55 && index != 56 && index != 57 && index != 58 && index != 60 && index != 64)
	{
		failure = "bot_missing";
		return true;
	}
	if (!AIBT_MapFixtureIntact(failure))
	{
		return true;
	}
	if (bot !is null && bot.getPosition().y > (AIBT_GROUND_Y + 8) * 8)
	{
		failure = "bot_fell_below_fixture_floor " + AIBT_DescribeBuilder(bot);
		return true;
	}
	if (bot !is null && bot.get_u16("aib gym failure flags") != AIBG_FAILURE_NONE)
	{
		const u32 failureTick = bot.get_u32("aib gym failure tick");
		if (!bot.get_bool("aib gym diagnostic emitted") && getGameTime() < failureTick + AIBG_POST_TICKS + AIBG_OUTCOME_SAMPLE_TICKS)
			return false;
		failure = "gym_progress_violation " + bot.get_string("aib gym failure detail") + " " + AIBT_DescribeBuilder(bot);
		return true;
	}

	switch (index)
	{
		case 0:
		{
			if (tent !is null && AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f) > 0)
			{
				string shopDetails;
				if (!AIBT_HasValidGroundedBuilderShop(tent, shopDetails))
				{
					failure = "invalid_storage_workshop " + shopDetails;
					return true;
				}
				details = "wood_in_crates=" + AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f) +
					" crates=" + AIBT_CountBlobsNear("crate", tent.getPosition(), 140.0f) +
					" buildershops=" + AIBT_CountBlobsNear("buildershop", tent.getPosition(), 140.0f) + " " + shopDetails;
				return true;
			}
			if (elapsed > 900)
			{
				failure = "timeout " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 1:
		{
			if (tent !is null && AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f) > 0 && AIBT_CountInventoryMaterial(bot, "mat_wood") == 0)
			{
				string shopDetails;
				if (!AIBT_HasValidGroundedBuilderShop(tent, shopDetails))
				{
					failure = "invalid_storage_workshop " + shopDetails;
					return true;
				}
				details = "wood_in_crates=" + AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f) +
					" crates=" + AIBT_CountBlobsNear("crate", tent.getPosition(), 140.0f) +
					" buildershops=" + AIBT_CountBlobsNear("buildershop", tent.getPosition(), 140.0f) + " " + shopDetails;
				return true;
			}
			if (elapsed > 900)
			{
				failure = "timeout " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 2:
		{
			CBlob@ target = getBlobByNetworkID(bot.get_netid("ai builder target"));
			if (target !is null && elapsed >= 3)
			{
				if (target !is expected)
				{
					failure = "wrong_gloryhill_tree_target expected=" + AIBT_BlobRef(expected) + " actual=" + AIBT_BlobRef(target);
				}
				else if (bot.get_bool("ai builder justgo"))
				{
					failure = "gloryhill_uphill_route_used_direct_shortcut " + AIBT_DescribeBuilder(bot);
				}
				else
				{
					details = "target=" + AIBT_BlobRef(target) + " pathfinder_route=true";
				}
				return true;
			}
			if (elapsed > 60)
			{
				failure = "timeout_gloryhill_route " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 3:
		case 4:
		case 5:
		case 6:
		case 7:
		case 8:
		case 10:
		{
			if ((index == 6 || index == 7 || index == 8) && bot.get_u8("ai builder state") == AIBT_IDLE)
			{
				if (elapsed < 2) return false;
				AIBT_StartHarvest(bot);
				return false;
			}

			CBlob@ target = getBlobByNetworkID(bot.get_netid("ai builder target"));
			if (target !is null)
			{
				if (target is expected)
				{
					details = "target=" + AIBT_BlobRef(target);
				}
				else
				{
					failure = "wrong_target expected=" + AIBT_BlobRef(expected) + " actual=" + AIBT_BlobRef(target);
				}
				return true;
			}
			if (elapsed > 240)
			{
				failure = "timeout_no_target " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 9:
		{
			if (bot.get_u8("ai builder state") == AIBT_CHOP_TREE && bot.get_netid("ai builder target") == 0)
			{
				details = "flee_cleared_target=true";
				return true;
			}
			if (elapsed > 300)
			{
				CBlob@ target = getBlobByNetworkID(bot.get_netid("ai builder target"));
				if (target is null)
				{
					details = "target_cleared=true";
				}
				else
				{
					failure = "knight_did_not_clear_target " + AIBT_DescribeBuilder(bot);
				}
				return true;
			}
			break;
		}

		case 11:
		{
			CBlob@ target = getBlobByNetworkID(bot.get_netid("ai builder target"));
			if (target is expected && (bot.getPosition().x > 318 * 8 || bot.get_Vec2f("ai builder destination") != Vec2f_zero))
			{
				details = "reached_obstacle_area=true " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 1200)
			{
				failure = "timeout_pathing " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 12:
		{
			if (bot.get_u8("ai builder state") == AIBT_RETURN_WOOD)
			{
				const u16 wood = AIBT_CountInventoryMaterial(bot, "mat_wood");
				if (wood >= 120)
				{
					details = "resource_retained=true waiting_for_home=true inv_wood=" + wood;
				}
				else
				{
					failure = "resource_was_dropped_or_lost " + AIBT_DescribeBuilder(bot);
				}
				return true;
			}
			if (elapsed > 240)
			{
				failure = "timeout_no_home " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 13:
		{
			if (AIBT_CountSelectedTrees() != 1)
			{
				failure = "selection_toggle_did_not_select count=" + AIBT_CountSelectedTrees();
				return true;
			}

			CBlob@ target = getBlobByNetworkID(bot.get_netid("ai builder target"));
			if (target !is null)
			{
				if (target !is expected)
				{
					failure = "wrong_target_after_ui_toggle expected=" + AIBT_BlobRef(expected) + " actual=" + AIBT_BlobRef(target);
					return true;
				}

				details = "selected_filter_target=" + AIBT_BlobRef(target);
				return true;
			}

			if (elapsed > 240)
			{
				failure = "timeout_ui_selection " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 14:
		{
			CBlob@ target = getBlobByNetworkID(bot.get_netid("ai builder target"));
			if (target is expected && elapsed >= 10)
			{
				const f32 startX = 158 * 8 + 4;
				if (bot.getPosition().x < startX - 12.0f && bot.get_Vec2f("ai builder destination") != Vec2f_zero)
				{
					details = "moved_toward_hill_tree=true " + AIBT_DescribeBuilder(bot);
					return true;
				}
			}
			if (elapsed > 360)
			{
				failure = "timeout_hill_movement " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 15:
		{
			CMap@ map = getMap();
			const bool plugCleared = map !is null && !map.isTileSolid(map.getTile(AIBT_Pos(352, AIBT_GROUND_Y - 2)).type);
			const bool ladderBuilt = AIBT_CountBlobsNear("ladder", AIBT_Pos(349, AIBT_GROUND_Y - 5), 96.0f) > 0;
			const bool reachedTargetSide = bot.getPosition().x > 352 * 8;
			if (plugCleared || ladderBuilt || reachedTargetSide)
			{
				details = "supported_recovery=" + (ladderBuilt ? "ladder" : (plugCleared ? "mined" : "reached_target_side")) + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 300)
			{
				failure = "timeout_supported_ladder_chain " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 16:
		{
			CRules@ rules = getRules();
			CBlob@ crate = expected;
			AIBT_RecordBlueprintSceneDelta(bot, crate);
			const u16 crateWood = AIBT_CountInventoryMaterial(crate, "mat_wood");
			const u16 crateStone = AIBT_CountInventoryMaterial(crate, "mat_stone");
			if (crate !is null && (crateWood < 80 || AIBT_CountInventoryMaterial(bot, "mat_wood") > 0))
				rules.set_bool("aibt blueprint crate wood withdrawn", true);
			if (crate !is null && (crateStone < 80 || AIBT_CountInventoryMaterial(bot, "mat_stone") > 0))
				rules.set_bool("aibt blueprint crate stone withdrawn", true);
			const bool stoneBuilt = AIBT_BlueprintTileBuilt(394, AIBT_GROUND_Y - 1, CMap::tile_castle);
			const bool woodBuilt = AIBT_BlueprintTileBuilt(395, AIBT_GROUND_Y - 1, CMap::tile_wood);
			const u16 totalWood = AIBT_CountAllLiveMaterial("mat_wood");
			const u16 totalStone = AIBT_CountAllLiveMaterial("mat_stone");
			const bool conserved = totalWood == 80 - AIBP_BlockCost(AIBP_WOOD_BLOCK) &&
				totalStone == 80 - AIBP_BlockCost(AIBP_STONE_BLOCK);
			if (rules.get_bool("aibt blueprint crate wood withdrawn") && rules.get_bool("aibt blueprint crate stone withdrawn") &&
				crate !is null && stoneBuilt && woodBuilt && conserved &&
				AIBT_CountInventoryMaterial(bot, "mat_wood") >= 60 && AIBT_CountInventoryMaterial(bot, "mat_stone") >= 60)
			{
				details = "base_crate_materials_withdrawn=true stone_built=true wood_built=true material_conserved=true remaining_wood=" +
					totalWood + " remaining_stone=" + totalStone + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 300)
			{
				failure = "timeout_blueprint_base_crate wood_withdrawn=" + (rules.get_bool("aibt blueprint crate wood withdrawn") ? "true" : "false") +
					" stone_withdrawn=" + (rules.get_bool("aibt blueprint crate stone withdrawn") ? "true" : "false") +
					" crate=" + (crate is null ? "missing" : "present") + " crate_wood=" + crateWood + " crate_stone=" + crateStone +
					" total_wood=" + totalWood + " total_stone=" + totalStone + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 17:
		{
			CRules@ rules = getRules();
			if (rules !is null && rules.get_u8("aibt_pipeline_stage") == 0 && elapsed >= 20)
			{
				AIBT_SetSingleBlueprintTile(68, AIBT_GROUND_Y - 1, 48);
				rules.set_u8("aibt_pipeline_stage", 1);
			}

			Vec2f targetTile = bot.get_Vec2f("ai builder tile target");
			const bool targetAcquired = bot.get_u8("ai builder state") == AIBT_BUILD_BLUEPRINT_BLOCK &&
				Maths::Abs(targetTile.x - 68 * 8) < 1.0f &&
				Maths::Abs(targetTile.y - (AIBT_GROUND_Y - 1) * 8) < 1.0f;
			if (targetAcquired)
			{
				details = "late_blueprint_target_acquired=true " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (rules !is null && rules.get_u8("aibt_pipeline_stage") == 1 &&
				elapsed >= 40 && bot.get_u8("ai builder state") == AIBT_FIND_BLUEPRINT_BLOCK)
			{
				details = "late_blueprint_waiting_for_scan=true " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 120)
			{
				failure = "timeout_late_blueprint " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 18:
		{
			CRules@ rules = getRules();
			if (rules is null)
			{
				failure = "director_rules_missing";
				return true;
			}

			const u8 stage = rules.get_u8("aibt director stage");
			if (stage == 0 && rules.get_u16(AIBP_PlanKey(0, "id")) != 0)
			{
				const u16 desired = AIBT_CountLayerTiles(0, AIBP_Layer::ai_desired);
				const u16 work = AIBT_CountLayerTiles(0, AIBP_Layer::ai_work);
				const string templateName = rules.get_string(AIBP_PlanKey(0, "template"));
				const string reasons = rules.get_string(AIBP_PlanKey(0, "reasons"));
				const u32 setupTick = rules.get_u32("aibt director setup tick");
				const bool productionPlan = rules.get_bool("aibt director defaults valid") && desired > 0 && work == desired &&
					AIBT_LayerIsEmpty(0, AIBP_Layer::human) && templateName != "" && templateName != "mode_test" &&
					reasons.find("defense=") >= 0 && rules.get_u32(AIBP_PlanKey(0, "created")) >= setupTick &&
					rules.get_u32("aib strategy last replan team 0") >= setupTick;
				if (!productionPlan)
				{
					failure = "director_plan_invalid defaults=" + (rules.get_bool("aibt director defaults valid") ? "true" : "false") +
						" desired=" + desired + " work=" + work + " human_empty=" + (AIBT_LayerIsEmpty(0, AIBP_Layer::human) ? "true" : "false") +
						" template=" + templateName + " reasons=" + reasons;
					return true;
				}

				// The plan was selected and activated with no AI builders present.
				// Production bootstrap provisioning must now create and assign the
				// first worker; the test does not spawn or fund a bot directly.
				rules.set_bool("aibt director plan valid", true);
				rules.set_u8("aibt director stage", 1);
				return false;
			}

			if (stage == 1)
			{
				u16 assigned = 0; u16 woodJobs = 0; u16 stoneJobs = 0; u16 buildJobs = 0;
				AIBT_CountStrategyAssignments(0, assigned, woodJobs, stoneJobs, buildJobs);
				const bool claimed = AIBT_HasDirectorTaskClaim(0);
				if (claimed) rules.set_bool("aibt director task claim observed", true);
				const bool claimObserved = rules.get_bool("aibt director task claim observed");
				const u16 completed = rules.get_u16(AIBP_PlanKey(0, "completed"));
				CBlob@ bootstrap = AIBT_GetBootstrapWorker(0);
				const bool oneSafeBootstrap = bootstrap !is null && AIBT_CountLiveTeamBuilders(0) == 1 &&
					AIBT_CountLiveTeamBuilders(0, true) == 1 && bootstrap.get_bool("aib strategy bootstrap worker") &&
					AIBT_BootstrapWorkerHasSafeGround(bootstrap) && rules.get_bool(AIBS_BootstrapKey(0, "provisioned"));
				if (rules.get_bool("aibt director plan valid") && oneSafeBootstrap && assigned == 1 && buildJobs == 1 && claimObserved && completed > 0)
				{
					details = "default_ctf_auto=true planned_without_builders=true auto_bootstrap=true safe_spawn=true one_time_count=1 template=" + rules.get_string(AIBP_PlanKey(0, "template")) +
						" desired=" + AIBT_CountLayerTiles(0, AIBP_Layer::ai_desired) + " assigned=" + assigned +
						" build_jobs=" + buildJobs + " task_claimed=true completed=" + completed;
					return true;
				}
			}

			if (elapsed > 240)
			{
				u16 assigned = 0; u16 woodJobs = 0; u16 stoneJobs = 0; u16 buildJobs = 0;
				AIBT_CountStrategyAssignments(0, assigned, woodJobs, stoneJobs, buildJobs);
				failure = "director_heartbeat_timeout stage=" + stage + " plan=" + rules.get_u16(AIBP_PlanKey(0, "id")) +
					" desired=" + AIBT_CountLayerTiles(0, AIBP_Layer::ai_desired) + " work=" + AIBT_CountLayerTiles(0, AIBP_Layer::ai_work) +
					" assigned=" + assigned + " build_jobs=" + buildJobs + " claimed=" + (AIBT_HasDirectorTaskClaim(0) ? "true" : "false") +
					" bootstrap=" + AIBT_CountLiveTeamBuilders(0, true) + " total_builders=" + AIBT_CountLiveTeamBuilders(0) +
					" completed=" + rules.get_u16(AIBP_PlanKey(0, "completed"));
				return true;
			}
			break;
		}

		case 19:
		{
			CBlob@ nursery = null;
			CBlob@[] nurseries;
			getBlobsByName("nursery", @nurseries);
			if (nurseries.length > 0) @nursery = nurseries[0];
			if (nursery !is null && AIBT_CountSeedsNear(nursery.getPosition(), 48.0f) > 0)
			{
				details = "seed_bought=true seeds=" + AIBT_CountSeedsNear(nursery.getPosition(), 48.0f) + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 240)
			{
				failure = "timeout_seed_purchase " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 20:
		{
			const s16 fuel = tent is null ? -1 : AIBT_GetQuarryFuelNear(tent.getPosition(), 160.0f);
			if (fuel >= 100)
			{
				details = "quarry_built=true quarry_fueled=true fuel=" + fuel;
				return true;
			}
			if (elapsed > 240)
			{
				failure = "timeout_quarry_build_or_fuel fuel=" + fuel + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 21:
		{
			if (AIBT_CountInventoryMaterial(bot, "mat_stone") > 0 || bot.get_u8("ai builder state") == AIBT_RETURN_WOOD)
			{
				details = "quarry_output_collected=true " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 240)
			{
				failure = "timeout_quarry_output_pickup " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 22:
		{
			CBlob@ second = AIBT_GetBlob("aibt_delayed_bot");
			if (bot !is null && bot.get_u8("ai builder state") != AIBT_RETURN_WOOD && AIBT_CountInventoryMaterial(bot, "mat_wood") == 0)
			{
				bot.set_u8("ai builder state", AIBT_IDLE);
				bot.set_u8("ai builder job", AIBT_JOB_BLUEPRINT);
			}
			if (second !is null && second.get_u8("ai builder state") != AIBT_RETURN_WOOD && AIBT_CountInventoryMaterial(second, "mat_wood") == 0)
			{
				second.set_u8("ai builder state", AIBT_IDLE);
				second.set_u8("ai builder job", AIBT_JOB_BLUEPRINT);
			}
			const u16 wood = tent is null ? 0 : AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 160.0f);
			if (second !is null && wood >= 260 &&
				AIBT_CountInventoryMaterial(bot, "mat_wood") == 0 &&
				AIBT_CountInventoryMaterial(second, "mat_wood") == 0)
			{
				details = "shared_crates=true builders=2 wood_in_crates=" + wood + " crates=" + AIBT_CountBlobsNear("crate", tent.getPosition(), 160.0f);
				return true;
			}
			if (elapsed > 420)
			{
				failure = "timeout_multibuilder_storage wood_in_crates=" + wood + " first=" + AIBT_DescribeBuilder(bot) +
					" second=" + AIBT_DescribeBuilder(second);
				return true;
			}
			break;
		}

		case 23:
		{
			if (elapsed >= 20 && bot.get_u8("ai builder state") == AIBT_FIND_STONE && bot.get_Vec2f("ai builder tile target") == Vec2f_zero)
			{
				details = "stone_job_still_retrying=true " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 120)
			{
				failure = "stone_job_stopped_retrying " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 24:
		{
			CBlob@[] nurseries;
			getBlobsByName("nursery", @nurseries);
			CBlob@[] seeds;
			getBlobsByName("seed", @seeds);
			bool planted = false;
			for (uint i = 0; i < seeds.length; i++)
			{
				CBlob@ seed = seeds[i];
				if (seed !is null && seed.hasTag("aibuilder planted seed")) planted = true;
			}
			if (nurseries.length > 0 && planted && bot.get_u8("ai builder state") == AIBT_NURSERY_WAIT_TREE)
			{
				details = "nursery_built=true seed_bought=true seed_planted=true " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 600)
			{
				failure = "timeout_nursery_quest nurseries=" + nurseries.length + " planted=" + (planted ? "true" : "false") + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 25:
		{
			CRules@ rules = getRules();
			Vec2f targetTile = bot.get_Vec2f("ai builder tile target");
			if (rules !is null && rules.get_u8("aibt_pipeline_stage") == 0)
			{
				if (targetTile != Vec2f_zero)
				{
					failure = "enemy_team_blueprint_leaked " + AIBT_DescribeBuilder(bot);
					return true;
				}
				if (elapsed >= 20 && bot.get_u8("ai builder state") == AIBT_FIND_BLUEPRINT_BLOCK)
				{
					AIBT_SetSingleBlueprintTileForTeam(0, 394, AIBT_GROUND_Y - 1, AIBP_PLATFORM, false);
					rules.set_u8("aibt_pipeline_stage", 1);
					return false;
				}
			}
			else if (rules !is null && rules.get_u8("aibt_pipeline_stage") == 1)
			{
				const bool targetAcquired = bot.get_u8("ai builder state") == AIBT_BUILD_BLUEPRINT_BLOCK &&
					Maths::Abs(targetTile.x - 394 * 8) < 1.0f &&
					Maths::Abs(targetTile.y - (AIBT_GROUND_Y - 1) * 8) < 1.0f;
				if (targetAcquired)
				{
					details = "enemy_team_blueprint_ignored=true own_team_blueprint_target_acquired=true " + AIBT_DescribeBuilder(bot);
					return true;
				}
			}

			if (elapsed > 120)
			{
				failure = "timeout_blueprint_team_isolation " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 36:
		{
			CBlob@ building = expected;
			if (building !is null && AIBT_ShopHasBlob(building, "nursery") && AIBT_ShopHasBlob(building, "quarry"))
			{
				details = "construction_menu_has_nursery=true construction_menu_has_quarry=true";
				return true;
			}
			if (elapsed > 30)
			{
				failure = "construction_menu_missing_items nursery=" + (building !is null && AIBT_ShopHasBlob(building, "nursery") ? "true" : "false") +
					" quarry=" + (building !is null && AIBT_ShopHasBlob(building, "quarry") ? "true" : "false");
				return true;
			}
			break;
		}

		case 26:
		case 27:
		case 28:
		case 29:
		case 30:
		case 31:
		case 32:
		case 33:
		case 37:
		case 38:
		case 39:
		case 40:
		case 41:
		case 60:
		{
			const bool passed = getRules().get_bool("aibt strategic result");
			details = getRules().get_string("aibt strategic details");
			if (!passed) failure = getRules().get_string("aibt strategic failure");
			return true;
		}

		case 35:
		{
			if (AIBT_CountBlobsNear("wooden_platform", AIBT_Pos(394, AIBT_GROUND_Y - 1), 12.0f) > 0)
			{
				details = "wooden_platform_built=true over_backwall=true";
				return true;
			}
			if (elapsed > 240)
			{
				failure = "timeout_platform " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 34:
		{
			if (AIBT_CountBlobsNear("wooden_door", AIBT_Pos(394, AIBT_GROUND_Y - 1), 12.0f) > 0)
			{
				details = "wooden_door_built=true";
				return true;
			}
			if (elapsed > 240)
			{
				failure = "timeout_wooden_door " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 43:
		{
			CRules@ rules = getRules();
			CBlob@ mirror = expected;
			if (mirror is null)
			{
				failure = "corner_mirror_missing";
				return true;
			}

			const u32 now = getGameTime();
			const bool leftDriving = bot.get_s32("ai builder stone corner escape direction") == 1 &&
				bot.get_u32("ai builder stone corner escape until") > getGameTime() &&
				bot.isKeyPressed(key_right) && !bot.isKeyPressed(key_up) && !bot.isKeyPressed(key_action2);
			const bool rightDriving = mirror.get_s32("ai builder stone corner escape direction") == -1 &&
				mirror.get_u32("ai builder stone corner escape until") > getGameTime() &&
				mirror.isKeyPressed(key_left) && !mirror.isKeyPressed(key_up) && !mirror.isKeyPressed(key_action2);
			if (leftDriving) rules.set_bool("aibt left corner escape observed", true);
			if (rightDriving) rules.set_bool("aibt right corner escape observed", true);

			const bool leftMovedNow = bot.getPosition().x >= rules.get_f32("aibt left corner start x") + 8.0f;
			const bool rightMovedNow = mirror.getPosition().x <= rules.get_f32("aibt right corner start x") - 8.0f;
			if (leftMovedNow) rules.set_bool("aibt left corner moved observed", true);
			if (rightMovedNow) rules.set_bool("aibt right corner moved observed", true);
			const bool leftMoved = rules.get_bool("aibt left corner moved observed");
			const bool rightMoved = rules.get_bool("aibt right corner moved observed");
			const bool leftCycleNow = rules.get_bool("aibt left corner escape observed") &&
				bot.get_u32("ai builder stone corner escape until") == 0 &&
				bot.get_u32("ai builder stone corner escape cooldown") > now;
			const bool rightCycleNow = rules.get_bool("aibt right corner escape observed") &&
				mirror.get_u32("ai builder stone corner escape until") == 0 &&
				mirror.get_u32("ai builder stone corner escape cooldown") > now;
			if (leftCycleNow) rules.set_bool("aibt left corner cycle complete", true);
			if (rightCycleNow) rules.set_bool("aibt right corner cycle complete", true);
			const bool cyclesComplete = rules.get_bool("aibt left corner cycle complete") &&
				rules.get_bool("aibt right corner cycle complete");
			CMap@ map = getMap();
			const int y = AIBT_GROUND_Y - 2;
			const bool trapTilesIntact = map.isTileCastle(map.getTile(AIBT_Pos(320, y - 1)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(319, y - 1)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(318, y - 1)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(318, AIBT_GROUND_Y)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(336, y - 1)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(337, y - 1)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(338, y - 1)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(338, AIBT_GROUND_Y)).type) &&
				map.isTileGround(map.getTile(AIBT_Pos(320, AIBT_GROUND_Y)).type) &&
				map.isTileGround(map.getTile(AIBT_Pos(336, AIBT_GROUND_Y)).type);
			if (rules.get_bool("aibt left corner escape observed") && rules.get_bool("aibt right corner escape observed") &&
				cyclesComplete && leftMoved && rightMoved && trapTilesIntact)
			{
				details = "mirrored_corner_escape=true full_escape_cycle=true cooldown_latched=true obstruction_preload=false " +
					"one_tile_displacement=true castle_traps_preserved=true";
				return true;
			}
			if (elapsed > 150)
			{
				failure = "mirrored_corner_escape_timeout left_observed=" + (rules.get_bool("aibt left corner escape observed") ? "true" : "false") +
					" right_observed=" + (rules.get_bool("aibt right corner escape observed") ? "true" : "false") +
					" cycles_complete=" + (cyclesComplete ? "true" : "false") + " left_moved=" + (leftMoved ? "true" : "false") +
					" right_moved=" + (rightMoved ? "true" : "false") +
					" trap_tiles_intact=" + (trapTilesIntact ? "true" : "false") + " first=" + AIBT_DescribeBuilder(bot) +
					" mirror=" + AIBT_DescribeBuilder(mirror);
				return true;
			}
			break;
		}

		case 42:
		{
			CRules@ rules = getRules();
			CBlob@ crate = expected;
			CMap@ map = getMap();
			Vec2f activeTarget = bot.get_Vec2f("ai builder tile target");
			const int targetX = Maths::Floor(activeTarget.x / map.tilesize);
			if (bot.get_bool("ai builder mining gold") && (targetX == 51 || targetX == 52))
			{
				rules.set_bool("aibt gold discovery observed", true);
			}
			const bool clusterMined = !map.isTileGold(map.getTile(AIBT_Pos(51, AIBT_GROUND_Y - 2)).type) &&
				!map.isTileGold(map.getTile(AIBT_Pos(52, AIBT_GROUND_Y - 2)).type);
			if (clusterMined && rules.get_u32("aibt gold cluster depleted tick") == 0)
			{
				rules.set_u32("aibt gold cluster depleted tick", getGameTime());
			}
			if (bot.get_u8("ai builder state") == AIBT_RETURN_WOOD)
			{
				rules.set_bool("aibt gold return observed", true);
				if (rules.get_u32("aibt gold return tick") == 0) rules.set_u32("aibt gold return tick", getGameTime());
			}
			const bool discovered = rules.get_bool("aibt gold discovery observed");
			const bool returned = rules.get_bool("aibt gold return observed");
			const u32 depletedTick = rules.get_u32("aibt gold cluster depleted tick");
			const u32 returnTick = rules.get_u32("aibt gold return tick");
			const bool promptReturn = depletedTick > 0 && returnTick >= depletedTick && returnTick - depletedTick <= 2;
			const u16 storedGold = AIBT_CountInventoryMaterial(crate, "mat_gold");
			bool oreRouteOutsideNoBuild = true;
			for (int routeX = 46; routeX <= 52 && oreRouteOutsideNoBuild; routeX++)
			{
				for (int routeY = AIBT_GROUND_Y - 4; routeY < AIBT_GROUND_Y; routeY++)
				{
					if (map.getSectorAtPosition(AIBT_Pos(routeX, routeY), "no build") !is null)
					{
						oreRouteOutsideNoBuild = false;
						break;
					}
				}
			}
			const bool occludedGoldPreserved = map.isTileGold(map.getTile(AIBT_Pos(55, AIBT_GROUND_Y - 3)).type);
			const bool occluderPreserved = map.isTileCastle(map.getTile(AIBT_Pos(53, AIBT_GROUND_Y - 4)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(53, AIBT_GROUND_Y - 3)).type) &&
				map.isTileCastle(map.getTile(AIBT_Pos(53, AIBT_GROUND_Y - 2)).type);
			const bool stonePreserved = map.isTileStone(map.getTile(AIBT_Pos(56, AIBT_GROUND_Y - 2)).type);
			if (discovered && returned && promptReturn && clusterMined && storedGold >= 8 && oreRouteOutsideNoBuild &&
				occludedGoldPreserved && occluderPreserved && stonePreserved)
			{
				details = "los_discovered=true real_gold_tiles_mined=true prompt_return=true assigned_crate_gold=" + storedGold +
					" return_delta=" + (returnTick - depletedTick) +
					" ore_route_no_build=clear occluded_gold_preserved=true occluder_preserved=true unrelated_stone_preserved=true";
				return true;
			}
			if (elapsed > 360)
			{
				failure = "gold_delivery_timeout discovered=" + (discovered ? "true" : "false") +
					" returned=" + (returned ? "true" : "false") + " cluster_mined=" + (clusterMined ? "true" : "false") +
					" depleted_tick=" + depletedTick + " return_tick=" + returnTick + " prompt=" + (promptReturn ? "true" : "false") +
					" assigned_crate_gold=" + storedGold + " ore_route_no_build=" + (oreRouteOutsideNoBuild ? "clear" : "blocked") +
					" occluded_gold=" + (occludedGoldPreserved ? "true" : "false") +
					" occluder=" + (occluderPreserved ? "true" : "false") + " stone_preserved=" + (stonePreserved ? "true" : "false") +
					" " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 46:
		{
			CRules@ rules = getRules();
			if (!rules.get_bool("aibt stone route static passed"))
			{
				failure = rules.get_string("aibt stone route static failure");
				return true;
			}

			CMap@ map = getMap();
			const bool targetMined = !map.isTileStone(map.getTile(AIBT_Pos(288, 62)).type);
			const bool stoneAcquired = AIBT_CountInventoryMaterial(bot, "mat_stone") > 0;
			const bool plannedDirtDestroyed = !map.isTileGround(map.getTile(AIBT_Pos(284, 58)).type);
			const bool offRouteDirtPreserved = map.getTile(AIBT_Pos(282, 58)).type == CMap::tile_ground;
			const bool bedrockPreserved = map.isTileBedrock(map.getTile(AIBT_Pos(286, 58)).type);
			const bool castlePreserved = map.isTileCastle(map.getTile(AIBT_Pos(290, 58)).type);
			u16 destroyedDirt = 0;
			for (uint i = 0; i < AIBT_route_dirt_tiles.length; i++)
			{
				if (!map.isTileGround(map.getTile(AIBT_route_dirt_tiles[i]).type)) destroyedDirt++;
			}
			const bool boundedDestruction = destroyedDirt <= 1;
			if (targetMined && stoneAcquired && plannedDirtDestroyed && offRouteDirtPreserved &&
				bedrockPreserved && castlePreserved && boundedDestruction)
			{
				details = rules.get_string("aibt stone route static details") +
					" physical_target_mined=true stone_acquired=true planned_dirt_destroyed=true off_route_preserved=true" +
					" bedrock_preserved=true castle_preserved=true destroyed_dirt=" + destroyedDirt;
				return true;
			}
			if (elapsed > 360)
			{
				failure = "stone_route_physical_timeout target_mined=" + (targetMined ? "true" : "false") +
					" stone_acquired=" + (stoneAcquired ? "true" : "false") +
					" planned_dirt=" + (plannedDirtDestroyed ? "true" : "false") +
					" off_route=" + (offRouteDirtPreserved ? "true" : "false") +
					" bedrock=" + (bedrockPreserved ? "true" : "false") + " castle=" + (castlePreserved ? "true" : "false") +
					" destroyed_dirt=" + destroyedDirt + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 47:
		{
			if (elapsed < 65) break;
			CRules@ rules = getRules();
			const u16 team0Builders = AIBT_CountLiveTeamBuilders(0);
			const u16 team0Bootstrap = AIBT_CountLiveTeamBuilders(0, true);
			const u16 team1Builders = AIBT_CountLiveTeamBuilders(1);
			const u16 team2Builders = AIBT_CountLiveTeamBuilders(2);
			const bool activeTeam0Plan = rules.get_u16(AIBP_PlanKey(0, "id")) != 0 &&
				rules.get_u16(AIBP_PlanKey(0, "pending")) > 0;
			const bool suggestedTeam1Plan = rules.get_u16(AIBP_PlanKey(1, "id")) != 0 &&
				AIBT_CountLayerTiles(1, AIBP_Layer::ai_desired) > 0 && AIBT_LayerIsEmpty(1, AIBP_Layer::ai_work);
			const bool noHomeTeam2Plan = rules.get_u16(AIBP_PlanKey(2, "id")) == 0;
			const bool guardsHeld = activeTeam0Plan && suggestedTeam1Plan && noHomeTeam2Plan && team0Builders == 1 && team0Bootstrap == 0 &&
				team1Builders == 0 && team2Builders == 0 &&
				!rules.get_bool(AIBS_BootstrapKey(0, "provisioned")) &&
				!rules.get_bool(AIBS_BootstrapKey(1, "provisioned")) &&
				!rules.get_bool(AIBS_BootstrapKey(2, "provisioned"));
			if (guardsHeld)
			{
				details = "existing_worker_suppressed=true suggest_plan_visible=true suggest_work_inactive=true suggest_bootstrap_suppressed=true no_home_plan_suppressed=true no_home_bootstrap_suppressed=true heartbeats=2 team0_builders=1 team1_builders=0 team2_builders=0";
				return true;
			}
			if (elapsed > 100)
			{
				failure = "bootstrap_guard_failed active_plan=" + (activeTeam0Plan ? "true" : "false") +
					" suggest_plan=" + (suggestedTeam1Plan ? "true" : "false") + " no_home_plan=" + (noHomeTeam2Plan ? "true" : "false") +
					" team0=" + team0Builders + " team0_bootstrap=" + team0Bootstrap +
					" team1=" + team1Builders + " team2=" + team2Builders +
					" provisioned=" + (rules.get_bool(AIBS_BootstrapKey(0, "provisioned")) ? "true" : "false") + "," +
						(rules.get_bool(AIBS_BootstrapKey(1, "provisioned")) ? "true" : "false") + "," +
						(rules.get_bool(AIBS_BootstrapKey(2, "provisioned")) ? "true" : "false");
				return true;
			}
			break;
		}

		case 48:
		{
			CRules@ rules = getRules();
			const u8 stage = rules.get_u8("aibt bootstrap stage");
			if (stage == 0)
			{
				CBlob@ worker = AIBT_GetBootstrapWorker(0);
				if (worker !is null && worker.get_bool("aib strategy assigned") && AIBT_BootstrapWorkerHasSafeGround(worker))
				{
					const u16 workerID = worker.getNetworkID();
					const bool reserved = AIBT_HasReservationBy(0, workerID) || AIBT_ReserveFirstActiveTask(0, workerID);
					if (!reserved)
					{
						failure = "bootstrap_could_not_reserve_active_task";
						return true;
					}
					u16 taskX = 0; u16 taskY = 0;
					const bool captured = AIBT_GetReservationBy(0, workerID, taskX, taskY);
					if (!captured)
					{
						failure = "bootstrap_reserved_task_not_found";
						return true;
					}
					rules.set_netid("aibt bootstrap dead id", workerID);
					rules.set_bool("aibt bootstrap reservation made", true);
					rules.set_u16("aibt bootstrap plan id", rules.get_u16(AIBP_PlanKey(0, "id")));
					rules.set_u16("aibt bootstrap task x", taskX);
					rules.set_u16("aibt bootstrap task y", taskY);
					rules.set_bool("aibt bootstrap task captured", true);
					rules.set_u32("aibt bootstrap death tick", getGameTime());
					rules.set_u8("aibt bootstrap stage", 1);
					worker.server_Die();
					return false;
				}
			}
			else
			{
				const u16 deadID = rules.get_netid("aibt bootstrap dead id");
				const u32 sinceDeath = getGameTime() - rules.get_u32("aibt bootstrap death tick");
				if (sinceDeath >= 45)
				{
					const bool released = deadID != 0 && !AIBT_HasReservationBy(0, deadID);
					const bool samePlan = rules.get_u16("aibt bootstrap plan id") != 0 &&
						rules.get_u16(AIBP_PlanKey(0, "id")) == rules.get_u16("aibt bootstrap plan id");
					const bool taskPendingUnowned = rules.get_bool("aibt bootstrap task captured") &&
						AIBT_TaskIsPendingUnowned(0, rules.get_u16("aibt bootstrap task x"), rules.get_u16("aibt bootstrap task y"));
					const bool noReplacement = AIBT_CountLiveTeamBuilders(0) == 0 && AIBT_CountLiveTeamBuilders(0, true) == 0;
					const bool latched = rules.get_bool(AIBS_BootstrapKey(0, "provisioned"));
					if (rules.get_bool("aibt bootstrap reservation made") && released && samePlan && taskPendingUnowned && noReplacement && latched)
					{
						details = "one_time=true no_respawn_fountain=true reservation_released=true same_plan=true task_pending_unowned=true death_heartbeats=1 provision_latched=true";
						return true;
					}
					failure = "bootstrap_death_contract_failed dead_id=" + deadID +
						" released=" + (released ? "true" : "false") + " same_plan=" + (samePlan ? "true" : "false") +
						" task_pending_unowned=" + (taskPendingUnowned ? "true" : "false") + " live=" + AIBT_CountLiveTeamBuilders(0) +
						" bootstrap=" + AIBT_CountLiveTeamBuilders(0, true) + " latched=" + (latched ? "true" : "false");
					return true;
				}
			}
			if (elapsed > 180)
			{
				failure = "bootstrap_death_timeout stage=" + stage + " plan=" + rules.get_u16(AIBP_PlanKey(0, "id")) +
					" live=" + AIBT_CountLiveTeamBuilders(0) + " bootstrap=" + AIBT_CountLiveTeamBuilders(0, true);
				return true;
			}
			break;
		}

		case 49:
		{
			CRules@ rules = getRules();
			Vec2f target = bot.get_Vec2f("ai builder tile target");
			if (Maths::Floor(target.x / getMap().tilesize) == 66 && Maths::Floor(target.y / getMap().tilesize) == AIBT_GROUND_Y - 1)
				rules.set_bool("aibt exposed stone targeted", true);
			if (!getMap().isTileStone(getMap().getTile(AIBT_Pos(66, AIBT_GROUND_Y - 1)).type))
				rules.set_bool("aibt exposed stone mined", true);
			if (AIBT_CountInventoryMaterial(bot, "mat_stone") > 0 || bot.get_u8("ai builder state") == AIBT_RETURN_WOOD)
				rules.set_bool("aibt exposed stone acquired", true);
			const u16 stored = tent is null ? 0 : AIBT_CountMaterialInCratesNear("mat_stone", tent.getPosition(), 120.0f);
			if (rules.get_bool("aibt exposed stone targeted") && rules.get_bool("aibt exposed stone mined") &&
				rules.get_bool("aibt exposed stone acquired") && stored > 0 && AIBT_CountInventoryMaterial(bot, "mat_stone") == 0)
			{
				details = "selected_stone_targeted=true real_tile_mined=true stone_acquired=true delivered_to_crate=" + stored + " gym_flags=none";
				return true;
			}
			if (elapsed > 180)
			{
				failure = "exposed_stone_pipeline_timeout targeted=" + (rules.get_bool("aibt exposed stone targeted") ? "true" : "false") +
					" mined=" + (rules.get_bool("aibt exposed stone mined") ? "true" : "false") +
					" acquired=" + (rules.get_bool("aibt exposed stone acquired") ? "true" : "false") + " stored=" + stored + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 50:
		{
			CRules@ rules = getRules();
			AIBT_RecordHarvestSceneDelta(bot, expected, tent);
			if (expected !is null && bot.get_netid("ai builder target") == expected.getNetworkID())
				rules.set_bool("aibt selected tree targeted", true);
			if (expected is null || expected.hasTag("dead") || expected.hasTag("felldown") ||
				bot.get_u8("ai builder state") == AIBT_FIND_LOG || bot.get_u8("ai builder state") == AIBT_CHOP_LOG)
				rules.set_bool("aibt selected tree felled", true);
			if (AIBT_CountInventoryMaterial(bot, "mat_wood") > 0 || bot.get_u8("ai builder state") == AIBT_RETURN_WOOD)
				rules.set_bool("aibt selected tree wood acquired", true);
			const u16 stored = tent is null ? 0 : AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f);
			if (rules.get_bool("aibt selected tree targeted") && rules.get_bool("aibt selected tree felled") &&
				rules.get_bool("aibt selected tree wood acquired") && stored > 0 && AIBT_CountInventoryMaterial(bot, "mat_wood") == 0)
			{
				details = "accepted_tree_order=true selected_tree_targeted=true tree_felled=true logs_processed=true wood_acquired=true wood_delivered=" + stored + " gym_flags=none";
				return true;
			}
			if (elapsed > 1800)
			{
				failure = "gym_tree_pipeline_timeout targeted=" + (rules.get_bool("aibt selected tree targeted") ? "true" : "false") +
					" felled=" + (rules.get_bool("aibt selected tree felled") ? "true" : "false") +
					" acquired=" + (rules.get_bool("aibt selected tree wood acquired") ? "true" : "false") + " stored=" + stored + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 51:
		{
			const int x = 68;
			const int targetY = AIBT_GROUND_Y - 3;
			const int supportY = AIBT_GROUND_Y - 2;
			AIBT_RecordSupportSceneDelta(bot, x, targetY, supportY);
			CMap@ map = getMap();
			const bool backwallBuilt = map !is null && map.getTile(AIBT_Pos(x, supportY)).type == CMap::tile_castle_back;
			const bool foregroundBuilt = map !is null && map.getTile(AIBT_Pos(x, targetY)).type == CMap::tile_castle;
			const u16 remainingStone = AIBT_CountAllLiveMaterial("mat_stone");
			const u16 expectedStone = 100 - AIBP_BlockCost(AIBP_STONE_BACKWALL) - AIBP_BlockCost(AIBP_STONE_BLOCK);
			if (backwallBuilt && foregroundBuilt && remainingStone == expectedStone)
			{
				details = "generated_backwall_support=true foreground_built=true material_conserved=true remaining_stone=" + remainingStone;
				return true;
			}
			if (elapsed > 600)
			{
				failure = "generated_backwall_support_timeout backwall=" + (backwallBuilt ? "true" : "false") +
					" foreground=" + (foregroundBuilt ? "true" : "false") + " remaining_stone=" + remainingStone + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 52:
		{
			const u16 initialWood = getRules().get_u16("aibt overflow initial wood");
			const u8 fillers = getRules().get_u8("aibt overflow fillers");
			const u16 liveWood = AIBT_CountAllLiveMaterial("mat_wood");
			const u16 liveStone = AIBT_CountAllLiveMaterial("mat_stone");
			const u16 storedWood = tent is null ? 0 : AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 160.0f);
			const u16 storedStone = tent is null ? 0 : AIBT_CountMaterialInCratesNear("mat_stone", tent.getPosition(), 160.0f);
			u8 crateCount = 0;
			string placement;
			const bool validCrates = AIBT_OverflowCratesAreGroundedAndDistinct(tent, crateCount, placement);
			const bool delivered = AIBT_CountInventoryMaterial(bot, "mat_stone") == 0 && storedStone == 100;
			const bool conserved = initialWood >= 150 && liveWood == initialWood - 150 &&
				storedWood == initialWood - 150 && liveStone == 100;
			if (fillers == 8 && validCrates && delivered && conserved)
			{
				details = "overflow_created=true stored_stone=" + storedStone + " stored_wood=" + storedWood +
					" wood_cost=150 material_conserved=true " + placement;
				return true;
			}
			if (elapsed > 300)
			{
				failure = "overflow_storage_timeout fillers=" + fillers + " initial_wood=" + initialWood + " live_wood=" + liveWood +
					" stored_wood=" + storedWood + " live_stone=" + liveStone + " stored_stone=" + storedStone +
					" crates=" + crateCount + " placement=" + placement + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 53:
		{
			const u16 x = 68;
			const u16 y = AIBT_GROUND_Y - 2;
			const bool repaired = AIBP_MapMatchesBlock(x, y, AIBP_WOOD_BLOCK, 0);
			const bool neighborPreserved = getMap().getTile(AIBT_Pos(x - 1, y)).type == CMap::tile_castle;
			const u16 wood = AIBT_CountAllLiveMaterial("mat_wood");
			array<u8>@ states = null;
			getRules().get(AIBP_TaskKey(0, "state"), @states);
			const bool completed = states !is null && states.length == 1 && states[0] == AIBP_TaskState::completed;
			if (repaired && neighborPreserved && completed && wood == 40)
			{
				details = "owned_tile_repaired=true neighbor_preserved=true task_completed=true material_conserved=true remaining_wood=40";
				return true;
			}
			if (elapsed > 300)
			{
				failure = "physical_repair_timeout repaired=" + (repaired ? "true" : "false") +
					" neighbor=" + (neighborPreserved ? "true" : "false") + " completed=" + (completed ? "true" : "false") +
					" wood=" + wood + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 54:
		{
			string leftFailure; string leftDetails;
			string rightFailure; string rightDetails;
			const bool leftSafe = AIBT_RepresentativeDirectorCandidate(0, 1, false, leftFailure, leftDetails);
			const bool rightSafe = AIBT_RepresentativeDirectorCandidate(1, -1, false, rightFailure, rightDetails);
			if (!leftSafe || !rightSafe)
			{
				failure = "mirrored_director_candidate_failed left=" + leftFailure + " right=" + rightFailure;
				return true;
			}
			details = "mirrored_safe=true " + leftDetails + " | " + rightDetails;
			return true;
		}

		case 55:
		{
			string candidateFailure; string candidateDetails;
			AIBWorldState@ world = AIBS_ObserveWorld(0);
			array<AIBPlanCandidate@> generated;
			AIBS_GenerateCandidates(world, generated);
			bool primaryFound = false; bool primaryRejected = false;
			string primaryRejection = "missing";
			for (uint i = 0; i < generated.length; i++)
			{
				AIBPlanCandidate@ candidate = generated[i];
				if (candidate is null || candidate.templateName != "flag_gatehouse" || int(candidate.anchor.x) != 372) continue;
				primaryFound = true;
				primaryRejected = !AIBS_ValidateCandidate(world, candidate);
				primaryRejection = candidate.rejection;
				break;
			}
			if (!primaryFound || !primaryRejected)
			{
				failure = "uneven_edge_primary_not_rejected found=" + (primaryFound ? "true" : "false") + " rejection=" + primaryRejection;
				return true;
			}
			if (!AIBT_RepresentativeDirectorCandidate(0, -1, true, candidateFailure, candidateDetails))
			{
				failure = "uneven_edge_director_candidate_failed " + candidateFailure;
				return true;
			}
			details = "uneven_edge_safe_fallback=true primary_rejection=" + primaryRejection + " " + candidateDetails;
			return true;
		}

		case 56:
		{
			AIBWorldState@ world = AIBS_ObserveWorld(0);
			array<AIBPlanCandidate@> generated;
			AIBS_GenerateCandidates(world, generated);
			AIBPlanCandidate@ expensive = null;
			u32 expensiveWood = 0; u32 expensiveStone = 0; u32 expensiveTotal = 0;
			for (uint i = 0; i < generated.length; i++)
			{
				AIBPlanCandidate@ candidate = generated[i];
				if (!AIBS_ValidateCandidate(world, candidate)) continue;
				u32 wood = 0; u32 stone = 0;
				AIBS_CandidateCosts(candidate, wood, stone);
				if (wood + stone <= expensiveTotal) continue;
				@expensive = candidate; expensiveWood = wood; expensiveStone = stone; expensiveTotal = wood + stone;
			}
			if (expensive is null || expensiveTotal == 0)
			{
				failure = "scarcity_no_costed_candidate";
				return true;
			}
			world.storedWood = 0; world.storedStone = 0;
			const f32 scarceScore = AIBS_ScoreCandidate(world, expensive);
			const string scarceReasons = expensive.reasons;
			world.storedWood = u16(Maths::Min(expensiveWood, u32(65535)));
			world.storedStone = u16(Maths::Min(expensiveStone, u32(65535)));
			const f32 fundedScore = AIBS_ScoreCandidate(world, expensive);
			AIBStrategyWeights@ weights = AIBS_GetStrategyWeights();
			const f32 expectedPenalty = expensiveWood * weights.woodShortage + expensiveStone * weights.stoneShortage;
			const f32 actualPenalty = fundedScore - scarceScore;
			if (expectedPenalty <= 0.0f || Maths::Abs(actualPenalty - expectedPenalty) > 0.05f || scarceReasons.find("shortage=") < 0)
			{
				failure = "scarcity_penalty_invalid template=" + expensive.templateName + " expected=" + expectedPenalty +
					" actual=" + actualPenalty + " reasons=" + scarceReasons;
				return true;
			}
			details = "scarcity_penalty_applied=true template=" + expensive.templateName + " wood=" + expensiveWood +
				" stone=" + expensiveStone + " penalty=" + actualPenalty;
			return true;
		}

		case 57:
		{
			AIBWorldState@ world = AIBS_ObserveWorld(0);
			AIBPlanCandidate@ selected = AIBS_SelectCandidate(world);
			if (world is null || !world.frontlineCollapsing)
			{
				failure = "pressure_fixture_not_collapsing enemies=" + (world is null ? 0 : world.enemyKnights) +
					" pressure=" + (world is null ? 0.0f : world.pressure);
				return true;
			}
			if (selected is null || selected.intent != AIBStrategyIntent::emergency_barrier || selected.reasons.find("urgency=") < 0)
			{
				failure = "pressure_emergency_not_selected template=" + (selected is null ? "none" : selected.templateName) +
					" intent=" + (selected is null ? 255 : selected.intent) + " reasons=" + (selected is null ? "none" : selected.reasons);
				return true;
			}
			details = "frontline_collapsing=true emergency_selected=true enemies=" + world.enemyKnights +
				" pressure=" + world.pressure + " template=" + selected.templateName + " reasons=" + selected.reasons;
			return true;
		}

		case 58:
		{
			CRules@ rules = getRules();
			const u16 x = 78;
			const u16 y = AIBT_GROUND_Y - 1;
			if (!rules.get_bool("aibt damaged front setup"))
			{
				failure = "damaged_front_plan_publish_failed";
				return true;
			}
			array<u16>@ desired = null; array<u16>@ work = null;
			array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
			array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
			AIBP_GetLayerGrid(0, AIBP_Layer::ai_desired, @desired);
			AIBP_GetLayerGrid(0, AIBP_Layer::ai_work, @work);
			const bool loaded = AIBP_LoadTaskArrays(0, @xs, @ys, @blocks, @phases, @states, @reserved, @untils);
			const uint first = y * getMap().tilemapwidth + x;
			const bool layersValid = desired !is null && work !is null && first + 2 < desired.length && first + 2 < work.length &&
				desired[first] == AIBP_WOOD_BLOCK && desired[first + 1] == AIBP_STONE_BLOCK && desired[first + 2] == AIBP_WOOD_BLOCK &&
				work[first] == AIBP_WOOD_BLOCK && work[first + 1] == AIBP_STONE_BLOCK && work[first + 2] == 0;
			const bool tasksValid = loaded && states !is null && reserved !is null && states.length == 3 && reserved.length == 3 &&
				states[0] == AIBP_TaskState::pending && states[1] == AIBP_TaskState::pending && states[2] == AIBP_TaskState::completed &&
				reserved[0] == 0 && reserved[1] == 0 && reserved[2] == 0;
			const bool repairable = AIBP_IsRepairablePlanOccupant(0, x, y, AIBP_WOOD_BLOCK) &&
				AIBP_IsRepairablePlanOccupant(0, x + 1, y, AIBP_STONE_BLOCK);
			AIBWorldState@ world = AIBS_ObserveWorld(0);
			AIBPlanCandidate@ candidate = AIBS_SelectCandidate(world);
			const bool invalid = AIBS_ActivePlanInvalid(world);
			const bool replace = AIBS_ShouldReplacePlan(world, candidate);
			const bool identityStable = rules.get_u16(AIBP_PlanKey(0, "id")) == rules.get_u16("aibt damaged front plan id") &&
				rules.get_u16(AIBP_PlanKey(0, "version")) == rules.get_u16("aibt damaged front plan version");
			const bool countsValid = world !is null && world.planPending == 2 && world.planCompleted == 1 && world.planDamaged == 2 &&
				rules.get_u8(AIBP_PlanKey(0, "status")) == 1;
			if (!layersValid || !tasksValid || !repairable || world is null || candidate is null || invalid || replace || !identityStable || !countsValid)
			{
				failure = "damaged_front_reactivation_failed layers=" + (layersValid ? "true" : "false") +
					" tasks=" + (tasksValid ? "true" : "false") + " repairable=" + (repairable ? "true" : "false") +
					" candidate=" + (candidate is null ? "none" : candidate.templateName) + " invalid=" + (invalid ? "true" : "false") +
					" replace=" + (replace ? "true" : "false") + " identity=" + (identityStable ? "true" : "false") +
					" pending=" + (world is null ? 0 : world.planPending) + " completed=" + (world is null ? 0 : world.planCompleted) +
					" damaged=" + (world is null ? 0 : world.planDamaged) + " reason=" + rules.get_string("aib strategy replacement reason team 0");
				return true;
			}
			details = "damaged_tiles=2 reactivated=2 healthy_completed=1 repairable=true plan_identity_stable=true replacement=false template=" + candidate.templateName;
			return true;
		}

		case 59:
		{
			CRules@ rules = getRules();
			if (!rules.get_bool("aibt physical plan setup"))
			{
				failure = "physical_selected_plan_setup_failed template=" + rules.get_string("aibt physical plan template") +
					" route_safe=" + (rules.get_bool("aibt physical plan route safe") ? "true" : "false");
				return true;
			}
			AIBP_RefreshPlanState(0, true);
			const u16 expectedTasks = rules.get_u16("aibt physical plan tasks");
			const u16 initialCompleted = rules.get_u16("aibt physical plan initial completed");
			const u16 countedCompleted = rules.get_u16(AIBP_PlanKey(0, "completed"));
			if (countedCompleted > initialCompleted) rules.set_bool("aibt physical plan progress observed", true);
			u16 taskCount = 0; u16 stateCompleted = 0; u16 reservedCount = 0; string mismatch;
			const bool physical = AIBT_AllPlanTasksPhysicallyComplete(0, taskCount, stateCompleted, reservedCount, mismatch);
			const bool identityStable = rules.get_u16(AIBP_PlanKey(0, "id")) == rules.get_u16("aibt physical plan id") &&
				rules.get_u16(AIBP_PlanKey(0, "version")) == rules.get_u16("aibt physical plan version");
			const bool countersComplete = rules.get_u16(AIBP_PlanKey(0, "pending")) == 0 &&
				rules.get_u16(AIBP_PlanKey(0, "completed")) == expectedTasks && rules.get_u8(AIBP_PlanKey(0, "status")) == 2;
			const bool layersComplete = AIBT_CountLayerTiles(0, AIBP_Layer::ai_desired) == expectedTasks &&
				AIBT_LayerIsEmpty(0, AIBP_Layer::ai_work);
			const bool assignedExecutor = bot !is null && bot.hasTag("autobuilder") && bot.get_bool("aib strategy assigned") &&
				bot.get_u8("ai builder job") == AIBS_JOB_BLUEPRINT;
			const string archivePrefix = "aib strategy history plan " + rules.get_u16("aibt physical plan id") + " team 0 ";
			const bool archivedComplete = rules.get_string(archivePrefix + "archive reason") == "completed";
			const bool exercised = expectedTasks >= 6 && initialCompleted < expectedTasks && rules.get_bool("aibt physical plan progress observed");
			if (physical && identityStable && countersComplete && layersComplete && assignedExecutor && archivedComplete && exercised)
			{
				details = "selected_plan_physically_complete=true template=" + rules.get_string("aibt physical plan template") +
					" tasks=" + expectedTasks + " initial_completed=" + initialCompleted + " reservations=0 work_layer_empty=true route_safe=true plan_identity_stable=true";
				return true;
			}
			const u32 timeout = u32(expectedTasks) * 45 + 450;
			if (elapsed > timeout)
			{
				failure = "physical_selected_plan_timeout template=" + rules.get_string("aibt physical plan template") +
					" elapsed=" + elapsed + " timeout=" + timeout + " expected=" + expectedTasks + " tasks=" + taskCount +
					" states_completed=" + stateCompleted + " counted_completed=" + countedCompleted + " reserved=" + reservedCount +
					" identity=" + (identityStable ? "true" : "false") + " counters=" + (countersComplete ? "true" : "false") +
					" layers=" + (layersComplete ? "true" : "false") + " assigned=" + (assignedExecutor ? "true" : "false") +
					" archived=" + (archivedComplete ? "true" : "false") + " exercised=" + (exercised ? "true" : "false") +
					" mismatch=" + mismatch + " reasons=" + rules.get_string("aibt physical plan reasons") + " " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 61:
		case 62:
		case 63:
		{
			return AIBT_EvaluateRepresentativeFallback(elapsed, failure, details);
		}

		case 64:
		{
			CRules@ rules = getRules();
			CBlob@ left = AIBT_GetBootstrapWorker(0);
			CBlob@ right = AIBT_GetBootstrapWorker(1);
			const bool plansActive = rules !is null && rules.get_bool("aibt bootstrap lifecycle plans") &&
				rules.get_u16(AIBP_PlanKey(0, "pending")) == 1 && rules.get_u16(AIBP_PlanKey(1, "pending")) == 1;
			const bool mirroredWorkers = left !is null && right !is null && AIBT_CountLiveTeamBuilders(0) == 1 &&
				AIBT_CountLiveTeamBuilders(1) == 1 && AIBT_BootstrapWorkerHasSafeGround(left) && AIBT_BootstrapWorkerHasSafeGround(right) &&
				left.getPosition().x < right.getPosition().x && left.get_bool("aib strategy assigned") && right.get_bool("aib strategy assigned");
			const bool latchesHeld = rules !is null && rules.get_bool(AIBS_BootstrapKey(0, "provisioned")) &&
				rules.get_bool(AIBS_BootstrapKey(1, "provisioned")) &&
				rules.get_u32(AIBS_BootstrapKey(0, "next retry")) == 0 && rules.get_u32(AIBS_BootstrapKey(1, "next retry")) == 0;
			const bool passed = rules !is null && rules.get_bool("aibt bootstrap lifecycle setup") &&
				rules.get_bool(AIBT_BootstrapLifecycleKey(0, "passed")) && rules.get_bool(AIBT_BootstrapLifecycleKey(1, "passed")) &&
				plansActive && mirroredWorkers && latchesHeld;
			if (passed)
			{
				details = "blocked_sites_cooldown=true round_reset_reopened=true mirrored_safe_workers=true left={" +
					rules.get_string(AIBT_BootstrapLifecycleKey(0, "details")) + "} right={" +
					rules.get_string(AIBT_BootstrapLifecycleKey(1, "details")) + "}";
				return true;
			}
			if (elapsed > 10)
			{
				failure = "bootstrap_round_reset_lifecycle_failed setup=" +
					(rules !is null && rules.get_bool("aibt bootstrap lifecycle setup") ? "true" : "false") +
					" plans=" + (plansActive ? "true" : "false") + " workers=" + (mirroredWorkers ? "true" : "false") +
					" latches=" + (latchesHeld ? "true" : "false") + " left={" +
					(rules is null ? "rules_missing" : rules.get_string(AIBT_BootstrapLifecycleKey(0, "details"))) + "} right={" +
					(rules is null ? "rules_missing" : rules.get_string(AIBT_BootstrapLifecycleKey(1, "details"))) + "}";
				return true;
			}
			break;
		}

		case 44:
		{
			CRules@ rules = getRules();
			CBlob@ shop = AIBT_GetNearestTeamBuilderShop(tent);
			if (shop !is null)
			{
				rules.set_bool("aibt workshop observed", true);
				const u32 shopAge = shop.getTickSinceCreated();
				const bool alive = !shop.hasTag("dead");
				const bool productionTagged = shop.hasTag("aibuilder built storage shop");
				// Wait through DefaultBuilding's tick-10 overlap check and the
				// DefaultNoBuild/background lifecycle before judging geometry.
				if (shopAge < 46) break;
				if (!alive || !productionTagged)
				{
					failure = "tent_workshop_lifecycle_invalid age=" + shopAge + " alive=" + (alive ? "true" : "false") +
						" production_tag=" + (productionTagged ? "true" : "false");
					return true;
				}

				string placement;
				const bool valid = AIBT_HasValidBuilderShopPlacement(tent, 6.0f, placement);
				const f32 dxTiles = Maths::Abs(shop.getPosition().x - tent.getPosition().x) / getMap().tilesize;
				const bool searchedPastBlockedBand = dxTiles >= 16.0f;
				const bool blockersRemain = getMap().isTileSolid(getMap().getTile(AIBT_Pos(210 - 13, AIBT_GROUND_Y - 2)).type) &&
					getMap().isTileSolid(getMap().getTile(AIBT_Pos(210 + 13, AIBT_GROUND_Y - 2)).type);
				if (!valid || !searchedPastBlockedBand || !blockersRemain)
				{
					failure = "tent_workshop_bad_site searched_past_blocked=" + (searchedPastBlockedBand ? "true" : "false") +
						" blockers_remain=" + (blockersRemain ? "true" : "false") + " " + placement;
					return true;
				}
				details = "home=tent nearest_obstructed=true farther_site=true blocked_through=15 lifecycle_age=" + shopAge +
					" alive=true production_tag=true " + placement;
				return true;
			}
			if (rules.get_bool("aibt workshop observed"))
			{
				failure = "tent_workshop_died_before_lifecycle_validation";
				return true;
			}
			if (elapsed > 15)
			{
				failure = "tent_workshop_not_built " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
		}

		case 45:
		{
			CRules@ rules = getRules();
			CBlob@ shop = AIBT_GetNearestTeamBuilderShop(tent);
			if (shop !is null)
			{
				rules.set_bool("aibt workshop observed", true);
				const u32 shopAge = shop.getTickSinceCreated();
				const bool alive = !shop.hasTag("dead");
				const bool productionTagged = shop.hasTag("aibuilder built storage shop");
				if (shopAge < 46) break;
				if (!alive || !productionTagged)
				{
					failure = "hall_workshop_lifecycle_invalid age=" + shopAge + " alive=" + (alive ? "true" : "false") +
						" production_tag=" + (productionTagged ? "true" : "false");
					return true;
				}

				string placement;
				const bool valid = AIBT_HasValidBuilderShopPlacement(tent, 6.0f, placement);
				const f32 dxTiles = Maths::Abs(shop.getPosition().x - tent.getPosition().x) / getMap().tilesize;
				// Even-width halls align to whole tiles while odd-width workshops
				// align to half tiles, so search distance 19 measures 18.5 centers.
				const bool searchedPastUnsupportedBand = dxTiles >= 18.0f;
				const bool holesRemain = !getMap().isTileSolid(getMap().getTile(AIBT_Pos(230 - 16, AIBT_GROUND_Y)).type) &&
					!getMap().isTileSolid(getMap().getTile(AIBT_Pos(230 - 15, AIBT_GROUND_Y)).type) &&
					!getMap().isTileSolid(getMap().getTile(AIBT_Pos(230 + 15, AIBT_GROUND_Y)).type) &&
					!getMap().isTileSolid(getMap().getTile(AIBT_Pos(230 + 16, AIBT_GROUND_Y)).type);
				if (!valid || !searchedPastUnsupportedBand || !holesRemain)
				{
					failure = "hall_workshop_bad_site searched_past_unsupported=" + (searchedPastUnsupportedBand ? "true" : "false") +
						" holes_remain=" + (holesRemain ? "true" : "false") + " " + placement;
					return true;
				}
				details = "home=hall partial_support_rejected=true four_support_holes_preserved=true farther_site=true " +
					"unsupported_search_distances_through=18 lifecycle_age=" + shopAge +
					" alive=true production_tag=true " + placement;
				return true;
			}
			if (rules.get_bool("aibt workshop observed"))
			{
				failure = "hall_workshop_died_before_lifecycle_validation";
				return true;
			}
			if (elapsed > 15)
			{
				failure = "hall_workshop_not_built " + AIBT_DescribeBuilder(bot);
				return true;
			}
			break;
	}
}

	return false;
}

void AIBT_RecordHarvestSceneDelta(CBlob@ bot, CBlob@ tree, CBlob@ tent)
{
	CRules@ rules = getRules();
	if (rules is null) return;

	u16 logs = 0;
	CBlob@[] logBlobs;
	getBlobsByName("log", @logBlobs);
	for (uint i = 0; i < logBlobs.length; i++)
	{
		CBlob@ item = logBlobs[i];
		if (item !is null && !item.hasTag("dead")) logs++;
	}

	u16 looseWoodBlobs = 0;
	u16 looseWoodQuantity = 0;
	CBlob@[] woodBlobs;
	getBlobsByName("mat_wood", @woodBlobs);
	for (uint i = 0; i < woodBlobs.length; i++)
	{
		CBlob@ item = woodBlobs[i];
		if (item is null || item.hasTag("dead") || item.isInInventory() || item.isAttached()) continue;
		looseWoodBlobs++;
		looseWoodQuantity += item.getQuantity();
	}

	string treeStatus = "0";
	if (tree !is null)
	{
		CMap@ map = getMap();
		const bool supported = map !is null && map.isTileSolid(map.getTile(tree.getPosition() + Vec2f(0.0f, map.tilesize)).type);
		treeStatus = "id:" + tree.getNetworkID() + ",hp:" + tree.getHealth() + ",grown:" + tree.get_u8("grown_times") +
			",big:" + (tree.hasTag("startbig") ? 1 : 0) + ",support:" + (supported ? 1 : 0) +
			",dead:" + (tree.hasTag("dead") ? 1 : 0) + ",fell:" + (tree.hasTag("felldown") ? 1 : 0);
	}

	CBlob@ carried = bot is null ? null : bot.getCarriedBlob();
	const string carriedStatus = carried is null ? "none" : carried.getName() + ":" + carried.getNetworkID();
	const u16 inventoryWood = bot is null ? 0 : AIBT_CountInventoryMaterial(bot, "mat_wood");
	const u16 storedWood = tent is null ? 0 : AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f);
	const string signature = "tree=" + treeStatus + " logs=" + logs + " loose=" + looseWoodBlobs + ":" + looseWoodQuantity +
		" carry=" + carriedStatus + " inv=" + inventoryWood + " stored=" + storedWood;
	if (signature == rules.get_string("aibt harvest scene signature")) return;

	rules.set_string("aibt harvest scene signature", signature);
	rules.set_u32("aibt harvest last progress tick", getGameTime());
	AIB_LogEvent("scene", "blob_delta", bot is null ? "builder:none" : AIBT_BlobRef(bot), signature);
}

void AIBT_RecordBlueprintSceneDelta(CBlob@ bot, CBlob@ crate)
{
	CRules@ rules = getRules();
	if (rules is null) return;

	const u16 crateWood = crate is null ? 0 : AIBT_CountInventoryMaterial(crate, "mat_wood");
	const u16 crateStone = crate is null ? 0 : AIBT_CountInventoryMaterial(crate, "mat_stone");
	const u16 builderWood = bot is null ? 0 : AIBT_CountInventoryMaterial(bot, "mat_wood");
	const u16 builderStone = bot is null ? 0 : AIBT_CountInventoryMaterial(bot, "mat_stone");
	CMap@ map = getMap();
	const u16 stoneType = map is null ? 0 : map.getTile(AIBT_Pos(394, AIBT_GROUND_Y - 1)).type;
	const u16 woodType = map is null ? 0 : map.getTile(AIBT_Pos(395, AIBT_GROUND_Y - 1)).type;
	const string signature = "crate=" + (crate is null ? 0 : crate.getNetworkID()) + ":" + crateWood + ":" + crateStone +
		" builder=" + builderWood + ":" + builderStone + " tiles=" + stoneType + ":" + woodType +
		" state=" + (bot is null ? 255 : bot.get_u8("ai builder state"));
	if (signature == rules.get_string("aibt blueprint scene signature")) return;

	rules.set_string("aibt blueprint scene signature", signature);
	AIB_LogEvent("scene", "blueprint_delta", bot is null ? "builder:none" : AIBT_BlobRef(bot), signature);
}

u16 AIBT_CountAllLiveMaterial(const string &in name)
{
	u32 total = 0;
	CBlob@[] materials;
	getBlobsByName(name, @materials);
	for (uint i = 0; i < materials.length; i++)
	{
		CBlob@ material = materials[i];
		if (material is null || material.hasTag("dead")) continue;
		total += material.getQuantity();
	}
	return u16(Maths::Min(total, 65535));
}

void AIBT_RecordSupportSceneDelta(CBlob@ bot, const int x, const int targetY, const int supportY)
{
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null) return;
	const u16 targetType = map.getTile(AIBT_Pos(x, targetY)).type;
	const u16 supportType = map.getTile(AIBT_Pos(x, supportY)).type;
	const string signature = "target=" + targetType + " support=" + supportType +
		" stone=" + (bot is null ? 0 : AIBT_CountInventoryMaterial(bot, "mat_stone")) +
		" state=" + (bot is null ? 255 : bot.get_u8("ai builder state"));
	if (signature == rules.get_string("aibt support scene signature")) return;
	rules.set_string("aibt support scene signature", signature);
	AIB_LogEvent("scene", "support_delta", bot is null ? "builder:none" : AIBT_BlobRef(bot), signature);
}
