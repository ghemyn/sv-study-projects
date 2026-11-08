_start:
movir 0xDE r0
movir 0x00 r7
movrm r0 r7 ; r0 -> ram[0x00]
movir 0xAD r0
movir 0x01 r7
movrm r0 r7 ; r0 -> ram[0x01]
movir 0xBE r0
movir 0x02 r7
movrm r0 r7 ; r0 -> ram[0x02]
movir 0xEF r0
movir 0x03 r7
movrm r0 r7 ; r0 -> ram[0x03]

movir 0x00 r7
movmr r7 r1 ; ram[0x00] -> r1
movrr r1 rr
movir 0x01 r7
movmr r7 r1 ; ram[0x01] -> r1
movrr r1 rr
movir 0x02 r7
movmr r7 r1 ; ram[0x02] -> r1
movrr r1 rr
movir 0x03 r7
movmr r7 r1 ; ram[0x03] -> r1
movrr r1 rr

jmp 8

halt
