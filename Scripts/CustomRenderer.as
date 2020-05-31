//This code has been started from the ScriptRenderExample.as script
uint8[][] dynamicMapTileData;


const string REEEPPNG = "REEE";//stand for "Relevent Environnement for Enhancing Effectiveness [of rendering]" 
SMesh@ everythingMesh = SMesh();
SMaterial@ everythingMat = SMaterial();

float x_size;
float y_size;
uint8 blockIndex;//this.get_TileType("buildtile");
float pngWidth = 128.0f;
float pngHeight = 256.0f;
float x = (blockIndex % (pngWidth/8))/(pngWidth/8);
float y = int(blockIndex / (pngWidth/8)) / (pngHeight/8);
float offsetx = 8/pngWidth;
float offsety = 8/pngHeight;

void onInit(CRules@ this)
{
	customMenuTurn = 1;
	x_size = 4;
	y_size = 4;
	blockIndex = 48;
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
	CPlayer@ player = getLocalPlayer();
	if (player != null)
	{
		uint16 id = player.getNetworkID();
		CBitStream params;
		params.write_u16(id);
		getRules().SendCommand(getRules().getCommandID("getAllBlocks"), params);
	}
}

void RulesRenderFunction(int id)
{
	CBlob@ playerBlob = getLocalPlayerBlob();
	if(playerBlob == null){return;} 
	RenderWidgetFor(getLocalPlayerBlob());
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
	CMap@ map = getMap();
	uint8[][] _dynamicMapTileData(map.tilemapwidth, uint8[](map.tilemapheight, 0));
	dynamicMapTileData = _dynamicMapTileData;
	if(isClient())
	{
		Setup();
	}
}


//toggle through each render type to give a working example of each call
int oldBlockIndex = -1;

void onTick(CRules@ this)
{

	if(isClient())
	{	
		CBlob@ playerBlob = getLocalPlayerBlob();
		if(playerBlob == null){return;} 
		ChangeIfNeeded(); 
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

	if (c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL))
	{

		Vec2f temp = getLocalPlayerBlob().getAimPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		uint16 indexX = (currentPlacementPosition.x-4)/8;
		uint16 indexY = (currentPlacementPosition.y-4)/8; 
		CMap@ map = getMap();
		if(indexX < map.tilemapwidth && indexY < map.tilemapheight)//ensure that we don't get index out of the array
		{
			if (c.isKeyPressed(c.getActionKeyKey(AK_ACTION1)) && c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL))
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
			else if (c.isKeyPressed(c.getActionKeyKey(AK_ACTION2))  && c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL) && dynamicMapTileData[indexX][indexY] != 0)
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
    if(cmd == this.getCommandID("addBlocks"))
    {
        uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		uint8 receivedBlockIndex = params.read_u8();
		
		dynamicMapTileData[positionx][positiony] = receivedBlockIndex;
		
    }
	if(cmd == this.getCommandID("removeBlocks"))
	{
		uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		
		dynamicMapTileData[positionx][positiony] = 0;

	}
	if(!isClient() && cmd == this.getCommandID("getAllBlocks"))
	{
		CMap@ map = getMap();
		CBitStream insideparams;
		insideparams.write_u16(getLocalPlayer().getNetworkID());
		uint16 playerNetworkID = params.read_u16();
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

u16[] v_i;

//this is the highest performance option
Vertex[] v_raw;



void ClearRenderState()
{
	v_i.clear();
	v_raw.clear();
	//we are rendering after the world
	//so we can alpha blend relatively safely, although it will still misbehave
	//when rendering over other alpha-blended stuff
	Render::SetAlphaBlend(true);
}



void RenderWidgetFor(CBlob@ this)
{

	Render::SetTransformWorldspace();
	//Vec2f p = this.getInterpolatedPosition();
	Vec2f p = this.getAimPos();
	CMap@ map = getMap();

	string render_texture_name = REEEPPNG;

	ClearRenderState();

	//render in front of almost everything
	f32 z = this.getSprite().getZ() + 1000;

	//COLOR : 0xAARRGGBB
	CControls@ c = getControls();
	p.x+=15;
	p.y-=15;
	if(c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL))
	{
		toggleBlueprint = true;
		v_raw.push_back(Vertex(p.x - x_size, p.y - y_size, z, x, 			y, 			SColor(0x70aacdff)));
		v_raw.push_back(Vertex(p.x + x_size, p.y - y_size, z, x+offsetx, 	y, 			SColor(0x70aacdff)));
		v_raw.push_back(Vertex(p.x + x_size, p.y + y_size, z, x+offsetx, 	y+offsety, 	SColor(0x70aacdff)));
		v_raw.push_back(Vertex(p.x - x_size, p.y + y_size, z, x, 			y+offsety, 	SColor(0x70aacdff)));
		//set up the mesh indexing
	}
	else{
		v_raw.push_back(Vertex(p.x - x_size, p.y - y_size, z, x, 			y, 			SColor(0x00aacdff)));
		v_raw.push_back(Vertex(p.x + x_size, p.y - y_size, z, x+offsetx, 	y, 			SColor(0x00aacdff)));
		v_raw.push_back(Vertex(p.x + x_size, p.y + y_size, z, x+offsetx, 	y+offsety, 	SColor(0x00aacdff)));
		v_raw.push_back(Vertex(p.x - x_size, p.y + y_size, z, x, 			y+offsety, 	SColor(0x00aacdff)));
	}
	v_i.push_back(0);
	v_i.push_back(1);
	v_i.push_back(2);
	v_i.push_back(0);
	v_i.push_back(2);
	v_i.push_back(3);

	if(toggleBlueprint)
	{
		placeEntities(dynamicMapTileData, v_raw, v_i, z);
	}
	everythingMesh.SetVertex(v_raw);
	everythingMesh.SetIndices(v_i); 
	everythingMesh.BuildMesh();
	everythingMesh.SetDirty(SMesh::VERTEX_INDEX);
	everythingMesh.RenderMeshWithMaterial(); 
	//Render::RawTrianglesIndexed(render_texture_name, v_raw, v_i);

}

void placeEntities(uint8[][] &position, Vertex[] &v_raw, u16[] &v_i, f32 z)
{
	CMap@ map = getMap();
	int index = v_i[v_i.size()-1] + 1;
	for( int y = 0; y < map.tilemapheight; y++ ) {
		for(int x = 0; x < map.tilemapwidth; x++)
		{
			if(position[x][y] !=0 )
			{
				v_raw.push_back(Vertex(x*8+4 - x_size, y*8+4 - y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y]), 			SColor(0x70aacdff)));
				v_raw.push_back(Vertex(x*8+4 + x_size, y*8+4 - y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y]), 			SColor(0x70aacdff)));
				v_raw.push_back(Vertex(x*8+4 + x_size, y*8+4 + y_size, z, getUVX(position[x][y])+offsetx, 	getUVY(position[x][y])+offsety, 	SColor(0x70aacdff)));
				v_raw.push_back(Vertex(x*8+4 - x_size, y*8+4 + y_size, z, getUVX(position[x][y]), 			getUVY(position[x][y])+offsety, 	SColor(0x70aacdff)));
				v_i.push_back(index);
				v_i.push_back(index+1);
				v_i.push_back(index+2);
				v_i.push_back(index);
				v_i.push_back(index+2);
				v_i.push_back(index+3);
				index += 4;
			}
		}
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

//this is the fastest way of checking if a a vector is in an vector array, maybe this functino should be removed
bool isVecInVecArray(Vec2f &in inputVec, Vec2f[] &in inputVecArray)
{
	if(inputVecArray.find(inputVec) >= 0)
	{
		return true;
	}
	else
	{
		return false;
	}
}
