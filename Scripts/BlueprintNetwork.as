#include "BlueprintData.as";

const u32 AIBP_EDIT_RATE_TICKS = 2;

bool AIBP_ServerCanEdit(const u16 playerNetID, const u8 team)
{
	CPlayer@ player = getPlayerByNetworkId(playerNetID);
	if (player is null) return false;
	if (team >= 8 || player.getTeamNum() >= 8) return false;
	if (player.getTeamNum() != team && player.getTeamNum() < 100) return false;
	if (!AIB_ServerCanUseBlueprintControls(playerNetID)) return false;
	CRules@ rules = getRules();
	if (rules is null) return false;
	const string rateKey = "aib blueprint last edit player " + playerNetID;
	const u32 last = rules.get_u32(rateKey);
	if (last != 0 && getGameTime() < last + AIBP_EDIT_RATE_TICKS) return false;
	rules.set_u32(rateKey, getGameTime());
	return true;
}

bool AIBP_ServerApplyHumanDelta(const u16 playerNetID, const u16 x, const u16 y,
	const u16 value, const u16 expectedVersion = 0xffff)
{
	CPlayer@ player = getPlayerByNetworkId(playerNetID);
	if (player is null) return false;
	const u8 team = u8(player.getTeamNum());
	if (expectedVersion != 0xffff && getRules().get_u16(AIBP_PlanKey(team, "human version")) != expectedVersion)
	{
		AIBP_SendDisplaySnapshot(playerNetID, team);
		return false;
	}
	if (!AIBP_ServerCanEdit(playerNetID, team)) return false;
	const bool changed = AIBP_SetHumanTile(team, x, y, value, expectedVersion);
	if (changed)
	{
		AIB_ActionQueueBoundary(AIBActionBoundary::human_blueprint_delta, AIBActionActorKind::player,
			playerNetID, getRules().get_u16(AIBP_PlanKey(team, "human version")), team, x, y, value, 0);
	}
	return changed;
}

bool AIBP_ServerApplyHumanPrefab(const u16 playerNetID, const u16 expectedVersion,
	const u16 centerX, const u16 centerY, const u16 width, const u16 height, uint16[][] &source)
{
	if (!AIBP_IsPrefabSizeValid(width, height)) return false;
	CPlayer@ player = getPlayerByNetworkId(playerNetID);
	if (player is null) return false;
	const u8 team = u8(player.getTeamNum());
	if (getRules().get_u16(AIBP_PlanKey(team, "human version")) != expectedVersion)
	{
		AIBP_SendDisplaySnapshot(playerNetID, team);
		return false;
	}
	if (!AIBP_ServerCanEdit(playerNetID, team)) return false;
	const bool changed = AIBP_ApplyHumanPlacement(team, centerX, centerY, width, height, source);
	if (changed)
	{
		AIB_ActionQueueBoundary(AIBActionBoundary::human_blueprint_prefab, AIBActionActorKind::player,
			playerNetID, getRules().get_u16(AIBP_PlanKey(team, "human version")), team,
			centerX, centerY, width, height);
	}
	return changed;
}

void AIBP_ServerClearHumanLayer(const u16 playerNetID)
{
	CPlayer@ player = getPlayerByNetworkId(playerNetID);
	if (player is null) return;
	const u8 team = u8(player.getTeamNum());
	if (!AIBP_ServerCanEdit(playerNetID, team)) return;
	array<u16> empty;
	AIBP_NewEmptyGrid(empty);
	getRules().set(AIBP_LayerDataKey(team, AIBP_Layer::human), empty);
	getRules().set_u16(AIBP_PlanKey(team, "human version"), getRules().get_u16(AIBP_PlanKey(team, "human version")) + 1);
	getRules().Sync(AIBP_PlanKey(team, "human version"), true);
	AIBP_RebuildCompatibility(team, false);
	AIBP_SendDisplaySnapshot(0, team);
	AIB_ActionQueueBoundary(AIBActionBoundary::human_blueprint_clear, AIBActionActorKind::player,
		playerNetID, getRules().get_u16(AIBP_PlanKey(team, "human version")), team, 0, 0, 0, 0);
	AIBS_Log("human_clear", team, "player=" + playerNetID);
}
