//This code has been started from the ScriptRenderExample.as script


const string REEEPPNG = "REEE";//stand for "Relevent Environnement for Enhancing Effectiveness [of rendering]" 
SMesh@ everythingMesh = SMesh();
SMaterial@ everythingMat = SMaterial();
void Setup()
{
	//ensure that we don't duplicate a texture
	if(!Texture::exists(REEEPPNG))
	{
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
	everythingMesh.SetHardwareMapping(SMesh::STATIC); //maybe MAP::STATIC instead


}
//toggle through each render type to give a working example of each call


int last_changed = 0;
bool toggleBlueprint = true;
Vec2f currentPlacementPosition;
int customMenuTurn = 1;
void ChangeIfNeeded(CBlob@ this)
{
	CControls@ c = getControls();
	if (c is null) return;

	if(c.isKeyJustPressed(KEY_KEY_H))
	{
		toggleBlueprint = !toggleBlueprint;
	}

	if (c.isKeyPressed(KEY_LCONTROL) || c.isKeyPressed(KEY_RCONTROL))
	{

		Vec2f temp = this.getAimPos();
		currentPlacementPosition = Vec2f(int(temp.x/8) * 8 + 4,int(temp.y/8) * 8 + 4);
		if (c.isKeyPressed(c.getActionKeyKey(AK_ACTION1)) && toggleBlueprint)
		{
			//if the vector doesn't exist in the array then... (find return negative number when the item is not in array)
			if(savedPositions.find(currentPlacementPosition) < 0)
			{
				savedPositions.push_back(currentPlacementPosition);
				uvcoord.push_back(Vec2f(x,y));

				CBitStream params;
				uint16 xpos = currentPlacementPosition.x;
				uint16 ypos = currentPlacementPosition.y;
        		params.write_u16(xpos);
				params.write_u16(ypos);
				params.write_u8(blockIndex);
        		this.SendCommand(this.getCommandID("addBlocks"), params);
			}

		}
		else if (c.isKeyPressed(c.getActionKeyKey(AK_ACTION2))  && toggleBlueprint)
		{

				int i = savedPositions.find(currentPlacementPosition);
				if(i >= 0)
				{
					savedPositions[i] = Vec2f_zero;
					
					CBitStream params;
					uint16 xpos = currentPlacementPosition.x;
					uint16 ypos = currentPlacementPosition.y;
					params.write_u16(xpos);
					params.write_u16(ypos);
					this.SendCommand(this.getCommandID("removeBlocks"), params);
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




//blob hooks
void onInit(CBlob@ this)
{
	Setup();
	int cb_id = Render::addBlobScript(Render::layer_postworld, this, "CustomRenderer.as", "ExampleBlobRenderFunction");
//////////////////////////NETWORK PART//////////////////////////
	this.addCommandID("addBlocks");
	this.addCommandID("removeBlocks");
	//this.addCommandID("getAllBlocks");
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
    if(cmd == this.getCommandID("addBlocks"))//toggles the gui help overlay
    {
        uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		uint8 receivedBlockIndex = params.read_u8();
		
		Vec2f positionVector = Vec2f(positionx, positiony);

		print("command addblocks called");

		float uv_x = (receivedBlockIndex % (pngWidth/8))/(pngWidth/8);
		float uv_y = int(receivedBlockIndex / (pngWidth/8)) / (pngHeight/8);

		int ind = savedPositions.find(positionVector);
		
		if(ind < 0)//check if the block is already filled in. If it is, the block at that position is replaced
		{
			savedPositions.push_back(positionVector);
			uvcoord.push_back(Vec2f(uv_x, uv_y));
		}
		else{
			savedPositions[ind] = positionVector;
			uvcoord[ind] = Vec2f(uv_x, uv_y);
		}
    }
	if(cmd == this.getCommandID("removeBlocks"))
	{
		uint16 positionx = params.read_u16();
		uint16 positiony = params.read_u16();
		
		Vec2f positionVector = Vec2f(positionx, positiony);
		print("command removeBlocks called");
		int i = savedPositions.find(positionVector);
		if(i >= 0)
		{
			savedPositions[i] = Vec2f_zero;
		}
	}
}
//////////////////NETWORK PART END/////////////////////////////////
int oldBlockIndex = -1;
void onTick(CBlob@ this)
{
	ChangeIfNeeded(this); 
	blockIndex = GiveBlockIndex(this);
	if (blockIndex != oldBlockIndex)
	{
		oldBlockIndex = blockIndex;
		x = (blockIndex % (pngWidth/8))/(pngWidth/8);
		y = int(blockIndex / (pngWidth/8)) / (pngHeight/8);
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

//render functions
//
// blob functions get the blob they were created with as an argument
//  and are removed safely when that blob is killed/removed
//
// both get the id of their function - they can be removed with
//  Render::RemoveScript if appropriate

void ExampleBlobRenderFunction(CBlob@ this, int id)
{
	RenderWidgetFor(this);
}
void onInit(CRules@ this)
{
    this.addCommandID("clientshowhelp");
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


Vec2f[] savedPositions;
float x_size = 4;
float y_size = 4;
uint8 blockIndex = 48;//this.get_TileType("buildtile");
float pngWidth = 128.0f;
float pngHeight = 256.0f;
float x = (blockIndex % (pngWidth/8))/(pngWidth/8);
float y = int(blockIndex / (pngWidth/8)) / (pngHeight/8);
float offsetx = 8/pngWidth;
float offsety = 8/pngHeight;
Vec2f[] uvcoord;

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
		v_raw.push_back(Vertex(p.x - x_size, p.y - y_size, z, x, 			y, 			SColor(0xb0aacdff)));
		v_raw.push_back(Vertex(p.x + x_size, p.y - y_size, z, x+offsetx, 	y, 			SColor(0xb0aacdff)));
		v_raw.push_back(Vertex(p.x + x_size, p.y + y_size, z, x+offsetx, 	y+offsety, 	SColor(0xb0aacdff)));
		v_raw.push_back(Vertex(p.x - x_size, p.y + y_size, z, x, 			y+offsety, 	SColor(0xb0aacdff)));
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

	if(savedPositions.size() != 0 && toggleBlueprint)
	{
		placeEntities(savedPositions, v_raw, v_i, z, uvcoord);
	}
	everythingMesh.SetVertex(v_raw);
	everythingMesh.SetIndices(v_i); 
	everythingMesh.BuildMesh();
	everythingMesh.SetDirty(SMesh::VERTEX_INDEX);
	everythingMesh.RenderMeshWithMaterial(); 
	//Render::RawTrianglesIndexed(render_texture_name, v_raw, v_i);

}

void placeEntities(Vec2f[] &position, Vertex[] &v_raw, u16[] &v_i, f32 z, Vec2f[] &uvcoord)
{
	int index = v_i[v_i.size()-1] + 1;
	for( int i = 0; i < position.size(); i++ ) {
		if(!position[i].opEquals(Vec2f_zero))
		{
			v_raw.push_back(Vertex(position[i].x - x_size, position[i].y - y_size, z, uvcoord[i].x, 			uvcoord[i].y, 			SColor(0x80aacdff)));
			v_raw.push_back(Vertex(position[i].x + x_size, position[i].y - y_size, z, uvcoord[i].x+offsetx, 	uvcoord[i].y, 			SColor(0x80aacdff)));
			v_raw.push_back(Vertex(position[i].x + x_size, position[i].y + y_size, z, uvcoord[i].x+offsetx, 	uvcoord[i].y+offsety, 	SColor(0x80aacdff)));
			v_raw.push_back(Vertex(position[i].x - x_size, position[i].y + y_size, z, uvcoord[i].x, 			uvcoord[i].y+offsety, 	SColor(0x80aacdff)));
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
