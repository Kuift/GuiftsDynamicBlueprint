#include "AIBWorldModel.as";
#include "BlueprintCatalog.as";

void AIBS_AddTask(AIBPlanCandidate@ candidate, const int x, const int y, const u16 block, const u8 phase = 255)
{
	if (candidate is null || x < 0 || y < 0) return;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ existing = candidate.tasks[i];
		if (existing !is null && existing.x == x && existing.y == y) return;
	}
	candidate.tasks.push_back(BlueprintTask(u16(x), u16(y), block, phase == 255 ? AIBP_BlockPhase(block) : phase));
}

u16 AIBS_GatehouseGroundAt(const int anchorX)
{
	// Place the access floor at the highest surface across the shell plus one
	// landing tile on each side.  Using only the center surface leaves either
	// door unsupported on ordinary uneven CTF terrain.
	u16 ground = AIBS_SurfaceAt(anchorX - 4);
	for (int x = anchorX - 3; x <= anchorX + 4; x++) ground = Maths::Min(ground, AIBS_SurfaceAt(x));
	return ground;
}

u16 AIBS_GatehouseDoorBlock()
{
	// The gatehouse already pays for a stone shell.  Keep its two ground-level
	// access points in the same defensive material class instead of leaving the
	// complete structure gated by the old low-health wooden doors.
	return AIBP_EncodeBlock(AIBP_STONE_DOOR, 1);
}

bool AIBS_GatehouseNeedsFoundationCell(const int x, const int y)
{
	CMap@ map = getMap();
	if (map is null || x < 0 || y < 0 || x >= map.tilemapwidth || y >= map.tilemapheight) return false;
	const Vec2f center = Vec2f(x * map.tilesize + map.tilesize * 0.5f, y * map.tilesize + map.tilesize * 0.5f);
	return !map.isTileSolid(map.getTile(center).type);
}

AIBPlanCandidate@ AIBS_GatehouseTemplate(const int anchorX, const int groundY)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::flag_gatehouse; c.templateName = "flag_gatehouse"; c.anchor = Vec2f(anchorX, groundY);
	// Existing terrain is already a legal floor.  Fill only the air cells needed
	// to make a level nine-tile foundation/approach; these tasks remain part of
	// the published production plan and may grow normal backwall dependencies.
	for (int x = -4; x <= 4; x++)
	{
		if (AIBS_GatehouseNeedsFoundationCell(anchorX + x, groundY))
			AIBS_AddTask(c, anchorX + x, groundY, AIBP_STONE_BLOCK, AIBP_Phase::foundation);
	}
	for (int x = -3; x <= 3; x++) AIBS_AddTask(c, anchorX + x, groundY - 5, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	for (int y = 3; y <= 4; y++)
	{
		AIBS_AddTask(c, anchorX - 3, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
		AIBS_AddTask(c, anchorX + 3, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	}
	AIBS_AddTask(c, anchorX - 3, groundY - 1, AIBS_GatehouseDoorBlock(), AIBP_Phase::access);
	AIBS_AddTask(c, anchorX + 3, groundY - 1, AIBS_GatehouseDoorBlock(), AIBP_Phase::access);
	for (int x = -2; x <= 2; x++)
	{
		if (x != 0) AIBS_AddTask(c, anchorX + x, groundY - 3, AIBP_PLATFORM, AIBP_Phase::access);
	}
	AIBS_AddTask(c, anchorX, groundY - 2, AIBP_EncodeBlock(AIBP_LADDER, 0), AIBP_Phase::access);
	AIBS_AddTask(c, anchorX, groundY - 3, AIBP_EncodeBlock(AIBP_LADDER, 0), AIBP_Phase::access);
	AIBS_AddTask(c, anchorX, groundY - 4, AIBP_EncodeBlock(AIBP_LADDER, 0), AIBP_Phase::access);
	for (int y = 1; y <= 4; y++)
	{
		// The y=3 row is occupied by access-phase platforms/ladders.  Backwall
		// directly above that row cannot be a foundation dependency without a
		// phase cycle on maps whose air has no pre-existing background support.
		const u8 phase = y == 4 ? AIBP_Phase::access : AIBP_Phase::foundation;
		for (int x = -2; x <= 2; x++) AIBS_AddTask(c, anchorX + x, groundY - y, AIBP_STONE_BACKWALL, phase);
	}
	return c;
}

u16 AIBS_GuideFlagRoomGroundAt(const int anchorX)
{
	u16 ground = AIBS_SurfaceAt(anchorX - 6);
	for (int x = anchorX - 5; x <= anchorX + 6; x++)
		ground = Maths::Min(ground, AIBS_SurfaceAt(x));
	return ground;
}

AIBPlanCandidate@ AIBS_GuideFlagRoomTemplate(const int anchorX, const int groundY,
	const s8 enemyDirection = 1)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::guide_flag_room;
	c.templateName = "guide_flag_room";
	c.anchor = Vec2f(anchorX, groundY);

	// Keep the flag/tent footprint open while levelling the two thick side-wall
	// landings.  Both layers of the home entrance begin at floor height.  The
	// enemy entrance is raised one tile so a passing enemy cannot open it merely
	// by running along the ground.
	for (int x = -6; x <= 6; x++)
	{
		if (Maths::Abs(x) >= 4 && AIBS_GatehouseNeedsFoundationCell(anchorX + x, groundY))
			AIBS_AddTask(c, anchorX + x, groundY, AIBP_STONE_BLOCK, AIBP_Phase::foundation);
	}
	const int homeInnerX = anchorX - enemyDirection * 4;
	const int homeOuterX = anchorX - enemyDirection * 5;
	const int enemyInnerX = anchorX + enemyDirection * 4;
	const int enemyOuterX = anchorX + enemyDirection * 5;
	const int[] homeWalls = { homeInnerX, homeOuterX };
	const int[] enemyWalls = { enemyInnerX, enemyOuterX };
	for (uint wall = 0; wall < homeWalls.length; wall++)
	{
		for (int y = 1; y <= 8; y++)
		{
			const u16 block = y <= 2 ? AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 1) : AIBP_STONE_BLOCK;
			AIBS_AddTask(c, homeWalls[wall], groundY - y, block,
				y <= 2 ? AIBP_Phase::closure : AIBP_Phase::shell);
		}
	}
	for (uint wall = 0; wall < enemyWalls.length; wall++)
	{
		for (int y = 1; y <= 8; y++)
		{
			u16 block = AIBP_STONE_BLOCK;
			u8 phase = AIBP_Phase::shell;
			if (y == 2 || y == 3)
			{
				block = AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 1);
				phase = AIBP_Phase::closure;
			}
			AIBS_AddTask(c, enemyWalls[wall], groundY - y, block, phase);
		}
	}

	// Two stone roof courses require a two-column opening through both rows: a
	// one-column shaft cannot contain the player's 2x2 tile volume. Four
	// reinforced hatch cells preserve that complete aperture. Alternating ladder
	// rungs reach it with the guide's one-empty-tile spacing.
	const int hatchOuterX = anchorX - enemyDirection * 3;
	const int hatchInnerX = anchorX - enemyDirection * 2;
	for (int y = 8; y <= 9; y++)
	{
		for (int x = -5; x <= 5; x++)
		{
			const bool hatch = anchorX + x == hatchOuterX || anchorX + x == hatchInnerX;
			const u16 block = hatch ?
				AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 0) : AIBP_STONE_BLOCK;
			AIBS_AddTask(c, anchorX + x, groundY - y, block,
				hatch ? AIBP_Phase::closure : AIBP_Phase::roof);
		}
	}
	for (int y = 1; y <= 7; y += 2)
		AIBS_AddTask(c, hatchInnerX, groundY - y, AIBP_LADDER, AIBP_Phase::access);

	// Interior stone backing connects each shell to terrain without occupying
	// the flag base's complete three-column no-build channel.  A flag-base sector
	// extends farther upward than the blob's physical footprint, so clearing only
	// the bottom three rows makes this otherwise intended first plan invalid
	// throughout warm-up. The ladder's alternating gaps are backed too.
	for (int y = 1; y <= 7; y++)
	{
		for (int x = -3; x <= 3; x++)
		{
			const int worldX = anchorX + x;
			if (Maths::Abs(x) <= 1) continue;
			if (worldX == hatchInnerX && (y & 1) == 1) continue;
			AIBS_AddTask(c, worldX, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
		}
	}
	return c;
}

u16 AIBS_ProtectedWorkshopsGroundAt(const int anchorX)
{
	// The bunker is nineteen tiles wide and has one landing cell beyond each
	// team door.  Level its floor to the highest surface across that complete
	// footprint so both 5x3 workshops receive support under every column.
	u16 ground = AIBS_SurfaceAt(anchorX - 9);
	for (int x = anchorX - 8; x <= anchorX + 9; x++) ground = Maths::Min(ground, AIBS_SurfaceAt(x));
	return ground;
}

int AIBS_ProtectedWorkshopsHomeRise(const int anchorX, const int groundY, const s8 enemyDirection,
	const int rampDistance = 10)
{
	const int rampStartX = anchorX - enemyDirection * rampDistance;
	return Maths::Max(0, int(AIBS_SurfaceAt(rampStartX)) - groundY);
}

u8 AIBS_ProtectedWorkshopsEnemyWallDepth()
{
	// A single three-block column was physically breached in 364 ticks from the
	// left and 298 from the right. A second paid castle column fits between the
	// existing wall and enemy-side workshop without narrowing the home route.
	return 2;
}

AIBPlanCandidate@ AIBS_ProtectedWorkshopsTemplate(const int anchorX, const int groundY,
	const s8 enemyDirection = 1, const bool compact = false)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::protected_workshops;
	c.templateName = compact ? "protected_workshops_compact" : "protected_workshops";
	c.anchor = Vec2f(anchorX, groundY);
	const int shopOffset = compact ? 3 : 4;
	const int wallOffset = compact ? 7 : 8;
	const int foundationRadius = wallOffset + 1;

	// The level floor and two exterior landing cells make the facility usable on
	// ordinary uneven CTF terrain. Missing cells remain normal paid production
	// tasks; the executor may generate their legal support backwalls as usual.
	for (int x = -foundationRadius; x <= foundationRadius; x++)
	{
		if (AIBS_GatehouseNeedsFoundationCell(anchorX + x, groundY))
			AIBS_AddTask(c, anchorX + x, groundY, AIBP_STONE_BLOCK, AIBP_Phase::foundation);
	}
	// The level protected deck can sit well above a sloped resource home. Build
	// a one-tile-per-column solid stair on the home side, filling each step down
	// to existing terrain so the diagonal tops remain cardinally supported. A
	// route probe must use this paid production access; a floating deck is not a
	// valid class facility merely because every blueprint task completed.
	const int homeRise = AIBS_ProtectedWorkshopsHomeRise(anchorX, groundY, enemyDirection,
		foundationRadius + 1);
	for (int step = 1; step <= homeRise; step++)
	{
		const int x = anchorX - enemyDirection * (foundationRadius + step);
		const int stepTop = groundY + step;
		const int surface = int(AIBS_SurfaceAt(x));
		for (int y = stepTop; y < surface; y++)
		{
			if (AIBS_GatehouseNeedsFoundationCell(x, y))
				AIBS_AddTask(c, x, y, AIBP_STONE_BLOCK, AIBP_Phase::foundation);
		}
	}

	const int homeShopX = anchorX - enemyDirection * shopOffset;
	const int enemyShopX = anchorX + enemyDirection * shopOffset;
	const int[] shopXs = { homeShopX, enemyShopX };
	// Back every occupied workshop cell with stone before either wooden class
	// shop is created. The anchor cell itself belongs to the workshop task; its
	// DefaultNoBuild lifecycle supplies the normal window/background there.
	for (uint shopIndex = 0; shopIndex < shopXs.length; shopIndex++)
	{
		const int shopX = shopXs[shopIndex];
		for (int y = 1; y <= 3; y++)
		{
			for (int x = -2; x <= 2; x++)
			{
				if (x == 0 && y == 2) continue;
				AIBS_AddTask(c, shopX + x, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
			}
		}
	}

	// A stone roof, a depth-bounded enemy-facing wall, and the upper cell of the
	// home entrance bound the two 5x3 workshop footprints. A two-cell reinforced
	// roof hatch and gapped interior ladder provide a genuinely independent
	// second exit without exposing a ground-level enemy door. One-cell ladder
	// openings are not runner-enterable in build 4762, hence the two door cells.
	const int hatchOuterX = anchorX - enemyDirection;
	const int hatchInnerX = anchorX;
	for (int x = -wallOffset; x <= wallOffset; x++)
	{
		const int worldX = anchorX + x;
		const bool hatch = worldX == hatchOuterX || worldX == hatchInnerX;
		AIBS_AddTask(c, worldX, groundY - 4,
			hatch ? AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 0) : AIBP_STONE_BLOCK,
			hatch ? AIBP_Phase::closure : AIBP_Phase::shell);
	}
	for (int y = 1; y <= 3; y += 2)
		AIBS_AddTask(c, hatchOuterX, groundY - y, AIBP_LADDER, AIBP_Phase::access);
	const int homeWallX = anchorX - enemyDirection * wallOffset;
	AIBS_AddTask(c, homeWallX, groundY - 3, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	for (u8 depth = 0; depth < AIBS_ProtectedWorkshopsEnemyWallDepth(); depth++)
	{
		const int enemyWallX = anchorX + enemyDirection * (wallOffset - depth);
		for (int y = 1; y <= 3; y++)
			AIBS_AddTask(c, enemyWallX, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	}

	AIBS_AddTask(c, homeShopX, groundY - 2, AIBP_KNIGHT_SHOP, AIBP_Phase::shell);
	AIBS_AddTask(c, enemyShopX, groundY - 2, AIBP_ARCHER_SHOP, AIBP_Phase::shell);
	AIBS_AddTask(c, homeWallX, groundY - 1,
		AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 1), AIBP_Phase::closure);
	AIBS_AddTask(c, homeWallX, groundY - 2,
		AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 1), AIBP_Phase::closure);
	return c;
}

AIBPlanCandidate@ AIBS_EmergencyBarrierTemplate(const int anchorX, const int groundY)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::emergency_barrier; c.templateName = "emergency_barrier"; c.anchor = Vec2f(anchorX, groundY);
	for (int y = 2; y <= 3; y++)
	{
		AIBS_AddTask(c, anchorX - 1, groundY - y, AIBP_WOOD_BLOCK, AIBP_Phase::shell);
		AIBS_AddTask(c, anchorX + 1, groundY - y, AIBP_WOOD_BLOCK, AIBP_Phase::shell);
	}
	AIBS_AddTask(c, anchorX - 1, groundY - 1, AIBP_EncodeBlock(AIBP_WOOD_DOOR, 1), AIBP_Phase::access);
	AIBS_AddTask(c, anchorX + 1, groundY - 1, AIBP_EncodeBlock(AIBP_WOOD_DOOR, 1), AIBP_Phase::access);
	AIBS_AddTask(c, anchorX, groundY - 3, AIBP_PLATFORM, AIBP_Phase::access);
	// Keep the upper platform support connected to terrain on maps without
	// pre-existing background.  A single backwall at ground-2 floats one cell
	// above the surface and makes the entire emergency candidate unsupported.
	AIBS_AddTask(c, anchorX, groundY - 1, AIBP_WOOD_BACKWALL, AIBP_Phase::foundation);
	AIBS_AddTask(c, anchorX, groundY - 2, AIBP_WOOD_BACKWALL, AIBP_Phase::foundation);
	return c;
}

AIBPlanCandidate@ AIBS_FrontlineTowerTemplate(const int anchorX, const int groundY, const s8 enemyDirection = 1)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::frontline_tower; c.templateName = "frontline_tower"; c.anchor = Vec2f(anchorX, groundY);
	for (int x = -3; x <= 3; x++)
	{
		if (AIBS_GatehouseNeedsFoundationCell(anchorX + x, groundY))
			AIBS_AddTask(c, anchorX + x, groundY, AIBP_STONE_BLOCK, AIBP_Phase::foundation);
	}

	// Three complete foreground layers form the front wall. The lower two rows
	// are exactly six door cells: five stone-backed wooden doors and one stone
	// door. Above them the enemy and home faces stay stone, while the middle
	// wooden layer receives a stone firebreak every fourth course.
	for (int layer = -1; layer <= 1; layer++)
	{
		const int x = anchorX + enemyDirection * layer;
		for (int y = 1; y <= 10; y++)
		{
			if (y <= 2)
			{
				const bool singleStoneDoor = layer == 1 && y == 1;
				const u16 door = singleStoneDoor ? AIBP_EncodeBlock(AIBP_STONE_DOOR, 1) :
					AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 1);
				AIBS_AddTask(c, x, groundY - y, door, AIBP_Phase::closure);
			}
			else
			{
				const bool stoneFace = layer != 0;
				const bool firebreak = y % 4 == 0;
				AIBS_AddTask(c, x, groundY - y,
					(stoneFace || firebreak) ? AIBP_STONE_BLOCK : AIBP_WOOD_BLOCK,
					AIBP_Phase::shell);
			}
		}
	}

	const int ladderX = anchorX - enemyDirection * 2;
	for (int y = 1; y <= 9; y += 2)
		AIBS_AddTask(c, ladderX, groundY - y, AIBP_LADDER, AIBP_Phase::access);
	for (int y = 2; y <= 10; y += 2)
		AIBS_AddTask(c, ladderX, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
	// A second continuous home-side spine gives the three-layer foreground a
	// redundant terrain connection.  The ladder column alone alternates between
	// rungs and backwall and therefore is not collapse backing by itself.
	const int backingX = anchorX - enemyDirection * 3;
	for (int y = 1; y <= 10; y++)
		AIBS_AddTask(c, backingX, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
	for (int offset = -2; offset <= 2; offset++)
		AIBS_AddTask(c, anchorX + enemyDirection * offset, groundY - 11,
			AIBP_EncodeBlock(AIBP_REINFORCED_PLATFORM, 0), AIBP_Phase::roof);
	return c;
}

AIBPlanCandidate@ AIBS_ArcherPerchTemplate(const int anchorX, const int groundY, const s8 enemyDirection = 1)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::archer_perch; c.templateName = "archer_perch"; c.anchor = Vec2f(anchorX, groundY);
	for (int y = 1; y <= 4; y++) AIBS_AddTask(c, anchorX, groundY - y, AIBP_LADDER, AIBP_Phase::access);
	for (int x = -2; x <= 2; x++) AIBS_AddTask(c, anchorX + x, groundY - 5, AIBP_PLATFORM, AIBP_Phase::access);
	// Rear cover protects the archer without blocking the outward firing lane.
	AIBS_AddTask(c, anchorX - enemyDirection * 2, groundY - 6, AIBP_WOOD_BLOCK, AIBP_Phase::shell);
	for (int y = 1; y <= 4; y++)
	{
		AIBS_AddTask(c, anchorX - 1, groundY - y, AIBP_WOOD_BACKWALL, AIBP_Phase::foundation);
		AIBS_AddTask(c, anchorX + 1, groundY - y, AIBP_WOOD_BACKWALL, AIBP_Phase::foundation);
	}
	return c;
}

AIBPlanCandidate@ AIBS_AccessRouteTemplate(const int anchorX, const int groundY, const s8 direction)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::access_route; c.templateName = "access_route"; c.anchor = Vec2f(anchorX, groundY);
	for (int i = 0; i < 6; i++)
	{
		AIBS_AddTask(c, anchorX + direction * i, groundY - i - 1, AIBP_EncodeBlock(AIBP_LADDER, i % 2), AIBP_Phase::access);
	}
	return c;
}

u16 AIBS_GuideServiceGroundAt(const int anchorX, const int radius)
{
	u16 ground = AIBS_SurfaceAt(anchorX - radius);
	for (int x = anchorX - radius + 1; x <= anchorX + radius; x++)
		ground = Maths::Min(ground, AIBS_SurfaceAt(x));
	return ground;
}

AIBPlanCandidate@ AIBS_GuideHomeTunnelTemplate(const int anchorX, const int groundY,
	const s8 enemyDirection = 1)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::guide_home_tunnel;
	c.templateName = "guide_home_tunnel";
	c.anchor = Vec2f(anchorX, groundY);
	for (int x = -4; x <= 4; x++)
	{
		if (AIBS_GatehouseNeedsFoundationCell(anchorX + x, groundY))
			AIBS_AddTask(c, anchorX + x, groundY, AIBP_STONE_BLOCK, AIBP_Phase::foundation);
	}
	for (int y = 1; y <= 4; y++)
	{
		for (int x = -2; x <= 2; x++)
		{
			if (x == 0 && y == 2) continue;
			AIBS_AddTask(c, anchorX + x, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
		}
	}
	for (int x = -3; x <= 3; x++)
		AIBS_AddTask(c, anchorX + x, groundY - 5, AIBP_STONE_BLOCK, AIBP_Phase::roof);
	const int homeWallX = anchorX - enemyDirection * 3;
	const int enemyWallX = anchorX + enemyDirection * 3;
	for (int y = 1; y <= 4; y++)
	{
		const u16 homeBlock = y <= 2 ? AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 1) : AIBP_STONE_BLOCK;
		AIBS_AddTask(c, homeWallX, groundY - y, homeBlock,
			y <= 2 ? AIBP_Phase::closure : AIBP_Phase::shell);
		AIBS_AddTask(c, enemyWallX, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	}
	AIBS_AddTask(c, anchorX, groundY - 2, AIBP_TUNNEL, AIBP_Phase::shell);
	return c;
}

AIBPlanCandidate@ AIBS_GuideFrontTunnelTemplate(const int anchorX, const int groundY,
	const s8 enemyDirection = 1)
{
	// Both ends of the tunnel network use the same paid, stone-backed station
	// geometry.  Keep a distinct intent/template so the director can prove that
	// the home station completed before it offers the frontline station and so
	// plan history cannot mistake two tunnel blobs for one repeated home plan.
	AIBPlanCandidate@ c = AIBS_GuideHomeTunnelTemplate(anchorX, groundY, enemyDirection);
	c.intent = AIBStrategyIntent::guide_front_tunnel;
	c.templateName = "guide_front_tunnel";
	return c;
}

AIBPlanCandidate@ AIBS_GuideQuarryStorageTemplate(const int anchorX, const int groundY,
	const s8 enemyDirection = 1)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::guide_quarry_storage;
	c.templateName = "guide_quarry_storage";
	c.anchor = Vec2f(anchorX, groundY);
	for (int x = -4; x <= 4; x++)
	{
		if (AIBS_GatehouseNeedsFoundationCell(anchorX + x, groundY))
			AIBS_AddTask(c, anchorX + x, groundY, AIBP_STONE_BLOCK, AIBP_Phase::foundation);
	}

	// Storage occupies ground-3..ground-1. The Quarry occupies
	// ground-7..ground-5, leaving ground-4 as the visible one-tile gap. A
	// continuous stone-back column supports the upper workshop without a solid
	// floor that would intercept ore falling from x-1 into Storage.
	for (int y = 1; y <= 8; y++)
	{
		for (int x = -2; x <= 2; x++)
		{
			if (x == 0 && (y == 2 || y == 6)) continue;
			AIBS_AddTask(c, anchorX + x, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
		}
	}
	const int homeWallX = anchorX - enemyDirection * 3;
	const int enemyWallX = anchorX + enemyDirection * 3;
	for (int y = 1; y <= 8; y++)
	{
		const u16 homeBlock = y <= 2 ? AIBP_EncodeBlock(AIBP_REINFORCED_WOOD_DOOR, 1) : AIBP_STONE_BLOCK;
		AIBS_AddTask(c, homeWallX, groundY - y, homeBlock,
			y <= 2 ? AIBP_Phase::closure : AIBP_Phase::shell);
		AIBS_AddTask(c, enemyWallX, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	}
	for (int x = -3; x <= 3; x++)
		AIBS_AddTask(c, anchorX + x, groundY - 9, AIBP_STONE_BLOCK, AIBP_Phase::roof);
	AIBS_AddTask(c, anchorX, groundY - 2, AIBP_STORAGE, AIBP_Phase::shell);
	AIBS_AddTask(c, anchorX, groundY - 6, AIBP_QUARRY, AIBP_Phase::roof);
	return c;
}

s8 AIBS_AccessClimbDirection(const int anchorX, const s8 preferredDirection)
{
	const int leftSurface = int(AIBS_SurfaceAt(anchorX - 6));
	const int rightSurface = int(AIBS_SurfaceAt(anchorX + 6));
	if (leftSurface + 2 < rightSurface) return -1;
	if (rightSurface + 2 < leftSurface) return 1;
	return preferredDirection;
}

bool AIBS_PrefabAnchorFitsBounds(const int anchorX, const int groundY,
	const int leftExtent, const int rightExtent, const int height)
{
	CMap@ map = getMap();
	return map !is null && anchorX - leftExtent >= 0 &&
		anchorX + rightExtent < int(map.tilemapwidth) && groundY - height >= 0 &&
		groundY < int(map.tilemapheight);
}

void AIBS_GenerateCandidates(AIBWorldState@ world, array<AIBPlanCandidate@> &out candidates,
	const bool includeLegacy = false)
{
	candidates.clear();
	if (world is null || world.home == Vec2f_zero) return;
	const int homeX = int(world.home.x / 8.0f);
	const int resourceX = world.resourceHome == Vec2f_zero ? homeX : int(world.resourceHome.x / 8.0f);
	Vec2f resourcePosition = world.resourceHome == Vec2f_zero ? world.home : world.resourceHome;
	const u16 resourceGroundY = AIBS_GroundBelowPosition(resourcePosition);
	const int frontlineX = int(world.frontline.x / 8.0f);
	const int gateX = homeX + world.enemyDirection * 10;
	const int towerX = homeX + world.enemyDirection * 20;
	const int emergencyX = homeX + world.enemyDirection * 6;
	const int chokeX = AIBS_FindChokepointX(frontlineX, 12);
	CRules@ rules = getRules();
	const bool homeCoreComplete = AIBS_GuideStageComplete(rules, world.team, AIBGuideStage::home_core);
	const bool frontlineTowerComplete = AIBS_GuideStageComplete(rules, world.team, AIBGuideStage::frontline_tower);
	const bool protectedShopsComplete = AIBS_GuideStageComplete(rules, world.team, AIBGuideStage::protected_shops);
	const bool homeTunnelComplete = AIBS_GuideStageComplete(rules, world.team, AIBGuideStage::home_tunnel);
	const bool frontTunnelComplete = AIBS_GuideStageComplete(rules, world.team, AIBGuideStage::front_tunnel);
	const bool quarryStorageComplete = AIBS_GuideStageComplete(rules, world.team, AIBGuideStage::quarry_storage);

	if (!homeCoreComplete && world.friendlyFlags > 0)
		candidates.push_back(AIBS_GuideFlagRoomTemplate(homeX, AIBS_GuideFlagRoomGroundAt(homeX), world.enemyDirection));

	if (includeLegacy)
	{
		// Retain legacy generation only for explicitly named historical fixtures
		// and benchmarks. Production never mixes these old assumptions back into
		// the Chapter 1 curriculum.
		const int[] gateOffsets = { 0, -3, 3, 6, 9, 12 };
		for (uint i = 0; i < gateOffsets.length; i++)
		{
			const int x = gateX + world.enemyDirection * gateOffsets[i];
			candidates.push_back(AIBS_GatehouseTemplate(x, AIBS_GatehouseGroundAt(x)));
		}
	}

	int[] tacticalAnchors = { chokeX, towerX, frontlineX - world.enemyDirection * 8 };
	// Real CTF terrain can make all three semantic samples fail for unrelated
	// reasons (occupied choke, unreachable tower, protected/no-build fallback).
	// Search a small neighborhood around the intended tower rather than leaving
	// an otherwise healthy team with no plan. Validation and scoring still own
	// the final safety and quality decision.
	const int[] towerFallbackOffsets = { -4, 4, 8, 12, 16 };
	for (uint i = 0; i < towerFallbackOffsets.length; i++)
	{
		const int fallback = towerX + world.enemyDirection * towerFallbackOffsets[i];
		bool duplicate = false;
		for (uint j = 0; j < tacticalAnchors.length; j++)
		{
			if (tacticalAnchors[j] == fallback) { duplicate = true; break; }
		}
		if (!duplicate) tacticalAnchors.push_back(fallback);
	}
	if (!frontlineTowerComplete) for (uint i = 0; i < tacticalAnchors.length; i++)
	{
		const int x = tacticalAnchors[i];
		candidates.push_back(AIBS_FrontlineTowerTemplate(x, AIBS_SurfaceAt(x), world.enemyDirection));
	}
	if (!protectedShopsComplete)
	{
		// Keep every base-workshop option on the resource home's actual floor. An
		// overhead shelf is not a base level, even when it is the first walkable
		// surface in a top-down terrain scan. Rings on both sides ensure that one
		// occupied/no-build footprint cannot make the whole guide stage disappear.
		const int[] protectedOffsets = { -18, 18, -32, 32, -46, 46 };
		for (uint i = 0; i < protectedOffsets.length; i++)
		{
			const int protectedX = resourceX + world.enemyDirection * protectedOffsets[i];
			if (AIBS_PrefabAnchorFitsBounds(protectedX, resourceGroundY, 9, 9, 4))
				candidates.push_back(AIBS_ProtectedWorkshopsTemplate(protectedX,
					resourceGroundY, world.enemyDirection));
		}
		// Tight official bases can leave less than nineteen buildable cells between
		// the tent and flag sectors. This fifteen-cell shell moves the two 5x3 shops
		// one tile inward while retaining the two-cell home door and 2x2 roof hatch.
		const int[] compactOffsets = { -32, 32 };
		for (uint i = 0; i < compactOffsets.length; i++)
		{
			const int protectedX = resourceX + world.enemyDirection * compactOffsets[i];
			if (AIBS_PrefabAnchorFitsBounds(protectedX, resourceGroundY, 8, 8, 4))
				candidates.push_back(AIBS_ProtectedWorkshopsTemplate(protectedX,
					resourceGroundY, world.enemyDirection, true));
		}
	}
	// Publish honest mixed-material work before its gold is already in storage.
	// This keeps the director active during warm-up and gives stone miners a live
	// gold demand to satisfy instead of withholding the plan that would request it.
	if (!homeTunnelComplete)
	{
		const int[] homeTunnelOffsets = { 14, -14, 34, -34, 50, -50 };
		for (uint i = 0; i < homeTunnelOffsets.length; i++)
		{
			const int tunnelX = resourceX + world.enemyDirection * homeTunnelOffsets[i];
			if (AIBS_PrefabAnchorFitsBounds(tunnelX, resourceGroundY, 4, 4, 5))
				candidates.push_back(AIBS_GuideHomeTunnelTemplate(tunnelX,
					resourceGroundY, world.enemyDirection));
		}
	}
	if (!frontTunnelComplete)
	{
		const int tunnelX = towerX + world.enemyDirection * 10;
		candidates.push_back(AIBS_GuideFrontTunnelTemplate(tunnelX,
			AIBS_GuideServiceGroundAt(tunnelX, 4), world.enemyDirection));
	}
	// KAG permits one quarry per team.  Account for a human-built quarry too;
	// offering another blueprint would strand its mixed-material reservation.
	if (!quarryStorageComplete && world.friendlyQuarries == 0)
	{
		const int[] quarryOffsets = { -26, 26, -46, 46, -62, 62 };
		for (uint i = 0; i < quarryOffsets.length; i++)
		{
			const int quarryX = resourceX + world.enemyDirection * quarryOffsets[i];
			if (AIBS_PrefabAnchorFitsBounds(quarryX, resourceGroundY, 4, 4, 9))
				candidates.push_back(AIBS_GuideQuarryStorageTemplate(quarryX,
					resourceGroundY, world.enemyDirection));
		}
	}
	if (includeLegacy)
	{
		const int highX = AIBS_FindHighGroundX(towerX, 10);
		candidates.push_back(AIBS_ArcherPerchTemplate(highX, AIBS_SurfaceAt(highX), world.enemyDirection));
		const int frontHighX = AIBS_FindHighGroundX(frontlineX - world.enemyDirection * 6, 8);
		if (frontHighX != highX) candidates.push_back(AIBS_ArcherPerchTemplate(frontHighX, AIBS_SurfaceAt(frontHighX), world.enemyDirection));
		candidates.push_back(AIBS_AccessRouteTemplate(frontlineX, AIBS_SurfaceAt(frontlineX), AIBS_AccessClimbDirection(frontlineX, world.enemyDirection)));
		candidates.push_back(AIBS_AccessRouteTemplate(chokeX, AIBS_SurfaceAt(chokeX), AIBS_AccessClimbDirection(chokeX, world.enemyDirection)));
	}
	if (world.frontlineCollapsing)
	{
		candidates.push_back(AIBS_EmergencyBarrierTemplate(emergencyX, AIBS_SurfaceAt(emergencyX)));
		const int fallbackX = emergencyX - world.enemyDirection * 4;
		candidates.push_back(AIBS_EmergencyBarrierTemplate(fallbackX, AIBS_SurfaceAt(fallbackX)));
	}
}
