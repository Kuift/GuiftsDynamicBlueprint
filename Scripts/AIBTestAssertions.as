const u8 AIBT_IDLE = 0;
const u8 AIBT_FIND_TREE = 1;
const u8 AIBT_CHOP_TREE = 2;
const u8 AIBT_FIND_LOG = 3;
const u8 AIBT_CHOP_LOG = 4;
const u8 AIBT_FIND_WOOD = 5;
const u8 AIBT_RETURN_WOOD = 6;
const u8 AIBT_FIND_STONE = 7;
const u8 AIBT_PREPARE_STONE_SHAFT = 8;
const u8 AIBT_DIG_STONE_SHAFT = 9;
const u8 AIBT_TUNNEL_TO_STONE = 10;
const u8 AIBT_FIND_STONE_MAT = 11;
const u8 AIBT_COLLECT_BLUEPRINT_RESOURCES = 12;
const u8 AIBT_FIND_BLUEPRINT_BLOCK = 13;
const u8 AIBT_BUILD_BLUEPRINT_BLOCK = 14;
const u8 AIBT_NURSERY_COLLECT_WOOD = 15;
const u8 AIBT_NURSERY_BUILD = 16;
const u8 AIBT_NURSERY_COLLECT_STONE = 17;
const u8 AIBT_NURSERY_BUY_SEED = 18;
const u8 AIBT_NURSERY_PLANT_SEED = 19;
const u8 AIBT_NURSERY_WAIT_TREE = 20;
const u8 AIBT_JOB_WOOD = 0;
const u8 AIBT_JOB_STONE = 1;
const u8 AIBT_JOB_BLUEPRINT = 2;

string AIBT_StateName(const u8 state)
{
	switch (state)
	{
		case AIBT_IDLE: return "idle";
		case AIBT_FIND_TREE: return "find_tree";
		case AIBT_CHOP_TREE: return "chop_tree";
		case AIBT_FIND_LOG: return "find_log";
		case AIBT_CHOP_LOG: return "chop_log";
		case AIBT_FIND_WOOD: return "find_wood";
		case AIBT_RETURN_WOOD: return "return_wood";
		case AIBT_FIND_STONE: return "find_stone";
		case AIBT_PREPARE_STONE_SHAFT: return "prepare_stone_shaft";
		case AIBT_DIG_STONE_SHAFT: return "dig_stone_shaft";
		case AIBT_TUNNEL_TO_STONE: return "tunnel_to_stone";
		case AIBT_FIND_STONE_MAT: return "find_stone_mat";
		case AIBT_COLLECT_BLUEPRINT_RESOURCES: return "collect_blueprint_resources";
		case AIBT_FIND_BLUEPRINT_BLOCK: return "find_blueprint_block";
		case AIBT_BUILD_BLUEPRINT_BLOCK: return "build_blueprint_block";
		case AIBT_NURSERY_COLLECT_WOOD: return "nursery_collect_wood";
		case AIBT_NURSERY_BUILD: return "nursery_build";
		case AIBT_NURSERY_COLLECT_STONE: return "nursery_collect_stone";
		case AIBT_NURSERY_BUY_SEED: return "nursery_buy_seed";
		case AIBT_NURSERY_PLANT_SEED: return "nursery_plant_seed";
		case AIBT_NURSERY_WAIT_TREE: return "nursery_wait_tree";
	}
	return "unknown";
}

string AIBT_BlobRef(CBlob@ blob)
{
	return AIB_EventBlobRef(blob);
}

u16 AIBT_MaterialQuantity(CBlob@ blob)
{
	if (blob is null) return 0;
	const u16 quantity = blob.getQuantity();
	return quantity == 0 ? 1 : quantity;
}

CBlob@ AIBT_GetBlob(const string &in key)
{
	CRules@ rules = getRules();
	if (rules is null || !rules.exists(key)) return null;
	return getBlobByNetworkID(rules.get_netid(key));
}

void AIBT_SetBlob(const string &in key, CBlob@ blob)
{
	CRules@ rules = getRules();
	if (rules is null) return;
	rules.set_netid(key, blob is null ? 0 : blob.getNetworkID());
}

u16 AIBT_CountMaterialNear(const string &in name, Vec2f pos, const f32 radius)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	u16 count = 0;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob !is null && (blob.getPosition() - pos).Length() <= radius)
		{
			if (!blob.isInInventory() && !blob.isAttached())
			{
				count += AIBT_MaterialQuantity(blob);
			}
		}
	}
	return count;
}

u16 AIBT_CountMaterialInCratesNear(const string &in name, Vec2f pos, const f32 radius)
{
	CBlob@[] crates;
	getBlobsByName("crate", @crates);
	u16 count = 0;
	for (uint i = 0; i < crates.length; i++)
	{
		CBlob@ crate = crates[i];
		if (crate is null || crate.hasTag("dead")) continue;
		if (crate.exists("packed")) continue;
		if ((crate.getPosition() - pos).Length() > radius) continue;

		CInventory@ inv = crate.getInventory();
		if (inv is null) continue;
		for (uint j = 0; j < inv.getItemsCount(); j++)
		{
			CBlob@ item = inv.getItem(j);
			if (item !is null && item.getName() == name)
			{
				count += AIBT_MaterialQuantity(item);
			}
		}
	}
	return count;
}

u16 AIBT_CountBlobsNear(const string &in name, Vec2f pos, const f32 radius)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	u16 count = 0;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob !is null && !blob.hasTag("dead") && (blob.getPosition() - pos).Length() <= radius)
		{
			count++;
		}
	}
	return count;
}

u16 AIBT_CountInventoryMaterial(CBlob@ blob, const string &in name)
{
	if (blob is null) return 0;
	CInventory@ inv = blob.getInventory();
	u16 count = 0;
	if (inv !is null)
	{
		for (uint i = 0; i < inv.getItemsCount(); i++)
		{
			CBlob@ item = inv.getItem(i);
			if (item !is null && item.getName() == name)
			{
				count += AIBT_MaterialQuantity(item);
			}
		}
	}

	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == name)
	{
		count += AIBT_MaterialQuantity(carried);
	}
	return count;
}

string AIBT_DescribeBuilder(CBlob@ bot)
{
	if (bot is null) return "bot=null";
	CBlob@ target = getBlobByNetworkID(bot.get_netid("ai builder target"));
	return "state=" + AIBT_StateName(bot.get_u8("ai builder state")) +
		" target=" + AIBT_BlobRef(target) +
		" pos=" + AIB_EventPos(bot.getPosition()) +
		" dest=" + AIB_EventPos(bot.get_Vec2f("ai builder destination")) +
		" tile=" + AIB_EventPos(bot.get_Vec2f("ai builder tile target")) +
		" obstruction=" + bot.get_u8("ai builder obstruction threshold") +
		" inv_wood=" + AIBT_CountInventoryMaterial(bot, "mat_wood") +
		" inv_stone=" + AIBT_CountInventoryMaterial(bot, "mat_stone");
}

bool AIBT_TargetIs(CBlob@ bot, CBlob@ expected)
{
	if (bot is null || expected is null) return false;
	return bot.get_netid("ai builder target") == expected.getNetworkID();
}
