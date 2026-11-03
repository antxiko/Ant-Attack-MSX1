; Pantallas de la parte BASIC original, rehechas en SCREEN 2.
; Las cadenas usan ASCII en mayusculas, 10 = salto de linea, 0 = fin.

menu_clear:
        di
        call sound_stop
        call vdp_init
        ld hl,2000h
        call vaddr
        ld bc,1800h
mc_color:
        ld a,0F1h               ; blanco sobre negro
        out (VDPD),a
        dec bc
        ld a,b
        or c
        jr nz,mc_color
        ret

; B = fila (0..23), C = columna (0..31)
menu_setpos:
        ld a,c
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,b
        jp vaddr

; HL = texto terminado en cero. B/C = fila/columna inicial.
menu_print:
        push de
        ld d,h
        ld e,l
        call menu_setpos
mp_next:
        ld a,(de)
        inc de
        or a
        jr z,mp_done
        cp 10
        jr z,mp_newline
        push de
        call menu_char
        pop de
        inc c
        jr mp_next
mp_newline:
        inc b
        ld c,2
        call menu_setpos
        jr mp_next
mp_done:
        pop de
        ret

menu_char:
        cp 32
        jr nc,mc_in_range
        ld a,32
mc_in_range:
        cp 91
        jr c,mc_index
        ld a,32
mc_index:
        sub 32
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,menu_font
        add hl,de
        jp emit_char

menu_wait_space:
mws_release:
        ei
        halt
        ld a,8
        call msx_row
        bit 0,a
        jr z,mws_release
mws_press:
        halt
        ld a,8
        call msx_row
        bit 0,a
        jr nz,mws_press
        di
        ret

menu_title:
        call menu_clear
        call menu_draw_logo
        ld bc,020Ah
        ld hl,text_title
        call menu_print
        ld bc,040Bh
        ld hl,text_presents
        call menu_print
        ld bc,0C07h
        ld hl,text_credit
        call menu_print
        ld bc,1003h
        ld hl,text_tagline
        call menu_print
        ld bc,1409h
        ld hl,text_gender
        call menu_print
        ld bc,1208h
        ld hl,text_mode_rotate
        ld a,(control_mode)
        or a
        jr z,mt_mode_label
        ld hl,text_mode_direct
mt_mode_label:
        call menu_print
        ld bc,1603h
        ld hl,text_gender_key
        call menu_print
        call sound_intro
        call menu_wait_release
mt_wait:
        ei
        halt
        ld a,3                 ; G fisica MSX
        call msx_row
        bit 4,a
        jr z,mt_girl
        ld a,2                 ; B fisica MSX
        call msx_row
        bit 7,a
        jr z,mt_boy
        ld a,4                 ; K: redefinir
        call msx_row
        bit 0,a
        jr z,mt_redefine
        ld a,5                 ; T: cambiar modo de control
        call msx_row
        bit 1,a
        jr nz,mt_wait
        ld a,(control_mode)
        xor 1
        ld (control_mode),a
        call apply_controls
        call menu_wait_release
        jp menu_title
mt_redefine:
        di
        call menu_redefine
        jp menu_title
mt_boy:
        xor a
        ld (player_sex),a
        di
        ret
mt_girl:
        ld a,1
        ld (player_sex),a
        di
        ret

; Espera una tecla fisica MSX y devuelve su fila*16+bit en A.
menu_scan_key:
        ld b,0
msk_row:
        ld a,b
        call msx_row
        cp 0FFh
        jr nz,msk_found
        inc b
        ld a,b
        cp 11
        jr c,msk_row
        ld a,0FFh
        ret
msk_found:
        ld c,0
msk_bit:
        rrca
        jr nc,msk_code
        inc c
        jr msk_bit
msk_code:
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or c
        ret

menu_wait_release:
mwr_loop:
        ei
        halt
        call menu_scan_key
        cp 0FFh
        jr nz,mwr_loop
        di
        ret

menu_get_key:
        call menu_wait_release
mgk_press:
        ei
        halt
        call menu_scan_key
        cp 0FFh
        jr z,mgk_press
        di
        ret

menu_redefine:
        xor a
        ld (rebind_index),a
mr_next:
        call menu_clear
        ld bc,0308h
        ld hl,text_redefine
        call menu_print
        ld bc,0706h
        ld hl,text_key_for
        call menu_print
        ld a,(rebind_index)
        add a,a
        ld l,a
        ld h,0
        ld de,rebind_name_ptrs
        ld a,(control_mode)
        or a
        jr z,mr_name_ready
        ld de,rebind_direct_ptrs
mr_name_ready:
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld bc,0A04h
        call menu_print
        ld bc,1304h
        ld hl,text_esc_cancel
        call menu_print
mr_wait:
        call menu_get_key
        cp 072h               ; Escape
        ret z
        ld c,a
        ld a,(rebind_index)
        ld b,a
        ld hl,rebind_keys
mr_check:
        ld a,b
        or a
        jr z,mr_store
        ld a,(hl)
        cp c
        jr z,mr_duplicate
        inc hl
        djnz mr_check
mr_store:
        ld (hl),c
        ld a,(rebind_index)
        inc a
        ld (rebind_index),a
        cp 14
        jr c,mr_next
        ld hl,rebind_keys
        ld de,control_keys
        ld bc,14
        ldir
        call apply_controls
        ret
mr_duplicate:
        ld bc,0F05h
        ld hl,text_key_used
        call menu_print
        jr mr_wait
menu_draw_logo:
        ld hl,0700h
        call vaddr
        ld hl,menu_logo
        ld bc,0400h
mdl_next:
        ld a,(hl)
        out (VDPD),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,mdl_next
        ret

menu_intro:
        call menu_clear
        ld bc,0208h
        ld hl,text_level
        call menu_print
        ld a,(level_number)
        inc a
        cp 10
        jr c,mi_one
        ld a,1
        call emit_digit
        xor a
        jr mi_unit
mi_one:
        push af
        xor a
        call emit_digit
        pop af
mi_unit:
        call emit_digit
        ld a,(level_number)
        ld l,a
        ld h,0
        add hl,hl
        ld de,story_ptrs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld bc,0502h
        call menu_print
        ld bc,1405h
        ld hl,text_start
        call menu_print
        call menu_wait_space
        call sound_ready
        ret

menu_gameover:
        call menu_clear
        ld bc,070Bh
        ld hl,text_gameover
        call menu_print
        ld bc,0B07h
        ld hl,text_try_again
        call menu_print
        ld bc,1405h
        ld hl,text_continue
        call menu_print
        jp menu_wait_space

menu_timeout:
        call menu_clear
        call sound_timeout
        ld bc,0708h
        ld hl,text_timeout
        call menu_print
        call menu_show_score
        ld bc,1405h
        ld hl,text_new_game
        call menu_print
        jp menu_wait_space

menu_score:
        call menu_clear
        ld a,13                ; tonadilla original de rescate al pasar de fase
        call sound_event
        ld bc,050Bh
        ld hl,text_rescued
        call menu_print
        ld bc,0906h
        ld hl,text_saved
        call menu_print
        ld a,(level_number)
        call emit_two_digits
        call menu_show_score
        ld bc,1405h
        ld hl,text_continue
        call menu_print
        jp menu_wait_space

menu_victory:
        call menu_clear
        ld a,17
        call sound_event
        ld bc,0504h
        ld hl,text_victory
        call menu_print
        call menu_show_score
        ld bc,1405h
        ld hl,text_continue
        call menu_print
        jp menu_wait_space

menu_show_score:
        ld bc,0C08h
        ld hl,text_score
        call menu_print
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
        jp emit_digit

add_score:
        ld a,(0B436h)
        ld b,a
        ld a,(0B437h)
        ld c,a
        ld a,(level_number)
        inc a
        ld e,a
        ld hl,(score)
as_loop:
        add hl,bc
        dec e
        jr nz,as_loop
        ld (score),hl
        ret

text_title: db "QUICKSILVA",0
text_presents: db "PRESENTS...",0
text_credit: db "SANDY WHITE 1983",0
text_tagline: db "SOFT SOLID 3-D PAT. PENDING",0
text_gender: db "BOY OR GIRL?",0
text_gender_key: db "B/G START  K KEYS  T MODE",0
text_mode_rotate: db "MODE: ROTATE",0
text_mode_direct: db "MODE: DIRECT",0
text_redefine: db "REDEFINE KEYS",0
text_key_for: db "PRESS A KEY FOR:",0
text_esc_cancel: db "ESC CANCELS",0
text_key_used: db "KEY ALREADY USED",0
rebind_name_ptrs:
        dw key_forward,key_left,key_right,key_jump
        dw key_fire1,key_fire2,key_fire3,key_fire4
        dw key_view1,key_view2,key_view3,key_view4
        dw key_reset,key_back
rebind_direct_ptrs:
        dw key_up,key_move_left,key_move_right,key_jump
        dw key_fire1,key_fire2,key_fire3,key_fire4
        dw key_view1,key_view2,key_view3,key_view4
        dw key_reset,key_down
key_forward: db "FORWARD",0
key_left: db "TURN LEFT",0
key_right: db "TURN RIGHT",0
key_up: db "MOVE UP",0
key_move_left: db "MOVE LEFT",0
key_move_right: db "MOVE RIGHT",0
key_jump: db "JUMP",0
key_fire1: db "GRENADE SHORT",0
key_fire2: db "GRENADE MEDIUM",0
key_fire3: db "GRENADE LONG",0
key_fire4: db "GRENADE FAR",0
key_view1: db "VIEW ANGLE 1",0
key_view2: db "VIEW ANGLE 2",0
key_view3: db "VIEW ANGLE 3",0
key_view4: db "VIEW ANGLE 4",0
key_reset: db "NEW GAME",0
key_back: db "WALK BACKWARD",0
key_down: db "MOVE DOWN",0
text_level: db "LEVEL ",0
text_start: db "PRESS SPACE TO START",0
text_continue: db "PRESS SPACE TO CONTINUE",0
text_gameover: db "GAME OVER",0
text_timeout: db "TIME RAN OUT!",0
text_new_game: db "PRESS SPACE FOR NEW GAME",0
text_try_again: db "HAVE ANOTHER GO!",0
text_rescued: db "RESCUED!",0
text_saved: db "PEOPLE SAVED: ",0
text_score: db "SCORE: ",0
text_victory: db "ALL TEN PEOPLE RESCUED!",0

story_ptrs:
        dw story1,story2,story3,story4,story5
        dw story6,story7,story8,story9,story10
story1:
        db "AFTER A LONG JOURNEY YOU SEE ",10
        db "YOUR DESTINATION. THE HIGH ",10
        db "WALLED CITY OF ANTESCHER. ",10
        db "AS YOU STAND AT THE GATE YOU",10
        db "HEAR A CALL OF DISTRESS. ",10
        db "YOU MUST ANSWER IT. GOOD LUCK!",0
story2:
        db "WELL DONE, BUT THAT WAS EASY.",10
        db "NOW THERE IS SOMEONE ELSE TO ",10
        db "SAVE!",0
story3:
        db "SO FAR SO GOOD. ON YOUR FEET ",10
        db "ONCE MORE. NO TIME FOR A ",10
        db "COFFEE BREAK!",0
story4:
        db "ARE YOU BRAVE ENOUGH TO TRY ",10
        db "AGAIN? DONT WASTE TOO MUCH ",10
        db "TIME THINKING!",0
story5:
        db "YOU HAVE A BRAVE HEART. ",10
        db "BETTER USE YOUR BRAIN FROM ",10
        db "NOW ON TOO!",0
story6:
        db "SURVIVAL OF THE FITTEST! ",10
        db "ARE YOU FIT ENOUGH TO ",10
        db "SURVIVE? PROVE IT!",0
story7:
        db "YOU HANDLED THAT WELL. ",10
        db "IT MUST HAVE BEEN TOO EASY. ",10
        db "TRY AGAIN!",0
story8:
        db "WHO WOULD HAVE THOUGHT YOU ",10
        db "COULD GET SO FAR? BETTER ",10
        db "NOT BE SILLY NOW!",0
story9:
        db "ALTHOUGH YOU ARE WEAK, YOU ",10
        db "CANNOT GIVE UP WHILE HUMAN ",10
        db "LIFE IS IN PERIL!",0
story10:
        db "THERE IS ONLY ONE PERSON LEFT",10
        db "IN THE CITY. YOUR MISSION ",10
        db "WILL SOON BE ACCOMPLISHED. ",10
        db "IF YOU LIVE!",0

        include "menu_font.inc"
        include "menu_logo.inc"
