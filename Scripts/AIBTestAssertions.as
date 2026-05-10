const u8 AIBT_IDLE = 0;
const u8 AIBT_FIND_TREE = 1;
const u8 AIBT_CHOP_TREE = 2;
const u8 AIBT_FIND_LOG = 3;
const u8 AIBT_CHOP_LOG = 4;
const u8 AIBT_FIND_WOOD = 5;
const u8 AIBT_RETURN_WOOD = 6;

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
		" obstruction=" + bot.get_u8("ai builder obstruction threshold") +
		" inv_wood=" + AIBT_CountInventoryMaterial(bot, "mat_wood");
}

bool AIBT_TargetIs(CBlob@ bot, CBlob@ expected)
{
	if (bot is null || expected is null) return false;
	return bot.get_netid("ai builder target") == expected.getNetworkID();
}
