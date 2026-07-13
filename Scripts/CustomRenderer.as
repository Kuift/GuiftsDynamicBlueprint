#include "Inventory.as"
#include "Item.as"
#include "AIBEventLog.as"
#include "BlueprintMemory.as"
#include "BlueprintNetwork.as"

u8 enableLiveEdit = 1; //EDIT THIS TO 0 IF YOU DON'T WANT TO ALLOW LIVE EDIT BY DEFAULT
u8 enableOverseer = 1; //EDIT THIS TO 1 IF YOU WANT TO ENABLE Overseer BY DEFAULT

///those next 2 global variable are the only thing you can modify without breaking anything if you understand what they do.
//you have to set the image size of the texture used for the tiles mesh.
float pngWidth = 128.0f;
float pngHeight = 256.0f;

const string REEEPPNG = "REEE";//stand for "Relevent Environnement for Enhancing Effectiveness [of rendering]" 
const u8 AIB_RENDERER_JOB_WOOD = 0;
const u8 AIB_RENDERER_JOB_STONE = 1;
const u8 AIB_RENDERER_JOB_BLUEPRINT = 2;
const u8 AIB_RENDERER_STATE_IDLE = 0;
const u8 AIB_RENDERER_STATE_FIND_STONE = 7;
const string AIB_BLUEPRINT_DATA_KEY = "aibuilder blueprint data";
const string AIB_BLUEPRINT_WIDTH_KEY = "aibuilder blueprint width";
const string AIB_BLUEPRINT_HEIGHT_KEY = "aibuilder blueprint height";
const string AIB_BLUEPRINT_TEAM_SUFFIX = " team ";
const u8 BLUEPRINT_TOOL_PAINT = 0;
const u8 BLUEPRINT_TOOL_ERASE = 1;
const u8 BLUEPRINT_TOOL_SELECT = 2;
const u8 BLUEPRINT_TOOL_SAVE = 3;
const u8 BLUEPRINT_TOOL_LOAD = 4;
const u8 BLUEPRINT_TOOL_ROTATE = 5;
const u8 BLUEPRINT_TOOL_FLIP = 6;
const u8 BLUEPRINT_TOOL_VISIBILITY = 7;
const u8 BLUEPRINT_TOOL_OVERSEER = 8;
const u8 BLUEPRINT_TOOL_COUNT = 8;
const u8 AIB_CATALOG_TAB_BLOCKS = 0;
const u8 AIB_CATALOG_TAB_WORKSHOPS = 1;
const u8 AIB_CATALOG_TAB_BLOBS = 2;
const u8 AIB_CATALOG_TAB_COUNT = 3;
const u8 AIB_OVERSEER_ORDER_WOOD = 0;
const u8 AIB_OVERSEER_ORDER_STONE = 1;
const u8 AIB_OVERSEER_ORDER_BLUEPRINT = 2;
const u8 AIB_OVERSEER_ORDER_DIRECTOR_OFF = 3;
const u8 AIB_OVERSEER_ORDER_DIRECTOR_ON = 4;
const string AIB_OVERSEER_NETIDS_KEY = "blueprint overseer netids";
const string AIB_OVERSEER_TEAM_SUFFIX = " team ";
const s32 AIB_BUILDER_HEAD_FRAME = 120;
const f32 AIB_RESOURCE_MARKER_SCALE = 0.5f;

//This code has been started from the ScriptRenderExample.as script
uint16[][] dynamicMapTileData;

SMesh@ everythingMesh = SMesh();
SMesh@ nonTileMesh = SMesh();
SMaterial@ everythingMat = SMaterial();
Inventory@ inv; 

float x_size;
float y_size;
uint16 blockIndex;
uint16 currentRotation = 0;

bool justJoined = true;
u8 localBlueprintTeam = 255;
bool keyOJustPressed = false;
bool triggerAPrefabLoad = false;
bool displayPrefabSelectionMenu = false;
array<string> filenames;
array<RuntimeBlueprint@> runtimeBlueprints;

void onInit(CRules@ this)
{
	this.set_bool("has_overseer", true);
	this.set_bool("blueprint_liveEdit", false);
	currentBlueprintData.clear();
	resetTrigger = true;
	customMenuTurn = 1;
	x_size = 4;
	y_size = 4;
	blockIndex = 1;
	/*getDriver().ForceStartShaders();
	getDriver().AddShader("customShader");
	getDriver().SetShader("customShader", true);
	getDriver().SetShader('hq2x', false);*/
	if(isClient())
	{
		searchForBlueprints(); // modify the global variable filenames to add to it every blueprint.png that is found
		@inv = Inventory(Vec2f(100,100), filenames); // constructor : Inventory(Vec2f position, int numberOfBlueprint, int number of item per rows)
		int cb_id = Render::addScript(Render::layer_postworld, "CustomRenderer.as", "RulesRenderFunction", 0.0f);
		int cb_id2 = Render::addScript(Render::layer_prehud, "CustomRenderer.as", "RenderAdvancedGui", 0.0f);
		Setup();
	}
	this.addCommandID("addBlocks");
	this.addCommandID("removeBlocks");
	this.addCommandID("getAllBlocks");
	this.addCommandID("giveAllBlocks");
	this.addCommandID("sendBlueprint");
	this.addCommandID("syncBlueprintBlock");
	this.addCommandID("setLiveEdit");
	this.addCommandID("getLiveEdit");
	this.addCommandID("setOverseerMode");
	this.addCommandID("getOverseerMode");
	this.addCommandID("removeAllOverseer");
	this.addCommandID("setOverseer");
	this.addCommandID("checkOverseerWinCondition");
	this.addCommandID("aibuilderToggleTreeSelection");
	this.addCommandID("aibuilderToggleStoneSelection");
	this.addCommandID("overseerOrderAIBuilder");
	this.addCommandID("clearBlueprintLayer");
	CMap@ map = getMap();
	uint16[][] _dynamicMapTileData(map.tilemapwidth, uint16[](map.tilemapheight, 0));
	dynamicMapTileData = _dynamicMapTileData;
}

/* search for all png files path that start with "blueprint_" and
put the path into a string array named filenames */
void searchForBlueprints()
{
	CFileMatcher@ files = CFileMatcher("blueprint_");
	files.reset();
	while (files.iterating())
	{
		filenames.push_back(files.getCurrent());
		print(files.getCurrent() + " blueprint has been found");
	}
}

void RulesRenderFunction(int id)
{
	CPlayer@ player = getLocalPlayer();
	if(player == null){return;} 
	RenderWidgetFor(getLocalPlayer());
}

void Setup()
{
	//ensure that we don't duplicate a texture
	if(!Texture::exists(REEEPPNG))
	{
		print("creating texture...");
		Texture::createFromFile(REEEPPNG,"/Sprites/REEE.png");
	}

	//initial config for the material that will be applied to the mesh
	everythingMat.AddTexture(REEEPPNG, 0);
	everythingMat.DisableAllFlags();
	everythingMat.SetFlag(SMaterial::COLOR_MASK, true);
	everythingMat.SetFlag(SMaterial::ZBUFFER, true);
	everythingMat.SetFlag(SMaterial::ZWRITE_ENABLE, true);
	everythingMat.SetMaterialType(SMaterial::TRANSPARENT_VERTEX_ALPHA);

	//mesh initial config
	everythingMesh.SetMaterial(everythingMat);
	everythingMesh.SetHardwareMapping(SMesh::STATIC);

	nonTileMesh.SetMaterial(everythingMat);
	nonTileMesh.SetHardwareMapping(SMesh::STATIC);

}

void onRestart(CRules@ this)
{
	localBlueprintTeam = 255;
	justJoined = true;
	dynamicMapTileData.clear();
	currentBlueprintData.clear();
	networkBlueprintData.clear();
	CMap@ map = getMap();
	uint16[][] _dynamicMapTileData(map.tilemapwidth, uint16[](map.tilemapheight, 0));
	dynamicMapTileData = _dynamicMapTileData;
	if(isClient())
	{
		Setup();
	}
	resetTrigger = true;
	blueprintMeshDirty = true;
	currentRotation = 0;
	oldBlockIndex = -1;
}


//toggle through each render type to give a working example of each call
int oldBlockIndex = -1;
void onTick(CRules@ this)
{
	if(isClient())
	{
		CPlayer@ local = getLocalPlayer();
		const u8 team = local is null ? 255 : u8(local.getTeamNum());
		if(team != localBlueprintTeam)
		{
			localBlueprintTeam = team;
			overseerSelectedBuilders.clear();
			AIB_CloseSelectionModes();
			CMap@ map = getMap();
			if(map !is null)
			{
				uint16[][] empty(map.tilemapwidth, uint16[](map.tilemapheight, 0));
				dynamicMapTileData = empty;
				blueprintMeshDirty = true;
			}
			if(local !is null && team < 100)
			{
				CBitStream request;
				request.write_u16(local.getNetworkID());
				this.SendCommand(this.getCommandID("getAllBlocks"), request);
			}
		}
	}

	if(this.get_bool("blueprint_liveEdit")) // if the !bp_edit_toggle command is executed, the following is executed to enable or disable live editing.
	{
		this.set_bool("blueprint_liveEdit",false);
		if(enableLiveEdit == 1)
		{
			enableLiveEdit = 0;
		}
		else
		{
			enableLiveEdit = 1;
		}
		CBitStream params;
		params.write_u8(enableLiveEdit);
		this.SendCommand(this.getCommandID("setLiveEdit"), params);
		
	}
	if(this.get_bool("blueprint_Overseer_mode")) // if the !bp_Overseer_toggle command is executed, the following is executed to enable or disable Overseer gamemode.
	{
		this.set_bool("blueprint_Overseer_mode",false);
		if(enableOverseer == 1)
		{
			enableOverseer = 0;
		}
		else
		{
			enableOverseer = 1;
		}
		CBitStream params;
		params.write_u8(enableOverseer);
		this.SendCommand(this.getCommandID("setOverseerMode"), params);
		
	}
	if(this.get_bool("blueprint_Overseer_none"))//triggered when the !bp_Overseer_none command is executed. It will proceed to remove all Overseer in the current game
	{
		this.set_bool("blueprint_Overseer_none",false);
		CBitStream params;
		this.SendCommand(this.getCommandID("removeAllOverseer"), params);
	}
	if(this.get_bool("blueprint_Overseer_set"))//triggered when the !bp_Overseer_set command is executed. It will proceed to make the selected player a Overseer.
	{
		this.set_bool("blueprint_Overseer_set",false);
		CBitStream params;
		params.write_u16(this.get_u16("Overseer_netid"));
		this.SendCommand(this.getCommandID("setOverseer"), params);
	}
	if(isClient())
	{	
		string selectedBlueprint = "";
		AIB_SyncOverseerViewWithWorkshop();
		// Match PlayerCamera/Spectator camera timing: capped clients update on
		// ticks, while uncapped clients update every rendered frame. Advancing a
		// detached camera only at the 30 Hz rules tick makes its position visibly
		// step between frames.
		if(v_capped)
		{
			UpdateOverseerViewCamera();
		}
		bool toolbarConsumed = UpdateBlueprintToolbar();
		bool catalogPanelConsumed = UpdateBlueprintCatalogPanel();
		bool advancedPanelConsumed = UpdateBlueprintAdvancedPanel();
		bool directorToggleConsumed = UpdateAIBDirectorToggle();
		bool treeButtonConsumed = UpdateTreeSelectionButton();
		bool stoneButtonConsumed = UpdateStoneSelectionButton();
		bool overseerConsumed = UpdateOverseerView();
		bool prefabMenuConsumed = false;
		if(toggleBlueprint && displayPrefabSelectionMenu && !toolbarConsumed && !catalogPanelConsumed && !advancedPanelConsumed && !directorToggleConsumed && !treeButtonConsumed && !stoneButtonConsumed)
		{
			selectedBlueprint = inv.Update();
			prefabMenuConsumed = inv.consumesMouseInput() || selectedBlueprint != "";
			if( selectedBlueprint != "")
			{		
				print("Loading " + selectedBlueprint);
				displayPrefabSelectionMenu = false;
				AIB_CloseSelectionModes();
				blueprintEditorActive = false;
				blueprintEditorSelecting = false;
				triggerAPrefabLoad = true;
				displayMouseSelect = false;
			}
		}

		CBlob@ playerBlob = getLocalPlayerBlob();
		if(!toolbarConsumed && !catalogPanelConsumed && !advancedPanelConsumed && !directorToggleConsumed && !treeButtonConsumed && !stoneButtonConsumed && !overseerConsumed && !prefabMenuConsumed)
		{
			ChangeIfNeeded();
		}
		const u16 selectedBlock = GiveBlockIndex(playerBlob);
		blockIndex = AIBP_IsCatalogBlock(selectedBlock) ? selectedBlock : AIBP_STONE_BLOCK;
		/*if (blockIndex != oldBlockIndex)
		{
			//oldBlockIndex = blockIndex;
			//currentImageTextureX = (blockIndex % (pngWidth/8))/(pngWidth/8);
			//currentImageTextureY = int(blockIndex / (pngWidth/8)) / (pngHeight/8);
		}*/
		if(keyOJustPressed)
		{
			SaveBlueprintToPng(this);
		}
		if(triggerAPrefabLoad && !displayLoadedBlueprint)
		{
			LoadBlueprintFromPng(this,selectedBlueprint);
		}
		else
		{
			triggerAPrefabLoad = false;
		}
		if(displayLoadedBlueprint)
		{
			LoadBlueprintDataToMapTileData();
		}
		if(playerBlob == null){return;} 
	}
}

void onRender(CRules@ this)
{
	if(isClient() && !v_capped)
	{
		UpdateOverseerViewCamera();
	}
}

int last_changed = 0;
bool toggleBlueprint = true;
bool blueprintEditorActive = false;
u8 blueprintEditorTool = BLUEPRINT_TOOL_PAINT;
bool blueprintToolbarButtonPressed = false;
u8 blueprintToolbarPressedTool = 255;
bool blueprintCatalogPanelButtonPressed = false;
u16 blueprintCatalogPanelPressedBlock = 0;
bool blueprintCatalogTabButtonPressed = false;
u8 blueprintCatalogTabPressed = 255;
u8 blueprintCatalogTab = AIB_CATALOG_TAB_BLOCKS;
u8 blueprintAdvancedTab = 0;
bool blueprintAdvancedButtonPressed = false;
u8 blueprintAdvancedPressedTab = 255;
bool blueprintEditorSelecting = false;
bool overseerViewActive = false;
Vec2f overseerCameraPos = Vec2f_zero;
u16[] overseerSelectedBuilders;
bool overseerSelectionDragging = false;
bool overseerOrderButtonPressed = false;
u8 overseerPressedOrder = 255;
bool aibDirectorTogglePressed = false;
Vec2f overseerPanelPosition = Vec2f(-1.0f, -1.0f);
bool overseerPanelDragging = false;
Vec2f overseerPanelDragOffset = Vec2f_zero;
Vec2f currentPlacementPosition;
uint16 customMenuTurn;
bool customCatalogSelectionActive = false;
array<Vec2f> mouseSelect = {Vec2f(1.0f,1.0f),Vec2f(3.0f,3.0f)};
bool displayMouseSelect = false;
bool aibTreeSelectMode = false;
bool aibTreeSelecting = false;
bool aibTreeButtonPressed = false;
Vec2f aibTreeButtonPosition = Vec2f(100, 66);
bool aibStoneSelectMode = false;
bool aibStoneSelecting = false;
bool aibStoneButtonPressed = false;
Vec2f aibStoneButtonPosition = Vec2f(100, 98);

string AIB_BlueprintDataKeyForTeam(const u8 team)
{
	return AIB_BLUEPRINT_DATA_KEY + AIB_BLUEPRINT_TEAM_SUFFIX + int(team);
}

string AIB_BlueprintWidthKeyForTeam(const u8 team)
{
	return AIB_BLUEPRINT_WIDTH_KEY + AIB_BLUEPRINT_TEAM_SUFFIX + int(team);
}

string AIB_BlueprintHeightKeyForTeam(const u8 team)
{
	return AIB_BLUEPRINT_HEIGHT_KEY + AIB_BLUEPRINT_TEAM_SUFFIX + int(team);
}

bool AIB_GetPlayerTeamByNetID(const u16 netID, u8 &out team)
{
	CPlayer@ player = getPlayerByNetworkId(netID);
	if(player is null)
	{
		return false;
	}
	team = u8(player.getTeamNum());
	return true;
}

u8 AIB_GetLocalBlueprintTeam()
{
	CPlayer@ player = getLocalPlayer();
	return player is null ? 0 : u8(player.getTeamNum());
}

bool AIB_LocalCanSeeBlueprintTeam(const u8 team)
{
	CPlayer@ player = getLocalPlayer();
	if(player is null)
	{
		return true;
	}
	const int localTeam = player.getTeamNum();
	return localTeam == team || localTeam >= 100;
}

string AIB_OverseerNetIDsKeyForTeam(const u8 team)
{
	return AIB_OVERSEER_NETIDS_KEY + AIB_OVERSEER_TEAM_SUFFIX + int(team);
}

array<u16>@ AIB_GetOverseerNetIDs(const u8 team)
{
	CRules@ rules = getRules();
	array<u16>@ ids = null;
	if(rules is null)
	{
		return null;
	}
	const string key = AIB_OverseerNetIDsKeyForTeam(team);
	if(!rules.get(key, @ids) || ids is null)
	{
		array<u16> empty;
		rules.set(key, empty);
		rules.get(key, @ids);
	}
	return ids;
}

bool AIB_IsOverseerNetID(const u16 netID, const u8 team)
{
	array<u16>@ ids = AIB_GetOverseerNetIDs(team);
	if(ids is null) return false;
	for(uint i = 0; i < ids.length; i++)
	{
		if(ids[i] == netID) return true;
	}
	return false;
}

bool AIB_HasAssignedOverseers(const u8 team)
{
	array<u16>@ ids = AIB_GetOverseerNetIDs(team);
	return ids !is null && ids.length > 0;
}

bool AIB_CanPlayerUseOverseerControls(CPlayer@ player)
{
	if(player is null) return false;
	if(enableOverseer == 0) return true;
	if(player.getTeamNum() >= 100) return true;
	if(!getRules().get_bool("has_overseer")) return false;
	const u8 team = u8(player.getTeamNum());
	if(!AIB_HasAssignedOverseers(team)) return true;
	return AIB_IsOverseerNetID(player.getNetworkID(), team);
}

bool AIB_LocalCanUseBlueprintControls()
{
	return AIB_CanPlayerUseOverseerControls(getLocalPlayer());
}

bool AIB_ServerCanUseBlueprintControls(const u16 playerNetID)
{
	CPlayer@ player = getPlayerByNetworkId(playerNetID);
	if(player is null) return false;
	if(enableOverseer == 0 || player.getTeamNum() >= 100) return true;
	if(!getRules().get_bool("has_overseer")) return false;
	const u8 team = u8(player.getTeamNum());
	if(!AIB_HasAssignedOverseers(team)) return true;
	return AIB_IsOverseerNetID(playerNetID, team);
}

bool AIB_ServerCanIssueOverseerCommand(const u16 playerNetID, const u8 targetTeam)
{
	CPlayer@ player = getPlayerByNetworkId(playerNetID);
	if(player is null) return false;
	CBlob@ playerBlob = player.getBlob();
	if(playerBlob is null || !playerBlob.isAttachedToPoint("OVERSEER")) return false;
	if(player.getTeamNum() != targetTeam && player.getTeamNum() < 100) return false;
	if(enableOverseer == 0) return true;
	if(player.getTeamNum() >= 100) return true;
	if(!getRules().get_bool("has_overseer")) return false;
	if(!AIB_HasAssignedOverseers(targetTeam)) return true;
	return AIB_IsOverseerNetID(playerNetID, targetTeam);
}

void AIB_AddOverseerNetID(const u16 netID)
{
	u8 team = 255;
	if(netID == 0 || !AIB_GetPlayerTeamByNetID(netID, team) || team >= 100) return;
	array<u16>@ ids = AIB_GetOverseerNetIDs(team);
	if(ids is null || AIB_IsOverseerNetID(netID, team)) return;
	ids.push_back(netID);
	getRules().set(AIB_OverseerNetIDsKeyForTeam(team), ids);
}

void AIB_ClearOverseerNetIDs()
{
	for(u8 team = 0; team < 8; team++)
	{
		array<u16> empty;
		getRules().set(AIB_OverseerNetIDsKeyForTeam(team), empty);
	}
}

bool AIB_NormalizeSelectionRect(u16 &out x1, u16 &out y1, u16 &out x2, u16 &out y2)
{
	CMap@ map = getMap();
	if(map is null)
	{
		return false;
	}

	int ax = Maths::Floor(mouseSelect[0].x);
	int ay = Maths::Floor(mouseSelect[0].y);
	int bx = Maths::Floor(mouseSelect[1].x);
	int by = Maths::Floor(mouseSelect[1].y);

	const int sx = Maths::Max(0, Maths::Min(ax, bx));
	const int sy = Maths::Max(0, Maths::Min(ay, by));
	const int ex = Maths::Min(map.tilemapwidth - 1, Maths::Max(ax, bx));
	const int ey = Maths::Min(map.tilemapheight - 1, Maths::Max(ay, by));
	if(sx > ex || sy > ey)
	{
		return false;
	}

	x1 = u16(sx);
	y1 = u16(sy);
	x2 = u16(ex);
	y2 = u16(ey);
	return true;
}

bool AIB_SelectionHasArea()
{
	u16 x1;
	u16 y1;
	u16 x2;
	u16 y2;
	return AIB_NormalizeSelectionRect(x1, y1, x2, y2) && (x1 != x2 || y1 != y2);
}

void AIB_SendBlueprintBlockCommand(const bool add, const u16 x, const u16 y, const u16 value = 0)
{
	CPlayer@ player = getLocalPlayer();
	if(player is null)
	{
		return;
	}

	CBitStream params;
	params.write_u16(player.getNetworkID());
	params.write_u16(x);
	params.write_u16(y);
	// Individual paint/erase deltas commute. Requiring the last acknowledged
	// version here makes normal drag editing drop nearly every input on a
	// networked game while earlier deltas are still in flight.
	params.write_u16(0xffff);
	if(add)
	{
		params.write_u16(value);
		getRules().SendCommand(getRules().getCommandID("addBlocks"), params);
	}
	else
	{
		getRules().SendCommand(getRules().getCommandID("removeBlocks"), params);
	}
}

void AIB_ApplyBlueprintBlockLocal(const u8 team, const u16 x, const u16 y, const u16 value)
{
	if(!AIB_LocalCanSeeBlueprintTeam(team))
	{
		return;
	}

	CMap@ map = getMap();
	if(map is null || dynamicMapTileData.size() == 0) return;
	if(x >= map.tilemapwidth || y >= map.tilemapheight) return;
	if(x >= dynamicMapTileData.size() || y >= dynamicMapTileData[x].size()) return;

	dynamicMapTileData[x][y] = value;
	blueprintMeshDirty = true;
}

void AIB_LoadFlatBlueprintLocal(const u8 team, array<u16>@ blueprint, const u16 width, const u16 height)
{
	if(!AIB_LocalCanSeeBlueprintTeam(team) || blueprint is null)
	{
		return;
	}

	CMap@ map = getMap();
	if(map is null || width == 0 || height == 0)
	{
		return;
	}

	uint16[][] next(map.tilemapwidth, uint16[](map.tilemapheight, 0));
	for(int y = 0; y < map.tilemapheight && y < height; y++)
	{
		for(int x = 0; x < map.tilemapwidth && x < width; x++)
		{
			const uint index = y * width + x;
			if(index < blueprint.length)
			{
				next[x][y] = blueprint[index];
			}
		}
	}

	dynamicMapTileData = next;
	blueprintMeshDirty = true;
}

void AIB_GetTeamBlueprintFlat(const u8 team, array<u16>@ &out blueprint)
{
	AIBP_GetCompatibilityGrid(team, @blueprint);
}

void AIB_ServerApplyBlueprintBlock(const u8 team, const u16 x, const u16 y, const u16 value)
{
	AIBP_SetHumanTile(team, x, y, value);
}

void AIB_ServerSendBlueprintSnapshot(const u16 targetNetID, const u8 team)
{
	AIBP_SendDisplaySnapshot(targetNetID, team);
}

void AIB_ServerApplyBlueprintPlacement(const u8 team, const u16 centerX, const u16 centerY, const u16 bpWidth, const u16 bpHeight, uint16[][] &source)
{
	AIBP_ApplyHumanPlacement(team, centerX, centerY, bpWidth, bpHeight, source);
}

void ChangeIfNeeded()
{
	CControls@ c = getControls();
	if (c is null) return;
	CPlayer@ playerBlob = getLocalPlayer();

	if(c.isKeyJustPressed(KEY_KEY_H)) //activate or deactivate mesh rendering
	{
		toggleBlueprint = !toggleBlueprint;
	}

	if(c.isKeyJustPressed(KEY_KEY_O) && AIB_LocalCanUseBlueprintControls())//load a png
	{
		displayMouseSelect = false;
		keyOJustPressed = true;
		print("saving blueprint...");
	}
	if(c.isKeyPressed(KEY_KEY_X) && AIB_LocalCanUseBlueprintControls())
	{
		displayPrefabSelectionMenu = true;
		aibTreeButtonPosition = c.getMouseScreenPos() + Vec2f(0, -34);
		aibStoneButtonPosition = c.getMouseScreenPos() + Vec2f(0, -66);
		inv.setPosition(c.getMouseScreenPos());
	}
	if(c.isKeyJustPressed(KEY_KEY_L) && AIB_LocalCanUseBlueprintControls())
	{
		displayPrefabSelectionMenu = !displayPrefabSelectionMenu;
		if(!displayPrefabSelectionMenu)
		{
			AIB_CloseSelectionModes();
		}
		print("Prefabs blueprint windows state changed");
	}
	if((c.isKeyJustPressed(KEY_RBUTTON) || c.isKeyJustPressed(KEY_CANCEL)) && AIB_LocalCanUseBlueprintControls())
	{
		displayMouseSelect = false;
		blueprintEditorSelecting = false;
		aibTreeSelecting = false;
		aibStoneSelecting = false;
		if (aibTreeSelectMode)
		{
			aibTreeSelectMode = false;
		}
		if (aibStoneSelectMode)
		{
			aibStoneSelectMode = false;
		}
		if(displayLoadedBlueprint == true)
		{
			dynamicMapTileData = tileMapDataCopy;
			displayLoadedBlueprint = false;
			currentBlueprintData.clear();
			blueprintMeshDirty = true;
		}
	}

	if(blueprintEditorActive && enableLiveEdit == 1 && AIB_LocalCanUseBlueprintControls())
	{
		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8;
		CMap@ map = getMap();
		const bool inMap = map !is null && indexX < map.tilemapwidth && indexY < map.tilemapheight && dynamicMapTileData.size() > 0;
		if(blueprintEditorTool == BLUEPRINT_TOOL_SELECT)
		{
			if(c.isKeyJustPressed(KEY_LBUTTON) && inMap)
			{
				blueprintEditorSelecting = true;
				mouseSelect[0] = Vec2f(indexX, indexY);
				mouseSelect[1] = Vec2f(indexX, indexY);
				displayMouseSelect = true;
			}
			else if(blueprintEditorSelecting && c.isKeyPressed(KEY_LBUTTON))
			{
				AIB_SetSelectionCorner(1, c.getMouseWorldPos());
				displayMouseSelect = true;
			}
			else if(blueprintEditorSelecting && !c.isKeyPressed(KEY_LBUTTON))
			{
				AIB_SetSelectionCorner(1, c.getMouseWorldPos());
				displayMouseSelect = AIB_SelectionHasArea();
				blueprintEditorSelecting = false;
			}
		}
		else if(inMap && blueprintEditorTool == BLUEPRINT_TOOL_PAINT && c.isKeyPressed(KEY_LBUTTON) && dynamicMapTileData[indexX][indexY] == 0)
		{
			AIB_SendBlueprintBlockCommand(true, indexX, indexY, blockIndex);
		}
		else if(inMap && blueprintEditorTool == BLUEPRINT_TOOL_ERASE && c.isKeyPressed(KEY_LBUTTON) && dynamicMapTileData[indexX][indexY] != 0)
		{
			AIB_SendBlueprintBlockCommand(false, indexX, indexY);
		}

		return;
	}

	if(aibTreeSelectMode && AIB_LocalCanUseBlueprintControls())
	{
		if(c.isKeyJustPressed(KEY_LBUTTON))
		{
			AIB_BeginTreeSelection(c.getMouseWorldPos());
		}
		else if(aibTreeSelecting && c.isKeyPressed(KEY_LBUTTON))
		{
			AIB_UpdateTreeSelection(c.getMouseWorldPos());
		}
		else if(aibTreeSelecting && !c.isKeyPressed(KEY_LBUTTON))
		{
			AIB_UpdateTreeSelection(c.getMouseWorldPos());
			AIB_SendTreeSelection();
			aibTreeSelecting = false;
			displayMouseSelect = false;
		}

		return;
	}

	if(aibStoneSelectMode && AIB_LocalCanUseBlueprintControls())
	{
		if(c.isKeyJustPressed(KEY_LBUTTON))
		{
			AIB_BeginStoneSelection(c.getMouseWorldPos());
		}
		else if(aibStoneSelecting && c.isKeyPressed(KEY_LBUTTON))
		{
			AIB_UpdateStoneSelection(c.getMouseWorldPos());
		}
		else if(aibStoneSelecting && !c.isKeyPressed(KEY_LBUTTON))
		{
			AIB_UpdateStoneSelection(c.getMouseWorldPos());
			AIB_SendStoneSelection();
			aibStoneSelecting = false;
			displayMouseSelect = false;
		}

		return;
	}

	if(c.isKeyJustPressed(KEY_LBUTTON) && displayLoadedBlueprint == true && AIB_LocalCanUseBlueprintControls())
	{
		displayLoadedBlueprint = false; // if the player selected a blueprint and pressed left click, then we send the blueprint to everybody

		CBitStream params;

		uint16 id = playerBlob.getNetworkID();

		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8; 

		params.write_u16(id);
		params.write_u16(getRules().get_u16(AIBP_PlanKey(u8(playerBlob.getTeamNum()), "human version")));
		params.write_u16(currentBlueprintWidth);
		params.write_u16(currentBlueprintHeight);
		params.write_u16(indexX);
		params.write_u16(indexY);

		if(flipBlueprint)
		{
			for(int y = 0; y < currentBlueprintHeight; y++)// iterate through all the element of the current blueprint and send it but flipped
			{
				for(int x = 0; x < currentBlueprintWidth; x++) 
				{
					params.write_u16(AIB_FlipBlueprintBlockHorizontal(currentBlueprintData[currentBlueprintWidth-1-x][y]));
					
				}
			}
		}
		else
		{
			for(int y = 0; y < currentBlueprintHeight; y++)// iterate through all the element of the current blueprint and send it 
			{
				for(int x = 0; x < currentBlueprintWidth; x++) 
				{
					params.write_u16(currentBlueprintData[x][y]);
				}
			}
		}
		getRules().SendCommand(getRules().getCommandID("sendBlueprint"), params);
	}

	if(c.isKeyJustPressed(KEY_KEY_I) && AIB_LocalCanUseBlueprintControls())
	{
		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8; 
		mouseSelect[0] = Vec2f(indexX,indexY);
		displayMouseSelect = true;
		if(mouseSelect[1].x == mouseSelect[0].x || mouseSelect[1].y == mouseSelect[0].y)
		{
			displayMouseSelect = false;
		}
		print("First vector x : " + mouseSelect[0].x);
		print("First vector y : " + mouseSelect[0].y);
		
	}
	if(c.isKeyJustPressed(KEY_KEY_P) && AIB_LocalCanUseBlueprintControls())
	{
		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8; 
		mouseSelect[1] = Vec2f(indexX, indexY);
		displayMouseSelect = true;
		if(mouseSelect[1].x == mouseSelect[0].x || mouseSelect[1].y == mouseSelect[0].y)
		{
			displayMouseSelect = false;
		}
		print("second vector x : " + mouseSelect[1].x);
		print("second vector y : " + mouseSelect[1].y);
	}
	if(c.isKeyJustPressed(KEY_MBUTTON) && AIB_LocalCanUseBlueprintControls())
	{
		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8; 
		mouseSelect[0] = Vec2f(indexX, indexY);
		displayMouseSelect = false;
		if(mouseSelect[1].x == mouseSelect[0].x || mouseSelect[1].y == mouseSelect[0].y)
		{
			displayMouseSelect = false;
		}
		print("First vector x : " + mouseSelect[0].x);
		print("First vector y : " + mouseSelect[0].y);
	}
	else if(c.isKeyPressed(KEY_MBUTTON) && AIB_LocalCanUseBlueprintControls())
	{
		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8; 
		mouseSelect[1] = Vec2f(indexX, indexY);
		displayMouseSelect = true;
		if(mouseSelect[1].x == mouseSelect[0].x || mouseSelect[1].y == mouseSelect[0].y)
		{
			displayMouseSelect = false;
		}
		print("second vector x : " + mouseSelect[1].x);
		print("second vector y : " + mouseSelect[1].y);
	}

	if(c.isKeyJustPressed(KEY_KEY_J)) //this key serve to adjust the "chunk" the player can see.
	{
		if(xRenderLimit == 37)
		{
			xRenderLimit = 20;
			yRenderLimit = 15;
		}
		else if(xRenderLimit == 20)
		{
			xRenderLimit = 68;
			yRenderLimit = 40;
		}
		else if(xRenderLimit == 68)
		{
			xRenderLimit = 37;
			yRenderLimit = 21;
		}
		initRender(false);
	}
	if(c.isKeyJustPressed(KEY_KEY_K))
	{
		if(renderingState == 0)
		{
			renderingState = 1;
		}
		else if (renderingState == 1)
		{
			renderingState = 0;
		}
	}
	if ((c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL)) && enableLiveEdit == 1 && AIB_LocalCanUseBlueprintControls())
	{
		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8; 
		CMap@ map = getMap();
		if(indexX < map.tilemapwidth && indexY < map.tilemapheight && dynamicMapTileData.size() > 0)//ensure that we don't get index out of the array
		{
			if (c.isKeyPressed(c.getActionKeyKey(AK_ACTION1)) && (c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL)))
			{
				if(dynamicMapTileData[indexX][indexY] == 0)
				{
					AIB_SendBlueprintBlockCommand(true, indexX, indexY, blockIndex);
				}
			}
			else if (c.isKeyPressed(c.getActionKeyKey(AK_ACTION2))  && (c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL)) && dynamicMapTileData[indexX][indexY] != 0)
			{				
				AIB_SendBlueprintBlockCommand(false, indexX, indexY);
			}
		}
		if(c.isKeyJustPressed(KEY_KEY_U))
		{
			customMenuTurn = AIBP_NextCatalogId(customMenuTurn, 1);
			customCatalogSelectionActive = true;
		}
		else if(c.isKeyJustPressed(KEY_KEY_R))
		{
			customMenuTurn = AIBP_NextCatalogId(customMenuTurn, -1);
			customCatalogSelectionActive = true;
		}
	}

	if(c.isKeyJustPressed(KEY_SPACE) && displayLoadedBlueprint == false && AIB_LocalCanUseBlueprintControls())
	{
		if(blockIndex > 2 && blockIndex != 4 && blockIndex != 5)
		if(currentRotation <= 0)
		{
			currentRotation = 3;
		}
		else
		{
			currentRotation -= 1;
		}
	}
	else if(c.isKeyJustPressed(KEY_SPACE) && displayLoadedBlueprint == true && AIB_LocalCanUseBlueprintControls())
	{
		flipBlueprint = !flipBlueprint;
	}
}



void onCommand(CRules@ this, u8 cmd, CBitStream @params)
{
    if(cmd == this.getCommandID("addBlocks") && dynamicMapTileData.size() > 0)
    {
		if(!isServer()) return;

		uint16 netID = params.read_u16();
        uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		uint16 expectedVersion = params.read_u16();
		uint16 receivedBlockIndex = params.read_u16();
		CPlayer@ sender = getNet().getActiveCommandPlayer();
		if(sender is null || sender.getNetworkID() != netID) return;

		AIBP_ServerApplyHumanDelta(netID, positionx, positiony, receivedBlockIndex, expectedVersion);
		
    }
	if(cmd == this.getCommandID("removeBlocks") && dynamicMapTileData.size() > 0)
	{
		if(!isServer()) return;

		uint16 netID = params.read_u16();
		uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		uint16 expectedVersion = params.read_u16();
		CPlayer@ sender = getNet().getActiveCommandPlayer();
		if(sender is null || sender.getNetworkID() != netID) return;

		AIBP_ServerApplyHumanDelta(netID, positionx, positiony, 0, expectedVersion);
	}
	if(isClient() && cmd == this.getCommandID("syncBlueprintBlock"))
	{
		u8 team = params.read_u8();
		u16 positionx = params.read_u16();
		u16 positiony = params.read_u16();
		u16 value = params.read_u16();
		u16 humanVersion = params.read_u16();
		getRules().set_u16(AIBP_PlanKey(team, "human version"), humanVersion);
		AIB_ApplyBlueprintBlockLocal(team, positionx, positiony, value);
	}
	if(!isClient() && cmd == this.getCommandID("getAllBlocks") && dynamicMapTileData.size() > 0)
	{
		uint16 netID = params.read_u16();
		CPlayer@ sender = getNet().getActiveCommandPlayer();
		if(sender is null || sender.getNetworkID() != netID) return;
		u8 team = 0;
		if(AIB_GetPlayerTeamByNetID(netID, team))
		{
			AIB_ServerSendBlueprintSnapshot(netID, team);
		}
	}
	if(isClient() && cmd == this.getCommandID("giveAllBlocks"))
	{
		uint16 netID = params.read_u16();
		u8 team = params.read_u8();
		u16 width = params.read_u16();
		u16 height = params.read_u16();
		u16 humanVersion = params.read_u16();
		CMap@ snapshotMap = getMap();
		if(snapshotMap is null || width != snapshotMap.tilemapwidth || height != snapshotMap.tilemapheight) return;
		CPlayer@ local = getLocalPlayer();
		bool targetMatches = netID == 0 || (local !is null && local.getNetworkID() == netID);
		array<u16> blueprint;
		blueprint.set_length(width * height);
		for(uint i = 0; i < blueprint.length; i++)
		{
			blueprint[i] = params.read_u16();
		}
		if(targetMatches)
		{
			getRules().set_u16(AIBP_PlanKey(team, "human version"), humanVersion);
			AIB_LoadFlatBlueprintLocal(team, @blueprint, width, height);
		}
	}
	if(cmd == this.getCommandID("sendBlueprint") && dynamicMapTileData.size() > 0)
	{
		uint16 netID = params.read_u16();
		if(isServer())
		{
			CPlayer@ sender = getNet().getActiveCommandPlayer();
			if(sender is null || sender.getNetworkID() != netID) return;
		}
		uint16 expectedVersion = params.read_u16();
		uint16 bpWidth = params.read_u16();
		uint16 bpHeight = params.read_u16();
		uint16 indx = params.read_u16();
		uint16 indy = params.read_u16();
		if(!AIBP_IsPrefabSizeValid(bpWidth, bpHeight)) return;
		uint16[][] _networkBlueprintData(bpWidth, uint16[](bpHeight, 0));
		networkBlueprintData = _networkBlueprintData;
		for(int y = 0; y < bpHeight; y++)
		{
			for(int x = 0; x < bpWidth; x++)
			{
				networkBlueprintData[x][y] = params.read_u16();
			}
		}

		u8 team = 0;
		if(!AIB_GetPlayerTeamByNetID(netID, team)) return;
		if(isServer())
		{
			AIBP_ServerApplyHumanPrefab(netID, expectedVersion, indx, indy, bpWidth, bpHeight, networkBlueprintData);
		}
	}
	if(cmd == this.getCommandID("setLiveEdit"))
	{
		enableLiveEdit = params.read_u8();
	}
	if(cmd == this.getCommandID("getLiveEdit"))
	{
		if(!isClient())
		{	
			CBitStream insideparams;
			insideparams.write_u8(enableLiveEdit);
			this.SendCommand(this.getCommandID("setLiveEdit"), insideparams);
		}
	}

	if(cmd == this.getCommandID("setOverseerMode"))
	{
		enableOverseer = params.read_u8();
	}
	if(cmd == this.getCommandID("getOverseerMode"))
	{
		if(!isClient())
		{	
			CBitStream insideparams;
			insideparams.write_u8(enableOverseer);
			this.SendCommand(this.getCommandID("setOverseerMode"), insideparams);
		}
	}
	if(cmd == this.getCommandID("removeAllOverseer"))
	{
		AIB_ClearOverseerNetIDs();
		isOverseer = false;
		this.set_bool("has_overseer", false);
		print("removed all overseer");
	}
	if(cmd == this.getCommandID("setOverseer"))
	{
		uint16 netID = params.read_u16();
		AIB_AddOverseerNetID(netID);
		if(!isClient())
		{
			this.set_bool("has_overseer", true);
		}
		CPlayer@ player = getLocalPlayer();
		print("got in trigger 7");
		if (player != null)
		{
			this.set_bool("has_overseer", true);
			print("got in trigger 6");
			if(getLocalPlayer().getNetworkID() == netID)
			{
				print("got in trigger 5");
				CBitStream localparams;
				isOverseer = true;
				localparams.write_string("******************* "+getPlayerByNetworkId(netID).getUsername()+" now is a Overseer! *******************");
				getRules().SendCommand(getRules().getCommandID("SendChatMessage"), localparams);
			}
		}
	}
	if(cmd == this.getCommandID("checkOverseerWinCondition"))
	{
		if(!isClient())
		{
			this.set_bool("overseer_win_condition", mapFitBlueprint());
		}
	}
	if(cmd == this.getCommandID("aibuilderToggleTreeSelection"))
	{
		u16 playerNetID = params.read_u16();
		if(isServer())
		{
			CPlayer@ sender = getNet().getActiveCommandPlayer();
			if(sender is null || sender.getNetworkID() != playerNetID || !AIB_ServerCanUseBlueprintControls(playerNetID)) return;
		}
		u16 x1 = params.read_u16();
		u16 y1 = params.read_u16();
		u16 x2 = params.read_u16();
		u16 y2 = params.read_u16();
		AIB_ToggleTreesInSelection(x1, y1, x2, y2);
	}
	if(cmd == this.getCommandID("aibuilderToggleStoneSelection"))
	{
		u16 playerNetID = params.read_u16();
		if(isServer())
		{
			CPlayer@ sender = getNet().getActiveCommandPlayer();
			if(sender is null || sender.getNetworkID() != playerNetID || !AIB_ServerCanUseBlueprintControls(playerNetID)) return;
		}
		u16 x1 = params.read_u16();
		u16 y1 = params.read_u16();
		u16 x2 = params.read_u16();
		u16 y2 = params.read_u16();
		AIB_ToggleStoneInSelection(x1, y1, x2, y2);
		if(isServer())
		{
			AIB_RetargetStoneBuilders();
		}
	}
	if(cmd == this.getCommandID("overseerOrderAIBuilder"))
	{
		u16 playerNetID = params.read_u16();
		if(isServer())
		{
			CPlayer@ sender = getNet().getActiveCommandPlayer();
			if(sender is null || sender.getNetworkID() != playerNetID) return;
		}
		u16 builderNetID = params.read_u16();
		u8 order = params.read_u8();
		AIB_ServerApplyOverseerOrder(playerNetID, builderNetID, order);
	}
	if(cmd == this.getCommandID("clearBlueprintLayer") && isServer())
	{
		const u16 playerNetID = params.read_u16();
		CPlayer@ sender = getNet().getActiveCommandPlayer();
		if(sender !is null && sender.getNetworkID() == playerNetID) AIBP_ServerClearHumanLayer(playerNetID);
	}
}


uint16 GiveBlockIndex(CBlob@ this)
{
	const u16 fallback = AIBP_IsCatalogBlock(customMenuTurn) ? AIBP_BlockId(customMenuTurn) : AIBP_STONE_BLOCK;
	if(customCatalogSelectionActive)
	{
		if(int(fallback) != oldBlockIndex)
		{
			currentRotation = AIBP_DefaultRotation(fallback);
			oldBlockIndex = fallback;
		}
		return AIBP_EncodeBlock(fallback, currentRotation);
	}
	const u16 selectedId = AIBP_BlockId(AIBP_FromBuilderSelection(this, fallback, 0));
	if(int(selectedId) != oldBlockIndex)
	{
		currentRotation = AIBP_DefaultRotation(selectedId);
		oldBlockIndex = selectedId;
	}
	return AIBP_FromBuilderSelection(this, fallback, currentRotation);
}


//we will build our meshes into here
//for "high performance" stuff you'll generally want to keep them persistent
//but we clear ours each time around rendering

u16[] v_i;

//this is the highest performance option
Vertex[] v_raw;


u16[] v_indexNonTile;

//this is the highest performance option
Vertex[] v_vertexNonTile;

bool resetTrigger = false;
bool blueprintMeshDirty = true;
const int MAX_BLUEPRINT_QUADS = 16000; // u16 indices support at most 65535 vertices.

void ClearRenderState()
{

	//we are rendering after the world
	//so we can alpha blend relatively safely, although it will still misbehave
	//when rendering over other alpha-blended stuff
}


void initRender(bool resetMapData = true)
{
	v_i.clear();
	v_raw.clear();
	v_indexNonTile.clear();
	v_vertexNonTile.clear();
	Render::SetAlphaBlend(true);
	
	if(resetMapData)
	{
		CMap@ map = getMap();
		uint16[][] _dynamicMapTileData(map.tilemapwidth, uint16[](map.tilemapheight, 0));
		dynamicMapTileData = _dynamicMapTileData;
	}

	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,0),getUVY(blockIndex,0),SColor(0x70aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,1),getUVY(blockIndex,1),SColor(0x70aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,2),getUVY(blockIndex,2),SColor(0x70aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,3),getUVY(blockIndex,3),SColor(0x70aacdff)));
	v_i.push_back(0);
	v_i.push_back(1);
	v_i.push_back(2);
	v_i.push_back(0);
	v_i.push_back(2);
	v_i.push_back(3);

	v_vertexNonTile.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,0),getUVY(blockIndex,0),SColor(0x70aacdff)));
	v_vertexNonTile.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,1),getUVY(blockIndex,1),SColor(0x70aacdff)));
	v_vertexNonTile.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,2),getUVY(blockIndex,2),SColor(0x70aacdff)));
	v_vertexNonTile.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,3),getUVY(blockIndex,3),SColor(0x70aacdff)));
	v_indexNonTile.push_back(0);
	v_indexNonTile.push_back(1);
	v_indexNonTile.push_back(2);
	v_indexNonTile.push_back(0);
	v_indexNonTile.push_back(2);
	v_indexNonTile.push_back(3);

	blueprintMeshDirty = true;
}
int updateOptimisation = 0;


void RenderWidgetFor(CPlayer@ this)
{
	Render::SetTransformWorldspace();
	//ensure that there's no null pointer. there will always be something in the array
	if(v_raw.size() < 4)
	{
		resetTrigger = true;
	}
	if(resetTrigger)
	{
		initRender(true);
		resetTrigger = false;
		if (this != null && justJoined)
		{
			CBitStream emptyparams;
			getRules().SendCommand(getRules().getCommandID("getLiveEdit"),emptyparams);
			getRules().SendCommand(getRules().getCommandID("getOverseerMode"),emptyparams);
			uint16 id = this.getNetworkID();
			CBitStream params;
			params.write_u16(id);
			getRules().SendCommand(getRules().getCommandID("getAllBlocks"), params);
			justJoined = false;
		}
	}
	CControls@ c = getControls();
	Vec2f p;
	p = c.getMouseWorldPos();
	p.x+=15;
	p.y-=15;

	//COLOR : 0xAARRGGBB
	if(c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL)) // this display the blueprint mod cursor
	{
		toggleBlueprint = true;
		v_raw[0] = (Vertex(p.x - getSizeX(blockIndex), p.y - getSizeY(blockIndex), 1000, getUVX(blockIndex,0),getUVY(blockIndex,0),SColor(0x70aacdff)));
		v_raw[1] = (Vertex(p.x + getSizeX(blockIndex), p.y - getSizeY(blockIndex), 1000, getUVX(blockIndex,1),getUVY(blockIndex,1),SColor(0x70aacdff)));
		v_raw[2] = (Vertex(p.x + getSizeX(blockIndex), p.y + getSizeY(blockIndex), 1000, getUVX(blockIndex,2),getUVY(blockIndex,2),SColor(0x70aacdff)));
		v_raw[3] = (Vertex(p.x - getSizeX(blockIndex), p.y + getSizeY(blockIndex), 1000, getUVX(blockIndex,3),getUVY(blockIndex,3),SColor(0x70aacdff)));
	}
	else
	{
		v_raw[0] = (Vertex(p.x - x_size, p.y - y_size, 1000, getUVX(blockIndex,0),getUVY(blockIndex,0),SColor(0x00aacdff)));
		v_raw[1] = (Vertex(p.x + x_size, p.y - y_size, 1000, getUVX(blockIndex,1),getUVY(blockIndex,1),SColor(0x00aacdff)));
		v_raw[2] = (Vertex(p.x + x_size, p.y + y_size, 1000, getUVX(blockIndex,2),getUVY(blockIndex,2),SColor(0x00aacdff)));
		v_raw[3] = (Vertex(p.x - x_size, p.y + y_size, 1000, getUVX(blockIndex,3),getUVY(blockIndex,3),SColor(0x00aacdff)));
	}

	if(displayMouseSelect) // this display the current selection zone
	{ // 	mouseSelect[] use index value : when x = 2, it mean 16+4 in world coords
		int x_size = Maths::Abs(mouseSelect[0].x*8-mouseSelect[1].x*8+4)/2;
		int y_size =  Maths::Abs(mouseSelect[0].y*8-mouseSelect[1].y*8+4)/2;
		int centerx;
		int centery;
		int z = 1000;
		if(mouseSelect[0].x < mouseSelect[1].x)
		{
			centerx = mouseSelect[0].x*8 +x_size;
		}
		else
		{
			centerx = mouseSelect[1].x*8 + x_size;
		}

		if(mouseSelect[0].y < mouseSelect[1].y)
		{
			centery = mouseSelect[0].y *8 + y_size;
		}
		else
		{
			centery = mouseSelect[1].y *8 + y_size;
		}
		v_raw[0] = Vertex(centerx 	- x_size, centery - y_size, 	z, getUVX(10,0), getUVY(10,0), 	SColor(0x30aacdff)); //upper left
		v_raw[1] = Vertex(centerx + 4 + x_size, centery - y_size, 	z, getUVX(10,1), getUVY(10,1), 	SColor(0x30aacdff)); //upper right
		v_raw[2] = Vertex(centerx + 4 + x_size, centery + y_size + 4, z, getUVX(10,2), getUVY(10,2), 	SColor(0x30aacdff)); //bottom right
		v_raw[3] = Vertex(centerx 	- x_size, centery + y_size + 4, z, getUVX(10,3), getUVY(10,3), 	SColor(0x30aacdff)); //bottom left
	}
	else
	{
		v_raw[0] = (Vertex(p.x - x_size, p.y - y_size, 1000, getUVX(blockIndex,0), getUVY(blockIndex,0), 	SColor(0x00aacdff)));
		v_raw[1] = (Vertex(p.x + x_size, p.y - y_size, 1000, getUVX(blockIndex,1), getUVY(blockIndex,1), 	SColor(0x00aacdff)));
		v_raw[2] = (Vertex(p.x + x_size, p.y + y_size, 1000, getUVX(blockIndex,2), getUVY(blockIndex,2), 	SColor(0x00aacdff)));
		v_raw[3] = (Vertex(p.x - x_size, p.y + y_size, 1000, getUVX(blockIndex,3), getUVY(blockIndex,3), 	SColor(0x00aacdff)));
	}

	if(toggleBlueprint)
	{
		if(blueprintMeshDirty)
		{
			updateVertex(this, v_raw, dynamicMapTileData);
			everythingMesh.SetVertex(v_raw);
			everythingMesh.SetIndices(v_i);
			if(v_raw.size() > 0)
			{
				everythingMesh.BuildMesh();
				everythingMesh.SetDirty(SMesh::VERTEX_INDEX);
			}
			else
			{
				everythingMesh.BuildMesh();
				everythingMesh.SetDirty(SMesh::VERTEX_INDEX);
			}
			blueprintMeshDirty = false;
		}
		everythingMesh.SetVertex(v_raw);
		everythingMesh.SetIndices(v_i);
		everythingMesh.BuildMesh();
		everythingMesh.SetDirty(SMesh::VERTEX_INDEX);
		everythingMesh.RenderMeshWithMaterial();
	}

	RenderSelectedTreeMarkers();

}
int xRenderLimit = 37;
int yRenderLimit = 21;
int renderingState = 0; //0 = render relative to camera position, 1 = render relative to player position

void AIB_BeginTreeSelection(Vec2f worldPos)
{
	aibTreeSelecting = true;
	AIB_SetSelectionCorner(0, worldPos);
	AIB_SetSelectionCorner(1, worldPos);
	displayMouseSelect = false;
}

void AIB_UpdateTreeSelection(Vec2f worldPos)
{
	AIB_SetSelectionCorner(1, worldPos);
	displayMouseSelect = mouseSelect[0].x != mouseSelect[1].x || mouseSelect[0].y != mouseSelect[1].y;
}

void AIB_SetSelectionCorner(const u8 index, Vec2f worldPos)
{
	int tileX = int(worldPos.x / 8);
	int tileY = int(worldPos.y / 8);
	if(tileX < 0) tileX = 0;
	if(tileY < 0) tileY = 0;
	mouseSelect[index] = Vec2f(tileX, tileY);
}

void AIB_SendTreeSelection()
{
	u16 x1;
	u16 y1;
	u16 x2;
	u16 y2;
	if(!AIB_NormalizeSelectionRect(x1, y1, x2, y2))
	{
		return;
	}

	CBitStream params;
	CPlayer@ player = getLocalPlayer();
	if(player is null) return;
	params.write_u16(player.getNetworkID());
	params.write_u16(x1);
	params.write_u16(y1);
	params.write_u16(x2);
	params.write_u16(y2);
	AIB_LogEvent("ui", "select_trees_rect", AIB_EventPlayerRef(getLocalPlayer()), "rect=" + x1 + "," + y1 + "," + x2 + "," + y2);
	getRules().SendCommand(getRules().getCommandID("aibuilderToggleTreeSelection"), params);
}

void AIB_BeginStoneSelection(Vec2f worldPos)
{
	aibStoneSelecting = true;
	AIB_SetSelectionCorner(0, worldPos);
	AIB_SetSelectionCorner(1, worldPos);
	displayMouseSelect = true;
}

void AIB_UpdateStoneSelection(Vec2f worldPos)
{
	AIB_SetSelectionCorner(1, worldPos);
}

void AIB_SendStoneSelection()
{
	u16 x1;
	u16 y1;
	u16 x2;
	u16 y2;
	if(!AIB_NormalizeSelectionRect(x1, y1, x2, y2))
	{
		return;
	}

	CBitStream params;
	CPlayer@ player = getLocalPlayer();
	if(player is null) return;
	params.write_u16(player.getNetworkID());
	params.write_u16(x1);
	params.write_u16(y1);
	params.write_u16(x2);
	params.write_u16(y2);
	AIB_LogEvent("ui", "select_stone_rect", AIB_EventPlayerRef(getLocalPlayer()), "rect=" + x1 + "," + y1 + "," + x2 + "," + y2);
	getRules().SendCommand(getRules().getCommandID("aibuilderToggleStoneSelection"), params);
}

Vec2f AIB_ToolbarMin()
{
	return Vec2f(12, 66);
}

Vec2f AIB_ToolButtonMin(const u8 tool)
{
	Vec2f start = AIB_ToolbarMin();
	return start + Vec2f(0, tool * 26);
}

bool AIB_MouseInToolButton(const u8 tool, Vec2f mouse)
{
	Vec2f min = AIB_ToolButtonMin(tool);
	Vec2f max = min + Vec2f(92, 24);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

string AIB_ToolLabel(const u8 tool)
{
	if(tool == BLUEPRINT_TOOL_PAINT) return "Paint";
	if(tool == BLUEPRINT_TOOL_ERASE) return "Erase";
	if(tool == BLUEPRINT_TOOL_SELECT) return "Select";
	if(tool == BLUEPRINT_TOOL_SAVE) return "Save";
	if(tool == BLUEPRINT_TOOL_LOAD) return "Load";
	if(tool == BLUEPRINT_TOOL_ROTATE) return "Rotate";
	if(tool == BLUEPRINT_TOOL_FLIP) return "Flip";
	if(tool == BLUEPRINT_TOOL_VISIBILITY) return toggleBlueprint ? "Hide" : "Show";
	if(tool == BLUEPRINT_TOOL_OVERSEER) return "Overseer";
	return "";
}

bool UpdateBlueprintToolbar()
{
	if(!AIB_LocalCanUseBlueprintControls())
	{
		blueprintToolbarButtonPressed = false;
		blueprintToolbarPressedTool = 255;
		return false;
	}

	CControls@ controls = getControls();
	if(controls is null) return false;

	Vec2f mouse = controls.getMouseScreenPos();
	u8 hovered = 255;
	for(u8 i = 0; i < BLUEPRINT_TOOL_COUNT; i++)
	{
		if(AIB_MouseInToolButton(i, mouse))
		{
			hovered = i;
			break;
		}
	}

	if(hovered != 255 && controls.isKeyJustPressed(KEY_LBUTTON))
	{
		blueprintToolbarButtonPressed = true;
		blueprintToolbarPressedTool = hovered;
		return true;
	}

	if(blueprintToolbarButtonPressed && !controls.isKeyPressed(KEY_LBUTTON))
	{
		if(hovered == blueprintToolbarPressedTool)
		{
			AIB_ActivateToolbarTool(hovered);
		}
		blueprintToolbarButtonPressed = false;
		blueprintToolbarPressedTool = 255;
		return true;
	}

	return hovered != 255 && controls.isKeyPressed(KEY_LBUTTON);
}

bool AIB_BlueprintCatalogPanelVisible()
{
	return AIB_LocalCanUseBlueprintControls() && AIB_LocalIsWorkshopOverseer() && blueprintEditorActive;
}

Vec2f AIB_BlueprintCatalogPanelMin()
{
	Vec2f screen = getDriver().getScreenDimensions();
	return Vec2f((screen.x - 456.0f) / 2.0f, 58.0f);
}

Vec2f AIB_BlueprintCatalogTabMin(const u8 tab)
{
	return AIB_BlueprintCatalogPanelMin() + Vec2f(8 + tab * 96, 8);
}

bool AIB_MouseInBlueprintCatalogTab(const u8 tab, Vec2f mouse)
{
	Vec2f min = AIB_BlueprintCatalogTabMin(tab);
	Vec2f max = min + Vec2f(90, 24);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

string AIB_BlueprintCatalogTabLabel(const u8 tab)
{
	if(tab == AIB_CATALOG_TAB_BLOCKS) return "Blocks";
	if(tab == AIB_CATALOG_TAB_WORKSHOPS) return "Workshops";
	return "Blobs";
}

u16 AIB_BlueprintCatalogCount(const u8 tab)
{
	if(tab == AIB_CATALOG_TAB_BLOCKS) return 4;
	if(tab == AIB_CATALOG_TAB_BLOBS) return 6;
	return 11;
}

u16 AIB_BlueprintCatalogBlockAt(const u8 tab, const u16 index)
{
	if(tab == AIB_CATALOG_TAB_BLOCKS)
	{
		if(index == 0) return AIBP_STONE_BLOCK;
		if(index == 1) return AIBP_STONE_BACKWALL;
		if(index == 2) return AIBP_WOOD_BLOCK;
		if(index == 3) return AIBP_WOOD_BACKWALL;
	}
	else if(tab == AIB_CATALOG_TAB_BLOBS)
	{
		if(index == 0) return AIBP_STONE_DOOR;
		if(index == 1) return AIBP_WOOD_DOOR;
		if(index == 2) return AIBP_BRIDGE;
		if(index == 3) return AIBP_PLATFORM;
		if(index == 4) return AIBP_LADDER;
		if(index == 5) return AIBP_SPIKES;
	}
	else
	{
		if(index == 0) return AIBP_BUILDER_SHOP;
		if(index == 1) return AIBP_QUARTERS;
		if(index == 2) return AIBP_KNIGHT_SHOP;
		if(index == 3) return AIBP_ARCHER_SHOP;
		if(index == 4) return AIBP_BOAT_SHOP;
		if(index == 5) return AIBP_VEHICLE_SHOP;
		if(index == 6) return AIBP_AI_BUILDER_SHOP;
		if(index == 7) return AIBP_NURSERY;
		if(index == 8) return AIBP_STORAGE;
		if(index == 9) return AIBP_TUNNEL;
		if(index == 10) return AIBP_QUARRY;
	}
	return AIBP_STONE_BLOCK;
}

string AIB_BlueprintCatalogShortName(const u16 block)
{
	const u16 id = AIBP_BlockId(block);
	if(id == AIBP_STONE_BLOCK) return "Stone";
	if(id == AIBP_STONE_BACKWALL) return "Stone wall";
	if(id == AIBP_WOOD_BLOCK) return "Wood";
	if(id == AIBP_WOOD_BACKWALL) return "Wood wall";
	if(id == AIBP_STONE_DOOR) return "Stone door";
	if(id == AIBP_WOOD_DOOR) return "Wood door";
	if(id == AIBP_BRIDGE) return "Bridge";
	if(id == AIBP_PLATFORM) return "Platform";
	if(id == AIBP_LADDER) return "Ladder";
	if(id == AIBP_SPIKES) return "Spikes";
	if(id == AIBP_BUILDER_SHOP) return "Builder";
	if(id == AIBP_QUARTERS) return "Quarters";
	if(id == AIBP_KNIGHT_SHOP) return "Knight";
	if(id == AIBP_ARCHER_SHOP) return "Archer";
	if(id == AIBP_BOAT_SHOP) return "Boat";
	if(id == AIBP_VEHICLE_SHOP) return "Vehicle";
	if(id == AIBP_AI_BUILDER_SHOP) return "AI Builder";
	if(id == AIBP_NURSERY) return "Nursery";
	if(id == AIBP_STORAGE) return "Storage";
	if(id == AIBP_TUNNEL) return "Tunnel";
	if(id == AIBP_QUARRY) return "Quarry";
	return AIBP_BlockDisplayName(block);
}

SColor AIB_BlueprintCatalogSwatch(const u16 block)
{
	const u16 id = AIBP_BlockId(block);
	if(id == AIBP_STONE_BLOCK || id == AIBP_STONE_BACKWALL || id == AIBP_STONE_DOOR || id == AIBP_SPIKES) return SColor(0xff8f969e);
	if(id == AIBP_WOOD_BLOCK || id == AIBP_WOOD_BACKWALL || id == AIBP_WOOD_DOOR || id == AIBP_BRIDGE || id == AIBP_PLATFORM || id == AIBP_LADDER) return SColor(0xffb17a42);
	if(AIBP_IsWorkshopBlock(block)) return SColor(0xff6f8fb1);
	return SColor(0xff777777);
}

bool AIB_BlueprintCatalogUsesAtlasPreview(const u16 block)
{
	return !AIBP_IsWorkshopBlock(block);
}

u16 AIB_BlueprintCatalogAtlasFrame(const u16 block)
{
	return AIBP_BlockId(AIB_RenderAtlasBlock(block));
}

Vec2f AIB_BlueprintCatalogCellMin(const u16 index)
{
	const u16 cols = 4;
	Vec2f panelMin = AIB_BlueprintCatalogPanelMin();
	return panelMin + Vec2f(8 + (index % cols) * 110, 40 + (index / cols) * 50);
}

bool AIB_MouseInBlueprintCatalogCell(const u16 index, Vec2f mouse)
{
	Vec2f min = AIB_BlueprintCatalogCellMin(index);
	Vec2f max = min + Vec2f(104, 44);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

bool AIB_BlueprintCatalogBlockAtMouse(Vec2f mouse, u16 &out block)
{
	const u16 count = AIB_BlueprintCatalogCount(blueprintCatalogTab);
	for(u16 i = 0; i < count; i++)
	{
		if(AIB_MouseInBlueprintCatalogCell(i, mouse))
		{
			block = AIB_BlueprintCatalogBlockAt(blueprintCatalogTab, i);
			return true;
		}
	}
	return false;
}

bool UpdateBlueprintCatalogPanel()
{
	if(!AIB_BlueprintCatalogPanelVisible())
	{
		blueprintCatalogPanelButtonPressed = false;
		blueprintCatalogPanelPressedBlock = 0;
		blueprintCatalogTabButtonPressed = false;
		blueprintCatalogTabPressed = 255;
		return false;
	}

	CControls@ controls = getControls();
	if(controls is null) return false;
	Vec2f mouse = controls.getMouseScreenPos();

	u8 hoveredTab = 255;
	for(u8 i = 0; i < AIB_CATALOG_TAB_COUNT; i++)
	{
		if(AIB_MouseInBlueprintCatalogTab(i, mouse))
		{
			hoveredTab = i;
			break;
		}
	}

	if(hoveredTab != 255 && controls.isKeyJustPressed(KEY_LBUTTON))
	{
		blueprintCatalogTabButtonPressed = true;
		blueprintCatalogTabPressed = hoveredTab;
		return true;
	}
	if(blueprintCatalogTabButtonPressed && !controls.isKeyPressed(KEY_LBUTTON))
	{
		if(hoveredTab == blueprintCatalogTabPressed) blueprintCatalogTab = hoveredTab;
		blueprintCatalogTabButtonPressed = false;
		blueprintCatalogTabPressed = 255;
		return true;
	}

	u16 hoveredBlock = 0;
	const bool hoveredCell = AIB_BlueprintCatalogBlockAtMouse(mouse, hoveredBlock);
	if(hoveredCell && controls.isKeyJustPressed(KEY_LBUTTON))
	{
		blueprintCatalogPanelButtonPressed = true;
		blueprintCatalogPanelPressedBlock = hoveredBlock;
		return true;
	}
	if(blueprintCatalogPanelButtonPressed && !controls.isKeyPressed(KEY_LBUTTON))
	{
		if(hoveredCell && hoveredBlock == blueprintCatalogPanelPressedBlock)
		{
			customMenuTurn = AIBP_BlockId(hoveredBlock);
			currentRotation = AIBP_DefaultRotation(hoveredBlock);
			oldBlockIndex = customMenuTurn;
			blockIndex = AIBP_EncodeBlock(customMenuTurn, currentRotation);
			customCatalogSelectionActive = true;
		}
		blueprintCatalogPanelButtonPressed = false;
		blueprintCatalogPanelPressedBlock = 0;
		return true;
	}

	Vec2f panelMin = AIB_BlueprintCatalogPanelMin();
	Vec2f panelMax = panelMin + Vec2f(456, 198);
	const bool inPanel = mouse.x >= panelMin.x && mouse.x <= panelMax.x && mouse.y >= panelMin.y && mouse.y <= panelMax.y;
	return inPanel && controls.isKeyPressed(KEY_LBUTTON);
}

void AIB_ActivateToolbarTool(const u8 tool)
{
	if(tool == BLUEPRINT_TOOL_SAVE)
	{
		keyOJustPressed = true;
		return;
	}
	if(tool == BLUEPRINT_TOOL_LOAD)
	{
		displayPrefabSelectionMenu = !displayPrefabSelectionMenu;
		if(!displayPrefabSelectionMenu)
		{
			AIB_CloseSelectionModes();
		}
		return;
	}
	if(tool == BLUEPRINT_TOOL_ROTATE)
	{
		if(currentRotation <= 0)
		{
			currentRotation = 3;
		}
		else
		{
			currentRotation -= 1;
		}
		return;
	}
	if(tool == BLUEPRINT_TOOL_FLIP)
	{
		flipBlueprint = !flipBlueprint;
		return;
	}
	if(tool == BLUEPRINT_TOOL_VISIBILITY)
	{
		toggleBlueprint = !toggleBlueprint;
		return;
	}
	if(tool == BLUEPRINT_TOOL_OVERSEER)
	{
		// Overseer view is entered and exited through an AI Builder Workshop chair.
		return;
	}

	if(blueprintEditorActive && blueprintEditorTool == tool)
	{
		blueprintEditorActive = false;
		blueprintEditorSelecting = false;
	}
	else
	{
		blueprintEditorActive = true;
		blueprintEditorTool = tool;
	}
	displayPrefabSelectionMenu = false;
	AIB_CloseSelectionModes();
}

void AIB_SetOverseerViewActive(const bool active)
{
	overseerViewActive = active;
	overseerSelectionDragging = false;
	displayMouseSelect = false;
	if(active)
	{
		blueprintEditorActive = false;
		displayPrefabSelectionMenu = true;
		toggleBlueprint = true;
		CCamera@ camera = getCamera();
		CBlob@ blob = getLocalPlayerBlob();
		if(camera !is null)
		{
			overseerCameraPos = camera.getPosition();
			camera.setTarget(null);
		}
		else if(blob !is null)
		{
			overseerCameraPos = blob.getPosition();
		}
	}
	else
	{
		CCamera@ camera = getCamera();
		CBlob@ blob = getLocalPlayerBlob();
		if(camera !is null && blob !is null)
		{
			camera.setTarget(blob);
		}
	}
}

bool AIB_LocalIsWorkshopOverseer()
{
	CBlob@ blob = getLocalPlayerBlob();
	return blob !is null && blob.isAttachedToPoint("OVERSEER");
}

void AIB_SyncOverseerViewWithWorkshop()
{
	const bool shouldBeActive = AIB_LocalIsWorkshopOverseer()
		&& AIB_CanPlayerUseOverseerControls(getLocalPlayer());
	if(shouldBeActive != overseerViewActive)
	{
		AIB_SetOverseerViewActive(shouldBeActive);
	}
}

void UpdateOverseerViewCamera()
{
	if(!overseerViewActive) return;
	CPlayer@ player = getLocalPlayer();
	if(!AIB_CanPlayerUseOverseerControls(player))
	{
		AIB_SetOverseerViewActive(false);
		return;
	}

	CCamera@ camera = getCamera();
	CControls@ controls = getControls();
	if(camera is null || controls is null) return;

	if(overseerCameraPos == Vec2f_zero)
	{
		overseerCameraPos = camera.getPosition();
	}

	Vec2f move = Vec2f_zero;
	if(controls.isKeyPressed(KEY_KEY_A)) move.x -= 1.0f;
	if(controls.isKeyPressed(KEY_KEY_D)) move.x += 1.0f;
	if(controls.isKeyPressed(KEY_KEY_W)) move.y -= 1.0f;
	if(controls.isKeyPressed(KEY_KEY_S)) move.y += 1.0f;
	if(move.Length() > 0.0f)
	{
		move.Normalize();
		const f32 speed = controls.isKeyPressed(KEY_LSHIFT) || controls.isKeyPressed(KEY_RSHIFT) ? 28.0f : 14.0f;
		overseerCameraPos += move * speed * getRenderApproximateCorrectionFactor();
	}

	camera.setTarget(null);
	camera.setPosition(overseerCameraPos);
}

bool UpdateOverseerView()
{
	if(!overseerViewActive) return false;
	CPlayer@ player = getLocalPlayer();
	if(!AIB_CanPlayerUseOverseerControls(player)) return false;

	CControls@ controls = getControls();
	if(controls is null) return true;

	// Blueprint editing and resource selection own world mouse input while they
	// are active.  The control modifier also preserves the legacy live-edit
	// gesture.  Let ChangeIfNeeded handle those clicks instead of turning every
	// overseer left-click into an AI-builder selection drag.
	if(blueprintEditorActive || displayLoadedBlueprint || aibTreeSelectMode || aibStoneSelectMode
		|| controls.isKeyPressed(KEY_LCONTROL) || controls.isKeyPressed(KEY_RCONTROL))
	{
		return false;
	}

	bool consumedDrag = UpdateOverseerPanelDrag();
	if(consumedDrag) return true;

	bool consumedOrder = UpdateOverseerOrderButtons();
	if(consumedOrder) return true;

	if(controls.isKeyJustPressed(KEY_RBUTTON) || controls.isKeyJustPressed(KEY_CANCEL))
	{
		overseerSelectedBuilders.clear();
		overseerSelectionDragging = false;
		displayMouseSelect = false;
		return true;
	}

	if(controls.isKeyJustPressed(KEY_LBUTTON))
	{
		overseerSelectionDragging = true;
		AIB_SetSelectionCorner(0, controls.getMouseWorldPos());
		AIB_SetSelectionCorner(1, controls.getMouseWorldPos());
		displayMouseSelect = true;
		return true;
	}
	if(overseerSelectionDragging && controls.isKeyPressed(KEY_LBUTTON))
	{
		AIB_SetSelectionCorner(1, controls.getMouseWorldPos());
		displayMouseSelect = true;
		return true;
	}
	if(overseerSelectionDragging && !controls.isKeyPressed(KEY_LBUTTON))
	{
		AIB_SetSelectionCorner(1, controls.getMouseWorldPos());
		AIB_SelectBuildersInCurrentRect();
		overseerSelectionDragging = false;
		displayMouseSelect = false;
		return true;
	}

	// No overseer interaction consumed this frame.  Allow the legacy blueprint
	// controls to process keyboard input such as holding X to move/open the UI.
	return false;
}

bool AIB_IsSelectedOverseerBuilder(CBlob@ builder)
{
	if(builder is null) return false;
	const u16 id = builder.getNetworkID();
	for(uint i = 0; i < overseerSelectedBuilders.length; i++)
	{
		if(overseerSelectedBuilders[i] == id) return true;
	}
	return false;
}

void AIB_SelectBuildersInCurrentRect()
{
	u16 x1;
	u16 y1;
	u16 x2;
	u16 y2;
	if(!AIB_NormalizeSelectionRect(x1, y1, x2, y2)) return;

	CPlayer@ player = getLocalPlayer();
	const int team = player is null ? -1 : player.getTeamNum();
	overseerSelectedBuilders.clear();
	CBlob@[] builders;
	AIB_GetConstructionWorkers(builders);
	for(uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if(builder is null || builder.hasTag("dead")) continue;
		if(team >= 0 && team < 100 && builder.getTeamNum() != team) continue;
		const u16 tx = u16(builder.getPosition().x / 8);
		const u16 ty = u16(builder.getPosition().y / 8);
		if(tx >= x1 && tx <= x2 && ty >= y1 && ty <= y2)
		{
			overseerSelectedBuilders.push_back(builder.getNetworkID());
		}
	}

	if(overseerSelectedBuilders.length == 0)
	{
		CBlob@ nearest = AIB_GetNearestOverseerBuilder(getControls().getMouseWorldPos());
		if(nearest !is null)
		{
			overseerSelectedBuilders.push_back(nearest.getNetworkID());
		}
	}
}

CBlob@ AIB_GetNearestOverseerBuilder(Vec2f worldPos)
{
	CPlayer@ player = getLocalPlayer();
	const int team = player is null ? -1 : player.getTeamNum();
	CBlob@[] builders;
	AIB_GetConstructionWorkers(builders);
	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	for(uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if(builder is null || builder.hasTag("dead")) continue;
		if(team >= 0 && team < 100 && builder.getTeamNum() != team) continue;
		const f32 distance = (builder.getPosition() - worldPos).Length();
		if(distance < bestDistance && distance <= 40.0f)
		{
			bestDistance = distance;
			@best = builder;
		}
	}
	return best;
}

Vec2f AIB_OverseerPanelDefaultPosition()
{
	Vec2f screen = getDriver().getScreenDimensions();
	return Vec2f(118, screen.y - 146);
}

Vec2f AIB_ClampOverseerPanelPosition(Vec2f pos)
{
	Vec2f screen = getDriver().getScreenDimensions();
	const f32 width = 154.0f;
	const f32 height = 124.0f;
	pos.x = Maths::Clamp(pos.x, 4.0f, Maths::Max(4.0f, screen.x - width - 4.0f));
	pos.y = Maths::Clamp(pos.y, 4.0f, Maths::Max(4.0f, screen.y - height - 4.0f));
	return pos;
}

Vec2f AIB_OverseerPanelPosition()
{
	if(overseerPanelPosition.x < 0.0f || overseerPanelPosition.y < 0.0f)
	{
		overseerPanelPosition = AIB_OverseerPanelDefaultPosition();
	}
	overseerPanelPosition = AIB_ClampOverseerPanelPosition(overseerPanelPosition);
	return overseerPanelPosition;
}

Vec2f AIB_OverseerPanelHeaderMin()
{
	return AIB_OverseerPanelPosition();
}

bool AIB_MouseInOverseerPanelHeader(Vec2f mouse)
{
	Vec2f min = AIB_OverseerPanelHeaderMin();
	Vec2f max = min + Vec2f(154, 28);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

bool UpdateOverseerPanelDrag()
{
	CControls@ controls = getControls();
	if(controls is null) return false;

	Vec2f mouse = controls.getMouseScreenPos();
	if(AIB_MouseInOverseerPanelHeader(mouse) && controls.isKeyJustPressed(KEY_LBUTTON))
	{
		overseerPanelDragging = true;
		overseerPanelDragOffset = mouse - AIB_OverseerPanelPosition();
		return true;
	}

	if(overseerPanelDragging)
	{
		if(controls.isKeyPressed(KEY_LBUTTON))
		{
			overseerPanelPosition = AIB_ClampOverseerPanelPosition(mouse - overseerPanelDragOffset);
			return true;
		}

		overseerPanelDragging = false;
		return true;
	}

	return false;
}

Vec2f AIB_OverseerOrderButtonMin(const u8 order)
{
	return AIB_OverseerPanelPosition() + Vec2f(0, 34 + order * 32);
}

bool AIB_MouseInOverseerOrderButton(const u8 order, Vec2f mouse)
{
	Vec2f min = AIB_OverseerOrderButtonMin(order);
	Vec2f max = min + Vec2f(154, 28);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

Vec2f AIB_DirectorPanelMin()
{
	return Vec2f(210, 8);
}

Vec2f AIB_DirectorToggleMin()
{
	return AIB_DirectorPanelMin() + Vec2f(330, 4);
}

bool AIB_LocalCanToggleDirector()
{
	CPlayer@ player = getLocalPlayer();
	return player !is null && player.getTeamNum() >= 0 && player.getTeamNum() < 8 && AIB_CanPlayerUseOverseerControls(player);
}

bool AIB_MouseInDirectorToggle(Vec2f mouse)
{
	Vec2f min = AIB_DirectorToggleMin();
	Vec2f max = min + Vec2f(92, 22);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

bool UpdateAIBDirectorToggle()
{
	if(!AIB_LocalCanToggleDirector())
	{
		aibDirectorTogglePressed = false;
		return false;
	}

	CControls@ controls = getControls();
	if(controls is null) return false;
	const bool hovered = AIB_MouseInDirectorToggle(controls.getMouseScreenPos());
	if(hovered && controls.isKeyJustPressed(KEY_LBUTTON))
	{
		aibDirectorTogglePressed = true;
		return true;
	}

	if(aibDirectorTogglePressed && !controls.isKeyPressed(KEY_LBUTTON))
	{
		if(hovered) AIB_SendDirectorToggle();
		aibDirectorTogglePressed = false;
		return true;
	}

	return hovered && controls.isKeyPressed(KEY_LBUTTON);
}

void AIB_SendDirectorToggle()
{
	CPlayer@ player = getLocalPlayer();
	CRules@ rules = getRules();
	if(player is null || rules is null || player.getTeamNum() < 0 || player.getTeamNum() >= 8) return;
	const u8 team = u8(player.getTeamNum());
	const u8 requestedMode = AIBP_ToggleDirectorMode(rules.get_u8(AIBP_ModeKey(team)));
	CBitStream params;
	params.write_u16(player.getNetworkID());
	params.write_u16(0);
	params.write_u8(requestedMode == AIBP_StrategyMode::auto_mode ? AIB_OVERSEER_ORDER_DIRECTOR_ON : AIB_OVERSEER_ORDER_DIRECTOR_OFF);
	rules.SendCommand(rules.getCommandID("overseerOrderAIBuilder"), params);
	AIB_LogEvent("ui", "director_toggle", AIB_EventPlayerRef(player), "mode=" + requestedMode + " team=" + team);
}

void AIB_ServerSetDirectorMode(const u16 playerNetID, const u8 requestedMode)
{
	if(!isServer() || (requestedMode != AIBP_StrategyMode::off && requestedMode != AIBP_StrategyMode::auto_mode)) return;
	CPlayer@ player = getPlayerByNetworkId(playerNetID);
	if(player is null || player.getTeamNum() < 0 || player.getTeamNum() >= 8 || !AIB_ServerCanUseBlueprintControls(playerNetID)) return;
	const u8 team = u8(player.getTeamNum());
	CRules@ rules = getRules();
	if(rules is null) return;
	rules.set_u8(AIBP_ModeKey(team), requestedMode);
	rules.Sync(AIBP_ModeKey(team), true);
	rules.set_u32("aib strategy important event team " + int(team), getGameTime());
	AIBP_SetAIWorkEnabled(team, requestedMode == AIBP_StrategyMode::auto_mode);
	if(requestedMode == AIBP_StrategyMode::off) AIB_ServerStopDirectorAssignments(team);
	AIB_LogEvent("player", "director_mode", AIB_EventPlayerRef(player), "mode=" + requestedMode + " team=" + team);
}

void AIB_ServerStopDirectorAssignments(const u8 team)
{
	if(!isServer()) return;
	CBlob@[] builders;
	AIB_GetConstructionWorkers(builders);
	for(uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if(builder is null || builder.hasTag("dead") || builder.getTeamNum() != team || !builder.get_bool("aib strategy assigned")) continue;
		AIBP_ReleaseBuilderReservation(team, builder.getNetworkID());
		builder.set_u8("ai builder state", AIB_RENDERER_STATE_IDLE);
		builder.set_bool("ai builder job active", false);
		builder.set_bool("aib strategy assigned", false);
		builder.set_netid("ai builder target", 0);
		builder.set_Vec2f("ai builder destination", Vec2f_zero);
		builder.set_Vec2f("ai builder tile target", Vec2f_zero);
		builder.Sync("ai builder state", true);
		builder.Sync("ai builder job active", true);
	}
}

void AIB_GetConstructionWorkers(array<CBlob@> &out builders)
{
	builders.clear();
	string[] names = { "aibuilder", "autobuilder" };
	for(uint n = 0; n < names.length; n++)
	{
		CBlob@[] named;
		getBlobsByName(names[n], @named);
		for(uint i = 0; i < named.length; i++) builders.push_back(named[i]);
	}
}

bool UpdateOverseerOrderButtons()
{
	if(overseerSelectedBuilders.length == 0)
	{
		overseerOrderButtonPressed = false;
		overseerPressedOrder = 255;
		return false;
	}

	CControls@ controls = getControls();
	if(controls is null) return false;
	Vec2f mouse = controls.getMouseScreenPos();
	u8 hovered = 255;
	for(u8 i = 0; i < 3; i++)
	{
		if(AIB_MouseInOverseerOrderButton(i, mouse))
		{
			hovered = i;
			break;
		}
	}

	if(hovered != 255 && controls.isKeyJustPressed(KEY_LBUTTON))
	{
		overseerOrderButtonPressed = true;
		overseerPressedOrder = hovered;
		return true;
	}

	if(overseerOrderButtonPressed && !controls.isKeyPressed(KEY_LBUTTON))
	{
		if(hovered == overseerPressedOrder)
		{
			AIB_SendOverseerOrder(hovered);
		}
		overseerOrderButtonPressed = false;
		overseerPressedOrder = 255;
		return true;
	}

	return hovered != 255 && controls.isKeyPressed(KEY_LBUTTON);
}

void AIB_SendOverseerOrder(const u8 order)
{
	CPlayer@ player = getLocalPlayer();
	if(player is null) return;
	for(uint i = 0; i < overseerSelectedBuilders.length; i++)
	{
		CBitStream params;
		params.write_u16(player.getNetworkID());
		params.write_u16(overseerSelectedBuilders[i]);
		params.write_u8(order);
		getRules().SendCommand(getRules().getCommandID("overseerOrderAIBuilder"), params);
	}
}

void AIB_ServerApplyOverseerOrder(const u16 playerNetID, const u16 builderNetID, const u8 order)
{
	if(!isServer()) return;
	if(order == AIB_OVERSEER_ORDER_DIRECTOR_OFF || order == AIB_OVERSEER_ORDER_DIRECTOR_ON)
	{
		AIB_ServerSetDirectorMode(playerNetID,
			order == AIB_OVERSEER_ORDER_DIRECTOR_ON ? AIBP_StrategyMode::auto_mode : AIBP_StrategyMode::off);
		return;
	}
	CBlob@ builder = getBlobByNetworkID(builderNetID);
	if(builder is null || (builder.getName() != "aibuilder" && builder.getName() != "autobuilder") || builder.hasTag("dead")) return;
	if(!AIB_ServerCanIssueOverseerCommand(playerNetID, u8(builder.getTeamNum()))) return;
	const bool autoBuilder = builder.getName() == "autobuilder";
	if(autoBuilder && order != AIB_OVERSEER_ORDER_BLUEPRINT) return;
	AIBP_ReleaseBuilderReservation(u8(builder.getTeamNum()), builder.getNetworkID());

	if(order == AIB_OVERSEER_ORDER_WOOD)
	{
		builder.set_u8("ai builder state", 1);
		builder.set_u8("ai builder job", 0);
	}
	else if(order == AIB_OVERSEER_ORDER_STONE)
	{
		builder.set_u8("ai builder state", 7);
		builder.set_u8("ai builder job", 1);
		builder.set_Vec2f("ai builder tile target", Vec2f_zero);
		builder.set_Vec2f("ai builder shaft top", Vec2f_zero);
	}
	else if(order == AIB_OVERSEER_ORDER_BLUEPRINT)
	{
		builder.set_u8("ai builder state", autoBuilder ? 13 : 12);
		builder.set_u8("ai builder job", 2);
		builder.set_Vec2f("ai builder tile target", Vec2f_zero);
		builder.set_Vec2f("ai builder shaft top", Vec2f_zero);
		builder.set_bool("ai builder saw blueprint target", false);
	}
	else
	{
		return;
	}

	builder.set_netid("ai builder target", 0);
	builder.set_Vec2f("ai builder destination", Vec2f_zero);
	builder.set_bool("ai builder job active", true);
	builder.set_bool("aib strategy assigned", false);
	builder.Sync("ai builder state", true);
	builder.Sync("ai builder job", true);
	builder.Sync("ai builder job active", true);
	AIB_LogEvent("player", "overseer_order", AIB_EventBlobRef(builder), "order=" + order + " player=" + playerNetID + " pos=" + AIB_EventPos(builder.getPosition()));
}

bool UpdateTreeSelectionButton()
{
	if(!AIB_LocalCanUseBlueprintControls())
	{
		aibTreeButtonPressed = false;
		return false;
	}
	if(!displayPrefabSelectionMenu)
	{
		aibTreeButtonPressed = false;
		return false;
	}

	CControls@ controls = getControls();
	if(controls is null)
	{
		aibTreeButtonPressed = false;
		return false;
	}

	bool hover = AIB_MouseInTreeButton(controls.getMouseScreenPos());
	bool leftPressed = controls.isKeyJustPressed(KEY_LBUTTON);

	if(hover && leftPressed)
	{
		aibTreeButtonPressed = true;
		return true;
	}

	if(aibTreeButtonPressed && !controls.isKeyPressed(KEY_LBUTTON))
	{
		if(hover)
		{
			aibTreeSelectMode = !aibTreeSelectMode;
			aibStoneSelectMode = false;
			aibTreeSelecting = false;
			aibStoneSelecting = false;
			displayMouseSelect = false;
			displayPrefabSelectionMenu = !aibTreeSelectMode;
			AIB_LogEvent("ui", aibTreeSelectMode ? "select_trees_open" : "select_trees_confirm", AIB_EventPlayerRef(getLocalPlayer()), "button_pos=" + AIB_EventPos(aibTreeButtonPosition));
		}
		aibTreeButtonPressed = false;
		return true;
	}

	return aibTreeButtonPressed || (hover && controls.isKeyPressed(KEY_LBUTTON));
}

bool AIB_MouseInTreeButton(Vec2f mouse)
{
	Vec2f min = aibTreeButtonPosition;
	Vec2f max = min + Vec2f(178, 28);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

bool UpdateStoneSelectionButton()
{
	if(!AIB_LocalCanUseBlueprintControls())
	{
		aibStoneButtonPressed = false;
		return false;
	}
	if(!displayPrefabSelectionMenu)
	{
		aibStoneButtonPressed = false;
		return false;
	}

	CControls@ controls = getControls();
	if(controls is null)
	{
		aibStoneButtonPressed = false;
		return false;
	}

	bool hover = AIB_MouseInStoneButton(controls.getMouseScreenPos());
	bool leftPressed = controls.isKeyJustPressed(KEY_LBUTTON);

	if(hover && leftPressed)
	{
		aibStoneButtonPressed = true;
		return true;
	}

	if(aibStoneButtonPressed && !controls.isKeyPressed(KEY_LBUTTON))
	{
		if(hover)
		{
			aibStoneSelectMode = !aibStoneSelectMode;
			aibTreeSelectMode = false;
			aibStoneSelecting = false;
			aibTreeSelecting = false;
			displayMouseSelect = false;
			displayPrefabSelectionMenu = !aibStoneSelectMode;
			AIB_LogEvent("ui", aibStoneSelectMode ? "select_stone_open" : "select_stone_confirm", AIB_EventPlayerRef(getLocalPlayer()), "button_pos=" + AIB_EventPos(aibStoneButtonPosition));
		}
		aibStoneButtonPressed = false;
		return true;
	}

	return aibStoneButtonPressed || (hover && controls.isKeyPressed(KEY_LBUTTON));
}

bool AIB_MouseInStoneButton(Vec2f mouse)
{
	Vec2f min = aibStoneButtonPosition;
	Vec2f max = min + Vec2f(178, 28);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

void AIB_CloseSelectionModes()
{
	aibTreeSelectMode = false;
	aibTreeSelecting = false;
	aibTreeButtonPressed = false;
	aibStoneSelectMode = false;
	aibStoneSelecting = false;
	aibStoneButtonPressed = false;
	displayMouseSelect = false;
}

void AIB_ToggleTreesInSelection(const u16 x1, const u16 y1, const u16 x2, const u16 y2)
{
	CBlob@[] trees;
	getBlobsByTag("tree", @trees);
	for(uint i = 0; i < trees.length; i++)
	{
		CBlob@ tree = trees[i];
		if(tree is null) continue;

		Vec2f pos = tree.getPosition();
		u16 tx = u16(pos.x / 8);
		u16 ty = u16(pos.y / 8);
		if(tx < x1 || tx > x2 || ty < y1 || ty > y2)
		{
			continue;
		}

		bool selected = !tree.get_bool("aibuilder selected tree");
		tree.set_bool("aibuilder selected tree", selected);
		tree.Sync("aibuilder selected tree", true);
		AIB_LogEvent("ui", "toggle_tree", AIB_EventBlobRef(tree), "selected=" + (selected ? "true" : "false") + " rect=" + x1 + "," + y1 + "," + x2 + "," + y2);
		if(selected)
		{
			tree.Tag("aibuilder selected tree");
		}
		else
		{
			tree.Untag("aibuilder selected tree");
		}
	}
}

array<Vec2f>@ AIB_GetSelectedStoneTiles()
{
	CRules@ rules = getRules();
	array<Vec2f>@ stones = null;
	if(!rules.get("aibuilder selected stone tiles", @stones))
	{
		array<Vec2f> empty;
		rules.set("aibuilder selected stone tiles", empty);
		rules.get("aibuilder selected stone tiles", @stones);
	}
	return stones;
}

void AIB_ToggleStoneInSelection(const u16 x1, const u16 y1, const u16 x2, const u16 y2)
{
	CMap@ map = getMap();
	if(map is null) return;

	array<Vec2f>@ stones = AIB_GetSelectedStoneTiles();
	if(stones is null) return;

	const int startX = Maths::Max(0, int(x1));
	const int startY = Maths::Max(0, int(y1));
	const int endX = Maths::Min(int(x2), map.tilemapwidth - 1);
	const int endY = Maths::Min(int(y2), map.tilemapheight - 1);
	if(startX > endX || startY > endY) return;

	for(int y = startY; y <= endY; y++)
	{
		for(int x = startX; x <= endX; x++)
		{
			Vec2f tile = Vec2f(x * map.tilesize, y * map.tilesize);
			if(!AIB_IsSelectableStoneTile(tile)) continue;

			int index = AIB_FindSelectedStoneIndex(stones, u16(x), u16(y));
			bool selected = index < 0;
			if(selected)
			{
				stones.push_back(Vec2f(x, y));
			}
			else
			{
				stones.removeAt(index);
			}
			AIB_LogEvent("ui", "toggle_stone", "stone:" + x + "," + y, "selected=" + (selected ? "true" : "false") + " rect=" + x1 + "," + y1 + "," + x2 + "," + y2);
		}
	}
}

void AIB_RetargetStoneBuilders()
{
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	for(uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if(builder is null || builder.hasTag("dead")) continue;
		if(builder.get_u8("ai builder job") != AIB_RENDERER_JOB_STONE) continue;

		builder.set_u8("ai builder state", AIB_RENDERER_STATE_FIND_STONE);
		builder.set_netid("ai builder target", 0);
		builder.set_Vec2f("ai builder destination", Vec2f_zero);
		builder.set_Vec2f("ai builder tile target", Vec2f_zero);
		builder.set_Vec2f("ai builder shaft top", Vec2f_zero);
		builder.Sync("ai builder state", true);
	}
}

int AIB_FindSelectedStoneIndex(array<Vec2f>@ stones, const u16 x, const u16 y)
{
	if(stones is null) return -1;
	for(uint i = 0; i < stones.length; i++)
	{
		if(u16(stones[i].x) == x && u16(stones[i].y) == y)
		{
			return i;
		}
	}
	return -1;
}

bool AIB_IsSelectableStoneTile(Vec2f tile)
{
	CMap@ map = getMap();
	if(map is null) return false;

	TileType type = map.getTile(tile).type;
	return map.isTileStone(type) || map.isTileThickStone(type);
}

void RenderSelectedTreeMarkers()
{
	v_vertexNonTile.clear();
	v_indexNonTile.clear();

	CBlob@[] trees;
	getBlobsByTag("tree", @trees);
	for(uint i = 0; i < trees.length; i++)
	{
		CBlob@ tree = trees[i];
		if(tree is null || !tree.get_bool("aibuilder selected tree")) continue;

		AIB_DrawResourceSelectionHead(tree.getPosition() + Vec2f(0, -14));
	}

	array<Vec2f>@ stones = AIB_GetSelectedStoneTiles();
	CMap@ map = getMap();
	if(stones !is null && map !is null)
	{
		for(uint i = 0; i < stones.length; i++)
		{
			Vec2f tile = Vec2f(stones[i].x * map.tilesize, stones[i].y * map.tilesize);
			if(!AIB_IsSelectableStoneTile(tile)) continue;

			AIB_DrawResourceSelectionHead(tile + Vec2f(map.tilesize * 0.5f, map.tilesize * 0.5f));
		}
	}

	if(overseerViewActive)
	{
		CBlob@[] builders;
		AIB_GetConstructionWorkers(builders);
		for(uint i = 0; i < builders.length; i++)
		{
			CBlob@ builder = builders[i];
			if(builder is null || builder.hasTag("dead")) continue;
			if(!AIB_IsSelectedOverseerBuilder(builder)) continue;
			AIB_DrawBuilderSelectionMarker(builder.getPosition() + Vec2f(0, -6));
		}
	}

	if(v_vertexNonTile.size() == 0)
	{
		return;
	}

	nonTileMesh.SetVertex(v_vertexNonTile);
	nonTileMesh.SetIndices(v_indexNonTile);
	nonTileMesh.BuildMesh();
	nonTileMesh.SetDirty(SMesh::VERTEX_INDEX);
	nonTileMesh.RenderMeshWithMaterial();
}

void AIB_DrawResourceSelectionHead(Vec2f worldPos)
{
	CPlayer@ player = getLocalPlayer();
	u8 team = player is null || player.getTeamNum() >= 8 ? 0 : u8(player.getTeamNum());
	Vec2f screenPos = getDriver().getScreenPosFromWorldPos(worldPos);
	Vec2f iconSize = Vec2f(16, 16) * AIB_RESOURCE_MARKER_SCALE;
	GUI::DrawIcon("Heads.png", AIB_BUILDER_HEAD_FRAME, Vec2f(16, 16), screenPos - iconSize * 0.5f, AIB_RESOURCE_MARKER_SCALE, team);
}

void AIB_DrawBuilderSelectionMarker(Vec2f worldPos)
{
	Vec2f screenPos = getDriver().getScreenPosFromWorldPos(worldPos);

	// Layer translucent circles from the faint outer edge inward.  This keeps
	// the builder visible while producing a soft white selection glow without
	// relying on the blueprint mesh texture/UVs.
	GUI::DrawCircle(screenPos, 22.0f, SColor(0x30ffffff));
	GUI::DrawCircle(screenPos, 19.0f, SColor(0x38ffffff));
	GUI::DrawCircle(screenPos, 16.0f, SColor(0x40ffffff));
	GUI::DrawCircle(screenPos, 13.0f, SColor(0x48ffffff));
}

void AddBlueprintQuad(Vertex[] &vertices, u16[] &indices, int x, int y, uint16 blockID)
{
	u16 index = uint16(vertices.size());
	f32 z = 1000;

	vertices.push_back(Vertex(x*8+4 - getSizeX(blockID), y*8+4 - getSizeY(blockID), z, getUVX(blockID,0), getUVY(blockID,0), SColor(0x70aacdff)));
	vertices.push_back(Vertex(x*8+4 + getSizeX(blockID), y*8+4 - getSizeY(blockID), z, getUVX(blockID,1), getUVY(blockID,1), SColor(0x70aacdff)));
	vertices.push_back(Vertex(x*8+4 + getSizeX(blockID), y*8+4 + getSizeY(blockID), z, getUVX(blockID,2), getUVY(blockID,2), SColor(0x70aacdff)));
	vertices.push_back(Vertex(x*8+4 - getSizeX(blockID), y*8+4 + getSizeY(blockID), z, getUVX(blockID,3), getUVY(blockID,3), SColor(0x70aacdff)));

	indices.push_back(index);
	indices.push_back(index+1);
	indices.push_back(index+2);
	indices.push_back(index);
	indices.push_back(index+2);
	indices.push_back(index+3);
}

void updateVertex(CPlayer@ this, Vertex[] &v_raw, uint16[][] &tileData)
{
	CMap@ map = getMap();
	v_raw.clear();
	v_i.clear();

	if(map is null || tileData.size() == 0)
	{
		return;
	}

	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,0),getUVY(blockIndex,0),SColor(0x00aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,1),getUVY(blockIndex,1),SColor(0x00aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,2),getUVY(blockIndex,2),SColor(0x00aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,3),getUVY(blockIndex,3),SColor(0x00aacdff)));
	v_i.push_back(0);
	v_i.push_back(1);
	v_i.push_back(2);
	v_i.push_back(0);
	v_i.push_back(2);
	v_i.push_back(3);

	int width = Maths::Min(map.tilemapwidth, tileData.size());
	int height = map.tilemapheight;
	int quadCount = 0;
	for(int y = 0; y < height; y++)
	{
		for(int x = 0; x < width; x++)
		{
			if(y >= tileData[x].size())
			{
				continue;
			}

			if(tileData[x][y] == 0)
			{
				continue;
			}

			if(quadCount >= MAX_BLUEPRINT_QUADS)
			{
				print("Blueprint renderer reached the mesh quad limit. Some blueprint blocks were skipped.");
				return;
			}

			AddBlueprintQuad(v_raw, v_i, x, y, tileData[x][y]);
			quadCount++;
		}
	}
}

void initVertexAray(Vertex[] &v_raw, u16[] &v_i)
{
	// Kept as a compatibility stub. Blueprint quads are now generated sparsely in updateVertex().
}

float offsetx = 8/pngWidth;
float offsety = 8/pngHeight;
u16 AIB_RenderAtlasBlock(uint16 blockID)
{
	const u16 id = AIBP_BlockId(blockID);
	if(id == AIBP_BRIDGE) return AIBP_EncodeBlock(180, AIBP_BlockRotation(blockID));
	if(id == AIBP_SPIKES) return AIBP_EncodeBlock(57, AIBP_BlockRotation(blockID));
	return blockID;
}

float getUVX(uint16 blockID, uint16 vertexNumber)
{
	blockID = AIB_RenderAtlasBlock(blockID);
	if(AIBP_IsWorkshopBlock(blockID)) blockID = AIBP_EncodeBlock(AIBP_BUILDER_SHOP, AIBP_BlockRotation(blockID));
	const u16 id = AIBP_BlockId(blockID);
	float ModuloCalc = (((blockID << 2) >> 2) % (pngWidth/8))/(pngWidth/8) ;//the << and >> operator remove the rotation bits from the blockID.
	uint16 uvxCurrentRotation = AIBP_BlockRotation(blockID);
	float ultraoffsetx = 0;
	blockID = (blockID << 2) >> 2;
	if(id == AIBP_BUILDER_SHOP)
	{
		ultraoffsetx = offsetx*4;
	}
	if(id == AIBP_LADDER)
	{
		ultraoffsetx= offsetx*2/8;
	}
	vertexNumber += uvxCurrentRotation;
	if(vertexNumber > 3)
	{
		vertexNumber -= 4;
	}
	//vertex number position : 0 = upper left, 1 = upper right, 2 = bottom right, 3 = bottom left
	if(vertexNumber == 0)
	{
		return ModuloCalc;
	}
	else if(vertexNumber == 1)
	{
		return ModuloCalc + offsetx + ultraoffsetx;
	}
	else if(vertexNumber == 2)
	{
		return ModuloCalc + offsetx + ultraoffsetx;
	}
	else
	{
		return ModuloCalc;
	}
}

float getUVY(uint16 blockID, uint16 vertexNumber)
{
	blockID = AIB_RenderAtlasBlock(blockID);
	if(AIBP_IsWorkshopBlock(blockID)) blockID = AIBP_EncodeBlock(AIBP_BUILDER_SHOP, AIBP_BlockRotation(blockID));
	const u16 id = AIBP_BlockId(blockID);

	float ModuloCalc = (int(((blockID << 2)>> 2) / (pngWidth/8)) / (pngHeight/8)); //the << and >> operator remove the rotation bits from the blockID.
	uint16 uvyCurrentRotation = AIBP_BlockRotation(blockID);
	float ultraoffsety = 0;
	blockID = (blockID << 2) >> 2;
	if(id == AIBP_BUILDER_SHOP || id == AIBP_LADDER)
	{
		ultraoffsety = offsety*2;
	}
	if(id == AIBP_SPIKES)
	{
		ultraoffsety = offsety*3/8;
	}
	vertexNumber += uvyCurrentRotation;
	if(vertexNumber > 3)
	{
		vertexNumber -= 4;
	}
	if(vertexNumber == 0)
	{
		return ModuloCalc;
	}
	else if(vertexNumber == 1)
	{
		return ModuloCalc;
	}
	else if(vertexNumber == 2)
	{
		return ModuloCalc + offsety + ultraoffsety;
	}
	else
	{
		return ModuloCalc + offsety + ultraoffsety;
	}
}

int getSizeX(uint16 blockID)
{
	const u16 id = AIBP_BlockId(blockID);
	const u8 rotation = AIBP_BlockRotation(blockID);
	if(AIBP_IsWorkshopBlock(blockID))
	{
		return 20;
	}
	if(id == AIBP_LADDER)
	{
		return (rotation & 1) == 0 ? 5 : 12;
	}
	return x_size;
}
int getSizeY(uint16 blockID)
{
	const u16 id = AIBP_BlockId(blockID);
	const u8 rotation = AIBP_BlockRotation(blockID);
	if(AIBP_IsWorkshopBlock(blockID))
	{
		return 12;
	}
	if(id == AIBP_LADDER)
	{
		return (rotation & 1) == 0 ? 12 : 5;
	}
	if(id == AIBP_SPIKES)
	{
		return 4;
	}
	return y_size;
}
void setVertexMatrix(uint16[][] &position, Vertex[] &v_raw, int x, int y)
{
	f32 z = 1000;

	CMap@ map = getMap();
	uint64 ind = 4 + (x * 4 + y * (map.tilemapwidth-1)*4 + y * 4);
	print("size : " + v_raw.size());
	print("ind : " + ind);
	print("x : " + x);
	print("y : " + y);
	print("width : " + map.tilemapwidth);
	print("height : " + map.tilemapheight);
	v_raw[ind] =	(Vertex(x*8+4 - getSizeX(position[x][y]), y*8+4 - getSizeY(position[x][y]), z, getUVX(position[x][y],0),getUVY(position[x][y],0),SColor(0x70aacdff)));
	v_raw[ind+1] = 	(Vertex(x*8+4 + getSizeX(position[x][y]), y*8+4 - getSizeY(position[x][y]), z, getUVX(position[x][y],1),getUVY(position[x][y],1),SColor(0x70aacdff)));
	v_raw[ind+2] = 	(Vertex(x*8+4 + getSizeX(position[x][y]), y*8+4 + getSizeY(position[x][y]), z, getUVX(position[x][y],2),getUVY(position[x][y],2),SColor(0x70aacdff)));
	v_raw[ind+3] = 	(Vertex(x*8+4 - getSizeX(position[x][y]), y*8+4 + getSizeY(position[x][y]), z, getUVX(position[x][y],3),getUVY(position[x][y],3),SColor(0x70aacdff)));
}

void unsetVertexMatrix(uint16[][] &position, Vertex[] &v_raw, int x, int y)
{
	f32 z = 1000;

	CMap@ map = getMap();
	int ind = 4 + (x * 4 + y * map.tilemapwidth); 

	v_raw[ind] = 	(Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(position[x][y],0),getUVY(position[x][y],0),SColor(0x00aacdff)));
	v_raw[ind+1] = 	(Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(position[x][y],1),getUVY(position[x][y],1),SColor(0x00aacdff)));
	v_raw[ind+2] = 	(Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(position[x][y],2),getUVY(position[x][y],2),SColor(0x00aacdff)));
	v_raw[ind+3] = 	(Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(position[x][y],3),getUVY(position[x][y],3),SColor(0x00aacdff)));
}

void RenderAdvancedGui(int id)
{
	RenderAIBuilderResourceCounters();
	RenderAIBStrategyStatus();
	RenderBlueprintToolbar();
	RenderBlueprintCatalogPanel();

	if(toggleBlueprint && displayPrefabSelectionMenu)
	{
		inv.Render();
	}

	RenderTreeSelectionButton();
	RenderStoneSelectionButton();
	RenderBlueprintAdvancedPanel();
	RenderOverseerView();
}

void RenderAIBStrategyStatus()
{
	CPlayer@ player = getLocalPlayer();
	CRules@ rules = getRules();
	if (player is null || rules is null || player.getTeamNum() >= 100) return;
	const u8 team = u8(player.getTeamNum());
	const u8 mode = rules.get_u8(AIBP_ModeKey(team));
	const bool directorEnabled = AIBP_IsDirectorEnabled(mode);
	const u16 plan = rules.get_u16(AIBP_PlanKey(team, "id"));
	const string templateName = rules.get_string(AIBP_PlanKey(team, "template"));
	const f32 score = rules.get_f32(AIBP_PlanKey(team, "score"));
	const string reasons = rules.get_string(AIBP_PlanKey(team, "reasons"));
	const u16 pending = rules.get_u16(AIBP_PlanKey(team, "pending"));
	const u16 completed = rules.get_u16(AIBP_PlanKey(team, "completed"));
	const u16 damaged = rules.get_u16(AIBP_PlanKey(team, "damaged"));
	Vec2f min = AIB_DirectorPanelMin();
	Vec2f max = min + Vec2f(430, 66);
	GUI::DrawRectangle(min, max, SColor(0xdd101820));
	const SColor statusColor = directorEnabled ? SColor(0xff70e090) : SColor(0xffffa070);
	GUI::DrawText("Director AI: " + (directorEnabled ? "ON" : "OFF"), min + Vec2f(8, 6), statusColor);

	const bool canToggle = AIB_LocalCanToggleDirector();
	CControls@ controls = getControls();
	const bool hover = canToggle && controls !is null && AIB_MouseInDirectorToggle(controls.getMouseScreenPos());
	Vec2f buttonMin = AIB_DirectorToggleMin();
	Vec2f buttonMax = buttonMin + Vec2f(92, 22);
	SColor buttonFill = canToggle ? SColor(0xff283844) : SColor(0xaa202830);
	if(aibDirectorTogglePressed) buttonFill = SColor(0xff505050);
	else if(hover) buttonFill = SColor(0xff3e5868);
	GUI::DrawRectangle(buttonMin, buttonMax, SColor(0xff080808));
	GUI::DrawRectangle(buttonMin + Vec2f(1, 1), buttonMax - Vec2f(1, 1), buttonFill);
	GUI::DrawTextCentered(directorEnabled ? "Turn off" : "Turn on", (buttonMin + buttonMax) / 2.0f,
		canToggle ? SColor(0xffffffff) : SColor(0xff888888));

	if(directorEnabled)
	{
		if(plan == 0)
		{
			GUI::DrawText("Planning and assigning builders...", min + Vec2f(8, 27), SColor(0xffb8d8ee));
		}
		else
		{
			GUI::DrawText(templateName + "  score " + formatFloat(score, "", 0, 1) + "  tasks " + completed + "/" +
				(completed + pending) + (damaged > 0 ? " damaged " + damaged : ""), min + Vec2f(8, 27), SColor(0xffffffff));
			GUI::DrawText(reasons, min + Vec2f(8, 46), SColor(0xffb8d8ee));
		}
	}
	else if(mode == AIBP_StrategyMode::suggest)
	{
		GUI::DrawText("Suggestion mode only; automatic builder orders are off.", min + Vec2f(8, 27), SColor(0xffe0c070));
	}
	else
	{
		GUI::DrawText("Automatic planning and builder assignment are disabled.", min + Vec2f(8, 27), SColor(0xffb8d8ee));
	}
}

void RenderBlueprintToolbar()
{
	if(!AIB_LocalCanUseBlueprintControls())
	{
		return;
	}

	CControls@ controls = getControls();
	Vec2f mouse = controls is null ? Vec2f_zero : controls.getMouseScreenPos();
	for(u8 i = 0; i < BLUEPRINT_TOOL_COUNT; i++)
	{
		Vec2f min = AIB_ToolButtonMin(i);
		Vec2f max = min + Vec2f(92, 24);
		bool hover = controls !is null && AIB_MouseInToolButton(i, mouse);
		bool selected = blueprintEditorActive && (i == blueprintEditorTool) &&
			(i == BLUEPRINT_TOOL_PAINT || i == BLUEPRINT_TOOL_ERASE || i == BLUEPRINT_TOOL_SELECT);

		SColor fill = SColor(0xdd202020);
		if(blueprintToolbarButtonPressed && blueprintToolbarPressedTool == i)
		{
			fill = SColor(0xff505050);
		}
		else if(selected)
		{
			fill = SColor(0xff2f6f8f);
		}
		else if(hover)
		{
			fill = SColor(0xff3a3a3a);
		}

		GUI::DrawRectangle(min, max, SColor(0xff080808));
		GUI::DrawRectangle(min + Vec2f(1, 1), max - Vec2f(1, 1), fill);
		GUI::DrawTextCentered(AIB_ToolLabel(i), (min + max) / 2.0f, SColor(0xffffffff));
	}

	Vec2f statusMin = AIB_ToolButtonMin(BLUEPRINT_TOOL_COUNT) + Vec2f(0, 4);
	Vec2f statusMax = statusMin + Vec2f(92, 24);
	GUI::DrawRectangle(statusMin, statusMax, blueprintEditorActive ? SColor(0xdd14331d) : SColor(0xdd331414));
	GUI::DrawTextCentered(blueprintEditorActive ? "Editor on" : "Editor off", (statusMin + statusMax) / 2.0f, SColor(0xffffffff));
	Vec2f blockMin = statusMin + Vec2f(0, 28);
	Vec2f blockMax = blockMin + Vec2f(160, 38);
	GUI::DrawRectangle(blockMin, blockMax, SColor(0xdd202020));
	GUI::DrawText(AIBP_BlockDisplayName(blockIndex), blockMin + Vec2f(5, 3), SColor(0xffffffff));
	GUI::DrawText(AIBP_BlockMaterial(blockIndex) + " " + AIBP_BlockCost(blockIndex) + "  rot " + AIBP_BlockRotation(blockIndex), blockMin + Vec2f(5, 20), SColor(0xffb8d8ee));
}

void RenderBlueprintCatalogPanel()
{
	if(!AIB_BlueprintCatalogPanelVisible()) return;

	CControls@ controls = getControls();
	Vec2f mouse = controls is null ? Vec2f_zero : controls.getMouseScreenPos();
	Vec2f min = AIB_BlueprintCatalogPanelMin();
	Vec2f max = min + Vec2f(456, 198);
	GUI::DrawRectangle(min, max, SColor(0x66121212));

	for(u8 i = 0; i < AIB_CATALOG_TAB_COUNT; i++)
	{
		Vec2f tabMin = AIB_BlueprintCatalogTabMin(i);
		Vec2f tabMax = tabMin + Vec2f(90, 24);
		SColor fill = i == blueprintCatalogTab ? SColor(0xaa2f6f8f) : SColor(0x77202020);
		if(blueprintCatalogTabButtonPressed && blueprintCatalogTabPressed == i) fill = SColor(0xbb505050);
		else if(controls !is null && AIB_MouseInBlueprintCatalogTab(i, mouse) && i != blueprintCatalogTab) fill = SColor(0x88404040);
		GUI::DrawRectangle(tabMin, tabMax, fill);
		GUI::DrawTextCentered(AIB_BlueprintCatalogTabLabel(i), (tabMin + tabMax) / 2.0f, SColor(0xffffffff));
	}

	const u16 count = AIB_BlueprintCatalogCount(blueprintCatalogTab);
	for(u16 i = 0; i < count; i++)
	{
		const u16 catalogBlock = AIB_BlueprintCatalogBlockAt(blueprintCatalogTab, i);
		Vec2f cellMin = AIB_BlueprintCatalogCellMin(i);
		Vec2f cellMax = cellMin + Vec2f(104, 44);
		const bool selected = AIBP_BlockId(blockIndex) == AIBP_BlockId(catalogBlock);
		const bool hover = controls !is null && AIB_MouseInBlueprintCatalogCell(i, mouse);
		SColor fill = selected ? SColor(0xaa2f6f8f) : SColor(0x77202020);
		if(blueprintCatalogPanelButtonPressed && blueprintCatalogPanelPressedBlock == catalogBlock) fill = SColor(0xbb505050);
		else if(hover && !selected) fill = SColor(0x88404040);
		GUI::DrawRectangle(cellMin, cellMax, fill);
		if(AIB_BlueprintCatalogUsesAtlasPreview(catalogBlock))
		{
			GUI::DrawRectangle(cellMin + Vec2f(4, 5), cellMin + Vec2f(22, 23), SColor(0x88202020));
			GUI::DrawIcon("REEE.png", AIB_BlueprintCatalogAtlasFrame(catalogBlock), Vec2f(8, 8), cellMin + Vec2f(5, 6), 2.0f);
		}
		else
		{
			GUI::DrawRectangle(cellMin + Vec2f(4, 5), cellMin + Vec2f(22, 23), AIB_BlueprintCatalogSwatch(catalogBlock));
		}
		GUI::DrawText(AIB_BlueprintCatalogShortName(catalogBlock), cellMin + Vec2f(28, 4), SColor(0xffffffff));
		GUI::DrawText("" + AIBP_BlockCost(catalogBlock) + " " + (AIBP_BlockMaterial(catalogBlock) == "mat_stone" ? "stone" : "wood"),
			cellMin + Vec2f(6, 25), SColor(0xffb8d8ee));
	}
}

Vec2f AIB_BlueprintAdvancedPanelMin()
{
	Vec2f screen = getDriver().getScreenDimensions();
	return Vec2f(screen.x - 372, 66);
}

Vec2f AIB_BlueprintAdvancedTabMin(const u8 tab)
{
	return AIB_BlueprintAdvancedPanelMin() + Vec2f(6, 6 + tab * 28);
}

bool AIB_MouseInBlueprintAdvancedTab(const u8 tab, Vec2f mouse)
{
	Vec2f min = AIB_BlueprintAdvancedTabMin(tab);
	Vec2f max = min + Vec2f(116, 24);
	return mouse.x >= min.x && mouse.x <= max.x && mouse.y >= min.y && mouse.y <= max.y;
}

bool UpdateBlueprintAdvancedPanel()
{
	if(!AIB_LocalCanUseBlueprintControls() || !displayPrefabSelectionMenu)
	{
		blueprintAdvancedButtonPressed = false;
		blueprintAdvancedPressedTab = 255;
		return false;
	}

	CControls@ controls = getControls();
	if(controls is null) return false;
	Vec2f mouse = controls.getMouseScreenPos();
	u8 hovered = 255;
	for(u8 i = 0; i < 5; i++)
	{
		if(AIB_MouseInBlueprintAdvancedTab(i, mouse))
		{
			hovered = i;
			break;
		}
	}

	if(hovered != 255 && controls.isKeyJustPressed(KEY_LBUTTON))
	{
		blueprintAdvancedButtonPressed = true;
		blueprintAdvancedPressedTab = hovered;
		return true;
	}
	if(blueprintAdvancedButtonPressed && !controls.isKeyPressed(KEY_LBUTTON))
	{
		if(hovered == blueprintAdvancedPressedTab) blueprintAdvancedTab = hovered;
		blueprintAdvancedButtonPressed = false;
		blueprintAdvancedPressedTab = 255;
		return true;
	}

	Vec2f panelMin = AIB_BlueprintAdvancedPanelMin();
	Vec2f panelMax = panelMin + Vec2f(360, 158);
	const bool inPanel = mouse.x >= panelMin.x && mouse.x <= panelMax.x && mouse.y >= panelMin.y && mouse.y <= panelMax.y;
	return inPanel && controls.isKeyPressed(KEY_LBUTTON);
}

string AIB_BlueprintAdvancedTabLabel(const u8 tab)
{
	if(tab == 0) return "Blueprint";
	if(tab == 1) return "Team plan";
	if(tab == 2) return "Preview checks";
	if(tab == 3) return "Material summary";
	return "AI build queue";
}

u16 AIB_CountDisplayedBlueprintTiles()
{
	u16 count = 0;
	for(uint x = 0; x < dynamicMapTileData.length; x++)
	{
		for(uint y = 0; y < dynamicMapTileData[x].length; y++)
		{
			if(dynamicMapTileData[x][y] != 0 && count < 65535) count++;
		}
	}
	return count;
}

u16 AIB_CountTeamStoredMaterial(const u8 team, const string &in material)
{
	u32 count = 0;
	string[] names = { "tent", "hall", "crate", "buildershop", "aibuilder" };
	for(uint n = 0; n < names.length; n++)
	{
		CBlob@[] blobs;
		getBlobsByName(names[n], @blobs);
		for(uint i = 0; i < blobs.length; i++)
		{
			CBlob@ blob = blobs[i];
			if(blob is null || blob.hasTag("dead") || blob.getTeamNum() != team) continue;
			CInventory@ inventory = blob.getInventory();
			if(inventory !is null) count += inventory.getCount(material);
		}
	}
	return u16(Maths::Min(count, 65535));
}

void AIB_BlueprintMaterialCosts(u32 &out wood, u32 &out stone)
{
	wood = 0;
	stone = 0;
	for(uint x = 0; x < dynamicMapTileData.length; x++)
	{
		for(uint y = 0; y < dynamicMapTileData[x].length; y++)
		{
			const u16 block = dynamicMapTileData[x][y];
			const string material = AIBP_BlockMaterial(block);
			if(material == "mat_wood") wood += AIBP_BlockCost(block);
			else if(material == "mat_stone") stone += AIBP_BlockCost(block);
		}
	}
}

string AIB_PlanStatusLabel(const u8 status)
{
	if(status == 1) return "active";
	if(status == 2) return "completed";
	if(status == 3) return "replaced";
	return "none";
}

void AIB_DrawAdvancedLine(Vec2f contentMin, const u8 line, const string &in text, const SColor color = SColor(0xffd8d8d8))
{
	GUI::DrawText(text, contentMin + Vec2f(0, line * 20), color);
}

void RenderBlueprintAdvancedPanel()
{
	if(!AIB_LocalCanUseBlueprintControls() || !displayPrefabSelectionMenu)
	{
		return;
	}

	Vec2f min = AIB_BlueprintAdvancedPanelMin();
	Vec2f max = min + Vec2f(360, 158);
	GUI::DrawRectangle(min, max, SColor(0xdd151515));
	CControls@ controls = getControls();
	Vec2f mouse = controls is null ? Vec2f_zero : controls.getMouseScreenPos();
	for(u8 i = 0; i < 5; i++)
	{
		Vec2f tabMin = AIB_BlueprintAdvancedTabMin(i);
		Vec2f tabMax = tabMin + Vec2f(116, 24);
		SColor fill = i == blueprintAdvancedTab ? SColor(0xff2f6f8f) : SColor(0xdd252525);
		if(blueprintAdvancedButtonPressed && blueprintAdvancedPressedTab == i) fill = SColor(0xff505050);
		else if(AIB_MouseInBlueprintAdvancedTab(i, mouse) && i != blueprintAdvancedTab) fill = SColor(0xff3a3a3a);
		GUI::DrawRectangle(tabMin, tabMax, fill);
		GUI::DrawTextCentered(AIB_BlueprintAdvancedTabLabel(i), (tabMin + tabMax) / 2.0f, SColor(0xffffffff));
	}

	CPlayer@ player = getLocalPlayer();
	CRules@ rules = getRules();
	if(player is null || rules is null) return;
	const u8 team = u8(player.getTeamNum());
	Vec2f content = min + Vec2f(132, 10);
	if(blueprintAdvancedTab == 0)
	{
		AIB_DrawAdvancedLine(content, 0, AIBP_BlockDisplayName(blockIndex), SColor(0xffffffff));
		AIB_DrawAdvancedLine(content, 1, "Tool: " + (blueprintEditorActive ? AIB_ToolLabel(blueprintEditorTool) : "off"));
		AIB_DrawAdvancedLine(content, 2, "Visible tiles: " + AIB_CountDisplayedBlueprintTiles());
		AIB_DrawAdvancedLine(content, 3, "Team version: " + rules.get_u16(AIBP_PlanKey(team, "human version")));
		AIB_DrawAdvancedLine(content, 4, displayLoadedBlueprint ? "Prefab: " + currentBlueprintWidth + " x " + currentBlueprintHeight : "Prefab: none loaded");
		AIB_DrawAdvancedLine(content, 5, toggleBlueprint ? "Layer: visible" : "Layer: hidden");
	}
	else if(blueprintAdvancedTab == 1)
	{
		const u16 plan = rules.get_u16(AIBP_PlanKey(team, "id"));
		const u8 mode = rules.get_u8(AIBP_ModeKey(team));
		AIB_DrawAdvancedLine(content, 0, "Plan #" + plan + "  v" + rules.get_u16(AIBP_PlanKey(team, "version")), SColor(0xffffffff));
		AIB_DrawAdvancedLine(content, 1, "Mode: " + (mode == AIBP_StrategyMode::off ? "off" : (mode == AIBP_StrategyMode::suggest ? "suggest" : "auto")));
		AIB_DrawAdvancedLine(content, 2, "Status: " + AIB_PlanStatusLabel(rules.get_u8(AIBP_PlanKey(team, "status"))));
		AIB_DrawAdvancedLine(content, 3, "Template: " + (plan == 0 ? "none" : rules.get_string(AIBP_PlanKey(team, "template"))));
		AIB_DrawAdvancedLine(content, 4, "Done " + rules.get_u16(AIBP_PlanKey(team, "completed")) + "  pending " + rules.get_u16(AIBP_PlanKey(team, "pending")));
		AIB_DrawAdvancedLine(content, 5, "Damaged: " + rules.get_u16(AIBP_PlanKey(team, "damaged")));
	}
	else if(blueprintAdvancedTab == 2)
	{
		CMap@ map = getMap();
		Vec2f world = controls is null ? Vec2f_zero : controls.getMouseWorldPos();
		const int x = Maths::Floor(world.x / 8.0f);
		const int y = Maths::Floor(world.y / 8.0f);
		const bool inBounds = map !is null && x >= 0 && y >= 0 && x < map.tilemapwidth && y < map.tilemapheight;
		AIB_DrawAdvancedLine(content, 0, "Cursor tile: " + x + ", " + y, SColor(0xffffffff));
		AIB_DrawAdvancedLine(content, 1, inBounds ? "Map bounds: pass" : "Map bounds: blocked", inBounds ? SColor(0xff8fe68f) : SColor(0xffff8888));
		const bool noBuild = inBounds && map.getSectorAtPosition(Vec2f(x * 8 + 4, y * 8 + 4), "no build") !is null;
		AIB_DrawAdvancedLine(content, 2, noBuild ? "No-build sector: blocked" : "No-build sector: pass", noBuild ? SColor(0xffff8888) : SColor(0xff8fe68f));
		const bool occupied = inBounds && map.isTileSolid(map.getTile(Vec2f(x * 8 + 4, y * 8 + 4)).type);
		AIB_DrawAdvancedLine(content, 3, occupied ? "Terrain: occupied" : "Terrain: clear", occupied ? SColor(0xffffcc77) : SColor(0xff8fe68f));
		const bool hasBlueprint = inBounds && x < int(dynamicMapTileData.length) && y < int(dynamicMapTileData[x].length) && dynamicMapTileData[x][y] != 0;
		AIB_DrawAdvancedLine(content, 4, hasBlueprint ? "Blueprint tile: occupied" : "Blueprint tile: clear");
		AIB_DrawAdvancedLine(content, 5, displayLoadedBlueprint ? "Prefab footprint: previewing" : "Prefab footprint: none");
	}
	else if(blueprintAdvancedTab == 3)
	{
		u32 wood = 0; u32 stone = 0;
		AIB_BlueprintMaterialCosts(wood, stone);
		const u16 storedWood = AIB_CountTeamStoredMaterial(team, "mat_wood");
		const u16 storedStone = AIB_CountTeamStoredMaterial(team, "mat_stone");
		const bool infiniteBuilder = AIB_TeamHasAutoBuilder(team);
		AIB_DrawAdvancedLine(content, 0, "Blueprint cost", SColor(0xffffffff));
		AIB_DrawAdvancedLine(content, 1, "Wood: " + wood + "  stored " + storedWood);
		AIB_DrawAdvancedLine(content, 2, "Stone: " + stone + "  stored " + storedStone);
		AIB_DrawAdvancedLine(content, 3, infiniteBuilder ? "Wood shortage: ignored by Autobuilder" :
			"Wood shortage: " + (wood > storedWood ? wood - storedWood : 0));
		AIB_DrawAdvancedLine(content, 4, infiniteBuilder ? "Stone shortage: ignored by Autobuilder" :
			"Stone shortage: " + (stone > storedStone ? stone - storedStone : 0));
	}
	else
	{
		u16 builders = 0; u16 building = 0; u16 reserved = 0;
		CBlob@[] aiBuilders;
		AIB_GetConstructionWorkers(aiBuilders);
		for(uint i = 0; i < aiBuilders.length; i++)
		{
			CBlob@ builder = aiBuilders[i];
			if(builder is null || builder.hasTag("dead") || builder.getTeamNum() != team) continue;
			builders++;
			const u8 state = builder.get_u8("ai builder state");
			if(state == 12 || state == 13 || state == 14) building++;
			if(builder.get_netid("ai builder target") != 0) reserved++;
		}
		AIB_DrawAdvancedLine(content, 0, "Team builders: " + builders, SColor(0xffffffff));
		AIB_DrawAdvancedLine(content, 1, "Building: " + building);
		AIB_DrawAdvancedLine(content, 2, "With target: " + reserved);
		AIB_DrawAdvancedLine(content, 3, "Queued tasks: " + rules.get_u16(AIBP_PlanKey(team, "pending")));
		AIB_DrawAdvancedLine(content, 4, "Completed: " + rules.get_u16(AIBP_PlanKey(team, "completed")));
		AIB_DrawAdvancedLine(content, 5, "Damaged: " + rules.get_u16(AIBP_PlanKey(team, "damaged")));
	}
}

bool AIB_TeamHasAutoBuilder(const u8 team)
{
	CBlob@[] builders;
	getBlobsByName("autobuilder", @builders);
	for(uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if(builder !is null && !builder.hasTag("dead") && builder.getTeamNum() == team) return true;
	}
	return false;
}

string AIB_OverseerOrderLabel(const u8 order)
{
	if(order == AIB_OVERSEER_ORDER_WOOD) return "Harvest wood";
	if(order == AIB_OVERSEER_ORDER_STONE) return "Mine stone";
	if(order == AIB_OVERSEER_ORDER_BLUEPRINT) return "Build blueprint";
	return "";
}

void RenderOverseerView()
{
	if(!overseerViewActive)
	{
		return;
	}

	Vec2f panelMin = AIB_OverseerPanelHeaderMin();
	Vec2f panelMax = panelMin + Vec2f(154, 28);
	GUI::DrawRectangle(panelMin, panelMax, SColor(0xdd151515));
	GUI::DrawTextCentered("AI selected: " + overseerSelectedBuilders.length, (panelMin + panelMax) / 2.0f, SColor(0xffffffff));

	CControls@ controls = getControls();
	Vec2f mouse = controls is null ? Vec2f_zero : controls.getMouseScreenPos();
	for(u8 i = 0; i < 3; i++)
	{
		Vec2f min = AIB_OverseerOrderButtonMin(i);
		Vec2f max = min + Vec2f(154, 28);
		bool hover = controls !is null && AIB_MouseInOverseerOrderButton(i, mouse);
		SColor fill = SColor(0xdd202020);
		if(overseerOrderButtonPressed && overseerPressedOrder == i)
		{
			fill = SColor(0xff505050);
		}
		else if(hover)
		{
			fill = SColor(0xff3a3a3a);
		}
		if(overseerSelectedBuilders.length == 0)
		{
			fill = SColor(0xaa202020);
		}

		GUI::DrawRectangle(min, max, SColor(0xff080808));
		GUI::DrawRectangle(min + Vec2f(1, 1), max - Vec2f(1, 1), fill);
		GUI::DrawTextCentered(AIB_OverseerOrderLabel(i), (min + max) / 2.0f, SColor(0xffffffff));
	}
}

void RenderAIBuilderResourceCounters()
{
	u16 woodBuilders = 0;
	u16 stoneBuilders = 0;
	u16 blueprintBuilders = 0;

	CBlob@[] builders;
	AIB_GetConstructionWorkers(builders);
	for(uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if(builder is null || builder.hasTag("dead")) continue;
		if(builder.get_u8("ai builder state") == AIB_RENDERER_STATE_IDLE) continue;

		const u8 job = builder.get_u8("ai builder job");
		if(job == AIB_RENDERER_JOB_WOOD)
		{
			woodBuilders++;
		}
		else if(job == AIB_RENDERER_JOB_STONE)
		{
			stoneBuilders++;
		}
		else if(job == AIB_RENDERER_JOB_BLUEPRINT)
		{
			blueprintBuilders++;
		}
	}

	Vec2f screen = getDriver().getScreenDimensions();
	const f32 counterWidth = 58.0f;
	const f32 counterGap = 10.0f;
	const f32 totalWidth = counterWidth * 3.0f + counterGap * 2.0f;
	const f32 mapUiReserve = 174.0f;
	Vec2f pos = Vec2f(Maths::Max(4.0f, screen.x - mapUiReserve - totalWidth - 12.0f), 8);
	pos = RenderAIBuilderResourceCounter(pos, "$mat_wood$", woodBuilders);
	pos = RenderAIBuilderResourceCounter(pos + Vec2f(counterGap, 0), "$mat_stone$", stoneBuilders);
	RenderAIBuilderResourceCounter(pos + Vec2f(counterGap, 0), "$BUILDER$", blueprintBuilders);
}

Vec2f RenderAIBuilderResourceCounter(Vec2f pos, const string &in iconToken, const u16 count)
{
	Vec2f min = pos;
	Vec2f max = pos + Vec2f(58, 24);
	GUI::DrawRectangle(min, max, SColor(0xaa101010));
	GUI::DrawIconByName(iconToken, pos + Vec2f(4, 4));
	GUI::DrawText("" + count, pos + Vec2f(26, 5), SColor(0xffffffff));
	return Vec2f(max.x, pos.y);
}

void RenderTreeSelectionButton()
{
	if(!AIB_LocalCanUseBlueprintControls())
	{
		return;
	}
	if(!displayPrefabSelectionMenu)
	{
		return;
	}

	CControls@ controls = getControls();
	if(controls is null)
	{
		return;
	}

	Vec2f min = aibTreeButtonPosition;
	Vec2f max = min + Vec2f(178, 28);
	Vec2f mouse = controls.getMouseScreenPos();
	bool hover = AIB_MouseInTreeButton(mouse);

	SColor fill = SColor(0xffdadada);
	if(aibTreeButtonPressed)
	{
		fill = SColor(0xff666666);
	}
	else if(hover)
	{
		fill = SColor(0xff8a8a8a);
	}
	SColor border = SColor(0xff202020);
	GUI::DrawRectangle(min, max, border);
	GUI::DrawRectangle(min + Vec2f(1, 1), max - Vec2f(1, 1), fill);

	GUI::DrawTextCentered(aibTreeSelectMode ? "Confirm trees selection" : "Select trees", (min + max) / 2.0f, SColor(0xff101010));
}

void RenderStoneSelectionButton()
{
	if(!AIB_LocalCanUseBlueprintControls())
	{
		return;
	}
	if(!displayPrefabSelectionMenu)
	{
		return;
	}

	CControls@ controls = getControls();
	if(controls is null)
	{
		return;
	}

	Vec2f min = aibStoneButtonPosition;
	Vec2f max = min + Vec2f(178, 28);
	Vec2f mouse = controls.getMouseScreenPos();
	bool hover = AIB_MouseInStoneButton(mouse);

	SColor fill = SColor(0xffdadada);
	if(aibStoneButtonPressed)
	{
		fill = SColor(0xff666666);
	}
	else if(hover)
	{
		fill = SColor(0xff8a8a8a);
	}
	SColor border = SColor(0xff202020);
	GUI::DrawRectangle(min, max, border);
	GUI::DrawRectangle(min + Vec2f(1, 1), max - Vec2f(1, 1), fill);

	GUI::DrawTextCentered(aibStoneSelectMode ? "Confirm stone selection" : "Select stone to mine", (min + max) / 2.0f, SColor(0xff101010));
}


//////////////////////////////////////LOADING AND SAVING IMPLEMENTATION SECTION BEGIN HERE/////////////////////////////////////////////////
CFileImage@ save_image;
void SaveBlueprintToPng(CRules@ this)
{
	u16 x1;
	u16 y1;
	u16 x2;
	u16 y2;
	if(!AIB_NormalizeSelectionRect(x1, y1, x2, y2))
	{
		print("couldn't save blueprint : selection is outside the map");
		keyOJustPressed = false;
		return;
	}

	int startingXPosition = x1;
	int endingXPosition = x2;
	int startingYPosition = y1;
	int endingYPosition = y2;
	int width = endingXPosition - startingXPosition + 1;
	int height = endingYPosition - startingYPosition + 1;
	@save_image = CFileImage(width, height, true);
	int currentTime = Time();
	string blueprintPath = "Maps/DynamicBlueprints/blueprint_" + currentTime + ".png";
	save_image.setFilename("DynamicBlueprints/blueprint_" + currentTime + ".png", ImageFileBase::IMAGE_FILENAME_BASE_MAPS);
	save_image.setPixelOffset(0);

	if(startingXPosition >= 0 && startingYPosition >= 0 && endingXPosition >= 0 && endingYPosition >= 0)
	{
		RuntimeBlueprint@ runtimeBlueprint = RuntimeBlueprint(blueprintPath, width, height);
		for (int yp = startingYPosition; yp < endingYPosition+1; yp++)
		{
			for(int xp = startingXPosition; xp < endingXPosition+1; xp++)
			{
				Vec2f pixelpos = save_image.getPixelPosition();
				uint16 blockData = dynamicMapTileData[xp][yp];
				SColor pixelColor = getColorFromBlockID(blockData);
				int imageX = xp - startingXPosition;
				int imageY = yp - startingYPosition;
				save_image.setPixelAtPosition(imageX, imageY, pixelColor, false);
				if(runtimeBlueprint !is null &&
					imageX >= 0 && imageX < runtimeBlueprint.width &&
					imageY >= 0 && imageY < runtimeBlueprint.height)
				{
					runtimeBlueprint.data[imageX][imageY] = blockData;
				}
			}
		}
		save_image.Save();
		print("image saved.");
		StoreRuntimeBlueprint(runtimeBlueprint);
		filenames.push_back(blueprintPath);
		inv.resizeGUI(filenames);
	}
	else
	{
		print("couldn't save blueprint : selection positions are invalid");
	}
	keyOJustPressed = false;
}

uint16[][] currentBlueprintData;
int OButtonSelect = 0;
int16 currentBlueprintWidth = 0;
int16 currentBlueprintHeight = 0;

void StoreRuntimeBlueprint(RuntimeBlueprint@ blueprint)
{
	if(blueprint is null || blueprint.path == "")
	{
		return;
	}

	for(uint i = 0; i < runtimeBlueprints.length; i++)
	{
		if(runtimeBlueprints[i] !is null && runtimeBlueprints[i].path == blueprint.path)
		{
			@runtimeBlueprints[i] = blueprint;
			return;
		}
	}

	runtimeBlueprints.push_back(blueprint);
}

RuntimeBlueprint@ GetRuntimeBlueprint(const string &in imagePath)
{
	for(uint i = 0; i < runtimeBlueprints.length; i++)
	{
		RuntimeBlueprint@ blueprint = runtimeBlueprints[i];
		if(blueprint !is null && blueprint.path == imagePath)
		{
			return blueprint;
		}
	}

	return null;
}

bool LoadBlueprintFromMemory(const string &in imagePath)
{
	RuntimeBlueprint@ blueprint = GetRuntimeBlueprint(imagePath);
	if(blueprint is null)
	{
		return false;
	}

	currentBlueprintWidth = blueprint.width;
	currentBlueprintHeight = blueprint.height;
	uint16[][] _currentBlueprintData(currentBlueprintWidth, uint16[](currentBlueprintHeight, 0));
	currentBlueprintData = _currentBlueprintData;

	for(int x = 0; x < currentBlueprintWidth; x++)
	{
		for(int y = 0; y < currentBlueprintHeight; y++)
		{
			currentBlueprintData[x][y] = blueprint.data[x][y];
		}
	}

	deepCopyArray();
	displayLoadedBlueprint = true;
	triggerAPrefabLoad = false;
	print("loaded runtime blueprint " + imagePath);
	return true;
}

void LoadBlueprintFromPng(CRules@ this, string imagePath)
{
	if(LoadBlueprintFromMemory(imagePath))
	{
		return;
	}

	@save_image = CFileImage(imagePath);
	bool done = false;
	bool proceed = false;
	if (save_image.isLoaded())
	{
		proceed = true;
	}
	else
	{
		@save_image = CFileImage("../Cache/"+imagePath.substr(23));
		print("HERE'S THE SUBSTRINGS : " + "../Cache/"+imagePath.substr(23));
		if(save_image.isLoaded())
		{
			proceed = true;
		}
	}
	if (proceed)
	{
		currentBlueprintWidth = save_image.getWidth();
		currentBlueprintHeight = save_image.getHeight();
		save_image.setPixelOffset(-1);
		uint16[][] _currentBlueprintData(currentBlueprintWidth, uint16[](currentBlueprintHeight, 0));
		currentBlueprintData = _currentBlueprintData;
		u8 a;
		u8 r;
		u8 g;
		u8 b;
		while(save_image.nextPixel() && !done)
		{
			if(save_image.readPixel(a, r, g, b)) ///the argument given are the output of the function
			{
				//r contain the block id and b contain the rotation data
				currentBlueprintData[save_image.getPixelPosition().x][save_image.getPixelPosition().y] = AIBP_EncodeBlock(uint16(r), b);
				//only the red part of the image is used to store something.
                //Therefore only retrieve the red value is retrieved.
			}
			else
			{
				print("an error occured while reading a pixel from a blueprint png");
			}
		}
		deepCopyArray();
		displayLoadedBlueprint = true;
	}
	else
	{
		print("couldn't load blueprint");
	}
	triggerAPrefabLoad = false;
}

bool displayLoadedBlueprint = false;
uint16[][] networkBlueprintData;

u16 AIB_FlipBlueprintBlockHorizontal(const u16 block)
{
	const u16 id = AIBP_BlockId(block);
	u8 rotation = AIBP_BlockRotation(block);
	if(rotation == 1) rotation = 3;
	else if(rotation == 3) rotation = 1;
	return AIBP_EncodeBlock(id, rotation);
}

void LoadBlueprintDataToMapTileDataFromNetwork(int16 indexX, int16 indexY, int16 bpWidth, int16 bpHeight)
{
	CMap@ map = getMap();
	if(map is null) return;

	const int startingx = indexX - Maths::Ceil(float(bpWidth) / 2.0f);
	const int startingy = indexY - Maths::Ceil(float(bpHeight) / 2.0f);
	for(int ybp = 0; ybp < bpHeight; ybp++)
	{
		for(int xbp = 0; xbp < bpWidth; xbp++)
		{
			const int xp = startingx + xbp;
			const int yp = startingy + ybp;
			if(xp < 0 || yp < 0 || xp >= map.tilemapwidth || yp >= map.tilemapheight) continue;
			dynamicMapTileData[xp][yp] = networkBlueprintData[xbp][ybp];
		}
	}
	blueprintMeshDirty = true;
}

bool flipBlueprint = false;
void LoadBlueprintDataToMapTileData(int16 indexX = -1, int16 indexY = -1)
{
	CControls@ c = getControls();
	if(c != null && currentBlueprintData.size() > 0)
	{
		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		if(indexX == -1 || indexY == -1 )
		{
			indexX = (currentPlacementPosition.x-4)/8;
			indexY = (currentPlacementPosition.y-4)/8;
			dynamicMapTileData = tileMapDataCopy;
		}
		CMap@ map = getMap();
		if(map is null) return;
		const int startingx = indexX - Maths::Ceil(float(currentBlueprintWidth) / 2.0f);
		const int startingy = indexY - Maths::Ceil(float(currentBlueprintHeight) / 2.0f);
		if(flipBlueprint) // if it's true, we flip the blueprint on the y axis
		{
			for(int ybp = 0; ybp < currentBlueprintHeight; ybp++)
			{
				for(int xbp = 0; xbp < currentBlueprintWidth; xbp++)
				{
					const int xp = startingx + xbp;
					const int yp = startingy + ybp;
					const int flippedX = startingx + (currentBlueprintWidth - 1 - xbp);
					if(flippedX < 0 || yp < 0 || flippedX >= map.tilemapwidth || yp >= map.tilemapheight) continue;

					dynamicMapTileData[flippedX][yp] = AIB_FlipBlueprintBlockHorizontal(currentBlueprintData[xbp][ybp]);
				}
			}
		}
		else
		{
			for(int ybp = 0; ybp < currentBlueprintHeight; ybp++)
			{
				for(int xbp = 0; xbp < currentBlueprintWidth; xbp++)
				{
					const int xp = startingx + xbp;
					const int yp = startingy + ybp;
					if(xp < 0 || yp < 0 || xp >= map.tilemapwidth || yp >= map.tilemapheight) continue;
					dynamicMapTileData[xp][yp] = currentBlueprintData[xbp][ybp];
				}
			}
		}
		blueprintMeshDirty = true;
	}
}

uint16[][] tileMapDataCopy;
void deepCopyArray()
{
	CMap@ map = getMap();
	tileMapDataCopy = dynamicMapTileData; // this should do a shallow copy according to angelscript's documentation but it doesn't ¯\_(ツ)_/¯
}

SColor getColorFromBlockID(u16 blockID) 
{
	uint16 currentRotation = AIBP_BlockRotation(blockID);
	blockID = AIBP_CanonicalId(blockID);
	// 48 = stone, 64 = stone backwall, 196 = wood, 205 = wood backwall
	// 3 = stone door, 6 = wooden doors, 7 = trap, 8 = ladder, 9 = platform, 10 = workshop, 11 = spike
	if(blockID == 0)
	{
		return SColor(0,0,0,0);
	}
	if(blockID == AIBP_STONE_BLOCK)
	{
		return SColor(255,1,0,currentRotation);
	}
	if(blockID == AIBP_STONE_BACKWALL)
	{
		return SColor(255,2,0,currentRotation);
	}
	if(blockID == AIBP_WOOD_BLOCK)
	{
		return SColor(255,4,0,currentRotation);
	}
	if(blockID == AIBP_WOOD_BACKWALL)
	{
		return SColor(255,5,0,currentRotation);
	}
	return SColor(255,blockID,0,currentRotation);
}

//Overseer GAMEMODE RELATED FUNCTIONS
bool isOverseer = false;

bool mapFitBlueprint()
{	
	CMap@ map = getMap();

	for( int y = 0; y < map.tilemapheight; y++ ) 
		{
			for(int x = 0; x < map.tilemapwidth; x++)
			{
				uint16 tileType = map.getTile(Vec2f((x*8)+4,(y*8)+4)).type;
				if(tileType == 48 || tileType == 64 || tileType == 196 || tileType == 205)
				{
					if(tileType == 48)
					{
						tileType = 1;
					}
					else if(tileType == 64)
					{
						tileType = 2;
					}
					else if(tileType == 196)
					{
						tileType = 4;
					}
					else if (tileType == 205)
					{
						tileType = 5;
					}
				}
				if(dynamicMapTileData[x][y] == 1 || dynamicMapTileData[x][y] == 2 || dynamicMapTileData[x][y] == 4 || dynamicMapTileData[x][y] == 5)
				{
					if(tileType != dynamicMapTileData[x][y])
					{
						print("tiletype : " + tileType);
						print("target pos : " + Vec2f((x*8)+4,(y*8)+4));
						print("mouse pos : " + getControls().getMouseWorldPos());
						print("dynamicMapTileData[x][y] : " + dynamicMapTileData[x][y]);
						print("REACHED FALSE");
						return false;
					}
				}
			}
		}
	print("REACHED TRUE");
	return true;
}
