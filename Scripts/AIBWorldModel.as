#include "AIBStrategicTypes.as";

array<u16> AIBS_surface;
array<u16> AIBS_lane_width;
array<u16> AIBS_wall_height;
u16 AIBS_surface_width = 0;

void AIBS_RecomputeTerrainFeatures(const int fromX, const int toX)
{
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0 || AIBS_surface.length != uint(map.tilemapwidth)) return;
	if (AIBS_lane_width.length != uint(map.tilemapwidth)) AIBS_lane_width.set_length(map.tilemapwidth);
	if (AIBS_wall_height.length != uint(map.tilemapwidth)) AIBS_wall_height.set_length(map.tilemapwidth);
	const int start = Maths::Max(0, fromX);
	const int end = Maths::Min(int(map.tilemapwidth) - 1, toX);
	for (int x = start; x <= end; x++)
	{
		const int surface = int(AIBS_surface[x]);
		const int leftSurface = int(AIBS_surface[Maths::Max(0, x - 1)]);
		const int rightSurface = int(AIBS_surface[Maths::Min(int(map.tilemapwidth) - 1, x + 1)]);
		AIBS_wall_height[x] = u16(Maths::Max(Maths::Abs(surface - leftSurface), Maths::Abs(surface - rightSurface)));
		u16 laneWidth = 1;
		for (int direction = -1; direction <= 1; direction += 2)
		{
			for (int step = 1; step <= 12; step++)
			{
				const int nx = x + direction * step;
				if (nx < 0 || nx >= map.tilemapwidth || Maths::Abs(int(AIBS_surface[nx]) - surface) > 2) break;
				laneWidth++;
			}
		}
		AIBS_lane_width[x] = laneWidth;
	}
}

bool AIBS_IsCombatBlob(CBlob@ blob)
{
	if (blob is null) return false;
	const string name = blob.getName();
	return name == "knight" || name == "archer" || name == "builder" || name == "aibuilder" || name == "autobuilder";
}

CBlob@ AIBS_NearestTeamBlob(const u8 team, const string &in name, Vec2f from)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	CBlob@ best = null;
	f32 distance = 99999999.0f;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob is null || blob.hasTag("dead") || blob.getTeamNum() != team) continue;
		const f32 d = (blob.getPosition() - from).LengthSquared();
		if (d < distance) { distance = d; @best = blob; }
	}
	return best;
}

CBlob@ AIBS_TeamHomeBlob(const u8 team)
{
	CBlob@ flag = AIBS_NearestTeamBlob(team, "flag", Vec2f_zero);
	if (flag !is null) return flag;
	CBlob@ tent = AIBS_NearestTeamBlob(team, "tent", Vec2f_zero);
	if (tent !is null) return tent;
	return AIBS_NearestTeamBlob(team, "hall", Vec2f_zero);
}

CBlob@ AIBS_TeamResourceHomeBlob(const u8 team, Vec2f from)
{
	CBlob@ tent = AIBS_NearestTeamBlob(team, "tent", from);
	if (tent !is null) return tent;
	return AIBS_NearestTeamBlob(team, "hall", from);
}

CBlob@ AIBS_EnemyHomeBlob(const u8 team, Vec2f from)
{
	CBlob@ best = null;
	f32 distance = 99999999.0f;
	string[] names = { "flag", "tent", "hall" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] homes;
		getBlobsByName(names[n], @homes);
		for (uint i = 0; i < homes.length; i++)
		{
			CBlob@ home = homes[i];
			if (home is null || home.hasTag("dead") || home.getTeamNum() == team || home.getTeamNum() >= 100) continue;
			const f32 d = (home.getPosition() - from).LengthSquared();
			if (d < distance) { distance = d; @best = home; }
		}
		if (best !is null) return best; // Prefer flags, then tents, then halls.
	}
	return best;
}

void AIBS_BuildStaticTerrain()
{
	CMap@ map = getMap();
	if (map is null) return;
	if (map.tilemapwidth == 0 || map.tilemapheight == 0)
	{
		AIBS_surface_width = 0;
		AIBS_surface.clear();
		AIBS_lane_width.clear();
		AIBS_wall_height.clear();
		return;
	}
	AIBS_surface_width = map.tilemapwidth;
	AIBS_surface.set_length(AIBS_surface_width);
	AIBS_lane_width.set_length(AIBS_surface_width);
	AIBS_wall_height.set_length(AIBS_surface_width);
	for (u16 x = 0; x < AIBS_surface_width; x++)
	{
		u16 surface = map.tilemapheight - 1;
		for (u16 y = 0; y < map.tilemapheight; y++)
		{
			if (map.isTileSolid(map.getTile(Vec2f(x * map.tilesize + 4, y * map.tilesize + 4)).type))
			{
				surface = y;
				break;
			}
		}
		AIBS_surface[x] = surface;
	}
	AIBS_RecomputeTerrainFeatures(0, int(AIBS_surface_width) - 1);
}

void AIBS_RefreshTerrainRegion(const int centerX, const int radius)
{
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0) return;
	if (AIBS_surface_width != map.tilemapwidth || AIBS_surface.length != uint(map.tilemapwidth)) AIBS_BuildStaticTerrain();
	if (AIBS_surface.length != uint(map.tilemapwidth)) return;
	const int start = Maths::Max(0, centerX - radius);
	const int end = Maths::Min(int(map.tilemapwidth) - 1, centerX + radius);
	for (int x = start; x <= end; x++)
	{
		u16 surface = map.tilemapheight - 1;
		for (u16 y = 0; y < map.tilemapheight; y++)
		{
			if (map.isTileSolid(map.getTile(Vec2f(x * map.tilesize + 4, y * map.tilesize + 4)).type))
			{
				surface = y;
				break;
			}
		}
		AIBS_surface[x] = surface;
	}
	AIBS_RecomputeTerrainFeatures(start - 12, end + 12);
}

u16 AIBS_SurfaceAt(const int x)
{
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0) return 0;
	if (AIBS_surface_width != map.tilemapwidth || AIBS_surface.length != uint(map.tilemapwidth)) AIBS_BuildStaticTerrain();
	if (AIBS_surface.length != uint(map.tilemapwidth)) return 0;
	const int safeX = Maths::Clamp(x, 0, map.tilemapwidth - 1);
	return AIBS_surface[safeX];
}

u16 AIBS_LaneWidthAt(const int x)
{
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0) return 0;
	if (AIBS_surface_width != map.tilemapwidth || AIBS_lane_width.length != uint(map.tilemapwidth)) AIBS_BuildStaticTerrain();
	if (AIBS_lane_width.length != uint(map.tilemapwidth)) return 0;
	return AIBS_lane_width[Maths::Clamp(x, 0, map.tilemapwidth - 1)];
}

u16 AIBS_WallHeightAt(const int x)
{
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0) return 0;
	if (AIBS_surface_width != map.tilemapwidth || AIBS_wall_height.length != uint(map.tilemapwidth)) AIBS_BuildStaticTerrain();
	if (AIBS_wall_height.length != uint(map.tilemapwidth)) return 0;
	return AIBS_wall_height[Maths::Clamp(x, 0, map.tilemapwidth - 1)];
}

u16 AIBS_CountStored(const u8 team, const string &in material)
{
	u32 total = 0;
	string[] names = { "tent", "hall", "crate", "buildershop", "aibuilder" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] blobs;
		getBlobsByName(names[n], @blobs);
		for (uint i = 0; i < blobs.length; i++)
		{
			CBlob@ blob = blobs[i];
			if (blob is null || blob.hasTag("dead") || blob.getTeamNum() != team) continue;
			CInventory@ inv = blob.getInventory();
			if (inv !is null) total += inv.getCount(material);
		}
	}
	return u16(Maths::Min(total, 65535));
}

AIBWorldState@ AIBS_ObserveWorld(const u8 team)
{
	AIBWorldState@ world = AIBWorldState();
	world.team = team;
	CBlob@ home = AIBS_TeamHomeBlob(team);
	world.home = home is null ? Vec2f_zero : home.getPosition();
	CBlob@ resourceHome = AIBS_TeamResourceHomeBlob(team, world.home);
	world.resourceHome = resourceHome is null ? Vec2f_zero : resourceHome.getPosition();
	CBlob@ enemyHome = AIBS_EnemyHomeBlob(team, world.home);
	world.enemyHome = enemyHome is null ? Vec2f_zero : enemyHome.getPosition();
	world.enemyDirection = world.enemyHome == Vec2f_zero || world.enemyHome.x >= world.home.x ? 1 : -1;
	world.storedWood = AIBS_CountStored(team, "mat_wood");
	world.storedStone = AIBS_CountStored(team, "mat_stone");
	CRules@ rules = getRules();
	world.planPending = rules is null ? 0 : rules.get_u16(AIBP_PlanKey(team, "pending"));
	world.planCompleted = rules is null ? 0 : rules.get_u16(AIBP_PlanKey(team, "completed"));
	world.planDamaged = rules is null ? 0 : rules.get_u16(AIBP_PlanKey(team, "damaged"));

	CBlob@[] all;
	getBlobs(@all);
	AIBS_RefreshTerrainRegion(int(world.home.x / 8.0f), 32);
	if (rules !is null)
	{
		Vec2f planAnchor = rules.get_Vec2f(AIBP_PlanKey(team, "anchor"));
		if (planAnchor != Vec2f_zero) AIBS_RefreshTerrainRegion(int(planAnchor.x), 16);
	}
	f32 friendlyFront = world.home.x;
	f32 activeThreat = 0.0f;
	u16 frontCount = 0;
	for (uint i = 0; i < all.length; i++)
	{
		CBlob@ blob = all[i];
		if (blob is null || blob.hasTag("dead")) continue;
		const bool friendly = blob.getTeamNum() == team;
		const string name = blob.getName();
		if (name == "flag" || name == "tent" || name == "hall")
		{
			if (friendly)
			{
				world.friendlyHomes.push_back(blob.getPosition());
				if (name == "flag") world.friendlyFlags++; else if (name == "tent") world.friendlyTents++; else world.friendlyHalls++;
			}
			else if (blob.getTeamNum() < 100)
			{
				world.enemyHomes.push_back(blob.getPosition());
				if (name == "flag") world.enemyFlags++; else if (name == "tent") world.enemyTents++; else world.enemyHalls++;
			}
		}
		if (!friendly && blob.getTeamNum() < 100 && (name == "bomb" || name == "keg" || name == "mine" || name == "bombarrow"))
		{
			world.enemyExplosives++;
			if ((blob.getPosition() - world.home).Length() <= 320.0f) world.explosivePressure += name == "keg" ? 2.0f : 0.75f;
		}
		if ((name == "fire" || blob.hasTag("fire source")) && (blob.getPosition() - world.home).Length() <= 240.0f) world.firePressure += 0.5f;
		if (!AIBS_IsCombatBlob(blob)) continue;
		if (friendly)
		{
			if (name == "knight") world.friendlyKnights++;
			else if (name == "archer") world.friendlyArchers++;
			else if (name == "builder") world.friendlyBuilders++;
			else if (name == "aibuilder" || name == "autobuilder")
			{
				world.aiBuilders++;
				if (name == "autobuilder") world.autoBuilders++;
				const u8 job = blob.get_u8("ai builder job");
				if (job == 0) world.aiWoodJobs++;
				else if (job == 1) world.aiStoneJobs++;
				else if (job == 2) world.aiBuildJobs++;
			}
			if (name == "knight" || name == "archer") { friendlyFront += blob.getPosition().x; frontCount++; }
		}
		else if (blob.getTeamNum() < 100)
		{
			if (name == "knight") world.enemyKnights++;
			else if (name == "archer") world.enemyArchers++;
			else if (name == "builder" || name == "aibuilder" || name == "autobuilder") world.enemyBuilders++;
			if ((blob.getPosition() - world.home).Length() <= 240.0f)
			{
				activeThreat += name == "knight" ? 1.0f : (name == "archer" ? 0.7f : 0.25f);
				AIBS_RecordPressure(team, blob.getPosition(), 0.15f);
				if (rules !is null) rules.set_f32("aib strategy recent attacks team " + int(team),
					Maths::Min(12.0f, rules.get_f32("aib strategy recent attacks team " + int(team)) + 0.1f));
			}
		}
	}
	world.frontline = Vec2f(frontCount == 0 ? world.home.x + world.enemyDirection * 160.0f : friendlyFront / float(frontCount + 1), world.home.y);
	AIBS_RefreshTerrainRegion(int(world.frontline.x / 8.0f), 32);
	world.homeLaneWidth = AIBS_LaneWidthAt(int(world.home.x / 8.0f));
	world.frontlineLaneWidth = AIBS_LaneWidthAt(int(world.frontline.x / 8.0f));
	world.frontlineWallHeight = AIBS_WallHeightAt(int(world.frontline.x / 8.0f));
	world.frontlineChokepointValue = AIBS_ChokepointValueAt(int(world.frontline.x / 8.0f));
	world.recentAttacks = rules is null ? 0.0f : rules.get_f32("aib strategy recent attacks team " + int(team));
	world.pressure = (rules is null ? 0.0f : rules.get_f32("aib strategy pressure team " + int(team))) + activeThreat + world.explosivePressure + world.firePressure + world.recentAttacks * 0.25f;
	const f32 previousFront = rules is null ? world.frontline.x : rules.get_f32("aib strategy previous frontline team " + int(team));
	world.frontlineAdvancing = previousFront == 0.0f || (world.frontline.x - previousFront) * world.enemyDirection > 8.0f;
	world.frontlineCollapsing = world.pressure >= 3.0f ||
		(world.enemyKnights + world.enemyArchers > world.friendlyKnights + world.friendlyArchers + 2) ||
		(previousFront != 0.0f && (world.frontline.x - previousFront) * world.enemyDirection < -24.0f);
	if (rules !is null) rules.set_f32("aib strategy previous frontline team " + int(team), world.frontline.x);
	return world;
}

int AIBS_FindHighGroundX(const int centerX, const int radius)
{
	int bestX = centerX;
	u16 bestY = AIBS_SurfaceAt(centerX);
	for (int x = centerX - radius; x <= centerX + radius; x++)
	{
		const u16 y = AIBS_SurfaceAt(x);
		if (y < bestY) { bestY = y; bestX = x; }
	}
	return bestX;
}

int AIBS_FindChokepointX(const int centerX, const int radius)
{
	int bestX = centerX;
	f32 bestValue = -1.0f;
	for (int x = centerX - radius; x <= centerX + radius; x++)
	{
		const f32 value = AIBS_ChokepointValueAt(x);
		if (value > bestValue) { bestValue = value; bestX = x; }
	}
	return bestX;
}

f32 AIBS_ChokepointValueAt(const int x)
{
	const int left = int(AIBS_SurfaceAt(x - 3));
	const int center = int(AIBS_SurfaceAt(x));
	const int right = int(AIBS_SurfaceAt(x + 3));
	const int wall = Maths::Max(Maths::Abs(left - center), Maths::Abs(right - center));
	const int enclosure = Maths::Abs(left - right);
	const f32 narrowness = Maths::Max(0.0f, 12.0f - float(AIBS_LaneWidthAt(x))) * 0.75f;
	return Maths::Min(20.0f, float(wall * 2 + enclosure + AIBS_WallHeightAt(x)) + narrowness);
}

void AIBS_RecordDeath(CBlob@ blob)
{
	if (blob is null || !AIBS_IsCombatBlob(blob) || blob.getTeamNum() >= 100) return;
	CRules@ rules = getRules();
	if (rules is null) return;
	const u8 team = u8(blob.getTeamNum());
	const string key = "aib strategy pressure team " + int(team);
	rules.set_f32(key, Maths::Min(10.0f, rules.get_f32(key) + 1.0f));
	AIBS_RecordPressure(team, blob.getPosition(), 1.0f);
	rules.set_u32("aib strategy important event team " + int(team), getGameTime());
}

void AIBS_RecordPressure(const u8 team, Vec2f position, const f32 amount)
{
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null) return;
	array<f32>@ heat = null;
	const string key = "aib strategy pressure heat team " + int(team);
	const uint buckets = uint(Maths::Max(1, int(map.tilemapwidth / 10)));
	if (!rules.get(key, @heat) || heat is null || heat.length != buckets)
	{
		array<f32> fresh;
		fresh.set_length(buckets);
		rules.set(key, fresh);
		rules.get(key, @heat);
	}
	if (heat is null) return;
	uint bucket = uint(Maths::Max(0, int(position.x / 80.0f)));
	if (bucket >= heat.length) bucket = heat.length - 1;
	heat[bucket] = Maths::Min(20.0f, heat[bucket] + amount);
	rules.set(key, heat);
}

f32 AIBS_PressureAt(const u8 team, Vec2f position)
{
	array<f32>@ heat = null;
	if (!getRules().get("aib strategy pressure heat team " + int(team), @heat) || heat is null || heat.length == 0) return 0.0f;
	uint bucket = uint(Maths::Max(0, int(position.x / 80.0f)));
	if (bucket >= heat.length) bucket = heat.length - 1;
	return heat[bucket];
}

void AIBS_DecayPressure(const u8 team)
{
	CRules@ rules = getRules();
	if (rules is null) return;
	const string key = "aib strategy pressure team " + int(team);
	rules.set_f32(key, Maths::Max(0.0f, rules.get_f32(key) - 0.2f));
	const string attacksKey = "aib strategy recent attacks team " + int(team);
	rules.set_f32(attacksKey, Maths::Max(0.0f, rules.get_f32(attacksKey) - 0.15f));
	array<f32>@ heat = null;
	const string heatKey = "aib strategy pressure heat team " + int(team);
	if (rules.get(heatKey, @heat) && heat !is null)
	{
		for (uint i = 0; i < heat.length; i++) heat[i] = Maths::Max(0.0f, heat[i] - 0.05f);
		rules.set(heatKey, heat);
	}
}
