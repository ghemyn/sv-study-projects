movir 0xF0 rr ; write 0xF0 to the result register
movir 0x50 r0 ; write 0x50 to r0
movir 0x03 r1 ; write 0x03 to r1
add r0 r1 r2  ; add r0+r1 and store in r2
movrr r2 rr   ; move from r2 to the result register
jmp 0         ; end