// Visible server-only control for the localhost resource-handshake probe.

#include "Default/DefaultStart.as"
#include "Default/DefaultLoaders.as"

void Configure()
{
	s_soundon = 0;
	v_driver = 5;
	v_vsync = false;
	g_lazy_load = true;
	// Build 4762 can enter its frame loop without completing server startup
	// when lazy loading is enabled but background precompilation is disabled.
	g_lazy_load_precompile = true;
	sv_canpause = false;
	sv_gamemode = "AIBResearchMinimal";
	sv_mapcycle = "../Mods/GuiftsDynamicBlueprint_vDev/research/runtime/minimal_mapcycle.cfg";
	sv_mapcycle_shuffle = false;
}

void InitializeGame()
{
	print("[AIBMIN] SERVER_ONLY_LAUNCH");
	LoadDefaultMapLoaders();
	if (getNet().CreateServer())
	{
		LoadRules("../Mods/GuiftsDynamicBlueprint_vDev/research/runtime/minimal_gamemode.cfg");
		LoadMapCycle(sv_mapcycle);
		LoadNextMap();
	}
}
