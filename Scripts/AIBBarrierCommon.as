#include "RedBarrierCommon.as";

bool AIB_ShouldBarrier(CRules@ rules)
{
	return rules !is null && (shouldBarrier(rules) || rules.get_bool("aib test resource barrier"));
}
