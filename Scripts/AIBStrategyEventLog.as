#include "AIBEventLog.as";

void AIBS_Log(const string &in action, const u8 team, const string &in detail)
{
	CRules@ rules = getRules();
	if (rules is null) return;
	const bool enabled = rules.get_bool("aib event log enabled") || rules.get_bool("aib strategy event log enabled");
	if (!enabled) return;
	AIB_EmitEvent("strategy", action, "team:" + int(team), detail);
}
