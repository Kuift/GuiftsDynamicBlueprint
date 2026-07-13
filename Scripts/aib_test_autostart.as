// Launch with:
// KAG.exe noautoupdate nolauncher autostart Scripts/aib_test_autostart.as

#include "Default/DefaultStart.as"
#include "Default/DefaultLoaders.as"

void Configure()
{
	s_soundon = 0;
	// Keep automated gameplay/debug runs visible, as required by this mod's
	// agent workflow.  Compile-only callers may explicitly choose a null driver.
	v_driver = 5;
	sv_canpause = false;
	sv_gamemode = "AIBTest";
	sv_mapcycle = "../Mods/GuiftsDynamicBlueprint_vDev/Rules/AIBTest/aibtest_mapcycle.cfg";
	sv_mapcycle_shuffle = false;
}

void InitializeGame()
{
	print("Initializing AIB test game");
	LoadDefaultMapLoaders();
	// A visible test scene needs a real localhost client.  RunServer() alone
	// renders a server window but has no client camera and is subject to the
	// long-standing headless simulation stall.
	RunLocalhost();
}
