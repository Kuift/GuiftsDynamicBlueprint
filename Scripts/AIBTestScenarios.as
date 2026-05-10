#include "AIBTestEventLog.as";
#include "AIBTestAssertions.as";

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
	"tree_selection_toggle_filtering"
};

string AIBT_ScenarioName(const int index)
{
	if (index < 0 || index >= int(AIBT_SCENARIOS.length)) return "unknown";
	return AIBT_SCENARIOS[index];
}

void AIBT_PrepareArena(const bool wall = false, const bool lowObstacle = false)
{
	CMap@ map = getMap();
	if (map is null) return;

	const int maxX = Maths::Min(AIBT_ORIGIN_X + AIBT_WIDTH, map.tilemapwidth - 2);
	const int maxY = Maths::Min(AIBT_GROUND_Y + 10, map.tilemapheight - 2);

	for (int x = AIBT_ORIGIN_X; x < maxX; x++)
	{
		for (int y = 8; y < maxY; y++)
		{
			Vec2f pos = Vec2f(x * 8 + 4, y * 8 + 4);
			map.server_SetTile(pos, y >= AIBT_GROUND_Y ? CMap::tile_ground : CMap::tile_empty);
		}
	}

	if (wall)
	{
		for (int y = AIBT_GROUND_Y - 11; y < AIBT_GROUND_Y; y++)
		{
			map.server_SetTile(Vec2f(72 * 8 + 4, y * 8 + 4), CMap::tile_castle);
		}
	}

	if (lowObstacle)
	{
		for (int y = AIBT_GROUND_Y - 3; y < AIBT_GROUND_Y; y++)
		{
			map.server_SetTile(Vec2f(82 * 8 + 4, y * 8 + 4), CMap::tile_castle);
		}
	}
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

	AIB_LogEvent("test", "cleanup", "runner", "killed=" + killed);
	AIBT_spawned_ids.clear();
	getRules().SetCurrentState(GAME);
	getRules().set_u16("barrier_x1", 0);
	getRules().set_u16("barrier_x2", 0);
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

CBlob@ AIBT_SpawnTent(const int tileX)
{
	CBlob@ tent = AIBT_Spawn("tent", 0, AIBT_Pos(tileX, AIBT_GROUND_Y - 2));
	AIBT_SetBlob("aibt_tent", tent);
	return tent;
}

CBlob@ AIBT_SpawnBot(const int tileX)
{
	CBlob@ bot = AIBT_Spawn("aibuilder", 0, AIBT_Pos(tileX, AIBT_GROUND_Y - 2));
	AIBT_SetBlob("aibt_bot", bot);
	return bot;
}

CBlob@ AIBT_SpawnTree(const int tileX, const bool selected = false)
{
	CBlob@ tree = AIBT_Spawn("tree_pine", 0, AIBT_Pos(tileX, AIBT_GROUND_Y - 3));
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
	AIBT_PrepareArena(false, false);

	CMap@ map = getMap();
	if (map is null) return;

	for (int x = 52; x <= 82; x++)
	{
		int top = AIBT_GROUND_Y;
		if (x <= 62)
		{
			top = 64;
		}
		else if (x <= 76)
		{
			top = 64 + ((x - 62) / 2);
		}

		for (int y = top; y < AIBT_GROUND_Y; y++)
		{
			map.server_SetTile(Vec2f(x * 8 + 4, y * 8 + 4), CMap::tile_ground);
		}
	}

	for (int y = 65; y < AIBT_GROUND_Y; y++)
	{
		map.server_SetTile(Vec2f(75 * 8 + 4, y * 8 + 4), CMap::tile_ground);
	}
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
	bot.set_netid("ai builder target", 0);
	bot.set_Vec2f("ai builder destination", Vec2f_zero);
	AIB_LogEvent("test", "start_harvest", AIBT_BlobRef(bot), "state=find_tree pos=" + AIB_EventPos(bot.getPosition()));
}

void AIBT_ForceState(CBlob@ bot, const u8 state)
{
	if (bot is null) return;
	bot.set_u8("ai builder state", state);
	bot.set_netid("ai builder target", 0);
	bot.set_Vec2f("ai builder destination", Vec2f_zero);
	AIB_LogEvent("test", "force_state", AIBT_BlobRef(bot), "state=" + AIBT_StateName(state) + " pos=" + AIB_EventPos(bot.getPosition()));
}

void AIBT_GiveWood(CBlob@ bot, const u16 quantity = 100)
{
	if (bot is null) return;
	CBlob@ wood = server_CreateBlob("mat_wood", bot.getTeamNum(), bot.getPosition());
	if (wood !is null)
	{
		wood.Tag("aibt test fixture");
		AIBT_spawned_ids.push_back(wood.getNetworkID());
		wood.server_SetQuantity(quantity);
		bot.server_PutInInventory(wood);
		AIB_LogEvent("test", "give_inventory", AIBT_BlobRef(bot), "item=mat_wood quantity=" + quantity);
	}
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

void AIBT_SetupScenario(const int index)
{
	AIBT_CleanupScenario();
	getRules().set_string("aib test scenario", AIBT_ScenarioName(index));

	if (index == 10)
	{
		AIBT_PrepareArena(true, false);
	}
	else if (index == 11)
	{
		AIBT_PrepareArena(false, true);
	}
	else
	{
		AIBT_PrepareArena(false, false);
	}

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
			AIBT_SpawnTent(76);
			@bot = AIBT_SpawnBot(78);
			CBlob@ selected = AIBT_SpawnTreeAt(72, 61, true);
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
			getRules().SetCurrentState(WARMUP);
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
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(62);
			CBlob@ wallSafe = AIBT_SpawnTree(80, false);
			AIBT_Spawn("knight", 1, AIBT_Pos(76, AIBT_GROUND_Y - 2));
			AIBT_SetBlob("aibt_expected", wallSafe);
			AIBT_StartHarvest(bot);
			break;
		}

		case 11:
		{
			AIBT_SpawnTent(38);
			@bot = AIBT_SpawnBot(54);
			CBlob@ obstacleTree = AIBT_SpawnTree(96, false);
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

	switch (index)
	{
		case 0:
		{
			if (tent !is null && AIBT_CountMaterialNear("mat_wood", tent.getPosition(), 36.0f) > 0)
			{
				details = "wood_at_tent=" + AIBT_CountMaterialNear("mat_wood", tent.getPosition(), 36.0f);
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
			if (tent !is null && AIBT_CountMaterialNear("mat_wood", tent.getPosition(), 36.0f) > 0 && AIBT_CountInventoryMaterial(bot, "mat_wood") == 0)
			{
				details = "wood_at_tent=" + AIBT_CountMaterialNear("mat_wood", tent.getPosition(), 36.0f);
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
			if (target is expected || bot.getPosition().x > 82 * 8)
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
			if (bot.get_u8("ai builder state") == AIBT_IDLE)
			{
				if (AIBT_CountInventoryMaterial(bot, "mat_wood") > 0 && AIBT_CountMaterialNear("mat_wood", bot.getPosition(), 32.0f) == 0)
				{
					details = "resource_retained=true";
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
	}

	return false;
}
