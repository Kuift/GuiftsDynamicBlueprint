#include "BlueprintCommon.as";

// Canonical IDs are the legacy editor IDs. Rotation occupies the top two bits.
const u16 AIBP_STONE_BLOCK = 1;
const u16 AIBP_STONE_BACKWALL = 2;
const u16 AIBP_STONE_DOOR = 3;
const u16 AIBP_WOOD_BLOCK = 4;
const u16 AIBP_WOOD_BACKWALL = 5;
const u16 AIBP_WOOD_DOOR = 6;
const u16 AIBP_BRIDGE = 7;
const u16 AIBP_PLATFORM = 9;
// Legacy blueprint-atlas ID for the builder's stone spikes. Keep this ID so
// PNG save/load continues to encode the selection directly in the red channel.
const u16 AIBP_SPIKES = 44;
const u16 AIBP_LADDER = 88;
// Workshop variants deliberately use distinct catalog IDs. Blueprint PNGs
// store the ID in the red channel, so the chosen type survives save/load,
// network snapshots, and the AI build queue without a side table.
const u16 AIBP_BUILDER_SHOP = 80;
const u16 AIBP_QUARTERS = 81;
const u16 AIBP_KNIGHT_SHOP = 82;
const u16 AIBP_ARCHER_SHOP = 83;
const u16 AIBP_BOAT_SHOP = 84;
const u16 AIBP_VEHICLE_SHOP = 85;
const u16 AIBP_AI_BUILDER_SHOP = 86;
const u16 AIBP_NURSERY = 87;
const u16 AIBP_STORAGE = 89;
const u16 AIBP_TUNNEL = 90;
const u16 AIBP_QUARRY = 91;

bool AIBP_IsWorkshopBlock(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	return id >= AIBP_BUILDER_SHOP && id <= AIBP_NURSERY ||
		id >= AIBP_STORAGE && id <= AIBP_QUARRY;
}

u8 AIBP_DefaultRotation(const u16 encoded)
{
	return AIBP_BlockId(encoded) == AIBP_LADDER ? 1 : 0;
}

u16 AIBP_FromBuilderSelection(CBlob@ builder, const u16 fallback, const u8 rotation)
{
	if (builder is null || builder.getName() != "builder") return AIBP_EncodeBlock(fallback, rotation);
	const u16 tile = u16(builder.get_TileType("buildtile"));
	if (tile == 48) return AIBP_STONE_BLOCK;
	if (tile == 64) return AIBP_STONE_BACKWALL;
	if (tile == 196) return AIBP_WOOD_BLOCK;
	if (tile == 205) return AIBP_WOOD_BACKWALL;
	if (builder.get_u8("build page") != 0) return AIBP_EncodeBlock(fallback, rotation);
	const u8 blob = builder.get_u8("buildblob");
	if (blob == 2) return AIBP_EncodeBlock(AIBP_STONE_DOOR, rotation);
	if (blob == 5) return AIBP_EncodeBlock(AIBP_WOOD_DOOR, rotation);
	if (blob == 6) return AIBP_EncodeBlock(AIBP_BRIDGE, rotation);
	if (blob == 7) return AIBP_EncodeBlock(AIBP_LADDER, rotation);
	if (blob == 8) return AIBP_EncodeBlock(AIBP_PLATFORM, rotation);
	// CTF/SmallCTF/TTH insert their workshop/factory at slot 9, shifting
	// spikes from the common-builder slot 9 to slot 10.
	const string mode = getRules().gamemode_name;
	const u8 spikesSlot = (mode == "CTF" || mode == "SmallCTF" || mode == "TTH") ? 10 : 9;
	if (blob == spikesSlot) return AIBP_EncodeBlock(AIBP_SPIKES, rotation);
	return AIBP_EncodeBlock(fallback, rotation);
}

u16 AIBP_NextCatalogId(const u16 current, const s8 direction)
{
	u16[] ids = { AIBP_STONE_BLOCK, AIBP_STONE_BACKWALL, AIBP_STONE_DOOR,
		AIBP_WOOD_BLOCK, AIBP_WOOD_BACKWALL, AIBP_WOOD_DOOR, AIBP_BRIDGE, AIBP_PLATFORM, AIBP_SPIKES, AIBP_LADDER,
		AIBP_BUILDER_SHOP, AIBP_QUARTERS, AIBP_KNIGHT_SHOP, AIBP_ARCHER_SHOP,
		AIBP_BOAT_SHOP, AIBP_VEHICLE_SHOP, AIBP_AI_BUILDER_SHOP, AIBP_NURSERY,
		AIBP_STORAGE, AIBP_TUNNEL, AIBP_QUARRY };
	int index = 0;
	for (uint i = 0; i < ids.length; i++) if (ids[i] == AIBP_BlockId(current)) { index = i; break; }
	index = (index + direction + int(ids.length)) % int(ids.length);
	return ids[index];
}

u16 AIBP_CanonicalId(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	if (id == 48) return AIBP_STONE_BLOCK;
	if (id == 64) return AIBP_STONE_BACKWALL;
	if (id == 196) return AIBP_WOOD_BLOCK;
	if (id == 205) return AIBP_WOOD_BACKWALL;
	return id;
}

bool AIBP_IsCatalogBlock(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	return id == AIBP_STONE_BLOCK || id == AIBP_STONE_BACKWALL ||
		id == AIBP_STONE_DOOR || id == AIBP_WOOD_BLOCK ||
		id == AIBP_WOOD_BACKWALL || id == AIBP_WOOD_DOOR ||
		id == AIBP_BRIDGE || id == AIBP_PLATFORM || id == AIBP_SPIKES || id == AIBP_LADDER ||
		AIBP_IsWorkshopBlock(encoded) ||
		id == 48 || id == 64 || id == 196 || id == 205;
}

bool AIBP_IsTileBlock(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	return id == AIBP_STONE_BLOCK || id == AIBP_STONE_BACKWALL ||
		id == AIBP_WOOD_BLOCK || id == AIBP_WOOD_BACKWALL ||
		id == 48 || id == 64 || id == 196 || id == 205;
}

bool AIBP_IsSolidTileBlock(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	return id == AIBP_STONE_BLOCK || id == AIBP_WOOD_BLOCK || id == 48 || id == 196;
}

bool AIBP_IsBlobBlock(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	return id == AIBP_STONE_DOOR || id == AIBP_WOOD_DOOR || id == AIBP_BRIDGE || id == AIBP_PLATFORM || id == AIBP_SPIKES ||
		id == AIBP_LADDER || AIBP_IsWorkshopBlock(encoded);
}

string AIBP_BlockBlobName(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	if (id == AIBP_STONE_DOOR) return "stone_door";
	if (id == AIBP_WOOD_DOOR) return "wooden_door";
	if (id == AIBP_BRIDGE) return "bridge";
	if (id == AIBP_PLATFORM) return "wooden_platform";
	if (id == AIBP_SPIKES) return "spikes";
	if (id == AIBP_LADDER) return "ladder";
	if (id == AIBP_BUILDER_SHOP) return "buildershop";
	if (id == AIBP_QUARTERS) return "quarters";
	if (id == AIBP_KNIGHT_SHOP) return "knightshop";
	if (id == AIBP_ARCHER_SHOP) return "archershop";
	if (id == AIBP_BOAT_SHOP) return "boatshop";
	if (id == AIBP_VEHICLE_SHOP) return "vehicleshop";
	if (id == AIBP_AI_BUILDER_SHOP) return "aibuildershop";
	if (id == AIBP_NURSERY) return "nursery";
	if (id == AIBP_STORAGE) return "storage";
	if (id == AIBP_TUNNEL) return "tunnel";
	if (id == AIBP_QUARRY) return "quarry";
	return "";
}

bool AIBP_IsBlueprintBlobName(const string &in name)
{
	return name == "stone_door" || name == "wooden_door" || name == "bridge" || name == "wooden_platform" || name == "spikes" ||
		name == "ladder" || name == "buildershop" || name == "quarters" ||
		name == "knightshop" || name == "archershop" || name == "boatshop" ||
		name == "vehicleshop" || name == "aibuildershop" || name == "nursery" ||
		name == "storage" || name == "tunnel" || name == "quarry";
}

string AIBP_BlockDisplayName(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	if (id == AIBP_STONE_BLOCK || id == 48) return "Stone block";
	if (id == AIBP_STONE_BACKWALL || id == 64) return "Stone backwall";
	if (id == AIBP_STONE_DOOR) return "Stone door";
	if (id == AIBP_WOOD_BLOCK || id == 196) return "Wood block";
	if (id == AIBP_WOOD_BACKWALL || id == 205) return "Wood backwall";
	if (id == AIBP_WOOD_DOOR) return "Wooden door";
	if (id == AIBP_BRIDGE) return "Team bridge";
	if (id == AIBP_PLATFORM) return "Wooden platform";
	if (id == AIBP_SPIKES) return "Spikes";
	if (id == AIBP_LADDER) return "Ladder";
	if (id == AIBP_BUILDER_SHOP) return "Workshop: Builder shop";
	if (id == AIBP_QUARTERS) return "Workshop: Quarters";
	if (id == AIBP_KNIGHT_SHOP) return "Workshop: Knight shop";
	if (id == AIBP_ARCHER_SHOP) return "Workshop: Archer shop";
	if (id == AIBP_BOAT_SHOP) return "Workshop: Boat shop";
	if (id == AIBP_VEHICLE_SHOP) return "Workshop: Vehicle shop";
	if (id == AIBP_AI_BUILDER_SHOP) return "Workshop: AI builders";
	if (id == AIBP_NURSERY) return "Workshop: Nursery";
	if (id == AIBP_STORAGE) return "Workshop: Storage";
	if (id == AIBP_TUNNEL) return "Workshop: Tunnel";
	if (id == AIBP_QUARRY) return "Workshop: Quarry";
	return "Unknown";
}

string AIBP_BlockMaterial(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	if (id == AIBP_STONE_BLOCK || id == AIBP_STONE_BACKWALL || id == AIBP_STONE_DOOR || id == 48 || id == 64) return "mat_stone";
	if (id == AIBP_SPIKES) return "mat_stone";
	if (id == AIBP_WOOD_BLOCK || id == AIBP_WOOD_BACKWALL || id == AIBP_WOOD_DOOR || id == AIBP_BRIDGE || id == AIBP_PLATFORM || id == AIBP_LADDER || AIBP_IsWorkshopBlock(encoded) || id == 196 || id == 205) return "mat_wood";
	return "";
}

u16 AIBP_BlockCost(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	if (id == AIBP_STONE_BACKWALL || id == AIBP_WOOD_BACKWALL || id == 64 || id == 205) return 2;
	if (id == AIBP_STONE_DOOR) return 50;
	if (id == AIBP_WOOD_DOOR) return 30;
	if (id == AIBP_BRIDGE) return 30;
	if (id == AIBP_PLATFORM) return 15;
	if (id == AIBP_SPIKES) return 30;
	if (id == AIBP_LADDER) return 10;
	// This is the base workshop construction cost. Typed shops are created
	// directly so the blueprint does not stop at the conversion menu.
	if (AIBP_IsWorkshopBlock(encoded)) return 150;
	if (AIBP_IsTileBlock(encoded)) return 10;
	return 0;
}

u8 AIBP_BlockPhase(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	if (id == AIBP_STONE_BACKWALL || id == AIBP_WOOD_BACKWALL || id == 64 || id == 205) return AIBP_Phase::foundation;
	if (id == AIBP_STONE_DOOR || id == AIBP_WOOD_DOOR || id == AIBP_BRIDGE || id == AIBP_PLATFORM || id == AIBP_SPIKES || id == AIBP_LADDER) return AIBP_Phase::access;
	if (AIBP_IsWorkshopBlock(encoded)) return AIBP_Phase::shell;
	return AIBP_Phase::shell;
}

TileType AIBP_BlockTileType(const u16 encoded)
{
	const u16 id = AIBP_BlockId(encoded);
	if (id == AIBP_STONE_BLOCK || id == 48) return CMap::tile_castle;
	if (id == AIBP_STONE_BACKWALL || id == 64) return CMap::tile_castle_back;
	if (id == AIBP_WOOD_BLOCK || id == 196) return CMap::tile_wood;
	if (id == AIBP_WOOD_BACKWALL || id == 205) return CMap::tile_wood_back;
	return CMap::tile_empty;
}
