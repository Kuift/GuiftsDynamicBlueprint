#define SERVER_ONLY

#include "AIBStrategyEventLog.as";
#include "AIBPlacementPlanner.as";
#include "AutoBuilderCommon.as";
#include "ArcherCommon.as";
#include "AIBWorldFingerprint.as";

const u32 AIBW_ARCHER_FIRE_CYCLE = 52;
const u32 AIBW_ARCHER_DRAW_TICKS = 40;
const u16 AIBW_ARCHER_ARROWS = 60;

u32 AIBW_DesiredPlanCost(const u8 team)
{
	array<u16>@ desired = null;
	if (!AIBP_GetLayerGrid(team, AIBP_Layer::ai_desired, @desired) || desired is null) return 0;
	u32 total = 0;
	for (uint i = 0; i < desired.length; i++) total += AIBP_BlockCost(desired[i]);
	return total;
}

AIBPlanCandidate@ AIBW_CurrentCandidate(const u8 team)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return null;
	AIBPlanCandidate@ candidate = AIBPlanCandidate();
	candidate.intent = getRules().get_u8(AIBP_PlanKey(team, "intent"));
	candidate.anchor = getRules().get_Vec2f(AIBP_PlanKey(team, "anchor"));
	for (uint i = 0; i < xs.length && i < ys.length && i < blocks.length && i < phases.length; i++)
		candidate.tasks.push_back(BlueprintTask(xs[i], ys[i], blocks[i], phases[i]));
	return candidate;
}

void onInit(CRules@ this)
{
	this.set_bool("aib wave running", false);
	this.set_bool("aib wave enabled", false);
	this.set_bool("aib wave initial captured", false);
	this.set_string("aib wave initial fingerprint", "");
	this.set_string("aib wave measurement fingerprint", "");
}

void onRestart(CRules@ this)
{
	this.set_bool("aib wave running", false);
	this.set_bool("aib wave enabled", false);
	this.set_bool("aib wave initial captured", false);
	this.set_string("aib wave initial fingerprint", "");
	this.set_string("aib wave measurement fingerprint", "");
	this.set_bool("aib strategy event log enabled", false);
}

string AIBW_InitialMetrics(CRules@ rules)
{
	return " fixture_id=" + rules.get_string("aib wave fixture id") +
		" fixture_version=" + rules.get_u16("aib wave fixture version") +
		" team=" + rules.get_u8("aib wave team") +
		" team_side=" + rules.get_string("aib wave team side") +
		" initial_fingerprint=" + rules.get_string("aib wave initial fingerprint") +
		" measurement_fingerprint=" + rules.get_string("aib wave measurement fingerprint") +
		" initial_map_hash=" + rules.get_u32("aib wave initial map hash") +
		" initial_terrain_hash=" + rules.get_u32("aib wave initial terrain hash") +
		" initial_map_width=" + rules.get_u16("aib wave initial map width") +
		" initial_map_height=" + rules.get_u16("aib wave initial map height") +
		" initial_solid_tiles=" + rules.get_u32("aib wave initial solid tiles") +
		" initial_no_build_hash=" + rules.get_u32("aib wave initial no build hash") +
		" initial_no_build_tiles=" + rules.get_u32("aib wave initial no build tiles") +
		" initial_manifest_blob_count=" + rules.get_u32("aib wave initial manifest blob count") +
		" initial_manifest_blob_hash=" + rules.get_u32("aib wave initial manifest blob hash") +
		" initial_manifest_inventory_hash=" + rules.get_u32("aib wave initial manifest inventory hash") +
		" initial_manifest_strategy_hash=" + rules.get_u32("aib wave initial manifest strategy hash") +
		" measurement_terrain_hash=" + rules.get_u32("aib wave measurement terrain hash") +
		" measurement_no_build_hash=" + rules.get_u32("aib wave measurement no build hash") +
		" measurement_blob_hash=" + rules.get_u32("aib wave measurement blob hash") +
		" measurement_inventory_hash=" + rules.get_u32("aib wave measurement inventory hash") +
		" measurement_strategy_hash=" + rules.get_u32("aib wave measurement strategy hash") +
		" initial_home_x=" + rules.get_s32("aib wave initial home x") +
		" initial_home_y=" + rules.get_s32("aib wave initial home y") +
		" initial_enemy_home_x=" + rules.get_s32("aib wave initial enemy home x") +
		" initial_enemy_home_y=" + rules.get_s32("aib wave initial enemy home y") +
		" initial_ai_builders=" + rules.get_u16("aib wave initial ai builders") +
		" initial_normal_ai_builders=" + rules.get_u16("aib wave initial normal ai builders") +
		" initial_autobuilders=" + rules.get_u16("aib wave initial autobuilders") +
		" initial_ai_builder_type_position_hash=" + rules.get_u32("aib wave initial ai builder type position hash") +
		" initial_autobuilder_speed_level=" + rules.get_u8("aib wave initial autobuilder speed level") +
		" initial_friendly_units=" + rules.get_u16("aib wave initial friendly units") +
		" initial_enemy_units=" + rules.get_u16("aib wave initial enemy units") +
		" initial_trees=" + rules.get_u16("aib wave initial trees") +
		" initial_tree_hash=" + rules.get_u32("aib wave initial tree hash") +
		" initial_wood=" + rules.get_u16("aib wave initial wood") +
		" initial_stone=" + rules.get_u16("aib wave initial stone") +
		" initial_plan_id=" + rules.get_u16("aib wave initial plan id") +
		" initial_plan_status=" + rules.get_u8("aib wave initial plan status") +
		" initial_plan_pending=" + rules.get_u16("aib wave initial plan pending") +
		" initial_plan_completed=" + rules.get_u16("aib wave initial plan completed");
}

bool AIBW_CaptureMeasurementState(CRules@ rules, const u8 team)
{
	if (rules is null) return false;
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0) return false;

	u32 terrainHash = 0;
	u32 solidTiles = 0;
	u32 noBuildHash = 0;
	u32 noBuildTiles = 0;
	u32 blobCount = 0;
	u32 blobHash = 0;
	u32 inventoryHash = 0;
	u32 strategyHash = 0;
	const string fingerprint = AIBWF_CaptureWorldManifest(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,
		blobCount, blobHash, inventoryHash, strategyHash);
	if (fingerprint == "") return false;
	rules.set_string("aib wave measurement fingerprint", fingerprint);
	rules.set_u32("aib wave measurement terrain hash", terrainHash);
	rules.set_u32("aib wave measurement no build hash", noBuildHash);
	rules.set_u32("aib wave measurement blob hash", blobHash);
	rules.set_u32("aib wave measurement inventory hash", inventoryHash);
	rules.set_u32("aib wave measurement strategy hash", strategyHash);
	return true;
}

void AIBW_Abort(CRules@ rules, const string &in reason, AIBPlanCandidate@ candidate)
{
	const u8 team = rules.get_u8("aib wave team");
	AIBS_Log("wave_abort", team, "seed=" + rules.get_u32("aib wave seed") +
		" variant=" + rules.get_string("aib wave variant") + " scenario=" + rules.get_string("aib wave scenario") +
		" reason=" + reason + " plan=" + rules.get_u16(AIBP_PlanKey(team, "id")) +
		" status=" + rules.get_u8(AIBP_PlanKey(team, "status")) +
		" tasks=" + (candidate is null ? 0 : candidate.tasks.length) +
		" cost=" + AIBW_DesiredPlanCost(team) + AIBW_InitialMetrics(rules));
	rules.set_bool("aib wave enabled", false);
	rules.set_bool("aib wave running", false);
	rules.set_bool("aib wave initial captured", false);
	rules.set_string("aib wave initial fingerprint", "");
	rules.set_string("aib wave measurement fingerprint", "");
	rules.set_bool("aib strategy event log enabled", false);
}

bool AIBW_Start(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	if (!rules.get_bool("aib wave initial captured") || rules.get_string("aib wave initial fingerprint") == "")
	{
		AIBW_Abort(rules, "missing_initial_state", null);
		return false;
	}
	if (!AIBW_CaptureMeasurementState(rules, team))
	{
		AIBW_Abort(rules, "missing_measurement_state", null);
		return false;
	}
	AIBPlanCandidate@ candidate = AIBW_CurrentCandidate(team);
	const u16 planID = rules.get_u16(AIBP_PlanKey(team, "id"));
	const u8 planStatus = rules.get_u8(AIBP_PlanKey(team, "status"));
	const u32 planCost = AIBW_DesiredPlanCost(team);
	if (rules.get_string("aib wave variant") == "plan" &&
		(planID == 0 || (planStatus != 1 && planStatus != 2) || candidate is null || candidate.tasks.length == 0 || planCost == 0))
	{
		AIBW_Abort(rules, "no_nonempty_active_plan", candidate);
		return false;
	}
	rules.set_bool("aib wave running", true);
	rules.set_u32("aib wave start tick", getGameTime());
	rules.set_u8("aib wave spawned", 0);
	rules.set_u8("aib wave crossings", 0);
	rules.set_u8("aib wave deaths", 0);
	rules.set_u8("aib wave builder deaths", 0);
	rules.set_u8("aib wave flag approaches", 0);
	rules.set_u16("aib wave reservation conflicts", 0);
	rules.set_u16("aib wave replans", 0);
	rules.set_u16("aib wave damage events", 0);
	rules.set_u32("aib wave damage cost", 0);
	rules.set_u32("aib wave first breach", 0);
	rules.set_bool("aib wave breached", false);
	rules.set_u32("aib wave completion tick", 0);
	rules.set_u32("aib wave first damage tick", 0);
	rules.set_f32("aib wave builder travel", 0.0f);
	rules.set_u32("aib wave builder idle", 0);
	rules.set_u32("aib wave plan cost", planCost);
	rules.set_u16("aib wave completed start", rules.get_u16(AIBP_PlanKey(team, "completed")));
	rules.set_u16("aib wave damaged start", rules.get_u16(AIBP_PlanKey(team, "damaged")));
	const f32 routePenalty = candidate is null ? 0.0f : AIBS_FriendlyRoutePenalty(candidate);
	rules.set_f32("aib wave friendly route penalty", routePenalty);
	rules.set_bool("aib wave route preserved", routePenalty < 1.0f);
	rules.set_u16("aib wave plan tasks", candidate is null ? 0 : candidate.tasks.length);
	if (candidate !is null && candidate.tasks.length > 0 && rules.get_u16(AIBP_PlanKey(team, "pending")) == 0)
		rules.set_u32("aib wave completion tick", 1); // Plan was already complete when the measured wave began.
	AIBS_Log("wave_start", team, "seed=" + rules.get_u32("aib wave seed") + " variant=" + rules.get_string("aib wave variant") +
		" scenario=" + rules.get_string("aib wave scenario") + " pending=" + rules.get_u16(AIBP_PlanKey(team, "pending")) +
		" completed=" + rules.get_u16(AIBP_PlanKey(team, "completed")) + " cost=" + rules.get_u32("aib wave plan cost") +
		" route_preserved=" + rules.get_bool("aib wave route preserved") + AIBW_InitialMetrics(rules));
	return true;
}

void AIBW_EquipArcher(CBlob@ unit)
{
	if (unit is null || unit.getName() != "archer") return;
	CBlob@ arrows = server_CreateBlobNoInit("mat_arrows");
	bool equipped = false;
	if (arrows !is null)
	{
		arrows.Tag("custom quantity");
		arrows.Init();
		arrows.server_SetQuantity(AIBW_ARCHER_ARROWS);
		equipped = unit.server_PutInInventory(arrows);
		if (!equipped) arrows.setPosition(unit.getPosition());
	}
	if (!equipped) return;
	ArcherInfo@ archer;
	if (unit.get("archerInfo", @archer) && archer !is null)
	{
		archer.arrow_type = ArrowType::normal;
		archer.has_arrow = true;
		archer.charge_state = ArcherParams::not_aiming;
		archer.charge_time = 0;
	}
	unit.set_bool("has_arrow", true);
	unit.Sync("has_arrow", true);
}

void AIBW_SpawnUnit(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	const u8 enemyTeam = team == 0 ? 1 : 0;
	const u8 index = rules.get_u8("aib wave spawned");
	const u32 seed = rules.get_u32("aib wave seed");
	AIBWorldState@ world = AIBS_ObserveWorld(team);
	if (world is null || world.home == Vec2f_zero) return;
	Vec2f spawn = world.enemyHome;
	if (spawn == Vec2f_zero)
	{
		CMap@ map = getMap();
		spawn = Vec2f(world.enemyDirection > 0 ? map.tilemapwidth * map.tilesize - 24 : 24, world.home.y);
	}
	const string scenario = rules.get_string("aib wave scenario");
	const bool archer = scenario == "archer" || (scenario == "mixed" && ((seed + index * 17) % 4) == 0);
	const u32 formation = (seed * u32(1103515245)) ^ (u32(index + 1) * u32(2654435761));
	const f32 yOffset = -f32(formation % 5) * 4.0f;
	CBlob@ unit = server_CreateBlob(archer ? "archer" : "knight", enemyTeam, spawn + Vec2f(0, yOffset));
	if (unit !is null)
	{
		unit.Tag("aib strategy wave unit");
		unit.set_u8("aib wave target team", team);
		unit.set_u8("aib wave spawn index", index);
		unit.set_u32("aib wave spawn tick", getGameTime());
		AIBW_EquipArcher(unit);
	}
	rules.set_u8("aib wave spawned", index + 1);
}

void AIBW_ThrowBomb(CBlob@ unit, CBlob@ home)
{
	if (unit is null || home is null || unit.hasTag("aib wave bomb thrown")) return;
	if ((home.getPosition() - unit.getPosition()).Length() > 176.0f) return;
	unit.Tag("aib wave bomb thrown");
	const f32 direction = home.getPosition().x >= unit.getPosition().x ? 1.0f : -1.0f;
	CBlob@ bomb = server_CreateBlob("bomb", unit.getTeamNum(), unit.getPosition() + Vec2f(direction * 8.0f, -4.0f));
	if (bomb !is null)
	{
		bomb.set_u16("explosive_parent", unit.getNetworkID());
		bomb.setVelocity(Vec2f(direction * 6.5f, -2.0f));
		bomb.Tag("aib strategy wave bomb");
	}
}

void AIBW_DriveUnits(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	CBlob@ home = AIBS_TeamHomeBlob(team);
	if (home is null) return;
	CBlob@[] units;
	getBlobsByTag("aib strategy wave unit", @units);
	for (uint i = 0; i < units.length; i++)
	{
		CBlob@ unit = units[i];
		if (unit is null || unit.hasTag("dead")) continue;
		const f32 direction = home.getPosition().x >= unit.getPosition().x ? 1.0f : -1.0f;
		unit.setKeyPressed(direction > 0 ? key_right : key_left, true);
		const bool isArcher = unit.getName() == "archer";
		const u32 age = getGameTime() - unit.get_u32("aib wave spawn tick");
		const bool attackPressed = !isArcher || age % AIBW_ARCHER_FIRE_CYCLE < AIBW_ARCHER_DRAW_TICKS;
		unit.setKeyPressed(key_action1, attackPressed);
		unit.setAimPos(home.getPosition());
		unit.setVelocity(Vec2f(direction * Maths::Max(1.5f, Maths::Abs(unit.getVelocity().x)), unit.getVelocity().y));
		const string scenario = rules.get_string("aib wave scenario");
		if (scenario == "bomb" || (scenario == "mixed" && (unit.get_u8("aib wave spawn index") + rules.get_u32("aib wave seed")) % 3 == 0)) AIBW_ThrowBomb(unit, home);
		if (!unit.hasTag("aib wave approached flag") && (unit.getPosition() - home.getPosition()).Length() <= 80.0f)
		{
			unit.Tag("aib wave approached flag");
			rules.set_u8("aib wave flag approaches", rules.get_u8("aib wave flag approaches") + 1);
		}
		if (!unit.hasTag("aib wave crossed") && Maths::Abs(unit.getPosition().x - home.getPosition().x) <= 16.0f)
		{
			unit.Tag("aib wave crossed");
			rules.set_u8("aib wave crossings", rules.get_u8("aib wave crossings") + 1);
			if (!rules.get_bool("aib wave breached"))
			{
				rules.set_bool("aib wave breached", true);
				rules.set_u32("aib wave first breach", getGameTime() - rules.get_u32("aib wave start tick"));
			}
		}
	}
}

void AIBW_SampleBuilders(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	CBlob@[] builders;
	AIBW_GetConstructionWorkers(builders);
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder is null || builder.hasTag("dead") || builder.getTeamNum() != team) continue;
		const string key = "aib wave builder last " + builder.getNetworkID();
		Vec2f last = rules.get_Vec2f(key);
		if (last != Vec2f_zero) rules.set_f32("aib wave builder travel", rules.get_f32("aib wave builder travel") + (builder.getPosition() - last).Length());
		rules.set_Vec2f(key, builder.getPosition());
		if (builder.get_u8("ai builder state") == 0) rules.set_u32("aib wave builder idle", rules.get_u32("aib wave builder idle") + 1);
	}
	const u32 elapsed = getGameTime() - rules.get_u32("aib wave start tick");
	if (rules.get_u16("aib wave plan tasks") > 0 && rules.get_u32("aib wave completion tick") == 0 && rules.get_u16(AIBP_PlanKey(team, "pending")) == 0)
		rules.set_u32("aib wave completion tick", elapsed);
	if (rules.get_u32("aib wave first damage tick") == 0 && rules.get_u16(AIBP_PlanKey(team, "damaged")) > rules.get_u16("aib wave damaged start"))
		rules.set_u32("aib wave first damage tick", elapsed);
}

void AIBW_GetConstructionWorkers(array<CBlob@> &out builders)
{
	builders.clear();
	string[] names = { "aibuilder", "autobuilder" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] named;
		getBlobsByName(names[n], @named);
		for (uint i = 0; i < named.length; i++) builders.push_back(named[i]);
	}
}

void AIBW_Finish(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	const u32 elapsed = getGameTime() - rules.get_u32("aib wave start tick");
	const u32 absorbedCost = rules.get_u32("aib wave damage cost");
	const u32 completionTick = rules.get_u32("aib wave completion tick");
	const u32 structureLifetime = completionTick == 0 || completionTick >= elapsed ? 0 : elapsed - completionTick;
	AIBS_Log("wave_result", team, "seed=" + rules.get_u32("aib wave seed") +
		" variant=" + rules.get_string("aib wave variant") + " scenario=" + rules.get_string("aib wave scenario") + " elapsed=" + elapsed +
		" breached=" + rules.get_bool("aib wave breached") + " first_breach=" + rules.get_u32("aib wave first breach") + " crossings=" + rules.get_u8("aib wave crossings") +
		" enemy_deaths=" + rules.get_u8("aib wave deaths") + " builder_deaths=" + rules.get_u8("aib wave builder deaths") +
		" flag_approaches=" + rules.get_u8("aib wave flag approaches") + " plan_completed_delta=" +
			(int(rules.get_u16(AIBP_PlanKey(team, "completed"))) - int(rules.get_u16("aib wave completed start"))) +
		" plan_pending=" + rules.get_u16(AIBP_PlanKey(team, "pending")) + " plan_damaged=" + rules.get_u16(AIBP_PlanKey(team, "damaged")) +
		" damage_events=" + rules.get_u16("aib wave damage events") +
		" damage_absorbed_cost=" + absorbedCost + " plan_cost=" + rules.get_u32("aib wave plan cost") + " completion_tick=" + rules.get_u32("aib wave completion tick") +
		" first_damage_tick=" + rules.get_u32("aib wave first damage tick") + " structure_lifetime=" + structureLifetime +
		" builder_travel=" + rules.get_f32("aib wave builder travel") + " builder_idle_ticks=" + rules.get_u32("aib wave builder idle") +
		" reservation_conflicts=" + rules.get_u16("aib wave reservation conflicts") + " replans=" + rules.get_u16("aib wave replans") +
		" route_preserved=" + rules.get_bool("aib wave route preserved") + " friendly_route_penalty=" + rules.get_f32("aib wave friendly route penalty") +
		AIBW_InitialMetrics(rules));
	rules.set_bool("aib wave enabled", false);
	rules.set_bool("aib wave running", false);
	rules.set_bool("aib wave initial captured", false);
	rules.set_string("aib wave initial fingerprint", "");
	rules.set_string("aib wave measurement fingerprint", "");
	rules.set_bool("aib strategy event log enabled", false);
}

void onTick(CRules@ this)
{
	if (!isServer() || !this.get_bool("aib wave enabled")) return;
	if (!this.get_bool("aib wave running"))
	{
		if (getGameTime() < this.get_u32("aib wave arm tick")) return;
		if (!AIBW_Start(this)) return;
	}
	const u32 elapsed = getGameTime() - this.get_u32("aib wave start tick");
	const u32 spawnInterval = 40 + (this.get_u32("aib wave seed") % 11);
	if (this.get_u8("aib wave spawned") < 12 && elapsed % spawnInterval == 1) AIBW_SpawnUnit(this);
	AIBW_DriveUnits(this);
	AIBW_SampleBuilders(this);
	if (elapsed >= 1200 || (this.get_u8("aib wave spawned") >= 12 && this.get_u8("aib wave crossings") + this.get_u8("aib wave deaths") >= 12)) AIBW_Finish(this);
}

void onBlobDie(CRules@ this, CBlob@ blob)
{
	if (!isServer() || blob is null || !this.get_bool("aib wave running")) return;
	if (blob.hasTag("aib strategy wave unit")) this.set_u8("aib wave deaths", this.get_u8("aib wave deaths") + 1);
	else if ((blob.getName() == "aibuilder" || blob.getName() == "autobuilder") &&
		blob.getTeamNum() == this.get_u8("aib wave team"))
		this.set_u8("aib wave builder deaths", this.get_u8("aib wave builder deaths") + 1);
}
