; reg 0 = return, reg 1 = a, reg 2 = b
add_int: ; int add_int(int a, int b) -> a+b
    add r1 r2 r0 ; returnval = a + b
    ret

; reg 0 = return, reg 1 = a, reg 2 = b
mul_int_unsigned: ; int power_n(int a, int b) -> a*b
    movir 1 r5 ; inc
    movir 0 r4 ; loop_counter
    movir 0 r0 ; returnval = 0

    cmp r2 r0 ; if b == 0
    je mul_int_end
    cmp r1 r0 ; if a == 0
    je mul_int_end


    cmp r1 r2
    jg mul_int_notswapping ; if a > b go straight to multiplication loop
    ; else (if a <= b):
    ; swap a and b to reduce number of iterations
    push r1 ; save old a
    movrr r2 r1 ; a = b
    pop r2 ; b = old a

    mul_int_notswapping:

    mul_int_loop:
        add r0 r1 r0 ; returnval += a

        add r4 r5 r4 ; loop_counter++
        cmp r4 r2 ; repeat b times
        jl mul_int_loop

    mul_int_end:

    ret

pow_int: ; int power_n(int a, int b) -> a^b
    movir 1 r5 ; inc
    movir 0 r4 ; loop_counter
    movir 1 r0 ; returnval = 1

    cmp r1 r4 ; if a != 0
    jne pow_int_nz

    ; else (if a == 0):
    movir 0 r0 ; return 0
    ret    

    pow_int_nz:

    cmp r2 r4 ; if b == 0
    je pow_int_end

    pow_int_loop:
        ; do not save r0 because it is the return value of mul_int anyways
        push r1
        push r2
        push r3
        push r4
        push r5

        movrr r1 r2 ; b = a
        movrr r0 r1 ; a = returnval

        call mul_int_unsigned ; returnval *= a
        
        pop r5
        pop r4
        pop r3
        pop r2
        pop r1

        add r4 r5 r4 ; loop_counter++
        cmp r4 r2 ; repeat b times
        jl pow_int_loop

    pow_int_end:

    ret

_start:
    movir 7 r1
    movir 31 r2
    call add_int
    movrr r0 rr ; output result

    movir 33 r1
    movir 3 r2
    call mul_int_unsigned
    movrr r0 rr ; output result

    movir 7 r1
    movir 3 r2
    call pow_int
    movrr r0 rr ; output result

    halt