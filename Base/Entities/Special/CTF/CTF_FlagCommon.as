const string return_prop = "return time";
const u16 return_time = 600;

bool canPickupFlag(CBlob@ blob)
{
	// AI builders have resource/construction orders, not a flag objective. Their
	// player tag otherwise makes ordinary CTF collision code attach an enemy flag
	// during a cross-map work route and the resource return state carries it home.
	if (blob is null || blob.getName() == "aibuilder" || blob.getName() == "autobuilder") return false;

	bool pick = !blob.hasAttached();

	if (!pick)
	{
		CBlob@ carried = blob.getCarriedBlob();
		if (carried !is null)
		{
			pick = carried.hasTag("temp blob");
		}
		else
		{
			pick = true;
		}
	}

	return pick;
}

bool shouldFastReturn(CBlob@ this)
{
	const int team = this.getTeamNum();

	bool fast_return = false;
	CBlob@[] overlapping;
	if (this.getOverlapping(overlapping))
	{
		for(uint i = 0; i < overlapping.length; i++)
		{
			if (overlapping[i].getTeamNum() == team && overlapping[i].hasTag("player"))
			{
				fast_return = true;
				break;
			}
		}
	}

	return fast_return;
}
