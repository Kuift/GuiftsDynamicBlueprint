# Attach after the minimal localhost probe reaches Waiting for scripts. This
# traces the native per-script dispatcher without mutating KAG state.
set pagination off
set confirm off

python
import gdb
import re
files = gdb.execute("info files", to_string=True)
match = re.search(r"(?m)^\s*(0x[0-9a-fA-F]+)\s+-\s+0x[0-9a-fA-F]+\s+is \.text\s*$", files)
if match is None:
    raise gdb.GdbError("Could not recover the relocated KAG .text address")
base = int(match.group(1), 16) - 0x1000
gdb.execute("set $base = 0x%x" % base)
gdb.write("KAG_BASE=0x%x\n" % base)
end

set $hook_calls = 0
break *($base + 0x2b01b0)
commands
  silent
  set $hook_calls = $hook_calls + 1
  set $script = $rcx
  set $name = *(char **)($script + 8)
  printf "HOOK call=%u script=%p name=%s hook_arg=%p on_tick=%p engine_obj=%p server_flag=%u client_flag=%u error=%u\n", $hook_calls, $script, $name, $rdx, *(void **)($script + 0xb8), *(void **)($script + 0x28), *(unsigned char *)($script + 0x88), *(unsigned char *)($script + 0x89), *(unsigned char *)($script + 0x91)
  if $hook_calls >= 16
    printf "TRACE_DONE hook_calls=%u\n", $hook_calls
    detach
    quit
  end
  continue
end

continue
