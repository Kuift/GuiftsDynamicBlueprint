#include "MaterialCommon.as"
#include "AIBHomeResourceCommon.as"

const string AIB_GUIDE_RESUPPLY_NEXT_KEY = "aib guide resupply next";
const string AIB_GUIDE_RESUPPLY_LAST_KEY = "aib guide resupply last";
const string AIB_GUIDE_RESUPPLY_SOURCE_KEY = "aib guide resupply source";
const string AIB_GUIDE_RESUPPLY_TEST_KEY = "aib guide resupply test enabled";
const u16 AIB_GUIDE_WARMUP_WOOD = 250;
const u16 AIB_GUIDE_WARMUP_STONE = 80;
const u16 AIB_GUIDE_MATCH_WOOD = 100;
const u16 AIB_GUIDE_MATCH_STONE = 30;
const u32 AIB_GUIDE_WARMUP_INTERVAL = 40 * 30;
const u32 AIB_GUIDE_MATCH_INTERVAL = 20 * 30;
const f32 AIB_GUIDE_BASE_SHOP_ENVELOPE = 28.0f * 8.0f;

bool AIBGuide_ResupplyEnabled(CRules@ rules)
{
	return rules !is null && (rules.gamemode_name == "CTF" || rules.get_bool(AIB_GUIDE_RESUPPLY_TEST_KEY));
}

bool AIBGuide_IsAutonomousBuilder(CBlob@ blob)
{
	return blob !is null && !blob.hasTag("dead") && blob.getName() == "aibuilder" && !blob.hasTag("autobuilder");
}

bool AIBGuide_CanCreateTeamQuarry(const int team)
{
	CBlob@[] quarries;
	getBlobsByName("quarry", @quarries);
	for (uint i = 0; i < quarries.length; i++)
	{
		CBlob@ quarry = quarries[i];
		if (quarry !is null && !quarry.hasTag("dead") && quarry.getTeamNum() == team) return false;
	}
	return true;
}

CBlob@ AIBGuide_GetResourceHome(CBlob@ builder)
{
	if (builder is null) return null;
	CBlob@ assigned = AIBR_GetAssignedResourceHome(builder);
	if (assigned !is null) return assigned;

	CBlob@ best = null;
	f32 bestDistance = 99999999.0f;
	string[] names = { "tent", "hall" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] homes;
		getBlobsByName(names[n], @homes);
		for (uint i = 0; i < homes.length; i++)
		{
			CBlob@ home = homes[i];
			if (!AIBR_IsFriendlyResourceHome(builder, home)) continue;
			const f32 distance = (home.getPosition() - builder.getPosition()).LengthSquared();
			if (distance < bestDistance)
			{
				bestDistance = distance;
				@best = home;
			}
		}
		// Preserve the production home preference: a tent beats a hall even if
		// the hall is marginally closer.
		if (best !is null) return best;
	}
	return null;
}

bool AIBGuide_IsBaseScopedBuilderShop(CBlob@ shop, CBlob@ builder)
{
	if (shop is null || builder is null || shop.hasTag("dead") || shop.getName() != "buildershop" ||
		shop.getTeamNum() != builder.getTeamNum()) return false;
	CBlob@ home = AIBGuide_GetResourceHome(builder);
	return home !is null &&
		(shop.getPosition() - home.getPosition()).Length() <= AIB_GUIDE_BASE_SHOP_ENVELOPE &&
		AIBR_IsOnSameBarrierSide(home, shop.getPosition());
}

bool AIBGuide_IsEligibleResupplySpot(CBlob@ spot, CBlob@ builder)
{
	if (spot is null || builder is null || spot.hasTag("dead") || spot.getTeamNum() != builder.getTeamNum()) return false;
	if (spot.getName() == "tent") return spot is AIBGuide_GetResourceHome(builder);
	return AIBGuide_IsBaseScopedBuilderShop(spot, builder);
}

bool AIBGuide_IsMatchResupplySpot(CBlob@ spot, CBlob@ builder)
{
	if (!AIBGuide_IsEligibleResupplySpot(spot, builder)) return false;
	// CTF_GiveSpawnItems asks the resupply structure for its overlap list. The
	// one-to-one isOverlapping query is not equivalent during the spawn/physics
	// callback boundary, so mirror the production CTF direction here.
	CBlob@[] overlapping;
	if (!spot.getOverlapping(overlapping)) return false;
	for (uint i = 0; i < overlapping.length; i++)
	{
		if (overlapping[i] is builder) return true;
	}
	return false;
}

CBlob@ AIBGuide_GetOverlappingResupplySpot(CBlob@ builder)
{
	if (builder is null) return null;
	string[] names = { "tent", "buildershop" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] spots;
		getBlobsByName(names[n], @spots);
		for (uint i = 0; i < spots.length; i++)
		{
			if (AIBGuide_IsMatchResupplySpot(spots[i], builder)) return spots[i];
		}
	}
	return null;
}

CBlob@ AIBGuide_GetNearestResupplySpot(CBlob@ builder)
{
	if (builder is null) return null;
	CBlob@ best = null;
	f32 bestDistance = 99999999.0f;
	string[] names = { "tent", "buildershop" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] spots;
		getBlobsByName(names[n], @spots);
		for (uint i = 0; i < spots.length; i++)
		{
			CBlob@ spot = spots[i];
			if (!AIBGuide_IsEligibleResupplySpot(spot, builder)) continue;
			const f32 distance = (spot.getPosition() - builder.getPosition()).LengthSquared();
			if (distance < bestDistance)
			{
				bestDistance = distance;
				@best = spot;
			}
		}
	}
	return best;
}

bool AIBGuide_IsSafeEpisodeBoundary(CBlob@ builder)
{
	if (builder is null || builder.get_netid("ai builder target") != 0 ||
		builder.get_Vec2f("ai builder tile target") != Vec2f_zero) return false;
	const u8 state = builder.get_u8("ai builder state");
	// Stable enum values: idle, find_tree, find_stone, find_blueprint_block.
	return state == 0 || state == 1 || state == 7 || state == 13;
}

bool AIBGuide_IsNaturalTreeFarmPosition(Vec2f pos)
{
	CMap@ map = getMap();
	if (map is null || pos.x < 0.0f || pos.y < 0.0f ||
		pos.x >= map.tilemapwidth * map.tilesize || pos.y >= map.tilemapheight * map.tilesize ||
		!AIBR_IsInsideCurrentBarrierZoneAt(pos)) return false;
	if (map.isTileSolid(pos) || !map.isTileGround(map.getTile(pos + Vec2f(0.0f, map.tilesize)).type)) return false;
	if (map.getSectorAtPosition(pos, "no build") !is null) return false;

	CBlob@[] nearby;
	if (map.getBlobsInRadius(pos, 15.5f, @nearby))
	{
		for (uint i = 0; i < nearby.length; i++)
		{
			CBlob@ other = nearby[i];
			if (other !is null && !other.hasTag("dead") &&
				(other.getName() == "seed" || other.hasTag("tree"))) return false;
		}
	}
	return true;
}

bool AIBGuide_IsSameBarrierZone(const f32 anchorX, const f32 candidateX,
	const u16 x1, const u16 x2)
{
	if (x1 == x2) return true;
	const s8 anchorZone = AIBR_GetBarrierZone(anchorX, x1, x2);
	const s8 candidateZone = AIBR_GetBarrierZone(candidateX, x1, x2);
	return anchorZone != 0 && anchorZone == candidateZone;
}

bool AIBGuide_IsSameCurrentBarrierZone(Vec2f anchor, Vec2f candidate)
{
	CRules@ rules = getRules();
	if (rules is null || !AIB_ShouldBarrier(rules)) return true;
	return AIBGuide_IsSameBarrierZone(anchor.x, candidate.x,
		rules.get_u16("barrier_x1"), rules.get_u16("barrier_x2"));
}

Vec2f AIBGuide_FindTreeFarmPosition(Vec2f anchor)
{
	CMap@ map = getMap();
	if (map is null) return Vec2f_zero;
	const f32 ts = map.tilesize;
	for (int radius = 2; radius <= 8; radius++)
	{
		for (int side = -1; side <= 1; side += 2)
		{
			Vec2f levelCandidate = Vec2f(Maths::Floor(anchor.x / ts + side * radius) * ts + ts * 0.5f,
				Maths::Floor(anchor.y / ts) * ts + ts * 0.5f);
			if (AIBGuide_IsNaturalTreeFarmPosition(levelCandidate) &&
				AIBGuide_IsSameCurrentBarrierZone(anchor, levelCandidate)) return levelCandidate;
			for (int offset = 1; offset <= 4; offset++)
			{
				Vec2f above = levelCandidate + Vec2f(0.0f, -offset * ts);
				if (AIBGuide_IsNaturalTreeFarmPosition(above) &&
					AIBGuide_IsSameCurrentBarrierZone(anchor, above)) return above;
				Vec2f below = levelCandidate + Vec2f(0.0f, offset * ts);
				if (AIBGuide_IsNaturalTreeFarmPosition(below) &&
					AIBGuide_IsSameCurrentBarrierZone(anchor, below)) return below;
			}
		}
	}
	return Vec2f_zero;
}

bool AIBGuide_IsSawOutsideFriendlyFlagRoom(CBlob@ saw, const int team)
{
	if (saw is null) return false;
	CBlob@[] flags;
	getBlobsByName("ctf_flag", @flags);
	for (uint i = 0; i < flags.length; i++)
	{
		CBlob@ flag = flags[i];
		if (flag !is null && !flag.hasTag("dead") && flag.getTeamNum() == team &&
			(flag.getPosition() - saw.getPosition()).Length() < 10.0f * 8.0f) return false;
	}
	return true;
}

bool AIBGuide_IsStructurallySafeSaw(CBlob@ builder, CBlob@ log, CBlob@ saw, CBlob@ home)
{
	if (builder is null || log is null || saw is null || home is null || saw.hasTag("dead") ||
		saw.isAttached() || saw.isInInventory() || saw.getName() != "saw" ||
		saw.getTeamNum() != builder.getTeamNum() || !saw.get_bool("saw_on")) return false;
	return (saw.getPosition() - home.getPosition()).Length() <= 28.0f * 8.0f &&
		(saw.getPosition() - log.getPosition()).Length() <= 20.0f * 8.0f &&
		AIBGuide_IsSawOutsideFriendlyFlagRoom(saw, builder.getTeamNum()) &&
		AIBR_IsOnSameBarrierSide(builder, saw.getPosition());
}

CBlob@ AIBGuide_CreateMaterial(CBlob@ builder, const string &in name, const u16 quantity)
{
	if (builder is null || quantity == 0) return null;
	CBlob@ material = server_CreateBlobNoInit(name);
	if (material is null) return null;
	material.Tag("custom quantity");
	material.Tag("aib guide resupply material");
	material.Init();
	material.server_SetQuantity(quantity);
	if (!builder.server_PutInInventory(material))
	{
		material.setPosition(builder.getPosition());
		material.setVelocity(Vec2f_zero);
	}
	return material;
}

bool AIBGuide_TryGrantResupply(CRules@ rules, CBlob@ builder, const bool warmup)
{
	if (!isServer() || !AIBGuide_ResupplyEnabled(rules) || !AIBGuide_IsAutonomousBuilder(builder)) return false;
	const u32 now = getGameTime();
	if (builder.get_u32(AIB_GUIDE_RESUPPLY_NEXT_KEY) > now) return false;
	CBlob@ source = null;
	if (!warmup)
	{
		@source = AIBGuide_GetOverlappingResupplySpot(builder);
		if (source is null) return false;
	}

	const u16 wood = warmup ? AIB_GUIDE_WARMUP_WOOD : AIB_GUIDE_MATCH_WOOD;
	const u16 stone = warmup ? AIB_GUIDE_WARMUP_STONE : AIB_GUIDE_MATCH_STONE;
	CBlob@ woodBlob = AIBGuide_CreateMaterial(builder, "mat_wood", wood);
	CBlob@ stoneBlob = AIBGuide_CreateMaterial(builder, "mat_stone", stone);
	if (woodBlob is null || stoneBlob is null)
	{
		// A resupply is one grant, not two independent gifts.  Roll back the
		// successfully created half if allocation of the other material failed.
		if (woodBlob !is null) woodBlob.server_Die();
		if (stoneBlob !is null) stoneBlob.server_Die();
		return false;
	}
	builder.set_u32(AIB_GUIDE_RESUPPLY_LAST_KEY, now);
	builder.set_u32(AIB_GUIDE_RESUPPLY_NEXT_KEY, now + (warmup ? AIB_GUIDE_WARMUP_INTERVAL : AIB_GUIDE_MATCH_INTERVAL));
	builder.set_netid(AIB_GUIDE_RESUPPLY_SOURCE_KEY, source is null ? 0 : source.getNetworkID());
	return true;
}
