// Visible minimal localhost probe. This intentionally bypasses the standard
// Rules/<gamemode>/gamemode.cfg lookup so all experimental files stay under
// research and use collision-resistant basenames.

#include "Default/DefaultStart.as"
#include "Default/DefaultLoaders.as"

void Configure()
{
	s_soundon = 0;
	v_driver = 5;
	// Keep presentation uncapped for the research harness. A stack sampled in
	// the OpenGL present path only proved that rendering was active, not that
	// the driver caused the simulation stall.
	v_vsync = false;
	g_lazy_load = true;
	// Disabling this while lazy loading remains enabled prevented server
	// initialization from completing in a reproduced build-4762 control.
	g_lazy_load_precompile = true;
	sv_canpause = false;
	sv_gamemode = "AIBResearchMinimal";
	sv_mapcycle = "../Mods/GuiftsDynamicBlueprint_vDev/research/runtime/minimal_mapcycle.cfg";
	sv_mapcycle_shuffle = false;
}

void InitializeGame()
{
	print("[AIBMIN] LAUNCH");
	LoadDefaultMapLoaders();
	if (getNet().CreateServer())
	{
		LoadRules("../Mods/GuiftsDynamicBlueprint_vDev/research/runtime/minimal_gamemode.cfg");
		LoadMapCycle(sv_mapcycle);
		LoadNextMap();
	}
	ConnectLocalhost();
}
