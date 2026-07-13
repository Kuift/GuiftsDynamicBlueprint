// Shared low-destruction stone-route policy used by production AI and tests.

const u8 AIB_STONE_ROUTE_SHAFT_SEARCH = 12;
const f32 AIB_STONE_DIRT_PENALTY = 48.0f;

bool AIB_UsesDedicatedStoneRouteMovement(const u8 job, const u8 state)
{
	// AI builder job 1 is stone and state 10 is tunnel_to_stone. Keep this
	// dependency-free so the route policy can be exercised by AIBTest.
	return job == 1 && state == 10;
}

Vec2f AIB_RouteTileCenter(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return tile;
	return map.getTileWorldPosition(map.getTileSpacePosition(tile)) + Vec2f(map.tilesize * 0.5f, map.tilesize * 0.5f);
}

bool AIB_IsDirtTile(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const TileType type = map.getTile(tile).type;
	return map.isTileGround(type) && !map.isTileStone(type) && !map.isTileThickStone(type) && !map.isTileGold(type);
}

bool AIB_IsMineableStoneRouteTile(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const TileType type = map.getTile(tile).type;
	return map.isTileGround(type) || map.isTileStone(type) || map.isTileThickStone(type) || map.isTileGold(type);
}

bool AIB_IsNonMineableStoneRouteBlock(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const TileType type = map.getTile(tile).type;
	return map.isTileSolid(type) && !AIB_IsMineableStoneRouteTile(tile);
}

bool AIB_IsStoneRouteTileTraversable(Vec2f tile)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const Vec2f space = map.getTileSpacePosition(tile);
	if (space.x < 1 || space.y < 1 || space.x >= map.tilemapwidth - 1 || space.y >= map.tilemapheight - 1) return false;
	if (map.getSectorAtPosition(AIB_RouteTileCenter(tile), "no build") !is null) return false;

	const TileType type = map.getTile(tile).type;
	if (map.isTileBedrock(type)) return false;
	return !map.isTileSolid(type) || AIB_IsMineableStoneRouteTile(tile);
}

bool AIB_IsStoneRouteInsideBarrier(CBlob@ blob, Vec2f position)
{
	CRules@ rules = getRules();
	if (blob is null || rules is null || !AIB_ShouldBarrier(rules)) return true;

	const u16 rawX1 = rules.get_u16("barrier_x1");
	const u16 rawX2 = rules.get_u16("barrier_x2");
	const u16 x1 = Maths::Min(rawX1, rawX2);
	const u16 x2 = Maths::Max(rawX1, rawX2);
	const s8 blobZone = blob.getPosition().x < x1 ? -1 : (blob.getPosition().x > x2 ? 1 : 0);
	const s8 routeZone = position.x < x1 ? -1 : (position.x > x2 ? 1 : 0);
	return blobZone != 0 && blobZone == routeZone;
}

// True only for the two-wide shaft and two-high cross-tunnel that remain
// between the builder and this ore target.  Generic movement clearance also
// samples the builder's current head/body cells; those are not necessarily
// part of the planned tunnel and must not invalidate an otherwise good route.
bool AIB_IsTileOnStoneRoute(CBlob@ blob, Vec2f target, Vec2f routeCorner, Vec2f tile)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero ||
		routeCorner == Vec2f_zero || tile == Vec2f_zero) return false;

	Vec2f pos = blob.getPosition();
	const int builderY = Maths::Floor(pos.y / map.tilesize);
	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	const int tileX = Maths::Floor(tile.x / map.tilesize);
	const int tileY = Maths::Floor(tile.y / map.tilesize);
	const int side = targetX < shaftX ? -1 : 1;

	const int minShaftY = Maths::Min(builderY, targetY);
	const int maxShaftY = Maths::Max(builderY, targetY);
	const bool inRemainingShaft = (tileX == shaftX || tileX == shaftX + side) &&
		tileY >= minShaftY && tileY <= maxShaftY;
	const int minCrossX = Maths::Min(shaftX, targetX);
	const int maxCrossX = Maths::Max(shaftX, targetX);
	const bool inCrossTunnel = tileX >= minCrossX && tileX <= maxCrossX &&
		(tileY == targetY || tileY == targetY - 1);
	return inRemainingShaft || inCrossTunnel;
}

u16 AIB_CountDirtOnStoneRoute(CBlob@ blob, Vec2f target, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero || routeCorner == Vec2f_zero) return 0;

	Vec2f pos = blob.getPosition();
	const int startY = Maths::Floor(pos.y / map.tilesize);
	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	const int side = targetX < shaftX ? -1 : 1;
	u16 dirt = 0;

	const int verticalStep = targetY < startY ? -1 : 1;
	for (int y = startY + verticalStep; y != targetY + verticalStep; y += verticalStep)
	{
		if (AIB_IsDirtTile(Vec2f(shaftX * map.tilesize, y * map.tilesize))) dirt++;
		if (AIB_IsDirtTile(Vec2f((shaftX + side) * map.tilesize, y * map.tilesize))) dirt++;
	}

	const int horizontalStep = targetX < shaftX ? -1 : 1;
	for (int x = shaftX + horizontalStep; x != targetX + horizontalStep; x += horizontalStep)
	{
		if (AIB_IsDirtTile(Vec2f(x * map.tilesize, targetY * map.tilesize))) dirt++;
		if (AIB_IsDirtTile(Vec2f(x * map.tilesize, (targetY - 1) * map.tilesize))) dirt++;
	}
	return dirt;
}

bool AIB_IsStoneRouteTraversable(CBlob@ blob, Vec2f target, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero || routeCorner == Vec2f_zero) return false;

	Vec2f pos = blob.getPosition();
	const int startY = Maths::Floor(pos.y / map.tilesize);
	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	const int side = targetX < shaftX ? -1 : 1;
	Vec2f entryFoot = Vec2f(shaftX * map.tilesize, startY * map.tilesize);
	Vec2f secondFoot = entryFoot + Vec2f(side * map.tilesize, 0.0f);
	if (!AIB_IsStoneRouteTileTraversable(entryFoot) ||
		!AIB_IsStoneRouteTileTraversable(entryFoot - Vec2f(0.0f, map.tilesize)) ||
		!AIB_IsStoneRouteTileTraversable(secondFoot) ||
		!AIB_IsStoneRouteTileTraversable(secondFoot - Vec2f(0.0f, map.tilesize))) return false;

	const int verticalStep = targetY < startY ? -1 : 1;
	for (int y = startY + verticalStep; y != targetY + verticalStep; y += verticalStep)
	{
		if (!AIB_IsStoneRouteTileTraversable(Vec2f(shaftX * map.tilesize, y * map.tilesize))) return false;
		if (!AIB_IsStoneRouteTileTraversable(Vec2f((shaftX + side) * map.tilesize, y * map.tilesize))) return false;
	}

	const int horizontalStep = targetX < shaftX ? -1 : 1;
	for (int x = shaftX + horizontalStep; x != targetX + horizontalStep; x += horizontalStep)
	{
		if (!AIB_IsStoneRouteTileTraversable(Vec2f(x * map.tilesize, targetY * map.tilesize))) return false;
		if (!AIB_IsStoneRouteTileTraversable(Vec2f(x * map.tilesize, (targetY - 1) * map.tilesize))) return false;
	}
	return true;
}

int AIB_GetStoneRouteEntryX(const int builderX, const int shaftX, const int targetX)
{
	const int side = targetX < shaftX ? -1 : 1;
	// Vertical clearance always opens builderX and builderX+1.  Force the
	// canonical left column of the chosen two-wide shaft; accepting the other
	// column makes leftward shafts try to clear an off-route tile forever.
	return side > 0 ? shaftX : shaftX - 1;
}

// Surface travel is ordinary movement, not mining.  A shaft is eligible only
// when the builder can walk through a genuinely open two-high corridor to its
// canonical entry.  This prevents a locally open shaft mouth behind a solid
// surface band from winning and causing endless path retries.
bool AIB_HasClearStoneRouteApproach(CBlob@ blob, Vec2f target, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero || routeCorner == Vec2f_zero) return false;

	Vec2f pos = blob.getPosition();
	const int builderX = Maths::Floor(pos.x / map.tilesize);
	const int builderY = Maths::Floor(pos.y / map.tilesize);
	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int entryX = AIB_GetStoneRouteEntryX(builderX, shaftX, targetX);
	const int step = entryX < builderX ? -1 : 1;

	for (int x = builderX; ; x += step)
	{
		Vec2f foot = Vec2f(x * map.tilesize, builderY * map.tilesize);
		Vec2f head = foot - Vec2f(0.0f, map.tilesize);
		if (!AIB_IsStoneRouteTileTraversable(foot) || !AIB_IsStoneRouteTileTraversable(head)) return false;
		if (map.isTileSolid(map.getTile(foot).type) || map.isTileSolid(map.getTile(head).type)) return false;
		if (!AIB_IsStoneRouteInsideBarrier(blob, AIB_RouteTileCenter(foot)) ||
			!AIB_IsStoneRouteInsideBarrier(blob, AIB_RouteTileCenter(head))) return false;
		if (x == entryX) break;
	}
	return true;
}

// Choose a fixed shaft once per ore target.  The bounded search discovers
// nearby caves and already-cut shafts without an expensive whole-map dig-path
// search. Dirt dominates; surface travel and cross-tunnel length break ties.
Vec2f AIB_GetBestStoneRouteCornerExcluding(CBlob@ blob, Vec2f target, Vec2f blockedTile)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero) return Vec2f_zero;

	Vec2f pos = blob.getPosition();
	const int startX = Maths::Floor(pos.x / map.tilesize);
	const int startY = Maths::Floor(pos.y / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	Vec2f best = Vec2f_zero;
	f32 bestScore = 99999999.0f;

	for (int offset = -AIB_STONE_ROUTE_SHAFT_SEARCH; offset <= AIB_STONE_ROUTE_SHAFT_SEARCH; offset++)
	{
		const int shaftX = startX + offset;
		if (shaftX < 2 || shaftX >= map.tilemapwidth - 2) continue;

		const int side = targetX < shaftX ? -1 : 1;
		Vec2f entryFoot = Vec2f(shaftX * map.tilesize, startY * map.tilesize);
		Vec2f entryHead = entryFoot - Vec2f(0.0f, map.tilesize);
		Vec2f secondFoot = entryFoot + Vec2f(side * map.tilesize, 0.0f);
		Vec2f secondHead = secondFoot - Vec2f(0.0f, map.tilesize);
		if (map.isTileSolid(entryFoot) || map.isTileSolid(entryHead) ||
			map.isTileSolid(secondFoot) || map.isTileSolid(secondHead)) continue;
		if (!AIB_IsStoneRouteInsideBarrier(blob, AIB_RouteTileCenter(entryFoot))) continue;

		Vec2f corner = Vec2f(shaftX * map.tilesize, targetY * map.tilesize);
		if (!AIB_HasClearStoneRouteApproach(blob, target, corner)) continue;
		if (blockedTile != Vec2f_zero && AIB_IsTileOnStoneRoute(blob, target, corner, blockedTile)) continue;
		if (!AIB_IsStoneRouteTraversable(blob, target, corner)) continue;
		const u16 dirt = AIB_CountDirtOnStoneRoute(blob, target, corner);
		const f32 surfaceTravel = Maths::Abs(shaftX - startX);
		const f32 crossTunnel = Maths::Abs(targetX - shaftX);
		const f32 score = dirt * 100.0f + surfaceTravel * 1.5f + crossTunnel * 0.1f;
		if (score < bestScore)
		{
			bestScore = score;
			best = corner;
		}
	}
	return best;
}

Vec2f AIB_GetBestStoneRouteCorner(CBlob@ blob, Vec2f target)
{
	return AIB_GetBestStoneRouteCornerExcluding(blob, target, Vec2f_zero);
}

bool AIB_ShouldAvoidDirtClearance(CBlob@ blob, Vec2f target, Vec2f tile)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return false;

	const TileType type = map.getTile(tile).type;
	if (!map.isTileGround(type)) return false;
	if (map.isTileStone(type) || map.isTileThickStone(type)) return false;

	Vec2f oreTarget = blob.get_Vec2f("ai builder tile target");
	if (oreTarget == Vec2f_zero) oreTarget = target;
	Vec2f routeCorner = blob.get_Vec2f("ai builder stone route corner");
	if (routeCorner == Vec2f_zero) routeCorner = AIB_GetBestStoneRouteCorner(blob, oreTarget);
	if (oreTarget == Vec2f_zero || routeCorner == Vec2f_zero) return true;

	return !AIB_IsTileOnStoneRoute(blob, oreTarget, routeCorner, tile);
}

bool AIB_CanMineStoneRouteClearance(CBlob@ blob, Vec2f target, Vec2f tile)
{
	if (!AIB_IsMineableStoneRouteTile(tile)) return false;
	return !AIB_ShouldAvoidDirtClearance(blob, target, tile);
}
