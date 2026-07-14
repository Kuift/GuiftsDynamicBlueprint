#include "BlueprintCommon.as";

namespace AIBStrategyIntent
{
	enum intent
	{
		flag_gatehouse = 0,
		frontline_tower,
		emergency_barrier,
		archer_perch,
		access_route
	}
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
	u16 enemyFlags;
	u16 enemyTents;
	u16 enemyHalls;
	u16 enemyExplosives;
	f32 explosivePressure;
	f32 firePressure;
	f32 recentAttacks;
	u16 storedWood;
	u16 storedStone;
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
