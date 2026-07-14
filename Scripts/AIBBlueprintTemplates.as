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

AIBPlanCandidate@ AIBS_GatehouseTemplate(const int anchorX, const int groundY)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::flag_gatehouse; c.templateName = "flag_gatehouse"; c.anchor = Vec2f(anchorX, groundY);
	for (int x = -3; x <= 3; x++) AIBS_AddTask(c, anchorX + x, groundY - 5, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	for (int y = 3; y <= 4; y++)
	{
		AIBS_AddTask(c, anchorX - 3, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
		AIBS_AddTask(c, anchorX + 3, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	}
	AIBS_AddTask(c, anchorX - 3, groundY - 1, AIBP_EncodeBlock(AIBP_WOOD_DOOR, 1), AIBP_Phase::access);
	AIBS_AddTask(c, anchorX + 3, groundY - 1, AIBP_EncodeBlock(AIBP_WOOD_DOOR, 1), AIBP_Phase::access);
	for (int x = -2; x <= 2; x++)
	{
		if (x != 0) AIBS_AddTask(c, anchorX + x, groundY - 3, AIBP_PLATFORM, AIBP_Phase::access);
	}
	AIBS_AddTask(c, anchorX, groundY - 2, AIBP_EncodeBlock(AIBP_LADDER, 0), AIBP_Phase::access);
	AIBS_AddTask(c, anchorX, groundY - 3, AIBP_EncodeBlock(AIBP_LADDER, 0), AIBP_Phase::access);
	AIBS_AddTask(c, anchorX, groundY - 4, AIBP_EncodeBlock(AIBP_LADDER, 0), AIBP_Phase::access);
	for (int y = 1; y <= 4; y++)
	{
		for (int x = -2; x <= 2; x++) AIBS_AddTask(c, anchorX + x, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
	}
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
	AIBS_AddTask(c, anchorX, groundY - 2, AIBP_WOOD_BACKWALL, AIBP_Phase::foundation);
	return c;
}

AIBPlanCandidate@ AIBS_FrontlineTowerTemplate(const int anchorX, const int groundY, const s8 enemyDirection = 1)
{
	AIBPlanCandidate@ c = AIBPlanCandidate();
	c.intent = AIBStrategyIntent::frontline_tower; c.templateName = "frontline_tower"; c.anchor = Vec2f(anchorX, groundY);
	for (int y = 2; y <= 7; y++)
	{
		AIBS_AddTask(c, anchorX - 2, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
		AIBS_AddTask(c, anchorX + 2, groundY - y, AIBP_STONE_BLOCK, AIBP_Phase::shell);
	}
	// Close the two entrances only after the adjacent shell is complete. KAG's
	// CollapseMissingAdjacent accepts solid foreground, not backwall support, so
	// access-phase doors fall before the later side walls can stabilize them.
	AIBS_AddTask(c, anchorX - 2, groundY - 1, AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), AIBP_Phase::closure);
	AIBS_AddTask(c, anchorX + 2, groundY - 1, AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), AIBP_Phase::closure);
	// The two corner cells already belong to the side walls. Add frontal roof
	// cover after both walls are complete, while retaining a two-tile hatch on
	// the home side. A runner is wider than one KAG tile; the old center-only
	// hatch kept DetectLadder disabled because adjacent roof blocks still made
	// the worker grounded above the ladder.
	AIBS_AddTask(c, anchorX + enemyDirection, groundY - 7, AIBP_STONE_BLOCK, AIBP_Phase::roof);
	// Four stacked ladders remain within KAG's propagated blob-support depth and
	// provide access through the two-tile openings. A fifth ladder is not stable,
	// and placing it after a center roof cell seals the worker on the wrong side.
	for (int y = 2; y <= 5; y++) AIBS_AddTask(c, anchorX, groundY - y, AIBP_LADDER, AIBP_Phase::access);
	// Keep the firing platform on the enemy side and leave the center plus home
	// side open. Two symmetric platforms made a one-tile gap and kept the runner
	// grounded, which prevents DetectLadder from ever engaging during descent.
	AIBS_AddTask(c, anchorX + enemyDirection, groundY - 4, AIBP_PLATFORM, AIBP_Phase::access);
	// Keep the original grounded foundation footprint. The old full-height
	// columns left backwalls above phase-1 platform cells after AddTask deduped the
	// overlapping cell. Phase 0 then waited for support through a phase-1 task,
	// so neither phase could advance. The lower seven cells provide the intended
	// grounded interior backing without crossing an access-phase dependency.
	for (int y = 1; y <= 3; y++)
	{
		AIBS_AddTask(c, anchorX - 1, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
		AIBS_AddTask(c, anchorX + 1, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
	}
	AIBS_AddTask(c, anchorX, groundY - 1, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);
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

s8 AIBS_AccessClimbDirection(const int anchorX, const s8 preferredDirection)
{
	const int leftSurface = int(AIBS_SurfaceAt(anchorX - 6));
	const int rightSurface = int(AIBS_SurfaceAt(anchorX + 6));
	if (leftSurface + 2 < rightSurface) return -1;
	if (rightSurface + 2 < leftSurface) return 1;
	return preferredDirection;
}

void AIBS_GenerateCandidates(AIBWorldState@ world, array<AIBPlanCandidate@> &out candidates)
{
	candidates.clear();
	if (world is null || world.home == Vec2f_zero) return;
	const int homeX = int(world.home.x / 8.0f);
	const int frontlineX = int(world.frontline.x / 8.0f);
	const int gateX = homeX + world.enemyDirection * 10;
	const int towerX = homeX + world.enemyDirection * 20;
	const int emergencyX = homeX + world.enemyDirection * 6;
	const int highX = AIBS_FindHighGroundX(towerX, 10);
	const int chokeX = AIBS_FindChokepointX(frontlineX, 12);
	const int[] gateOffsets = { 0, -3, 3 };
	for (uint i = 0; i < gateOffsets.length; i++)
	{
		const int x = gateX + world.enemyDirection * gateOffsets[i];
		candidates.push_back(AIBS_GatehouseTemplate(x, AIBS_SurfaceAt(x)));
	}
	const int[] tacticalAnchors = { chokeX, towerX, frontlineX - world.enemyDirection * 8 };
	for (uint i = 0; i < tacticalAnchors.length; i++)
	{
		const int x = tacticalAnchors[i];
		candidates.push_back(AIBS_FrontlineTowerTemplate(x, AIBS_SurfaceAt(x), world.enemyDirection));
	}
	candidates.push_back(AIBS_ArcherPerchTemplate(highX, AIBS_SurfaceAt(highX), world.enemyDirection));
	const int frontHighX = AIBS_FindHighGroundX(frontlineX - world.enemyDirection * 6, 8);
	if (frontHighX != highX) candidates.push_back(AIBS_ArcherPerchTemplate(frontHighX, AIBS_SurfaceAt(frontHighX), world.enemyDirection));
	candidates.push_back(AIBS_AccessRouteTemplate(frontlineX, AIBS_SurfaceAt(frontlineX), AIBS_AccessClimbDirection(frontlineX, world.enemyDirection)));
	candidates.push_back(AIBS_AccessRouteTemplate(chokeX, AIBS_SurfaceAt(chokeX), AIBS_AccessClimbDirection(chokeX, world.enemyDirection)));
	if (world.frontlineCollapsing)
	{
		candidates.push_back(AIBS_EmergencyBarrierTemplate(emergencyX, AIBS_SurfaceAt(emergencyX)));
		const int fallbackX = emergencyX - world.enemyDirection * 4;
		candidates.push_back(AIBS_EmergencyBarrierTemplate(fallbackX, AIBS_SurfaceAt(fallbackX)));
	}
}
