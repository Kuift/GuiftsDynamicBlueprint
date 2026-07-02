#define SERVER_ONLY

#include "AIBPlacementPlanner.as";

const u32 AIBS_OBSERVE_RATE = 30;
const u32 AIBS_REPLAN_RATE = 210;
const u8 AIBS_JOB_WOOD = 0;
const u8 AIBS_JOB_STONE = 1;
const u8 AIBS_JOB_BLUEPRINT = 2;
const u8 AIBS_STATE_IDLE = 0;
const u8 AIBS_STATE_FIND_TREE = 1;
const u8 AIBS_STATE_FIND_STONE = 7;
const u8 AIBS_STATE_COLLECT_BLUEPRINT = 12;

void onInit(CRules@ this)
{
	if (!isServer()) return;
	AIBS_BuildStaticTerrain();
	for (u8 team = 0; team < 8; team++)
	{
		if (!this.exists(AIBP_ModeKey(team))) this.set_u8(AIBP_ModeKey(team), this.gamemode_name == "AIBTest" ? AIBP_StrategyMode::off : AIBP_StrategyMode::suggest);
		this.set_u8("aib strategy last mode team " + int(team), this.get_u8(AIBP_ModeKey(team)));
		this.Sync(AIBP_ModeKey(team), true);
	}
}

void onRestart(CRules@ this)
{
	if (!isServer()) return;
	AIBS_BuildStaticTerrain();
	for (u8 team = 0; team < 8; team++)
	{
		this.set_u32("aib strategy last replan team " + int(team), 0);
		this.set_u32("aib strategy important event team " + int(team), getGameTime());
		this.set_f32("aib strategy pressure team " + int(team), 0.0f);
		this.set_f32("aib strategy recent attacks team " + int(team), 0.0f);
		this.set_f32("aib strategy previous frontline team " + int(team), 0.0f);
		array<f32> emptyHeat;
		this.set("aib strategy pressure heat team " + int(team), emptyHeat);
	}
}

void AIBS_SetBuilderJob(CBlob@ builder, const u8 job, const u8 state)
{
	if (builder is null || builder.hasTag("dead")) return;
	const u8 oldJob = builder.get_u8("ai builder job");
	const u8 oldState = builder.get_u8("ai builder state");
	if (oldJob == job && oldState != AIBS_STATE_IDLE) return;
	if (oldJob == AIBS_JOB_BLUEPRINT && job != AIBS_JOB_BLUEPRINT) AIBP_ReleaseBuilderReservation(u8(builder.getTeamNum()), builder.getNetworkID());
	builder.set_u8("ai builder job", job);
	builder.set_u8("ai builder state", state);
	builder.set_bool("ai builder job active", true);
	builder.set_netid("ai builder target", 0);
	builder.set_Vec2f("ai builder destination", Vec2f_zero);
	builder.set_Vec2f("ai builder tile target", Vec2f_zero);
	builder.set_bool("aib strategy assigned", true);
	builder.Sync("ai builder job", true);
	builder.Sync("ai builder state", true);
	builder.Sync("ai builder job active", true);
	AIBS_Log("assign", u8(builder.getTeamNum()), "builder=" + builder.getNetworkID() + " job=" + job + " state=" + state);
}

void AIBS_AssignBuilders(AIBWorldState@ world)
{
	if (world is null) return;
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	array<CBlob@> teamBuilders;
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder !is null && !builder.hasTag("dead") && builder.getTeamNum() == world.team) teamBuilders.push_back(builder);
	}
	if (teamBuilders.length == 0) return;
	const u16 woodCost = AIBP_RemainingMaterialCost(world.team, "mat_wood");
	const u16 stoneCost = AIBP_RemainingMaterialCost(world.team, "mat_stone");
	const u32 woodShort = woodCost > world.storedWood ? woodCost - world.storedWood : 0;
	const u32 stoneShort = stoneCost > world.storedStone ? stoneCost - world.storedStone : 0;
	const u32 totalShort = woodShort + stoneShort;
	const uint maxCollectors = teamBuilders.length > 1 && world.planPending > 0 ? teamBuilders.length - 1 : teamBuilders.length;
	uint collectors = totalShort == 0 ? 0 : uint(Maths::Ceil(float(totalShort) / 250.0f));
	const uint materialKinds = (woodShort > 0 ? 1 : 0) + (stoneShort > 0 ? 1 : 0);
	collectors = Maths::Min(maxCollectors, Maths::Max(collectors, materialKinds));
	uint woodCollectors = totalShort == 0 ? 0 : uint(Maths::Round(float(collectors) * float(woodShort) / float(totalShort)));
	if (woodShort > 0 && woodCollectors == 0 && collectors > 0) woodCollectors = 1;
	if (stoneShort > 0 && woodCollectors >= collectors && collectors > 1) woodCollectors = collectors - 1;
	const uint stoneCollectors = collectors - woodCollectors;
	uint index = 0;
	for (uint i = 0; i < woodCollectors && index < teamBuilders.length; i++) AIBS_SetBuilderJob(teamBuilders[index++], AIBS_JOB_WOOD, AIBS_STATE_FIND_TREE);
	for (uint i = 0; i < stoneCollectors && index < teamBuilders.length; i++) AIBS_SetBuilderJob(teamBuilders[index++], AIBS_JOB_STONE, AIBS_STATE_FIND_STONE);
	while (index < teamBuilders.length) AIBS_SetBuilderJob(teamBuilders[index++], AIBS_JOB_BLUEPRINT, AIBS_STATE_COLLECT_BLUEPRINT);
}

void AIBS_StopAssignedBuilders(const u8 team)
{
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder is null || builder.getTeamNum() != team || !builder.get_bool("aib strategy assigned")) continue;
		AIBP_ReleaseBuilderReservation(team, builder.getNetworkID());
		builder.set_u8("ai builder state", AIBS_STATE_IDLE);
		builder.set_bool("ai builder job active", false);
		builder.set_bool("aib strategy assigned", false);
		builder.Sync("ai builder state", true);
		builder.Sync("ai builder job active", true);
	}
}

void AIBS_StopTeam(const u8 team)
{
	AIBP_SetAIWorkEnabled(team, false);
	AIBS_StopAssignedBuilders(team);
	AIBS_Log("stop", team, "mode=off");
}

void AIBS_HandleModeChange(CRules@ rules, const u8 team, const u8 mode)
{
	const string lastKey = "aib strategy last mode team " + int(team);
	const u8 previous = rules.get_u8(lastKey);
	if (previous == mode) return;
	rules.set_u8(lastKey, mode);
	if (mode == AIBP_StrategyMode::off) AIBS_StopTeam(team);
	else if (mode == AIBP_StrategyMode::auto_mode) AIBP_SetAIWorkEnabled(team, true);
	else
	{
		AIBP_SetAIWorkEnabled(team, false);
		AIBS_StopAssignedBuilders(team);
	}
	rules.set_u32("aib strategy important event team " + int(team), getGameTime());
	AIBS_Log("mode", team, "from=" + previous + " to=" + mode);
}

void AIBS_UpdateTeam(CRules@ rules, const u8 team)
{
	const u8 mode = rules.get_u8(AIBP_ModeKey(team));
	AIBS_HandleModeChange(rules, team, mode);
	if (mode == AIBP_StrategyMode::off) { AIBS_DecayPressure(team); return; }
	AIBP_RefreshPlanState(team, mode == AIBP_StrategyMode::auto_mode);
	AIBWorldState@ world = AIBS_ObserveWorld(team);
	if (world is null) return;
	if (world.home == Vec2f_zero || world.aiBuilders == 0) { AIBS_DecayPressure(team); return; }
	const u32 now = getGameTime();
	const u32 lastPlan = rules.get_u32("aib strategy last replan team " + int(team));
	const u32 important = rules.get_u32("aib strategy important event team " + int(team));
	const bool shouldPlan = rules.get_u16(AIBP_PlanKey(team, "id")) == 0 || now >= lastPlan + AIBS_REPLAN_RATE || important > lastPlan;
	if (shouldPlan)
	{
		AIBPlanCandidate@ candidate = AIBS_SelectCandidate(world);
		if (candidate !is null && AIBS_ShouldReplacePlan(world, candidate))
		{
			BlueprintPlan@ plan = AIBS_MakePlan(world, candidate);
			if (AIBP_PublishAIPlan(plan, mode == AIBP_StrategyMode::auto_mode))
			{
				rules.set_u32("aib strategy last replan team " + int(team), now);
			}
		}
		else rules.set_u32("aib strategy last replan team " + int(team), now);
	}
	if (mode == AIBP_StrategyMode::auto_mode) AIBS_AssignBuilders(world);
	AIBS_DecayPressure(team);
}

void onTick(CRules@ this)
{
	if (!isServer()) return;
	if (getGameTime() % AIBS_OBSERVE_RATE != 0) return;
	for (u8 team = 0; team < 8; team++) AIBS_UpdateTeam(this, team);
}

void onBlobDie(CRules@ this, CBlob@ blob)
{
	if (isServer()) AIBS_RecordDeath(blob);
}
