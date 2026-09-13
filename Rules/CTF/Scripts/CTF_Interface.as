#include "CTF_Structs.as";

// Mod-local CTF HUD override. The base HUD stacks teams vertically according to
// their team number, which puts both flag panels in the upper-left corner.

const int CTF_HUD_MAX_FLAGS_PER_ROW = 6;
const f32 CTF_HUD_SCREEN_MARGIN = 8.0f;
const f32 CTF_HUD_PANEL_PADDING = 10.0f;
const f32 CTF_HUD_FLAG_STEP = 32.0f;
const f32 CTF_HUD_ROW_HEIGHT = 32.0f;

void onInit(CRules@ this)
{
	onRestart(this);
}

void onRestart(CRules@ this)
{
	UIData ui;
	CBlob@[] flags;
	if (getBlobsByName("ctf_flag", flags))
	{
		for (uint i = 0; i < flags.length; i++)
		{
			CBlob@ flag = flags[i];
			ui.flagIds.push_back(flag.getNetworkID());
			ui.flagStates.push_back("f");
			ui.flagTeams.push_back(flag.getTeamNum());
			ui.addTeam(flag.getTeamNum());
		}
	}

	this.set("uidata", @ui);
	CBitStream serialised = ui.serialize();
	this.set_CBitStream("ctf_serialised_team_hud", serialised);
	this.Sync("ctf_serialised_team_hud", true);
	this.set_s16("stalemate_breaker", 0);
}

void onBlobCreated(CRules@ this, CBlob@ blob)
{
	if (!getNet().isServer() || blob.getName() != "ctf_flag") return;

	UIData@ ui;
	this.get("uidata", @ui);
	if (ui is null) return;

	ui.flagIds.push_back(blob.getNetworkID());
	ui.flagStates.push_back("f");
	ui.flagTeams.push_back(blob.getTeamNum());
	ui.addTeam(blob.getTeamNum());
	CBitStream serialised = ui.serialize();
	this.set_CBitStream("ctf_serialised_team_hud", serialised);
	this.Sync("ctf_serialised_team_hud", true);
}

void onBlobDie(CRules@ this, CBlob@ blob)
{
	if (!getNet().isServer() || blob.getName() != "ctf_flag") return;

	UIData@ ui;
	this.get("uidata", @ui);
	if (ui is null) return;

	const int id = blob.getNetworkID();
	for (uint i = 0; i < ui.flagIds.length; i++)
	{
		if (ui.flagIds[i] == id) ui.flagStates[i] = "c";
	}

	CBitStream serialised = ui.serialize();
	this.set_CBitStream("ctf_serialised_team_hud", serialised);
	this.Sync("ctf_serialised_team_hud", true);
}

void onRender(CRules@ this)
{
	if (g_videorecording) return;

	CPlayer@ player = getLocalPlayer();
	if (player is null || !player.isMyPlayer()) return;

	CBitStream serialised;
	this.get_CBitStream("ctf_serialised_team_hud", serialised);
	if (serialised.getBytesUsed() > 8)
	{
		serialised.Reset();
		u16 check;
		if (serialised.saferead_u16(check) && check == 0x5afe)
		{
			while (!serialised.isBufferEnd())
			{
				CTF_HUD hud(serialised);
				CTF_DrawFlagPanel(hud);
			}
		}
		serialised.Reset();
	}

	string propname = "ctf spawn time " + player.getUsername();
	if (player.getBlob() is null && this.exists(propname))
	{
		u8 spawn = this.get_u8(propname);
		if (this.isMatchRunning() && spawn != 255)
		{
			string message = getTranslatedString("Respawning in: {SEC}").replace(
				"{SEC}", spawn > 250 ? getTranslatedString("approximatively never") : "" + spawn);
			GUI::SetFont("hud");
			GUI::DrawText(message, Vec2f(getScreenWidth() / 2 - 70,
				getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f),
				SColor(255, 255, 255, 55));
		}
	}
}

void CTF_DrawFlagPanel(CTF_HUD@ hud)
{
	if (hud is null) return;

	const string pattern = hud.flag_pattern;
	const int flagCount = int(pattern.size());
	if (flagCount <= 0) return;

	const int columns = Maths::Min(flagCount, CTF_HUD_MAX_FLAGS_PER_ROW);
	const int rows = (flagCount + CTF_HUD_MAX_FLAGS_PER_ROW - 1) / CTF_HUD_MAX_FLAGS_PER_ROW;
	const f32 panelWidth = CTF_HUD_PANEL_PADDING * 2.0f + columns * CTF_HUD_FLAG_STEP;
	const f32 panelHeight = CTF_HUD_PANEL_PADDING * 2.0f + rows * CTF_HUD_ROW_HEIGHT;
	const bool anchorRight = (hud.team_num % 2) == 1;
	const f32 panelX = anchorRight
		? getScreenWidth() - CTF_HUD_SCREEN_MARGIN - panelWidth
		: CTF_HUD_SCREEN_MARGIN;
	Vec2f panelMin = Vec2f(panelX, CTF_HUD_SCREEN_MARGIN);
	Vec2f panelMax = panelMin + Vec2f(panelWidth, panelHeight);
	GUI::DrawRectangle(panelMin, panelMax);

	for (int i = 0; i < flagCount; i++)
	{
		const int column = i % CTF_HUD_MAX_FLAGS_PER_ROW;
		const int row = i / CTF_HUD_MAX_FLAGS_PER_ROW;
		const int rowStart = row * CTF_HUD_MAX_FLAGS_PER_ROW;
		const int rowFlagCount = Maths::Min(CTF_HUD_MAX_FLAGS_PER_ROW, flagCount - rowStart);
		const f32 rowOffset = (columns - rowFlagCount) * CTF_HUD_FLAG_STEP / 2.0f;
		int frame = 0;
		const string state = pattern.substr(i, 1);
		if (state == "c") frame = 2;
		else if (state == "m") frame = getGameTime() % 20 > 10 ? 1 : 2;

		// On the right, grow toward the center so the outermost flag remains
		// visually attached to its team's screen edge.
		const int visualColumn = anchorRight ? rowFlagCount - 1 - column : column;
		Vec2f iconPos = panelMin + Vec2f(
			// CTFGui's 16x24 source frame occupies a 32-pixel-wide HUD cell
			// when drawn, so its draw origin is already the centered position.
			CTF_HUD_PANEL_PADDING + rowOffset + visualColumn * CTF_HUD_FLAG_STEP,
			CTF_HUD_PANEL_PADDING + row * CTF_HUD_ROW_HEIGHT);
		GUI::DrawIcon("Rules/CTF/CTFGui.png", frame, Vec2f(16, 24), iconPos, 1.0f, hud.team_num);
	}
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	this.SyncToPlayer("ctf_serialised_team_hud", player);
}
