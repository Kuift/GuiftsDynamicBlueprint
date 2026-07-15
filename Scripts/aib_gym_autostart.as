// Visible localhost launcher for map-scoped KAG Gym episodes. It uses the
// first real map in the normal CTF rotation (currently 8x_Gloryhill) and does
// not add fixture terrain or the older developer support scenario.

#include "Default/DefaultStart.as"
#include "Default/DefaultLoaders.as"

void Configure()
{
	s_soundon = 1;
	v_driver = 5;
	sv_canpause = false;
	sv_gamemode = "CTF";
	sv_mapcycle = "";
	sv_mapcycle_shuffle = false;
}

void InitializeGame()
{
	print("Initializing visible map-scoped KAG Gym localhost");
	LoadDefaultMapLoaders();
	RunLocalhost();
}
