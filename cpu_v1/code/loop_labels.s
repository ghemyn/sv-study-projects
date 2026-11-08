; uint8_t inc = 1;
; uint8_t limit = 4;
; for(uint8_t i = 0; i < limit; i = i + inc) {
;     result = i;    
; }
_start:
movir 129 r2 ; r2 will be the "limit"
movir 0 r3 ; r3 will be the "i"
movir 1 r4 ; r4 will be the "inc"

; 6th byte of ROM:
loop_start:
movrr r3 rr
add r3 r4 r3
cmp r3 r2
jl loop_start     ; repeat if "i<limit"

movir 0xFF rr ; output 0xFF after 4 iterations of the loop
halt

