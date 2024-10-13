org 0x7C00
bits 16

start:
    jmp main

; Prints a string to screen
; Params:
;   - ds:si points to string
puts:
    ; save registers we modify
    push si
    push ax

.putsLoop:
    lodsb           ; loads a single byte from ds:si to al segmentation and increments it
    or al, al       ; or instruction sets zero flag if the result is zero. This is used to test for null
    jz .putsLoopEnd ; jumps when zero flag is set

    mov ah, 0x0e
    mov bh, 0
    int 0x10

    jmp .putsLoop

.putsLoopEnd:
    pop ax
    pop si
    ret

main:
    ; setup data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00

    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

msg_hello: db 'Hello World!', 0

times 510-($-$$) db 0
dw 0xAA55