//This code has been started from the ScriptRenderExample.as script
uint8[][] dynamicMapTileData;


const string REEEPPNG = "REEE";//stand for "Relevent Environnement for Enhancing Effectiveness [of rendering]" 
SMesh@ everythingMesh = SMesh();
SMaterial@ everythingMat = SMaterial();

float x_size;
float y_size;
uint8 blockIndex;
float pngWidth = 128.0f;
float pngHeight = 256.0f;
float x = (blockIndex % (pngWidth/8))/(pngWidth/8);
float y = int(blockIndex / (pngWidth/8)) / (pngHeight/8);
float offsetx = 8/pngWidth;
float offsety = 8/pngHeight;

bool justJoined = true;
bool keyOJustPressed = false;
bool keyLJustPressed = false;

void onInit(CRules@ this)
{
	currentBlueprintData.clear();
	resetTrigger = true;
	customMenuTurn = 1;
	x_size = 4;
	y_size = 4;
	blockIndex = 48;
	/*getDriver().ForceStartShaders();
	getDriver().AddShader("customShader");
	getDriver().SetShader("customShader", true);
	getDriver().SetShader('hq2x', false);*/
	if(isClient())
	{
		int cb_id = Render::addScript(Render::layer_objects, "CustomRenderer.as", "RulesRenderFunction", 0.0f);
		Setup();
	}
	this.addCommandID("addBlocks");
	this.addCommandID("removeBlocks");
	this.addCommandID("getAllBlocks");
	this.addCommandID("giveAllBlocks");
	this.addCommandID("sendBlueprint");
	CMap@ map = getMap();
	uint8[][] _dynamicMapTileData(map.tilemapwidth, uint8[](map.tilemapheight, 0));
	dynamicMapTileData = _dynamicMapTileData;
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
		everythingMesh.SetHardwareMapping(SMesh::STATIC); //maybe MAP::STATIC instead
	}


}

void onRestart(CRules@ this)
{
	dynamicMapTileData.clear();
	currentBlueprintData.clear();
	networkBlueprintData.clear();
	CMap@ map = getMap();
	uint8[][] _dynamicMapTileData(map.tilemapwidth, uint8[](map.tilemapheight, 0));
	dynamicMapTileData = _dynamicMapTileData;
	if(isClient())
	{
		Setup();
	}
	resetTrigger = true;
}


//toggle through each render type to give a working example of each call
int oldBlockIndex = -1;

void onTick(CRules@ this)
{

	if(isClient())
	{	
		CBlob@ playerBlob = getLocalPlayerBlob();
		ChangeIfNeeded();
		blockIndex = GiveBlockIndex(playerBlob);
		if (blockIndex != oldBlockIndex)
		{
			oldBlockIndex = blockIndex;
			x = (blockIndex % (pngWidth/8))/(pngWidth/8);
			y = int(blockIndex / (pngWidth/8)) / (pngHeight/8);
		}
		if(keyOJustPressed)
		{
			SaveBlueprintToPng(this);
		}
		if(keyLJustPressed)
		{
			LoadBlueprintFromPng(this);
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
int customMenuTurn;
array<Vec2f> mouseSelect(2,Vec2f(0.0f,0.0f));
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
		keyOJustPressed = true;
		print("saving blueprint...");
	}

	if(c.isKeyJustPressed(KEY_KEY_L))
	{
		keyLJustPressed = true;
		print("loading blueprint...");
	}
	if(c.isKeyJustPressed(KEY_RBUTTON) || c.isKeyJustPressed(KEY_CANCEL))
	{
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
				params.write_u8(currentBlueprintData[x][y]);
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
					params.write_u8(blockIndex);
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
}



void onCommand(CRules@ this, u8 cmd, CBitStream @params)
{
    if(cmd == this.getCommandID("addBlocks") && dynamicMapTileData.size() > 0)
    {
        uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		uint8 receivedBlockIndex = params.read_u8();
		
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
					insideparams.write_u8(dynamicMapTileData[x][y]);
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
					dynamicMapTileData[x][y] = params.read_u8();
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
			uint8[][] _networkBlueprintData(bpWidth, uint8[](bpHeight, 0));
			networkBlueprintData = _networkBlueprintData;
			for(int y = 0; y < bpHeight; y++)// iterate through all the element of the current blueprint and send it 
			{
				for(int x = 0; x < bpWidth; x++) 
				{
					networkBlueprintData[x][y] = params.read_u8();
				}
			}
			LoadBlueprintDataToMapTileDataFromNetwork(indx,indy,bpWidth,bpHeight);
		}
	}
}



int GiveBlockIndex(CBlob@ this)
{
	if(this == null)
	{
		return customMenuTurn;
	}
	int tileType = this.get_TileType("buildtile"); //48 = stone, 64 = stone backwall, 196 = wood, 205 = wood backwall
	int tileBlob = this.get_u8("buildblob"); // 2 = stone door, 5 = wooden doors, 6 = trap, 7 = ladder, 8 = platform, 9 = workshop, 10 = spike
	if(this.getName() != "builder")
	{
		return customMenuTurn;
	}
	if(tileType == 48 || tileType == 64 || tileType == 196 || tileType == 205)
	{
		return tileType;
	}
	else if (tileBlob == 2 || tileBlob == 5 || tileBlob == 6 || tileBlob == 7 || tileBlob == 8 || tileBlob == 9 || tileBlob == 10)
	{
		return tileBlob + 1;
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
	Render::SetAlphaBlend(true);
	
	if(resetMapData)
	{
		CMap@ map = getMap();
		uint8[][] _dynamicMapTileData(map.tilemapwidth, uint8[](map.tilemapheight, 0));
		dynamicMapTileData = _dynamicMapTileData;
	}

	v_raw.push_back(Vertex(0, 0, 1000, x, 			y, 			SColor(0x70aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, x+offsetx, 	y, 			SColor(0x70aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, x+offsetx, 	y+offsety, 	SColor(0x70aacdff)));
	v_raw.push_back(Vertex(0, 0, 1000, x, 			y+offsety, 	SColor(0x70aacdff)));
	v_i.push_back(0);
	v_i.push_back(1);
	v_i.push_back(2);
	v_i.push_back(0);
	v_i.push_back(2);
	v_i.push_back(3);
		
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
		v_raw[0] = (Vertex(p.x - x_size, p.y - y_size, 1000, x, 			y, 			SColor(0x70aacdff)));
		v_raw[1] = (Vertex(p.x + x_size, p.y - y_size, 1000, x+offsetx, 	y, 			SColor(0x70aacdff)));
		v_raw[2] = (Vertex(p.x + x_size, p.y + y_size, 1000, x+offsetx, 	y+offsety, 	SColor(0x70aacdff)));
		v_raw[3] = (Vertex(p.x - x_size, p.y + y_size, 1000, x, 			y+offsety, 	SColor(0x70aacdff)));
	}
	else
	{
		v_raw[0] = (Vertex(p.x - x_size, p.y - y_size, 1000, x, 			y, 			SColor(0x00aacdff)));
		v_raw[1] = (Vertex(p.x + x_size, p.y - y_size, 1000, x+offsetx, 	y, 			SColor(0x00aacdff)));
		v_raw[2] = (Vertex(p.x + x_size, p.y + y_size, 1000, x+offsetx, 	y+offsety, 	SColor(0x00aacdff)));
		v_raw[3] = (Vertex(p.x - x_size, p.y + y_size, 1000, x, 			y+offsety, 	SColor(0x00aacdff)));
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
	}

}
int xRenderLimit = 37;
int yRenderLimit = 21;
int renderingState = 0; //0 = render relative to camera position, 1 = render relative to player position
void updateVertex(CPlayer@ this, Vertex[] &v_raw, uint8[][] &tileData)
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
				v_raw[index]   = Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(tileData[x][y]), 			getUVY(tileData[x][y]), 			SColor(0x70aacdff));
				v_raw[index+1] = Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(tileData[x][y])+offsetx, 	getUVY(tileData[x][y]), 			SColor(0x70aacdff));
				v_raw[index+2] = Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(tileData[x][y])+offsetx, 	getUVY(tileData[x][y])+offsety, 	SColor(0x70aacdff));
				v_raw[index+3] = Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(tileData[x][y]), 			getUVY(tileData[x][y])+offsety, 	SColor(0x70aacdff));
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

float getUVX(int blockID)
{
	return (blockID % (pngWidth/8))/(pngWidth/8);
}

float getUVY(int blockID)
{
	return int(blockID / (pngWidth/8)) / (pngHeight/8);
}

void setVertexMatrix(uint8[][] &position, Vertex[] &v_raw, int x, int y)
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
	v_raw[ind] = (Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y]), 			SColor(0x70aacdff)));
	v_raw[ind+1] = (Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y]), 			SColor(0x70aacdff)));
	v_raw[ind+2] = (Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y])+offsety, 	SColor(0x70aacdff)));
	v_raw[ind+3] = (Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y])+offsety, 	SColor(0x70aacdff)));
}

void unsetVertexMatrix(uint8[][] &position, Vertex[] &v_raw, int x, int y)
{
	f32 z = 1000;

	CMap@ map = getMap();
	int ind = 4 + (x * 4 + y * map.tilemapwidth); 

	v_raw[ind] = (Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y]), 			SColor(0x00aacdff)));
	v_raw[ind+1] = (Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y]), 			SColor(0x00aacdff)));
	v_raw[ind+2] = (Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y])+offsety, 	SColor(0x00aacdff)));
	v_raw[ind+3] = (Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y])+offsety, 	SColor(0x00aacdff)));
}










//////////////////////////////////////LOADING AND SAVING IMPLEMENTATION SECTION BEGIN HERE/////////////////////////////////////////////////
CFileImage@ save_image;
void SaveBlueprintToPng(CRules@ this)
{
	int startingXPosition = 0;
	int endingXPosition = 10;
	int startingYPosition = 0;
	int endingYPosition = 10;

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
	save_image.setFilename("DynamicBlueprints/1.png", ImageFileBase::IMAGE_FILENAME_BASE_MAPS);
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
	}
	else
	{
		print("couldn't save blueprint : selection positions are invalid");
	}
	keyOJustPressed = false;
}

uint8[][] currentBlueprintData;
int OButtonSelect = 0;
int16 currentBlueprintWidth = 0;
int16 currentBlueprintHeight = 0;
void LoadBlueprintFromPng(CRules@ this)
{
	@save_image = CFileImage("DynamicBlueprints/1.png");
	bool done = false;

	if (save_image.isLoaded())
	{
		currentBlueprintWidth = save_image.getWidth();
		currentBlueprintHeight = save_image.getHeight();
		save_image.setPixelOffset(-1);
		uint8[][] _currentBlueprintData(currentBlueprintWidth, uint8[](currentBlueprintHeight, 0));
		currentBlueprintData = _currentBlueprintData;
		u8 a;
		u8 r;
		u8 g;
		u8 b;
		while(save_image.nextPixel() && !done)
		{
			if(save_image.readPixel(a, r, g, b)) //this readpixel function is dank af, the argument given are the output of the function
			{
				currentBlueprintData[save_image.getPixelPosition().x][save_image.getPixelPosition().y] = r;
				//print("r value : " + r);
			}
			else
			{
				print("an error occured while reading a pixel from a blueprint png");
			}
		}
		deepCopyArray();
	}
	else
	{
		print("couldn't load blueprint");
	}
	keyLJustPressed = false;
	displayLoadedBlueprint = true;
}

bool displayLoadedBlueprint = false;
uint8[][] networkBlueprintData;
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

uint8[][] tileMapDataCopy;
void deepCopyArray()
{
	CMap@ map = getMap();
	tileMapDataCopy = dynamicMapTileData;
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