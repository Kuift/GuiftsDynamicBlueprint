# Build 4762 Tick/Script Trace

This note records derived clean-room observations only. Raw debugger stacks and
decompiler output remain under ignored `research/private/`.

## Focused native map

- Scheduler traversal: preferred image `0x140055650`.
- Main per-tick engine callback: `0x1403161e0`.
- Network/state-stream tick callback: `0x1401f3ef0`.
- Rules/script dispatcher: `0x1402ef870`.
- Per-script hook dispatcher: `0x1402b01b0`.
- AngelScript `u32 getGameTime()` binding: `0x1402f9be0`.

`getGameTime()` returns zero when the engine game-time enable flag is clear;
otherwise it reads the active rules object's 32-bit tick field at offset
`0x148`.

## Reproduced localhost state

After the visible minimal localhost log ended at `Waiting for scripts...` and
game time 30, a read-only eight-callback sample recorded:

- main pause byte `0` on every sample;
- rules active/initialized bytes both `1`;
- rules tick `905, 906, 907, 908, 909, 910, 911, 912`;
- a stable four-entry rules-script vector.

A separate hook sample showed the `aibresearchminimalprobe` object with a
non-null compiled engine object, non-null `onTick` hook, server-only flags, and
no error flag. The hook was passed to the native per-script dispatcher on two
successive cycles after the console file had stopped.

## Consequence

The console file is not a valid proxy for the simulation clock in this state.
The validated persistent runner therefore does not use it for completion. It
crosses from the localhost client to a research-only server `CRules` command,
calls `this.RestartRules()` on the server, and consumes explicit TCPR ACK and
DONE records. Do not add more scheduler traces unless that channel identifies
a specific native branch that needs inspection.
