// Simple chat processing example.
// If the player sends a command, the server does what the command says.
// You can also modify the chat message before it is sent to clients by modifying text_out
// By the way, in case you couldn't tell, "mat" stands for "material(s)"

#include "MakeSeed.as";
#include "MakeCrate.as";
#include "MakeScroll.as";
#include "BlueprintCommon.as";
#include "AutoBuilderCommon.as";
#include "AIBDirectorPolicy.as";
#include "AIBTelemetryPolicy.as";
#include "AIBManualOrderCommon.as";

const bool ChatCommandCoolDown = false; // enable if you want cooldown on your server
const uint ChatCommandDelay = 3 * 30; // Cooldown in seconds

void onInit(CRules@ this)
{
	this.addCommandID("SendChatMessage");
}

bool AIB_HandleTelemetryCommand(CRules@ rules, const string &in text, CPlayer@ player)
{
	if (rules is null || player is null) return false;
	string[]@ tokens = text.split(" ");
	if (tokens.length == 0 || tokens[0] != "!aib_telemetry") return false;
	if (!player.isMod() || tokens.length != 2 ||
		(tokens[1] != "on" && tokens[1] != "off" && tokens[1] != "status"))
	{
		SendChatMessage(rules, player, "[AIB] usage: !aib_telemetry on|off|status (moderator)", SColor(255, 255, 220, 80));
		return true;
	}
	if (tokens[1] != "status")
	{
		rules.set_bool("aib player action log enabled", tokens[1] == "on");
		rules.Sync("aib player action log enabled", true);
	}
	const string telemetryState = rules.get_bool("aib player action log enabled") ? "on" : "off";
	AIBTelemetryPolicy@ telemetryPolicy = AIB_GetTelemetryPolicy();
	SendChatMessage(rules, player, "[AIB] privacy-bounded player action telemetry: " + telemetryState +
		"; CTF startup " + (telemetryPolicy.ctfEnabled ? "on" : "off") +
		"; player notice " + (telemetryPolicy.playerNoticeEnabled ? "on" : "off"), SColor(255, 100, 210, 255));
	return true;
}

bool AIB_HandleGymCommand(CRules@ rules, const string &in text, CPlayer@ player)
{
	if (rules is null || player is null) return false;
	string[]@ tokens = text.split(" ");
	if (tokens.length == 0 || tokens[0] != "!aib_gym") return false;
	if (!player.isMod())
	{
		SendChatMessage(rules, player, "[AIB Gym] moderator access required", SColor(255, 255, 80, 80));
		return true;
	}
	if (tokens.length == 2 && tokens[1] == "status")
	{
		const bool infrastructure = rules.get_bool("aib infrastructure active") || rules.get_bool("aib infrastructure request");
		SendChatMessage(rules, player, infrastructure ?
			("[AIB Gym] " + rules.get_string("aib infrastructure status") + "; run=" + rules.get_string("aib infrastructure run id")) :
			("[AIB Gym] " + rules.get_string("aib gym status") + "; run=" + rules.get_string("aib gym run id")),
			SColor(255, 100, 210, 255));
		return true;
	}
	if (tokens.length == 2 && tokens[1] == "stop")
	{
		if (rules.get_bool("aib infrastructure active") || rules.get_bool("aib infrastructure request"))
			rules.set_bool("aib infrastructure stop requested", true);
		else rules.set_bool("aib gym stop requested", true);
		SendChatMessage(rules, player, "[AIB Gym] stop requested", SColor(255, 100, 210, 255));
		return true;
	}
	if ((tokens.length == 2 || tokens.length == 3) && tokens[1] == "infrastructure")
	{
		const string infrastructureMetric = tokens.length == 3 ? tokens[2] : "gatehouse";
		if (infrastructureMetric != "gatehouse" && infrastructureMetric != "workshops" &&
			infrastructureMetric != "gatehouse_breach" && infrastructureMetric != "workshops_breach")
		{
			SendChatMessage(rules, player, "[AIB Gym] infrastructure metric must be gatehouse, workshops, gatehouse_breach, or workshops_breach", SColor(255, 255, 80, 80));
			return true;
		}
		const s8 infrastructureTeam = player.getTeamNum();
		if (infrastructureTeam < 0 || infrastructureTeam >= 8)
		{
			SendChatMessage(rules, player, "[AIB Gym] join a playing team before starting infrastructure", SColor(255, 255, 80, 80));
			return true;
		}
		if (rules.get_bool("aib gym active") || rules.get_bool("aib gym request") ||
			rules.get_bool("aib infrastructure active") || rules.get_bool("aib infrastructure request"))
		{
			SendChatMessage(rules, player, "[AIB Gym] another episode is active", SColor(255, 255, 80, 80));
			return true;
		}
		rules.set_u8("aib infrastructure team", u8(infrastructureTeam));
		rules.set_string("aib infrastructure metric", infrastructureMetric);
		rules.set_string("aib infrastructure variant", "manual");
		rules.set_string("aib infrastructure run id", "manual_infrastructure_" + getGameTime());
		rules.set_u32("aib infrastructure readiness deadline", 0);
		rules.set_bool("aib infrastructure stop requested", false);
		rules.set_bool("aib infrastructure request", true);
		SendChatMessage(rules, player, "[AIB Gym] physical " + infrastructureMetric + " episode requested", SColor(255, 100, 210, 255));
		return true;
	}
	if (tokens.length < 4 || tokens.length > 5 || tokens[1] != "resources")
	{
		SendChatMessage(rules, player, "[AIB Gym] usage: !aib_gym resources 1|4 wood|stone|mixed [10-180 seconds] | infrastructure [gatehouse|workshops|gatehouse_breach|workshops_breach] | status | stop", SColor(255, 255, 220, 80));
		return true;
	}
	const s8 team = player.getTeamNum();
	const int builders = parseInt(tokens[2]);
	const string order = tokens[3];
	const int seconds = tokens.length == 5 ? parseInt(tokens[4]) : 180;
	if (team < 0 || team >= 8 || (builders != 1 && builders != 4) ||
		(order != "wood" && order != "stone" && order != "mixed") || (order == "mixed" && builders != 4) ||
		seconds < 10 || seconds > 180)
	{
		SendChatMessage(rules, player, "[AIB Gym] invalid request; mixed requires four builders and duration must be 10-180 seconds", SColor(255, 255, 80, 80));
		return true;
	}
	if (rules.get_bool("aib gym active") || rules.get_bool("aib gym request"))
	{
		SendChatMessage(rules, player, "[AIB Gym] another episode is active", SColor(255, 255, 80, 80));
		return true;
	}
	rules.set_u8("aib gym team", u8(team));
	rules.set_u8("aib gym builder count", u8(builders));
	rules.set_string("aib gym resource order", order);
	rules.set_u32("aib gym duration ticks", u32(seconds * 30));
	rules.set_string("aib gym variant", "manual");
	rules.set_string("aib gym run id", "manual_" + getGameTime());
	rules.set_bool("aib gym stop requested", false);
	rules.set_bool("aib gym request", true);
	SendChatMessage(rules, player, "[AIB Gym] map-scoped " + seconds + "s resource episode requested for " + builders + " builder(s)", SColor(255, 100, 210, 255));
	return true;
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
	if (AIB_HandleTelemetryCommand(this, text_in, player)) return false;
	if (AIB_HandleGymCommand(this, text_in, player)) return false;

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
		AIBM_ReleaseTeamManualControl(u8(team));
		this.set_u32("aib strategy important event team " + team, getGameTime());
		SendChatMessage(this, player, worker is null ? "[AIB] director test worker spawn failed" : "[AIB] director test enabled; AI builder " + worker.getNetworkID() + " is ready", worker is null ? SColor(255, 255, 80, 80) : SColor(255, 100, 210, 255));
		return false;
	}
	if(tokens.length > 0 && tokens[0] == "!aib_bootstrap")
	{
		if(!player.isMod() || team < 0 || team >= 8 || tokens.length != 2 ||
			(tokens[1] != "on" && tokens[1] != "off" && tokens[1] != "status"))
		{
			SendChatMessage(this, player, "[AIB] usage: !aib_bootstrap on|off|status (moderator on a playing team)", SColor(255, 255, 220, 80));
			return false;
		}

		const string enabledKey = AIBS_BootstrapKey(u8(team), "enabled");
		if(tokens[1] != "status")
		{
			this.set_bool(enabledKey, tokens[1] == "on");
			this.Sync(enabledKey, true);
			if(tokens[1] == "on") this.set_u32("aib strategy important event team " + team, getGameTime());
		}
		const bool enabled = this.get_bool(enabledKey);
		const bool provisioned = this.get_bool(AIBS_BootstrapKey(u8(team), "provisioned"));
		const u32 retryAt = this.get_u32(AIBS_BootstrapKey(u8(team), "next retry"));
		const u32 retryTicks = retryAt > getGameTime() ? retryAt - getGameTime() : 0;
		SendChatMessage(this, player, "[AIB] team " + team + " free bootstrap: " + (enabled ? "on" : "off") +
			"; round grant " + (provisioned ? "used" : "available") +
			(retryTicks > 0 ? "; retry in " + retryTicks + " ticks" : ""), SColor(255, 100, 210, 255));
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
		if(mode == AIBP_StrategyMode::auto_mode) AIBM_ReleaseTeamManualControl(u8(team));
		this.set_u32("aib strategy important event team " + team, getGameTime());
		SendChatMessage(this, player, "[AIB] strategy mode: " + tokens[1], SColor(255, 100, 210, 255));
		return false;
	}
	if(tokens.length > 0 && tokens[0] == "!aib_wave")
	{
		const string scenario = tokens.length >= 4 ? tokens[3] : "mixed";
		const bool validScenario = scenario == "knight" || scenario == "archer" || scenario == "bomb" || scenario == "mixed";
		if(!player.isMod() || team < 0 || team > 1 || tokens.length < 3 ||
			(tokens[2] != "control" && tokens[2] != "plan") || !validScenario)
		{
			SendChatMessage(this, player, "[AIB] usage: !aib_wave <seed> control|plan [knight|archer|bomb|mixed] (fresh map)", SColor(255, 255, 220, 80));
			return false;
		}
		const u32 seed = parseInt(tokens[1]);
		if(this.get_bool("aib wave request") || this.get_bool("aib wave enabled") || this.get_bool("aib wave running"))
		{
			SendChatMessage(this, player, "[AIB] another wave request or episode is active", SColor(255, 255, 80, 80));
			return false;
		}
		this.set_u8("aib wave request team", u8(team));
		this.set_u32("aib wave request seed", seed);
		this.set_string("aib wave request variant", tokens[2]);
		this.set_string("aib wave request scenario", scenario);
		this.set_string("aib wave request run id", "");
		this.set_bool("aib wave request", true);
		SendChatMessage(this, player, "[AIB] " + scenario + " wave requested; use a fresh sv_test CTF map for the paired variant", SColor(255, 100, 210, 255));
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
