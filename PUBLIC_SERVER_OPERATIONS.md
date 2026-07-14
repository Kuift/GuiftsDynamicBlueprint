# AI Director Public Server Operations

This runbook covers the privacy-bounded `[AIBACT]` evaluation stream. It does not replace the host's general privacy policy: KAG console logs can contain unrelated usernames, chat, moderation events, or network diagnostics outside the AI telemetry envelope.

## Before opening a public test

1. Review `Rules/CommonScripts/AIBTelemetryPolicy.cfg`.
2. Leave `player_notice_enabled = true` whenever `ctf_enabled = true`, unless an equivalent notice is already provided by the server MOTD.
3. Publish the retention period and who can access raw console logs in the server rules or MOTD.
4. Confirm `!aib_telemetry status` reports the intended current, startup, and notice states.
5. Keep `AIB_DEBUG` and `[AIBEVT]` disabled outside focused diagnostics.

The built-in notice is sent once per affected player connection. It states that capture is for AI evaluation and excludes usernames, IP addresses, and chat from `[AIBACT]` records. Enabling telemetry at runtime also notifies already-connected players who have not received the notice. Disabling capture flushes the current compact batch with `reason=disabled`; a later enable starts a new episode rather than joining evidence across the gap.

## Runtime control

- `!aib_telemetry on` enables capture for the current rules session and survives round restarts.
- `!aib_telemetry off` flushes and disables capture; it also survives round restarts.
- `!aib_telemetry status` reports current capture, configured CTF startup, and player-notice states.

These commands require a moderator. A full server/rules reload reapplies `AIBTelemetryPolicy.cfg` when the rules object is recreated.

## Rotation and retention

The mod writes compact base64 envelopes to the normal KAG console log because AngelScript has no safe private binary log writer. File rotation and deletion therefore belong to the server operator.

Use a documented schedule appropriate to the public test. A conservative starting point is to rotate console logs daily, restrict raw-log access, retain raw logs only long enough to validate/export the test, and keep longer-lived analysis in the privacy-filtered NDJSON outputs. Shorten retention when local policy or player expectations require it.

For every retained collection window:

1. Preserve complete `[AIBACT]` lines, including episode, batch, record count, reason, and data fields.
2. Export with `Tools/parse_aib_player_actions.ps1` and treat parser errors or schema-v3 loss records as incomplete evidence.
3. Derive episodes with `Tools/summarize_aib_player_episodes.ps1`.
4. Record capture start/end times, map/fixture context, disabled intervals, parser version, and the raw-log deletion date.
5. Delete or archive the encompassing KAG console log according to the published schedule; remember that non-`[AIBACT]` lines may carry ordinary server identity or chat data.

## Evidence gate

Do not use a collection for AI-versus-human quality claims unless its player notice was active, capture gaps are documented, batch loss is absent or explicitly bounded, and comparison cohorts share the same coarse context key. Proximity inference is not explicit ownership.
