// AIBuilderBrain.as

#define SERVER_ONLY

#include "Hitters.as";
#include "MaterialCommon.as";
#include "RedBarrierCommon.as";
#include "AIBEventLog.as";

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
const u16 AIB_BLUEPRINT_MIN_WOOD = 20;
const u16 AIB_BLUEPRINT_MIN_STONE = 20;
const u8 AIB_BLUEPRINT_PLACE_DELAY = 8;
const string AIB_BLUEPRINT_DATA_KEY = "aibuilder blueprint data";
const string AIB_BLUEPRINT_WIDTH_KEY = "aibuilder blueprint width";
const string AIB_BLUEPRINT_HEIGHT_KEY = "aibuilder blueprint height";
const u8 AIB_SHAFT_WIDTH = 2;
const u8 AIB_WOOD_BLOCK_COST = 10;
const u8 AIB_WOODEN_DOOR_COST = 30;
const bool AIB_DEBUG = false; // Set true while debugging. Uses print(), so keep false for deployed builds.
const u32 AIB_DEBUG_SNAPSHOT_RATE = 150;

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
		build_blueprint_block
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
	blob.set_u8("ai builder debug last state", AIBuilderState::idle);

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
	if (AIB_FleeFromNearbyKnight(this, blob))
	{
		AIB_FloatInWater(blob);
		return;
	}

	if (AIB_ShouldReturnResources(blob) && state != AIBuilderState::return_wood)
	{
		AIB_SetState(blob, AIBuilderState::return_wood, "inventory full or carrying resources");
	}

	if (state == AIBuilderState::idle)
	{
		AIB_FloatInWater(blob);
		return;
	}

	if (state >= AIBuilderState::find_stone && blob.get_u8("ai builder job") != AIB_JOB_STONE)
	{
		if (state < AIBuilderState::collect_blueprint_resources || blob.get_u8("ai builder job") != AIB_JOB_BLUEPRINT)
		{
			AIB_SetState(blob, AIBuilderState::idle, "state without matching job");
			AIB_FloatInWater(blob);
			return;
		}
	}

	if (state >= AIBuilderState::find_stone &&
		state < AIBuilderState::collect_blueprint_resources &&
		blob.get_u8("ai builder job") != AIB_JOB_STONE)
	{
		AIB_SetState(blob, AIBuilderState::idle, "stone state without stone job");
		AIB_FloatInWater(blob);
		return;
	}

	if (AIB_HasWood(blob) &&
		blob.get_u8("ai builder job") == AIB_JOB_WOOD &&
		state != AIBuilderState::chop_tree &&
		state != AIBuilderState::find_log &&
		state != AIBuilderState::chop_log)
	{
		AIB_SetState(blob, AIBuilderState::return_wood, "has wood outside harvesting states");
	}

	switch (blob.get_u8("ai builder state"))
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
	}

	AIB_FloatInWater(blob);
}

void AIB_FindTree(CBrain@ brain, CBlob@ blob)
{
	CBlob@ tree = AIB_GetNearestTree(blob);
	if (tree is null)
	{
		AIB_SetState(blob, AIBuilderState::idle, "no tree found");
		return;
	}

	brain.SetTarget(tree);
	brain.SetPathTo(tree.getPosition(), false);
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
	brain.SetPathTo(log.getPosition(), false);
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
			AIB_SetState(blob, AIBuilderState::idle, "loose wood missing, no tree available");
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
		AIB_LogEvent("ai", "no_home", AIB_EventBlobRef(blob), "state=return_wood pos=" + AIB_EventPos(blob.getPosition()));
		AIB_Debug(blob, "no team home found; cannot drop resources");
		AIB_SetState(blob, AIBuilderState::idle, "no home for resource drop");
		return;
	}

	Vec2f hallPos = home.getPosition();
	Vec2f blobPos = blob.getPosition();
	if ((hallPos - blobPos).Length() > 34.0f)
	{
		if (blob.get_u8("ai builder job") == AIB_JOB_WOOD)
		{
			AIB_ReadyWoodInHand(blob);
		}
		AIB_GoTo(brain, blob, hallPos);
		return;
	}

	AIB_DropAllResourcesAtPosition(blob, home.getPosition() + Vec2f(0.0f, -12.0f));
	AIB_LogEvent("ai", "drop_resources", AIB_EventBlobRef(blob), "home=" + AIB_EventBlobRef(home) + " pos=" + AIB_EventPos(home.getPosition()));

	if (blob.get_u8("ai builder job") == AIB_JOB_STONE)
	{
		AIB_SetState(blob, AIBuilderState::find_stone, "resources delivered");
	}
	else
	{
		AIB_SetState(blob, AIBuilderState::find_tree, "wood delivered");
	}
}

void AIB_FindStone(CBrain@ brain, CBlob@ blob)
{
	Vec2f stone = AIB_GetBestStoneTile(blob);
	if (stone == Vec2f_zero)
	{
		AIB_SetState(blob, AIBuilderState::idle, "no stone tile found");
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
		AIB_SetState(blob, AIBuilderState::idle, "not enough wood to seal shaft entrance");
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
	if (clearanceTile != Vec2f_zero)
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
	if (blockingTile != Vec2f_zero && (blockingTile - target).Length() > 1.0f)
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
	CBlob@ home = AIB_GetTeamHome(blob);
	if (home is null)
	{
		AIB_SetState(blob, AIBuilderState::idle, "no home for blueprint resources");
		return;
	}

	if ((home.getPosition() - blob.getPosition()).Length() > 34.0f)
	{
		AIB_GoTo(brain, blob, home.getPosition());
		return;
	}

	AIB_StashCarriedBlueprintMaterial(blob);
	AIB_CollectHomeMaterial(blob, home, "mat_wood");
	AIB_CollectHomeMaterial(blob, home, "mat_stone");

	if (AIB_CountWood(blob) >= AIB_BLUEPRINT_MIN_WOOD && AIB_CountStone(blob) >= AIB_BLUEPRINT_MIN_STONE)
	{
		AIB_SetState(blob, AIBuilderState::find_blueprint_block, "blueprint resources ready");
	}
}

void AIB_FindBlueprintBlock(CBrain@ brain, CBlob@ blob)
{
	if (AIB_CountWood(blob) < AIB_BLUEPRINT_MIN_WOOD || AIB_CountStone(blob) < AIB_BLUEPRINT_MIN_STONE)
	{
		AIB_SetState(blob, AIBuilderState::collect_blueprint_resources, "low blueprint resources");
		return;
	}

	Vec2f tile = AIB_GetNearestBlueprintBuildTile(blob);
	if (tile == Vec2f_zero)
	{
		AIB_SetState(blob, AIBuilderState::idle, "blueprint complete or empty");
		return;
	}

	blob.set_Vec2f("ai builder tile target", tile);
	AIB_SetState(blob, AIBuilderState::build_blueprint_block, "blueprint target acquired");
}

void AIB_BuildBlueprintBlock(CBrain@ brain, CBlob@ blob)
{
	Vec2f tile = blob.get_Vec2f("ai builder tile target");
	if (tile == Vec2f_zero || !AIB_BlueprintTileStillNeedsWork(tile))
	{
		AIB_SetState(blob, AIBuilderState::find_blueprint_block, "blueprint tile complete");
		return;
	}

	Vec2f center = AIB_TileCenter(tile);
	if ((center - blob.getPosition()).Length() > 32.0f)
	{
		AIB_GoTo(brain, blob, center);
		return;
	}

	blob.setAimPos(center);
	if (AIB_PlaceBlueprintTile(blob, tile))
	{
		AIB_SetState(blob, AIBuilderState::find_blueprint_block, "placed blueprint tile");
	}
	else if (AIB_CountWood(blob) < AIB_BLUEPRINT_MIN_WOOD || AIB_CountStone(blob) < AIB_BLUEPRINT_MIN_STONE)
	{
		AIB_SetState(blob, AIBuilderState::collect_blueprint_resources, "out of blueprint material");
	}
}

void AIB_GoTo(CBrain@ brain, CBlob@ blob, Vec2f destination)
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
		if (candidate is null || candidate.hasTag("dead") || candidate.isAttached()) continue;
		if (AIB_IsDeliveredResourceAtHome(blob, candidate)) continue;

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
		if (candidate is null || candidate.hasTag("dead") || candidate.isAttached()) continue;
		if (AIB_IsDeliveredResourceAtHome(blob, candidate)) continue;

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

bool AIB_PickupStone(CBlob@ blob, CBlob@ stone)
{
	if (blob is null || stone is null || stone.hasTag("dead") || stone.isAttached()) return false;
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
	CBlob@ home = AIB_GetNearestTeamBlob(blob, "tent");
	if (home !is null) return home;

	return AIB_GetNearestTeamBlob(blob, "hall");
}

bool AIB_CollectHomeMaterial(CBlob@ blob, CBlob@ home, const string &in name)
{
	CBlob@[] mats;
	getBlobsByName(name, @mats);

	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f homePos = home.getPosition() + Vec2f(0.0f, -12.0f);
	for (uint i = 0; i < mats.length; i++)
	{
		CBlob@ mat = mats[i];
		if (mat is null || mat.hasTag("dead") || mat.isAttached()) continue;
		if ((mat.getPosition() - homePos).Length() > 48.0f) continue;

		const f32 distance = (mat.getPosition() - blob.getPosition()).Length();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = mat;
		}
	}

	if (best is null) return false;
	return blob.server_PutInInventory(best);
}

void AIB_StashCarriedBlueprintMaterial(CBlob@ blob)
{
	CBlob@ carried = blob.getCarriedBlob();
	if (carried is null) return;
	if (carried.getName() != "mat_wood" && carried.getName() != "mat_stone") return;

	blob.server_PutInInventory(carried);
}

Vec2f AIB_GetNearestBlueprintBuildTile(CBlob@ blob)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;

	array<u16>@ blueprint = null;
	if (!getRules().get(AIB_BLUEPRINT_DATA_KEY, @blueprint) || blueprint is null) return Vec2f_zero;

	const u16 width = getRules().get_u16(AIB_BLUEPRINT_WIDTH_KEY);
	const u16 height = getRules().get_u16(AIB_BLUEPRINT_HEIGHT_KEY);
	if (width == 0 || height == 0) return Vec2f_zero;

	Vec2f best = Vec2f_zero;
	f32 bestDistance = 99999999.0f;
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
			if (!AIB_BlueprintTileStillNeedsWork(target)) continue;

			const f32 distance = (AIB_TileCenter(target) - pos).Length();
			if (distance < bestDistance)
			{
				bestDistance = distance;
				best = target;
			}
		}
	}

	return best;
}

u16 AIB_GetBlueprintBlock(array<u16>@ blueprint, const u16 width, const u16 height, const int x, const int y)
{
	if (blueprint is null || x < 0 || y < 0 || x >= width || y >= height) return 0;
	const uint index = y * width + x;
	if (index >= blueprint.length) return 0;
	return blueprint[index] << 2 >> 2;
}

bool AIB_BlueprintTileStillNeedsWork(Vec2f tile)
{
	u16 target = AIB_GetBlueprintTargetForTile(tile);
	return target != 0 && !AIB_MapTileMatchesBlueprint(tile, target) && AIB_CanPlaceBlueprintAt(tile, target);
}

u16 AIB_GetBlueprintTargetForTile(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return 0;

	Vec2f space = map.getTileSpacePosition(tile);
	const int x = Maths::Floor(space.x);
	const int y = Maths::Floor(space.y);

	array<u16>@ blueprint = null;
	if (!getRules().get(AIB_BLUEPRINT_DATA_KEY, @blueprint) || blueprint is null) return 0;
	const u16 width = getRules().get_u16(AIB_BLUEPRINT_WIDTH_KEY);
	const u16 height = getRules().get_u16(AIB_BLUEPRINT_HEIGHT_KEY);
	u16 target = AIB_GetBlueprintBlock(blueprint, width, height, x, y);
	if (AIB_IsSupportedBlueprintBlock(target)) return target;

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

bool AIB_PlaceBlueprintTile(CBlob@ blob, Vec2f tile)
{
	const u32 gameTime = getGameTime();
	if (gameTime < blob.get_u32("ai builder next place")) return false;

	u16 target = AIB_GetBlueprintTargetForTile(tile);
	if (target == 0 || AIB_MapTileMatchesBlueprint(tile, target)) return true;

	CMap@ map = getMap();
	if (map is null) return false;
	if (!AIB_CanPlaceBlueprintAt(tile, target)) return true;

	const string material = AIB_BlueprintMaterial(target);
	const u16 cost = AIB_BlueprintCost(target);
	if (material == "" || cost == 0) return true;
	if (!AIB_TakeMaterial(blob, material, cost)) return false;

	map.server_SetTile(tile, AIB_BlueprintTileType(target));
	blob.set_u32("ai builder next place", gameTime + AIB_BLUEPRINT_PLACE_DELAY);
	return true;
}

bool AIB_CanPlaceBlueprintAt(Vec2f tile, const u16 block)
{
	CMap@ map = getMap();
	if (map is null) return false;

	const TileType current = map.getTile(tile).type;
	if (map.isTileBedrock(current)) return false;
	if (!AIB_TileCountsAsAirForBlueprint(tile) && !(AIB_IsSolidBlueprintBlock(block) && AIB_IsSupportBackwall(current))) return false;
	if (!AIB_HasBlueprintSupportAt(tile)) return false;

	return true;
}

bool AIB_HasBlueprintSupportAt(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;
	if (!map.hasSupportAtPos(tile)) return false;

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
	if (map.isTileGrass(type) || map.isTileGroundStuff(type)) return false;
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
	if (!map.isTileSolid(type) && !AIB_IsSupportBackwall(type)) return true;
	return false;
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
	return map.getTile(tile).type == AIB_BlueprintTileType(block);
}

bool AIB_IsSupportedBlueprintBlock(const u16 block)
{
	return block == 1 || block == 2 || block == 4 || block == 5 || block == 48 || block == 64 || block == 196 || block == 205;
}

bool AIB_IsSolidBlueprintBlock(const u16 block)
{
	return block == 1 || block == 4 || block == 48 || block == 196;
}

TileType AIB_BlueprintTileType(const u16 block)
{
	if (block == 1 || block == 48) return CMap::tile_castle;
	if (block == 2 || block == 64) return CMap::tile_castle_back;
	if (block == 4 || block == 196) return CMap::tile_wood;
	if (block == 5 || block == 205) return CMap::tile_wood_back;
	return CMap::tile_empty;
}

string AIB_BlueprintMaterial(const u16 block)
{
	if (block == 1 || block == 2 || block == 48 || block == 64) return "mat_stone";
	if (block == 4 || block == 5 || block == 196 || block == 205) return "mat_wood";
	return "";
}

u16 AIB_BlueprintCost(const u16 block)
{
	if (block == 2 || block == 5 || block == 64 || block == 205) return 2;
	return 10;
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

CBlob@ AIB_GetNearest(CBlob@ blob, CBlob@[]@ candidates)
{
	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < candidates.length; i++)
	{
		CBlob@ candidate = candidates[i];
		if (candidate is null || candidate.hasTag("dead")) continue;
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
		if (candidate is null || candidate.hasTag("dead")) continue;
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
	if (rules is null || !shouldBarrier(rules)) return true;

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
	if (carried !is null && carried.getName() == "mat_wood")
	{
		return true;
	}

	CInventory@ inv = blob.getInventory();
	if (inv is null) return false;
	if (inv.getCount("mat_wood") > 0) return true;

	for (uint i = 0; i < inv.getItemsCount(); i++)
	{
		CBlob@ item = inv.getItem(i);
		if (item !is null && item.getName() == "mat_wood")
		{
			return true;
		}
	}

	return false;
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
	if (blob.isInWater())
	{
		blob.setKeyPressed(key_up, true);
	}
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

void AIB_SetState(CBlob@ blob, const u8 next, const string &in reason)
{
	const u8 previous = blob.get_u8("ai builder state");
	blob.set_u8("ai builder state", next);

	if (previous != next)
	{
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
