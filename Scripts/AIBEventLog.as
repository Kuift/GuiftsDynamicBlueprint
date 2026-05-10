// AIBEventLog.as

bool AIB_EventLogEnabled()
{
	CRules@ rules = getRules();
	return rules !is null && rules.get_bool("aib event log enabled");
}

string AIB_EventBlobRef(CBlob@ blob)
{
	if (blob is null) return "none";
	return blob.getName() + ":" + blob.getNetworkID();
}

string AIB_EventPlayerRef(CPlayer@ player)
{
	if (player is null) return "none";
	return "player:" + player.getNetworkID();
}

string AIB_EventPos(Vec2f pos)
{
	return "" + int(pos.x) + "," + int(pos.y);
}

void AIB_LogEvent(const string &in source, const string &in action, const string &in actor, const string &in details = "")
{
	CRules@ rules = getRules();
	if (rules is null || !rules.get_bool("aib event log enabled")) return;

	u32 seq = rules.get_u32("aib event log seq") + 1;
	rules.set_u32("aib event log seq", seq);

	string scenario = rules.exists("aib test scenario") ? rules.get_string("aib test scenario") : "manual";
	string line = "[AIBEVT] t=" + getGameTime() +
		" seq=" + seq +
		" scenario=" + scenario +
		" source=" + source +
		" action=" + action +
		" actor=" + actor;

	if (details != "")
	{
		line += " " + details;
	}

	print(line);
}
