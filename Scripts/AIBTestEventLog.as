#include "AIBEventLog.as";

void AIBT_EnableEventLog(CRules@ rules)
{
	if (rules is null) return;
	rules.set_bool("aib event log enabled", true);
	rules.set_u32("aib event log seq", 0);
}

void AIBT_LogTest(const string &in action, const string &in details = "")
{
	AIB_LogEvent("test", action, "runner", details);
}

void AIBT_PrintStart(const string &in scenario)
{
	print("[AIBTEST] START " + scenario);
	AIBT_LogTest("start", "name=" + scenario);
}

void AIBT_PrintPass(const string &in scenario, const u32 ticks, const string &in details = "")
{
	string line = "[AIBTEST] PASS " + scenario + " ticks=" + ticks;
	if (details != "") line += " " + details;
	print(line);
	AIBT_LogTest("pass", "name=" + scenario + " ticks=" + ticks + " " + details);
}

void AIBT_PrintFail(const string &in scenario, const string &in reason)
{
	print("[AIBTEST] FAIL " + scenario + " reason=" + reason);
	AIBT_LogTest("fail", "name=" + scenario + " reason=" + reason);
}

void AIBT_PrintDone(const u16 passed, const u16 failed)
{
	print("[AIBTEST] DONE passed=" + passed + " failed=" + failed);
	AIBT_LogTest("done", "passed=" + passed + " failed=" + failed);
}
