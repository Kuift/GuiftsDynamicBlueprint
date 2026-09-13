#define SERVER_ONLY

#include "AIBGymBenchmarkCommon.as";
#include "AIBGymCommon.as";
#include "AIBHomeResourceCommon.as";
#include "AIBManualOrderCommon.as";
#include "AIBWorldFingerprint.as";

const u32 AIBGM_RESOURCE_DURATION_TICKS = 180 * 30;
const u32 AIBGM_MIN_DURATION_TICKS = 10 * 30;
const u32 AIBGM_PROGRESS_RATE = 5 * 30;
const u32 AIBGM_SAMPLE_RATE = 5;
const u32 AIBGM_WARMUP_TICKS = 15;
const u8 AIBGM_MAX_AI_ACTORS = 8;
const u8 AIBGM_WORKER_SPAWN_MIN_HOME_TILES = 3;
const u8 AIBGM_WORKER_SPAWN_MAX_HOME_TILES = 22;
// AI builders have a 7.5-pixel shape radius. Sixteen-pixel centers keep their
// shapes disjoint while fitting four workers around compact official-map tents.
const f32 AIBGM_WORKER_SPAWN_SEPARATION = 16.0f;
const u16 AIBGM_SCHEMA_VERSION = 4;
const u16 AIBGM_FIXTURE_VERSION = 1;
const string AIBGM_SUPPLY_PROBE_TAG = "aib gym forced supply probe";
const u32 AIBGM_SUPPLY_PROBE_SETTLE_TICKS = 2;
const u32 AIBGM_SUPPLY_PROBE_TIMEOUT_TICKS = 600;
const u32 AIBGM_SUPPLY_PROBE_SAMPLE_TICKS = 5;

void AIBGM_ResetSession(CRules@ rules)
{
	if (rules is null) return;
	rules.set_bool("aib gym request", false);
	rules.set_bool("aib gym active", false);
	rules.set_bool("aib gym running", false);
	rules.set_bool("aib gym done", false);
	rules.set_bool("aib gym stop requested", false);
	rules.set_bool("aib gym force base supply route", false);
	rules.set_u32("aib gym force base supply delay ticks", 0);
	rules.set_string("aib gym status", "idle");
	rules.set_string("aib gym failure", "");
}

void onInit(CRules@ this)
{
	if (!isServer()) return;
	AIBGM_ResetSession(this);
}

void onRestart(CRules@ this)
{
	if (!isServer()) return;
	AIBGM_ResetSession(this);
}

CBlob@ AIBGM_NearestTeamBlob(const u8 team, const string &in name, Vec2f from)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	CBlob@ best = null;
	f32 bestDistance = 999999999.0f;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ candidate = blobs[i];
		if (candidate is null || candidate.hasTag("dead") || candidate.getTeamNum() != team) continue;
		const f32 distance = (candidate.getPosition() - from).LengthSquared();
		if (distance < bestDistance)
		{
			bestDistance = distance;
			@best = candidate;
		}
	}
	return best;
}

CBlob@ AIBGM_ResourceHome(const u8 team)
{
	CBlob@ flag = AIBGM_NearestTeamBlob(team, "ctf_flag", Vec2f_zero);
	const Vec2f anchor = flag is null ? Vec2f_zero : flag.getPosition();
	CBlob@ home = AIBGM_NearestTeamBlob(team, "tent", anchor);
	return home is null ? AIBGM_NearestTeamBlob(team, "hall", anchor) : home;
}

CBlob@ AIBGM_EnemyAnchor(const u8 team, Vec2f from)
{
	CBlob@ best = null;
	f32 bestDistance = 999999999.0f;
	string[] names = { "ctf_flag", "tent", "hall" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] blobs;
		getBlobsByName(names[n], @blobs);
		for (uint i = 0; i < blobs.length; i++)
		{
			CBlob@ candidate = blobs[i];
			if (candidate is null || candidate.hasTag("dead") || candidate.getTeamNum() == team || candidate.getTeamNum() >= 100) continue;
			const f32 distance = (candidate.getPosition() - from).LengthSquared();
			if (distance < bestDistance)
			{
				bestDistance = distance;
				@best = candidate;
			}
		}
	}
	return best;
}

bool AIBGM_SpawnClearOfActors(Vec2f position)
{
	CMap@ map = getMap();
	if (map is null) return false;
	CBlob@[] nearby;
	if (!map.getBlobsInRadius(position, 18.0f, @nearby)) return true;
	for (uint i = 0; i < nearby.length; i++)
	{
		CBlob@ blob = nearby[i];
		if (blob is null || blob.hasTag("dead") || blob.isInInventory()) continue;
		const string name = blob.getName();
		if (blob.hasTag("player") || blob.hasTag("building") || name == "tent" || name == "hall" || name == "ctf_flag" || name == "crate") return false;
	}
	return true;
}

class AIBGMSpawnReachability
{
	u16 width;
	u16 height;
	bool seeded;
	array<bool> cells;

	AIBGMSpawnReachability()
	{
		width = 0;
		height = 0;
		seeded = false;
	}
}

bool AIBGM_IsWorkerSpawnRouteCell(CBlob@ home, const int x, const int y)
{
	CMap@ map = getMap();
	if (home is null || map is null || x < 1 || y < 1 || x >= map.tilemapwidth - 1 || y >= map.tilemapheight - 1)
		return false;
	const f32 ts = map.tilesize;
	return AIBR_IsGroundedStoragePoint(home, Vec2f((x + 0.5f) * ts, (y + 0.5f) * ts));
}

AIBGMSpawnReachability@ AIBGM_BuildWorkerSpawnReachability(CBlob@ home)
{
	AIBGMSpawnReachability@ result = AIBGMSpawnReachability();
	CMap@ map = getMap();
	if (home is null || map is null) return result;
	result.width = map.tilemapwidth;
	result.height = map.tilemapheight;
	result.cells.set_length(result.width * result.height);

	const Vec2f homeSpace = map.getTileSpacePosition(home.getPosition());
	const int homeX = Maths::Floor(homeSpace.x);
	const int homeY = Maths::Floor(homeSpace.y);
	int seedX = -1;
	int seedY = -1;
	int seedScore = 2147483647;
	for (int y = Maths::Max(1, homeY - 4); y <= Maths::Min(int(map.tilemapheight) - 2, homeY + 4); y++)
	{
		for (int x = Maths::Max(1, homeX - 4); x <= Maths::Min(int(map.tilemapwidth) - 2, homeX + 4); x++)
		{
			if (!AIBGM_IsWorkerSpawnRouteCell(home, x, y)) continue;
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
	const int seedIndex = seedY * result.width + seedX;
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
				const int nextX = x + stepX;
				const int nextY = y + stepY;
				if (nextX < 1 || nextY < 1 || nextX >= map.tilemapwidth - 1 || nextY >= map.tilemapheight - 1) continue;
				const int index = nextY * result.width + nextX;
				if (result.cells[index] || !AIBGM_IsWorkerSpawnRouteCell(home, nextX, nextY)) continue;
				result.cells[index] = true;
				queueX.push_back(nextX);
				queueY.push_back(nextY);
			}
		}
	}
	return result;
}

bool AIBGM_IsWorkerSpawnReachable(AIBGMSpawnReachability@ reachability, const int x, const int y)
{
	if (reachability is null || !reachability.seeded || x < 0 || y < 0 ||
		x >= reachability.width || y >= reachability.height) return false;
	const int index = y * reachability.width + x;
	return index >= 0 && index < int(reachability.cells.length) && reachability.cells[index];
}

bool AIBGM_WorkerSpawnSeparated(Vec2f candidate, array<Vec2f>@ selected)
{
	if (selected is null) return true;
	for (uint i = 0; i < selected.length; i++)
	{
		if ((selected[i] - candidate).Length() < AIBGM_WORKER_SPAWN_SEPARATION) return false;
	}
	return true;
}

bool AIBGM_SelectWorkerSpawnSet(array<Vec2f>@ candidates, const u8 needed, const uint start,
	array<Vec2f>@ selected)
{
	if (candidates is null || selected is null) return false;
	if (selected.length >= needed) return true;
	if (start >= candidates.length || candidates.length - start < needed - selected.length) return false;
	for (uint i = start; i < candidates.length; i++)
	{
		if (!AIBGM_WorkerSpawnSeparated(candidates[i], selected)) continue;
		selected.push_back(candidates[i]);
		if (AIBGM_SelectWorkerSpawnSet(candidates, needed, i + 1, selected)) return true;
		selected.pop_back();
	}
	return false;
}

bool AIBGM_FindWorkerSpawns(CBlob@ home, const s8 enemyDirection, const u8 requested,
	AIBGMSpawnReachability@ reachability, array<Vec2f>@ selected)
{
	CMap@ map = getMap();
	if (home is null || map is null || reachability is null || !reachability.seeded || selected is null) return false;
	selected.clear();
	const Vec2f space = map.getTileSpacePosition(home.getPosition());
	const int homeX = Maths::Floor(space.x);
	const int homeY = Maths::Floor(space.y);
	const int preferredSide = enemyDirection >= 0 ? -1 : 1;
	array<Vec2f> candidates;
	u16 reachableCount = 0;
	u16 actorBlocked = 0;
	for (int distance = AIBGM_WORKER_SPAWN_MIN_HOME_TILES; distance <= AIBGM_WORKER_SPAWN_MAX_HOME_TILES; distance++)
	{
		for (int sideIndex = 0; sideIndex < 2; sideIndex++)
		{
			const int side = sideIndex == 0 ? preferredSide : -preferredSide;
			for (int yOffset = -5; yOffset <= 7; yOffset++)
			{
				const int x = homeX + side * distance;
				const int y = homeY + yOffset;
				Vec2f candidate = Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize);
				if (!AIBGM_IsWorkerSpawnReachable(reachability, x, y)) continue;
				reachableCount++;
				if (!AIBGM_SpawnClearOfActors(candidate)) { actorBlocked++; continue; }
				candidates.push_back(candidate);
			}
		}
	}

	const bool found = AIBGM_SelectWorkerSpawnSet(@candidates, requested, 0, selected);
	string positions = "";
	for (uint i = 0; i < selected.length; i++)
	{
		if (i > 0) positions += ";";
		positions += selected[i].x + "," + selected[i].y;
	}
	print("[AIBGYM] SPAWN_SET requested=" + requested + " found=" + (found ? "true" : "false") +
		" reachable=" + reachableCount + " actor_blocked=" + actorBlocked +
		" candidates=" + candidates.length + " positions=" + positions);
	return found;
}

u8 AIBGM_ManagedActorCount()
{
	u8 count = 0;
	string[] names = { "aibuilder", "autobuilder" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] blobs;
		getBlobsByName(names[n], @blobs);
		for (uint i = 0; i < blobs.length; i++)
		{
			if (blobs[i] !is null && !blobs[i].hasTag("dead")) count++;
		}
	}
	CBlob@[] wave;
	getBlobsByTag("aib strategy wave unit", @wave);
	for (uint i = 0; i < wave.length; i++)
	{
		if (wave[i] !is null && !wave[i].hasTag("dead")) count++;
	}
	return count;
}

bool AIBGM_CanonicalizeDirectorState(CRules@ rules)
{
	if (rules is null) return false;
	// A normal CTF director heartbeat can provision a worker during the short
	// interval between entering GAME and arming the gym. The benchmark owns all
	// AI actors, so stop every director and remove only those explicitly tagged
	// production-bootstrap workers before capturing the initial fingerprint.
	for (u8 team = 0; team < 8; team++)
	{
		rules.set_u8(AIBP_ModeKey(team), AIBP_StrategyMode::off);
		rules.Sync(AIBP_ModeKey(team), true);
		AIBP_ResetTeamPlanForRound(team);
	}
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	bool removed = false;
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder is null || builder.hasTag("dead") || !builder.hasTag("aib strategy bootstrap worker")) continue;
		builder.server_Die();
		removed = true;
	}
	return removed;
}

void AIBGM_StopWorkers(CRules@ rules)
{
	if (rules is null) return;
	CBlob@[] workers;
	getBlobsByTag(AIBGM_WORKER_TAG, @workers);
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker is null || worker.hasTag("dead") || worker.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch")) continue;
		AIBM_ClearNavigationIntent(worker);
		worker.set_Vec2f(AIBM_STONE_SURFACE_MEMORY_KEY, Vec2f_zero);
		worker.set_u8("ai builder state", AIBM_STATE_IDLE);
		worker.set_bool("ai builder job active", false);
		worker.Sync("ai builder state", true);
		worker.Sync("ai builder job active", true);
	}
}

void AIBGM_EmitAbort(CRules@ rules, const string &in reason)
{
	if (rules is null) return;
	const string runID = rules.get_string("aib gym run id");
	const string record = "[AIBGYMR] schema=" + AIBGM_SCHEMA_VERSION + " status=abort run=" + runID + " reason=" + reason;
	print(record);
	tcpr(record);
	tcpr("AIBGYM|ABORT|run=" + runID + "|reason=" + reason);
	AIBGM_StopWorkers(rules);
	rules.set_bool("aib gym request", false);
	rules.set_bool("aib gym active", false);
	rules.set_bool("aib gym running", false);
	rules.set_bool("aib gym done", true);
	rules.set_string("aib gym status", "abort:" + reason);
	rules.set_string("aib gym failure", reason);
}

bool AIBGM_CaptureInitialState(CRules@ rules, CBlob@ home, CBlob@ enemy)
{
	CMap@ map = getMap();
	if (rules is null || home is null || enemy is null || map is null) return false;
	u32 terrainHash = 0, solidTiles = 0, noBuildHash = 0, noBuildTiles = 0;
	u32 blobCount = 0, blobHash = 0, inventoryHash = 0, strategyHash = 0;
	const string fingerprint = AIBWF_CaptureWorldManifest(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,
		blobCount, blobHash, inventoryHash, strategyHash);
	if (fingerprint == "") return false;
	const u32 mapHash = u32(map.getMapName().getHash());
	const s32 homeX = Maths::Floor(home.getPosition().x / map.tilesize);
	const s32 homeY = Maths::Floor(home.getPosition().y / map.tilesize);
	const s32 enemyX = Maths::Floor(enemy.getPosition().x / map.tilesize);
	rules.set_string("aib gym fixture id", "map_" + mapHash + "_" + map.tilemapwidth + "x" + map.tilemapheight);
	rules.set_u16("aib gym fixture version", AIBGM_FIXTURE_VERSION);
	rules.set_string("aib gym team side", homeX <= enemyX ? "left" : "right");
	rules.set_string("aib gym initial fingerprint", fingerprint);
	rules.set_u32("aib gym map hash", mapHash);
	rules.set_u32("aib gym initial terrain hash", terrainHash);
	rules.set_u16("aib gym map width", map.tilemapwidth);
	rules.set_u16("aib gym map height", map.tilemapheight);
	rules.set_s32("aib gym home x", homeX);
	rules.set_s32("aib gym home y", homeY);
	rules.set_u16("aib gym initial wood", AIBR_CountAccessibleHomeMaterial(home, "mat_wood"));
	rules.set_u16("aib gym initial stone", AIBR_CountAccessibleHomeMaterial(home, "mat_stone"));
	rules.set_u16("aib gym initial gold", AIBR_CountAccessibleHomeMaterial(home, "mat_gold"));
	return true;
}

bool AIBGM_PrepareResourceRun(CRules@ rules)
{
	if (rules is null) return false;
	const u8 team = rules.get_u8("aib gym team");
	const u8 requestedBuilders = rules.get_u8("aib gym builder count");
	const string order = rules.get_string("aib gym resource order");
	if (team >= 8 || (requestedBuilders != 1 && requestedBuilders != 4) ||
		(order != "wood" && order != "stone" && order != "mixed") ||
		(order == "mixed" && requestedBuilders != 4))
	{
		AIBGM_EmitAbort(rules, "invalid_request");
		return false;
	}
	if (AIBGM_CanonicalizeDirectorState(rules))
	{
		// Blob death is finalized after this rules callback. Retry setup on the
		// next tick instead of diagnosing our own just-issued cleanup as outside
		// contamination.
		rules.set_bool("aib gym request", true);
		rules.set_string("aib gym status", "canonicalizing_director_workers");
		return false;
	}
	if (rules.get_bool("aib wave running") || AIBGM_ManagedActorCount() != 0 || requestedBuilders > AIBGM_MAX_AI_ACTORS)
	{
		AIBGM_EmitAbort(rules, "contaminated_ai_actors");
		return false;
	}
	CBlob@ home = AIBGM_ResourceHome(team);
	CBlob@ enemy = home is null ? null : AIBGM_EnemyAnchor(team, home.getPosition());
	if (home is null || enemy is null)
	{
		AIBGM_EmitAbort(rules, "missing_team_homes");
		return false;
	}

	// Resource throughput is an explicit manual-order benchmark. Director work
	// was canonicalized above so construction policy cannot silently change what
	// this episode measures.
	if (!AIBGM_CaptureInitialState(rules, home, enemy))
	{
		AIBGM_EmitAbort(rules, "initial_fingerprint_failed");
		return false;
	}

	const s8 enemyDirection = enemy.getPosition().x >= home.getPosition().x ? 1 : -1;
	AIBGMSpawnReachability@ spawnReachability = AIBGM_BuildWorkerSpawnReachability(home);
	if (spawnReachability is null || !spawnReachability.seeded)
	{
		AIBGM_EmitAbort(rules, "no_home_connected_spawn_region");
		return false;
	}
	array<Vec2f> spawns;
	if (!AIBGM_FindWorkerSpawns(home, enemyDirection, requestedBuilders, spawnReachability, @spawns))
	{
		AIBGM_EmitAbort(rules, "no_safe_spawn_set");
		return false;
	}
	for (u8 slot = 0; slot < requestedBuilders; slot++)
	{
		Vec2f spawn = spawns[slot];
		CBlob@ worker = server_CreateBlob("aibuilder", team, spawn);
		if (worker is null)
		{
			AIBGM_EmitAbort(rules, "worker_spawn_failed_" + slot);
			return false;
		}
		worker.Tag(AIBGM_WORKER_TAG);
		worker.set_u32(AIBGM_WORKER_EPOCH_KEY, rules.get_u32("aib gym epoch"));
		worker.set_u8(AIBGM_WORKER_SLOT_KEY, slot);
		worker.set_bool("ai builder starter materials granted", true);
		worker.set_Vec2f("aib gym benchmark spawn", spawn);
		worker.set_Vec2f("aib gym benchmark last position", spawn);
		worker.set_f32("aib gym benchmark travel", 0.0f);
		worker.set_u32("aib gym benchmark idle", 0);
		rules.set_u32(AIBGM_SlotMetricKey(slot, "wood"), 0);
		rules.set_u32(AIBGM_SlotMetricKey(slot, "stone"), 0);
		rules.set_u32(AIBGM_SlotMetricKey(slot, "gold"), 0);
		rules.set_u32(AIBGM_SlotMetricKey(slot, "collected wood"), 0);
		rules.set_u32(AIBGM_SlotMetricKey(slot, "collected stone"), 0);
		rules.set_u32(AIBGM_SlotMetricKey(slot, "collected gold"), 0);
	}

	rules.set_netid("aib gym home", home.getNetworkID());
	rules.set_u32("aib gym warmup until", getGameTime() + AIBGM_WARMUP_TICKS);
	rules.set_bool("aib gym active", true);
	rules.set_bool("aib gym running", false);
	rules.set_bool("aib gym done", false);
	rules.set_string("aib gym status", "warming_up");
	return true;
}

void AIBGM_StartOrders(CRules@ rules)
{
	if (rules is null) return;
	CBlob@[] workers;
	getBlobsByTag(AIBGM_WORKER_TAG, @workers);
	u8 ordered = 0;
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker is null || worker.hasTag("dead") || worker.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch")) continue;
		const u8 slot = worker.get_u8(AIBGM_WORKER_SLOT_KEY);
		const string requested = rules.get_string("aib gym resource order");
		const string order = requested == "mixed" ? (slot % 2 == 0 ? "wood" : "stone") : requested;
		CBitStream params;
		worker.SendCommand(worker.getCommandID(order == "wood" ? "ai harvest wood" : "ai mine stone"), params);
		ordered++;
	}
	if (ordered != rules.get_u8("aib gym builder count"))
	{
		AIBGM_EmitAbort(rules, "worker_missing_before_order");
		return;
	}
	rules.set_u32("aib gym start tick", getGameTime());
	rules.set_u32("aib gym next progress", getGameTime() + AIBGM_PROGRESS_RATE);
	rules.set_bool("aib gym running", true);
	rules.set_string("aib gym status", "running");
	const string runID = rules.get_string("aib gym run id");
	const string marker = "AIBGYM|START|run=" + runID + "|metric=" + rules.get_string("aib gym metric") +
		"|fixture=" + rules.get_string("aib gym fixture id") + "|side=" + rules.get_string("aib gym team side") +
		"|builders=" + rules.get_u8("aib gym builder count") + "|order=" + rules.get_string("aib gym resource order") +
		"|duration=" + rules.get_u32("aib gym duration ticks");
	print("[AIBGYM] " + marker);
	tcpr(marker);
}

void AIBGM_SampleWorkers(CRules@ rules)
{
	if (rules is null || getGameTime() % AIBGM_SAMPLE_RATE != 0) return;
	CBlob@[] workers;
	getBlobsByTag(AIBGM_WORKER_TAG, @workers);
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker is null || worker.hasTag("dead") || worker.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch")) continue;
		Vec2f last = worker.get_Vec2f("aib gym benchmark last position");
		if (last != Vec2f_zero) worker.set_f32("aib gym benchmark travel", worker.get_f32("aib gym benchmark travel") + (worker.getPosition() - last).Length());
		worker.set_Vec2f("aib gym benchmark last position", worker.getPosition());
		if (worker.get_u8("ai builder state") == AIBM_STATE_IDLE)
			worker.set_u32("aib gym benchmark idle", worker.get_u32("aib gym benchmark idle") + AIBGM_SAMPLE_RATE);
	}
}

void AIBGM_EmitProgress(CRules@ rules)
{
	if (rules is null || getGameTime() < rules.get_u32("aib gym next progress")) return;
	rules.set_u32("aib gym next progress", getGameTime() + AIBGM_PROGRESS_RATE);
	const u32 elapsed = getGameTime() - rules.get_u32("aib gym start tick");
	const u32 collected = rules.get_u32("aib gym collected wood") + rules.get_u32("aib gym collected stone") + rules.get_u32("aib gym collected gold");
	const u32 delivered = rules.get_u32("aib gym delivered wood") + rules.get_u32("aib gym delivered stone") + rules.get_u32("aib gym delivered gold");
	tcpr("AIBGYM|PROGRESS|run=" + rules.get_string("aib gym run id") + "|elapsed=" + elapsed + "|collected=" + collected + "|delivered=" + delivered + "|deaths=" + rules.get_u8("aib gym deaths"));
}

bool AIBGM_RestoreFlagPickedUpByWorker(CRules@ rules)
{
	if (rules is null) return false;
	CBlob@[] workers;
	getBlobsByTag(AIBGM_WORKER_TAG, @workers);
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker is null || worker.hasTag("dead") ||
			worker.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch")) continue;
		CBlob@ flag = worker.getCarriedBlob();
		if (flag is null || flag.getName() != "ctf_flag") continue;

		flag.server_DetachFrom(worker);
		bool restored = false;
		CBlob@[] bases;
		getBlobsByName("flag_base", @bases);
		for (uint b = 0; b < bases.length; b++)
		{
			CBlob@ base = bases[b];
			if (base is null || base.hasTag("dead") || base.get_netid("flag id") != flag.getNetworkID()) continue;
			base.server_AttachTo(flag, "FLAG");
			restored = true;
			break;
		}
		const string marker = "AIBGYM|CONTAMINATION|run=" + rules.get_string("aib gym run id") +
			"|kind=worker_flag_pickup|slot=" + worker.get_u8(AIBGM_WORKER_SLOT_KEY) +
			"|worker=" + worker.getNetworkID() + "|flag=" + flag.getNetworkID() +
			"|restored=" + (restored ? "true" : "false");
		print("[AIBGYM] " + marker);
		tcpr(marker);
		return true;
	}
	return false;
}

void AIBGM_FinishResourceRun(CRules@ rules, const bool complete, const string &in reason)
{
	if (rules is null) return;
	CBlob@ home = getBlobByNetworkID(rules.get_netid("aib gym home"));
	if (home is null || home.hasTag("dead"))
	{
		AIBGM_EmitAbort(rules, "home_lost");
		return;
	}
	const u32 elapsed = getGameTime() - rules.get_u32("aib gym start tick");
	const u32 wood = rules.get_u32("aib gym delivered wood");
	const u32 stone = rules.get_u32("aib gym delivered stone");
	const u32 gold = rules.get_u32("aib gym delivered gold");
	const u32 delivered = wood + stone + gold;
	const u32 collectedWood = rules.get_u32("aib gym collected wood");
	const u32 collectedStone = rules.get_u32("aib gym collected stone");
	const u32 collectedGold = rules.get_u32("aib gym collected gold");
	const u32 collected = collectedWood + collectedStone + collectedGold;
	const s32 stockWood = s32(AIBR_CountAccessibleHomeMaterial(home, "mat_wood")) - s32(rules.get_u16("aib gym initial wood"));
	const s32 stockStone = s32(AIBR_CountAccessibleHomeMaterial(home, "mat_stone")) - s32(rules.get_u16("aib gym initial stone"));
	const s32 stockGold = s32(AIBR_CountAccessibleHomeMaterial(home, "mat_gold")) - s32(rules.get_u16("aib gym initial gold"));
	f32 travel = 0.0f;
	u32 idle = 0;
	u16 failureFlags = 0;
	u8 live = 0;
	CBlob@[] workers;
	getBlobsByTag(AIBGM_WORKER_TAG, @workers);
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker is null || worker.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch")) continue;
		if (!worker.hasTag("dead")) live++;
		travel += worker.get_f32("aib gym benchmark travel");
		idle += worker.get_u32("aib gym benchmark idle");
		failureFlags |= worker.get_u16("aib gym failure flags");
	}
	const string status = complete ? "result" : "censored";
	const string record = "[AIBGYMR] schema=" + AIBGM_SCHEMA_VERSION + " status=" + status +
		" run=" + rules.get_string("aib gym run id") + " variant=" + rules.get_string("aib gym variant") +
		" metric=" + rules.get_string("aib gym metric") + " fixture_id=" + rules.get_string("aib gym fixture id") +
		" fixture_version=" + rules.get_u16("aib gym fixture version") + " team=" + rules.get_u8("aib gym team") +
		" team_side=" + rules.get_string("aib gym team side") + " map_hash=" + rules.get_u32("aib gym map hash") +
		" map_width=" + rules.get_u16("aib gym map width") + " map_height=" + rules.get_u16("aib gym map height") +
		" initial_terrain_hash=" + rules.get_u32("aib gym initial terrain hash") +
		" initial_fingerprint=" + rules.get_string("aib gym initial fingerprint") +
		" builders=" + rules.get_u8("aib gym builder count") + " live_builders=" + live +
		" order=" + rules.get_string("aib gym resource order") + " duration=" + rules.get_u32("aib gym duration ticks") +
		" elapsed=" + elapsed + " collected_wood=" + collectedWood + " collected_stone=" + collectedStone +
		" collected_gold=" + collectedGold + " collected_total=" + collected +
		" delivered_wood=" + wood + " delivered_stone=" + stone + " delivered_gold=" + gold +
		" delivered_total=" + delivered + " stock_delta_wood=" + stockWood + " stock_delta_stone=" + stockStone +
		" stock_delta_gold=" + stockGold + " deaths=" + rules.get_u8("aib gym deaths") + " failure_flags=" + failureFlags +
		" idle_ticks=" + idle + " travel_px=" + travel + " reason=" + reason;
	print(record);
	tcpr(record);
	for (u8 slot = 0; slot < rules.get_u8("aib gym builder count"); slot++)
	{
		const u32 slotWood = rules.get_u32(AIBGM_SlotMetricKey(slot, "wood"));
		const u32 slotStone = rules.get_u32(AIBGM_SlotMetricKey(slot, "stone"));
		const u32 slotGold = rules.get_u32(AIBGM_SlotMetricKey(slot, "gold"));
		const u32 slotCollectedWood = rules.get_u32(AIBGM_SlotMetricKey(slot, "collected wood"));
		const u32 slotCollectedStone = rules.get_u32(AIBGM_SlotMetricKey(slot, "collected stone"));
		const u32 slotCollectedGold = rules.get_u32(AIBGM_SlotMetricKey(slot, "collected gold"));
		const string workerRecord = "[AIBGYMB] schema=" + AIBGM_SCHEMA_VERSION + " run=" + rules.get_string("aib gym run id") + " slot=" + slot +
			" collected_wood=" + slotCollectedWood + " collected_stone=" + slotCollectedStone + " collected_gold=" + slotCollectedGold +
			" collected_total=" + (slotCollectedWood + slotCollectedStone + slotCollectedGold) +
			" delivered_wood=" + slotWood + " delivered_stone=" + slotStone + " delivered_gold=" + slotGold +
			" delivered_total=" + (slotWood + slotStone + slotGold);
		print(workerRecord);
		tcpr(workerRecord);
	}
	tcpr("AIBGYM|RESULT|run=" + rules.get_string("aib gym run id") + "|status=" + status + "|metric=" +
		rules.get_string("aib gym metric") + "|collected=" + collected + "|delivered=" + delivered + "|elapsed=" + elapsed + "|deaths=" +
		rules.get_u8("aib gym deaths") + "|failures=" + failureFlags + "|reason=" + reason);
	AIBGM_StopWorkers(rules);
	rules.set_bool("aib gym active", false);
	rules.set_bool("aib gym running", false);
	rules.set_bool("aib gym done", true);
	rules.set_bool("aib gym stop requested", false);
	rules.set_string("aib gym status", status + ":delivered=" + delivered);
}

string AIBGM_SupplyProbePos(Vec2f position)
{
	return Maths::Round(position.x) + "," + Maths::Round(position.y);
}

CBlob@ AIBGM_GetSupplyProbeShop(const u8 team)
{
	CBlob@ best = null;
	u16 bestID = 65535;
	CBlob@[] shops;
	getBlobsByName("buildershop", @shops);
	for (uint i = 0; i < shops.length; i++)
	{
		CBlob@ shop = shops[i];
		if (shop is null || shop.hasTag("dead") || shop.getTeamNum() != team ||
			!shop.hasTag("aibuilder built storage shop")) continue;
		const u16 id = shop.getNetworkID();
		if (id >= bestID) continue;
		bestID = id;
		@best = shop;
	}
	return best;
}

u32 AIBGM_RetypeSupplyProbeOre()
{
	CMap@ map = getMap();
	if (map is null) return 0;
	u32 changed = 0;
	for (u16 y = 0; y < map.tilemapheight; y++)
	{
		for (u16 x = 0; x < map.tilemapwidth; x++)
		{
			Vec2f position = Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize);
			const TileType type = map.getTile(position).type;
			if (map.isTileBedrock(type) ||
				(!map.isTileStone(type) && !map.isTileThickStone(type) && !map.isTileGold(type))) continue;
			map.server_SetTile(position, CMap::tile_ground);
			changed++;
		}
	}
	return changed;
}

u16 AIBGM_RemoveSupplyProbeSources(const u8 team)
{
	u16 removed = 0;
	CBlob@[] stone;
	getBlobsByName("mat_stone", @stone);
	for (uint i = 0; i < stone.length; i++)
	{
		CBlob@ material = stone[i];
		if (material is null || material.hasTag("dead") || material.isInInventory() || material.isAttached()) continue;
		material.server_Die();
		removed++;
	}
	CBlob@[] quarries;
	getBlobsByName("quarry", @quarries);
	for (uint i = 0; i < quarries.length; i++)
	{
		CBlob@ quarry = quarries[i];
		if (quarry is null || quarry.hasTag("dead") || quarry.getTeamNum() != team) continue;
		quarry.server_Die();
		removed++;
	}
	return removed;
}

void AIBGM_SuppressSupplyProbeQuarries(CRules@ rules)
{
	if (rules is null) return;
	const u32 retryUntil = getGameTime() + AIBGM_SUPPLY_PROBE_TIMEOUT_TICKS + 300;
	CBlob@[] workers;
	getBlobsByTag(AIBGM_WORKER_TAG, @workers);
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker is null || worker.hasTag("dead") ||
			worker.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch")) continue;
		worker.set_u32("ai builder next quarry site search", retryUntil);
	}
}

u16 AIBGM_ClearSupplyProbeResources(CBlob@ worker)
{
	if (worker is null) return 0;
	u16 removed = 0;
	CInventory@ inventory = worker.getInventory();
	string[] names = { "mat_wood", "mat_stone", "mat_gold" };
	if (inventory !is null)
	{
		for (uint i = 0; i < names.length; i++)
		{
			const u16 count = inventory.getCount(names[i]);
			if (count == 0) continue;
			inventory.server_RemoveItems(names[i], count);
			removed += count;
		}
	}
	CBlob@ carried = worker.getCarriedBlob();
	if (carried !is null && carried.hasTag("material"))
	{
		removed += carried.getQuantity();
		carried.server_Die();
	}
	return removed;
}

bool AIBGM_BeginSupplyProbe(CRules@ rules, CBlob@ shop)
{
	if (rules is null || shop is null) return false;
	CBlob@ probe = null;
	CBlob@[] workers;
	getBlobsByTag(AIBGM_WORKER_TAG, @workers);
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker is null || worker.hasTag("dead") ||
			worker.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch") ||
			worker.get_u8(AIBGM_WORKER_SLOT_KEY) % 2 == 0) continue;
		if (probe is null || worker.getNetworkID() < probe.getNetworkID()) @probe = worker;
	}
	if (probe is null) return false;

	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker is null || worker.hasTag("dead") || worker is probe ||
			worker.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch") ||
			worker.get_u8(AIBGM_WORKER_SLOT_KEY) % 2 == 0) continue;
		AIBM_ClearNavigationIntent(worker);
		worker.set_u8("ai builder state", AIBM_STATE_IDLE);
		worker.set_bool("ai builder job active", false);
		worker.Sync("ai builder state", true);
		worker.Sync("ai builder job active", true);
	}

	AIBM_ClearNavigationIntent(probe);
	const u16 removed = AIBGM_ClearSupplyProbeResources(probe);
	Vec2f spawn = probe.get_Vec2f("aib gym benchmark spawn");
	if (spawn != Vec2f_zero)
	{
		probe.setPosition(spawn);
		probe.setVelocity(Vec2f_zero);
	}
	probe.Tag(AIBGM_SUPPLY_PROBE_TAG);
	probe.set_u8("ai builder job", AIBM_JOB_STONE);
	probe.set_u8("ai builder state", AIBM_STATE_FIND_STONE);
	probe.set_bool("ai builder job active", true);
	probe.set_u32("ai builder next quarry site search", getGameTime() + AIBGM_SUPPLY_PROBE_TIMEOUT_TICKS + 300);
	probe.set_u32("ai builder next stone supply", getGameTime() + AIBGM_SUPPLY_PROBE_TIMEOUT_TICKS + 300);
	probe.Sync("ai builder job", true);
	probe.Sync("ai builder state", true);
	probe.Sync("ai builder job active", true);

	const f32 distance = (shop.getPosition() - probe.getPosition()).Length();
	rules.set_netid("aib gym supply probe worker", probe.getNetworkID());
	rules.set_u32("aib gym supply probe start", getGameTime());
	rules.set_u32("aib gym supply probe next sample", getGameTime());
	rules.set_f32("aib gym supply probe best distance", distance);
	rules.set_u8("aib gym supply probe stage", 2);
	tcpr("AIBGYM|SUPPLY_PROBE|BEGIN|worker=" + probe.getNetworkID() + "|shop=" + shop.getNetworkID() +
		"|start=" + AIBGM_SupplyProbePos(probe.getPosition()) + "|target=" + AIBGM_SupplyProbePos(shop.getPosition()) +
		"|distance=" + distance + "|removed_inventory=" + removed);
	return true;
}

void AIBGM_EmitSupplyProbeSample(CRules@ rules, CBlob@ probe, CBlob@ shop)
{
	if (rules is null || probe is null || shop is null || getGameTime() < rules.get_u32("aib gym supply probe next sample")) return;
	rules.set_u32("aib gym supply probe next sample", getGameTime() + AIBGM_SUPPLY_PROBE_SAMPLE_TICKS);
	BrainPath@ path;
	probe.get("ai builder brain path", @path);
	const uint lowCount = path is null ? 0 : path.path.length;
	const uint waypointCount = path is null ? 0 : path.waypoints.length;
	Vec2f low0 = lowCount == 0 ? Vec2f_zero : path.path[0];
	Vec2f way0 = waypointCount == 0 ? Vec2f_zero : path.waypoints[0];
	Vec2f wayLast = waypointCount == 0 ? Vec2f_zero : path.waypoints[waypointCount - 1];
	u8 keyMask = 0;
	if (probe.isKeyPressed(key_left)) keyMask |= 1;
	if (probe.isKeyPressed(key_right)) keyMask |= 2;
	if (probe.isKeyPressed(key_up)) keyMask |= 4;
	if (probe.isKeyPressed(key_down)) keyMask |= 8;
	tcpr("AIBGYM|SUPPLY_PATH|t=" + getGameTime() + "|worker=" + probe.getNetworkID() +
		"|state=" + probe.get_u8("ai builder state") + "|pos=" + AIBGM_SupplyProbePos(probe.getPosition()) +
		"|destination=" + AIBGM_SupplyProbePos(probe.get_Vec2f("ai builder destination")) +
		"|target=" + AIBGM_SupplyProbePos(shop.getPosition()) + "|low=" + lowCount + "|waypoints=" + waypointCount +
		"|low0=" + AIBGM_SupplyProbePos(low0) + "|way0=" + AIBGM_SupplyProbePos(way0) +
		"|way_last=" + AIBGM_SupplyProbePos(wayLast) + "|tail_gap=" + (wayLast - shop.getPosition()).Length() +
		"|distance=" + (shop.getPosition() - probe.getPosition()).Length() + "|keys=" + keyMask);
}

bool AIBGM_UpdateForcedSupplyProbe(CRules@ rules)
{
	if (rules is null || !rules.get_bool("aib gym force base supply route")) return false;
	const u8 team = rules.get_u8("aib gym team");
	const u8 stage = rules.get_u8("aib gym supply probe stage");
	if (stage == 0)
	{
		const u32 runElapsed = getGameTime() - rules.get_u32("aib gym start tick");
		const u32 delayTicks = rules.get_u32("aib gym force base supply delay ticks");
		if (runElapsed < delayTicks) return false;
		CBlob@ shop = AIBGM_GetSupplyProbeShop(team);
		if (shop is null) return false;
		AIBGM_SuppressSupplyProbeQuarries(rules);
		const u32 retyped = AIBGM_RetypeSupplyProbeOre();
		const u16 removed = AIBGM_RemoveSupplyProbeSources(team);
		rules.set_netid("aib gym supply probe shop", shop.getNetworkID());
		rules.set_u32("aib gym supply probe settle until", getGameTime() + AIBGM_SUPPLY_PROBE_SETTLE_TICKS);
		rules.set_u8("aib gym supply probe stage", 1);
		tcpr("AIBGYM|SUPPLY_PROBE|SANITIZE|shop=" + shop.getNetworkID() + "|target=" +
			AIBGM_SupplyProbePos(shop.getPosition()) + "|run_elapsed=" + runElapsed + "|delay=" + delayTicks +
			"|ore_retyped=" + retyped + "|sources_removed=" + removed);
		return false;
	}

	AIBGM_SuppressSupplyProbeQuarries(rules);
	AIBGM_RemoveSupplyProbeSources(team);
	CBlob@ shop = getBlobByNetworkID(rules.get_netid("aib gym supply probe shop"));
	if (shop is null || shop.hasTag("dead"))
	{
		tcpr("AIBGYM|SUPPLY_PROBE|RESULT|outcome=shop_lost");
		AIBGM_FinishResourceRun(rules, true, "supply_probe_shop_lost");
		return true;
	}
	if (stage == 1)
	{
		if (getGameTime() < rules.get_u32("aib gym supply probe settle until")) return false;
		if (!AIBGM_BeginSupplyProbe(rules, shop)) return false;
		return false;
	}

	CBlob@ probe = getBlobByNetworkID(rules.get_netid("aib gym supply probe worker"));
	if (probe is null || probe.hasTag("dead"))
	{
		tcpr("AIBGYM|SUPPLY_PROBE|RESULT|outcome=worker_lost");
		AIBGM_FinishResourceRun(rules, true, "supply_probe_worker_lost");
		return true;
	}
	const f32 distance = (shop.getPosition() - probe.getPosition()).Length();
	if (distance < rules.get_f32("aib gym supply probe best distance"))
		rules.set_f32("aib gym supply probe best distance", distance);
	AIBGM_EmitSupplyProbeSample(rules, probe, shop);
	const u32 elapsed = getGameTime() - rules.get_u32("aib gym supply probe start");
	if (distance <= 34.0f)
	{
		tcpr("AIBGYM|SUPPLY_PROBE|RESULT|outcome=reached|elapsed=" + elapsed + "|worker=" + probe.getNetworkID() +
			"|pos=" + AIBGM_SupplyProbePos(probe.getPosition()) + "|target=" + AIBGM_SupplyProbePos(shop.getPosition()) +
			"|distance=" + distance + "|best=" + rules.get_f32("aib gym supply probe best distance"));
		AIBGM_FinishResourceRun(rules, true, "supply_probe_reached");
		return true;
	}
	if (elapsed < AIBGM_SUPPLY_PROBE_TIMEOUT_TICKS) return false;
	tcpr("AIBGYM|SUPPLY_PROBE|RESULT|outcome=timeout|elapsed=" + elapsed + "|worker=" + probe.getNetworkID() +
		"|pos=" + AIBGM_SupplyProbePos(probe.getPosition()) + "|target=" + AIBGM_SupplyProbePos(shop.getPosition()) +
		"|distance=" + distance + "|best=" + rules.get_f32("aib gym supply probe best distance"));
	AIBGM_FinishResourceRun(rules, true, "supply_probe_timeout");
	return true;
}

void AIBGM_BeginRequest(CRules@ rules)
{
	if (rules is null) return;
	rules.set_bool("aib gym request", false);
	rules.set_bool("aib gym done", false);
	rules.set_string("aib gym failure", "");
	rules.set_u32("aib gym epoch", rules.get_u32("aib gym epoch") + 1);
	rules.set_u32("aib gym delivered wood", 0);
	rules.set_u32("aib gym delivered stone", 0);
	rules.set_u32("aib gym delivered gold", 0);
	rules.set_u32("aib gym collected wood", 0);
	rules.set_u32("aib gym collected stone", 0);
	rules.set_u32("aib gym collected gold", 0);
	rules.set_u8("aib gym deaths", 0);
	rules.set_u8("aib gym supply probe stage", 0);
	rules.set_netid("aib gym supply probe shop", 0);
	rules.set_netid("aib gym supply probe worker", 0);
	if (rules.get_string("aib gym run id") == "") rules.set_string("aib gym run id", "run_" + rules.get_u32("aib gym epoch"));
	if (rules.get_string("aib gym variant") == "") rules.set_string("aib gym variant", "manual");
	u32 duration = rules.get_u32("aib gym duration ticks");
	if (duration < AIBGM_MIN_DURATION_TICKS) duration = AIBGM_RESOURCE_DURATION_TICKS;
	rules.set_u32("aib gym duration ticks", duration);
	rules.set_string("aib gym metric", duration == AIBGM_RESOURCE_DURATION_TICKS ? "resource_collection_180s" : "resource_collection_smoke");
	AIBGM_PrepareResourceRun(rules);
}

void onTick(CRules@ this)
{
	if (!isServer()) return;
	if (this.get_bool("aib gym request") && !this.get_bool("aib gym active"))
	{
		if (!this.isMatchRunning())
		{
			this.set_string("aib gym status", "waiting_for_live_match");
			return;
		}
		AIBGM_BeginRequest(this);
	}
	if (!this.get_bool("aib gym active")) return;
	if (this.get_bool("aib gym stop requested"))
	{
		if (this.get_bool("aib gym running")) AIBGM_FinishResourceRun(this, false, "operator_stop");
		else AIBGM_EmitAbort(this, "operator_stop_before_start");
		return;
	}
	if (!this.get_bool("aib gym running"))
	{
		if (getGameTime() >= this.get_u32("aib gym warmup until")) AIBGM_StartOrders(this);
		return;
	}
	if (AIBGM_UpdateForcedSupplyProbe(this)) return;
	CMap@ map = getMap();
	if (map is null || u32(map.getMapName().getHash()) != this.get_u32("aib gym map hash"))
	{
		AIBGM_EmitAbort(this, "map_changed");
		return;
	}
	// Ordinary builders carry the player tag, so CTF collision code can attach
	// an enemy flag during a resource route. Restore it immediately and reject
	// the episode instead of silently scoring a flag run as resource throughput.
	if (AIBGM_RestoreFlagPickedUpByWorker(this))
	{
		AIBGM_EmitAbort(this, "gym_worker_picked_flag");
		return;
	}
	AIBGM_SampleWorkers(this);
	AIBGM_EmitProgress(this);
	const u32 elapsed = getGameTime() - this.get_u32("aib gym start tick");
	if (elapsed >= this.get_u32("aib gym duration ticks")) AIBGM_FinishResourceRun(this, true, "duration_complete");
}

void onBlobDie(CRules@ this, CBlob@ blob)
{
	if (!isServer() || blob is null || !this.get_bool("aib gym active") || !blob.hasTag(AIBGM_WORKER_TAG)) return;
	if (blob.get_u32(AIBGM_WORKER_EPOCH_KEY) != this.get_u32("aib gym epoch")) return;
	this.set_u8("aib gym deaths", this.get_u8("aib gym deaths") + 1);
}
