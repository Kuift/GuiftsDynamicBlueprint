// Visible localhost launcher for manual CTF verification and clean handoff.
// Launch from the KAG root with:
// KAG.exe noautoupdate nolauncher autostart ../Mods/GuiftsDynamicBlueprint_vDev/Scripts/aib_ctf_autostart.as

#include "Default/DefaultStart.as"
#include "Default/DefaultLoaders.as"

void Configure()
{
	s_soundon = 1;
	v_driver = 5;
	sv_canpause = false;
	sv_gamemode = "CTF";
	sv_mapcycle = "";
	sv_mapcycle_shuffle = true;
}

void InitializeGame()
{
	print("Initializing visible CTF localhost");
	LoadDefaultMapLoaders();
	RunLocalhost();
	// This launcher is developer-only.  Keep deployed CTF quiet, but retain
	// transition/path evidence during visible manual acceptance runs.
	CRules@ rules = getRules();
	if (rules !is null)
	{
		rules.set_bool("aib event log enabled", true);
		rules.set_u32("aib event log seq", 0);
		rules.set_bool("aib developer force worker", true);
		rules.set_u8("aib developer force worker team", 0);
		rules.AddScript("AIBCTFDevScenario.as");
	}
}
