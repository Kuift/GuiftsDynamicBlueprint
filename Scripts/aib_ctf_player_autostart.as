// Visible localhost launcher for player-facing CTF director acceptance.
// Unlike aib_ctf_autostart.as, this does not force a worker, inject a
// developer blueprint, or change the strategy mode.

#include "Default/DefaultStart.as"
#include "Default/DefaultLoaders.as"

void Configure()
{
	s_soundon = 1;
	v_driver = 5;
	sv_canpause = false;
	sv_gamemode = "CTF";
	// Use the real CTF cycle, but make fresh launches deterministic.
	sv_mapcycle = "";
	sv_mapcycle_shuffle = false;
}

void InitializeGame()
{
	print("Initializing visible player-facing CTF localhost");
	LoadDefaultMapLoaders();
	RunLocalhost();
	// Passive event evidence is the only developer addition in this launcher.
	CRules@ rules = getRules();
	if (rules !is null)
	{
		rules.set_bool("aib event log enabled", true);
		rules.set_u32("aib event log seq", 0);
	}
}
