// Stable client observer for visible AIBTest localhost runs.
// This script replaces PlayerCamera only in the AIBTest gamemode, so there is
// one camera owner instead of two targets fighting between rendered frames.

#define CLIENT_ONLY
#include "Spectator.as"

u16 AIBTC_targetNetID = 0;
Vec2f AIBTC_followPosition;
Vec2f AIBTC_manualOffset;
bool AIBTC_hasFollowPosition = false;
u16 AIBTC_verifyTargetNetID = 0;
u8 AIBTC_verifyFrames = 0;
u32 AIBTC_lastOverrideReport = 0;

string AIBTC_Pos(Vec2f position)
{
	return "" + Maths::Round(position.x) + "," + Maths::Round(position.y);
}

Vec2f AIBTC_TargetPosition(CBlob@ target)
{
	if (target is null) return Vec2f_zero;
	Vec2f authoritative = target.getPosition();
	Vec2f interpolated = target.getInterpolatedPosition();
	// A newly replicated blob can report an interpolated origin for one frame.
	// Treat that (and any similarly large replication discontinuity) as invalid,
	// otherwise every scene transition visibly snaps to the map's upper-left.
	if (interpolated == Vec2f_zero || (interpolated - authoritative).Length() > 64.0f)
	{
		return authoritative;
	}
	return interpolated;
}

void AIBTC_ResetCamera()
{
	AIBTC_targetNetID = 0;
	AIBTC_hasFollowPosition = false;
	AIBTC_manualOffset = Vec2f_zero;
	AIBTC_verifyTargetNetID = 0;
	AIBTC_verifyFrames = 0;
	AIBTC_lastOverrideReport = 0;
	SetTargetPlayer(null);
	currentTarget = 0;
	switchTarget = 0;
	waitForRelease = false;
	panEaseModifier = 1.0f;
	zoomEaseModifier = 1.0f;
	timeToCinematic = 0.0f;
	setCinematicEnabled(false);
	setCinematicForceDisabled(true);

	CCamera@ camera = getCamera();
	if (camera is null) return;
	// Preserve the view that the client already has.  ViewEntireMap() seeds the
	// spectator easing target at the map centre, which made every short gap
	// between test fixtures pull the camera away from the active scene.
	Vec2f heldPosition = camera.getPosition();
	camera.setTarget(null);
	camera.targetDistance = 1.0f;
	zoomTarget = 1.0f;
	posActual = heldPosition;
	posTarget = heldPosition;
	AIBTC_followPosition = heldPosition;
	camera.setPosition(heldPosition);
}

void onInit(CRules@ this)
{
	AIBTC_ResetCamera();
}

void onRestart(CRules@ this)
{
	AIBTC_ResetCamera();
}

bool AIBTC_IsLiveBuilder(CBlob@ blob)
{
	return blob !is null && blob.getName() == "aibuilder" &&
		!blob.hasTag("dead");
}

CBlob@ AIBTC_FindBuilder()
{
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	CBlob@ best = null;
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ candidate = builders[i];
		if (!AIBTC_IsLiveBuilder(candidate)) continue;
		if (best is null || candidate.getNetworkID() < best.getNetworkID()) @best = candidate;
	}
	return best;
}

void AIBTC_ReleaseCamera(CCamera@ camera)
{
	if (AIBTC_targetNetID == 0) return;
	AIBTC_targetNetID = 0;
	AIBTC_hasFollowPosition = false;
	AIBTC_manualOffset = Vec2f_zero;
	AIBTC_verifyTargetNetID = 0;
	AIBTC_verifyFrames = 0;
	if (camera is null) return;
	Vec2f heldPosition = camera.getPosition();
	camera.setTarget(null);
	SetTargetPlayer(null);
	setCinematicEnabled(false);
	setCinematicForceDisabled(true);
	posActual = heldPosition;
	posTarget = heldPosition;
	AIBTC_followPosition = heldPosition;
	camera.setPosition(heldPosition);
}

bool AIBTC_UpdateFollow(CRules@ this)
{
	CCamera@ camera = getCamera();
	if (camera is null) return false;

	CBlob@ target = getBlobByNetworkID(AIBTC_targetNetID);
	if (!AIBTC_IsLiveBuilder(target)) @target = AIBTC_FindBuilder();
	if (target is null)
	{
		AIBTC_ReleaseCamera(camera);
		return false;
	}

	const u16 nextID = target.getNetworkID();
	const bool targetChanged = nextID != AIBTC_targetNetID;
	AIBTC_targetNetID = nextID;
	// KAG does not reliably retain a native camera target for this non-player
	// test blob.  Own the camera position directly instead: snap once when the
	// scene changes, then onRender follows the blob's interpolated position.
	if (targetChanged || !AIBTC_hasFollowPosition)
	{
		SetTargetPlayer(null);
		setCinematicEnabled(false);
		setCinematicForceDisabled(true);
		camera.setTarget(null);
		AIBTC_followPosition = AIBTC_TargetPosition(target);
		AIBTC_manualOffset = Vec2f_zero;
		AIBTC_hasFollowPosition = true;
		camera.setPosition(AIBTC_followPosition);
		if (targetChanged)
		{
			AIBTC_verifyTargetNetID = nextID;
			AIBTC_verifyFrames = 0;
			print("[AIBTEST] CAMERA_TARGET target=" + nextID + " requested=" +
				AIBTC_Pos(AIBTC_followPosition));
		}
	}
	return true;
}

void AIBTC_UpdateManualOffset(CCamera@ camera)
{
	if (camera is null) return;
	CControls@ controls = getControls();
	if (controls is null) return;

	const f32 correction = getRenderApproximateCorrectionFactor();
	const f32 zoom = Maths::Max(camera.targetDistance, 0.5f);
	const f32 speed = 15.0f * correction / zoom;
	if (controls.ActionKeyPressed(AK_MOVE_LEFT)) AIBTC_manualOffset.x -= speed;
	if (controls.ActionKeyPressed(AK_MOVE_RIGHT)) AIBTC_manualOffset.x += speed;
	if (controls.ActionKeyPressed(AK_MOVE_UP)) AIBTC_manualOffset.y -= speed;
	if (controls.ActionKeyPressed(AK_MOVE_DOWN)) AIBTC_manualOffset.y += speed;

	if (controls.isKeyPressed(KEY_LBUTTON))
	{
		Vec2f desired = AIBTC_followPosition + AIBTC_manualOffset;
		AIBTC_manualOffset += (controls.getMouseWorldPos() - desired) / 8.0f * correction;
	}
	if (controls.isKeyJustPressed(KEY_RBUTTON)) AIBTC_manualOffset = Vec2f_zero;

	if (controls.mouseScrollUp)
	{
		camera.targetDistance = camera.targetDistance < 1.0f ? 1.0f : 2.0f;
	}
	else if (controls.mouseScrollDown)
	{
		camera.targetDistance = camera.targetDistance > 1.0f ? 1.0f : 0.5f;
	}
}

void onTick(CRules@ this)
{
	if (!isClient() || this is null || this.gamemode_name != "AIBTest") return;
	if (AIBTC_UpdateFollow(this)) return;
	if (v_capped) Spectator(this);
}

void onRender(CRules@ this)
{
	if (!isClient() || this is null || this.gamemode_name != "AIBTest") return;
	const string status = this.get_string("aib test display status");
	if (status != "")
	{
		Vec2f screen = getDriver().getScreenDimensions();
		Vec2f center = Vec2f(screen.x * 0.5f, 22.0f);
		const f32 halfWidth = Maths::Min(360.0f, screen.x * 0.45f);
		GUI::DrawRectangle(center - Vec2f(halfWidth, 15.0f), center + Vec2f(halfWidth, 15.0f), SColor(220, 12, 18, 24));
		GUI::DrawTextCentered(status, center - Vec2f(0.0f, 4.0f), SColor(255, 235, 245, 255));
	}
	// onTick is the sole authority that releases or changes a follow target.
	// Render only advances the already-selected target's interpolated position;
	// it never chooses a competing scene or falls through to Spectator mid-tick.
	if (AIBTC_targetNetID != 0)
	{
		CBlob@ target = getBlobByNetworkID(AIBTC_targetNetID);
		if (AIBTC_IsLiveBuilder(target))
		{
			CCamera@ camera = getCamera();
			if (camera !is null)
			{
				Vec2f observedBefore = camera.getPosition();
				AIBTC_followPosition = AIBTC_TargetPosition(target);
				AIBTC_UpdateManualOffset(camera);
				Vec2f desiredPosition = AIBTC_followPosition + AIBTC_manualOffset;
				camera.setTarget(null);
				camera.setPosition(desiredPosition);
				Vec2f observedAfter = camera.getPosition();
				const f32 beforeError = (observedBefore - desiredPosition).Length();
				const f32 afterError = (observedAfter - desiredPosition).Length();
				if (AIBTC_verifyTargetNetID == AIBTC_targetNetID && AIBTC_verifyFrames < 2)
				{
					AIBTC_verifyFrames++;
					if (AIBTC_verifyFrames == 2)
					{
						print("[AIBTEST] CAMERA_VIEW target=" + AIBTC_targetNetID +
							" observed_before=" + AIBTC_Pos(observedBefore) +
							" observed_after=" + AIBTC_Pos(observedAfter) +
							" scene=" + AIBTC_Pos(AIBTC_followPosition) +
							" desired=" + AIBTC_Pos(desiredPosition) +
							" before_error=" + Maths::Round(beforeError) +
							" after_error=" + Maths::Round(afterError));
					}
				}
				else if (beforeError > 48.0f && getGameTime() - AIBTC_lastOverrideReport >= 30)
				{
					AIBTC_lastOverrideReport = getGameTime();
					print("[AIBTEST] CAMERA_OVERRIDE target=" + AIBTC_targetNetID +
						" observed=" + AIBTC_Pos(observedBefore) +
						" desired=" + AIBTC_Pos(desiredPosition) +
						" error=" + Maths::Round(beforeError));
				}
			}
		}
		return;
	}
	if (!v_capped) Spectator(this);
}
