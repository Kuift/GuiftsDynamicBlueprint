#include "AIBPlacementPlanner.as";
#include "AIBWorldFingerprint.as";
#include "AutoBuilderCommon.as";

// Wave fixture v4 measures a short, naturally grounded corridor around the
// production selector's pre-intervention candidate.  Both control and plan
// arms therefore attack the same coordinates without first crossing unrelated
// map hazards.  The candidate itself remains the intervention: the control arm
// leaves it absent and the plan arm lets the normal director publish/build it.
const u16 AIBW_FIXTURE_VERSION = 4;
const int AIBW_FIXTURE_HOME_CLEARANCE = 4;
const int AIBW_FIXTURE_ENEMY_CLEARANCE = 6;
const int AIBW_FIXTURE_INITIAL_Y_SEARCH = 8;

CBlob@ AIBW_ArmNearestHome(const u8 team, const string &in name, Vec2f from)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	CBlob@ best = null;
	f32 bestDistance = 99999999.0f;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ candidate = blobs[i];
		if (candidate is null || candidate.hasTag("dead") || candidate.getTeamNum() != team) continue;
		const f32 distance = (candidate.getPosition() - from).LengthSquared();
		if (distance < bestDistance) { bestDistance = distance; @best = candidate; }
	}
	return best;
}

CBlob@ AIBW_ArmTeamHome(const u8 team)
{
	CBlob@ home = AIBW_ArmNearestHome(team, "ctf_flag", Vec2f_zero);
	if (home !is null) return home;
	@home = AIBW_ArmNearestHome(team, "tent", Vec2f_zero);
	return home !is null ? home : AIBW_ArmNearestHome(team, "hall", Vec2f_zero);
}

CBlob@ AIBW_ArmEnemyHome(const u8 team, Vec2f from)
{
	string[] names = { "ctf_flag", "tent", "hall" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] homes;
		getBlobsByName(names[n], @homes);
		CBlob@ best = null;
		f32 bestDistance = 99999999.0f;
		for (uint i = 0; i < homes.length; i++)
		{
			CBlob@ candidate = homes[i];
			if (candidate is null || candidate.hasTag("dead") || candidate.getTeamNum() == team || candidate.getTeamNum() >= 100) continue;
			const f32 distance = (candidate.getPosition() - from).LengthSquared();
			if (distance < bestDistance) { bestDistance = distance; @best = candidate; }
		}
		if (best !is null) return best;
	}
	return null;
}

u16 AIBW_ArmStoredMaterial(const u8 team, const string &in material)
{
	u32 total = 0;
	string[] names = { "tent", "hall", "crate", "buildershop", "aibuilder" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] blobs;
		getBlobsByName(names[n], @blobs);
		for (uint i = 0; i < blobs.length; i++)
		{
			CBlob@ storage = blobs[i];
			if (storage is null || storage.hasTag("dead") || storage.getTeamNum() != team) continue;
			CInventory@ inventory = storage.getInventory();
			if (inventory !is null) total += inventory.getCount(material);
		}
	}
	return u16(Maths::Min(total, 65535));
}

u32 AIBW_FixtureTaskHash(AIBPlanCandidate@ candidate)
{
	if (candidate is null) return 0;
	u32 hash = 2166136261;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null) continue;
		hash = (hash ^ task.x) * 16777619;
		hash = (hash ^ task.y) * 16777619;
		hash = (hash ^ task.block) * 16777619;
		hash = (hash ^ task.phase) * 16777619;
	}
	return hash;
}

bool AIBW_FindGroundedAtX(CBlob@ home, const int x, const int preferredY,
	const int maxYOffset, Vec2f &out result)
{
	result = Vec2f_zero;
	CMap@ map = getMap();
	if (home is null || map is null || x < 2 || x >= map.tilemapwidth - 2) return false;
	for (int offset = 0; offset <= maxYOffset; offset++)
	{
		const int signs = offset == 0 ? 1 : 2;
		for (int signIndex = 0; signIndex < signs; signIndex++)
		{
			const int y = preferredY + (signIndex == 0 ? offset : -offset);
			if (y < 2 || y >= map.tilemapheight - 2) continue;
			Vec2f candidate = Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize);
			if (!AIBR_IsGroundedStoragePoint(home, candidate)) continue;
			result = candidate;
			return true;
		}
	}
	return false;
}

bool AIBW_CaptureCandidateCorridor(CRules@ rules, CBlob@ home, AIBWorldState@ world,
	AIBPlanCandidate@ candidate)
{
	if (rules is null) return false;
	rules.set_string("aib wave fixture capture detail", "candidate_unavailable");
	if (home is null || world is null || candidate is null || candidate.tasks.length == 0) return false;
	CMap@ map = getMap();
	if (map is null || world.enemyDirection == 0)
	{
		rules.set_string("aib wave fixture capture detail", "map_or_direction_invalid");
		return false;
	}
	int minX = map.tilemapwidth;
	int maxX = -1;
	for (uint i = 0; i < candidate.tasks.length; i++)
	{
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null) continue;
		minX = Maths::Min(minX, int(task.x));
		maxX = Maths::Max(maxX, int(task.x));
	}
	if (minX > maxX)
	{
		rules.set_string("aib wave fixture capture detail", "empty_task_bounds");
		return false;
	}

	const int direction = world.enemyDirection;
	const int homeEdgeX = direction > 0 ? minX : maxX;
	const int enemyEdgeX = direction > 0 ? maxX : minX;
	const int targetX = homeEdgeX - direction * AIBW_FIXTURE_HOME_CLEARANCE;
	const int spawnX = enemyEdgeX + direction * AIBW_FIXTURE_ENEMY_CLEARANCE;
	if (targetX < 2 || targetX >= map.tilemapwidth - 2 || spawnX < 2 || spawnX >= map.tilemapwidth - 2)
	{
		rules.set_string("aib wave fixture capture detail", "bounds_" + candidate.templateName + "_" + int(candidate.anchor.x));
		return false;
	}

	Vec2f target = Vec2f_zero;
	const int preferredY = int(candidate.anchor.y) - 1;
	if (!AIBW_FindGroundedAtX(home, targetX, preferredY, AIBW_FIXTURE_INITIAL_Y_SEARCH, target))
	{
		rules.set_string("aib wave fixture capture detail", "target_ground_" + candidate.templateName + "_" + int(candidate.anchor.x) + "_x" + targetX);
		return false;
	}
	Vec2f previous = target;
	u32 corridorHash = 2166136261;
	for (int x = targetX; x != spawnX + direction; x += direction)
	{
		Vec2f cell = Vec2f_zero;
		const int previousY = Maths::Floor(previous.y / map.tilesize);
		if (!AIBW_FindGroundedAtX(home, x, previousY, x == targetX ? 0 : 1, cell))
		{
			rules.set_string("aib wave fixture capture detail", "corridor_" + candidate.templateName + "_" + int(candidate.anchor.x) + "_x" + x + "_y" + previousY);
			return false;
		}
		previous = cell;
		corridorHash = (corridorHash ^ u32(x)) * 16777619;
		corridorHash = (corridorHash ^ u32(Maths::Floor(cell.y / map.tilesize))) * 16777619;
	}
	Vec2f spawn = previous;
	if ((spawn - target).Length() < 64.0f)
	{
		rules.set_string("aib wave fixture capture detail", "corridor_short_" + candidate.templateName + "_" + int(candidate.anchor.x));
		return false;
	}

	rules.set_string("aib wave fixture template", candidate.templateName);
	rules.set_s32("aib wave fixture anchor x", int(candidate.anchor.x));
	rules.set_s32("aib wave fixture anchor y", int(candidate.anchor.y));
	rules.set_s32("aib wave fixture direction", direction);
	rules.set_u16("aib wave fixture tasks", candidate.tasks.length);
	rules.set_u32("aib wave fixture task hash", AIBW_FixtureTaskHash(candidate));
	rules.set_u32("aib wave fixture corridor hash", corridorHash);
	rules.set_Vec2f("aib wave approach start", spawn);
	rules.set_Vec2f("aib wave breach target", target);
	rules.set_string("aib wave fixture capture detail", "ok_" + candidate.templateName + "_" + int(candidate.anchor.x));
	return true;
}

bool AIBW_CaptureArmState(CRules@ rules, const u8 team)
{
	if (rules is null) return false;
	rules.set_bool("aib wave initial captured", false);
	rules.set_string("aib wave initial fingerprint", "");
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0) return false;
	CBlob@ home = AIBW_ArmTeamHome(team);
	CBlob@ enemyHome = home is null ? null : AIBW_ArmEnemyHome(team, home.getPosition());
	if (home is null || enemyHome is null) return false;

	const u32 mapHash = u32(map.getMapName().getHash());
	u32 terrainHash = 0;
	u32 solidTiles = 0;
	u32 noBuildHash = 0;
	u32 noBuildTiles = 0;
	u32 manifestBlobCount = 0;
	u32 manifestBlobHash = 0;
	u32 manifestInventoryHash = 0;
	u32 manifestStrategyHash = 0;

	u16 friendlyUnits = 0;
	u16 enemyUnits = 0;
	u16 aiBuilders = 0;
	u16 normalAIBuilderCount = 0;
	u16 autoBuilderCount = 0;
	u32 aiBuilderTypePositionHash = 0;
	CBlob@[] all;
	getBlobs(@all);
	for (uint i = 0; i < all.length; i++)
	{
		CBlob@ unit = all[i];
		if (unit is null || unit.hasTag("dead")) continue;
		const string name = unit.getName();
		const bool combatUnit = name == "builder" || name == "aibuilder" || name == "autobuilder" || name == "knight" || name == "archer";
		if (!combatUnit) continue;
		if (unit.getTeamNum() == team)
		{
			friendlyUnits++;
			if (name == "aibuilder" || name == "autobuilder")
			{
				aiBuilders++;
				if (name == "autobuilder") autoBuilderCount++; else normalAIBuilderCount++;
				const u32 workerX = u32(Maths::Max(0, int(unit.getPosition().x / map.tilesize)));
				const u32 workerY = u32(Maths::Max(0, int(unit.getPosition().y / map.tilesize)));
				aiBuilderTypePositionHash += u32(name.getHash()) ^ (workerX * 73856093) ^ (workerY * 19349663);
			}
		}
		else if (unit.getTeamNum() < 100) enemyUnits++;
	}

	CBlob@[] trees;
	getBlobsByTag("tree", @trees);
	u16 treeCount = 0;
	u32 treeHash = 0;
	for (uint i = 0; i < trees.length; i++)
	{
		CBlob@ tree = trees[i];
		if (tree is null || tree.hasTag("dead") || tree.hasTag("felldown")) continue;
		treeCount++;
		const u32 tx = u32(Maths::Max(0, int(tree.getPosition().x / map.tilesize)));
		const u32 ty = u32(Maths::Max(0, int(tree.getPosition().y / map.tilesize)));
		treeHash += ((tx + 1) * 73856093) ^ ((ty + 1) * 19349663) ^ u32(tree.get_u8("grown_times"));
	}

	const s32 homeX = s32(home.getPosition().x / map.tilesize);
	const s32 homeY = s32(home.getPosition().y / map.tilesize);
	const s32 enemyHomeX = s32(enemyHome.getPosition().x / map.tilesize);
	const s32 enemyHomeY = s32(enemyHome.getPosition().y / map.tilesize);
	const u8 autoBuilderSpeedLevel = AIBU_GetSpeedLevel(team);
	const string fixtureID = "map_" + mapHash + "_" + map.tilemapwidth + "x" + map.tilemapheight;
	const string teamSide = homeX <= enemyHomeX ? "left" : "right";
	const u16 initialWood = AIBW_ArmStoredMaterial(team, "mat_wood");
	const u16 initialStone = AIBW_ArmStoredMaterial(team, "mat_stone");
	const u16 initialPlanID = rules.get_u16(AIBP_PlanKey(team, "id"));
	const u8 initialPlanStatus = rules.get_u8(AIBP_PlanKey(team, "status"));
	const u16 initialPlanPending = rules.get_u16(AIBP_PlanKey(team, "pending"));
	const u16 initialPlanCompleted = rules.get_u16(AIBP_PlanKey(team, "completed"));
	const string fingerprint = AIBWF_CaptureWorldManifest(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,
		manifestBlobCount, manifestBlobHash, manifestInventoryHash, manifestStrategyHash);
	if (fingerprint == "") return false;

	// Select after capturing the canonical fingerprint. Candidate rejection
	// diagnostics may update rules-local log state, but may not redefine the
	// pre-intervention world identity used to pair control and plan.
	AIBWorldState@ world = AIBS_ObserveWorld(team);
	AIBPlanCandidate@ candidate = AIBS_SelectCandidate(world);
	if (world is null || candidate is null || !AIBW_CaptureCandidateCorridor(rules, home, world, candidate)) return false;

	rules.set_string("aib wave initial fingerprint", fingerprint);
	rules.set_string("aib wave fixture id", fixtureID);
	rules.set_u16("aib wave fixture version", AIBW_FIXTURE_VERSION);
	rules.set_string("aib wave team side", teamSide);
	rules.set_string("aib wave measurement fingerprint", "");
	rules.set_u32("aib wave initial map hash", mapHash);
	rules.set_u32("aib wave initial terrain hash", terrainHash);
	rules.set_u16("aib wave initial map width", map.tilemapwidth);
	rules.set_u16("aib wave initial map height", map.tilemapheight);
	rules.set_u32("aib wave initial solid tiles", solidTiles);
	rules.set_u32("aib wave initial no build hash", noBuildHash);
	rules.set_u32("aib wave initial no build tiles", noBuildTiles);
	rules.set_u32("aib wave initial manifest blob count", manifestBlobCount);
	rules.set_u32("aib wave initial manifest blob hash", manifestBlobHash);
	rules.set_u32("aib wave initial manifest inventory hash", manifestInventoryHash);
	rules.set_u32("aib wave initial manifest strategy hash", manifestStrategyHash);
	rules.set_s32("aib wave initial home x", homeX);
	rules.set_s32("aib wave initial home y", homeY);
	rules.set_s32("aib wave initial enemy home x", enemyHomeX);
	rules.set_s32("aib wave initial enemy home y", enemyHomeY);
	rules.set_u16("aib wave initial ai builders", aiBuilders);
	rules.set_u16("aib wave initial normal ai builders", normalAIBuilderCount);
	rules.set_u16("aib wave initial autobuilders", autoBuilderCount);
	rules.set_u32("aib wave initial ai builder type position hash", aiBuilderTypePositionHash);
	rules.set_u8("aib wave initial autobuilder speed level", autoBuilderSpeedLevel);
	rules.set_u16("aib wave initial friendly units", friendlyUnits);
	rules.set_u16("aib wave initial enemy units", enemyUnits);
	rules.set_u16("aib wave initial trees", treeCount);
	rules.set_u32("aib wave initial tree hash", treeHash);
	rules.set_u16("aib wave initial wood", initialWood);
	rules.set_u16("aib wave initial stone", initialStone);
	rules.set_u16("aib wave initial plan id", initialPlanID);
	rules.set_u8("aib wave initial plan status", initialPlanStatus);
	rules.set_u16("aib wave initial plan pending", initialPlanPending);
	rules.set_u16("aib wave initial plan completed", initialPlanCompleted);
	rules.set_bool("aib wave initial captured", true);
	return true;
}
