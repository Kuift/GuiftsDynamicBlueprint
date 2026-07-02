#include "AIBBlueprintTemplates.as";
#include "BlueprintData.as";
#include "AIBBarrierCommon.as";

u16 AIBS_CandidateBlockAt(AIBPlanCandidate@ candidate, const int x, const int y)
{
	if (candidate is null || x < 0 || y < 0) return 0;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task !is null && task.x == x && task.y == y) return task.block;
	}
	return 0;
}

bool AIBS_CandidateSolidAt(AIBPlanCandidate@ candidate, const int x, const int y)
{
	return AIBP_IsSolidTileBlock(AIBS_CandidateBlockAt(candidate, x, y));
}

bool AIBS_CandidateLadderAt(AIBPlanCandidate@ candidate, const int x, const int y)
{
	return AIBP_BlockId(AIBS_CandidateBlockAt(candidate, x, y)) == AIBP_LADDER;
}

bool AIBS_CandidatePlatformAt(AIBPlanCandidate@ candidate, const int x, const int y)
{
	return AIBP_BlockId(AIBS_CandidateBlockAt(candidate, x, y)) == AIBP_PLATFORM;
}

bool AIBS_CandidateSupportBlock(const u16 block)
{
	const u16 id = AIBP_BlockId(block);
	return AIBP_IsTileBlock(block) || id == AIBP_PLATFORM || id == AIBP_LADDER ||
		id == AIBP_STONE_BACKWALL || id == AIBP_WOOD_BACKWALL || id == 64 || id == 205;
}

bool AIBS_CandidateBackwallBlock(const u16 block)
{
	const u16 id = AIBP_BlockId(block);
	return id == AIBP_STONE_BACKWALL || id == AIBP_WOOD_BACKWALL || id == 64 || id == 205;
}

bool AIBS_MapOrCandidateSolid(AIBPlanCandidate@ candidate, const int x, const int y)
{
	CMap@ map = getMap();
	if (map is null || x < 0 || y < 0 || x >= map.tilemapwidth || y >= map.tilemapheight) return true;
	if (AIBS_CandidateSolidAt(candidate, x, y)) return true;
	return map.isTileSolid(map.getTile(Vec2f(x * map.tilesize + 4, y * map.tilesize + 4)).type);
}

bool AIBS_RouteCellClear(AIBPlanCandidate@ candidate, const int x, const int y)
{
	CMap@ map = getMap();
	if (map is null || x < 0 || y < 1 || x >= map.tilemapwidth || y >= map.tilemapheight) return false;
	return !AIBS_MapOrCandidateSolid(candidate, x, y) && !AIBS_MapOrCandidateSolid(candidate, x, y - 1);
}

bool AIBS_RouteCellSupported(AIBPlanCandidate@ candidate, const int x, const int y)
{
	return AIBS_MapOrCandidateSolid(candidate, x, y + 1) || AIBS_CandidatePlatformAt(candidate, x, y + 1) ||
		AIBS_CandidatePlatformAt(candidate, x, y) || AIBS_CandidateLadderAt(candidate, x, y) ||
		AIBS_CandidateLadderAt(candidate, x, y + 1) || AIBS_CandidateLadderAt(candidate, x - 1, y) ||
		AIBS_CandidateLadderAt(candidate, x + 1, y) ||
		(!AIBS_CandidateSolidAt(candidate, x, y) && AIBS_CandidateSupportBlock(AIBS_CandidateBlockAt(candidate, x, y))) ||
		(!AIBS_CandidateSolidAt(candidate, x, y + 1) && AIBS_CandidateSupportBlock(AIBS_CandidateBlockAt(candidate, x, y + 1)));
}

bool AIBS_TaskHasApproach(AIBPlanCandidate@ candidate, BlueprintTask@ task)
{
	if (task is null) return false;
	CMap@ map = getMap();
	if (map is null) return false;
	const int[] dx = { -1, 1, 0, 0, -1, 1, -1, 1 };
	const int[] dy = { 0, 0, -1, 1, -1, -1, 1, 1 };
	for (uint i = 0; i < dx.length; i++)
	{
		const int x = int(task.x) + dx[i];
		const int y = int(task.y) + dy[i];
		if (AIBS_RouteCellClear(candidate, x, y)) return true;
	}
	return false;
}

bool AIBS_TaskTouchesSupportedPlan(AIBPlanCandidate@ candidate, const uint taskIndex, array<bool> &supported)
{
	if (candidate is null || taskIndex >= candidate.tasks.length) return false;
	BlueprintTask@ task = candidate.tasks[taskIndex];
	if (task is null) return false;
	for (uint i = 0; i < candidate.tasks.length && i < supported.length; i++)
	{
		if (!supported[i] || i == taskIndex) continue;
		BlueprintTask@ other = candidate.tasks[i];
		if (other is null || !AIBS_CandidateSupportBlock(other.block)) continue;
		if (other.phase > task.phase && !AIBS_CandidateBackwallBlock(task.block)) continue;
		if (Maths::Abs(int(other.x) - int(task.x)) + Maths::Abs(int(other.y) - int(task.y)) == 1) return true;
	}
	return false;
}

bool AIBS_MapProvidesImmediateSupport(Vec2f center)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const f32 ts = map.tilesize;
	Vec2f[] points = { center, center + Vec2f(0, ts), center - Vec2f(0, ts), center + Vec2f(ts, 0), center - Vec2f(ts, 0) };
	for (uint i = 0; i < points.length; i++)
	{
		const TileType type = map.getTile(points[i]).type;
		if (map.isTileGrass(type)) continue;
		if (map.isTileSolid(type)) return true;
		if ((type >= CMap::tile_castle_back && type <= 79) || type == CMap::tile_castle_back_moss ||
			(type >= CMap::tile_wood_back && type <= 207)) return true;
	}
	return false;
}

bool AIBS_CandidateHasDependencySupport(AIBPlanCandidate@ candidate)
{
	if (candidate is null || candidate.tasks.length == 0) return false;
	CMap@ map = getMap();
	if (map is null) return false;
	array<bool> supported(candidate.tasks.length, false);
	uint supportedCount = 0;
	bool progress = true;
	while (progress)
	{
		progress = false;
		for (uint i = 0; i < candidate.tasks.length; i++)
		{
			if (supported[i]) continue;
			BlueprintTask@ task = candidate.tasks[i];
			if (task is null) return false;
			Vec2f center = Vec2f(task.x * map.tilesize + 4, task.y * map.tilesize + 4);
			if (AIBP_MapMatchesBlock(task.x, task.y, task.block) || map.hasSupportAtPos(center) || AIBS_MapProvidesImmediateSupport(center) ||
				AIBS_TaskTouchesSupportedPlan(candidate, i, supported))
			{
				supported[i] = true;
				supportedCount++;
				progress = true;
			}
		}
	}
	return supportedCount == candidate.tasks.length;
}

bool AIBS_InsideBarrierSide(AIBWorldState@ world, Vec2f position)
{
	CRules@ rules = getRules();
	if (rules is null || !AIB_ShouldBarrier(rules)) return true;
	const f32 x1 = rules.get_u16("barrier_x1");
	const f32 x2 = rules.get_u16("barrier_x2");
	const f32 left = Maths::Min(x1, x2);
	const f32 right = Maths::Max(x1, x2);
	if (position.x >= left && position.x <= right) return false;
	if (world is null) return false;
	return (world.home.x < left && position.x < left) || (world.home.x > right && position.x > right);
}

bool AIBS_OverlapsProtectedBlob(const u8 team, Vec2f center)
{
	CMap@ map = getMap();
	if (map is null) return true;
	CBlob@[] nearby;
	if (!map.getBlobsInRadius(center, 20.0f, @nearby)) return false;
	for (uint i = 0; i < nearby.length; i++)
	{
		CBlob@ blob = nearby[i];
		if (blob is null || blob.hasTag("dead")) continue;
		if (blob.hasTag("aibuilder blueprint structure") && blob.getTeamNum() == team) continue;
		const string name = blob.getName();
		const f32 distance = (blob.getPosition() - center).Length();
		if (name == "flag" || name == "tent" || name == "hall" || name == "buildershop" || name == "crate" || blob.hasTag("building")) return true;
		if (distance <= 8.0f && (blob.hasTag("vehicle") || blob.hasTag("door") || name == "wooden_platform" || name == "ladder")) return true;
	}
	return false;
}

void AIBS_CandidateCosts(AIBPlanCandidate@ candidate, u32 &out wood, u32 &out stone)
{
	wood = 0; stone = 0;
	if (candidate is null) return;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null || AIBP_MapMatchesBlock(task.x, task.y, task.block)) continue;
		const string material = AIBP_BlockMaterial(task.block);
		if (material == "mat_wood") wood += AIBP_BlockCost(task.block);
		else if (material == "mat_stone") stone += AIBP_BlockCost(task.block);
	}
}

int AIBS_FriendlyRouteDistance(AIBPlanCandidate@ boundsCandidate, AIBPlanCandidate@ routeCandidate)
{
	if (boundsCandidate is null || boundsCandidate.tasks.length == 0) return -1;
	CMap@ map = getMap();
	if (map is null) return -1;
	int minX = map.tilemapwidth; int maxX = 0; int minY = map.tilemapheight; int maxY = 0;
	for (uint i = 0; i < boundsCandidate.tasks.length; i++)
	{
		BlueprintTask@ task = boundsCandidate.tasks[i];
		if (task is null) continue;
		minX = Maths::Min(minX, int(task.x)); maxX = Maths::Max(maxX, int(task.x));
		minY = Maths::Min(minY, int(task.y)); maxY = Maths::Max(maxY, int(task.y));
	}
	minX = Maths::Max(0, minX - 2); maxX = Maths::Min(int(map.tilemapwidth) - 1, maxX + 2);
	minY = Maths::Max(1, minY - 3); maxY = Maths::Min(int(map.tilemapheight) - 2, maxY + 2);
	if (minX >= maxX || minY >= maxY) return -1;
	const int width = maxX - minX + 1;
	const int height = maxY - minY + 1;
	array<bool> visited(width * height, false);
	array<int> queueX; array<int> queueY; array<int> queueDistance;
	for (int y = minY; y <= maxY; y++)
	{
		if (!AIBS_RouteCellClear(routeCandidate, minX, y) || !AIBS_RouteCellSupported(routeCandidate, minX, y)) continue;
		queueX.push_back(minX); queueY.push_back(y); queueDistance.push_back(0); visited[(y - minY) * width] = true;
	}
	uint head = 0;
	while (head < queueX.length)
	{
		const int x = queueX[head]; const int y = queueY[head]; const int distance = queueDistance[head]; head++;
		if (x == maxX) return distance;
		for (int stepX = -1; stepX <= 1; stepX += 2)
		{
			for (int stepY = -1; stepY <= 1; stepY++)
			{
				const int nx = x + stepX; const int ny = y + stepY;
				if (nx < minX || nx > maxX || ny < minY || ny > maxY) continue;
				if (!AIBS_RouteCellClear(routeCandidate, nx, ny) || !AIBS_RouteCellSupported(routeCandidate, nx, ny)) continue;
				const int index = (ny - minY) * width + (nx - minX);
				if (visited[index]) continue;
				visited[index] = true; queueX.push_back(nx); queueY.push_back(ny); queueDistance.push_back(distance + 1);
			}
		}
		if (AIBS_CandidateLadderAt(routeCandidate, x, y))
		{
			for (int stepY = -1; stepY <= 1; stepY += 2)
			{
				const int ny = y + stepY;
				if (ny < minY || ny > maxY || !AIBS_RouteCellClear(routeCandidate, x, ny)) continue;
				const int index = (ny - minY) * width + (x - minX);
				if (visited[index]) continue;
				visited[index] = true; queueX.push_back(x); queueY.push_back(ny); queueDistance.push_back(distance + 1);
			}
		}
	}
	return -1;
}

bool AIBS_PreservesFriendlyRoute(AIBPlanCandidate@ candidate)
{
	if (candidate is null || candidate.tasks.length == 0) return false;
	const int baseline = AIBS_FriendlyRouteDistance(candidate, null);
	if (baseline < 0) return true;
	if (AIBS_FriendlyRouteDistance(candidate, candidate) >= 0) return true;
	return AIBS_CandidateHasAccessPassage(candidate) && AIBS_AllTasksHaveReachableApproach(candidate);
}

f32 AIBS_FriendlyRoutePenalty(AIBPlanCandidate@ candidate)
{
	if (candidate is null || candidate.tasks.length == 0) return 0.0f;
	const int baseline = AIBS_FriendlyRouteDistance(candidate, null);
	const int planned = AIBS_FriendlyRouteDistance(candidate, candidate);
	if (baseline < 0) return planned < 0 ? 0.0f : -1.0f;
	if (planned < 0 && AIBS_CandidateHasAccessPassage(candidate) && AIBS_AllTasksHaveReachableApproach(candidate)) return 0.5f;
	if (planned < 0) return 1.0f;
	return float(planned - baseline) / float(Maths::Max(1, baseline));
}

bool AIBS_CandidateHasAccessPassage(AIBPlanCandidate@ candidate)
{
	if (candidate is null) return false;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null) continue;
		const u16 id = AIBP_BlockId(task.block);
		if (id == AIBP_LADDER || id == AIBP_PLATFORM || id == AIBP_STONE_DOOR || id == AIBP_WOOD_DOOR || id == AIBP_BRIDGE) return true;
	}
	return false;
}

u16 AIBS_SightLineLength(AIBPlanCandidate@ candidate, const s8 direction, const u16 maxTiles = 24)
{
	if (candidate is null) return 0;
	CMap@ map = getMap();
	if (map is null) return 0;
	const int startX = int(candidate.anchor.x);
	const int sightY = int(candidate.anchor.y) - 6;
	u16 clear = 0;
	for (u16 step = 1; step <= maxTiles; step++)
	{
		const int x = startX + direction * step;
		if (x < 0 || x >= map.tilemapwidth || sightY < 0 || sightY >= map.tilemapheight) break;
		if (AIBS_MapOrCandidateSolid(candidate, x, sightY)) break;
		clear++;
	}
	return clear;
}

bool AIBS_AllTasksHaveReachableApproach(AIBPlanCandidate@ candidate)
{
	if (candidate is null || candidate.tasks.length == 0) return false;
	CMap@ map = getMap();
	if (map is null) return false;
	int minX = map.tilemapwidth; int maxX = 0; int minY = map.tilemapheight; int maxY = 0;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null) continue;
		minX = Maths::Min(minX, int(task.x)); maxX = Maths::Max(maxX, int(task.x));
		minY = Maths::Min(minY, int(task.y)); maxY = Maths::Max(maxY, int(task.y));
	}
	minX = Maths::Max(0, minX - 6); maxX = Maths::Min(int(map.tilemapwidth) - 1, maxX + 6);
	minY = Maths::Max(1, minY - 4); maxY = Maths::Min(int(map.tilemapheight) - 2, maxY + 3);
	const int width = maxX - minX + 1;
	const int height = maxY - minY + 1;
	if (width <= 0 || height <= 0) return false;
	array<bool> visited(width * height, false);
	array<int> queueX; array<int> queueY;
	for (int y = minY; y <= maxY; y++)
	{
		if (!AIBS_RouteCellClear(candidate, minX, y) || !AIBS_RouteCellSupported(candidate, minX, y)) continue;
		queueX.push_back(minX); queueY.push_back(y); visited[(y - minY) * width] = true;
		if (maxX != minX && AIBS_RouteCellClear(candidate, maxX, y) && AIBS_RouteCellSupported(candidate, maxX, y))
		{
			queueX.push_back(maxX); queueY.push_back(y); visited[(y - minY) * width + (maxX - minX)] = true;
		}
	}
	uint head = 0;
	while (head < queueX.length)
	{
		const int x = queueX[head]; const int y = queueY[head]; head++;
		for (int stepX = -1; stepX <= 1; stepX += 2)
		{
			for (int stepY = -1; stepY <= 1; stepY++)
			{
				const int nx = x + stepX; const int ny = y + stepY;
				if (nx < minX || nx > maxX || ny < minY || ny > maxY || !AIBS_RouteCellClear(candidate, nx, ny) || !AIBS_RouteCellSupported(candidate, nx, ny)) continue;
				const int index = (ny - minY) * width + (nx - minX);
				if (visited[index]) continue;
				visited[index] = true; queueX.push_back(nx); queueY.push_back(ny);
			}
		}
		if (AIBS_CandidateLadderAt(candidate, x, y))
		{
			for (int stepY = -1; stepY <= 1; stepY += 2)
			{
				const int ny = y + stepY;
				if (ny < minY || ny > maxY || !AIBS_RouteCellClear(candidate, x, ny)) continue;
				const int index = (ny - minY) * width + (x - minX);
				if (visited[index]) continue;
				visited[index] = true; queueX.push_back(x); queueY.push_back(ny);
			}
		}
	}
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null || AIBP_MapMatchesBlock(task.x, task.y, task.block)) continue;
		bool reachable = false;
		// Builders place from up to 32 px away. Requiring an immediately adjacent
		// walkable cell incorrectly rejects roof and outer-wall tasks that are
		// reachable from the template's platform/ladder access path.
		for (int offsetY = -6; offsetY <= 6 && !reachable; offsetY++)
		{
			for (int offsetX = -6; offsetX <= 6; offsetX++)
			{
				if (offsetX * offsetX + offsetY * offsetY > 36) continue;
				if (AIBP_IsSolidTileBlock(task.block) && offsetX == 0 && offsetY == 0) continue;
				const int x = int(task.x) + offsetX; const int y = int(task.y) + offsetY;
				if (x < minX || x > maxX || y < minY || y > maxY) continue;
				if (visited[(y - minY) * width + (x - minX)]) { reachable = true; break; }
			}
		}
		if (!reachable)
		{
			return false;
		}
	}
	return true;
}

bool AIBS_ValidateCandidate(AIBWorldState@ world, AIBPlanCandidate@ candidate)
{
	if (world is null || candidate is null || candidate.tasks.length == 0) return false;
	CMap@ map = getMap();
	CRules@ rules = getRules();
	if (map is null || rules is null) return false;
	array<u16>@ human = null;
	AIBP_GetLayerGrid(world.team, AIBP_Layer::human, @human);
	uint matched = 0;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null || task.x >= map.tilemapwidth || task.y >= map.tilemapheight || task.y == 0)
		{
			candidate.rejection = "bounds"; return false;
		}
		if (!AIBP_IsCatalogBlock(task.block)) { candidate.rejection = "catalog"; return false; }
		const uint index = task.y * map.tilemapwidth + task.x;
		if (human !is null && index < human.length && human[index] != 0) { candidate.rejection = "human_plan"; return false; }
		Vec2f center = Vec2f(task.x * map.tilesize + map.tilesize * 0.5f, task.y * map.tilesize + map.tilesize * 0.5f);
		const TileType current = map.getTile(center).type;
		if (map.isTileBedrock(current)) { candidate.rejection = "bedrock"; return false; }
		if (AIBP_MapMatchesBlock(task.x, task.y, task.block)) { matched++; continue; }
		// Grass is a replaceable foreground decoration in KAG.  Treating it as
		// occupied terrain rejects otherwise valid plans before a builder ever
		// gets a chance to clear it and place the requested tile/backwall.
		if (map.isTileSolid(current) && !map.isTileGrass(current)) { candidate.rejection = "occupied_terrain"; return false; }
		if (!AIBS_InsideBarrierSide(world, center)) { candidate.rejection = "barrier"; return false; }
		if (AIBP_BlockId(task.block) != AIBP_LADDER && map.getSectorAtPosition(center, "no build") !is null) { candidate.rejection = "no_build"; return false; }
		if (AIBS_OverlapsProtectedBlob(world.team, center)) { candidate.rejection = "building_overlap"; return false; }
		if (!AIBS_TaskHasApproach(candidate, task)) { candidate.rejection = "no_approach"; return false; }
	}
	if (matched == candidate.tasks.length || matched * 4 >= candidate.tasks.length * 3) { candidate.rejection = "duplicate"; return false; }
	if (!AIBS_CandidateHasDependencySupport(candidate)) { candidate.rejection = "unsupported"; return false; }
	if (!AIBS_PreservesFriendlyRoute(candidate)) { candidate.rejection = "friendly_route"; return false; }
	if (!AIBS_AllTasksHaveReachableApproach(candidate)) { candidate.rejection = "unreachable_tasks"; return false; }
	if (candidate.intent == AIBStrategyIntent::archer_perch && AIBS_SightLineLength(candidate, world.enemyDirection) < 8)
		{ candidate.rejection = "poor_sightline"; return false; }

	u32 wood = 0; u32 stone = 0;
	AIBS_CandidateCosts(candidate, wood, stone);
	if (wood > world.storedWood + 1200 || stone > world.storedStone + 1200) { candidate.rejection = "planning_horizon"; return false; }
	return true;
}

f32 AIBS_ScoreCandidate(AIBWorldState@ world, AIBPlanCandidate@ candidate)
{
	if (world is null || candidate is null) return -999999.0f;
	u32 wood = 0; u32 stone = 0;
	AIBS_CandidateCosts(candidate, wood, stone);
	const f32 enemyPressure = world.enemyKnights * 9.0f + world.enemyArchers * 6.0f + world.pressure * 12.0f;
	f32 defensiveGain = 20.0f + enemyPressure;
	const int anchorX = int(candidate.anchor.x);
	const f32 routeGain = candidate.intent == AIBStrategyIntent::access_route ? 55.0f : 15.0f;
	const f32 measuredHeight = Maths::Max(-5.0f, Maths::Min(35.0f, (float(AIBS_SurfaceAt(int(world.home.x / 8.0f))) - candidate.anchor.y) * 4.0f));
	const f32 heightValue = (candidate.intent == AIBStrategyIntent::frontline_tower || candidate.intent == AIBStrategyIntent::archer_perch) ? measuredHeight + 15.0f : measuredHeight * 0.25f;
	const f32 chokepointValue = AIBS_ChokepointValueAt(anchorX) * 3.0f;
	const f32 sightlineValue = candidate.intent == AIBStrategyIntent::archer_perch ? float(AIBS_SightLineLength(candidate, world.enemyDirection)) * 1.5f : 0.0f;
	f32 urgency = world.frontlineCollapsing && candidate.intent == AIBStrategyIntent::emergency_barrier ? 100.0f : 0.0f;
	const f32 localPressure = AIBS_PressureAt(world.team, candidate.anchor * 8.0f);
	f32 threatFit = (candidate.intent == AIBStrategyIntent::flag_gatehouse ? world.enemyKnights * 8.0f : world.enemyArchers * 5.0f) + localPressure * 4.0f;
	CRules@ rules = getRules();
	Vec2f activeAnchor = rules is null ? Vec2f_zero : rules.get_Vec2f(AIBP_PlanKey(world.team, "anchor"));
	const f32 continuity = activeAnchor == Vec2f_zero ? 0.0f : Maths::Max(0.0f, 24.0f - (candidate.anchor - activeAnchor).Length() * 0.75f);
	const u32 lastTemplate = rules is null ? 0 : rules.get_u32("aib strategy template last " + candidate.templateName + " team " + int(world.team));
	const f32 cooldown = lastTemplate != 0 && getGameTime() < lastTemplate + 900 ? 20.0f : 0.0f;
	const f32 materialCost = wood * 0.08f + stone * 0.06f;
	const f32 travel = Maths::Abs(candidate.anchor.x * 8.0f - world.home.x) * 0.04f;
	const f32 buildTime = candidate.tasks.length * 1.2f;
	const f32 exposure = Maths::Max(0.0f, Maths::Abs(candidate.anchor.x * 8.0f - world.home.x) - 160.0f) * 0.08f + localPressure * 2.0f;
	const f32 friendlyRoutePenalty = AIBS_FriendlyRoutePenalty(candidate) * 60.0f;
	candidate.score = defensiveGain + routeGain + heightValue + chokepointValue + sightlineValue + threatFit + urgency + continuity - cooldown - materialCost - travel - buildTime - exposure - friendlyRoutePenalty;
	candidate.reasons = "defense=" + defensiveGain + " route=" + routeGain + " height=" + heightValue + " choke=" + chokepointValue + " sight=" + sightlineValue + " threat=" + threatFit + " urgency=" + urgency +
		" continuity=" + continuity + " cooldown=" + cooldown + " cost=" + materialCost + " travel=" + travel + " exposure=" + exposure + " route_penalty=" + friendlyRoutePenalty;
	return candidate.score;
}

AIBPlanCandidate@ AIBS_SelectCandidate(AIBWorldState@ world)
{
	array<AIBPlanCandidate@> candidates;
	AIBS_GenerateCandidates(world, candidates);
	array<AIBPlanCandidate@> valid;
	f32 bestScore = -999999.0f;
	for (uint i = 0; i < candidates.length; i++)
	{
		AIBPlanCandidate@ candidate = candidates[i];
		if (!AIBS_ValidateCandidate(world, candidate))
		{
			AIBS_Log("reject", world.team, "template=" + candidate.templateName + " reason=" + candidate.rejection);
			continue;
		}
		AIBS_ScoreCandidate(world, candidate);
		valid.push_back(candidate);
		if (candidate.score > bestScore) bestScore = candidate.score;
	}
	if (valid.length == 0) return null;
	array<AIBPlanCandidate@> nearBest;
	const f32 threshold = bestScore - Maths::Max(1.0f, Maths::Abs(bestScore) * 0.07f);
	for (uint i = 0; i < valid.length; i++) if (valid[i].score >= threshold) nearBest.push_back(valid[i]);
	const u16 version = getRules().get_u16(AIBP_PlanKey(world.team, "version"));
	return nearBest[(world.team * 31 + version * 17) % nearBest.length];
}

bool AIBS_ActivePlanInvalid(AIBWorldState@ world)
{
	if (world is null) return true;
	CMap@ map = getMap();
	if (map is null) return true;
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(world.team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return true;
	array<u16>@ human = null;
	AIBP_GetLayerGrid(world.team, AIBP_Layer::human, @human);
	for (uint i = 0; i < xs.length && i < ys.length && i < blocks.length && i < states.length; i++)
	{
		if (states[i] == AIBP_TaskState::completed || states[i] == AIBP_TaskState::cancelled) continue;
		if (xs[i] >= map.tilemapwidth || ys[i] >= map.tilemapheight) return true;
		const uint index = ys[i] * map.tilemapwidth + xs[i];
		if (human !is null && index < human.length && human[index] != 0) return true;
		if (AIBP_MapMatchesBlock(xs[i], ys[i], blocks[i])) continue;
		Vec2f center = Vec2f(xs[i] * map.tilesize + 4, ys[i] * map.tilesize + 4);
		const TileType current = map.getTile(center).type;
		if (map.isTileBedrock(current) || map.isTileSolid(current)) return true;
		if (!AIBS_InsideBarrierSide(world, center)) return true;
		if (AIBP_BlockId(blocks[i]) != AIBP_LADDER && map.getSectorAtPosition(center, "no build") !is null) return true;
		if (AIBS_OverlapsProtectedBlob(world.team, center)) return true;
	}
	return false;
}

bool AIBS_ShouldReplacePlan(AIBWorldState@ world, AIBPlanCandidate@ candidate)
{
	if (world is null || candidate is null) return false;
	CRules@ rules = getRules();
	if (rules is null) return false;
	const u16 planID = rules.get_u16(AIBP_PlanKey(world.team, "id"));
	if (planID == 0) return true;
	const u32 updated = rules.get_u32(AIBP_PlanKey(world.team, "updated"));
	const u8 status = rules.get_u8(AIBP_PlanKey(world.team, "status"));
	const bool emergency = world.frontlineCollapsing && candidate.intent == AIBStrategyIntent::emergency_barrier;
	if (status == 3) { rules.set_string("aib strategy replacement reason team " + int(world.team), "cancelled"); return true; }
	if (status == 2 && (emergency || getGameTime() >= updated + 300))
	{
		rules.set_string("aib strategy replacement reason team " + int(world.team), emergency ? "emergency_after_completion" : "completed");
		return true;
	}
	if (status != 1) return false;
	const u8 activeIntent = rules.get_u8(AIBP_PlanKey(world.team, "intent"));
	if (emergency && activeIntent != AIBStrategyIntent::emergency_barrier)
	{
		rules.set_string("aib strategy replacement reason team " + int(world.team), "frontline_collapse");
		return true;
	}
	if (AIBS_ActivePlanInvalid(world))
	{
		rules.set_string("aib strategy replacement reason team " + int(world.team), "invalidated");
		return true;
	}
	return false;
}

BlueprintPlan@ AIBS_MakePlan(AIBWorldState@ world, AIBPlanCandidate@ candidate)
{
	if (world is null || candidate is null) return null;
	CRules@ rules = getRules();
	BlueprintPlan@ plan = BlueprintPlan();
	plan.team = world.team;
	plan.id = rules.get_u16("aib strategy next plan id") + 1;
	rules.set_u16("aib strategy next plan id", plan.id);
	plan.version = rules.get_u16(AIBP_PlanKey(world.team, "version")) + 1;
	plan.owner = 255;
	plan.intent = candidate.intent;
	plan.status = 1;
	plan.templateName = candidate.templateName;
	plan.anchor = candidate.anchor;
	plan.score = candidate.score;
	plan.reasons = candidate.reasons;
	plan.createdAt = getGameTime(); plan.updatedAt = getGameTime();
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null) continue;
		if (AIBP_MapMatchesBlock(task.x, task.y, task.block)) task.state = AIBP_TaskState::completed;
		plan.tasks.push_back(task);
	}
	return plan;
}
