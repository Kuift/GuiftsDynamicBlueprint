//This code has been started from the ScriptRenderExample.as script
uint8[][] dynamicMapTileData;


const string REEEPPNG = "REEE";//stand for "Relevent Environnement for Enhancing Effectiveness [of rendering]" 
array<SMesh@> everythingMesh;
SMaterial@ everythingMat = SMaterial();


float MAX_ENTITIES_PER_MESH = 10000.0f; //the 10000 is the maximum number of block we can put before the mesh bug
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

void onInit(CRules@ this)
{
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
		array<SMesh@> _everythingMesh(Maths::Ceil(float(getMap().tilemapwidth)*float(getMap().tilemapheight)/MAX_ENTITIES_PER_MESH), SMesh());
		everythingMesh = _everythingMesh;
		for(int i = 0; i < everythingMesh.size(); i++)
		{
			//mesh initial config 
			everythingMesh[i].SetMaterial(everythingMat);
			everythingMesh[i].SetHardwareMapping(SMesh::STATIC); 
		}
	}
}

void onRestart(CRules@ this)
{
	dynamicMapTileData.clear();
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
		if(playerBlob == null){return;} 
		blockIndex = GiveBlockIndex(playerBlob);
		if (blockIndex != oldBlockIndex)
		{
			oldBlockIndex = blockIndex;
			x = (blockIndex % (pngWidth/8))/(pngWidth/8);
			y = int(blockIndex / (pngWidth/8)) / (pngHeight/8);
		}
	}
}

int last_changed = 0;
bool toggleBlueprint = true;
Vec2f currentPlacementPosition;
int customMenuTurn;
void ChangeIfNeeded()
{
	CControls@ c = getControls();
	if (c is null) return;

	if(c.isKeyJustPressed(KEY_KEY_H))
	{
		toggleBlueprint = !toggleBlueprint;
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
		CBlob@ playerBlob = getLocalPlayerBlob();
		Vec2f temp;
		if(playerBlob != null)
		{
			temp = getLocalPlayerBlob().getAimPos();
		}
		else
		{
			temp = Vec2f(0,0);
		}
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
		if(isClient())
		{
			setVertexMatrix(dynamicMapTileData, v_raw, positionx, positiony);
		}
		
    }
	if(cmd == this.getCommandID("removeBlocks") && dynamicMapTileData.size() > 0)
	{
		uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		
		dynamicMapTileData[positionx][positiony] = 0;
		if(isClient())
		{
			unsetVertexMatrix(dynamicMapTileData, v_raw, positionx, positiony);
		}

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
					setVertexMatrix(dynamicMapTileData, v_raw, x, y);
				}
			}
		}
	}
}



int GiveBlockIndex(CBlob@ this)
{
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

u16[][] v_i;

//this is the highest performance option
Vertex[][] v_raw;

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
	
	//u16[][] _v_i(Maths::Ceil(float(getMap().tilemapwidth)*float(getMap().tilemapheight)/MAX_ENTITIES_PER_MESH, u16[](0, 0));
	//Vertex[][] _v_raw(Maths::Ceil(float(getMap().tilemapwidth)*float(getMap().tilemapheight)/MAX_ENTITIES_PER_MESH, Vertex[]);
	array<array<u16>> _v_i(Maths::Ceil(float(getMap().tilemapwidth)*float(getMap().tilemapheight)/MAX_ENTITIES_PER_MESH), array<u16>(0));
	array<array<Vertex>> _v_raw(Maths::Ceil(float(getMap().tilemapwidth)*float(getMap().tilemapheight)/MAX_ENTITIES_PER_MESH), array<Vertex>(0));
	v_i = _v_i;
	v_raw = _v_raw;
	if(resetMapData)
	{
		CMap@ map = getMap();
		uint8[][] _dynamicMapTileData(map.tilemapwidth, uint8[](map.tilemapheight, 0));
		dynamicMapTileData = _dynamicMapTileData;
	}
	
	/*Vec2f p = this.getAimPos();
	p.x+=15;
	p.y-=15;*/
	v_raw[0].push_back(Vertex(0, 0, 1000, x, 			y, 			SColor(0x70aacdff)));
	v_raw[0].push_back(Vertex(0, 0, 1000, x+offsetx, 	y, 			SColor(0x70aacdff)));
	v_raw[0].push_back(Vertex(0, 0, 1000, x+offsetx, 	y+offsety, 	SColor(0x70aacdff)));
	v_raw[0].push_back(Vertex(0, 0, 1000, x, 			y+offsety, 	SColor(0x70aacdff)));
	v_i[0].push_back(0);
	v_i[0].push_back(1);
	v_i[0].push_back(2);
	v_i[0].push_back(0);
	v_i[0].push_back(2);
	v_i[0].push_back(3);
		
	initIndexVertexArrays(v_raw,v_i);//initVertexAray(v_raw, v_i);
}

void initIndexVertexArrays(Vertex[][] &v_raw, u16[][] &v_i)
{
	CMap@ map = getMap();
	int index = v_i[0][v_i[0].size()-1] + 1;
	for(int i = 0; i < map.tilemapwidth*map.tilemapheight; i++)
	{
		int arrayIndex = int(float(index*1.5)/MAX_ENTITIES_PER_MESH);
		index = index % MAX_ENTITIES_PER_MESH;
		v_raw[arrayIndex].push_back(Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff)));
		v_raw[arrayIndex].push_back(Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff)));
		v_raw[arrayIndex].push_back(Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff)));
		v_raw[arrayIndex].push_back(Vertex(0, 0, 0, 0, 	0, 	SColor(0x00aacdff)));
		v_i[arrayIndex].push_back(index);
		v_i[arrayIndex].push_back(index+1);
		v_i[arrayIndex].push_back(index+2);
		v_i[arrayIndex].push_back(index);
		v_i[arrayIndex].push_back(index+2);
		v_i[arrayIndex].push_back(index+3);
		index += 4;
	}
}


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
	CBlob@ playerBlob = this.getBlob();
	Vec2f p;
	if(playerBlob != null)
	{
		p = playerBlob.getAimPos();
		p.x+=15;
		p.y-=15;
	}
	else
	{
		p = Vec2f(0,0);
	}


	//COLOR : 0xAARRGGBB
	CControls@ c = getControls();
	if(c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL))
	{
		toggleBlueprint = true;
		v_raw[0][0] = (Vertex(p.x - x_size, p.y - y_size, 1000, x, 			y, 			SColor(0x70aacdff)));
		v_raw[0][1] = (Vertex(p.x + x_size, p.y - y_size, 1000, x+offsetx, 	y, 			SColor(0x70aacdff)));
		v_raw[0][2] = (Vertex(p.x + x_size, p.y + y_size, 1000, x+offsetx, 	y+offsety, 	SColor(0x70aacdff)));
		v_raw[0][3] = (Vertex(p.x - x_size, p.y + y_size, 1000, x, 			y+offsety, 	SColor(0x70aacdff)));
	}
	else
	{
		v_raw[0][0] = (Vertex(p.x - x_size, p.y - y_size, 1000, x, 			y, 			SColor(0x00aacdff)));
		v_raw[0][1] = (Vertex(p.x + x_size, p.y - y_size, 1000, x+offsetx, 	y, 			SColor(0x00aacdff)));
		v_raw[0][2] = (Vertex(p.x + x_size, p.y + y_size, 1000, x+offsetx, 	y+offsety, 	SColor(0x00aacdff)));
		v_raw[0][3] = (Vertex(p.x - x_size, p.y + y_size, 1000, x, 			y+offsety, 	SColor(0x00aacdff)));
	}

	if(toggleBlueprint)
	{
		//updateVertex(this, v_raw, dynamicMapTileData);
		for(int i = 0; i < everythingMesh.size(); i++)
		{
			/*print("i before crash : " + i);
			print("vraw size ev : " + v_raw.size());
			print("vraw[i] size : " + v_raw[i].size());
			print("vi size : " + v_i.size());
			print("v_i[i] size : " + v_i[i].size());*/
			everythingMesh[i].SetVertex(v_raw[i]);
			everythingMesh[i].SetIndices(v_i[i]); 
			everythingMesh[i].BuildMesh();
			everythingMesh[i].SetDirty(SMesh::VERTEX_INDEX);
			everythingMesh[i].RenderMeshWithMaterial();
		}
	}
}
int xRenderLimit = 37;
int yRenderLimit = 21;
int renderingState = 0; //0 = render relative to camera position, 1 = render relative to player position
void updateVertex(CPlayer@ this, Vertex[] &v_raw, uint8[][] &tileData)
{
	CMap@ map = getMap();
	Vec2f blobPosition;
	CBlob@ playerBlob = this.getBlob();
	if(renderingState == 1 && playerBlob != null)
	{
		blobPosition = playerBlob.getAimPos();
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

void setVertexMatrix(uint8[][] &position, Vertex[][] &v_raw, int x, int y)
{
	f32 z = 1000;
	//7/15/200/100 7 + (15)*200
	CMap@ map = getMap();
	uint64 ind = 4 + x * 4 + y * (map.tilemapwidth-1)*4 + y * 4;
	//uint64 ind = 4 + (x + y *  (map.tilemapwidth-1))*4;
	print("indbefore : " + ind);
	print("x : " + x);
	print("y : " + y);
	print("everythingmesh size : " + everythingMesh.size());
	int arrayIndex = int(float(ind/6)/MAX_ENTITIES_PER_MESH);
	ind = ind % MAX_ENTITIES_PER_MESH;
	print("ind : " + ind);
	print("arrayind : " + arrayIndex);
	v_raw[arrayIndex][ind] = (Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y]), 			SColor(0x70aacdff)));
	v_raw[arrayIndex][ind+1] = (Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y]), 			SColor(0x70aacdff)));
	v_raw[arrayIndex][ind+2] = (Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y])+offsety, 	SColor(0x70aacdff)));
	v_raw[arrayIndex][ind+3] = (Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y])+offsety, 	SColor(0x70aacdff)));
}

void unsetVertexMatrix(uint8[][] &position, Vertex[][] &v_raw, int x, int y)
{
	f32 z = 1000;

	CMap@ map = getMap();
	int ind = 4 + (x * 4 + y * map.tilemapwidth); 
	int arrayIndex = int(float(ind)/MAX_ENTITIES_PER_MESH);
	ind = ind % MAX_ENTITIES_PER_MESH;
	v_raw[arrayIndex][ind] = (Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y]), 			SColor(0x00aacdff)));
	v_raw[arrayIndex][ind+1] = (Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y]), 			SColor(0x00aacdff)));
	v_raw[arrayIndex][ind+2] = (Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y])+offsety, 	SColor(0x00aacdff)));
	v_raw[arrayIndex][ind+3] = (Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y])+offsety, 	SColor(0x00aacdff)));
}
