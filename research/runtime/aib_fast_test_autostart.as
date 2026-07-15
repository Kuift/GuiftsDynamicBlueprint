// Visible research-only launcher for the persistent AIBTest rules bridge.

#include "Default/DefaultStart.as"
#include "Default/DefaultLoaders.as"

void Configure()
{
	s_soundon = 0;
	v_driver = 5;
	sv_canpause = false;
	sv_gamemode = "AIBTest";
	sv_mapcycle = "../Mods/GuiftsDynamicBlueprint_vDev/Rules/AIBTest/aibtest_mapcycle.cfg";
	sv_mapcycle_shuffle = false;
}

void InitializeGame()
{
	print("Initializing research AIB fast-loop game");
	LoadDefaultMapLoaders();
	if (getNet().CreateServer())
	{
		LoadRules("../Mods/GuiftsDynamicBlueprint_vDev/research/runtime/aib_fast_gamemode.cfg");
		LoadMapCycle(sv_mapcycle);
		LoadNextMap();
	}
	ConnectLocalhost();
}
