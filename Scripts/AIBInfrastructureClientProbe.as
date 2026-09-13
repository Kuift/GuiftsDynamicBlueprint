#define CLIENT_ONLY

// The server physically drives an unbound runner to each exact workshop, then
// briefly binds that same runner lineage to this connected player. This helper
// supplies only player-originated production input: action 0 invokes an exact
// workshop's existing "change class" command while overlapping it; action 1
// attaches the enemy probe helper that sends BuilderLogic's existing pickaxe
// command. OneClassAvailable, StandardRespawnCommand, runner collision, and
// BuilderLogic remain authoritative. No benchmark command ID or server-side hit
// shortcut is allocated.

u32 AIBIC_nextUseTick = 0;

void AIBIC_ClearKeys(CBlob@ blob)
{
	if (blob is null) return;
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	blob.setKeyPressed(key_up, false);
	blob.setKeyPressed(key_down, false);
	blob.setKeyPressed(key_action1, false);
	blob.setKeyPressed(key_action2, false);
	blob.setKeyPressed(key_action3, false);
}

void onInit(CRules@ this)
{
	AIBIC_nextUseTick = 0;
}

void onRestart(CRules@ this)
{
	AIBIC_ClearKeys(getLocalPlayerBlob());
	AIBIC_nextUseTick = 0;
}

void onTick(CRules@ this)
{
	CPlayer@ localPlayer = getLocalPlayer();
	CBlob@ blob = getLocalPlayerBlob();
	const bool active = this.get_bool("aib infrastructure client probe active");
	if (!active || localPlayer is null || localPlayer.getNetworkID() != this.get_u16("aib infrastructure probe player"))
	{
		return;
	}
	if (blob is null || blob.hasTag("dead")) return;

	const u8 action = this.get_u8("aib infrastructure client action");
	const Vec2f destination = this.get_Vec2f("aib infrastructure client destination");
	AIBIC_ClearKeys(blob);
	if (action == 1)
	{
		blob.setAimPos(destination);
		if (!blob.hasScript("AIBInfrastructureEnemyProbeDriver.as"))
			blob.AddScript("AIBInfrastructureEnemyProbeDriver.as");
		return;
	}

	const u16 targetID = this.get_u16("aib infrastructure client target");
	CBlob@ targetBlob = targetID == 0 ? null : getBlobByNetworkID(targetID);
	if (targetBlob !is null && !targetBlob.hasTag("dead") && blob.isOverlapping(targetBlob))
	{
		const string requiredClass = targetBlob.get_string("required class");
		if (requiredClass != "" && blob.getName() != requiredClass && blob.getTickSinceCreated() >= 10 &&
			getGameTime() >= AIBIC_nextUseTick)
		{
			CBitStream params;
			params.write_u8(0);
			targetBlob.SendCommand(targetBlob.getCommandID("change class"), params);
			AIBIC_nextUseTick = getGameTime() + 15;
		}
	}
}
