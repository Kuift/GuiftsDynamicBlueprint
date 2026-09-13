// Shared low-destruction stone-route policy used by production AI and tests.

const u8 AIB_STONE_ROUTE_SHAFT_SEARCH = 12;
const f32 AIB_STONE_DIRT_PENALTY = 48.0f;

bool AIB_UsesDedicatedStoneRouteMovement(const u8 job, const u8 state)
{
	// AI builder job 1 is stone and state 10 is tunnel_to_stone. Keep this
	// dependency-free so the route policy can be exercised by AIBTest.
	return job == 1 && state == 10;
}

s32 AIB_GetDownwardPathSteerDirection(Vec2f pos, Vec2f next, Vec2f destination)
{
	// A diagonal-down BrainPath node identifies the lip that must be crossed.
	// Steering from the final destination can point across that node in the
	// opposite direction and repeatedly pull the runner away from the drop.
	// Preserve destination steering only for a nominally vertical node, where
	// the route itself supplies no lateral walk-off direction.
	const f32 nextLateral = next.x - pos.x;
	if (Maths::Abs(nextLateral) > 0.5f) return nextLateral < 0.0f ? -1 : 1;
	return destination.x < pos.x ? -1 : 1;
}

s32 AIB_SelectDownwardPathSteerDirection(Vec2f pos, Vec2f next, Vec2f destination,
	const s32 heldDirection, const bool holdActive)
{
	// A runner can cross the node x by one pixel before it has cleared the lip.
	// Keep the first chosen side for the existing bounded hold window so that
	// collision jitter cannot alternate the side probe and movement keys.
	if (holdActive && heldDirection != 0) return heldDirection;
	return AIB_GetDownwardPathSteerDirection(pos, next, destination);
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

bool AIB_HasSupportedStoneCrossTunnel(Vec2f target, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (map is null || target == Vec2f_zero || routeCorner == Vec2f_zero) return false;

	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	if (targetY < 1 || targetY >= map.tilemapheight - 1) return false;

	// The first two columns are the open shaft itself and cannot have a floor.
	// Every body cell after that must retain solid terrain below it. Treating a
	// wide cave void as a zero-dirt cross-tunnel makes the runner climb to the
	// opening, fall before reaching the ore, and repeat the same route forever.
	const int distance = Maths::Abs(targetX - shaftX);
	if (distance <= 2) return true;
	const int step = targetX < shaftX ? -1 : 1;
	for (int x = shaftX + step * 2; x != targetX; x += step)
	{
		Vec2f support = Vec2f(x * map.tilesize, (targetY + 1) * map.tilesize);
		if (!map.isTileSolid(support)) return false;
	}
	return true;
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

bool AIB_IsStoneCrossTunnelOpen(Vec2f target, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (map is null || target == Vec2f_zero || routeCorner == Vec2f_zero) return false;

	const int shaftX = Maths::Floor(routeCorner.x / map.tilesize);
	const int targetX = Maths::Floor(target.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	if (targetY < 1) return false;
	const int step = targetX < shaftX ? -1 : 1;
	for (int x = shaftX; ; x += step)
	{
		Vec2f foot = Vec2f(x * map.tilesize, targetY * map.tilesize);
		Vec2f head = foot - Vec2f(0.0f, map.tilesize);
		// The ore target itself may still be solid; every intermediate body and
		// head cell must already be open before ordinary exposed-path movement
		// is allowed to bypass the route excavator.
		if (map.isTileSolid(head) || (x != targetX && map.isTileSolid(foot))) return false;
		if (x == targetX) break;
	}
	return AIB_HasSupportedStoneCrossTunnel(target, routeCorner);
}

// A nearby underground target can invalidate the fresh-route search because
// that search deliberately requires an already-open surface approach.  Reuse
// the last measured shaft x instead, but only when the complete remaining
// two-wide shaft and two-high cross-tunnel still satisfy the normal route
// gates.  The returned corner is at the new target depth; callers must retain
// the independently measured surface-return anchor.
Vec2f AIB_GetContinuedStoneRouteCorner(CBlob@ blob, Vec2f target, Vec2f previousCorner)
{
	CMap@ map = getMap();
	if (blob is null || map is null || target == Vec2f_zero || previousCorner == Vec2f_zero)
		return Vec2f_zero;

	const int shaftX = Maths::Floor(previousCorner.x / map.tilesize);
	const int targetY = Maths::Floor(target.y / map.tilesize);
	Vec2f continuedCorner = Vec2f(shaftX * map.tilesize, targetY * map.tilesize);
	Vec2f targetCenter = AIB_RouteTileCenter(target);
	Vec2f cornerCenter = AIB_RouteTileCenter(continuedCorner);
	if (!AIB_IsStoneRouteInsideBarrier(blob, targetCenter) ||
		!AIB_IsStoneRouteInsideBarrier(blob, cornerCenter)) return Vec2f_zero;
	if (!AIB_IsStoneRouteTraversable(blob, target, continuedCorner)) return Vec2f_zero;
	// A retained underground shaft cannot move to a safer column. Reject a
	// continuation whose open cross-leg is a cave void: ordinary pathing falls
	// out of it and repeatedly climbs back to the same mouth.
	if (!AIB_HasSupportedStoneCrossTunnel(target, continuedCorner)) return Vec2f_zero;
	return continuedCorner;
}

int AIB_GetStoneRouteEntryX(const int builderX, const int shaftX, const int targetX)
{
	const int side = targetX < shaftX ? -1 : 1;
	// Vertical clearance always opens builderX and builderX+1.  Force the
	// canonical left column of the chosen two-wide shaft; accepting the other
	// column makes leftward shafts try to clear an off-route tile forever.
	return side > 0 ? shaftX : shaftX - 1;
}

bool AIB_IsStoneRouteShaftColumn(const int columnX, const int shaftX, const int targetX)
{
	const int side = targetX < shaftX ? -1 : 1;
	return columnX == shaftX || columnX == shaftX + side;
}

f32 AIB_GetStoneRouteShaftCenterX(const int shaftX, const int targetX, const f32 tileSize)
{
	if (tileSize <= 0.0f) return 0.0f;
	// A full-width runner must straddle both planned clearance columns.  The
	// canonical entry is the left column for either mirrored route, so the true
	// collision-safe centerline is its right edge rather than its tile center.
	const int entryX = AIB_GetStoneRouteEntryX(shaftX, shaftX, targetX);
	return (entryX + 1.0f) * tileSize;
}

Vec2f AIB_GetStoneReturnCornerRejoinTarget(Vec2f anchor, Vec2f routeCorner, const f32 tileSize)
{
	if (anchor == Vec2f_zero || routeCorner == Vec2f_zero || tileSize <= 0.0f) return Vec2f_zero;
	// The return anchor is the centre of the canonical left shaft tile, while the
	// saved corner is a route-tile origin. A full-width runner must rejoin on the
	// boundary between both cleared shaft columns. Steering at routeCorner.x can
	// instead walk it out through the opposite wall on mirrored routes.
	return Vec2f(anchor.x + tileSize * 0.5f, routeCorner.y);
}

bool AIB_HasEscapedStoneReturnClimbWall(Vec2f pos, Vec2f anchor, const f32 tileSize, const s32 direction)
{
	if (anchor == Vec2f_zero || tileSize <= 0.0f || direction == 0) return false;
	// The anchor is the center of the canonical left shaft tile. Its left world
	// edge is half a tile earlier and the right edge of the second tile is one
	// and a half tiles later. Once the runner center crosses the wall it selected,
	// continuing that input drives it into an adjacent pocket instead of upward.
	return direction < 0 ? pos.x < anchor.x - tileSize * 0.5f :
		pos.x > anchor.x + tileSize * 1.5f;
}

s32 AIB_SelectStoneReturnClimbDirection(const u8 wallMask, const s32 previous)
{
	const bool leftWall = (wallMask & 1) != 0;
	const bool rightWall = (wallMask & 2) != 0;
	// A prior cross-tunnel can leave a side opening above the retained corner.
	// Never invent a wall direction there: leaning into empty space ejects the
	// runner from the shaft and creates a release/recenter loop.
	if (!leftWall && !rightWall) return 0;
	if (leftWall && !rightWall) return -1;
	if (rightWall && !leftWall) return 1;
	if (previous != 0) return previous;
	return -1;
}

bool AIB_IsInsideStoneReturnShaftInfluence(Vec2f pos, Vec2f anchor, const f32 tileSize)
{
	if (anchor == Vec2f_zero || tileSize <= 0.0f) return false;
	// The anchor is the centre of the canonical left column; the physical shaft
	// centre is half a tile to its right. Allow one extra half-tile for collision
	// jitter, but do not re-arm underground return on an ordinary surface slope.
	const f32 shaftCenterX = anchor.x + tileSize * 0.5f;
	return Maths::Abs(pos.x - shaftCenterX) <= tileSize * 1.5f;
}

Vec2f AIB_SelectStoneReturnAnchor(Vec2f measured, Vec2f proven, const f32 tileSize)
{
	if (measured == Vec2f_zero || proven == Vec2f_zero || tileSize <= 0.0f) return measured;
	if (Maths::Abs(proven.x - measured.x) >= 1.0f) return measured;
	// A larger world y is a lower, more conservative handoff. Reuse it only for
	// ordinary collision-height variation; a genuinely different elevation must
	// establish its own route rather than inherit a stale underground exit.
	const f32 downwardDrift = proven.y - measured.y;
	if (downwardDrift <= 0.0f || downwardDrift > tileSize * 1.5f) return measured;
	return Vec2f(measured.x, proven.y);
}

bool AIB_HasReachedStoneReturnSurface(Vec2f pos, Vec2f anchor, const f32 tileSize)
{
	if (anchor == Vec2f_zero || tileSize <= 0.0f) return false;
	// One and a half tiles admits the first wall-climb apex below a shaft lip.
	// BrainPath can then select a node over the still-open shaft, lose height,
	// and hand control back to the return controller. Half a tile tolerates
	// collision-height variation without declaring that marginal apex surfaced.
	return pos.y <= anchor.y + tileSize * 0.5f;
}

bool AIB_IsStoneReturnEgressElevation(Vec2f candidate, Vec2f anchor, const f32 tileSize)
{
	if (candidate == Vec2f_zero || anchor == Vec2f_zero || tileSize <= 0.0f) return false;
	// Grounded-point validation alone can accept a lower ledge inside the mined
	// shaft. Walking down to that ledge drops the runner back below the return
	// re-entry band and creates a surface/return loop. Keep the handoff on the
	// measured surface: at most one tile above it and only collision-height
	// tolerance below it.
	const f32 deltaY = candidate.y - anchor.y;
	return deltaY >= -tileSize && deltaY <= tileSize * 0.5f;
}

bool AIB_IsRejectedStoneRouteTarget(Vec2f candidate, Vec2f rejected, const u32 now,
	const u32 rejectedUntil, const f32 tileSize, const u8 radiusTiles)
{
	if (candidate == Vec2f_zero || rejected == Vec2f_zero || tileSize <= 0.0f ||
		radiusTiles == 0 || rejectedUntil == 0 || now >= rejectedUntil) return false;
	return (candidate - rejected).Length() <= radiusTiles * tileSize;
}

bool AIB_HasAdvancedStoneShaftProgress(Vec2f previous, Vec2f current, Vec2f routeCorner,
	const f32 tileSize, const f32 minimumPixels)
{
	if (previous == Vec2f_zero || routeCorner == Vec2f_zero || tileSize <= 0.0f || minimumPixels <= 0.0f)
		return false;
	// Shaft progress is reduced vertical error to the cross-tunnel row.  Lateral
	// wall-bounce displacement is not progress: an unsupported cave crossing can
	// otherwise oscillate a full runner width forever and reset the watchdog on
	// every pass.
	const f32 routeCenterY = routeCorner.y + tileSize * 0.5f;
	const f32 previousError = Maths::Abs(previous.y - routeCenterY);
	const f32 currentError = Maths::Abs(current.y - routeCenterY);
	return previousError - currentError >= minimumPixels;
}

bool AIB_HasAdvancedStoneReturnProgress(Vec2f previous, Vec2f current, Vec2f anchor,
	Vec2f routeCorner, const bool cornerRejoined, const f32 tileSize, const f32 minimumPixels)
{
	if (previous == Vec2f_zero || anchor == Vec2f_zero || tileSize <= 0.0f || minimumPixels <= 0.0f)
		return false;
	// Once the runner has rejoined its two-column shaft, only upward movement
	// toward the measured surface is return progress. A wall-release/recenter
	// cycle can otherwise move a full runner width forever while resetting the
	// watchdog on every lateral pass.
	if (cornerRejoined || routeCorner == Vec2f_zero)
	{
		const f32 previousError = Maths::Max(0.0f, previous.y - anchor.y);
		const f32 currentError = Maths::Max(0.0f, current.y - anchor.y);
		return previousError - currentError >= minimumPixels;
	}

	// Before the shaft handoff, the retained cross-tunnel leg is allowed to be
	// horizontal. Measure real approach to the physical two-column rejoin point
	// instead of requiring vertical motion during that distinct phase.
	Vec2f rejoin = AIB_GetStoneReturnCornerRejoinTarget(anchor, routeCorner, tileSize);
	if (rejoin == Vec2f_zero) return false;
	return (previous - rejoin).Length() - (current - rejoin).Length() >= minimumPixels;
}

f32 AIB_GetStoneReturnOuterWallSampleX(Vec2f anchor, const f32 tileSize, const s32 direction)
{
	if (anchor == Vec2f_zero || tileSize <= 0.0f || direction == 0) return 0.0f;
	// The anchor is the center of the canonical left shaft tile. Sample the
	// centers of the immediately adjacent outer-wall tiles from that stable
	// topology, not from the runner's jittering body position. A two-pixel drift
	// can move a body-relative probe into the next tile and invent a distant wall.
	const f32 shaftCenterX = anchor.x + tileSize * 0.5f;
	return shaftCenterX + direction * tileSize * 1.5f;
}

f32 AIB_GetStoneReturnWallEngageY(Vec2f anchor, Vec2f routeCorner, const f32 tileSize)
{
	if (anchor == Vec2f_zero || routeCorner == Vec2f_zero || tileSize <= 0.0f) return 0.0f;
	// A target left of its shaft opens both the corner row and the row above it
	// through the same wall used by the canonical left-column climb. The runner
	// must clear that upper row before leaning left; otherwise the wall hold
	// simply walks it back into the cross-tunnel. Right-opening routes retain
	// the left wall and can engage at the corner elevation.
	const f32 openingClearance = routeCorner.x > anchor.x + 1.0f ? tileSize * 1.5f : 0.0f;
	return Maths::Max(routeCorner.y - openingClearance, anchor.y + tileSize * 2.0f);
}

bool AIB_CanUseFreshStoneRetarget(Vec2f pos, Vec2f returnAnchor, Vec2f retainedCorner,
	Vec2f freshCorner, const f32 tileSize)
{
	if (freshCorner == Vec2f_zero || tileSize <= 0.0f) return false;
	if (returnAnchor == Vec2f_zero || retainedCorner == Vec2f_zero) return true;
	// Near the surface the worker can physically walk to a newly selected shaft
	// and AIB_UpdateStoneReturnRoute may move the measured entry. Underground,
	// preserving the old anchor while accepting a different fresh shaft creates
	// an impossible hybrid return route. Only the retained column may deepen.
	if (pos.y <= returnAnchor.y + tileSize * 1.5f) return true;
	return Maths::Floor(freshCorner.x / tileSize) == Maths::Floor(retainedCorner.x / tileSize);
}

bool AIB_ShouldClimbToStoneReturnCorner(Vec2f pos, Vec2f routeCorner, const f32 tileSize)
{
	if (routeCorner == Vec2f_zero || tileSize <= 0.0f) return false;
	// The retained cross-tunnel is two tiles high. While the runner's centre is
	// in that band, forced up input wedges it against the ceiling and prevents
	// the intended horizontal rejoin. A displaced runner must also finish its
	// long horizontal approach before combining up with lateral shaft input.
	return pos.y > routeCorner.y + tileSize * 0.5f &&
		Maths::Abs(pos.x - routeCorner.x) <= tileSize * 1.5f;
}

bool AIB_IsStoneRouteReservedByOther(CBlob@ blob, Vec2f routeCorner)
{
	CMap@ map = getMap();
	if (blob is null || map is null || routeCorner == Vec2f_zero) return false;
	const int routeX = Maths::Floor(routeCorner.x / map.tilesize);
	CBlob@[] workers;
	getBlobsByName("aibuilder", @workers);
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ other = workers[i];
		// AI builder job 1 is stone. Route state is considered owned while its
		// saved return anchor/corner survive; normal delivery and ownership
		// cleanup clear both at the atomic episode boundary.
		if (other is null || other is blob || other.hasTag("dead") ||
			other.getTeamNum() != blob.getTeamNum() || other.get_u8("ai builder job") != 1) continue;
		Vec2f otherCorner = other.get_Vec2f("ai builder stone return corner");
		if (otherCorner == Vec2f_zero) otherCorner = other.get_Vec2f("ai builder stone route corner");
		if (otherCorner == Vec2f_zero || other.get_Vec2f("ai builder stone return anchor") == Vec2f_zero) continue;
		if (Maths::Floor(otherCorner.x / map.tilesize) == routeX) return true;
	}
	return false;
}

bool AIB_IsWithinStoneReturnReentryBand(Vec2f pos, Vec2f anchor, const f32 tileSize)
{
	if (anchor == Vec2f_zero || tileSize <= 0.0f) return false;
	// After a strict surface crossing, retain ordinary navigation across the
	// small fall/jump jitter seen at a mined shaft lip. A fall below this wider
	// band is a genuine loss of the surface and may reacquire direct return.
	return pos.y <= anchor.y + tileSize * 1.5f;
}

bool AIB_HasStoneApproachBodyClearance(CBlob@ blob, Vec2f center)
{
	CMap@ map = getMap();
	if (blob is null || map is null || center == Vec2f_zero) return false;
	if (map.isTileSolid(center)) return false;

	// A center point can pass immediately below a one-tile upper corner while a
	// 7.5-pixel runner collides with it. Sample the real head envelope so an
	// invalid adjacent cell falls back to the exact two-high mining route.
	const f32 headOffset = Maths::Max(map.tilesize * 0.5f, blob.getRadius() - 0.5f);
	return !map.isTileSolid(center - Vec2f(0.0f, headOffset));
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
