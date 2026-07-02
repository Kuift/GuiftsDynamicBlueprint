// AIBuilderBrain.as

#define SERVER_ONLY

#include "Hitters.as";
#include "MaterialCommon.as";
#include "AIBBarrierCommon.as";
#include "AIBEventLog.as";
#include "BlueprintData.as";
#include "Pathing/BrainPathing.as";
#include "MakeSeed.as";

const f32 AIB_HIT_DAMAGE = 0.5f;
const u8 AIB_HIT_DELAY = 12;
const u8 AIB_LOG_WAIT = 45;
const f32 AIB_SAFE_RADIUS = 10.0f * 8.0f;
const f32 AIB_KNIGHT_FEAR_RADIUS = 10.0f * 8.0f;
const u8 AIB_JOB_WOOD = 0;
const u8 AIB_JOB_STONE = 1;
const u8 AIB_JOB_BLUEPRINT = 2;
const u8 AIB_STONE_SCAN_RADIUS = 80;
const u8 AIB_STONE_LOCAL_RADIUS = 3;
const u16 AIB_STONE_RETURN_AMOUNT = 250;
const u8 AIB_BLUEPRINT_PLACE_DELAY = 8;
const u8 AIB_LADDER_WOOD_COST = 10;
const u8 AIB_LADDER_BACKWALL_WOOD_COST = 2;
const u8 AIB_LADDER_OBSTRUCTION_THRESHOLD = 14;
const u8 AIB_LADDER_PLACE_DELAY = 45;
const u8 AIB_LADDER_BACKWALL_MAX_CHAIN = 8;
const f32 AIB_LADDER_HORIZONTAL_ANGLE = 90.0f;
const u8 AIB_STONE_CORNER_OBSTRUCTION_THRESHOLD = 12;
const u8 AIB_STONE_CORNER_ESCAPE_TICKS = 12;
const u8 AIB_STONE_CORNER_ESCAPE_COOLDOWN = 45;
const u16 AIB_BUILDER_SHOP_WOOD_COST = 50;
const u16 AIB_CRATE_WOOD_COST = 150;
const u16 AIB_NURSERY_WOOD_COST = 100;
const u16 AIB_NURSERY_SEED_STONE_COST = 20;
const u16 AIB_QUARRY_WOOD_COST = 200;
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
const u32 AIB_STATUS_BUBBLE_RATE = 10 * 30;

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
		nursery_wait_tree
	}
}

void onInit(CBrain@ this)
{
	CBlob@ blob = this.getBlob();
	blob.set_u8("ai builder state", AIBuilderState::idle);
	blob.set_netid("ai builder target", 0);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_Vec2f("ai builder tile target", Vec2f_zero);
	blob.set_Vec2f("ai builder shaft top", Vec2f_zero);
	blob.set_u8("ai builder job", AIB_JOB_WOOD);
	blob.set_u32("ai builder log wait until", 0);
	blob.set_u16("ai builder pending wood", 0);
	blob.set_u8("ai builder obstruction threshold", 0);
	blob.set_bool("ai builder justgo", false);
	blob.set_u32("ai builder next place", 0);
	blob.set_u32("ai builder next pickup", 0);
	blob.set_u32("ai builder next ladder", 0);
	blob.set_u32("ai builder stone corner escape until", 0);
	blob.set_u32("ai builder stone corner escape cooldown", 0);
	blob.set_s32("ai builder stone corner escape direction", 0);
	blob.set_u32("ai builder next blueprint clearance jump", 0);
	blob.set_u32("ai builder next seed buy", 0);
	blob.set_u32("ai builder nursery wait until", 0);
	blob.set_u32("ai builder next stone supply", 0);
	blob.set_Vec2f("ai builder jump peak", Vec2f_zero);
	blob.set_u8("ai builder debug last state", AIBuilderState::idle);
	BrainPath@ path = BrainPath(blob, Path::ALL);
	blob.set("ai builder brain path", @path);

	this.server_SetActive(true);
	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
	this.getCurrentScript().tickFrequency = 1;
}

void onTick(CBrain@ this)
{
	CBlob@ blob = this.getBlob();
	if (blob is null || blob.hasTag("dead")) return;
	if (blob.isAttached())
	{
		blob.server_DetachFromAll();
		AIB_FloatInWater(blob);
		return;
	}

	const u8 state = blob.get_u8("ai builder state");
	AIB_DebugSnapshot(this, blob, state);
	if (this.getState() == CBrain::stuck || this.getState() == CBrain::wrong_path)
	{
		AIB_ReportTimedStatus(blob, "Stuck while " + AIB_StateName(state), "stuck");
	}
	if (AIB_FleeFromNearbyKnight(this, blob))
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
	if (AIB_TryRecoverStoneCorner(this, blob, activeState))
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
	}

	AIB_FloatInWater(blob);
}

void AIB_FindTree(CBrain@ brain, CBlob@ blob)
{
	CBlob@ tree = AIB_GetNearestTree(blob);
	if (tree is null)
	{
		CBlob@ growingTree = AIB_GetNearestAccessibleTreeIgnoringMaturity(blob);
		if (growingTree !is null && !AIB_IsTreeHarvestReady(growingTree))
		{
			AIB_ReportWaitingStatus(blob, "Waiting for trees to mature");
			return;
		}

		if (AIB_GetNearestTreeIgnoringSelection(blob) is null)
		{
			AIB_SetState(blob, AIBuilderState::nursery_collect_wood, "no accessible trees; starting nursery quest");
		}
		else
		{
			AIB_SetState(blob, AIBuilderState::find_tree, "no overseer-selected tree available");
		}
		return;
	}

	brain.SetTarget(tree);
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
	blob.set_netid("ai builder target", tree.getNetworkID());
	AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=" + AIB_EventBlobRef(tree) + " state=chop_tree pos=" + AIB_EventPos(blob.getPosition()));
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

	blob.setAimPos(treePos);
	if (distance > 32.0f)
	{
		AIB_GoTo(brain, blob, treePos);
	}
	else
	{
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
		return;
	}

	Vec2f logPos = AIB_GetHitPosition(blob, log);
	Vec2f blobPos = blob.getPosition();
	const f32 distance = (logPos - blobPos).Length();

	blob.setAimPos(logPos);
	if (distance > 28.0f)
	{
		AIB_GoTo(brain, blob, logPos);
	}
	else
	{
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
		AIB_ReadyWoodInHand(blob);
		AIB_SetState(blob, AIBuilderState::return_wood, "picked loose wood");
	}
}

void AIB_ReturnWood(CBrain@ brain, CBlob@ blob)
{
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

	AIB_StashCarriedResource(blob);
	if (!AIB_StoreResourcesInBaseCrates(blob, home))
	{
		AIB_ReportWaitingStatus(blob, "Waiting for storage at home");
		AIB_Debug(blob, "waiting for crate storage at base");
		return;
	}
	AIB_LogEvent("ai", "store_resources", AIB_EventBlobRef(blob), "home=" + AIB_EventBlobRef(home) + " pos=" + AIB_EventPos(home.getPosition()));

	if (job == AIB_JOB_STONE)
	{
		AIB_SetState(blob, AIBuilderState::find_stone, "resources delivered");
	}
	else
	{
		if (AIB_TryMaintainBaseQuarry(brain, blob, home))
		{
			return;
		}
		AIB_SetState(blob, AIBuilderState::find_tree, "wood delivered");
	}
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
		AIB_SetState(blob, AIBuilderState::find_stone, "inside barrier strip, retrying stone job");
		return;
	}

	Vec2f stone = AIB_GetBestStoneTile(blob);
	if (stone == Vec2f_zero)
	{
		if (AIB_TryUseBaseStoneSource(brain, blob)) return;
		AIB_SetState(blob, AIBuilderState::find_stone, "no stone source found, retrying stone job");
		return;
	}

	blob.set_Vec2f("ai builder tile target", stone);
	blob.set_Vec2f("ai builder shaft top", Vec2f_zero);
	AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=stone_tile state=tunnel_to_stone tile=" + AIB_EventPos(stone) + " pos=" + AIB_EventPos(blob.getPosition()));
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
	if (target == Vec2f_zero || !AIB_IsStoneTile(target))
	{
		AIB_CollectNearbyStone(blob);
		if (AIB_ShouldReturnStone(blob))
		{
			AIB_SetState(blob, AIBuilderState::return_wood, "stone quota reached");
			return;
		}

		Vec2f nearbyStone = AIB_GetNearbyStoneTile(blob, target == Vec2f_zero ? blob.getPosition() : target, AIB_STONE_LOCAL_RADIUS);
		if (nearbyStone != Vec2f_zero)
		{
			blob.set_Vec2f("ai builder tile target", nearbyStone);
			AIB_LogEvent("ai", "target", AIB_EventBlobRef(blob), "target=nearby_stone_tile state=tunnel_to_stone tile=" + AIB_EventPos(nearbyStone) + " pos=" + AIB_EventPos(blob.getPosition()));
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
	if (AIB_ShouldReturnStone(blob))
	{
		AIB_SetState(blob, AIBuilderState::return_wood, "stone quota reached");
		return;
	}

	Vec2f targetCenter = AIB_TileCenter(target);
	Vec2f clearanceTile = AIB_GetPassageClearanceTile(blob, target);
	if (clearanceTile != Vec2f_zero && !AIB_ShouldAvoidDirtClearance(blob, target, clearanceTile))
	{
		Vec2f clearanceCenter = AIB_TileCenter(clearanceTile);
		if ((clearanceCenter - blob.getPosition()).Length() <= 40.0f)
		{
			AIB_MineTile(blob, clearanceTile);
			return;
		}

		AIB_GoTo(brain, blob, clearanceCenter);
		return;
	}

	Vec2f blockingTile = AIB_GetBlockingTileTowardStone(blob, target);
	if (blockingTile != Vec2f_zero && (blockingTile - target).Length() > 1.0f && !AIB_ShouldAvoidDirtClearance(blob, target, blockingTile))
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

	Vec2f approach = AIB_GetApproachPositionForStone(blob, target);
	const bool hasOpenApproach = (approach - targetCenter).Length() > 1.0f;
	const bool shouldDig = !hasOpenApproach ||
		blob.get_u8("ai builder obstruction threshold") > 8 ||
		brain.getState() == CBrain::stuck ||
		brain.getState() == CBrain::wrong_path;

	if (shouldDig)
	{
		Vec2f dig = AIB_GetNextTunnelTile(blob, target);
		if (dig != Vec2f_zero)
		{
			Vec2f digCenter = AIB_TileCenter(dig);
			if ((digCenter - blob.getPosition()).Length() <= 40.0f)
			{
				AIB_MineTile(blob, dig);
				return;
			}

			AIB_GoTo(brain, blob, digCenter);
			return;
		}
	}

	AIB_GoTo(brain, blob, approach);
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
			AIB_SetState(blob, AIBuilderState::tunnel_to_stone, "nearby stone found");
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
				AIB_SetState(blob, AIBuilderState::tunnel_to_stone, "picked loose stone, nearby stone remains");
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
	const u8 team = u8(blob.getTeamNum());
	Vec2f targetTile = blob.get_Vec2f("ai builder tile target");
	if (targetTile != Vec2f_zero)
	{
		const u16 target = AIB_GetBlueprintTargetForTile(targetTile, team);
		if (target != 0)
		{
			material = AIBP_BlockMaterial(target);
			amount = AIBP_BlockCost(target);
			return material != "" && AIB_CountMaterial(blob, material) < amount;
		}
	}

	const u16 wood = AIBP_MinRemainingBlockCost(team, "mat_wood");
	const u16 stone = AIBP_MinRemainingBlockCost(team, "mat_stone");
	if ((wood > 0 && AIB_CountWood(blob) >= wood) || (stone > 0 && AIB_CountStone(blob) >= stone)) return false;
	if (wood > 0 && AIB_CountWood(blob) < wood)
	{
		material = "mat_wood"; amount = wood; return true;
	}
	if (stone > 0 && AIB_CountStone(blob) < stone)
	{
		material = "mat_stone"; amount = stone; return true;
	}
	return false;
}

void AIB_FindBlueprintBlock(CBrain@ brain, CBlob@ blob)
{
	Vec2f tile = AIB_GetNearestBlueprintBuildTile(blob);
	if (tile == Vec2f_zero)
	{
		if (blob.get_bool("ai builder saw blueprint target"))
		{
			AIB_ReportWaitingStatus(blob, "Waiting for blueprint work");
		}
		blob.set_Vec2f("ai builder tile target", Vec2f_zero);
		AIB_EndBrainPath(blob);
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		return;
	}

	blob.set_bool("ai builder saw blueprint target", true);
	blob.set_Vec2f("ai builder tile target", tile);
	string needed;
	u16 amount = 0;
	if (AIB_GetBlueprintMaterialNeed(blob, needed, amount))
	{
		AIB_SetState(blob, AIBuilderState::collect_blueprint_resources, "need " + needed + "=" + amount);
		return;
	}
	AIB_SetState(blob, AIBuilderState::build_blueprint_block, "blueprint target acquired");
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
		AIB_SetState(blob, AIBuilderState::find_blueprint_block, "blueprint tile complete");
		return;
	}

	Vec2f center = AIB_TileCenter(tile);
	if (AIB_ClearBlueprintPlacementPosition(brain, blob, tile)) return;
	if (AIB_ClearBlueprintSiteObstruction(brain, blob, tile)) return;

	Vec2f approach = AIB_GetBlueprintBuildApproach(blob, tile);
	if ((center - blob.getPosition()).Length() > 32.0f && (approach - blob.getPosition()).Length() > 18.0f)
	{
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

	const u16 target = AIB_GetBlueprintTargetForTile(tile, u8(blob.getTeamNum()));
	if (!AIBP_IsSolidTileBlock(target) && !AIBP_IsBlobBlock(target)) return false;

	Vec2f center = AIB_TileCenter(tile);
	Vec2f pos = blob.getPosition();
	// AIBuilder.cfg uses a 7.5 px shape radius; a tile extends 4 px from center.
	// Leave a small safety margin because positions are integrated between ticks.
	if (Maths::Abs(pos.x - center.x) >= 12.0f || Maths::Abs(pos.y - center.y) >= 12.0f) return false;

	f32 direction = pos.x < center.x ? -1.0f : 1.0f;
	const f32 sidestep = map.tilesize * 2.0f;
	if (!AIB_HasBuilderClearance(pos + Vec2f(direction * sidestep, 0.0f), blob.getTeamNum()) &&
		AIB_HasBuilderClearance(pos + Vec2f(-direction * sidestep, 0.0f), blob.getTeamNum()))
	{
		direction = -direction;
	}

	brain.EndPath();
	AIB_EndBrainPath(blob);
	blob.set_Vec2f("ai builder destination", Vec2f_zero);
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
	if (AIB_GoToBrainPath(brain, blob, destination))
	{
		return;
	}

	AIB_GoToFallback(brain, blob, destination);
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
		path.SetPath(pos, destination);
		blob.set_Vec2f("ai builder destination", destination);
		blob.set_bool("ai builder justgo", false);
		brain.EndPath();
		AIB_LogEvent("ai", "path_set", AIB_EventBlobRef(blob), "destination=" + AIB_EventPos(destination) + " waypoints=" + path.waypoints.length + " low=" + path.path.length);
	}

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
	Vec2f mine = AIB_GetMineablePathBlock(blob, path);
	if (mine != Vec2f_zero)
	{
		if ((AIB_TileCenter(mine) - pos).Length() <= 40.0f)
		{
			AIB_MineTile(blob, mine);
			return true;
		}
	}

	path.Tick();
	path.SetSuggestedKeys();
	path.SetSuggestedAimPos();

	AIB_ScaleObstacles(blob, next);
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
	if (!clearDirectRay) return true;

	// Close uphill targets can still require moving away from the target first.
	// In that case direct key movement repeatedly jumps at the slope; let CBrain
	// follow the path nodes instead.
	return false;
}

// A builder can jump under a one-tile overhang and remain pinned between the
// underside and the block's vertical face.  Repathing and obstacle scaling both
// keep pressing up in that geometry, so neither can lower the builder enough to
// move away.  After confirmed immobility, briefly suppress jumping and walk
// away from the overhang.  This is deliberately limited to active stone jobs,
// the asymmetric one-block corner shape, and a short cooldown.
bool AIB_TryRecoverStoneCorner(CBrain@ brain, CBlob@ blob, const u8 state)
{
	if (brain is null || blob is null || blob.get_u8("ai builder job") != AIB_JOB_STONE) return false;
	if (state != AIBuilderState::tunnel_to_stone && state != AIBuilderState::find_stone_mat && state != AIBuilderState::return_wood) return false;

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

	if (now < blob.get_u32("ai builder stone corner escape cooldown") ||
		blob.get_u8("ai builder obstruction threshold") < AIB_STONE_CORNER_OBSTRUCTION_THRESHOLD) return false;

	const s32 direction = AIB_GetStoneCornerEscapeDirection(blob);
	if (direction == 0) return false;

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
	const f32 radius = blob.getRadius();
	const f32 side = radius + 1.0f;
	const f32 upper = -radius * 0.70f;
	const f32 lower = radius * 0.55f;
	const bool upperLeft = map.isTileSolid(pos + Vec2f(-side, upper));
	const bool lowerLeft = map.isTileSolid(pos + Vec2f(-side, lower));
	const bool upperRight = map.isTileSolid(pos + Vec2f(side, upper));
	const bool lowerRight = map.isTileSolid(pos + Vec2f(side, lower));
	const bool leftOverhang = upperLeft && !lowerLeft;
	const bool rightOverhang = upperRight && !lowerRight;

	if (leftOverhang == rightOverhang) return 0;
	return leftOverhang ? 1 : -1;
}

void AIB_DriveStoneCornerEscape(CBlob@ blob)
{
	if (blob is null) return;

	const s32 direction = blob.get_s32("ai builder stone corner escape direction");
	blob.setKeyPressed(key_up, false);
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	if (direction < 0) blob.setKeyPressed(key_left, true);
	else if (direction > 0) blob.setKeyPressed(key_right, true);
}

void AIB_DetectObstructions(CBrain@ brain, CBlob@ blob, Vec2f destination)
{
	u8 threshold = blob.get_u8("ai builder obstruction threshold");
	const bool obstructed = (blob.getPosition() - blob.getOldPosition()).Length() < 2.5f;

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
		AIB_TrySomethingNew(brain, blob, destination);
		blob.setKeyPressed(key_up, true);
	}

	blob.set_u8("ai builder obstruction threshold", threshold);
}

void AIB_DetectBrainPathObstructions(CBlob@ blob, BrainPath@ path, Vec2f destination, Vec2f next)
{
	if (blob is null || path is null) return;

	u8 threshold = blob.get_u8("ai builder obstruction threshold");
	const bool obstructed = (blob.getPosition() - blob.getOldPosition()).Length() < 2.5f;
	const bool uphill = AIB_IsUphillPathTarget(blob, next);
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
		const bool placedLadder = AIB_TryPlaceRecoveryLadder(blob, next);
		threshold = 0;
		path.EndPath();
		blob.set_Vec2f("ai builder destination", Vec2f_zero);
		blob.set_bool("ai builder justgo", false);
		blob.setKeyPressed(key_up, true);
		AIB_LogEvent("ai", "path_replan", AIB_EventBlobRef(blob), "reason=" + (placedLadder ? "ladder_recovery" : "obstruction") + " destination=" + AIB_EventPos(destination));
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

	const u16 woodCost = AIB_LADDER_WOOD_COST + backwallChain.length * AIB_LADDER_BACKWALL_WOOD_COST;
	if (AIB_CountWood(blob) < woodCost) return false;

	CBlob@ ladder = server_CreateBlob("ladder", blob.getTeamNum(), AIB_TileCenter(tile));
	if (ladder is null) return false;
	if (!AIB_TakeMaterial(blob, "mat_wood", woodCost))
	{
		ladder.server_Die();
		return false;
	}

	for (uint i = 0; i < backwallChain.length; i++)
	{
		map.server_SetTile(backwallChain[i], CMap::tile_wood_back);
	}
	if (needsBackwall && !map.hasSupportAtPos(AIB_TileCenter(tile)))
	{
		ladder.server_Die();
		return false;
	}

	ladder.Tag("aibuilder recovery ladder");
	ladder.setAngleDegrees(AIB_LADDER_HORIZONTAL_ANGLE);
	ladder.getShape().SetStatic(true);
	ladder.getShape().SetGravityScale(0.0f);
	blob.set_u32("ai builder next ladder", getGameTime() + AIB_LADDER_PLACE_DELAY);
	blob.set_Vec2f("ai builder jump peak", Vec2f_zero);
	AIB_LogEvent("ai", "place_ladder", AIB_EventBlobRef(blob), "tile=" + AIB_EventPos(tile) + " next=" + AIB_EventPos(next) + " angle=90 backwall=" + AIB_BoolString(needsBackwall) + " chain=" + backwallChain.length);
	return true;
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

	if (blob.isOnLadder() || blob.isInWater())
	{
		blob.setKeyPressed(destination.y < pos.y ? key_up : key_down, true);
	}
	else if (blob.isOnWall() ||
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

	Vec2f best = Vec2f_zero;
	f32 bestScore = 99999999.0f;

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
			if (!AIB_IsInsideCurrentBarrierZone(blob, AIB_TileCenter(tilePos))) continue;
			if (!AIB_IsSafeResource(blob, AIB_TileCenter(tilePos))) continue;

			const f32 builderDistance = (AIB_TileCenter(tilePos) - builderPos).Length();
			const f32 depthPenalty = Maths::Max(0.0f, tilePos.y - builderPos.y) * 0.05f;
			const f32 score = builderDistance + depthPenalty;

			if (score < bestScore)
			{
				bestScore = score;
				best = tilePos;
			}
		}
	}

	return best;
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

Vec2f AIB_GetNextTunnelTile(CBlob@ blob, Vec2f target)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	Vec2f clearance = AIB_GetPassageClearanceTile(blob, target);
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

bool AIB_ShouldAvoidDirtClearance(CBlob@ blob, Vec2f target, Vec2f tile)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return false;

	const TileType type = map.getTile(tile).type;
	if (!map.isTileGround(type)) return false;
	if (map.isTileStone(type) || map.isTileThickStone(type)) return false;

	const Vec2f pos = blob.getPosition();
	const int builderX = Maths::Floor(pos.x / map.tilesize);
	const int builderY = Maths::Floor(pos.y / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	const int tileX = Maths::Floor(tile.x / map.tilesize);
	const int tileY = Maths::Floor(tile.y / map.tilesize);

	// Prefer a two-wide vertical shaft to the stone layer over carving a long
	// diagonal dirt tunnel. Horizontal dirt is only allowed once the builder is
	// already near the target layer, or when the passage is explicitly too short.
	if (Maths::Abs(tileY - builderY) <= 1 && Maths::Abs(tileX - builderX) <= 1 &&
		Maths::Abs(builderY - targetY) > 2)
	{
		return true;
	}

	if (Maths::Abs(tileY - targetY) <= 1 && Maths::Abs(targetX - builderX) > 2)
	{
		Vec2f foot = Vec2f(tileX * map.tilesize, tileY * map.tilesize);
		Vec2f head = foot - Vec2f(0.0f, map.tilesize);
		if (!AIB_TileNeedsDigging(head)) return true;
	}

	return false;
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
	blob.set_u32("ai builder next hit", gameTime + AIB_HIT_DELAY);

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
	return map.isTileGround(type) || map.isTileStone(type) || map.isTileThickStone(type);
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
		if (!AIB_IsInsideCurrentBarrierZone(blob, AIB_TileCenter(tile))) continue;
		if (!AIB_IsSafeResource(blob, AIB_TileCenter(tile))) continue;

		const f32 distance = (AIB_TileCenter(tile) - builderPos).Length();
		if (distance < bestScore)
		{
			bestScore = distance;
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
		Vec2f tile = target + offsets[i];
		if (map.isTileSolid(tile)) continue;

		Vec2f center = AIB_TileCenter(tile);
		const f32 distance = (center - builderPos).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			best = center;
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
		if (!AIB_IsLooseWorldResource(candidate)) continue;
		const bool baseStone = AIB_IsBaseStoneSource(blob, candidate);
		if (AIB_IsDeliveredResourceAtHome(blob, candidate) && !baseStone) continue;
		if (!baseStone && !AIB_IsAccessibleResource(blob, candidate)) continue;

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
		if (!AIB_IsLooseWorldResource(candidate)) continue;
		const bool baseStone = AIB_IsBaseStoneSource(blob, candidate);
		if (AIB_IsDeliveredResourceAtHome(blob, candidate) && !baseStone) continue;
		if (!baseStone && !AIB_IsAccessibleResource(blob, candidate)) continue;

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

bool AIB_IsBaseStoneSource(CBlob@ blob, CBlob@ stone)
{
	if (blob is null || !AIB_IsLooseWorldResource(stone)) return false;
	if (stone.hasTag("aibuilder stone supply")) return true;
	if (stone.hasTag("aibuilder base stone source")) return true;

	CBlob@ home = AIB_GetTeamHome(blob);
	if (home !is null && (stone.getPosition() - AIB_GetHomeDropPoint(home)).Length() <= 56.0f)
	{
		stone.Tag("aibuilder base stone source");
		return true;
	}

	CBlob@[] quarries;
	getBlobsByName("quarry", @quarries);
	for (uint i = 0; i < quarries.length; i++)
	{
		CBlob@ quarry = quarries[i];
		if (quarry is null || quarry.hasTag("dead") || quarry.getTeamNum() != blob.getTeamNum()) continue;
		if ((stone.getPosition() - quarry.getPosition()).Length() <= 40.0f)
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
	return blob.getCarriedBlob() is stone;
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
	return AIB_GetNearest(blob, @logs);
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

	CBlob@ home = AIB_GetNearestTeamBlob(blob, "tent");
	if (AIB_IsFriendlyHome(blob, home)) return home;

	@home = AIB_GetNearestTeamBlob(blob, "hall");
	return AIB_IsFriendlyHome(blob, home) ? home : null;
}

bool AIB_IsFriendlyHome(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null || home.hasTag("dead")) return false;
	if (home.getTeamNum() != blob.getTeamNum()) return false;

	const string name = home.getName();
	return name == "tent" || name == "hall";
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

	CMap@ map = getMap();
	const f32 ts = map is null ? 8.0f : map.tilesize;
	Vec2f base = home.getPosition() + Vec2f(-9.0f * ts, -1.0f * ts);
	if (map is null) return base;

	Vec2f best = base;
	f32 bestScore = 999999.0f;
	for (int y = -2; y <= 2; y++)
	{
		for (int x = 0; x <= 6; x++)
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

Vec2f AIB_GetBuilderShopPoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;

	CMap@ map = getMap();
	const f32 ts = map is null ? 8.0f : map.tilesize;
	return AIB_GetBaseStoragePoint(home) + Vec2f(5.0f * ts, 0.0f);
}

bool AIB_StoreResourcesInBaseCrates(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return false;

	AIB_StashCarriedResource(blob);

	CBlob@ shop = AIB_GetNearestTeamBlob(blob, "buildershop");
	if (shop is null)
	{
		@shop = AIB_BuildBaseBuilderShop(blob, home);
	}

	for (u8 i = 0; i < 8 && AIB_HasAnyResource(blob); i++)
	{
		CBlob@ crate = AIB_GetBestBaseResourceCrate(blob, home);
		if (crate is null)
		{
			if (shop is null)
			{
				return false;
			}
			@crate = AIB_BuyBaseResourceCrate(blob, home, shop);
			if (crate is null)
			{
				return false;
			}
		}

		const u8 before = AIB_CountResourceItems(blob);
		AIB_PutResourcesInCrate(blob, crate);
		if (AIB_CountResourceItems(blob) >= before)
		{
			crate.Tag("aibuilder full resource crate");
		}
	}

	return !AIB_HasAnyResource(blob);
}

CBlob@ AIB_BuildBaseBuilderShop(CBlob@ blob, CBlob@ home)
{
	if (blob is null || home is null) return null;
	if (AIB_CountWood(blob) < AIB_BUILDER_SHOP_WOOD_COST) return null;
	if (!AIB_TakeMaterial(blob, "mat_wood", AIB_BUILDER_SHOP_WOOD_COST)) return null;

	CBlob@ shop = server_CreateBlob("buildershop", blob.getTeamNum(), AIB_GetBuilderShopPoint(home));
	if (shop is null) return null;

	shop.Tag("aibuilder built storage shop");
	AIB_LogEvent("ai", "build_storage_shop", AIB_EventBlobRef(blob), "shop=" + AIB_EventBlobRef(shop) + " pos=" + AIB_EventPos(shop.getPosition()));
	return shop;
}

CBlob@ AIB_BuyBaseResourceCrate(CBlob@ blob, CBlob@ home, CBlob@ shop)
{
	if (blob is null || home is null || shop is null) return null;
	if (AIB_CountWood(blob) < AIB_CRATE_WOOD_COST) return null;
	if (!AIB_TakeMaterial(blob, "mat_wood", AIB_CRATE_WOOD_COST)) return null;

	CBlob@ crate = server_CreateBlob("crate", blob.getTeamNum(), AIB_GetNextBaseCratePoint(home));
	if (crate is null) return null;

	crate.Tag("aibuilder resource crate");
	AIB_LogEvent("ai", "buy_storage_crate", AIB_EventBlobRef(blob), "shop=" + AIB_EventBlobRef(shop) + " crate=" + AIB_EventBlobRef(crate) + " pos=" + AIB_EventPos(crate.getPosition()));
	return crate;
}

bool AIB_IsNurseryState(const u8 state)
{
	return state >= AIBuilderState::nursery_collect_wood && state <= AIBuilderState::nursery_wait_tree;
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
	}

	Vec2f center = AIB_TileCenter(target);
	Vec2f clearanceTile = AIB_GetPassageClearanceTile(blob, target);
	if (clearanceTile != Vec2f_zero)
	{
		Vec2f clearanceCenter = AIB_TileCenter(clearanceTile);
		if ((clearanceCenter - blob.getPosition()).Length() <= 40.0f)
		{
			AIB_MineTile(blob, clearanceTile);
		}
		else
		{
			AIB_GoTo(brain, blob, clearanceCenter);
		}
		return;
	}

	Vec2f blockingTile = AIB_GetBlockingTileTowardStone(blob, target);
	if (blockingTile != Vec2f_zero && (blockingTile - target).Length() > 1.0f)
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

	Vec2f approach = AIB_GetApproachPositionForStone(blob, target);
	const bool shouldDig = (approach - center).Length() <= 1.0f ||
		blob.get_u8("ai builder obstruction threshold") > 8 ||
		brain.getState() == CBrain::stuck || brain.getState() == CBrain::wrong_path;
	if (shouldDig)
	{
		Vec2f dig = AIB_GetNextTunnelTile(blob, target);
		if (dig != Vec2f_zero)
		{
			Vec2f digCenter = AIB_TileCenter(dig);
			if ((digCenter - blob.getPosition()).Length() <= 40.0f)
			{
				AIB_MineTile(blob, dig);
			}
			else
			{
				AIB_GoTo(brain, blob, digCenter);
			}
			return;
		}
	}
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

	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;
	const f32 ts = map.tilesize;
	for (int radius = 2; radius <= 8; radius++)
	{
		for (int side = -1; side <= 1; side += 2)
		{
			for (int y = -4; y <= 4; y++)
			{
				Vec2f candidate = Vec2f(Maths::Floor(anchor.x / ts + side * radius) * ts + ts * 0.5f,
					Maths::Floor(anchor.y / ts + y) * ts + ts * 0.5f);
				if (AIB_IsValidSeedPosition(candidate)) return candidate;
			}
		}
	}
	return Vec2f_zero;
}

bool AIB_IsValidSeedPosition(Vec2f pos)
{
	CMap@ map = getMap();
	if (map is null || !AIB_IsInsideMap(pos) || !AIB_IsInsideCurrentBarrierZoneAt(pos)) return false;
	if (map.isTileSolid(pos) || !map.isTileGround(map.getTile(pos + Vec2f(0.0f, map.tilesize)).type)) return false;
	if (map.getSectorAtPosition(pos, "no build") !is null) return false;

	CBlob@[] nearby;
	if (map.getBlobsInRadius(pos, 18.0f, @nearby))
	{
		for (uint i = 0; i < nearby.length; i++)
		{
			CBlob@ other = nearby[i];
			if (other !is null && (other.getName() == "seed" || other.hasTag("tree"))) return false;
		}
	}
	return true;
}

bool AIB_TryMaintainBaseQuarry(CBrain@ brain, CBlob@ blob, CBlob@ home)
{
	if (brain is null || blob is null || home is null) return false;
	if (AIB_GetBestStoneTile(blob) != Vec2f_zero) return false;
	if (AIB_GetNearestStoneMat(blob) !is null) return false;

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

bool AIB_TryUseBaseStoneSource(CBrain@ brain, CBlob@ blob)
{
	if (brain is null || blob is null) return false;

	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null)
	{
		AIB_ReportWaitingStatus(blob, "Waiting for a team home");
		return true;
	}

	CBlob@ storedStone = AIB_GetHomeMaterial(blob, home, "mat_stone");
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

	CBlob@[] shops;
	getBlobsByName("buildershop", @shops);
	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f storage = AIB_GetBaseStoragePoint(home);
	for (uint i = 0; i < shops.length; i++)
	{
		CBlob@ shop = shops[i];
		if (shop is null || shop.hasTag("dead") || shop.getTeamNum() != home.getTeamNum()) continue;
		const f32 distance = (shop.getPosition() - storage).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = shop;
		}
	}
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
	if (AIB_CountHomeMaterial(home, "mat_wood") < AIB_QUARRY_WOOD_COST + AIB_QUARRY_FUEL_BATCH) return null;
	if (!AIB_TakeHomeMaterial(home, "mat_wood", AIB_QUARRY_WOOD_COST)) return null;

	CBlob@ quarry = server_CreateBlob("quarry", blob.getTeamNum(), AIB_GetQuarryPoint(home));
	if (quarry is null) return null;

	quarry.Tag("aibuilder built quarry");
	AIB_LogEvent("ai", "build_quarry", AIB_EventBlobRef(blob), "quarry=" + AIB_EventBlobRef(quarry) + " pos=" + AIB_EventPos(quarry.getPosition()) + " cost_wood=" + AIB_QUARRY_WOOD_COST);
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

	CMap@ map = getMap();
	const f32 ts = map is null ? 8.0f : map.tilesize;
	return AIB_GetBaseStoragePoint(home) + Vec2f(8.0f * ts, 0.0f);
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
	Vec2f base = AIB_GetBaseStoragePoint(home);
	CMap@ map = getMap();
	const f32 ts = map is null ? 8.0f : map.tilesize;
	u8 existing = AIB_CountBaseResourceCrates(home);
	return base + Vec2f(existing * ts * 2.5f, 0.0f);
}

u8 AIB_CountBaseResourceCrates(CBlob@ home)
{
	if (home is null) return 0;

	u8 count = 0;
	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	Vec2f storage = AIB_GetBaseStoragePoint(home);
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
	Vec2f storage = AIB_GetBaseStoragePoint(home);
	for (uint i = 0; i < crates.length; i++)
	{
		CBlob@ crate = crates[i];
		if (!AIB_IsBaseResourceCrate(crate, home, storage)) continue;
		if (crate.hasTag("aibuilder full resource crate")) continue;
		if (!AIB_CrateCanTakeAnyResource(crate, blob)) continue;

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
	if (crate is null || home is null || crate.hasTag("dead")) return false;
	if (crate.isAttached() || crate.isInInventory()) return false;
	if (crate.getTeamNum() != home.getTeamNum()) return false;
	if (crate.exists("packed")) return false;
	if ((crate.getPosition() - storage).Length() > 128.0f) return false;

	CInventory@ inv = crate.getInventory();
	return inv !is null;
}

bool AIB_CrateCanTakeAnyResource(CBlob@ crate, CBlob@ blob)
{
	if (crate is null || blob is null) return false;

	CInventory@ crateInv = crate.getInventory();
	if (crateInv is null) return false;
	if (!crateInv.isFull()) return true;

	CInventory@ blobInv = blob.getInventory();
	if (blobInv is null) return false;
	for (uint i = 0; i < blobInv.getItemsCount(); i++)
	{
		CBlob@ item = blobInv.getItem(i);
		if (AIB_IsResourceBlob(item) && crateInv.getCount(item.getName()) > 0)
		{
			return true;
		}
	}
	return false;
}

void AIB_PutResourcesInCrate(CBlob@ blob, CBlob@ crate)
{
	if (blob is null || crate is null) return;

	AIB_StashCarriedResource(blob);
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
			continue;
		}

		if (!blob.server_PutInInventory(item))
		{
			blob.server_Pickup(item);
		}
		crate.Tag("aibuilder full resource crate");
		break;
	}
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

u8 AIB_CountResourceItems(CBlob@ blob)
{
	if (blob is null) return 0;

	u8 count = AIB_IsResourceBlob(blob.getCarriedBlob()) ? 1 : 0;
	CInventory@ inv = blob.getInventory();
	if (inv is null) return count;

	for (uint i = 0; i < inv.getItemsCount(); i++)
	{
		if (AIB_IsResourceBlob(inv.getItem(i))) count++;
	}
	return count;
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
	if (home is null) return 0;

	u16 count = 0;
	CBlob@[] mats;
	getBlobsByName(name, @mats);
	Vec2f homePos = AIB_GetHomeDropPoint(home);
	for (uint i = 0; i < mats.length; i++)
	{
		CBlob@ mat = mats[i];
		if (!AIB_IsLooseWorldResource(mat)) continue;
		if ((mat.getPosition() - homePos).Length() > 56.0f) continue;
		count += mat.getQuantity();
	}

	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	Vec2f storage = AIB_GetBaseStoragePoint(home);
	for (uint i = 0; i < crates.length; i++)
	{
		CBlob@ crate = crates[i];
		if (!AIB_IsBaseResourceCrate(crate, home, storage)) continue;

		CInventory@ inv = crate.getInventory();
		if (inv !is null) count += inv.getCount(name);
	}

	return count;
}

bool AIB_TakeHomeMaterial(CBlob@ home, const string &in name, const u16 amount)
{
	if (home is null || amount == 0) return false;

	u16 remaining = amount;
	CBlob@[] mats;
	getBlobsByName(name, @mats);
	Vec2f homePos = AIB_GetHomeDropPoint(home);
	for (uint i = 0; i < mats.length && remaining > 0; i++)
	{
		CBlob@ mat = mats[i];
		if (!AIB_IsLooseWorldResource(mat)) continue;
		if ((mat.getPosition() - homePos).Length() > 56.0f) continue;

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
	Vec2f storage = AIB_GetBaseStoragePoint(home);
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

CBlob@ AIB_GetHomeMaterial(CBlob@ blob, CBlob@ home, const string &in name)
{
	CBlob@[] mats;
	getBlobsByName(name, @mats);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f homePos = AIB_GetHomeDropPoint(home);
	for (uint i = 0; i < mats.length; i++)
	{
		CBlob@ mat = mats[i];
		if (!AIB_IsLooseWorldResource(mat)) continue;
		if ((mat.getPosition() - homePos).Length() > 56.0f) continue;

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
	Vec2f storage = AIB_GetBaseStoragePoint(home);
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
	if (carried.getName() != "mat_wood" && carried.getName() != "mat_stone") return;

	blob.server_PutInInventory(carried);
}

u16 AIB_CountMaterial(CBlob@ blob, const string &in name)
{
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

			Vec2f tile = Vec2f(x * map.tilesize, y * map.tilesize);
			Vec2f support = AIB_GetNeededSupportTileFor(tile, block);
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
			const string material = AIB_BlueprintMaterial(targetBlock);
			const u16 cost = AIB_BlueprintCost(targetBlock);
			if ((material == "" || cost == 0 || AIB_CountMaterial(blob, material) >= cost) &&
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
	return target != 0 && !AIB_MapTileMatchesBlueprint(tile, target) &&
		(AIB_CanPlaceBlueprintAt(tile, target) || AIB_CanClearBlueprintSite(tile, target));
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
			return 2;
		}
		above -= Vec2f(0.0f, map.tilesize);
	}

	return 0;
}

Vec2f AIB_GetNeededSupportTileFor(Vec2f blueprintTile, const u16 block)
{
	if (AIBP_IsWorkshopBlock(block)) return AIB_GetNeededWorkshopSupportTile(blueprintTile);
	if (!AIB_IsSolidBlueprintBlock(block)) return Vec2f_zero;

	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	Vec2f below = blueprintTile + Vec2f(0.0f, map.tilesize);
	if (AIB_HasBlueprintSupportAt(blueprintTile)) return Vec2f_zero;

	Vec2f scan = below;
	Vec2f lowestMissing = Vec2f_zero;
	while (scan.y < map.tilemapheight * map.tilesize)
	{
		if (AIB_TileProvidesBlueprintSupport(scan))
		{
			return lowestMissing;
		}
		if (!AIB_MapTileMatchesBlueprint(scan, 2) && AIB_CanPlaceBlueprintAt(scan, 2))
		{
			lowestMissing = scan;
		}
		scan += Vec2f(0.0f, map.tilesize);
	}

	return lowestMissing;
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
		Vec2f lowestMissing = Vec2f_zero;
		while (scan.y < map.tilemapheight * ts)
		{
			if (AIB_TileProvidesBlueprintSupport(scan)) return lowestMissing;
			if (!AIB_MapTileMatchesBlueprint(scan, 2) && AIB_CanPlaceBlueprintAt(scan, 2))
			{
				lowestMissing = scan;
			}
			scan += Vec2f(0.0f, ts);
		}
		return lowestMissing;
	}

	return Vec2f_zero;
}

bool AIB_PlaceBlueprintTile(CBlob@ blob, Vec2f tile)
{
	const u32 gameTime = getGameTime();
	if (gameTime < blob.get_u32("ai builder next place")) return false;

	const u8 team = u8(blob.getTeamNum());
	u16 target = AIB_GetBlueprintTargetForTile(tile, team);
	if (target == 0 || AIB_MapTileMatchesBlueprint(tile, target)) return true;

	CMap@ map = getMap();
	if (map is null) return false;
	if (!AIB_CanPlaceBlueprintAt(tile, target)) return true;

	if (AIBP_IsBlobBlock(target))
	{
		return AIB_PlaceBlueprintBlob(blob, tile, target);
	}

	const string material = AIB_BlueprintMaterial(target);
	const u16 cost = AIB_BlueprintCost(target);
	if (material == "" || cost == 0) return true;
	if (!AIB_TakeMaterial(blob, material, cost)) return false;

	// Replace the current tile in one server mutation.  In particular, do not
	// clear grass with server_SetTile immediately before placing a backwall:
	// KAG queues/synchronises tile mutations, so two writes to the same tile in
	// one tick can leave only the clear applied.  Base PlaceBlock also replaces
	// grass directly with the requested foreground/background tile.
	map.server_SetTile(tile, AIB_BlueprintTileType(target));
	AIB_ClearBlueprintTargetForTile(tile, team);
	blob.set_u32("ai builder next place", gameTime + AIB_BLUEPRINT_PLACE_DELAY);
	return true;
}

bool AIB_PlaceBlueprintBlob(CBlob@ blob, Vec2f tile, const u16 target)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return false;
	// Revalidate immediately before creation so a workshop cannot bypass a
	// changed no-build sector or foundation state after task selection.
	if (AIBP_IsWorkshopBlock(target) &&
		(AIB_WorkshopFootprintIntersectsNoBuild(tile) || AIB_GetNeededWorkshopSupportTile(tile) != Vec2f_zero)) return false;

	const string material = AIB_BlueprintMaterial(target);
	const u16 cost = AIB_BlueprintCost(target);
	const string blobName = AIBP_BlockBlobName(target);
	if (blobName == "") return false;
	const TileType replacedTile = map.getTile(tile).type;
	const bool replacesGrass = map.isTileGrass(replacedTile);
	if (replacesGrass) map.server_SetTile(tile, CMap::tile_empty);
	CBlob@ placed = server_CreateBlob(blobName, blob.getTeamNum(), AIB_TileCenter(tile));
	if (placed is null)
	{
		if (replacesGrass) map.server_SetTile(tile, replacedTile);
		return false;
	}
	if (!AIB_TakeMaterial(blob, material, cost))
	{
		placed.server_Die();
		if (replacesGrass) map.server_SetTile(tile, replacedTile);
		return false;
	}

	const u16 rotation = AIB_BlueprintRotation(target);
	placed.setAngleDegrees(rotation * 90.0f);
	placed.Tag("aibuilder blueprint structure");
	if (blobName == "ladder") placed.Tag("aibuilder blueprint ladder");
	placed.getShape().SetStatic(true);
	placed.getShape().SetGravityScale(0.0f);
	AIB_ClearBlueprintTargetForTile(tile, u8(blob.getTeamNum()));
	blob.set_u32("ai builder next place", getGameTime() + AIB_BLUEPRINT_PLACE_DELAY);
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
	CMap@ map = getMap();
	if (map is null) return false;

	const TileType current = map.getTile(tile).type;
	if (map.isTileBedrock(current)) return false;
	if (AIB_BlueprintBlockId(block) != AIBP_LADDER && map.getSectorAtPosition(AIB_TileCenter(tile), "no build") !is null) return false;
	if (AIBP_IsWorkshopBlock(block))
	{
		if (AIB_WorkshopFootprintIntersectsNoBuild(tile)) return false;
		if (AIB_GetNeededWorkshopSupportTile(tile) != Vec2f_zero) return false;
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
	CMap@ map = getMap();
	if (map is null) return false;

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
	if (target == 0 || !AIB_CanClearBlueprintSite(tile, target)) return false;

	Vec2f center = AIB_TileCenter(tile);
	if ((center - blob.getPosition()).Length() > 40.0f)
	{
		AIB_GoTo(brain, blob, center);
		return true;
	}

	const u32 gameTime = getGameTime();
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
		if (name == "flag" || name == "tent" || name == "hall" || name == "aibuilder" ||
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

bool AIB_HasBlueprintSupportAt(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;

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

	const TileType type = map.getTile(tile).type;
	if (type == CMap::tile_empty || type == CMap::tile_ground_back) return false;
	if (map.isTileGrass(type)) return false;
	if (map.isTileGroundStuff(type)) return false;
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

	Vec2f center = AIB_TileCenter(tile);
	Vec2f best = center;
	f32 bestScore = 999999.0f;
	const f32 ts = map.tilesize;
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
	CRules@ rules = getRules();
	if (rules is null || !AIB_ShouldBarrier(rules)) return true;

	const u16 x1 = rules.get_u16("barrier_x1");
	const u16 x2 = rules.get_u16("barrier_x2");
	if (x1 == x2) return true;

	return AIB_GetBarrierZone(position.x, x1, x2) != 0;
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
	CMap@ map = getMap();
	if (map is null) return false;
	if (AIBP_IsBlobBlock(block))
	{
		CBlob@ placed = AIB_GetBlueprintBlobAt(tile, AIBP_BlockBlobName(block));
		if (placed is null) return false;

		const u16 rotation = AIB_BlueprintRotation(block);
		const u8 actual = AIBP_NormalizeRotationForId(AIBP_BlockId(block),
			u8((Maths::Round(placed.getAngleDegrees() / 90.0f) + 4) % 4));
		return actual == rotation;
	}
	return map.getTile(tile).type == AIB_BlueprintTileType(block);
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
	CInventory@ inv = blob.getInventory();
	if (inv is null || inv.getCount(name) < amount) return false;

	inv.server_RemoveItems(name, amount);
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
	if (!AIB_IsResourceBlob(blob)) return false;
	if (blob.hasTag("dead")) return false;
	if (blob.isAttached()) return false;
	if (blob.isInInventory()) return false;
	return true;
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

CBlob@ AIB_GetBestTreeForHome(CBlob@ blob, CBlob@[]@ candidates)
{
	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null)
	{
		return AIB_GetNearest(blob, candidates);
	}

	CBlob@ best = null;
	f32 bestScore = 999999.0f;
	Vec2f homePos = home.getPosition();
	Vec2f builderPos = blob.getPosition();

	for (uint i = 0; i < candidates.length; i++)
	{
		CBlob@ candidate = candidates[i];
		if (candidate is null || candidate.hasTag("dead") || candidate.isInInventory()) continue;
		if (!AIB_IsTreeHarvestReady(candidate)) continue;
		if (!AIB_IsAllowedByOverseerSelection(candidate)) continue;
		if (!AIB_IsAccessibleResource(blob, candidate)) continue;

		Vec2f treePos = candidate.getPosition();
		const f32 homeDistance = (treePos - homePos).Length();
		const f32 builderDistance = (treePos - builderPos).Length();
		const f32 score = homeDistance + builderDistance * 0.20f;

		if (score < bestScore)
		{
			bestScore = score;
			@best = candidate;
		}
	}

	return best;
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
		AIB_LogEvent("ai", "reject_resource", AIB_EventBlobRef(blob), "resource=" + AIB_EventBlobRef(resource) + " reason=barrier pos=" + AIB_EventPos(resource.getPosition()));
		return false;
	}

	if (!AIB_IsSafeResource(blob, resource.getPosition()))
	{
		if (AIB_DEBUG)
		{
			AIB_Debug(blob, "ignored " + resource.getName() + " in unsafe enemy zone");
		}
		AIB_LogEvent("ai", "reject_resource", AIB_EventBlobRef(blob), "resource=" + AIB_EventBlobRef(resource) + " reason=unsafe pos=" + AIB_EventPos(resource.getPosition()));
		return false;
	}

	return true;
}

bool AIB_IsInsideCurrentBarrierZone(CBlob@ blob, Vec2f position)
{
	CRules@ rules = getRules();
	if (rules is null || !AIB_ShouldBarrier(rules)) return true;

	const u16 x1 = rules.get_u16("barrier_x1");
	const u16 x2 = rules.get_u16("barrier_x2");
	if (x1 == x2) return true;

	const s8 blobZone = AIB_GetBarrierZone(blob.getPosition().x, x1, x2);
	const s8 resourceZone = AIB_GetBarrierZone(position.x, x1, x2);

	return blobZone != 0 && blobZone == resourceZone;
}

s8 AIB_GetBarrierZone(const f32 x, const u16 x1, const u16 x2)
{
	if (x < x1) return -1;
	if (x > x2) return 1;
	return 0;
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
	blob.set_u8("ai builder state", next);

	if (previous != next)
	{
		blob.Sync("ai builder state", true);
		AIB_LogEvent("ai", "state", AIB_EventBlobRef(blob), "from=" + AIB_StateName(previous) + " to=" + AIB_StateName(next) + " reason=" + reason + " pos=" + AIB_EventPos(blob.getPosition()));
		AIB_Debug(blob, "state " + AIB_StateName(previous) + " -> " + AIB_StateName(next) + " reason=" + reason);
	}
	else
	{
		AIB_Debug(blob, "state stays " + AIB_StateName(next) + " reason=" + reason);
	}
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
