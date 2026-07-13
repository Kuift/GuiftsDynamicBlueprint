#define SERVER_ONLY

#include "AIBStrategicJobs.as";

const u32 AIBDEV_SETUP_AFTER = 60;
const u32 AIBDEV_TIMEOUT = 1800;

void onInit(CRules@ this)
{
	if (!isServer()) return;
	this.set_bool("aib dev scenario setup", false);
	this.set_bool("aib dev scenario done", false);
	this.set_string("aib dev scenario signature", "");
}

CBlob@ AIBDEV_GetWorker()
{
	CBlob@[] workers;
	getBlobsByName("aibuilder", @workers);
	for (uint i = 0; i < workers.length; i++)
	{
		CBlob@ worker = workers[i];
		if (worker !is null && !worker.hasTag("dead") && worker.getTeamNum() == 0 && worker.hasTag("aib developer forced worker")) return worker;
	}
	return null;
}

CBlob@ AIBDEV_GetHome()
{
	string[] names = { "tent", "hall", "flag" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] homes;
		getBlobsByName(names[n], @homes);
		for (uint i = 0; i < homes.length; i++)
		{
			CBlob@ home = homes[i];
			if (home !is null && !home.hasTag("dead") && home.getTeamNum() == 0) return home;
		}
	}
	return null;
}

bool AIBDEV_FindSupportScenario(CBlob@ home, u16 &out tileX, u16 &out targetY, u16 &out supportY)
{
	CMap@ map = getMap();
	if (home is null || map is null) return false;
	const Vec2f homeSpace = map.getTileSpacePosition(home.getPosition());
	const int homeX = Maths::Floor(homeSpace.x);
	for (int distance = 10; distance <= 28; distance++)
	{
		for (int side = 1; side >= -1; side -= 2)
		{
			const int x = homeX + side * distance;
			if (x < 3 || x >= map.tilemapwidth - 3) continue;
			for (int y = 4; y < map.tilemapheight - 2; y++)
			{
				Vec2f anchor = Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize);
				Vec2f support = anchor - Vec2f(0.0f, map.tilesize);
				Vec2f target = support - Vec2f(0.0f, map.tilesize);
				if (!map.isTileSolid(map.getTile(anchor).type)) continue;
				if (map.isTileSolid(map.getTile(support).type) || map.isTileSolid(map.getTile(target).type)) continue;
				if (map.getSectorAtPosition(support, "no build") !is null || map.getSectorAtPosition(target, "no build") !is null) continue;
				if (AIBS_OverlapsProtectedBlob(0, support) || AIBS_OverlapsProtectedBlob(0, target)) continue;
				tileX = u16(x);
				targetY = u16(y - 2);
				supportY = u16(y - 1);
				return true;
			}
		}
	}
	return false;
}

void AIBDEV_GiveStone(CBlob@ worker, const u16 quantity)
{
	if (worker is null) return;
	CBlob@ stone = server_CreateBlob("mat_stone", worker.getTeamNum(), worker.getPosition());
	if (stone is null) return;
	stone.server_SetQuantity(quantity);
	worker.server_PutInInventory(stone);
}

void AIBDEV_RecordDelta(CRules@ rules, CBlob@ worker)
{
	CMap@ map = getMap();
	if (rules is null || worker is null || map is null) return;
	const u16 x = rules.get_u16("aib dev target x");
	const u16 targetY = rules.get_u16("aib dev target y");
	const u16 supportY = rules.get_u16("aib dev support y");
	const TileType targetType = map.getTile(Vec2f((x + 0.5f) * map.tilesize, (targetY + 0.5f) * map.tilesize)).type;
	const TileType supportType = map.getTile(Vec2f((x + 0.5f) * map.tilesize, (supportY + 0.5f) * map.tilesize)).type;
	const string signature = "state=" + worker.get_u8("ai builder state") + " target=" + targetType +
		" support=" + supportType + " stone=" + AIBDEV_CountStone(worker);
	if (signature == rules.get_string("aib dev scenario signature")) return;
	rules.set_string("aib dev scenario signature", signature);
	AIBS_Log("dev_support_delta", 0, "builder=" + worker.getNetworkID() + " x=" + x + " target_y=" + targetY +
		" support_y=" + supportY + " " + signature);
}

u16 AIBDEV_CountStone(CBlob@ worker)
{
	if (worker is null) return 0;
	u16 count = 0;
	CInventory@ inv = worker.getInventory();
	if (inv !is null) count += inv.getCount("mat_stone");
	CBlob@ carried = worker.getCarriedBlob();
	if (carried !is null && carried.getName() == "mat_stone") count += carried.getQuantity();
	return count;
}

void onTick(CRules@ this)
{
	if (!isServer() || this.get_bool("aib dev scenario done") || getGameTime() < AIBDEV_SETUP_AFTER) return;
	CBlob@ worker = AIBDEV_GetWorker();
	if (worker is null) return;

	if (!this.get_bool("aib dev scenario setup"))
	{
		CBlob@ home = AIBDEV_GetHome();
		u16 x = 0, targetY = 0, supportY = 0;
		if (home is null || !AIBDEV_FindSupportScenario(home, x, targetY, supportY)) return;
		// Isolate the smoke blueprint from autonomous ai_work while retaining the
		// director's visible suggestion.  The developer scenario owns this tagged
		// worker after its current resource episode reaches a safe handoff.
		this.set_u8(AIBP_ModeKey(0), AIBP_StrategyMode::suggest);
		this.set_u8("aib strategy last mode team 0", AIBP_StrategyMode::suggest);
		this.Sync(AIBP_ModeKey(0), true);
		AIBP_SetAIWorkEnabled(0, false);
		if (!AIBP_SetHumanTile(0, x, targetY, AIBP_STONE_BLOCK)) return;
		worker.Tag("aib developer scenario role locked");
		AIBDEV_GiveStone(worker, 100);
		const u16 initialStone = AIBDEV_CountStone(worker);
		this.set_u16("aib dev target x", x);
		this.set_u16("aib dev target y", targetY);
		this.set_u16("aib dev support y", supportY);
		this.set_u16("aib dev initial stone", initialStone);
		this.set_u32("aib dev scenario started", getGameTime());
		this.set_bool("aib dev scenario setup", true);
		AIBS_Log("dev_support_setup", 0, "builder=" + worker.getNetworkID() + " x=" + x + " target_y=" + targetY +
			" support_y=" + supportY + " initial_stone=" + initialStone);
	}

	AIBS_SetBuilderJob(worker, AIBS_JOB_BLUEPRINT, AIBS_STATE_COLLECT_BLUEPRINT);
	AIBDEV_RecordDelta(this, worker);
	CMap@ map = getMap();
	const u16 x = this.get_u16("aib dev target x");
	const u16 targetY = this.get_u16("aib dev target y");
	const u16 supportY = this.get_u16("aib dev support y");
	const TileType targetType = map.getTile(Vec2f((x + 0.5f) * map.tilesize, (targetY + 0.5f) * map.tilesize)).type;
	const TileType supportType = map.getTile(Vec2f((x + 0.5f) * map.tilesize, (supportY + 0.5f) * map.tilesize)).type;
	const u16 expectedStone = this.get_u16("aib dev initial stone") - AIBP_BlockCost(AIBP_STONE_BACKWALL) - AIBP_BlockCost(AIBP_STONE_BLOCK);
	if (targetType == CMap::tile_castle && supportType == CMap::tile_castle_back && AIBDEV_CountStone(worker) == expectedStone)
	{
		this.set_bool("aib dev scenario done", true);
		print("[AIBDEV] PASS generated_backwall_support builder=" + worker.getNetworkID() + " x=" + x +
			" target_y=" + targetY + " support_y=" + supportY + " remaining_stone=" + expectedStone);
		return;
	}
	if (getGameTime() - this.get_u32("aib dev scenario started") > AIBDEV_TIMEOUT)
	{
		this.set_bool("aib dev scenario done", true);
		print("[AIBDEV] FAIL generated_backwall_support state=" + worker.get_u8("ai builder state") +
			" target=" + targetType + " support=" + supportType + " stone=" + AIBDEV_CountStone(worker));
	}
}
