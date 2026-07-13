#include "AIBTestScenarios.as";

// Intermediate fixtures remain briefly visible before cleanup. The final
// selected fixture is retained indefinitely after DONE so a human can inspect
// the exact pass/fail scene; closing the AIBTest process is its cleanup.
const u32 AIBT_VISUAL_RESULT_HOLD_TICKS = 15;

int AIBT_index = -1;
int AIBT_firstIndex = 0;
int AIBT_lastIndex = -1;
u16 AIBT_selectedCount = 0;
u32 AIBT_started = 0;
u16 AIBT_passed = 0;
u16 AIBT_failed = 0;
bool AIBT_done = false;
bool AIBT_resultPending = false;
u32 AIBT_resultTick = 0;
u32 AIBT_lastHeartbeat = 0;

int AIBT_FindScenarioIndex(const string &in name)
{
	for (uint i = 0; i < AIBT_SCENARIOS.length; i++)
	{
		if (AIBT_SCENARIOS[i] == name) return int(i);
	}
	return -1;
}

bool AIBT_ConfigureSelection(string &out error)
{
	error = "";
	AIBT_firstIndex = 0;
	AIBT_lastIndex = int(AIBT_SCENARIOS.length) - 1;
	AIBT_selectedCount = AIBT_SCENARIOS.length;

	ConfigFile cfg = ConfigFile("../Mods/GuiftsDynamicBlueprint_vDev/Rules/AIBTest/gamemode.cfg");
	const string exact = cfg.read_string("aibtest_scenario", "");
	const string first = cfg.read_string("aibtest_start_scenario", "");
	const string last = cfg.read_string("aibtest_end_scenario", "");

	if (exact != "")
	{
		if (first != "" || last != "")
		{
			error = "aibtest_scenario cannot be combined with range bounds";
			AIBT_selectedCount = 0;
			return false;
		}

		const int exactIndex = AIBT_FindScenarioIndex(exact);
		if (exactIndex < 0)
		{
			error = "unknown scenario " + exact;
			AIBT_selectedCount = 0;
			return false;
		}

		AIBT_firstIndex = exactIndex;
		AIBT_lastIndex = exactIndex;
		AIBT_selectedCount = 1;
		return true;
	}

	if (first != "")
	{
		AIBT_firstIndex = AIBT_FindScenarioIndex(first);
		if (AIBT_firstIndex < 0)
		{
			error = "unknown start scenario " + first;
			AIBT_selectedCount = 0;
			return false;
		}
	}

	if (last != "")
	{
		AIBT_lastIndex = AIBT_FindScenarioIndex(last);
		if (AIBT_lastIndex < 0)
		{
			error = "unknown end scenario " + last;
			AIBT_selectedCount = 0;
			return false;
		}
	}

	if (AIBT_firstIndex > AIBT_lastIndex)
	{
		error = "start scenario comes after end scenario";
		AIBT_selectedCount = 0;
		return false;
	}

	AIBT_selectedCount = u16(AIBT_lastIndex - AIBT_firstIndex + 1);
	return AIBT_selectedCount > 0;
}

void AIBT_ReportSelectionError(CRules@ rules, const string &in error)
{
	AIBT_done = true;
	rules.set_bool("aib tests done", true);
	print("[AIBTEST] CONFIG_ERROR reason=" + error);
	AIBT_PrintFail("configuration", error);
	AIBT_PrintDone(0, 1);
}

void onInit(CRules@ this)
{
	AIBT_EnableEventLog(this);
	this.set_bool("aib tests done", false);
	this.set_string("aib test scenario", "boot");
	this.set_string("aib test display status", "AIBTEST: BOOTING");
	this.Sync("aib test display status", true);
	this.SetCurrentState(GAME);

	string selectionError;
	const bool selectionValid = AIBT_ConfigureSelection(selectionError);
	AIBT_index = AIBT_firstIndex - 1;
	print("[AIBTEST] BOOT scenarios=" + AIBT_selectedCount +
		" first=" + (AIBT_selectedCount > 0 ? AIBT_ScenarioName(AIBT_firstIndex) : "none") +
		" last=" + (AIBT_selectedCount > 0 ? AIBT_ScenarioName(AIBT_lastIndex) : "none"));
	if (!selectionValid)
	{
		AIBT_ReportSelectionError(this, selectionError);
	}
}

void onRestart(CRules@ this)
{
	string selectionError;
	const bool selectionValid = AIBT_ConfigureSelection(selectionError);
	AIBT_index = AIBT_firstIndex - 1;
	AIBT_started = 0;
	AIBT_passed = 0;
	AIBT_failed = 0;
	AIBT_done = !selectionValid;
	AIBT_resultPending = false;
	AIBT_resultTick = 0;
	AIBT_lastHeartbeat = 0;
	this.set_bool("aib tests done", !selectionValid);
	this.set_string("aib test scenario", "boot");
	this.set_string("aib test display status", "AIBTEST: BOOTING");
	this.Sync("aib test display status", true);
	AIBT_EnableEventLog(this);
	if (!selectionValid)
	{
		print("[AIBTEST] CONFIG_ERROR reason=" + selectionError);
	}
}

void onTick(CRules@ this)
{
	if (!isServer() || AIBT_done) return;
	if (getGameTime() < 5) return;
	if (AIBT_resultPending)
	{
		if (getGameTime() - AIBT_resultTick < AIBT_VISUAL_RESULT_HOLD_TICKS) return;
		AIBT_FinishVisualHold(this);
		return;
	}

	if (AIBT_index < AIBT_firstIndex)
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
	const bool finalScenario = AIBT_index >= AIBT_lastIndex;
	if (finalScenario)
	{
		if (failure == "") AIBT_passed++;
		else AIBT_failed++;
		AIBT_done = true;
		this.set_bool("aib tests done", true);
		this.set_string("aib test display status", (failure == "" ? "PASS - FROZEN: " : "FAIL - FROZEN: ") + scenario);
		this.Sync("aib test display status", true);
		this.SetCurrentState(GAME);
		AIBT_FreezeFinalFixture();
		AIBT_PrintFinalVerdict(scenario, elapsed, failure, details, AIBT_passed, AIBT_failed);
		return;
	}

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
	AIBT_resultPending = true;
	AIBT_resultTick = getGameTime();
}

void AIBT_FinishVisualHold(CRules@ this)
{
	AIBT_resultPending = false;
	if (AIBT_index >= AIBT_lastIndex)
	{
		AIBT_done = true;
		this.set_bool("aib tests done", true);
		this.SetCurrentState(GAME);
		AIBT_PrintDone(AIBT_passed, AIBT_failed);
		AIBT_FreezeFinalFixture();
		return;
	}

	AIBT_CleanupScenario();
	AIBT_StartNext(this);
}

void AIBT_StartNext(CRules@ rules)
{
	AIBT_index++;
	if (AIBT_index > AIBT_lastIndex)
	{
		AIBT_done = true;
		rules.set_bool("aib tests done", true);
		rules.SetCurrentState(GAME);
		AIBT_PrintDone(AIBT_passed, AIBT_failed);
		return;
	}

	const string scenario = AIBT_ScenarioName(AIBT_index);
	rules.set_string("aib test scenario", scenario);
	rules.set_string("aib test display status", "RUNNING: " + scenario);
	rules.Sync("aib test display status", true);
	AIBT_PrintStart(scenario);
	AIBT_SetupScenario(AIBT_index);
	AIBT_started = getGameTime();
	AIBT_lastHeartbeat = getGameTime();
}
