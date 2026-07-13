#include "BlueprintData.as";
#include "AutoBuilderCommon.as";

// Canonical, privacy-safe world manifest used at both wave boundaries. Never
// include player names, usernames, network ids, or absolute game time: those
// values differ across otherwise equivalent fresh trials and are not policy
// inputs. Entry hashes are sorted before folding so getBlobs() iteration order
// cannot invalidate a control/plan pair.

u32 AIBWF_Mix(const u32 hash, const u32 value)
{
	return (hash ^ value) * 16777619;
}

u32 AIBWF_FoldSorted(array<u32> &inout entries)
{
	entries.sortAsc();
	u32 hash = AIBWF_Mix(2166136261, entries.length);
	for (uint i = 0; i < entries.length; i++) hash = AIBWF_Mix(hash, entries[i]);
	return hash;
}

u32 AIBWF_InventoryEntry(CBlob@ item)
{
	if (item is null) return 0;
	u32 hash = AIBWF_Mix(2166136261, u32(item.getName().getHash()));
	hash = AIBWF_Mix(hash, item.getQuantity());
	hash = AIBWF_Mix(hash, item.maxQuantity);
	return hash;
}

u32 AIBWF_InventoryHash(CBlob@ owner, u16 &out itemCount)
{
	itemCount = 0;
	array<u32> entries;
	if (owner is null) return AIBWF_FoldSorted(entries);
	CInventory@ inventory = owner.getInventory();
	if (inventory is null) return AIBWF_FoldSorted(entries);
	for (uint i = 0; i < inventory.getItemsCount(); i++)
	{
		CBlob@ item = inventory.getItem(i);
		if (item is null || item.hasTag("dead")) continue;
		entries.push_back(AIBWF_InventoryEntry(item));
		itemCount++;
	}
	return AIBWF_FoldSorted(entries);
}

u32 AIBWF_BlobEntry(CBlob@ blob, CMap@ map, u32 &out inventoryContribution)
{
	inventoryContribution = 0;
	if (blob is null || map is null) return 0;
	u16 inventoryCount = 0;
	const u32 inventoryHash = AIBWF_InventoryHash(blob, inventoryCount);
	inventoryContribution = AIBWF_Mix(inventoryHash, inventoryCount);

	Vec2f position = blob.getPosition();
	const s32 tileX = Maths::Floor(position.x / map.tilesize);
	const s32 tileY = Maths::Floor(position.y / map.tilesize);
	u32 hash = AIBWF_Mix(2166136261, u32(blob.getName().getHash()));
	hash = AIBWF_Mix(hash, u32(blob.getTeamNum() + 128));
	hash = AIBWF_Mix(hash, u32(tileX + 32768));
	hash = AIBWF_Mix(hash, u32(tileY + 32768));
	hash = AIBWF_Mix(hash, u32(Maths::Max(0, Maths::Round(blob.getHealth() * 100.0f))));
	hash = AIBWF_Mix(hash, blob.getQuantity());
	hash = AIBWF_Mix(hash, u32(Maths::Round(blob.getAngleDegrees()) + 720));
	hash = AIBWF_Mix(hash, blob.get_u8("grown_times"));
	hash = AIBWF_Mix(hash, blob.get_u8("ai builder job"));
	hash = AIBWF_Mix(hash, blob.get_u8("ai builder state"));
	hash = AIBWF_Mix(hash, inventoryContribution);
	return hash;
}

u32 AIBWF_BlobManifest(CMap@ map, u32 &out blobCount, u32 &out inventoryHash)
{
	blobCount = 0;
	inventoryHash = 2166136261;
	array<u32> entries;
	array<u32> inventories;
	CBlob@[] blobs;
	getBlobs(@blobs);
	for (uint i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (blob is null || blob.hasTag("dead") || blob.isInInventory()) continue;
		u32 inventoryContribution = 0;
		entries.push_back(AIBWF_BlobEntry(blob, map, inventoryContribution));
		inventories.push_back(inventoryContribution);
		blobCount++;
	}
	inventoryHash = AIBWF_FoldSorted(inventories);
	return AIBWF_FoldSorted(entries);
}

u32 AIBWF_TerrainHash(CMap@ map, u32 &out solidTiles)
{
	solidTiles = 0;
	if (map is null) return 0;
	u32 hash = 2166136261;
	const uint cells = uint(map.tilemapwidth) * uint(map.tilemapheight);
	for (uint i = 0; i < cells; i++)
	{
		const TileType type = map.getTile(i).type;
		hash = AIBWF_Mix(hash, u32(type));
		if (map.isTileSolid(type)) solidTiles++;
	}
	return hash;
}

u32 AIBWF_NoBuildHash(CMap@ map, u32 &out noBuildTiles)
{
	noBuildTiles = 0;
	if (map is null) return 0;
	u32 hash = 2166136261;
	const uint cells = uint(map.tilemapwidth) * uint(map.tilemapheight);
	for (uint i = 0; i < cells; i++)
	{
		const u16 x = u16(i % map.tilemapwidth);
		const u16 y = u16(i / map.tilemapwidth);
		const Vec2f center = Vec2f((x + 0.5f) * map.tilesize, (y + 0.5f) * map.tilesize);
		if (map.getSectorAtPosition(center, "no build") is null) continue;
		hash = AIBWF_Mix(hash, i + 1);
		noBuildTiles++;
	}
	return AIBWF_Mix(hash, noBuildTiles);
}

u32 AIBWF_LayerHash(const u8 team, const u8 layer)
{
	array<u16>@ grid = null;
	u32 hash = AIBWF_Mix(2166136261, layer);
	if (!AIBP_GetLayerGrid(team, layer, @grid) || grid is null) return AIBWF_Mix(hash, 0);
	hash = AIBWF_Mix(hash, grid.length);
	for (uint i = 0; i < grid.length; i++)
	{
		if (grid[i] == 0) continue;
		hash = AIBWF_Mix(hash, i + 1);
		hash = AIBWF_Mix(hash, grid[i]);
	}
	return hash;
}

u32 AIBWF_TaskHash(const u8 team)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	u32 hash = 2166136261;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return AIBWF_Mix(hash, 0);
	hash = AIBWF_Mix(hash, xs.length);
	for (uint i = 0; i < xs.length && i < ys.length && i < blocks.length && i < phases.length && i < states.length; i++)
	{
		hash = AIBWF_Mix(hash, xs[i]);
		hash = AIBWF_Mix(hash, ys[i]);
		hash = AIBWF_Mix(hash, blocks[i]);
		hash = AIBWF_Mix(hash, phases[i]);
		hash = AIBWF_Mix(hash, states[i]);
		// Reservation ownership uses transient network ids. Record only whether a
		// live ownership claim exists, which is the strategic state that matters.
		hash = AIBWF_Mix(hash, i < reserved.length && reserved[i] != 0 ? 1 : 0);
	}
	return hash;
}

u32 AIBWF_StrategyHash(CRules@ rules)
{
	if (rules is null) return 0;
	u32 hash = 2166136261;
	hash = AIBWF_Mix(hash, rules.getCurrentState());
	hash = AIBWF_Mix(hash, rules.get_u16("barrier_x1"));
	hash = AIBWF_Mix(hash, rules.get_u16("barrier_x2"));
	hash = AIBWF_Mix(hash, rules.get_bool("aib test resource barrier") ? 1 : 0);
	for (u8 team = 0; team < 8; team++)
	{
		hash = AIBWF_Mix(hash, team);
		hash = AIBWF_Mix(hash, rules.get_u8(AIBP_ModeKey(team)));
		hash = AIBWF_Mix(hash, rules.get_u16(AIBP_PlanKey(team, "id")));
		hash = AIBWF_Mix(hash, rules.get_u8(AIBP_PlanKey(team, "status")));
		hash = AIBWF_Mix(hash, rules.get_u8(AIBP_PlanKey(team, "intent")));
		hash = AIBWF_Mix(hash, rules.get_u16(AIBP_PlanKey(team, "pending")));
		hash = AIBWF_Mix(hash, rules.get_u16(AIBP_PlanKey(team, "completed")));
		hash = AIBWF_Mix(hash, AIBU_GetSpeedLevel(team));
		hash = AIBWF_Mix(hash, AIBWF_LayerHash(team, AIBP_Layer::human));
		hash = AIBWF_Mix(hash, AIBWF_LayerHash(team, AIBP_Layer::ai_desired));
		hash = AIBWF_Mix(hash, AIBWF_LayerHash(team, AIBP_Layer::ai_work));
		hash = AIBWF_Mix(hash, AIBWF_TaskHash(team));
	}
	return hash;
}

string AIBWF_CaptureWorldManifest(CRules@ rules, CMap@ map,
	u32 &out terrainHash, u32 &out solidTiles, u32 &out noBuildHash, u32 &out noBuildTiles,
	u32 &out blobCount, u32 &out blobHash, u32 &out inventoryHash, u32 &out strategyHash)
{
	if (rules is null || map is null) return "";
	terrainHash = AIBWF_TerrainHash(map, solidTiles);
	noBuildHash = AIBWF_NoBuildHash(map, noBuildTiles);
	blobHash = AIBWF_BlobManifest(map, blobCount, inventoryHash);
	strategyHash = AIBWF_StrategyHash(rules);
	const u32 mapHash = u32(map.getMapName().getHash());
	return "w1-" + mapHash + "-" + map.tilemapwidth + "x" + map.tilemapheight + "-" +
		terrainHash + "-" + solidTiles + "-" + noBuildHash + "-" + noBuildTiles + "-" +
		blobCount + "-" + blobHash + "-" + inventoryHash + "-" + strategyHash;
}
