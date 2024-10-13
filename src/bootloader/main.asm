org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; FAT12 header
jmp short start
nop

bdb_oem: db 'MSWIN4.1'
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0xE0
bdb_total_sectors: dw 2880
bdb_media_descriptor_type: db 0xF0 ; indicates its a 3.5 inch floppy disk
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sector_count: dd 0
bdb_large_sector_count: dd 0

; extended boot record
ebr_drive_number: db 0
                  db 0 ; reserved for windows NT
ebr_signature: db 0x29
ebr_volume_id: db 0x12, 0x34, 0x56, 0x78 ; doesnt matter
ebr_volume_label: db 'MOLKO OS   ' ; padded with spaces
ebr_system_ident: db 'FAT12   '    ; padded with spaces

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

    ; read something from floppy disk
    ; bios should set DL to drive number
    mov [ebr_drive_number], dl

    mov ax, 1 ; LBA=1, second sector
    mov cl, 1 ; 1 sector to read
    mov bx, 0x7E00 ; data should be after the bootloader
    call disk_read

    mov si, msg_hello
    call puts

    cli
    hlt

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 0x16    ;  wait for keypress
    jmp 0xFFFF:0 ; jumps to beginning of BIOS, which reboots the system

; .halt:
;     cli ; disable interrupts
;     hlt

; Converts LBA address to CHS address (hard disk address)
; Params:
;   ax: LBA address
; Returns:
;   cx [0-5]: sector number
;   cx [6-15]: cylinder
;   dh: head
lba_to_chs:
    push ax
    push dx

    xor dx, dx ; dx = 0
    div word [bdb_sectors_per_track] ; ax = LBA / sectors per track
                                     ; dx = LBA % sectors per track
    inc dx ; dx = (LBA % sectors per track) = sector
    mov cx, dx ; cx = sector
    xor dx, dx ; dx = 0
    div word [bdb_heads] ; ax = (LBA / sectorspertrack) / heads = cylinder
                         ; dx = (LBA / sectorspertrack) % heads = head
    mov dh, dl           ; dh = head
    mov ch, al           ; ch = cylinder (lower 8 byte)
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al ; restore DL (not DH because its used for returning head)
    pop ax     ; restore AX

    ret

; Read sectors from a disk
; Params:
;   ax: LBA address
;   cl: number of sectors to read
;   dl: drive number
;   es:bx: memory address where to store
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax ; al = number of sectors to read

    mov ah, 0x2
    mov di, 3 ; repeat 3 times

.disk_readLoop:
    pusha     ; pushes all registers
    stc       ; set carry flag, some bios dont set it
    int 0x13  ; carry flag cleared = success
    jnc .disk_readDone

    ; read failed
    popa
    call disk_reset
    dec di
    test di, di
    jnz .disk_readLoop

    ; read failed with all attempts
.disk_readFail:
    jmp floppy_error

.disk_readDone:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret

; reset disk controller
; dl: drive number
disk_reset:
    pusha
    mov ah, 0
    stc
    int 0x13
    jc floppy_error
    popa
    ret

msg_hello: db 'Hello World!', ENDL, 0
msg_read_failed: db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0xAA55