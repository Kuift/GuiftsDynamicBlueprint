#include "AIBGymCommon.as";

const u8 AIBT_IDLE = 0;
const u8 AIBT_FIND_TREE = 1;
const u8 AIBT_CHOP_TREE = 2;
const u8 AIBT_FIND_LOG = 3;
const u8 AIBT_CHOP_LOG = 4;
const u8 AIBT_FIND_WOOD = 5;
const u8 AIBT_RETURN_WOOD = 6;
const u8 AIBT_FIND_STONE = 7;
const u8 AIBT_PREPARE_STONE_SHAFT = 8;
const u8 AIBT_DIG_STONE_SHAFT = 9;
const u8 AIBT_TUNNEL_TO_STONE = 10;
const u8 AIBT_FIND_STONE_MAT = 11;
const u8 AIBT_COLLECT_BLUEPRINT_RESOURCES = 12;
const u8 AIBT_FIND_BLUEPRINT_BLOCK = 13;
const u8 AIBT_BUILD_BLUEPRINT_BLOCK = 14;
const u8 AIBT_NURSERY_COLLECT_WOOD = 15;
const u8 AIBT_NURSERY_BUILD = 16;
const u8 AIBT_NURSERY_COLLECT_STONE = 17;
const u8 AIBT_NURSERY_BUY_SEED = 18;
const u8 AIBT_NURSERY_PLANT_SEED = 19;
const u8 AIBT_NURSERY_WAIT_TREE = 20;
const u8 AIBT_VISIT_RESUPPLY = 21;
const u8 AIBT_DELIVER_LOG_TO_SAW = 22;
const u8 AIBT_JOB_WOOD = 0;
const u8 AIBT_JOB_STONE = 1;
const u8 AIBT_JOB_BLUEPRINT = 2;

string AIBT_StateName(const u8 state)
{
	switch (state)
	{
		case AIBT_IDLE: return "idle";
		case AIBT_FIND_TREE: return "find_tree";
		case AIBT_CHOP_TREE: return "chop_tree";
		case AIBT_FIND_LOG: return "find_log";
		case AIBT_CHOP_LOG: return "chop_log";
		case AIBT_FIND_WOOD: return "find_wood";
		case AIBT_RETURN_WOOD: return "return_wood";
		case AIBT_FIND_STONE: return "find_stone";
		case AIBT_PREPARE_STONE_SHAFT: return "prepare_stone_shaft";
		case AIBT_DIG_STONE_SHAFT: return "dig_stone_shaft";
		case AIBT_TUNNEL_TO_STONE: return "tunnel_to_stone";
		case AIBT_FIND_STONE_MAT: return "find_stone_mat";
		case AIBT_COLLECT_BLUEPRINT_RESOURCES: return "collect_blueprint_resources";
		case AIBT_FIND_BLUEPRINT_BLOCK: return "find_blueprint_block";
		case AIBT_BUILD_BLUEPRINT_BLOCK: return "build_blueprint_block";
		case AIBT_NURSERY_COLLECT_WOOD: return "nursery_collect_wood";
		case AIBT_NURSERY_BUILD: return "nursery_build";
		case AIBT_NURSERY_COLLECT_STONE: return "nursery_collect_stone";
		case AIBT_NURSERY_BUY_SEED: return "nursery_buy_seed";
		case AIBT_NURSERY_PLANT_SEED: return "nursery_plant_seed";
		case AIBT_NURSERY_WAIT_TREE: return "nursery_wait_tree";
		case AIBT_VISIT_RESUPPLY: return "visit_resupply";
		case AIBT_DELIVER_LOG_TO_SAW: return "deliver_log_to_saw";
	}
	return "unknown";
}

string AIBT_BlobRef(CBlob@ blob)
{
	return AIB_EventBlobRef(blob);
}

u16 AIBT_MaterialQuantity(CBlob@ blob)
{
	if (blob is null) return 0;
	const u16 quantity = blob.getQuantity();
	return quantity == 0 ? 1 : quantity;
}

CBlob@ AIBT_GetBlob(const string &in key)
{
	CRules@ rules = getRules();
	if (rules is null || !rules.exists(key)) return null;
	return getBlobByNetworkID(rules.get_netid(key));
}

void AIBT_SetBlob(const string &in key, CBlob@ blob)
{
	CRules@ rules = getRules();
	if (rules is null) return;
	rules.set_netid(key, blob is null ? 0 : blob.getNetworkID());
}

u16 AIBT_CountMaterialNear(const string &in name, Vec2f pos, const f32 radius)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	u16 count = 0;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob !is null && (blob.getPosition() - pos).Length() <= radius)
		{
			if (!blob.isInInventory() && !blob.isAttached())
			{
				count += AIBT_MaterialQuantity(blob);
			}
		}
	}
	return count;
}

u16 AIBT_CountMaterialInCratesNear(const string &in name, Vec2f pos, const f32 radius)
{
	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	u16 count = 0;
	for (uint i = 0; i < crates.length; i++)
	{
		CBlob@ crate = crates[i];
		if (crate is null || crate.hasTag("dead")) continue;
		if (crate.exists("packed")) continue;
		if ((crate.getPosition() - pos).Length() > radius) continue;

		CInventory@ inv = crate.getInventory();
		if (inv is null) continue;
		for (uint j = 0; j < inv.getItemsCount(); j++)
		{
			CBlob@ item = inv.getItem(j);
			if (item !is null && item.getName() == name)
			{
				count += AIBT_MaterialQuantity(item);
			}
		}
	}
	return count;
}

u16 AIBT_CountBlobsNear(const string &in name, Vec2f pos, const f32 radius)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	u16 count = 0;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob !is null && !blob.hasTag("dead") && (blob.getPosition() - pos).Length() <= radius)
		{
			count++;
		}
	}
	return count;
}

u16[] AIBT_tracked_workshop_ids;
Vec2f[] AIBT_workshop_background_tiles;
u16[] AIBT_workshop_background_originals;

bool AIBT_IsWoodBackgroundTile(const u16 type)
{
	return type >= CMap::tile_wood_back && type <= 207;
}

void AIBT_TrackWorkshopBackground(CBlob@ shop, const int fixtureGroundY)
{
	if (shop is null || shop.getName() != "buildershop") return;
	if (!shop.hasTag("aibt test fixture") && !shop.hasTag("aibuilder built storage shop")) return;
	const u16 id = shop.getNetworkID();
	if (AIBT_tracked_workshop_ids.find(id) >= 0) return;

	CMap@ map = getMap();
	if (map is null) return;
	AIBT_tracked_workshop_ids.push_back(id);
	const f32 ts = map.tilesize;
	for (int x = -2; x <= 2; x++)
	{
		for (int y = -1; y <= 1; y++)
		{
			const Vec2f sample = shop.getPosition() + Vec2f(x * ts, y * ts);
			const Vec2f tileSpace = map.getTileSpacePosition(sample);
			// The static AIBTest fixture is foreground terrain from groundY
			// downward.  Only remember workshop footprint cells in fixture air.
			if (tileSpace.y < 0.0f || tileSpace.y >= fixtureGroundY) continue;
			const Vec2f tile = map.getTileWorldPosition(tileSpace);
			AIBT_workshop_background_tiles.push_back(tile);
			AIBT_workshop_background_originals.push_back(map.getTile(tile).type);
		}
	}
}

void AIBT_TrackWorkshopBackgrounds(const int fixtureGroundY)
{
	CBlob@[] shops;
	getBlobsByName("buildershop", @shops);
	for (uint i = 0; i < shops.length; i++)
	{
		AIBT_TrackWorkshopBackground(shops[i], fixtureGroundY);
	}
}

void AIBT_RestoreWorkshopBackgrounds(const int fixtureGroundY)
{
	CMap@ map = getMap();
	if (map !is null)
	{
		for (uint i = 0; i < AIBT_workshop_background_tiles.length && i < AIBT_workshop_background_originals.length; i++)
		{
			const Vec2f tile = AIBT_workshop_background_tiles[i];
			const Vec2f tileSpace = map.getTileSpacePosition(tile);
			if (tileSpace.y < 0.0f || tileSpace.y >= fixtureGroundY) continue;

			const u16 current = map.getTile(tile).type;
			const u16 original = AIBT_workshop_background_originals[i];
			// Remove only a workshop-generated wood background.  If some test
			// changed the tile to anything else later, preserve that newer state.
			if (current != original && AIBT_IsWoodBackgroundTile(current))
			{
				map.server_SetTile(tile, original);
			}
		}
	}

	AIBT_tracked_workshop_ids.clear();
	AIBT_workshop_background_tiles.clear();
	AIBT_workshop_background_originals.clear();
}

bool AIBT_IsInsideMap(Vec2f pos)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const Vec2f tile = map.getTileSpacePosition(pos);
	return tile.x >= 0.0f && tile.y >= 0.0f &&
		tile.x < map.tilemapwidth && tile.y < map.tilemapheight;
}

CBlob@ AIBT_GetNearestTeamBuilderShop(CBlob@ home)
{
	if (home is null) return null;

	CBlob@[] shops;
	getBlobsByName("buildershop", @shops);
	CBlob@ nearest = null;
	f32 nearestDistance = 999999.0f;
	for (uint i = 0; i < shops.length; i++)
	{
		CBlob@ shop = shops[i];
		if (shop is null || shop.hasTag("dead") || shop.getTeamNum() != home.getTeamNum()) continue;
		const f32 distance = (shop.getPosition() - home.getPosition()).Length();
		if (distance < nearestDistance)
		{
			nearestDistance = distance;
			@nearest = shop;
		}
	}
	return nearest;
}

f32 AIBT_HorizontalEdgeGap(CBlob@ first, CBlob@ second)
{
	if (first is null || second is null) return -1.0f;
	Vec2f firstUL, firstLR, secondUL, secondLR;
	first.getShape().getBoundingRect(firstUL, firstLR);
	second.getShape().getBoundingRect(secondUL, secondLR);
	if (firstLR.x <= secondUL.x) return secondUL.x - firstLR.x;
	if (secondLR.x <= firstUL.x) return firstUL.x - secondLR.x;
	return -Maths::Min(firstLR.x - secondUL.x, secondLR.x - firstUL.x);
}

bool AIBT_HasGroundedShopApproach(CBlob@ shop)
{
	CMap@ map = getMap();
	if (shop is null || map is null) return false;

	const f32 ts = map.tilesize;
	for (int side = -1; side <= 1; side += 2)
	{
		// Legacy KAG Vec2f operators do not accept a const Vec2f left operand.
		Vec2f feet = shop.getPosition() + Vec2f(side * 3.0f * ts, ts);
		const Vec2f head = feet - Vec2f(0.0f, ts);
		const Vec2f ground = feet + Vec2f(0.0f, ts);
		if (AIBT_IsInsideMap(head) && AIBT_IsInsideMap(feet) && AIBT_IsInsideMap(ground) &&
			!map.isTileSolid(map.getTile(head).type) && !map.isTileSolid(map.getTile(feet).type) &&
			map.isTileSolid(map.getTile(ground).type)) return true;
	}
	return false;
}

bool AIBT_HasValidBuilderShopPlacement(CBlob@ home, const f32 minHomeEdgeTiles, string &out reason)
{
	reason = "shop_missing";
	if (home is null) return false;

	CMap@ map = getMap();
	if (map is null)
	{
		reason = "map_missing";
		return false;
	}

	CBlob@ shop = AIBT_GetNearestTeamBuilderShop(home);
	if (shop is null) return false;

	const f32 ts = map.tilesize;
	const Vec2f delta = shop.getPosition() - home.getPosition();
	const f32 horizontalTiles = Maths::Abs(delta.x) / ts;
	const f32 homeEdgeTiles = AIBT_HorizontalEdgeGap(shop, home) / ts;
	if (homeEdgeTiles < minHomeEdgeTiles)
	{
		reason = "shop_too_close home=" + home.getName() + " dx_tiles=" + horizontalTiles +
			" edge_tiles=" + homeEdgeTiles + " required_edge=" + minHomeEdgeTiles;
		return false;
	}

	u8 clearTiles = 0;
	u8 supportedColumns = 0;
	for (int x = -2; x <= 2; x++)
	{
		for (int y = -1; y <= 1; y++)
		{
			const Vec2f footprint = shop.getPosition() + Vec2f(x * ts, y * ts);
			if (!AIBT_IsInsideMap(footprint))
			{
				reason = "shop_footprint_out_of_bounds x=" + x + " y=" + y + " dx_tiles=" + horizontalTiles;
				return false;
			}

			const TileType type = map.getTile(footprint).type;
			if (map.isTileSolid(type))
			{
				reason = "shop_footprint_obstructed x=" + x + " y=" + y + " type=" + type + " dx_tiles=" + horizontalTiles;
				return false;
			}

			CMap::Sector@ sector = map.getSectorAtPosition(footprint, "no build");
			if (sector !is null && sector.ownerID != shop.getNetworkID())
			{
				reason = "shop_external_no_build x=" + x + " y=" + y + " owner=" + sector.ownerID +
					" shop=" + shop.getNetworkID() + " dx_tiles=" + horizontalTiles;
				return false;
			}
			clearTiles++;
		}

		const Vec2f support = shop.getPosition() + Vec2f(x * ts, 2.0f * ts);
		if (!AIBT_IsInsideMap(support) || !map.isTileSolid(map.getTile(support).type))
		{
			reason = "shop_not_fully_grounded column=" + x + " dx_tiles=" + horizontalTiles +
				" supported=" + supportedColumns;
			return false;
		}
		supportedColumns++;
	}

	if (!AIBT_HasGroundedShopApproach(shop))
	{
		reason = "shop_no_grounded_approach dx_tiles=" + horizontalTiles + " edge_tiles=" + homeEdgeTiles;
		return false;
	}

	reason = "shop_valid=true home=" + home.getName() + " dx_tiles=" + horizontalTiles +
		" edge_tiles=" + homeEdgeTiles + " dy_tiles=" + (delta.y / ts) +
		" footprint_clear=" + clearTiles + " supported=" + supportedColumns + " approach=true no_build=clear";
	return true;
}

bool AIBT_HasValidGroundedBuilderShop(CBlob@ home, string &out reason)
{
	// Measure clearance from the actual blob bounds.  Center distance hid the
	// original regression because both the home and workshop are several tiles
	// wide even when their anchors look separated.
	return AIBT_HasValidBuilderShopPlacement(home, 6.0f, reason);
}

u16 AIBT_CountInventoryMaterial(CBlob@ blob, const string &in name)
{
	if (blob is null) return 0;
	CInventory@ inv = blob.getInventory();
	u16 count = 0;
	if (inv !is null)
	{
		for (uint i = 0; i < inv.getItemsCount(); i++)
		{
			CBlob@ item = inv.getItem(i);
			if (item !is null && item.getName() == name)
			{
				count += AIBT_MaterialQuantity(item);
			}
		}
	}

	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == name)
	{
		count += AIBT_MaterialQuantity(carried);
	}
	return count;
}

string AIBT_DescribeBuilder(CBlob@ bot)
{
	if (bot is null) return "bot=null";
	CBlob@ target = getBlobByNetworkID(bot.get_netid("ai builder target"));
	return "state=" + AIBT_StateName(bot.get_u8("ai builder state")) +
		" target=" + AIBT_BlobRef(target) +
		" pos=" + AIB_EventPos(bot.getPosition()) +
		" dest=" + AIB_EventPos(bot.get_Vec2f("ai builder destination")) +
		" tile=" + AIB_EventPos(bot.get_Vec2f("ai builder tile target")) +
		" obstruction=" + bot.get_u8("ai builder obstruction threshold") +
		" gym=" + AIBG_FailureNames(bot.get_u16("aib gym failure flags")) +
		" inv_wood=" + AIBT_CountInventoryMaterial(bot, "mat_wood") +
		" inv_stone=" + AIBT_CountInventoryMaterial(bot, "mat_stone");
}

bool AIBT_TargetIs(CBlob@ bot, CBlob@ expected)
{
	if (bot is null || expected is null) return false;
	return bot.get_netid("ai builder target") == expected.getNetworkID();
}
