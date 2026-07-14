#define SERVER_ONLY

#include "AIBStrategicJobs.as";

const u32 AIBS_OBSERVE_RATE = 30;
const u32 AIBS_REPLAN_RATE = 210;

void onInit(CRules@ this)
{
	if (!isServer()) return;
	AIBS_BuildStaticTerrain();
	for (u8 team = 0; team < 8; team++)
	{
		if (!this.exists(AIBP_ModeKey(team))) this.set_u8(AIBP_ModeKey(team), AIBS_DefaultModeForGamemode(this.gamemode_name));
		AIBS_InitBootstrapPolicy(this, team);
		AIBU_InitSpeedPolicy(this, team);
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
		AIBS_StopAssignedBuilders(team);
		AIBP_ResetTeamPlanForRound(team);
		AIBS_ResetBootstrapForRound(this, team);
		AIBU_ResetSpeedLevel(this, team);
		this.set_u32("aib strategy last replan team " + int(team), 0);
		this.set_u32("aib strategy important event team " + int(team), getGameTime());
		this.set_f32("aib strategy pressure team " + int(team), 0.0f);
		this.set_f32("aib strategy recent attacks team " + int(team), 0.0f);
		this.set_f32("aib strategy previous frontline team " + int(team), 0.0f);
		array<f32> emptyHeat;
		this.set("aib strategy pressure heat team " + int(team), emptyHeat);
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
	// Planning is a team-level responsibility.  Publish the plan even before a
	// builder is deployed so the intent is visible and the first arriving AI
	// builder can be assigned immediately on the next observation heartbeat.
	if (world.home == Vec2f_zero) { AIBS_DecayPressure(team); return; }
	const u32 now = getGameTime();
	const u32 lastPlan = rules.get_u32("aib strategy last replan team " + int(team));
	const u32 important = rules.get_u32("aib strategy important event team " + int(team));
	const bool shouldPlan = rules.get_u16(AIBP_PlanKey(team, "id")) == 0 || now >= lastPlan + AIBS_REPLAN_RATE || important > lastPlan;
	bool cancelledUnsafePlan = false;
	if (shouldPlan)
	{
		const bool activeInvalid = rules.get_u8(AIBP_PlanKey(team, "status")) == 1 && AIBS_ActivePlanInvalid(world);
		AIBPlanCandidate@ candidate = AIBS_SelectCandidate(world);
		bool attemptedPublish = false;
		bool published = false;
		if (candidate !is null && AIBS_ShouldReplacePlan(world, candidate))
		{
			attemptedPublish = true;
			BlueprintPlan@ plan = AIBS_MakePlan(world, candidate);
			published = AIBP_PublishAIPlan(plan, mode == AIBP_StrategyMode::auto_mode);
			if (published) rules.set_u32("aib strategy last replan team " + int(team), now);
		}
		if (!published && activeInvalid)
		{
			cancelledUnsafePlan = AIBP_CancelCurrentPlan(team, "invalidated");
			if (cancelledUnsafePlan)
			{
				// Do not leave director-owned workers carrying stale targets from an
				// unsafe plan merely because no replacement was available or publish
				// failed. Manual player orders are not strategy-assigned and survive.
				AIBS_StopAssignedBuilders(team);
				rules.set_u32("aib strategy last replan team " + int(team), now);
			}
		}
		if (!attemptedPublish && !activeInvalid) rules.set_u32("aib strategy last replan team " + int(team), now);
	}
	if (mode == AIBP_StrategyMode::auto_mode && !cancelledUnsafePlan)
	{
		AIBS_TryBootstrapBuilder(rules, world);
		AIBS_AssignBuilders(world);
	}
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
	if (!isServer()) return;
	if (blob !is null && (blob.getName() == "aibuilder" || AIBU_IsAutoBuilder(blob)) &&
		blob.getTeamNum() >= 0 && blob.getTeamNum() < 8)
	{
		AIBP_ReleaseBuilderReservation(u8(blob.getTeamNum()), blob.getNetworkID());
	}
	AIBS_RecordDeath(blob);
}
