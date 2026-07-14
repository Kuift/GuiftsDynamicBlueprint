#include "BlueprintData.as";
#include "AIBHomeResourceCommon.as";
#include "Pathing/BrainPathing.as";

const string AIBM_MANUAL_CONTROL_KEY = "aib player manual order";
const string AIBM_RETIRE_PENDING_KEY = "aib strategy retire pending";
const string AIBM_RESOURCE_HANDOFF_UNTIL_KEY = "aib strategy resource handoff until";
const u8 AIBM_JOB_WOOD = 0;
const u8 AIBM_JOB_STONE = 1;
const u8 AIBM_JOB_BLUEPRINT = 2;
const u8 AIBM_STATE_IDLE = 0;
const u8 AIBM_STATE_FIND_TREE = 1;
const u8 AIBM_STATE_FIND_STONE = 7;
const u8 AIBM_STATE_COLLECT_BLUEPRINT = 12;
const u8 AIBM_STATE_FIND_BLUEPRINT = 13;

bool AIBM_IsUnderManualControl(CBlob@ builder)
{
	return builder !is null && builder.get_bool(AIBM_MANUAL_CONTROL_KEY);
}

bool AIBM_IsValidStrategyRole(const u8 job, const u8 state)
{
	return (job == AIBM_JOB_WOOD && state == AIBM_STATE_FIND_TREE) ||
		(job == AIBM_JOB_STONE && state == AIBM_STATE_FIND_STONE) ||
		(job == AIBM_JOB_BLUEPRINT && (state == AIBM_STATE_COLLECT_BLUEPRINT || state == AIBM_STATE_FIND_BLUEPRINT));
}

bool AIBM_IsAtStrategyHandoff(CBlob@ builder)
{
	if (builder is null) return false;
	const u8 state = builder.get_u8("ai builder state");
	if (state == AIBM_STATE_IDLE) return true;
	if (builder.get_netid("ai builder target") != 0 || builder.get_Vec2f("ai builder tile target") != Vec2f_zero) return false;
	const u8 job = builder.get_u8("ai builder job");
	if (job == AIBM_JOB_WOOD) return state == AIBM_STATE_FIND_TREE;
	if (job == AIBM_JOB_STONE) return state == AIBM_STATE_FIND_STONE;
	if (job == AIBM_JOB_BLUEPRINT) return state == AIBM_STATE_FIND_BLUEPRINT;
	return false;
}

void AIBM_ClearNavigationIntent(CBlob@ builder)
{
	if (builder is null) return;
	CBrain@ brain = builder.getBrain();
	if (brain !is null) brain.EndPath();
	BrainPath@ path;
	if (builder.get("ai builder brain path", @path) && path !is null) path.EndPath();
	builder.set_netid("ai builder target", 0);
	builder.set_Vec2f("ai builder destination", Vec2f_zero);
	builder.set_Vec2f("ai builder tile target", Vec2f_zero);
	builder.set_Vec2f("ai builder shaft top", Vec2f_zero);
	builder.set_Vec2f("ai builder stone route corner", Vec2f_zero);
	builder.set_bool("ai builder justgo", false);
	builder.set_bool("ai builder mining gold", false);
	builder.set_bool("ai builder direct stone shaft", false);
	builder.set_u8("ai builder obstruction threshold", 0);
	builder.set_Vec2f("ai builder jump peak", Vec2f_zero);
	builder.set_u32("ai builder stone corner escape until", 0);
	builder.set_u32("ai builder stone corner escape cooldown", 0);
	builder.set_s32("ai builder stone corner escape direction", 0);
	builder.set_netid("ai builder delivery home", 0);
	builder.set_Vec2f("ai builder recovery support target", Vec2f_zero);
	builder.set_u32("ai builder recovery support tick", 0);
	builder.set_u8("ai builder recovery support chain", 0);
	builder.set_bool("ai builder recovery path probe pending", false);
	builder.set_netid("ai builder recovery path probe ladder", 0);
	builder.set_u32("ai builder recovery ladder tick", 0);
	builder.set_u16("ai builder navigation epoch", builder.get_u16("ai builder navigation epoch") + 1);
	builder.setKeyPressed(key_left, false);
	builder.setKeyPressed(key_right, false);
	builder.setKeyPressed(key_up, false);
	builder.setKeyPressed(key_down, false);
	builder.setKeyPressed(key_action1, false);
	builder.setKeyPressed(key_action2, false);
	builder.setKeyPressed(key_action3, false);
}

void AIBM_ClearDeferredStrategyRole(CBlob@ builder)
{
	if (builder is null) return;
	builder.set_bool("aib strategy role pending", false);
	builder.set_u8("aib strategy pending job", 0);
	builder.set_u8("aib strategy pending state", 0);
}

bool AIBM_ApplyStrategyRole(CBlob@ builder, const u8 job, const u8 state)
{
	if (builder is null || builder.hasTag("dead") || !AIBM_IsValidStrategyRole(job, state)) return false;
	const int team = builder.getTeamNum();
	const u8 oldJob = builder.get_u8("ai builder job");
	if (oldJob == AIBM_JOB_BLUEPRINT && job != AIBM_JOB_BLUEPRINT && team >= 0 && team < 8)
		AIBP_ReleaseBuilderReservation(u8(team), builder.getNetworkID());
	AIBM_ClearNavigationIntent(builder);
	builder.set_u8("ai builder job", job);
	builder.set_u8("ai builder state", state);
	builder.set_bool("ai builder job active", true);
	builder.set_bool("aib strategy assigned", true);
	AIBM_ClearDeferredStrategyRole(builder);
	builder.set_bool(AIBM_RETIRE_PENDING_KEY, false);
	builder.set_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY, 0);
	builder.Sync("ai builder job", true);
	builder.Sync("ai builder state", true);
	builder.Sync("ai builder job active", true);
	return true;
}

void AIBM_ClearStrategyControl(CBlob@ builder)
{
	if (builder is null) return;
	const int team = builder.getTeamNum();
	if (team >= 0 && team < 8) AIBP_ReleaseBuilderReservation(u8(team), builder.getNetworkID());
	AIBM_ClearNavigationIntent(builder);
	builder.set_bool("aib strategy assigned", false);
	AIBM_ClearDeferredStrategyRole(builder);
	builder.set_bool(AIBM_RETIRE_PENDING_KEY, false);
	builder.set_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY, 0);
	builder.set_netid(AIBR_ASSIGNED_HOME_KEY, 0);
	builder.Sync(AIBR_ASSIGNED_HOME_KEY, true);
}

void AIBM_TakeManualControl(CBlob@ builder)
{
	if (builder is null) return;
	AIBM_ClearStrategyControl(builder);
	builder.set_bool(AIBM_MANUAL_CONTROL_KEY, true);
	builder.Sync(AIBM_MANUAL_CONTROL_KEY, true);
}

void AIBM_StopDirectorControl(CBlob@ builder)
{
	if (builder is null) return;
	AIBM_ClearStrategyControl(builder);
	builder.set_u8("ai builder state", 0);
	builder.set_bool("ai builder job active", false);
	builder.set_bool(AIBM_MANUAL_CONTROL_KEY, false);
	builder.Sync("ai builder state", true);
	builder.Sync("ai builder job active", true);
	builder.Sync(AIBM_MANUAL_CONTROL_KEY, true);
}

bool AIBM_TryRetireAtSafeBoundary(CBlob@ builder)
{
	if (builder is null || !builder.get_bool("aib strategy assigned") ||
		!builder.get_bool(AIBM_RETIRE_PENDING_KEY) || !AIBM_IsAtStrategyHandoff(builder)) return false;
	AIBM_StopDirectorControl(builder);
	return true;
}

bool AIBM_TryApplyDeferredRoleAtSafeBoundary(CBlob@ builder)
{
	if (builder is null || !builder.get_bool("aib strategy assigned") ||
		builder.get_bool(AIBM_RETIRE_PENDING_KEY) || !builder.get_bool("aib strategy role pending") ||
		!AIBM_IsAtStrategyHandoff(builder)) return false;
	const u8 job = builder.get_u8("aib strategy pending job");
	const u8 state = builder.get_u8("aib strategy pending state");
	if (!AIBM_ApplyStrategyRole(builder, job, state)) return false;
	AIBS_Log("assign_handoff", u8(builder.getTeamNum()), "builder=" + builder.getNetworkID() +
		" job=" + job + " state=" + state);
	return true;
}

void AIBM_ReleaseManualControl(CBlob@ builder)
{
	if (!AIBM_IsUnderManualControl(builder)) return;
	builder.set_bool(AIBM_MANUAL_CONTROL_KEY, false);
	builder.Sync(AIBM_MANUAL_CONTROL_KEY, true);
}

void AIBM_ReleaseTeamManualControl(const u8 team)
{
	string[] names = { "aibuilder", "autobuilder" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] builders;
		getBlobsByName(names[n], @builders);
		for (uint i = 0; i < builders.length; i++)
		{
			CBlob@ builder = builders[i];
			if (builder is null || builder.hasTag("dead") || builder.getTeamNum() != team) continue;
			AIBM_ReleaseManualControl(builder);
		}
	}
}
