#define SERVER_ONLY

u32 AIBRM_lastHeartbeat = 0;
bool AIBRM_done = false;

void onInit(CRules@ this)
{
	AIBRM_lastHeartbeat = getGameTime();
	AIBRM_done = false;
	this.SetCurrentState(GAME);
	CPlayer@ clockBot = AddBot("AIBResearchClock", 0, 0);
	print("[AIBMIN] INIT gametime=" + getGameTime() +
		" clock_bot=" + (clockBot is null ? "false" : "true") +
		" players=" + getPlayersCount() +
		" sv_canpause=" + (sv_canpause ? "true" : "false") +
		" net_server=" + (getNet().isServer() ? "true" : "false") +
		" net_client=" + (getNet().isClient() ? "true" : "false") +
		" window_focused=" + (isWindowFocused() ? "true" : "false"));
}

void onRestart(CRules@ this)
{
	AIBRM_lastHeartbeat = getGameTime();
	AIBRM_done = false;
	this.SetCurrentState(GAME);
	print("[AIBMIN] RESTART gametime=" + getGameTime());
}

void onTick(CRules@ this)
{
	if (AIBRM_done) return;
	const u32 now = getGameTime();
	if (now - AIBRM_lastHeartbeat >= 30)
	{
		print("[AIBMIN] HEARTBEAT gametime=" + now +
			" window_focused=" + (isWindowFocused() ? "true" : "false"));
		AIBRM_lastHeartbeat = now;
	}
	if (now >= 90)
	{
		AIBRM_done = true;
		print("[AIBMIN] DONE gametime=" + now);
	}
}
