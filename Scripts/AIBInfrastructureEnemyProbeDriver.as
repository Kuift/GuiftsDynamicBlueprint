// Attached only to the benchmark-owned, connected enemy builder.  The server
// benchmark moves the body through bounded collision-respecting velocity; this client script
// supplies the production attack boundary by sending BuilderLogic's existing
// pickaxe command.  BuilderLogic still performs its normal range, cooldown,
// no-build, tile-damage, blob-damage, and attribution checks.

const u32 AIBIED_COMMAND_INTERVAL = 12;

bool AIBIED_IsActive(CBlob@ this, CRules@ rules)
{
	if (this is null || rules is null || !this.hasTag("aib infrastructure ally probe")) return false;
	return rules.get_bool("aib infrastructure client probe active") &&
		rules.get_u8("aib infrastructure client action") == 1 &&
		rules.get_netid("aib infrastructure enemy probe blob") == this.getNetworkID() &&
		this.getPlayer() !is null && this.getPlayer().getNetworkID() == rules.get_u16("aib infrastructure probe player");
}

CBlob@ AIBIED_ClosestProtectedDoor(CBlob@ this, CRules@ rules)
{
	CBlob@[] nearby;
	getMap().getBlobsInRadius(this.getPosition(), 32.0f, @nearby);
	CBlob@ best = null;
	f32 bestDistance = 999999.0f;
	for (uint i = 0; i < nearby.length; i++)
	{
		CBlob@ candidate = nearby[i];
		if (candidate is null || candidate.hasTag("dead") || !candidate.hasTag("door") ||
			candidate.getTeamNum() != rules.get_u8("aib infrastructure team")) continue;
		const f32 distance = this.getDistanceTo(candidate);
		if (best is null || distance < bestDistance)
		{
			@best = candidate;
			bestDistance = distance;
		}
	}
	return best;
}

bool AIBIED_SendWorkshopWallPickaxe(CBlob@ this, CRules@ rules, CMap@ map)
{
	if (rules.get_string("aib infrastructure metric") != "workshops_breach") return false;
	const int anchorX = rules.get_s32("aib infrastructure anchor x");
	const int groundY = rules.get_s32("aib infrastructure ground y");
	const int direction = rules.get_s32("aib infrastructure direction");
	const u8 configuredDepth = rules.get_u8("aib infrastructure enemy wall depth");
	const u8 wallDepth = configuredDepth == 0 ? 1 : configuredDepth;
	for (u8 depth = 0; depth < wallDepth; depth++)
	{
		const int wallX = anchorX + direction * (8 - depth);
		for (int y = 1; y <= 3; y++)
		{
			Vec2f center = Vec2f(wallX * map.tilesize + map.tilesize * 0.5f,
				(groundY - y) * map.tilesize + map.tilesize * 0.5f);
			if (!map.isTileSolid(map.getTile(center).type) || (center - this.getPosition()).Length() > 40.0f) continue;
			this.setAimPos(center);
			CBitStream params;
			params.write_u16(0);
			params.write_Vec2f(center);
			this.SendCommand(this.getCommandID("pickaxe"), params);
			return true;
		}
	}
	return false;
}

void AIBIED_SendProductionPickaxe(CBlob@ this, CRules@ rules)
{
	CMap@ map = getMap();
	if (this is null || rules is null || map is null) return;
	CBlob@ door = AIBIED_ClosestProtectedDoor(this, rules);
	CBitStream params;
	if (door !is null)
	{
		this.setAimPos(door.getPosition());
		params.write_u16(door.getNetworkID());
		params.write_Vec2f(door.getPosition());
		this.SendCommand(this.getCommandID("pickaxe"), params);
		return;
	}
	if (AIBIED_SendWorkshopWallPickaxe(this, rules, map)) return;
	Vec2f direction = rules.get_Vec2f("aib infrastructure client destination") - this.getPosition();
	if (direction.Length() < 1.0f) return;
	direction.Normalize();
	const Vec2f rayEnd = this.getPosition() + direction * 36.0f;
	Vec2f surface;
	if (!map.rayCastSolid(this.getPosition(), rayEnd, surface)) return;
	const Vec2f tileTarget = surface + direction * (map.tilesize * 0.5f);
	this.setAimPos(tileTarget);
	params.write_u16(0);
	params.write_Vec2f(tileTarget);
	this.SendCommand(this.getCommandID("pickaxe"), params);
}

void onInit(CBlob@ this)
{
	this.set_u32("aib infrastructure next client pickaxe", 0);
}

void onTick(CBlob@ this)
{
	if (!isClient() || !this.isMyPlayer()) return;
	CRules@ rules = getRules();
	if (!AIBIED_IsActive(this, rules)) return;
	const u32 now = getGameTime();
	if (now < this.get_u32("aib infrastructure next client pickaxe")) return;
	this.set_u32("aib infrastructure next client pickaxe", now + AIBIED_COMMAND_INTERVAL);
	AIBIED_SendProductionPickaxe(this, rules);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (!isServer() || cmd != this.getCommandID("pickaxe")) return;
	CRules@ rules = getRules();
	if (!AIBIED_IsActive(this, rules)) return;
	if (rules.get_u32("aib infrastructure enemy command tick") == 0)
		rules.set_u32("aib infrastructure enemy command tick", getGameTime());
	rules.set_u32("aib infrastructure enemy last command tick", getGameTime());
	const u32 count = rules.get_u32("aib infrastructure enemy command count");
	if (count < 0xffffffff) rules.set_u32("aib infrastructure enemy command count", count + 1);
}
