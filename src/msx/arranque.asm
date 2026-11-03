; Arranque de la MegaROM (banco 0, pagina 1). Averigua los slots, pone RAM en
; la pagina 0, copia alli la capa MSX y le salta. La capa copia la imagen.
        include "capa_syms.inc"

EXPTBL  equ 0FCC1h
SLTTBL  equ 0FCC5h
T_RAM   equ 0E000h              ; temporales en pagina 3 (se pisan despues)
T_CART  equ 0E002h

        org 4000h
        db "AB"
        dw init
        dw 0,0,0,0,0,0

init:   di
        in a,(0A8h)
        ld b,a
        ; RAM = el slot de la pagina 3 (se supone el mismo para las 4 paginas)
        rlca
        rlca
        and 3
        ld d,a
        add a,EXPTBL and 0FFh
        ld l,a
        ld h,EXPTBL/256
        ld e,0FFh
        bit 7,(hl)
        jr z,i1
        ld a,(0FFFFh)
        cpl
        rlca
        rlca
        and 3
        ld e,a
i1:     ld (T_RAM),de
        ; cartucho = el slot de la pagina 1
        ld a,b
        rrca
        rrca
        and 3
        ld d,a
        add a,EXPTBL and 0FFh
        ld l,a
        ld h,EXPTBL/256
        ld e,0FFh
        bit 7,(hl)
        jr z,i2
        ld a,d
        add a,SLTTBL and 0FFh
        ld l,a
        ld a,(hl)
        rrca
        rrca
        and 3
        ld e,a
i2:     ld (T_CART),de
        ; pagina 0 -> RAM
        ld de,(T_RAM)
        ld a,e
        cp 0FFh
        jr z,i3
        ld a,(0FFFFh)
        cpl
        and 0FCh
        or e
        ld (0FFFFh),a
i3:     in a,(0A8h)
        and 0FCh
        or d
        out (0A8h),a
        ld hl,capa
        ld de,0
        ld bc,CAPA_LEN
        ldir
        ld hl,(T_RAM)
        ld (L_RAMV),hl
        ld hl,(T_CART)
        ld (L_CARTV),hl
        jp L_start

capa:   incbin "capa.bin"
CAPA_LEN equ $-capa
