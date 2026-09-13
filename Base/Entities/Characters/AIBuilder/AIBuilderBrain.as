// AIBuilderBrain.as

#define SERVER_ONLY

#include "Hitters.as";
#include "MaterialCommon.as";
#include "AIBBarrierCommon.as";
#include "AIBStoneRouteCommon.as";
#include "AIBEventLog.as";
#include "AIBGymBenchmarkCommon.as";
#include "AIBHomeResourceCommon.as";
#include "AIBManualOrderCommon.as";
#include "AIBBuilderGuideCommon.as";
#include "AutoBuilderCommon.as";
#include "BlueprintData.as";
#include "Pathing/BrainPathing.as";
#include "MakeSeed.as";

const f32 AIB_HIT_DAMAGE = 0.5f;
const u8 AIB_HIT_DELAY = 12;
const u8 AIB_LOG_WAIT = 45;
const f32 AIB_SAFE_RADIUS = 10.0f * 8.0f;
const f32 AIB_KNIGHT_FEAR_RADIUS = 10.0f * 8.0f;
// Stock bombs damage actors within 64 pixels and may destroy the short wall
// that currently blocks their ray. Retreat while an activated enemy bomb is
// within twice that radius instead of waiting for its carrier to reach the
// ordinary knight-fear envelope.
const f32 AIB_BOMB_FEAR_RADIUS = 16.0f * 8.0f;
const u8 AIB_JOB_WOOD = 0;
const u8 AIB_JOB_STONE = 1;
const u8 AIB_JOB_BLUEPRINT = 2;
const u8 AIB_STONE_SCAN_RADIUS = 80;
const u8 AIB_STONE_LOCAL_RADIUS = 3;
// Loose ore is useful immediately around a miner, but a map-global material
// scan can send a base worker through the enemy flag to remote quarry output.
const u8 AIB_STONE_LOOSE_SEARCH_RADIUS_TILES = 12;
const u8 AIB_STONE_ROUTE_CANDIDATE_LIMIT = 24;
const u8 AIB_STONE_ROUTE_CANDIDATE_SEPARATION = 4;
const u8 AIB_GOLD_SIGHT_RADIUS = 16;
const u8 AIB_REJECTED_ROUTE_CLUSTER_RADIUS = 4;
const u16 AIB_REJECTED_ROUTE_COOLDOWN = 900;
const u16 AIB_STONE_SHAFT_NO_PROGRESS_TICKS = 4 * 30;
const u16 AIB_STONE_SHAFT_HANDOFF_NO_PROGRESS_TICKS = 30;
const u16 AIB_STONE_RETURN_AMOUNT = 250;
const u8 AIB_STONE_RETURN_PROGRESS_PIXELS = 4;
const u8 AIB_STONE_RETURN_STALL_TICKS = 30;
const u8 AIB_BLUEPRINT_PLACE_DELAY = 8;
const u8 AIB_LADDER_WOOD_COST = 10;
const u8 AIB_LADDER_BACKWALL_WOOD_COST = 2;
const u8 AIB_LADDER_OBSTRUCTION_THRESHOLD = 14;
const u8 AIB_LADDER_PLACE_DELAY = 45;
const u8 AIB_LADDER_BACKWALL_MAX_CHAIN = 8;
const f32 AIB_LADDER_HORIZONTAL_ANGLE = 90.0f;
const string AIB_RECOVERY_SUPPORT_TARGET_KEY = "ai builder recovery support target";
const string AIB_RECOVERY_SUPPORT_TICK_KEY = "ai builder recovery support tick";
const string AIB_RECOVERY_SUPPORT_CHAIN_KEY = "ai builder recovery support chain";
const string AIB_RECOVERY_PROBE_PENDING_KEY = "ai builder recovery path probe pending";
const string AIB_RECOVERY_PROBE_LADDER_KEY = "ai builder recovery path probe ladder";
const string AIB_RECOVERY_LADDER_TICK_KEY = "ai builder recovery ladder tick";
const u8 AIB_STONE_CORNER_OBSTRUCTION_THRESHOLD = 12;
// Twelve ticks was long enough to unpress jump but not long enough to leave a
// one-tile overhang with a usable run-up. Pathing immediately drove the worker
// back into the same corner. Keep direct ownership for just over a second, then
// suppress another escape cycle while the path controller uses that run-up.
const u8 AIB_STONE_CORNER_ESCAPE_TICKS = 36;
const u8 AIB_STONE_CORNER_ESCAPE_COOLDOWN = 90;
const u16 AIB_BUILDER_SHOP_WOOD_COST = 200;
const u8 AIB_BASE_WORKSHOP_MIN_SEARCH_TILES = 7;
const u8 AIB_BASE_WORKSHOP_MAX_SEARCH_TILES = 26;
const u8 AIB_BASE_WORKSHOP_VERTICAL_SEARCH_TILES = 8;
const u8 AIB_BASE_WORKSHOP_EXISTING_RADIUS_TILES = 28;
const u8 AIB_BASE_WORKSHOP_HOME_CLEARANCE_TILES = 6;
const u8 AIB_BASE_WORKSHOP_BUILDING_CLEARANCE_TILES = 2;
const u8 AIB_BASE_WORKSHOP_RETRY_TICKS = 60;
const u16 AIB_CRATE_WOOD_COST = 150;
const u8 AIB_BASE_CRATE_MAX_SEARCH_TILES = 12;
const u8 AIB_BASE_CRATE_VERTICAL_SEARCH_TILES = 4;
const u16 AIB_NURSERY_WOOD_COST = 250;
const u16 AIB_NURSERY_SEED_STONE_COST = 20;
const u16 AIB_QUARRY_WOOD_COST = 150;
const u16 AIB_QUARRY_STONE_COST = 150;
const u16 AIB_QUARRY_GOLD_COST = 100;
// At growth step 10 (of 15), trees enter the mature minimap/wood-yield tier.
// Younger nursery trees can be destroyed without producing useful logs.
const u8 AIB_TREE_HARVEST_GROWTH = 10;
const u16 AIB_QUARRY_FUEL_BATCH = 100;
const s16 AIB_QUARRY_MAX_FUEL = 500;
const s16 AIB_QUARRY_REFUEL_BELOW = 200;
const s16 AIB_QUARRY_MIN_WORKING_FUEL = 2;
const u16 AIB_STONE_SUPPLY_AMOUNT = 80;
const u32 AIB_STONE_SUPPLY_DELAY = 30 * 30;
const u32 AIB_SEED_BUY_DELAY = 300;
const u8 AIB_AIR_SURFACE_BELOW = 90;
const u8 AIB_AIR_RESUME_AT = 165;
const string AIB_BLUEPRINT_DATA_KEY = "aibuilder blueprint data";
const string AIB_BLUEPRINT_WIDTH_KEY = "aibuilder blueprint width";
const string AIB_BLUEPRINT_HEIGHT_KEY = "aibuilder blueprint height";
const string AIB_BLUEPRINT_TEAM_SUFFIX = " team ";
const u8 AIB_SHAFT_WIDTH = 2;
const u8 AIB_WOOD_BLOCK_COST = 10;
const u8 AIB_WOODEN_DOOR_COST = 30;
const bool AIB_DEBUG = false; // Set true while debugging. Uses print(), so keep false for deployed builds.
const u32 AIB_DEBUG_SNAPSHOT_RATE = 150;
const u32 AIB_PUBLIC_STATE_SYNC_RATE = 5 * 30;
const u32 AIB_STATUS_BUBBLE_RATE = 10 * 30;
const u32 AIB_RESOURCE_REJECT_LOG_REFRESH = 30 * 30;
const u32 AIB_TREE_NO_PROGRESS_TICKS = 10 * 30;
const u32 AIB_TREE_RETRY_COOLDOWN = 30 * 30;
const f32 AIB_TREE_DISTANCE_PROGRESS = 8.0f;
// A zero-stock emergency plan has one warm-up resource episode in which to
// become useful. Its director-owned collector should prefer a grounded tree to
// a closer high canopy; ordinary/manual harvesting retains the measured
// home-distance score used by the resource-collection cohort.
const f32 AIB_URGENT_TREE_FREE_APPROACH_RISE_TILES = 3.0f;
const f32 AIB_URGENT_TREE_UPHILL_SCORE_PER_PIXEL = 2.0f;
const u32 AIB_RESOURCE_HANDOFF_HOLD_TICKS = 31;
// Inventory transfers are queued by KAG. A crate can report acceptance in the
// mutation tick and return the stack to the builder shortly afterward.
const u32 AIB_DELIVERY_CONFIRM_TICKS = 3;
const string AIB_DELIVERY_CONFIRM_UNTIL_KEY = "ai builder delivery confirm until";
const string AIB_CRATE_CAPACITY_RETRY_KEY = "aibuilder resource crate capacity retry";
const u32 AIB_CRATE_CAPACITY_RETRY_TICKS = 30;
// A log target exists only after the engine has spawned it, so this watchdog is
// separate from AIB_LOG_WAIT. Logs are produced beside a tree the worker just
// felled. A full 8x_Gloryhill cohort rejected the three-second candidate, so
// retain the historical ten-second window while the underlying route defect
// is investigated. The separate pre-target spawn wait remains AIB_LOG_WAIT.
const u32 AIB_LOG_NO_PROGRESS_TICKS = 10 * 30;
const u32 AIB_LOG_RETRY_COOLDOWN = 30 * 30;
const f32 AIB_LOG_DISTANCE_PROGRESS = 8.0f;
// BrainPath can legally return a straight-down air node. A runner has no
// free-fall control for that node unless it first walks off its support.
const u8 AIB_DOWNWARD_PATH_STEER_OBSTRUCTION_TICKS = 6;
const u8 AIB_DOWNWARD_PATH_STEER_HOLD_TICKS = 12;
const u8 AIB_UPWARD_PATH_STEER_OBSTRUCTION_TICKS = 6;
const u8 AIB_UPWARD_PATH_STEER_HOLD_TICKS = 36;

namespace AIBuilderState
{
	enum state
	{
		idle = 0,
		find_tree,
		chop_tree,
		find_log,
		chop_log,
		find_wood,
		return_wood,
		find_stone,
		prepare_stone_shaft,
		dig_stone_shaft,
		tunnel_to_stone,
		find_stone_mat,
		collect_blueprint_resources,
		find_blueprint_block,
		build_blueprint_block,
		nursery_collect_wood,
		nursery_build,
		nursery_collect_stone,
		nursery_buy_seed,
		nursery_plant_seed,
		nursery_wait_tree,
		visit_resupply,
		deliver_log_to_saw
	}
}

#include "AIBGymMonitor.as";

void onInit(CBrain@ this)
{
	CBlob@ blob = this.getBlob();
	const bool autoBuilder = AIBU_IsAutoBuilder(blob);
	blob.set_u8("ai builder state", AIBuilderState::idle);
	blob.set_netid("ai builder target", 0);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_Vec2f("ai builder tile target", Vec2f_zero);
	blob.set_Vec2f("ai builder shaft top", Vec2f_zero);
	blob.set_Vec2f("ai builder stone route corner", Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY, Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_RETURN_CORNER_KEY, Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_SURFACE_MEMORY_KEY, Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY, Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_EXPOSED_APPROACH_KEY, Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_REJECTED_ROUTE_KEY, Vec2f_zero);
	blob.set_u32(AIBM_STONE_REJECTED_ROUTE_UNTIL_KEY, 0);
	blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, Vec2f_zero);
	blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, 0);
	blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, false);
	blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, 0);
	blob.set_bool(AIBM_STONE_RETURN_SURFACED_KEY, false);
	blob.set_u8("ai builder job", autoBuilder ? AIB_JOB_BLUEPRINT : AIB_JOB_WOOD);
	AIB_SyncPublicState(blob, true);
	blob.set_u32("ai builder log wait until", 0);
	blob.set_u16("ai builder pending wood", 0);
	blob.set_u32(AIB_DELIVERY_CONFIRM_UNTIL_KEY, 0);
	blob.set_u16("ai builder delivery pending wood", 0);
	blob.set_u16("ai builder delivery pending stone", 0);
	blob.set_u16("ai builder delivery pending gold", 0);
	blob.set_u8("ai builder obstruction threshold", 0);
	blob.set_bool("ai builder justgo", false);
	blob.set_u32("ai builder next place", 0);
	blob.set_u32("ai builder next pickup", 0);
	blob.set_u32("ai builder next ladder", 0);
	blob.set_Vec2f(AIB_RECOVERY_SUPPORT_TARGET_KEY, Vec2f_zero);
	blob.set_u32(AIB_RECOVERY_SUPPORT_TICK_KEY, 0);
	blob.set_u8(AIB_RECOVERY_SUPPORT_CHAIN_KEY, 0);
	blob.set_bool(AIB_RECOVERY_PROBE_PENDING_KEY, false);
	blob.set_netid(AIB_RECOVERY_PROBE_LADDER_KEY, 0);
	blob.set_u32(AIB_RECOVERY_LADDER_TICK_KEY, 0);
	blob.set_u32("ai builder stone corner escape until", 0);
	blob.set_u32("ai builder stone corner escape cooldown", 0);
	blob.set_s32("ai builder stone corner escape direction", 0);
	blob.set_bool("ai builder mining gold", false);
	blob.set_bool("ai builder direct stone shaft", false);
	blob.set_bool("ai builder direct stone return", false);
	blob.set_u32("ai builder next blueprint clearance jump", 0);
	blob.set_u32("ai builder next seed buy", 0);
	blob.set_u32("ai builder nursery wait until", 0);
	blob.set_u32("ai builder next stone supply", 0);
	blob.set_u32("ai builder guide resupply request", 0);
	blob.set_u32("ai builder guide resupply timeout", 0);
	blob.set_u32("ai builder guide resupply retry", 0);
	blob.set_netid("ai builder guide saw target", 0);
	blob.set_Vec2f("ai builder jump peak", Vec2f_zero);
	blob.set_u8("ai builder debug last state", AIBuilderState::idle);
	blob.set_u16("ai builder navigation epoch", 0);
	blob.set_netid("ai builder tree progress target", 0);
	blob.set_u32("ai builder tree progress tick", 0);
	blob.set_f32("ai builder tree progress distance", 999999.0f);
	blob.set_f32("ai builder tree progress health", 0.0f);
	blob.set_netid("ai builder log progress target", 0);
	blob.set_u32("ai builder log progress tick", 0);
	blob.set_f32("ai builder log progress distance", 999999.0f);
	blob.set_f32("ai builder log progress health", 0.0f);
	blob.set_netid("ai builder bomb threat", 0);
	blob.set_netid("ai builder bomb threat logged", 0);
	blob.set_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY, 0);
	AIBG_Init(blob);
	if (autoBuilder)
	{
		blob.set_u8("air_count", 255);
		CShape@ shape = blob.getShape();
		if (shape !is null)
		{
			shape.getConsts().mapCollisions = false;
			shape.getConsts().collidable = false;
			shape.SetGravityScale(0.0f);
		}
	}
	else
	{
		BrainPath@ path = BrainPath(blob, Path::ALL);
		blob.set("ai builder brain path", @path);
	}

	this.server_SetActive(true);
	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
	this.getCurrentScript().tickFrequency = 1;
}

void onTick(CBrain@ this)
{
	CBlob@ blob = this.getBlob();
	if (blob is null || blob.hasTag("dead")) return;
	// Immediate transition syncs are retained, while this low-rate staggered
	// heartbeat bounds late-join or dropped-delta HUD staleness without turning
	// public state into per-tick network traffic.
	AIB_SyncPublicState(blob, false);
	if (blob.isAttached())
	{
		blob.server_DetachFromAll();
		AIB_FloatInWater(blob);
		return;
	}
	// The director may decide that a completed/cancelled/absent plan has no more
	// executable work while this runner is still finishing a resource episode.
	// Consume that deferred retirement here, before a target-free find state can
	// select another tree, stone route, or blueprint task between heartbeats.
	if (AIBM_TryRetireAtSafeBoundary(blob)) return;
	// Apply the latest director-selected role at the same atomic boundary. This
	// prevents the old find state from starting another resource episode during
	// the gap before the next 30-tick strategic observation.
	if (AIBM_TryApplyDeferredRoleAtSafeBoundary(blob)) return;
	if (AIBU_IsAutoBuilder(blob))
	{
		AIB_TickAutoBuilder(this, blob);
		return;
	}
	if (AIB_TryStartGuideResupply(blob)) return;
	if (AIB_ShouldHoldAtResourceHandoff(blob))
	{
		AIB_FloatInWater(blob);
		return;
	}

	const u8 state = blob.get_u8("ai builder state");
	const bool gymMonitorable = (state != AIBuilderState::idle || blob.get_bool("ai builder job active")) && state != AIBuilderState::nursery_wait_tree &&
		!(state == AIBuilderState::find_log && blob.get_u32("ai builder log wait until") > getGameTime());
	AIBG_Tick(this, blob, state, gymMonitorable);
	AIB_DebugSnapshot(this, blob, state);
	if (this.getState() == CBrain::stuck || this.getState() == CBrain::wrong_path)
	{
		AIB_ReportTimedStatus(blob, "Stuck while " + AIB_StateName(state), "stuck");
	}
	if (AIB_FleeFromNearbyBomb(this, blob) || AIB_FleeFromNearbyKnight(this, blob))
	{
		AIB_FloatInWater(blob);
		return;
	}
	if (AIB_HandleBreathing(this, blob))
	{
		return;
	}

	if (AIB_ShouldReturnResources(blob) && state != AIBuilderState::return_wood && !AIB_IsNurseryState(state))
	{
		AIB_SetState(blob, AIBuilderState::return_wood, "inventory full or carrying resources");
	}

	if (state == AIBuilderState::idle)
	{
		if (!AIB_ResumeActiveJob(blob, "resuming assigned job"))
		{
			AIB_FloatInWater(blob);
			return;
		}
	}

	if (state >= AIBuilderState::find_stone &&
		state < AIBuilderState::collect_blueprint_resources &&
		blob.get_u8("ai builder job") != AIB_JOB_STONE)
	{
		if (!AIB_ResumeActiveJob(blob, "stone state without stone job"))
		{
			AIB_SetState(blob, AIBuilderState::idle, "stone state without stone job");
		}
		AIB_FloatInWater(blob);
		return;
	}

	if (state >= AIBuilderState::collect_blueprint_resources &&
		state <= AIBuilderState::build_blueprint_block &&
		blob.get_u8("ai builder job") != AIB_JOB_BLUEPRINT)
	{
		if (!AIB_ResumeActiveJob(blob, "blueprint state without blueprint job"))
		{
			AIB_SetState(blob, AIBuilderState::idle, "blueprint state without blueprint job");
		}
		AIB_FloatInWater(blob);
		return;
	}

	if (AIB_IsNurseryState(state) && blob.get_u8("ai builder job") != AIB_JOB_WOOD)
	{
		if (!AIB_ResumeActiveJob(blob, "nursery state without wood job"))
		{
			AIB_SetState(blob, AIBuilderState::idle, "nursery state without wood job");
		}
		AIB_FloatInWater(blob);
		return;
	}

	if (AIB_HasWood(blob) &&
		blob.get_u8("ai builder job") == AIB_JOB_WOOD &&
		state != AIBuilderState::chop_tree &&
		state != AIBuilderState::find_log &&
		state != AIBuilderState::chop_log &&
		!AIB_IsNurseryState(state))
	{
		AIB_SetState(blob, AIBuilderState::return_wood, "has wood outside harvesting states");
	}

	const u8 activeState = blob.get_u8("ai builder state");
	CMap@ activeMap = getMap();
	Vec2f stoneReturnAnchor = blob.get_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY);
	const bool stoneReturnBelowBand = activeMap !is null && stoneReturnAnchor != Vec2f_zero &&
		!AIB_IsWithinStoneReturnReentryBand(blob.getPosition(), stoneReturnAnchor, activeMap.tilesize);
	const bool stoneReturnSurfaced = blob.get_bool(AIBM_STONE_RETURN_SURFACED_KEY);
	const bool stoneReturnShaftReentry = stoneReturnBelowBand && activeMap !is null &&
		AIB_IsInsideStoneReturnShaftInfluence(blob.getPosition(), stoneReturnAnchor, activeMap.tilesize);
	const bool directStoneReturnOwnsKeys = activeMap !is null &&
		activeState == AIBuilderState::return_wood && blob.get_u8("ai builder job") == AIB_JOB_STONE &&
		stoneReturnAnchor != Vec2f_zero &&
		(blob.get_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY) != Vec2f_zero ||
			blob.get_bool("ai builder direct stone return") ||
			(stoneReturnBelowBand && (!stoneReturnSurfaced || stoneReturnShaftReentry)));
	// The deep-shaft return controller must hold wall direction plus up without a
	// generic corner-escape cycle walking it back across the open shaft. Normal
	// travel and tunnel mining retain the mirrored overhang recovery below.
	if (!directStoneReturnOwnsKeys && AIB_TryRecoverStoneCorner(this, blob, activeState))
	{
		return;
	}

	switch (activeState)
	{
		case AIBuilderState::find_tree:
			AIB_FindTree(this, blob);
			break;

		case AIBuilderState::chop_tree:
			AIB_ChopTree(this, blob);
			break;

		case AIBuilderState::find_log:
			AIB_FindLog(this, blob);
			break;

		case AIBuilderState::chop_log:
			AIB_ChopLog(this, blob);
			break;

		case AIBuilderState::find_wood:
			AIB_FindWood(this, blob);
			break;

		case AIBuilderState::return_wood:
			AIB_ReturnWood(this, blob);
			break;

		case AIBuilderState::find_stone:
			AIB_FindStone(this, blob);
			break;

		case AIBuilderState::prepare_stone_shaft:
			AIB_SetState(blob, AIBuilderState::find_stone, "legacy shaft state disabled");
			break;

		case AIBuilderState::dig_stone_shaft:
			AIB_SetState(blob, AIBuilderState::find_stone, "legacy shaft state disabled");
			break;

		case AIBuilderState::tunnel_to_stone:
			AIB_TunnelToStone(this, blob);
			break;

		case AIBuilderState::find_stone_mat:
			AIB_FindStoneMat(this, blob);
			break;

		case AIBuilderState::collect_blueprint_resources:
			AIB_CollectBlueprintResources(this, blob);
			break;

		case AIBuilderState::find_blueprint_block:
			AIB_FindBlueprintBlock(this, blob);
			break;

		case AIBuilderState::build_blueprint_block:
			AIB_BuildBlueprintBlock(this, blob);
			break;

		case AIBuilderState::nursery_collect_wood:
			AIB_NurseryCollectWood(this, blob);
			break;

		case AIBuilderState::nursery_build:
			AIB_NurseryBuild(this, blob);
			break;

		case AIBuilderState::nursery_collect_stone:
			AIB_NurseryCollectStone(this, blob);
			break;

		case AIBuilderState::nursery_buy_seed:
			AIB_NurseryBuySeed(this, blob);
			break;

		case AIBuilderState::nursery_plant_seed:
			AIB_NurseryPlantSeed(this, blob);
			break;

		case AIBuilderState::nursery_wait_tree:
			AIB_NurseryWaitForTree(this, blob);
			break;

		case AIBuilderState::visit_resupply:
			AIB_VisitGuideResupply(this, blob);
			break;

		case AIBuilderState::deliver_log_to_saw:
			AIB_DeliverLogToSaw(this, blob);
			break;
	}

	if (AIB_CaptureStoneReturnReentryFixture(this, blob)) return;
	AIB_FloatInWater(blob);
}

bool AIB_CaptureStoneReturnReentryFixture(CBrain@ brain, CBlob@ blob)
{
	if (!isServer() || brain is null || blob is null ||
		!blob.hasTag("aibt stone return reentry probe")) return false;
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null ||
		!rules.get_bool("aibt stone route abort reentry staged")) return false;

	// The rules fixture samples before this brain callback. Capture the brief
	// production handoff here so a re-entry that climbs from the stale-corner
	// setup cannot surface and disappear again between two rules observations.
	if (!rules.get_bool("aibt stone route abort reentry bypassed corner") &&
		blob.get_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY) &&
		blob.get_bool("ai builder direct stone return"))
	{
		rules.set_bool("aibt stone route abort reentry bypassed corner", true);
		AIB_LogEvent("test", "stone_return_reentry_fixture_bypass", AIB_EventBlobRef(blob),
			"anchor=" + AIB_EventPos(blob.get_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY)) +
			" corner=" + AIB_EventPos(blob.get_Vec2f(AIBM_STONE_RETURN_CORNER_KEY)) +
			" pos=" + AIB_EventPos(blob.getPosition()));
	}

	Vec2f anchor = blob.get_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY);
	if (rules.get_bool("aibt stone route abort reentry bypassed corner") &&
		!rules.get_bool("aibt stone route abort reentry surfaced") && getGameTime() % 10 == 7)
	{
		AIB_LogEvent("test", "stone_return_reentry_fixture_progress", AIB_EventBlobRef(blob),
			"anchor=" + AIB_EventPos(anchor) + " pos=" + AIB_EventPos(blob.getPosition()) +
			" surfaced=" + (blob.get_bool(AIBM_STONE_RETURN_SURFACED_KEY) ? "true" : "false") +
			" direct=" + (blob.get_bool("ai builder direct stone return") ? "true" : "false") +
			" rejoined=" + (blob.get_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY) ? "true" : "false"));
	}
	if (!rules.get_bool("aibt stone route abort reentry bypassed corner") ||
		!blob.get_bool(AIBM_STONE_RETURN_SURFACED_KEY) ||
		!AIB_HasReachedStoneReturnSurface(blob.getPosition(), anchor, map.tilesize)) return false;

	const bool firstSurfaceCapture = !rules.get_bool("aibt stone route abort reentry surfaced");
	rules.set_bool("aibt stone route abort reentry surfaced", true);
	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_bool("ai builder justgo", false);
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	blob.setKeyPressed(key_up, false);
	blob.setKeyPressed(key_down, false);
	blob.setVelocity(Vec2f_zero);
	if (firstSurfaceCapture)
	{
		AIB_LogEvent("test", "stone_return_reentry_fixture_complete", AIB_EventBlobRef(blob),
			"anchor=" + AIB_EventPos(anchor) + " pos=" + AIB_EventPos(blob.getPosition()) +
			" corner_bypassed=true surfaced=true");
	}
	return true;
}

void AIB_TickAutoBuilder(CBrain@ brain, CBlob@ blob)
{
	if (brain is null || blob is null) return;
	CShape@ shape = blob.getShape();
	if (shape !is null)
	{
		shape.getConsts().mapCollisions = false;
		shape.getConsts().collidable = false;
		shape.SetGravityScale(0.0f);
	}

	if (!blob.get_bool("ai builder job active"))
	{
		blob.setVelocity(Vec2f_zero);
		if (blob.get_u8("ai builder state") != AIBuilderState::idle)
		{
			AIBP_ReleaseBuilderReservation(u8(blob.getTeamNum()), blob.getNetworkID());
			AIB_SetState(blob, AIBuilderState::idle, "autobuilder inactive");
		}
		return;
	}

	if (blob.get_u8("ai builder job") != AIB_JOB_BLUEPRINT)
	{
		blob.set_u8("ai builder job", AIB_JOB_BLUEPRINT);
		blob.Sync("ai builder job", true);
	}

	const u8 state = blob.get_u8("ai builder state");
	if (state == AIBuilderState::find_blueprint_block)
	{
		AIB_FindBlueprintBlock(brain, blob);
		if (blob.get_u8("ai builder state") == AIBuilderState::find_blueprint_block &&
			blob.get_Vec2f("ai builder tile target") == Vec2f_zero)
		{
			blob.setVelocity(Vec2f_zero);
		}
		return;
	}
	if (state == AIBuilderState::build_blueprint_block)
	{
		AIB_BuildBlueprintBlock(brain, blob);
		return;
	}

	// The director may use the ordinary builder's resource-collection entry
	// state. Infinite-resource orbs collapse every non-build state to selection.
	blob.set_netid("ai builder target", 0);
	blob.set_Vec2f("ai builder tile target", Vec2f_zero);
	AIB_SetState(blob, AIBuilderState::find_blueprint_block, "autobuilder blueprint-only executor");
}

void AIB_FindTree(CBrain@ brain, CBlob@ blob)
{
	CBlob@ tree = AIB_GetNearestTree(blob);
	if (tree is null)
	{
		// Quarry creation reserves one fuel batch in addition to its build cost.
		// Finish that build/approach/refuel transaction before a no-tree nursery
		// quest can spend the same base stock.
		CBlob@ home = AIB_GetTeamHome(blob);
		if (home !is null && AIB_TryMaintainBaseQuarry(brain, blob, home))
		{
			return;
		}

		CBlob@ growingTree = AIB_GetNearestAccessibleTreeIgnoringMaturity(blob);
		if (growingTree !is null && !AIB_IsTreeHarvestReady(growingTree))
		{
			AIB_ReportWaitingStatus(blob, "Waiting for trees to mature");
			return;
		}

		const bool noUnselectedTrees = AIB_GetNearestTreeIgnoringSelection(blob) is null;
		if (noUnselectedTrees && AIB_CanStartNurseryQuest(blob, home))
		{
			AIB_SetState(blob, AIBuilderState::nursery_collect_wood, "no accessible trees; starting nursery quest");
		}
		else
		{
			AIB_ReportWaitingStatus(blob, noUnselectedTrees ?
				"Waiting for nursery funding" : "Waiting for an overseer-selected tree");
			AIB_SetState(blob, AIBuilderState::find_tree,
				noUnselectedTrees ? "no trees and nursery quest is not yet funded" : "no overseer-selected tree available");
		}
		return;
	}

	brain.SetTarget(tree);
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_netid("ai builder target", tree.getNetworkID());
	AIB_BeginTreeProgress(blob, tree);
	AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=" + AIB_EventBlobRef(tree) +
		" state=chop_tree pos=" + AIB_EventPos(blob.getPosition()) +
		" climb_penalty=" + blob.get_f32("ai builder selected tree climb penalty"));
	AIB_SetState(blob, AIBuilderState::chop_tree, "tree target acquired");
}

void AIB_ChopTree(CBrain@ brain, CBlob@ blob)
{
	CBlob@ tree = getBlobByNetworkID(blob.get_netid("ai builder target"));
	if (tree is null || tree.hasTag("dead") || tree.hasTag("felldown"))
	{
		AIB_SetState(blob, AIBuilderState::find_log, "tree felled or gone");
		blob.set_netid("ai builder target", 0);
		blob.set_u32("ai builder log wait until", getGameTime() + AIB_LOG_WAIT);
		return;
	}
	if (!AIB_IsTreeHarvestReady(tree))
	{
		brain.SetTarget(null);
		blob.set_netid("ai builder target", 0);
		AIB_SetState(blob, AIBuilderState::find_tree, "target tree is still growing");
		return;
	}

	Vec2f treePos = AIB_GetHitPosition(blob, tree);
	Vec2f blobPos = blob.getPosition();
	const f32 distance = (treePos - blobPos).Length();
	if (AIB_TreeProgressExpired(brain, blob, tree, distance)) return;

	blob.setAimPos(treePos);
	if (distance > 32.0f)
	{
		AIB_GoTo(brain, blob, treePos);
	}
	else
	{
		// The approach is complete. Do not leave the old destination/path looking
		// like movement intent while the builder correctly stands still to chop.
		brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		blob.setKeyPressed(key_action2, true);
		AIB_HitTarget(blob, tree, treePos);
	}
}

void AIB_FindLog(CBrain@ brain, CBlob@ blob)
{
	CBlob@ log = AIB_GetNearestLog(blob);
	if (log is null)
	{
		if (getGameTime() < blob.get_u32("ai builder log wait until"))
		{
			AIB_ReportWaitingStatus(blob, "Waiting for fallen logs");
			return;
		}

		AIB_EnsureHarvestedWood(blob);
		if (AIB_HasWood(blob))
		{
			AIB_ReadyWoodInHand(blob);
			AIB_SetState(blob, AIBuilderState::return_wood, "no logs left and wood held");
		}
		else if (AIB_GetNearestWood(blob) !is null)
		{
			AIB_SetState(blob, AIBuilderState::find_wood, "loose wood found after logs");
		}
		else
		{
			AIB_SetState(blob, AIBuilderState::find_tree, "no logs or wood found");
		}
		return;
	}

	brain.SetTarget(log);
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_netid("ai builder target", log.getNetworkID());
	AIB_BeginLogProgress(blob, log);
	AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=" + AIB_EventBlobRef(log) + " state=chop_log pos=" + AIB_EventPos(blob.getPosition()));
	AIB_SetState(blob, AIBuilderState::chop_log, "log target acquired");
}

void AIB_ChopLog(CBrain@ brain, CBlob@ blob)
{
	CBlob@ log = getBlobByNetworkID(blob.get_netid("ai builder target"));
	if (log is null || log.hasTag("dead"))
	{
		AIB_SetState(blob, AIBuilderState::find_log, "log gone");
		blob.set_netid("ai builder target", 0);
		blob.set_netid("ai builder log progress target", 0);
		return;
	}

	Vec2f logPos = AIB_GetHitPosition(blob, log);
	Vec2f blobPos = blob.getPosition();
	const f32 distance = (logPos - blobPos).Length();
	if (AIB_LogProgressExpired(brain, blob, log, distance)) return;

	blob.setAimPos(logPos);
	if (distance > 28.0f)
	{
		AIB_GoTo(brain, blob, logPos);
	}
	else
	{
		brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		CBlob@ saw = AIB_GetGuideLogSaw(blob, log);
		if (saw !is null)
		{
			blob.setAimPos(log.getPosition());
			blob.setKeyPressed(key_action3, true);
			blob.server_Pickup(log);
			if (blob.getCarriedBlob() is log)
			{
				blob.set_netid("ai builder guide saw target", saw.getNetworkID());
				AIB_LogEvent("ai", "guide_saw_log_pickup", AIB_EventBlobRef(blob),
					"log=" + AIB_EventBlobRef(log) + " saw=" + AIB_EventBlobRef(saw));
				AIB_SetState(blob, AIBuilderState::deliver_log_to_saw, "safe guide saw available");
				return;
			}
		}
		blob.setKeyPressed(key_action2, true);
		if (AIB_HitTarget(blob, log, logPos))
		{
			blob.set_u16("ai builder pending wood", Maths::Min(500, blob.get_u16("ai builder pending wood") + 10));
		}

		if (AIB_GetNearestLog(blob) is null && AIB_HasWood(blob))
		{
			AIB_ReadyWoodInHand(blob);
			AIB_SetState(blob, AIBuilderState::return_wood, "last log consumed and wood held");
		}
	}
}

CBlob@ AIB_GetGuideLogSaw(CBlob@ blob, CBlob@ log)
{
	if (blob is null || log is null) return null;
	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null) return null;
	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	CBlob@[] saws;
	getBlobsByName("saw", @saws);
	for (uint i = 0; i < saws.length; i++)
	{
		CBlob@ saw = saws[i];
		if (!AIBGuide_IsStructurallySafeSaw(blob, log, saw, home) || !AIB_IsAccessibleResource(blob, saw)) continue;
		const f32 distance = (saw.getPosition() - blob.getPosition()).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = saw;
		}
	}
	return best;
}

void AIB_DeliverLogToSaw(CBrain@ brain, CBlob@ blob)
{
	CBlob@ log = blob.getCarriedBlob();
	CBlob@ saw = getBlobByNetworkID(blob.get_netid("ai builder guide saw target"));
	if (log is null || log.getName() != "log")
	{
		blob.set_netid("ai builder guide saw target", 0);
		blob.set_netid("ai builder target", 0);
		AIB_SetState(blob, AIBuilderState::find_log, "carried guide saw log missing");
		return;
	}
	if (saw is null || saw.hasTag("dead") || !saw.get_bool("saw_on") || !AIB_IsAccessibleResource(blob, saw))
	{
		log.server_DetachFrom(blob);
		log.setPosition(blob.getPosition());
		log.setVelocity(Vec2f_zero);
		blob.set_netid("ai builder guide saw target", 0);
		blob.set_netid("ai builder target", 0);
		AIB_SetState(blob, AIBuilderState::find_log, "guide saw became unsafe or unavailable");
		return;
	}
	CBlob@ home = AIB_GetTeamHome(blob);
	if (!AIBGuide_IsStructurallySafeSaw(blob, log, saw, home))
	{
		log.server_DetachFrom(blob);
		log.setPosition(blob.getPosition());
		log.setVelocity(Vec2f_zero);
		blob.set_netid("ai builder guide saw target", 0);
		blob.set_netid("ai builder target", 0);
		AIB_SetState(blob, AIBuilderState::find_log, "guide saw left safe base role");
		return;
	}
	const f32 side = blob.getPosition().x <= saw.getPosition().x ? -1.0f : 1.0f;
	Vec2f approach = saw.getPosition() + Vec2f(side * 28.0f, -4.0f);
	if ((approach - blob.getPosition()).Length() > 14.0f)
	{
		AIB_GoTo(brain, blob, approach);
		return;
	}
	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	log.server_DetachFrom(blob);
	log.setPosition(saw.getPosition() + Vec2f(0.0f, -16.0f));
	log.setVelocity(Vec2f_zero);
	AIB_LogEvent("ai", "guide_saw_log_drop", AIB_EventBlobRef(blob),
		"log=" + AIB_EventBlobRef(log) + " saw=" + AIB_EventBlobRef(saw));
	blob.set_netid("ai builder guide saw target", 0);
	blob.set_netid("ai builder target", 0);
	blob.set_u32("ai builder log wait until", getGameTime() + AIB_LOG_WAIT);
	AIB_SetState(blob, AIBuilderState::find_log, "log delivered to guide saw");
}

void AIB_FindWood(CBrain@ brain, CBlob@ blob)
{
	CBlob@ wood = AIB_GetNearestWood(blob);
	if (wood is null)
	{
		CBlob@ tree = AIB_GetNearestTree(blob);
		if (tree !is null)
		{
			AIB_SetState(blob, AIBuilderState::find_tree, "loose wood missing, tree available");
		}
		else
		{
			AIB_SetState(blob, AIBuilderState::find_tree, "loose wood missing, retrying wood job");
		}
		return;
	}

	Vec2f woodPos = wood.getPosition();
	Vec2f blobPos = blob.getPosition();
	if ((woodPos - blobPos).Length() > 18.0f)
	{
		AIB_GoTo(brain, blob, woodPos);
	}
	else
	{
		blob.setAimPos(woodPos);
		blob.setKeyPressed(key_action3, true);
		blob.server_Pickup(wood);
		if (wood.isInInventory() || blob.getCarriedBlob() is wood) AIBGM_RecordCollectedResource(blob, wood);
		AIB_ReadyWoodInHand(blob);
		AIB_SetState(blob, AIBuilderState::return_wood, "picked loose wood");
	}
}

void AIB_ReturnWood(CBrain@ brain, CBlob@ blob)
{
	// A stone runner can finish its quota at the bottom of the two-wide route.
	// Ordinary BrainPath navigation does not reliably climb that open shaft, so
	// retrace the episode's exact entry column before selecting the base path.
	if (AIB_TryReturnThroughStoneRoute(brain, blob)) return;

	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null)
	{
		blob.set_netid("ai builder delivery home", 0);
		brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		AIB_ReportWaitingStatus(blob, "Waiting for a team home");
		AIB_LogEvent("ai", "no_home", AIB_EventBlobRef(blob), "state=return_wood pos=" + AIB_EventPos(blob.getPosition()));
		AIB_Debug(blob, "no team home found; cannot drop resources");
		const u8 job = blob.get_u8("ai builder job");
		if (job == AIB_JOB_WOOD || job == AIB_JOB_STONE)
		{
			AIB_SetState(blob, AIBuilderState::return_wood, "no home for resource drop, retrying resource job");
		}
		else
		{
			AIB_SetState(blob, AIBuilderState::idle, "no home for resource drop");
		}
		return;
	}

	// A path is only valid for the friendly home it was created for.  A builder
	// can be re-teamed after spawning, and tents/halls can change team while it
	// is travelling.  Do not let the old path keep driving it to that now-enemy
	// structure for another tick cycle.
	const u16 homeID = home.getNetworkID();
	const u16 previousHomeID = blob.get_netid("ai builder delivery home");
	if (previousHomeID != homeID)
	{
		brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		blob.set_bool("ai builder justgo", false);
		blob.set_netid("ai builder delivery home", homeID);
	}

	Vec2f hallPos = AIB_GetBaseStoragePoint(home);
	Vec2f blobPos = blob.getPosition();
	const u8 job = blob.get_u8("ai builder job");

	if ((hallPos - blobPos).Length() > 34.0f)
	{
		AIB_StashCarriedResource(blob);
		AIB_GoTo(brain, blob, hallPos);
		return;
	}
	// Reaching the storage interaction radius ends the travel phase. Inventory
	// insertion and its engine confirmation can legitimately take several
	// stationary ticks, so the old approach destination must not remain visible
	// as movement intent during that wait.
	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);

	bool deliveryConfirmed = false;
	const u32 now = getGameTime();
	const u32 confirmUntil = blob.get_u32(AIB_DELIVERY_CONFIRM_UNTIL_KEY);
	if (confirmUntil != 0)
	{
		if (now < confirmUntil)
		{
			AIB_ReportWaitingStatus(blob, "Confirming storage transfer");
			return;
		}
		blob.set_u32(AIB_DELIVERY_CONFIRM_UNTIL_KEY, 0);
		if (AIB_HasAnyResource(blob))
		{
			// A queued crate insertion bounced back. Retry the normal selector so
			// it can mark the rejected crate full and fund overflow storage.
			AIB_LogEvent("ai", "store_resources_retry", AIB_EventBlobRef(blob),
				"wood=" + AIB_CountMaterial(blob, "mat_wood") +
				" stone=" + AIB_CountMaterial(blob, "mat_stone") +
				" gold=" + AIB_CountMaterial(blob, "mat_gold"));
		}
		else
		{
			deliveryConfirmed = true;
		}
	}

	if (!deliveryConfirmed)
	{
		AIB_StashCarriedResource(blob);
		if (blob.get_u16("ai builder delivery pending wood") == 0 &&
			blob.get_u16("ai builder delivery pending stone") == 0 &&
			blob.get_u16("ai builder delivery pending gold") == 0)
		{
			blob.set_u16("ai builder delivery pending wood", AIB_CountMaterial(blob, "mat_wood"));
			blob.set_u16("ai builder delivery pending stone", AIB_CountMaterial(blob, "mat_stone"));
			blob.set_u16("ai builder delivery pending gold", AIB_CountMaterial(blob, "mat_gold"));
		}
		if (!AIB_StoreResourcesInBaseCrates(blob, home))
		{
			AIB_ReportWaitingStatus(blob, "Waiting for storage at home");
			AIB_Debug(blob, "waiting for crate storage at base");
			return;
		}
		blob.set_u32(AIB_DELIVERY_CONFIRM_UNTIL_KEY, now + AIB_DELIVERY_CONFIRM_TICKS);
		AIB_ReportWaitingStatus(blob, "Confirming storage transfer");
		return;
	}
	AIB_LogEvent("ai", "store_resources", AIB_EventBlobRef(blob),
		"home=" + AIB_EventBlobRef(home) +
		" wood=" + blob.get_u16("ai builder delivery pending wood") +
		" stone=" + blob.get_u16("ai builder delivery pending stone") +
		" gold=" + blob.get_u16("ai builder delivery pending gold") +
		" pos=" + AIB_EventPos(home.getPosition()));
	AIBGM_RecordConfirmedDelivery(blob,
		blob.get_u16("ai builder delivery pending wood"),
		blob.get_u16("ai builder delivery pending stone"),
		blob.get_u16("ai builder delivery pending gold"));
	blob.set_u16("ai builder delivery pending wood", 0);
	blob.set_u16("ai builder delivery pending stone", 0);
	blob.set_u16("ai builder delivery pending gold", 0);

	// Delivery is the resource episode's atomic handoff boundary. Clear the old
	// tree/stone route before entering its neutral find state; otherwise the
	// pending-role predicate still sees a tile target and the old job can start
	// another long episode before the next director heartbeat.
	blob.set_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY, getGameTime() + AIB_RESOURCE_HANDOFF_HOLD_TICKS);
	AIBM_ClearDeliveredResourceEpisodeIntent(blob, job, getGameTime());
	if (job == AIB_JOB_STONE)
	{
		AIB_SetState(blob, AIBuilderState::find_stone, "resources delivered");
		if (AIBM_TryApplyDeferredRoleAtSafeBoundary(blob)) return;
	}
	else
	{
		AIB_SetState(blob, AIBuilderState::find_tree, "wood delivered");
		if (AIBM_TryApplyDeferredRoleAtSafeBoundary(blob)) return;
		if (AIB_TryMaintainBaseQuarry(brain, blob, home))
		{
			return;
		}
	}
}

bool AIB_ShouldHoldAtResourceHandoff(CBlob@ blob)
{
	if (blob is null || !blob.get_bool("aib strategy assigned")) return false;
	const u32 until = blob.get_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY);
	if (until == 0) return false;
	if (getGameTime() >= until)
	{
		blob.set_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY, 0);
		return false;
	}
	if (!AIBM_IsAtStrategyHandoff(blob)) return false;
	AIB_ReportWaitingStatus(blob, "Waiting for director role update");
	return true;
}

bool AIB_IsGuideResupplyBoundary(CBlob@ blob)
{
	return AIBGuide_IsSafeEpisodeBoundary(blob);
}

bool AIB_TryStartGuideResupply(CBlob@ blob)
{
	CRules@ rules = getRules();
	if (blob is null || rules is null || rules.isWarmup() || !AIBGuide_ResupplyEnabled(rules) ||
		!AIBGuide_IsAutonomousBuilder(blob) ||
		blob.get_u8("ai builder state") == AIBuilderState::visit_resupply) return false;
	const u32 now = getGameTime();
	if (blob.get_u32(AIB_GUIDE_RESUPPLY_NEXT_KEY) > now ||
		now < blob.get_u32("ai builder guide resupply retry") || !AIB_IsGuideResupplyBoundary(blob)) return false;
	// A resource runner carrying an episode outcome must finish its normal
	// delivery boundary first. Blueprint workers may keep partial shop funding.
	if (blob.get_u8("ai builder job") != AIB_JOB_BLUEPRINT && AIB_HasAnyResource(blob)) return false;
	// A warm-up grant or an earlier visit may have left a completion timestamp.
	// Clear its source before publishing this request so only a fresh physical
	// match resupply can complete the visit state.
	blob.set_netid(AIB_GUIDE_RESUPPLY_SOURCE_KEY, 0);
	blob.set_u32("ai builder guide resupply request", now);
	blob.set_u32("ai builder guide resupply timeout", now + 15 * 30);
	AIB_SetState(blob, AIBuilderState::visit_resupply, "guide resupply due at safe boundary");
	return true;
}

CBlob@ AIB_GetGuideResupplySpot(CBlob@ blob)
{
	return AIBGuide_GetNearestResupplySpot(blob);
}

void AIB_ResumeAfterGuideResupply(CBlob@ blob, const string &in reason)
{
	if (blob is null) return;
	blob.set_u32("ai builder guide resupply request", 0);
	blob.set_u32("ai builder guide resupply timeout", 0);
	const u8 job = blob.get_u8("ai builder job");
	if (job == AIB_JOB_BLUEPRINT)
	{
		AIB_SetState(blob, AIBuilderState::collect_blueprint_resources, reason);
	}
	else if (AIB_HasAnyResource(blob))
	{
		AIB_SetState(blob, AIBuilderState::return_wood, reason);
	}
	else if (job == AIB_JOB_STONE)
	{
		AIB_SetState(blob, AIBuilderState::find_stone, reason);
	}
	else
	{
		AIB_SetState(blob, AIBuilderState::find_tree, reason);
	}
}

void AIB_VisitGuideResupply(CBrain@ brain, CBlob@ blob)
{
	const u32 request = blob.get_u32("ai builder guide resupply request");
	const u16 sourceID = blob.get_netid(AIB_GUIDE_RESUPPLY_SOURCE_KEY);
	if (request != 0 && sourceID != 0 && blob.get_u32(AIB_GUIDE_RESUPPLY_LAST_KEY) >= request)
	{
		AIB_LogEvent("ai", "guide_resupply", AIB_EventBlobRef(blob),
			"source=" + sourceID +
			" wood=" + AIB_GUIDE_MATCH_WOOD + " stone=" + AIB_GUIDE_MATCH_STONE);
		AIB_ResumeAfterGuideResupply(blob, "guide resupply collected");
		return;
	}
	if (getGameTime() >= blob.get_u32("ai builder guide resupply timeout"))
	{
		blob.set_u32("ai builder guide resupply retry", getGameTime() + 5 * 30);
		AIB_ResumeAfterGuideResupply(blob, "guide resupply visit timed out");
		return;
	}

	CBlob@ spot = AIB_GetGuideResupplySpot(blob);
	if (spot is null)
	{
		blob.set_u32("ai builder guide resupply retry", getGameTime() + 5 * 30);
		AIB_ResumeAfterGuideResupply(blob, "no eligible guide resupply point");
		return;
	}
	if (!AIBGuide_IsMatchResupplySpot(spot, blob))
	{
		AIB_GoTo(brain, blob, spot.getPosition());
		return;
	}
	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_bool("ai builder justgo", false);
	AIB_ReportWaitingStatus(blob, "Collecting Builder resupply");
}

void AIB_FindStone(CBrain@ brain, CBlob@ blob)
{
	if (AIB_GetNearestStoneMat(blob) !is null)
	{
		AIB_SetState(blob, AIBuilderState::find_stone_mat, "quarry or loose stone available");
		return;
	}

	if (!AIB_IsInsideCurrentBarrierZoneAt(blob.getPosition()))
	{
		AIB_ReportWaitingStatus(blob, "Waiting outside the active barrier strip");
		AIB_SetState(blob, AIBuilderState::find_stone, "inside barrier strip, retrying stone job");
		return;
	}

	Vec2f stone = AIB_GetBestStoneTile(blob);
	if (stone == Vec2f_zero)
	{
		if (AIB_TryUseBaseStoneSource(brain, blob)) return;
		AIB_ReportWaitingStatus(blob, "Waiting for an accessible stone source");
		AIB_SetState(blob, AIBuilderState::find_stone, "no stone source found, retrying stone job");
		return;
	}

	blob.set_Vec2f("ai builder tile target", stone);
	blob.set_Vec2f("ai builder shaft top", Vec2f_zero);
	Vec2f routeCorner = AIB_GetBestStoneRouteCorner(blob, stone);
	blob.set_Vec2f("ai builder stone route corner", routeCorner);
	AIB_SetStoneReturnAnchor(blob, stone, routeCorner);
	blob.set_bool("ai builder mining gold", false);
	AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=stone_tile state=tunnel_to_stone tile=" + AIB_EventPos(stone) +
		" route_corner=" + AIB_EventPos(routeCorner) + " route_dirt=" + AIB_CountDirtOnStoneRoute(blob, stone, routeCorner) +
		" pos=" + AIB_EventPos(blob.getPosition()));
	AIB_SetState(blob, AIBuilderState::tunnel_to_stone, "stone tile acquired");
}

void AIB_PrepareStoneShaft(CBrain@ brain, CBlob@ blob)
{
	Vec2f shaftTop = blob.get_Vec2f("ai builder shaft top");
	if (shaftTop == Vec2f_zero)
	{
		AIB_SetState(blob, AIBuilderState::find_stone, "missing shaft top");
		return;
	}

	Vec2f stand = shaftTop + Vec2f(getMap().tilesize * 0.5f, -getMap().tilesize);
	if ((stand - blob.getPosition()).Length() > 28.0f)
	{
		AIB_GoTo(brain, blob, stand);
		return;
	}

	if (AIB_TileNeedsDigging(shaftTop) && !AIB_MineTile(blob, shaftTop))
	{
		blob.setAimPos(shaftTop + Vec2f(getMap().tilesize * 0.5f, getMap().tilesize * 0.5f));
		return;
	}

	Vec2f second = shaftTop + Vec2f(getMap().tilesize, 0.0f);
	if (AIB_TileNeedsDigging(second) && !AIB_MineTile(blob, second))
	{
		blob.setAimPos(second + Vec2f(getMap().tilesize * 0.5f, getMap().tilesize * 0.5f));
		return;
	}

	if (!AIB_SealShaftEntrance(blob, shaftTop))
	{
		AIB_SetState(blob, AIBuilderState::find_stone, "not enough wood to seal shaft entrance, retrying stone job");
		return;
	}
	AIB_SetState(blob, AIBuilderState::dig_stone_shaft, "shaft entrance prepared");
}

void AIB_DigStoneShaft(CBrain@ brain, CBlob@ blob)
{
	CMap@ map = getMap();
	Vec2f target = blob.get_Vec2f("ai builder tile target");
	Vec2f shaftTop = blob.get_Vec2f("ai builder shaft top");
	if (target == Vec2f_zero || shaftTop == Vec2f_zero || !AIB_IsStoneTile(target))
	{
		AIB_SetState(blob, AIBuilderState::find_stone, "stone target missing");
		return;
	}

	const int targetY = Maths::Floor(target.y / map.tilesize);
	const int builderY = Maths::Floor(blob.getPosition().y / map.tilesize);
	const int topY = Maths::Floor(shaftTop.y / map.tilesize);
	if (builderY >= targetY)
	{
		AIB_SetState(blob, AIBuilderState::tunnel_to_stone, "stone level reached");
		return;
	}

	const int shaftX = Maths::Floor(shaftTop.x / map.tilesize);
	Vec2f dig = Vec2f_zero;
	for (int y = topY + 1; y <= targetY; y++)
	{
		Vec2f left = Vec2f(shaftX * map.tilesize, y * map.tilesize);
		if (AIB_TileNeedsDigging(left))
		{
			dig = left;
			break;
		}

		Vec2f right = left + Vec2f(map.tilesize, 0.0f);
		if (AIB_TileNeedsDigging(right))
		{
			dig = right;
			break;
		}
	}

	if (dig != Vec2f_zero)
	{
		if ((AIB_TileCenter(dig) - blob.getPosition()).Length() > 34.0f)
		{
			AIB_GoTo(brain, blob, AIB_TileCenter(dig) + Vec2f(0.0f, -map.tilesize));
		}
		else
		{
			AIB_MineTile(blob, dig);
			blob.setKeyPressed(key_down, true);
		}
		return;
	}

	AIB_GoTo(brain, blob, AIB_TileCenter(Vec2f(shaftX * map.tilesize, (builderY + 1) * map.tilesize)));
	blob.setKeyPressed(key_down, true);
}

void AIB_TunnelToStone(CBrain@ brain, CBlob@ blob)
{
	CMap@ map = getMap();
	Vec2f target = blob.get_Vec2f("ai builder tile target");
	bool miningGold = blob.get_bool("ai builder mining gold");
	if (!miningGold)
	{
		Vec2f visibleGold = AIB_GetBestVisibleGoldTile(blob);
		if (visibleGold != Vec2f_zero)
		{
			target = visibleGold;
			miningGold = true;
			blob.set_bool("ai builder mining gold", true);
			blob.set_Vec2f("ai builder tile target", target);
			// Visible gold can be discovered after the miner is already below the
			// surface. A fresh surface-oriented route search may then fail even
			// though the retained shaft has a legal continuation. Use the same
			// fail-closed retarget policy as nearby stone so the return corner is
			// extended to this depth or the worker surfaces with its old route.
			if (!AIB_RetargetExistingStoneRoute(brain, blob, target)) return;
			brain.EndPath();
			AIB_EndBrainPath(blob);
			blob.set_Vec2f("ai builder destination", Vec2f_zero);
			AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=visible_gold_tile state=tunnel_to_stone tile=" + AIB_EventPos(target) + " pos=" + AIB_EventPos(blob.getPosition()));
		}
	}

	if (target == Vec2f_zero || (miningGold ? !AIB_IsGoldTile(target) : !AIB_IsStoneTile(target)))
	{
		AIB_CollectNearbyStone(blob);
		AIB_CollectNearbyGold(blob);
		if (miningGold)
		{
			Vec2f visibleGold = AIB_GetBestVisibleGoldTileNear(blob, target, 4);
			if (visibleGold != Vec2f_zero)
			{
				blob.set_Vec2f("ai builder tile target", visibleGold);
				if (!AIB_RetargetExistingStoneRoute(brain, blob, visibleGold)) return;
				AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=visible_gold_cluster_tile state=tunnel_to_stone tile=" + AIB_EventPos(visibleGold) + " pos=" + AIB_EventPos(blob.getPosition()));
				return;
			}

			blob.set_bool("ai builder mining gold", false);
			if (AIB_HasGold(blob))
			{
				AIB_SetState(blob, AIBuilderState::return_wood, "visible gold cluster depleted");
				return;
			}
		}
		if (AIB_ShouldReturnStone(blob))
		{
			AIB_SetState(blob, AIBuilderState::return_wood, "stone quota reached");
			return;
		}

		Vec2f nearbyStone = AIB_GetNearbyStoneTile(blob, target == Vec2f_zero ? blob.getPosition() : target, AIB_STONE_LOCAL_RADIUS);
		if (nearbyStone != Vec2f_zero)
		{
			blob.set_Vec2f("ai builder tile target", nearbyStone);
			if (AIB_RetargetExistingStoneRoute(brain, blob, nearbyStone))
			{
				AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=nearby_stone_tile state=tunnel_to_stone tile=" + AIB_EventPos(nearbyStone) + " pos=" + AIB_EventPos(blob.getPosition()));
			}
			return;
		}

		if (AIB_GetNearestStoneMat(blob) !is null)
		{
			AIB_SetState(blob, AIBuilderState::find_stone_mat, "stone tile mined");
		}
		else if (AIB_HasStone(blob))
		{
			AIB_SetState(blob, AIBuilderState::return_wood, "stone acquired");
		}
		else
		{
			AIB_SetState(blob, AIBuilderState::find_stone, "stone target consumed");
		}
		return;
	}

	AIB_CollectNearbyStone(blob);
	AIB_CollectNearbyGold(blob);
	if (!miningGold && AIB_ShouldReturnStone(blob))
	{
		AIB_SetState(blob, AIBuilderState::return_wood, "stone quota reached");
		return;
	}

	// Surface/exposed ore is an ordinary short movement-and-hit task. Sending a
	// same-level target through the shaft planner can make a small jump change
	// builderY by one tile, after which the planner repeatedly targets a
	// pointless vertical corner under the builder instead of approaching ore.
	// Prefer direct visible movement whenever an adjacent standing cell is open.
	if (AIB_TryMineExposedStone(brain, blob, target)) return;

	Vec2f targetCenter = AIB_TileCenter(target);
	Vec2f routeCorner = blob.get_Vec2f("ai builder stone route corner");
	if (routeCorner == Vec2f_zero)
	{
		// Safety net for hot-reloaded/legacy state and any retarget caller that
		// reaches tunnel movement without a usable corner. Never degrade to raw
		// ore BrainPath through dirt: continue the retained shaft or surface.
		if (!AIB_RetargetExistingStoneRoute(brain, blob, target)) return;
		routeCorner = blob.get_Vec2f("ai builder stone route corner");
	}
	Vec2f routeDestination = AIB_GetStoneRouteDestination(blob, target);
	Vec2f clearanceTile = AIB_GetStoneRouteClearanceTile(blob, target, routeCorner, routeDestination);
	if (clearanceTile != Vec2f_zero && AIB_IsNonMineableStoneRouteBlock(clearanceTile) &&
		AIB_IsTileOnStoneRoute(blob, target, routeCorner, clearanceTile))
	{
		AIB_RecomputeStoneRouteAroundBlock(brain, blob, target, clearanceTile);
		return;
	}
	if (clearanceTile != Vec2f_zero && AIB_CanMineStoneRouteClearance(blob, target, clearanceTile))
	{
		Vec2f clearanceCenter = AIB_TileCenter(clearanceTile);
		if ((clearanceCenter - blob.getPosition()).Length() <= 40.0f)
		{
			AIB_MineTile(blob, clearanceTile);
			return;
		}

		// BrainPath alternates surface/underground nodes when a vertical clearance
		// tile is just beyond hit range. Let the dedicated shaft controller own the
		// approach before falling back to ordinary pathing.
		if (AIB_DriveStoneRouteShaft(brain, blob, target, routeCorner)) return;
		AIB_GoTo(brain, blob, clearanceCenter);
		return;
	}

	Vec2f blockingTile = AIB_GetBlockingTileTowardStone(blob, routeDestination);
	if (blockingTile != Vec2f_zero && AIB_IsNonMineableStoneRouteBlock(blockingTile) &&
		AIB_IsTileOnStoneRoute(blob, target, routeCorner, blockingTile))
	{
		AIB_RecomputeStoneRouteAroundBlock(brain, blob, target, blockingTile);
		return;
	}
	if (blockingTile != Vec2f_zero && (blockingTile - target).Length() > 1.0f && AIB_CanMineStoneRouteClearance(blob, target, blockingTile))
	{
		Vec2f blockingCenter = AIB_TileCenter(blockingTile);
		if ((blockingCenter - blob.getPosition()).Length() <= 40.0f)
		{
			AIB_MineTile(blob, blockingTile);
			return;
		}
	}

	if ((targetCenter - blob.getPosition()).Length() <= 40.0f)
	{
		AIB_MineTile(blob, target);
		return;
	}

	Vec2f routeCenter = AIB_TileCenter(routeDestination);
	const bool atOreSegment = (routeCenter - targetCenter).Length() < 1.0f;
	Vec2f approach = atOreSegment ? AIB_GetApproachPositionForStone(blob, target) : routeCenter;
	const bool hasOpenApproach = !atOreSegment || (approach - routeCenter).Length() > 1.0f;
	const bool shouldDig = !hasOpenApproach ||
		blob.get_u8("ai builder obstruction threshold") > 8 ||
		brain.getState() == CBrain::stuck ||
		brain.getState() == CBrain::wrong_path;

	if (shouldDig)
	{
		Vec2f dig = AIB_GetNextTunnelTile(blob, target, routeCorner, routeDestination);
		if (dig != Vec2f_zero && AIB_IsNonMineableStoneRouteBlock(dig) &&
			AIB_IsTileOnStoneRoute(blob, target, routeCorner, dig))
		{
			AIB_RecomputeStoneRouteAroundBlock(brain, blob, target, dig);
			return;
		}
		if (dig != Vec2f_zero && AIB_CanMineStoneRouteClearance(blob, target, dig))
		{
			Vec2f digCenter = AIB_TileCenter(dig);
			if ((digCenter - blob.getPosition()).Length() <= 40.0f)
			{
				AIB_MineTile(blob, dig);
				return;
			}

			if (AIB_DriveStoneRouteShaft(brain, blob, target, routeCorner)) return;
			AIB_GoTo(brain, blob, digCenter);
			return;
		}
	}

	if (AIB_DriveStoneRouteShaft(brain, blob, target, routeCorner)) return;
	blob.set_bool("ai builder direct stone shaft", false);
	AIB_GoTo(brain, blob, approach);
}

bool AIB_TryMineExposedStone(CBrain@ brain, CBlob@ blob, Vec2f target)
{
	CMap@ map = getMap();
	if (brain is null || blob is null || map is null || target == Vec2f_zero) return false;

	Vec2f returnAnchor = blob.get_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY);
	Vec2f routeCorner = blob.get_Vec2f("ai builder stone route corner");
	const bool underground = returnAnchor != Vec2f_zero &&
		blob.getPosition().y > returnAnchor.y + map.tilesize * 1.5f;
	// An ordinary BrainPath shortcut can reach exposed ore through a cave while
	// skipping solid cells in the planned cross-tunnel. The miner would then
	// retain a shaft it cannot physically rejoin. Below the surface handoff,
	// require the entire two-high return corridor to be open; otherwise fall
	// through to the route excavator below.
	if (underground && (routeCorner == Vec2f_zero || !AIB_IsStoneCrossTunnelOpen(target, routeCorner)))
	{
		blob.set_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY, Vec2f_zero);
		blob.set_Vec2f(AIBM_STONE_EXPOSED_APPROACH_KEY, Vec2f_zero);
		return false;
	}

	Vec2f latchedTarget = blob.get_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY);
	Vec2f approach = blob.get_Vec2f(AIBM_STONE_EXPOSED_APPROACH_KEY);
	bool continuingApproach = latchedTarget != Vec2f_zero && approach != Vec2f_zero &&
		(latchedTarget - target).Length() < 1.0f;
	if (!continuingApproach && latchedTarget != Vec2f_zero)
	{
		blob.set_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY, Vec2f_zero);
		blob.set_Vec2f(AIBM_STONE_EXPOSED_APPROACH_KEY, Vec2f_zero);
		latchedTarget = Vec2f_zero;
		approach = Vec2f_zero;
	}

	const int builderY = Maths::Floor(blob.getPosition().y / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	if (!continuingApproach)
	{
		if (Maths::Abs(builderY - targetY) > 2 || AIB_CountOpenStoneSides(target) == 0) return false;
		approach = AIB_GetApproachPositionForStone(blob, target);
		if (!AIB_HasStoneApproachBodyClearance(blob, approach)) return false;

		brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		blob.set_bool("ai builder justgo", false);
		blob.set_u8("ai builder obstruction threshold", 0);
		blob.set_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY, target);
		blob.set_Vec2f(AIBM_STONE_EXPOSED_APPROACH_KEY, approach);
		continuingApproach = true;
		AIB_LogEvent("ai", "stone_exposed_path", AIB_EventBlobRef(blob),
			"target=" + AIB_EventPos(target) + " approach=" + AIB_EventPos(approach));
	}
	else if (!AIB_HasStoneApproachBodyClearance(blob, approach))
	{
		blob.set_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY, Vec2f_zero);
		blob.set_Vec2f(AIBM_STONE_EXPOSED_APPROACH_KEY, Vec2f_zero);
		return false;
	}

	Vec2f targetCenter = AIB_TileCenter(target);
	if ((targetCenter - blob.getPosition()).Length() <= 40.0f)
	{
		AIB_MineTile(blob, target);
		return true;
	}

	AIB_GoTo(brain, blob, approach);
	blob.setAimPos(targetCenter);
	return true;
}

void AIB_FindStoneMat(CBrain@ brain, CBlob@ blob)
{
	CBlob@ stone = AIB_GetNearestStoneMat(blob);
	if (stone is null)
	{
		Vec2f target = blob.get_Vec2f("ai builder tile target");
		Vec2f nearbyStone = AIB_GetNearbyStoneTile(blob, target == Vec2f_zero ? blob.getPosition() : target, AIB_STONE_LOCAL_RADIUS);
		if (nearbyStone != Vec2f_zero && !AIB_ShouldReturnStone(blob))
		{
			blob.set_Vec2f("ai builder tile target", nearbyStone);
			if (AIB_RetargetExistingStoneRoute(brain, blob, nearbyStone))
			{
				AIB_SetState(blob, AIBuilderState::tunnel_to_stone, "nearby stone found");
			}
		}
		else if (AIB_HasStone(blob))
		{
			AIB_SetState(blob, AIBuilderState::return_wood, "stone gathered");
		}
		else
		{
			AIB_SetState(blob, AIBuilderState::find_stone, "loose stone missing");
		}
		return;
	}

	Vec2f stonePos = stone.getPosition();
	if ((stonePos - blob.getPosition()).Length() > 18.0f)
	{
		AIB_GoTo(brain, blob, stonePos);
	}
	else
	{
		blob.setAimPos(stonePos);
		AIB_PickupStone(blob, stone);
		if (AIB_ShouldReturnStone(blob))
		{
			AIB_SetState(blob, AIBuilderState::return_wood, "stone quota reached");
		}
		else
		{
			Vec2f target = blob.get_Vec2f("ai builder tile target");
			Vec2f nearbyStone = AIB_GetNearbyStoneTile(blob, target == Vec2f_zero ? stonePos : target, AIB_STONE_LOCAL_RADIUS);
			if (nearbyStone != Vec2f_zero)
			{
				blob.set_Vec2f("ai builder tile target", nearbyStone);
				if (AIB_RetargetExistingStoneRoute(brain, blob, nearbyStone))
				{
					AIB_SetState(blob, AIBuilderState::tunnel_to_stone, "picked loose stone, nearby stone remains");
				}
			}
			else
			{
				AIB_SetState(blob, AIBuilderState::return_wood, "local stone depleted");
			}
		}
	}
}

void AIB_CollectBlueprintResources(CBrain@ brain, CBlob@ blob)
{
	// Reservations protect an active approach/place attempt, not an unbounded
	// material trip. Release defensively on every collection tick as well as at
	// the transition so hot-reloaded workers cannot retain an old lease.
	if (blob !is null && blob.getTeamNum() >= 0 && blob.getTeamNum() < 8)
		AIBP_ReleaseBuilderReservation(u8(blob.getTeamNum()), blob.getNetworkID());
	string needed;
	u16 amount = 0;
	if (!AIB_GetBlueprintMaterialNeed(blob, needed, amount))
	{
		AIB_SetState(blob, AIBuilderState::find_blueprint_block, "blueprint resources ready");
		return;
	}

	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null)
	{
		AIB_ReportWaitingStatus(blob, "Waiting for a team home");
		return;
	}

	AIB_StashCarriedBlueprintMaterial(blob);

	CBlob@ material = AIB_GetHomeMaterial(blob, home, needed);
	if (material is null)
	{
		AIB_ReportWaitingStatus(blob, "Waiting for " + needed + " at home");
		AIB_Debug(blob, "waiting for blueprint material at home name=" + needed);
		return;
	}

	const f32 pickupDistance = material.getName() == "crate" ? 28.0f : 18.0f;
	if ((material.getPosition() - blob.getPosition()).Length() > pickupDistance)
	{
		AIB_GoTo(brain, blob, material.getPosition());
		return;
	}

	blob.setAimPos(material.getPosition());
	blob.setKeyPressed(key_action3, true);
	AIB_CollectHomeMaterial(blob, home, needed);

	string stillNeeded;
	u16 stillAmount = 0;
	if (!AIB_GetBlueprintMaterialNeed(blob, stillNeeded, stillAmount))
	{
		AIB_SetState(blob, AIBuilderState::find_blueprint_block, "blueprint resources ready");
	}
}

bool AIB_GetBlueprintMaterialNeed(CBlob@ blob, string &out material, u16 &out amount)
{
	material = "";
	amount = 0;
	if (blob is null) return false;
	if (AIBU_IsAutoBuilder(blob)) return false;
	const u8 team = u8(blob.getTeamNum());
	Vec2f targetTile = blob.get_Vec2f("ai builder tile target");
	if (targetTile != Vec2f_zero)
	{
		const u16 target = AIB_GetBlueprintTargetForTile(targetTile, team);
		if (target != 0)
		{
			string[] materials = { "mat_wood", "mat_stone", "mat_gold" };
			for (uint i = 0; i < materials.length; i++)
			{
				const u16 required = AIBP_BlockMaterialCost(target, materials[i]);
				if (required == 0 || AIB_CountMaterial(blob, materials[i]) >= required) continue;
				material = materials[i];
				amount = required;
				return true;
			}
			return false;
		}
	}

	const u16 wood = AIBP_MinRemainingBlockCost(team, "mat_wood");
	const u16 stone = AIBP_MinRemainingBlockCost(team, "mat_stone");
	const u16 gold = AIBP_MinRemainingBlockCost(team, "mat_gold");
	if ((wood > 0 && AIB_CountWood(blob) >= wood) || (stone > 0 && AIB_CountStone(blob) >= stone) ||
		(gold > 0 && AIB_CountMaterial(blob, "mat_gold") >= gold)) return false;
	if (wood > 0 && AIB_CountWood(blob) < wood)
	{
		material = "mat_wood"; amount = wood; return true;
	}
	if (stone > 0 && AIB_CountStone(blob) < stone)
	{
		material = "mat_stone"; amount = stone; return true;
	}
	if (gold > 0 && AIB_CountMaterial(blob, "mat_gold") < gold)
	{
		material = "mat_gold"; amount = gold; return true;
	}
	return false;
}

void AIB_FindBlueprintBlock(CBrain@ brain, CBlob@ blob)
{
	AIBP_ActivateSuggestedWorkForManualBuilder(blob);
	Vec2f tile = AIB_GetNearestBlueprintBuildTile(blob);
	if (tile == Vec2f_zero)
	{
		AIBP_ReleaseBuilderReservation(u8(blob.getTeamNum()), blob.getNetworkID());
		const string waitStatus = AIB_GetBlueprintWaitStatus(blob);
		AIB_LogBlueprintWaitSnapshot(blob, waitStatus);
		if (blob.get_bool("ai builder saw blueprint target") || waitStatus != "Waiting for blueprint work")
		{
			AIB_ReportWaitingStatus(blob, waitStatus);
		}
		blob.set_Vec2f("ai builder tile target", Vec2f_zero);
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		return;
	}

	blob.set_bool("ai builder saw blueprint target", true);
	blob.set_Vec2f("ai builder tile target", tile);
	AIB_LogEvent("ai", "blueprint_target", AIB_EventBlobRef(blob),
		"tile=" + AIB_EventPos(tile) + " block=" + AIB_GetBlueprintTargetForTile(tile, u8(blob.getTeamNum())));
	string needed;
	u16 amount = 0;
	if (AIB_GetBlueprintMaterialNeed(blob, needed, amount))
	{
		AIB_SetState(blob, AIBuilderState::collect_blueprint_resources, "need " + needed + "=" + amount);
		return;
	}
	AIB_SetState(blob, AIBuilderState::build_blueprint_block, "blueprint target acquired");
}

void AIB_LogBlueprintWaitSnapshot(CBlob@ blob, const string &in status)
{
	if (blob is null) return;
	CRules@ rules = getRules();
	if (rules is null) return;
	const u8 team = u8(blob.getTeamNum());
	const string signature = status + " phase=" + AIBP_CurrentTaskPhase(team) +
		" pending=" + rules.get_u16(AIBP_PlanKey(team, "pending")) +
		" wood=" + AIB_CountWood(blob) + " stone=" + AIB_CountStone(blob);
	const u32 now = getGameTime();
	if (blob.get_string("ai builder blueprint wait signature") == signature &&
		now < blob.get_u32("ai builder blueprint wait log tick") + AIB_STATUS_BUBBLE_RATE) return;
	blob.set_string("ai builder blueprint wait signature", signature);
	blob.set_u32("ai builder blueprint wait log tick", now);
	AIB_LogEvent("ai", "blueprint_wait", AIB_EventBlobRef(blob), signature);
}

void AIB_BuildBlueprintBlock(CBrain@ brain, CBlob@ blob)
{
	Vec2f tile = blob.get_Vec2f("ai builder tile target");
	const u8 team = u8(blob.getTeamNum());
	if (tile != Vec2f_zero)
	{
		Vec2f space = getMap().getTileSpacePosition(tile);
		if (!AIBP_ReserveTask(team, u16(space.x), u16(space.y), blob.getNetworkID()))
		{
			blob.set_Vec2f("ai builder tile target", Vec2f_zero);
			AIB_SetState(blob, AIBuilderState::find_blueprint_block, "blueprint reservation lost");
			return;
		}
	}
	if (tile == Vec2f_zero || !AIB_BlueprintTileStillNeedsWork(tile, team))
	{
		AIBP_ReleaseBuilderReservation(team, blob.getNetworkID());
		AIB_SetState(blob, AIBuilderState::find_blueprint_block, "blueprint tile complete");
		return;
	}

	Vec2f center = AIB_TileCenter(tile);
	if (AIB_ClearBlueprintPlacementPosition(brain, blob, tile)) return;
	if (AIB_ClearBlueprintSiteObstruction(brain, blob, tile)) return;

	Vec2f approach = AIB_GetBlueprintBuildApproach(blob, tile);
	if (AIBU_IsAutoBuilder(blob))
	{
		if ((approach - blob.getPosition()).Length() > 1.0f)
		{
			AIB_GoTo(brain, blob, approach);
			return;
		}
		blob.setPosition(approach);
		blob.setVelocity(Vec2f_zero);
	}
	else if ((center - blob.getPosition()).Length() > 32.0f && (approach - blob.getPosition()).Length() > 18.0f)
	{
		const Vec2f delta = approach - blob.getPosition();
		if (delta.y > 0.0f && Maths::Abs(delta.x) <= getMap().tilesize &&
			(blob.isOnLadder() || AIB_HasBlueprintLadderNear(blob)))
		{
			// Suggested paths can repeatedly replan without issuing key_down on a
			// vertical ladder inside a completed shell. isOnLadder() remains false
			// until the runner leaves the firing platform, so the placed ladder is
			// the stable signal while centering over the two-tile hatch and descending.
			brain.EndPath();
			AIB_EndBrainPath(blob);
			blob.set_Vec2f("ai builder destination", approach);
			if (Maths::Abs(delta.x) > 1.5f)
			{
				blob.setKeyPressed(delta.x < 0.0f ? key_left : key_right, true);
			}
			else
			{
				blob.setKeyPressed(key_down, true);
			}
			return;
		}
		AIB_GoTo(brain, blob, approach);
		return;
	}

	blob.setAimPos(center);
	if (AIB_PlaceBlueprintTile(blob, tile))
	{
		AIB_SetState(blob, AIBuilderState::find_blueprint_block, "placed blueprint tile");
	}
	else
	{
		string needed;
		u16 amount = 0;
		if (AIB_GetBlueprintMaterialNeed(blob, needed, amount))
		{
			AIB_SetState(blob, AIBuilderState::collect_blueprint_resources, "out of " + needed);
		}
	}
}

// Physical blueprint blocks cannot be created while the builder's collision
// shape overlaps their tile.  Move sideways as well as jumping so a low
// ceiling cannot leave the builder hopping forever on the reserved task.
bool AIB_ClearBlueprintPlacementPosition(CBrain@ brain, CBlob@ blob, Vec2f tile)
{
	CMap@ map = getMap();
	if (brain is null || blob is null || map is null) return false;
	if (AIBU_IsAutoBuilder(blob)) return false;

	const u16 target = AIB_GetBlueprintTargetForTile(tile, u8(blob.getTeamNum()));
	if (!AIBP_IsSolidTileBlock(target) && !AIBP_IsBlobBlock(target)) return false;

	Vec2f center = AIB_TileCenter(tile);
	Vec2f pos = blob.getPosition();
	// AIBuilder.cfg uses a 7.5 px shape radius; a tile extends 4 px from center.
	// Leave a small safety margin because positions are integrated between ticks.
	if (Maths::Abs(pos.x - center.x) >= 12.0f || Maths::Abs(pos.y - center.y) >= 12.0f) return false;

	f32 direction = pos.x < center.x ? -1.0f : 1.0f;
	const f32 sidestep = map.tilesize * 2.0f;
	const bool primaryClear = AIB_HasBuilderClearance(pos + Vec2f(direction * sidestep, 0.0f), blob.getTeamNum());
	const bool alternateClear = AIB_HasBuilderClearance(pos + Vec2f(-direction * sidestep, 0.0f), blob.getTeamNum());
	if (!primaryClear && alternateClear)
	{
		direction = -direction;
	}

	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	if (!primaryClear && !alternateClear)
	{
		// A narrow tower can block both horizontal sidesteps while leaving its
		// ladder/interior open. Move vertically away from the target so placing a
		// roof or low wall cannot overlap the builder's collision shape forever.
		f32 vertical = pos.y < center.y ? -1.0f : 1.0f;
		if (!AIB_HasBuilderClearance(pos + Vec2f(0.0f, vertical * sidestep), blob.getTeamNum()) &&
			AIB_HasBuilderClearance(pos + Vec2f(0.0f, -vertical * sidestep), blob.getTeamNum()))
		{
			vertical = -vertical;
		}
		blob.setKeyPressed(vertical < 0.0f ? key_up : key_down, true);
		return true;
	}
	blob.setKeyPressed(direction < 0.0f ? key_left : key_right, true);
	const u32 now = getGameTime();
	if (blob.isOnGround() && now >= blob.get_u32("ai builder next blueprint clearance jump"))
	{
		blob.setKeyPressed(key_up, true);
		blob.set_u32("ai builder next blueprint clearance jump", now + 30);
	}
	return true;
}

void AIB_GoTo(CBrain@ brain, CBlob@ blob, Vec2f destination)
{
	if (AIBU_IsAutoBuilder(blob))
	{
		AIB_GoToAutoBuilder(blob, destination);
		return;
	}
	if (AIB_GoToBrainPath(brain, blob, destination))
	{
		return;
	}

	AIB_GoToFallback(brain, blob, destination);
}

void AIB_GoToAutoBuilder(CBlob@ blob, Vec2f destination)
{
	if (blob is null) return;
	blob.set_Vec2f("ai builder destination", destination);
	blob.setAimPos(destination);

	Vec2f delta = destination - blob.getPosition();
	const f32 distance = delta.Length();
	const f32 speed = AIBU_GetFlightSpeed(u8(blob.getTeamNum()));
	if (distance <= speed || distance < 0.01f)
	{
		blob.setPosition(destination);
		blob.setVelocity(Vec2f_zero);
		return;
	}

	delta.Normalize();
	blob.setVelocity(delta * speed);
}

bool AIB_GoToBrainPath(CBrain@ brain, CBlob@ blob, Vec2f destination)
{
	if (blob is null) return false;

	BrainPath@ path = AIB_GetBrainPath(blob);
	if (path is null) return false;

	HighLevelNode@[]@ nodeMap;
	if (!getRules().get("node_map", @nodeMap) || nodeMap is null || nodeMap.length == 0)
	{
		return false;
	}

	Vec2f pos = blob.getPosition();
	Vec2f last = blob.get_Vec2f("ai builder destination");
	const f32 distance = (destination - pos).Length();
	const bool movedDestination = last == Vec2f_zero || (last - destination).Length() > 16.0f;
	if (movedDestination || !path.isPathing())
	{
		AIBG_RecordRepath(blob);
		path.SetPath(pos, destination);
		blob.set_Vec2f("ai builder destination", destination);
		blob.set_bool("ai builder justgo", false);
		brain.EndPath();
		Vec2f firstLow = path.path.length > 0 ? path.path[0] : Vec2f_zero;
		Vec2f firstWaypoint = path.waypoints.length > 0 ? path.waypoints[0] : Vec2f_zero;
		AIB_LogEvent("ai", "path_set", AIB_EventBlobRef(blob), "destination=" + AIB_EventPos(destination) +
			" waypoints=" + path.waypoints.length + " low=" + path.path.length +
			" low0=" + AIB_EventPos(firstLow) + " way0=" + AIB_EventPos(firstWaypoint));
	}
	AIB_RecordRecoveryPathProbe(blob, path, destination);

	if (!path.isPathing())
	{
		return distance <= 24.0f;
	}

	Vec2f next = destination;
	if (path.path.length > 0)
	{
		next = path.path[0];
	}
	else if (path.waypoints.length > 0)
	{
		next = path.waypoints[0];
	}

	AIB_DetectBrainPathObstructions(blob, path, destination, next);
	// General travel must not turn every path into a dirt tunnel.  Only the
	// stone miner's deliberate tunnel state may clear a path node, and even
	// then the dirt-route policy below gets the final say.
	Vec2f mine = Vec2f_zero;
	if (blob.get_u8("ai builder job") == AIB_JOB_STONE &&
		blob.get_u8("ai builder state") == AIBuilderState::tunnel_to_stone)
	{
		mine = AIB_GetMineablePathBlock(blob, path);
		Vec2f oreTarget = blob.get_Vec2f("ai builder tile target");
		if (mine != Vec2f_zero && oreTarget != Vec2f_zero && !AIB_CanMineStoneRouteClearance(blob, oreTarget, mine))
		{
			mine = Vec2f_zero;
		}
	}
	if (mine != Vec2f_zero)
	{
		if ((AIB_TileCenter(mine) - pos).Length() <= 40.0f)
		{
			AIB_MineTile(blob, mine);
			return true;
		}
	}

	path.Tick();
	const bool downwardSteer = AIB_TrySteerDownwardPath(blob, next, destination);
	if (!downwardSteer)
	{
		blob.set_u32("ai builder downward path steer until", 0);
		blob.set_s32("ai builder downward path steer direction", 0);
		blob.set_bool("ai builder downward path steering", false);
	}
	const bool upwardSteer = !downwardSteer && AIB_TrySteerUpwardPath(blob, next, destination);
	if (!upwardSteer)
	{
		blob.set_u32("ai builder upward path steer until", 0);
		blob.set_s32("ai builder upward path steer direction", 0);
		blob.set_bool("ai builder upward path steering", false);
	}
	const bool directVerticalSteer = downwardSteer || upwardSteer;
	if (!directVerticalSteer) path.SetSuggestedKeys();
	path.SetSuggestedAimPos();

	// Obstacle scaling injects a jump when horizontal speed is initially low;
	// that would cancel the deliberate walk-off or wall-jump direction used by
	// the bounded vertical-node controllers.
	if (!directVerticalSteer) AIB_ScaleObstacles(blob, next);
	return true;
}

bool AIB_TrySteerUpwardPath(CBlob@ blob, Vec2f next, Vec2f destination)
{
	if (blob is null || next == Vec2f_zero || blob.isOnLadder() || blob.isInWater()) return false;
	if (AIB_UsesDedicatedStoneRouteMovement(blob.get_u8("ai builder job"), blob.get_u8("ai builder state")) &&
		blob.get_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY) == Vec2f_zero) return false;

	CMap@ map = getMap();
	if (map is null) return false;
	Vec2f pos = blob.getPosition();
	const f32 rise = pos.y - next.y;
	const f32 nextLateral = next.x - pos.x;
	const u32 now = getGameTime();
	const u32 until = blob.get_u32("ai builder upward path steer until");
	const bool active = until > now;
	// BrainPath can express a wall climb as a one-tile diagonal-up node. The
	// former 0.75-tile lateral bound excluded the recurring Gloryhill
	// (63,328)->(56,320) escape node, leaving ordinary workers at the bottom of
	// a mined shaft. Keep the existing obstruction delay and one-sided wall
	// qualification, but admit exactly one tile of lateral node offset.
	if (rise < map.tilesize * 0.75f || (!active && Maths::Abs(nextLateral) > map.tilesize)) return false;
	if (!active && blob.get_u8("ai builder obstruction threshold") < AIB_UPWARD_PATH_STEER_OBSTRUCTION_TICKS)
		return false;

	const f32 wallX = blob.getRadius() + map.tilesize;
	const f32 wallY = blob.getRadius() * 0.5f;
	const bool leftWall = map.isTileSolid(pos + Vec2f(-wallX, -wallY)) ||
		map.isTileSolid(pos + Vec2f(-wallX, wallY));
	const bool rightWall = map.isTileSolid(pos + Vec2f(wallX, -wallY)) ||
		map.isTileSolid(pos + Vec2f(wallX, wallY));
	if (!active && !leftWall && !rightWall) return false;

	const s32 previous = blob.get_s32("ai builder upward path steer direction");
	s32 direction = previous;
	if (leftWall && !rightWall) direction = 1;
	else if (rightWall && !leftWall) direction = -1;
	else if (direction == 0) direction = destination.x < pos.x ? -1 : 1;
	if (direction == 0) return false;

	blob.setKeyPressed(key_left, direction < 0);
	blob.setKeyPressed(key_right, direction > 0);
	blob.setKeyPressed(key_up, true);
	blob.setKeyPressed(key_down, false);
	if (!active || direction != previous)
	{
		blob.set_u32("ai builder upward path steer until", now + AIB_UPWARD_PATH_STEER_HOLD_TICKS);
	}
	if (!blob.get_bool("ai builder upward path steering") || direction != previous)
	{
		AIB_LogEvent("ai", direction == previous || previous == 0 ? "path_upward_steer" : "path_upward_turn",
			AIB_EventBlobRef(blob), "pos=" + AIB_EventPos(pos) + " next=" + AIB_EventPos(next) +
			" destination=" + AIB_EventPos(destination) + " direction=" + direction +
			" left_wall=" + AIB_BoolString(leftWall) + " right_wall=" + AIB_BoolString(rightWall));
	}
	blob.set_s32("ai builder upward path steer direction", direction);
	blob.set_bool("ai builder upward path steering", true);
	return true;
}

bool AIB_TrySteerDownwardPath(CBlob@ blob, Vec2f next, Vec2f destination)
{
	if (blob is null || next == Vec2f_zero || blob.isOnLadder() || blob.isInWater()) return false;
	if (AIB_UsesDedicatedStoneRouteMovement(blob.get_u8("ai builder job"), blob.get_u8("ai builder state")) &&
		blob.get_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY) == Vec2f_zero) return false;

	CMap@ map = getMap();
	if (map is null) return false;
	Vec2f pos = blob.getPosition();
	const f32 down = next.y - pos.y;
	const f32 nextLateral = next.x - pos.x;
	const f32 destinationLateral = destination.x - pos.x;
	if (down < map.tilesize || Maths::Abs(nextLateral) > map.tilesize * 0.75f ||
		Maths::Abs(destinationLateral) <= blob.getRadius() * 0.75f) return false;

	const u32 now = getGameTime();
	const u32 until = blob.get_u32("ai builder downward path steer until");
	const bool holdActive = until > now;
	if (until <= now && blob.get_u8("ai builder obstruction threshold") < AIB_DOWNWARD_PATH_STEER_OBSTRUCTION_TICKS)
		return false;

	const s32 previousDirection = blob.get_s32("ai builder downward path steer direction");
	const s32 direction = AIB_SelectDownwardPathSteerDirection(pos, next, destination,
		previousDirection, holdActive);
	const bool right = direction > 0;
	// The active low-level node owns a diagonal descent's horizontal sign. The
	// final destination may already lie beyond the shaft in the opposite
	// direction; following it here walks away from the lip and fights BrainPath.
	// Direct walk-off owns the keys only while the adjacent side is open.
	// Gloryhill can pair a nominal down node with a nearby two-high stone wall;
	// once the runner actually reaches that wall, release direct ownership so
	// BrainPath's jump scaling can take over. Looking farther ahead rejects the
	// valid run-up and strands the worker before the recovery can engage.
	const f32 sideProbeX = (blob.getRadius() + map.tilesize) * (right ? 1.0f : -1.0f);
	const f32 upperProbeY = -blob.getRadius() * 0.5f;
	const f32 lowerProbeY = blob.getRadius() * 0.5f;
	const bool sideBlocked = map.isTileSolid(pos + Vec2f(sideProbeX, upperProbeY)) ||
		map.isTileSolid(pos + Vec2f(sideProbeX, lowerProbeY));
	// A two-tile shaft legitimately has a wall at the far probe. Preserve the
	// walk-off when the adjacent column fits the runner and remains open one tile
	// below; the Gloryhill wall false-positive has bedrock at that lower sample.
	const f32 nearProbeX = (blob.getRadius() + map.tilesize * 0.25f) * (right ? 1.0f : -1.0f);
	const f32 dropProbeY = blob.getRadius() + map.tilesize * 0.75f;
	const bool adjacentDropOpen = !map.isTileSolid(pos + Vec2f(nearProbeX, upperProbeY)) &&
		!map.isTileSolid(pos + Vec2f(nearProbeX, lowerProbeY)) &&
		!map.isTileSolid(pos + Vec2f(nearProbeX, dropProbeY));
	const bool narrowDrop = sideBlocked && adjacentDropOpen;
	if (sideBlocked && !narrowDrop)
	{
		if (blob.get_bool("ai builder downward path steering"))
		{
			AIB_LogEvent("ai", "path_downward_release", AIB_EventBlobRef(blob),
				"reason=blocked_side pos=" + AIB_EventPos(pos) + " next=" + AIB_EventPos(next) +
				" destination=" + AIB_EventPos(destination) + " direction=" + (right ? "right" : "left"));
		}
		return false;
	}

	blob.setKeyPressed(key_left, !right);
	blob.setKeyPressed(key_right, right);
	blob.setKeyPressed(key_up, false);
	blob.setKeyPressed(key_down, false);
	if (until <= now)
	{
		blob.set_u32("ai builder downward path steer until", now + AIB_DOWNWARD_PATH_STEER_HOLD_TICKS);
		blob.set_s32("ai builder downward path steer direction", direction);
	}
	if (!blob.get_bool("ai builder downward path steering") || direction != previousDirection)
	{
		AIB_LogEvent("ai", "path_downward_steer", AIB_EventBlobRef(blob),
			"pos=" + AIB_EventPos(pos) + " next=" + AIB_EventPos(next) +
			" destination=" + AIB_EventPos(destination) + " direction=" + (right ? "right" : "left") +
			" narrow_drop=" + AIB_BoolString(narrowDrop));
	}
	blob.set_bool("ai builder downward path steering", true);
	return true;
}

BrainPath@ AIB_GetBrainPath(CBlob@ blob)
{
	BrainPath@ path;
	if (blob.get("ai builder brain path", @path) && path !is null)
	{
		return path;
	}

	@path = BrainPath(blob, Path::ALL);
	blob.set("ai builder brain path", @path);
	return path;
}

void AIB_EndBrainPath(CBlob@ blob)
{
	if (blob is null) return;

	BrainPath@ path;
	if (blob.get("ai builder brain path", @path) && path !is null)
	{
		path.EndPath();
	}
}

Vec2f AIB_GetMineablePathBlock(CBlob@ blob, BrainPath@ path)
{
	CMap@ map = getMap();
	if (map is null || path is null) return Vec2f_zero;

	Vec2f pos = blob.getPosition();
	Vec2f next = Vec2f_zero;
	if (path.path.length > 0)
	{
		next = path.path[0];
	}
	else if (path.waypoints.length > 0)
	{
		next = path.waypoints[0];
	}
	if (next == Vec2f_zero) return Vec2f_zero;

	Vec2f col;
	if (map.rayCastSolid(pos, next, col))
	{
		Vec2f hit = map.getTileWorldPosition(map.getTileSpacePosition(col));
		if (AIB_IsMineableStonePathTile(hit)) return hit;
	}

	Vec2f nextTile = map.getTileWorldPosition(map.getTileSpacePosition(next));
	if (AIB_IsMineableStonePathTile(nextTile)) return nextTile;
	if (AIB_IsMineableStonePathTile(nextTile - Vec2f(0.0f, map.tilesize))) return nextTile - Vec2f(0.0f, map.tilesize);

	return Vec2f_zero;
}

void AIB_GoToFallback(CBrain@ brain, CBlob@ blob, Vec2f destination)
{
	CMap@ map = getMap();
	Vec2f pos = blob.getPosition();
	Vec2f last = blob.get_Vec2f("ai builder destination");
	const f32 distance = (destination - pos).Length();
	const bool movedDestination = last == Vec2f_zero || (last - destination).Length() > 24.0f;

	if (movedDestination)
	{
		AIB_Repath(brain, blob, destination);
		blob.set_Vec2f("ai builder destination", destination);
	}

	const bool allowDirectShortcut = AIB_CanUseDirectShortcut(blob, destination);
	bool justGo = blob.get_bool("ai builder justgo");
	if (distance < 160.0f && allowDirectShortcut)
	{
		Vec2f col;
		if (!map.rayCastSolid(pos, destination, col))
		{
			justGo = true;
		}
	}
	else if (justGo && !allowDirectShortcut)
	{
		justGo = false;
		blob.set_bool("ai builder justgo", false);
		AIB_LogEvent("ai", "path_direct_suppressed", AIB_EventBlobRef(blob), "reason=uphill_detour destination=" + AIB_EventPos(destination));
	}

	AIB_DetectObstructions(brain, blob, destination);

	if (justGo)
	{
		AIB_PathTo(blob, destination);
		if (distance < 48.0f || XORRandom(80) == 0)
		{
			blob.set_bool("ai builder justgo", false);
		}
	}
	else
	{
		switch (brain.getState())
		{
			case CBrain::has_path:
				if (brain.getPathSize() > 0 && (pos - brain.getPathPositionAtIndex(brain.getPathSize() - 1)).Length() > 10.0f)
				{
					brain.SetSuggestedKeys();
				}
				else
				{
					AIB_TrySomethingNew(brain, blob, destination);
				}
				break;

			case CBrain::idle:
			case CBrain::stuck:
			case CBrain::wrong_path:
				AIB_TrySomethingNew(brain, blob, destination);
				break;

			default:
				AIB_PathTo(blob, destination);
				break;
		}
	}

	AIB_ScaleObstacles(blob, destination);
	blob.setAimPos(destination);
}

void AIB_Repath(CBrain@ brain, CBlob@ blob, Vec2f destination)
{
	AIBG_RecordRepath(blob);
	brain.SetPathTo(destination, false);
	blob.set_bool("ai builder justgo", false);
}

void AIB_TrySomethingNew(CBrain@ brain, CBlob@ blob, Vec2f destination)
{
	if (AIB_CanUseDirectShortcut(blob, destination) && XORRandom(2) == 0)
	{
		blob.set_bool("ai builder justgo", true);
		brain.EndPath();
		AIB_PathTo(blob, destination);
	}
	else
	{
		AIB_Repath(brain, blob, destination);
	}
}

bool AIB_CanUseDirectShortcut(CBlob@ blob, Vec2f destination)
{
	if (blob is null) return false;
	if (blob.isOnLadder() || blob.isOnWall() || blob.isInWater()) return true;

	Vec2f pos = blob.getPosition();
	const f32 verticalRise = pos.y - destination.y;
	if (verticalRise <= 18.0f) return true;

	CMap@ map = getMap();
	if (map is null) return false;

	Vec2f col;
	const bool clearDirectRay = !map.rayCastSolid(pos, destination, col);
	if (!clearDirectRay) return false;

	// Close uphill targets can still require moving away from the target first.
	// In that case direct key movement repeatedly jumps at the slope; let CBrain
	// follow the path nodes instead.
	return false;
}

// A builder can jump under a one-tile overhang and remain pinned between the
// underside and the block's vertical face.  Repathing and obstacle scaling both
// keep pressing up in that geometry, so neither can lower the builder enough to
// move away.  After confirmed immobility, briefly suppress jumping and walk
// away from the overhang.  The recovery is gated by the exact asymmetric
// one-block geometry plus either blocked uphill intent or confirmed immobility,
// so it is safe for harvesting, delivery, construction, and mining travel.
bool AIB_TryRecoverStoneCorner(CBrain@ brain, CBlob@ blob, const u8 state)
{
	if (brain is null || blob is null || state == AIBuilderState::idle) return false;

	const u32 now = getGameTime();
	const u32 until = blob.get_u32("ai builder stone corner escape until");
	if (until > now)
	{
		AIB_DriveStoneCornerEscape(blob);
		return true;
	}
	if (until != 0)
	{
		blob.set_u32("ai builder stone corner escape until", 0);
		blob.set_u32("ai builder stone corner escape cooldown", now + AIB_STONE_CORNER_ESCAPE_COOLDOWN);
		blob.set_s32("ai builder stone corner escape direction", 0);
	}

	if (now < blob.get_u32("ai builder stone corner escape cooldown")) return false;
	const s32 direction = AIB_GetStoneCornerEscapeDirection(blob);
	if (direction == 0) return false;
	const bool pressingIntoCorner = AIB_IsStoneCornerIntentBlocked(blob, direction);
	if (!pressingIntoCorner &&
		blob.get_u8("ai builder obstruction threshold") < AIB_STONE_CORNER_OBSTRUCTION_THRESHOLD) return false;

	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_bool("ai builder justgo", false);
	blob.set_u8("ai builder obstruction threshold", 0);
	blob.set_s32("ai builder stone corner escape direction", direction);
	blob.set_u32("ai builder stone corner escape until", now + AIB_STONE_CORNER_ESCAPE_TICKS);
	AIB_LogEvent("ai", "corner_escape", AIB_EventBlobRef(blob), "direction=" + direction + " state=" + AIB_StateName(state) + " pos=" + AIB_EventPos(blob.getPosition()));
	AIB_DriveStoneCornerEscape(blob);
	return true;
}

s32 AIB_GetStoneCornerEscapeDirection(CBlob@ blob)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return 0;

	// KAG's legacy Vec2f operators do not accept const Vec2f operands.
	Vec2f pos = blob.getPosition();
	const f32 sample = blob.getRadius() + 2.0f;
	// Sample tile centers across the three cells that form the trap: the ceiling,
	// its upper diagonal, and the open body-height escape side.  The previous
	// edge samples could both land in the ceiling tile while the runner bobbed,
	// making a genuinely asymmetric corner look symmetric.
	const bool ceiling = map.isTileSolid(pos + Vec2f(0.0f, -sample));
	const bool upperLeft = map.isTileSolid(pos + Vec2f(-sample, -sample));
	const bool lowerLeft = map.isTileSolid(pos + Vec2f(-sample, 0.0f));
	const bool upperRight = map.isTileSolid(pos + Vec2f(sample, -sample));
	const bool lowerRight = map.isTileSolid(pos + Vec2f(sample, 0.0f));
	// The official Gloryhill route also exposes a diagonal-only variant: the
	// runner's head catches one upper diagonal even though the sample directly
	// overhead is empty.  Accept that shape only when the opposite upper sample
	// is open, preserving the same asymmetric one-sided gate as the ceiling
	// variant and rejecting tunnels with solid headroom on both sides.
	const bool leftOverhang = upperLeft && !lowerLeft && (ceiling || !upperRight);
	const bool rightOverhang = upperRight && !lowerRight && (ceiling || !upperLeft);

	if (leftOverhang == rightOverhang) return 0;
	return leftOverhang ? 1 : -1;
}

bool AIB_IsStoneCornerIntentBlocked(CBlob@ blob, const s32 escapeDirection)
{
	CMap@ map = getMap();
	if (blob is null || map is null || escapeDirection == 0) return false;

	Vec2f intent = blob.get_Vec2f("ai builder destination");
	if (intent == Vec2f_zero || (intent - blob.getPosition()).Length() < map.tilesize)
	{
		intent = blob.get_Vec2f("ai builder tile target");
	}
	if (intent == Vec2f_zero) return false;

	Vec2f pos = blob.getPosition();
	const bool uphill = intent.y < pos.y - map.tilesize * 0.5f;
	const bool towardBlockedLeft = escapeDirection > 0 && intent.x < pos.x - map.tilesize * 0.5f;
	const bool towardBlockedRight = escapeDirection < 0 && intent.x > pos.x + map.tilesize * 0.5f;
	return uphill && (towardBlockedLeft || towardBlockedRight);
}

void AIB_DriveStoneCornerEscape(CBlob@ blob)
{
	if (blob is null) return;

	const s32 direction = blob.get_s32("ai builder stone corner escape direction");
	blob.setKeyPressed(key_up, false);
	blob.setKeyPressed(key_action2, false);
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	if (direction < 0) blob.setKeyPressed(key_left, true);
	else if (direction > 0) blob.setKeyPressed(key_right, true);
}

void AIB_DetectObstructions(CBrain@ brain, CBlob@ blob, Vec2f destination)
{
	u8 threshold = blob.get_u8("ai builder obstruction threshold");
	const bool obstructed = (blob.getPosition() - blob.getOldPosition()).Length() < 2.5f;
	const bool dedicatedStoneRoute = AIB_UsesDedicatedStoneRouteMovement(blob.get_u8("ai builder job"), blob.get_u8("ai builder state"));

	if (obstructed)
	{
		threshold++;
	}
	else if (threshold > 0)
	{
		threshold--;
	}

	if (threshold > 20)
	{
		threshold = 0;
		if (dedicatedStoneRoute)
		{
			brain.EndPath();
			AIB_EndBrainPath(blob);
			blob.set_Vec2f("ai builder destination", Vec2f_zero);
			blob.set_bool("ai builder justgo", false);
			blob.setKeyPressed(key_up, false);
		}
		else
		{
			AIB_TrySomethingNew(brain, blob, destination);
			blob.setKeyPressed(key_up, true);
		}
	}

	blob.set_u8("ai builder obstruction threshold", threshold);
}

void AIB_DetectBrainPathObstructions(CBlob@ blob, BrainPath@ path, Vec2f destination, Vec2f next)
{
	if (blob is null || path is null) return;

	u8 threshold = blob.get_u8("ai builder obstruction threshold");
	const bool obstructed = (blob.getPosition() - blob.getOldPosition()).Length() < 2.5f;
	const bool uphill = AIB_IsUphillPathTarget(blob, next);
	const bool dedicatedStoneRoute = AIB_UsesDedicatedStoneRouteMovement(blob.get_u8("ai builder job"), blob.get_u8("ai builder state"));
	AIB_UpdateJumpPeak(blob, uphill && obstructed);

	if (obstructed)
	{
		threshold++;
	}
	else if (threshold > 0)
	{
		threshold--;
	}

	if (threshold > 20)
	{
		const bool placedLadder = !dedicatedStoneRoute && AIB_TryPlaceRecoveryLadder(blob, next);
		threshold = 0;
		path.EndPath();
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		blob.set_bool("ai builder justgo", false);
		blob.setKeyPressed(key_up, !dedicatedStoneRoute);
		AIB_LogEvent("ai", "path_replan", AIB_EventBlobRef(blob), "reason=" +
			(dedicatedStoneRoute ? "stone_route_obstruction" : (placedLadder ? "ladder_recovery" : "obstruction")) +
			" destination=" + AIB_EventPos(destination) + " next=" + AIB_EventPos(next) +
			" low=" + path.path.length + " waypoints=" + path.waypoints.length);
	}

	blob.set_u8("ai builder obstruction threshold", threshold);
}

bool AIB_IsUphillPathTarget(CBlob@ blob, Vec2f next)
{
	if (blob is null || next == Vec2f_zero) return false;
	return next.y < blob.getPosition().y - 12.0f;
}

void AIB_UpdateJumpPeak(CBlob@ blob, const bool tracking)
{
	if (blob is null) return;

	if (!tracking)
	{
		blob.set_Vec2f("ai builder jump peak", Vec2f_zero);
		return;
	}

	Vec2f pos = blob.getPosition();
	Vec2f peak = blob.get_Vec2f("ai builder jump peak");
	if (peak == Vec2f_zero || pos.y < peak.y)
	{
		blob.set_Vec2f("ai builder jump peak", pos);
	}
}

bool AIB_TryPlaceRecoveryLadder(CBlob@ blob, Vec2f next)
{
	if (blob is null || !AIB_IsUphillPathTarget(blob, next)) return false;
	if (blob.get_u8("ai builder obstruction threshold") < AIB_LADDER_OBSTRUCTION_THRESHOLD) return false;
	if (getGameTime() < blob.get_u32("ai builder next ladder")) return false;
	Vec2f peak = blob.get_Vec2f("ai builder jump peak");
	if (peak == Vec2f_zero) peak = blob.getPosition();

	CMap@ map = getMap();
	if (map is null) return false;

	Vec2f tile = map.getTileWorldPosition(map.getTileSpacePosition(peak));
	if (!AIB_CanPlaceRecoveryLadderAt(blob, tile)) return false;

	const bool needsBackwall = AIB_RecoveryLadderNeedsBackwall(tile);
	Vec2f[] backwallChain;
	if (needsBackwall && !AIB_GetRecoveryBackwallChain(blob, tile, backwallChain)) return false;
	// Recovery support is a distinct, paid phase. Creating the ladder before
	// these writes let the fixture observe an unsupported ladder and gave KAG's
	// path cache no simulation boundary in which to recognize the new backwall.
	if (needsBackwall)
	{
		AIB_PrepareRecoveryLadderSupport(blob, tile, backwallChain);
		return false;
	}

	const bool supportReadyBeforeSpawn = map.hasSupportAtPos(AIB_TileCenter(tile));
	if (!supportReadyBeforeSpawn || AIB_CountWood(blob) < AIB_LADDER_WOOD_COST) return false;
	CBlob@ ladder = server_CreateBlob("ladder", blob.getTeamNum(), AIB_TileCenter(tile));
	if (ladder is null) return false;
	if (!AIB_TakeMaterial(blob, "mat_wood", AIB_LADDER_WOOD_COST))
	{
		ladder.server_Die();
		return false;
	}

	const u32 now = getGameTime();
	Vec2f preparedTarget = blob.get_Vec2f(AIB_RECOVERY_SUPPORT_TARGET_KEY);
	const u32 preparedTick = blob.get_u32(AIB_RECOVERY_SUPPORT_TICK_KEY);
	const u8 preparedChain = blob.get_u8(AIB_RECOVERY_SUPPORT_CHAIN_KEY);
	const bool preparedHere = preparedTarget != Vec2f_zero && preparedTick > 0 && preparedChain > 0 &&
		(preparedTarget - tile).Length() < 0.1f;
	// A staged chain can make the adjacent next rung supported before the
	// runner's next obstruction cycle. Preserve that causal evidence when the
	// last paid chain ended one tile away and is still within two normal ladder
	// placement windows; exact-target support remains valid without that age cap.
	const bool preparedNearby = !preparedHere && preparedTarget != Vec2f_zero &&
		preparedTick > 0 && preparedTick < now && preparedChain > 0 &&
		now - preparedTick <= AIB_LADDER_PLACE_DELAY * 2 &&
		(preparedTarget - tile).Length() <= map.tilesize * 1.5f;
	const bool preparedForLadder = preparedHere || preparedNearby;
	const u32 supportTick = preparedForLadder ? preparedTick : 0;
	const u8 supportChain = preparedForLadder ? preparedChain : 0;
	ladder.Tag("aibuilder recovery ladder");
	ladder.set_bool("aibuilder recovery support ready before spawn", supportReadyBeforeSpawn);
	ladder.set_bool("aibuilder recovery support inherited adjacent", preparedNearby);
	ladder.set_Vec2f("aibuilder recovery support target", preparedForLadder ? preparedTarget : Vec2f_zero);
	ladder.set_u32("aibuilder recovery support tick", supportTick);
	ladder.set_u8("aibuilder recovery support chain", supportChain);
	ladder.set_u32("aibuilder recovery ladder tick", now);
	ladder.setAngleDegrees(AIB_LADDER_HORIZONTAL_ANGLE);
	ladder.getShape().SetStatic(true);
	ladder.getShape().SetGravityScale(0.0f);
	blob.set_u32("ai builder next ladder", now + AIB_LADDER_PLACE_DELAY);
	blob.set_Vec2f("ai builder jump peak", Vec2f_zero);
	blob.set_bool(AIB_RECOVERY_PROBE_PENDING_KEY, true);
	blob.set_netid(AIB_RECOVERY_PROBE_LADDER_KEY, ladder.getNetworkID());
	blob.set_u32(AIB_RECOVERY_LADDER_TICK_KEY, now);
	AIB_LogEvent("ai", "place_ladder", AIB_EventBlobRef(blob), "tile=" + AIB_EventPos(tile) +
		" next=" + AIB_EventPos(next) + " angle=90 support_before_spawn=true prepared_tick=" + supportTick +
		" chain=" + supportChain + " support_target=" +
		AIB_EventPos(preparedForLadder ? preparedTarget : Vec2f_zero) +
		" inherited_adjacent=" + AIB_BoolString(preparedNearby));
	return true;
}

bool AIB_PrepareRecoveryLadderSupport(CBlob@ blob, Vec2f tile, Vec2f[] &in backwallChain)
{
	CMap@ map = getMap();
	if (blob is null || map is null || backwallChain.length == 0) return false;

	Vec2f[] missing;
	for (uint i = 0; i < backwallChain.length; i++)
	{
		const TileType type = map.getTile(backwallChain[i]).type;
		if (!AIB_IsSupportBackwall(type)) missing.push_back(backwallChain[i]);
	}
	// Tile support/cache updates may lag a same-tick server_SetTile. If every
	// chain cell already exists, wait for a later obstruction cycle instead of
	// charging for or rewriting the same backwalls again.
	if (missing.length == 0) return false;

	const u16 supportCost = missing.length * AIB_LADDER_BACKWALL_WOOD_COST;
	if (AIB_CountWood(blob) < AIB_LADDER_WOOD_COST + supportCost ||
		!AIB_TakeMaterial(blob, "mat_wood", supportCost)) return false;
	for (uint i = 0; i < missing.length; i++) map.server_SetTile(missing[i], CMap::tile_wood_back);

	blob.set_Vec2f(AIB_RECOVERY_SUPPORT_TARGET_KEY, tile);
	blob.set_u32(AIB_RECOVERY_SUPPORT_TICK_KEY, getGameTime());
	blob.set_u8(AIB_RECOVERY_SUPPORT_CHAIN_KEY, u8(Maths::Min(backwallChain.length, uint(255))));
	AIB_LogEvent("ai", "place_ladder_support", AIB_EventBlobRef(blob), "tile=" + AIB_EventPos(tile) +
		" chain=" + backwallChain.length + " new=" + missing.length + " support_cost=" + supportCost);
	return true;
}

void AIB_RecordRecoveryPathProbe(CBlob@ blob, BrainPath@ path, Vec2f destination)
{
	if (blob is null || path is null || !blob.get_bool(AIB_RECOVERY_PROBE_PENDING_KEY) ||
		getGameTime() <= blob.get_u32(AIB_RECOVERY_LADDER_TICK_KEY)) return;

	CBlob@ ladder = getBlobByNetworkID(blob.get_netid(AIB_RECOVERY_PROBE_LADDER_KEY));
	if (ladder is null || ladder.hasTag("dead"))
	{
		blob.set_bool(AIB_RECOVERY_PROBE_PENDING_KEY, false);
		blob.set_netid(AIB_RECOVERY_PROBE_LADDER_KEY, 0);
		return;
	}

	Vec2f next = Vec2f_zero;
	if (path.path.length > 0) next = path.path[0];
	else if (path.waypoints.length > 0) next = path.waypoints[0];
	const Vec2f mineable = AIB_GetMineablePathBlock(blob, path);
	Vec2f collision;
	CMap@ map = getMap();
	const bool nextBlocked = map !is null && next != Vec2f_zero && map.rayCastSolid(blob.getPosition(), next, collision);
	// This is deliberately only the pathfinder's acceptance signal. The focused
	// fixture separately requires real traversal, because a non-empty path alone
	// is not evidence that movement can follow it.
	const bool accepted = path.isPathing() && next != Vec2f_zero;

	ladder.set_bool("aibuilder recovery post path probe", true);
	ladder.set_bool("aibuilder recovery post path accepted", accepted);
	ladder.set_bool("aibuilder recovery post next blocked", nextBlocked);
	ladder.set_u16("aibuilder recovery post low nodes", u16(Maths::Min(path.path.length, uint(65535))));
	ladder.set_u16("aibuilder recovery post waypoints", u16(Maths::Min(path.waypoints.length, uint(65535))));
	ladder.set_Vec2f("aibuilder recovery post next", next);
	ladder.set_Vec2f("aibuilder recovery post mineable", mineable);
	ladder.set_u32("aibuilder recovery post probe tick", getGameTime());
	AIB_LogEvent("ai", "ladder_path_probe", AIB_EventBlobRef(blob), "ladder=" + AIB_EventBlobRef(ladder) +
		" destination=" + AIB_EventPos(destination) + " pathing=" + AIB_BoolString(path.isPathing()) +
		" low=" + path.path.length + " waypoints=" + path.waypoints.length + " next=" + AIB_EventPos(next) +
		" next_blocked=" + AIB_BoolString(nextBlocked) + " mineable=" + AIB_EventPos(mineable) +
		" accepted=" + AIB_BoolString(accepted));
	blob.set_bool(AIB_RECOVERY_PROBE_PENDING_KEY, false);
	blob.set_netid(AIB_RECOVERY_PROBE_LADDER_KEY, 0);
}

bool AIB_CanPlaceRecoveryLadderAt(CBlob@ blob, Vec2f tile)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return false;
	if (!AIB_IsInsideMap(tile)) return false;
	if (!AIB_IsInsideCurrentBarrierZoneAt(tile)) return false;
	if (!AIB_IsSafePosition(AIB_TileCenter(tile), blob.getTeamNum())) return false;
	if (map.isTileSolid(tile)) return false;
	if (AIB_RecoveryLadderNeedsBackwall(tile))
	{
		Vec2f[] backwallChain;
		if (!AIB_GetRecoveryBackwallChain(blob, tile, backwallChain)) return false;
	}
	if ((AIB_TileCenter(tile) - blob.getPosition()).Length() > 40.0f) return false;

	CBlob@[] blobs;
	if (map.getBlobsInRadius(AIB_TileCenter(tile), 6.0f, @blobs))
	{
		for (uint i = 0; i < blobs.length; i++)
		{
			CBlob@ other = blobs[i];
			if (other !is null && other.getName() == "ladder" && !other.hasTag("dead"))
			{
				return false;
			}
		}
	}

	return true;
}

bool AIB_RecoveryLadderNeedsBackwall(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;
	return !map.hasSupportAtPos(AIB_TileCenter(tile));
}

bool AIB_CanPlaceRecoveryLadderBackwallAt(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;

	const TileType type = map.getTile(tile).type;
	if (type == CMap::tile_empty || type == CMap::tile_ground_back || AIB_IsSupportBackwall(type)) return true;
	if (map.isTileGrass(type)) return true;
	return !map.isTileSolid(type);
}

bool AIB_GetRecoveryBackwallChain(CBlob@ blob, Vec2f targetTile, Vec2f[] &out chain)
{
	chain.clear();

	CMap@ map = getMap();
	if (blob is null || map is null) return false;
	if (!AIB_CanPlaceRecoveryLadderBackwallAt(targetTile)) return false;

	Vec2f[] nodes;
	s32[] parents;
	nodes.push_back(targetTile);
	parents.push_back(-1);

	for (uint i = 0; i < nodes.length && i < 96; i++)
	{
		Vec2f current = nodes[i];
		if (AIB_HasAdjacentRecoveryBackwallSupport(current))
		{
			AIB_BuildRecoveryBackwallChain(nodes, parents, i, chain);
			return chain.length > 0;
		}

		if (AIB_TileDistance(targetTile, current) >= AIB_LADDER_BACKWALL_MAX_CHAIN) continue;

		const f32 ts = map.tilesize;
		Vec2f[] nextTiles = {
			current + Vec2f(ts, 0.0f),
			current + Vec2f(-ts, 0.0f),
			current + Vec2f(0.0f, ts),
			current + Vec2f(0.0f, -ts)
		};

		for (uint j = 0; j < nextTiles.length; j++)
		{
			Vec2f next = map.getTileWorldPosition(map.getTileSpacePosition(nextTiles[j]));
			if (AIB_FindTileIndex(nodes, next) >= 0) continue;
			if (!AIB_CanPlaceRecoveryLadderBackwallAt(next)) continue;
			if (!AIB_IsInsideMap(next)) continue;
			if (!AIB_IsInsideCurrentBarrierZoneAt(next)) continue;
			if (!AIB_IsSafePosition(AIB_TileCenter(next), blob.getTeamNum())) continue;

			nodes.push_back(next);
			parents.push_back(i);
		}
	}

	return false;
}

bool AIB_HasAdjacentRecoveryBackwallSupport(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;

	const f32 ts = map.tilesize;
	return AIB_TileProvidesRecoveryBackwallSupport(tile + Vec2f(ts, 0.0f)) ||
		AIB_TileProvidesRecoveryBackwallSupport(tile + Vec2f(-ts, 0.0f)) ||
		AIB_TileProvidesRecoveryBackwallSupport(tile + Vec2f(0.0f, ts)) ||
		AIB_TileProvidesRecoveryBackwallSupport(tile + Vec2f(0.0f, -ts));
}

bool AIB_TileProvidesRecoveryBackwallSupport(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;

	const TileType type = map.getTile(tile).type;
	if (type == CMap::tile_empty || type == CMap::tile_ground_back) return false;
	return map.isTileSolid(type) || AIB_IsSupportBackwall(type);
}

void AIB_BuildRecoveryBackwallChain(Vec2f[] &in nodes, s32[] &in parents, const uint endIndex, Vec2f[] &out chain)
{
	chain.clear();

	Vec2f[] reverse;
	s32 index = endIndex;
	while (index >= 0 && uint(index) < nodes.length)
	{
		reverse.push_back(nodes[index]);
		index = parents[index];
	}

	for (int i = int(reverse.length) - 1; i >= 0; i--)
	{
		chain.push_back(reverse[i]);
	}
}

s32 AIB_FindTileIndex(Vec2f[] &in tiles, Vec2f tile)
{
	for (uint i = 0; i < tiles.length; i++)
	{
		if ((tiles[i] - tile).Length() < 0.1f) return i;
	}
	return -1;
}

u8 AIB_TileDistance(Vec2f a, Vec2f b)
{
	CMap@ map = getMap();
	const f32 ts = map is null ? 8.0f : map.tilesize;
	return u8(Maths::Abs(a.x - b.x) / ts + Maths::Abs(a.y - b.y) / ts);
}

void AIB_PathTo(CBlob@ blob, Vec2f destination)
{
	Vec2f pos = blob.getPosition();
	if (Maths::Abs(destination.x - pos.x) > blob.getRadius() * 0.75f)
	{
		blob.setKeyPressed(destination.x < pos.x ? key_left : key_right, true);
	}
	if (destination.y + getMap().tilesize < pos.y)
	{
		blob.setKeyPressed(key_up, true);
	}
}

void AIB_ScaleObstacles(CBlob@ blob, Vec2f destination)
{
	CMap@ map = getMap();
	Vec2f pos = blob.getPosition();
	const f32 radius = blob.getRadius();
	const bool dedicatedStoneRoute = AIB_UsesDedicatedStoneRouteMovement(
		blob.get_u8("ai builder job"), blob.get_u8("ai builder state"));
	const bool exposedStonePath = blob.get_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY) != Vec2f_zero;

	if (blob.isOnLadder() || blob.isInWater())
	{
		blob.setKeyPressed(destination.y < pos.y ? key_up : key_down, true);
	}
	else if (dedicatedStoneRoute && !exposedStonePath)
	{
		// Shaft/tunnel movement explicitly centers, descends, climbs, and mines
		// exact route tiles. Generic obstacle scaling fights that controller by
		// repeatedly injecting jumps whenever horizontal speed is low.
		return;
	}
	if (blob.isOnWall() ||
		(blob.isKeyPressed(key_right) && (map.isTileSolid(pos + Vec2f(1.3f * radius, radius)) || blob.getShape().vellen < 0.1f)) ||
		(blob.isKeyPressed(key_left) && (map.isTileSolid(pos + Vec2f(-1.3f * radius, radius)) || blob.getShape().vellen < 0.1f)))
	{
		blob.setKeyPressed(key_up, true);
	}
}

Vec2f AIB_GetBestStoneTile(CBlob@ blob)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	Vec2f selected = AIB_GetBestSelectedStoneTile(blob);
	if (selected != Vec2f_zero)
	{
		return selected;
	}

	Vec2f builderPos = blob.getPosition();
	const int originX = Maths::Floor(builderPos.x / map.tilesize);
	const int originY = Maths::Floor(builderPos.y / map.tilesize);

	Vec2f[] candidates;
	f32[] approximateScores;

	for (int dy = -AIB_STONE_SCAN_RADIUS; dy <= AIB_STONE_SCAN_RADIUS; dy++)
	{
		const int y = originY + dy;
		if (y < 2 || y >= map.tilemapheight - 2) continue;

		for (int dx = -AIB_STONE_SCAN_RADIUS; dx <= AIB_STONE_SCAN_RADIUS; dx++)
		{
			const int x = originX + dx;
			if (x < 2 || x >= map.tilemapwidth - 3) continue;

			Vec2f tilePos = Vec2f(x * map.tilesize, y * map.tilesize);
			if (!AIB_IsStoneTile(tilePos)) continue;
			if (AIB_IsRejectedMiningRouteTarget(blob, tilePos)) continue;
			if (!AIB_IsInsideCurrentBarrierZone(blob, AIB_TileCenter(tilePos))) continue;
			if (!AIB_IsSafeResource(blob, AIB_TileCenter(tilePos))) continue;

			Vec2f center = AIB_TileCenter(tilePos);
			const f32 builderDistance = (center - builderPos).Length();
			const f32 depthPenalty = Maths::Max(0.0f, tilePos.y - builderPos.y) * 0.05f;
			const f32 exposureBonus = AIB_CountOpenStoneSides(tilePos) * 28.0f;
			const f32 approximate = builderDistance + depthPenalty - exposureBonus;

			// Keep representatives from different local deposits.  Exact route
			// validation is intentionally deferred to this bounded shortlist so the
			// 161x161 scan does not run a shaft search for every stone tile.
			s32 nearby = -1;
			for (uint i = 0; i < candidates.length; i++)
			{
				if ((candidates[i] - tilePos).Length() <= AIB_STONE_ROUTE_CANDIDATE_SEPARATION * map.tilesize)
				{
					nearby = i;
					break;
				}
			}
			if (nearby >= 0)
			{
				if (approximate < approximateScores[nearby])
				{
					candidates[nearby] = tilePos;
					approximateScores[nearby] = approximate;
				}
				continue;
			}

			if (candidates.length < AIB_STONE_ROUTE_CANDIDATE_LIMIT)
			{
				candidates.push_back(tilePos);
				approximateScores.push_back(approximate);
				continue;
			}

			uint worst = 0;
			for (uint i = 1; i < approximateScores.length; i++)
			{
				if (approximateScores[i] > approximateScores[worst]) worst = i;
			}
			if (approximate < approximateScores[worst])
			{
				candidates[worst] = tilePos;
				approximateScores[worst] = approximate;
			}
		}
	}

	Vec2f best = Vec2f_zero;
	f32 bestScore = 99999999.0f;
	for (uint i = 0; i < candidates.length; i++)
	{
		Vec2f routeCorner = AIB_GetBestStoneRouteCorner(blob, candidates[i]);
		if (routeCorner == Vec2f_zero) continue;
		if (AIB_IsStoneRouteReservedByOther(blob, routeCorner)) continue;
		const u16 dirt = AIB_CountDirtOnStoneRoute(blob, candidates[i], routeCorner);
		const f32 score = approximateScores[i] + dirt * AIB_STONE_DIRT_PENALTY;
		if (score < bestScore)
		{
			bestScore = score;
			best = candidates[i];
		}
	}
	return best;
}

u8 AIB_CountOpenStoneSides(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return 0;

	u8 open = 0;
	const f32 ts = map.tilesize;
	if (!map.isTileSolid(tile + Vec2f(-ts, 0.0f))) open++;
	if (!map.isTileSolid(tile + Vec2f(ts, 0.0f))) open++;
	if (!map.isTileSolid(tile + Vec2f(0.0f, -ts))) open++;
	if (!map.isTileSolid(tile + Vec2f(0.0f, ts))) open++;
	return open;
}

Vec2f AIB_GetStoneRouteDestination(CBlob@ blob, Vec2f target)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero) return target;

	Vec2f corner = blob.get_Vec2f("ai builder stone route corner");
	if (corner == Vec2f_zero)
	{
		corner = AIB_GetBestStoneRouteCorner(blob, target);
		blob.set_Vec2f("ai builder stone route corner", corner);
		AIB_UpdateStoneReturnRoute(blob, target, corner);
	}
	if (corner == Vec2f_zero) return target;

	Vec2f pos = blob.getPosition();
	const int builderX = Maths::Floor(pos.x / map.tilesize);
	const int builderY = Maths::Floor(pos.y / map.tilesize);
	const int shaftX = Maths::Floor(corner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	const int entryX = AIB_GetStoneRouteEntryX(builderX, shaftX, targetX);

	// Reach the shaft mouth over existing terrain before digging. A full-width
	// runner is centered on the boundary between both planned shaft columns, so
	// either column is valid ownership after the surface approach.
	if (!AIB_IsStoneRouteShaftColumn(builderX, shaftX, targetX))
	{
		return Vec2f(entryX * map.tilesize, builderY * map.tilesize);
	}
	if (Maths::Abs(builderY - targetY) > 1)
	{
		return corner;
	}
	return target;
}

// BrainPath is useful for reaching the shaft mouth, but it oscillates between
// surface and underground nodes inside a simple open vertical shaft.  Once the
// builder occupies either planned shaft column, keep descent centered across
// the full opening and retain the wall alignment required for ascent. Clearance
// mining runs before this helper each tick, so only exact route tiles are dug.
bool AIB_DriveStoneRouteShaft(CBrain@ brain, CBlob@ blob, Vec2f target, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (brain is null || blob is null || map is null || target == Vec2f_zero || routeCorner == Vec2f_zero) return false;

	Vec2f pos = blob.getPosition();
	const int builderX = Maths::Floor(pos.x / map.tilesize);
	const int builderY = Maths::Floor(pos.y / map.tilesize);
	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);

	const int side = targetX < shaftX ? -1 : 1;
	const int entryX = AIB_GetStoneRouteEntryX(builderX, shaftX, targetX);
	const f32 entryCenterX = (entryX + 0.5f) * map.tilesize;
	const f32 shaftCenterX = AIB_GetStoneRouteShaftCenterX(shaftX, targetX, map.tilesize);
	const bool inShaftColumn = builderX == shaftX || builderX == shaftX + side;
	// Take over the final short, clear approach before BrainPath can settle just
	// outside the shaft column and repeatedly replan.  This only drives movement;
	// all clearance mining has already passed the exact-route checks above.
	const bool nearClearEntry = Maths::Abs(pos.x - shaftCenterX) <= map.tilesize * 2.0f &&
		AIB_HasClearStoneRouteApproach(blob, target, routeCorner);
	if (!inShaftColumn && !nearClearEntry) return false;

	const u32 now = getGameTime();
	Vec2f progressPos = blob.get_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY);
	u32 progressTick = blob.get_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY);
	const bool atHandoffBand = Maths::Abs(builderY - targetY) <= 1;
	const bool recordedHandoffBand = progressPos != Vec2f_zero &&
		Maths::Abs(Maths::Floor(progressPos.y / map.tilesize) - targetY) <= 1;
	if (progressPos == Vec2f_zero || progressTick == 0 ||
		(atHandoffBand && !recordedHandoffBand) ||
		AIB_HasAdvancedStoneShaftProgress(progressPos, pos, routeCorner, map.tilesize, 8.0f))
	{
		blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, pos);
		blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, now);
		blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
	}
	const u16 noProgressTicks = atHandoffBand ?
		AIB_STONE_SHAFT_HANDOFF_NO_PROGRESS_TICKS : AIB_STONE_SHAFT_NO_PROGRESS_TICKS;
	if (now - blob.get_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY) >= noProgressTicks)
	{
		AIB_LogEvent("ai", "stone_route_stall", AIB_EventBlobRef(blob),
			"reason=shaft_no_progress target=" + AIB_EventPos(target) +
			" route_corner=" + AIB_EventPos(routeCorner) +
			" phase=" + (atHandoffBand ? "handoff" : "shaft") +
			" supported_cross=" + (AIB_HasSupportedStoneCrossTunnel(target, routeCorner) ? "true" : "false") +
			" elapsed=" + (now - blob.get_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY)) +
			" threshold=" + noProgressTicks + " pos=" + AIB_EventPos(pos));
		AIB_AbortStoneRouteToSurface(brain, blob, target, "shaft_no_progress");
		return true;
	}

	// Observe the last vertical step before handing the target-row crossing back
	// to ordinary pathing. Previously this return ran first, so a miner bouncing
	// between the lip and the one-tile band never recorded its best elevation and
	// could replan forever. Once it travels away from the shaft, the ownership
	// gate above releases it without applying this vertical watchdog to a valid
	// horizontal cross-tunnel traversal.
	if (atHandoffBand) return false;

	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_bool("ai builder justgo", false);
	blob.set_u8("ai builder obstruction threshold", 0);
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	blob.setKeyPressed(key_up, false);
	blob.setKeyPressed(key_down, false);

	const bool descending = targetY > builderY;
	// Down on a grounded one-tile lip is crouch, not descent. Straddle the full
	// opening only while grounded; once gravity owns the fall, restore the proven
	// clearance-column alignment. This avoids steering every open-shaft fall into
	// the far wall while still releasing a real supporting lip. Ascending miners
	// keep the established wall-center alignment needed for KAG wall climbing.
	const f32 driveCenterX = descending && blob.isOnGround() ? shaftCenterX : entryCenterX;
	const bool centered = Maths::Abs(pos.x - driveCenterX) <= 1.0f;
	if (pos.x < driveCenterX - 1.0f) blob.setKeyPressed(key_right, true);
	else if (pos.x > driveCenterX + 1.0f) blob.setKeyPressed(key_left, true);

	if (descending)
	{
		if (centered) blob.setKeyPressed(key_down, true);
	}
	else
	{
		blob.setKeyPressed(key_up, true);
		AIB_ScaleObstacles(blob, Vec2f(entryCenterX, AIB_TileCenter(target).y));
	}

	if (!blob.get_bool("ai builder direct stone shaft"))
	{
		blob.set_bool("ai builder direct stone shaft", true);
		AIB_LogEvent("ai", "stone_route_direct", AIB_EventBlobRef(blob),
			"phase=" + (descending ? "descend" : "ascend") + " entry_x=" + entryX +
			" target=" + AIB_EventPos(target) + " pos=" + AIB_EventPos(pos));
	}
	return true;
}

void AIB_SetStoneReturnAnchor(CBlob@ blob, Vec2f target, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero || routeCorner == Vec2f_zero)
	{
		if (blob !is null)
		{
			blob.set_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY, Vec2f_zero);
			blob.set_Vec2f(AIBM_STONE_RETURN_CORNER_KEY, Vec2f_zero);
			blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, Vec2f_zero);
			blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, Vec2f_zero);
			blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, 0);
			blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
			blob.set_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY, false);
			blob.set_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY, false);
			blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, false);
			blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, 0);
			blob.set_bool(AIBM_STONE_RETURN_SURFACED_KEY, false);
		}
		return;
	}

	Vec2f pos = blob.getPosition();
	const int builderX = Maths::Floor(pos.x / map.tilesize);
	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int entryX = AIB_GetStoneRouteEntryX(builderX, shaftX, targetX);
	Vec2f measuredAnchor = Vec2f((entryX + 0.5f) * map.tilesize, pos.y);
	Vec2f anchor = AIB_SelectStoneReturnAnchor(measuredAnchor,
		blob.get_Vec2f(AIBM_STONE_SURFACE_MEMORY_KEY), map.tilesize);
	const bool reusedSurface = (anchor - measuredAnchor).Length() >= 1.0f;
	blob.set_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY, anchor);
	blob.set_Vec2f(AIBM_STONE_RETURN_CORNER_KEY, routeCorner);
	blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, pos);
	blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, getGameTime());
	blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, false);
	blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, 0);
	blob.set_bool(AIBM_STONE_RETURN_SURFACED_KEY, false);
	blob.set_bool("ai builder direct stone return", false);
	AIB_LogEvent("ai", "stone_return_anchor", AIB_EventBlobRef(blob),
		"anchor=" + AIB_EventPos(anchor) + " target=" + AIB_EventPos(target) +
		" route_corner=" + AIB_EventPos(routeCorner) +
		" measured_anchor=" + AIB_EventPos(measuredAnchor) +
		" reused_surface=" + (reusedSurface ? "true" : "false"));
}

void AIB_UpdateStoneReturnRoute(CBlob@ blob, Vec2f target, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero || routeCorner == Vec2f_zero) return;
	Vec2f previous = blob.get_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY);
	if (previous == Vec2f_zero)
	{
		AIB_SetStoneReturnAnchor(blob, target, routeCorner);
		return;
	}

	const int builderX = Maths::Floor(blob.getPosition().x / map.tilesize);
	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int entryX = AIB_GetStoneRouteEntryX(builderX, shaftX, targetX);
	// The initial entry is a measured surface connection. A route chosen while
	// already underground describes only the local ore leg and must not invent a
	// new surface shaft at that x. Retarget the canonical entry only while the
	// runner is still within the normal surface handoff band.
	const bool canRetargetSurfaceEntry = blob.getPosition().y <= previous.y + map.tilesize * 1.5f;
	Vec2f updated = canRetargetSurfaceEntry ?
		Vec2f((entryX + 0.5f) * map.tilesize, previous.y) : previous;
	Vec2f previousCorner = blob.get_Vec2f(AIBM_STONE_RETURN_CORNER_KEY);
	const bool anchorChanged = Maths::Abs(updated.x - previous.x) >= 1.0f;
	const bool cornerChanged = previousCorner == Vec2f_zero || (routeCorner - previousCorner).Length() >= 1.0f;
	if (!anchorChanged && !cornerChanged) return;

	// Nearby ore and visible gold can legitimately extend the current tunnel at
	// a new depth. Retain that last valid corner for the underground rejoin leg,
	// while preserving the episode's measured surface entry once below ground;
	// the mutable mining corner can legitimately become zero on a later target.
	blob.set_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY, updated);
	blob.set_Vec2f(AIBM_STONE_RETURN_CORNER_KEY, routeCorner);
	blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, Vec2f_zero);
	blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, blob.getPosition());
	blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, getGameTime());
	blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, false);
	blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, 0);
	blob.set_bool(AIBM_STONE_RETURN_SURFACED_KEY, false);
	blob.set_bool("ai builder direct stone return", false);
	AIB_LogEvent("ai", "stone_return_anchor_retarget", AIB_EventBlobRef(blob),
		"from=" + AIB_EventPos(previous) + " anchor=" + AIB_EventPos(updated) +
		" corner_from=" + AIB_EventPos(previousCorner) +
		" surface_entry_changed=" + (anchorChanged ? "true" : "false") +
		" target=" + AIB_EventPos(target) + " route_corner=" + AIB_EventPos(routeCorner));
}

string AIB_StoneReturnGeometry(CMap@ map, Vec2f pos)
{
	if (map is null) return "none";
	const int centerX = Maths::Floor(pos.x / map.tilesize);
	const int centerY = Maths::Floor(pos.y / map.tilesize);
	string geometry = "";
	for (int dy = -3; dy <= 3; dy++)
	{
		if (dy > -3) geometry += "/";
		for (int dx = -3; dx <= 3; dx++)
		{
			Vec2f sample = Vec2f((centerX + dx + 0.5f) * map.tilesize,
				(centerY + dy + 0.5f) * map.tilesize);
			geometry += (map.isTileSolid(sample) ? "1" : "0");
		}
	}
	return geometry;
}

u8 AIB_GetStoneReturnClimbWallMask(CBlob@ blob, Vec2f pos, Vec2f anchor)
{
	CMap@ map = getMap();
	if (blob is null || map is null || anchor == Vec2f_zero) return 0;
	const f32 leftWallX = AIB_GetStoneReturnOuterWallSampleX(anchor, map.tilesize, -1);
	const f32 rightWallX = AIB_GetStoneReturnOuterWallSampleX(anchor, map.tilesize, 1);
	const f32 wallY = blob.getRadius() * 0.5f;
	u8 mask = 0;
	if (map.isTileSolid(Vec2f(leftWallX, pos.y - wallY)) ||
		map.isTileSolid(Vec2f(leftWallX, pos.y + wallY))) mask |= 1;
	if (map.isTileSolid(Vec2f(rightWallX, pos.y - wallY)) ||
		map.isTileSolid(Vec2f(rightWallX, pos.y + wallY))) mask |= 2;
	return mask;
}

bool AIB_ObserveStoneReturnProgress(CBlob@ blob, CMap@ map, Vec2f anchor, Vec2f routeCorner)
{
	if (blob is null || map is null) return false;
	Vec2f pos = blob.getPosition();
	Vec2f progressPos = blob.get_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY);
	const u32 now = getGameTime();
	const bool cornerRejoined = blob.get_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY);
	if (progressPos == Vec2f_zero || AIB_HasAdvancedStoneReturnProgress(progressPos, pos,
		anchor, routeCorner, cornerRejoined, map.tilesize, AIB_STONE_RETURN_PROGRESS_PIXELS))
	{
		blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, pos);
		blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, now);
		blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
		return false;
	}

	const u32 progressTick = blob.get_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY);
	if (progressTick == 0 || now < progressTick + AIB_STONE_RETURN_STALL_TICKS ||
		blob.get_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY)) return false;
	blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, true);
	AIB_LogEvent("ai", "stone_return_stall", AIB_EventBlobRef(blob),
		"anchor=" + AIB_EventPos(anchor) + " corner=" + AIB_EventPos(routeCorner) +
		" pos=" + AIB_EventPos(pos) + " geometry=" + AIB_StoneReturnGeometry(map, pos));
	return true;
}

Vec2f AIB_FindStoneReturnEgress(CBlob@ blob, Vec2f anchor)
{
	CMap@ map = getMap();
	if (blob is null || map is null || anchor == Vec2f_zero) return Vec2f_zero;
	CBlob@ home = AIB_GetTeamHome(blob);
	const f32 ts = map.tilesize;
	const int anchorX = Maths::Floor(anchor.x / ts);
	const int anchorY = Maths::Floor(anchor.y / ts);
	const s32 preferred = home !is null && home.getPosition().x > anchor.x ? 1 : -1;
	array<s32> directions = { preferred, -preferred };
	array<s32> vertical = { 0, -1, 1, -2, 2 };
	for (uint side = 0; side < directions.length; side++)
	{
		for (s32 step = 1; step <= 4; step++)
		{
			const int x = anchorX + directions[side] * step;
			for (uint dy = 0; dy < vertical.length; dy++)
			{
				Vec2f candidate = Vec2f((x + 0.5f) * ts, (anchorY + vertical[dy] + 0.5f) * ts);
				if (!AIB_IsStoneReturnEgressElevation(candidate, anchor, ts)) continue;
				if (home !is null ? AIBR_IsGroundedStoragePoint(home, candidate) : AIBR_IsGroundedStoragePoint(candidate))
					return candidate;
			}
		}
	}
	return Vec2f_zero;
}

bool AIB_DriveStoneReturnEgress(CBrain@ brain, CBlob@ blob, Vec2f anchor, Vec2f egress)
{
	CMap@ map = getMap();
	if (brain is null || blob is null || map is null || egress == Vec2f_zero) return false;
	if (!AIB_IsStoneReturnEgressElevation(egress, anchor, map.tilesize) ||
		!AIBR_IsGroundedStoragePoint(egress))
	{
		blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, Vec2f_zero);
		return false;
	}

	Vec2f pos = blob.getPosition();
	if ((pos - egress).Length() <= map.tilesize * 1.25f && blob.isOnGround())
	{
		blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, Vec2f_zero);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		AIB_LogEvent("ai", "stone_return_exit", AIB_EventBlobRef(blob),
			"anchor=" + AIB_EventPos(anchor) + " egress=" + AIB_EventPos(egress) +
			" pos=" + AIB_EventPos(pos) + " surface_memory=" + AIB_EventPos(anchor));
		return false;
	}

	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", egress);
	blob.set_bool("ai builder justgo", false);
	blob.set_u8("ai builder obstruction threshold", 0);
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	blob.setKeyPressed(key_up, false);
	blob.setKeyPressed(key_down, false);
	if (egress.x < pos.x - 1.0f) blob.setKeyPressed(key_left, true);
	else if (egress.x > pos.x + 1.0f) blob.setKeyPressed(key_right, true);
	if (!blob.isOnGround() || pos.y > egress.y + 1.0f) blob.setKeyPressed(key_up, true);
	AIB_ScaleObstacles(blob, egress);
	return true;
}

void AIB_RearmStoneReturnFromShaftReentry(CBlob@ blob, CMap@ map, Vec2f anchor)
{
	if (blob is null || map is null || anchor == Vec2f_zero) return;
	// The re-entry predicate already proves that the worker fell back inside the
	// saved two-column shaft. Preserve that physical handoff: asking it to rejoin
	// the retained ore-corridor corner again can steer toward a stale corner above
	// the surface anchor and trap an already-in-shaft runner below the lip. Adopt
	// a wall only when the canonical outer-wall probes detect one, but do so at
	// the current depth because the stale corner is no longer a valid engage gate.
	const u8 wallMask = AIB_GetStoneReturnClimbWallMask(blob, blob.getPosition(), anchor);
	const s32 climbDirection = AIB_SelectStoneReturnClimbDirection(wallMask, 0);
	blob.set_bool(AIBM_STONE_RETURN_SURFACED_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY, false);
	blob.set_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY, true);
	blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, climbDirection != 0);
	blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, climbDirection);
	blob.set_bool("ai builder direct stone return", false);
	blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, blob.getPosition());
	blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, getGameTime());
	blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
}

bool AIB_TryReturnThroughStoneRoute(CBrain@ brain, CBlob@ blob)
{
	CMap@ map = getMap();
	if (brain is null || blob is null || map is null || blob.get_u8("ai builder job") != AIB_JOB_STONE)
		return false;

	Vec2f anchor = blob.get_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY);
	if (anchor == Vec2f_zero) return false;
	Vec2f pos = blob.getPosition();
	Vec2f routeCorner = blob.get_Vec2f(AIBM_STONE_RETURN_CORNER_KEY);
	if (routeCorner == Vec2f_zero) routeCorner = blob.get_Vec2f("ai builder stone route corner");
	Vec2f egress = blob.get_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY);
	const bool withinReentryBand = AIB_IsWithinStoneReturnReentryBand(pos, anchor, map.tilesize);
	const bool shaftReentry = !withinReentryBand &&
		AIB_IsInsideStoneReturnShaftInfluence(pos, anchor, map.tilesize);
	if (egress != Vec2f_zero)
	{
		if (shaftReentry)
		{
			blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, Vec2f_zero);
			AIB_RearmStoneReturnFromShaftReentry(blob, map, anchor);
			AIB_LogEvent("ai", "stone_return_reentry", AIB_EventBlobRef(blob),
				"anchor=" + AIB_EventPos(anchor) + " pos=" + AIB_EventPos(pos) + " source=egress");
		}
		else
		{
			return AIB_DriveStoneReturnEgress(brain, blob, anchor, egress);
		}
	}
	else if (blob.get_bool(AIBM_STONE_RETURN_SURFACED_KEY))
	{
		// Once the worker has physically crossed the shaft lip, ordinary surface
		// navigation owns the trip home. Re-arm the shaft controller only for a
		// real fall inside the same two-column shaft, never for a lower surface
		// slope several tiles away.
		if (!shaftReentry) return false;
		AIB_RearmStoneReturnFromShaftReentry(blob, map, anchor);
		AIB_LogEvent("ai", "stone_return_reentry", AIB_EventBlobRef(blob),
			"anchor=" + AIB_EventPos(anchor) + " pos=" + AIB_EventPos(pos) + " source=surface");
	}
	const bool directReturnActive = blob.get_bool("ai builder direct stone return");
	const bool strictSurfaceCrossing = AIB_HasReachedStoneReturnSurface(pos, anchor, map.tilesize);
	const bool retainedSurfaceOwnership = !directReturnActive &&
		withinReentryBand;
	// Keep this controller through the marginal wall-climb apex below the shaft
	// lip. After the strict crossing, a wider re-entry band prevents collision
	// jitter from alternating direct return and BrainPath every few ticks.
	if (strictSurfaceCrossing || retainedSurfaceOwnership)
	{
		if (directReturnActive)
		{
			// This anchor has now been crossed under real movement. Preserve that
			// proof across delivery cleanup so a same-shaft follow-up route cannot
			// replace it with one transient, higher collision position.
			blob.set_Vec2f(AIBM_STONE_SURFACE_MEMORY_KEY, anchor);
			egress = AIB_FindStoneReturnEgress(blob, anchor);
			blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, egress);
			AIB_LogEvent("ai", "stone_return_surface", AIB_EventBlobRef(blob),
				"anchor=" + AIB_EventPos(anchor) + " pos=" + AIB_EventPos(pos) +
				" egress=" + AIB_EventPos(egress) + " surface_memory=" + AIB_EventPos(anchor));
		}
		blob.set_bool(AIBM_STONE_RETURN_SURFACED_KEY, true);
		blob.set_bool("ai builder direct stone return", false);
		blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, Vec2f_zero);
		blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, 0);
		blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
		blob.set_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY, false);
		blob.set_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY, false);
		blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, false);
		blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, 0);
		if (egress != Vec2f_zero) return AIB_DriveStoneReturnEgress(brain, blob, anchor, egress);
		if (directReturnActive)
		{
			AIB_LogEvent("ai", "stone_return_exit", AIB_EventBlobRef(blob),
				"anchor=" + AIB_EventPos(anchor) + " egress=none pos=" + AIB_EventPos(pos) +
				" surface_memory=" + AIB_EventPos(anchor));
		}
		return false;
	}
	const bool startingDirectReturn = !directReturnActive;
	if (startingDirectReturn)
	{
		// Mining-route progress timestamps belong to the outbound leg. Start a
		// fresh return window instead of reporting an immediate false stall.
		blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, pos);
		blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, getGameTime());
		blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
	}
	const bool retryCornerRejoin = !startingDirectReturn &&
		AIB_ObserveStoneReturnProgress(blob, map, anchor, routeCorner);
	if (retryCornerRejoin)
	{
		blob.set_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY, false);
		blob.set_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY, false);
		blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, false);
		blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, 0);
		AIB_LogEvent("ai", "stone_return_corner_retry", AIB_EventBlobRef(blob),
			"corner=" + AIB_EventPos(routeCorner) + " anchor=" + AIB_EventPos(anchor) +
			" pos=" + AIB_EventPos(pos));
	}

	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", anchor);
	blob.set_bool("ai builder justgo", false);
	blob.set_u8("ai builder obstruction threshold", 0);
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	blob.setKeyPressed(key_up, false);
	blob.setKeyPressed(key_down, false);

	// Adjacent ore and visible-gold diversions can leave the miner below the
	// retained cross-tunnel on either side of its corner. Aiming directly at the
	// surface anchor then walks horizontally into the solid diagonal below that
	// corridor forever. Rejoin the stored route corner first, but steer the
	// runner's body to the centre of the two cleared shaft columns rather than the
	// corner tile's left edge. Once it reaches that vertical band near the real
	// shaft centre, latch the handoff so crossing jitter cannot pull it backward.
	// The progress watchdog reopens this gate only after a genuine stopped fall.
	const bool wasCornerAssist = blob.get_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY);
	bool cornerRejoined = blob.get_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY);
	bool cornerAssist = false;
	Vec2f cornerRejoinTarget = AIB_GetStoneReturnCornerRejoinTarget(anchor, routeCorner, map.tilesize);
	if (!cornerRejoined && routeCorner != Vec2f_zero)
	{
		const bool insideReturnSpan = cornerRejoinTarget != Vec2f_zero &&
			Maths::Abs(pos.x - cornerRejoinTarget.x) <= map.tilesize * 0.5f;
		const f32 verticalTolerance = wasCornerAssist ? map.tilesize * 0.5f : map.tilesize;
		const bool insideTunnelBand = pos.y <= routeCorner.y + verticalTolerance;
		cornerAssist = !insideReturnSpan || !insideTunnelBand;
		if (!cornerAssist)
		{
			cornerRejoined = true;
			blob.set_bool(AIBM_STONE_RETURN_CORNER_REJOINED_KEY, true);
			// Start the climb phase with its own upward-progress sample. Horizontal
			// approach time must not consume the bounded wall-climb window.
			blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, pos);
			blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, getGameTime());
			blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
		}
	}
	if (cornerAssist != wasCornerAssist)
	{
		blob.set_bool(AIBM_STONE_RETURN_CORNER_ASSIST_KEY, cornerAssist);
		AIB_LogEvent("ai", cornerAssist ? "stone_return_corner_assist" : "stone_return_corner_rejoined",
			AIB_EventBlobRef(blob), "corner=" + AIB_EventPos(routeCorner) +
			" anchor=" + AIB_EventPos(anchor) + " pos=" + AIB_EventPos(pos));
	}
	Vec2f driveTarget = cornerAssist && cornerRejoinTarget != Vec2f_zero ? cornerRejoinTarget : anchor;
	const f32 lateral = driveTarget.x - pos.x;
	if (Maths::Abs(lateral) > 1.0f)
	{
		blob.setKeyPressed(key_left, lateral < 0.0f);
		blob.setKeyPressed(key_right, lateral > 0.0f);
	}
	// KAG wall climbing needs up while the runner also leans into the shaft
	// wall. Keep the long cross-tunnel approach horizontal, then combine both
	// inputs within a tile and a half of the stored entry column.
	if (cornerAssist)
	{
		if (AIB_ShouldClimbToStoneReturnCorner(pos, driveTarget, map.tilesize))
		{
			blob.setKeyPressed(key_up, true);
		}
		// During a long horizontal rejoin, ordinary geometry-qualified obstacle
		// scaling may jump a real lip without turning the whole approach into an
		// unbounded wall climb toward a distant, higher corner.
		AIB_ScaleObstacles(blob, driveTarget);
	}
	else if (Maths::Abs(lateral) <= map.tilesize * 1.5f)
	{
		// Cross-tunnels can leave a two-cell notch in the shaft's left wall. Jump
		// through that lip near the two-wide centerline before latching the wall
		// direction; pressing left from the tunnel floor walks under the lip.
		// After the latch, hold the selected solid wall plus up until the surface exit.
		bool climbLatched = blob.get_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY);
		s32 climbDirection = blob.get_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY);
		const f32 shaftCenterX = anchor.x + map.tilesize * 0.5f;
		const bool centeredForClimb = Maths::Abs(pos.x - shaftCenterX) <= 2.0f;
		const u8 climbWallMask = AIB_GetStoneReturnClimbWallMask(blob, pos, anchor);
		// When the ore lies left of the planned shaft, its two-high cross-tunnel
		// opens through the same outer wall used by the canonical left-column
		// climb. Rise half a tile through that notch before leaning left. A
		// right-opening tunnel leaves the climb wall intact and can latch sooner.
		const f32 wallEngageY = routeCorner == Vec2f_zero ? anchor.y + map.tilesize * 2.0f :
			AIB_GetStoneReturnWallEngageY(anchor, routeCorner, map.tilesize);
		if (climbLatched)
		{
			const s32 selectedDirection = AIB_SelectStoneReturnClimbDirection(climbWallMask, climbDirection);
			if (selectedDirection == 0)
			{
				climbLatched = false;
				climbDirection = 0;
				blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, false);
				blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, 0);
				AIB_LogEvent("ai", "stone_return_wall_release", AIB_EventBlobRef(blob),
					"reason=no_wall anchor=" + AIB_EventPos(anchor) +
					" corner=" + AIB_EventPos(routeCorner) + " pos=" + AIB_EventPos(pos));
			}
			else if (selectedDirection != climbDirection)
			{
				const s32 previousDirection = climbDirection;
				climbDirection = selectedDirection;
				blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, climbDirection);
				AIB_LogEvent("ai", "stone_return_wall_turn", AIB_EventBlobRef(blob),
					"from=" + previousDirection + " to=" + climbDirection + " walls=" + climbWallMask +
					" anchor=" + AIB_EventPos(anchor) + " pos=" + AIB_EventPos(pos));
			}
		}
		if (climbLatched && AIB_HasEscapedStoneReturnClimbWall(pos, anchor, map.tilesize, climbDirection))
		{
			climbLatched = false;
			climbDirection = 0;
			blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, false);
			blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, 0);
			AIB_LogEvent("ai", "stone_return_wall_release", AIB_EventBlobRef(blob),
				"reason=outside_shaft anchor=" + AIB_EventPos(anchor) +
				" corner=" + AIB_EventPos(routeCorner) + " pos=" + AIB_EventPos(pos));
		}
		const s32 availableClimbDirection = AIB_SelectStoneReturnClimbDirection(climbWallMask, 0);
		if (!climbLatched && availableClimbDirection != 0 && centeredForClimb && pos.y <= wallEngageY)
		{
			climbLatched = true;
			climbDirection = availableClimbDirection;
			blob.set_bool(AIBM_STONE_RETURN_CLIMB_LATCH_KEY, true);
			blob.set_s32(AIBM_STONE_RETURN_CLIMB_DIRECTION_KEY, climbDirection);
			AIB_LogEvent("ai", "stone_return_wall_hold", AIB_EventBlobRef(blob),
				"anchor=" + AIB_EventPos(anchor) + " corner=" + AIB_EventPos(routeCorner) +
				" direction=" + climbDirection + " walls=" + climbWallMask + " pos=" + AIB_EventPos(pos));
		}
		if (climbLatched)
		{
			blob.setKeyPressed(key_left, climbDirection < 0);
			blob.setKeyPressed(key_right, climbDirection > 0);
		}
		else
		{
			// Collision centers a full-width builder between the two route tiles,
			// half a tile right of the canonical left-column anchor.
			blob.setKeyPressed(key_left, pos.x > shaftCenterX + 1.0f);
			blob.setKeyPressed(key_right, pos.x < shaftCenterX - 1.0f);
		}
		blob.setKeyPressed(key_up, true);
		AIB_ScaleObstacles(blob, anchor);
	}

	if (!blob.get_bool("ai builder direct stone return"))
	{
		blob.set_bool("ai builder direct stone return", true);
		AIB_LogEvent("ai", "stone_return_direct", AIB_EventBlobRef(blob),
			"anchor=" + AIB_EventPos(anchor) + " pos=" + AIB_EventPos(pos));
	}
	return true;
}

void AIB_AbortStoneRouteToSurface(CBrain@ brain, CBlob@ blob, Vec2f target, const string &in reason)
{
	if (blob is null) return;
	Vec2f routeCorner = blob.get_Vec2f("ai builder stone route corner");
	Vec2f returnAnchor = blob.get_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY);
	Vec2f returnCorner = blob.get_Vec2f(AIBM_STONE_RETURN_CORNER_KEY);
	const bool rejectedGold = blob.get_bool("ai builder mining gold") || AIB_IsGoldTile(target);
	const u32 rejectedUntil = getGameTime() + AIB_REJECTED_ROUTE_COOLDOWN;
	blob.set_Vec2f(AIBM_STONE_REJECTED_ROUTE_KEY, target);
	blob.set_u32(AIBM_STONE_REJECTED_ROUTE_UNTIL_KEY, rejectedUntil);
	if (brain !is null) brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_Vec2f("ai builder tile target", Vec2f_zero);
	blob.set_bool("ai builder justgo", false);
	blob.set_bool("ai builder mining gold", false);
	blob.set_bool("ai builder direct stone shaft", false);
	blob.set_u8("ai builder obstruction threshold", 0);
	blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, blob.getPosition());
	blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, getGameTime());
	blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
	AIB_LogEvent("ai", "stone_route_abort", AIB_EventBlobRef(blob),
		"reason=" + reason + " target=" + AIB_EventPos(target) +
		" route_corner=" + AIB_EventPos(routeCorner) +
		" return_anchor=" + AIB_EventPos(returnAnchor) +
		" return_corner=" + AIB_EventPos(returnCorner) +
		" rejected_gold=" + (rejectedGold ? "true" : "false") +
		" retry=" + rejectedUntil +
		" pos=" + AIB_EventPos(blob.getPosition()));
	AIB_SetState(blob, AIBuilderState::return_wood,
		reason == "shaft_no_progress" ? "stone shaft made no progress" : "stone route has no legal continuation");
}

bool AIB_RetargetExistingStoneRoute(CBrain@ brain, CBlob@ blob, Vec2f target)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero) return false;

	// Adjacent ore can cross to the other side of the old shaft or introduce a
	// new bedrock/structure conflict.  Re-run the bounded exact search; already
	// open corridors remain cheapest and are naturally reused.
	Vec2f previousCorner = blob.get_Vec2f("ai builder stone route corner");
	Vec2f retainedCorner = blob.get_Vec2f(AIBM_STONE_RETURN_CORNER_KEY);
	if (retainedCorner == Vec2f_zero) retainedCorner = previousCorner;
	Vec2f returnAnchor = blob.get_Vec2f(AIBM_STONE_RETURN_ANCHOR_KEY);
	Vec2f corner = AIB_GetBestStoneRouteCorner(blob, target);
	if (AIB_CanUseFreshStoneRetarget(blob.getPosition(), returnAnchor, retainedCorner, corner, map.tilesize))
	{
		blob.set_Vec2f("ai builder stone route corner", corner);
		AIB_UpdateStoneReturnRoute(blob, target, corner);
		return true;
	}
	if (corner != Vec2f_zero)
	{
		AIB_LogEvent("ai", "stone_route_fresh_rejected", AIB_EventBlobRef(blob),
			"reason=underground_shaft_change from=" + AIB_EventPos(retainedCorner) +
			" candidate=" + AIB_EventPos(corner) + " anchor=" + AIB_EventPos(returnAnchor) +
			" target=" + AIB_EventPos(target) + " pos=" + AIB_EventPos(blob.getPosition()));
	}

	// A fresh search is surface-oriented and can legitimately fail once the
	// worker is already inside its tunnel. Continue the last nonzero shaft x at
	// the new depth only after validating every remaining shaft/cross-tunnel
	// cell. The saved return corner survives even if legacy state already erased
	// the mutable mining corner.
	Vec2f continuedCorner = AIB_GetContinuedStoneRouteCorner(blob, target, retainedCorner);
	if (continuedCorner != Vec2f_zero)
	{
		if (brain !is null) brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		blob.set_bool("ai builder justgo", false);
		blob.set_bool("ai builder direct stone shaft", false);
		blob.set_u8("ai builder obstruction threshold", 0);
		blob.set_Vec2f("ai builder stone route corner", continuedCorner);
		AIB_UpdateStoneReturnRoute(blob, target, continuedCorner);
		AIB_LogEvent("ai", "stone_route_continue", AIB_EventBlobRef(blob),
			"from=" + AIB_EventPos(retainedCorner) +
			" corner=" + AIB_EventPos(continuedCorner) +
			" target=" + AIB_EventPos(target) +
			" route_dirt=" + AIB_CountDirtOnStoneRoute(blob, target, continuedCorner) +
			" pos=" + AIB_EventPos(blob.getPosition()));
		return true;
	}

	AIB_AbortStoneRouteToSurface(brain, blob, target, "no_legal_continuation");
	return false;
}

void AIB_RecomputeStoneRouteAroundBlock(CBrain@ brain, CBlob@ blob, Vec2f target, Vec2f blockedTile)
{
	if (blob is null || target == Vec2f_zero) return;

	CMap@ map = getMap();
	u16 blockedType = 0;
	if (map !is null) blockedType = map.getTile(blockedTile).type;
	Vec2f current = blob.get_Vec2f("ai builder stone route corner");
	Vec2f replacement = AIB_GetBestStoneRouteCornerExcluding(blob, target, blockedTile);
	const bool sameCorner = current != Vec2f_zero && replacement != Vec2f_zero &&
		(replacement - current).Length() < 1.0f;
	const bool stillBlocked = replacement != Vec2f_zero &&
		AIB_IsTileOnStoneRoute(blob, target, replacement, blockedTile);
	if (replacement != Vec2f_zero && !sameCorner && !stillBlocked)
	{
		blob.set_Vec2f("ai builder stone route corner", replacement);
		AIB_UpdateStoneReturnRoute(blob, target, replacement);
		if (brain !is null) brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		AIB_LogEvent("ai", "stone_route_replan", AIB_EventBlobRef(blob), "blocked=" + AIB_EventPos(blockedTile) +
			" blocked_type=" + blockedType + " replacement=" + AIB_EventPos(replacement) + " target=" + AIB_EventPos(target));
		return;
	}

	if (brain !is null) brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_Vec2f("ai builder stone route corner", Vec2f_zero);
	blob.set_Vec2f("ai builder tile target", Vec2f_zero);
	if (blob.get_u8("ai builder state") == AIBuilderState::tunnel_to_stone)
	{
		AIB_SetState(blob, AIBuilderState::find_stone, "stone route blocked by non-mineable tile");
	}
	else
	{
		AIB_ReportWaitingStatus(blob, "Stone route blocked; choosing another deposit");
	}
	string rejectReason = "no_alternate";
	if (sameCorner) rejectReason = "same_route";
	else if (stillBlocked) rejectReason = "still_blocked";
	AIB_LogEvent("ai", "stone_route_reject", AIB_EventBlobRef(blob), "blocked=" + AIB_EventPos(blockedTile) +
		" blocked_type=" + blockedType + " reason=" + rejectReason +
		" target=" + AIB_EventPos(target));
}

Vec2f AIB_GetShaftTopForStone(Vec2f stone)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	int stoneX = Maths::Floor(stone.x / map.tilesize);
	int stoneY = Maths::Floor(stone.y / map.tilesize);
	if (stoneX > map.tilemapwidth - 4) stoneX = map.tilemapwidth - 4;

	for (int y = 2; y <= stoneY; y++)
	{
		Vec2f here = Vec2f(stoneX * map.tilesize, y * map.tilesize);
		Vec2f below = here + Vec2f(0.0f, map.tilesize);
		if (!map.isTileSolid(here) &&
			!map.isTileSolid(here + Vec2f(map.tilesize, 0.0f)) &&
			(map.isTileSolid(below) || map.isTileSolid(below + Vec2f(map.tilesize, 0.0f))))
		{
			return here;
		}
	}

	return Vec2f_zero;
}

Vec2f AIB_GetNextTunnelTile(CBlob@ blob, Vec2f oreTarget, Vec2f routeCorner, Vec2f target)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	Vec2f clearance = AIB_GetStoneRouteClearanceTile(blob, oreTarget, routeCorner, target);
	if (clearance != Vec2f_zero) return clearance;

	Vec2f hit = AIB_GetBlockingTileTowardStone(blob, target);
	if (hit != Vec2f_zero) return hit;

	Vec2f pos = blob.getPosition();
	int builderX = Maths::Floor(pos.x / map.tilesize);
	int builderY = Maths::Floor(pos.y / map.tilesize);
	int targetX = Maths::Floor(target.x / map.tilesize);
	int targetY = Maths::Floor(target.y / map.tilesize);

	if (builderY < targetY - 1)
	{
		Vec2f tile = Vec2f(builderX * map.tilesize, (builderY + 1) * map.tilesize);
		return AIB_IsMineableStonePathTile(tile) ? tile : Vec2f_zero;
	}
	if (builderY > targetY + 1)
	{
		Vec2f tile = Vec2f(builderX * map.tilesize, (builderY - 1) * map.tilesize);
		return AIB_IsMineableStonePathTile(tile) ? tile : Vec2f_zero;
	}

	if (Maths::Abs(targetX - builderX) <= 1)
	{
		return target;
	}

	const int step = targetX > builderX ? 1 : -1;
	Vec2f ahead = Vec2f((builderX + step) * map.tilesize, targetY * map.tilesize);
	if (AIB_IsMineableStonePathTile(ahead)) return ahead;

	Vec2f head = ahead - Vec2f(0.0f, map.tilesize);
	if (AIB_IsMineableStonePathTile(head)) return head;

	return target;
}

Vec2f AIB_GetStoneRouteClearanceTile(CBlob@ blob, Vec2f target, Vec2f routeCorner, Vec2f routeDestination)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero || routeCorner == Vec2f_zero)
		return AIB_GetPassageClearanceTile(blob, routeDestination);

	Vec2f pos = blob.getPosition();
	const int builderX = Maths::Floor(pos.x / map.tilesize);
	const int builderY = Maths::Floor(pos.y / map.tilesize);
	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	const int destinationX = Maths::Floor(routeDestination.x / map.tilesize);
	const int destinationY = Maths::Floor(routeDestination.y / map.tilesize);
	const int side = targetX < shaftX ? -1 : 1;

	if (!AIB_IsStoneRouteShaftColumn(builderX, shaftX, targetX))
		return AIB_GetPassageClearanceTile(blob, routeDestination);

	// During the vertical leg, sample the exact two planned shaft columns. Once
	// the runner straddles their boundary, deriving clearance from floor(pos.x)
	// would shift the second sample one tile off-route and could leave the real
	// supporting lip untouched forever.
	const bool verticalLeg = destinationX == shaftX && destinationY == targetY &&
		(destinationX != targetX || Maths::Abs(builderY - targetY) > 1);
	if (verticalLeg)
	{
		const int stepY = targetY >= builderY ? 1 : -1;
		Vec2f first = Vec2f(shaftX * map.tilesize, (builderY + stepY) * map.tilesize);
		Vec2f second = first + Vec2f(side * map.tilesize, 0.0f);
		if (AIB_TileNeedsDigging(first)) return first;
		if (AIB_TileNeedsDigging(second)) return second;
		return Vec2f_zero;
	}

	// At ore depth, keep clearance on the canonical two-high cross-tunnel even
	// if collision or a jump leaves the runner's floor row one tile above/below
	// it. Choose the nearest remaining route cell, excluding the ore foot itself
	// so normal target handling retains ownership of the final hit.
	if (targetX == shaftX) return Vec2f_zero;
	Vec2f best = Vec2f_zero;
	f32 bestDistance = 999999.0f;
	for (int x = shaftX + side; ; x += side)
	{
		Vec2f foot = Vec2f(x * map.tilesize, targetY * map.tilesize);
		Vec2f head = foot - Vec2f(0.0f, map.tilesize);
		if (x != targetX && AIB_TileNeedsDigging(foot))
		{
			const f32 distance = (AIB_TileCenter(foot) - pos).Length();
			if (distance < bestDistance)
			{
				best = foot;
				bestDistance = distance;
			}
		}
		if (AIB_TileNeedsDigging(head))
		{
			const f32 distance = (AIB_TileCenter(head) - pos).Length();
			if (distance < bestDistance)
			{
				best = head;
				bestDistance = distance;
			}
		}
		if (x == targetX) break;
	}
	return best;
}

Vec2f AIB_GetPassageClearanceTile(CBlob@ blob, Vec2f target)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	Vec2f pos = blob.getPosition();
	const int builderX = Maths::Floor(pos.x / map.tilesize);
	const int builderY = Maths::Floor(pos.y / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);

	if (Maths::Abs(targetX - builderX) >= Maths::Abs(targetY - builderY))
	{
		const int step = targetX >= builderX ? 1 : -1;
		Vec2f currentHead = Vec2f(builderX * map.tilesize, (builderY - 1) * map.tilesize);
		Vec2f foot = Vec2f((builderX + step) * map.tilesize, builderY * map.tilesize);
		Vec2f head = foot - Vec2f(0.0f, map.tilesize);

		if (AIB_TileNeedsDigging(foot)) return foot;
		if (AIB_TileNeedsDigging(currentHead)) return currentHead;
		if (AIB_TileNeedsDigging(head)) return head;
	}
	else
	{
		const int step = targetY >= builderY ? 1 : -1;
		Vec2f left = Vec2f(builderX * map.tilesize, (builderY + step) * map.tilesize);
		Vec2f right = left + Vec2f(map.tilesize, 0.0f);

		if (AIB_TileNeedsDigging(left)) return left;
		if (AIB_TileNeedsDigging(right)) return right;
	}

	return Vec2f_zero;
}

Vec2f AIB_GetBlockingTileTowardStone(CBlob@ blob, Vec2f target)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	Vec2f col;
	if (!map.rayCastSolid(blob.getPosition(), AIB_TileCenter(target), col)) return Vec2f_zero;

	Vec2f hit = map.getTileWorldPosition(map.getTileSpacePosition(col));
	return AIB_IsMineableStonePathTile(hit) ? hit : Vec2f_zero;
}

bool AIB_MineTile(CBlob@ blob, Vec2f tilePos)
{
	CMap@ map = getMap();
	if (map is null) return false;

	Vec2f center = AIB_TileCenter(tilePos);
	blob.setAimPos(center);
	blob.setKeyPressed(key_action2, true);

	const u32 gameTime = getGameTime();
	if (gameTime < blob.get_u32("ai builder next hit")) return false;
	if ((center - blob.getPosition()).Length() > 40.0f) return false;
	if (!AIB_IsMineableStonePathTile(tilePos)) return false;

	TileType type = map.getTile(tilePos).type;
	const bool wasStone = map.isTileStone(type) || map.isTileThickStone(type);
	map.server_DestroyTile(tilePos, 1.0f, blob);
	Material::fromTile(blob, type, 1.0f);
	AIBG_RecordInteraction(blob);
	blob.set_u32("ai builder next hit", gameTime + AIB_HIT_DELAY);
	if (AIB_UsesDedicatedStoneRouteMovement(blob.get_u8("ai builder job"), blob.get_u8("ai builder state")))
	{
		// A stationary hit is real route progress. Keep thick stone and repeated
		// clearance hits from consuming the direct-movement watchdog window.
		blob.set_Vec2f(AIBM_STONE_RETURN_PROGRESS_POS_KEY, blob.getPosition());
		blob.set_u32(AIBM_STONE_RETURN_PROGRESS_TICK_KEY, gameTime);
		blob.set_bool(AIBM_STONE_RETURN_STALL_LOGGED_KEY, false);
	}

	if (wasStone)
	{
		AIB_CollectNearbyStone(blob);
		if (AIB_ShouldReturnStone(blob))
		{
			AIB_SetState(blob, AIBuilderState::return_wood, "stone quota reached");
		}
	}
	return true;
}

bool AIB_IsMineableStonePathTile(Vec2f tilePos)
{
	CMap@ map = getMap();
	if (map is null) return false;

	TileType type = map.getTile(tilePos).type;
	return map.isTileGround(type) || map.isTileStone(type) || map.isTileThickStone(type) || map.isTileGold(type);
}

Vec2f AIB_GetNearbyStoneTile(CBlob@ blob, Vec2f center, const u8 radius)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	Vec2f centerTile = map.getTileWorldPosition(map.getTileSpacePosition(center));
	Vec2f builderPos = blob.getPosition();
	Vec2f best = Vec2f_zero;
	f32 bestDistance = 99999999.0f;
	const bool hasSelectedStone = AIB_HasSelectedStoneTiles();

	for (int y = -radius; y <= radius; y++)
	{
		for (int x = -radius; x <= radius; x++)
		{
			Vec2f tile = centerTile + Vec2f(x * map.tilesize, y * map.tilesize);
			if (!AIB_IsStoneTile(tile)) continue;
			if (AIB_IsRejectedMiningRouteTarget(blob, tile)) continue;
			if (hasSelectedStone && !AIB_IsSelectedStoneTile(tile)) continue;
			if (!AIB_IsInsideCurrentBarrierZone(blob, AIB_TileCenter(tile))) continue;
			if (!AIB_IsSafeResource(blob, AIB_TileCenter(tile))) continue;

			const f32 distance = (AIB_TileCenter(tile) - builderPos).Length();
			if (distance < bestDistance)
			{
				bestDistance = distance;
				best = tile;
			}
		}
	}

	return best;
}

bool AIB_HasSelectedStoneTiles()
{
	array<Vec2f>@ selected = AIB_GetSelectedStoneTiles();
	if (selected is null) return false;

	CMap@ map = getMap();
	if (map is null) return false;
	for (uint i = 0; i < selected.length; i++)
	{
		if (AIB_IsStoneTile(Vec2f(selected[i].x * map.tilesize, selected[i].y * map.tilesize)))
		{
			return true;
		}
	}
	return false;
}

bool AIB_IsSelectedStoneTile(Vec2f tile)
{
	array<Vec2f>@ selected = AIB_GetSelectedStoneTiles();
	if (selected is null) return false;

	CMap@ map = getMap();
	if (map is null) return false;
	Vec2f tileSpace = map.getTileSpacePosition(tile);
	u16 tx = u16(tileSpace.x);
	u16 ty = u16(tileSpace.y);

	for (uint i = 0; i < selected.length; i++)
	{
		if (u16(selected[i].x) == tx && u16(selected[i].y) == ty)
		{
			return true;
		}
	}
	return false;
}

Vec2f AIB_GetBestSelectedStoneTile(CBlob@ blob)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	array<Vec2f>@ selected = AIB_GetSelectedStoneTiles();
	if (selected is null || selected.length == 0) return Vec2f_zero;

	Vec2f builderPos = blob.getPosition();
	Vec2f best = Vec2f_zero;
	f32 bestScore = 99999999.0f;

	for (uint i = 0; i < selected.length; i++)
	{
		Vec2f tile = Vec2f(selected[i].x * map.tilesize, selected[i].y * map.tilesize);
		if (!AIB_IsStoneTile(tile)) continue;
		if (AIB_IsRejectedMiningRouteTarget(blob, tile)) continue;
		if (!AIB_IsInsideCurrentBarrierZone(blob, AIB_TileCenter(tile))) continue;
		if (!AIB_IsSafeResource(blob, AIB_TileCenter(tile))) continue;

		const f32 distance = (AIB_TileCenter(tile) - builderPos).Length();
		Vec2f routeCorner = AIB_GetBestStoneRouteCorner(blob, tile);
		if (routeCorner == Vec2f_zero) continue;
		if (AIB_IsStoneRouteReservedByOther(blob, routeCorner)) continue;
		const f32 score = distance + AIB_CountDirtOnStoneRoute(blob, tile, routeCorner) * AIB_STONE_DIRT_PENALTY;
		if (score < bestScore)
		{
			bestScore = score;
			best = tile;
		}
	}

	return best;
}

array<Vec2f>@ AIB_GetSelectedStoneTiles()
{
	CRules@ rules = getRules();
	if (rules is null) return null;

	array<Vec2f>@ selected = null;
	if (!rules.get("aibuilder selected stone tiles", @selected))
	{
		return null;
	}
	return selected;
}

Vec2f AIB_GetApproachPositionForStone(CBlob@ blob, Vec2f target)
{
	CMap@ map = getMap();
	if (map is null) return AIB_TileCenter(target);

	Vec2f best = AIB_TileCenter(target);
	f32 bestDistance = 99999999.0f;
	Vec2f builderPos = blob.getPosition();
	array<Vec2f> offsets = {
		Vec2f(0.0f, -map.tilesize),
		Vec2f(-map.tilesize, 0.0f),
		Vec2f(map.tilesize, 0.0f),
		Vec2f(0.0f, map.tilesize)
	};

	for (uint i = 0; i < offsets.length; i++)
	{
		for (u8 step = 1; step <= 3; step++)
		{
			Vec2f tile = target + offsets[i] * step;
			Vec2f center = AIB_TileCenter(tile);
			// A farther clear cell is not an exposed approach if an intervening
			// body-height cell is blocked. Stop this ray at the first obstruction.
			if (!AIB_HasStoneApproachBodyClearance(blob, center)) break;
			const f32 distance = (center - builderPos).Length();
			if (distance < bestDistance)
			{
				bestDistance = distance;
				best = center;
			}
		}
	}

	return best;
}

bool AIB_TileNeedsDigging(Vec2f tilePos)
{
	CMap@ map = getMap();
	if (map is null) return false;

	Tile tile = map.getTile(tilePos);
	return map.isTileSolid(tile.type) && !map.isTileBedrock(tile.type);
}

bool AIB_IsStoneTile(Vec2f tilePos)
{
	CMap@ map = getMap();
	if (map is null) return false;

	TileType type = map.getTile(tilePos).type;
	return map.isTileStone(type) || map.isTileThickStone(type);
}

bool AIB_IsGoldTile(Vec2f tilePos)
{
	CMap@ map = getMap();
	return map !is null && map.isTileGold(map.getTile(tilePos).type);
}

Vec2f AIB_GetBestVisibleGoldTile(CBlob@ blob)
{
	return AIB_GetBestVisibleGoldTileNear(blob, Vec2f_zero, AIB_GOLD_SIGHT_RADIUS);
}

Vec2f AIB_GetBestVisibleGoldTileNear(CBlob@ blob, Vec2f clusterCenter, const u8 radius)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return Vec2f_zero;

	Vec2f pos = blob.getPosition();
	Vec2f origin = map.getTileWorldPosition(map.getTileSpacePosition(pos));
	Vec2f best = Vec2f_zero;
	f32 bestDistance = 999999.0f;
	const f32 ts = map.tilesize;
	for (int y = -AIB_GOLD_SIGHT_RADIUS; y <= AIB_GOLD_SIGHT_RADIUS; y++)
	{
		for (int x = -AIB_GOLD_SIGHT_RADIUS; x <= AIB_GOLD_SIGHT_RADIUS; x++)
		{
			if (x * x + y * y > AIB_GOLD_SIGHT_RADIUS * AIB_GOLD_SIGHT_RADIUS) continue;
			Vec2f tile = origin + Vec2f(x * ts, y * ts);
			if (!AIB_IsInsideMap(tile) || !AIB_IsGoldTile(tile)) continue;
			if (AIB_IsRejectedMiningRouteTarget(blob, tile)) continue;
			if (clusterCenter != Vec2f_zero && (tile - clusterCenter).Length() > radius * ts) continue;

			Vec2f center = AIB_TileCenter(tile);
			if (!AIB_IsInsideCurrentBarrierZone(blob, center) || !AIB_IsSafeResource(blob, center)) continue;
			// Visible ore does not need a full two-wide mining route, but protected
			// building footprints must never be undermined.  Apply this to both the
			// initial sighting and adjacent cluster continuation.
			if (map.getSectorAtPosition(center, "no build") !is null) continue;

			Vec2f collision;
			if (!map.rayCastSolid(pos, center, collision)) continue;
			Vec2f hitTile = map.getTileWorldPosition(map.getTileSpacePosition(collision));
			if ((hitTile - tile).Length() > 1.0f) continue;

			const f32 distance = (center - pos).Length();
			if (distance < bestDistance)
			{
				bestDistance = distance;
				best = tile;
			}
		}
	}
	return best;
}

bool AIB_IsRejectedMiningRouteTarget(CBlob@ blob, Vec2f tile)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return false;
	const u32 until = blob.get_u32(AIBM_STONE_REJECTED_ROUTE_UNTIL_KEY);
	if (until != 0 && getGameTime() >= until)
	{
		blob.set_Vec2f(AIBM_STONE_REJECTED_ROUTE_KEY, Vec2f_zero);
		blob.set_u32(AIBM_STONE_REJECTED_ROUTE_UNTIL_KEY, 0);
		return false;
	}
	return AIB_IsRejectedStoneRouteTarget(tile,
		blob.get_Vec2f(AIBM_STONE_REJECTED_ROUTE_KEY), getGameTime(), until,
		map.tilesize, AIB_REJECTED_ROUTE_CLUSTER_RADIUS);
}

Vec2f AIB_TileCenter(Vec2f tilePos)
{
	CMap@ map = getMap();
	return map.getTileWorldPosition(map.getTileSpacePosition(tilePos)) + Vec2f(map.tilesize * 0.5f, map.tilesize * 0.5f);
}

bool AIB_SealShaftEntrance(CBlob@ blob, Vec2f shaftTop)
{
	return false;
}

bool AIB_PlaceWoodenDoor(CBlob@ blob, Vec2f tilePos)
{
	CMap@ map = getMap();
	if (map is null) return false;
	if (AIB_HasDoorAt(tilePos)) return true;
	if (!AIB_TakeWood(blob, AIB_WOODEN_DOOR_COST)) return false;

	CBlob@ door = server_CreateBlob("wooden_door", blob.getTeamNum(), AIB_TileCenter(tilePos));
	if (door is null) return false;

	CShape@ shape = door.getShape();
	if (shape !is null)
	{
		shape.server_SetActive(true);
		shape.SetStatic(true);
	}
	return true;
}

bool AIB_HasDoorAt(Vec2f tilePos)
{
	CBlob@[] blobs;
	getMap().getBlobsAtPosition(AIB_TileCenter(tilePos), @blobs);
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ b = blobs[i];
		if (b !is null && b.getName() == "wooden_door") return true;
	}
	return false;
}

bool AIB_TakeWood(CBlob@ blob, const u16 amount)
{
	CInventory@ inv = blob.getInventory();
	if (inv is null || inv.getCount("mat_wood") < amount) return false;

	inv.server_RemoveItems("mat_wood", amount);
	return true;
}

u16 AIB_CountWood(CBlob@ blob)
{
	CInventory@ inv = blob.getInventory();
	if (inv is null) return 0;

	return inv.getCount("mat_wood");
}

bool AIB_IsEligibleLooseStoneMat(CBlob@ blob, CBlob@ candidate)
{
	if (blob is null || !AIB_IsLooseWorldResource(candidate)) return false;
	const bool baseStone = AIB_IsBaseStoneSource(blob, candidate);
	if (AIB_IsDeliveredResourceAtHome(blob, candidate) && !baseStone) return false;
	// Base output is eligible only while it remains at the exact home, storage,
	// or supported-quarry boundary. Do not follow a tagged stack after it falls
	// into a shaft and becomes a moving lure below the base.
	if (!baseStone && (candidate.hasTag("aibuilder stone supply") ||
		candidate.hasTag("aibuilder base stone source")))
	{
		AIB_LogResourceRejectionDelta(blob, candidate, "escaped_base_stone");
		return false;
	}

	const f32 distance = (candidate.getPosition() - blob.getPosition()).Length();
	CMap@ map = getMap();
	if (!baseStone && (map is null || distance > AIB_STONE_LOOSE_SEARCH_RADIUS_TILES * map.tilesize))
	{
		AIB_LogResourceRejectionDelta(blob, candidate, "remote_stone");
		return false;
	}
	return baseStone || AIB_IsAccessibleResource(blob, candidate);
}

CBlob@ AIB_GetNearestStoneMat(CBlob@ blob)
{
	CBlob@[] stone;
	getBlobsByName("mat_stone", @stone);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < stone.length; i++)
	{
		CBlob@ candidate = stone[i];
		if (!AIB_IsEligibleLooseStoneMat(blob, candidate)) continue;

		const f32 distance = (candidate.getPosition() - pos).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}

	return best;
}

bool AIB_CollectNearbyStone(CBlob@ blob)
{
	if (AIB_HasCarriedStone(blob)) return true;

	CBlob@[] stone;
	getBlobsByName("mat_stone", @stone);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < stone.length; i++)
	{
		CBlob@ candidate = stone[i];
		if (!AIB_IsEligibleLooseStoneMat(blob, candidate)) continue;

		const f32 distance = (candidate.getPosition() - pos).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}

	if (best is null || bestDistance > 28.0f) return false;
	return AIB_PickupStone(blob, best);
}

bool AIB_CollectNearbyGold(CBlob@ blob)
{
	if (blob is null) return false;

	CBlob@[] gold;
	getBlobsByName("mat_gold", @gold);
	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < gold.length; i++)
	{
		CBlob@ candidate = gold[i];
		if (!AIB_IsLooseWorldResource(candidate)) continue;
		if (AIB_IsDeliveredResourceAtHome(blob, candidate)) continue;
		if (!AIB_IsAccessibleResource(blob, candidate)) continue;

		const f32 distance = (candidate.getPosition() - pos).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}

	if (best is null || bestDistance > 28.0f) return false;
	if (blob.server_PutInInventory(best))
	{
		AIBGM_RecordCollectedResource(blob, best);
		return true;
	}
	blob.server_Pickup(best);
	AIB_StashCarriedResource(blob);
	const bool acquired = best.isInInventory() || blob.getCarriedBlob() is best;
	if (acquired) AIBGM_RecordCollectedResource(blob, best);
	return acquired;
}

bool AIB_HasSupportedBaseQuarryFoundation(CBlob@ home, Vec2f position)
{
	CMap@ map = getMap();
	if (home is null || map is null || position == Vec2f_zero) return false;
	if (!AIB_IsInsideCurrentBarrierZone(home, position)) return false;
	const f32 ts = map.tilesize;
	// Quarry.cfg is 40x24, matching a five-by-three workshop. Ore spawns one
	// tile left of center, so complete five-column support also covers its output.
	for (int x = -2; x <= 2; x++)
	{
		Vec2f foundation = position + Vec2f(x * ts, 2.0f * ts);
		if (!AIB_IsInsideMap(foundation) ||
			!map.isTileSolid(map.getTile(foundation).type)) return false;
	}
	return true;
}

bool AIB_IsBaseStoneSource(CBlob@ blob, CBlob@ stone)
{
	if (blob is null || !AIB_IsLooseWorldResource(stone)) return false;
	// Grounded no-crate delivery is accessible team stock, not a quarry output.
	// Without this guard a stone runner immediately reclaims its own deposit and
	// can loop between the mine and home without increasing stored resources.
	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null || stone.hasTag("aibuilder delivered resource")) return false;
	Vec2f stonePosition = stone.getPosition();
	if (!AIBR_IsOnSameBarrierSide(home, stonePosition)) return false;
	if ((stonePosition - AIB_GetHomeDropPoint(home)).Length() <= 56.0f ||
		(stonePosition - AIB_GetBaseStoragePoint(home)).Length() <= 56.0f)
	{
		stone.Tag("aibuilder base stone source");
		return true;
	}

	CBlob@[] quarries;
	getBlobsByName("quarry", @quarries);
	Vec2f storage = AIB_GetBaseStoragePoint(home);
	for (uint i = 0; i < quarries.length; i++)
	{
		CBlob@ quarry = quarries[i];
		if (quarry is null || quarry.hasTag("dead") || quarry.getTeamNum() != home.getTeamNum()) continue;
		if (!AIBR_IsOnSameBarrierSide(home, quarry.getPosition())) continue;
		if ((quarry.getPosition() - storage).Length() > 176.0f) continue;
		if (!AIB_HasSupportedBaseQuarryFoundation(home, quarry.getPosition())) continue;
		if ((stonePosition - quarry.getPosition()).Length() <= 40.0f)
		{
			stone.Tag("aibuilder base stone source");
			return true;
		}
	}
	return false;
}

bool AIB_PickupStone(CBlob@ blob, CBlob@ stone)
{
	if (blob is null || !AIB_IsLooseWorldResource(stone)) return false;
	if (AIB_HasCarriedStone(blob)) return true;

	blob.server_Pickup(stone);
	const bool acquired = stone.isInInventory() || blob.getCarriedBlob() is stone;
	if (acquired) AIBGM_RecordCollectedResource(blob, stone);
	return acquired;
}

bool AIB_HasCarriedStone(CBlob@ blob)
{
	CBlob@ carried = blob.getCarriedBlob();
	return carried !is null && carried.getName() == "mat_stone";
}

bool AIB_IsDeliveredResourceAtHome(CBlob@ blob, CBlob@ resource)
{
	if (resource is null) return false;
	if (resource.hasTag("aibuilder delivered resource")) return true;

	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null) return false;
	return (resource.getPosition() - (home.getPosition() + Vec2f(0.0f, -12.0f))).Length() <= 36.0f;
}

CBlob@ AIB_GetNearestTree(CBlob@ blob)
{
	CBlob@[] trees;
	getBlobsByTag("tree", @trees);
	return AIB_GetBestTreeForHome(blob, @trees);
}

CBlob@ AIB_GetNearestTreeIgnoringSelection(CBlob@ blob)
{
	CBlob@[] trees;
	getBlobsByTag("tree", @trees);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	for (uint i = 0; i < trees.length; i++)
	{
		CBlob@ tree = trees[i];
		if (tree is null || tree.hasTag("dead") || tree.hasTag("felldown")) continue;
		if (AIB_IsTreeRetryBlocked(blob, tree)) continue;
		if (!AIB_IsTreeHarvestReady(tree)) continue;
		if (!AIB_IsAccessibleResource(blob, tree)) continue;

		const f32 distance = (tree.getPosition() - blob.getPosition()).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = tree;
		}
	}
	return best;
}

CBlob@ AIB_GetNearestAccessibleTreeIgnoringMaturity(CBlob@ blob)
{
	CBlob@[] trees;
	getBlobsByTag("tree", @trees);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	for (uint i = 0; i < trees.length; i++)
	{
		CBlob@ tree = trees[i];
		if (tree is null || tree.hasTag("dead") || tree.hasTag("felldown") || tree.isInInventory()) continue;
		if (AIB_IsTreeRetryBlocked(blob, tree)) continue;
		if (!AIB_IsAllowedByOverseerSelection(tree)) continue;
		if (!AIB_IsAccessibleResource(blob, tree)) continue;

		const f32 distance = (tree.getPosition() - blob.getPosition()).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = tree;
		}
	}
	return best;
}

bool AIB_IsTreeHarvestReady(CBlob@ tree)
{
	return tree !is null && tree.hasTag("tree") && tree.get_u8("grown_times") >= AIB_TREE_HARVEST_GROWTH;
}

CBlob@ AIB_GetNearestWood(CBlob@ blob)
{
	CBlob@[] wood;
	getBlobsByName("mat_wood", @wood);
	return AIB_GetNearest(blob, @wood);
}

CBlob@ AIB_GetNearestLog(CBlob@ blob)
{
	CBlob@[] logs;
	getBlobsByName("log", @logs);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < logs.length; i++)
	{
		CBlob@ candidate = logs[i];
		if (candidate is null || candidate.hasTag("dead") || candidate.isInInventory()) continue;
		if (AIB_IsLogRetryBlocked(blob, candidate)) continue;
		if (!AIB_IsAccessibleResource(blob, candidate)) continue;

		const f32 distance = (candidate.getPosition() - pos).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}
	return best;
}

CBlob@ AIB_GetNearestTeamHall(CBlob@ blob)
{
	CBlob@[] halls;
	getBlobsByName("hall", @halls);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < halls.length; i++)
	{
		CBlob@ hall = halls[i];
		if (hall is null || hall.getTeamNum() != blob.getTeamNum()) continue;

		const f32 distance = (hall.getPosition() - pos).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = hall;
		}
	}
	return best;
}

CBlob@ AIB_GetTeamHome(CBlob@ blob)
{
	if (blob is null || blob.getTeamNum() >= 100) return null;
	CBlob@ assignedHome = AIBR_GetAssignedResourceHome(blob);
	if (assignedHome !is null) return assignedHome;

	CBlob@ home = AIB_GetNearestTeamBlob(blob, "tent");
	if (AIB_IsFriendlyHome(blob, home)) return home;

	@home = AIB_GetNearestTeamBlob(blob, "hall");
	return AIB_IsFriendlyHome(blob, home) ? home : null;
}

bool AIB_IsFriendlyHome(CBlob@ blob, CBlob@ home)
{
	return AIBR_IsFriendlyResourceHome(blob, home);
}

Vec2f AIB_GetHomeDropPoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;

	CMap@ map = getMap();
	const f32 ts = map is null ? 8.0f : map.tilesize;
	Vec2f base = home.getPosition() + Vec2f(0.0f, -12.0f);
	if (map is null) return base;

	Vec2f best = base;
	f32 bestScore = 999999.0f;
	for (int y = -2; y <= 2; y++)
	{
		for (int x = -3; x <= 3; x++)
		{
			Vec2f candidate = base + Vec2f(x * ts, y * ts);
			if (!AIB_HasBuilderClearance(candidate, home.getTeamNum())) continue;

			const f32 score = (candidate - base).Length();
			if (score < bestScore)
			{
				bestScore = score;
				best = candidate;
			}
		}
	}
	return best;
}

Vec2f AIB_GetBaseStoragePoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;
	Vec2f best = AIBR_FindBaseStoragePoint(home);
	return best != Vec2f_zero ? best : AIB_GetHomeDropPoint(home);
}

bool AIB_IsGroundedBaseStoragePoint(Vec2f candidate)
{
	return AIBR_IsGroundedStoragePoint(candidate);
}

Vec2f AIB_GetBuilderShopPoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;

	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	const f32 ts = map.tilesize;
	const Vec2f homeTile = map.getTileSpacePosition(home.getPosition());
	Vec2f best = Vec2f_zero;
	f32 bestScore = 999999.0f;
	CBlob@[] siteBlobs;
	getBlobs(@siteBlobs);

	// Search a real area on both sides of the base.  Clearance is measured from
	// building edges in AIB_CanBuildBaseWorkshopAt, so the first legal center is
	// much farther away than this initial search radius on a normal 5-tile tent.
	for (int distance = AIB_BASE_WORKSHOP_MIN_SEARCH_TILES; distance <= AIB_BASE_WORKSHOP_MAX_SEARCH_TILES; distance++)
	{
		for (int side = -1; side <= 1; side += 2)
		{
			for (int yOffset = -AIB_BASE_WORKSHOP_VERTICAL_SEARCH_TILES; yOffset <= AIB_BASE_WORKSHOP_VERTICAL_SEARCH_TILES; yOffset++)
			{
				const int tileX = Maths::Floor(homeTile.x) + side * distance;
				const int tileY = Maths::Floor(homeTile.y) + yOffset;
				Vec2f candidate = Vec2f((tileX + 0.5f) * ts, (tileY + 0.5f) * ts);
				if (!AIB_CanBuildBaseWorkshopAt(candidate, home, @siteBlobs)) continue;

				const u8 approaches = AIB_CountBaseWorkshopApproaches(candidate);
				const u8 deepSupport = AIB_CountBaseWorkshopDeepSupport(candidate);
				// Prefer close, level, accessible ground.  A second open side and
				// deeper terrain are useful tie-breakers, not substitutes for the
				// mandatory five-column foundation check below.
				const f32 score = float(distance) + Maths::Abs(yOffset) * 2.5f -
					float(approaches - 1) * 1.5f - float(deepSupport) * 0.15f;
				if (score < bestScore)
				{
					bestScore = score;
					best = candidate;
				}
			}
		}
	}

	return best;
}

void AIB_GetBaseWorkshopBounds(Vec2f pos, Vec2f &out upperLeft, Vec2f &out lowerRight)
{
	CMap@ map = getMap();
	const f32 ts = map is null ? 8.0f : map.tilesize;
	// BuilderShop.cfg is 40x24: five tiles wide and three tiles high.
	upperLeft = pos - Vec2f(2.5f * ts, 1.5f * ts);
	lowerRight = pos + Vec2f(2.5f * ts, 1.5f * ts);
}

bool AIB_BaseWorkshopBoundsOverlap(Vec2f aMin, Vec2f aMax, Vec2f bMin, Vec2f bMax, const f32 clearance)
{
	return aMin.x < bMax.x + clearance && aMax.x > bMin.x - clearance &&
		aMin.y < bMax.y + clearance && aMax.y > bMin.y - clearance;
}

bool AIB_IsImportantBaseBuilding(CBlob@ blob)
{
	if (blob is null || blob.hasTag("dead") || blob.isInInventory()) return false;
	if (blob.hasTag("building")) return true;

	const string name = blob.getName();
	return name == "ctf_flag" || name == "tent" || name == "hall" || name == "buildershop" ||
		name == "quarters" || name == "knightshop" || name == "archershop" ||
		name == "boatshop" || name == "vehicleshop" || name == "aibuildershop" ||
		name == "nursery" || name == "storage" || name == "tunnel" || name == "quarry" ||
		name == "crate";
}

bool AIB_HasBaseWorkshopBuildingClearance(Vec2f pos, CBlob@ home, CBlob@[]@ blobs)
{
	CMap@ map = getMap();
	if (map is null || home is null || blobs is null) return false;

	Vec2f siteMin, siteMax;
	AIB_GetBaseWorkshopBounds(pos, siteMin, siteMax);
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ other = blobs[i];
		if (!AIB_IsImportantBaseBuilding(other)) continue;

		const string name = other.getName();
		const bool friendlyHome = other.getTeamNum() == home.getTeamNum() &&
			(name == "ctf_flag" || name == "tent" || name == "hall");
		const f32 clearance = (friendlyHome ? AIB_BASE_WORKSHOP_HOME_CLEARANCE_TILES :
			AIB_BASE_WORKSHOP_BUILDING_CLEARANCE_TILES) * map.tilesize;

		CShape@ otherShape = other.getShape();
		if (otherShape is null)
		{
			const Vec2f otherPos = other.getPosition();
			if (otherPos.x > siteMin.x - clearance && otherPos.x < siteMax.x + clearance &&
				otherPos.y > siteMin.y - clearance && otherPos.y < siteMax.y + clearance) return false;
			continue;
		}

		Vec2f otherMin, otherMax;
		otherShape.getBoundingRect(otherMin, otherMax);
		if (AIB_BaseWorkshopBoundsOverlap(siteMin, siteMax, otherMin, otherMax, clearance)) return false;
	}
	return true;
}

bool AIB_IgnoreBaseWorkshopOccupant(CBlob@ blob)
{
	if (blob is null || blob.hasTag("dead") || blob.isInInventory()) return true;
	if (blob.hasTag("material") || blob.hasTag("projectile")) return true;
	if (blob.hasTag("player") || blob.hasTag("flesh")) return true;

	const string name = blob.getName();
	return name == "builder" || name == "aibuilder" || name == "autobuilder" ||
		name == "knight" || name == "archer" || name == "migrant";
}

bool AIB_HasBaseWorkshopBlockingBlob(Vec2f pos, CBlob@[]@ blobs)
{
	if (blobs is null) return true;
	Vec2f siteMin, siteMax;
	AIB_GetBaseWorkshopBounds(pos, siteMin, siteMax);
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ other = blobs[i];
		if (AIB_IgnoreBaseWorkshopOccupant(other)) continue;

		CShape@ shape = other.getShape();
		if (shape is null)
		{
			const Vec2f otherPos = other.getPosition();
			if (otherPos.x > siteMin.x && otherPos.x < siteMax.x &&
				otherPos.y > siteMin.y && otherPos.y < siteMax.y) return true;
			continue;
		}

		Vec2f otherMin, otherMax;
		shape.getBoundingRect(otherMin, otherMax);
		if (!AIB_BaseWorkshopBoundsOverlap(siteMin, siteMax, otherMin, otherMax, 0.0f)) continue;

		const string name = other.getName();
		if (other.hasTag("tree") || other.hasTag("vehicle") || name == "drill" || name == "saw" ||
			shape.isStatic() || other.isCollidable()) return true;
	}
	return false;
}

bool AIB_BaseWorkshopConflictsWithBlueprint(Vec2f pos, const u8 team)
{
	CMap@ map = getMap();
	if (map is null) return true;

	array<u16>@ human = null;
	array<u16>@ desired = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::human, @human);
	AIBP_GetLayerGrid(team, AIBP_Layer::ai_desired, @desired);
	Vec2f siteMin, siteMax;
	AIB_GetBaseWorkshopBounds(pos, siteMin, siteMax);
	const f32 tileRadius = map.tilesize * 0.5f;
	const int minX = Maths::Floor((siteMin.x - tileRadius) / map.tilesize);
	const int maxX = Maths::Floor((siteMax.x + tileRadius) / map.tilesize);
	const int minY = Maths::Floor((siteMin.y - tileRadius) / map.tilesize);
	const int maxY = Maths::Floor((siteMax.y + tileRadius) / map.tilesize);
	for (int y = minY; y <= maxY; y++)
	{
		if (y < 0 || y >= map.tilemapheight) continue;
		for (int x = minX; x <= maxX; x++)
		{
			if (x < 0 || x >= map.tilemapwidth) continue;
			const uint index = y * map.tilemapwidth + x;
			const bool humanWork = human !is null && index < human.length && human[index] != 0;
			const bool directorWork = desired !is null && index < desired.length && desired[index] != 0;
			if (!humanWork && !directorWork) continue;
			Vec2f center = Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize);
			// Tile edges may touch the 40x24 shop boundary, but their interiors may
			// not overlap it. AIBS_OverlapsProtectedBlob applies this same exact
			// exception to tagged same-team storage shops after they are spawned.
			if (center.x > siteMin.x - tileRadius && center.x < siteMax.x + tileRadius &&
				center.y > siteMin.y - tileRadius && center.y < siteMax.y + tileRadius) return true;
		}
	}
	return false;
}

u8 AIB_CountBaseWorkshopApproaches(Vec2f pos)
{
	CMap@ map = getMap();
	if (map is null) return 0;

	const f32 ts = map.tilesize;
	u8 clearSides = 0;
	for (int side = -1; side <= 1; side += 2)
	{
		const Vec2f sideOffset = Vec2f(side * 3.0f * ts, 0.0f);
		Vec2f head = pos + sideOffset;
		const Vec2f foot = head + Vec2f(0.0f, ts);
		const Vec2f ground = head + Vec2f(0.0f, 2.0f * ts);
		if (!AIB_IsInsideMap(head) || !AIB_IsInsideMap(foot) || !AIB_IsInsideMap(ground)) continue;
		if (map.isTileSolid(map.getTile(head).type) || map.isTileSolid(map.getTile(foot).type)) continue;
		if (!map.isTileSolid(map.getTile(ground).type)) continue;
		clearSides++;
	}
	return clearSides;
}

u8 AIB_CountBaseWorkshopDeepSupport(Vec2f pos)
{
	CMap@ map = getMap();
	if (map is null) return 0;

	const f32 ts = map.tilesize;
	u8 supported = 0;
	for (int x = -2; x <= 2; x++)
	{
		Vec2f belowFoundation = pos + Vec2f(x * ts, 3.0f * ts);
		if (AIB_IsInsideMap(belowFoundation) && map.isTileSolid(map.getTile(belowFoundation).type)) supported++;
	}
	return supported;
}

bool AIB_CanBuildBaseWorkshopAt(Vec2f pos, CBlob@ home)
{
	CBlob@[] siteBlobs;
	getBlobs(@siteBlobs);
	return AIB_CanBuildBaseWorkshopAt(pos, home, @siteBlobs);
}

bool AIB_CanBuildBaseWorkshopAt(Vec2f pos, CBlob@ home, CBlob@[]@ siteBlobs)
{
	CMap@ map = getMap();
	if (map is null || home is null || pos == Vec2f_zero) return false;
	if (!AIB_IsInsideCurrentBarrierZone(home, pos)) return false;
	if (AIB_BaseWorkshopConflictsWithBlueprint(pos, u8(home.getTeamNum()))) return false;

	const f32 ts = map.tilesize;
	// The entire 5x3 volume must be empty.  Unlike a normal tile placement, the
	// direct blob spawn does not clear grass or terrain outside its anchor.
	for (int x = -2; x <= 2; x++)
	{
		for (int y = -1; y <= 1; y++)
		{
			Vec2f footprint = pos + Vec2f(x * ts, y * ts);
			if (!AIB_IsInsideMap(footprint)) return false;
			if (!AIB_IsInsideCurrentBarrierZone(home, footprint)) return false;
			if (map.getSectorAtPosition(footprint, "no build") !is null) return false;
			const TileType type = map.getTile(footprint).type;
			if (map.isTileSolid(type)) return false;
		}

		// Every bottom column must sit immediately on solid terrain/support.  This
		// prevents a visually plausible center tile from hiding a cliff or hole
		// under either edge of the 40px-wide shop.
		Vec2f foundation = pos + Vec2f(x * ts, 2.0f * ts);
		if (!AIB_IsInsideMap(foundation)) return false;
		if (!map.isTileSolid(map.getTile(foundation).type)) return false;
	}

	if (AIB_CountBaseWorkshopApproaches(pos) == 0) return false;
	if (!AIB_HasBaseWorkshopBuildingClearance(pos, home, siteBlobs)) return false;
	return !AIB_HasBaseWorkshopBlockingBlob(pos, siteBlobs);
}

bool AIB_DropInitialResourcesAtHome(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return false;
	Vec2f storage = AIB_GetBaseStoragePoint(home);
	if (storage == Vec2f_zero) return false;
	const u16 wood = AIB_CountMaterial(blob, "mat_wood");
	const u16 stone = AIB_CountMaterial(blob, "mat_stone");
	const u16 gold = AIB_CountMaterial(blob, "mat_gold");
	AIB_DropAllResourcesAtPosition(blob, storage);
	if (AIB_HasAnyResource(blob)) return false;
	AIB_LogEvent("ai", "store_resources_loose", AIB_EventBlobRef(blob),
		"home=" + AIB_EventBlobRef(home) + " reason=no_initial_crate wood=" + wood +
		" stone=" + stone + " gold=" + gold + " pos=" + AIB_EventPos(storage));
	return true;
}

bool AIB_StoreResourcesInBaseCrates(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return false;

	AIB_StashCarriedResource(blob);

	CBlob@ shop = AIB_GetBestBaseBuilderShop(home, blob.getPosition());
	if (shop is null)
	{
		@shop = AIB_BuildBaseBuilderShop(blob, home);
	}
	blob.set_netid("ai builder base storage shop", shop is null ? 0 : shop.getNetworkID());

	for (u8 i = 0; i < 8 && AIB_HasAnyResource(blob); i++)
	{
		CBlob@ crate = AIB_GetBestBaseResourceCrate(blob, home);
		if (crate is null)
		{
			const bool hasBaseCrate = AIB_CountBaseResourceCrates(home) > 0;
			if (shop is null)
			{
				// A base with no storage must still be able to finish its first
				// resource episode. The free runner can afford the workshop but not
				// the 150-wood crate, and waiting here deadlocks a one-worker team.
				// Existing/full-crate overflow remains crate-only so its capacity and
				// conservation contract is not weakened by this bootstrap fallback.
				if (!hasBaseCrate) return AIB_DropInitialResourcesAtHome(blob, home);
				return false;
			}
			@crate = AIB_BuyBaseResourceCrate(blob, home, shop);
			if (crate is null)
			{
				if (!hasBaseCrate) return AIB_DropInitialResourcesAtHome(blob, home);
				return false;
			}
		}

		if (!AIB_PutResourcesInCrate(blob, crate))
		{
			crate.Tag("aibuilder full resource crate");
			crate.set_u32(AIB_CRATE_CAPACITY_RETRY_KEY, getGameTime() + AIB_CRATE_CAPACITY_RETRY_TICKS);
		}
	}

	return !AIB_HasAnyResource(blob);
}

CBlob@ AIB_GetBestBaseBuilderShop(CBlob@ home, Vec2f reference)
{
	CMap@ map = getMap();
	if (home is null || map is null) return null;

	Vec2f homePosition = home.getPosition();
	Vec2f storage = AIBR_FindBaseStoragePoint(home);
	if (storage == Vec2f_zero) storage = homePosition;
	if (reference == Vec2f_zero) reference = homePosition;
	const f32 maxHomeDistance = AIB_BASE_WORKSHOP_EXISTING_RADIUS_TILES * map.tilesize;
	CBlob@ best = null;
	f32 bestScore = 999999.0f;
	u16 bestID = 65535;
	CBlob@[] shops;
	getBlobsByName("buildershop", @shops);
	for (uint i = 0; i < shops.length; i++)
	{
		CBlob@ shop = shops[i];
		if (shop is null || shop.hasTag("dead") || shop.isAttached() || shop.isInInventory()) continue;
		if (shop.getTeamNum() != home.getTeamNum() || shop.exists("packed")) continue;
		Vec2f shopPosition = shop.getPosition();
		if (!AIBR_IsOnSameBarrierSide(home, shopPosition)) continue;
		if ((shopPosition - homePosition).Length() > maxHomeDistance) continue;

		const f32 score = (shopPosition - storage).Length() + (shopPosition - reference).Length() * 0.05f;
		const u16 id = shop.getNetworkID();
		if (score + 0.001f < bestScore || (Maths::Abs(score - bestScore) <= 0.001f && id < bestID))
		{
			bestScore = score;
			bestID = id;
			@best = shop;
		}
	}
	return best;
}

CBlob@ AIB_BuildBaseBuilderShop(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return null;
	if (AIB_CountWood(blob) < AIB_BUILDER_SHOP_WOOD_COST) return null;
	const u32 now = getGameTime();
	const string retryKey = "ai builder next workshop site search";
	if (now < blob.get_u32(retryKey)) return null;

	Vec2f buildPos = AIB_GetBuilderShopPoint(home);
	if (buildPos == Vec2f_zero || !AIB_CanBuildBaseWorkshopAt(buildPos, home))
	{
		blob.set_u32(retryKey, now + AIB_BASE_WORKSHOP_RETRY_TICKS);
		AIB_Debug(blob, "no supported ground available for base builder shop");
		return null;
	}
	// Pay only after the site is revalidated. Unlike a loose crate, a workshop's
	// initialization can mutate its footprint/background, so create it as a paid
	// object and refund the exact cost if the engine rejects the spawn.
	if (!AIB_TakeMaterial(blob, "mat_wood", AIB_BUILDER_SHOP_WOOD_COST)) return null;
	CBlob@ shop = server_CreateBlob("buildershop", blob.getTeamNum(), buildPos);
	if (shop is null)
	{
		u16 refund = AIB_BUILDER_SHOP_WOOD_COST;
		string refundName = "mat_wood";
		Material::createFor(blob, refundName, refund);
		blob.set_u32(retryKey, now + AIB_BASE_WORKSHOP_RETRY_TICKS);
		return null;
	}

	blob.set_u32(retryKey, 0);
	shop.Tag("aibuilder built storage shop");
	AIB_LogEvent("ai", "build_storage_shop", AIB_EventBlobRef(blob), "shop=" + AIB_EventBlobRef(shop) + " pos=" + AIB_EventPos(shop.getPosition()));
	return shop;
}

CBlob@ AIB_BuyBaseResourceCrate(CBlob@ blob, CBlob@ home, CBlob@ shop)
{
	if (blob is null || home is null || shop is null) return null;
	Vec2f cratePoint = AIB_GetNextBaseCratePoint(home);
	if (cratePoint == Vec2f_zero || !AIB_CanFundBaseCrate(blob, home)) return null;

	// Create only after validating the site and available funding, but pay only
	// after creation succeeds.  This keeps a failed engine spawn from consuming
	// 150 wood with no storage outcome.
	CBlob@ crate = server_CreateBlob("crate", blob.getTeamNum(), cratePoint);
	if (crate is null) return null;
	if (!AIB_PayForBaseCrate(blob, home))
	{
		crate.server_Die();
		return null;
	}

	crate.Tag("aibuilder resource crate");
	AIB_LogEvent("ai", "buy_storage_crate", AIB_EventBlobRef(blob), "shop=" + AIB_EventBlobRef(shop) + " crate=" + AIB_EventBlobRef(crate) + " pos=" + AIB_EventPos(crate.getPosition()));
	return crate;
}

bool AIB_IsNurseryState(const u8 state)
{
	return state >= AIBuilderState::nursery_collect_wood && state <= AIBuilderState::nursery_wait_tree;
}

bool AIB_CanStartNurseryQuest(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return false;
	const u32 wood = u32(AIB_CountMaterial(blob, "mat_wood")) + u32(AIB_CountHomeMaterial(home, "mat_wood"));
	const u32 stone = u32(AIB_CountMaterial(blob, "mat_stone")) + u32(AIB_CountHomeMaterial(home, "mat_stone"));
	const bool canAcquireSeedStone = stone >= AIB_NURSERY_SEED_STONE_COST ||
		AIB_GetNearestStoneMat(blob) !is null || AIB_GetBestStoneTile(blob) != Vec2f_zero;
	CBlob@ nursery = AIB_GetNearestTeamBlob(blob, "nursery");
	// A half-funded nursery diverts a wood runner forever and can consume the
	// first harvest before the base has any useful reserve. Enter the durable
	// quest only when its next material leg is already executable.
	return nursery !is null ? canAcquireSeedStone :
		wood >= AIB_NURSERY_WOOD_COST && canAcquireSeedStone;
}

void AIB_NurseryCollectWood(CBrain@ brain, CBlob@ blob)
{
	CBlob@ nursery = AIB_GetNearestTeamBlob(blob, "nursery");
	if (nursery !is null)
	{
		AIB_SetState(blob, AIBuilderState::nursery_collect_stone, "team nursery already exists");
		return;
	}

	if (AIB_CountWood(blob) >= AIB_NURSERY_WOOD_COST)
	{
		AIB_SetState(blob, AIBuilderState::nursery_build, "nursery wood acquired");
		return;
	}

	CBlob@ home = AIB_GetTeamHome(blob);
	if (AIB_CollectQuestMaterial(brain, blob, home, "mat_wood")) return;

	CBlob@ log = AIB_GetNearestLog(blob);
	if (log !is null)
	{
		brain.SetTarget(log);
		blob.set_netid("ai builder target", log.getNetworkID());
		AIB_SetState(blob, AIBuilderState::chop_log, "using loose log for nursery wood");
		return;
	}

	AIB_Debug(blob, "nursery quest waiting for wood");
	AIB_ReportWaitingStatus(blob, "Waiting for nursery wood");
}

void AIB_NurseryBuild(CBrain@ brain, CBlob@ blob)
{
	CBlob@ nursery = AIB_GetNearestTeamBlob(blob, "nursery");
	if (nursery !is null)
	{
		AIB_SetState(blob, AIBuilderState::nursery_collect_stone, "nursery became available");
		return;
	}

	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null)
	{
		AIB_SetState(blob, AIBuilderState::nursery_collect_wood, "no team home for nursery");
		return;
	}

	if (AIB_CountWood(blob) < AIB_NURSERY_WOOD_COST)
	{
		AIB_SetState(blob, AIBuilderState::nursery_collect_wood, "nursery wood missing");
		return;
	}

	Vec2f buildPos = AIB_GetNurseryPoint(home);
	if ((buildPos - blob.getPosition()).Length() > 34.0f)
	{
		AIB_GoTo(brain, blob, buildPos);
		return;
	}

	if (!AIB_TakeMaterial(blob, "mat_wood", AIB_NURSERY_WOOD_COST))
	{
		AIB_SetState(blob, AIBuilderState::nursery_collect_wood, "failed to spend nursery wood");
		return;
	}

	@nursery = server_CreateBlob("nursery", blob.getTeamNum(), buildPos);
	if (nursery is null)
	{
		string refundMaterial = "mat_wood";
		u16 refundAmount = AIB_NURSERY_WOOD_COST;
		Material::createFor(blob, refundMaterial, refundAmount);
		AIB_SetState(blob, AIBuilderState::nursery_collect_wood, "nursery creation failed");
		return;
	}

	nursery.Tag("aibuilder built nursery");
	AIB_LogEvent("ai", "build_nursery", AIB_EventBlobRef(blob), "nursery=" + AIB_EventBlobRef(nursery) + " pos=" + AIB_EventPos(buildPos) + " cost_wood=" + AIB_NURSERY_WOOD_COST);
	AIB_SetState(blob, AIBuilderState::nursery_collect_stone, "nursery built");
}

void AIB_NurseryCollectStone(CBrain@ brain, CBlob@ blob)
{
	if (AIB_CountStone(blob) >= AIB_NURSERY_SEED_STONE_COST)
	{
		AIB_StashCarriedResource(blob);
		AIB_SetState(blob, AIBuilderState::nursery_buy_seed, "seed stone acquired");
		return;
	}

	CBlob@ home = AIB_GetTeamHome(blob);
	if (AIB_CollectQuestMaterial(brain, blob, home, "mat_stone")) return;

	CMap@ map = getMap();
	if (map is null) return;
	AIB_CollectNearbyStone(blob);
	if (AIB_CountStone(blob) >= AIB_NURSERY_SEED_STONE_COST) return;

	Vec2f target = blob.get_Vec2f("ai builder tile target");
	if (target == Vec2f_zero || !AIB_IsStoneTile(target))
	{
		target = AIB_GetBestStoneTile(blob);
		blob.set_Vec2f("ai builder tile target", target);
		if (target == Vec2f_zero)
		{
			AIB_ReportWaitingStatus(blob, "Waiting for nursery stone");
			AIB_Debug(blob, "nursery quest waiting for stone");
			return;
		}
		blob.set_Vec2f("ai builder stone route corner", AIB_GetBestStoneRouteCorner(blob, target));
	}

	Vec2f center = AIB_TileCenter(target);
	Vec2f routeDestination = AIB_GetStoneRouteDestination(blob, target);
	Vec2f routeCorner = blob.get_Vec2f("ai builder stone route corner");
	Vec2f clearanceTile = AIB_GetStoneRouteClearanceTile(blob, target, routeCorner, routeDestination);
	if (clearanceTile != Vec2f_zero && AIB_IsNonMineableStoneRouteBlock(clearanceTile) &&
		AIB_IsTileOnStoneRoute(blob, target, routeCorner, clearanceTile))
	{
		AIB_RecomputeStoneRouteAroundBlock(brain, blob, target, clearanceTile);
		return;
	}
	if (clearanceTile != Vec2f_zero && AIB_CanMineStoneRouteClearance(blob, target, clearanceTile))
	{
		Vec2f clearanceCenter = AIB_TileCenter(clearanceTile);
		if ((clearanceCenter - blob.getPosition()).Length() <= 40.0f)
		{
			AIB_MineTile(blob, clearanceTile);
		}
		else
		{
			if (AIB_DriveStoneRouteShaft(brain, blob, target, routeCorner)) return;
			AIB_GoTo(brain, blob, clearanceCenter);
		}
		return;
	}

	Vec2f blockingTile = AIB_GetBlockingTileTowardStone(blob, routeDestination);
	if (blockingTile != Vec2f_zero && AIB_IsNonMineableStoneRouteBlock(blockingTile) &&
		AIB_IsTileOnStoneRoute(blob, target, routeCorner, blockingTile))
	{
		AIB_RecomputeStoneRouteAroundBlock(brain, blob, target, blockingTile);
		return;
	}
	if (blockingTile != Vec2f_zero && (blockingTile - target).Length() > 1.0f &&
		AIB_CanMineStoneRouteClearance(blob, target, blockingTile))
	{
		Vec2f blockingCenter = AIB_TileCenter(blockingTile);
		if ((blockingCenter - blob.getPosition()).Length() <= 40.0f)
		{
			AIB_MineTile(blob, blockingTile);
			return;
		}
	}

	if ((center - blob.getPosition()).Length() <= 40.0f)
	{
		AIB_MineTile(blob, target);
		return;
	}

	Vec2f routeCenter = AIB_TileCenter(routeDestination);
	const bool atOreSegment = (routeCenter - center).Length() < 1.0f;
	Vec2f approach = atOreSegment ? AIB_GetApproachPositionForStone(blob, target) : routeCenter;
	const bool shouldDig = (atOreSegment && (approach - routeCenter).Length() <= 1.0f) ||
		blob.get_u8("ai builder obstruction threshold") > 8 ||
		brain.getState() == CBrain::stuck || brain.getState() == CBrain::wrong_path;
	if (shouldDig)
	{
		Vec2f dig = AIB_GetNextTunnelTile(blob, target, routeCorner, routeDestination);
		if (dig != Vec2f_zero && AIB_IsNonMineableStoneRouteBlock(dig) &&
			AIB_IsTileOnStoneRoute(blob, target, routeCorner, dig))
		{
			AIB_RecomputeStoneRouteAroundBlock(brain, blob, target, dig);
			return;
		}
		if (dig != Vec2f_zero && AIB_CanMineStoneRouteClearance(blob, target, dig))
		{
			Vec2f digCenter = AIB_TileCenter(dig);
			if ((digCenter - blob.getPosition()).Length() <= 40.0f)
			{
				AIB_MineTile(blob, dig);
			}
			else
			{
				if (AIB_DriveStoneRouteShaft(brain, blob, target, routeCorner)) return;
				AIB_GoTo(brain, blob, digCenter);
			}
			return;
		}
	}
	if (AIB_DriveStoneRouteShaft(brain, blob, target, routeCorner)) return;
	blob.set_bool("ai builder direct stone shaft", false);
	AIB_GoTo(brain, blob, approach);
}

void AIB_NurseryBuySeed(CBrain@ brain, CBlob@ blob)
{
	CBlob@ nursery = AIB_GetNearestTeamBlob(blob, "nursery");
	if (nursery is null)
	{
		AIB_SetState(blob, AIBuilderState::nursery_collect_wood, "nursery missing before seed purchase");
		return;
	}

	if (AIB_GetNurserySeed(blob) !is null)
	{
		AIB_SetState(blob, AIBuilderState::nursery_plant_seed, "tree seed already held");
		return;
	}

	AIB_StashCarriedResource(blob);
	if (AIB_CountStone(blob) < AIB_NURSERY_SEED_STONE_COST)
	{
		AIB_SetState(blob, AIBuilderState::nursery_collect_stone, "seed stone missing");
		return;
	}

	if ((nursery.getPosition() - blob.getPosition()).Length() > 34.0f)
	{
		AIB_GoTo(brain, blob, nursery.getPosition());
		return;
	}

	if (!AIB_TakeMaterial(blob, "mat_stone", AIB_NURSERY_SEED_STONE_COST))
	{
		AIB_SetState(blob, AIBuilderState::nursery_collect_stone, "failed to spend seed stone");
		return;
	}

	CBlob@ seed = server_MakeSeed(blob.getPosition(), "tree_pine", 600, 2, 4);
	if (seed is null)
	{
		string refundMaterial = "mat_stone";
		u16 refundAmount = AIB_NURSERY_SEED_STONE_COST;
		Material::createFor(blob, refundMaterial, refundAmount);
		AIB_SetState(blob, AIBuilderState::nursery_collect_stone, "seed creation failed");
		return;
	}

	seed.Tag("aibuilder nursery seed");
	seed.set_netid("aibuilder nursery owner", blob.getNetworkID());
	if (!blob.server_PutInInventory(seed))
	{
		blob.server_Pickup(seed);
	}
	blob.set_netid("ai builder target", seed.getNetworkID());
	AIB_LogEvent("ai", "buy_seed", AIB_EventBlobRef(blob), "nursery=" + AIB_EventBlobRef(nursery) + " seed=" + AIB_EventBlobRef(seed) + " cost_stone=" + AIB_NURSERY_SEED_STONE_COST);
	AIB_SetState(blob, AIBuilderState::nursery_plant_seed, "tree seed purchased");
}

void AIB_NurseryPlantSeed(CBrain@ brain, CBlob@ blob)
{
	CBlob@ seed = AIB_GetNurserySeed(blob);
	if (seed is null)
	{
		AIB_SetState(blob, AIBuilderState::nursery_buy_seed, "nursery seed missing");
		return;
	}

	Vec2f plantPos = blob.get_Vec2f("ai builder destination");
	if (plantPos == Vec2f_zero || !AIB_IsValidSeedPosition(plantPos))
	{
		plantPos = AIB_GetNurseryPlantPosition(blob);
		blob.set_Vec2f("ai builder destination", plantPos);
	}
	if (plantPos == Vec2f_zero)
	{
		AIB_ReportWaitingStatus(blob, "Waiting for a planting tile");
		AIB_Debug(blob, "nursery quest waiting for a valid planting tile");
		return;
	}

	if ((plantPos - blob.getPosition()).Length() > 22.0f)
	{
		AIB_GoTo(brain, blob, plantPos);
		return;
	}

	if (seed.isInInventory())
	{
		CBlob@ releasedSeed = blob.server_PutOutInventory("seed");
		if (releasedSeed !is null) @seed = releasedSeed;
	}
	if (seed.isAttached()) seed.server_DetachFrom(blob);
	seed.setPosition(plantPos);
	seed.setVelocity(Vec2f_zero);
	seed.Tag("aibuilder planted seed");
	blob.set_netid("ai builder target", seed.getNetworkID());
	blob.set_u32("ai builder nursery wait until", getGameTime() + 900);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	AIB_LogEvent("ai", "plant_seed", AIB_EventBlobRef(blob), "seed=" + AIB_EventBlobRef(seed) + " pos=" + AIB_EventPos(plantPos));
	AIB_SetState(blob, AIBuilderState::nursery_wait_tree, "tree seed planted");
}

void AIB_NurseryWaitForTree(CBrain@ brain, CBlob@ blob)
{
	CBlob@ tree = AIB_GetNearestAccessibleTreeIgnoringMaturity(blob);
	if (tree !is null)
	{
		if (AIB_IsTreeHarvestReady(tree))
		{
			blob.set_netid("ai builder target", 0);
			AIB_SetState(blob, AIBuilderState::find_tree, "nursery tree mature");
		}
		else
		{
			AIB_ReportWaitingStatus(blob, "Waiting for the nursery tree to mature");
		}
		return;
	}

	CBlob@ seed = getBlobByNetworkID(blob.get_netid("ai builder target"));
	if (seed !is null && seed.getName() == "seed")
	{
		if ((seed.getPosition() - blob.getPosition()).Length() > 48.0f)
		{
			AIB_GoTo(brain, blob, seed.getPosition());
		}
		AIB_ReportWaitingStatus(blob, "Waiting for the nursery tree");
		return;
	}

	if (getGameTime() >= blob.get_u32("ai builder nursery wait until"))
	{
		AIB_SetState(blob, AIBuilderState::find_tree, "nursery seed wait ended");
	}
}

bool AIB_CollectQuestMaterial(CBrain@ brain, CBlob@ blob, CBlob@ home, const string &in name)
{
	CBlob@ material = home is null ? null : AIB_GetHomeMaterial(blob, home, name);
	if (material is null)
	{
		CBlob@[] materials;
		getBlobsByName(name, @materials);
		@material = AIB_GetNearest(blob, @materials);
	}
	if (material is null) return false;

	if ((material.getPosition() - blob.getPosition()).Length() > 18.0f)
	{
		AIB_GoTo(brain, blob, material.getPosition());
		return true;
	}

	if (home !is null && material.getName() == "crate")
	{
		AIB_CollectHomeMaterial(blob, home, name);
		return true;
	}

	if (!blob.server_PutInInventory(material))
	{
		blob.server_Pickup(material);
		AIB_StashCarriedResource(blob);
	}
	return true;
}

CBlob@ AIB_GetNurserySeed(CBlob@ blob)
{
	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == "seed" && carried.hasTag("aibuilder nursery seed")) return carried;

	CInventory@ inv = blob.getInventory();
	if (inv is null) return null;
	for (uint i = 0; i < inv.getItemsCount(); i++)
	{
		CBlob@ item = inv.getItem(i);
		if (item !is null && item.getName() == "seed" && item.hasTag("aibuilder nursery seed")) return item;
	}
	return null;
}

Vec2f AIB_GetNurseryPoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;
	CMap@ map = getMap();
	const f32 ts = map is null ? 8.0f : map.tilesize;
	return AIB_GetBaseStoragePoint(home) + Vec2f(11.0f * ts, 0.0f);
}

Vec2f AIB_GetNurseryPlantPosition(CBlob@ blob)
{
	CBlob@ home = AIB_GetTeamHome(blob);
	CBlob@ tree = AIB_GetNearestTreeIgnoringSelection(blob);
	Vec2f anchor = home is null ? blob.getPosition() : home.getPosition();
	if (tree !is null && (tree.getPosition() - blob.getPosition()).Length() < (anchor - blob.getPosition()).Length())
	{
		anchor = tree.getPosition();
	}

	return AIBGuide_FindTreeFarmPosition(anchor);
}

bool AIB_IsValidSeedPosition(Vec2f pos)
{
	return AIBGuide_IsNaturalTreeFarmPosition(pos);
}

bool AIB_TryMaintainBaseQuarry(CBrain@ brain, CBlob@ blob, CBlob@ home)
{
	if (brain is null || blob is null || home is null) return false;
	if (AIB_GetBestStoneTile(blob) != Vec2f_zero) return false;
	CBlob@ looseStone = AIB_GetNearestStoneMat(blob);
	// Stone sitting at the exact resource home is construction funding, not
	// evidence that a sustainable quarry source already exists.
	if (looseStone !is null && !AIB_IsBaseStoneSource(blob, looseStone)) return false;

	CBlob@ quarry = AIB_GetBestBaseQuarry(blob, home);
	if (quarry is null)
	{
		@quarry = AIB_BuildBaseQuarry(blob, home);
		if (quarry is null) return false;
	}

	if ((quarry.getPosition() - blob.getPosition()).Length() > 42.0f)
	{
		AIB_GoTo(brain, blob, quarry.getPosition());
		return true;
	}

	s16 fuel = quarry.get_s16("fuel_level");
	if (fuel >= AIB_QUARRY_REFUEL_BELOW) return false;

	const u16 available = AIB_CountHomeMaterial(home, "mat_wood");
	if (available < AIB_QUARRY_FUEL_BATCH) return false;

	const u16 amount = Maths::Min(AIB_QUARRY_FUEL_BATCH, Maths::Min(available, u16(AIB_QUARRY_MAX_FUEL - fuel)));
	if (amount == 0) return false;
	if (!AIB_TakeHomeMaterial(home, "mat_wood", amount)) return false;

	quarry.set_s16("fuel_level", fuel + amount);
	quarry.Sync("fuel_level", true);
	AIB_LogEvent("ai", "feed_quarry", AIB_EventBlobRef(blob), "quarry=" + AIB_EventBlobRef(quarry) + " wood=" + amount + " fuel=" + quarry.get_s16("fuel_level"));
	return false;
}

CBlob@ AIB_GetLooseBaseStoneSource(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return null;

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	CBlob@[] stone;
	getBlobsByName("mat_stone", @stone);
	for (uint i = 0; i < stone.length; i++)
	{
		CBlob@ candidate = stone[i];
		if (!AIBR_IsLooseHomeMaterial(home, candidate)) continue;
		if (!AIB_IsBaseStoneSource(blob, candidate)) continue;

		const f32 distance = (candidate.getPosition() - blob.getPosition()).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}
	return best;
}

bool AIB_TryUseBaseStoneSource(CBrain@ brain, CBlob@ blob)
{
	if (brain is null || blob is null) return false;

	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null)
	{
		AIB_ReportWaitingStatus(blob, "Waiting for a team home");
		return true;
	}

	// A stone runner may collect fresh loose quarry/fallback output, but must
	// never withdraw crated stock. Crated stone is a completed delivery; taking
	// it immediately starts a return/reclaim loop with no resource outcome.
	CBlob@ storedStone = AIB_GetLooseBaseStoneSource(blob, home);
	if (storedStone !is null)
	{
		const f32 pickupDistance = storedStone.getName() == "crate" ? 28.0f : 18.0f;
		if ((storedStone.getPosition() - blob.getPosition()).Length() > pickupDistance)
		{
			AIB_GoTo(brain, blob, storedStone.getPosition());
			return true;
		}

		blob.setAimPos(storedStone.getPosition());
		blob.setKeyPressed(key_action3, true);
		if (AIB_CollectHomeMaterial(blob, home, "mat_stone"))
		{
			AIB_SetState(blob, AIBuilderState::return_wood, "collected base stone supply");
		}
		else
		{
			AIB_ReportWaitingStatus(blob, "Waiting for stone supply");
		}
		return true;
	}

	CBlob@ quarry = AIB_GetBestBaseQuarry(blob, home);
	if (quarry is null)
	{
		@quarry = AIB_BuildBaseQuarry(blob, home);
	}

	if (quarry !is null)
	{
		if ((quarry.getPosition() - blob.getPosition()).Length() > 42.0f)
		{
			AIB_GoTo(brain, blob, quarry.getPosition());
			return true;
		}
		// Interaction-range waiting/refuelling is stationary work. Retire the
		// completed approach so the monitor does not see stale movement intent.
		brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		blob.set_bool("ai builder justgo", false);

		const s16 fuel = quarry.get_s16("fuel_level");
		if (fuel < AIB_QUARRY_REFUEL_BELOW && AIB_CountHomeMaterial(home, "mat_wood") >= AIB_QUARRY_FUEL_BATCH)
		{
			const u16 amount = Maths::Min(AIB_QUARRY_FUEL_BATCH, Maths::Min(AIB_CountHomeMaterial(home, "mat_wood"), u16(AIB_QUARRY_MAX_FUEL - fuel)));
			if (amount > 0 && AIB_TakeHomeMaterial(home, "mat_wood", amount))
			{
				quarry.set_s16("fuel_level", fuel + amount);
				quarry.Sync("fuel_level", true);
				AIB_LogEvent("ai", "feed_quarry", AIB_EventBlobRef(blob), "quarry=" + AIB_EventBlobRef(quarry) + " wood=" + amount + " fuel=" + quarry.get_s16("fuel_level"));
			}
		}

		if (quarry.get_s16("fuel_level") >= AIB_QUARRY_MIN_WORKING_FUEL)
		{
			AIB_ReportWaitingStatus(blob, "Waiting for quarry stone");
		}
		else
		{
			AIB_ReportWaitingStatus(blob, "Waiting for quarry fuel");
		}
		return true;
	}

	Vec2f waitPoint = AIB_GetStoneSupplyWaitPoint(home);
	if ((waitPoint - blob.getPosition()).Length() > 34.0f)
	{
		AIB_GoTo(brain, blob, waitPoint);
		return true;
	}
	// The fallback supply timer is an explicit stationary wait. Retire the
	// completed approach at its interaction radius just like the quarry branch;
	// otherwise a route-reserved miner retains movement intent while correctly
	// waiting for another shaft or the next generated supply batch.
	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_bool("ai builder justgo", false);

	if (AIB_CreateBaseStoneSupply(blob, home, waitPoint))
	{
		AIB_SetState(blob, AIBuilderState::find_stone_mat, "base stone supply arrived");
	}
	else
	{
		AIB_ReportWaitingStatus(blob, "Waiting for stone supply");
	}
	return true;
}

Vec2f AIB_GetStoneSupplyWaitPoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;
	Vec2f storage = AIB_GetBaseStoragePoint(home);
	CBlob@ best = AIB_GetBestBaseBuilderShop(home, storage);
	return best !is null ? best.getPosition() : AIB_GetHomeDropPoint(home);
}

bool AIB_CreateBaseStoneSupply(CBlob@ blob, CBlob@ home, Vec2f point)
{
	if (blob is null || home is null) return false;

	const u32 now = getGameTime();
	if (blob.get_u32("ai builder next stone supply") == 0)
	{
		blob.set_u32("ai builder next stone supply", now + AIB_STONE_SUPPLY_DELAY);
		return false;
	}
	if (now < blob.get_u32("ai builder next stone supply")) return false;
	blob.set_u32("ai builder next stone supply", now + AIB_STONE_SUPPLY_DELAY);

	CBlob@ stone = server_CreateBlob("mat_stone", home.getTeamNum(), point);
	if (stone is null) return false;
	stone.server_SetQuantity(AIB_STONE_SUPPLY_AMOUNT);
	stone.Tag("aibuilder stone supply");
	AIB_LogEvent("ai", "stone_supply", AIB_EventBlobRef(blob), "stone=" + AIB_EventBlobRef(stone) + " quantity=" + AIB_STONE_SUPPLY_AMOUNT + " pos=" + AIB_EventPos(point));
	return true;
}

CBlob@ AIB_BuildBaseQuarry(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return null;
	const u32 now = getGameTime();
	const string retryKey = "ai builder next quarry site search";
	if (now < blob.get_u32(retryKey)) return null;
	// Raw server_CreateBlob bypasses the conversion shop's "no more" rule.
	// Enforce KAG's one-quarry-per-team contract before site work or payment,
	// including a quarry built by a player at another base.
	if (!AIBGuide_CanCreateTeamQuarry(blob.getTeamNum()))
	{
		blob.set_u32(retryKey, now + AIB_BASE_WORKSHOP_RETRY_TICKS);
		return null;
	}
	Vec2f buildPos = AIB_GetQuarryPoint(home);
	if (buildPos == Vec2f_zero || !AIB_CanBuildBaseWorkshopAt(buildPos, home))
	{
		blob.set_u32(retryKey, now + AIB_BASE_WORKSHOP_RETRY_TICKS);
		return null;
	}
	if (AIB_CountHomeMaterial(home, "mat_wood") < AIB_QUARRY_WOOD_COST + AIB_QUARRY_FUEL_BATCH ||
		AIB_CountHomeMaterial(home, "mat_stone") < AIB_QUARRY_STONE_COST ||
		AIB_CountHomeMaterial(home, "mat_gold") < AIB_QUARRY_GOLD_COST) return null;
	if (!AIB_TakeHomeBlueprintMaterials(home, AIBP_QUARRY)) return null;

	CBlob@ quarry = server_CreateBlob("quarry", blob.getTeamNum(), buildPos);
	if (quarry is null)
	{
		AIB_RefundHomeBlueprintMaterials(home, AIBP_QUARRY);
		blob.set_u32(retryKey, now + AIB_BASE_WORKSHOP_RETRY_TICKS);
		return null;
	}

	blob.set_u32(retryKey, 0);
	quarry.Tag("aibuilder built quarry");
	AIB_LogEvent("ai", "build_quarry", AIB_EventBlobRef(blob), "quarry=" + AIB_EventBlobRef(quarry) +
		" pos=" + AIB_EventPos(quarry.getPosition()) + " cost={" + AIBP_BlockCostSummary(AIBP_QUARRY) + "}");
	return quarry;
}

CBlob@ AIB_GetBestBaseQuarry(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return null;

	CBlob@ best = null;
	f32 bestScore = 999999.0f;
	CBlob@[] quarries;
	getBlobsByName("quarry", @quarries);
	Vec2f base = AIB_GetBaseStoragePoint(home);
	for (uint i = 0; i < quarries.length; i++)
	{
		CBlob@ quarry = quarries[i];
		if (quarry is null || quarry.hasTag("dead")) continue;
		if (quarry.getTeamNum() != home.getTeamNum()) continue;
		if ((quarry.getPosition() - base).Length() > 176.0f) continue;
		if (!AIB_HasSupportedBaseQuarryFoundation(home, quarry.getPosition())) continue;

		const f32 score = (quarry.getPosition() - blob.getPosition()).Length();
		if (score < bestScore)
		{
			bestScore = score;
			@best = quarry;
		}
	}
	return best;
}

Vec2f AIB_GetQuarryPoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;
	// Quarry.cfg has the same 40x24 footprint as the base workshops and emits
	// ore one tile left of center. Reuse the full supported-site selector so its
	// complete footprint and output column stay over solid foundation.
	return AIB_GetBuilderShopPoint(home);
}

u8 AIB_CountSeedsNear(Vec2f pos, const f32 radius)
{
	u8 count = 0;
	CBlob@[] seeds;
	getBlobsByName("seed", @seeds);
	for (uint i = 0; i < seeds.length; i++)
	{
		CBlob@ seed = seeds[i];
		if (seed is null || seed.hasTag("dead")) continue;
		if ((seed.getPosition() - pos).Length() <= radius) count++;
	}
	return count;
}

Vec2f AIB_GetNextBaseCratePoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;
	Vec2f base = AIB_GetBaseStoragePoint(home);
	CMap@ map = getMap();
	if (map is null || base == Vec2f_zero) return Vec2f_zero;
	const f32 ts = map.tilesize;
	// Search the current storage shelf and both sides.  The old `count * 2.5
	// tiles` offset could put a paid crate into a wall, pit, or outside the
	// 128-pixel base-storage radius on uneven maps.
	for (int distance = 0; distance <= AIB_BASE_CRATE_MAX_SEARCH_TILES; distance++)
	{
		const int sideCount = distance == 0 ? 1 : 2;
		for (int sideIndex = 0; sideIndex < sideCount; sideIndex++)
		{
			const int side = sideIndex == 0 ? 1 : -1;
			for (int vertical = 0; vertical <= AIB_BASE_CRATE_VERTICAL_SEARCH_TILES; vertical++)
			{
				const int verticalCount = vertical == 0 ? 1 : 2;
				for (int verticalIndex = 0; verticalIndex < verticalCount; verticalIndex++)
				{
					const int ySign = verticalIndex == 0 ? -1 : 1;
					Vec2f candidate = base + Vec2f(side * distance * ts, ySign * vertical * ts);
					if (AIB_IsValidBaseCratePoint(home, candidate)) return candidate;
				}
			}
		}
	}
	return Vec2f_zero;
}

bool AIB_IsValidBaseCratePoint(CBlob@ home, Vec2f candidate)
{
	CMap@ map = getMap();
	if (home is null || map is null || candidate == Vec2f_zero) return false;
	if ((candidate - AIB_GetBaseStoragePoint(home)).Length() > 120.0f) return false;
	if (!AIB_IsGroundedBaseStoragePoint(candidate)) return false;
	if (map.getSectorAtPosition(candidate, "no build") !is null) return false;
	if (map.getSectorAtPosition(candidate - Vec2f(0.0f, map.tilesize), "no build") !is null) return false;

	CBlob@[] nearby;
	if (!map.getBlobsInRadius(candidate, 14.0f, @nearby)) return true;
	for (uint i = 0; i < nearby.length; i++)
	{
		CBlob@ other = nearby[i];
		if (other is null || other.hasTag("dead") || other.isInInventory() || other.isAttached()) continue;
		if (other.hasTag("material") || other.hasTag("projectile") || other.hasTag("player") || other.hasTag("flesh")) continue;
		if (other.getName() == "crate" || other.hasTag("building") || other.hasTag("vehicle") || other.isCollidable()) return false;
	}
	return true;
}

bool AIB_CanFundBaseCrate(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return false;
	CInventory@ inventory = blob.getInventory();
	const u16 spendableBuilderWood = inventory is null ? 0 : inventory.getCount("mat_wood");
	return u32(spendableBuilderWood) + u32(AIB_CountHomeMaterial(home, "mat_wood")) >= AIB_CRATE_WOOD_COST;
}

bool AIB_PayForBaseCrate(CBlob@ blob, CBlob@ home)
{
	if (!AIB_CanFundBaseCrate(blob, home)) return false;
	const u16 atHome = AIB_CountHomeMaterial(home, "mat_wood");
	const u16 fromHome = Maths::Min(u16(AIB_CRATE_WOOD_COST), atHome);
	const u16 fromBuilder = AIB_CRATE_WOOD_COST - fromHome;
	// Confirm the less reliable builder-inventory leg first. AIB_CountWood also
	// includes a carried stack, while AIB_TakeMaterial spends inventory only;
	// taking home wood first could therefore consume a partial payment and then
	// fail the builder leg. Refund the builder if the home leg unexpectedly
	// becomes unavailable so the combined payment remains conservative.
	if (fromBuilder > 0 && !AIB_TakeMaterial(blob, "mat_wood", fromBuilder)) return false;
	if (fromHome > 0 && !AIB_TakeHomeMaterial(home, "mat_wood", fromHome))
	{
		if (fromBuilder > 0)
		{
			u16 refund = fromBuilder;
			string refundName = "mat_wood";
			Material::createFor(blob, refundName, refund);
		}
		return false;
	}
	return true;
}

u8 AIB_CountBaseResourceCrates(CBlob@ home)
{
	if (home is null) return 0;

	u8 count = 0;
	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	Vec2f storage = AIBR_FindBaseStoragePoint(home);
	for (uint i = 0; i < crates.length; i++)
	{
		CBlob@ crate = crates[i];
		if (!AIB_IsBaseResourceCrate(crate, home, storage)) continue;
		count++;
	}
	return count;
}

CBlob@ AIB_GetBestBaseResourceCrate(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return null;

	CBlob@ best = null;
	f32 bestScore = 999999.0f;
	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	Vec2f storage = AIBR_FindBaseStoragePoint(home);
	for (uint i = 0; i < crates.length; i++)
	{
		CBlob@ crate = crates[i];
		if (!AIB_IsBaseResourceCrate(crate, home, storage)) continue;
		if (crate.hasTag("aibuilder full resource crate"))
		{
			if (getGameTime() < crate.get_u32(AIB_CRATE_CAPACITY_RETRY_KEY)) continue;
			// Capacity can change when a player withdraws an item. Retry the real
			// insertion periodically instead of trusting a stale diagnostic tag.
			crate.Untag("aibuilder full resource crate");
		}

		const f32 score = (crate.getPosition() - blob.getPosition()).Length();
		if (score < bestScore)
		{
			bestScore = score;
			@best = crate;
		}
	}
	return best;
}

bool AIB_IsBaseResourceCrate(CBlob@ crate, CBlob@ home, Vec2f storage)
{
	return AIBR_IsBaseResourceCrate(crate, home, storage);
}

bool AIB_PutResourcesInCrate(CBlob@ blob, CBlob@ crate)
{
	if (blob is null || crate is null) return false;

	AIB_StashCarriedResource(blob);
	bool acceptedAny = false;
	for (u8 i = 0; i < 24; i++)
	{
		CBlob@ resource = AIB_GetInventoryResource(blob);
		if (resource is null) break;

		const string name = resource.getName();
		CBlob@ item = blob.server_PutOutInventory(name);
		if (item is null) break;

		if (crate.server_PutInInventory(item))
		{
			item.Tag("aibuilder delivered resource");
			AIBG_RecordInteraction(blob);
			acceptedAny = true;
			continue;
		}

		if (!blob.server_PutInInventory(item))
		{
			blob.server_Pickup(item);
		}
		crate.Tag("aibuilder full resource crate");
		crate.set_u32(AIB_CRATE_CAPACITY_RETRY_KEY, getGameTime() + AIB_CRATE_CAPACITY_RETRY_TICKS);
		break;
	}
	return acceptedAny;
}

void AIB_StashCarriedResource(CBlob@ blob)
{
	if (blob is null) return;

	CBlob@ carried = blob.getCarriedBlob();
	if (!AIB_IsResourceBlob(carried)) return;
	if (!blob.server_PutInInventory(carried))
	{
		blob.server_Pickup(carried);
	}
}

bool AIB_HasAnyResource(CBlob@ blob)
{
	if (blob is null) return false;
	if (AIB_IsResourceBlob(blob.getCarriedBlob())) return true;
	return AIB_GetInventoryResource(blob) !is null;
}

bool AIB_CollectHomeMaterial(CBlob@ blob, CBlob@ home, const string &in name)
{
	const u32 gameTime = getGameTime();
	if (gameTime < blob.get_u32("ai builder next pickup")) return false;

	CBlob@ best = AIB_GetHomeMaterial(blob, home, name);
	if (best is null) return false;
	if (best.getName() == "crate")
	{
		CBlob@ material = AIB_TakeMaterialFromCrate(best, name);
		if (material is null) return false;

		material.setPosition(best.getPosition());
		material.setVelocity(Vec2f_zero);
		@best = material;
	}

	const u16 before = AIB_CountMaterial(blob, name);
	bool acquired = blob.server_PutInInventory(best);
	if (!acquired && !best.isAttached() && (best.getPosition() - blob.getPosition()).Length() <= 18.0f)
	{
		blob.server_Pickup(best);
		acquired = blob.getCarriedBlob() is best;
		if (acquired)
		{
			acquired = blob.server_PutInInventory(best);
		}
	}

	const bool changed = acquired || AIB_CountMaterial(blob, name) > before;
	blob.set_u32("ai builder next pickup", gameTime + (changed ? 6 : 18));
	return changed;
}

u16 AIB_CountHomeMaterial(CBlob@ home, const string &in name)
{
	return AIBR_CountAccessibleHomeMaterial(home, name);
}

bool AIB_TakeHomeMaterial(CBlob@ home, const string &in name, const u16 amount)
{
	if (home is null || amount == 0) return false;
	// All callers treat false as "nothing was paid". Preflight the exact same
	// accessible-stock contract before mutating loose stacks or crate inventory
	// so a short source cannot be partially consumed.
	if (AIB_CountHomeMaterial(home, name) < amount) return false;

	u16 remaining = amount;
	CBlob@[] mats;
	getBlobsByName(name, @mats);
	for (uint i = 0; i < mats.length && remaining > 0; i++)
	{
		CBlob@ mat = mats[i];
		if (!AIBR_IsLooseHomeMaterial(home, mat)) continue;

		const u16 quantity = mat.getQuantity();
		const u16 take = Maths::Min(quantity, remaining);
		if (take >= quantity)
		{
			mat.server_Die();
		}
		else
		{
			mat.server_SetQuantity(quantity - take);
		}
		remaining -= take;
	}

	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	Vec2f storage = AIBR_FindBaseStoragePoint(home);
	for (uint i = 0; i < crates.length && remaining > 0; i++)
	{
		CBlob@ crate = crates[i];
		if (!AIB_IsBaseResourceCrate(crate, home, storage)) continue;

		CInventory@ inv = crate.getInventory();
		if (inv is null) continue;

		const u16 take = Maths::Min(inv.getCount(name), remaining);
		if (take == 0) continue;

		inv.server_RemoveItems(name, take);
		remaining -= take;
	}

	return remaining == 0;
}

bool AIB_HasHomeBlueprintMaterials(CBlob@ home, const u16 block)
{
	if (home is null) return false;
	string[] materials = { "mat_wood", "mat_stone", "mat_gold" };
	for (uint i = 0; i < materials.length; i++)
	{
		const u16 required = AIBP_BlockMaterialCost(block, materials[i]);
		if (required > 0 && AIB_CountHomeMaterial(home, materials[i]) < required) return false;
	}
	return true;
}

void AIB_RefundHomeMaterial(CBlob@ home, const string &in material, const u16 amount)
{
	if (home is null || amount == 0) return;
	CBlob@ refund = server_CreateBlob(material, home.getTeamNum(), AIB_GetHomeDropPoint(home));
	if (refund is null) return;
	refund.server_SetQuantity(amount);
	refund.Tag("aibuilder delivered resource");
}

void AIB_RefundHomeBlueprintMaterials(CBlob@ home, const u16 block)
{
	AIB_RefundHomeMaterial(home, "mat_wood", AIBP_BlockMaterialCost(block, "mat_wood"));
	AIB_RefundHomeMaterial(home, "mat_stone", AIBP_BlockMaterialCost(block, "mat_stone"));
	AIB_RefundHomeMaterial(home, "mat_gold", AIBP_BlockMaterialCost(block, "mat_gold"));
}

bool AIB_TakeHomeBlueprintMaterials(CBlob@ home, const u16 block)
{
	if (!AIB_HasHomeBlueprintMaterials(home, block)) return false;
	string[] materials = { "mat_wood", "mat_stone", "mat_gold" };
	array<u16> paid(materials.length, 0);
	for (uint i = 0; i < materials.length; i++)
	{
		const u16 required = AIBP_BlockMaterialCost(block, materials[i]);
		if (required == 0) continue;
		if (AIB_TakeHomeMaterial(home, materials[i], required))
		{
			paid[i] = required;
			continue;
		}
		for (uint refundIndex = 0; refundIndex < paid.length; refundIndex++)
			AIB_RefundHomeMaterial(home, materials[refundIndex], paid[refundIndex]);
		return false;
	}
	return true;
}

CBlob@ AIB_GetHomeMaterial(CBlob@ blob, CBlob@ home, const string &in name)
{
	CBlob@[] mats;
	getBlobsByName(name, @mats);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	for (uint i = 0; i < mats.length; i++)
	{
		CBlob@ mat = mats[i];
		if (!AIBR_IsLooseHomeMaterial(home, mat)) continue;

		const f32 distance = (mat.getPosition() - blob.getPosition()).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = mat;
		}
	}

	if (best !is null) return best;
	return AIB_GetCratedHomeMaterialSource(home, name);
}

CBlob@ AIB_GetCratedHomeMaterialSource(CBlob@ home, const string &in name)
{
	if (home is null) return null;

	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	Vec2f storage = AIBR_FindBaseStoragePoint(home);
	for (uint i = 0; i < crates.length; i++)
	{
		CBlob@ crate = crates[i];
		if (!AIB_IsBaseResourceCrate(crate, home, storage)) continue;

		CInventory@ inv = crate.getInventory();
		if (inv is null || inv.getCount(name) == 0) continue;

		return crate;
	}

	return null;
}

CBlob@ AIB_TakeMaterialFromCrate(CBlob@ crate, const string &in name)
{
	if (crate is null) return null;

	CInventory@ inv = crate.getInventory();
	if (inv is null || inv.getCount(name) == 0) return null;

	return crate.server_PutOutInventory(name);
}

void AIB_StashCarriedBlueprintMaterial(CBlob@ blob)
{
	CBlob@ carried = blob.getCarriedBlob();
	if (carried is null) return;
	if (carried.getName() != "mat_wood" && carried.getName() != "mat_stone" && carried.getName() != "mat_gold") return;

	blob.server_PutInInventory(carried);
}

u16 AIB_CountMaterial(CBlob@ blob, const string &in name)
{
	if (AIBU_IsAutoBuilder(blob)) return 65535;
	if (name == "mat_wood") return AIB_CountWood(blob);
	if (name == "mat_stone") return AIB_CountStone(blob);

	CInventory@ inv = blob.getInventory();
	return inv is null ? 0 : inv.getCount(name);
}

string AIB_BlueprintDataKeyForTeam(const u8 team)
{
	return AIB_BLUEPRINT_DATA_KEY + AIB_BLUEPRINT_TEAM_SUFFIX + int(team);
}

string AIB_BlueprintWidthKeyForTeam(const u8 team)
{
	return AIB_BLUEPRINT_WIDTH_KEY + AIB_BLUEPRINT_TEAM_SUFFIX + int(team);
}

string AIB_BlueprintHeightKeyForTeam(const u8 team)
{
	return AIB_BLUEPRINT_HEIGHT_KEY + AIB_BLUEPRINT_TEAM_SUFFIX + int(team);
}

Vec2f AIB_GetNearestBlueprintBuildTile(CBlob@ blob)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	CRules@ rules = getRules();
	if (rules is null) return Vec2f_zero;

	array<u16>@ blueprint = null;
	u16 width = 0;
	u16 height = 0;
	const u8 team = u8(blob.getTeamNum());
	if (rules.get(AIB_BlueprintDataKeyForTeam(team), @blueprint) && blueprint !is null)
	{
		width = rules.get_u16(AIB_BlueprintWidthKeyForTeam(team));
		height = rules.get_u16(AIB_BlueprintHeightKeyForTeam(team));
	}
	else
	{
		return Vec2f_zero;
	}

	if (width == 0 || height == 0) return Vec2f_zero;

	Vec2f bestAffordable = Vec2f_zero;
	f32 bestAffordableDistance = 99999999.0f;
	Vec2f bestFallback = Vec2f_zero;
	f32 bestFallbackDistance = 99999999.0f;
	Vec2f pos = blob.getPosition();
	for (int y = height - 1; y >= 0; y--)
	{
		for (int x = 0; x < width; x++)
		{
			u16 block = AIB_GetBlueprintBlock(blueprint, width, height, x, y);
			if (!AIB_IsSupportedBlueprintBlock(block)) continue;
			// Generated backwall cells use loose reservations because they are not
			// explicit strategic tasks. Gate them through their owning blueprint
			// task first, otherwise a shell dependency can bypass unfinished
			// foundation/access phases and strand the worker on premature work.
			if (!AIBP_TaskAvailableForBuilder(team, u16(x), u16(y), blob.getNetworkID())) continue;

			Vec2f tile = Vec2f(x * map.tilesize, y * map.tilesize);
			Vec2f support = AIB_GetNeededSupportTileFor(tile, block);
			if (AIB_IsInvalidBlueprintSupportTile(support)) continue;
			Vec2f target = support != Vec2f_zero ? support : tile;
			if (!AIB_BlueprintTileStillNeedsWork(target, team))
			{
				continue;
			}
			Vec2f targetSpace = map.getTileSpacePosition(target);
			if (!AIBP_TaskAvailableForBuilder(team, u16(targetSpace.x), u16(targetSpace.y), blob.getNetworkID()))
			{
				continue;
			}

			const f32 distance = (AIB_TileCenter(target) - pos).Length();
			if (distance < bestFallbackDistance)
			{
				bestFallbackDistance = distance;
				bestFallback = target;
			}

			const u16 targetBlock = AIB_GetBlueprintTargetForTile(target, team);
			if (AIB_HasBlueprintMaterials(blob, targetBlock) &&
				distance < bestAffordableDistance)
			{
				bestAffordableDistance = distance;
				bestAffordable = target;
			}
		}
	}
	// Do useful work with materials already on hand before reserving a task that
	// requires a trip home. Phase, dependency, and reservation eligibility were
	// applied above, so this only changes priority among currently valid tasks.
	Vec2f best = bestAffordable != Vec2f_zero ? bestAffordable : bestFallback;
	if (best != Vec2f_zero)
	{
		Vec2f bestSpace = map.getTileSpacePosition(best);
		if (!AIBP_ReserveTask(team, u16(bestSpace.x), u16(bestSpace.y), blob.getNetworkID())) return Vec2f_zero;
	}
	return best;
}

string AIB_GetBlueprintWaitStatus(CBlob@ blob)
{
	CMap@ map = getMap();
	CRules@ rules = getRules();
	if (blob is null || map is null || rules is null || blob.getTeamNum() < 0 || blob.getTeamNum() >= 8)
		return "Waiting for blueprint work";

	const u8 team = u8(blob.getTeamNum());
	const u8 mode = rules.get_u8(AIBP_ModeKey(team));
	if (mode == AIBP_StrategyMode::suggest && AIBP_LayerHasWork(team, AIBP_Layer::ai_desired) &&
		!AIBP_LayerHasWork(team, AIBP_Layer::ai_work))
	{
		return "Blueprint suggestion paused; issue Build blueprint to approve it";
	}

	array<u16>@ blueprint = null;
	if (!rules.get(AIB_BlueprintDataKeyForTeam(team), @blueprint) || blueprint is null)
		return "Waiting for blueprint work";
	const u16 width = rules.get_u16(AIB_BlueprintWidthKeyForTeam(team));
	const u16 height = rules.get_u16(AIB_BlueprintHeightKeyForTeam(team));
	if (width == 0 || height == 0) return "Waiting for blueprint work";
	u16 unfinished = 0;
	u16 reserved = 0;
	u16 actionable = 0;
	for (int y = height - 1; y >= 0; y--)
	{
		for (int x = 0; x < width; x++)
		{
			const u16 block = AIB_GetBlueprintBlock(blueprint, width, height, x, y);
			if (!AIB_IsSupportedBlueprintBlock(block)) continue;
			Vec2f tile = Vec2f(x * map.tilesize, y * map.tilesize);
			if (AIB_MapTileMatchesBlueprint(tile, block)) continue;
			unfinished++;
			if (!AIBP_TaskAvailableForBuilder(team, u16(x), u16(y), blob.getNetworkID()))
			{
				reserved++;
				continue;
			}
			Vec2f support = AIB_GetNeededSupportTileFor(tile, block);
			if (AIB_IsInvalidBlueprintSupportTile(support)) continue;
			Vec2f target = support != Vec2f_zero ? support : tile;
			if (!AIB_BlueprintTileStillNeedsWork(target, team)) continue;
			Vec2f targetSpace = map.getTileSpacePosition(target);
			if (AIBP_TaskAvailableForBuilder(team, u16(targetSpace.x), u16(targetSpace.y), blob.getNetworkID())) actionable++;
			else reserved++;
		}
	}

	if (actionable > 0) return "Retrying available blueprint work";
	if (reserved > 0) return "Waiting for another builder's blueprint reservation";
	if (unfinished > 0) return "Blueprint blocked by support, no-build area, or obstruction";
	return "Waiting for blueprint work";
}

u16 AIB_GetBlueprintBlock(array<u16>@ blueprint, const u16 width, const u16 height, const int x, const int y)
{
	return AIB_BlueprintBlockId(AIB_GetBlueprintBlockRaw(blueprint, width, height, x, y));
}

u16 AIB_GetBlueprintBlockRaw(array<u16>@ blueprint, const u16 width, const u16 height, const int x, const int y)
{
	if (blueprint is null || x < 0 || y < 0 || x >= width || y >= height) return 0;
	const uint index = y * width + x;
	if (index >= blueprint.length) return 0;
	return blueprint[index];
}

bool AIB_BlueprintTileStillNeedsWork(Vec2f tile, const u8 team)
{
	u16 target = AIB_GetBlueprintTargetForTile(tile, team);
	return target != 0 && !AIB_MapTileMatchesBlueprint(tile, target, team) &&
		(AIB_CanPlaceBlueprintAt(tile, target, team) || AIB_CanClearBlueprintSite(tile, target, team));
}

u16 AIB_GetBlueprintTargetForTile(Vec2f tile, const u8 team)
{
	CMap@ map = getMap();
	if (map is null) return 0;

	Vec2f space = map.getTileSpacePosition(tile);
	const int x = Maths::Floor(space.x);
	const int y = Maths::Floor(space.y);

	CRules@ rules = getRules();
	if (rules is null) return 0;

	array<u16>@ blueprint = null;
	u16 width = 0;
	u16 height = 0;
	if (rules.get(AIB_BlueprintDataKeyForTeam(team), @blueprint) && blueprint !is null)
	{
		width = rules.get_u16(AIB_BlueprintWidthKeyForTeam(team));
		height = rules.get_u16(AIB_BlueprintHeightKeyForTeam(team));
	}
	else
	{
		return 0;
	}

	u16 target = AIB_GetBlueprintBlockRaw(blueprint, width, height, x, y);
	if (AIB_IsSupportedBlueprintBlock(target)) return target;

	// Workshops occupy a 5x3 footprint while their blueprint is represented by
	// one anchor cell.  Their generated foundation may therefore be below any
	// of the five footprint columns, rather than directly below the anchor.
	for (int anchorX = x - 2; anchorX <= x + 2; anchorX++)
	{
		for (int anchorY = y - 2; anchorY >= 0; anchorY--)
		{
			u16 workshop = AIB_GetBlueprintBlockRaw(blueprint, width, height, anchorX, anchorY);
			if (!AIBP_IsWorkshopBlock(workshop)) continue;

			Vec2f workshopTile = Vec2f(anchorX * map.tilesize, anchorY * map.tilesize);
			if (AIB_GetNeededWorkshopSupportTile(workshopTile) == tile) return 2;
		}
	}

	Vec2f above = tile - Vec2f(0.0f, map.tilesize);
	while (above.y >= 0.0f)
	{
		Vec2f aboveSpace = map.getTileSpacePosition(above);
		u16 aboveTarget = AIB_GetBlueprintBlock(blueprint, width, height, Maths::Floor(aboveSpace.x), Maths::Floor(aboveSpace.y));
		if (AIB_IsSolidBlueprintBlock(aboveTarget) && AIB_GetNeededSupportTileFor(above, aboveTarget) == tile)
		{
			return AIB_GetBlueprintSupportBackwall(aboveTarget);
		}
		above -= Vec2f(0.0f, map.tilesize);
	}

	return 0;
}

Vec2f AIB_GetNeededSupportTileFor(Vec2f blueprintTile, const u16 block)
{
	if (AIBP_IsWorkshopBlock(block)) return AIB_GetNeededWorkshopSupportTile(blueprintTile);
	if (!AIB_IsSolidBlueprintBlock(block)) return Vec2f_zero;
	const u16 supportBackwall = AIB_GetBlueprintSupportBackwall(block);
	if (supportBackwall == 0) return Vec2f_zero;

	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	Vec2f below = blueprintTile + Vec2f(0.0f, map.tilesize);
	if (AIB_HasBlueprintSupportAt(blueprintTile)) return Vec2f_zero;

	Vec2f scan = below;
	bool crossedGap = false;
	while (scan.y < map.tilemapheight * map.tilesize)
	{
		if (AIB_TileProvidesBlueprintSupport(scan))
		{
			// Immediate support was already handled above. Reaching an anchor only
			// after an unbuildable gap means no legal vertical dependency exists.
			return crossedGap ? AIB_InvalidBlueprintSupportTile() : Vec2f_zero;
		}
		// Select the first cell that can legally attach. It is already supported
		// from below or from a side, and the next dependency step will naturally
		// advance upward. Continuing past this cell used to overwrite it with the
		// bottom map row, whose out-of-bounds neighbour may look solid to KAG.
		if (!AIB_MapTileMatchesBlueprint(scan, supportBackwall) && AIB_CanPlaceBlueprintAt(scan, supportBackwall))
		{
			return scan;
		}
		crossedGap = true;
		scan += Vec2f(0.0f, map.tilesize);
	}

	return AIB_InvalidBlueprintSupportTile();
}

Vec2f AIB_InvalidBlueprintSupportTile()
{
	return Vec2f(-8.0f, -8.0f);
}

bool AIB_IsInvalidBlueprintSupportTile(Vec2f tile)
{
	return tile.x < 0.0f || tile.y < 0.0f;
}

u16 AIB_GetBlueprintSupportBackwall(const u16 block)
{
	const string material = AIB_BlueprintMaterial(block);
	if (material == "mat_wood") return AIBP_WOOD_BACKWALL;
	if (material == "mat_stone") return AIBP_STONE_BACKWALL;
	return 0;
}

Vec2f AIB_GetNeededWorkshopSupportTile(Vec2f blueprintTile)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;
	// Do not generate foundation work for a workshop that can never be placed.
	if (AIB_WorkshopFootprintIntersectsNoBuild(blueprintTile)) return Vec2f_zero;

	const f32 ts = map.tilesize;
	// All workshop variants use the base 40x24 (5x3 tile) footprint.  Require
	// every bottom column to meet terrain or a built support before placement.
	for (int x = -2; x <= 2; x++)
	{
		Vec2f foundation = blueprintTile + Vec2f(x * ts, 2.0f * ts);
		if (AIB_TileProvidesBlueprintSupport(foundation)) continue;

		Vec2f scan = foundation;
		bool crossedGap = false;
		while (scan.y < map.tilemapheight * ts)
		{
			if (AIB_TileProvidesBlueprintSupport(scan))
				return crossedGap ? AIB_InvalidBlueprintSupportTile() : Vec2f_zero;
			if (!AIB_MapTileMatchesBlueprint(scan, 2) && AIB_CanPlaceBlueprintAt(scan, 2))
			{
				return scan;
			}
			crossedGap = true;
			scan += Vec2f(0.0f, ts);
		}
		return AIB_InvalidBlueprintSupportTile();
	}

	return Vec2f_zero;
}

bool AIB_PlaceBlueprintTile(CBlob@ blob, Vec2f tile)
{
	const u32 gameTime = getGameTime();
	if (gameTime < blob.get_u32("ai builder next place")) return false;

	const u8 team = u8(blob.getTeamNum());
	u16 target = AIB_GetBlueprintTargetForTile(tile, team);
	if (target == 0 || AIB_MapTileMatchesBlueprint(tile, target, team)) return true;

	CMap@ map = getMap();
	if (map is null) return false;
	Vec2f space = map.getTileSpacePosition(tile);
	const u16 tileX = u16(Maths::Floor(space.x));
	const u16 tileY = u16(Maths::Floor(space.y));
	if (AIBP_IsRepairablePlanOccupant(team, tileX, tileY, target))
	{
		if (AIBP_IsBlobBlock(target) || !AIB_TakeBlueprintMaterials(blob, target)) return false;
		map.server_SetTile(tile, AIB_BlueprintTileType(target));
		AIB_LogEvent("ai", "repair", AIB_EventBlobRef(blob), "tile=" + AIB_EventPos(tile) +
			" block=" + target + " cost={" + AIBP_BlockCostSummary(target) + "}");
		AIB_ClearBlueprintTargetForTile(tile, team);
		blob.set_u32("ai builder next place", gameTime + AIB_GetBlueprintPlaceDelay(blob));
		return true;
	}
	if (!AIB_CanPlaceBlueprintAt(tile, target, team))
	{
		AIBG_RecordInvalidBuild(blob, "placement_invalid");
		return true;
	}

	if (AIBP_IsBlobBlock(target))
	{
		return AIB_PlaceBlueprintBlob(blob, tile, target);
	}

	if (AIB_BlueprintCost(target) == 0) return true;
	if (!AIB_TakeBlueprintMaterials(blob, target)) return false;

	// Replace the current tile in one server mutation.  In particular, do not
	// clear grass with server_SetTile immediately before placing a backwall:
	// KAG queues/synchronises tile mutations, so two writes to the same tile in
	// one tick can leave only the clear applied.  Base PlaceBlock also replaces
	// grass directly with the requested foreground/background tile.
	map.server_SetTile(tile, AIB_BlueprintTileType(target));
	AIB_ClearBlueprintTargetForTile(tile, team);
	blob.set_u32("ai builder next place", gameTime + AIB_GetBlueprintPlaceDelay(blob));
	return true;
}

u8 AIB_GetBlueprintPlaceDelay(CBlob@ blob)
{
	return AIBU_IsAutoBuilder(blob) ? AIBU_PLACE_DELAY_TICKS : AIB_BLUEPRINT_PLACE_DELAY;
}

bool AIB_PlaceBlueprintBlob(CBlob@ blob, Vec2f tile, const u16 target)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return false;
	// Revalidate immediately before creation so a workshop cannot bypass a
	// changed no-build sector or foundation state after task selection.
	if (AIBP_IsWorkshopBlock(target) &&
		(AIB_WorkshopFootprintIntersectsNoBuild(tile) || AIB_GetNeededWorkshopSupportTile(tile) != Vec2f_zero ||
			!AIB_BlueprintWorkshopEnvironmentValid(tile, target)))
	{
		AIBG_RecordInvalidBuild(blob, "workshop_revalidation");
		return false;
	}

	const string blobName = AIBP_BlockBlobName(target);
	if (blobName == "") { AIBG_RecordInvalidBuild(blob, "missing_blob_catalog"); return false; }
	// Mixed-material structures must be all-or-nothing.  Preflight the entire
	// catalog cost before creating a networked blob or clearing grass; the
	// payment helper repeats the check immediately before removal.
	if (!AIB_HasBlueprintMaterials(blob, target)) return false;
	const TileType replacedTile = map.getTile(tile).type;
	const bool replacesGrass = map.isTileGrass(replacedTile);
	if (replacesGrass) map.server_SetTile(tile, CMap::tile_empty);
	CBlob@ placed = server_CreateBlob(blobName, blob.getTeamNum(), AIB_TileCenter(tile));
	if (placed is null)
	{
		AIBG_RecordInvalidBuild(blob, "blob_creation_failed");
		if (replacesGrass) map.server_SetTile(tile, replacedTile);
		return false;
	}
	if (!AIB_TakeBlueprintMaterials(blob, target))
	{
		placed.server_Die();
		if (replacesGrass) map.server_SetTile(tile, replacedTile);
		return false;
	}

	const u16 rotation = AIB_BlueprintRotation(target);
	placed.setAngleDegrees(rotation * 90.0f);
	if (AIBP_RequiresStoneBackground(target))
	{
		placed.set_TileType("background tile", CMap::tile_castle_back);
		map.server_SetTile(tile, CMap::tile_castle_back);
	}
	placed.set_u8(AIBP_BLUEPRINT_OWNER_TEAM_KEY, u8(blob.getTeamNum()));
	placed.Sync(AIBP_BLUEPRINT_OWNER_TEAM_KEY, true);
	placed.Tag("aibuilder blueprint structure");
	if (blobName == "ladder") placed.Tag("aibuilder blueprint ladder");
	placed.getShape().SetStatic(true);
	placed.getShape().SetGravityScale(0.0f);
	AIB_ClearBlueprintTargetForTile(tile, u8(blob.getTeamNum()));
	blob.set_u32("ai builder next place", getGameTime() + AIB_GetBlueprintPlaceDelay(blob));
	return true;
}

void AIB_ClearBlueprintTargetForTile(Vec2f tile, const u8 team)
{
	CMap@ map = getMap();
	CRules@ rules = getRules();
	if (map is null || rules is null) return;

	Vec2f space = map.getTileSpacePosition(tile);
	const int x = Maths::Floor(space.x);
	const int y = Maths::Floor(space.y);
	if (x < 0 || y < 0 || x >= map.tilemapwidth || y >= map.tilemapheight) return;
	AIBP_ClearConsumableTile(team, u16(x), u16(y));
}

bool AIB_CanPlaceBlueprintAt(Vec2f tile, const u16 block)
{
	return AIB_CanPlaceBlueprintAt(tile, block, -1);
}

bool AIB_CanPlaceBlueprintAt(Vec2f tile, const u16 block, const s16 expectedTeam)
{
	CMap@ map = getMap();
	if (map is null) return false;
	Vec2f space = map.getTileSpacePosition(tile);
	const u16 tileX = u16(Maths::Floor(space.x));
	const u16 tileY = u16(Maths::Floor(space.y));
	// Repair is a legal placement outcome; it must not be routed through the
	// obstruction clearer, which would destroy the owned structure first.
	if (expectedTeam >= 0 && AIBP_IsRepairablePlanOccupant(u8(expectedTeam), tileX, tileY, block)) return true;
	if (expectedTeam < 0 && !AIBP_IsBlobBlock(block) &&
		AIBP_DamagedTileMatchesBlock(map.getTile(tile).type, block)) return true;

	const TileType current = map.getTile(tile).type;
	if (map.isTileBedrock(current)) return false;
	if (AIB_BlueprintBlockId(block) != AIBP_LADDER && map.getSectorAtPosition(AIB_TileCenter(tile), "no build") !is null) return false;
	if (AIBP_IsWorkshopBlock(block))
	{
		if (AIB_WorkshopFootprintIntersectsNoBuild(tile)) return false;
		if (AIB_GetNeededWorkshopSupportTile(tile) != Vec2f_zero) return false;
		if (!AIB_BlueprintWorkshopEnvironmentValid(tile, block)) return false;
	}
	if (AIBP_IsBlobBlock(block))
	{
		if (AIB_MapTileMatchesBlueprint(tile, block)) return true;
		if (!AIB_TileCountsAsAirForBlueprint(tile)) return false;
		if (!AIBP_IsWorkshopBlock(block) && !AIB_HasBlueprintSupportAt(tile)) return false;
		return !AIB_HasConflictingBlueprintBlob(tile);
	}
	if (!AIB_TileCountsAsAirForBlueprint(tile) && !(AIB_IsSolidBlueprintBlock(block) && AIB_IsSupportBackwall(current))) return false;
	if (!AIB_HasBlueprintSupportAt(tile)) return false;

	return true;
}

bool AIB_CanClearBlueprintSite(Vec2f tile, const u16 block)
{
	return AIB_CanClearBlueprintSite(tile, block, -1);
}

bool AIB_CanClearBlueprintSite(Vec2f tile, const u16 block, const s16 expectedTeam)
{
	CMap@ map = getMap();
	if (map is null) return false;
	Vec2f space = map.getTileSpacePosition(tile);
	const u16 tileX = u16(Maths::Floor(space.x));
	const u16 tileY = u16(Maths::Floor(space.y));
	if (expectedTeam >= 0 && AIBP_IsRepairablePlanOccupant(u8(expectedTeam), tileX, tileY, block)) return false;
	if (expectedTeam < 0 && !AIBP_IsBlobBlock(block) &&
		AIBP_DamagedTileMatchesBlock(map.getTile(tile).type, block)) return false;

	const TileType current = map.getTile(tile).type;
	if (map.isTileBedrock(current)) return false;
	const bool clearableTile = !AIB_TileCountsAsAirForBlueprint(tile) &&
		!(AIB_IsSolidBlueprintBlock(block) && AIB_IsSupportBackwall(current)) &&
		map.isTileSolid(current);
	return clearableTile || AIB_GetClearableBlueprintSiteBlob(tile, block) !is null;
}

bool AIB_ClearBlueprintSiteObstruction(CBrain@ brain, CBlob@ blob, Vec2f tile)
{
	CMap@ map = getMap();
	if (brain is null || blob is null || map is null) return false;

	const u16 target = AIB_GetBlueprintTargetForTile(tile, u8(blob.getTeamNum()));
	if (target == 0 || !AIB_CanClearBlueprintSite(tile, target, blob.getTeamNum())) return false;

	Vec2f center = AIB_TileCenter(tile);
	if ((center - blob.getPosition()).Length() > 40.0f)
	{
		AIB_GoTo(brain, blob, center);
		return true;
	}

	const u32 gameTime = getGameTime();
	if (AIBU_IsAutoBuilder(blob)) blob.setVelocity(Vec2f_zero);
	if (gameTime < blob.get_u32("ai builder next hit")) return true;

	blob.setAimPos(center);
	blob.setKeyPressed(key_action2, true);
	const TileType current = map.getTile(tile).type;
	if (map.isTileSolid(current))
	{
		map.server_DestroyTile(tile, 1.0f, blob);
	}
	else
	{
		CBlob@ obstruction = AIB_GetClearableBlueprintSiteBlob(tile, target);
		if (obstruction is null) return false;
		AIB_HitTarget(blob, obstruction, obstruction.getPosition());
	}
	blob.set_u32("ai builder next hit", gameTime + AIB_HIT_DELAY);
	return true;
}

CBlob@ AIB_GetClearableBlueprintSiteBlob(Vec2f tile, const u16 target)
{
	CMap@ map = getMap();
	if (map is null) return null;

	const Vec2f center = AIB_TileCenter(tile);
	const Vec2f space = map.getTileSpacePosition(tile);
	const u16 tileX = u16(Maths::Floor(space.x));
	const u16 tileY = u16(Maths::Floor(space.y));
	const string expected = AIBP_BlockBlobName(target);
	CBlob@[] nearby;
	if (!map.getBlobsInRadius(center, 8.0f, @nearby)) return null;
	for (uint i = 0; i < nearby.length; i++)
	{
		CBlob@ candidate = nearby[i];
		if (candidate is null || candidate.hasTag("dead") || candidate.isAttached()) continue;
		const string name = candidate.getName();
		if (!AIBP_BlobAnchoredAtTile(candidate, tileX, tileY)) continue;
		if (name == expected && AIB_MapTileMatchesBlueprint(tile, target)) continue;
		if (name == "ctf_flag" || name == "tent" || name == "hall" || name == "aibuilder" || name == "autobuilder" ||
			name == "builder" || name == "knight" || name == "archer") continue;
		if (!AIBP_IsBlueprintBlobName(name) && !candidate.hasTag("building")) continue;
		return candidate;
	}
	return null;
}

bool AIB_WorkshopFootprintIntersectsNoBuild(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return true;

	const f32 ts = map.tilesize;
	for (int x = -2; x <= 2; x++)
	{
		for (int y = -1; y <= 1; y++)
		{
			Vec2f footprintTile = tile + Vec2f(x * ts, y * ts);
			Vec2f center = AIB_TileCenter(footprintTile);
			if (!AIB_IsInsideMap(center) || map.getSectorAtPosition(center, "no build") !is null) return true;
		}
	}
	return false;
}

bool AIB_BlueprintWorkshopEnvironmentValid(Vec2f tile, const u16 block)
{
	if (AIBP_BlockId(block) != AIBP_BOAT_SHOP) return true;
	CMap@ map = getMap();
	if (map is null) return false;
	const f32 ts = map.tilesize;
	const Vec2f center = AIB_TileCenter(tile);
	for (int offsetX = -3; offsetX <= 3; offsetX++)
	{
		for (int offsetY = -1; offsetY <= 3; offsetY++)
		{
			const Vec2f sample = Vec2f(center.x + offsetX * ts, center.y + offsetY * ts);
			if (map.isInWater(sample)) return true;
		}
	}
	return false;
}

bool AIB_HasBlueprintSupportAt(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;
	// Match the authoritative player placement check first. Engine support
	// includes static blob structures such as the ladder immediately below a
	// new ladder; tile-only inspection cannot see that support chain.
	if (map.hasSupportAtPos(AIB_TileCenter(tile))) return true;

	const f32 ts = map.tilesize;
	return AIB_TileProvidesBlueprintSupport(tile) ||
		AIB_TileProvidesBlueprintSupport(tile + Vec2f(0.0f, ts)) ||
		AIB_TileProvidesBlueprintSupport(tile + Vec2f(0.0f, -ts)) ||
		AIB_TileProvidesBlueprintSupport(tile + Vec2f(ts, 0.0f)) ||
		AIB_TileProvidesBlueprintSupport(tile + Vec2f(-ts, 0.0f));
}

bool AIB_TileProvidesBlueprintSupport(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;
	// map.getTile() may report an out-of-bounds sentinel as solid. The bottom
	// map edge is not a legal KAG attachment anchor.
	if (!AIB_IsInsideMap(AIB_TileCenter(tile))) return false;

	const TileType type = map.getTile(tile).type;
	if (type == CMap::tile_empty || type == CMap::tile_ground_back) return false;
	// KAG permits backwalls and foreground blocks to attach to solid terrain.
	// Rejecting grass/dirt here left generated support chains with no legal
	// anchor and made otherwise buildable plans report "unsupported".
	if (map.isTileSolid(type)) return true;
	return AIB_IsSupportBackwall(type);
}

bool AIB_TileCountsAsAirForBlueprint(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;

	const TileType type = map.getTile(tile).type;
	if (type == CMap::tile_empty || type == CMap::tile_ground_back) return true;
	if (map.isTileGrass(type)) return true;
	if (AIB_IsSupportBackwall(type)) return true;
	if (!map.isTileSolid(type) && !AIB_IsSupportBackwall(type)) return true;
	return false;
}

Vec2f AIB_GetBlueprintBuildApproach(CBlob@ blob, Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return AIB_TileCenter(tile);
	if (AIBU_IsAutoBuilder(blob))
	{
		Vec2f center = AIB_TileCenter(tile);
		const u16 target = AIB_GetBlueprintTargetForTile(tile, u8(blob.getTeamNum()));
		const f32 clearance = AIBP_IsWorkshopBlock(target) ? 28.0f : 12.0f;
		f32 direction = blob.getPosition().x <= center.x ? -1.0f : 1.0f;
		const f32 mapWidth = map.tilemapwidth * map.tilesize;
		if (center.x + direction * clearance < 4.0f || center.x + direction * clearance >= mapWidth - 4.0f)
		{
			direction = -direction;
		}
		return center + Vec2f(direction * clearance, 0.0f);
	}

	Vec2f center = AIB_TileCenter(tile);
	Vec2f best = center;
	f32 bestScore = 999999.0f;
	const f32 ts = map.tilesize;
	CRules@ rules = getRules();
	if (rules !is null && blob.getTeamNum() >= 0)
	{
		const u8 team = u8(blob.getTeamNum());
		const Vec2f space = map.getTileSpacePosition(tile);
		const u16 tileX = u16(Maths::Floor(space.x));
		const u16 tileY = u16(Maths::Floor(space.y));
		const Vec2f anchor = rules.get_Vec2f(AIBP_PlanKey(team, "anchor"));
		const f32 anchorWorldX = anchor.x * ts + ts * 0.5f;
		const f32 inward = anchorWorldX < center.x ? -1.0f : (anchorWorldX > center.x ? 1.0f : 0.0f);
		if (rules.get_u16(AIBP_PlanKey(team, "id")) != 0 && inward != 0.0f && AIBP_IsAIWorkTile(team, tileX, tileY))
		{
			Vec2f interior = center + Vec2f(inward * ts, 0.0f);
			if (blob.getPosition().y < center.y && AIBP_CurrentTaskPhase(team) == AIBP_Phase::closure)
			{
				CBlob@ home = AIB_GetTeamHome(blob);
				const f32 homeward = home !is null && home.getPosition().x < anchorWorldX ? -1.0f : 1.0f;
				Vec2f hatchApproach = Vec2f(anchorWorldX + homeward * ts * 0.5f, center.y - 2.0f * ts);
				if ((hatchApproach - center).Length() <= 32.0f && AIB_HasBuilderClearance(hatchApproach, blob.getTeamNum()))
					return hatchApproach;
			}
			// A builder already above a lower wall/door need not descend to the
			// target's floor. This elevated interior stance remains within normal
			// build reach and avoids unreliable downward ladder pathing.
			Vec2f elevatedInterior = interior - Vec2f(0.0f, 2.0f * ts);
			Vec2f elevatedAnchor = Vec2f(anchorWorldX, center.y - 2.0f * ts);
			if (blob.getPosition().y < center.y && (elevatedAnchor - center).Length() <= 32.0f &&
				AIB_HasBuilderClearance(elevatedAnchor, blob.getTeamNum()))
			{
				return elevatedAnchor;
			}
			if (blob.getPosition().y < center.y && AIB_HasBuilderClearance(elevatedInterior, blob.getTeamNum()))
				return elevatedInterior;
			if (AIB_HasBuilderClearance(interior, blob.getTeamNum())) return interior;
		}
	}
	Vec2f[] candidates = {
		center + Vec2f(-ts, 0.0f),
		center + Vec2f(ts, 0.0f),
		center + Vec2f(0.0f, -ts),
		center + Vec2f(0.0f, ts),
		center + Vec2f(-ts, -ts),
		center + Vec2f(ts, -ts),
		center + Vec2f(-ts, ts),
		center + Vec2f(ts, ts)
	};

	for (uint i = 0; i < candidates.length; i++)
	{
		Vec2f candidate = candidates[i];
		if (!AIB_HasBuilderClearance(candidate, blob.getTeamNum())) continue;

		const f32 score = (candidate - blob.getPosition()).Length() + (candidate - center).Length() * 0.25f;
		if (score < bestScore)
		{
			bestScore = score;
			best = candidate;
		}
	}
	return best;
}

bool AIB_HasBuilderClearance(Vec2f pos, const int team)
{
	CMap@ map = getMap();
	if (map is null) return false;
	if (!AIB_IsInsideMap(pos)) return false;
	if (!AIB_IsInsideCurrentBarrierZoneAt(pos)) return false;
	if (!AIB_IsSafePosition(pos, team)) return false;

	const f32 ts = map.tilesize;
	Vec2f foot = pos;
	Vec2f head = pos - Vec2f(0.0f, ts);
	const bool verticalClearance = AIB_IsBuilderPassableAt(foot) && AIB_IsBuilderPassableAt(head);
	const bool horizontalClearance = AIB_IsBuilderPassableAt(foot + Vec2f(-ts * 0.5f, 0.0f)) && AIB_IsBuilderPassableAt(foot + Vec2f(ts * 0.5f, 0.0f));
	return verticalClearance || horizontalClearance;
}

bool AIB_IsBuilderPassableAt(Vec2f pos)
{
	CMap@ map = getMap();
	if (map is null) return false;

	const TileType type = map.getTile(pos).type;
	if (map.isTileBedrock(type)) return false;
	if (map.isTileSolid(type)) return false;
	return true;
}

bool AIB_IsInsideMap(Vec2f pos)
{
	CMap@ map = getMap();
	if (map is null) return false;
	return pos.x >= 0.0f && pos.y >= 0.0f && pos.x < map.tilemapwidth * map.tilesize && pos.y < map.tilemapheight * map.tilesize;
}

bool AIB_IsInsideCurrentBarrierZoneAt(Vec2f position)
{
	return AIBR_IsInsideCurrentBarrierZoneAt(position);
}

bool AIB_IsSafePosition(Vec2f position, const int team)
{
	CBlob@[] enemies;
	if (!getMap().getBlobsInRadius(position, AIB_SAFE_RADIUS, @enemies)) return true;

	for (uint i = 0; i < enemies.length; i++)
	{
		CBlob@ enemy = enemies[i];
		if (enemy is null || enemy.hasTag("dead")) continue;
		if (enemy.getTeamNum() == team) continue;

		const string name = enemy.getName();
		if (name != "knight" && name != "archer") continue;
		if (AIB_HasDirectEnemyPath(position, enemy)) return false;
	}
	return true;
}

bool AIB_IsSupportBackwall(const TileType type)
{
	return (type >= CMap::tile_castle_back && type <= 79) ||
		type == CMap::tile_castle_back_moss ||
		(type >= CMap::tile_wood_back && type <= 207);
}

bool AIB_MapTileMatchesBlueprint(Vec2f tile, const u16 block)
{
	return AIB_MapTileMatchesBlueprint(tile, block, -1);
}

bool AIB_MapTileMatchesBlueprint(Vec2f tile, const u16 block, const s16 expectedTeam)
{
	CMap@ map = getMap();
	if (map is null) return false;
	Vec2f space = map.getTileSpacePosition(tile);
	return AIBP_MapMatchesBlock(u16(Maths::Floor(space.x)), u16(Maths::Floor(space.y)), block, expectedTeam);
}

u16 AIB_BlueprintBlockId(const u16 block)
{
	return AIBP_BlockId(block);
}

u16 AIB_BlueprintRotation(const u16 block)
{
	return AIBP_BlockRotation(block);
}

CBlob@ AIB_GetBlueprintBlobAt(Vec2f tile, const string &in name)
{
	CMap@ map = getMap();
	if (map is null) return null;
	const Vec2f space = map.getTileSpacePosition(tile);
	const u16 tileX = u16(Maths::Floor(space.x));
	const u16 tileY = u16(Maths::Floor(space.y));

	CBlob@[] blobs;
	if (!map.getBlobsInRadius(AIB_TileCenter(tile), 6.0f, @blobs)) return null;

	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob !is null && blob.getName() == name && !blob.hasTag("dead") &&
			AIBP_BlobAnchoredAtTile(blob, tileX, tileY))
		{
			return blob;
		}
	}
	return null;
}

CBlob@ AIB_GetBlueprintLadderAt(Vec2f tile)
{
	return AIB_GetBlueprintBlobAt(tile, "ladder");
}

bool AIB_HasBlueprintLadderNear(CBlob@ blob)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return false;

	const f32 tilesize = map.tilesize;
	const Vec2f space = map.getTileSpacePosition(blob.getPosition());
	const s32 tileX = s32(Maths::Floor(space.x));
	const s32 tileY = s32(Maths::Floor(space.y));
	for (s32 yOffset = -1; yOffset <= 1; yOffset++)
	{
		const s32 y = tileY + yOffset;
		if (tileX < 0 || y < 0 || tileX >= map.tilemapwidth || y >= map.tilemapheight) continue;
		if (AIB_GetBlueprintLadderAt(Vec2f(tileX * tilesize, y * tilesize)) !is null) return true;
	}
	return false;
}

bool AIB_HasConflictingBlueprintBlob(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return true;
	const Vec2f space = map.getTileSpacePosition(tile);
	const u16 tileX = u16(Maths::Floor(space.x));
	const u16 tileY = u16(Maths::Floor(space.y));
	CBlob@[] blobs;
	if (!map.getBlobsInRadius(AIB_TileCenter(tile), 6.0f, @blobs)) return false;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ candidate = blobs[i];
		if (candidate is null || candidate.hasTag("dead")) continue;
		if (!AIBP_BlobAnchoredAtTile(candidate, tileX, tileY)) continue;
		const string name = candidate.getName();
		if (name == "bridge" || AIBP_IsBlueprintBlobName(name)) return true;
	}
	return false;
}

bool AIB_IsSupportedBlueprintBlock(const u16 block)
{
	return AIBP_IsCatalogBlock(block);
}

bool AIB_IsSolidBlueprintBlock(const u16 block)
{
	return AIBP_IsSolidTileBlock(block);
}

TileType AIB_BlueprintTileType(const u16 block)
{
	return AIBP_BlockTileType(block);
}

string AIB_BlueprintMaterial(const u16 block)
{
	return AIBP_BlockMaterial(block);
}

u16 AIB_BlueprintCost(const u16 block)
{
	return AIBP_BlockCost(block);
}

bool AIB_TakeMaterial(CBlob@ blob, const string &in name, const u16 amount)
{
	if (AIBU_IsAutoBuilder(blob)) return true;
	CInventory@ inv = blob.getInventory();
	if (inv is null || inv.getCount(name) < amount) return false;

	inv.server_RemoveItems(name, amount);
	return true;
}

bool AIB_HasBlueprintMaterials(CBlob@ blob, const u16 block)
{
	if (blob is null) return false;
	if (AIBU_IsAutoBuilder(blob)) return true;
	string[] materials = { "mat_wood", "mat_stone", "mat_gold" };
	for (uint i = 0; i < materials.length; i++)
	{
		const u16 required = AIBP_BlockMaterialCost(block, materials[i]);
		if (required > 0 && AIB_CountMaterial(blob, materials[i]) < required) return false;
	}
	return true;
}

bool AIB_TakeBlueprintMaterials(CBlob@ blob, const u16 block)
{
	// Preflight every component before the first mutation. This keeps a mixed
	// shop/stone-backed access task all-or-nothing even if only its final
	// component is missing.
	if (!AIB_HasBlueprintMaterials(blob, block)) return false;
	if (AIBU_IsAutoBuilder(blob)) return true;
	string[] materials = { "mat_wood", "mat_stone", "mat_gold" };
	for (uint i = 0; i < materials.length; i++)
	{
		const u16 required = AIBP_BlockMaterialCost(block, materials[i]);
		if (required > 0 && !AIB_TakeMaterial(blob, materials[i], required)) return false;
	}
	return true;
}

CBlob@ AIB_GetNearestTeamBlob(CBlob@ blob, const string &in name)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ candidate = blobs[i];
		if (candidate is null || candidate.hasTag("dead") || candidate.getTeamNum() != blob.getTeamNum()) continue;

		const f32 distance = (candidate.getPosition() - pos).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}

	return best;
}

Vec2f AIB_GetHitPosition(CBlob@ blob, CBlob@ target)
{
	Vec2f targetPos = target.getPosition();
	Vec2f blobPos = blob.getPosition();
	const f32 xOffset = blobPos.x < targetPos.x ? -4.0f : 4.0f;

	if (target.hasTag("tree"))
	{
		return targetPos + Vec2f(xOffset, -8.0f);
	}

	return targetPos + Vec2f(xOffset, 0.0f);
}

bool AIB_HitTarget(CBlob@ blob, CBlob@ target, Vec2f hitPos)
{
	const u32 gameTime = getGameTime();
	if (gameTime < blob.get_u32("ai builder next hit")) return false;

	Vec2f attackVel = hitPos - blob.getPosition();
	attackVel.Normalize();

	f32 damage = AIB_HIT_DAMAGE;
	blob.server_Hit(target, hitPos, attackVel, damage, Hitters::builder, true);
	Material::fromBlob(blob, target, damage);
	AIBG_RecordInteraction(blob);
	blob.set_u32("ai builder next hit", gameTime + AIB_HIT_DELAY);
	return true;
}

void AIB_ReadyWoodInHand(CBlob@ blob)
{
	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == "mat_wood") return;

	CInventory@ inv = blob.getInventory();
	if (inv is null) return;

	blob.setKeyPressed(key_inventory, true);
	CBlob@ wood = blob.server_PutOutInventory("mat_wood");
	if (wood !is null)
	{
		blob.server_Pickup(wood);
	}
}

void AIB_EnsureHarvestedWood(CBlob@ blob)
{
	if (AIB_HasWood(blob) || AIB_GetNearestWood(blob) !is null) return;

	const u16 quantity = blob.get_u16("ai builder pending wood");
	if (quantity == 0) return;

	CBlob@ wood = server_CreateBlob("mat_wood", blob.getTeamNum(), blob.getPosition());
	if (wood is null) return;

	wood.server_SetQuantity(quantity);
	if (!blob.server_PutInInventory(wood))
	{
		blob.server_Pickup(wood);
	}
	AIBGM_RecordCollectedResource(blob, wood);
	blob.set_u16("ai builder pending wood", 0);
}

void AIB_DropAllResourcesAtPosition(CBlob@ blob, Vec2f position)
{
	CBlob@ carried = blob.getCarriedBlob();
	if (AIB_IsResourceBlob(carried))
	{
		carried.server_DetachFrom(blob);
		carried.setPosition(position);
		carried.setVelocity(Vec2f_zero);
		carried.Tag("aibuilder delivered resource");
	}

	for (u8 i = 0; i < 24; i++)
	{
		CBlob@ resource = AIB_GetInventoryResource(blob);
		if (resource is null) break;

		CBlob@ dropped = blob.server_PutOutInventory(resource.getName());
		if (dropped is null) break;

		dropped.setPosition(position);
		dropped.setVelocity(Vec2f_zero);
		dropped.Tag("aibuilder delivered resource");
	}
}

CBlob@ AIB_GetInventoryResource(CBlob@ blob)
{
	CInventory@ inv = blob.getInventory();
	if (inv is null) return null;

	for (uint i = 0; i < inv.getItemsCount(); i++)
	{
		CBlob@ item = inv.getItem(i);
		if (AIB_IsResourceBlob(item))
		{
			return item;
		}
	}

	return null;
}

bool AIB_ShouldReturnResources(CBlob@ blob)
{
	CInventory@ inv = blob.getInventory();
	if (inv is null) return false;

	if (blob.get_u8("ai builder job") == AIB_JOB_STONE)
	{
		return AIB_ShouldReturnStone(blob);
	}
	if (blob.get_u8("ai builder job") == AIB_JOB_BLUEPRINT)
	{
		return false;
	}

	if (inv.isFull() && AIB_HasInventoryResource(blob)) return true;

	CBlob@ carried = blob.getCarriedBlob();
	return AIB_IsResourceBlob(carried);
}

bool AIB_HasInventoryResource(CBlob@ blob)
{
	return AIB_GetInventoryResource(blob) !is null;
}

bool AIB_HasInventoryResource(CBlob@ blob, const string &in name)
{
	return AIB_GetInventoryResource(blob, name) !is null;
}

CBlob@ AIB_GetInventoryResource(CBlob@ blob, const string &in name)
{
	CInventory@ inv = blob.getInventory();
	if (inv is null) return null;

	for (uint i = 0; i < inv.getItemsCount(); i++)
	{
		CBlob@ item = inv.getItem(i);
		if (item !is null && item.getName() == name)
		{
			return item;
		}
	}

	return null;
}

bool AIB_IsResourceBlob(CBlob@ blob)
{
	if (blob is null) return false;
	return blob.getName().substr(0, 4) == "mat_";
}

bool AIB_IsLooseWorldResource(CBlob@ blob)
{
	return AIBR_IsLooseWorldResource(blob);
}

CBlob@ AIB_GetNearest(CBlob@ blob, CBlob@[]@ candidates)
{
	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < candidates.length; i++)
	{
		CBlob@ candidate = candidates[i];
		if (AIB_IsResourceBlob(candidate) && !AIB_IsLooseWorldResource(candidate)) continue;
		if (candidate is null || candidate.hasTag("dead") || candidate.isInInventory()) continue;
		if (!AIB_IsAccessibleResource(blob, candidate)) continue;

		const f32 distance = (candidate.getPosition() - pos).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}
	return best;
}

bool AIB_IsAllowedByOverseerSelection(CBlob@ tree)
{
	CBlob@[] trees;
	getBlobsByTag("tree", @trees);
	bool hasSelection = false;
	for (uint i = 0; i < trees.length; i++)
	{
		CBlob@ candidate = trees[i];
		if (candidate !is null && candidate.get_bool("aibuilder selected tree"))
		{
			hasSelection = true;
			break;
		}
	}
	if (!hasSelection) return true;

	return tree !is null && tree.get_bool("aibuilder selected tree");
}

bool AIB_IsUrgentPlanCollector(CBlob@ blob)
{
	if (blob is null || !blob.get_bool("aib strategy assigned") || blob.get_u8("ai builder job") != AIB_JOB_WOOD) return false;
	CRules@ rules = getRules();
	const int team = blob.getTeamNum();
	if (rules is null || team < 0 || team >= 8) return false;
	return rules.get_u8(AIBP_PlanKey(u8(team), "status")) == 1 &&
		rules.get_u8(AIBP_PlanKey(u8(team), "intent")) == AIBStrategyIntent::emergency_barrier &&
		rules.get_u16(AIBP_PlanKey(u8(team), "pending")) > 0;
}

CBlob@ AIB_GetBestTreeForHome(CBlob@ blob, CBlob@[]@ candidates)
{
	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null)
	{
		return AIB_GetNearest(blob, candidates);
	}

	CBlob@ best = null;
	f32 bestScore = 999999.0f;
	f32 bestClimbPenalty = 0.0f;
	Vec2f homePos = home.getPosition();
	Vec2f builderPos = blob.getPosition();
	CMap@ map = getMap();
	const bool urgentPlanCollector = AIB_IsUrgentPlanCollector(blob);
	const f32 freeRise = (map is null ? 8.0f : map.tilesize) * AIB_URGENT_TREE_FREE_APPROACH_RISE_TILES;

	for (uint i = 0; i < candidates.length; i++)
	{
		CBlob@ candidate = candidates[i];
		if (candidate is null || candidate.hasTag("dead") || candidate.isInInventory()) continue;
		if (AIB_IsTreeRetryBlocked(blob, candidate)) continue;
		if (!AIB_IsTreeHarvestReady(candidate)) continue;
		if (!AIB_IsAllowedByOverseerSelection(candidate)) continue;
		if (!AIB_IsAccessibleResource(blob, candidate)) continue;

		Vec2f treePos = candidate.getPosition();
		const f32 homeDistance = (treePos - homePos).Length();
		const f32 builderDistance = (treePos - builderPos).Length();
		const Vec2f hitPos = AIB_GetHitPosition(blob, candidate);
		const f32 climbPenalty = urgentPlanCollector ?
			Maths::Max(0.0f, builderPos.y - hitPos.y - freeRise) * AIB_URGENT_TREE_UPHILL_SCORE_PER_PIXEL : 0.0f;
		const f32 score = homeDistance + builderDistance * 0.20f + climbPenalty;

		if (score < bestScore)
		{
			bestScore = score;
			bestClimbPenalty = climbPenalty;
			@best = candidate;
		}
	}
	blob.set_f32("ai builder selected tree climb penalty", bestClimbPenalty);

	return best;
}

bool AIB_IsTreeRetryBlocked(CBlob@ blob, CBlob@ tree)
{
	if (blob is null || tree is null) return true;
	return getGameTime() < blob.get_u32("ai builder tree retry " + tree.getNetworkID());
}

bool AIB_IsLogRetryBlocked(CBlob@ blob, CBlob@ log)
{
	if (blob is null || log is null) return true;
	return getGameTime() < blob.get_u32("ai builder log retry " + log.getNetworkID());
}

void AIB_BeginLogProgress(CBlob@ blob, CBlob@ log)
{
	if (blob is null || log is null) return;
	Vec2f hit = AIB_GetHitPosition(blob, log);
	blob.set_netid("ai builder log progress target", log.getNetworkID());
	blob.set_u32("ai builder log progress tick", getGameTime());
	blob.set_f32("ai builder log progress distance", (hit - blob.getPosition()).Length());
	blob.set_f32("ai builder log progress health", log.getHealth());
}

bool AIB_LogProgressExpired(CBrain@ brain, CBlob@ blob, CBlob@ log, const f32 distance)
{
	if (brain is null || blob is null || log is null) return false;
	if (blob.get_netid("ai builder log progress target") != log.getNetworkID())
	{
		AIB_BeginLogProgress(blob, log);
		return false;
	}

	const f32 previousDistance = blob.get_f32("ai builder log progress distance");
	const f32 previousHealth = blob.get_f32("ai builder log progress health");
	const f32 health = log.getHealth();
	const bool movedCloser = distance + AIB_LOG_DISTANCE_PROGRESS < previousDistance;
	const bool damagedLog = health + 0.001f < previousHealth;
	if (movedCloser || damagedLog)
	{
		blob.set_u32("ai builder log progress tick", getGameTime());
		if (movedCloser) blob.set_f32("ai builder log progress distance", distance);
		blob.set_f32("ai builder log progress health", health);
		return false;
	}

	if (getGameTime() - blob.get_u32("ai builder log progress tick") <= AIB_LOG_NO_PROGRESS_TICKS) return false;

	blob.set_u32("ai builder log retry " + log.getNetworkID(), getGameTime() + AIB_LOG_RETRY_COOLDOWN);
	AIB_LogEvent("ai", "target_abandon", AIB_EventBlobRef(blob), "target=" + AIB_EventBlobRef(log) +
		" reason=no_progress distance=" + distance + " health=" + health + " retry=" + AIB_LOG_RETRY_COOLDOWN);
	brain.SetTarget(null);
	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_netid("ai builder target", 0);
	blob.set_netid("ai builder log progress target", 0);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	AIB_SetState(blob, AIBuilderState::find_log, "log target made no progress");
	return true;
}

void AIB_BeginTreeProgress(CBlob@ blob, CBlob@ tree)
{
	if (blob is null || tree is null) return;
	Vec2f hit = AIB_GetHitPosition(blob, tree);
	blob.set_netid("ai builder tree progress target", tree.getNetworkID());
	blob.set_u32("ai builder tree progress tick", getGameTime());
	blob.set_f32("ai builder tree progress distance", (hit - blob.getPosition()).Length());
	blob.set_f32("ai builder tree progress health", tree.getHealth());
}

bool AIB_TreeProgressExpired(CBrain@ brain, CBlob@ blob, CBlob@ tree, const f32 distance)
{
	if (brain is null || blob is null || tree is null) return false;
	if (blob.get_netid("ai builder tree progress target") != tree.getNetworkID())
	{
		AIB_BeginTreeProgress(blob, tree);
		return false;
	}

	const f32 previousDistance = blob.get_f32("ai builder tree progress distance");
	const f32 previousHealth = blob.get_f32("ai builder tree progress health");
	const f32 health = tree.getHealth();
	const bool movedCloser = distance + AIB_TREE_DISTANCE_PROGRESS < previousDistance;
	const bool damagedTree = health + 0.001f < previousHealth;
	if (movedCloser || damagedTree)
	{
		blob.set_u32("ai builder tree progress tick", getGameTime());
		if (movedCloser) blob.set_f32("ai builder tree progress distance", distance);
		blob.set_f32("ai builder tree progress health", health);
		return false;
	}

	if (getGameTime() - blob.get_u32("ai builder tree progress tick") <= AIB_TREE_NO_PROGRESS_TICKS) return false;

	blob.set_u32("ai builder tree retry " + tree.getNetworkID(), getGameTime() + AIB_TREE_RETRY_COOLDOWN);
	AIB_LogEvent("ai", "target_abandon", AIB_EventBlobRef(blob), "target=" + AIB_EventBlobRef(tree) +
		" reason=no_progress distance=" + distance + " health=" + health + " retry=" + AIB_TREE_RETRY_COOLDOWN);
	brain.SetTarget(null);
	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_netid("ai builder target", 0);
	blob.set_netid("ai builder tree progress target", 0);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	AIB_SetState(blob, AIBuilderState::find_tree, "tree target made no progress");
	return true;
}

bool AIB_FleeFromNearbyKnight(CBrain@ brain, CBlob@ blob)
{
	CBlob@ knight = AIB_GetNearbyThreateningKnight(blob);
	if (knight is null) return false;

	if (AIB_DEBUG)
	{
		AIB_Debug(blob, "fleeing enemy knight id=" + knight.getNetworkID());
	}

	brain.EndPath();
	AIB_EndBrainPath(blob);
	brain.SetTarget(null);
	blob.set_netid("ai builder target", 0);
	blob.set_bool("ai builder justgo", true);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);

	Vec2f pos = blob.getPosition();
	Vec2f enemyPos = knight.getPosition();

	blob.setKeyPressed(enemyPos.x > pos.x ? key_left : key_right, true);
	if (enemyPos.y + getMap().tilesize < pos.y)
	{
		blob.setKeyPressed(key_down, true);
	}
	else if (enemyPos.y > pos.y + getMap().tilesize)
	{
		blob.setKeyPressed(key_up, true);
	}

	AIB_ScaleObstacles(blob, pos + Vec2f(enemyPos.x > pos.x ? -64.0f : 64.0f, 0.0f));
	blob.setAimPos(enemyPos);
	return true;
}

bool AIB_FleeFromNearbyBomb(CBrain@ brain, CBlob@ blob)
{
	CBlob@ bomb = AIB_GetNearbyThreateningBomb(blob);
	if (bomb is null)
	{
		blob.set_netid("ai builder bomb threat", 0);
		return false;
	}

	blob.set_netid("ai builder bomb threat", bomb.getNetworkID());
	if (blob.get_netid("ai builder bomb threat logged") != bomb.getNetworkID())
	{
		blob.set_netid("ai builder bomb threat logged", bomb.getNetworkID());
		AIB_LogEvent("ai", "flee_bomb", AIB_EventBlobRef(blob), "bomb=" + AIB_EventBlobRef(bomb) +
			" distance=" + blob.getDistanceTo(bomb) + " pos=" + AIB_EventPos(blob.getPosition()));
	}

	brain.EndPath();
	AIB_EndBrainPath(blob);
	brain.SetTarget(null);
	blob.set_netid("ai builder target", 0);
	blob.set_bool("ai builder justgo", true);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);

	Vec2f pos = blob.getPosition();
	Vec2f bombPos = bomb.getPosition();
	const bool bombOnRight = bombPos.x > pos.x;
	blob.setKeyPressed(bombOnRight ? key_left : key_right, true);
	if (bombPos.y + getMap().tilesize < pos.y)
	{
		blob.setKeyPressed(key_down, true);
	}
	else if (bombPos.y > pos.y + getMap().tilesize)
	{
		blob.setKeyPressed(key_up, true);
	}

	AIB_ScaleObstacles(blob, pos + Vec2f(bombOnRight ? -64.0f : 64.0f, 0.0f));
	blob.setAimPos(bombPos);
	return true;
}

CBlob@ AIB_GetNearbyThreateningBomb(CBlob@ blob)
{
	CMap@ map = getMap();
	if (map is null) return null;
	CBlob@[] nearby;
	if (!map.getBlobsInRadius(blob.getPosition(), AIB_BOMB_FEAR_RADIUS, @nearby)) return null;

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	for (uint i = 0; i < nearby.length; i++)
	{
		CBlob@ candidate = nearby[i];
		if (candidate is null || candidate.getName() != "bomb" || candidate.hasTag("dead") || !candidate.hasTag("activated")) continue;
		if (candidate.getTeamNum() == blob.getTeamNum()) continue;

		const f32 distance = blob.getDistanceTo(candidate);
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}
	return best;
}

CBlob@ AIB_GetNearbyThreateningKnight(CBlob@ blob)
{
	CBlob@[] enemies;
	if (!getMap().getBlobsInRadius(blob.getPosition(), AIB_KNIGHT_FEAR_RADIUS, @enemies)) return null;

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	for (uint i = 0; i < enemies.length; i++)
	{
		CBlob@ enemy = enemies[i];
		if (enemy is null || enemy.getName() != "knight") continue;
		if (enemy.hasTag("dead") || enemy.getTeamNum() == blob.getTeamNum()) continue;
		if (!AIB_HasDirectEnemyPath(blob.getPosition(), enemy)) continue;

		const f32 distance = blob.getDistanceTo(enemy);
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = enemy;
		}
	}

	return best;
}

bool AIB_IsAccessibleResource(CBlob@ blob, CBlob@ resource)
{
	if (!AIB_IsInsideCurrentBarrierZone(blob, resource.getPosition()))
	{
		if (AIB_DEBUG)
		{
			AIB_Debug(blob, "ignored " + resource.getName() + " outside current barrier zone");
		}
		AIB_LogResourceRejectionDelta(blob, resource, "barrier");
		return false;
	}

	if (!AIB_IsSafeResource(blob, resource.getPosition()))
	{
		if (AIB_DEBUG)
		{
			AIB_Debug(blob, "ignored " + resource.getName() + " in unsafe enemy zone");
		}
		AIB_LogResourceRejectionDelta(blob, resource, "unsafe");
		return false;
	}

	return true;
}

void AIB_LogResourceRejectionDelta(CBlob@ blob, CBlob@ resource, const string &in reason)
{
	if (blob is null || resource is null || !AIB_EventLogEnabled()) return;
	const string key = "aib reject log " + reason + " " + resource.getNetworkID();
	const u32 now = getGameTime();
	const u32 last = blob.get_u32(key);
	if (last != 0 && now - last < AIB_RESOURCE_REJECT_LOG_REFRESH) return;
	blob.set_u32(key, now);
	AIB_LogEvent("ai", "reject_resource", AIB_EventBlobRef(blob), "resource=" + AIB_EventBlobRef(resource) +
		" reason=" + reason + " pos=" + AIB_EventPos(resource.getPosition()));
}

bool AIB_IsInsideCurrentBarrierZone(CBlob@ blob, Vec2f position)
{
	return AIBR_IsOnSameBarrierSide(blob, position);
}

bool AIB_IsSafeResource(CBlob@ blob, Vec2f position)
{
	CBlob@[] enemies;
	if (!getMap().getBlobsInRadius(position, AIB_SAFE_RADIUS, @enemies)) return true;

	for (uint i = 0; i < enemies.length; i++)
	{
		CBlob@ enemy = enemies[i];
		if (!AIB_IsEnemyCombatClass(blob, enemy)) continue;

		if (AIB_HasDirectEnemyPath(position, enemy))
		{
			return false;
		}
	}

	return true;
}

bool AIB_IsEnemyCombatClass(CBlob@ blob, CBlob@ enemy)
{
	if (enemy is null || enemy is blob || enemy.hasTag("dead")) return false;
	if (enemy.getTeamNum() == blob.getTeamNum()) return false;

	const string name = enemy.getName();
	return name == "knight" || name == "archer";
}

bool AIB_HasDirectEnemyPath(Vec2f position, CBlob@ enemy)
{
	return !AIB_HasTallWallBetween(position, enemy.getPosition());
}

bool AIB_HasTallWallBetween(Vec2f a, Vec2f b)
{
	CMap@ map = getMap();
	if (map is null) return false;

	const int minX = Maths::Min(a.x, b.x) / map.tilesize + 1;
	const int maxX = Maths::Max(a.x, b.x) / map.tilesize - 1;
	const int footY = Maths::Max(a.y, b.y) / map.tilesize;
	const int topY = Maths::Max(0, footY - 11);

	for (int x = minX; x <= maxX; x++)
	{
		u8 solidRun = 0;
		for (int y = footY; y >= topY; y--)
		{
			if (map.isTileSolid(Vec2f(x * map.tilesize + map.tilesize * 0.5f, y * map.tilesize + map.tilesize * 0.5f)))
			{
				solidRun++;
				if (solidRun >= 6) return true;
			}
			else
			{
				solidRun = 0;
			}
		}
	}

	return false;
}

bool AIB_HasWood(CBlob@ blob)
{
	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == "mat_wood" && !AIB_IsStarterMaterial(carried))
	{
		return true;
	}

	CInventory@ inv = blob.getInventory();
	if (inv is null) return false;

	for (uint i = 0; i < inv.getItemsCount(); i++)
	{
		CBlob@ item = inv.getItem(i);
		if (item !is null && item.getName() == "mat_wood" && !AIB_IsStarterMaterial(item))
		{
			return true;
		}
	}

	return false;
}

bool AIB_IsStarterMaterial(CBlob@ material)
{
	return material !is null && material.hasTag("aibuilder starter material");
}

bool AIB_HasStone(CBlob@ blob)
{
	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == "mat_stone")
	{
		return true;
	}

	CInventory@ inv = blob.getInventory();
	if (inv is null) return false;
	if (inv.getCount("mat_stone") > 0) return true;

	for (uint i = 0; i < inv.getItemsCount(); i++)
	{
		CBlob@ item = inv.getItem(i);
		if (item !is null && item.getName() == "mat_stone")
		{
			return true;
		}
	}

	return false;
}

bool AIB_HasGold(CBlob@ blob)
{
	if (blob is null) return false;
	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == "mat_gold") return true;

	CInventory@ inv = blob.getInventory();
	return inv !is null && inv.getCount("mat_gold") > 0;
}

bool AIB_ShouldReturnStone(CBlob@ blob)
{
	CInventory@ inv = blob.getInventory();
	if (inv is null) return false;

	return AIB_CountStone(blob) >= AIB_STONE_RETURN_AMOUNT ||
		(inv.isFull() && AIB_HasInventoryResource(blob, "mat_stone"));
}

u16 AIB_CountStone(CBlob@ blob)
{
	u16 total = 0;
	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == "mat_stone")
	{
		total += carried.getQuantity();
	}

	CInventory@ inv = blob.getInventory();
	if (inv is null) return total;
	total += inv.getCount("mat_stone");

	return total;
}

void AIB_FloatInWater(CBlob@ blob)
{
	if (blob.isInWater() && blob.get_u8("air_count") < AIB_AIR_SURFACE_BELOW)
	{
		blob.setKeyPressed(key_up, true);
	}
}

bool AIB_HandleBreathing(CBrain@ brain, CBlob@ blob)
{
	if (blob is null) return false;

	const u8 air = blob.get_u8("air_count");
	if (air < AIB_AIR_SURFACE_BELOW)
	{
		blob.set_bool("ai builder surfacing for air", true);
	}
	else if (air >= AIB_AIR_RESUME_AT)
	{
		blob.set_bool("ai builder surfacing for air", false);
	}

	if (!blob.get_bool("ai builder surfacing for air")) return false;

	if (brain !is null)
	{
		brain.EndPath();
	}
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.setKeyPressed(key_action1, false);
	blob.setKeyPressed(key_action2, false);
	blob.setKeyPressed(key_action3, false);

	if (blob.isInWater())
	{
		blob.setKeyPressed(key_up, true);
		AIB_ReportWaitingStatus(blob, "Surfacing for air");
	}
	else
	{
		AIB_ReportWaitingStatus(blob, "Catching breath");
	}
	return true;
}

string AIB_StateName(const u8 state)
{
	switch (state)
	{
		case AIBuilderState::idle: return "idle";
		case AIBuilderState::find_tree: return "find_tree";
		case AIBuilderState::chop_tree: return "chop_tree";
		case AIBuilderState::find_log: return "find_log";
		case AIBuilderState::chop_log: return "chop_log";
		case AIBuilderState::find_wood: return "find_wood";
		case AIBuilderState::return_wood: return "return_wood";
		case AIBuilderState::find_stone: return "find_stone";
		case AIBuilderState::prepare_stone_shaft: return "prepare_stone_shaft";
		case AIBuilderState::dig_stone_shaft: return "dig_stone_shaft";
		case AIBuilderState::tunnel_to_stone: return "tunnel_to_stone";
		case AIBuilderState::find_stone_mat: return "find_stone_mat";
		case AIBuilderState::collect_blueprint_resources: return "collect_blueprint_resources";
		case AIBuilderState::find_blueprint_block: return "find_blueprint_block";
		case AIBuilderState::build_blueprint_block: return "build_blueprint_block";
		case AIBuilderState::nursery_collect_wood: return "nursery_collect_wood";
		case AIBuilderState::nursery_build: return "nursery_build";
		case AIBuilderState::nursery_collect_stone: return "nursery_collect_stone";
		case AIBuilderState::nursery_buy_seed: return "nursery_buy_seed";
		case AIBuilderState::nursery_plant_seed: return "nursery_plant_seed";
		case AIBuilderState::nursery_wait_tree: return "nursery_wait_tree";
		case AIBuilderState::visit_resupply: return "visit_resupply";
		case AIBuilderState::deliver_log_to_saw: return "deliver_log_to_saw";
	}

	return "unknown";
}

string AIB_BrainStateName(CBrain@ brain)
{
	if (brain is null) return "null";

	switch (brain.getState())
	{
		case CBrain::idle: return "idle";
		case CBrain::searching: return "searching";
		case CBrain::has_path: return "has_path";
		case CBrain::stuck: return "stuck";
		case CBrain::wrong_path: return "wrong_path";
	}

	return "unknown";
}

void AIB_ReportWaitingStatus(CBlob@ blob, const string &in reason)
{
	AIB_ReportTimedStatus(blob, reason, "wait");
}

void AIB_ReportTimedStatus(CBlob@ blob, const string &in reason, const string &in channel)
{
	if (blob is null || reason.length == 0) return;

	const u32 now = getGameTime();
	const string key = "ai builder status " + channel;
	const u32 touched = blob.get_u32(key + " touched");
	const string previous = blob.get_string(key + " reason");

	// A different condition, or even one tick without this condition, starts a
	// fresh ten-second wait. This keeps brief pathing hiccups from making noise.
	if (previous != reason || touched + 1 < now)
	{
		blob.set_string(key + " reason", reason);
		blob.set_u32(key + " next", now + AIB_STATUS_BUBBLE_RATE);
	}
	blob.set_u32(key + " touched", now);

	if (now < blob.get_u32(key + " next")) return;

	CBitStream params;
	params.write_string(reason);
	blob.SendCommand(blob.getCommandID("ai builder status bubble"), params);
	blob.set_u32(key + " next", now + AIB_STATUS_BUBBLE_RATE);
}

bool AIB_ResumeActiveJob(CBlob@ blob, const string &in reason)
{
	if (blob is null || !blob.get_bool("ai builder job active")) return false;

	const u8 job = blob.get_u8("ai builder job");
	if (job == AIB_JOB_STONE)
	{
		AIB_SetState(blob, AIBuilderState::find_stone, reason);
	}
	else if (job == AIB_JOB_BLUEPRINT)
	{
		AIB_SetState(blob, AIBuilderState::collect_blueprint_resources, reason);
	}
	else
	{
		AIB_SetState(blob, AIBuilderState::find_tree, reason);
	}
	return true;
}

void AIB_SetState(CBlob@ blob, const u8 next, const string &in reason)
{
	const u8 previous = blob.get_u8("ai builder state");

	if (previous != next)
	{
		if (next == AIBuilderState::collect_blueprint_resources &&
			blob.getTeamNum() >= 0 && blob.getTeamNum() < 8)
		{
			// Material acquisition can take arbitrarily long and must never lock a
			// task away from another ordinary worker or an infinite-resource orb.
			AIBP_ReleaseBuilderReservation(u8(blob.getTeamNum()), blob.getNetworkID());
		}
		// State owns intent; paths and pressed keys from the previous state must
		// not leak into the next controller. Targets/tile targets are preserved
		// because transitions such as find_tree -> chop_tree and stone routing
		// deliberately hand those task objects forward.
		CBrain@ brain = blob.getBrain();
		if (brain !is null) brain.EndPath();
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		blob.set_bool("ai builder justgo", false);
		blob.set_u8("ai builder obstruction threshold", 0);
		blob.set_Vec2f("ai builder jump peak", Vec2f_zero);
		if (next != AIBuilderState::tunnel_to_stone)
		{
			blob.set_Vec2f(AIBM_STONE_EXPOSED_TARGET_KEY, Vec2f_zero);
			blob.set_Vec2f(AIBM_STONE_EXPOSED_APPROACH_KEY, Vec2f_zero);
		}
		if (next != AIBuilderState::return_wood)
			blob.set_Vec2f(AIBM_STONE_RETURN_EGRESS_KEY, Vec2f_zero);
		blob.setKeyPressed(key_left, false);
		blob.setKeyPressed(key_right, false);
		blob.setKeyPressed(key_up, false);
		blob.setKeyPressed(key_down, false);
		blob.setKeyPressed(key_action1, false);
		blob.setKeyPressed(key_action2, false);
		blob.set_u16("ai builder navigation epoch", blob.get_u16("ai builder navigation epoch") + 1);
		blob.set_u8("ai builder state", next);
		blob.Sync("ai builder state", true);
		AIB_LogEvent("ai", "state", AIB_EventBlobRef(blob), "from=" + AIB_StateName(previous) + " to=" + AIB_StateName(next) + " reason=" + reason + " pos=" + AIB_EventPos(blob.getPosition()));
		AIB_Debug(blob, "state " + AIB_StateName(previous) + " -> " + AIB_StateName(next) + " reason=" + reason);
	}
	else
	{
		blob.set_u8("ai builder state", next);
		AIB_Debug(blob, "state stays " + AIB_StateName(next) + " reason=" + reason);
	}
}

void AIB_SyncPublicState(CBlob@ blob, const bool force)
{
	if (blob is null) return;
	const u32 now = getGameTime();
	if (!force && (now + u32(blob.getNetworkID())) % AIB_PUBLIC_STATE_SYNC_RATE != 0) return;
	blob.Sync("ai builder state", true);
	blob.Sync("ai builder job", true);
	blob.Sync("ai builder job active", true);
}

void AIB_Debug(CBlob@ blob, const string &in message)
{
	if (!AIB_DEBUG || blob is null) return;

	print("[AIBuilder] t=" + getGameTime() +
		" id=" + blob.getNetworkID() +
		" state=" + AIB_StateName(blob.get_u8("ai builder state")) +
		" target=" + blob.get_netid("ai builder target") +
		" pending=" + blob.get_u16("ai builder pending wood") +
		" hasWood=" + AIB_BoolString(AIB_HasWood(blob)) +
		" justgo=" + AIB_BoolString(blob.get_bool("ai builder justgo")) +
		" msg=" + message);
}

void AIB_DebugSnapshot(CBrain@ brain, CBlob@ blob, const u8 state)
{
	if (!AIB_DEBUG || blob is null) return;
	if ((getGameTime() + blob.getNetworkID()) % AIB_DEBUG_SNAPSHOT_RATE != 0) return;

	CBlob@ target = getBlobByNetworkID(blob.get_netid("ai builder target"));
	const string targetName = target is null ? "null" : target.getName();
	const f32 targetDistance = target is null ? -1.0f : blob.getDistanceTo(target);

	AIB_Debug(blob, "snapshot brain=" + AIB_BrainStateName(brain) +
		" current=" + AIB_StateName(state) +
		" targetName=" + targetName +
		" targetDistance=" + targetDistance +
		" nearestTree=" + AIB_BoolString(AIB_GetNearestTree(blob) !is null) +
		" nearestLog=" + AIB_BoolString(AIB_GetNearestLog(blob) !is null) +
		" nearestWood=" + AIB_BoolString(AIB_GetNearestWood(blob) !is null) +
		" waitLeft=" + Maths::Max(0, int(blob.get_u32("ai builder log wait until")) - int(getGameTime())) +
		" obstruction=" + blob.get_u8("ai builder obstruction threshold"));
}

string AIB_BoolString(const bool value)
{
	return value ? "true" : "false";
}
