#include "BlueprintData.as";
#include "AIBHomeResourceCommon.as";
#include "Pathing/BrainPathing.as";

const string AIBM_MANUAL_CONTROL_KEY = "aib player manual order";
const string AIBM_RETIRE_PENDING_KEY = "aib strategy retire pending";
const u8 AIBM_JOB_WOOD = 0;
const u8 AIBM_JOB_STONE = 1;
const u8 AIBM_JOB_BLUEPRINT = 2;
const u8 AIBM_STATE_IDLE = 0;
const u8 AIBM_STATE_FIND_TREE = 1;
const u8 AIBM_STATE_FIND_STONE = 7;
const u8 AIBM_STATE_FIND_BLUEPRINT = 13;

bool AIBM_IsUnderManualControl(CBlob@ builder)
{
	return builder !is null && builder.get_bool(AIBM_MANUAL_CONTROL_KEY);
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

void AIBM_ClearStrategyControl(CBlob@ builder)
{
	if (builder is null) return;
	const int team = builder.getTeamNum();
	if (team >= 0 && team < 8) AIBP_ReleaseBuilderReservation(u8(team), builder.getNetworkID());
	CBrain@ brain = builder.getBrain();
	if (brain !is null) brain.EndPath();
	BrainPath@ path;
	if (builder.get("ai builder brain path", @path) && path !is null) path.EndPath();
	builder.set_bool("aib strategy assigned", false);
	builder.set_bool("aib strategy role pending", false);
	builder.set_bool(AIBM_RETIRE_PENDING_KEY, false);
	builder.set_u8("aib strategy pending job", 0);
	builder.set_u8("aib strategy pending state", 0);
	builder.set_netid(AIBR_ASSIGNED_HOME_KEY, 0);
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
	builder.set_u16("ai builder navigation epoch", builder.get_u16("ai builder navigation epoch") + 1);
	builder.setKeyPressed(key_left, false);
	builder.setKeyPressed(key_right, false);
	builder.setKeyPressed(key_up, false);
	builder.setKeyPressed(key_down, false);
	builder.setKeyPressed(key_action1, false);
	builder.setKeyPressed(key_action2, false);
	builder.setKeyPressed(key_action3, false);
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
