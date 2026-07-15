#define SERVER_ONLY

#include "AIBStrategicJobs.as";
#include "AIBWorldFingerprint.as";

// Map-scoped physical infrastructure benchmark.  This deliberately uses the
// production planner, plan publication, and Autobuilder executor.  The only
// synthetic part is a brain-disabled, player-shaped builder used to prove that
// a same-team body can enter through the rear/home-side door and leave through
// the front door after construction is physically complete.

const u16 AIBI_SCHEMA_VERSION = 1;
const u16 AIBI_FIXTURE_VERSION = 1;
const u8 AIBI_TOTAL_AI_LIMIT = 8;
const u32 AIBI_PROBE_SETTLE_TICKS = 15;
const u32 AIBI_PROBE_TIMEOUT_TICKS = 300;
const u32 AIBI_PROBE_STALL_TICKS = 20;
const u32 AIBI_PROBE_JUMP_TICKS = 12;
const string AIBI_EXECUTOR_TAG = "aib infrastructure executor";
const string AIBI_PROBE_TAG = "aib infrastructure ally probe";

void AIBI_Reset(CRules@ rules)
{
	if (rules is null) return;
	rules.set_bool("aib infrastructure active", false);
	rules.set_bool("aib infrastructure request", false);
	rules.set_bool("aib infrastructure stop requested", false);
	rules.set_string("aib infrastructure status", "idle");
	rules.set_string("aib infrastructure phase", "idle");
	rules.set_u32("aib infrastructure readiness deadline", 0);
}

void onInit(CRules@ this)
{
	if (isServer()) AIBI_Reset(this);
}

void onRestart(CRules@ this)
{
	if (isServer()) AIBI_Reset(this);
}

string AIBI_Bool(const bool value)
{
	return value ? "true" : "false";
}

void AIBI_EmitLine(const string &in line)
{
	print(line);
	tcpr(line);
}

void AIBI_StopTaggedActors()
{
	CBlob@[] all;
	getBlobs(@all);
	for (uint i = 0; i < all.length; i++)
	{
		CBlob@ blob = all[i];
		if (blob is null || blob.hasTag("dead")) continue;
		if (!blob.hasTag(AIBI_EXECUTOR_TAG) && !blob.hasTag(AIBI_PROBE_TAG)) continue;
		blob.setKeyPressed(key_left, false);
		blob.setKeyPressed(key_right, false);
		blob.setKeyPressed(key_up, false);
		blob.setKeyPressed(key_down, false);
		blob.setKeyPressed(key_action1, false);
		blob.server_Die();
	}
}

u8 AIBI_ExistingManagedActors()
{
	u8 count = 0;
	CBlob@[] all;
	getBlobs(@all);
	for (uint i = 0; i < all.length; i++)
	{
		CBlob@ blob = all[i];
		if (blob is null || blob.hasTag("dead")) continue;
		const string name = blob.getName();
		if (name == "aibuilder" || name == "autobuilder" || blob.hasTag("aib strategy wave unit") ||
			blob.hasTag(AIBI_EXECUTOR_TAG) || blob.hasTag(AIBI_PROBE_TAG)) count++;
	}
	return count;
}

bool AIBI_CanonicalizeDirectorState(CRules@ rules)
{
	if (rules is null) return false;
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

u16 AIBI_CountLayerTiles(const u8 team, const u8 layer)
{
	array<u16>@ grid = null;
	AIBP_GetLayerGrid(team, layer, @grid);
	if (grid is null) return 0;
	u16 count = 0;
	for (uint i = 0; i < grid.length; i++) if (grid[i] != 0 && count < 65535) count++;
	return count;
}

u16 AIBI_CountReservations(const u8 team)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils) || reserved is null) return 0;
	u16 count = 0;
	for (uint i = 0; i < reserved.length; i++) if (reserved[i] != 0 && count < 65535) count++;
	return count;
}

void AIBI_CountPhysical(const u8 team, u16 &out matched, u16 &out foundationMatched,
	u16 &out accessMatched, u16 &out shellMatched)
{
	matched = 0; foundationMatched = 0; accessMatched = 0; shellMatched = 0;
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils) ||
		xs is null || ys is null || blocks is null || phases is null) return;
	for (uint i = 0; i < xs.length && i < ys.length && i < blocks.length && i < phases.length; i++)
	{
		if (!AIBP_MapMatchesBlock(xs[i], ys[i], blocks[i], team)) continue;
		matched++;
		if (phases[i] == AIBP_Phase::foundation) foundationMatched++;
		else if (phases[i] == AIBP_Phase::access) accessMatched++;
		else if (phases[i] == AIBP_Phase::shell) shellMatched++;
	}
}

bool AIBI_CaptureInitialState(CRules@ rules, CBlob@ home, CBlob@ enemy)
{
	CMap@ map = getMap();
	if (rules is null || map is null || home is null || enemy is null) return false;
	u32 terrainHash = 0; u32 solidTiles = 0; u32 noBuildHash = 0; u32 noBuildTiles = 0;
	u32 blobCount = 0; u32 blobHash = 0; u32 inventoryHash = 0; u32 strategyHash = 0;
	const string fingerprint = AIBWF_CaptureWorldManifest(rules, map, terrainHash, solidTiles,
		noBuildHash, noBuildTiles, blobCount, blobHash, inventoryHash, strategyHash);
	if (fingerprint == "") return false;
	const u32 mapHash = u32(map.getMapName().getHash());
	rules.set_u32("aib infrastructure map hash", mapHash);
	rules.set_u16("aib infrastructure map width", map.tilemapwidth);
	rules.set_u16("aib infrastructure map height", map.tilemapheight);
	rules.set_u32("aib infrastructure initial terrain hash", terrainHash);
	rules.set_string("aib infrastructure initial fingerprint", fingerprint);
	rules.set_string("aib infrastructure fixture id", "map_" + mapHash + "_" + map.tilemapwidth + "x" + map.tilemapheight);
	rules.set_string("aib infrastructure team side", home.getPosition().x <= enemy.getPosition().x ? "left" : "right");
	rules.set_s32("aib infrastructure flag x", s32(home.getPosition().x / map.tilesize));
	rules.set_s32("aib infrastructure flag y", s32(home.getPosition().y / map.tilesize));
	return true;
}

string AIBI_DescribeUnsupportedTasks(AIBWorldState@ world, AIBPlanCandidate@ candidate)
{
	if (world is null || candidate is null) return "none";
	CMap@ map = getMap();
	if (map is null) return "no_map";
	array<bool> supported(candidate.tasks.length, false);
	bool progress = true;
	while (progress)
	{
		progress = false;
		for (uint i = 0; i < candidate.tasks.length; i++)
		{
			if (supported[i]) continue;
			BlueprintTask@ task = candidate.tasks[i];
			if (task is null) continue;
			Vec2f center = Vec2f(task.x * map.tilesize + map.tilesize * 0.5f, task.y * map.tilesize + map.tilesize * 0.5f);
			if (AIBP_MapMatchesBlock(task.x, task.y, task.block) || map.hasSupportAtPos(center) ||
				AIBS_MapProvidesImmediateSupport(center) || AIBS_CanGenerateBackwallSupport(world, candidate, task) ||
				AIBS_TaskTouchesSupportedPlan(candidate, i, supported))
			{
				supported[i] = true;
				progress = true;
			}
		}
	}
	string result = "";
	u8 emitted = 0;
	for (uint i = 0; i < candidate.tasks.length && emitted < 12; i++)
	{
		if (supported[i]) continue;
		BlueprintTask@ task = candidate.tasks[i];
		if (task is null) continue;
		const Vec2f center = Vec2f(task.x * map.tilesize + map.tilesize * 0.5f, task.y * map.tilesize + map.tilesize * 0.5f);
		result += (result == "" ? "" : ";") + task.x + "," + task.y + ",b" + AIBP_BlockId(task.block) +
			",p" + task.phase + ",tile" + map.getTile(center).type;
		emitted++;
	}
	return result == "" ? "none" : result;
}

CBlob@ AIBI_FindTagged(const string &in tag)
{
	CBlob@[] tagged;
	getBlobsByTag(tag, @tagged);
	for (uint i = 0; i < tagged.length; i++)
	{
		CBlob@ blob = tagged[i];
		if (blob !is null && !blob.hasTag("dead")) return blob;
	}
	return null;
}

void AIBI_Abort(CRules@ rules, const string &in reason)
{
	if (rules is null) return;
	const string runID = rules.get_string("aib infrastructure run id");
	const string line = "[AIBGYMI] schema=" + AIBI_SCHEMA_VERSION + " status=abort run=" + runID + " reason=" + reason;
	AIBI_EmitLine(line);
	tcpr("AIBGYMI|ABORT|run=" + runID + "|reason=" + reason);
	AIBI_StopTaggedActors();
	rules.set_bool("aib infrastructure active", false);
	rules.set_bool("aib infrastructure request", false);
	rules.set_bool("aib infrastructure stop requested", false);
	rules.set_string("aib infrastructure phase", "idle");
	rules.set_string("aib infrastructure status", "abort:" + reason);
	rules.set_u32("aib infrastructure readiness deadline", 0);
}

void AIBI_Finish(CRules@ rules, const bool passed, const string &in reason)
{
	if (rules is null) return;
	const u8 team = rules.get_u8("aib infrastructure team");
	u16 physical = 0; u16 foundation = 0; u16 access = 0; u16 shell = 0;
	AIBI_CountPhysical(team, physical, foundation, access, shell);
	const int direction = rules.get_s32("aib infrastructure direction");
	const u16 anchorX = u16(Maths::Max(0, rules.get_s32("aib infrastructure anchor x")));
	const u16 groundY = u16(Maths::Max(0, rules.get_s32("aib infrastructure ground y")));
	const u16 rearX = u16(int(anchorX) - direction * 3);
	const u16 frontX = u16(int(anchorX) + direction * 3);
	const u16 doorY = groundY - 1;
	CBlob@ rearDoor = AIBP_GetMatchingPlanBlob(rearX, doorY, AIBP_EncodeBlock(AIBP_WOOD_DOOR, 1), team);
	CBlob@ frontDoor = AIBP_GetMatchingPlanBlob(frontX, doorY, AIBP_EncodeBlock(AIBP_WOOD_DOOR, 1), team);
	const u32 startTick = rules.get_u32("aib infrastructure start tick");
	const u32 elapsed = getGameTime() >= startTick ? getGameTime() - startTick : 0;
	const u16 taskCount = rules.get_u16("aib infrastructure tasks");
	const u16 completed = rules.get_u16(AIBP_PlanKey(team, "completed"));
	const u16 pending = rules.get_u16(AIBP_PlanKey(team, "pending"));
	const u8 planStatus = rules.get_u8(AIBP_PlanKey(team, "status"));
	const u16 reservations = AIBI_CountReservations(team);
	const u16 desiredTiles = AIBI_CountLayerTiles(team, AIBP_Layer::ai_desired);
	const u16 workTiles = AIBI_CountLayerTiles(team, AIBP_Layer::ai_work);
	const u16 planID = rules.get_u16("aib infrastructure plan id");
	const string archivePrefix = "aib strategy history plan " + planID + " team " + int(team) + " ";
	const bool archived = rules.get_string(archivePrefix + "archive reason") == "completed";
	const u32 probeStart = rules.get_u32("aib infrastructure probe start tick");
	const u32 probeEnd = rules.get_u32("aib infrastructure probe end tick");
	const u32 traversal = probeStart > 0 && probeEnd >= probeStart ? probeEnd - probeStart : 0;
	CBlob@ allyProbe = AIBI_FindTagged(AIBI_PROBE_TAG);
	const f32 probeFinalX = allyProbe is null ? -1.0f : allyProbe.getPosition().x;
	const f32 probeFinalY = allyProbe is null ? -1.0f : allyProbe.getPosition().y;
	const string runID = rules.get_string("aib infrastructure run id");
	const string line = "[AIBGYMI] schema=" + AIBI_SCHEMA_VERSION + " status=result run=" + runID +
		" variant=" + rules.get_string("aib infrastructure variant") +
		" metric=flag_gatehouse_physical fixture_id=" + rules.get_string("aib infrastructure fixture id") +
		" fixture_version=" + AIBI_FIXTURE_VERSION + " team=" + team +
		" team_side=" + rules.get_string("aib infrastructure team side") +
		" map_hash=" + rules.get_u32("aib infrastructure map hash") +
		" map_width=" + rules.get_u16("aib infrastructure map width") +
		" map_height=" + rules.get_u16("aib infrastructure map height") +
		" initial_terrain_hash=" + rules.get_u32("aib infrastructure initial terrain hash") +
		" initial_fingerprint=" + rules.get_string("aib infrastructure initial fingerprint") +
		" template=flag_gatehouse flag_x=" + rules.get_s32("aib infrastructure flag x") +
		" flag_y=" + rules.get_s32("aib infrastructure flag y") +
		" anchor_x=" + anchorX + " ground_y=" + groundY + " enemy_direction=" + direction +
		" plan_id=" + planID + " plan_version=" + rules.get_u16("aib infrastructure plan version") +
		" tasks=" + taskCount + " initial_matches=" + rules.get_u16("aib infrastructure initial matches") +
		" physical_matches=" + physical + " foundation_matches=" + foundation +
		" access_matches=" + access + " shell_matches=" + shell +
		" completed=" + completed + " pending=" + pending + " plan_status=" + planStatus +
		" reservations=" + reservations + " desired_tiles=" + desiredTiles + " work_tiles=" + workTiles +
		" archived_complete=" + AIBI_Bool(archived) +
		" rear_gate=" + AIBI_Bool(rearDoor !is null) + " front_gate=" + AIBI_Bool(frontDoor !is null) +
		" rear_gate_x=" + rearX + " front_gate_x=" + frontX +
		" friendly_route_penalty=" + rules.get_f32("aib infrastructure route penalty") +
		" ally_rear_entered=" + AIBI_Bool(rules.get_u32("aib infrastructure rear crossed tick") > 0) +
		" ally_front_exited=" + AIBI_Bool(rules.get_u32("aib infrastructure front crossed tick") > 0) +
		" ally_traversal_ticks=" + traversal +
		" ally_final_x=" + probeFinalX + " ally_final_y=" + probeFinalY +
		" ally_progress_px=" + rules.get_f32("aib infrastructure probe progress") +
		" completion_tick=" + rules.get_u32("aib infrastructure completion tick") +
		" elapsed=" + elapsed + " ai_actor_cap=" + AIBI_TOTAL_AI_LIMIT + " managed_actor_peak=2" +
		" passed=" + AIBI_Bool(passed) + " reason=" + reason;
	AIBI_EmitLine(line);
	tcpr("AIBGYMI|RESULT|run=" + runID + "|passed=" + AIBI_Bool(passed) + "|reason=" + reason);
	AIBI_StopTaggedActors();
	AIBP_CancelCurrentPlan(team, "infrastructure_benchmark_complete");
	rules.set_bool("aib infrastructure active", false);
	rules.set_bool("aib infrastructure request", false);
	rules.set_bool("aib infrastructure stop requested", false);
	rules.set_string("aib infrastructure phase", "idle");
	rules.set_string("aib infrastructure status", (passed ? "passed:" : "failed:") + reason);
	rules.set_u32("aib infrastructure readiness deadline", 0);
}

bool AIBI_Prepare(CRules@ rules)
{
	if (rules is null) return false;
	if (AIBI_CanonicalizeDirectorState(rules))
	{
		// server_Die is finalized after this callback.  Retry only after the
		// benchmark-owned bootstrap cleanup is no longer visible.
		rules.set_bool("aib infrastructure active", false);
		rules.set_bool("aib infrastructure request", true);
		rules.set_string("aib infrastructure status", "canonicalizing_director_workers");
		return false;
	}
	const u8 team = rules.get_u8("aib infrastructure team");
	if (rules.get_bool("aib gym active") || rules.get_bool("aib wave running") || AIBI_ExistingManagedActors() != 0)
	{
		AIBI_Abort(rules, "contaminated_ai_actors"); return false;
	}
	CMap@ map = getMap();
	CBlob@ home = AIBS_TeamHomeBlob(team);
	CBlob@ enemy = home is null ? null : AIBS_EnemyHomeBlob(team, home.getPosition());
	if (map is null || home is null || enemy is null || home.getName() != "ctf_flag" || enemy.getName() != "ctf_flag")
	{
		if (getGameTime() >= rules.get_u32("aib infrastructure readiness deadline"))
		{
			AIBI_Abort(rules, "team_flags_readiness_timeout"); return false;
		}
		rules.set_bool("aib infrastructure active", false);
		rules.set_bool("aib infrastructure request", true);
		rules.set_string("aib infrastructure status", "waiting_for_team_flags");
		return false;
	}
	rules.set_bool("aib infrastructure active", true);
	rules.set_bool("aib infrastructure request", false);
	rules.set_string("aib infrastructure status", "preparing");
	if (!AIBI_CaptureInitialState(rules, home, enemy))
	{
		AIBI_Abort(rules, "initial_fingerprint_failed"); return false;
	}

	// Freeze automatic planning without waiting for a heartbeat, then publish one
	// benchmark-owned production plan.  Recording the director's last mode avoids
	// a later off-mode transition from stopping the assigned executor.
	rules.set_u8("aib infrastructure previous mode", rules.get_u8(AIBP_ModeKey(team)));
	rules.set_u8(AIBP_ModeKey(team), AIBP_StrategyMode::off);
	rules.set_u8("aib strategy last mode team " + int(team), AIBP_StrategyMode::off);
	AIBS_StopAssignedBuilders(team);
	AIBP_CancelCurrentPlan(team, "infrastructure_benchmark_reset");
	AIBP_SetAIWorkEnabled(team, false);
	AIBS_BuildStaticTerrain();

	AIBWorldState@ world = AIBS_ObserveWorld(team);
	array<AIBPlanCandidate@> candidates;
	AIBS_GenerateCandidates(world, candidates);
	AIBPlanCandidate@ selected = null;
	string gateDiagnostics = "";
	for (uint i = 0; i < candidates.length; i++)
	{
		AIBPlanCandidate@ candidate = candidates[i];
		if (candidate is null || candidate.intent != AIBStrategyIntent::flag_gatehouse) continue;
		const bool valid = AIBS_ValidateCandidate(world, candidate);
		gateDiagnostics += (gateDiagnostics == "" ? "" : ";") + int(candidate.anchor.x) + "," + int(candidate.anchor.y) +
			":" + (valid ? "valid" : candidate.rejection);
		if (!valid) continue;
		AIBS_ScoreCandidate(world, candidate);
		if (selected is null || candidate.score > selected.score ||
			(candidate.score == selected.score && candidate.anchor.x < selected.anchor.x)) @selected = candidate;
	}
	if (selected is null)
	{
		string outwardScan = "";
		AIBPlanCandidate@ firstUnsupported = null;
		const int flagX = int(world.home.x / map.tilesize);
		for (int distance = 6; distance <= 30; distance += 2)
		{
			const int scanX = flagX + world.enemyDirection * distance;
			AIBPlanCandidate@ scan = AIBS_GatehouseTemplate(scanX, AIBS_GatehouseGroundAt(scanX));
			const bool valid = AIBS_ValidateCandidate(world, scan);
			if (!valid && scan.rejection == "unsupported" && firstUnsupported is null) @firstUnsupported = scan;
			outwardScan += (outwardScan == "" ? "" : ";") + distance + "@" + scanX + "," + int(scan.anchor.y) +
				":" + (valid ? "valid" : scan.rejection);
		}
		const string diagnostic = "AIBGYMI|CANDIDATES|run=" + rules.get_string("aib infrastructure run id") +
			"|flag=" + int(world.home.x / map.tilesize) + "," + int(world.home.y / map.tilesize) +
			"|resource_home=" + int(world.resourceHome.x / map.tilesize) + "," + int(world.resourceHome.y / map.tilesize) +
			"|gatehouses=" + gateDiagnostics;
		print("[AIBGYMI] " + diagnostic);
		tcpr(diagnostic);
		const string scanDiagnostic = "AIBGYMI|OUTWARD_SCAN|run=" + rules.get_string("aib infrastructure run id") + "|sites=" + outwardScan;
		print("[AIBGYMI] " + scanDiagnostic);
		tcpr(scanDiagnostic);
		if (firstUnsupported !is null)
		{
			const string supportDiagnostic = "AIBGYMI|UNSUPPORTED|run=" + rules.get_string("aib infrastructure run id") +
				"|anchor=" + int(firstUnsupported.anchor.x) + "," + int(firstUnsupported.anchor.y) +
				"|tasks=" + AIBI_DescribeUnsupportedTasks(world, firstUnsupported);
			print("[AIBGYMI] " + supportDiagnostic);
			tcpr(supportDiagnostic);
		}
		AIBI_Abort(rules, "no_valid_gatehouse"); return false;
	}
	BlueprintPlan@ plan = AIBS_MakePlan(world, selected);
	if (plan is null || plan.tasks.length == 0 || !AIBP_PublishAIPlan(plan, true))
	{
		AIBI_Abort(rules, "plan_publish_failed"); return false;
	}

	rules.set_s32("aib infrastructure anchor x", s32(selected.anchor.x));
	rules.set_s32("aib infrastructure ground y", s32(selected.anchor.y));
	rules.set_s32("aib infrastructure direction", world.enemyDirection);
	rules.set_u16("aib infrastructure tasks", u16(plan.tasks.length));
	rules.set_u16("aib infrastructure plan id", plan.id);
	rules.set_u16("aib infrastructure plan version", plan.version);
	rules.set_f32("aib infrastructure route penalty", AIBS_FriendlyRoutePenalty(selected));
	u16 initial = 0; u16 initialFoundation = 0; u16 initialAccess = 0; u16 initialShell = 0;
	AIBI_CountPhysical(team, initial, initialFoundation, initialAccess, initialShell);
	rules.set_u16("aib infrastructure initial matches", initial);

	const Vec2f executorPos = Vec2f(selected.anchor.x * map.tilesize + map.tilesize * 0.5f,
		(selected.anchor.y - 6) * map.tilesize + map.tilesize * 0.5f);
	CBlob@ executor = server_CreateBlob("autobuilder", team, executorPos);
	if (executor is null)
	{
		AIBI_Finish(rules, false, "executor_spawn_failed"); return false;
	}
	executor.Tag(AIBI_EXECUTOR_TAG);
	AIBWorldState@ assignedWorld = AIBS_ObserveWorld(team);
	AIBS_AssignBuilders(assignedWorld);
	if (!executor.get_bool("aib strategy assigned") || executor.get_u8("ai builder job") != AIBS_JOB_BLUEPRINT)
	{
		AIBI_Finish(rules, false, "executor_assignment_failed"); return false;
	}

	const u32 now = getGameTime();
	rules.set_u32("aib infrastructure start tick", now);
	rules.set_u32("aib infrastructure completion tick", 0);
	rules.set_u32("aib infrastructure probe start tick", 0);
	rules.set_u32("aib infrastructure probe end tick", 0);
	rules.set_u32("aib infrastructure rear crossed tick", 0);
	rules.set_u32("aib infrastructure front crossed tick", 0);
	rules.set_u32("aib infrastructure build deadline", now + u32(plan.tasks.length) * 45 + 600);
	rules.set_string("aib infrastructure phase", "building");
	rules.set_string("aib infrastructure status", "building");
	tcpr("AIBGYMI|START|run=" + rules.get_string("aib infrastructure run id") + "|tasks=" + plan.tasks.length +
		"|anchor=" + int(selected.anchor.x) + "," + int(selected.anchor.y));
	return true;
}

bool AIBI_PlanPhysicallyComplete(CRules@ rules)
{
	const u8 team = rules.get_u8("aib infrastructure team");
	if (getGameTime() % 15 == 0) AIBP_RefreshPlanState(team, true);
	u16 physical = 0; u16 foundation = 0; u16 access = 0; u16 shell = 0;
	AIBI_CountPhysical(team, physical, foundation, access, shell);
	const u16 expected = rules.get_u16("aib infrastructure tasks");
	const bool identity = rules.get_u16(AIBP_PlanKey(team, "id")) == rules.get_u16("aib infrastructure plan id") &&
		rules.get_u16(AIBP_PlanKey(team, "version")) == rules.get_u16("aib infrastructure plan version");
	const bool counters = rules.get_u16(AIBP_PlanKey(team, "pending")) == 0 &&
		rules.get_u16(AIBP_PlanKey(team, "completed")) == expected && rules.get_u8(AIBP_PlanKey(team, "status")) == 2;
	const bool layers = AIBI_CountLayerTiles(team, AIBP_Layer::ai_desired) == expected &&
		AIBI_CountLayerTiles(team, AIBP_Layer::ai_work) == 0;
	const string archivePrefix = "aib strategy history plan " + rules.get_u16("aib infrastructure plan id") + " team " + int(team) + " ";
	return identity && counters && layers && AIBI_CountReservations(team) == 0 && physical == expected &&
		rules.get_string(archivePrefix + "archive reason") == "completed";
}

bool AIBI_ProbeCellClear(CMap@ map, const int x, const int groundY)
{
	if (map is null || x < 0 || x >= map.tilemapwidth || groundY < 2 || groundY >= map.tilemapheight) return false;
	Vec2f feet = Vec2f(x * map.tilesize + map.tilesize * 0.5f, (groundY - 1) * map.tilesize + map.tilesize * 0.5f);
	Vec2f head = feet - Vec2f(0, map.tilesize);
	Vec2f support = feet + Vec2f(0, map.tilesize);
	return !map.isTileSolid(map.getTile(feet).type) && !map.isTileSolid(map.getTile(head).type) &&
		map.isTileSolid(map.getTile(support).type);
}

bool AIBI_StartProbe(CRules@ rules)
{
	CMap@ map = getMap();
	if (map is null) return false;
	const int team = rules.get_u8("aib infrastructure team");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const int direction = rules.get_s32("aib infrastructure direction");
	const int startX = anchorX - direction * 4;
	const int goalX = anchorX + direction * 4;
	if (!AIBI_ProbeCellClear(map, startX, groundY) || !AIBI_ProbeCellClear(map, goalX, groundY)) return false;
	Vec2f start = Vec2f(startX * map.tilesize + map.tilesize * 0.5f, groundY * map.tilesize - map.tilesize * 0.5f);
	CBlob@ probe = server_CreateBlob("builder", team, start);
	if (probe is null) return false;
	probe.Tag(AIBI_PROBE_TAG);
	probe.Tag("no pickup");
	CBrain@ brain = probe.getBrain();
	if (brain !is null) brain.server_SetActive(false);
	probe.setAimPos(start + Vec2f(direction * 80.0f, 0));
	rules.set_Vec2f("aib infrastructure probe start", start);
	rules.set_f32("aib infrastructure probe progress", 0.0f);
	rules.set_u32("aib infrastructure probe start tick", getGameTime());
	rules.set_u32("aib infrastructure probe progress tick", getGameTime());
	rules.set_u32("aib infrastructure probe jump until", 0);
	rules.set_u32("aib infrastructure probe deadline", getGameTime() + AIBI_PROBE_TIMEOUT_TICKS);
	rules.set_string("aib infrastructure phase", "probe_settle");
	rules.set_u32("aib infrastructure probe settle until", getGameTime() + AIBI_PROBE_SETTLE_TICKS);
	rules.set_string("aib infrastructure status", "probing_rear_gate");
	return true;
}

void AIBI_DriveProbe(CRules@ rules)
{
	CBlob@ probe = AIBI_FindTagged(AIBI_PROBE_TAG);
	CMap@ map = getMap();
	if (probe is null || map is null)
	{
		AIBI_Finish(rules, false, "ally_probe_lost"); return;
	}
	const int direction = rules.get_s32("aib infrastructure direction");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const f32 projected = (probe.getPosition().x - rules.get_Vec2f("aib infrastructure probe start").x) * direction;
	if (projected >= rules.get_f32("aib infrastructure probe progress") + 1.0f)
	{
		rules.set_f32("aib infrastructure probe progress", projected);
		rules.set_u32("aib infrastructure probe progress tick", getGameTime());
	}
	const f32 rearPlane = (anchorX - direction * 3) * map.tilesize + map.tilesize * 0.5f;
	const f32 frontPlane = (anchorX + direction * 3) * map.tilesize + map.tilesize * 0.5f;
	if (rules.get_u32("aib infrastructure rear crossed tick") == 0 && (probe.getPosition().x - rearPlane) * direction >= 0)
		rules.set_u32("aib infrastructure rear crossed tick", getGameTime());
	if (rules.get_u32("aib infrastructure front crossed tick") == 0 && (probe.getPosition().x - frontPlane) * direction >= 0)
		rules.set_u32("aib infrastructure front crossed tick", getGameTime());

	if (projected >= map.tilesize * 8.0f - 4.0f)
	{
		rules.set_u32("aib infrastructure probe end tick", getGameTime());
		AIBI_Finish(rules, rules.get_u32("aib infrastructure rear crossed tick") > 0 &&
			rules.get_u32("aib infrastructure front crossed tick") > 0, "physical_gatehouse_and_ally_passage_complete");
		return;
	}
	if (probe.getPosition().y > groundY * map.tilesize + map.tilesize * 3.0f)
	{
		AIBI_Finish(rules, false, "ally_probe_fell_from_route"); return;
	}
	if (getGameTime() >= rules.get_u32("aib infrastructure probe deadline"))
	{
		AIBI_Finish(rules, false, "ally_probe_timeout"); return;
	}
	probe.setKeyPressed(key_left, direction < 0);
	probe.setKeyPressed(key_right, direction > 0);
	// The production foundation is level.  Pressing up here can attach the probe
	// to the gatehouse's central ladder and test the upper deck instead of the
	// intended rear-to-front ground passage.
	probe.setKeyPressed(key_up, false);
	probe.setKeyPressed(key_down, false);
	probe.setKeyPressed(key_action1, false);
	probe.setKeyPressed(key_action2, false);
	probe.setAimPos(probe.getPosition() + Vec2f(direction * 80.0f, 0));
}

void onTick(CRules@ this)
{
	if (!isServer()) return;
	if (this.get_bool("aib infrastructure request") && !this.get_bool("aib infrastructure active"))
	{
		if (!this.isMatchRunning())
		{
			this.set_string("aib infrastructure status", "waiting_for_live_match");
			return;
		}
		if (this.get_u32("aib infrastructure readiness deadline") == 0)
			this.set_u32("aib infrastructure readiness deadline", getGameTime() + 10 * 30);
		AIBI_Prepare(this);
		return;
	}
	if (!this.get_bool("aib infrastructure active")) return;
	if (this.get_bool("aib infrastructure stop requested"))
	{
		AIBI_Abort(this, "operator_stop"); return;
	}
	CMap@ map = getMap();
	if (map is null || u32(map.getMapName().getHash()) != this.get_u32("aib infrastructure map hash"))
	{
		AIBI_Abort(this, "map_changed"); return;
	}
	const string phase = this.get_string("aib infrastructure phase");
	if (phase == "building")
	{
		if (AIBI_PlanPhysicallyComplete(this))
		{
			this.set_u32("aib infrastructure completion tick", getGameTime() - this.get_u32("aib infrastructure start tick"));
			if (!AIBI_StartProbe(this)) AIBI_Finish(this, false, "ally_probe_start_or_route_invalid");
			return;
		}
		if (getGameTime() >= this.get_u32("aib infrastructure build deadline"))
		{
			AIBI_Finish(this, false, "physical_plan_timeout"); return;
		}
	}
	else if (phase == "probe_settle")
	{
		CBlob@ probe = AIBI_FindTagged(AIBI_PROBE_TAG);
		if (probe is null) { AIBI_Finish(this, false, "ally_probe_lost_during_settle"); return; }
		probe.setKeyPressed(key_left, false);
		probe.setKeyPressed(key_right, false);
		probe.setKeyPressed(key_up, false);
		if (getGameTime() >= this.get_u32("aib infrastructure probe settle until"))
			this.set_string("aib infrastructure phase", "probing");
	}
	else if (phase == "probing") AIBI_DriveProbe(this);
}
