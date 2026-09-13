#include "BlueprintCommon.as";

namespace AIBStrategyIntent
{
	enum intent
	{
		flag_gatehouse = 0,
		frontline_tower,
		emergency_barrier,
		archer_perch,
		access_route,
		protected_workshops,
		guide_flag_room,
		guide_home_tunnel,
		guide_quarry_storage,
		guide_front_tunnel
	}
}

// Chapter 1 structures are an ordered production curriculum, not merely score
// suggestions competing with the older experimental templates.  Keep the
// stable intent values above for archived telemetry while mapping them onto the
// current guide sequence here.
namespace AIBGuideStage
{
	enum stage
	{
		home_core = 0,
		frontline_tower,
		protected_shops,
		home_tunnel,
		front_tunnel,
		quarry_storage,
		count,
		none = 255
	}
}

const u8 AIBS_GUIDE_POLICY_VERSION = 2;

u8 AIBS_GuideStageForIntent(const u8 intent)
{
	if (intent == AIBStrategyIntent::guide_flag_room) return AIBGuideStage::home_core;
	if (intent == AIBStrategyIntent::frontline_tower) return AIBGuideStage::frontline_tower;
	if (intent == AIBStrategyIntent::protected_workshops) return AIBGuideStage::protected_shops;
	if (intent == AIBStrategyIntent::guide_home_tunnel) return AIBGuideStage::home_tunnel;
	if (intent == AIBStrategyIntent::guide_front_tunnel) return AIBGuideStage::front_tunnel;
	if (intent == AIBStrategyIntent::guide_quarry_storage) return AIBGuideStage::quarry_storage;
	return AIBGuideStage::none;
}

string AIBS_GuideStageName(const u8 stage)
{
	if (stage == AIBGuideStage::home_core) return "home core";
	if (stage == AIBGuideStage::frontline_tower) return "frontline tower";
	if (stage == AIBGuideStage::protected_shops) return "protected shops";
	if (stage == AIBGuideStage::home_tunnel) return "home tunnel";
	if (stage == AIBGuideStage::front_tunnel) return "front tunnel";
	if (stage == AIBGuideStage::quarry_storage) return "quarry storage";
	return "";
}

string AIBS_GuideStageKey(const u8 team, const u8 stage)
{
	return "aib guide completed " + AIBS_GuideStageName(stage) + " team " + int(team);
}

bool AIBS_GuideStageComplete(CRules@ rules, const u8 team, const u8 stage)
{
	return rules !is null && stage < AIBGuideStage::count && rules.get_bool(AIBS_GuideStageKey(team, stage));
}

u8 AIBS_FirstIncompleteGuideStage(CRules@ rules, const u8 team)
{
	for (u8 stage = 0; stage < AIBGuideStage::count; stage++)
	{
		if (!AIBS_GuideStageComplete(rules, team, stage)) return stage;
	}
	return AIBGuideStage::none;
}

bool AIBS_IsLegacyProductionIntent(const u8 intent)
{
	return intent == AIBStrategyIntent::flag_gatehouse ||
		intent == AIBStrategyIntent::archer_perch ||
		intent == AIBStrategyIntent::access_route;
}

class BlueprintTask
{
	u16 x;
	u16 y;
	u16 block;
	u8 phase;
	u8 state;
	u16 reservedBy;
	u32 reservedUntil;

	BlueprintTask() {}
	BlueprintTask(const u16 _x, const u16 _y, const u16 _block, const u8 _phase)
	{
		x = _x; y = _y; block = _block; phase = _phase;
		state = AIBP_TaskState::pending;
		reservedBy = 0; reservedUntil = 0;
	}
}

class BlueprintPlan
{
	u16 id;
	u16 version;
	u8 team;
	u8 owner;
	u8 intent;
	u8 status;
	string templateName;
	Vec2f anchor;
	f32 score;
	string reasons;
	u32 createdAt;
	u32 updatedAt;
	array<BlueprintTask@> tasks;
}

class AIBWorldState
{
	u8 team;
	Vec2f home;
	Vec2f resourceHome;
	u16 resourceHomeID;
	Vec2f enemyHome;
	Vec2f frontline;
	s8 enemyDirection;
	u16 friendlyKnights;
	u16 friendlyArchers;
	u16 friendlyBuilders;
	u16 aiBuilders;
	u16 autoBuilders;
	u16 aiWoodJobs;
	u16 aiStoneJobs;
	u16 aiBuildJobs;
	u16 enemyKnights;
	u16 enemyArchers;
	u16 enemyBuilders;
	u16 friendlyFlags;
	u16 friendlyTents;
	u16 friendlyHalls;
	u16 friendlyQuarries;
	u16 enemyFlags;
	u16 enemyTents;
	u16 enemyHalls;
	u16 enemyExplosives;
	f32 explosivePressure;
	f32 firePressure;
	f32 recentAttacks;
	u16 storedWood;
	u16 storedStone;
	u16 storedGold;
	u16 planPending;
	u16 planCompleted;
	u16 planDamaged;
	f32 pressure;
	u16 homeLaneWidth;
	u16 frontlineLaneWidth;
	u16 frontlineWallHeight;
	f32 frontlineChokepointValue;
	bool frontlineAdvancing;
	bool frontlineCollapsing;
	array<Vec2f> friendlyHomes;
	array<Vec2f> enemyHomes;
}

class AIBPlanCandidate
{
	u8 intent;
	string templateName;
	Vec2f anchor;
	f32 score;
	string reasons;
	string rejection;
	array<BlueprintTask@> tasks;
}
