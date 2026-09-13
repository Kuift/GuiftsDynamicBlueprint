#define SERVER_ONLY

#include "AIBStrategicJobs.as";
#include "AIBWorldFingerprint.as";
#include "RulesCore.as";

// Map-scoped physical infrastructure benchmark.  This deliberately uses the
// production planner, plan publication, and Autobuilder executor.  The only
// synthetic part is a brain-disabled, player-shaped runner used to prove the
// requested friendly route after construction is complete.  Workshop runs bind
// that same runner lineage to the connected player only while it invokes each
// production shop's existing server-authoritative class command.  Explicit
// *_breach metrics then transfer that connected player through RulesCore to the
// opposing CTF team and bind a fresh builder at the enemy-facing landing.  Its
// client-originated production pickaxe input must damage the finished structure
// before resistance or a complete physical crossing can be recorded.

const u16 AIBI_GATEHOUSE_SCHEMA_VERSION = 1;
const u16 AIBI_WORKSHOP_SCHEMA_VERSION = 3;
const u16 AIBI_BREACH_SCHEMA_VERSION = 4;
const u16 AIBI_FIXTURE_VERSION = 1;
const u16 AIBI_WORKSHOP_FIXTURE_VERSION = 3;
const u16 AIBI_GATEHOUSE_BREACH_FIXTURE_VERSION = 3;
const u16 AIBI_WORKSHOP_BREACH_FIXTURE_VERSION = 4;
const u8 AIBI_TOTAL_AI_LIMIT = 8;
const u32 AIBI_PROBE_SETTLE_TICKS = 15;
const u32 AIBI_WORKSHOP_TEAM_STABLE_TICKS = 30;
const u32 AIBI_WORKSHOP_TEAM_TIMEOUT_TICKS = 450;
const u32 AIBI_PROBE_TIMEOUT_TICKS = 300;
const u32 AIBI_ENEMY_PROBE_TIMEOUT_TICKS = 900;
const u32 AIBI_ENEMY_MIN_PICKAXE_COMMANDS = 3;
// The retained mirrored-right cohort used as many as 895 ticks before the
// final exit boundary, leaving no scheduler/replan margin at the old 900-tick
// cap. Keep the probe bounded while allowing one partial BrainPath recovery.
const u32 AIBI_WORKSHOP_PROBE_TIMEOUT_TICKS = 1200;
const u32 AIBI_WORKSHOP_BREACH_PROBE_TIMEOUT_TICKS = 1800;
const string AIBI_METRIC_GATEHOUSE = "gatehouse";
const string AIBI_METRIC_WORKSHOPS = "workshops";
const string AIBI_METRIC_GATEHOUSE_BREACH = "gatehouse_breach";
const string AIBI_METRIC_WORKSHOPS_BREACH = "workshops_breach";
const string AIBI_EXECUTOR_TAG = "aib infrastructure executor";
const string AIBI_PROBE_TAG = "aib infrastructure ally probe";

u8 AIBI_WorkshopEnemyWallDepth(CRules@ rules)
{
	if (rules is null) return 1;
	const u8 depth = rules.get_u8("aib infrastructure enemy wall depth");
	return depth == 0 ? 1 : depth;
}

bool AIBI_IsBreachMetric(CRules@ rules)
{
	if (rules is null) return false;
	const string metric = rules.get_string("aib infrastructure metric");
	return metric == AIBI_METRIC_GATEHOUSE_BREACH || metric == AIBI_METRIC_WORKSHOPS_BREACH;
}

bool AIBI_IsWorkshopMetric(CRules@ rules)
{
	if (rules is null) return false;
	const string metric = rules.get_string("aib infrastructure metric");
	return metric == AIBI_METRIC_WORKSHOPS || metric == AIBI_METRIC_WORKSHOPS_BREACH;
}

u16 AIBI_SchemaVersion(CRules@ rules)
{
	if (AIBI_IsBreachMetric(rules)) return AIBI_BREACH_SCHEMA_VERSION;
	return AIBI_IsWorkshopMetric(rules) ? AIBI_WORKSHOP_SCHEMA_VERSION : AIBI_GATEHOUSE_SCHEMA_VERSION;
}

void AIBI_SetClientAction(CRules@ rules, const u8 action)
{
	if (rules is null) return;
	rules.set_u8("aib infrastructure client action", action);
	rules.Sync("aib infrastructure client action", true);
}

void AIBI_SetClientProbeActive(CRules@ rules, const bool active)
{
	if (rules is null) return;
	rules.set_bool("aib infrastructure client probe active", active);
	rules.Sync("aib infrastructure client probe active", true);
}

void AIBI_Reset(CRules@ rules)
{
	if (rules is null) return;
	rules.set_bool("aib infrastructure active", false);
	rules.set_bool("aib infrastructure request", false);
	rules.set_bool("aib infrastructure stop requested", false);
	rules.set_string("aib infrastructure status", "idle");
	rules.set_string("aib infrastructure phase", "idle");
	rules.set_string("aib infrastructure metric", AIBI_METRIC_GATEHOUSE);
	rules.set_u32("aib infrastructure readiness deadline", 0);
	rules.set_netid("aib infrastructure probe blob", 0);
	rules.set_netid("aib infrastructure probe holder", 0);
	rules.set_u16("aib infrastructure client target", 0);
	rules.set_Vec2f("aib infrastructure client destination", Vec2f_zero);
	rules.set_u8("aib infrastructure client action", 0);
	AIBI_SetClientProbeActive(rules, false);
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
	rules.set_u8("aib infrastructure enemy team", enemy.getTeamNum());
	rules.set_s32("aib infrastructure flag x", s32(home.getPosition().x / map.tilesize));
	rules.set_s32("aib infrastructure flag y", s32(home.getPosition().y / map.tilesize));
	return true;
}

bool AIBI_CaptureResourceHome(CRules@ rules, CBlob@ resourceHome)
{
	CMap@ map = getMap();
	if (rules is null || map is null || resourceHome is null || resourceHome.hasTag("dead")) return false;
	const string name = resourceHome.getName();
	if ((name != "tent" && name != "hall") || resourceHome.getTeamNum() != rules.get_u8("aib infrastructure team")) return false;
	rules.set_netid("aib infrastructure resource home", resourceHome.getNetworkID());
	rules.set_string("aib infrastructure resource home name", name);
	rules.set_s32("aib infrastructure resource home x", s32(resourceHome.getPosition().x / map.tilesize));
	rules.set_s32("aib infrastructure resource home y", s32(resourceHome.getPosition().y / map.tilesize));
	return true;
}

AIBPlanCandidate@ AIBI_SelectProtectedWorkshops(AIBWorldState@ world, string &out diagnostics)
{
	diagnostics = "";
	CMap@ map = getMap();
	if (world is null || map is null || world.resourceHome == Vec2f_zero) return null;
	const int homeX = int(world.resourceHome.x / map.tilesize);
	// Stay within a bounded production envelope around the exact tent/hall, but
	// try enough deterministic offsets to clear real no-build sectors and uneven
	// ground. The first legal site is the closest usable class facility.
	const int[] distances = { 14, 18, 22, 26, 30, 34, 38, 42, 46, 50 };
	for (uint i = 0; i < distances.length; i++)
	{
		const int anchorX = homeX + world.enemyDirection * distances[i];
		const int groundY = AIBS_ProtectedWorkshopsGroundAt(anchorX);
		const int homeRise = AIBS_ProtectedWorkshopsHomeRise(anchorX, groundY, world.enemyDirection);
		AIBPlanCandidate@ candidate = AIBS_ProtectedWorkshopsTemplate(anchorX, groundY, world.enemyDirection);
		const bool valid = AIBS_ValidateCandidate(world, candidate);
		diagnostics += (diagnostics == "" ? "" : ";") + distances[i] + "@" + anchorX + "," +
			int(candidate.anchor.y) + ":rise" + homeRise + ":" + (valid ? "valid" : candidate.rejection) +
			(candidate.reasons == "" ? "" : "(" + candidate.reasons + ")");
		if (!valid) continue;
		AIBS_ScoreCandidate(world, candidate);
		return candidate;
	}
	return null;
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
	const string line = "[AIBGYMI] schema=" + AIBI_SchemaVersion(rules) + " status=abort run=" + runID + " reason=" + reason;
	AIBI_EmitLine(line);
	tcpr("AIBGYMI|ABORT|run=" + runID + "|reason=" + reason);
	AIBI_RestoreProbePlayer(rules);
	AIBI_StopTaggedActors();
	rules.set_bool("aib infrastructure active", false);
	rules.set_bool("aib infrastructure request", false);
	rules.set_bool("aib infrastructure stop requested", false);
	rules.set_string("aib infrastructure phase", "idle");
	rules.set_string("aib infrastructure status", "abort:" + reason);
	rules.set_u32("aib infrastructure readiness deadline", 0);
}

void AIBI_FinishGatehouse(CRules@ rules, const bool passed, const string &in reason)
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
	CBlob@ rearDoor = AIBP_GetMatchingPlanBlob(rearX, doorY, AIBS_GatehouseDoorBlock(), team);
	CBlob@ frontDoor = AIBP_GetMatchingPlanBlob(frontX, doorY, AIBS_GatehouseDoorBlock(), team);
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
	const string line = "[AIBGYMI] schema=" + AIBI_GATEHOUSE_SCHEMA_VERSION + " status=result run=" + runID +
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
	AIBI_SetClientProbeActive(rules, false);
	AIBI_StopTaggedActors();
	AIBP_CancelCurrentPlan(team, "infrastructure_benchmark_complete");
	rules.set_bool("aib infrastructure active", false);
	rules.set_bool("aib infrastructure request", false);
	rules.set_bool("aib infrastructure stop requested", false);
	rules.set_string("aib infrastructure phase", "idle");
	rules.set_string("aib infrastructure status", (passed ? "passed:" : "failed:") + reason);
	rules.set_u32("aib infrastructure readiness deadline", 0);
}

CBlob@ AIBI_GetClassWorkshop(CRules@ rules, const bool knightShop)
{
	if (rules is null) return null;
	const u8 team = rules.get_u8("aib infrastructure team");
	const int direction = rules.get_s32("aib infrastructure direction");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const int shopX = anchorX + (knightShop ? -direction * 4 : direction * 4);
	const u16 block = knightShop ? AIBP_KNIGHT_SHOP : AIBP_ARCHER_SHOP;
	return AIBP_GetMatchingPlanBlob(u16(shopX), u16(groundY - 2), block, team);
}

void AIBI_CountWorkshopCover(CRules@ rules, u16 &out roofMatched, u16 &out backingMatched,
	u16 &out sideMatched)
{
	roofMatched = 0; backingMatched = 0; sideMatched = 0;
	if (rules is null) return;
	const int direction = rules.get_s32("aib infrastructure direction");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const int[] shopXs = { anchorX - direction * 4, anchorX + direction * 4 };
	for (uint shopIndex = 0; shopIndex < shopXs.length; shopIndex++)
	{
		const int shopX = shopXs[shopIndex];
		for (int x = -2; x <= 2; x++)
		{
			if (AIBP_MapMatchesBlock(u16(shopX + x), u16(groundY - 4), AIBP_STONE_BLOCK,
				rules.get_u8("aib infrastructure team"))) roofMatched++;
		}
		for (int y = 1; y <= 3; y++)
		{
			for (int x = -2; x <= 2; x++)
			{
				if (x == 0 && y == 2) continue;
				if (AIBP_MapMatchesBlock(u16(shopX + x), u16(groundY - y), AIBP_STONE_BACKWALL,
					rules.get_u8("aib infrastructure team"))) backingMatched++;
			}
		}
	}
	const int homeWallX = anchorX - direction * 8;
	if (AIBP_MapMatchesBlock(u16(homeWallX), u16(groundY - 3), AIBP_STONE_BLOCK,
		rules.get_u8("aib infrastructure team"))) sideMatched++;
	for (u8 depth = 0; depth < AIBI_WorkshopEnemyWallDepth(rules); depth++)
	{
		const int enemyWallX = anchorX + direction * (8 - depth);
		for (int y = 1; y <= 3; y++)
		{
			if (AIBP_MapMatchesBlock(u16(enemyWallX), u16(groundY - y), AIBP_STONE_BLOCK,
				rules.get_u8("aib infrastructure team"))) sideMatched++;
		}
	}
}

CPlayer@ AIBI_GetProbePlayer(CRules@ rules)
{
	if (rules is null) return null;
	const u16 id = rules.get_u16("aib infrastructure probe player");
	for (int i = 0; i < getPlayersCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player !is null && player.getNetworkID() == id) return player;
	}
	return null;
}

CBlob@ AIBI_GetWorkshopProbe(CRules@ rules)
{
	if (rules is null) return null;
	CBlob@ stored = getBlobByNetworkID(rules.get_netid("aib infrastructure probe blob"));
	if (stored !is null && !stored.hasTag("dead")) return stored;
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	CBlob@ active = player is null ? null : player.getBlob();
	if (active is null || active.hasTag("dead")) return null;
	const u8 stage = rules.get_u8("aib infrastructure workshop probe stage");
	if ((stage == 1 && active.getName() == "knight") || (stage == 3 && active.getName() == "archer"))
		return active;
	return null;
}

void AIBI_RestoreProbePlayer(CRules@ rules)
{
	if (rules is null) return;
	AIBI_SetClientProbeActive(rules, false);
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	CBlob@ holder = getBlobByNetworkID(rules.get_netid("aib infrastructure probe holder"));
	if (player is null || holder is null || holder.hasTag("dead")) return;
	CBlob@ active = player.getBlob();
	if (active is holder) return;
	if (active !is null) active.server_SetPlayer(null);
	holder.server_SetPlayer(player);
}

void AIBI_FinishWorkshops(CRules@ rules, const bool passed, const string &in reason)
{
	if (rules is null) return;
	const u8 team = rules.get_u8("aib infrastructure team");
	u16 physical = 0; u16 foundation = 0; u16 access = 0; u16 shell = 0;
	AIBI_CountPhysical(team, physical, foundation, access, shell);
	const int direction = rules.get_s32("aib infrastructure direction");
	const u16 anchorX = u16(Maths::Max(0, rules.get_s32("aib infrastructure anchor x")));
	const u16 groundY = u16(Maths::Max(0, rules.get_s32("aib infrastructure ground y")));
	const u16 homeGateX = u16(int(anchorX) - direction * 8);
	const u16 enemyWallX = u16(int(anchorX) + direction * 8);
	const u16 doorY = groundY - 1;
	CBlob@ homeDoor = AIBP_GetMatchingPlanBlob(homeGateX, doorY, AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), team);
	u16 enemyWallMatched = 0;
	const u8 enemyWallDepth = AIBI_WorkshopEnemyWallDepth(rules);
	for (u8 depth = 0; depth < enemyWallDepth; depth++)
	{
		const u16 wallX = u16(int(anchorX) + direction * (8 - depth));
		for (int y = 1; y <= 3; y++)
		{
			if (AIBP_MapMatchesBlock(wallX, u16(int(groundY) - y), AIBP_STONE_BLOCK, team)) enemyWallMatched++;
		}
	}
	const u16 expectedEnemyWall = u16(enemyWallDepth) * 3;
	const u16 expectedSideCover = expectedEnemyWall + 1;
	const bool homeUpperCover = AIBP_MapMatchesBlock(homeGateX, u16(int(groundY) - 3), AIBP_STONE_BLOCK, team);
	CBlob@ knightShop = AIBI_GetClassWorkshop(rules, true);
	CBlob@ archerShop = AIBI_GetClassWorkshop(rules, false);
	u16 roofCover = 0; u16 backingCover = 0; u16 sideCover = 0;
	AIBI_CountWorkshopCover(rules, roofCover, backingCover, sideCover);

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
	CBlob@ resourceHome = getBlobByNetworkID(rules.get_netid("aib infrastructure resource home"));
	const bool exactHome = resourceHome !is null && !resourceHome.hasTag("dead") && resourceHome.getTeamNum() == team &&
		resourceHome.getName() == rules.get_string("aib infrastructure resource home name") &&
		(resourceHome.getName() == "tent" || resourceHome.getName() == "hall");
	CBlob@ probe = AIBI_GetWorkshopProbe(rules);
	const string finalClass = probe is null ? "none" : probe.getName();
	const f32 probeFinalX = probe is null ? -1.0f : probe.getPosition().x;
	const f32 probeFinalY = probe is null ? -1.0f : probe.getPosition().y;
	const u32 probeStart = rules.get_u32("aib infrastructure probe start tick");
	const u32 probeEnd = rules.get_u32("aib infrastructure probe end tick");
	const u32 traversal = probeStart > 0 && probeEnd >= probeStart ? probeEnd - probeStart : 0;
	const u32 knightUsedTick = rules.get_u32("aib infrastructure knight used tick");
	const u32 archerUsedTick = rules.get_u32("aib infrastructure archer used tick");
	const u32 homeRouteTicks = probeStart > 0 && knightUsedTick >= probeStart ? knightUsedTick - probeStart : 0;
	const u32 classUseTicks = knightUsedTick > 0 && archerUsedTick >= knightUsedTick ? archerUsedTick - knightUsedTick : 0;
	const bool knightExact = knightShop !is null && knightShop.getTeamNum() == team &&
		knightShop.get_string("required class") == "knight";
	const bool archerExact = archerShop !is null && archerShop.getTeamNum() == team &&
		archerShop.get_string("required class") == "archer";
	const bool boundedCover = roofCover == 10 && backingCover == 28 && sideCover == expectedSideCover &&
		enemyWallMatched == expectedEnemyWall && homeUpperCover;
	const bool routeComplete = rules.get_u32("aib infrastructure rear crossed tick") > 0 &&
		rules.get_u32("aib infrastructure knight overlap tick") > 0 && knightUsedTick > 0 &&
		rules.get_u32("aib infrastructure archer overlap tick") > 0 && archerUsedTick > 0 &&
		rules.get_u32("aib infrastructure front crossed tick") > 0 && probeEnd > 0;
	const bool planComplete = physical == taskCount && completed == taskCount && pending == 0 && planStatus == 2 &&
		reservations == 0 && desiredTiles == taskCount && workTiles == 0 && archived;
	const bool finalPassed = passed && planComplete && knightExact && archerExact && boundedCover &&
		homeDoor !is null && exactHome && routeComplete && finalClass == "archer";
	const string finalReason = finalPassed ? reason : (passed ? "workshop_postcondition_failed" : reason);
	const string runID = rules.get_string("aib infrastructure run id");
	const string line = "[AIBGYMI] schema=" + AIBI_WORKSHOP_SCHEMA_VERSION + " status=result run=" + runID +
		" variant=" + rules.get_string("aib infrastructure variant") +
		" metric=protected_class_workshops_physical fixture_id=" + rules.get_string("aib infrastructure fixture id") +
		" fixture_version=" + AIBI_WORKSHOP_FIXTURE_VERSION + " team=" + team +
		" team_side=" + rules.get_string("aib infrastructure team side") +
		" map_hash=" + rules.get_u32("aib infrastructure map hash") +
		" map_width=" + rules.get_u16("aib infrastructure map width") +
		" map_height=" + rules.get_u16("aib infrastructure map height") +
		" initial_terrain_hash=" + rules.get_u32("aib infrastructure initial terrain hash") +
		" initial_fingerprint=" + rules.get_string("aib infrastructure initial fingerprint") +
		" template=protected_workshops resource_home=" + rules.get_string("aib infrastructure resource home name") +
		" resource_home_x=" + rules.get_s32("aib infrastructure resource home x") +
		" resource_home_y=" + rules.get_s32("aib infrastructure resource home y") +
		" resource_home_exact=" + AIBI_Bool(exactHome) +
		" anchor_x=" + anchorX + " ground_y=" + groundY + " enemy_direction=" + direction +
		" plan_id=" + planID + " plan_version=" + rules.get_u16("aib infrastructure plan version") +
		" tasks=" + taskCount + " initial_matches=" + rules.get_u16("aib infrastructure initial matches") +
		" physical_matches=" + physical + " foundation_matches=" + foundation +
		" access_matches=" + access + " shell_matches=" + shell +
		" completed=" + completed + " pending=" + pending + " plan_status=" + planStatus +
		" reservations=" + reservations + " desired_tiles=" + desiredTiles + " work_tiles=" + workTiles +
		" archived_complete=" + AIBI_Bool(archived) +
		" knight_shop=" + AIBI_Bool(knightExact) + " archer_shop=" + AIBI_Bool(archerExact) +
		" knight_shop_healthy=" + AIBI_Bool(knightShop !is null) +
		" archer_shop_healthy=" + AIBI_Bool(archerShop !is null) +
		" roof_cover_matches=" + roofCover + " roof_cover_expected=10" +
		" backing_cover_matches=" + backingCover + " backing_cover_expected=28" +
		" side_cover_matches=" + sideCover + " side_cover_expected=" + expectedSideCover + " bounded_cover=" + AIBI_Bool(boundedCover) +
		" home_gate=" + AIBI_Bool(homeDoor !is null) + " home_gate_x=" + homeGateX +
		" home_upper_cover=" + AIBI_Bool(homeUpperCover) +
		" enemy_wall_matches=" + enemyWallMatched + " enemy_wall_expected=" + expectedEnemyWall + " enemy_wall_x=" + enemyWallX +
		" friendly_route_penalty=" + rules.get_f32("aib infrastructure route penalty") +
		" home_route_started=" + AIBI_Bool(probeStart > 0) +
		" home_route_reached=" + AIBI_Bool(rules.get_u32("aib infrastructure knight overlap tick") > 0) +
		" home_route_ticks=" + homeRouteTicks +
		" home_start_distance_tiles=" + rules.get_f32("aib infrastructure home start distance tiles") +
		" home_access_rise=" + rules.get_u8("aib infrastructure home access rise") +
		" knight_shop_used=" + AIBI_Bool(knightUsedTick > 0) +
		" archer_shop_used=" + AIBI_Bool(archerUsedTick > 0) + " class_use_ticks=" + classUseTicks +
		" final_class=" + finalClass +
		" ally_home_entered=" + AIBI_Bool(rules.get_u32("aib infrastructure rear crossed tick") > 0) +
		" ally_home_exited=" + AIBI_Bool(rules.get_u32("aib infrastructure front crossed tick") > 0) +
		" ally_traversal_ticks=" + traversal +
		" ally_final_x=" + probeFinalX + " ally_final_y=" + probeFinalY +
		" ally_progress_px=" + rules.get_f32("aib infrastructure probe progress") +
		" completion_tick=" + rules.get_u32("aib infrastructure completion tick") +
		" elapsed=" + elapsed + " ai_actor_cap=" + AIBI_TOTAL_AI_LIMIT + " managed_actor_peak=2" +
		" passed=" + AIBI_Bool(finalPassed) + " reason=" + finalReason;
	AIBI_EmitLine(line);
	tcpr("AIBGYMI|RESULT|run=" + runID + "|passed=" + AIBI_Bool(finalPassed) + "|reason=" + finalReason);
	AIBI_RestoreProbePlayer(rules);
	AIBI_StopTaggedActors();
	AIBP_CancelCurrentPlan(team, "infrastructure_benchmark_complete");
	rules.set_bool("aib infrastructure active", false);
	rules.set_bool("aib infrastructure request", false);
	rules.set_bool("aib infrastructure stop requested", false);
	rules.set_string("aib infrastructure phase", "idle");
	rules.set_string("aib infrastructure status", (finalPassed ? "passed:" : "failed:") + finalReason);
	rules.set_u32("aib infrastructure readiness deadline", 0);
}

u16 AIBI_CountEnemyBlockers(CRules@ rules)
{
	if (rules is null) return 0;
	const u8 team = rules.get_u8("aib infrastructure team");
	const int direction = rules.get_s32("aib infrastructure direction");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	u16 count = 0;
	if (AIBI_IsWorkshopMetric(rules))
	{
		for (u8 depth = 0; depth < AIBI_WorkshopEnemyWallDepth(rules); depth++)
		{
			const int enemyWallX = anchorX + direction * (8 - depth);
			for (int y = 1; y <= 3; y++)
			{
				if (AIBP_MapMatchesBlock(u16(enemyWallX), u16(groundY - y), AIBP_STONE_BLOCK, team)) count++;
			}
		}
		if (AIBP_GetMatchingPlanBlob(u16(anchorX - direction * 8), u16(groundY - 1),
			AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), team) !is null) count++;
	}
	else
	{
		if (AIBP_GetMatchingPlanBlob(u16(anchorX + direction * 3), u16(groundY - 1),
			AIBS_GatehouseDoorBlock(), team) !is null) count++;
		if (AIBP_GetMatchingPlanBlob(u16(anchorX - direction * 3), u16(groundY - 1),
			AIBS_GatehouseDoorBlock(), team) !is null) count++;
	}
	return count;
}

f32 AIBI_EnemyBlockerHealth(CRules@ rules)
{
	if (rules is null) return 0.0f;
	const u8 team = rules.get_u8("aib infrastructure team");
	const int direction = rules.get_s32("aib infrastructure direction");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	f32 health = 0.0f;
	if (AIBI_IsWorkshopMetric(rules))
	{
		CBlob@ door = AIBP_GetMatchingPlanBlob(u16(anchorX - direction * 8), u16(groundY - 1),
			AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), team);
		if (door !is null) health += door.getHealth();
	}
	else
	{
		CBlob@ front = AIBP_GetMatchingPlanBlob(u16(anchorX + direction * 3), u16(groundY - 1),
			AIBS_GatehouseDoorBlock(), team);
		CBlob@ rear = AIBP_GetMatchingPlanBlob(u16(anchorX - direction * 3), u16(groundY - 1),
			AIBS_GatehouseDoorBlock(), team);
		if (front !is null) health += front.getHealth();
		if (rear !is null) health += rear.getHealth();
	}
	return health;
}

u32 AIBI_TicksSince(const u32 absoluteTick, const u32 startTick)
{
	return absoluteTick > 0 && startTick > 0 && absoluteTick >= startTick ? absoluteTick - startTick : 0;
}

void AIBI_FinishBreach(CRules@ rules, const bool passed, const string &in reason)
{
	if (rules is null) return;
	const u8 team = rules.get_u8("aib infrastructure team");
	const u8 enemyTeam = rules.get_u8("aib infrastructure enemy team");
	const bool workshops = AIBI_IsWorkshopMetric(rules);
	u16 physical = 0; u16 foundation = 0; u16 access = 0; u16 shell = 0;
	AIBI_CountPhysical(team, physical, foundation, access, shell);
	const u32 startTick = rules.get_u32("aib infrastructure start tick");
	const u32 elapsed = getGameTime() >= startTick ? getGameTime() - startTick : 0;
	const u32 allyStart = rules.get_u32("aib infrastructure probe start tick");
	const u32 allyEnd = rules.get_u32("aib infrastructure probe end tick");
	const u32 enemyStart = rules.get_u32("aib infrastructure enemy probe start tick");
	u32 enemyEnd = rules.get_u32("aib infrastructure enemy probe end tick");
	if (enemyStart > 0 && enemyEnd == 0) enemyEnd = getGameTime();
	const u32 pickaxeCommands = rules.get_u32("aib infrastructure enemy command count");
	const bool realBound = rules.get_u32("aib infrastructure enemy player bound tick") > 0;
	const bool contacted = rules.get_u32("aib infrastructure enemy contact tick") > 0;
	const bool damaged = rules.get_u32("aib infrastructure enemy damage tick") > 0;
	const bool friendlyValid = rules.get_bool("aib infrastructure friendly validated");
	const bool evidenceValid = realBound && pickaxeCommands >= AIBI_ENEMY_MIN_PICKAXE_COMMANDS && contacted && damaged;
	const bool finalPassed = passed && friendlyValid && evidenceValid;
	const string finalReason = finalPassed ? reason : (passed ? "enemy_probe_evidence_incomplete" : reason);
	const u16 initialBlockers = rules.get_u16("aib infrastructure enemy initial blockers");
	const u16 finalBlockers = AIBI_CountEnemyBlockers(rules);
	const f32 initialHealth = rules.get_f32("aib infrastructure enemy initial blocker health");
	const f32 finalHealth = AIBI_EnemyBlockerHealth(rules);
	CBlob@ enemyProbe = getBlobByNetworkID(rules.get_netid("aib infrastructure enemy probe blob"));
	const Vec2f enemyFinal = enemyProbe is null ? rules.get_Vec2f("aib infrastructure enemy final") : enemyProbe.getPosition();
	const Vec2f allyFinal = rules.get_Vec2f("aib infrastructure ally final");
	string outcome = rules.get_string("aib infrastructure enemy outcome");
	if (outcome == "") outcome = "invalid";
	const u16 planID = rules.get_u16("aib infrastructure plan id");
	const string archivePrefix = "aib strategy history plan " + planID + " team " + int(team) + " ";
	const bool archived = rules.get_string(archivePrefix + "archive reason") == "completed";
	const string metricName = workshops ? "protected_class_workshops_enemy_breach_physical" :
		"flag_gatehouse_enemy_breach_physical";
	const u16 fixtureVersion = workshops ? AIBI_WORKSHOP_BREACH_FIXTURE_VERSION :
		AIBI_GATEHOUSE_BREACH_FIXTURE_VERSION;
	const string line = "[AIBGYMI] schema=" + AIBI_BREACH_SCHEMA_VERSION + " status=result run=" +
		rules.get_string("aib infrastructure run id") +
		" variant=" + rules.get_string("aib infrastructure variant") + " metric=" + metricName +
		" fixture_id=" + rules.get_string("aib infrastructure fixture id") +
		" fixture_version=" + fixtureVersion + " team=" + team + " enemy_team=" + enemyTeam +
		" team_side=" + rules.get_string("aib infrastructure team side") +
		" map_hash=" + rules.get_u32("aib infrastructure map hash") +
		" map_width=" + rules.get_u16("aib infrastructure map width") +
		" map_height=" + rules.get_u16("aib infrastructure map height") +
		" initial_terrain_hash=" + rules.get_u32("aib infrastructure initial terrain hash") +
		" initial_fingerprint=" + rules.get_string("aib infrastructure initial fingerprint") +
		" template=" + (workshops ? "protected_workshops" : "flag_gatehouse") +
		" anchor_x=" + rules.get_s32("aib infrastructure anchor x") +
		" ground_y=" + rules.get_s32("aib infrastructure ground y") +
		" enemy_direction=" + rules.get_s32("aib infrastructure direction") +
		" plan_id=" + planID + " plan_version=" + rules.get_u16("aib infrastructure plan version") +
		" tasks=" + rules.get_u16("aib infrastructure tasks") +
		" initial_matches=" + rules.get_u16("aib infrastructure initial matches") +
		" physical_matches=" + rules.get_u16("aib infrastructure pre attack physical") +
		" completed=" + rules.get_u16("aib infrastructure pre attack completed") +
		" pending=" + rules.get_u16("aib infrastructure pre attack pending") +
		" reservations=" + rules.get_u16("aib infrastructure pre attack reservations") +
		" work_tiles=" + rules.get_u16("aib infrastructure pre attack work tiles") +
		" pre_attack_physical_matches=" + rules.get_u16("aib infrastructure pre attack physical") +
		" pre_attack_foundation_matches=" + rules.get_u16("aib infrastructure pre attack foundation") +
		" pre_attack_access_matches=" + rules.get_u16("aib infrastructure pre attack access") +
		" pre_attack_shell_matches=" + rules.get_u16("aib infrastructure pre attack shell") +
		" pre_attack_plan_complete=" + AIBI_Bool(rules.get_bool("aib infrastructure pre attack plan complete")) +
		" archived_complete=" + AIBI_Bool(archived) +
		" physical_matches_final=" + physical + " foundation_matches_final=" + foundation +
		" access_matches_final=" + access + " shell_matches_final=" + shell +
		" friendly_validated=" + AIBI_Bool(friendlyValid) +
		" ally_home_entered=" + AIBI_Bool(rules.get_u32("aib infrastructure rear crossed tick") > 0) +
		" ally_home_exited=" + AIBI_Bool(rules.get_u32("aib infrastructure front crossed tick") > 0) +
		" ally_traversal_ticks=" + AIBI_TicksSince(allyEnd, allyStart) +
		" ally_final_x=" + allyFinal.x + " ally_final_y=" + allyFinal.y +
		" enemy_probe_real=" + AIBI_Bool(realBound) + " enemy_class=builder enemy_attack_kind=pickaxe" +
		" enemy_player_bound=" + AIBI_Bool(realBound) +
		" enemy_attack_origin=client_existing_pickaxe_command" +
		" enemy_movement_controller=server_static_outer_stance_then_bounded_velocity" +
		" enemy_pickaxe_commands=" + pickaxeCommands +
		" enemy_contact=" + AIBI_Bool(contacted) + " enemy_damage_observed=" + AIBI_Bool(damaged) +
		" enemy_entered=" + AIBI_Bool(rules.get_u32("aib infrastructure enemy entered tick") > 0) +
		" enemy_crossed=" + AIBI_Bool(rules.get_u32("aib infrastructure enemy crossed tick") > 0) +
		" enemy_initial_blockers=" + initialBlockers + " enemy_final_blockers=" + finalBlockers +
		" enemy_initial_blocker_health=" + initialHealth + " enemy_final_blocker_health=" + finalHealth +
		" enemy_first_command_ticks=" + AIBI_TicksSince(rules.get_u32("aib infrastructure enemy command tick"), enemyStart) +
		" enemy_last_command_ticks=" + AIBI_TicksSince(rules.get_u32("aib infrastructure enemy last command tick"), enemyStart) +
		" enemy_first_contact_ticks=" + AIBI_TicksSince(rules.get_u32("aib infrastructure enemy contact tick"), enemyStart) +
		" enemy_first_damage_ticks=" + AIBI_TicksSince(rules.get_u32("aib infrastructure enemy damage tick"), enemyStart) +
		" enemy_entry_ticks=" + AIBI_TicksSince(rules.get_u32("aib infrastructure enemy entered tick"), enemyStart) +
		" enemy_crossing_ticks=" + AIBI_TicksSince(rules.get_u32("aib infrastructure enemy crossed tick"), enemyStart) +
		" enemy_probe_ticks=" + AIBI_TicksSince(enemyEnd, enemyStart) + " enemy_outcome=" + outcome +
		" enemy_final_x=" + enemyFinal.x + " enemy_final_y=" + enemyFinal.y +
		" completion_tick=" + rules.get_u32("aib infrastructure completion tick") +
		" elapsed=" + elapsed + " ai_actor_cap=" + AIBI_TOTAL_AI_LIMIT + " managed_actor_peak=2" +
		" passed=" + AIBI_Bool(finalPassed) + " reason=" + finalReason;
	AIBI_EmitLine(line);
	tcpr("AIBGYMI|RESULT|run=" + rules.get_string("aib infrastructure run id") +
		"|passed=" + AIBI_Bool(finalPassed) + "|reason=" + finalReason);
	AIBI_SetClientAction(rules, 0);
	AIBI_RestoreProbePlayer(rules);
	AIBI_StopTaggedActors();
	AIBP_CancelCurrentPlan(team, "infrastructure_benchmark_complete");
	rules.set_bool("aib infrastructure active", false);
	rules.set_bool("aib infrastructure request", false);
	rules.set_bool("aib infrastructure stop requested", false);
	rules.set_string("aib infrastructure phase", "idle");
	rules.set_string("aib infrastructure status", (finalPassed ? "passed:" : "failed:") + finalReason);
	rules.set_u32("aib infrastructure readiness deadline", 0);
}

void AIBI_Finish(CRules@ rules, const bool passed, const string &in reason)
{
	if (AIBI_IsBreachMetric(rules)) AIBI_FinishBreach(rules, passed, reason);
	else if (AIBI_IsWorkshopMetric(rules)) AIBI_FinishWorkshops(rules, passed, reason);
	else AIBI_FinishGatehouse(rules, passed, reason);
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
	const string metric = rules.get_string("aib infrastructure metric");
	CPlayer@ probePlayer = null;
	if (metric != AIBI_METRIC_GATEHOUSE && metric != AIBI_METRIC_WORKSHOPS &&
		metric != AIBI_METRIC_GATEHOUSE_BREACH && metric != AIBI_METRIC_WORKSHOPS_BREACH)
	{
		AIBI_Abort(rules, "invalid_metric"); return false;
	}
	if (rules.get_bool("aib gym active") || rules.get_bool("aib wave running") || AIBI_ExistingManagedActors() != 0)
	{
		AIBI_Abort(rules, "contaminated_ai_actors"); return false;
	}
	CMap@ map = getMap();
	CBlob@ home = AIBS_TeamHomeBlob(team);
	CBlob@ enemy = home is null ? null : AIBS_EnemyHomeBlob(team, home.getPosition());
	CBlob@ resourceHome = home is null ? null : AIBS_TeamResourceHomeBlob(team, home.getPosition());
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
	if (AIBI_IsWorkshopMetric(rules) && !AIBI_CaptureResourceHome(rules, resourceHome))
	{
		AIBI_Abort(rules, "resource_home_missing"); return false;
	}
	if (AIBI_IsWorkshopMetric(rules) || AIBI_IsBreachMetric(rules))
	{
		@probePlayer = AIBI_FindProbePlayerCandidate();
		if (probePlayer is null)
		{
			AIBI_Abort(rules, "connected_probe_player_missing"); return false;
		}
		probePlayer.freeze = false;
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
	AIBPlanCandidate@ selected = null;
	if (AIBI_IsWorkshopMetric(rules))
	{
		string workshopDiagnostics;
		@selected = AIBI_SelectProtectedWorkshops(world, workshopDiagnostics);
		const string diagnostic = "AIBGYMI|WORKSHOP_SITES|run=" + rules.get_string("aib infrastructure run id") +
			"|resource_home=" + int(world.resourceHome.x / map.tilesize) + "," + int(world.resourceHome.y / map.tilesize) +
			"|sites=" + workshopDiagnostics;
		print("[AIBGYMI] " + diagnostic);
		tcpr(diagnostic);
		if (selected is null)
		{
			AIBI_Abort(rules, "no_valid_protected_workshops"); return false;
		}
	}
	else
	{
		array<AIBPlanCandidate@> candidates;
		AIBS_GenerateCandidates(world, candidates, true);
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
	}
	rules.set_u8("aib infrastructure enemy wall depth", AIBI_IsWorkshopMetric(rules) ?
		AIBS_ProtectedWorkshopsEnemyWallDepth() : 1);
	rules.Sync("aib infrastructure enemy wall depth", true);
	BlueprintPlan@ plan = AIBS_MakePlan(world, selected);
	if (plan is null || plan.tasks.length == 0 || !AIBP_PublishAIPlan(plan, true))
	{
		AIBI_Abort(rules, "plan_publish_failed"); return false;
	}

	rules.set_s32("aib infrastructure anchor x", s32(selected.anchor.x));
	rules.set_s32("aib infrastructure ground y", s32(selected.anchor.y));
	rules.set_s32("aib infrastructure direction", world.enemyDirection);
	rules.set_u8("aib infrastructure home access rise", AIBI_IsWorkshopMetric(rules) ?
		u8(Maths::Min(255, AIBS_ProtectedWorkshopsHomeRise(int(selected.anchor.x), int(selected.anchor.y), world.enemyDirection))) : 0);
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
	rules.set_u32("aib infrastructure knight overlap tick", 0);
	rules.set_u32("aib infrastructure knight used tick", 0);
	rules.set_u32("aib infrastructure archer overlap tick", 0);
	rules.set_u32("aib infrastructure archer used tick", 0);
	rules.set_u16("aib infrastructure probe player", probePlayer is null ? 0 : probePlayer.getNetworkID());
	if (probePlayer !is null) rules.Sync("aib infrastructure probe player", true);
	rules.set_netid("aib infrastructure probe blob", 0);
	rules.set_netid("aib infrastructure probe holder", 0);
	rules.set_u8("aib infrastructure workshop probe stage", 0);
	rules.set_f32("aib infrastructure home start distance tiles", 0.0f);
	rules.set_bool("aib infrastructure friendly validated", false);
	rules.set_bool("aib infrastructure pre attack plan complete", false);
	rules.set_Vec2f("aib infrastructure ally final", Vec2f_zero);
	rules.set_Vec2f("aib infrastructure enemy final", Vec2f_zero);
	rules.set_netid("aib infrastructure enemy probe blob", 0);
	rules.set_u32("aib infrastructure enemy probe start tick", 0);
	rules.set_u32("aib infrastructure enemy probe end tick", 0);
	rules.set_u32("aib infrastructure enemy player bound tick", 0);
	rules.set_u32("aib infrastructure enemy command tick", 0);
	rules.set_u32("aib infrastructure enemy last command tick", 0);
	rules.set_u32("aib infrastructure enemy command count", 0);
	rules.set_u32("aib infrastructure enemy contact tick", 0);
	rules.set_u32("aib infrastructure enemy damage tick", 0);
	rules.set_u32("aib infrastructure enemy entered tick", 0);
	rules.set_u32("aib infrastructure enemy crossed tick", 0);
	rules.set_u16("aib infrastructure enemy initial blockers", 0);
	rules.set_f32("aib infrastructure enemy initial blocker health", 0.0f);
	rules.set_string("aib infrastructure enemy outcome", "");
	AIBI_SetClientAction(rules, 0);
	AIBI_SetClientProbeActive(rules, false);
	rules.set_u32("aib infrastructure build deadline", now + u32(plan.tasks.length) * 45 +
		(AIBI_IsWorkshopMetric(rules) ? 900 : 600));
	rules.set_string("aib infrastructure phase", "building");
	rules.set_string("aib infrastructure status", "building");
	tcpr("AIBGYMI|START|run=" + rules.get_string("aib infrastructure run id") + "|metric=" + metric + "|tasks=" + plan.tasks.length +
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

Vec2f AIBI_FindHomeProbeStart(CBlob@ home, const int direction)
{
	CMap@ map = getMap();
	if (home is null || map is null) return Vec2f_zero;
	Vec2f homeSpace = map.getTileSpacePosition(home.getPosition());
	const int homeX = Maths::Floor(homeSpace.x);
	const int homeY = Maths::Floor(homeSpace.y);
	for (int sideIndex = 0; sideIndex < 2; sideIndex++)
	{
		const int side = sideIndex == 0 ? direction : -direction;
		for (int distance = 3; distance <= 7; distance++)
		{
			for (int offset = 0; offset <= 4; offset++)
			{
				for (int signIndex = 0; signIndex < (offset == 0 ? 1 : 2); signIndex++)
				{
					const int y = homeY + (signIndex == 0 ? offset : -offset);
					Vec2f candidate = Vec2f((homeX + side * distance + 0.5f) * map.tilesize,
						(y + 0.5f) * map.tilesize);
					if (AIBR_IsGroundedStoragePoint(home, candidate)) return candidate;
				}
			}
		}
	}
	return Vec2f_zero;
}

CPlayer@ AIBI_FindProbePlayerCandidate()
{
	for (int i = 0; i < getPlayersCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player is null) continue;
		if (!player.isBot()) return player;
	}
	return null;
}

void AIBI_SetClientProbeTarget(CRules@ rules, CBlob@ target, Vec2f destination)
{
	if (rules is null) return;
	rules.set_u16("aib infrastructure client target", target is null ? 0 : target.getNetworkID());
	rules.set_Vec2f("aib infrastructure client destination", destination);
	rules.Sync("aib infrastructure client target", true);
	rules.Sync("aib infrastructure client destination", true);
}

void AIBI_ClearWorkshopProbeKeys(CBlob@ probe)
{
	if (probe is null) return;
	probe.setKeyPressed(key_left, false);
	probe.setKeyPressed(key_right, false);
	probe.setKeyPressed(key_up, false);
	probe.setKeyPressed(key_down, false);
	probe.setKeyPressed(key_action1, false);
	probe.setKeyPressed(key_action2, false);
}

BrainPath@ AIBI_GetWorkshopBrainPath(CBlob@ probe)
{
	if (probe is null) return null;
	BrainPath@ path;
	if (probe.get("aib infrastructure brain path", @path) && path !is null) return path;
	@path = BrainPath(probe, Path::ALL);
	probe.set("aib infrastructure brain path", @path);
	return path;
}

string AIBI_WorkshopPathPoints(Vec2f[]@ points, const u8 limit)
{
	if (points is null || points.length == 0) return "none";
	string value = "";
	const u32 count = Maths::Min(points.length, u32(limit));
	for (u32 i = 0; i < count; i++)
	{
		if (i > 0) value += ";";
		value += points[i].x + "," + points[i].y;
	}
	if (points.length > count) value += ";more";
	return value;
}

void AIBI_EmitWorkshopPath(CBlob@ probe, BrainPath@ path, Vec2f destination, const string &in reason)
{
	CRules@ rules = getRules();
	if (rules is null || probe is null || path is null) return;
	const Vec2f position = probe.getPosition();
	tcpr("AIBGYMI|PATH|run=" + rules.get_string("aib infrastructure run id") +
		"|reason=" + reason + "|tick=" + getGameTime() +
		"|x=" + position.x + "|y=" + position.y +
		"|dest_x=" + destination.x + "|dest_y=" + destination.y +
		"|variance=" + path.variance + "|high_count=" + path.waypoints.length +
		"|low_count=" + path.path.length +
		"|high=" + AIBI_WorkshopPathPoints(path.waypoints, 12) +
		"|low=" + AIBI_WorkshopPathPoints(path.path, 12));
}

void AIBI_EndWorkshopBrainPath(CBlob@ probe)
{
	if (probe is null) return;
	BrainPath@ path;
	if (probe.get("aib infrastructure brain path", @path) && path !is null) path.EndPath();
	probe.set_Vec2f("aib infrastructure path destination", Vec2f_zero);
	probe.set_u32("aib infrastructure path retry tick", 0);
	AIBI_ClearWorkshopProbeKeys(probe);
}

bool AIBI_DriveWorkshopBrainPath(CBlob@ probe, Vec2f destination)
{
	if (probe is null) return false;
	HighLevelNode@[]@ nodeMap;
	if (!getRules().get("node_map", @nodeMap) || nodeMap is null || nodeMap.length == 0) return false;
	BrainPath@ path = AIBI_GetWorkshopBrainPath(probe);
	if (path is null) return false;
	Vec2f position = probe.getPosition();
	Vec2f previous = probe.get_Vec2f("aib infrastructure path destination");
	const bool destinationChanged = (previous.x == 0.0f && previous.y == 0.0f) ||
		(previous - destination).Length() > 8.0f;
	if (destinationChanged)
	{
		path.EndPath();
		path.SetPath(position, destination);
		probe.set_Vec2f("aib infrastructure path destination", destination);
		probe.set_u32("aib infrastructure path retry tick", getGameTime());
		probe.set_u32("aib infrastructure path sample tick", getGameTime());
		AIBI_EmitWorkshopPath(probe, path, destination, "set");
	}
	path.Tick();
	const u32 now = getGameTime();
	if (now >= probe.get_u32("aib infrastructure path sample tick") + 60)
	{
		probe.set_u32("aib infrastructure path sample tick", now);
		AIBI_EmitWorkshopPath(probe, path, destination, "sample");
	}
	if (path.isPathing())
	{
		path.SetSuggestedKeys();
		path.SetSuggestedAimPos();
		probe.setKeyPressed(key_action1, false);
		probe.setKeyPressed(key_action2, false);
		return true;
	}
	Vec2f remaining = destination - position;
	if (remaining.Length() > 32.0f)
	{
		// BrainPath can exhaust a nominal route after making partial progress.
		// Replan from the new position at a bounded cadence; otherwise the fixed
		// destination suppresses SetPath forever and turns a recoverable route
		// loss into a deterministic 90-tick probe failure.
		if (now >= probe.get_u32("aib infrastructure path retry tick") + 15)
		{
			path.EndPath();
			path.SetPath(position, destination);
			probe.set_u32("aib infrastructure path retry tick", now);
			AIBI_EmitWorkshopPath(probe, path, destination, "retry");
			path.Tick();
			if (path.isPathing())
			{
				path.SetSuggestedKeys();
				path.SetSuggestedAimPos();
				probe.setKeyPressed(key_action1, false);
				probe.setKeyPressed(key_action2, false);
				return true;
			}
		}
		return false;
	}
	const int direction = remaining.x >= 0.0f ? 1 : -1;
	probe.setKeyPressed(key_left, direction < 0 && Maths::Abs(remaining.x) > 1.0f);
	probe.setKeyPressed(key_right, direction > 0 && Maths::Abs(remaining.x) > 1.0f);
	probe.setKeyPressed(key_up, remaining.y < -4.0f);
	probe.setKeyPressed(key_down, false);
	probe.setKeyPressed(key_action1, false);
	probe.setKeyPressed(key_action2, false);
	probe.setAimPos(destination);
	return true;
}

Vec2f AIBI_WorkshopApproach(CBlob@ shop, const int enemyDirection)
{
	if (shop is null) return Vec2f_zero;
	Vec2f approach = shop.getPosition();
	approach.x -= enemyDirection * 18.0f;
	return approach;
}

Vec2f AIBI_WorkshopHomeLanding(CRules@ rules)
{
	CMap@ map = getMap();
	if (rules is null || map is null) return Vec2f_zero;
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const int direction = rules.get_s32("aib infrastructure direction");
	return Vec2f((anchorX - direction * 9 + 0.5f) * map.tilesize,
		(groundY - 0.5f) * map.tilesize);
}

void AIBI_DriveWorkshopCorridor(CBlob@ probe, Vec2f destination)
{
	if (probe is null) return;
	const int direction = destination.x >= probe.getPosition().x ? 1 : -1;
	const f32 horizontal = Maths::Abs(destination.x - probe.getPosition().x);
	probe.setKeyPressed(key_left, direction < 0 && horizontal > 1.0f);
	probe.setKeyPressed(key_right, direction > 0 && horizontal > 1.0f);
	probe.setKeyPressed(key_up, false);
	probe.setKeyPressed(key_down, false);
	probe.setKeyPressed(key_action1, false);
	probe.setKeyPressed(key_action2, false);
	probe.setAimPos(destination);
}

void AIBI_EmitProbeBoundary(CRules@ rules, const string &in boundary, CBlob@ probe)
{
	if (rules is null) return;
	const Vec2f position = probe is null ? Vec2f_zero : probe.getPosition();
	tcpr("AIBGYMI|PROBE|run=" + rules.get_string("aib infrastructure run id") +
		"|boundary=" + boundary + "|tick=" + getGameTime() +
		"|class=" + (probe is null ? "none" : probe.getName()) +
		"|x=" + position.x + "|y=" + position.y);
}

void AIBI_SetWorkshopDriveDestination(CRules@ rules, CBlob@ target, Vec2f destination)
{
	AIBI_SetClientProbeTarget(rules, target, destination);
	CBlob@ probe = AIBI_GetWorkshopProbe(rules);
	AIBI_EndWorkshopBrainPath(probe);
	rules.set_f32("aib infrastructure drive best distance", probe is null ? 999999.0f :
		Maths::Abs(destination.x - probe.getPosition().x));
	rules.set_u32("aib infrastructure drive progress tick", getGameTime());
	rules.set_u32("aib infrastructure path unavailable since", 0);
}

bool AIBI_BindWorkshopProbeForUse(CRules@ rules, CBlob@ probe, CBlob@ shop,
	const u8 waitingStage, const string &in status)
{
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	CBlob@ holder = getBlobByNetworkID(rules.get_netid("aib infrastructure probe holder"));
	if (player is null || holder is null || holder.hasTag("dead") || probe is null || shop is null) return false;
	AIBI_EndWorkshopBrainPath(probe);
	CBlob@ active = player.getBlob();
	if (active !is null && active !is holder && active !is probe) return false;
	if (active is holder) holder.server_SetPlayer(null);
	if (player.getBlob() !is probe) probe.server_SetPlayer(player);
	rules.set_u8("aib infrastructure workshop probe stage", waitingStage);
	rules.set_u32("aib infrastructure class command start tick", getGameTime());
	AIBI_SetClientProbeTarget(rules, shop, shop.getPosition());
	AIBI_SetClientProbeActive(rules, true);
	rules.set_string("aib infrastructure status", status);
	AIBI_EmitProbeBoundary(rules, waitingStage == 1 ? "knight_shop_overlap" : "archer_shop_overlap", probe);
	return true;
}

bool AIBI_AdoptWorkshopClassChange(CRules@ rules, const string &in expectedClass)
{
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	CBlob@ holder = getBlobByNetworkID(rules.get_netid("aib infrastructure probe holder"));
	CBlob@ changed = player is null ? null : player.getBlob();
	if (player is null || holder is null || holder.hasTag("dead") || changed is null ||
		changed.hasTag("dead") || changed.getName() != expectedClass) return false;
	changed.Tag(AIBI_PROBE_TAG);
	changed.Tag("no pickup");
	CBrain@ brain = changed.getBrain();
	if (brain !is null) brain.server_SetActive(false);
	rules.set_netid("aib infrastructure probe blob", changed.getNetworkID());
	AIBI_SetClientProbeActive(rules, false);
	changed.server_SetPlayer(null);
	holder.server_SetPlayer(player);
	AIBI_EmitProbeBoundary(rules, expectedClass + "_shop_used", changed);
	return true;
}

bool AIBI_RequestWorkshopProbeTeam(CRules@ rules, CPlayer@ player, const u8 team)
{
	if (rules is null || player is null) return false;
	RulesCore@ core;
	rules.get("core", @core);
	if (core is null) return false;
	// CTF owns team identity in PlayerInfo and its respawn queue.  Changing only
	// CPlayer leaves that state stale and never creates a same-team holder.
	core.ChangePlayerTeam(player, team);
	return true;
}

bool AIBI_CaptureFriendlyPostconditions(CRules@ rules)
{
	if (rules is null) return false;
	const u8 team = rules.get_u8("aib infrastructure team");
	u16 physical = 0; u16 foundation = 0; u16 access = 0; u16 shell = 0;
	AIBI_CountPhysical(team, physical, foundation, access, shell);
	rules.set_u16("aib infrastructure pre attack physical", physical);
	rules.set_u16("aib infrastructure pre attack foundation", foundation);
	rules.set_u16("aib infrastructure pre attack access", access);
	rules.set_u16("aib infrastructure pre attack shell", shell);
	const u16 taskCount = rules.get_u16("aib infrastructure tasks");
	rules.set_u16("aib infrastructure pre attack completed", rules.get_u16(AIBP_PlanKey(team, "completed")));
	rules.set_u16("aib infrastructure pre attack pending", rules.get_u16(AIBP_PlanKey(team, "pending")));
	rules.set_u16("aib infrastructure pre attack reservations", AIBI_CountReservations(team));
	rules.set_u16("aib infrastructure pre attack work tiles", AIBI_CountLayerTiles(team, AIBP_Layer::ai_work));
	const u16 planID = rules.get_u16("aib infrastructure plan id");
	const string archivePrefix = "aib strategy history plan " + planID + " team " + int(team) + " ";
	const bool planComplete = physical == taskCount &&
		rules.get_u16(AIBP_PlanKey(team, "completed")) == taskCount &&
		rules.get_u16(AIBP_PlanKey(team, "pending")) == 0 &&
		rules.get_u8(AIBP_PlanKey(team, "status")) == 2 && AIBI_CountReservations(team) == 0 &&
		AIBI_CountLayerTiles(team, AIBP_Layer::ai_desired) == taskCount &&
		AIBI_CountLayerTiles(team, AIBP_Layer::ai_work) == 0 &&
		rules.get_string(archivePrefix + "archive reason") == "completed";
	rules.set_bool("aib infrastructure pre attack plan complete", planComplete);
	const bool routeComplete = rules.get_u32("aib infrastructure rear crossed tick") > 0 &&
		rules.get_u32("aib infrastructure front crossed tick") > 0 &&
		rules.get_u32("aib infrastructure probe end tick") > 0;
	bool structureComplete = false;
	CBlob@ ally = null;
	if (AIBI_IsWorkshopMetric(rules))
	{
		@ally = AIBI_GetWorkshopProbe(rules);
		const int direction = rules.get_s32("aib infrastructure direction");
		const int anchorX = rules.get_s32("aib infrastructure anchor x");
		const int groundY = rules.get_s32("aib infrastructure ground y");
		CBlob@ homeDoor = AIBP_GetMatchingPlanBlob(u16(anchorX - direction * 8), u16(groundY - 1),
			AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), team);
		CBlob@ knightShop = AIBI_GetClassWorkshop(rules, true);
		CBlob@ archerShop = AIBI_GetClassWorkshop(rules, false);
		u16 roof = 0; u16 backing = 0; u16 side = 0;
		AIBI_CountWorkshopCover(rules, roof, backing, side);
		structureComplete = homeDoor !is null && knightShop !is null && archerShop !is null &&
			knightShop.getTeamNum() == team && archerShop.getTeamNum() == team &&
			knightShop.get_string("required class") == "knight" &&
			archerShop.get_string("required class") == "archer" &&
			roof == 10 && backing == 28 &&
			side == u16(AIBI_WorkshopEnemyWallDepth(rules)) * 3 + 1 &&
			AIBI_CountEnemyBlockers(rules) == u16(AIBI_WorkshopEnemyWallDepth(rules)) * 3 + 1 &&
			rules.get_u32("aib infrastructure knight used tick") > 0 &&
			rules.get_u32("aib infrastructure archer used tick") > 0 &&
			ally !is null && ally.getName() == "archer";
	}
	else
	{
		@ally = AIBI_FindTagged(AIBI_PROBE_TAG);
		structureComplete = AIBI_CountEnemyBlockers(rules) == 2;
	}
	if (ally !is null) rules.set_Vec2f("aib infrastructure ally final", ally.getPosition());
	const bool valid = planComplete && routeComplete && structureComplete;
	rules.set_bool("aib infrastructure friendly validated", valid);
	return valid;
}

bool AIBI_BeginEnemyTeamSettle(CRules@ rules)
{
	if (rules is null) return false;
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	if (player is null) @player = AIBI_FindProbePlayerCandidate();
	if (player is null) return false;
	const u8 enemyTeam = rules.get_u8("aib infrastructure enemy team");
	if (enemyTeam == rules.get_u8("aib infrastructure team")) return false;
	rules.set_u16("aib infrastructure probe player", player.getNetworkID());
	rules.Sync("aib infrastructure probe player", true);
	rules.set_netid("aib infrastructure team settle holder", 0);
	rules.set_u32("aib infrastructure team stable since", 0);
	rules.set_u32("aib infrastructure team request tick", getGameTime());
	rules.set_u32("aib infrastructure team settle deadline", getGameTime() + AIBI_WORKSHOP_TEAM_TIMEOUT_TICKS);
	AIBI_SetClientAction(rules, 0);
	AIBI_SetClientProbeActive(rules, false);
	if (!AIBI_RequestWorkshopProbeTeam(rules, player, enemyTeam)) return false;
	player.freeze = false;
	rules.set_string("aib infrastructure phase", "enemy_team_settle");
	rules.set_string("aib infrastructure status", "settling_enemy_probe_team");
	AIBI_EmitProbeBoundary(rules, "enemy_team_settle_requested", player.getBlob());
	return true;
}

void AIBI_OnFriendlyProbeComplete(CRules@ rules, const string &in reason)
{
	if (!AIBI_IsBreachMetric(rules))
	{
		AIBI_Finish(rules, true, reason);
		return;
	}
	if (!AIBI_CaptureFriendlyPostconditions(rules))
	{
		AIBI_Finish(rules, false, "friendly_postcondition_failed_before_enemy_probe");
		return;
	}
	rules.set_u16("aib infrastructure enemy initial blockers", AIBI_CountEnemyBlockers(rules));
	rules.set_f32("aib infrastructure enemy initial blocker health", AIBI_EnemyBlockerHealth(rules));
	AIBI_StopTaggedActors();
	if (!AIBI_BeginEnemyTeamSettle(rules))
		AIBI_Finish(rules, false, "enemy_probe_team_settle_start_invalid");
}

bool AIBI_StartEnemyProbe(CRules@ rules)
{
	CMap@ map = getMap();
	if (rules is null || map is null) return false;
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	CBlob@ holder = player is null ? null : player.getBlob();
	const u8 enemyTeam = rules.get_u8("aib infrastructure enemy team");
	if (player is null || holder is null || holder.hasTag("dead") ||
		player.getTeamNum() != enemyTeam || holder.getTeamNum() != enemyTeam) return false;
	const int direction = rules.get_s32("aib infrastructure direction");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const int landing = AIBI_IsWorkshopMetric(rules) ? 9 : 4;
	const int startX = anchorX + direction * landing;
	const int goalX = anchorX - direction * landing;
	if (!AIBI_ProbeCellClear(map, startX, groundY) || !AIBI_ProbeCellClear(map, goalX, groundY)) return false;
	const Vec2f start = Vec2f(startX * map.tilesize + map.tilesize * 0.5f,
		groundY * map.tilesize - map.tilesize * 0.5f);
	const Vec2f goal = Vec2f(goalX * map.tilesize + map.tilesize * 0.5f,
		groundY * map.tilesize - map.tilesize * 0.5f);
	CBlob@ probe = server_CreateBlob("builder", enemyTeam, start);
	if (probe is null) return false;
	probe.Tag(AIBI_PROBE_TAG);
	probe.Tag("no pickup");
	probe.AddScript("AIBInfrastructureEnemyProbeDriver.as");
	CBrain@ brain = probe.getBrain();
	if (brain !is null) brain.server_SetActive(false);
	holder.server_SetPlayer(null);
	probe.server_SetPlayer(player);
	if (player.getBlob() !is probe)
	{
		probe.server_Die();
		holder.server_SetPlayer(player);
		return false;
	}
	probe.setAimPos(goal);
	rules.set_netid("aib infrastructure probe holder", holder.getNetworkID());
	rules.set_netid("aib infrastructure enemy probe blob", probe.getNetworkID());
	rules.set_Vec2f("aib infrastructure enemy start", start);
	rules.set_Vec2f("aib infrastructure enemy final", start);
	AIBI_SetClientProbeTarget(rules, null, goal);
	AIBI_SetClientAction(rules, 1);
	AIBI_SetClientProbeActive(rules, false);
	rules.set_string("aib infrastructure phase", "enemy_probe_settle");
	rules.set_u32("aib infrastructure probe settle until", getGameTime() + AIBI_PROBE_SETTLE_TICKS);
	rules.set_string("aib infrastructure status", "settling_real_enemy_builder");
	AIBI_EmitProbeBoundary(rules, "enemy_builder_bound", probe);
	return true;
}

void AIBI_UpdateEnemyTeamSettle(CRules@ rules)
{
	if (rules is null) return;
	const u32 now = getGameTime();
	if (now >= rules.get_u32("aib infrastructure team settle deadline"))
	{
		AIBI_Finish(rules, false, "enemy_probe_team_settle_timeout"); return;
	}
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	if (player is null)
	{
		AIBI_Finish(rules, false, "enemy_probe_player_lost_during_team_settle"); return;
	}
	const u8 enemyTeam = rules.get_u8("aib infrastructure enemy team");
	if (player.getTeamNum() != enemyTeam)
	{
		if (now - rules.get_u32("aib infrastructure team request tick") >= 60)
		{
			if (!AIBI_RequestWorkshopProbeTeam(rules, player, enemyTeam))
			{
				AIBI_Finish(rules, false, "enemy_probe_team_core_lost"); return;
			}
			rules.set_u32("aib infrastructure team request tick", now);
		}
		rules.set_netid("aib infrastructure team settle holder", 0);
		rules.set_u32("aib infrastructure team stable since", 0);
		return;
	}
	CBlob@ holder = player.getBlob();
	if (holder is null || holder.hasTag("dead") || holder.getTeamNum() != enemyTeam)
	{
		rules.set_netid("aib infrastructure team settle holder", 0);
		rules.set_u32("aib infrastructure team stable since", 0);
		return;
	}
	const u16 holderID = holder.getNetworkID();
	if (rules.get_netid("aib infrastructure team settle holder") != holderID)
	{
		rules.set_netid("aib infrastructure team settle holder", holderID);
		rules.set_u32("aib infrastructure team stable since", now);
		return;
	}
	const u32 stableSince = rules.get_u32("aib infrastructure team stable since");
	if (stableSince == 0 || now - stableSince < AIBI_WORKSHOP_TEAM_STABLE_TICKS) return;
	AIBI_EmitProbeBoundary(rules, "enemy_team_holder_stable", holder);
	if (!AIBI_StartEnemyProbe(rules)) AIBI_Finish(rules, false, "enemy_probe_start_or_route_invalid");
}

void AIBI_BeginEnemyProbeInput(CRules@ rules)
{
	if (rules is null) return;
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	CBlob@ probe = getBlobByNetworkID(rules.get_netid("aib infrastructure enemy probe blob"));
	if (player is null || probe is null || probe.hasTag("dead") || player.getBlob() !is probe ||
		probe.getName() != "builder" || probe.getTeamNum() != rules.get_u8("aib infrastructure enemy team"))
	{
		AIBI_Finish(rules, false, "enemy_probe_binding_lost_during_settle"); return;
	}
	const u32 now = getGameTime();
	CShape@ shape = probe.getShape();
	if (shape !is null) shape.SetStatic(true);
	probe.setPosition(rules.get_Vec2f("aib infrastructure enemy start"));
	probe.setVelocity(Vec2f_zero);
	rules.set_u32("aib infrastructure enemy probe start tick", now);
	rules.set_u32("aib infrastructure enemy player bound tick", now);
	rules.set_u32("aib infrastructure enemy probe deadline", now + AIBI_ENEMY_PROBE_TIMEOUT_TICKS);
	AIBI_SetClientProbeActive(rules, true);
	rules.set_string("aib infrastructure phase", "enemy_probing");
	rules.set_string("aib infrastructure status", "real_enemy_pickaxe_probe");
	AIBI_EmitProbeBoundary(rules, "enemy_input_started", probe);
}

void AIBI_DriveEnemyProbe(CRules@ rules)
{
	CMap@ map = getMap();
	if (rules is null || map is null) return;
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	CBlob@ probe = getBlobByNetworkID(rules.get_netid("aib infrastructure enemy probe blob"));
	if (player is null || probe is null || probe.hasTag("dead") || player.getBlob() !is probe ||
		probe.getName() != "builder" || player.getTeamNum() != rules.get_u8("aib infrastructure enemy team"))
	{
		AIBI_Finish(rules, false, "real_enemy_probe_lost"); return;
	}
	const u32 now = getGameTime();
	rules.set_Vec2f("aib infrastructure enemy final", probe.getPosition());
	const u32 pickaxeCommands = rules.get_u32("aib infrastructure enemy command count");
	const int direction = rules.get_s32("aib infrastructure direction");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const int enemyOffset = AIBI_IsWorkshopMetric(rules) ? 8 : 3;
	const int homeOffset = AIBI_IsWorkshopMetric(rules) ? 8 : 3;
	const f32 enemyPlane = (anchorX + direction * enemyOffset) * map.tilesize + map.tilesize * 0.5f;
	const f32 homePlane = (anchorX - direction * homeOffset) * map.tilesize + map.tilesize * 0.5f;
	const f32 passageY = (groundY - 0.5f) * map.tilesize;
	const Vec2f destination = rules.get_Vec2f("aib infrastructure client destination");
	const f32 dx = destination.x - probe.getPosition().x;
	const u16 blockers = AIBI_CountEnemyBlockers(rules);
	// Both fixtures leave exactly one home-side blocker after the complete
	// enemy-facing wall/door is gone. Do not drive into a partially opened wall;
	// KAG can resolve that head collision by sliding the runner off its landing.
	const bool outerBlockerClosed = blockers > 1;
	AIBI_ClearWorkshopProbeKeys(probe);
	probe.setAimPos(destination);
	CShape@ shape = probe.getShape();
	if (outerBlockerClosed)
	{
		if (shape !is null) shape.SetStatic(true);
		probe.setPosition(rules.get_Vec2f("aib infrastructure enemy start"));
	}
	else if (shape !is null && shape.isStatic()) shape.SetStatic(false);
	Vec2f velocity = probe.getVelocity();
	velocity.x = outerBlockerClosed ? 0.0f : (dx < -1.0f ? -1.5f : (dx > 1.0f ? 1.5f : 0.0f));
	probe.setVelocity(velocity);
	if (rules.get_u32("aib infrastructure enemy contact tick") == 0 &&
		Maths::Abs(probe.getPosition().x - enemyPlane) <= map.tilesize * 2.25f &&
		Maths::Abs(probe.getPosition().y - passageY) <= map.tilesize * 2.5f &&
		pickaxeCommands > 0)
		rules.set_u32("aib infrastructure enemy contact tick", now);
	const f32 blockerHealth = AIBI_EnemyBlockerHealth(rules);
	if (rules.get_u32("aib infrastructure enemy damage tick") == 0 &&
		(blockers < rules.get_u16("aib infrastructure enemy initial blockers") ||
			blockerHealth + 0.01f < rules.get_f32("aib infrastructure enemy initial blocker health")))
		rules.set_u32("aib infrastructure enemy damage tick", now);
	if (rules.get_u32("aib infrastructure enemy entered tick") == 0 &&
		(probe.getPosition().x - enemyPlane) * direction <= 0 &&
		Maths::Abs(probe.getPosition().y - passageY) <= map.tilesize * 2.5f)
		rules.set_u32("aib infrastructure enemy entered tick", now);
	if (rules.get_u32("aib infrastructure enemy crossed tick") == 0 &&
		(probe.getPosition().x - homePlane) * direction <= 0 &&
		Maths::Abs(probe.getPosition().y - passageY) <= map.tilesize * 2.5f)
	{
		rules.set_u32("aib infrastructure enemy crossed tick", now);
		rules.set_u32("aib infrastructure enemy probe end tick", now);
		rules.set_string("aib infrastructure enemy outcome", "crossed");
		AIBI_Finish(rules, true, "real_enemy_pickaxe_crossing_complete");
		return;
	}
	if (probe.getPosition().y >= map.tilemapheight * map.tilesize - map.tilesize)
	{
		AIBI_Finish(rules, false, "real_enemy_probe_fell_from_route"); return;
	}
	if (now >= rules.get_u32("aib infrastructure enemy probe deadline"))
	{
		rules.set_u32("aib infrastructure enemy probe end tick", now);
		const bool validInteraction = rules.get_u32("aib infrastructure enemy player bound tick") > 0 &&
			rules.get_u32("aib infrastructure enemy command count") >= AIBI_ENEMY_MIN_PICKAXE_COMMANDS &&
			rules.get_u32("aib infrastructure enemy contact tick") > 0 &&
			rules.get_u32("aib infrastructure enemy damage tick") > 0;
		const u32 lastCommand = rules.get_u32("aib infrastructure enemy last command tick");
		const bool liveAtDeadline = lastCommand > 0 && now >= lastCommand && now - lastCommand <= 60;
		if (validInteraction && liveAtDeadline && blockers > 0)
		{
			rules.set_string("aib infrastructure enemy outcome", "resisted");
			AIBI_Finish(rules, true, "real_enemy_pickaxe_resisted_until_deadline");
		}
		else
		{
			rules.set_string("aib infrastructure enemy outcome", "invalid");
			const string failure = !validInteraction ? "enemy_probe_no_valid_damage_interaction" :
				(!liveAtDeadline ? "enemy_attack_not_live_at_deadline" : "enemy_route_failed_after_all_blockers_lost");
			AIBI_Finish(rules, false, failure);
		}
	}
}

bool AIBI_BeginWorkshopTeamSettle(CRules@ rules)
{
	if (rules is null) return false;
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	if (player is null) @player = AIBI_FindProbePlayerCandidate();
	if (player is null) return false;
	const u8 team = rules.get_u8("aib infrastructure team");
	rules.set_u16("aib infrastructure probe player", player.getNetworkID());
	rules.Sync("aib infrastructure probe player", true);
	rules.set_netid("aib infrastructure team settle holder", 0);
	rules.set_u32("aib infrastructure team stable since", 0);
	rules.set_u32("aib infrastructure team request tick", getGameTime());
	rules.set_u32("aib infrastructure team settle deadline",
		getGameTime() + AIBI_WORKSHOP_TEAM_TIMEOUT_TICKS);
	if (!AIBI_RequestWorkshopProbeTeam(rules, player, team)) return false;
	player.freeze = false;
	rules.set_string("aib infrastructure phase", "workshop_team_settle");
	rules.set_string("aib infrastructure status", "settling_workshop_probe_team");
	AIBI_EmitProbeBoundary(rules, "team_settle_requested", player.getBlob());
	return true;
}

void AIBI_UpdateWorkshopTeamSettle(CRules@ rules)
{
	if (rules is null) return;
	const u32 now = getGameTime();
	if (now >= rules.get_u32("aib infrastructure team settle deadline"))
	{
		AIBI_Finish(rules, false, "workshop_probe_team_settle_timeout"); return;
	}
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	if (player is null)
	{
		AIBI_Finish(rules, false, "workshop_probe_player_lost_during_team_settle"); return;
	}
	const u8 team = rules.get_u8("aib infrastructure team");
	if (player.getTeamNum() != team)
	{
		if (now - rules.get_u32("aib infrastructure team request tick") >= 60)
		{
			if (!AIBI_RequestWorkshopProbeTeam(rules, player, team))
			{
				AIBI_Finish(rules, false, "workshop_probe_team_core_lost"); return;
			}
			rules.set_u32("aib infrastructure team request tick", now);
		}
		rules.set_netid("aib infrastructure team settle holder", 0);
		rules.set_u32("aib infrastructure team stable since", 0);
		return;
	}
	CBlob@ holder = player.getBlob();
	if (holder is null || holder.hasTag("dead") || holder.getTeamNum() != team)
	{
		rules.set_netid("aib infrastructure team settle holder", 0);
		rules.set_u32("aib infrastructure team stable since", 0);
		return;
	}
	const u16 holderId = holder.getNetworkID();
	if (rules.get_netid("aib infrastructure team settle holder") != holderId)
	{
		rules.set_netid("aib infrastructure team settle holder", holderId);
		rules.set_u32("aib infrastructure team stable since", now);
		return;
	}
	const u32 stableSince = rules.get_u32("aib infrastructure team stable since");
	if (stableSince == 0 || now - stableSince < AIBI_WORKSHOP_TEAM_STABLE_TICKS) return;
	AIBI_EmitProbeBoundary(rules, "team_holder_stable", holder);
	if (!AIBI_StartWorkshopProbe(rules))
		AIBI_Finish(rules, false, "workshop_probe_start_cover_or_route_invalid");
}

bool AIBI_StartWorkshopProbe(CRules@ rules)
{
	CMap@ map = getMap();
	if (rules is null || map is null) return false;
	CBlob@ knightShop = AIBI_GetClassWorkshop(rules, true);
	CBlob@ archerShop = AIBI_GetClassWorkshop(rules, false);
	u16 roofCover = 0; u16 backingCover = 0; u16 sideCover = 0;
	AIBI_CountWorkshopCover(rules, roofCover, backingCover, sideCover);
	const u16 expectedSideCover = u16(AIBI_WorkshopEnemyWallDepth(rules)) * 3 + 1;
	if (knightShop is null || archerShop is null || roofCover != 10 || backingCover != 28 ||
		sideCover != expectedSideCover) return false;
	CBlob@ home = getBlobByNetworkID(rules.get_netid("aib infrastructure resource home"));
	const int direction = rules.get_s32("aib infrastructure direction");
	Vec2f start = AIBI_FindHomeProbeStart(home, direction);
	if (home is null || start == Vec2f_zero) return false;
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	if (player is null) @player = AIBI_FindProbePlayerCandidate();
	if (player is null) return false;
	CBlob@ holder = player.getBlob();
	if (holder is null || holder.hasTag("dead") || player.getTeamNum() != rules.get_u8("aib infrastructure team") ||
		holder.getTeamNum() != rules.get_u8("aib infrastructure team")) return false;
	player.freeze = false;
	CBlob@ probe = server_CreateBlob("builder", rules.get_u8("aib infrastructure team"), start);
	if (probe is null) return false;
	probe.Tag(AIBI_PROBE_TAG);
	probe.Tag("no pickup");
	CBrain@ brain = probe.getBrain();
	if (brain !is null) brain.server_SetActive(false);
	Vec2f homeLanding = AIBI_WorkshopHomeLanding(rules);
	probe.setAimPos(homeLanding);
	rules.set_u16("aib infrastructure probe player", player.getNetworkID());
	rules.Sync("aib infrastructure probe player", true);
	rules.set_netid("aib infrastructure probe holder", holder.getNetworkID());
	rules.set_netid("aib infrastructure probe blob", probe.getNetworkID());
	rules.set_Vec2f("aib infrastructure probe start", start);
	rules.set_f32("aib infrastructure probe progress", 0.0f);
	rules.set_u32("aib infrastructure probe start tick", getGameTime());
	rules.set_u32("aib infrastructure probe progress tick", getGameTime());
	rules.set_u32("aib infrastructure home landing tick", 0);
	rules.set_u32("aib infrastructure probe last seen tick", getGameTime());
	rules.set_u32("aib infrastructure probe deadline", getGameTime() +
		(AIBI_IsBreachMetric(rules) ? AIBI_WORKSHOP_BREACH_PROBE_TIMEOUT_TICKS : AIBI_WORKSHOP_PROBE_TIMEOUT_TICKS));
	rules.set_u8("aib infrastructure workshop probe stage", 0);
	rules.set_u8("aib infrastructure workshop route leg", 0);
	rules.set_f32("aib infrastructure home start distance tiles",
		(start - home.getPosition()).Length() / map.tilesize);
	AIBI_SetWorkshopDriveDestination(rules, knightShop, homeLanding);
	AIBI_SetClientProbeActive(rules, false);
	rules.set_string("aib infrastructure phase", "workshop_probe_settle");
	rules.set_u32("aib infrastructure probe settle until", getGameTime() + AIBI_PROBE_SETTLE_TICKS);
	rules.set_string("aib infrastructure status", "probing_home_to_knight_shop");
	AIBI_EmitProbeBoundary(rules, "home_route_started", probe);
	return true;
}

void AIBI_DriveWorkshopProbe(CRules@ rules)
{
	CMap@ map = getMap();
	if (rules is null || map is null) return;
	CPlayer@ player = AIBI_GetProbePlayer(rules);
	if (player is null || player.getTeamNum() != rules.get_u8("aib infrastructure team"))
	{
		AIBI_Finish(rules, false, "workshop_probe_player_lost"); return;
	}
	CBlob@ holder = getBlobByNetworkID(rules.get_netid("aib infrastructure probe holder"));
	if (holder is null || holder.hasTag("dead"))
	{
		AIBI_Finish(rules, false, "workshop_probe_holder_lost"); return;
	}
	if (getGameTime() >= rules.get_u32("aib infrastructure probe deadline"))
	{
		AIBI_Finish(rules, false, "workshop_probe_timeout"); return;
	}

	const int direction = rules.get_s32("aib infrastructure direction");
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const u8 stage = rules.get_u8("aib infrastructure workshop probe stage");
	if (stage == 1)
	{
		if (!AIBI_AdoptWorkshopClassChange(rules, "knight")) return;
		rules.set_u32("aib infrastructure knight used tick", getGameTime());
		rules.set_u8("aib infrastructure workshop probe stage", 2);
		CBlob@ archerShop = AIBI_GetClassWorkshop(rules, false);
		if (archerShop is null) { AIBI_Finish(rules, false, "archer_shop_lost_before_use"); return; }
		AIBI_SetWorkshopDriveDestination(rules, archerShop, AIBI_WorkshopApproach(archerShop, direction));
		rules.set_string("aib infrastructure status", "probing_knight_to_archer_shop");
		return;
	}
	if (stage == 3)
	{
		if (!AIBI_AdoptWorkshopClassChange(rules, "archer")) return;
		rules.set_u32("aib infrastructure archer used tick", getGameTime());
		rules.set_u8("aib infrastructure workshop probe stage", 4);
		Vec2f exitDestination = Vec2f((anchorX - direction * 9 + 0.5f) * map.tilesize,
			(groundY - 0.5f) * map.tilesize);
		AIBI_SetWorkshopDriveDestination(rules, null, exitDestination);
		rules.set_string("aib infrastructure status", "probing_front_exit_after_class_use");
		return;
	}

	CBlob@ probe = AIBI_GetWorkshopProbe(rules);
	if (probe is null || probe.hasTag("dead"))
	{
		AIBI_Finish(rules, false, "workshop_probe_blob_lost"); return;
	}
	probe.Tag(AIBI_PROBE_TAG);
	probe.Tag("no pickup");
	CBrain@ probeBrain = probe.getBrain();
	if (probeBrain !is null) probeBrain.server_SetActive(false);
	rules.set_u32("aib infrastructure probe last seen tick", getGameTime());
	const f32 projected = (probe.getPosition().x - rules.get_Vec2f("aib infrastructure probe start").x) * direction;
	if (projected >= rules.get_f32("aib infrastructure probe progress") + 1.0f)
	{
		rules.set_f32("aib infrastructure probe progress", projected);
		rules.set_u32("aib infrastructure probe progress tick", getGameTime());
	}
	const f32 rearPlane = (anchorX - direction * 8) * map.tilesize + map.tilesize * 0.5f;
	const f32 passageY = (groundY - 0.5f) * map.tilesize;
	if (rules.get_u32("aib infrastructure rear crossed tick") == 0 &&
		(probe.getPosition().x - rearPlane) * direction >= 0 &&
		Maths::Abs(probe.getPosition().y - passageY) <= map.tilesize * 2.0f)
		rules.set_u32("aib infrastructure rear crossed tick", getGameTime());
	if (probe.getPosition().y >= map.tilemapheight * map.tilesize - map.tilesize)
	{
		AIBI_Finish(rules, false, "workshop_probe_fell_from_route");
		return;
	}

	if (stage == 0)
	{
		CBlob@ shop = AIBI_GetClassWorkshop(rules, true);
		if (shop is null) { AIBI_Finish(rules, false, "knight_shop_lost_during_probe"); return; }
		if (rules.get_u8("aib infrastructure workshop route leg") == 0)
		{
			Vec2f landing = AIBI_WorkshopHomeLanding(rules);
			Vec2f position = probe.getPosition();
			if ((landing - position).Length() <= 18.0f)
			{
				rules.set_u8("aib infrastructure workshop route leg", 1);
				rules.set_u32("aib infrastructure home landing tick", getGameTime());
				AIBI_SetWorkshopDriveDestination(rules, shop, AIBI_WorkshopApproach(shop, direction));
				rules.set_string("aib infrastructure status", "crossing_home_gate_to_knight_shop");
				AIBI_EmitProbeBoundary(rules, "home_landing_reached", probe);
			}
		}
		if (probe.isOverlapping(shop))
		{
			if (rules.get_u32("aib infrastructure knight overlap tick") == 0)
				rules.set_u32("aib infrastructure knight overlap tick", getGameTime());
			if (!AIBI_BindWorkshopProbeForUse(rules, probe, shop, 1, "using_knight_shop"))
				AIBI_Finish(rules, false, "knight_shop_player_bind_failed");
			return;
		}
	}
	else if (stage == 2)
	{
		CBlob@ shop = AIBI_GetClassWorkshop(rules, false);
		if (shop is null) { AIBI_Finish(rules, false, "archer_shop_lost_during_probe"); return; }
		if (probe.isOverlapping(shop))
		{
			if (rules.get_u32("aib infrastructure archer overlap tick") == 0)
				rules.set_u32("aib infrastructure archer overlap tick", getGameTime());
			if (!AIBI_BindWorkshopProbeForUse(rules, probe, shop, 3, "using_archer_shop"))
				AIBI_Finish(rules, false, "archer_shop_player_bind_failed");
			return;
		}
	}
	else if (stage == 4)
	{
		const f32 exitPlane = (anchorX - direction * 9) * map.tilesize + map.tilesize * 0.5f;
		if ((probe.getPosition().x - exitPlane) * direction <= 0 &&
			Maths::Abs(probe.getPosition().y - passageY) <= map.tilesize * 2.0f)
		{
			rules.set_u32("aib infrastructure front crossed tick", getGameTime());
			rules.set_u32("aib infrastructure probe end tick", getGameTime());
			AIBI_OnFriendlyProbeComplete(rules, "protected_workshops_home_route_class_use_and_return_complete");
			return;
		}
	}
	else
	{
		AIBI_Finish(rules, false, "invalid_workshop_probe_stage"); return;
	}

	Vec2f destination = rules.get_Vec2f("aib infrastructure client destination");
	if (destination.x == 0.0f && destination.y == 0.0f)
	{
		AIBI_Finish(rules, false, "workshop_probe_destination_missing"); return;
	}
	const f32 horizontalDistance = Maths::Abs(destination.x - probe.getPosition().x);
	if (horizontalDistance + 0.75f < rules.get_f32("aib infrastructure drive best distance"))
	{
		rules.set_f32("aib infrastructure drive best distance", horizontalDistance);
		rules.set_u32("aib infrastructure drive progress tick", getGameTime());
	}
	const bool graphLeg = stage == 0 && rules.get_u8("aib infrastructure workshop route leg") == 0;
	if (graphLeg && !AIBI_DriveWorkshopBrainPath(probe, destination))
	{
		u32 unavailableSince = rules.get_u32("aib infrastructure path unavailable since");
		if (unavailableSince == 0)
		{
			unavailableSince = getGameTime();
			rules.set_u32("aib infrastructure path unavailable since", unavailableSince);
			rules.set_string("aib infrastructure status", "waiting_for_workshop_brain_path");
		}
		else if (getGameTime() > unavailableSince + 90)
		{
			AIBI_Finish(rules, false, "workshop_brain_path_unavailable");
		}
	}
	else if (graphLeg)
	{
		rules.set_u32("aib infrastructure path unavailable since", 0);
	}
	else
	{
		rules.set_u32("aib infrastructure path unavailable since", 0);
		AIBI_DriveWorkshopCorridor(probe, destination);
	}
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
		if (rules.get_u32("aib infrastructure rear crossed tick") > 0 &&
			rules.get_u32("aib infrastructure front crossed tick") > 0)
			AIBI_OnFriendlyProbeComplete(rules, "physical_gatehouse_and_ally_passage_complete");
		else AIBI_Finish(rules, false, "physical_gatehouse_ally_passage_incomplete");
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
			if (AIBI_IsWorkshopMetric(this))
			{
				if (!AIBI_BeginWorkshopTeamSettle(this))
					AIBI_Finish(this, false, "workshop_probe_team_settle_start_invalid");
			}
			else if (!AIBI_StartProbe(this)) AIBI_Finish(this, false, "ally_probe_start_or_route_invalid");
			return;
		}
		if (getGameTime() >= this.get_u32("aib infrastructure build deadline"))
		{
			AIBI_Finish(this, false, "physical_plan_timeout"); return;
		}
	}
	else if (phase == "workshop_team_settle") AIBI_UpdateWorkshopTeamSettle(this);
	else if (phase == "enemy_team_settle") AIBI_UpdateEnemyTeamSettle(this);
	else if (phase == "enemy_probe_settle")
	{
		CPlayer@ player = AIBI_GetProbePlayer(this);
		CBlob@ probe = getBlobByNetworkID(this.get_netid("aib infrastructure enemy probe blob"));
		if (player is null || probe is null || probe.hasTag("dead") || player.getBlob() !is probe)
		{
			AIBI_Finish(this, false, "enemy_probe_lost_during_settle"); return;
		}
		AIBI_ClearWorkshopProbeKeys(probe);
		// A newly rebound local runner can retain/receive player motion while its
		// ownership settles. Keep fixture setup on the exact paid landing; after
		// measurement starts this pin is never used and collision owns the route.
		probe.setPosition(this.get_Vec2f("aib infrastructure enemy start"));
		probe.setVelocity(Vec2f_zero);
		if (getGameTime() >= this.get_u32("aib infrastructure probe settle until"))
			AIBI_BeginEnemyProbeInput(this);
	}
	else if (phase == "enemy_probing") AIBI_DriveEnemyProbe(this);
	else if (phase == "workshop_probe_settle")
	{
		CBlob@ probe = AIBI_GetWorkshopProbe(this);
		if (probe is null) { AIBI_Finish(this, false, "workshop_probe_lost_during_settle"); return; }
		AIBI_ClearWorkshopProbeKeys(probe);
		if (getGameTime() >= this.get_u32("aib infrastructure probe settle until"))
		{
			this.set_string("aib infrastructure phase", "workshop_probing");
		}
	}
	else if (phase == "workshop_probing") AIBI_DriveWorkshopProbe(this);
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
