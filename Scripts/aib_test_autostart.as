// Launch with:
// KAG.exe noautoupdate nolauncher autostart Scripts/aib_test_autostart.as

#include "Default/DefaultStart.as"
#include "Default/DefaultLoaders.as"

void Configure()
{
	s_soundon = 0;
	v_driver = 0;
	sv_canpause = false;
	sv_gamemode = "AIBTest";
	sv_mapcycle = "../Mods/GuiftsDynamicBlueprint_vDev/Rules/AIBTest/aibtest_mapcycle.cfg";
	sv_mapcycle_shuffle = false;
}

void InitializeGame()
{
	print("Initializing AIB test game");
	LoadDefaultMapLoaders();
	RunServer();
}
