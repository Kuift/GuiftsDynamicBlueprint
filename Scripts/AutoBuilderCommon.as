const string AIBU_ENTITY_NAME = "autobuilder";
const string AIBU_SPEED_LEVEL_PREFIX = "autobuilder speed level team ";
const u8 AIBU_MAX_SPEED_LEVEL = 3;
const u16 AIBU_SPEED_UPGRADE_GOLD_COST = 50;
const u8 AIBU_PLACE_DELAY_TICKS = 30;

string AIBU_SpeedLevelKey(const u8 team)
{
	return AIBU_SPEED_LEVEL_PREFIX + int(team);
}

bool AIBU_IsAutoBuilder(CBlob@ blob)
{
	return blob !is null && blob.getName() == AIBU_ENTITY_NAME;
}

void AIBU_InitSpeedPolicy(CRules@ rules, const u8 team)
{
	if (rules is null || team >= 8) return;
	const string key = AIBU_SpeedLevelKey(team);
	if (isServer())
	{
		if (!rules.exists(key)) rules.set_u8(key, 0);
		rules.Sync(key, true);
	}
}

void AIBU_ResetSpeedLevel(CRules@ rules, const u8 team)
{
	if (rules is null || team >= 8) return;
	rules.set_u8(AIBU_SpeedLevelKey(team), 0);
	if (isServer()) rules.Sync(AIBU_SpeedLevelKey(team), true);
}

u8 AIBU_GetSpeedLevel(const u8 team)
{
	CRules@ rules = getRules();
	if (rules is null || team >= 8) return 0;
	return Maths::Min(AIBU_MAX_SPEED_LEVEL, rules.get_u8(AIBU_SpeedLevelKey(team)));
}

void AIBU_SetSpeedLevel(CRules@ rules, const u8 team, const u8 level)
{
	if (rules is null || team >= 8) return;
	rules.set_u8(AIBU_SpeedLevelKey(team), Maths::Min(AIBU_MAX_SPEED_LEVEL, level));
	if (isServer()) rules.Sync(AIBU_SpeedLevelKey(team), true);
}

f32 AIBU_GetFlightSpeed(const u8 team)
{
	switch (AIBU_GetSpeedLevel(team))
	{
		case 1: return 6.0f;
		case 2: return 8.0f;
		case 3: return 12.0f;
	}
	return 4.0f;
}

string AIBU_GetFlightSpeedLabel(const u8 team)
{
	return "Level " + AIBU_GetSpeedLevel(team) + "/" + AIBU_MAX_SPEED_LEVEL +
		" (" + AIBU_GetFlightSpeed(team) + " px/tick)";
}
