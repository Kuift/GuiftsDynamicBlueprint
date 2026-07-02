#define CLIENT_ONLY

const f32 DBP_HELP_PADDING = 10.0f;
const f32 DBP_HELP_LINE_GAP = 3.0f;
const f32 DBP_HELP_SCREEN_MARGIN = 8.0f;

void onInit(CRules@ this)
{
	AddIconToken("$AIBuilder$", "Entities/Characters/AIBuilder/AIBuilderMale.png", Vec2f(32, 32), 0);
}

void onRender(CRules@ this)
{
	if (!u_showtutorial || g_videorecording)
		return;

	CBlob@ blob = getLocalPlayerBlob();
	if (blob is null)
		return;

	const string name = blob.getName();
	if (name != "builder" && name != "knight" && name != "archer" && name != "aibuilder")
		return;

	string[] lines =
	{
		getTranslatedString("Blueprint controls"),
		getTranslatedString("$KEY_X$ menu at cursor    $KEY_L$ toggle menu"),
		getTranslatedString("Paint / Erase / Select    Save / Load"),
		getTranslatedString("Rotate / Flip / Preview    select trees or stone"),
		getTranslatedString("Overseer: drag-select AI, then choose a job"),
		getTranslatedString("Assign: !bp_overseer_set username")
	};

	if (name == "aibuilder")
	{
		lines.push_back(getTranslatedString("$AIBuilder$ Jobs: wood / stone / build; returns to home"));
	}

	DrawDynamicBlueprintHelp(lines);
}

void DrawDynamicBlueprintHelp(const string[] &in lines)
{
	GUI::SetFont("menu");

	f32 contentWidth = 0.0f;
	f32 lineHeight = 0.0f;
	for (uint i = 0; i < lines.length; i++)
	{
		Vec2f dimensions;
		GUI::GetTextDimensions(lines[i], dimensions);
		contentWidth = Maths::Max(contentWidth, dimensions.x);
		lineHeight = Maths::Max(lineHeight, dimensions.y);
	}

	if (lineHeight <= 0.0f)
		lineHeight = 16.0f;

	const f32 screenWidth = getDriver().getScreenWidth();
	const f32 panelWidth = Maths::Min(contentWidth + DBP_HELP_PADDING * 2.0f,
		Maths::Max(0.0f, screenWidth - DBP_HELP_SCREEN_MARGIN * 2.0f));
	const f32 panelHeight = DBP_HELP_PADDING * 2.0f + lineHeight * lines.length +
		DBP_HELP_LINE_GAP * Maths::Max(0, int(lines.length) - 1);
	// KAG's legacy Vec2f arithmetic operators do not accept const operands.
	Vec2f panelMin(screenWidth - panelWidth - DBP_HELP_SCREEN_MARGIN, DBP_HELP_SCREEN_MARGIN);
	Vec2f panelMax = panelMin + Vec2f(panelWidth, panelHeight);

	GUI::DrawRectangle(panelMin, panelMax, SColor(0xff050505));
	GUI::DrawRectangle(panelMin + Vec2f(1.0f, 1.0f), panelMax - Vec2f(1.0f, 1.0f), SColor(0xe5222529));

	Vec2f textPos = panelMin + Vec2f(DBP_HELP_PADDING, DBP_HELP_PADDING);
	for (uint i = 0; i < lines.length; i++)
	{
		const SColor color = i == 0 ? SColor(0xffffd56a) : color_white;
		GUI::DrawText(lines[i], textPos, color);
		textPos.y += lineHeight + DBP_HELP_LINE_GAP;
	}
}
