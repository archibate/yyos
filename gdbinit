#set auto-load safe-path /

define hook-stop
 x/i $cs * 16 + $eip
end

define qemu-connection
 target remote localhost:1234
end

define qemu-quit
 echo + gdb + quit\n
 kill
 quit
end

define qq
 qemu-quit
end

define print-stack
 set $stack=$sp
 set $stack_end=$arg0+$sp
 while ($stack > $stack_end)
  x/w $stack
 end
end

define print-list
 set $list=$arg0
 while ($list)
  p *$list
  set $list=$list->next
 end
end

file oskernel.elf
qemu-connection
symbol-file oskernel.elf
