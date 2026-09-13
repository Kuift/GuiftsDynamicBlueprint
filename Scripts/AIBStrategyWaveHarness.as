#define SERVER_ONLY

#include "AIBStrategyEventLog.as";
#include "ArcherCommon.as";
#include "AIBManualOrderCommon.as";
#include "AIBWaveFixtureCommon.as";

const u32 AIBW_ARCHER_FIRE_CYCLE = 52;
const u32 AIBW_ARCHER_DRAW_TICKS = 40;
const u16 AIBW_ARCHER_ARROWS = 60;
const u32 AIBW_JUMP_HOLD_TICKS = 18;
const u32 AIBW_JUMP_RETRY_TICKS = 30;
const u32 AIBW_STALL_TICKS = 12;
const u32 AIBW_WARMUP_TICKS = 1200;
const f32 AIBW_PROGRESS_STEP = 4.0f;
const u8 AIBW_TOTAL_AI_LIMIT = 8;
const u8 AIBW_ATTACKER_LIMIT = 7;
const u8 AIBW_WORKER_LIMIT = 1;
const f32 AIBW_PRESSURE_RADIUS = 96.0f;
const f32 AIBW_CROSSING_RADIUS = 24.0f;
const f32 AIBW_MAX_DRIVE_SPEED = 2.0f;
const string AIBW_DRIVER = "grounded_candidate_corridor_v4_exclusive_spawn_outcomes";
const string AIBW_OUTCOME_CONTRACT = "exclusive_spawn_index_v1";

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
	candidate.templateName = getRules().get_string(AIBP_PlanKey(team, "template"));
	candidate.anchor = getRules().get_Vec2f(AIBP_PlanKey(team, "anchor"));
	for (uint i = 0; i < xs.length && i < ys.length && i < blocks.length && i < phases.length; i++)
		candidate.tasks.push_back(BlueprintTask(xs[i], ys[i], blocks[i], phases[i]));
	return candidate;
}

bool AIBW_CaptureMeasuredPlan(CRules@ rules, const u8 team, AIBPlanCandidate@ candidate)
{
	if (rules is null) return false;
	array<u16> xs, ys, blocks;
	array<u8> healthy, everHealthy;
	u16 healthyCount = 0;
	if (candidate !is null)
	{
		for (uint i = 0; i < candidate.tasks.length; i++)
		{
			BlueprintTask@ task = candidate.tasks[i];
			if (task is null) return false;
			xs.push_back(task.x); ys.push_back(task.y); blocks.push_back(task.block);
			const bool matches = AIBP_MapMatchesBlock(task.x, task.y, task.block, team);
			healthy.push_back(matches ? 1 : 0);
			everHealthy.push_back(matches ? 1 : 0);
			if (matches) healthyCount++;
		}
	}
	rules.set("aib wave measured task x", xs);
	rules.set("aib wave measured task y", ys);
	rules.set("aib wave measured task block", blocks);
	rules.set("aib wave measured task healthy", healthy);
	rules.set("aib wave measured task ever healthy", everHealthy);
	rules.set_u16("aib wave measured healthy start", healthyCount);
	rules.set_u16("aib wave measured healthy", healthyCount);
	rules.set_u16("aib wave measured pending", u16(xs.length) - healthyCount);
	rules.set_u16("aib wave measured damaged", 0);
	const u16 planID = rules.get_u16(AIBP_PlanKey(team, "id"));
	rules.set_u16("aib wave measured plan id", planID);
	rules.set_u16("aib wave observed plan id", planID);
	return candidate is null || xs.length == rules.get_u16("aib wave fixture tasks");
}

bool AIBW_SampleMeasuredPlan(CRules@ rules)
{
	if (rules is null) return false;
	const u8 team = rules.get_u8("aib wave team");
	const u16 currentPlanID = rules.get_u16(AIBP_PlanKey(team, "id"));
	const u16 observedPlanID = rules.get_u16("aib wave observed plan id");
	if (currentPlanID != observedPlanID)
	{
		rules.set_u16("aib wave replans", rules.get_u16("aib wave replans") + 1);
		rules.set_u16("aib wave observed plan id", currentPlanID);
	}

	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null;
	array<u8>@ healthy = null; array<u8>@ everHealthy = null;
	if (!rules.get("aib wave measured task x", @xs) || xs is null ||
		!rules.get("aib wave measured task y", @ys) || ys is null ||
		!rules.get("aib wave measured task block", @blocks) || blocks is null ||
		!rules.get("aib wave measured task healthy", @healthy) || healthy is null ||
		!rules.get("aib wave measured task ever healthy", @everHealthy) || everHealthy is null ||
		xs.length != ys.length || xs.length != blocks.length || xs.length != healthy.length || xs.length != everHealthy.length)
		return false;

	u16 healthyCount = 0;
	u16 damagedCount = 0;
	const u32 elapsed = getGameTime() - rules.get_u32("aib wave start tick");
	for (uint i = 0; i < xs.length; i++)
	{
		const bool matches = AIBP_MapMatchesBlock(xs[i], ys[i], blocks[i], team);
		if (matches)
		{
			healthyCount++;
			everHealthy[i] = 1;
		}
		else if (healthy[i] != 0)
		{
			rules.set_u16("aib wave damage events", rules.get_u16("aib wave damage events") + 1);
			rules.set_u32("aib wave damage cost", rules.get_u32("aib wave damage cost") + AIBP_BlockCost(blocks[i]));
			if (rules.get_u32("aib wave first damage tick") == 0)
				rules.set_u32("aib wave first damage tick", elapsed);
		}
		healthy[i] = matches ? 1 : 0;
		if (!matches && everHealthy[i] != 0) damagedCount++;
	}
	rules.set("aib wave measured task healthy", healthy);
	rules.set("aib wave measured task ever healthy", everHealthy);
	rules.set_u16("aib wave measured healthy", healthyCount);
	rules.set_u16("aib wave measured pending", u16(xs.length) - healthyCount);
	rules.set_u16("aib wave measured damaged", damagedCount);
	if (xs.length > 0 && healthyCount == xs.length && rules.get_u32("aib wave completion tick") == 0)
		rules.set_u32("aib wave completion tick", elapsed == 0 ? 1 : elapsed);
	return true;
}

void onInit(CRules@ this)
{
	this.set_bool("aib wave running", false);
	this.set_bool("aib wave enabled", false);
	this.set_bool("aib wave initial captured", false);
	this.set_string("aib wave initial fingerprint", "");
	this.set_string("aib wave measurement fingerprint", "");
	this.set_bool("aib wave request", false);
	this.set_string("aib wave run id", "");
}

void onRestart(CRules@ this)
{
	this.set_bool("aib wave running", false);
	this.set_bool("aib wave enabled", false);
	this.set_bool("aib wave initial captured", false);
	this.set_string("aib wave initial fingerprint", "");
	this.set_string("aib wave measurement fingerprint", "");
	this.set_bool("aib strategy event log enabled", false);
	this.set_bool("aib wave request", false);
	this.set_string("aib wave run id", "");
}

string AIBW_InitialMetrics(CRules@ rules)
{
	return " fixture_id=" + rules.get_string("aib wave fixture id") +
		" fixture_version=" + rules.get_u16("aib wave fixture version") +
		" team=" + rules.get_u8("aib wave team") +
		" team_side=" + rules.get_string("aib wave team side") +
		" driver=" + AIBW_DRIVER +
		" fixture_template=" + rules.get_string("aib wave fixture template") +
		" fixture_anchor_x=" + rules.get_s32("aib wave fixture anchor x") +
		" fixture_anchor_y=" + rules.get_s32("aib wave fixture anchor y") +
		" fixture_direction=" + rules.get_s32("aib wave fixture direction") +
		" fixture_tasks=" + rules.get_u16("aib wave fixture tasks") +
		" fixture_task_hash=" + rules.get_u32("aib wave fixture task hash") +
		" fixture_corridor_hash=" + rules.get_u32("aib wave fixture corridor hash") +
		" approach_start_x=" + rules.get_Vec2f("aib wave approach start").x +
		" approach_start_y=" + rules.get_Vec2f("aib wave approach start").y +
		" breach_target_x=" + rules.get_Vec2f("aib wave breach target").x +
		" breach_target_y=" + rules.get_Vec2f("aib wave breach target").y +
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
	const string runID = rules.get_string("aib wave run id");
	AIBS_Log("wave_abort", team, "run_id=" + runID + " seed=" + rules.get_u32("aib wave seed") +
		" variant=" + rules.get_string("aib wave variant") + " scenario=" + rules.get_string("aib wave scenario") +
		" reason=" + reason + " plan=" + rules.get_u16(AIBP_PlanKey(team, "id")) +
		" status=" + rules.get_u8(AIBP_PlanKey(team, "status")) +
		" spawned=" + rules.get_u8("aib wave spawned") +
		" archers_spawned=" + rules.get_u8("aib wave archers spawned") +
		" bomb_carriers=" + rules.get_u8("aib wave bomb carriers") +
		" crossings=" + rules.get_u8("aib wave crossings") + " deaths=" + rules.get_u8("aib wave deaths") +
		" arrows_fired=" + rules.get_u16("aib wave arrows fired") +
		" bombs_thrown=" + rules.get_u16("aib wave bombs thrown") +
		" tasks=" + (candidate is null ? 0 : candidate.tasks.length) +
		" cost=" + AIBW_DesiredPlanCost(team) + AIBW_InitialMetrics(rules));
	rules.set_bool("aib wave enabled", false);
	rules.set_bool("aib wave running", false);
	rules.set_bool("aib wave initial captured", false);
	rules.set_string("aib wave initial fingerprint", "");
	rules.set_string("aib wave measurement fingerprint", "");
	rules.set_bool("aib strategy event log enabled", false);
	rules.set_bool("aib event log enabled", rules.get_bool("aib wave previous event log enabled"));
	rules.set_bool("aib wave request", false);
	tcpr("AIBWAVE|ABORT|run=" + runID + "|reason=" + reason);
	if (team < 8)
	{
		rules.set_u8(AIBP_ModeKey(team), AIBP_StrategyMode::off);
		rules.Sync(AIBP_ModeKey(team), true);
	}
	AIBW_StopWaveActors();
}

bool AIBW_CurrentPlanMatchesFixture(CRules@ rules, AIBPlanCandidate@ candidate)
{
	if (rules is null || candidate is null) return false;
	if (candidate.templateName != rules.get_string("aib wave fixture template")) return false;
	if (int(candidate.anchor.x) != rules.get_s32("aib wave fixture anchor x") ||
		int(candidate.anchor.y) != rules.get_s32("aib wave fixture anchor y")) return false;
	return candidate.tasks.length == rules.get_u16("aib wave fixture tasks") &&
		AIBW_FixtureTaskHash(candidate) == rules.get_u32("aib wave fixture task hash");
}

bool AIBW_ValidScenario(const string &in scenario)
{
	return scenario == "knight" || scenario == "archer" || scenario == "bomb" || scenario == "mixed";
}

void AIBW_HandleArmRequest(CRules@ rules)
{
	if (rules is null || !rules.get_bool("aib wave request")) return;
	rules.set_bool("aib wave request", false);
	const u8 team = rules.get_u8("aib wave request team");
	const u32 seed = rules.get_u32("aib wave request seed");
	const string variant = rules.get_string("aib wave request variant");
	const string scenario = rules.get_string("aib wave request scenario");
	string runID = rules.get_string("aib wave request run id");
	if (runID == "") runID = "manual_" + team + "_" + seed + "_" + variant + "_" + scenario + "_" + getGameTime();
	if (rules.get_bool("aib wave enabled") || rules.get_bool("aib wave running") ||
		rules.get_bool("aib gym active") || rules.get_bool("aib infrastructure active"))
	{
		tcpr("AIBWAVE|ABORT|run=" + runID + "|reason=another_episode_active");
		return;
	}
	rules.set_string("aib wave run id", runID);
	rules.set_u8("aib wave team", team);
	rules.set_u32("aib wave seed", seed);
	rules.set_string("aib wave variant", variant);
	rules.set_string("aib wave scenario", scenario);
	rules.set_bool("aib wave previous event log enabled", rules.get_bool("aib event log enabled"));
	rules.set_bool("aib event log enabled", true);
	if (team > 1 || (variant != "control" && variant != "plan") || !AIBW_ValidScenario(scenario))
	{
		AIBW_Abort(rules, "invalid_request", null);
		return;
	}
	array<CBlob@> existingWorkers;
	AIBW_GetConstructionWorkers(existingWorkers);
	for (uint i = 0; i < existingWorkers.length; i++)
	{
		if (existingWorkers[i] !is null && !existingWorkers[i].hasTag("dead"))
		{
			AIBW_Abort(rules, "noncanonical_initial_worker", null);
			return;
		}
	}
	if (!AIBW_CaptureArmState(rules, team))
	{
		tcpr("AIBWAVE|FIXTURE|run=" + runID + "|detail=" + rules.get_string("aib wave fixture capture detail"));
		AIBW_Abort(rules, "fixture_capture_failed", null);
		return;
	}
	rules.set_u8(AIBP_ModeKey(team), variant == "plan" ? AIBP_StrategyMode::auto_mode : AIBP_StrategyMode::off);
	rules.Sync(AIBP_ModeKey(team), true);
	if (variant == "plan") AIBM_ReleaseTeamManualControl(team);
	rules.set_bool("aib strategy event log enabled", true);
	rules.set_u32("aib wave arm tick", getGameTime() + AIBW_WARMUP_TICKS);
	rules.set_bool("aib wave enabled", true);
	rules.set_bool("aib wave running", false);
	tcpr("AIBWAVE|ARMED|run=" + runID + "|template=" + rules.get_string("aib wave fixture template") +
		"|anchor=" + rules.get_s32("aib wave fixture anchor x") + "," + rules.get_s32("aib wave fixture anchor y"));
}

bool AIBW_Start(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	if (!rules.get_bool("aib wave initial captured") || rules.get_string("aib wave initial fingerprint") == "")
	{
		AIBW_Abort(rules, "missing_initial_state", null);
		return false;
	}
	if (!rules.isMatchRunning())
	{
		AIBW_Abort(rules, "match_not_running", null);
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
	const string variant = rules.get_string("aib wave variant");
	if (variant == "plan" &&
		(planID == 0 || (planStatus != 1 && planStatus != 2) || candidate is null || candidate.tasks.length == 0 ||
			planCost == 0 || !AIBW_CurrentPlanMatchesFixture(rules, candidate)))
	{
		AIBW_Abort(rules, "active_plan_does_not_match_fixture", candidate);
		return false;
	}
	if (variant == "control" && (planID != 0 || candidate !is null || planCost != 0))
	{
		AIBW_Abort(rules, "control_plan_contamination", candidate);
		return false;
	}
	array<CBlob@> existingWorkers;
	AIBW_GetConstructionWorkers(existingWorkers);
	u8 liveWorkers = 0;
	for (uint i = 0; i < existingWorkers.length; i++)
	{
		if (existingWorkers[i] !is null && !existingWorkers[i].hasTag("dead")) liveWorkers++;
	}
	if (liveWorkers > AIBW_WORKER_LIMIT || liveWorkers + AIBW_ATTACKER_LIMIT > AIBW_TOTAL_AI_LIMIT)
	{
		AIBW_Abort(rules, "worker_count_exceeds_fixed_pressure_cap", candidate);
		return false;
	}
	rules.set_u8("aib wave spawn limit", AIBW_ATTACKER_LIMIT);
	rules.set_bool("aib wave running", true);
	rules.set_u32("aib wave start tick", getGameTime());
	rules.set_u8("aib wave spawned", 0);
	rules.set_u8("aib wave archers spawned", 0);
	rules.set_u8("aib wave bomb carriers", 0);
	rules.set_u8("aib wave crossings", 0);
	rules.set_u8("aib wave deaths", 0);
	rules.set_u16("aib wave outcome mask", 0);
	rules.set_u16("aib wave crossing mask", 0);
	rules.set_u16("aib wave death callback mask", 0);
	rules.set_u16("aib wave bomb death callback mask", 0);
	rules.set_u16("aib wave duplicate death callbacks", 0);
	rules.set_u16("aib wave post cross deaths", 0);
	rules.set_u16("aib wave duplicate bomb callbacks", 0);
	rules.set_u8("aib wave builder deaths", 0);
	rules.set_u8("aib wave flag approaches", 0);
	rules.set_u8("aib wave pressure approaches", 0);
	rules.set_u32("aib wave attack ticks", 0);
	rules.set_u16("aib wave arrows fired", 0);
	rules.set_u16("aib wave bombs thrown", 0);
	rules.set_u16("aib wave bombs detonated", 0);
	rules.set_f32("aib wave minimum target distance", 999999.0f);
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
	if (!AIBW_CaptureMeasuredPlan(rules, team, candidate))
	{
		AIBW_Abort(rules, "measured_plan_capture_failed", candidate);
		return false;
	}
	const f32 routePenalty = candidate is null ? 0.0f : AIBS_FriendlyRoutePenalty(candidate);
	rules.set_f32("aib wave friendly route penalty", routePenalty);
	rules.set_bool("aib wave route preserved", routePenalty < 1.0f);
	rules.set_u16("aib wave plan tasks", candidate is null ? 0 : candidate.tasks.length);
	if (candidate !is null && candidate.tasks.length > 0 && rules.get_u16("aib wave measured pending") == 0)
		rules.set_u32("aib wave completion tick", 1); // Plan was already complete when the measured wave began.
	AIBS_Log("wave_start", team, "run_id=" + rules.get_string("aib wave run id") + " seed=" + rules.get_u32("aib wave seed") + " variant=" + rules.get_string("aib wave variant") +
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

u16 AIBW_ArrowCount(CBlob@ unit)
{
	if (unit is null) return 0;
	CInventory@ inventory = unit.getInventory();
	return inventory is null ? 0 : inventory.getCount("mat_arrows");
}

bool AIBW_IsArcher(const string &in scenario, const u32 seed, const u8 index)
{
	if (scenario == "archer") return true;
	if (scenario != "mixed") return false;
	// The lead archer completes a real opening shot before later bomb carriers
	// can detonate. Remaining seeded roles still vary the mixed formation.
	return index == 0 || ((seed + index * 17) % 4) == 0;
}

bool AIBW_IsBombCarrier(const string &in scenario, const u32 seed, const u8 index, const bool isArcher)
{
	if (scenario == "bomb") return true;
	return scenario == "mixed" && !isArcher && ((index + seed) % 3) == 0;
}

void AIBW_SpawnUnit(CRules@ rules)
{
	array<CBlob@> constructionWorkers;
	AIBW_GetConstructionWorkers(constructionWorkers);
	u8 liveActors = 0;
	for (uint i = 0; i < constructionWorkers.length; i++)
	{
		if (constructionWorkers[i] !is null && !constructionWorkers[i].hasTag("dead")) liveActors++;
	}
	CBlob@[] activeWave;
	getBlobsByTag("aib strategy wave unit", @activeWave);
	for (uint i = 0; i < activeWave.length; i++)
	{
		if (activeWave[i] !is null && !activeWave[i].hasTag("dead")) liveActors++;
	}
	if (liveActors >= AIBW_TOTAL_AI_LIMIT) return;

	const u8 team = rules.get_u8("aib wave team");
	const u8 enemyTeam = team == 0 ? 1 : 0;
	const u8 index = rules.get_u8("aib wave spawned");
	const u32 seed = rules.get_u32("aib wave seed");
	Vec2f spawn = rules.get_Vec2f("aib wave approach start");
	if (spawn == Vec2f_zero) return;
	const string scenario = rules.get_string("aib wave scenario");
	const bool archer = AIBW_IsArcher(scenario, seed, index);
	const bool bombCarrier = AIBW_IsBombCarrier(scenario, seed, index, archer);
	const u32 formation = (seed * u32(1103515245)) ^ (u32(index + 1) * u32(2654435761));
	const f32 yOffset = -f32(formation % 3) * 4.0f;
	CBlob@ unit = server_CreateBlob(archer ? "archer" : "knight", enemyTeam, spawn + Vec2f(0, yOffset));
	if (unit !is null)
	{
		unit.Tag("aib strategy wave unit");
		unit.set_u8("aib wave target team", team);
		unit.set_u8("aib wave spawn index", index);
		unit.set_u32("aib wave spawn tick", getGameTime());
		unit.set_f32("aib wave progress x", unit.getPosition().x);
		unit.set_u32("aib wave progress tick", getGameTime());
		AIBW_EquipArcher(unit);
		if (archer) rules.set_u8("aib wave archers spawned", rules.get_u8("aib wave archers spawned") + 1);
		if (bombCarrier)
		{
			unit.Tag("aib wave bomb carrier");
			rules.set_u8("aib wave bomb carriers", rules.get_u8("aib wave bomb carriers") + 1);
		}
		unit.set_u16("aib wave arrows remaining", AIBW_ArrowCount(unit));
		rules.set_u8("aib wave spawned", index + 1);
	}
}

void AIBW_ThrowBomb(CRules@ rules, CBlob@ unit, Vec2f target)
{
	if (rules is null || unit is null || unit.hasTag("aib wave bomb thrown")) return;
	if ((target - unit.getPosition()).Length() > 176.0f) return;
	unit.Tag("aib wave bomb thrown");
	const f32 direction = target.x >= unit.getPosition().x ? 1.0f : -1.0f;
	CBlob@ bomb = server_CreateBlob("bomb", unit.getTeamNum(), unit.getPosition() + Vec2f(direction * 8.0f, -4.0f));
	if (bomb !is null)
	{
		bomb.set_u16("explosive_parent", unit.getNetworkID());
		bomb.set_u8("aib wave spawn index", unit.get_u8("aib wave spawn index"));
		bomb.setVelocity(Vec2f(direction * 6.5f, -2.0f));
		bomb.Tag("aib strategy wave bomb");
		rules.set_u16("aib wave bombs thrown", rules.get_u16("aib wave bombs thrown") + 1);
	}
}

bool AIBW_RecordCrossing(CRules@ rules, CBlob@ unit)
{
	if (rules is null || unit is null) return false;
	const u8 index = unit.get_u8("aib wave spawn index");
	if (index >= rules.get_u8("aib wave spawn limit") || index >= 16) return false;
	const u16 bit = u16(1) << index;
	const u16 outcomeMask = rules.get_u16("aib wave outcome mask");
	if ((outcomeMask & bit) != 0) return false;
	rules.set_u16("aib wave outcome mask", outcomeMask | bit);
	rules.set_u16("aib wave crossing mask", rules.get_u16("aib wave crossing mask") | bit);
	unit.Tag("aib wave crossed");
	rules.set_u8("aib wave crossings", rules.get_u8("aib wave crossings") + 1);
	return true;
}

void AIBW_DriveUnits(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	CBlob@ home = AIBS_TeamHomeBlob(team);
	if (home is null) return;
	Vec2f target = rules.get_Vec2f("aib wave breach target");
	if (target == Vec2f_zero) return;
	CBlob@[] units;
	getBlobsByTag("aib strategy wave unit", @units);
	for (uint i = 0; i < units.length; i++)
	{
		CBlob@ unit = units[i];
		if (unit is null || unit.hasTag("dead")) continue;
		const bool isArcher = unit.getName() == "archer";
		if (isArcher)
		{
			const u16 arrows = AIBW_ArrowCount(unit);
			const u16 previousArrows = unit.get_u16("aib wave arrows remaining");
			if (arrows < previousArrows)
			{
				rules.set_u16("aib wave arrows fired", rules.get_u16("aib wave arrows fired") + previousArrows - arrows);
				unit.Tag("aib wave opening shot fired");
			}
			unit.set_u16("aib wave arrows remaining", arrows);
		}
		if (unit.hasTag("aib wave crossed"))
		{
			unit.setKeyPressed(key_left, false);
			unit.setKeyPressed(key_right, false);
			unit.setKeyPressed(key_up, false);
			unit.setKeyPressed(key_action1, false);
			continue;
		}
		Vec2f toTarget = target - unit.getPosition();
		const f32 targetDistance = toTarget.Length();
		if (targetDistance < rules.get_f32("aib wave minimum target distance"))
			rules.set_f32("aib wave minimum target distance", targetDistance);
		const f32 direction = target.x >= unit.getPosition().x ? 1.0f : -1.0f;
		const u32 now = getGameTime();
		const u32 age = now - unit.get_u32("aib wave spawn tick");
		// A 96 px approach can reach the 24 px crossing radius before a bow's first
		// 40-tick draw releases. Hold each archer at local pressure until the engine
		// actually consumes an arrow, then let it resume the identical route.
		const bool awaitingOpeningShot = isArcher && !unit.hasTag("aib wave opening shot fired") &&
			targetDistance <= AIBW_PRESSURE_RADIUS;
		unit.setKeyPressed(key_left, !awaitingOpeningShot && direction < 0);
		unit.setKeyPressed(key_right, !awaitingOpeningShot && direction > 0);
		unit.setKeyPressed(key_down, false);
		const f32 progressX = unit.get_f32("aib wave progress x");
		if ((unit.getPosition().x - progressX) * direction >= AIBW_PROGRESS_STEP)
		{
			unit.set_f32("aib wave progress x", unit.getPosition().x);
			unit.set_u32("aib wave progress tick", now);
		}
		if (awaitingOpeningShot) unit.set_u32("aib wave progress tick", now);
		const bool obstructed = !awaitingOpeningShot && age > 10 && now - unit.get_u32("aib wave progress tick") >= AIBW_STALL_TICKS;
		if (obstructed && now >= unit.get_u32("aib wave next jump tick"))
		{
			unit.set_u32("aib wave jump until", now + AIBW_JUMP_HOLD_TICKS);
			unit.set_u32("aib wave next jump tick", now + AIBW_JUMP_RETRY_TICKS);
		}
		unit.setKeyPressed(key_up, !awaitingOpeningShot && now < unit.get_u32("aib wave jump until"));
		const bool attackPressed = !isArcher || age % AIBW_ARCHER_FIRE_CYCLE < AIBW_ARCHER_DRAW_TICKS;
		unit.setKeyPressed(key_action1, attackPressed);
		unit.setAimPos(target);
		const f32 driveSpeed = Maths::Min(AIBW_MAX_DRIVE_SPEED, Maths::Max(1.25f, Maths::Abs(unit.getVelocity().x)));
		unit.setVelocity(Vec2f(awaitingOpeningShot ? 0.0f : direction * driveSpeed, unit.getVelocity().y));
		if (unit.hasTag("aib wave bomb carrier")) AIBW_ThrowBomb(rules, unit, target);
		if (targetDistance <= AIBW_PRESSURE_RADIUS)
		{
			if (!unit.hasTag("aib wave pressure approach"))
			{
				unit.Tag("aib wave pressure approach");
				rules.set_u8("aib wave pressure approaches", rules.get_u8("aib wave pressure approaches") + 1);
			}
			if (attackPressed) rules.set_u32("aib wave attack ticks", rules.get_u32("aib wave attack ticks") + 1);
		}
		if (!unit.hasTag("aib wave approached flag") && (unit.getPosition() - home.getPosition()).Length() <= 80.0f)
		{
			unit.Tag("aib wave approached flag");
			rules.set_u8("aib wave flag approaches", rules.get_u8("aib wave flag approaches") + 1);
		}
		if (targetDistance <= AIBW_CROSSING_RADIUS && AIBW_RecordCrossing(rules, unit))
		{
			if (!rules.get_bool("aib wave breached"))
			{
				rules.set_bool("aib wave breached", true);
				rules.set_u32("aib wave first breach", getGameTime() - rules.get_u32("aib wave start tick"));
			}
		}
	}
}

void AIBW_ReleaseUnitControls()
{
	CBlob@[] units;
	getBlobsByTag("aib strategy wave unit", @units);
	for (uint i = 0; i < units.length; i++)
	{
		CBlob@ unit = units[i];
		if (unit is null) continue;
		unit.setKeyPressed(key_left, false);
		unit.setKeyPressed(key_right, false);
		unit.setKeyPressed(key_up, false);
		unit.setKeyPressed(key_down, false);
		unit.setKeyPressed(key_action1, false);
		unit.setKeyPressed(key_action2, false);
	}
}

void AIBW_SampleBuilders(CRules@ rules)
{
	AIBW_SampleMeasuredPlan(rules);
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

void AIBW_StopWaveActors()
{
	CBlob@[] units;
	getBlobsByTag("aib strategy wave unit", @units);
	for (uint i = 0; i < units.length; i++)
	{
		CBlob@ unit = units[i];
		if (unit !is null && !unit.hasTag("dead")) unit.server_Die();
	}
	CBlob@[] bombs;
	getBlobsByTag("aib strategy wave bomb", @bombs);
	for (uint i = 0; i < bombs.length; i++)
	{
		CBlob@ bomb = bombs[i];
		if (bomb !is null && !bomb.hasTag("dead")) bomb.server_Die();
	}
}

void AIBW_EmitResult(CRules@ rules, const u8 team, const string &in detail)
{
	if (rules is null) return;
	const u32 seq = rules.get_u32("aib event log seq") + 1;
	rules.set_u32("aib event log seq", seq);
	const string line = "[AIBEVT] t=" + getGameTime() + " seq=" + seq +
		" scenario=manual source=strategy action=wave_result actor=team:" + team + " " + detail;
	print(line);
	tcpr(line);
	tcpr("AIBWAVE|RESULT|run=" + rules.get_string("aib wave run id"));
}

void AIBW_Finish(CRules@ rules)
{
	AIBW_ReleaseUnitControls();
	if (!AIBW_SampleMeasuredPlan(rules))
	{
		AIBW_Abort(rules, "measured_plan_tracking_failed", AIBW_CurrentCandidate(rules.get_u8("aib wave team")));
		return;
	}
	const u8 team = rules.get_u8("aib wave team");
	const string scenario = rules.get_string("aib wave scenario");
	if (rules.get_u8("aib wave spawned") != rules.get_u8("aib wave spawn limit"))
	{
		AIBW_Abort(rules, "incomplete_fixed_pressure_spawn", AIBW_CurrentCandidate(team));
		return;
	}
	if (rules.get_u8("aib wave pressure approaches") == 0 || rules.get_u32("aib wave attack ticks") == 0)
	{
		AIBW_Abort(rules, "no_local_pressure_contact", AIBW_CurrentCandidate(team));
		return;
	}
	if ((scenario == "archer" || scenario == "mixed") && rules.get_u16("aib wave arrows fired") == 0)
	{
		AIBW_Abort(rules, "no_production_archer_shot", AIBW_CurrentCandidate(team));
		return;
	}
	if ((scenario == "bomb" || scenario == "mixed") && rules.get_u16("aib wave bombs thrown") == 0)
	{
		AIBW_Abort(rules, "no_real_bomb_throw", AIBW_CurrentCandidate(team));
		return;
	}
	if (rules.get_string("aib wave variant") == "control" && !rules.get_bool("aib wave breached"))
	{
		AIBW_Abort(rules, "control_did_not_cross_fixture_target", AIBW_CurrentCandidate(team));
		return;
	}
	const u32 elapsed = getGameTime() - rules.get_u32("aib wave start tick");
	const u32 absorbedCost = rules.get_u32("aib wave damage cost");
	const u32 completionTick = rules.get_u32("aib wave completion tick");
	const u32 firstDamageTick = rules.get_u32("aib wave first damage tick");
	const u32 lifetimeEnd = firstDamageTick == 0 ? elapsed : firstDamageTick;
	const u32 structureLifetime = completionTick == 0 || completionTick >= lifetimeEnd ? 0 : lifetimeEnd - completionTick;
	const string detail = "run_id=" + rules.get_string("aib wave run id") + " pressure_valid=true seed=" + rules.get_u32("aib wave seed") +
		" variant=" + rules.get_string("aib wave variant") + " scenario=" + scenario + " elapsed=" + elapsed +
		" breached=" + rules.get_bool("aib wave breached") + " first_breach=" + rules.get_u32("aib wave first breach") + " crossings=" + rules.get_u8("aib wave crossings") +
		" enemy_deaths=" + rules.get_u8("aib wave deaths") + " builder_deaths=" + rules.get_u8("aib wave builder deaths") +
		" outcomes_resolved=" + (rules.get_u8("aib wave crossings") + rules.get_u8("aib wave deaths")) +
		" outcome_contract=" + AIBW_OUTCOME_CONTRACT +
		" duplicate_death_callbacks=" + rules.get_u16("aib wave duplicate death callbacks") +
		" post_cross_deaths=" + rules.get_u16("aib wave post cross deaths") +
		" duplicate_bomb_callbacks=" + rules.get_u16("aib wave duplicate bomb callbacks") +
		" flag_approaches=" + rules.get_u8("aib wave flag approaches") +
		" pressure_approaches=" + rules.get_u8("aib wave pressure approaches") +
		" attack_ticks=" + rules.get_u32("aib wave attack ticks") +
		" archers_spawned=" + rules.get_u8("aib wave archers spawned") +
		" bomb_carriers=" + rules.get_u8("aib wave bomb carriers") +
		" arrows_fired=" + rules.get_u16("aib wave arrows fired") +
		" bombs_thrown=" + rules.get_u16("aib wave bombs thrown") +
		" bombs_detonated=" + rules.get_u16("aib wave bombs detonated") +
		" bomb_origin=server_wave_throw_with_real_explosion minimum_target_distance=" + rules.get_f32("aib wave minimum target distance") +
		" spawned=" + rules.get_u8("aib wave spawned") + " plan_completed_delta=" +
			(int(rules.get_u16("aib wave measured healthy")) - int(rules.get_u16("aib wave measured healthy start"))) +
		" plan_pending=" + rules.get_u16("aib wave measured pending") + " plan_damaged=" + rules.get_u16("aib wave measured damaged") +
		" damage_events=" + rules.get_u16("aib wave damage events") +
		" damage_absorbed_cost=" + absorbedCost + " plan_cost=" + rules.get_u32("aib wave plan cost") + " completion_tick=" + rules.get_u32("aib wave completion tick") +
		" first_damage_tick=" + rules.get_u32("aib wave first damage tick") + " structure_lifetime=" + structureLifetime +
		" builder_travel=" + rules.get_f32("aib wave builder travel") + " builder_idle_ticks=" + rules.get_u32("aib wave builder idle") +
		" reservation_conflicts=" + rules.get_u16("aib wave reservation conflicts") + " replans=" + rules.get_u16("aib wave replans") +
		" measured_plan_id=" + rules.get_u16("aib wave measured plan id") + " final_plan_id=" + rules.get_u16(AIBP_PlanKey(team, "id")) +
		" ai_actor_cap=" + AIBW_TOTAL_AI_LIMIT + " spawn_limit=" + rules.get_u8("aib wave spawn limit") +
		" route_preserved=" + rules.get_bool("aib wave route preserved") + " friendly_route_penalty=" + rules.get_f32("aib wave friendly route penalty") +
		AIBW_InitialMetrics(rules);
	AIBW_EmitResult(rules, team, detail);
	rules.set_bool("aib wave enabled", false);
	rules.set_bool("aib wave running", false);
	rules.set_bool("aib wave initial captured", false);
	rules.set_string("aib wave initial fingerprint", "");
	rules.set_string("aib wave measurement fingerprint", "");
	rules.set_bool("aib strategy event log enabled", false);
	rules.set_bool("aib event log enabled", rules.get_bool("aib wave previous event log enabled"));
	rules.set_bool("aib wave request", false);
	AIBW_StopWaveActors();
}

void onTick(CRules@ this)
{
	if (!isServer()) return;
	AIBW_HandleArmRequest(this);
	if (!this.get_bool("aib wave enabled")) return;
	if (!this.get_bool("aib wave running"))
	{
		if (getGameTime() < this.get_u32("aib wave arm tick")) return;
		if (!AIBW_Start(this)) return;
	}
	const u32 elapsed = getGameTime() - this.get_u32("aib wave start tick");
	const u32 spawnInterval = 40 + (this.get_u32("aib wave seed") % 11);
	const u8 spawnLimit = this.get_u8("aib wave spawn limit");
	if (this.get_u8("aib wave spawned") < spawnLimit && elapsed % spawnInterval == 1) AIBW_SpawnUnit(this);
	AIBW_DriveUnits(this);
	AIBW_SampleBuilders(this);
	if (elapsed >= 1200 || (this.get_u8("aib wave spawned") >= spawnLimit &&
		this.get_u8("aib wave crossings") + this.get_u8("aib wave deaths") >= spawnLimit)) AIBW_Finish(this);
}

void onBlobDie(CRules@ this, CBlob@ blob)
{
	if (!isServer() || blob is null || !this.get_bool("aib wave running")) return;
	if (blob.hasTag("aib strategy wave unit"))
	{
		const u8 index = blob.get_u8("aib wave spawn index");
		if (index >= this.get_u8("aib wave spawn limit") || index >= 16) return;
		const u16 bit = u16(1) << index;
		const u16 callbackMask = this.get_u16("aib wave death callback mask");
		if ((callbackMask & bit) != 0)
		{
			this.set_u16("aib wave duplicate death callbacks", this.get_u16("aib wave duplicate death callbacks") + 1);
			return;
		}
		this.set_u16("aib wave death callback mask", callbackMask | bit);
		const u16 outcomeMask = this.get_u16("aib wave outcome mask");
		if ((outcomeMask & bit) != 0)
		{
			this.set_u16("aib wave post cross deaths", this.get_u16("aib wave post cross deaths") + 1);
			return;
		}
		this.set_u16("aib wave outcome mask", outcomeMask | bit);
		this.set_u8("aib wave deaths", this.get_u8("aib wave deaths") + 1);
	}
	else if (blob.hasTag("aib strategy wave bomb"))
	{
		const u8 index = blob.get_u8("aib wave spawn index");
		if (index >= this.get_u8("aib wave spawn limit") || index >= 16) return;
		const u16 bit = u16(1) << index;
		const u16 callbackMask = this.get_u16("aib wave bomb death callback mask");
		if ((callbackMask & bit) != 0)
		{
			this.set_u16("aib wave duplicate bomb callbacks", this.get_u16("aib wave duplicate bomb callbacks") + 1);
			return;
		}
		this.set_u16("aib wave bomb death callback mask", callbackMask | bit);
		this.set_u16("aib wave bombs detonated", this.get_u16("aib wave bombs detonated") + 1);
	}
	else if ((blob.getName() == "aibuilder" || blob.getName() == "autobuilder") &&
		blob.getTeamNum() == this.get_u8("aib wave team") && !blob.hasTag("aib wave builder death counted"))
	{
		blob.Tag("aib wave builder death counted");
		this.set_u8("aib wave builder deaths", this.get_u8("aib wave builder deaths") + 1);
	}
}
