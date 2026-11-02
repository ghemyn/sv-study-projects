; bubble sort test

movir 16 r7 ; r7 = N

; step 1: generate N random values
movir 0 r0 ; r0 - loop counter
movir 0xB8 r1 ; r1 - random value
movir 1 r6 ; r6 - increment

loop_generate:
    movir 0x77 r2 ; reset r1 to the initial random value
    add r1 r2 r1 ; r1 = r1 + r2
    add r0 r1 r1 ; r1 = r0 + r1
    xor r1 r2 r1 ; r1 = r1 ^ r2
    not r1 r1 ; r1 = ~r1
    add r1 r2 r1 ; r1 = r1 + r2
    add r1 r1 r1 ; r1 = r1 * 2
    
    movrm r1 r0 ; store random value in ram[r0]
            
    add r0 r6 r0 ; increment loop counter
    cmp r0 r7
    jl loop_generate

; step 2: display the N random values

movir 0 r0 ; r0 - loop counter
loop_display1:
    movmr r0 rr ; output ram[r0]

    add r0 r6 r0 ; increment loop counter
    cmp r0 r7
    jl loop_display1

movir 0 rr ; reset the result register to 0

; step 3: sort the N random values using bubble sort

; i = 0
movir 0 r0 ; r0 - outer loop counter
outer_loop:
    ; j = i+1
    movrr r0 r1 ; r1 - inner loop counter
    add r1 r6 r1 ; increment inner loop counter

    inner_loop:
        movir 0 rr

        ; compare ram[i] and ram[j]
        movmr r0 r2
        movmr r1 r3

        cmp r2 r3
        ;jul no_swap ; unsigned comparison
        jl no_swap ; signed comparison
        
        ; swap ram[i] and ram[j]
        movrm r2 r1
        movrm r3 r0

        no_swap:

        add r1 r6 r1 ; increment inner loop counter
        cmp r1 r7
        jl inner_loop

    add r0 r6 r0 ; increment outer loop counter
    cmp r0 r7
    jl outer_loop

; step 4: display the N sorted values

movir 0 r0 ; r0 - loop counter
loop_display2:
    movmr r0 rr ; output ram[r0]

    add r0 r6 r0 ; increment loop counter
    cmp r0 r7
    jl loop_display2

halt