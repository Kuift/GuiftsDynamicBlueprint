const u8 AIBD_POLICY_MODE_OFF = 0;
const u8 AIBD_POLICY_MODE_SUGGEST = 1;
const u8 AIBD_POLICY_MODE_AUTO = 2;

class AIBDirectorPolicy
{
	u16 version = 1;
	u8 ctfDefaultMode = AIBD_POLICY_MODE_AUTO;
	bool ctfBootstrapEnabled = true;
}

AIBDirectorPolicy AIBD_director_policy;
bool AIBD_director_policy_loaded = false;

u8 AIBD_ParseConfiguredMode(const string &in value)
{
	if (value == "off") return AIBD_POLICY_MODE_OFF;
	if (value == "suggest") return AIBD_POLICY_MODE_SUGGEST;
	return AIBD_POLICY_MODE_AUTO;
}

AIBDirectorPolicy@ AIBD_GetDirectorPolicy()
{
	if (AIBD_director_policy_loaded) return @AIBD_director_policy;
	AIBD_director_policy_loaded = true;

	ConfigFile cfg = ConfigFile();
	const string filename = CFileMatcher("AIBDirectorPolicy.cfg").getFirst();
	if (filename != "") cfg.loadFile(filename);
	AIBD_director_policy.version = u16(cfg.read_s32("config_version", 1));
	AIBD_director_policy.ctfDefaultMode = AIBD_ParseConfiguredMode(cfg.read_string("ctf_default_mode", "auto"));
	AIBD_director_policy.ctfBootstrapEnabled = cfg.read_bool("ctf_bootstrap_enabled", true);
	return @AIBD_director_policy;
}

string AIBS_BootstrapKey(const u8 team, const string &in field)
{
	return "aib strategy bootstrap " + field + " team " + int(team);
}

bool AIBS_DefaultBootstrapForGamemode(const string &in gamemode)
{
	AIBDirectorPolicy@ policy = AIBD_GetDirectorPolicy();
	return gamemode == "CTF" && policy.ctfBootstrapEnabled;
}

u8 AIBS_DefaultModeForGamemode(const string &in gamemode)
{
	// Automated fixtures opt in per scenario so the director cannot mutate
	// their world unexpectedly. CTF is administrator-configurable; other modes
	// remain suggestion-only so merely installing the mod does not seize them.
	if (gamemode == "AIBTest") return AIBD_POLICY_MODE_OFF;
	if (gamemode == "CTF")
	{
		AIBDirectorPolicy@ policy = AIBD_GetDirectorPolicy();
		return policy.ctfDefaultMode;
	}
	return AIBD_POLICY_MODE_SUGGEST;
}
