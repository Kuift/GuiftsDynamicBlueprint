#include "AIBPlacementPlanner.as";
#include "AutoBuilderCommon.as";
#include "AIBDirectorPolicy.as";
#include "AIBManualOrderCommon.as";

const u8 AIBS_JOB_WOOD = AIBM_JOB_WOOD;
const u8 AIBS_JOB_STONE = AIBM_JOB_STONE;
const u8 AIBS_JOB_BLUEPRINT = AIBM_JOB_BLUEPRINT;
const u8 AIBS_STATE_IDLE = AIBM_STATE_IDLE;
const u8 AIBS_STATE_FIND_TREE = AIBM_STATE_FIND_TREE;
const u8 AIBS_STATE_FIND_STONE = AIBM_STATE_FIND_STONE;
const u8 AIBS_STATE_COLLECT_BLUEPRINT = AIBM_STATE_COLLECT_BLUEPRINT;
const u8 AIBS_STATE_FIND_BLUEPRINT = AIBM_STATE_FIND_BLUEPRINT;
const u8 AIBS_BOOTSTRAP_MIN_HOME_DISTANCE = 6;
const u8 AIBS_BOOTSTRAP_MAX_HOME_DISTANCE = 24;
const u8 AIBS_BOOTSTRAP_VERTICAL_SEARCH = 12;
const u8 AIBS_BOOTSTRAP_HOME_SEED_RADIUS = 4;
const u32 AIBS_BOOTSTRAP_RETRY_TICKS = 10 * 30;
const u16 AIBS_COLLECTOR_LOAD = 250;

class AIBBootstrapReachability
{
	int minX;
	int maxX;
	int minY;
	int maxY;
	int width;
	bool seeded;
	array<bool> cells;

	AIBBootstrapReachability()
	{
		minX = 0; maxX = -1; minY = 0; maxY = -1; width = 0; seeded = false;
	}
}

void AIBS_InitBootstrapPolicy(CRules@ rules, const u8 team)
{
	if (rules is null) return;
	const string enabledKey = AIBS_BootstrapKey(team, "enabled");
	if (!rules.exists(enabledKey)) rules.set_bool(enabledKey, AIBS_DefaultBootstrapForGamemode(rules.gamemode_name));
	if (!rules.exists(AIBS_BootstrapKey(team, "provisioned"))) rules.set_bool(AIBS_BootstrapKey(team, "provisioned"), false);
	if (!rules.exists(AIBS_BootstrapKey(team, "next retry"))) rules.set_u32(AIBS_BootstrapKey(team, "next retry"), 0);
	rules.Sync(enabledKey, true);
	rules.Sync(AIBS_BootstrapKey(team, "provisioned"), true);
}

void AIBS_ResetBootstrapForRound(CRules@ rules, const u8 team)
{
	if (rules is null) return;
	AIBS_InitBootstrapPolicy(rules, team);
	rules.set_bool(AIBS_BootstrapKey(team, "provisioned"), false);
	rules.set_u32(AIBS_BootstrapKey(team, "next retry"), 0);
	rules.Sync(AIBS_BootstrapKey(team, "provisioned"), true);
}

void AIBS_SetBuilderResourceHome(CBlob@ builder, const u16 homeID)
{
	if (builder is null) return;
	const u16 desired = AIBU_IsAutoBuilder(builder) ? 0 : homeID;
	if (builder.get_netid(AIBR_ASSIGNED_HOME_KEY) == desired) return;
	builder.set_netid(AIBR_ASSIGNED_HOME_KEY, desired);
	builder.Sync(AIBR_ASSIGNED_HOME_KEY, true);
}

u16 AIBS_CurrentResourceHomeID(const u8 team)
{
	CBlob@ strategicHome = AIBS_TeamHomeBlob(team);
	Vec2f strategicPosition = strategicHome is null ? Vec2f_zero : strategicHome.getPosition();
	CBlob@ resourceHome = AIBS_TeamResourceHomeBlob(team, strategicPosition);
	return resourceHome is null ? 0 : resourceHome.getNetworkID();
}

u16 AIBS_WorldResourceHomeID(AIBWorldState@ world)
{
	if (world is null || world.resourceHome == Vec2f_zero) return 0;
	return world.resourceHomeID != 0 ? world.resourceHomeID : AIBS_CurrentResourceHomeID(world.team);
}

void AIBS_SetBuilderJob(CBlob@ builder, const u8 job, const u8 state)
{
	if (builder is null || builder.hasTag("dead")) return;
	// New executable work supersedes a deferred no-work retirement.
	builder.set_bool(AIBM_RETIRE_PENDING_KEY, false);
	if (!AIBU_IsAutoBuilder(builder) && builder.get_netid(AIBR_ASSIGNED_HOME_KEY) == 0)
		AIBS_SetBuilderResourceHome(builder, AIBS_CurrentResourceHomeID(u8(builder.getTeamNum())));
	const u8 oldJob = builder.get_u8("ai builder job");
	const u8 oldState = builder.get_u8("ai builder state");
	const bool assigned = builder.get_bool("aib strategy assigned");
	if (assigned && oldJob != job && !AIBS_BuilderAtRoleHandoff(builder, oldJob, oldState))
	{
		const bool changed = !builder.get_bool("aib strategy role pending") ||
			builder.get_u8("aib strategy pending job") != job || builder.get_u8("aib strategy pending state") != state;
		builder.set_bool("aib strategy role pending", true);
		builder.set_u8("aib strategy pending job", job);
		builder.set_u8("aib strategy pending state", state);
		if (changed) AIBS_Log("assign_deferred", u8(builder.getTeamNum()), "builder=" + builder.getNetworkID() +
			" current_job=" + oldJob + " current_state=" + oldState + " pending_job=" + job + " pending_state=" + state);
		return;
	}
	// A matching manually-issued job is not yet owned by the director. Only
	// skip the write when this builder already carries the full strategy
	// assignment contract; otherwise StopTeam and reservation cleanup would
	// never recognize it as director-controlled.
	if (oldJob == job && oldState != AIBS_STATE_IDLE && assigned)
	{
		AIBM_ClearDeferredStrategyRole(builder);
		return;
	}
	if (AIBM_ApplyStrategyRole(builder, job, state))
		AIBS_Log("assign", u8(builder.getTeamNum()), "builder=" + builder.getNetworkID() + " job=" + job + " state=" + state);
}

bool AIBS_BuilderAtRoleHandoff(CBlob@ builder, const u8 job, const u8 state)
{
	return AIBM_IsAtStrategyHandoff(builder);
}

void AIBS_RetireBuilderAtSafeBoundary(const u8 team, CBlob@ builder)
{
	if (builder is null || !builder.get_bool("aib strategy assigned")) return;
	const u8 job = builder.get_u8("ai builder job");
	const u8 state = builder.get_u8("ai builder state");
	// Autobuilders carry no resources. Once no work exists, they have no
	// resource episode to preserve and can relinquish ownership immediately.
	if (AIBU_IsAutoBuilder(builder) || AIBS_BuilderAtRoleHandoff(builder, job, state))
	{
		AIBS_StopBuilderAssignment(team, builder);
		AIBS_Log("retire", team, "builder=" + builder.getNetworkID() + " reason=no_executable_work");
		return;
	}
	if (!builder.get_bool(AIBM_RETIRE_PENDING_KEY))
	{
		builder.set_bool(AIBM_RETIRE_PENDING_KEY, true);
		AIBS_Log("retire_deferred", team, "builder=" + builder.getNetworkID() + " job=" + job + " state=" + state);
	}
}

void AIBS_RetireAssignedBuildersAtSafeBoundary(const u8 team, array<CBlob@> &in builders)
{
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder is null || AIBM_IsUnderManualControl(builder)) continue;
		AIBS_RetireBuilderAtSafeBoundary(team, builder);
	}
}

void AIBS_GetTeamBuilders(const u8 team, array<CBlob@> &out teamBuilders)
{
	teamBuilders.clear();
	string[] names = { "aibuilder", AIBU_ENTITY_NAME };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] builders;
		getBlobsByName(names[n], @builders);
		for (uint i = 0; i < builders.length; i++)
		{
			CBlob@ builder = builders[i];
			if (builder is null || builder.hasTag("dead") || builder.getTeamNum() != team) continue;

			// Blob enumeration order is not a coordination contract. Keep role
			// allocation stable as builders enter and leave by sorting on net ID.
			uint insertAt = 0;
			while (insertAt < teamBuilders.length &&
				teamBuilders[insertAt].getNetworkID() < builder.getNetworkID()) insertAt++;
			teamBuilders.insertAt(insertAt, builder);
		}
	}
}

bool AIBS_HasActivePendingPlan(const u8 team)
{
	CRules@ rules = getRules();
	if (rules is null || rules.get_u16(AIBP_PlanKey(team, "id")) == 0 ||
		rules.get_u8(AIBP_PlanKey(team, "status")) != 1 ||
		rules.get_u16(AIBP_PlanKey(team, "pending")) == 0) return false;

	array<u16>@ work = null;
	if (!AIBP_GetLayerGrid(team, AIBP_Layer::ai_work, @work) || work is null) return false;
	for (uint i = 0; i < work.length; i++) if (work[i] != 0) return true;
	return false;
}

void AIBS_CollectBootstrapBlockers(array<Vec2f> &out blockerMins, array<Vec2f> &out blockerMaxs)
{
	blockerMins.clear();
	blockerMaxs.clear();
	CBlob@[] blobs;
	getBlobs(@blobs);
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ other = blobs[i];
		if (other is null || other.hasTag("dead") || other.isInInventory()) continue;
		const string name = other.getName();
		const bool important = other.hasTag("building") || other.hasTag("player") || other.hasTag("flesh") ||
			other.hasTag("vehicle") || other.isCollidable() || name == "ctf_flag" || name == "tent" || name == "hall" ||
			name == "crate" || name == "buildershop" || name == "aibuildershop";
		if (!important) continue;

		CShape@ shape = other.getShape();
		if (shape is null)
		{
			const Vec2f point = other.getPosition();
			blockerMins.push_back(point);
			blockerMaxs.push_back(point);
			continue;
		}

		Vec2f otherMin, otherMax;
		shape.getBoundingRect(otherMin, otherMax);
		blockerMins.push_back(otherMin);
		blockerMaxs.push_back(otherMax);
	}

}

bool AIBS_BootstrapSpawnOverlapsBlockers(Vec2f center, array<Vec2f>@ blockerMins, array<Vec2f>@ blockerMaxs)
{
	if (blockerMins is null || blockerMaxs is null) return false;
	const Vec2f spawnMin = center - Vec2f(8.0f, 8.0f);
	const Vec2f spawnMax = center + Vec2f(8.0f, 8.0f);
	const uint count = Maths::Min(blockerMins.length, blockerMaxs.length);
	for (uint i = 0; i < count; i++)
	{
		Vec2f otherMin = blockerMins[i];
		Vec2f otherMax = blockerMaxs[i];
		if (otherMin.x == otherMax.x && otherMin.y == otherMax.y)
		{
			if (otherMin.x > spawnMin.x && otherMin.x < spawnMax.x &&
				otherMin.y > spawnMin.y && otherMin.y < spawnMax.y) return true;
			continue;
		}
		if (spawnMin.x < otherMax.x && spawnMax.x > otherMin.x &&
			spawnMin.y < otherMax.y && spawnMax.y > otherMin.y) return true;
	}
	return false;
}

bool AIBS_IsBootstrapRouteCell(AIBWorldState@ world, const int x, const int y)
{
	CMap@ map = getMap();
	if (world is null || map is null || x < 1 || x >= map.tilemapwidth - 1 || y < 1 || y >= map.tilemapheight - 1) return false;
	if (!AIBS_RouteCellClear(null, x, y) || !AIBS_RouteCellSupported(null, x, y)) return false;
	const f32 ts = map.tilesize;
	Vec2f body = Vec2f((x + 0.5f) * ts, (y + 0.5f) * ts);
	Vec2f head = body - Vec2f(0.0f, ts);
	Vec2f ground = body + Vec2f(0.0f, ts);
	return AIBS_InsideBarrierSide(world, body) && AIBS_InsideBarrierSide(world, head) && AIBS_InsideBarrierSide(world, ground);
}

AIBBootstrapReachability@ AIBS_BuildBootstrapReachability(AIBWorldState@ world)
{
	AIBBootstrapReachability@ result = AIBBootstrapReachability();
	CMap@ map = getMap();
	if (world is null || map is null || world.resourceHome == Vec2f_zero) return result;
	const Vec2f homeSpace = map.getTileSpacePosition(world.resourceHome);
	const int homeX = Maths::Floor(homeSpace.x);
	const int homeY = Maths::Floor(homeSpace.y);
	result.minX = Maths::Max(1, homeX - int(AIBS_BOOTSTRAP_MAX_HOME_DISTANCE) - 2);
	result.maxX = Maths::Min(int(map.tilemapwidth) - 2, homeX + int(AIBS_BOOTSTRAP_MAX_HOME_DISTANCE) + 2);
	result.minY = Maths::Max(1, homeY - int(AIBS_BOOTSTRAP_VERTICAL_SEARCH) - 4);
	result.maxY = Maths::Min(int(map.tilemapheight) - 2, homeY + int(AIBS_BOOTSTRAP_VERTICAL_SEARCH) + 4);
	result.width = result.maxX - result.minX + 1;
	const int height = result.maxY - result.minY + 1;
	if (result.width <= 0 || height <= 0) return result;
	result.cells.set_length(result.width * height);

	// Use one deterministic terrain seed nearest to the home. Seeding every
	// nearby standing cell would incorrectly bless a sealed pocket merely
	// because its wall happens to be close to a tent or hall.
	int seedX = -1;
	int seedY = -1;
	int seedScore = 2147483647;
	const int seedMinX = Maths::Max(result.minX, homeX - int(AIBS_BOOTSTRAP_HOME_SEED_RADIUS));
	const int seedMaxX = Maths::Min(result.maxX, homeX + int(AIBS_BOOTSTRAP_HOME_SEED_RADIUS));
	const int seedMinY = Maths::Max(result.minY, homeY - int(AIBS_BOOTSTRAP_HOME_SEED_RADIUS));
	const int seedMaxY = Maths::Min(result.maxY, homeY + int(AIBS_BOOTSTRAP_HOME_SEED_RADIUS));
	for (int y = seedMinY; y <= seedMaxY; y++)
	{
		for (int x = seedMinX; x <= seedMaxX; x++)
		{
			if (!AIBS_IsBootstrapRouteCell(world, x, y)) continue;
			const int dx = x - homeX;
			const int dy = y - homeY;
			const int score = dx * dx + dy * dy;
			if (score >= seedScore) continue;
			seedScore = score;
			seedX = x;
			seedY = y;
		}
	}
	if (seedX < 0) return result;

	array<int> queueX;
	array<int> queueY;
	const int seedIndex = (seedY - result.minY) * result.width + (seedX - result.minX);
	result.cells[seedIndex] = true;
	result.seeded = true;
	queueX.push_back(seedX);
	queueY.push_back(seedY);
	uint head = 0;
	while (head < queueX.length)
	{
		const int x = queueX[head];
		const int y = queueY[head];
		head++;
		for (int stepX = -1; stepX <= 1; stepX += 2)
		{
			for (int stepY = -1; stepY <= 1; stepY++)
			{
				const int nx = x + stepX;
				const int ny = y + stepY;
				if (nx < result.minX || nx > result.maxX || ny < result.minY || ny > result.maxY) continue;
				const int index = (ny - result.minY) * result.width + (nx - result.minX);
				if (result.cells[index] || !AIBS_IsBootstrapRouteCell(world, nx, ny)) continue;
				result.cells[index] = true;
				queueX.push_back(nx);
				queueY.push_back(ny);
			}
		}
	}
	return result;
}

bool AIBS_BootstrapReachable(AIBBootstrapReachability@ reachability, Vec2f center)
{
	CMap@ map = getMap();
	if (reachability is null || !reachability.seeded || map is null || center == Vec2f_zero) return false;
	const Vec2f space = map.getTileSpacePosition(center);
	const int x = Maths::Floor(space.x);
	const int y = Maths::Floor(space.y);
	if (x < reachability.minX || x > reachability.maxX || y < reachability.minY || y > reachability.maxY) return false;
	const int index = (y - reachability.minY) * reachability.width + (x - reachability.minX);
	return index >= 0 && index < int(reachability.cells.length) && reachability.cells[index];
}

bool AIBS_IsBootstrapSpawnEnvelopeSafe(AIBWorldState@ world, Vec2f center,
	array<Vec2f>@ blockerMins, array<Vec2f>@ blockerMaxs)
{
	CMap@ map = getMap();
	if (world is null || map is null || center == Vec2f_zero) return false;
	const Vec2f space = map.getTileSpacePosition(center);
	const int x = Maths::Floor(space.x);
	const int y = Maths::Floor(space.y);
	if (x < 1 || x >= map.tilemapwidth - 1 || y < 1 || y >= map.tilemapheight - 1) return false;

	const f32 ts = map.tilesize;
	// KAG's Vec2f arithmetic/equality operators are non-const member methods.
	// Keep operands mutable even though this function does not otherwise alter them.
	Vec2f body = Vec2f((x + 0.5f) * ts, (y + 0.5f) * ts);
	// The builder radius is almost one full tile, so a solid immediately beside
	// the center column can overlap and collision-nudge the spawn. Require the
	// complete three-column, two-tile body envelope to be open.
	for (int dx = -1; dx <= 1; dx++)
	{
		Vec2f bodySample = body + Vec2f(dx * ts, 0.0f);
		Vec2f headSample = bodySample - Vec2f(0.0f, ts);
		if (map.isTileSolid(map.getTile(bodySample).type) || map.isTileSolid(map.getTile(headSample).type)) return false;
		if (!AIBS_InsideBarrierSide(world, bodySample) || !AIBS_InsideBarrierSide(world, headSample)) return false;
	}
	Vec2f ground = body + Vec2f(0.0f, ts);
	if (!map.isTileSolid(map.getTile(ground).type) || !AIBS_InsideBarrierSide(world, ground)) return false;
	return !AIBS_BootstrapSpawnOverlapsBlockers(body, blockerMins, blockerMaxs);
}

bool AIBS_IsSafeBootstrapSpawn(AIBWorldState@ world, Vec2f center,
	array<Vec2f>@ blockerMins, array<Vec2f>@ blockerMaxs, AIBBootstrapReachability@ reachability)
{
	return AIBS_IsBootstrapSpawnEnvelopeSafe(world, center, blockerMins, blockerMaxs) &&
		AIBS_BootstrapReachable(reachability, center);
}

Vec2f AIBS_FindBootstrapSpawn(AIBWorldState@ world)
{
	CMap@ map = getMap();
	if (world is null || map is null || world.resourceHome == Vec2f_zero) return Vec2f_zero;
	const Vec2f homeSpace = map.getTileSpacePosition(world.resourceHome);
	const int homeX = Maths::Floor(homeSpace.x);
	const int homeY = Maths::Floor(homeSpace.y);
	const int preferredSide = world.enemyDirection >= 0 ? -1 : 1;
	Vec2f best = Vec2f_zero;
	f32 bestScore = 999999.0f;
	array<Vec2f> blockerMins;
	array<Vec2f> blockerMaxs;
	AIBBootstrapReachability@ reachability = AIBS_BuildBootstrapReachability(world);
	if (reachability is null || !reachability.seeded) return Vec2f_zero;
	// Blob bounds are stable during this one search.  The previous version called
	// getBlobs() for every terrain candidate (up to 950 full world scans).
	AIBS_CollectBootstrapBlockers(blockerMins, blockerMaxs);

	// Evaluate both sides rather than accepting a convenient point inside the
	// home. Prefer the rear side only as a deterministic tie-breaker.
	for (int distance = AIBS_BOOTSTRAP_MIN_HOME_DISTANCE; distance <= AIBS_BOOTSTRAP_MAX_HOME_DISTANCE; distance++)
	{
		for (int sideIndex = 0; sideIndex < 2; sideIndex++)
		{
			const int side = sideIndex == 0 ? preferredSide : -preferredSide;
			const int x = homeX + side * distance;
			for (int yOffset = -AIBS_BOOTSTRAP_VERTICAL_SEARCH; yOffset <= AIBS_BOOTSTRAP_VERTICAL_SEARCH; yOffset++)
			{
				const int y = homeY + yOffset;
				Vec2f candidate = Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize);
				if (!AIBS_IsSafeBootstrapSpawn(world, candidate, blockerMins, blockerMaxs, reachability)) continue;
				const f32 score = float(distance) + Maths::Abs(yOffset) * 2.0f + (side == preferredSide ? 0.0f : 0.25f);
				if (score < bestScore)
				{
					bestScore = score;
					best = candidate;
				}
			}
		}
	}
	return best;
}

bool AIBS_TryBootstrapBuilder(CRules@ rules, AIBWorldState@ world)
{
	if (!isServer() || rules is null || world is null) return false;
	const u8 team = world.team;
	// The unattended launcher owns one explicit team.  Treating the developer
	// override as global needlessly spawned an enemy worker and doubled AI load.
	const bool developerForce = rules.get_bool("aib developer force worker") &&
		rules.get_u8("aib developer force worker team") == team;
	if (!rules.get_bool(AIBS_BootstrapKey(team, "enabled")) ||
		rules.get_bool(AIBS_BootstrapKey(team, "provisioned")) ||
		world.home == Vec2f_zero || world.resourceHome == Vec2f_zero ||
		(!developerForce && !AIBS_HasActivePendingPlan(team))) return false;

	array<CBlob@> builders;
	AIBS_GetTeamBuilders(team, builders);
	if (builders.length > 0) return false;

	const u32 now = getGameTime();
	if (now < rules.get_u32(AIBS_BootstrapKey(team, "next retry"))) return false;
	Vec2f spawn = AIBS_FindBootstrapSpawn(world);
	if (spawn == Vec2f_zero)
	{
		rules.set_u32(AIBS_BootstrapKey(team, "next retry"), now + AIBS_BOOTSTRAP_RETRY_TICKS);
		AIBS_Log("provision_wait", team, "reason=no_safe_home_spawn retry=" + AIBS_BOOTSTRAP_RETRY_TICKS);
		return false;
	}

	CBlob@ builder = server_CreateBlob("aibuilder", team, spawn);
	if (builder is null)
	{
		rules.set_u32(AIBS_BootstrapKey(team, "next retry"), now + AIBS_BOOTSTRAP_RETRY_TICKS);
		AIBS_Log("provision_wait", team, "reason=create_failed retry=" + AIBS_BOOTSTRAP_RETRY_TICKS);
		return false;
	}

	builder.Tag("aib strategy bootstrap worker");
	if (developerForce) builder.Tag("aib developer forced worker");
	builder.set_bool("aib strategy bootstrap worker", true);
	builder.set_Vec2f("aib strategy bootstrap spawn", spawn);
	builder.Sync("aib strategy bootstrap worker", true);
	rules.set_bool(AIBS_BootstrapKey(team, "provisioned"), true);
	rules.set_u32(AIBS_BootstrapKey(team, "next retry"), 0);
	rules.Sync(AIBS_BootstrapKey(team, "provisioned"), true);
	AIBS_Log("provision", team, "builder=" + builder.getNetworkID() + " source=" +
		(developerForce ? "developer_ctf" : "home") + " pos=" + int(spawn.x) + "," + int(spawn.y) + " one_time=true");
	return true;
}

void AIBS_ComputeRoleDemand(const uint builderCount, const u16 planPending,
	const u32 woodShort, const u32 stoneShort, const u32 goldShort,
	uint &out woodCollectors, uint &out stoneCollectors, uint &out builders)
{
	woodCollectors = 0;
	stoneCollectors = 0;
	builders = builderCount;
	if (builderCount == 0) return;

	// Stone workers own visible-gold discovery and delivery. One outstanding gold
	// requirement therefore contributes one collector load to their demand; it
	// must not disappear merely because the plan was published before gold was
	// already stored.
	const u32 effectiveStoneShort = stoneShort + (goldShort > 0 ? AIBS_COLLECTOR_LOAD : 0);
	const u32 totalShort = woodShort + effectiveStoneShort;
	if (totalShort == 0) return;
	const uint maxCollectors = builderCount > 1 && planPending > 0 ? builderCount - 1 : builderCount;
	uint collectors = uint(Maths::Ceil(float(totalShort) / float(AIBS_COLLECTOR_LOAD)));
	const uint materialKinds = (woodShort > 0 ? 1 : 0) + (effectiveStoneShort > 0 ? 1 : 0);
	collectors = Maths::Min(maxCollectors, Maths::Max(collectors, materialKinds));
	if (collectors == 0) return;

	// When only one collector slot is available, minimum-one-per-material is
	// impossible. Choose the larger outstanding demand instead of always
	// favoring wood because it happens to be assigned first.
	if (collectors == 1)
	{
		woodCollectors = woodShort > 0 && (effectiveStoneShort == 0 || woodShort >= effectiveStoneShort) ? 1 : 0;
		stoneCollectors = 1 - woodCollectors;
	}
	else
	{
		woodCollectors = uint(Maths::Round(float(collectors) * float(woodShort) / float(totalShort)));
		if (woodShort > 0 && woodCollectors == 0) woodCollectors = 1;
		if (effectiveStoneShort > 0 && woodCollectors >= collectors) woodCollectors = collectors - 1;
		stoneCollectors = collectors - woodCollectors;
	}
	builders = builderCount - collectors;
}

void AIBS_AssignStableRoles(array<CBlob@> &in teamBuilders,
	const uint woodCollectors, const uint stoneCollectors, const uint builders)
{
	array<u8> roles;
	roles.set_length(teamBuilders.length);
	for (uint i = 0; i < roles.length; i++) roles[i] = 255;
	uint woodLeft = woodCollectors;
	uint stoneLeft = stoneCollectors;
	uint buildLeft = builders;

	// Keep builders already in a still-needed role. This avoids needless
	// cross-role handoffs when a delivery changes a shortage by one heartbeat.
	for (uint i = 0; i < teamBuilders.length; i++)
	{
		CBlob@ builder = teamBuilders[i];
		if (builder is null || !builder.get_bool("aib strategy assigned")) continue;
		const u8 job = builder.get_u8("ai builder job");
		if (job == AIBS_JOB_WOOD && woodLeft > 0) { roles[i] = job; woodLeft--; }
		else if (job == AIBS_JOB_STONE && stoneLeft > 0) { roles[i] = job; stoneLeft--; }
		else if (job == AIBS_JOB_BLUEPRINT && buildLeft > 0) { roles[i] = job; buildLeft--; }
	}

	// AIBS_GetTeamBuilders sorted the roster by network ID, so filling open
	// slots in this order is deterministic even when entities enumerate oddly.
	for (uint i = 0; i < teamBuilders.length; i++)
	{
		if (roles[i] != 255) continue;
		if (woodLeft > 0) { roles[i] = AIBS_JOB_WOOD; woodLeft--; }
		else if (stoneLeft > 0) { roles[i] = AIBS_JOB_STONE; stoneLeft--; }
		else { roles[i] = AIBS_JOB_BLUEPRINT; if (buildLeft > 0) buildLeft--; }
	}

	for (uint i = 0; i < teamBuilders.length; i++)
	{
		if (roles[i] == AIBS_JOB_WOOD) AIBS_SetBuilderJob(teamBuilders[i], AIBS_JOB_WOOD, AIBS_STATE_FIND_TREE);
		else if (roles[i] == AIBS_JOB_STONE) AIBS_SetBuilderJob(teamBuilders[i], AIBS_JOB_STONE, AIBS_STATE_FIND_STONE);
		else AIBS_SetBuilderJob(teamBuilders[i], AIBS_JOB_BLUEPRINT, AIBS_STATE_COLLECT_BLUEPRINT);
	}
}

void AIBS_AssignBuilders(AIBWorldState@ world)
{
	if (world is null) return;
	array<CBlob@> teamBuilders;
	AIBS_GetTeamBuilders(world.team, teamBuilders);
	for (int i = int(teamBuilders.length) - 1; i >= 0; i--)
	{
		if (teamBuilders[i].hasTag("aib developer scenario role locked")) teamBuilders.removeAt(i);
	}
	// A completed, cancelled, suggestion-only, or absent plan has no executable
	// director work. Do not reclaim idle workers as blueprint builders. Preserve
	// an in-flight resource episode until its normal target-free handoff, then
	// relinquish the assignment on a later heartbeat.
	if (!AIBS_HasActivePendingPlan(world.team))
	{
		AIBS_RetireAssignedBuildersAtSafeBoundary(world.team, teamBuilders);
		return;
	}
	// Collisionless infinite-resource workers exist specifically to isolate
	// director strategy from harvesting and pathing. They always execute the
	// blueprint role and never consume a collector slot.
	bool hasAutoBuilder = false;
	for (int i = int(teamBuilders.length) - 1; i >= 0; i--)
	{
		if (!AIBU_IsAutoBuilder(teamBuilders[i])) continue;
		hasAutoBuilder = true;
		if (AIBM_IsUnderManualControl(teamBuilders[i])) { teamBuilders.removeAt(i); continue; }
		AIBS_SetBuilderResourceHome(teamBuilders[i], 0);
		AIBS_SetBuilderJob(teamBuilders[i], AIBS_JOB_BLUEPRINT, AIBS_STATE_FIND_BLUEPRINT);
		teamBuilders.removeAt(i);
	}
	for (int i = int(teamBuilders.length) - 1; i >= 0; i--)
	{
		if (AIBM_IsUnderManualControl(teamBuilders[i])) teamBuilders.removeAt(i);
	}
	if (world.resourceHome == Vec2f_zero)
	{
		// Autobuilders have no inventory and may keep executing paid blueprint
		// work around a surviving strategic flag. Ordinary runners cannot finish
		// collection, delivery, or retrieval without a tent/hall, so relinquish
		// only their director assignments until an operational home returns.
		for (uint i = 0; i < teamBuilders.length; i++)
		{
			CBlob@ builder = teamBuilders[i];
			if (builder !is null && builder.get_bool("aib strategy assigned"))
				AIBS_StopBuilderAssignment(world.team, builder);
		}
		return;
	}
	const u16 resourceHomeID = AIBS_WorldResourceHomeID(world);
	if (hasAutoBuilder)
	{
		// A normal bootstrap worker can already exist by the time a player buys
		// the orb. Do not give director-owned runner builders new construction
		// reservations while an Autobuilder is present. A runner already inside a
		// blueprint episode hands off to wood at its normal safe boundary; manual
		// player orders remain untouched because they are not strategy-assigned.
		for (uint i = 0; i < teamBuilders.length; i++)
		{
			CBlob@ builder = teamBuilders[i];
			AIBS_SetBuilderResourceHome(builder, builder.get_bool("aib strategy assigned") ? resourceHomeID : 0);
			if (builder.get_bool("aib strategy assigned") && builder.get_u8("ai builder job") == AIBS_JOB_BLUEPRINT)
				AIBS_SetBuilderJob(builder, AIBS_JOB_WOOD, AIBS_STATE_FIND_TREE);
		}
		return;
	}
	if (teamBuilders.length == 0) return;
	for (uint i = 0; i < teamBuilders.length; i++) AIBS_SetBuilderResourceHome(teamBuilders[i], resourceHomeID);
	const u16 woodCost = AIBP_RemainingMaterialCost(world.team, "mat_wood");
	const u16 stoneCost = AIBP_RemainingMaterialCost(world.team, "mat_stone");
	const u16 goldCost = AIBP_RemainingMaterialCost(world.team, "mat_gold");
	const u32 woodShort = woodCost > world.storedWood ? woodCost - world.storedWood : 0;
	const u32 stoneShort = stoneCost > world.storedStone ? stoneCost - world.storedStone : 0;
	const u32 goldShort = goldCost > world.storedGold ? goldCost - world.storedGold : 0;
	uint woodCollectors = 0;
	uint stoneCollectors = 0;
	uint builders = 0;
	AIBS_ComputeRoleDemand(teamBuilders.length, world.planPending, woodShort, stoneShort, goldShort,
		woodCollectors, stoneCollectors, builders);
	AIBS_AssignStableRoles(teamBuilders, woodCollectors, stoneCollectors, builders);
}

void AIBS_StopBuilderAssignment(const u8 team, CBlob@ builder)
{
	if (builder is null || !builder.get_bool("aib strategy assigned")) return;
	AIBM_StopDirectorControl(builder);
}

void AIBS_StopAssignedBuilders(const u8 team)
{
	array<CBlob@> builders;
	AIBS_GetTeamBuilders(team, builders);
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		AIBS_StopBuilderAssignment(team, builder);
	}
}
