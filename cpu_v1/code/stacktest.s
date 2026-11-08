; test of the stack operations (PUSH, POP)

_start:

movir 0x10 r1
movrr r1 rr
push r1

movir 0x67 r1
movrr r1 rr
push r1

movir 0xFF r1
movrr r1 rr
push r1

movir 0 rr

pop r2
movrr r2 rr

pop r2
movrr r2 rr

pop r2
movrr r2 rr

halt