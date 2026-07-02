#include "AIBTestEventLog.as";
#include "AIBTestAssertions.as";
#include "ShopCommon.as";
#include "BlueprintData.as";
#include "AIBPlacementPlanner.as";

const int AIBT_ORIGIN_X = 12;
const int AIBT_WIDTH = 150;
const int AIBT_GROUND_Y = 72;
u16[] AIBT_spawned_ids;

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
	"construction_menu_has_nursery_and_quarry",
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
	"strategic_suggest_auto_layers",
	"blueprint_builds_wooden_door",
	"blueprint_builds_platform",
	"strategic_template_phases_and_passage",
	"strategic_hard_rejects_human_overlap",
	"strategic_replan_hysteresis",
	"strategic_destroyed_task_reactivated",
	"strategic_candidate_intent_anchor_footprint",
	"strategic_hard_rejects_barrier",
	"human_blueprint_reservation_exclusive"
};

string AIBT_ScenarioName(const int index)
{
	if (index < 0 || index >= int(AIBT_SCENARIOS.length)) return "unknown";
	return AIBT_SCENARIOS[index];
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
	u16 killed = 0;
	for (uint i = 0; i < AIBT_spawned_ids.length; i++)
	{
		CBlob@ blob = getBlobByNetworkID(AIBT_spawned_ids[i]);
		if (blob !is null)
		{
			if (blob.getName() == "aibuilder") AIBP_ReleaseBuilderReservation(u8(blob.getTeamNum()), blob.getNetworkID());
			blob.set_u8("ai builder state", AIBT_IDLE);
			blob.set_netid("ai builder target", 0);
			blob.Tag("dead");
			blob.server_Die();
			killed++;
		}
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
		"mat_wood", "mat_stone", "log", "seed", "tree_pine", "tree_bushy",
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

	getRules().SetCurrentState(GAME);
	getRules().set_bool("aib test resource barrier", false);
	getRules().set_u16("barrier_x1", 0);
	getRules().set_u16("barrier_x2", 0);
	AIB_LogEvent("test", "cleanup", "runner", "killed=" + killed);
	AIBT_spawned_ids.clear();
	AIBT_ClearScenarioRefs();
}

CBlob@ AIBT_Spawn(const string &in name, const u8 team, Vec2f pos)
{
	CBlob@ blob = server_CreateBlob(name, team, pos);
	if (blob !is null)
	{
		blob.Tag("aibt test fixture");
		AIBT_spawned_ids.push_back(blob.getNetworkID());
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
	CBlob@ tree = AIBT_Spawn("tree_pine", 0, AIBT_Pos(tileX, AIBT_GROUND_Y - 3));
	if (tree !is null)
	{
		// Targeting tests use harvest-ready fixtures unless they explicitly test growth.
		tree.set_u8("grown_times", 15);
	}
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
	CBlob@ tree = AIBT_Spawn("tree_pine", 0, AIBT_Pos(tileX, tileY));
	if (tree !is null)
	{
		// Targeting tests use harvest-ready fixtures unless they explicitly test growth.
		tree.set_u8("grown_times", 15);
	}
	if (tree !is null && selected)
	{
		tree.set_bool("aibuilder selected tree", true);
		tree.Sync("aibuilder selected tree", true);
		tree.Tag("aibuilder selected tree");
		AIB_LogEvent("test", "select_tree", AIBT_BlobRef(tree), "selected=true pos=" + AIB_EventPos(tree.getPosition()));
	}
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
	CBlob@ material = server_CreateBlob(name, bot.getTeamNum(), bot.getPosition());
	if (material !is null)
	{
		material.Tag("aibt test fixture");
		AIBT_spawned_ids.push_back(material.getNetworkID());
		material.server_SetQuantity(quantity);
		bot.server_PutInInventory(material);
		AIB_LogEvent("test", "give_inventory", AIBT_BlobRef(bot), "item=" + name + " quantity=" + quantity);
	}
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
	array<u16> empty;
	rules.set("aibuilder blueprint data", empty);
	rules.set_u16("aibuilder blueprint width", 0);
	rules.set_u16("aibuilder blueprint height", 0);
	rules.set("aibuilder blueprint data team 0", empty);
	rules.set_u16("aibuilder blueprint width team 0", 0);
	rules.set_u16("aibuilder blueprint height team 0", 0);
	rules.set("aibuilder blueprint data team 1", empty);
	rules.set_u16("aibuilder blueprint width team 1", 0);
	rules.set_u16("aibuilder blueprint height team 1", 0);
	for (u8 team = 0; team < 2; team++)
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

void AIBT_SetupScenario(const int index)
{
	AIBT_CleanupScenario();
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
			AIBT_SpawnMaterial("mat_wood", 382, 80);
			AIBT_SpawnMaterial("mat_stone", 383, 80);
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
			AIBT_SpawnTent(54);
			@bot = AIBT_SpawnBot(54);
			CBlob@ building = AIBT_Spawn("building", 0, AIBT_Pos(58, AIBT_GROUND_Y - 2));
			AIBT_SetBlob("aibt_expected", building);
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
			AIBT_SetStrategicResult(humanSet && published && otherPublished && preserved && metadata,
				"human_priority=true ai_published=true team_isolation=true metadata=true", "layer_merge_team_or_metadata_failed");
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

		case 32:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
			const u16 y = AIBT_GROUND_Y - 1;
			getRules().set_u8(AIBP_ModeKey(0), AIBP_StrategyMode::suggest);
			BlueprintPlan@ plan = AIBT_NewStrategicPlan(0, "mode_test");
			plan.tasks.push_back(BlueprintTask(388, y, AIBP_PLATFORM, AIBP_Phase::access));
			const bool published = AIBP_PublishAIPlan(plan, false);
			array<u16>@ compat = null; AIBP_GetCompatibilityGrid(0, @compat);
			const uint at = y * getMap().tilemapwidth + 388;
			const bool suggestOnly = published && compat !is null && compat[at] == 0 && AIBP_GetDisplayTile(0, 388, y) == AIBP_PLATFORM;
			AIBP_SetAIWorkEnabled(0, true); AIBP_GetCompatibilityGrid(0, @compat);
			const bool autoActive = compat !is null && compat[at] == AIBP_PLATFORM;
			AIBT_SetStrategicResult(suggestOnly && autoActive, "suggest_ghost=true auto_work=true", "mode_layers_failed");
			break;
		}

		case 33:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384); AIBT_DisableStarterMaterials(bot);
			AIBT_GiveMaterial(bot, "mat_wood", 60);
			AIBP_SetHumanTile(0, 394, AIBT_GROUND_Y - 1, AIBP_EncodeBlock(AIBP_WOOD_DOOR, 1));
			AIBT_StartBlueprint(bot, false);
			break;
		}

		case 34:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384); AIBT_DisableStarterMaterials(bot);
			AIBT_GiveMaterial(bot, "mat_wood", 40);
			CMap@ map = getMap();
			if (map !is null) map.server_SetTile(AIBT_Pos(394, AIBT_GROUND_Y - 1), CMap::tile_wood_back);
			AIBP_SetHumanTile(0, 394, AIBT_GROUND_Y - 1, AIBP_PLATFORM);
			AIBT_StartBlueprint(bot, false);
			break;
		}

		case 35:
		{
			AIBT_SpawnTent(382); @bot = AIBT_SpawnBot(384);
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
			const bool dependency = AIBS_CandidateHasDependencySupport(candidate);
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

		case 36:
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

		case 37:
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

		case 38:
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

		case 39:
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

		case 40:
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

		case 41:
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

	}
}

bool AIBT_EvaluateScenario(const int index, const u32 elapsed, string &out failure, string &out details)
{
	CBlob@ bot = AIBT_GetBlob("aibt_bot");
	CBlob@ tent = AIBT_GetBlob("aibt_tent");
	CBlob@ expected = AIBT_GetBlob("aibt_expected");
	details = "";
	failure = "";

	if (bot is null)
	{
		failure = "bot_missing";
		return true;
	}
	if (!AIBT_MapFixtureIntact(failure))
	{
		return true;
	}
	if (bot.getPosition().y > (AIBT_GROUND_Y + 8) * 8)
	{
		failure = "bot_fell_below_fixture_floor " + AIBT_DescribeBuilder(bot);
		return true;
	}

	switch (index)
	{
		case 0:
		{
			if (tent !is null && AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f) > 0)
			{
				details = "wood_in_crates=" + AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f) +
					" crates=" + AIBT_CountBlobsNear("crate", tent.getPosition(), 140.0f) +
					" buildershops=" + AIBT_CountBlobsNear("buildershop", tent.getPosition(), 140.0f);
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
				details = "wood_in_crates=" + AIBT_CountMaterialInCratesNear("mat_wood", tent.getPosition(), 140.0f) +
					" crates=" + AIBT_CountBlobsNear("crate", tent.getPosition(), 140.0f) +
					" buildershops=" + AIBT_CountBlobsNear("buildershop", tent.getPosition(), 140.0f);
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
			const bool stoneBuilt = AIBT_BlueprintTileBuilt(394, AIBT_GROUND_Y - 1, CMap::tile_castle);
			const bool woodBuilt = AIBT_BlueprintTileBuilt(395, AIBT_GROUND_Y - 1, CMap::tile_wood);
			if (stoneBuilt && woodBuilt && AIBT_CountInventoryMaterial(bot, "mat_wood") >= 60 && AIBT_CountInventoryMaterial(bot, "mat_stone") >= 60)
			{
				details = "blueprint_materials_collected=true stone_built=true wood_built=true " + AIBT_DescribeBuilder(bot);
				return true;
			}
			if (elapsed > 300)
			{
				failure = "timeout_blueprint_materials " + AIBT_DescribeBuilder(bot);
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

		case 26:
		case 27:
		case 28:
		case 29:
		case 30:
		case 31:
		case 32:
		case 35:
		case 36:
		case 37:
		case 38:
		case 39:
		case 40:
		case 41:
		{
			const bool passed = getRules().get_bool("aibt strategic result");
			details = getRules().get_string("aibt strategic details");
			if (!passed) failure = getRules().get_string("aibt strategic failure");
			return true;
		}

		case 33:
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

		case 34:
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
	}

	return false;
}
