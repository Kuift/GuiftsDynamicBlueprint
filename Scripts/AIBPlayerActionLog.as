// Compact server-side player demonstration capture.
//
// Records are binary delta frames in memory and are flushed once per ten
// seconds (or when the batch reaches 2 KiB) as one base64 console record.
// KAG exposes no safe persistent binary-file writer to AngelScript, so base64
// is only the transport envelope; Tools/parse_aib_player_actions.ps1 restores
// the original bytes. No per-tick/per-player strings are printed.

#include "AIBActionBoundaryCommon.as";

const u8 AIB_ACTION_SCHEMA_VERSION = 3;
const u32 AIB_ACTION_FRAME_TICKS = 30;
const u32 AIB_ACTION_AIM_SAMPLE_TICKS = 5;
const u32 AIB_ACTION_FLUSH_TICKS = 300;
const uint AIB_ACTION_MAX_BATCH_BYTES = 2048;

u8[] aibActionBytes;
u16 aibActionRecords = 0;
u32 aibActionLastRecordTick = 0;
u32 aibActionLastFlushTick = 0;
u32 aibActionBatchSequence = 0;

string AIB_ActionKey(const u16 playerNetID, const string &in field)
{
	return "aib action player " + playerNetID + " " + field;
}

void AIB_ActionByte(const u8 value) { aibActionBytes.push_back(value); }
void AIB_ActionU16(const u16 value)
{
	AIB_ActionByte(u8(value & 0xff));
	AIB_ActionByte(u8((value >> 8) & 0xff));
}
void AIB_ActionS16(const s16 value) { AIB_ActionU16(u16(value)); }
void AIB_ActionU32(const u32 value)
{
	AIB_ActionU16(u16(value & 0xffff));
	AIB_ActionU16(u16((value >> 16) & 0xffff));
}

u16 AIB_ActionTickDelta()
{
	const u32 now = getGameTime();
	const u32 elapsed = now - aibActionLastRecordTick;
	aibActionLastRecordTick = now;
	return u16(Maths::Min(elapsed, 65535));
}

s8 AIB_ActionClampS8(const s32 value)
{
	return s8(Maths::Max(-127, Maths::Min(127, value)));
}

u8 AIB_ActionClass(CBlob@ blob)
{
	if (blob is null) return 0;
	const string name = blob.getName();
	if (name == "builder") return 1;
	if (name == "knight") return 2;
	if (name == "archer") return 3;
	return 0;
}

u8 AIB_ActionEntityClass(CBlob@ blob)
{
	if (blob is null) return 0;
	if (blob.hasTag("player") || AIB_ActionClass(blob) != 0) return 1;
	if (blob.hasTag("material")) return 2;
	if (blob.hasTag("building") || blob.hasTag("structure")) return 3;
	if (blob.hasTag("tree") || blob.getName() == "log") return 4;
	if (blob.hasTag("projectile")) return 6;
	if (blob.isCollidable()) return 5;
	return 0;
}

bool AIB_ActionImportantBlob(CBlob@ blob)
{
	if (blob is null) return false;
	const u8 kind = AIB_ActionEntityClass(blob);
	if (kind == 1 || kind == 2 || kind == 3 || kind == 4) return true;
	const string name = blob.getName();
	return name == "crate" || name == "ladder" || name == "wooden_door" || name == "stone_door" ||
		name == "wooden_platform" || name == "bridge" || name == "spikes" || name == "bomb" ||
		name == "waterbomb" || name == "mine" || name == "keg";
}

CPlayer@ AIB_ActionAttributingPlayer(Vec2f position, u8 &out confidence)
{
	confidence = 0;
	CPlayer@ best = null;
	f32 bestScore = 999999.0f;
	for (int i = 0; i < getPlayersCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player is null) continue;
		CBlob@ actor = player.getBlob();
		if (actor is null || actor.hasTag("dead")) continue;
		const f32 distance = (actor.getPosition() - position).Length();
		const bool acting = actor.isKeyPressed(key_action1) || actor.isKeyPressed(key_action2) || actor.isKeyPressed(key_action3);
		if (!acting && distance > 24.0f) continue;
		if (acting && distance > 64.0f) continue;
		const f32 score = distance + (acting ? 0.0f : 64.0f);
		if (score >= bestScore) continue;
		bestScore = score;
		@best = player;
		confidence = acting ? 2 : 1;
	}
	return best;
}

u16 AIB_ActionInventoryCount(CBlob@ blob, const string &in name)
{
	if (blob is null) return 0;
	u16 count = 0;
	CInventory@ inv = blob.getInventory();
	if (inv !is null) count += inv.getCount(name);
	CBlob@ carried = blob.getCarriedBlob();
	if (carried !is null && carried.getName() == name)
		count += carried.hasTag("material") ? carried.getQuantity() : 1;
	return count;
}

u8 AIB_ActionInputMask(CBlob@ blob)
{
	if (blob is null) return 0;
	u8 mask = 0;
	if (blob.isKeyPressed(key_left)) mask |= 1;
	if (blob.isKeyPressed(key_right)) mask |= 2;
	if (blob.isKeyPressed(key_up)) mask |= 4;
	if (blob.isKeyPressed(key_down)) mask |= 8;
	if (blob.isKeyPressed(key_action1)) mask |= 16;
	if (blob.isKeyPressed(key_action2)) mask |= 32;
	if (blob.isKeyPressed(key_action3)) mask |= 64;
	return mask;
}

string AIB_ActionBase64()
{
	const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	string result = "";
	for (uint i = 0; i < aibActionBytes.length; i += 3)
	{
		const u32 a = aibActionBytes[i];
		const bool hasB = i + 1 < aibActionBytes.length;
		const bool hasC = i + 2 < aibActionBytes.length;
		const u32 b = hasB ? aibActionBytes[i + 1] : 0;
		const u32 c = hasC ? aibActionBytes[i + 2] : 0;
		const u32 packed = (a << 16) | (b << 8) | c;
		result += alphabet.substr((packed >> 18) & 63, 1);
		result += alphabet.substr((packed >> 12) & 63, 1);
		result += hasB ? alphabet.substr((packed >> 6) & 63, 1) : "=";
		result += hasC ? alphabet.substr(packed & 63, 1) : "=";
	}
	return result;
}

void AIB_ActionFlush(CRules@ rules, const string &in reason)
{
	if (!isServer() || rules is null || aibActionBytes.length == 0) return;
	aibActionBatchSequence++;
	print("[AIBACT] v=" + AIB_ACTION_SCHEMA_VERSION + " episode=" + rules.get_u32("aib action episode") +
		" batch=" + aibActionBatchSequence + " records=" + aibActionRecords + " reason=" + reason +
		" data=" + AIB_ActionBase64());
	aibActionBytes.clear();
	aibActionRecords = 0;
	aibActionLastFlushTick = getGameTime();
}

void AIB_ActionRecordHeader(const u8 kind)
{
	AIB_ActionByte(kind);
	AIB_ActionU16(AIB_ActionTickDelta());
	aibActionRecords++;
}

void AIB_ActionDrainBoundaries(CRules@ rules)
{
	if (rules is null) return;
	array<u32>@ queue = null;
	const bool hasQueue = rules.get(AIB_ACTION_BOUNDARY_QUEUE, @queue) && queue !is null;
	u16 dropped = rules.get_u16(AIB_ACTION_BOUNDARY_DROPPED);
	if (hasQueue && queue.length % AIB_ACTION_BOUNDARY_FIELDS == 0)
	{
		for (uint i = 0; i < queue.length; i += AIB_ACTION_BOUNDARY_FIELDS)
		{
			AIB_ActionRecordHeader(9); // authoritative action/plan/task boundary
			AIB_ActionU32(queue[i]);
			AIB_ActionByte(u8(queue[i + 1]));
			AIB_ActionByte(u8(queue[i + 2]));
			AIB_ActionU16(u16(queue[i + 3]));
			AIB_ActionU16(u16(queue[i + 4]));
			AIB_ActionByte(u8(queue[i + 5]));
			AIB_ActionU16(u16(queue[i + 6]));
			AIB_ActionU16(u16(queue[i + 7]));
			AIB_ActionU16(u16(queue[i + 8]));
			AIB_ActionU16(u16(queue[i + 9]));
			if (aibActionBytes.length >= AIB_ACTION_MAX_BATCH_BYTES) AIB_ActionFlush(rules, "boundary_size");
		}
	}
	else if (hasQueue && queue.length > 0 && dropped < 65535)
	{
		dropped++;
	}
	if (dropped > 0)
	{
		AIB_ActionRecordHeader(10); // bounded queue overflow; evidence is incomplete
		AIB_ActionU16(dropped);
	}
	array<u32> empty;
	rules.set(AIB_ACTION_BOUNDARY_QUEUE, empty);
	rules.set_u16(AIB_ACTION_BOUNDARY_DROPPED, 0);
}

void AIB_ActionResetPlayer(CRules@ rules, CPlayer@ player)
{
	if (rules is null || player is null) return;
	const u16 id = player.getNetworkID();
	rules.set_netid(AIB_ActionKey(id, "blob"), 0);
	rules.set_u8(AIB_ActionKey(id, "buttons"), 0);
	rules.set_s16(AIB_ActionKey(id, "aim x"), 0);
	rules.set_s16(AIB_ActionKey(id, "aim y"), 0);
	rules.set_u8(AIB_ActionKey(id, "build page"), 255);
	rules.set_u8(AIB_ActionKey(id, "build blob"), 255);
	rules.set_u16(AIB_ActionKey(id, "build tile"), 65535);
	rules.set_netid(AIB_ActionKey(id, "carried"), 0);
	rules.set_u32(AIB_ActionKey(id, "aim tick"), 0);
	rules.set_u32(AIB_ActionKey(id, "frame tick"), 0);
	rules.set_u16(AIB_ActionKey(id, "wood"), 65535);
	rules.set_u16(AIB_ActionKey(id, "stone"), 65535);
	rules.set_u16(AIB_ActionKey(id, "gold"), 65535);
	rules.set_u16(AIB_ActionKey(id, "arrows"), 65535);
	rules.set_u16(AIB_ActionKey(id, "explosives"), 65535);
	rules.set_u16(AIB_ActionKey(id, "coins"), 65535);
}

void AIB_ActionRecordInventoryDelta(CRules@ rules, CPlayer@ player, CBlob@ blob)
{
	if (rules is null || player is null || blob is null) return;
	const u16 id = player.getNetworkID();
	const string prefix = "aib action player " + id + " ";
	const u16 wood = AIB_ActionInventoryCount(blob, "mat_wood");
	const u16 stone = AIB_ActionInventoryCount(blob, "mat_stone");
	const u16 gold = AIB_ActionInventoryCount(blob, "mat_gold");
	const u16 arrows = AIB_ActionInventoryCount(blob, "mat_arrows");
	const u16 explosives = AIB_ActionInventoryCount(blob, "bomb") + AIB_ActionInventoryCount(blob, "waterbomb") +
		AIB_ActionInventoryCount(blob, "mine") + AIB_ActionInventoryCount(blob, "keg");
	const u16 coins = player.getCoins();
	u8 mask = 0;
	if (wood != rules.get_u16(prefix + "wood")) mask |= 1;
	if (stone != rules.get_u16(prefix + "stone")) mask |= 2;
	if (gold != rules.get_u16(prefix + "gold")) mask |= 4;
	if (arrows != rules.get_u16(prefix + "arrows")) mask |= 8;
	if (explosives != rules.get_u16(prefix + "explosives")) mask |= 16;
	if (coins != rules.get_u16(prefix + "coins")) mask |= 32;
	if (mask == 0) return;

	AIB_ActionRecordHeader(8); // changed resource/economy totals
	AIB_ActionU16(id);
	AIB_ActionByte(mask);
	if ((mask & 1) != 0) AIB_ActionU16(wood);
	if ((mask & 2) != 0) AIB_ActionU16(stone);
	if ((mask & 4) != 0) AIB_ActionU16(gold);
	if ((mask & 8) != 0) AIB_ActionU16(arrows);
	if ((mask & 16) != 0) AIB_ActionU16(explosives);
	if ((mask & 32) != 0) AIB_ActionU16(coins);
	rules.set_u16(prefix + "wood", wood);
	rules.set_u16(prefix + "stone", stone);
	rules.set_u16(prefix + "gold", gold);
	rules.set_u16(prefix + "arrows", arrows);
	rules.set_u16(prefix + "explosives", explosives);
	rules.set_u16(prefix + "coins", coins);
}

void AIB_ActionBeginEpisode(CRules@ rules)
{
	if (!isServer() || rules is null) return;
	AIB_ActionDrainBoundaries(rules);
	AIB_ActionFlush(rules, "episode_end");
	aibActionBatchSequence = 0;
	aibActionLastRecordTick = getGameTime();
	aibActionLastFlushTick = getGameTime();
	rules.set_bool("aib player action log enabled", rules.gamemode_name == "CTF");
	AIB_ActionClearBoundaryQueue(rules);
	rules.set_u32("aib action episode", rules.get_u32("aib action episode") + 1);
	if (rules.get_bool("aib player action log enabled"))
	{
		AIB_ActionRecordHeader(0); // episode
		AIB_ActionU32(u32(getMap() is null ? 0 : getMap().getMapName().getHash()));
	}
	for (int i = 0; i < getPlayersCount(); i++) AIB_ActionResetPlayer(rules, getPlayer(i));
}

void onInit(CRules@ this) { AIB_ActionBeginEpisode(this); }
void onRestart(CRules@ this) { AIB_ActionBeginEpisode(this); }

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	if (!isServer() || !this.get_bool("aib player action log enabled") || player is null) return;
	AIB_ActionDrainBoundaries(this);
	AIB_ActionResetPlayer(this, player);
	AIB_ActionRecordHeader(1); // join
	AIB_ActionU16(player.getNetworkID());
	AIB_ActionByte(u8(player.getTeamNum()));
}

void onPlayerLeave(CRules@ this, CPlayer@ player)
{
	if (!isServer() || !this.get_bool("aib player action log enabled") || player is null) return;
	AIB_ActionDrainBoundaries(this);
	AIB_ActionRecordHeader(2); // leave
	AIB_ActionU16(player.getNetworkID());
	AIB_ActionByte(u8(player.getTeamNum()));
}

void onTick(CRules@ this)
{
	if (!isServer() || this is null || !this.get_bool("aib player action log enabled")) return;
	AIB_ActionDrainBoundaries(this);
	const u32 now = getGameTime();
	for (int i = 0; i < getPlayersCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player is null) continue;
		CBlob@ blob = player.getBlob();
		if (blob is null) continue;

		const u16 id = player.getNetworkID();
		const string prefix = "aib action player " + id + " ";
		const u16 blobID = blob.getNetworkID();
		if (this.get_netid(prefix + "blob") != blobID)
		{
			AIB_ActionResetPlayer(this, player);
			this.set_netid(prefix + "blob", blobID);
			AIB_ActionRecordHeader(3); // spawn/class change
			AIB_ActionU16(id);
			AIB_ActionU16(blobID);
			AIB_ActionByte(u8(blob.getTeamNum()));
			AIB_ActionByte(AIB_ActionClass(blob));
			AIB_ActionS16(s16(blob.getPosition().x));
			AIB_ActionS16(s16(blob.getPosition().y));
		}

		const u8 inputMask = AIB_ActionInputMask(blob);
		const Vec2f aim = blob.getAimPos() - blob.getPosition();
		const s16 aimX = s16(aim.x / 8.0f);
		const s16 aimY = s16(aim.y / 8.0f);
		const bool buttonsChanged = inputMask != this.get_u8(prefix + "buttons");
		const bool aimChanged = aimX != this.get_s16(prefix + "aim x") || aimY != this.get_s16(prefix + "aim y");
		const bool sampleAim = aimChanged && now - this.get_u32(prefix + "aim tick") >= AIB_ACTION_AIM_SAMPLE_TICKS;

		const u8 buildPage = blob.get_u8("build page");
		const u8 buildBlob = blob.get_u8("buildblob");
		const u16 buildTile = u16(blob.get_TileType("buildtile"));
		CBlob@ carried = blob.getCarriedBlob();
		const u16 carriedID = carried is null ? 0 : carried.getNetworkID();
		const bool equipmentChanged = buildPage != this.get_u8(prefix + "build page") ||
			buildBlob != this.get_u8(prefix + "build blob") || buildTile != this.get_u16(prefix + "build tile") ||
			carriedID != this.get_netid(prefix + "carried");
		const bool frameDue = now - this.get_u32(prefix + "frame tick") >= AIB_ACTION_FRAME_TICKS;

		u8 flags = 0;
		if (buttonsChanged) flags |= 1;
		if (buttonsChanged || sampleAim) flags |= 2;
		if (equipmentChanged) flags |= 4;
		if (frameDue) flags |= 8;
		// Resource/economy outcomes are independent of sampled input/motion.
		// Record them before the no-input-delta fast path so a pickup and spend
		// between periodic frames cannot disappear from the demonstration.
		AIB_ActionRecordInventoryDelta(this, player, blob);
		if (flags == 0) continue;

		AIB_ActionRecordHeader(4); // delta
		AIB_ActionU16(id);
		AIB_ActionByte(flags);
		if ((flags & 1) != 0) AIB_ActionByte(inputMask);
		if ((flags & 2) != 0)
		{
			AIB_ActionByte(u8(AIB_ActionClampS8(aimX)));
			AIB_ActionByte(u8(AIB_ActionClampS8(aimY)));
			this.set_s16(prefix + "aim x", aimX);
			this.set_s16(prefix + "aim y", aimY);
			this.set_u32(prefix + "aim tick", now);
		}
		if ((flags & 4) != 0)
		{
			AIB_ActionByte(buildPage);
			AIB_ActionByte(buildBlob);
			AIB_ActionU16(buildTile);
			AIB_ActionU16(carriedID);
		}
		if ((flags & 8) != 0)
		{
			AIB_ActionS16(s16(blob.getPosition().x));
			AIB_ActionS16(s16(blob.getPosition().y));
			AIB_ActionByte(u8(AIB_ActionClampS8(s32(blob.getVelocity().x * 10.0f))));
			AIB_ActionByte(u8(AIB_ActionClampS8(s32(blob.getVelocity().y * 10.0f))));
			this.set_u32(prefix + "frame tick", now);
		}

		this.set_u8(prefix + "buttons", inputMask);
		this.set_u8(prefix + "build page", buildPage);
		this.set_u8(prefix + "build blob", buildBlob);
		this.set_u16(prefix + "build tile", buildTile);
		this.set_netid(prefix + "carried", carriedID);
	}

	if (aibActionBytes.length >= AIB_ACTION_MAX_BATCH_BYTES || now - aibActionLastFlushTick >= AIB_ACTION_FLUSH_TICKS)
		AIB_ActionFlush(this, aibActionBytes.length >= AIB_ACTION_MAX_BATCH_BYTES ? "size" : "interval");
}

void onSetTile(CMap@ map, u32 index, TileType newTile, TileType oldTile)
{
	CRules@ rules = getRules();
	if (!isServer() || map is null || rules is null || !rules.get_bool("aib player action log enabled") || newTile == oldTile) return;
	AIB_ActionDrainBoundaries(rules);
	const u16 x = u16(index % map.tilemapwidth);
	const u16 y = u16(index / map.tilemapwidth);
	const Vec2f center = Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize);
	u8 confidence = 0;
	CPlayer@ actor = AIB_ActionAttributingPlayer(center, confidence);
	AIB_ActionRecordHeader(5); // authoritative tile mutation
	AIB_ActionU16(actor is null ? 0 : actor.getNetworkID());
	AIB_ActionByte(confidence);
	AIB_ActionU16(x);
	AIB_ActionU16(y);
	AIB_ActionU16(oldTile);
	AIB_ActionU16(newTile);
}

void onBlobCreated(CRules@ rules, CBlob@ blob)
{
	if (!isServer() || rules is null || !rules.get_bool("aib player action log enabled") || !AIB_ActionImportantBlob(blob)) return;
	AIB_ActionDrainBoundaries(rules);
	u8 confidence = 0;
	CPlayer@ actor = blob.getDamageOwnerPlayer();
	if (actor !is null) confidence = 3;
	else @actor = AIB_ActionAttributingPlayer(blob.getPosition(), confidence);
	AIB_ActionRecordHeader(6); // important blob creation
	AIB_ActionU16(actor is null ? 0 : actor.getNetworkID());
	AIB_ActionByte(confidence);
	AIB_ActionU16(blob.getNetworkID());
	AIB_ActionByte(u8(blob.getTeamNum()));
	AIB_ActionByte(AIB_ActionEntityClass(blob));
	AIB_ActionU32(u32(blob.getName().getHash()));
	AIB_ActionS16(s16(blob.getPosition().x));
	AIB_ActionS16(s16(blob.getPosition().y));
}

void onBlobDie(CRules@ rules, CBlob@ blob)
{
	if (!isServer() || rules is null || blob is null || !rules.get_bool("aib player action log enabled")) return;
	AIB_ActionDrainBoundaries(rules);
	CPlayer@ victim = blob.getPlayer();
	CPlayer@ killer = blob.getPlayerOfRecentDamage();
	if (victim is null && killer is null && !AIB_ActionImportantBlob(blob)) return;
	AIB_ActionRecordHeader(7); // character/important-blob death
	AIB_ActionU16(victim is null ? 0 : victim.getNetworkID());
	AIB_ActionU16(killer is null ? 0 : killer.getNetworkID());
	AIB_ActionU16(blob.getNetworkID());
	AIB_ActionByte(u8(blob.getTeamNum()));
	AIB_ActionByte(AIB_ActionEntityClass(blob));
	AIB_ActionU32(u32(blob.getName().getHash()));
	AIB_ActionS16(s16(blob.getPosition().x));
	AIB_ActionS16(s16(blob.getPosition().y));
}
