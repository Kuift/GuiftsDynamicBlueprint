#include "AIBTestScenarios.as";

int AIBT_index = -1;
u32 AIBT_started = 0;
u16 AIBT_passed = 0;
u16 AIBT_failed = 0;
bool AIBT_done = false;
u32 AIBT_lastHeartbeat = 0;

void onInit(CRules@ this)
{
	AIBT_EnableEventLog(this);
	this.set_bool("aib tests done", false);
	this.set_string("aib test scenario", "boot");
	this.SetCurrentState(GAME);
	print("[AIBTEST] BOOT scenarios=" + AIBT_SCENARIOS.length);
}

void onRestart(CRules@ this)
{
	AIBT_index = -1;
	AIBT_started = 0;
	AIBT_passed = 0;
	AIBT_failed = 0;
	AIBT_done = false;
	AIBT_lastHeartbeat = 0;
	this.set_bool("aib tests done", false);
	this.set_string("aib test scenario", "boot");
	AIBT_EnableEventLog(this);
}

void onTick(CRules@ this)
{
	if (!isServer() || AIBT_done) return;
	if (getGameTime() < 5) return;

	if (AIBT_index < 0)
	{
		AIBT_StartNext(this);
		return;
	}

	string failure;
	string details;
	const u32 elapsed = getGameTime() - AIBT_started;
	if (getGameTime() - AIBT_lastHeartbeat >= 30)
	{
		print("[AIBTEST] HEARTBEAT scenario=" + AIBT_ScenarioName(AIBT_index) + " elapsed=" + elapsed + " gametime=" + getGameTime());
		AIBT_lastHeartbeat = getGameTime();
	}

	if (!AIBT_EvaluateScenario(AIBT_index, elapsed, failure, details))
	{
		return;
	}

	const string scenario = AIBT_ScenarioName(AIBT_index);
	if (failure == "")
	{
		AIBT_passed++;
		AIBT_PrintPass(scenario, elapsed, details);
	}
	else
	{
		AIBT_failed++;
		AIBT_PrintFail(scenario, failure);
	}

	if (AIBT_index + 1 >= int(AIBT_SCENARIOS.length))
	{
		AIBT_done = true;
		this.set_bool("aib tests done", true);
		this.SetCurrentState(GAME);
		AIBT_PrintDone(AIBT_passed, AIBT_failed);
		AIBT_CleanupScenario();
		return;
	}

	AIBT_CleanupScenario();
	AIBT_StartNext(this);
}

void AIBT_StartNext(CRules@ rules)
{
	AIBT_index++;
	if (AIBT_index >= int(AIBT_SCENARIOS.length))
	{
		AIBT_done = true;
		rules.set_bool("aib tests done", true);
		rules.SetCurrentState(GAME);
		AIBT_PrintDone(AIBT_passed, AIBT_failed);
		return;
	}

	const string scenario = AIBT_ScenarioName(AIBT_index);
	rules.set_string("aib test scenario", scenario);
	AIBT_PrintStart(scenario);
	AIBT_SetupScenario(AIBT_index);
	AIBT_started = getGameTime();
	AIBT_lastHeartbeat = getGameTime();
}
