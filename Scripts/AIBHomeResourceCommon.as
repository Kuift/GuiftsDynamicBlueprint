#include "AIBBarrierCommon.as";

const f32 AIBR_LOOSE_HOME_RADIUS = 88.0f;
const f32 AIBR_CRATE_STORAGE_RADIUS = 128.0f;
const string AIBR_ASSIGNED_HOME_KEY = "aib strategy resource home";

s8 AIBR_GetBarrierZone(const f32 x, const u16 x1, const u16 x2)
{
	const u16 left = Maths::Min(x1, x2);
	const u16 right = Maths::Max(x1, x2);
	if (x < left) return -1;
	if (x > right) return 1;
	return 0;
}

bool AIBR_IsOnSameBarrierSide(CBlob@ reference, Vec2f position)
{
	CRules@ rules = getRules();
	if (rules is null || !AIB_ShouldBarrier(rules)) return true;
	const u16 x1 = rules.get_u16("barrier_x1");
	const u16 x2 = rules.get_u16("barrier_x2");
	if (x1 == x2) return true;
	if (reference is null) return false;
	const s8 referenceZone = AIBR_GetBarrierZone(reference.getPosition().x, x1, x2);
	const s8 resourceZone = AIBR_GetBarrierZone(position.x, x1, x2);
	return referenceZone != 0 && referenceZone == resourceZone;
}

bool AIBR_IsFriendlyResourceHome(CBlob@ builder, CBlob@ home)
{
	if (builder is null || home is null || home.hasTag("dead")) return false;
	if (home.getTeamNum() != builder.getTeamNum()) return false;
	const string name = home.getName();
	return name == "tent" || name == "hall";
}

CBlob@ AIBR_GetAssignedResourceHome(CBlob@ builder)
{
	if (builder is null || !builder.get_bool("aib strategy assigned")) return null;
	CBlob@ home = getBlobByNetworkID(builder.get_netid(AIBR_ASSIGNED_HOME_KEY));
	return AIBR_IsFriendlyResourceHome(builder, home) ? home : null;
}

bool AIBR_IsLooseWorldResource(CBlob@ blob)
{
	if (blob is null || blob.getName().substr(0, 4) != "mat_") return false;
	return !blob.hasTag("dead") && !blob.isAttached() && !blob.isInInventory();
}

bool AIBR_IsLooseHomeMaterial(CBlob@ home, CBlob@ material)
{
	if (home is null || !AIBR_IsLooseWorldResource(material)) return false;
	if (!AIBR_IsOnSameBarrierSide(home, material.getPosition())) return false;
	// AIB_GetHomeDropPoint may move up to three tiles sideways and two tiles
	// vertically around this nominal point.  Eleven tiles covers the old
	// seven-tile pickup radius around every one of those legal drop points,
	// while keeping remote battlefield stacks out of base stock.
	Vec2f center = home.getPosition() + Vec2f(0.0f, -12.0f);
	return (material.getPosition() - center).Length() <= AIBR_LOOSE_HOME_RADIUS;
}

bool AIBR_IsBuilderPassableAt(Vec2f position)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const TileType type = map.getTile(position).type;
	return !map.isTileBedrock(type) && !map.isTileSolid(type);
}

bool AIBR_IsInsideCurrentBarrierZoneAt(Vec2f position)
{
	CRules@ rules = getRules();
	if (rules is null || !AIB_ShouldBarrier(rules)) return true;
	const u16 x1 = rules.get_u16("barrier_x1");
	const u16 x2 = rules.get_u16("barrier_x2");
	if (x1 == x2) return true;
	return AIBR_GetBarrierZone(position.x, x1, x2) != 0;
}

bool AIBR_IsGroundedStoragePoint(Vec2f candidate)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const f32 ts = map.tilesize;
	if (candidate.x < 2.0f * ts || candidate.x >= (map.tilemapwidth - 2) * ts ||
		candidate.y < 2.0f * ts || candidate.y >= (map.tilemapheight - 2) * ts) return false;
	if (!AIBR_IsBuilderPassableAt(candidate) || !AIBR_IsBuilderPassableAt(candidate - Vec2f(0.0f, ts))) return false;
	if (!map.isTileSolid(map.getTile(candidate + Vec2f(0.0f, ts)).type)) return false;
	return AIBR_IsInsideCurrentBarrierZoneAt(candidate);
}

bool AIBR_IsGroundedStoragePoint(CBlob@ home, Vec2f candidate)
{
	return AIBR_IsGroundedStoragePoint(candidate) && AIBR_IsOnSameBarrierSide(home, candidate);
}

Vec2f AIBR_FindBaseStoragePoint(CBlob@ home)
{
	if (home is null) return Vec2f_zero;
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;
	const f32 ts = map.tilesize;
	Vec2f homeSpace = map.getTileSpacePosition(home.getPosition());
	const int homeX = Maths::Floor(homeSpace.x);
	const int homeY = Maths::Floor(homeSpace.y);
	Vec2f best = Vec2f_zero;
	f32 bestScore = 999999.0f;
	// Keep this search shared with the executor.  A crate that is merely near a
	// base but not near this grounded point is not production-accessible stock.
	for (int distance = 9; distance >= 4; distance--)
	{
		for (int side = -1; side <= 1; side += 2)
		{
			const int x = homeX + side * distance;
			for (int yOffset = -3; yOffset <= 4; yOffset++)
			{
				const int y = homeY + yOffset;
				Vec2f candidate = Vec2f((x + 0.5f) * ts, (y + 0.5f) * ts);
				if (!AIBR_IsGroundedStoragePoint(home, candidate)) continue;
				const f32 score = Maths::Abs(distance - 9) * 3.0f + Maths::Abs(yOffset) + (side > 0 ? 0.25f : 0.0f);
				if (score < bestScore) { bestScore = score; best = candidate; }
			}
		}
	}
	return best;
}

bool AIBR_IsBaseResourceCrate(CBlob@ crate, CBlob@ home, Vec2f storage)
{
	if (crate is null || home is null || storage == Vec2f_zero || crate.hasTag("dead")) return false;
	if (crate.isAttached() || crate.isInInventory() || crate.getTeamNum() != home.getTeamNum() || crate.exists("packed")) return false;
	if (!AIBR_IsOnSameBarrierSide(home, crate.getPosition())) return false;
	if ((crate.getPosition() - storage).Length() > AIBR_CRATE_STORAGE_RADIUS) return false;
	return crate.getInventory() !is null;
}

u16 AIBR_CountAccessibleHomeMaterial(CBlob@ home, const string &in material)
{
	if (home is null) return 0;
	u32 total = 0;
	CBlob@[] materials;
	getBlobsByName(material, @materials);
	for (uint i = 0; i < materials.length; i++)
	{
		CBlob@ item = materials[i];
		if (AIBR_IsLooseHomeMaterial(home, item)) total += item.getQuantity();
	}
	Vec2f storage = AIBR_FindBaseStoragePoint(home);
	if (storage != Vec2f_zero)
	{
		CBlob@[] crates;
		getBlobsByName("crate", @crates);
		for (uint i = 0; i < crates.length; i++)
		{
			CBlob@ crate = crates[i];
			if (!AIBR_IsBaseResourceCrate(crate, home, storage)) continue;
			CInventory@ inventory = crate.getInventory();
			if (inventory !is null) total += inventory.getCount(material);
		}
	}
	return u16(Maths::Min(total, u32(65535)));
}
