# Expects the caller to set $base to the ASLR image base before sourcing.
set pagination off
set confirm off

break *($base + 0x55894)
commands
  silent
  set $obj = $rcx
  set $vt = *(void **)$obj
  printf "CALLBACK obj=%p byte8=%u byte10=%u vtable=%p tick=%p slot20=%p\n", $obj, *(unsigned char*)($obj+8), *(unsigned char*)($obj+0x10), $vt, *(void**)($vt+0x10), *(void**)($vt+0x20)
  continue
end

tbreak *($base + 0x558b6)
continue
printf "CALLBACK_TRAVERSAL_DONE\n"
detach
