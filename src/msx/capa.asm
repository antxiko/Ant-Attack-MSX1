; Capa experimental MSX para Ant Attack. Vive en RAM en la pagina 0 (0x0000),
; donde en el Spectrum estaba la ROM. El juego ocupa 0x4000-0xFFFF igual que alli.
; Los .inc los genera tools/build.py a partir del snapshot.

VDPD    equ 098h
VDPC    equ 099h
bitmap_shadow equ 6000h       ; BASIC ZX ya sustituido por menus MSX
PSGA    equ 0A0h
PSGD    equ 0A1h
PPIA    equ 0A8h
PPIB    equ 0A9h
PPIC    equ 0AAh

        org 0000h
        di
        jp L_start
        ds 0008h-$
; --- rst 08h: sustituye a IN A,(0FEh). Entra A = byte alto del puerto (filas
; del Spectrum a 0 las seleccionadas). Sale A con bits 0-4 = teclas (0=pulsada).
        jp kbd
        ds 0010h-$
; --- rst 10h: sustituye a OUT (0FEh),A del borde
        ret                     ; Ant Attack usa RST 10h para imprimir texto
        ds 0018h-$
; Sustituye IN A,(C) cuando C=FEh; el selector de fila esta en B.
        jp kbd_c
        ds 0038h-$
        jp isr                  ; reconocer IRQ del VDP antes de volver

; ---------------------------------------------------------------- arranque
L_start:
        ld sp,3FF0h
        call copy_image
        call psg_init
        call apply_controls
new_game:
        xor a
        ld (level_number),a
        ld (score),a
        ld (score+1),a
        ld (rescue_variant),a
        ld (reset_requested),a
        call menu_title
next_level:
        ld a,3
        ld (0B436h),a
        ld a,233
        ld (0B437h),a          ; BASIC 750: 1001, solo al empezar nivel
        call menu_intro
restart:
        di
        ld sp,7FF0h
        call vdp_init
        ld a,1
        ld (game_active),a
        xor a
        ld (message_id),a
        ld (message_timer),a
        ld (message_dirty),a
        ld (timer_extra_phase),a
        ld (depth_cache_valid),a
        ld hl,game_init
        ld de,0B420h
        ld bc,22              ; conserva B436/B437 al reintentar (BASIC 70)
        ldir
        ld hl,object_init
        ld de,0B480h
        ld bc,128
        ldir
        ld b,2                ; BASIC 190 fija las cuatro, tambien en nivel 1
        ld a,(level_number)
        cp 4
        jr c,ant_speed_set
        inc b
        cp 8
        jr c,ant_speed_set
        inc b
ant_speed_set:
        ld a,b
        ld (0B4CDh),a
        ld (0B4DDh),a
        ld (0B4EDh),a
        ld (0B4FDh),a
ant_speed_done:
        ld a,(player_sex)
        or a
        jr z,boy_sprite
        ld a,108
        ld (0B483h),a
        ld a,220
        ld (0B493h),a
boy_sprite:
        ld a,(level_number)
        ld l,a
        ld h,0
        add hl,hl
        ld de,rescue_ptrs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,(level_number)
        or a
        jr z,rescue_pos_ready
        ld a,(rescue_variant)
        ld e,a
        ld d,0
        add hl,de
        add hl,de
        add hl,de
rescue_pos_ready:
        ld a,(hl)
        ld (0B490h),a
        ld (0B49Ah),a
        inc hl
        ld a,(hl)
        ld (0B491h),a
        ld (0B49Bh),a
        inc hl
        ld a,(hl)
        ld (0B492h),a
        ld (0B49Ch),a
        ld a,0FFh
        ld (0B438h),a          ; FRAMES_LEFT: partida continua
        ld hl,4000h
        ld de,4001h
        ld bc,17FFh
        ld (hl),0
        ldir
        ld hl,5800h
        ld de,5801h
        ld bc,02FFh
        ld (hl),38h            ; ciudad gris: tinta negra, papel blanco
        ldir
        ld hl,bitmap_shadow
        ld de,bitmap_shadow+1
        ld bc,0EFFh            ; 3840 bytes de imagen jugable
        ld (hl),0FFh
        ldir
        call dump
        call hud_static
        call scan_sprite_init
        call hud_invalidate
        call draw_hud
        xor a
        ld (reset_requested),a
        call 8000h
        xor a
        ld (game_active),a
        ld a,(reset_requested)
        or a
        jp nz,new_game
        ld hl,return_count
        inc (hl)
        ld a,(0B49Dh)         ; rescatada: avanzar de nivel
        cp 2
        jr nz,round_lost
        call add_score
        ld a,(0B437h)
        and 3
        ld (rescue_variant),a
        ld a,(level_number)
        inc a
        ld (level_number),a
        cp 10
        jr z,game_won
        call menu_score
        jp next_level
round_lost:
        ld a,(0B436h)
        ld b,a
        ld a,(0B437h)
        or b
        jr nz,round_retry
        call menu_timeout
        jp new_game
round_retry:
        call menu_gameover
        jp restart
game_won:
        call menu_victory
        jp new_game

; Llamada de COPY_TO_SCREEN: conserva la copia original y vuelca al VDP.
game_screen_hook:
        call msx_copy_bitmap
        call dump
        call draw_hud
        ret

; El contador Spectrum baja una unidad cada tres vueltas de juego. Una
; unidad adicional cada diez vueltas aumenta su cadencia alrededor del 30%.
; No altera el divisor original ni el contador de salida de la partida.
game_timer_hook:
        call 08DD0h
        push af
        push hl
        ld a,(timer_extra_phase)
        inc a
        cp 10
        jr c,gt_store_phase
        xor a
        ld a,(0B436h)
        ld h,a
        ld a,(0B437h)
        ld l,a
        or h
        jr z,gt_reset_phase
        dec hl
        ld a,h
        ld (0B436h),a
        ld a,l
        ld (0B437h),a
gt_reset_phase:
        xor a
gt_store_phase:
        ld (timer_extra_phase),a
        pop hl
        pop af
        ei                      ; deja activo el VBlank para terminar el PSG
        ret

kbd_c:  ld a,b
        jp kbd

game_init:
        db 185,237,0,1,1,1,1,1,1,1,1,1,0,0
        db 0,0,20,0,20,0,20,1,0,0,1
object_init:
        db 0,0,0,220,2,0,0,1,0,1,185,4,0,0,0,0
        db 0,0,0,108,0,0,4,17,3,0,0,0,0,0,0,0
        db 0,0,0,104,0,0,0,16,0,1,0,64,0,0,0,0
        db 0,0,0,248,0,0,0,4,0,1,186,168,0,20,1,0
        db 0,0,0,248,0,0,0,4,0,1,184,168,0,2,4,0
        db 0,0,0,248,0,0,0,4,0,1,182,168,0,2,3,0
        db 0,0,0,248,0,0,0,4,0,1,180,168,0,2,2,0
        db 0,0,0,248,0,0,0,4,0,1,178,168,0,2,1,0
return_count: db 0
level_number: db 0
player_sex: db 0
score: dw 0
rescue_variant: db 0
sound_ptr: dw 0
sound_count: db 0
sound_mode: db 0             ; 0 = scripts maquina, 1 = BEEP BASIC
timer_extra_phase: db 0
reset_requested: db 0
game_active: db 0
control_mode: db 0            ; 0 = giro original, 1 = cuatro direcciones
hud_digits_mode: db 0         ; 0 = cifras normales, 1 = estrechas, 2 = inset
hud_digit_addr: dw 0          ; celda SCREEN 2 del siguiente digito del HUD
hud_cache:
hud_score_cache: dw 0
hud_level_cache: db 0
hud_ammo_cache: db 0
hud_girl_cache: db 0
hud_boy_cache: db 0
hud_time_cache: dw 0
hud_scan_cache: db 0
message_id: db 0
message_timer: db 0
message_dirty: db 0
; Fila MSX en nibble alto y bit en nibble bajo. El último es "abajo".
control_keys:
        db 085h,084h,087h,080h   ; arriba, izquierda, derecha, salto
        db 042h,043h,027h,053h   ; cuatro granadas: M,N,B,V
        db 001h,002h,003h,004h   ; angulos: 1,2,3,4
        db 000h,086h             ; nueva partida: 0; retroceder: abajo
rebind_keys: ds 14
rebind_index: db 0
back_facing: db 0
rescue_ptrs:
        dw rescue_1,rescue_2,rescue_3,rescue_4,rescue_5
        dw rescue_6,rescue_7,rescue_8,rescue_9,rescue_10
rescue_1: db 182,243,1
rescue_2: db 200,213,3,198,234,1,212,195,1,141,227,1
rescue_3: db 240,223,5,192,188,5,184,157,2,181,174,6
rescue_4: db 207,250,3,241,243,6,190,254,1,154,232,2
rescue_5: db 241,183,1,224,158,2,149,176,1,135,175,2
rescue_6: db 209,135,1,185,141,1,132,140,3,200,155,2
rescue_7: db 245,159,6,145,176,6,199,173,3,206,140,4
rescue_8: db 140,150,3,221,137,5,184,147,3,255,159,2
rescue_9: db 147,245,4,154,232,6,219,145,6,178,134,4
rescue_10: db 136,219,3,240,138,5,227,225,3,163,197,6

; Cabecera y paneles como en Spectrum. El marco fijo se instala una vez.
hud_invalidate:
        ld hl,hud_cache
        ld b,9
hi_next:
        ld (hl),0FFh
        inc hl
        djnz hi_next
        ret

; Solo vuelca las cifras cuyo valor ha cambiado desde el ultimo dibujo.
draw_hud:
        push af
        push bc
        push de
        push hl
        ld a,5                 ; cifras TheNestruo tambien en SCORE/RESCUED
        ld (hud_digits_mode),a
        ld hl,(score)
        ld de,(hud_score_cache)
        or a
        sbc hl,de
        jr z,dh_score_done
        ld hl,(score)
        ld (hud_score_cache),hl
        ld hl,0040h             ; SCORE: celda 8 de la fila superior
        call vaddr
        ld hl,(score)
        ld de,10000
        call decimal_place
        ld de,1000
        call decimal_place
        ld de,100
        call decimal_place
        ld de,10
        call decimal_place
        ld a,l
        call emit_digit
dh_score_done:
        ld a,(level_number)
        ld b,a
        ld a,(hud_level_cache)
        cp b
        jr z,dh_level_done
        ld a,b
        ld (hud_level_cache),a
        ld hl,00D0h             ; RESCUED: celda 26
        call vaddr
        ld a,(level_number)
        call emit_two_digits
dh_level_done:
        ld a,1
        ld (hud_digits_mode),a
        ld a,(0B430h)
        ld b,a
        ld a,(hud_ammo_cache)
        cp b
        jr z,dh_ammo_done
        ld a,b
        ld (hud_ammo_cache),a
        ld hl,1218h             ; y=144, dos cifras centradas en AMMO
        ld (hud_digit_addr),hl
        call emit_two_digits
dh_ammo_done:
        ld a,(player_sex)
        or a
        jr z,dh_girl_companion
        ld a,(0B432h)         ; con chica, la primera energia es GIRL
        jr dh_girl_value
dh_girl_companion:
        ld a,(0B434h)         ; con chico, la segunda energia es GIRL
dh_girl_value:
        ld b,a
        ld a,(hud_girl_cache)
        cp b
        jr z,dh_girl_done
        ld a,b
        ld (hud_girl_cache),a
        ld hl,1248h             ; GIRL
        ld (hud_digit_addr),hl
        call emit_two_digits
dh_girl_done:
        ld a,(player_sex)
        or a
        jr z,dh_boy_player
        ld a,(0B434h)         ; con chica, la segunda energia es BOY
        jr dh_boy_value
dh_boy_player:
        ld a,(0B432h)         ; con chico, la primera energia es BOY
dh_boy_value:
        ld b,a
        ld a,(hud_boy_cache)
        cp b
        jr z,dh_boy_done
        ld a,b
        ld (hud_boy_cache),a
        ld hl,1278h             ; BOY
        ld (hud_digit_addr),hl
        call emit_two_digits
dh_boy_done:
        ld hl,(0B436h)
        ld de,(hud_time_cache)
        or a
        sbc hl,de
        jr z,dh_time_done
        ld hl,(0B436h)
        ld (hud_time_cache),hl
        ld hl,12A0h             ; TIME
        ld (hud_digit_addr),hl
        ld a,(0B436h)
        ld h,a
        ld a,(0B437h)
        ld l,a
        ld de,1000
        ld a,2
        ld (hud_digits_mode),a
        call decimal_place
        ld a,3
        ld (hud_digits_mode),a
        ld de,100
        call decimal_place
        ld de,10
        call decimal_place
        ld a,4
        ld (hud_digits_mode),a
        ld a,l
        call emit_digit
dh_time_done:
        xor a
        ld (hud_digits_mode),a
        call draw_message
        call draw_scan
        pop hl
        pop de
        pop bc
        pop af
        ret

; El juego original escribe 04h (se acorta la distancia) o 02h (se aleja)
; en los atributos 5A5A..5AA1. La barra SCAN usa ese mismo color.
draw_scan:
        ld a,(05A5Ah)
        cp 04h
        ld a,9                 ; rojo
        jr nz,ds_color
        ld a,3                 ; verde
ds_color:
        ld c,a
        ld a,(hud_scan_cache)
        cp c
        ret z
        ld a,c
        ld (hud_scan_cache),a
        ld hl,1B03h           ; atributo de color del primer sprite
        ld b,3
ds_sprite:
        push bc
        push hl
        call vaddr
        ld a,c
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        pop hl
        pop bc
        ld de,4
        add hl,de
        djnz ds_sprite
        ret

scan_sprite_init:
        ld hl,3800h           ; patron 0: bloque de 8x8
        ld de,scan_pattern
        ld bc,8
        call hud_copy
        ld hl,1B00h           ; tres sprites, barra de 24 pixeles
        ld de,scan_attributes
        ld bc,13
        jp hud_copy

scan_pattern: db 0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
scan_attributes:
        db 147,212,0,9,147,220,0,9,147,228,0,9,0D0h

hud_static:
        push af
        push bc
        push de
        push hl
        ld hl,0000h
        ld de,hud_patterns
        ld bc,0100h
        call hud_copy
        ld hl,1000h
        ld de,hud_patterns+256
        ld bc,0800h
        call hud_copy
        ld hl,2000h
        ld de,hud_colors
        ld bc,0100h
        call hud_copy
        ld hl,3000h
        ld de,hud_colors+256
        ld bc,0800h
        call hud_copy
        pop hl
        pop de
        pop bc
        pop af
        ret

; HL = VRAM, DE = datos, BC = longitud. Las pausas respetan el VDP MSX1.
hud_copy:
        call vaddr
hc_loop:
        ld a,(de)
        out (VDPD),a
        inc de
        nop
        nop
        nop
        nop
        nop
        dec bc
        ld a,b
        or c
        jr nz,hc_loop
        ret

; HL=resto; DE=valor decimal. Devuelve HL=resto siguiente.
decimal_place:
        ld b,0
dp_sub:
        or a
        sbc hl,de
        jr c,dp_done
        inc b
        jr dp_sub
dp_done:
        add hl,de
        push hl
        ld a,b
        call emit_digit
        pop hl
        ret

emit_digit:
        push bc
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(hud_digits_mode)
        or a
        jr z,ed_normal
        cp 5
        jr z,ed_header
        add hl,hl               ; HUD: 16 bytes por cifra, dos bandas
        ld de,font_hud_digits
        cp 1
        jr z,ed_hud_font
        ld de,font_time_first
        cp 2
        jr z,ed_hud_font
        ld de,font_time_middle
        cp 3
        jr z,ed_hud_font
        ld de,font_time_last
ed_hud_font:
        add hl,de
        push hl
        ld hl,(hud_digit_addr)
        call vaddr
        pop hl
        call emit_char           ; y=144..151
        push hl
        ld hl,(hud_digit_addr)
        ld de,0100h
        add hl,de
        call vaddr
        pop hl
        call emit_char           ; y=152..159
        ld hl,(hud_digit_addr)
        ld de,8
        add hl,de
        ld (hud_digit_addr),hl
        jr ed_done
ed_normal:
        ld de,font_digits
        jr ed_small_font
ed_header:
        ld de,font_header_digits
ed_small_font:
        add hl,de
        call emit_char
ed_done:
        pop de
        pop bc
        ret

emit_two_digits:
        cp 100
        jr c,etd_range
        ld a,99
etd_range:
        ld b,0
etd_sub:
        cp 10
        jr c,etd_done
        sub 10
        inc b
        jr etd_sub
etd_done:
        push af
        ld a,b
        call emit_digit
        pop af
        call emit_digit
        ret

emit_char:
        push bc
        ld b,8
ec_loop:
        ld a,(hl)
        out (VDPD),a
        inc hl
        nop
        nop
        nop
        nop
        nop
        djnz ec_loop
        pop bc
        ret

font_l: db 00h,60h,60h,60h,60h,60h,7Eh,00h
font_blank: db 0,0,0,0,0,0,0,0
font_t: db 00h,7Eh,18h,18h,18h,18h,18h,00h
font_a: db 00h,18h,3Ch,66h,7Eh,66h,66h,00h
font_p: db 00h,7Ch,66h,66h,7Ch,60h,60h,00h
font_r: db 00h,7Ch,66h,66h,7Ch,6Ch,66h,00h
font_digits:
        db 00h,3Ch,66h,6Eh,76h,66h,3Ch,00h
        db 00h,18h,38h,18h,18h,18h,7Eh,00h
        db 00h,3Ch,66h,06h,1Ch,30h,7Eh,00h
        db 00h,3Ch,66h,0Ch,06h,66h,3Ch,00h
        db 00h,0Ch,1Ch,3Ch,6Ch,7Eh,0Ch,00h
        db 00h,7Eh,60h,7Ch,06h,66h,3Ch,00h
        db 00h,3Ch,60h,7Ch,66h,66h,3Ch,00h
        db 00h,7Eh,06h,0Ch,18h,18h,18h,00h
        db 00h,3Ch,66h,3Ch,66h,66h,3Ch,00h
        db 00h,3Ch,66h,66h,3Eh,06h,3Ch,00h

        include "hud_digits.inc"

        include "menu.inc"

; PSG: una voz para las notas de los scripts originales. Cada nota conserva
; su altura relativa y duración codificadas; no intenta emular el altavoz ULA.
sound_intro:
        ld hl,sound_basic_title
        ld (sound_ptr),hl
        ld a,1
        ld (sound_mode),a
        xor a
        ld (sound_count),a
        jp sound_tick

sound_timeout:
        ld hl,sound_basic_timeout
        ld (sound_ptr),hl
        ld a,1
        ld (sound_mode),a
        xor a
        ld (sound_count),a
        jp sound_tick

; BASIC 960: BEEP .01,40, justo despues de pulsar una tecla en la
; pantalla de texto. El PSG no puede clavar el timbre ULA, pero 42 da
; aproximadamente 2,66 kHz y este bucle dura unos 10 ms a 3,58 MHz.
sound_ready:
        call sound_stop
        xor a
        out (PSGA),a
        ld a,42
        out (PSGD),a
        ld a,1
        out (PSGA),a
        xor a
        out (PSGD),a
        ld a,7
        out (PSGA),a
        ld a,0BEh
        out (PSGD),a
        ld a,8
        out (PSGA),a
        ld a,12
        out (PSGD),a
        ld bc,1300
sr_wait:
        dec bc
        ld a,b
        or c
        jr nz,sr_wait
        jp sound_stop

; Las cuatro distancias mantienen su proporcion, con mas tiempo de vuelo
; para la escala visual del port MSX. El motor original sigue resolviendo
; movimiento y colisiones; solo se amplía la cuenta antes de la detonacion.
grenade_start:
        add a,a                 ; M/N/B/V: 2/4/8/16 -> 4/8/16/32
        ld (0B42Eh),a
        jp 08D22h

sound_event:
        push af
        push bc
        push de
        push hl
        cp 1
        jr c,se_done
        cp 18
        jr nc,se_done
        cp 13
        jr nz,se_pickup_check
        ld de,sound_seq_rescue
        jr se_start
se_pickup_check:
        cp 12
        jr nz,se_lookup
        ld de,sound_seq_pickup
        jr se_start
se_lookup:
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,sound_ptrs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
se_start:
        ld a,i
        push af
        di
        ld (sound_ptr),de
        xor a
        ld (sound_mode),a
        ld (sound_count),a
        call sound_tick
        pop af
        jp po,se_done
        ei
se_done:
        pop hl
        pop de
        pop bc
        pop af
        jp message_event

message_event:
        push af
        ld a,(game_active)
        or a
        jr z,me_done
        pop af
        cp 1
        ret c
        cp 18
        ret nc
        ld (message_id),a
        ld a,45
        ld (message_timer),a
        ld a,1
        ld (message_dirty),a
        ret
me_done:
        pop af
        ret

draw_message:
        ld a,(message_timer)
        or a
        jr z,dm_check
        dec a
        ld (message_timer),a
        jr nz,dm_check
        xor a
        ld (message_id),a
        inc a
        ld (message_dirty),a
dm_check:
        ld a,(message_dirty)
        or a
        ret z
        xor a
        ld (message_dirty),a
        ld bc,1601h
        ld hl,message_blank
        call menu_print
        ld a,(message_id)
        or a
        ret z
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,message_ptrs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld bc,1601h
        jp menu_print

message_ptrs:
        dw msg_fall,msg_fell,msg_shot,msg_none,msg_none
        dw msg_blast,msg_bitten,msg_none,msg_question,msg_got
        dw msg_none,msg_hero,msg_congrats,msg_eaten,msg_eaten
        dw msg_ant,msg_none
message_blank: db "                              ",0
msg_none: db 0
msg_fall: db "NASTY FALL!",0
msg_fell: db "HELP! I FELL!",0
msg_shot: db "GOOD SHOT!",0
msg_blast: db "YOU BLEW YOURSELF UP!",0
msg_bitten: db "BITTEN!",0
msg_question: db "HOW COULD YOU?",0
msg_got: db "THEY GOT ME!",0
msg_hero: db "MY HERO! TAKE ME AWAY!",0
msg_congrats: db "CONGRATULATIONS!",0
msg_eaten: db "EATEN ALIVE!",0
msg_ant: db "PARALYSED AN ANT!",0

sound_tick:
        push af
        push bc
        push de
        push hl
        ld a,(sound_count)
        or a
        jr z,st_next
        dec a
        ld (sound_count),a
        jp nz,st_done
st_next:
        ld hl,(sound_ptr)
        ld a,h
        or l
        jp z,st_done
        ld a,(sound_mode)
        or a
        jr nz,st_basic
        ld a,(hl)
        or a
        jp z,st_stop
        inc hl
        ld (sound_ptr),hl
        ld b,a
        and 070h
        rrca
        rrca
        rrca
        rrca
        inc a
        ld c,a
        ld a,b
        and 00Fh
        cp 15
        jr z,st_noise
        ld a,b
        and 00Fh               ; 8E45h: el interprete original pasa solo 0..15 a 8B80h
        ld e,a
        ld d,0
        ld hl,sound_frames
        add hl,de
        ld a,(hl)
        call st_set_count
        ld a,e
        add a,a
        ld l,a
        ld h,0
        ld de,sound_periods
        add hl,de
        xor a
        out (PSGA),a
        ld a,(hl)
        out (PSGD),a
        inc hl
        ld a,1
        out (PSGA),a
        ld a,(hl)
        out (PSGD),a
        ld a,0BEh
        jr st_mixer
st_basic:
        ld a,(hl)
        cp 0FFh
        jr z,st_stop
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        ld (sound_count),a
        inc hl
        ld (sound_ptr),hl
        xor a
        out (PSGA),a
        ld a,b
        out (PSGD),a
        ld a,1
        out (PSGA),a
        ld a,c
        out (PSGD),a
        ld a,0BEh
        jr st_mixer
st_noise:
        ld a,2
        call st_set_count
        ld a,6
        out (PSGA),a
        ld a,5
        out (PSGD),a
        ld a,0B7h
st_mixer:
        ld b,a
        ld a,7
        out (PSGA),a
        ld a,b
        out (PSGD),a
        ld a,8
        out (PSGA),a
        ld a,12
        out (PSGD),a
        jr st_done
st_set_count:
        ld b,a
        xor a
st_count_loop:
        add a,b
        dec c
        jr nz,st_count_loop
        ld (sound_count),a
        ret
st_stop:
        call sound_stop
st_done:
        pop hl
        pop de
        pop bc
        pop af
        ret

sound_stop:
        xor a
        ld (sound_ptr),a
        ld (sound_ptr+1),a
        ld (sound_count),a
        ld (sound_mode),a
        ld a,8
        out (PSGA),a
        xor a
        out (PSGD),a
        ret

        include "sound.inc"

; Entradas configurables del juego. Las rutinas BASIC del menú leen la matriz
; MSX directamente y no dependen de este mapa Spectrum.
apply_controls:
        ld a,(control_keys+0)
        ld (keymap+4),a          ; V del Spectrum = avanzar
        ld a,(control_keys+1)
        ld (keymap+37),a         ; M = girar izquierda
        ld a,(control_keys+2)
        ld (keymap+36),a         ; Symbol Shift = girar derecha
        ld a,(control_keys+3)
        ld (keymap+3),a          ; C = saltar
        ld a,(control_keys+4)
        ld (keymap+6),a          ; S/D/F/G = granadas
        ld a,(control_keys+5)
        ld (keymap+7),a
        ld a,(control_keys+6)
        ld (keymap+8),a
        ld a,(control_keys+7)
        ld (keymap+9),a
        ld a,(control_keys+8)
        ld (keymap+35),a         ; Space = angulo 1
        ld a,(control_keys+9)
        ld (keymap+30),a         ; Enter = angulo 2
        ld a,(control_keys+11)
        ld (keymap+20),a         ; 0 = angulo 4
        ld a,(control_keys+10)
        ld (keymap+25),a         ; P = angulo 3
        ld a,(control_keys+12)
        ld (keymap+15),a         ; 1 = salir y empezar de nuevo
        ld a,(control_mode)
        or a
        ret z
        ld a,0FFh
        ld (keymap+4),a          ; el modo direccional genera avance en MSX
        ld (keymap+36),a         ; sin giros originales
        ld (keymap+37),a
        ret

; La entrada original empieza con LD BC,0FEFEh. Se sustituye por JP aqui.
; La lectura Spectrum en 8063h conserva salto y resto de teclas.
msx_control_input:
        ld bc,0FEFEh
        ld a,(control_mode)
        or a
        jp z,08063h
        call 08063h
        ld a,(ix+6)
        or a
        ret nz
        ld a,(control_keys+0)
        call msx_key_down
        jr c,mci_up
        ld a,(control_keys+1)
        call msx_key_down
        jr c,mci_left
        ld a,(control_keys+2)
        call msx_key_down
        jr c,mci_right
        ld a,(control_keys+13)
        call msx_key_down
        ret nc
        xor a                   ; abajo: eje positivo de pantalla
        jr mci_move
mci_up: ld a,2
        jr mci_move
mci_left:
        ld a,3
        jr mci_move
mci_right:
        ld a,1
mci_move:
        ld c,a
        ld a,(0B422h)          ; angulo de la camara (0..3)
        ld b,a
        ld a,c
        sub b
        and 03h                ; direccion de mundo relativa a la pantalla
        ld (ix+4),a
        set 2,(ix+7)           ; avance del motor original
        ret

; A = fila MSX (0..10), devuelve A con bits a cero si tecla pulsada.
msx_row:
        push bc
        ld c,a
        in a,(PPIC)
        and 0F0h
        or c
        out (PPIC),a
        in a,(PPIB)
        pop bc
        ret

; A = fila*16+bit, devuelve acarreo si esta pulsada. FF = desactivada.
msx_key_down:
        cp 0FFh
        jr z,mkd_no
        push bc
        push de
        ld b,a
        and 0Fh
        ld e,a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        call msx_row
        ld b,e
        inc b
mkd_shift:
        rrca
        djnz mkd_shift
        ccf
        pop de
        pop bc
        ret
mkd_no:
        or a
        ret

; La flecha abajo camina hacia atras usando la colision del motor original.
; Se invierte el rumbo solo durante MOVE_OBJECT, conservando la orientacion.
msx_player_move:
        push af
        ld a,(control_mode)
        or a
        jr nz,mpm_direct
        ld a,(control_keys+13)
        call msx_key_down
        jr c,mpm_back
mpm_direct:
        pop af
        jp 089D0h
mpm_back:
        pop af
        ld a,(ix+4)
        ld (back_facing),a
        xor 2
        ld (ix+4),a
        set 2,(ix+7)
        call 089D0h
        push af
        ld a,(back_facing)
        ld (ix+4),a
        pop af
        ret

; Mantiene al personaje dentro de una zona central en las cuatro vistas.
; B465 solo es la proyeccion del jugador entre 8600h y la ordenacion 8580h;
; no es una coordenada persistente. Una entidad fuera devuelve FF en alto.
; Se usan mundo/altura antes de proyectar para que nunca desaparezca.
msx_camera_follow:
        push af
        push bc
        push de
        push hl
        ld a,(0B422h)
        and 3
        add a,a
        ld e,a
        ld d,0
        ld hl,camera_offsets
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,(0B482h)
        ld d,a
        ld a,(0B422h)
        and 2
        jr z,cf_x_height
        ld a,d
        neg
        ld d,a
cf_x_height:
        ld a,(0B480h)
        sub c
        add a,d
        ld hl,0B420h
        call camera_axis
        ld a,(0B482h)
        ld d,a
        ld a,(0B422h)
        inc a
        and 2
        jr nz,cf_y_height
        ld a,d
        neg
        ld d,a
cf_y_height:
        ld a,(0B481h)
        sub b
        add a,d
        ld hl,0B421h
        call camera_axis
        call camera_bottom_margin
        pop hl
        pop de
        pop bc
        pop af
        ret

; El borde inferior necesita mas aire junto al HUD. La banda anterior
; permite Y proyectada hasta 27; ahora empieza a seguir al superar 23.
; Ajuste diagonal en mundo: conserva X proyectada y los otros margenes.
camera_bottom_margin:
        ld a,(0B420h)
        ld d,a
        ld a,(0B480h)
        sub d
        ld d,a                 ; dx modular
        ld a,(0B421h)
        ld e,a
        ld a,(0B481h)
        sub e
        ld e,a                 ; dy modular
        ld a,(0B422h)
        and 3
        ld b,a
        bit 1,b
        jr nz,cb_x_positive
        ld a,d
        neg
        ld d,a
cb_x_positive:
        ld a,b
        inc a
        and 2
        jr z,cb_y_positive
        ld a,e
        neg
        ld e,a
cb_y_positive:
        ld a,(0B482h)
        add a,a
        ld c,a
        ld a,d
        add a,e
        sub c                  ; Y pantalla = +/-dx +/-dy - 2*altura
        cp 24
        ret c
        sub 22
        srl a                  ; ceil((Y-23)/2), 1 o 2 pasos
        ld c,a
        bit 1,b
        jr nz,cb_move_x
        neg
cb_move_x:
        ld hl,0B420h
        add a,(hl)
        ld (hl),a
        ld a,b
        inc a
        and 2
        ld a,c
        jr z,cb_move_y
        neg
cb_move_y:
        inc hl
        add a,(hl)
        ld (hl),a
        ret

; Tres casillas por eje: al proyectarse suman como maximo seis, no doce.
; Incluye la altura para mantener el margen al subir a los edificios.
; Recorta al borde de la banda antes de dibujar: un paso al caminar, varios
; si cambia la altura/vista o ya estaba fuera. No deja fotogramas invisibles.
; La resta modular cubre el paso por 255.
camera_axis:
        ld c,a
        sub (hl)
        jp m,ca_negative
        cp 4
        ret c
        ld a,c
        sub 3
        ld (hl),a
        ret
ca_negative:
        neg
        cp 4
        ret c
        ld a,c
        add a,3
        ld (hl),a
        ret

; Mismos offsets angulares que usa el juego en 8400h al elegir vista.
camera_offsets:
        db 0FDh,012h,0EEh,0FDh,003h,0EEh,012h,003h

msx_draw_view:
        call msx_camera_follow
        jp 083B0h              ; genera el mapa con la camara ya actualizada

; 81B0 transforma 672 bytes de terreno en 512 selectores de profundidad.
; Comparamos la entrada completa: incluso las modificaciones del terreno
; invalidan la cache. 8500 altera B500, por eso se restaura en cada acierto.
; RAM libre del BASIC sustituido: 7000..729F entrada, 7300..74FF resultado.
depth_cache_valid: db 0
msx_depth_layers:
        ld a,(depth_cache_valid)
        or a
        jr z,depth_miss
        ld hl,0B180h
        ld de,7000h
        ld b,84
depth_compare:
        rept 8
        ld a,(de)
        cp (hl)
        jr nz,depth_miss
        inc hl
        inc de
        endm
        djnz depth_compare
        ld hl,7300h
        ld de,0B500h
        ld bc,512
        ldir
        ret
depth_miss:
        ld hl,0B180h
        ld de,7000h
        ld bc,672
        ldir
        call 081B0h
        ld hl,0B500h
        ld de,7300h
        ld bc,512
        ldir
        ld a,1
        ld (depth_cache_valid),a
        ret

; Misma copia 8100 del motor: 128 filas de 30 bytes interiores.
; LDI desplegado evita repetir el salto interno de LDIR en cada byte.
msx_copy_bitmap:
        ld hl,0A180h
        ld de,4421h
        ld b,0
        ld a,2
mcb_band:
        push af
        jr mcb_row
mcb_next_row:
        ld c,0E2h
        ex de,hl
        add hl,bc
        ex de,hl
mcb_row:
        ld c,30
        inc hl
        rept 30
        ldi
        endm
        inc hl
        ld a,l
        and 0E0h
        jr nz,mcb_next_row
        inc de
        inc de
        ld a,h
        and 7
        jr z,mcb_next_band
        ld a,d
        add a,0F9h
        ld d,a
        jr mcb_row
mcb_next_band:
        pop af
        dec a
        jr nz,mcb_band
        ret

; ------------------------------------------------ slots y copia de la imagen
; L_RAMV / L_CARTV: db subslot (0FFh = slot no expandido), db primario
L_RAMV:  dw 0
L_CARTV: dw 0
sp_save: db 0

; C = pagina (1 o 2), E = subslot o 0FFh, D = primario
set_page:
        ld a,e
        cp 0FFh
        jr z,sp_prim
        in a,(PPIA)
        ld (sp_save),a
        and 3Fh
        ld b,a
        ld a,d
        rrca
        rrca
        or b
        out (PPIA),a            ; pagina 3 al primario pedido para ver su FFFF
        ld a,(0FFFFh)
        cpl
        ld b,a
        ld a,c
        dec a
        ld a,e
        jr nz,sps2
        rlca
        rlca
        ld l,a
        ld a,b
        and 0F3h
        jr spsw
sps2:   rlca
        rlca
        rlca
        rlca
        ld l,a
        ld a,b
        and 0CFh
spsw:   or l
        ld (0FFFFh),a
        ld a,(sp_save)
        out (PPIA),a
sp_prim:
        in a,(PPIA)
        ld b,a
        ld a,c
        dec a
        ld a,d
        jr nz,spp2
        rlca
        rlca
        ld l,a
        ld a,b
        and 0F3h
        jr sppw
spp2:   rlca
        rlca
        rlca
        rlca
        ld l,a
        ld a,b
        and 0CFh
sppw:   or l
        out (PPIA),a
        ret

; ASCII16: banco de la pagina 1 en 6000h, de la pagina 2 en 7000h (ambos en pag. 1)
; bancos 1,2,3 = imagen 4000-7FFF, 8000-BFFF, C000-FFFF
copy_image:
        ld c,2
        ld de,(L_CARTV)
        call set_page
        ld a,1
        ld (7000h),a
        ld c,1
        ld de,(L_RAMV)
        call set_page
        ld hl,8000h
        ld de,4000h
        ld bc,4000h
        ldir                    ; pagina 1 lista
        ld c,1
        ld de,(L_CARTV)
        call set_page
        ld a,3
        ld (7000h),a
        ld hl,8000h
        ld de,0C000h
        ld bc,3FFFh
        ldir                    ; pagina 3 menos FFFF
        ld a,(L_RAMV)
        inc a
        jr nz,ci_noff           ; slot de RAM expandido: FFFF es su registro
        ld a,(hl)
        ld (de),a
ci_noff:
        ld a,2
        ld (6000h),a
        ld c,2
        ld de,(L_RAMV)
        call set_page
        ld hl,4000h
        ld de,8000h
        ld bc,4000h
        ldir                    ; pagina 2 lista
        ld c,1
        ld de,(L_RAMV)
        jp set_page

; ---------------------------------------------------------------- VDP
vdp_regs: db 02h,0E0h,06h,0FFh,03h,36h,07h,0F1h
vdp_init:
        ld hl,vdp_regs
        ld b,8
        ld c,80h
vi1:    ld a,(hl)
        out (VDPC),a
        ld a,c
        out (VDPC),a
        inc hl
        inc c
        djnz vi1
        ld hl,0                 ; VRAM a cero
        call vaddr
        ld bc,4000h
vi2:    xor a
        out (VDPD),a
        dec bc
        ld a,b
        or c
        jr nz,vi2
        ld hl,1800h             ; tabla de nombres 0..255 x3
        call vaddr
        ld b,3
vi3:    xor a
vi4:    out (VDPD),a
        nop
        nop
        inc a
        jr nz,vi4
        djnz vi3
        ld hl,1B00h             ; sin sprites
        call vaddr
        ld a,0D0h
        out (VDPD),a
        ld hl,shadow            ; fuerza el primer volcado de color
        ld de,shadow+1
        ld bc,767
        ld (hl),0FFh
        ldir
        ret

; HL = direccion VRAM de escritura. La lectura del estado VDP en la ISR
; reinicia su biestable de control: los dos OUT deben ser atomicos.
vaddr:  ld a,i
        push af
        di
        ld a,l
        out (VDPC),a
        ld a,h
        or 40h
        out (VDPC),a
        pop af
        jp po,va_done
        ei
va_done:
        ret

psg_init:
        ld a,7
        out (PSGA),a
        ld a,0BFh               ; tonos y ruido fuera; puerto A entrada, B salida
        out (PSGD),a
        ld b,3
        ld c,8
pi1:    ld a,c
        out (PSGA),a
        xor a
        out (PSGD),a
        inc c
        djnz pi1
        ret

; ---------------------------------------------------------------- interrupcion
isr:    push af
        in a,(VDPC)             ; reconoce la interrupcion del VDP
        call sound_tick
        pop af
        ei
        reti

; ---------------------------------------------------------------- teclado
kbd:    push bc
        push de
        push hl
        push af
        ld a,(control_keys+12)
        call msx_key_down
        jr nc,kbd_no_reset
        ld a,1
        ld (reset_requested),a
kbd_no_reset:
        pop af
        ld c,a
        ld d,0FFh
        ld hl,keymap
        ld b,8
kb1:    rrc c
        jr c,kb_next            ; fila no seleccionada
        push bc
        ld e,1                  ; bit del Spectrum
        ld b,5
kb2:    ld a,(hl)
        cp 0FFh
        jr z,kb3
        push bc
        ld b,a
        rrca
        rrca
        rrca
        rrca
        and 0Fh                 ; fila MSX
        ld c,a
        in a,(PPIC)
        and 0F0h
        or c
        out (PPIC),a
        in a,(PPIB)
        ld c,a
        ld a,b
        and 07h                 ; bit MSX
        inc a
        ld b,a
        ld a,c
kbs:    rrca
        djnz kbs                ; el bit pedido queda en el acarreo
        pop bc
        jr c,kb3
        ld a,e
        cpl
        and d
        ld d,a
kb3:    inc hl
        sla e
        djnz kb2
        pop bc
        jr kb_row
kb_next:
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
kb_row: djnz kb1
        ld a,d
        or 0E0h
        pop hl
        pop de
        pop bc
        ret

; ---------------------------------------------------------------- borde
border: push af
        push hl
        and 7
        ld l,a
        ld h,0
        push de
        ld de,bordcol
        add hl,de
        pop de
        ld a,i
        push af
        di
        ld a,(hl)
        out (VDPC),a
        ld a,87h
        out (VDPC),a
        pop af
        jp po,bd1
        ei
bd1:    pop hl
        pop af
        ret

; ---------------------------------------------------------------- pantalla
; Se llama al final del volcado del juego (0xE795), con la pantalla del
; Spectrum ya en 0x4000. Patrones y colores solo de las celdas cambiadas.
hook_e795:
        ld (0E7AEh),a           ; lo que hacia la instruccion sustituida
dump:   ld a,i
        push af
        di
        pop af
        jp po,du0
        ei
du0:    ld hl,4020h             ; salta la primera fila de 8 pixeles
        ld de,bitmap_shadow
        xor a
        ld (dump_run),a
        ld c,2                  ; solo y=8..127; pie HUD intacto
        ld b,0E0h
du2:    push hl
        push de
        push bc
du_compare:
        ld a,(de)
        cp (hl)
        jr nz,du_changed
        inc de
        inc h
        ld a,(de)
        cp (hl)
        jr nz,du_changed
        inc de
        inc h
        ld a,(de)
        cp (hl)
        jr nz,du_changed
        inc de
        inc h
        ld a,(de)
        cp (hl)
        jr nz,du_changed
        inc de
        inc h
        ld a,(de)
        cp (hl)
        jr nz,du_changed
        inc de
        inc h
        ld a,(de)
        cp (hl)
        jr nz,du_changed
        inc de
        inc h
        ld a,(de)
        cp (hl)
        jr nz,du_changed
        inc de
        inc h
        ld a,(de)
        cp (hl)
        jr nz,du_changed
        pop bc
        pop de
        pop hl
        xor a
        ld (dump_run),a
        ld a,e
        add a,8
        ld e,a
        jr nc,du_next
        inc d
        jr du_next
du_changed:
        pop bc
        pop de
        pop hl
        push hl
        push de
        ld a,(dump_run)
        or a
        jr nz,du_address_ready
        ld h,d
        ld l,e
        ld a,h
        sub 05Fh               ; 6000h RAM -> 0100h VRAM
        ld h,a
        ld a,i
        push af
        di
        call vaddr
        pop af
        jp po,du_stay_di
        ei
du_stay_di:
du_address_ready:
        ld a,1
        ld (dump_run),a
        pop de
        pop hl
        push hl
        push bc
du_write:
        rept 8
        ld a,(hl)
        ld (de),a
        out (VDPD),a
        inc h
        inc de
        endm                    ; 35 T nominales entre OUT, mas esperas MSX
        pop bc
        pop hl
du_next:
        inc l
        dec b
        jp nz,du2
        ld a,h
        add a,8
        ld h,a
        dec c
        jr z,du_colors
        ld b,0
        jp du2
du_colors:
        ; color: 480 celdas del area de juego, indices 32..511
        ld hl,5820h
        ld de,shadow+32
        ld bc,32
dc1:    ld a,(de)
        cp (hl)
        jr z,dc3
        ld a,(hl)
        ld (de),a
        push hl
        push de
        ld l,a
        ld h,attr2col/256
        ld e,(hl)               ; color MSX de este atributo
        ld h,b
        ld l,c
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        or 20h
        ld h,a                  ; 2000h + celda*8
        ld a,i
        push af
        di
        call vaddr
        pop af
        jp po,dc2
        ei
dc2:    ld a,e
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        nop
        nop
        nop
        nop
        nop
        out (VDPD),a
        pop de
        pop hl
dc3:    inc hl
        inc de
        inc bc
        ld a,b
        cp 2
        jr nz,dc1
        ret

dump_run: db 0

        include "tablas.inc"
hud_patterns: incbin "hud_patterns.bin"
hud_colors:   incbin "hud_colors.bin"

        ds 3500h-$
shadow: ds 768
L_END:
