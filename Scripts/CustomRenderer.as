#include "Inventory.as"
#include "Item.as"

///those next 2 global variable are the only thing you can modify without breaking anything if you understand what they do.
//you have to set the image size of the texture used for the tiles mesh.
float pngWidth = 128.0f;
float pngHeight = 256.0f;

const string REEEPPNG = "REEE";//stand for "Relevent Environnement for Enhancing Effectiveness [of rendering]" 

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
bool keyOJustPressed = false;
bool triggerAPrefabLoad = false;
bool displayPrefabSelectionMenu = false;

array<string> filenames;

void onInit(CRules@ this)
{
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
		Texture::createFromFile(REEEPPNG,"/Sprites/REEE.png");
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


}

void onRestart(CRules@ this)
{
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
}


//toggle through each render type to give a working example of each call
int oldBlockIndex = -1;
bool antiVoid = false;
void onTick(CRules@ this)
{

	if(isClient())
	{	string selectedBlueprint = "";
		if(toggleBlueprint && displayPrefabSelectionMenu)
		{
			selectedBlueprint = inv.Update();
			if( selectedBlueprint != "")
			{		
				print("Loading " + selectedBlueprint);
				displayPrefabSelectionMenu = false;
				triggerAPrefabLoad = true;
				displayMouseSelect = false;
			}
		}

		CBlob@ playerBlob = getLocalPlayerBlob();
		ChangeIfNeeded();
		blockIndex = GiveBlockIndex(playerBlob);
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

int last_changed = 0;
bool toggleBlueprint = true;
Vec2f currentPlacementPosition;
uint16 customMenuTurn;
array<Vec2f> mouseSelect = {Vec2f(1.0f,1.0f),Vec2f(3.0f,3.0f)};
bool displayMouseSelect = false;
void ChangeIfNeeded()
{
	CControls@ c = getControls();
	if (c is null) return;
	CPlayer@ playerBlob = getLocalPlayer();

	if(c.isKeyJustPressed(KEY_KEY_H)) //activate or deactivate mesh rendering
	{
		toggleBlueprint = !toggleBlueprint;
	}

	if(c.isKeyJustPressed(KEY_KEY_O))//load a png
	{
		displayMouseSelect = false;
		keyOJustPressed = true;
		print("saving blueprint...");
	}
	if(c.isKeyPressed(KEY_KEY_X))
	{
		displayPrefabSelectionMenu = true;
		inv.setPosition(c.getMouseScreenPos());
	}
	if(c.isKeyJustPressed(KEY_KEY_L))
	{
		displayPrefabSelectionMenu = !displayPrefabSelectionMenu;
		print("Prefabs blueprint windows state changed");
	}
	if(c.isKeyJustPressed(KEY_RBUTTON) || c.isKeyJustPressed(KEY_CANCEL))
	{
		displayMouseSelect = false;
		if(displayLoadedBlueprint == true)
		{
			dynamicMapTileData = tileMapDataCopy;
			displayLoadedBlueprint = false;
			currentBlueprintData.clear();
		}
	}

	if(c.isKeyJustPressed(KEY_LBUTTON) && displayLoadedBlueprint == true)
	{
		displayLoadedBlueprint = false; // if the player selected a blueprint and pressed left click, then we send the blueprint to everybody

		CBitStream params;

		uint16 id = playerBlob.getNetworkID();

		Vec2f temp = c.getMouseWorldPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8; 

		params.write_u16(id);
		params.write_u16(currentBlueprintWidth);
		params.write_u16(currentBlueprintHeight);
		params.write_u16(indexX);
		params.write_u16(indexY);


		for(int y = 0; y < currentBlueprintHeight; y++)// iterate through all the element of the current blueprint and send it 
		{
			for(int x = 0; x < currentBlueprintWidth; x++) 
			{
				params.write_u16(currentBlueprintData[x][y]);
			}
		}
		getRules().SendCommand(getRules().getCommandID("sendBlueprint"), params);
	}

	if(c.isKeyJustPressed(KEY_KEY_I))
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
	if(c.isKeyJustPressed(KEY_KEY_P))
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
	if (c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL))
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
					CBitStream params;
					params.write_u16(indexX);
					params.write_u16(indexY);
					params.write_u16(blockIndex);
					getRules().SendCommand(getRules().getCommandID("addBlocks"), params);
				}
			}
			else if (c.isKeyPressed(c.getActionKeyKey(AK_ACTION2))  && (c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL)) && dynamicMapTileData[indexX][indexY] != 0)
			{				
				CBitStream params;
				params.write_u16(indexX);
				params.write_u16(indexY);
				getRules().SendCommand(getRules().getCommandID("removeBlocks"), params);
			}
		}
		if(c.isKeyJustPressed(KEY_KEY_U))
		{
			customMenuTurn += 1;
			if(customMenuTurn > 11)
			{
				customMenuTurn = 1;
			}
		}
		else if(c.isKeyJustPressed(KEY_KEY_R))
		{
			customMenuTurn -= 1;
			customMenuTurn = customMenuTurn % 12;
			if(customMenuTurn <= 0)
			{
				customMenuTurn = 11;
			}
		}
	}

	if(c.isKeyJustPressed(KEY_SPACE))
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
}



void onCommand(CRules@ this, u8 cmd, CBitStream @params)
{
    if(cmd == this.getCommandID("addBlocks") && dynamicMapTileData.size() > 0)
    {
        uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		uint16 receivedBlockIndex = params.read_u16();
		
		dynamicMapTileData[positionx][positiony] = receivedBlockIndex;
		/*if(isClient())
		{
			setVertexMatrix(dynamicMapTileData, v_raw, positionx, positiony);
		}*/
		
    }
	if(cmd == this.getCommandID("removeBlocks") && dynamicMapTileData.size() > 0)
	{
		uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		
		dynamicMapTileData[positionx][positiony] = 0;
		/*if(isClient())
		{
			unsetVertexMatrix(dynamicMapTileData, v_raw, positionx, positiony);
		}*/

	}
	if(!isClient() && cmd == this.getCommandID("getAllBlocks") && dynamicMapTileData.size() > 0)
	{
		uint16 netID = params.read_u16();
		CMap@ map = getMap();
		CBitStream insideparams;
		insideparams.write_u16(netID);
		for( int y = 0; y < map.tilemapheight; y++ ) 
		{
			for(int x = 0; x < map.tilemapwidth; x++)
			{
					insideparams.write_u16(dynamicMapTileData[x][y]);
			}
		}
		getRules().SendCommand(getRules().getCommandID("giveAllBlocks"), insideparams);
	}
	if(isClient() && cmd == this.getCommandID("giveAllBlocks"))
	{
		CMap@ map = getMap();
		uint16 netID = params.read_u16();
		if(getLocalPlayer().getNetworkID() == netID)
		{
			for( int y = 0; y < map.tilemapheight; y++ )
			{
				for(int x = 0; x < map.tilemapwidth; x++)
				{
					dynamicMapTileData[x][y] = params.read_u16();
					//setVertexMatrix(dynamicMapTileData, v_raw, x, y);
				}
			}
		}
	}
	if(cmd == this.getCommandID("sendBlueprint") && dynamicMapTileData.size() > 0)
	{
		uint16 netID = params.read_u16();
		CPlayer@ playerBlob = getLocalPlayer();
		bool condition = false;
		if(playerBlob == null)
		{
			condition = true;
		}
		else if(playerBlob.getNetworkID() != netID)// we don't modify the data to the player that just sent it
		{
			condition = true;
		}
		if(condition) 
		{
			uint16 bpWidth = params.read_u16();
			uint16 bpHeight = params.read_u16();
			uint16 indx = params.read_u16();
			uint16 indy = params.read_u16();
			uint16[][] _networkBlueprintData(bpWidth, uint16[](bpHeight, 0));
			networkBlueprintData = _networkBlueprintData;
			for(int y = 0; y < bpHeight; y++)// iterate through all the element of the current blueprint and send it 
			{
				for(int x = 0; x < bpWidth; x++) 
				{
					networkBlueprintData[x][y] = params.read_u16();
				}
			}
			LoadBlueprintDataToMapTileDataFromNetwork(indx,indy,bpWidth,bpHeight);
		}
	}
}


bool resetRotation = false;
uint16 GiveBlockIndex(CBlob@ this)
{
	if(this == null)
	{
		resetRotation = true;
		return customMenuTurn | (currentRotation << 14); // we use the last 2 bits of the uint16 to specify rotation.
	}
	uint16 tileType = uint16(this.get_TileType("buildtile")); //48 = stone, 64 = stone backwall, 196 = wood, 205 = wood backwall
	uint16 tileBlob = this.get_u8("buildblob"); // 2 = stone door, 5 = wooden doors, 6 = trap, 7 = ladder, 8 = platform, 9 = workshop, 10 = spike
	if(this.getName() != "builder")
	{
		resetRotation = true;
		return customMenuTurn | (currentRotation << 14);
	}
	if(resetRotation == true)
	{
		currentRotation = 0;
		resetRotation = false;
	}
	print("current Page : " + this.get_u8("build page"));
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
		return tileType;
	}
	else if (tileBlob == 2 || tileBlob == 5 || tileBlob == 6 || tileBlob == 7 || tileBlob == 8 || tileBlob == 9 || tileBlob == 10)
	{
		return tileBlob + 1 | (currentRotation << 14);
	}
	else
	{
		return 1;
	}
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
	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,2),getUVY(blockIndex,2), 	SColor(0x70aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, getUVX(blockIndex,3),getUVY(blockIndex,3), 	SColor(0x70aacdff)));
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
		
	initVertexAray(v_raw, v_i);
}
int updateOptimisation = 0;


void RenderWidgetFor(CPlayer@ this)
{
	Render::SetTransformWorldspace();
	//ensure that there's no null pointer. there will always be something in the array
	if(v_raw.size() <= 4)
	{
		resetTrigger = true;
	}
	if(resetTrigger)
	{
		initRender(true);
		resetTrigger = false;
		if (this != null && justJoined)
		{
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
	if(c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL))
	{
		toggleBlueprint = true;
		v_raw[0] = (Vertex(p.x - x_size, p.y - y_size, 1000, getUVX(blockIndex,0),getUVY(blockIndex,0),SColor(0x70aacdff)));
		v_raw[1] = (Vertex(p.x + x_size, p.y - y_size, 1000, getUVX(blockIndex,1),getUVY(blockIndex,1),SColor(0x70aacdff)));
		v_raw[2] = (Vertex(p.x + x_size, p.y + y_size, 1000, getUVX(blockIndex,2),getUVY(blockIndex,2),SColor(0x70aacdff)));
		v_raw[3] = (Vertex(p.x - x_size, p.y + y_size, 1000, getUVX(blockIndex,3),getUVY(blockIndex,3),SColor(0x70aacdff)));
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
		v_vertexNonTile[0] = Vertex(centerx 	- x_size, centery - y_size, 	z, getUVX(10,0), getUVY(10,0), 	SColor(0x30aacdff)); //upper left
		v_vertexNonTile[1] = Vertex(centerx + 4 + x_size, centery - y_size, 	z, getUVX(10,1), getUVY(10,1), 	SColor(0x30aacdff)); //upper right
		v_vertexNonTile[2] = Vertex(centerx + 4 + x_size, centery + y_size + 4, z, getUVX(10,2), getUVY(10,2), 	SColor(0x30aacdff)); //bottom right
		v_vertexNonTile[3] = Vertex(centerx 	- x_size, centery + y_size + 4, z, getUVX(10,3), getUVY(10,3), 	SColor(0x30aacdff)); //bottom left
	}
	else
	{
		v_vertexNonTile[0] = (Vertex(p.x - x_size, p.y - y_size, 1000, getUVX(blockIndex,0), getUVY(blockIndex,0), 	SColor(0x00aacdff)));
		v_vertexNonTile[1] = (Vertex(p.x + x_size, p.y - y_size, 1000, getUVX(blockIndex,1), getUVY(blockIndex,1), 	SColor(0x00aacdff)));
		v_vertexNonTile[2] = (Vertex(p.x + x_size, p.y + y_size, 1000, getUVX(blockIndex,2), getUVY(blockIndex,2), 	SColor(0x00aacdff)));
		v_vertexNonTile[3] = (Vertex(p.x - x_size, p.y + y_size, 1000, getUVX(blockIndex,3), getUVY(blockIndex,3), 	SColor(0x00aacdff)));
	}

	if(toggleBlueprint)
	{
		if(updateOptimisation == 0)
		{
			updateVertex(this, v_raw, dynamicMapTileData);
		}
		updateOptimisation += 1;
		if(updateOptimisation >= 5)
		{
			updateOptimisation = 0;
		}
		everythingMesh.SetVertex(v_raw);
		everythingMesh.SetIndices(v_i); 
		everythingMesh.BuildMesh();
		everythingMesh.SetDirty(SMesh::VERTEX_INDEX);
		everythingMesh.RenderMeshWithMaterial();
		nonTileMesh.SetVertex(v_vertexNonTile);
		nonTileMesh.SetIndices(v_indexNonTile); 
		nonTileMesh.BuildMesh();
		nonTileMesh.SetDirty(SMesh::VERTEX_INDEX);
		nonTileMesh.RenderMeshWithMaterial();
	}

}
int xRenderLimit = 37;
int yRenderLimit = 21;
int renderingState = 0; //0 = render relative to camera position, 1 = render relative to player position
void updateVertex(CPlayer@ this, Vertex[] &v_raw, uint16[][] &tileData)
{
	CMap@ map = getMap();
	Vec2f blobPosition;
	CControls@ c = getControls();
	if(renderingState == 1 && c != null)
	{
		blobPosition = c.getMouseWorldPos();
	}
	else
	{
		blobPosition = getCamera().getPosition();
	}
	int startingx = (blobPosition.x)/8 - xRenderLimit;
	int startingy = (blobPosition.y)/8 - yRenderLimit;
	int xConstraint = (blobPosition.x)/8 + xRenderLimit;
	int yConstraint = (blobPosition.y)/8 + yRenderLimit;

	if (startingx < 0)
	{
		startingx = 0;
	}
	if (startingy < 0)
	{
		startingy = 0;
	}
	f32 z = 1000;

	int index = 4;
	for(int y = startingy; y < map.tilemapheight && y < yConstraint; y++) 
	{
		for(int x = startingx; x < map.tilemapwidth && x < xConstraint; x++)
		{
			if(tileData[x][y] != 0)
			{
				v_raw[index]   = Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(tileData[x][y],0),getUVY(tileData[x][y],0),SColor(0x70aacdff));
				v_raw[index+1] = Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(tileData[x][y],1),getUVY(tileData[x][y],1),SColor(0x70aacdff));
				v_raw[index+2] = Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(tileData[x][y],2),getUVY(tileData[x][y],2),SColor(0x70aacdff));
				v_raw[index+3] = Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(tileData[x][y],3),getUVY(tileData[x][y],3),SColor(0x70aacdff));
			}
			else
			{
				v_raw[index]   = Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff));
				v_raw[index+1] = Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff));
				v_raw[index+2] = Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff));
				v_raw[index+3] = Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff));
			}
			index += 4;
		}
	}
}

void initVertexAray(Vertex[] &v_raw, u16[] &v_i)
{
	CMap@ map = getMap();
	int index = v_i[v_i.size()-1] + 1;
	for(int i = 0; i < xRenderLimit*yRenderLimit*4; i++)
	{
		v_raw.push_back(Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff)));
		v_raw.push_back(Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff)));
		v_raw.push_back(Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff)));
		v_raw.push_back(Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff)));
		v_i.push_back(index);
		v_i.push_back(index+1);
		v_i.push_back(index+2);
		v_i.push_back(index);
		v_i.push_back(index+2);
		v_i.push_back(index+3);
		index += 4;
	}
}

float offsetx = 8/pngWidth;
float offsety = 8/pngHeight;
uint16 oldBlockID = 0;
float oldModuloCalc = 0;
uint16 uvxCurrentRotation = 0;
float getUVX(uint16 blockID, int vertexNumber)
{
	if(oldBlockID != blockID)//prevent from doing unecessary calculation.
	{
		oldBlockID = blockID;
		oldModuloCalc = (((blockID % (pngWidth/8))/(pngWidth/8)) << 2 ) >> 2;//the << and >> operator remove the rotation bits from the answer.
		uvxCurrentRotation = blockID >> 14; // retrieve the 2 rotation bit from blockID
	}
	vertexNumber += uvxCurrentRotation;
	if(vertexNumber > 3)
	{
		vertexNumber -= 4;
	}
	//vertex number position : 0 = upper left, 1 = upper right, 2 = bottom right, 3 = bottom left
	if(vertexNumber == 0)
	{
		return oldModuloCalc;
	}
	else if(vertexNumber == 1)
	{
		return oldModuloCalc + offsetx;
	}
	else if(vertexNumber == 2)
	{
		return oldModuloCalc + offsetx;
	}
	else
	{
		return oldModuloCalc;
	}
}
uint16 oldBlockID2 = 0;
float oldModuloCalc2 = 0;
uint16 uvyCurrentRotation = 0;
float getUVY(int blockID, int vertexNumber)
{
	if(oldBlockID != blockID)//prevent from doing unecessary calculation.
	{
		oldBlockID2 = blockID;
		oldModuloCalc2 = ((int(blockID / (pngWidth/8)) / (pngHeight/8)) << 2) >> 2; //the << and >> operator remove the rotation bits from the answer.
		uvyCurrentRotation = blockID >> 14; // retrieve the 2 rotation bit from blockID
	}
	vertexNumber += uvyCurrentRotation;
	if(vertexNumber > 3)
	{
		vertexNumber -= 4;
	}
	if(vertexNumber == 0)
	{
		return oldModuloCalc2;
	}
	else if(vertexNumber == 1)
	{
		return oldModuloCalc2;
	}
	else if(vertexNumber == 2)
	{
		return oldModuloCalc2 + offsety;
	}
	else
	{
		return oldModuloCalc2 + offsety;
	}
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
	v_raw[ind] =	(Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(position[x][y],0),getUVY(position[x][y],0),SColor(0x70aacdff)));
	v_raw[ind+1] = 	(Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(position[x][y],1),getUVY(position[x][y],1),SColor(0x70aacdff)));
	v_raw[ind+2] = 	(Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(position[x][y],2),getUVY(position[x][y],2),SColor(0x70aacdff)));
	v_raw[ind+3] = 	(Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(position[x][y],3),getUVY(position[x][y],3),SColor(0x70aacdff)));
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
	if(toggleBlueprint && displayPrefabSelectionMenu)
	{
		inv.Render();
	}
}


//////////////////////////////////////LOADING AND SAVING IMPLEMENTATION SECTION BEGIN HERE/////////////////////////////////////////////////
CFileImage@ save_image;
void SaveBlueprintToPng(CRules@ this)
{
	int startingXPosition = 0;
	int endingXPosition = 10;
	int startingYPosition = 0;
	int endingYPosition = 10;
	if(mouseSelect[0].x == mouseSelect[1].x || mouseSelect[0].y == mouseSelect[1].y)
	{
		mouseSelect[0] = Vec2f(1,1);
		mouseSelect[1] = Vec2f(5,5);
	}
	if(mouseSelect[0].x > mouseSelect[1].x)
	{
		startingXPosition = mouseSelect[1].x;
		endingXPosition = mouseSelect[0].x;
	}
	else
	{
		startingXPosition = mouseSelect[0].x;
		endingXPosition = mouseSelect[1].x;
	}

	if(mouseSelect[0].y > mouseSelect[1].y)
	{
		startingYPosition = mouseSelect[1].y;
		endingYPosition = mouseSelect[0].y;
	}
	else
	{
		startingYPosition = mouseSelect[0].y;
		endingYPosition = mouseSelect[1].y;
	}
	int width = Maths::Abs(mouseSelect[0].x-mouseSelect[1].x);
	int height =  Maths::Abs(mouseSelect[0].y-mouseSelect[1].y);
	@save_image = CFileImage(width, height, true);
	int currentTime = Time();
	save_image.setFilename("DynamicBlueprints/blueprint_" + currentTime + ".png", ImageFileBase::IMAGE_FILENAME_BASE_MAPS);
	save_image.setPixelOffset(0);

	if(startingXPosition >= 0 && startingYPosition >= 0 && endingXPosition >= 0 && endingYPosition >= 0)
	{
		for (int yp = startingYPosition; yp < endingYPosition+1; yp++)
		{
			for(int xp = startingXPosition; xp < endingXPosition+1; xp++)
			{
				Vec2f pixelpos = save_image.getPixelPosition();
				SColor pixelColor = getColorFromBlockID(dynamicMapTileData[xp][yp]);
				uint p = pixelColor.getRed();
				if(p != dynamicMapTileData[xp][yp])
				{
					print("pixelColor : " + p);
					print("map data : " + dynamicMapTileData[xp][yp]);
				}
				save_image.setPixelAtPosition(width - (endingXPosition - xp), height - (endingYPosition - yp), pixelColor, false);
			}
		}
		save_image.Save();
		print("image saved.");
		filenames.push_back("Maps/DynamicBlueprints/blueprint_" + currentTime + ".png");
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
void LoadBlueprintFromPng(CRules@ this, string imagePath)
{
	@save_image = CFileImage(imagePath);
	bool done = false;

	if (save_image.isLoaded())
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
				currentBlueprintData[save_image.getPixelPosition().x][save_image.getPixelPosition().y] = r;
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
void LoadBlueprintDataToMapTileDataFromNetwork(int16 indexX, int16 indexY, int16 bpWidth, int16 bpHeight)
{
	uint16 startingx = indexX - Maths::Ceil(float(bpWidth)/2.0f);
	uint16 startingy = indexY - Maths::Ceil(float(bpHeight)/2.0f);
	uint16 endingx = indexX + int(bpWidth/2);
	uint16 endingy = indexY + int(bpHeight/2);
	if(startingx < 0)
	{
		startingx = 0;
	}
	if(startingy < 0)
	{
		startingy = 0;
	}
	CMap@ map = getMap();
	if(endingx >= map.tilemapwidth)
	{
		endingx = map.tilemapwidth;
	}
	if(endingy >= map.tilemapheight)
	{
		endingy = map.tilemapheight;
	}
	int xbp = 0;
	int ybp = 0;
	for(int yp = startingy; yp < endingy; yp++)
	{
		for(int xp = startingx; xp < endingx; xp++)
		{
			dynamicMapTileData[xp][yp] = networkBlueprintData[xbp][ybp];
			xbp += 1;
		}
		xbp = 0;
		ybp += 1;
	}
}

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
		uint16 startingx = indexX - Maths::Ceil(float(currentBlueprintWidth)/2.0f);
		uint16 startingy = indexY - Maths::Ceil(float(currentBlueprintHeight)/2.0f);
		uint16 endingx = indexX + int(currentBlueprintWidth/2);
		uint16 endingy = indexY + int(currentBlueprintHeight/2);
		if(startingx < 0)
		{
			startingx = 0;
		}
		if(startingy < 0)
		{
			startingy = 0;
		}
		CMap@ map = getMap();
		if(endingx >= map.tilemapwidth)
		{
			endingx = map.tilemapwidth;
		}
		if(endingy >= map.tilemapheight)
		{
			endingy = map.tilemapheight;
		}
		int xbp = 0;
		int ybp = 0;
		for(int yp = startingy; yp < endingy; yp++)
		{
			for(int xp = startingx; xp < endingx; xp++)
			{
				dynamicMapTileData[xp][yp] = currentBlueprintData[xbp][ybp];
				xbp += 1;
			}
			xbp = 0;
			ybp += 1;
		}
	}
}

uint16[][] tileMapDataCopy;
void deepCopyArray()
{
	CMap@ map = getMap();
	tileMapDataCopy = dynamicMapTileData; // this should do a shallow copy according to angelscript's documentation but it doesn't ¯\_(ツ)_/¯
}

SColor getColorFromBlockID(u8 blockID) 
{
	// 48 = stone, 64 = stone backwall, 196 = wood, 205 = wood backwall
	// 3 = stone door, 6 = wooden doors, 7 = trap, 8 = ladder, 9 = platform, 10 = workshop, 11 = spike
	if(blockID == 48 || blockID == 1)
	{
		return SColor(255,1,0,0);
	}
	if(blockID == 64 || blockID == 2)
	{
		return SColor(255,2,0,0);
	}
	if(blockID == 196 || blockID == 4)
	{
		return SColor(255,4,0,0);
	}
	if(blockID == 205 || blockID == 5)
	{
		return SColor(255,5,0,0);
	}
	if(blockID >= 3 && blockID <= 11)
	{
		return SColor(255,blockID,0,0);
	}
	return SColor(0,0,0,0);
}