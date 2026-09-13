// Client renderer for the status reports emitted by AIBuilderBrain.as.
// This must be a sprite script: blob scripts do not receive onRender(CSprite@).

#define CLIENT_ONLY

void onRender(CSprite@ sprite)
{
	CBlob@ blob = sprite.getBlob();
	if (blob is null || blob.hasTag("dead")) return;
	if (getGameTime() >= blob.get_u32("ai builder status bubble until")) return;

	const string text = blob.get_string("ai builder status bubble text");
	if (text.length == 0) return;

	GUI::SetFont("hud");
	Vec2f textSize;
	GUI::GetTextDimensions(text, textSize);

	// Blob screen coordinates follow the active camera (including overseer
	// view), so the bubble stays attached to the builder in every view mode.
	Vec2f center = blob.getScreenPos() - Vec2f(0.0f, 32.0f);
	Vec2f halfSize = textSize * 0.5f;
	Vec2f padding(8.0f, 5.0f);
	Vec2f upperLeft = center - halfSize - padding;
	Vec2f lowerRight = center + halfSize + padding;
	GUI::DrawBubble(upperLeft, lowerRight);
	GUI::DrawTextCentered(text, center, SColor(0xff101010));
}
