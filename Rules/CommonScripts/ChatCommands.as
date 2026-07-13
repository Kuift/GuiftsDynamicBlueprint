// Simple chat processing example.
// If the player sends a command, the server does what the command says.
// You can also modify the chat message before it is sent to clients by modifying text_out
// By the way, in case you couldn't tell, "mat" stands for "material(s)"

#include "MakeSeed.as";
#include "MakeCrate.as";
#include "MakeScroll.as";
#include "BlueprintCommon.as";
#include "AutoBuilderCommon.as";
#include "AIBWorldFingerprint.as";

const bool ChatCommandCoolDown = false; // enable if you want cooldown on your server
const uint ChatCommandDelay = 3 * 30; // Cooldown in seconds

CBlob@ AIBW_ArmNearestHome(const u8 team, const string &in name, Vec2f from)
{
	CBlob@[] blobs;
	getBlobsByName(name, @blobs);
	CBlob@ best = null;
	f32 bestDistance = 99999999.0f;
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ candidate = blobs[i];
		if (candidate is null || candidate.hasTag("dead") || candidate.getTeamNum() != team) continue;
		const f32 distance = (candidate.getPosition() - from).LengthSquared();
		if (distance < bestDistance) { bestDistance = distance; @best = candidate; }
	}
	return best;
}

CBlob@ AIBW_ArmTeamHome(const u8 team)
{
	CBlob@ home = AIBW_ArmNearestHome(team, "flag", Vec2f_zero);
	if (home !is null) return home;
	@home = AIBW_ArmNearestHome(team, "tent", Vec2f_zero);
	return home !is null ? home : AIBW_ArmNearestHome(team, "hall", Vec2f_zero);
}

CBlob@ AIBW_ArmEnemyHome(const u8 team, Vec2f from)
{
	string[] names = { "flag", "tent", "hall" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] homes;
		getBlobsByName(names[n], @homes);
		CBlob@ best = null;
		f32 bestDistance = 99999999.0f;
		for (uint i = 0; i < homes.length; i++)
		{
			CBlob@ candidate = homes[i];
			if (candidate is null || candidate.hasTag("dead") || candidate.getTeamNum() == team || candidate.getTeamNum() >= 100) continue;
			const f32 distance = (candidate.getPosition() - from).LengthSquared();
			if (distance < bestDistance) { bestDistance = distance; @best = candidate; }
		}
		if (best !is null) return best;
	}
	return null;
}

u16 AIBW_ArmStoredMaterial(const u8 team, const string &in material)
{
	u32 total = 0;
	string[] names = { "tent", "hall", "crate", "buildershop", "aibuilder" };
	for (uint n = 0; n < names.length; n++)
	{
		CBlob@[] blobs;
		getBlobsByName(names[n], @blobs);
		for (uint i = 0; i < blobs.length; i++)
		{
			CBlob@ storage = blobs[i];
			if (storage is null || storage.hasTag("dead") || storage.getTeamNum() != team) continue;
			CInventory@ inventory = storage.getInventory();
			if (inventory !is null) total += inventory.getCount(material);
		}
	}
	return u16(Maths::Min(total, 65535));
}

bool AIBW_CaptureArmState(CRules@ rules, const u8 team)
{
	if (rules is null) return false;
	rules.set_bool("aib wave initial captured", false);
	rules.set_string("aib wave initial fingerprint", "");
	CMap@ map = getMap();
	if (map is null || map.tilemapwidth == 0 || map.tilemapheight == 0) return false;
	CBlob@ home = AIBW_ArmTeamHome(team);
	CBlob@ enemyHome = home is null ? null : AIBW_ArmEnemyHome(team, home.getPosition());
	if (home is null || enemyHome is null) return false;

	const u32 mapHash = u32(map.getMapName().getHash());
	u32 terrainHash = 0;
	u32 solidTiles = 0;
	u32 noBuildHash = 0;
	u32 noBuildTiles = 0;
	u32 manifestBlobCount = 0;
	u32 manifestBlobHash = 0;
	u32 manifestInventoryHash = 0;
	u32 manifestStrategyHash = 0;

	u16 friendlyUnits = 0;
	u16 enemyUnits = 0;
	u16 aiBuilders = 0;
	u16 normalAIBuilderCount = 0;
	u16 autoBuilderCount = 0;
	u32 aiBuilderTypePositionHash = 0;
	CBlob@[] all;
	getBlobs(@all);
	for (uint i = 0; i < all.length; i++)
	{
		CBlob@ candidate = all[i];
		if (candidate is null || candidate.hasTag("dead")) continue;
		const string name = candidate.getName();
		const bool combatUnit = name == "builder" || name == "aibuilder" || name == "autobuilder" || name == "knight" || name == "archer";
		if (!combatUnit) continue;
		if (candidate.getTeamNum() == team)
		{
			friendlyUnits++;
			if (name == "aibuilder" || name == "autobuilder")
			{
				aiBuilders++;
				if (name == "autobuilder") autoBuilderCount++; else normalAIBuilderCount++;
				const u32 workerX = u32(Maths::Max(0, int(candidate.getPosition().x / map.tilesize)));
				const u32 workerY = u32(Maths::Max(0, int(candidate.getPosition().y / map.tilesize)));
				aiBuilderTypePositionHash += u32(name.getHash()) ^ (workerX * 73856093) ^ (workerY * 19349663);
			}
		}
		else if (candidate.getTeamNum() < 100) enemyUnits++;
	}

	CBlob@[] trees;
	getBlobsByTag("tree", @trees);
	u16 treeCount = 0;
	u32 treeHash = 0;
	for (uint i = 0; i < trees.length; i++)
	{
		CBlob@ tree = trees[i];
		if (tree is null || tree.hasTag("dead") || tree.hasTag("felldown")) continue;
		treeCount++;
		const u32 tx = u32(Maths::Max(0, int(tree.getPosition().x / map.tilesize)));
		const u32 ty = u32(Maths::Max(0, int(tree.getPosition().y / map.tilesize)));
		treeHash += ((tx + 1) * 73856093) ^ ((ty + 1) * 19349663) ^ u32(tree.get_u8("grown_times"));
	}

	const s32 homeX = s32(home.getPosition().x / map.tilesize);
	const s32 homeY = s32(home.getPosition().y / map.tilesize);
	const s32 enemyHomeX = s32(enemyHome.getPosition().x / map.tilesize);
	const s32 enemyHomeY = s32(enemyHome.getPosition().y / map.tilesize);
	const u8 autoBuilderSpeedLevel = AIBU_GetSpeedLevel(team);
	const string fixtureID = "map_" + mapHash + "_" + map.tilemapwidth + "x" + map.tilemapheight;
	const u16 fixtureVersion = 3;
	const string teamSide = homeX <= enemyHomeX ? "left" : "right";
	const u16 initialWood = AIBW_ArmStoredMaterial(team, "mat_wood");
	const u16 initialStone = AIBW_ArmStoredMaterial(team, "mat_stone");
	const u16 initialPlanID = rules.get_u16(AIBP_PlanKey(team, "id"));
	const u8 initialPlanStatus = rules.get_u8(AIBP_PlanKey(team, "status"));
	const u16 initialPlanPending = rules.get_u16(AIBP_PlanKey(team, "pending"));
	const u16 initialPlanCompleted = rules.get_u16(AIBP_PlanKey(team, "completed"));
	const string fingerprint = AIBWF_CaptureWorldManifest(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,
		manifestBlobCount, manifestBlobHash, manifestInventoryHash, manifestStrategyHash);
	if (fingerprint == "") return false;

	rules.set_string("aib wave initial fingerprint", fingerprint);
	rules.set_string("aib wave fixture id", fixtureID);
	rules.set_u16("aib wave fixture version", fixtureVersion);
	rules.set_string("aib wave team side", teamSide);
	rules.set_string("aib wave measurement fingerprint", "");
	rules.set_u32("aib wave initial map hash", mapHash);
	rules.set_u32("aib wave initial terrain hash", terrainHash);
	rules.set_u16("aib wave initial map width", map.tilemapwidth);
	rules.set_u16("aib wave initial map height", map.tilemapheight);
	rules.set_u32("aib wave initial solid tiles", solidTiles);
	rules.set_u32("aib wave initial no build hash", noBuildHash);
	rules.set_u32("aib wave initial no build tiles", noBuildTiles);
	rules.set_u32("aib wave initial manifest blob count", manifestBlobCount);
	rules.set_u32("aib wave initial manifest blob hash", manifestBlobHash);
	rules.set_u32("aib wave initial manifest inventory hash", manifestInventoryHash);
	rules.set_u32("aib wave initial manifest strategy hash", manifestStrategyHash);
	rules.set_s32("aib wave initial home x", homeX);
	rules.set_s32("aib wave initial home y", homeY);
	rules.set_s32("aib wave initial enemy home x", enemyHomeX);
	rules.set_s32("aib wave initial enemy home y", enemyHomeY);
	rules.set_u16("aib wave initial ai builders", aiBuilders);
	rules.set_u16("aib wave initial normal ai builders", normalAIBuilderCount);
	rules.set_u16("aib wave initial autobuilders", autoBuilderCount);
	rules.set_u32("aib wave initial ai builder type position hash", aiBuilderTypePositionHash);
	rules.set_u8("aib wave initial autobuilder speed level", autoBuilderSpeedLevel);
	rules.set_u16("aib wave initial friendly units", friendlyUnits);
	rules.set_u16("aib wave initial enemy units", enemyUnits);
	rules.set_u16("aib wave initial trees", treeCount);
	rules.set_u32("aib wave initial tree hash", treeHash);
	rules.set_u16("aib wave initial wood", initialWood);
	rules.set_u16("aib wave initial stone", initialStone);
	rules.set_u16("aib wave initial plan id", initialPlanID);
	rules.set_u8("aib wave initial plan status", initialPlanStatus);
	rules.set_u16("aib wave initial plan pending", initialPlanPending);
	rules.set_u16("aib wave initial plan completed", initialPlanCompleted);
	rules.set_bool("aib wave initial captured", true);
	return true;
}

void onInit(CRules@ this)
{
	this.addCommandID("SendChatMessage");
}

bool onServerProcessChat(CRules@ this, const string& in text_in, string& out text_out, CPlayer@ player)
{
	//--------MAKING CUSTOM COMMANDS-------//
	// Making commands is easy - Here's a template:
	//
	// if (text_in == "!YourCommand")
	// {
	//	// what the command actually does here
	// }
	//
	// Switch out the "!YourCommand" with
	// your command's name (i.e., !cool)
	//
	// Then decide what you want to have
	// the command do
	//
	// Here are a few bits of code you can put in there
	// to make your command do something:
	//
	// blob.server_Hit(blob, blob.getPosition(), Vec2f(0, 0), 10.0f, 0);
	// Deals 10 damage to the player that used that command (20 hearts)
	//
	// CBlob@ b = server_CreateBlob('mat_wood', -1, pos);
	// insert your blob/the thing you want to spawn at 'mat_wood'
	//
	// player.server_setCoins(player.getCoins() + 100);
	// Adds 100 coins to the player's coins
	//-----------------END-----------------//

	// cannot do commands while dead

	if (player is null)
		return true;

	// Moderator-only runtime control for KAG's TCP RCON listener. A password
	// must already be configured; accepting one through chat would leak it to logs.
	if (text_in == "!tcpr" || text_in == "!tcpr status" || text_in == "!tcpr on" || text_in == "!tcpr off")
	{
		if (!player.isMod())
		{
			SendChatMessage(this, player, "[TCPR] moderator access required", SColor(255, 255, 80, 80));
			return false;
		}

		if (text_in == "!tcpr on")
		{
			if (sv_rconpassword == "")
			{
				SendChatMessage(this, player, "[TCPR] set sv_rconpassword in KAG/autoconfig.cfg first", SColor(255, 255, 80, 80));
				return false;
			}

			SendChatMessage(this, player, "[TCPR] runtime mutation is unavailable; set sv_tcpr = 1 in autoconfig.cfg and restart", SColor(255, 255, 220, 80));
			return false;
		}

		if (text_in == "!tcpr off")
		{
			SendChatMessage(this, player, "[TCPR] runtime mutation is unavailable; set sv_tcpr = 0 in autoconfig.cfg and restart", SColor(255, 255, 220, 80));
			return false;
		}

		const string state = sv_tcpr ? "enabled" : "disabled";
		SendChatMessage(this, player, "[TCPR] " + state + " on sv_port " + sv_port, SColor(255, 100, 210, 255));
		return false;
	}

	// Only explicit moderator commands are forwarded to the local TCPR bridge.
	// Ordinary chat never leaves the game.
	if (text_in == "!codex" || text_in.substr(0, 7) == "!codex ")
	{
		if (!player.isMod())
		{
			SendChatMessage(this, player, "[Codex] moderator access required", SColor(255, 255, 80, 80));
			return false;
		}

		string request = text_in.size() > 7 ? text_in.substr(7, text_in.size() - 7) : "";
		if (request == "")
		{
			SendChatMessage(this, player, "[Codex] usage: !codex <request> | status | cancel", SColor(255, 255, 220, 80));
			return false;
		}

		if (request == "status" || request == "cancel")
		{
			tcpr("CODEX_CONTROL|" + player.getUsername() + "|" + request);
			SendChatMessage(this, player, "[Codex] " + request + " requested", SColor(255, 100, 210, 255));
			return false;
		}

		tcpr("CODEX_REQUEST|" + player.getUsername() + "|" + request);
		SendChatMessage(this, player, "[Codex] request submitted", SColor(255, 100, 210, 255));
		return false;
	}

	CBlob@ blob = player.getBlob(); // now, when the code references "blob," it means the player who called the command

	if (blob is null || text_in.substr(0, 1) != "!") // dont continue if its not a command
	{
		return true;
	}

	const Vec2f pos = blob.getPosition(); // grab player position (x, y)
	const int team = blob.getTeamNum(); // grab player team number (for i.e. making all flags you spawn be your team's flags)
	const bool isMod = player.isMod();
	const string gamemode = this.gamemode_name;
	bool wasCommandSuccessful = true; // assume command is successful 
	string errorMessage = ""; // so errors can be printed out of wasCommandSuccessful is false
	SColor errorColor = SColor(255,255,0,0); // ^

	if (!isMod && gamemode == "Sandbox" || ChatCommandCoolDown) // chat command cooldown timer
	{
		uint lastChatTime = 0;
		uint gameTime = getGameTime();
		if (blob.exists("chat_last_sent"))
		{
			lastChatTime = blob.get_u16("chat_last_sent");
			if (gameTime < lastChatTime)
			{
				return true;
			}
		}
	}

	string[]@ tokens = (text_in.substr(0, text_in.size())).split(" ");
	if(tokens.length > 0 && tokens[0] == "!aib_telemetry")
	{
		if(!player.isMod() || tokens.length != 2 || (tokens[1] != "on" && tokens[1] != "off" && tokens[1] != "status"))
		{
			SendChatMessage(this, player, "[AIB] usage: !aib_telemetry on|off|status (moderator)", SColor(255, 255, 220, 80));
			return false;
		}
		if(tokens[1] != "status") this.set_bool("aib player action log enabled", tokens[1] == "on");
		const string telemetryState = this.get_bool("aib player action log enabled") ? "on" : "off";
		SendChatMessage(this, player, "[AIB] privacy-bounded player action telemetry: " + telemetryState, SColor(255, 100, 210, 255));
		return false;
	}
	if(tokens.length > 0 && tokens[0] == "!aib_director_test")
	{
		if(!player.isMod() || team < 0 || team >= 8)
		{
			SendChatMessage(this, player, "[AIB] !aib_director_test requires a moderator on a playing team", SColor(255, 255, 220, 80));
			return false;
		}
		CBlob@[] workers;
		getBlobsByName("aibuilder", @workers);
		CBlob@ worker = null;
		for(uint i = 0; i < workers.length; i++)
		{
			if(workers[i] !is null && !workers[i].hasTag("dead") && workers[i].getTeamNum() == team) { @worker = workers[i]; break; }
		}
		if(worker is null)
		{
			@worker = server_CreateBlob("aibuilder", team, blob.getPosition());
			if(worker !is null) worker.Tag("aib director manual test worker");
		}
		this.set_u8(AIBP_ModeKey(u8(team)), AIBP_StrategyMode::auto_mode);
		this.Sync(AIBP_ModeKey(u8(team)), true);
		this.set_u32("aib strategy important event team " + team, getGameTime());
		SendChatMessage(this, player, worker is null ? "[AIB] director test worker spawn failed" : "[AIB] director test enabled; AI builder " + worker.getNetworkID() + " is ready", worker is null ? SColor(255, 255, 80, 80) : SColor(255, 100, 210, 255));
		return false;
	}
	if(tokens.length > 0 && tokens[0] == "!aib_strategy")
	{
		if(tokens.length < 2 || (tokens[1] != "off" && tokens[1] != "suggest" && tokens[1] != "auto"))
		{
			SendChatMessage(this, player, "[AIB] usage: !aib_strategy off|suggest|auto", SColor(255, 255, 220, 80));
			return false;
		}
		const u8 mode = tokens[1] == "off" ? AIBP_StrategyMode::off :
			(tokens[1] == "suggest" ? AIBP_StrategyMode::suggest : AIBP_StrategyMode::auto_mode);
		this.set_u8(AIBP_ModeKey(u8(team)), mode);
		this.Sync(AIBP_ModeKey(u8(team)), true);
		this.set_u32("aib strategy important event team " + team, getGameTime());
		SendChatMessage(this, player, "[AIB] strategy mode: " + tokens[1], SColor(255, 100, 210, 255));
		return false;
	}
	if(tokens.length > 0 && tokens[0] == "!aib_wave")
	{
		const string scenario = tokens.length >= 4 ? tokens[3] : "mixed";
		const bool validScenario = scenario == "knight" || scenario == "archer" || scenario == "bomb" || scenario == "mixed";
		if(!player.isMod() || tokens.length < 3 || (tokens[2] != "control" && tokens[2] != "plan") || !validScenario)
		{
			SendChatMessage(this, player, "[AIB] usage: !aib_wave <seed> control|plan [knight|archer|bomb|mixed] (fresh map)", SColor(255, 255, 220, 80));
			return false;
		}
		const u32 seed = parseInt(tokens[1]);
		const bool withPlan = tokens[2] == "plan";
		if(!AIBW_CaptureArmState(this, u8(team)))
		{
			SendChatMessage(this, player, "[AIB] wave not armed: map and both team homes must be ready", SColor(255, 255, 80, 80));
			return false;
		}
		this.set_u8("aib wave team", u8(team));
		this.set_u32("aib wave seed", seed);
		this.set_string("aib wave variant", tokens[2]);
		this.set_string("aib wave scenario", scenario);
		this.set_u8(AIBP_ModeKey(u8(team)), withPlan ? AIBP_StrategyMode::auto_mode : AIBP_StrategyMode::off);
		this.set_bool("aib strategy event log enabled", true);
		this.set_u32("aib wave arm tick", getGameTime() + 900);
		this.set_bool("aib wave enabled", true);
		this.set_bool("aib wave running", false);
		SendChatMessage(this, player, "[AIB] " + scenario + " wave armed; use a fresh map for the paired variant", SColor(255, 100, 210, 255));
		return false;
	}
	// commands that don't rely on sv_test being on (sv_test = 1)
	if (isMod)
	{
		if (text_in == "!bot")
		{
			AddBot("Henry");
			return true;
		}
		else if (text_in == "!debug")
		{
			CBlob@[] all;
			getBlobs(@all);

			for (u32 i = 0; i < all.length; i++)
			{
				CBlob@ blob = all[i];
				print("[" + blob.getName() + " " + blob.getNetworkID() + "] ");
			}
		}
		else if (text_in == "!endgame")
		{
			this.SetCurrentState(GAME_OVER); //go to map vote
			return true;
		}
		else if (text_in == "!startgame")
		{
			this.SetCurrentState(GAME);
			return true;
		}
		else if(text_in == "!bp_edit_toggle")
		{
			this.set_bool("blueprint_liveEdit", true);
			return true;
		}
		else if(text_in == "!bp_overseer_toggle")
		{
			this.set_bool("blueprint_Overseer_mode", true);
			return true;
		}
		else if(text_in == "!bp_overseer_none")
		{
			this.set_bool("blueprint_Overseer_none", true);
			return true;
		}
		else if(tokens[0] == "!bp_overseer_set")
		{
			string name = "guift";
			if(tokens.size()>1){name = tokens[1];}
			this.set_bool("blueprint_Overseer_set", true);
			if( getPlayerByUsername(name) == null)
			{
				print("INVALID NAME");
				CBitStream localparams;
				localparams.write_string("Error : invalid username");
				getRules().SendCommand(getRules().getCommandID("SendChatMessage"), localparams);
			}
			else
			{
				this.set_u16("Overseer_netid", getPlayerByUsername(name).getNetworkID());
			}
			return true;
		}
	}

	// spawning things

	// these all require sv_test - no spawning without it
	// some also require the player to have mod status (!spawnwater)

	if (sv_test)
	{
		if (text_in == "!tree") // pine tree (seed)
		{
			server_MakeSeed(pos, "tree_pine", 600, 1, 16);
		}
		else if (text_in == "!btree") // bushy tree (seed)
		{
			server_MakeSeed(pos, "tree_bushy", 400, 2, 16);
		}
		else if (text_in == "!allarrows") // 30 normal arrows, 2 water arrows, 2 fire arrows, 1 bomb arrow (full inventory for archer)
		{
			server_CreateBlob('mat_arrows', -1, pos);
			server_CreateBlob('mat_waterarrows', -1, pos);
			server_CreateBlob('mat_firearrows', -1, pos);
			server_CreateBlob('mat_bombarrows', -1, pos);
		}
		else if (text_in == "!arrows") // 3 mats of 30 arrows (90 arrows)
		{
			for (int i = 0; i < 3; i++)
			{
				server_CreateBlob('mat_arrows', -1, pos);
			}
		}
		else if (text_in == "!allbombs") // 2 normal bombs, 1 water bomb
		{
			for (int i = 0; i < 2; i++)
			{
				server_CreateBlob('mat_bombs', -1, pos);
			}
			server_CreateBlob('mat_waterbombs', -1, pos);
		}
		else if (text_in == "!bombs") // 3 (unlit) bomb mats
		{
			for (int i = 0; i < 3; i++)
			{
				server_CreateBlob('mat_bombs', -1, pos);
			}
		}
		else if (text_in == "!spawnwater" && player.isMod())
		{
			getMap().server_setFloodWaterWorldspace(pos, true);
		}
		/*else if (text_in == "!drink") // removes 1 water tile roughly at the player's x, y, coordinates (I notice that it favors the bottom left of the player's sprite)
		{
			getMap().server_setFloodWaterWorldspace(pos, false);
		}*/
		else if (text_in == "!seed")
		{
			// crash prevention?
		}
		else if (text_in == "!crate")
		{
			client_AddToChat("usage: !crate BLOBNAME [DESCRIPTION]", SColor(255, 255, 0, 0)); //e.g., !crate shark Your Little Darling
			server_MakeCrate("", "", 0, team, Vec2f(pos.x, pos.y - 30.0f));
		}
		else if (text_in == "!coins") // adds 100 coins to the player's coins
		{
			player.server_setCoins(player.getCoins() + 100);
		}
		else if (text_in == "!coinoverload") // + 10000 coins
		{
			player.server_setCoins(player.getCoins() + 10000);
		}
		else if (text_in == "!fishyschool") // spawns 12 fishies
		{
			for (int i = 0; i < 12; i++)
			{
				server_CreateBlob('fishy', -1, pos);
			}
		}
		else if (text_in == "!chickenflock") // spawns 12 chickens
		{
			for (int i = 0; i < 12; i++)
			{
				server_CreateBlob('chicken', -1, pos);
			}
		}
		else if (text_in == "!allmats") // 500 wood, 500 stone, 100 gold
		{
			//wood
			CBlob@ wood = server_CreateBlob('mat_wood', -1, pos);
			wood.server_SetQuantity(500); // so I don't have to repeat the server_CreateBlob line again
			//stone
			CBlob@ stone = server_CreateBlob('mat_stone', -1, pos);
			stone.server_SetQuantity(500);
			//gold
			CBlob@ gold = server_CreateBlob('mat_gold', -1, pos);
			gold.server_SetQuantity(100);
		}
		else if (text_in == "!woodstone") // 250 wood, 500 stone
		{
			server_CreateBlob('mat_wood', -1, pos);

			for (int i = 0; i < 2; i++)
			{
				server_CreateBlob('mat_stone', -1, pos);
			}
		}
		else if (text_in == "!stonewood") // 500 wood, 250 stone
		{
			server_CreateBlob('mat_stone', -1, pos);

			for (int i = 0; i < 2; i++)
			{
				server_CreateBlob('mat_wood', -1, pos);
			}
		}
		else if (text_in == "!wood") // 250 wood
		{
			server_CreateBlob('mat_wood', -1, pos);
		}
		else if (text_in == "!stones" || text_in == "!stone") // 250 stone
		{
			server_CreateBlob('mat_stone', -1, pos);
		}
		else if (text_in == "!gold") // 200 gold
		{
			for (int i = 0; i < 4; i++)
			{
				server_CreateBlob('mat_gold', -1, pos);
			}
		}
		// removed/commented out since this can easily be abused...
		/*else if (text_in == "!sharkpit") // spawns 5 sharks, perfect for making shark pits
		{
			for (int i = 0; i < 5; i++)
			{
				CBlob@ b = server_CreateBlob('shark', -1, pos);
			}
		}
		else if (text_in == "!bisonherd") // spawns 5 bisons
		{
			for (int i = 0; i < 5; i++)
			{
				CBlob@ b = server_CreateBlob('bison', -1, pos);
			}
		}*/
		else
		{
			string[]@ tokens = text_in.split(" ");

			if (tokens.length > 1)
			{
				//(see above for crate parsing example)
				if (tokens[0] == "!crate")
				{
					int frame = tokens[1] == "catapult" ? 1 : 0;
					string description = tokens.length > 2 ? tokens[2] : tokens[1];
					server_MakeCrate(tokens[1], description, frame, -1, Vec2f(pos.x, pos.y));
				}
				// eg. !team 2
				else if (tokens[0] == "!team")
				{
					// Picks team color from the TeamPalette.png (0 is blue, 1 is red, and so forth - if it runs out of colors, it uses the grey "neutral" color)
					int team = parseInt(tokens[1]);
					blob.server_setTeamNum(team);
					// We should consider if this should change the player team as well, or not.
				}
				else if (tokens[0] == "!scroll")
				{
					string s = tokens[1];
					for (uint i = 2; i < tokens.length; i++)
					{
						s += " " + tokens[i];
					}
					server_MakePredefinedScroll(pos, s);
				}
				else if(tokens[0] == "!coins")
				{
					int money = parseInt(tokens[1]);
					player.server_setCoins(money);
				}
			}
			else
			{
				string name = text_in.substr(1, text_in.size());
				if (!isMod && IsBlacklisted(name))
				{
					wasCommandSuccessful = false;
					errorMessage = "blob is currently blacklisted";
				}
				else
				{
					CBlob@ newBlob = server_CreateBlob(name, team, pos); // currently any blob made will come back with a valid pointer

					if (newBlob !is null)
					{
						if (newBlob.getName() != name)  // invalid blobs will have 'broken' names
						{
							wasCommandSuccessful = false;
							errorMessage = "blob " + text_in + " not found";
						}
					}
				}
			}
		}
	}

	if (wasCommandSuccessful)
	{
		blob.set_u16("chat_last_sent", getGameTime() + ChatCommandDelay);
	}
	else if(errorMessage != "") // send error message to client
	{
		CBitStream params;
		params.write_string(errorMessage);

		// List is reverse so we can read it correctly into SColor when reading
		params.write_u8(errorColor.getBlue());
		params.write_u8(errorColor.getGreen());
		params.write_u8(errorColor.getRed());
		params.write_u8(errorColor.getAlpha());

		this.SendCommand(this.getCommandID("SendChatMessage"), params, player);
	}

	return true;
}

bool onClientProcessChat(CRules@ this, const string& in text_in, string& out text_out, CPlayer@ player)
{
	if (text_in == "!debug" && !getNet().isServer())
	{
		// print all blobs
		CBlob@[] all;
		getBlobs(@all);

		for (u32 i = 0; i < all.length; i++)
		{
			CBlob@ blob = all[i];
			print("[" + blob.getName() + " " + blob.getNetworkID() + "] ");

			if (blob.getShape() !is null)
			{
				CBlob@[] overlapping;
				if (blob.getOverlapping(@overlapping))
				{
					for (uint i = 0; i < overlapping.length; i++)
					{
						CBlob@ overlap = overlapping[i];
						print("       " + overlap.getName() + " " + overlap.isLadder());
					}
				}
			}
		}
	}

	return true;
}


void onCommand(CRules@ this, u8 cmd, CBitStream @para)
{
	if (cmd == this.getCommandID("SendChatMessage"))
	{
		string errorMessage = para.read_string();
		SColor col = SColor(para.read_u8(), para.read_u8(), para.read_u8(), para.read_u8());
		client_AddToChat(errorMessage, col);
	}
}

void SendChatMessage(CRules@ this, CPlayer@ player, const string& in message, SColor color)
{
	CBitStream params;
	params.write_string(message);
	params.write_u8(color.getBlue());
	params.write_u8(color.getGreen());
	params.write_u8(color.getRed());
	params.write_u8(color.getAlpha());
	this.SendCommand(this.getCommandID("SendChatMessage"), params, player);
}

bool IsBlacklisted(string name)
{
	return  name=="hall" || // used to dig hole to bottom of the map, spawns lots of migrants
			name=="shark" || // greif
			name=="bison" ||
			name=="necromancer" || // annoying / grief
			name=="greg" || // annoying / grief
			name=="ctf_flag" || // sound spam
			name=="flag_base";// sound spam / grief
}
