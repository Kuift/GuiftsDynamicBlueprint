class AIBTelemetryPolicy
{
	u16 version = 1;
	bool ctfEnabled = true;
	bool playerNoticeEnabled = true;
	string playerNotice = "Privacy-bounded gameplay telemetry is enabled for AI evaluation. It excludes usernames, IP addresses, and chat.";
}

AIBTelemetryPolicy AIB_telemetry_policy;
bool AIB_telemetry_policy_loaded = false;

AIBTelemetryPolicy@ AIB_GetTelemetryPolicy()
{
	if (AIB_telemetry_policy_loaded) return @AIB_telemetry_policy;
	AIB_telemetry_policy_loaded = true;

	ConfigFile cfg = ConfigFile();
	const string filename = CFileMatcher("AIBTelemetryPolicy.cfg").getFirst();
	if (filename != "") cfg.loadFile(filename);
	AIB_telemetry_policy.version = u16(cfg.read_s32("config_version", 1));
	AIB_telemetry_policy.ctfEnabled = cfg.read_bool("ctf_enabled", true);
	AIB_telemetry_policy.playerNoticeEnabled = cfg.read_bool("player_notice_enabled", true);
	AIB_telemetry_policy.playerNotice = cfg.read_string("player_notice",
		"Privacy-bounded gameplay telemetry is enabled for AI evaluation. It excludes usernames, IP addresses, and chat.");
	return @AIB_telemetry_policy;
}

bool AIB_DefaultTelemetryForGamemode(const string &in gamemode)
{
	AIBTelemetryPolicy@ policy = AIB_GetTelemetryPolicy();
	return gamemode == "CTF" && policy.ctfEnabled;
}
