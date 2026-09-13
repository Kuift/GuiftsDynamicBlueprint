// Shared, low-cost hooks used by production AI code to attribute benchmark
// outcomes.  The rules-side benchmark owns episode setup and final scoring;
// this file only records confirmed resource delivery by workers belonging to
// the currently active episode.

const string AIBGM_WORKER_TAG = "aib gym worker";
const string AIBGM_WORKER_EPOCH_KEY = "aib gym worker epoch";
const string AIBGM_WORKER_SLOT_KEY = "aib gym worker slot";
const string AIBGM_COLLECTION_COUNTED_TAG = "aib gym collection counted";

string AIBGM_SlotMetricKey(const u8 slot, const string &in metric)
{
	return "aib gym slot " + slot + " " + metric;
}

void AIBGM_AddU32(CRules@ rules, const string &in key, const u32 amount)
{
	if (rules is null || amount == 0) return;
	rules.set_u32(key, rules.get_u32(key) + amount);
}

void AIBGM_RecordConfirmedDelivery(CBlob@ builder, const u16 wood, const u16 stone, const u16 gold)
{
	if (builder is null || !builder.hasTag(AIBGM_WORKER_TAG)) return;
	CRules@ rules = getRules();
	if (rules is null || !rules.get_bool("aib gym running")) return;
	if (builder.getTeamNum() != rules.get_u8("aib gym team") ||
		builder.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch")) return;

	const u8 slot = builder.get_u8(AIBGM_WORKER_SLOT_KEY);
	AIBGM_AddU32(rules, "aib gym delivered wood", wood);
	AIBGM_AddU32(rules, "aib gym delivered stone", stone);
	AIBGM_AddU32(rules, "aib gym delivered gold", gold);
	AIBGM_AddU32(rules, AIBGM_SlotMetricKey(slot, "wood"), wood);
	AIBGM_AddU32(rules, AIBGM_SlotMetricKey(slot, "stone"), stone);
	AIBGM_AddU32(rules, AIBGM_SlotMetricKey(slot, "gold"), gold);

	// Some material blobs are absorbed directly into inventory by engine pickup
	// code without ever exposing the carried-blob state used by the acquisition
	// hook below. Confirmed episode delivery is a conservative lower bound on
	// prior collection. Reconcile per worker/material so the gross collection
	// score cannot remain below material the same worker demonstrably returned.
	string[] materials = { "wood", "stone", "gold" };
	for (uint i = 0; i < materials.length; i++)
	{
		const string material = materials[i];
		const u32 delivered = rules.get_u32(AIBGM_SlotMetricKey(slot, material));
		const string collectedKey = AIBGM_SlotMetricKey(slot, "collected " + material);
		const u32 collected = rules.get_u32(collectedKey);
		if (collected >= delivered) continue;
		const u32 missing = delivered - collected;
		AIBGM_AddU32(rules, "aib gym collected " + material, missing);
		AIBGM_AddU32(rules, collectedKey, missing);
	}
}

void AIBGM_RecordCollectedResource(CBlob@ builder, CBlob@ resource)
{
	if (builder is null || resource is null || resource.hasTag(AIBGM_COLLECTION_COUNTED_TAG) ||
		resource.hasTag("aibuilder delivered resource") || resource.hasTag("aibuilder starter material")) return;
	CRules@ rules = getRules();
	if (rules is null || !rules.get_bool("aib gym running") || !builder.hasTag(AIBGM_WORKER_TAG) ||
		builder.getTeamNum() != rules.get_u8("aib gym team") ||
		builder.get_u32(AIBGM_WORKER_EPOCH_KEY) != rules.get_u32("aib gym epoch")) return;
	const string name = resource.getName();
	if (name != "mat_wood" && name != "mat_stone" && name != "mat_gold") return;
	resource.Tag(AIBGM_COLLECTION_COUNTED_TAG);
	const u32 quantity = resource.getQuantity();
	const string material = name == "mat_wood" ? "wood" : (name == "mat_stone" ? "stone" : "gold");
	const u8 slot = builder.get_u8(AIBGM_WORKER_SLOT_KEY);
	AIBGM_AddU32(rules, "aib gym collected " + material, quantity);
	AIBGM_AddU32(rules, AIBGM_SlotMetricKey(slot, "collected " + material), quantity);
}
