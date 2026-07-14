// Low-volume authoritative action boundaries shared by gameplay producers and
// the compact public telemetry transport. Producers append fixed-width numeric
// records to CRules; AIBPlayerActionLog drains them into coarse base64 batches.
// This deliberately adds no command ID and never formats per-event strings.

namespace AIBActionActorKind
{
	enum kind
	{
		system = 0,
		player = 1,
		ai_builder = 2
	}
}

namespace AIBActionBoundary
{
	enum opcode
	{
		human_blueprint_delta = 1,
		human_blueprint_prefab,
		human_blueprint_clear,
		overseer_order,
		director_mode,
		plan_publish,
		plan_archive,
		task_reserve,
		task_complete,
		task_damage,
		purchase,
		hit,
		pickup,
		drop
	}
}

namespace AIBActionPurchase
{
	enum product
	{
		ai_builder = 1,
		autobuilder,
		autobuilder_speed
	}
}

const string AIB_ACTION_BOUNDARY_QUEUE = "aib action boundary queue";
const string AIB_ACTION_BOUNDARY_DROPPED = "aib action boundary dropped";
const uint AIB_ACTION_BOUNDARY_FIELDS = 10;
const uint AIB_ACTION_BOUNDARY_MAX_RECORDS = 256;

void AIB_ActionClearBoundaryQueue(CRules@ rules)
{
	if (rules is null) return;
	array<u32> empty;
	rules.set(AIB_ACTION_BOUNDARY_QUEUE, empty);
	rules.set_u16(AIB_ACTION_BOUNDARY_DROPPED, 0);
}

void AIB_ActionQueueBoundary(const u8 opcode, const u8 actorKind, const u16 actor,
	const u16 subject, const u8 team, const u16 x, const u16 y, const u16 detail = 0, const u16 value = 0)
{
	if (!isServer()) return;
	CRules@ rules = getRules();
	if (rules is null || !rules.get_bool("aib player action log enabled")) return;
	array<u32>@ queue = null;
	if (!rules.get(AIB_ACTION_BOUNDARY_QUEUE, @queue) || queue is null)
	{
		array<u32> fresh;
		rules.set(AIB_ACTION_BOUNDARY_QUEUE, fresh);
		rules.get(AIB_ACTION_BOUNDARY_QUEUE, @queue);
	}
	if (queue is null) return;
	if (queue.length % AIB_ACTION_BOUNDARY_FIELDS != 0)
	{
		const u16 dropped = rules.get_u16(AIB_ACTION_BOUNDARY_DROPPED);
		array<u32> empty;
		rules.set(AIB_ACTION_BOUNDARY_QUEUE, empty);
		rules.set_u16(AIB_ACTION_BOUNDARY_DROPPED, dropped == 65535 ? dropped : dropped + 1);
		return;
	}
	if (queue.length >= AIB_ACTION_BOUNDARY_MAX_RECORDS * AIB_ACTION_BOUNDARY_FIELDS)
	{
		const u16 dropped = rules.get_u16(AIB_ACTION_BOUNDARY_DROPPED);
		rules.set_u16(AIB_ACTION_BOUNDARY_DROPPED, dropped == 65535 ? dropped : dropped + 1);
		return;
	}
	queue.push_back(getGameTime());
	queue.push_back(opcode);
	queue.push_back(actorKind);
	queue.push_back(actor);
	queue.push_back(subject);
	queue.push_back(team);
	queue.push_back(x);
	queue.push_back(y);
	queue.push_back(detail);
	queue.push_back(value);
	rules.set(AIB_ACTION_BOUNDARY_QUEUE, queue);
}

void AIB_ActionBoundaryBlobTile(CBlob@ blob, u16 &out x, u16 &out y)
{
	x = 0;
	y = 0;
	CMap@ map = getMap();
	if (blob is null || map is null) return;
	Vec2f tile = map.getTileSpacePosition(blob.getPosition());
	x = u16(Maths::Max(0, Maths::Min(int(map.tilemapwidth) - 1, int(Maths::Floor(tile.x)))));
	y = u16(Maths::Max(0, Maths::Min(int(map.tilemapheight) - 1, int(Maths::Floor(tile.y)))));
}

u16 AIB_ActionArchiveReasonCode(const string &in reason)
{
	if (reason == "completed") return 1;
	if (reason == "strategically_replaced") return 2;
	if (reason == "frontline_collapse" || reason == "emergency_after_completion") return 3;
	if (reason == "invalidated") return 4;
	if (reason == "cancelled") return 5;
	if (reason == "round_reset") return 6;
	if (reason == "human_override") return 7;
	return 255;
}
