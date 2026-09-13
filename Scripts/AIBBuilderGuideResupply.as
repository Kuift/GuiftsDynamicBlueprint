#define SERVER_ONLY

#include "AIBBuilderGuideCommon.as"

void AIBGuide_ResetResupplyTimers()
{
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (!AIBGuide_IsAutonomousBuilder(builder)) continue;
		builder.set_u32(AIB_GUIDE_RESUPPLY_NEXT_KEY, 0);
		builder.set_u32(AIB_GUIDE_RESUPPLY_LAST_KEY, 0);
		builder.set_netid(AIB_GUIDE_RESUPPLY_SOURCE_KEY, 0);
	}
}

void onInit(CRules@ this)
{
	if (isServer()) AIBGuide_ResetResupplyTimers();
}

void onRestart(CRules@ this)
{
	if (isServer()) AIBGuide_ResetResupplyTimers();
}

void onTick(CRules@ this)
{
	if (!isServer() || !AIBGuide_ResupplyEnabled(this) || getGameTime() % 15 != 5) return;
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	for (uint i = 0; i < builders.length; i++)
		AIBGuide_TryGrantResupply(this, builders[i], this.isWarmup());
}
