# Attach only after the minimal probe has stopped advancing so the samples
# describe the stalled state rather than initial resource loading.
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

set $main_hits = 0
set $rules_hits = 0

break *($base + 0x3161e0)
commands
  silent
  set $main_hits = $main_hits + 1
  set $main = $rcx
  set $world = *(void **)($main + 0x48)
  set $rules = *(void **)($main + 0x60)
  printf "MAIN hit=%u obj=%p pause=%u world=%p rules=%p\n", $main_hits, $main, *(unsigned char *)($main + 0x280), $world, $rules
  if $world != 0
    printf "  WORLD clock=%f\n", *(float *)($world + 0x230)
  end
  if $rules != 0
    printf "  RULES active=%u initialized=%u tick=%u scripts_begin=%p scripts_end=%p\n", *(unsigned char *)($rules + 0x130), *(unsigned char *)($rules + 0x2d8), *(unsigned int *)($rules + 0x148), *(void **)($rules + 0x260), *(void **)($rules + 0x268)
  end
  if $main_hits >= 8
    printf "TRACE_DONE main_hits=%u rules_hits=%u\n", $main_hits, $rules_hits
    detach
    quit
  end
  continue
end

break *($base + 0x2ef870)
commands
  silent
  set $rules_hits = $rules_hits + 1
  printf "RULES_CALL hit=%u obj=%p active=%u initialized=%u tick_before=%u\n", $rules_hits, $rcx, *(unsigned char *)($rcx + 0x130), *(unsigned char *)($rcx + 0x2d8), *(unsigned int *)($rcx + 0x148)
  continue
end

continue
