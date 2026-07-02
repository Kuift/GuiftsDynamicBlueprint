// Nursery

#include "ProductionCommon.as";
#include "Requirements.as"
#include "MakeSeed.as"
#include "WARCosts.as";

const u16 AIB_NURSERY_SEED_STONE_COST = 20;
const u16 AIB_NURSERY_TREE_SEED_PRODUCTION_SECONDS = 32;
const u16 AIB_NURSERY_TREE_SEED_STOCK_LIMIT = 1;

CBitStream@ AIB_SeedRequirements()
{
	CBitStream requirements;
	AddRequirement(requirements, "blob", "mat_stone", "Stone", AIB_NURSERY_SEED_STONE_COST);
	return requirements;
}

void onInit(CBlob@ this)
{
	this.set_string("produce sound", "/PopIn");

	{
		addSeedItem(this, "tree_pine", "Pine tree seed", AIB_NURSERY_TREE_SEED_PRODUCTION_SECONDS, AIB_NURSERY_TREE_SEED_STOCK_LIMIT, AIB_SeedRequirements());
	}
	{
		addSeedItem(this, "tree_bushy", "Oak tree seed", AIB_NURSERY_TREE_SEED_PRODUCTION_SECONDS, AIB_NURSERY_TREE_SEED_STOCK_LIMIT, AIB_SeedRequirements());
	}

	this.set_TileType("background tile", CMap::tile_wood_back);
	this.getSprite().getConsts().accurateLighting = true;

	this.getSprite().SetZ(-50);
	this.getShape().getConsts().mapCollisions = false;

	this.Tag("inventory access");

	string[] autograb_blobs = {"seed"};
	this.set("autograb blobs", autograb_blobs);

	this.inventoryButtonPos = Vec2f(0.0f, -24.0f);
}

void onDie(CBlob@ this)
{
	if (getNet().isServer())
	{
		CBlob@ blob = server_CreateBlob("mat_wood", this.getTeamNum(), this.getPosition());
		if (blob !is null)
		{
			blob.server_SetQuantity(COST_WOOD_NURSERY / 2);
		}
	}
}
