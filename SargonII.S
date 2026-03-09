; =====================================================================
; SARGON II CHESS - VIC-20 Disassembly
; =====================================================================
; Original: Dan & Kathe Spracklen, (C) 1979 Hayden Book Co., Inc.
; Adapted for VIC-20 by Andy Finkel
; Disassembly: 6502bench SourceGen v1.0.0
; Assembler: cc65 v2.17.0 (ca65/ld65)
;
; Memory Map:
;   $0000-$00FF  Zero page variables (game state, temp regs)
;   $033C-$0341  Input buffer (6 chars max)
;   $0200-$0205  Joystick move buffer
;   $1000-$101A  Principal variation / best move line
;   $12FE-$131B  Move history stack (last 12 moves, 2 bytes each)
;   $1319-$1327  Exchange evaluation table (SEE)
;   $1327-$133B  Per-ply captured piece / move flags
;   $133B-$1345  Per-ply move index
;   $1346-$13C5  Attack table (pieces attacking each square)
;   $13C6-$1445  Defend table (pieces defending each square)
;   $1445-$146D  Per-ply best from/to squares
;   $146E-$14E5  Board array (10x12 mailbox)
;   $1A00-$1BFF  Custom character set
;   $1E00-$1FF5  Screen RAM (22x23)
;   $9600-$97F5  Color RAM
;
; Board Array ($146E, 10x12 mailbox):
;   Squares $15-$62 are the 8x8 board (rows of 10, 2 border cols)
;   $FF = border/invalid, $00 = empty
;   Piece encoding: bit 7 = color (0=white, 1=black)
;                   bit 6 = has-moved flag
;                   bits 2-0 = type (1=P, 2=N, 3=B, 4=R, 5=Q, 6=K)
;
; Key Zero Page Variables:
;   $07-$08   From/to square (temp), board cursor
;   $0B-$0C   From/to square (current move)
;   $0D       Move flags / piece type temp
;   $0E       Captured piece temp
;   $13       Current piece (full byte from board)
;   $15       Human color (0=white, $80=black)
;   $16       Next color to move (0=white, $80=black)
;   $17       Ply depth (next_color+1)
;   $18       Move number
;   $19       Search depth level (0-6)
;   $1A       Max search depth (level+1)
;   $1B       Endgame flag (level+2)
;   $1E       Positional evaluation accumulator
;   $61-$62   Score (lo/hi) at current node
;   $6A       Material balance (positive = white ahead)
;   $6B       Pawn structure score
;   $6C       White king position (board index)
;   $6D       Black king position (board index)
;   $8B-$8C   Move list pointer (lo/hi)
;   $8D       Current move index in move list
;   $8E-$8F   Move list end pointer (lo/hi)
;
; ".byte $2c" Trick:
;   Throughout the code, ".byte $2c" (opcode for BIT abs) is used to
;   skip the next 2-byte instruction. When execution falls through,
;   the BIT instruction harmlessly reads an absolute address (the next
;   two bytes), effectively skipping them. This saves a JMP instruction.
; =====================================================================

         .setcpu "6502"

; --- Zero page and system equates ---
human_color =    $15            ; human's piece color (0=white, $80=black)
next_color =     $16            ; side to move (0=white, $80=black)
move_number =    $18            ; current full-move number
level    =       $19            ; search depth setting (0-6)
scoreL_stack =   $23            ; score low bytes (indexed by ply)
scoreH_stack =   $30            ; score high bytes (indexed by ply)
opening_ptr =   $94             ; pointer into opening book (2 bytes)
screen_page =    $0288          ; screen memory page register
nmi_vector_l =   $0318          ; NMI vector low byte
nmi_vector_h =   $0319          ; NMI vector high byte
vic_raster =     $9004          ; VIC raster counter (used as RNG seed)
b_init_ram =     $e3a4          ; BASIC ROM: init RAM
b_init_vecs =    $e45b          ; BASIC ROM: init vectors
b_init_hw =      $e518          ; BASIC ROM: init hardware
k_ramtas =       $fd8d          ; KERNAL: RAM test and set
k_init_regs =    $fdf9          ; KERNAL: init I/O registers
k_init_vecs =    $ff8a          ; KERNAL: init vectors
k_out_to_channel = $ffd2        ; KERNAL: output char to channel (CHROUT)
k_getchar =      $ffe4          ; KERNAL: get character (GETIN)
k_cursor_pos =   $fff0          ; KERNAL: set cursor position

         .org    $2000          ; original $a000

;--- PATCH (9 bytes) ---
         sei                    ; 1
         cld                    ; 1
         jsr     k_ramtas       ; 3
         jmp     start          ; 3
         nop                    ; 1
;--- PATCH ---

;--- ORIGINAL (9 bytes) ---
.if 0
         .byte   <start
         .byte   >start
         .byte   <nmi_handler
         .byte   >nmi_handler
         .byte   $41
         .byte   $30
         .byte   $c3
         .byte   $c2
         .byte   $cd
.endif
;--- END OF ORIGINAL ---

; =====================================================================
; I/O AND SCREEN ROUTINES
; =====================================================================

; Clear screen via KERNAL CHROUT ($93 = clear screen char)
clear_screen:   lda     #$93
         jmp     k_out_to_channel

; Clear screen, fill RAM, and home cursor to board origin (col 7, row 6)
clear_and_home:   jsr     clear_screen_fill
home_cursor:   clc
         ldx     #$07
         ldy     #$06
         jmp     k_cursor_pos

; Clear screen and fill screen+color RAM with spaces ($A0)
clear_screen_fill:   jsr     clear_screen
         lda     #$a0
         ldx     #$fd
@fill_loop:  sta     $1dff,x
         sta     $1efc,x
         dex
         bne     @fill_loop
         rts

; Scroll the status bar area (5 chars wide, 16 rows) down by one line
; Preserves A on stack. Source/dest ptrs in $57-$5C.
draw_status_bar:   pha
         ldx     #$03
@load_ptrs:  lda     @ptr_data,x
         sta     $57,x
         dex
         bpl     @load_ptrs
         ldx     #$0f
@row_loop:  ldy     #$00
         lda     $57
         sta     $5b
         clc
         lda     $58
         adc     #$78
         sta     $5c
@col_loop:  lda     ($59),y
         sta     ($57),y
         lda     #$01
         sta     ($5b),y
         iny
         cpy     #$05
         bcc     @col_loop
         lda     $5a
         sta     $58
         lda     $59
         sta     $57
         clc
         adc     #$16
         sta     $59
         bcc     @no_carry
         inc     $5a
@no_carry:  dex
         bne     @row_loop
         jsr     clear_input_line
         pla
         rts

@ptr_data:  .byte   $11
         .byte   $1e
         .byte   $27
         .byte   $1e

; Clear the 5-char input display line at $1F5B with spaces ($60)
clear_input_line:   ldy     #$04
@clr_loop:  lda     #$60
         sta     $1f5b,y
         lda     #$01
         sta     $975b,y
         dey
         bpl     @clr_loop
         rts

; Flash the board 15 times (visual feedback for game events)
flash_board:   lda     #$0f
         sta     $00
@flash_loop:  jsr     redraw_status
         dec     $00
         bne     @flash_loop
         rts

; Put a character to the input display area
; Input: A = character; $F9 = current cursor position
put_char:   ldx     $f9
         cmp     #$0d            ; carriage return?
         beq     redraw_status
         inx
         cpx     #$06
         bcc     @show_it
         jsr     redraw_status
@show_it:  jmp     show_input_char

print_and_redraw:   jsr     print_string_xy
redraw_status:   jsr     draw_status_bar
         ldx     #$00
         stx     $f9
         rts

; Get a line of input from keyboard (up to 5 chars)
; Returns: first char in A, full buffer at $033C
; $F9 = cursor pos, $1F = input mode flags (bit 7 = joystick)
get_input:   ldx     #$00
         stx     $f9
         stx     $1f
get_input_reset:   ldx     #$00
         stx     $00
get_input_loop:   jsr     poll_keyboard
         pha
         lda     $f9
         bne     @redraw
         jsr     clear_input_line
@redraw:  jsr     draw_board_frame
         pla
         bit     $1f
         bpl     @check_key
         jmp     joystick_input

@check_key:  cmp     #$0d
         bcc     get_input_loop
         cmp     #$4a
         bcs     get_input_loop
         cmp     #$14
         beq     handle_delete
         cmp     #$0d
         beq     @enter_key
         ldy     $00
         cpy     #$05
         bcs     get_input_loop
         jsr     store_input_char
         jmp     get_input_loop

@enter_key:  jsr     update_input_cursor
get_input_done:   ldx     #$00
         stx     $f9
         lda     $033c
         rts

handle_delete:   jsr     update_input_cursor
         dec     $00
         bmi     get_input_reset
         bpl     get_input_loop

; Poll keyboard and joystick for input
; Returns: key code in A. Sets $1F bit 7 if joystick used.
; '?' key triggers hint_move directly.
poll_keyboard:   jsr     k_getchar
         bne     @check_hint
         jsr     read_joystick    ; no key: check joystick
         beq     poll_keyboard
         lda     #$80             ; flag: input from joystick
         sta     $1f
@done:  rts

@check_hint:  cmp     #$3f
         bne     @done
         jmp     hint_move

wait_keypress:   jsr     k_getchar
         beq     wait_keypress
         rts

input:   jsr     input_string
         jsr     wait_keypress
echo_char_cr:   pha
         ora     #$80
         jsr     k_out_to_channel
         lda     #$0d
         jsr     k_out_to_channel
         pla
         rts

store_input_char:   ldy     $00
         inc     $00
         sta     $033c,y
update_input_cursor:   ldx     $f9
         cmp     #$14
         beq     @del_char
         cmp     #$0d
         beq     @reset_pos
         inx
         cpx     #$06
         bcc     show_input_char
         rts

@del_char:  lda     #$60
         cpx     #$00
         beq     @reset_pos
         sta     $1f5a,x
         dex
         beq     @save_pos
         bmi     @reset_pos
@save_pos:  stx     $f9
         rts

@reset_pos:  ldx     #$00
         stx     $f9
         rts

show_input_char:   stx     $f9
         ora     #$40
         sta     $1f5a,x
         pha
         lda     #$01
         sta     $975a,x
         pla
         rts

; Produce a beep sound. X = pitch value for VIC sound register.
beep:   stx     $900b
         ldx     #$80
         ldy     #$80
@delay:  dex
         bne     @delay
         dey
         bne     @delay
         sty     $900b
         rts

; Joystick-based move input: navigate board cursor, fire to select squares
; Builds from/to move in $0200 buffer, then copies to $033C input buffer
joystick_input:   ldx     #$36
@set_square:  stx     $07
@wait_joy:  jsr     joy_highlight_sq
         jsr     read_joystick
         beq     @wait_joy
         cmp     #$0d
         beq     @enter_move
         jsr     joy_move_cursor
         jmp     @set_square

@enter_move:  ldx     #$dc
         jsr     beep
         lda     $ab
         clc
         adc     #$41
         jsr     @store_char
         lda     $ac
         eor     #$07
         clc
         adc     #$31
         jsr     @store_char
         lda     $1f
         and     #$01
         bne     @copy_move
         lda     #$2d
         jsr     @store_char
         lda     #$81
         sta     $1f
         bne     @wait_joy

@copy_move:  ldx     #$05
@copy_loop:  lda     $0200,x
         sta     $033c,x
         dex
         bpl     @copy_loop
@wait_release:  jsr     read_joystick
         bne     @wait_release
         sta     $1f
         jmp     get_input_done

@store_char:  ldy     $00
         inc     $00
         sta     $0200,y
         jmp     update_input_cursor

; Read joystick via VIA registers
; Returns: 0 = no input, $0D = fire, $91/$11/$9D/$1D = directions
read_joystick:   sei
         ldx     #$7f             ; set VIA port A DDR for read
         stx     $9122
@debounce:  lda     $9120           ; debounce: read until stable
         cmp     $9120
         bne     @debounce
         ldx     #$ff             ; restore VIA port A DDR
         stx     $9122
         ldx     #$f7             ; set keyboard scan column
         stx     $9120
         cli
         and     #$80             ; check fire button (active low)
         bne     @read_col
; ".byte $2c" trick: LDA #$1D / RTS - returns $1D (right) if fire pressed
; But bit 7 clear means fire, so we get LDA #$1D then RTS
         .byte   $a9              ; LDA #imm (skip next 2 bytes)
         .byte   $1d              ; value: right cursor
         .byte   $60              ; RTS opcode

@read_col:  ldy     $9111
         cpy     $9111
         bne     @read_col
         ldx     #$04
@scan_dirs:  tya
         and     @dir_masks,x
         beq     @found_dir
         dex
         bpl     @scan_dirs
@found_dir:  lda     @dir_keys,x
         rts

@dir_masks:  .byte   $00
         .byte   $04
         .byte   $08
         .byte   $10
         .byte   $20
@dir_keys:  .byte   $00
         .byte   $91
         .byte   $11
         .byte   $9d
         .byte   $0d

; =====================================================================
; DISPLAY AND GRAPHICS
; =====================================================================

; Flash the square at board index $07 (for joystick cursor)
joy_highlight_sq:   lda     $07
         jsr     index_to_coords
         lda     $033c
         sta     $ab
         lda     $033d
         sta     $ac
         lda     #$02
         jsr     flash_square_n
         rts

; Move board cursor based on joystick direction
; A = key code ($9D=left, $1D=right, $91=down, $11=up)
; X = board index delta, Y = wrap-around delta
joy_move_cursor:   ldy     #$08
         ldx     #$ff
         cmp     #$9d
         beq     @apply_dir
         ldy     #$f8
         ldx     #$01
         cmp     #$1d
         beq     @apply_dir
         ldy     #$b0
         ldx     #$0a
         cmp     #$91
         beq     @apply_dir
         ldy     #$50
         ldx     #$f6
         cmp     #$11
         beq     @apply_dir
         ldy     #$ff
         rts

@apply_dir:  txa
         clc
         adc     $07
         tax
         lda     $146e,x
         cmp     #$ff
         bne     @done
         sty     $07
         txa
         clc
         adc     $07
         tax
@done:  rts

; Flash a square N times. flash_square_16 enters with N=16.
; $AB/$AC = file/rank coordinates of square to flash
flash_square_16:   lda     #$10
flash_square_n:   sta     $a8
@flash_loop:  jsr     invert_square
         ldy     #$30
@delay:  dex
         bne     @delay
         dey
         bne     @delay
         dec     $a8
         bne     @flash_loop
         rts

; Animate a piece moving from ($AB,$AC) to ($AD,$AE)
; $AA = piece code at destination (0 = empty after move)
animate_move:   jsr     flash_square_16
         clc
         lda     $ab
         adc     $ac
         and     #$01
         beq     @set_bg
         lda     #$80
@set_bg:  sta     $a9
         jsr     draw_empty_square
         lda     $ad
         sta     $ab
         lda     $ae
         sta     $ac
         lda     $aa
         beq     @done
         jsr     draw_piece
         jsr     flash_square_16
@done:  rts

; Draw a piece at coordinates ($AB,$AC)
; $AA = piece code (bits 0-2=type, bit 7=color, bit 6=has-moved)
; Determines square color (light/dark) and piece glyph index
draw_piece:   lda     $aa
         and     #$bf
         sta     $a7
         beq     @set_bg
         rol     A
         rol     A
         and     #$01
         sta     $a9
         lda     $ab
         clc
         adc     $ac
         and     #$01
         eor     $a9
         sta     $a9
         lda     $a7
         asl     A
         ora     $a9
         sta     $a5
         lda     $a7
         bmi     @black_bg
         lda     #$00
         beq     @set_bg

@black_bg:  lda     #$80
@set_bg:  sta     $a9
         lda     $a7
         bne     @draw_it
         lda     #$01
         sta     $a5
         clc
         lda     $ab
         adc     $ac
         and     #$01
         beq     @set_bg2
         lda     #$80
@set_bg2:  sta     $a9
@draw_it:  jsr     draw_piece_glyph
         rts

; Convert piece encoding to glyph table index
; Maps piece type (bits 0-2) to glyph index, preserving color in bit 7
rotate_piece_enc:   lda     $aa
         rol     A
         php
         ror     A
         and     #$07
         tax
         lda     @glyph_map,x
         plp
         ror     A
         sta     $aa
         rts

@glyph_map:  .byte   $00
         .byte   $02
         .byte   $06
         .byte   $08
         .byte   $04
         .byte   $0a
         .byte   $0c

; Parse board indices $07 (from) and $08 (to) into screen coordinates
; Output: $AB/$AC = from file/rank, $AD/$AE = to file/rank
parse_move_coords:   lda     $07
         jsr     index_to_coords
         lda     $033c
         sta     $ab
         lda     $033d
         sta     $ac
         lda     $08
         jsr     index_to_coords
         lda     $033c
         sta     $ad
         lda     $033d
         sta     $ae
         rts

; Convert board array index (A) to file/rank coordinates
; Divides by 10 to get rank, mod 10 for file. Adjusts for display.
; Output: $033C = file (0-7), $033D = rank (1-8)
index_to_coords:   ldx     #$01
         jsr     byte_to_decimal
         dec     $033c
         lda     $033c
         and     #$07
         sta     $033c
         lda     #$38
         sec
         sbc     $033d
         sta     $033d
         rts

; Animate a piece moving from square $07 to square $08 on the display
animate_piece:   ldx     $08
         lda     $146e,x
         sta     $aa
         jsr     parse_move_coords
         jsr     rotate_piece_enc
         jsr     animate_move
         rts

; Calculate screen RAM address for board square ($AB,$AC)
; Screen RAM base = $1E00, each row = 22 bytes, each square = 2 chars wide
; Output: $A3/$A4 = screen addr, $F7/$F8 = color addr, Y=1, X=2
calc_screen_addr:   lda     #$00
         sta     $a3
         sta     $a4
         lda     $ac
         asl     A
         asl     A
         jsr     add_offset_addr
         lda     $a3
         ldx     #$0a
@mul_loop:  jsr     add_offset_addr
         dex
         bne     @mul_loop
         lda     #$00
         clc
         adc     $a3
         sta     $a3
         lda     #$1e
         adc     $a4
         sta     $a4
         lda     $ab
         asl     A
         jsr     add_offset_addr
         ldy     #$01
         ldx     #$02
         rts

calc_color_addr:   lda     $a3
         sta     $f7
         clc
         lda     $a4
         adc     #$78
         sta     $f8
         rts

add_offset_addr:   pha
         clc
         adc     $a3
         sta     $a3
         bcc     @no_carry
         inc     $a4
@no_carry:  jsr     calc_color_addr
         pla
         rts

; Draw an empty square (enters with glyph index 1 = blank 2x2 tile)
draw_empty_square:   lda     #$01
         sta     $a5
; Draw a piece glyph at screen coords ($AB,$AC)
; $A5 = glyph index (x4 = offset into piece_glyphs table)
; $A9 = background mask (0=light square, $80=dark square)
draw_piece_glyph:   jsr     calc_screen_addr
         lda     $a5
         asl     A
         asl     A
         stx     $a5
         tax
         dex
@draw_loop:  lda     piece_glyphs,x
         eor     $a9
         eor     #$80
         sta     ($a3),y
         lda     #$01
         sta     ($f7),y
         dex
         dey
         bpl     @draw_loop
         ldy     #$01
         lda     #$16
         jsr     add_offset_addr
         dec     $a5
         bne     @draw_loop
         rts

; Invert (flash) a square by XORing screen bytes with $80
invert_square:   jsr     calc_screen_addr
@inv_loop:  lda     ($a3),y
         eor     #$80
         sta     ($a3),y
         dey
         bpl     @inv_loop
         ldy     #$01
         jsr     advance_row
         dex
         bne     @inv_loop
         rts

advance_row:   pha
         lda     #$16
         jsr     add_offset_addr
         pla
         rts

; Draw the entire chess board with all pieces in current positions
; Iterates board array $146E indexes $15-$62, draws each piece
draw_full_board:   jsr     clear_screen
         ldx     #$15
@piece_loop:  lda     $146e,x
         cmp     #$ff
         beq     @next_sq
         sta     $aa
         txa
         pha
         jsr     index_to_coords
         jsr     rotate_piece_enc
         lda     $033c
         sta     $ab
         lda     $033d
         sta     $ac
         jsr     draw_piece
         pla
         tax
@next_sq:  inx
         cpx     #$63
         bne     @piece_loop
draw_board_frame:   jsr     clear_msg_line
         lda     #$00
         sta     $a3
         lda     #$1e
         sta     $a4
         jsr     calc_color_addr
         lda     #$78
         sta     $a5
         ldy     #$10
@rank_loop:  lda     #$80
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         jsr     advance_row
         lda     $a5
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         jsr     advance_row
         dec     $a5
         lda     $a5
         cmp     #$70
         bne     @rank_loop
         ldy     #$00
         lda     #$41
         sta     $a5
@file_loop:  lda     #$80
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         iny
         lda     $a5
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         inc     $a5
         lda     $a5
         iny
         cmp     #$49
         bne     @file_loop
         clc
         ldx     #$15
         ldy     #$0c
         jsr     k_cursor_pos
         ldx     #<@llevel
         ldy     #>@llevel
         jsr     input_string
         lda     level
         ora     #$70
         sta     $1fe0
         clc
         ldx     #$13
         ldy     #$05
         jsr     k_cursor_pos
         ldx     #<@lsargon
         ldy     #>@lsargon
         jmp     input_string

@llevel: .byte   $cc,$c5,$d6,$c5,$cc,$a0,$a0,$a0,$a0,$a0,$00
@lsargon:
         .byte   $9f
         .byte   $12
         .byte   "5WXYZ23"
         .byte   $1d
         .byte   $34
         .byte   $05
         .byte   $92
         .byte   $00

; Display a centered message on the message line below the board
; Input: X/Y = pointer to null-terminated string
show_msg:
         stx     $a5
         sty     $a6
         jsr     clear_msg_line
         ldy     #$ff
@len_loop:  iny
         lda     ($a5),y
         bne     @len_loop
         tya
         lsr     A
         sta     $a7
         lda     #$08
         sec
         sbc     $a7
         jsr     add_offset_addr
         ldy     #$00
@print_loop:  lda     ($a5),y
         beq     @done
         ora     #$40
         sta     ($a3),y
         lda     #$01
         sta     ($f7),y
         iny
         bne     @print_loop
@done:  rts

clear_msg_line:   lda     #$60
         sta     $a3
         lda     #$1f
         sta     $a4
         jsr     calc_color_addr
         ldy     #$15
@clr_loop:  lda     #$80
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         dey
         bpl     @clr_loop
         rts

; Load custom character set into VIC character RAM ($1A00-$1BFF)
; First copies ROM charset ($8400) to $1A00, then overlays custom piece
; glyphs from la55c/la634 into the custom character positions.
; Also creates inverted versions (EOR #$FF) for dark squares.
load_charset:   lda     #$00
         tay
         sta     $57
         sta     $59
         lda     #$1a
         sta     $5a
         lda     #$84
         sta     $58
@copy_loop:  lda     ($57),y
         sta     ($59),y
         inc     $57
         inc     $59
         bne     @check_done
         inc     $58
         inc     $5a
@check_done:  lda     $5a
         cmp     #$1c
         bne     @copy_loop
         lda     $59
         bne     @copy_loop
         sta     $5b
         lda     #$18
         sta     $5c
         lda     #$1c
         sta     $5a
         lda     #<la55c
         sta     $57
         lda     #>la55c
         sta     $58
         jsr     @copy_block
         lda     #$d8
         sta     $59
         sta     $5b
         lda     #<la634
         sta     $57
         lda     #>la634
         sta     $58
@copy_block:  ldy     #$00
@byte_loop:  lda     ($57),y
         sta     ($59),y
         eor     #$ff
         sta     ($5b),y
         iny
         cpy     #$d8
         bne     @byte_loop
         rts

; =====================================================================
; DATA TABLES
; =====================================================================

; Piece glyph table: 4 bytes per glyph (2x2 character tile)
; Indexed by piece type x4: empty, pawn, knight, bishop, rook, queen, king
; Each entry has light-square and dark-square variants
piece_glyphs:   .byte   $00,$00,$00,$00,$1d,$1e,$1b,$1c,$03,$04,$01,$02,$22,$23,$1f,$21
         .byte   $07,$08,$05,$06,$26,$27,$24,$25,$0b,$0c,$09,$0a,$2a,$2b,$28,$29
         .byte   $0f,$10,$0d,$0e,$2e,$2f,$2c,$2d,$13,$14,$11,$12,$2e,$2f,$30,$31
         .byte   $13,$14,$15,$16
la55c:   .byte   $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$01,$03,$03,$03,$01,$0f
         .byte   $00,$00,$80,$c0,$c0,$c0,$80,$f0,$01,$01,$01,$01,$01,$03,$07,$1f
         .byte   $80,$80,$80,$80,$80,$c0,$e0,$f8,$00,$00,$33,$33,$3f,$3f,$3f,$0f
         .byte   $00,$00,$cc,$cc,$fc,$fc,$fc,$f0,$07,$07,$07,$07,$07,$1f,$3f,$3f
         .byte   $e0,$e0,$e0,$e0,$e0,$f8,$fc,$fc,$01,$07,$0f,$0f,$0f,$0f,$07,$03
         .byte   $00,$80,$c0,$60,$f8,$f8,$f8,$c0,$03,$03,$01,$01,$01,$03,$07,$1f
         .byte   $c0,$e0,$f0,$c0,$c0,$e0,$f0,$fc,$00,$01,$03,$07,$07,$07,$03,$01
         .byte   $00,$80,$c0,$a0,$60,$e0,$c0,$80,$03,$07,$07,$03,$01,$03,$0f,$1f
         .byte   $c0,$e0,$e0,$c0,$80,$c0,$f0,$f8,$00,$01,$15,$1f,$0f,$07,$03,$07
         .byte   $00,$80,$a8,$f8,$f0,$e0,$c0,$e0,$07,$03,$03,$03,$03,$07,$1f,$1f
         .byte   $e0,$c0,$c0,$c0,$c0,$e0,$f8,$f8,$01,$01,$07,$07,$01,$03,$07,$07
         .byte   $80,$80,$e0,$e0,$80,$c0,$e0,$e0,$3c,$72,$70,$3c,$0e,$4e,$3c,$00
         .byte   $7e,$4e,$4e,$7e,$4e,$4e,$4e,$00,$7c,$72,$72,$7c,$4e,$4e,$4e,$00
         .byte   $7e,$4e,$40,$5e,$4e,$4e,$7e,$00
; Custom character bitmaps (inverted versions for dark squares)
; Also contains important lookup tables at fixed offsets:
;   la634+216 ($070c): Initial piece setup for board ranks 1 & 8
;   la634+223 ($0713): Piece values: 0,1,3,5,5,10,20 (empty,P,N,B,R,Q,K) x $80 base
;   la634+229 ($0719): Move direction start index per piece type
;   la634+235 ($071f): Number of move directions per piece type
;   la634+242 ($0726): Direction offset table (8 queen dirs + 8 knight dirs)
;   la634+260 ($0738): Piece-square table (positional values per square)
;   la634+266 ($073e): Node count thresholds per depth level
la634:   .byte   $ff,$fe,$fd,$fb,$fb,$fb,$e1,$ef,$ff,$7f,$bf,$df,$df,$df,$87,$f7
         .byte   $e1,$fd,$fd,$fd,$f9,$f3,$c7,$df,$87,$bf,$bf,$bf,$9f,$cf,$e3,$fb
         .byte   $ff,$ff,$8c,$b3,$b3,$bf,$bf,$bf,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
         .byte   $ff,$ff,$31,$cd,$cd,$fd,$fd,$fd,$8f,$e7,$f7,$f7,$c7,$9f,$bf,$bf
         .byte   $f1,$e7,$ef,$ef,$e3,$f9,$fd,$fd,$f1,$e7,$ef,$ef,$ef,$ef,$e7,$f3
         .byte   $3f,$9f,$cf,$63,$fb,$fb,$fb,$c3,$fb,$fb,$f9,$fd,$f9,$f3,$c7,$df
         .byte   $cf,$e7,$f7,$c7,$cf,$e7,$f1,$fd,$fc,$f9,$f3,$f7,$f7,$f7,$f3,$f9
         .byte   $3f,$9f,$cf,$af,$6f,$ef,$cf,$9f,$fb,$f7,$f7,$fb,$f9,$e3,$cf,$df
         .byte   $df,$ef,$ef,$df,$9f,$c7,$f3,$fb,$fe,$c1,$d5,$df,$ef,$f7,$fb,$f7
         .byte   $7f,$83,$ab,$fb,$f7,$ef,$df,$ef,$f7,$fb,$fb,$fb,$f3,$c7,$df,$df
         .byte   $ef,$df,$df,$df,$cf,$e3,$fb,$fb,$fd,$f1,$f7,$f7,$f1,$f3,$f7,$f7
         .byte   $bf,$8f,$ef,$ef,$8f,$cf,$ef,$ef,$3c,$72,$72,$72,$72,$72,$3c,$00
         .byte   $46,$66,$76,$7e,$5e,$4e,$46,$00,$e7,$e7,$e7,$e7,$e7,$e7,$e7,$00
         .byte   $30,$4e,$4c,$40,$4c,$4e,$38,$00,$04,$02,$03,$05,$06,$03,$02,$04
         .byte   $01,$03,$03,$05,$09,$0a,$10,$08,$00,$04,$00,$00,$04,$08,$04,$04
         .byte   $08,$08,$09,$0b,$f5,$f7,$0a,$f6,$01,$ff,$eb,$f4,$08,$13,$15,$0c
         .byte   $f8,$ed,$0b,$09,$0a,$0a,$f5,$f7,$f6,$f6,$00,$01,$02,$05,$10,$20
         .byte   $80,$01,$02,$05,$10,$20,$80,$ff,$00,$00,$01,$02,$03,$03,$02,$01
         .byte   $00,$00,$00,$01,$03,$04,$05,$05,$04,$03,$01,$00,$00,$02,$04,$06
         .byte   $07,$07,$06,$04,$02,$00,$00,$03,$05,$07,$08,$08,$07,$05,$03,$00
         .byte   $00,$03,$05,$07,$08,$08,$07,$05,$03,$00,$00,$02,$04,$06,$07,$07
         .byte   $06,$04,$02,$00,$00,$01,$03,$04,$05,$05,$04,$03,$01,$00,$00,$00
         .byte   $01,$02,$03,$03,$02,$01,$00,$00,$11,$a9
lwelcome_msg:
         .byte   $05
         .byte   $08
         .byte   "WXYZ23"
         .byte   $a0
         .byte   $34
         .byte   $0d
         .byte   $0d
         .byte   $1d
         .byte   "IJ"
         .byte   $1d
.macro   HiAscii Arg
         .repeat .strlen(Arg), I
         .byte   .strat(Arg, I) | $80
         .endrep
.endmacro
         HiAscii "BY DAN & KATHE"
         .byte   $1d
         .byte   $4d
         .byte   $4e
         .byte   $0d
         .byte   $1d
         .byte   $4b
         .byte   $4c
         .byte   $1d
         .byte   $1d
         .byte   $1d
         HiAscii "SPRACKLEN"
         .byte   $1d
         .byte   $1d
         .byte   $1d
         .byte   $1d
         .byte   $4f
         .byte   $50
         .byte   $0d
         .byte   $0d
         .byte   $0d
         .byte   $0d
         .res    6,$1d
         HiAscii "(C)  1979"
         .byte   $0d
         .byte   $1d
         HiAscii "HAYDEN BOOK CO., INC"
         .byte   $0d
         .byte   $0d
         .res    5,$1d
         .byte   $c6,$b1,$a0,$d4,$cf,$a0,$d3,$d4,$c1,$d2,$d4,$00
lgame_or_setup:
         .byte   $13
         .byte   $0d
         .byte   $c7,$c1,$cd,$c5,$a0,$cf,$d2,$a0,$d3,$c5,$d4,$d5,$d0,$a0,$a8,$c7
         .byte   $ac,$d3,$a9,$ba,$00
lchoose_color:
         .byte   $0d
         .byte   $d9,$cf,$d5,$d2,$a0,$c3,$cf,$cc,$cf,$d2,$a0,$a8,$c2,$ac,$d7,$a9
         .byte   $ba,$00
lchoose_level:
         .byte   $cc,$c5,$d6,$c5,$cc,$a0,$cf,$c6,$a0,$d0,$cc,$c1,$d9,$a0,$a8,$b0
         .byte   $ad,$b6,$a9,$ba,$00
lnextcolor:
         .byte   $ce,$c5,$d8,$d4,$a0,$c3,$cf,$cc,$cf,$d2,$a8,$c2,$ac,$d7,$a9,$ba
         .byte   $00
lmovenum:
         .byte   $cd,$cf,$d6,$c5,$a0,$ce,$d5,$cd,$c2,$c5,$d2,$a0,$a8,$ce,$ce,$a9
         .byte   $ba,$00
ladapted:
         .byte   $0d,$0d,$0d,$0d,$35,$0d
         .byte   $c1,$c4,$c1,$d0,$d4,$c5,$c4,$a0,$c2,$d9,$a0,$c1,$ce,$c4,$d9,$a0
         .byte   $c6,$c9,$ce,$cb,$c5,$cc,$00
linvalid_move:
         .asciiz "INVALID MOVE"
lcheck:  .asciiz "CHECK"
lmate:   .asciiz "MATE"
lmatein2:
         .asciiz "MATE IN 2"
loo:     .asciiz " O-O "
looo:    .asciiz "O-O-O"
lpxpep:  .byte   "PXPEP"
lpnbrqk: .byte   $00
         .asciiz "PNBRQK"
lstalemate:
         .asciiz "STALEMATE"
; VIC chip initialization register values (16 bytes for $9000-$900F)
vic_init_regs:
         .byte   $05,$19,$96,$2e,$00,$fe,$00,$00,$ff,$ff,$00,$00,$00,$00,$0f,$6d

; =====================================================================
; NMI HANDLER AND STARTUP
; =====================================================================

; NMI handler - Restore/Stop key triggers game restart
nmi_handler:  

;--- ORIGINAL (14 bytes) ---
.if 0
         bit     $9111          ; 3
         jsr     $ffe1          ; 3
         beq     game_restart          ; 2
         pla                    ; 1
         tay                    ; 1
         pla                    ; 1
         tax                    ; 1
         pla                    ; 1
         rti                    ; 1
.endif
;--- END OF ORIGINAL ---

;--- PATCH (8 bytes) ---
         bit     $9111          ; 3
         jmp     game_restart          ; 3
         .res    2, $ea 
;--- END OF PATCH ---

start:   
;--- ORIGINAL (24 bytes) ---
.if 0
         cld                   ; 1
         jsr     k_ramtas      ; 3
         jsr     k_init_vecs   ; 3
         jsr     k_init_regs   ; 3
         lda     #$1e          ; 2
         sta     screen_page   ; 3
         jsr     b_init_hw     ; 3
         jsr     b_init_vecs   ; 3
         jsr     b_init_ram    ; 3
.endif
;--- END OF ORIGINAL ---

;--- PATCH (30 bytes) ---
         jsr     k_init_vecs    ; 3
         jsr     k_init_regs    ; 3 

         lda     #<nmi_handler  ; 2
         sta     nmi_vector_l   ; 3
         lda     #>nmi_handler  ; 2
         sta     nmi_vector_h   ; 3

         lda     #$1e           ; 2
         sta     screen_page    ; 3
         jsr     b_init_hw      ; 3
         jsr     b_init_vecs    ; 3
         jsr     b_init_ram     ; 3
;--- END OF PATCH ---

         jsr     load_charset
         jsr     init_board
; === GAME RESTART / MAIN LOOP ===
; Resets stack, reinitializes VIC, runs title screen, then game loop
game_restart:   sei
         ldx     #$ff             ; reset stack pointer
         txs
         cli
         ldy     #$11
@init_vic:  lda     vic_init_regs-1,y
         sta     $8fff,y
         dey
         bne     @init_vic
         sty     $f9
         sty     $21
         sty     $22
         sty     $2e
         sty     $2f
         lda     #$05
         sta     $20
         jsr     @welcome
         jsr     draw_full_board
         jsr     flash_board
         jsr     display_move_num
@game_loop:  lda     next_color
         cmp     human_color
         bne     @human_turn
         sei
         jsr     sargon_moves
         cli
         jsr     @next_move
         jmp     @game_loop

@human_turn:  lda     #$03
         sta     $97a7
         jsr     human_moves
         jsr     @next_move
         jmp     @game_loop

@next_move:
         lda     next_color
         eor     #$80
         sta     next_color
         bne     @done
         inc     move_number
         jmp     display_move_num

@done:  rts

@welcome:
         jsr     clear_and_home
         ldx     #<lwelcome_msg
         ldy     #>lwelcome_msg
         jsr     input_string
@title_loop:  jsr     k_getchar
         cmp     #$85
         beq     @start_game
         ldx     $028d
         cpx     #$07
         beq     @show_adapted
         jsr     @screen_x_offset
         jmp     @title_loop

@show_adapted:  jsr     home_cursor
         ldx     #<ladapted
         ldy     #>ladapted
         jsr     $ad27
         jmp     @title_loop

@screen_x_offset:
         tax
         lda     #$01
         cpx     #$1d
         bne     @screen_y_offset
         clc
         adc     $9000
         and     #$8f
         sta     $9000
         rts

@screen_y_offset:
         cpx     #$11
         bne     @screen_scan_mode
         clc
         adc     $9001
         and     #$3f
         sta     $9001
         rts

@screen_scan_mode:
         cpx     #$8c
         bne     @screen_bg_color
         lda     $9000
         eor     #$80
         sta     $9000
         rts

@screen_bg_color:
         cpx     #$86
         bne     @screen_fg_color
         lda     $900f
         clc
         adc     #$10
         sta     $900f
         rts

@screen_fg_color:
         cpx     #$87
         bne     @done2
         inc     $20
         lda     $20
         and     #$07
         sta     $20
         lda     $900f
         and     #$f8
         ora     $20
         sta     $900f
@done2:  rts

@start_game:  jsr     clear_screen_fill
         ldx     #<lgame_or_setup
         ldy     #>lgame_or_setup
         jsr     input
         cmp     #$53
         beq     @setup_mode
         jmp     @new_game

@setup_mode:  jsr     setup_board_editor
         jsr     clear_screen_fill
@ask_color:  ldx     #<lnextcolor
         ldy     #>lnextcolor
         jsr     input
         ldx     #$00
         cmp     #'W'
         beq     @set_color
         cmp     #'B'
         bne     @ask_color
         ldx     #$80
@set_color:  stx     next_color
         lda     #$01
         sta     $1c
         ldx     #<lmovenum
         ldy     #>lmovenum
         jsr     input_string
         lda     #$00
         sta     move_number
@get_digit:  jsr     @read_digit
         cmp     #$0d
         beq     @get_digit
         pha
         ora     #$80
         jsr     k_out_to_channel
         jsr     @read_digit
         cmp     #$0d
         beq     @ones_digit
         jsr     echo_char_cr
         tax
         pla
         tay
         txa
         pha
         tya
         sec
         sbc     #$30
         asl     A
         sta     move_number
         asl     A
         asl     A
         clc
         adc     move_number
         sta     move_number
@ones_digit:  pla
         sec
         sbc     #$30
         clc
         adc     move_number
         sta     move_number
         jmp     @choose_color

@read_digit:  jsr     wait_keypress
         cmp     #$0d
         beq     @digit_done
         cmp     #$30
         bcc     @read_digit
         cmp     #$3a
         bcs     @read_digit
@digit_done:  rts

@new_game:  lda     #$00
         sta     next_color
         sta     $1c
         lda     #$01
         sta     move_number
         jsr     init_board
@choose_color:  ldx     #<lchoose_color
         ldy     #>lchoose_color
         jsr     input
         ldx     #$80
         cmp     #'W'
         beq     @set_human
         cmp     #'B'
         bne     @choose_color
         ldx     #$00
@set_human:  stx     human_color
@choose_level:  ldx     #<lchoose_level
         ldy     #>lchoose_level
         jsr     input
         cmp     #'0'
         bcc     @choose_level
         cmp     #'7'
         bcs     @choose_level
         and     #$0f
         sta     level
         lda     #$00
         ldx     #$1b
@clear_hist:  sta     $12fe,x
         dex
         bpl     @clear_hist
         lda     #$01
         sta     next_color+1
         jmp     init_board_state

; Initialize the 10x12 board array at $146E with starting position
; Fills borders with $FF, places pieces from la634+216 setup data
; White pieces at ranks 1-2, black pieces (OR $80) at ranks 7-8
init_board:   ldx     #$77
         lda     #$ff
@fill_ff:  sta     $146e,x
         dex
         bpl     @fill_ff
         ldx     #$08
         ldy     #$00
@setup_loop:  lda     la634+216,y
         sta     $1483,y
         ora     #$80
         sta     $14c9,y
         lda     #$01
         sta     $148d,y
         ora     #$80
         sta     $14bf,y
         lda     #$00
         sta     $1497,y
         sta     $14a1,y
         sta     $14ab,y
         sta     $14b5,y
         iny
         dex
         bne     @setup_loop
         rts

; =====================================================================
; AI AND HUMAN MOVE HANDLING
; =====================================================================

; Computer plays a move: runs search, checks for mate/stalemate, displays
sargon_moves:
         jsr     draw_board_frame
         lda     #$02
         sta     $97a7
         jsr     calc_move
         lda     scoreH_stack
         bne     @not_mate
         lda     scoreL_stack
         cmp     #$01
         beq     @mate0
@not_mate:  jsr     check_stalemate
         bcs     @stalemate
         jsr     push_move_history
         ldx     #$b4
         jsr     beep
         jsr     execute_display_move
         lda     scoreH_stack
         cmp     #$ff
         bne     @done
         lda     scoreL_stack
         cmp     #$fe
         beq     @show_mate
         ldx     #<lmatein2
         ldy     #>lmatein2
         jsr     show_msg
         lda     scoreL_stack
         eor     #$ff
         lsr     A
         adc     #$6f
         sta     $1f6c
@done:  rts

@stalemate:
         ldx     #<lstalemate
         ldy     #>lstalemate
         jsr     show_msg
         jmp     @wait_restart

@mate0:  lda     next_color
         eor     #$80
         sta     next_color
@show_mate:  ldx     #<lmate
         ldy     #>lmate
         jsr     show_msg
@wait_restart:  ldx     #$c8
         jsr     beep
         cli
         jsr     wait_keypress
         jmp     game_restart

; Convert byte in A to 2-digit decimal ASCII at $033C,X and $033C,X-1
byte_to_decimal:   tay
         lda     #$2f
         sta     $033c,x
         tya
@div10:  cmp     #$0a
         bcc     @store_ones
         inc     $033c,x
         sec
         sbc     #$0a
         bne     @div10
@store_ones:  dex
         ora     #$40
         sta     $033c,x
         rts

; Parse algebraic notation from input buffer at $033C,X
; E.g. "E2" -> board index. Returns carry set if invalid.
; Reads rank (1-8) and file (A-H), converts to 10x12 mailbox index
parse_algebraic:   lda     $033c,x
         and     #$7f
         cmp     #$31
         bcc     @invalid
         cmp     #$39
         bcs     @invalid
         and     #$0f
         clc
         adc     #$01
         asl     A
         sta     $0341
         asl     A
         asl     A
         adc     $0341
         sta     $0341
         dex
         lda     $033c,x
         and     #$7f
         cmp     #$41
         bcc     @invalid
         cmp     #$49
         bcs     @invalid
         and     #$0f
         clc
         adc     $0341
         sta     $07,x
         dex
         dex
         rts

@invalid:  sec
         rts

; Human move input: generate legal moves, get input, validate, execute
human_moves:
         lda     #$01
         sta     $8e
         lda     #$10
         sta     $8f
         jsr     init_move_gen
@input_loop:  jsr     get_input
         ldx     #$04
@parse_loop:  jsr     parse_algebraic
         bcs     @bad_move
         bpl     @parse_loop
         jsr     find_move
         bcs     @bad_move
         jsr     push_move_history
         jsr     draw_board_frame
         jmp     execute_display_move

@bad_move:  ldx     #<linvalid_move
         ldy     #>linvalid_move
         jsr     show_msg
         ldx     #$aa
         jsr     beep
         jmp     @input_loop

; Board setup editor: navigate with cursor keys, type piece letters to place
; RETURN = done, cursor keys = move, piece letter = place piece
setup_board_editor:   jsr     wait_keypress
         jsr     draw_full_board
         ldx     #$15
@set_sq:  stx     $07
@edit_loop:  jsr     joy_highlight_sq
         jsr     k_getchar
         beq     @edit_loop
         cmp     #$0d
         bne     @move_cursor
         jsr     init_board_state
         jsr     clear_screen
         rts

@move_cursor:  jsr     joy_move_cursor
         cpy     #$ff
         bne     @set_sq
         ldx     #$06
@find_piece:  cmp     lpnbrqk,x
         beq     @set_piece
         dex
         bne     @find_piece
         txa
         beq     @place_piece
@set_piece:  stx     $aa
         jsr     wait_keypress
         ldy     #$00
         cmp     #$57
         beq     @set_color
         ldy     #$80
@set_color:  tya
         ora     $aa
         sta     $aa
         jsr     wait_keypress
         ldy     $aa
         and     #$01
         lsr     A
         ror     A
         ror     A
         sta     $aa
         tya
         ora     $aa
@place_piece:  ldx     $07
         sta     $146e,x
         sta     $aa
         jsr     rotate_piece_enc
         jsr     draw_piece
         ldx     $07
         jmp     @edit_loop

; Execute and display a move: animate piece, handle castling/en passant display
; Reads move flags from $1332 to determine special move types
execute_display_move:   jsr     display_move_check
         lda     $0b
         sta     $07
         lda     $0c
         sta     $08
         jsr     animate_piece
         bit     $1332
         bmi     @castling
         bvc     move_done_rts
         lda     #$0a
         bit     next_color
         bmi     @ep_black
         lda     #$f6
@ep_black:  clc
         adc     $08
         sta     $08
         bne     @do_rook
@castling:  lda     $08
         sec
         sbc     $07
         cmp     #$02
         beq     @queenside
         inc     $08
         asl     A
         bne     @rook_from
@queenside:  dec     $08
         inc     $07
@rook_from:  clc
         adc     $07
@do_rook:  sta     $07
         jmp     animate_piece

format_move_str:   bit     $1332
         bmi     @castling
         bvs     @en_passant
         ldx     #$01
         lda     $0b
         jsr     byte_to_decimal
         ldx     #$04
         lda     $0c
         jsr     byte_to_decimal
         ldx     #$2d
         lda     $1328
         beq     @set_sep
         ldx     #$58
@set_sep:  stx     $033e
         ldx     #$3c
         ldy     #$03
         bne     @print_str

@en_passant:  ldx     #<lpxpep
         ldy     #>lpxpep
         bne     @print_str

@castling:  lda     $0c
         sec
         sbc     $0b
         cmp     #$02
         beq     @kingside
         ldx     #<looo
         ldy     #>looo
         bne     @print_str

@kingside:  ldx     #<loo
         ldy     #>loo
@print_str:  lda     #$00
         sta     $0341
move_done_rts:   rts

display_move_check:   jsr     format_move_str
         jsr     print_and_redraw
check_for_check:   lda     next_color
         eor     #$80
         jsr     is_king_checked
         bcc     move_done_rts
         ldx     #<lcheck
         ldy     #>lcheck
         jmp     show_msg

display_move_num:   ldx     #$30
         lda     move_number
@div10:  cmp     #$0a
         bcc     @format
         inx
         sec
         sbc     #$0a
         bne     @div10
@format:  clc
         adc     #$30
         sta     $033d
         txa
         cmp     #$40
         bcs     @blank
         cmp     #$30
         bne     @store_tens
@blank:  lda     #$20
@store_tens:  sta     $033c
         lda     #$00
         sta     $033e
         ldx     #$3c
         ldy     #$03
         jmp     print_and_redraw

display_move_full:   jsr     clear_input_line
         lda     #$00
         sta     $f9
         sta     $00
         jsr     format_move_str
         jsr     print_string_xy
         lda     #$00
         sta     $f9
         sta     $00
         jmp     check_for_check

print_string_xy:   stx     $05
         sty     $06
         ldy     #$00
@print_loop:  lda     ($05),y
         beq     @done
         sty     $a3
         jsr     put_char
         ldy     $a3
         iny
         bne     @print_loop
@done:  rts

input_string:
         stx     $05
         sty     $06
         ldy     #$00
@print_loop:  lda     ($05),y
         beq     @done
         jsr     k_out_to_channel
         iny
         bne     @print_loop
@done:  rts

; Show hint: display the computer's best move (triggered by '?' key)
hint_move:   ldy     level+1
         cpy     #$02
         bcc     @done
         lda     $9f
         sta     $07
         lda     $b4
         sta     $0a
         jsr     find_move
         bcs     @done
         jsr     unmake_move
         jsr     display_move_full
@done:  jmp     poll_keyboard

; Push current move onto the move history stack at $12FE
; Shifts existing entries down, stores from/to/flags at top
push_move_history:   ldx     #$17
@shift_loop:  lda     $12fe,x
         sta     $1302,x
         dex
         bpl     @shift_loop
         lda     $0b
         sta     $12fe
         lda     $0c
         sta     $12ff
         lda     $1328
         sta     $1300
         lda     $1332
         sta     $1301
         rts

; Check for draw by repetition or stalemate
; Compares last move with move from 4 plies ago; also checks material
; Returns carry set if stalemate detected
check_stalemate:   lda     $6a
         bit     human_color
         bmi     @check_val
         eor     #$ff
         clc
         adc     #$01
@check_val:  clc
         adc     #$80
         cmp     #$81
         bcs     @no_draw
         lda     $12fe
         cmp     $130e
         bne     @no_draw
         lda     $12ff
         cmp     $130f
         bne     @no_draw
         lda     $1001
         cmp     $130a
         bne     @no_draw
         lda     $1002
         cmp     $130b
         bne     @no_draw
         lda     #$02
         sta     $8d
         jsr     try_make_move
         bcs     @no_draw
         jsr     evaluate_position
         lda     $1328
         and     #$07
         tax
         lda     la634+223,x
         asl     A
         sec
         sbc     $63
         bmi     @undo
         lda     $1003
         sta     $1001
         lda     $1004
         sta     $1002
         clc
         rts

@undo:  jsr     unmake_move
@no_draw:  lda     #$00
         sta     $8d
         beq     try_make_move

; Find a move in the generated move list matching from=$07, to=$0A
; Returns carry set if not found; sets $9C/$8D to move index if found
find_move:   ldx     #$fe
@scan_loop:  inx
         inx
         lda     $1001,x
         beq     move_not_found
         cmp     $07
         bne     @scan_loop
         lda     $1002,x
         cmp     $0a
         bne     @scan_loop
         stx     $9c
         stx     $8d
; Try to make a move: execute it, check if own king is in check
; If illegal (leaves king in check), unmake and return carry set
try_make_move:   jsr     make_move
         jsr     is_own_king_checked
         bcc     return_from_move  ; legal: carry clear
         jsr     unmake_move       ; illegal: undo
move_not_found:   sec
return_from_move:   rts

; =====================================================================
; MOVE GENERATION
; =====================================================================

; Generate pseudo-legal moves for a single piece
; $07 = piece square, $0D = piece type, $13 = full piece byte
; Walks each direction ray, storing from/to pairs via store_move_pair
; Handles pawn special moves (double push, captures, en passant)
gen_piece_moves:   ldx     $0d
         lda     la634+235,x
         sta     $10
         lda     la634+229,x
         cmp     #$10
         bne     @set_dir
         bit     $13
         bpl     @set_dir
         clc
         adc     #$04
@set_dir:  sta     $0f
@dir_loop:  ldx     $0f
         lda     la634+242,x
         sta     $11
         ldx     $07
@ray_loop:  clc
         txa
         adc     $11
         tax
         lda     $146e,x
         beq     @empty_sq
         cmp     #$ff
         beq     @next_dir
         eor     $13
         bpl     @next_dir
         eor     $13
@empty_sq:  sta     $0e
         lda     $0d
         cmp     #$01
         beq     @pawn_move
         jsr     store_move_pair
         lda     $0e
         bne     @next_dir
         lda     $0d
         cmp     #$06
         beq     @next_dir
         cmp     #$03
         bcs     @ray_loop
@next_dir:  inc     $0f
         dec     $10
         bne     @dir_loop
         rts

@pawn_move:  lda     $10
         cmp     #$03
         bcs     @pawn_capture
         lda     $0e
         bne     @pawn_done
         jsr     store_move_pair
         bit     $13
         bvs     @pawn_done
         dec     $10
         bne     @ray_loop
@pawn_done:  rts

@pawn_capture:  lda     $0e
         beq     @try_ep
         jsr     store_move_pair
         jmp     @next_dir

@try_ep:  jsr     check_en_passant
         jmp     @next_dir

; Store a from/to move pair into the move list at ($8B),Y
store_move_pair:   lda     $07
         sta     ($8b),y
         iny
         txa
         sta     ($8b),y
         iny
         rts

; Check if en passant capture is possible for current pawn
; Verifies pawn is on correct rank, adjacent enemy pawn just double-pushed
check_en_passant:   lda     $07
         bit     $13
         bpl     @check_rank
         clc
         adc     #$0a
@check_rank:  cmp     #$3d
         bcc     @no_ep
         cmp     #$45
         bcs     @no_ep
         lda     $0b
         sec
         sbc     $0c
         cmp     #$14
         beq     @save_to
         cmp     #$ec
         bne     @no_ep
@save_to:  stx     $08
         ldx     $0c
         lda     $146e,x
         and     #$07
         cmp     #$01
         bne     @no_ep
         txa
         ldx     $08
         sec
         sbc     $08
         cmp     #$0a
         beq     @store_ep
         cmp     #$f6
         bne     @no_ep
@store_ep:  jmp     store_move_pair

@no_ep:  rts

; Initialize move generation for the side to move
; Sets up move list pointers, generates castling moves, then iterates
; all pieces of the current color to generate their pseudo-legal moves
; Move list stored at ($8B),Y as pairs of (from, to) bytes, null-terminated
init_move_gen:   ldy     next_color+1
         lda     $8e
         sta     $1459,y
         sta     $8b
         lda     $8f
         sta     $1463,y
         sta     $8c
         lda     #$00
         sta     $133b,y
         sta     $8d
         tay
         jsr     @try_castle
         ldx     #$15
         stx     $07
@piece_loop:  lda     $146e,x
         beq     @next_piece
         cmp     #$ff
         beq     @next_piece
         eor     next_color
         bmi     @next_piece
         eor     next_color
         sta     $13
         and     #$07
         sta     $0d
         jsr     gen_piece_moves
@next_piece:  inc     $07
         ldx     $07
         cpx     #$63
         bcc     @piece_loop
         lda     #$00
         sta     $1d
         sta     ($8b),y
         iny
         tya
         clc
         adc     $8e
         sta     $8e
         lda     $8f
         adc     #$00
         sta     $8f
         rts

@try_castle:  ldx     $6c
         lda     next_color
         bpl     @check_moved
         ldx     $6d
@check_moved:  lda     $146e,x
         and     #$40
         bne     @castle_done
         lda     $146e,x
         sta     $13
         stx     $07
         jsr     is_king_attacked
         bcs     @castle_done
         lda     #$02
         sta     $12
         lda     #$ff
         sta     $09
         lda     #$03
@castle_dir:  clc
         adc     $07
         tax
         lda     $146e,x
         and     #$7f
         cmp     #$04
         bne     @try_other
@check_path:  txa
         clc
         adc     $09
         tax
         lda     $146e,x
         bne     @try_other
         lda     $12
         cmp     #$03
         beq     @path_clear
         jsr     is_king_attacked
         bcs     @try_other
@path_clear:  dec     $12
         bne     @check_path
         txa
         sec
         sbc     $09
         tax
         jsr     store_move_pair
@try_other:  lda     $09
         bpl     @castle_done
         ldx     $07
         lda     #$03
         sta     $12
         lda     #$01
         sta     $09
         lda     #$fc
         jmp     @castle_dir

@castle_done:  rts

; Check if the king at square X is under attack
; Scans all 16 directions (8 queen + 8 knight) from king's position
; Returns carry set if attacked, carry clear if safe
; $13 = king's piece byte (determines which side is defending)
is_king_attacked:   stx     $08
         lda     #$10
         sta     $10
         lda     #$00
         sta     $0f
@dir_loop:  lda     #$fe
         sta     $0e
         ldx     $0f
         lda     la634+242,x
         sta     $11
         ldx     $08
@ray_step:  inc     $0e
         clc
         txa
         adc     $11
         tax
         lda     $146e,x
         beq     @empty_check
         cmp     #$ff
         beq     @next_dir
         bne     @found_piece

@empty_check:  lda     $10
         cmp     #$09
         bcs     @ray_step
@next_dir:  inc     $0f
         dec     $10
         bne     @dir_loop
         clc
         bcc     @restore_x

@attacked:  sec
@restore_x:  ldx     $08
         rts

@found_piece:  eor     $13
         bpl     @next_dir
         eor     $13
         and     #$07
         sta     $0d
         lda     $10
         cmp     #$09
         bcc     @check_knight
         lda     $0d
         cmp     #$05
         beq     @attacked
         bit     $0e
         bpl     @check_type
         cmp     #$06
         beq     @attacked
@check_type:  lda     $10
         cmp     #$0d
         bcc     @check_rook
         lda     $0d
         cmp     #$03
         beq     @attacked
         bit     $0e
         bpl     @next_dir
         cmp     #$01
         bne     @next_dir
         lda     $13
         bmi     @pawn_bk
         lda     $10
         cmp     #$0f
         bcc     @next_dir
         jmp     @attacked

@pawn_bk:  lda     $10
         cmp     #$0f
         bcs     @next_dir
         jmp     @attacked

@check_rook:  lda     $0d
         cmp     #$04
         bne     @next_dir
         jmp     @attacked

@check_knight:  lda     $0d
         cmp     #$02
         bne     @next_dir
         beq     @attacked

; =====================================================================
; BOARD EVALUATION (Sargon "POINTS" routine)
; =====================================================================

; Build attack/defend tables for all pieces on the board
; $1346-$13C5 = attack table (enemies attacking each square)
; $13C6-$1445 = defend table (friendly pieces defending)
; $6E = defend count (counts down from $7F), $6F = attack count (counts up)
build_attack_table:   lda     #$00
         sta     $6f
         lda     #$7f
         sta     $6e
         ldx     #$15
         stx     $07
@piece_loop:  lda     $146e,x
         beq     @next_sq
         cmp     #$ff
         beq     @next_sq
         sta     $13
         and     #$07
         sta     $0d
         jsr     @scan_piece
@next_sq:  inc     $07
         ldx     $07
         cpx     #$63
         bcc     @piece_loop
         rts

@scan_piece:  ldx     $0d
         lda     la634+235,x
         sta     $10
         lda     la634+229,x
         cmp     #$10
         bne     @set_start
         dec     $10
         dec     $10
         bit     $13
         bpl     @set_start
         clc
         adc     #$04
@set_start:  sta     $0f
@dir_loop:  ldx     $0f
         lda     la634+242,x
         sta     $11
         ldx     $07
         lda     #$00
         sta     $12
@ray_loop:  clc
         txa
         adc     $11
         tax
         lda     $146e,x
         cmp     #$ff
         bne     @found
@next_dir:  inc     $0f
         dec     $10
         bne     @dir_loop
         rts

@found:  sta     $14
         and     #$07
         sta     $0e
         bit     $12
         bvs     @xray
         lda     la634+260,x
         lsr     A
         bit     $13
         bpl     @adjust_mob
         eor     #$ff
         clc
         adc     #$01
@adjust_mob:  clc
         adc     $68
         sta     $68
         lda     $14
         beq     @check_slide
         eor     $13
         bpl     @enemy
         lda     $0e
         cmp     #$06
         bne     @own_piece
         lda     #$01
         sta     $69
@own_piece:  lda     $12
         and     #$01
         bne     @set_flags
         ora     #$40
@set_flags:  ora     #$20
         sta     $12
         ldy     $6e
         dec     $6e
         jmp     @store_atk

@xray:  lda     $0e
         beq     @ray_loop
         cmp     #$01
         beq     @next_dir
         lda     $14
         eor     $13
         bpl     @next_dir
         txa
         ora     #$80
         tax
         lda     $12
         and     #$bf
         jmp     @set_flags

@enemy:  lda     $12
         ora     #$01
         sta     $12
         ldy     $6f
         inc     $6f
@store_atk:  txa
         sta     $1346,y
         lda     $12
         and     #$80
         ora     $07
         sta     $13c6,y
@check_slide:  lda     $0d
         cmp     #$03
         bcs     @check_king
@jmp_next_dir:  jmp     @next_dir

@check_king:  cmp     #$06
         beq     @jmp_next_dir
         bit     $12
         bvc     @check_blocked
@jmp_ray:  jmp     @ray_loop

@check_blocked:  lda     $12
         and     #$20
         bne     @jmp_next_dir
         lda     $0e
         beq     @jmp_ray
         lda     $0d
         cmp     #$04
         bne     @check_bishop
         lda     $0e
         cmp     #$04
         beq     @jmp_ray
         cmp     #$05
         bne     @jmp_next_dir
@set_xray:  lda     $12
         ora     #$80
         sta     $12
         jmp     @ray_loop

@check_bishop:  cmp     #$03
         bne     @check_q_r
         lda     $0e
         cmp     #$01
         beq     @same_dir
         cmp     #$05
         bne     @jmp_next_dir
         beq     @set_xray

@check_q_r:  lda     $0e
         cmp     #$03
         bne     @check_rook
         lda     $10
         cmp     #$05
         bcc     @jmp_next_dir
         jmp     @ray_loop

@check_rook:  cmp     #$04
         bne     @check_queen
         lda     $10
         cmp     #$05
         bcc     @jmp_ray
         jmp     @next_dir

@check_queen:  cmp     #$05
         beq     @jmp_ray
         cmp     #$01
         bne     @jmp_next_dir
         lda     $10
         cmp     #$05
         bcc     @jmp_next_dir
@same_dir:  lda     $13
         eor     $11
         bmi     @jmp_next_dir
         lda     $12
         ora     #$20
         sta     $12
         jmp     @ray_loop

; Prune illegal entries from attack/defend tables
; Removes attacks that are blocked by pinned pieces, etc.
prune_illegal:   lda     $6e
         eor     #$ff
         clc
         adc     #$80
         beq     @done
         sta     $10
         ldy     #$7f
@scan_def:  lda     $1346,y
         bmi     @process
@next_entry:  dey
         dec     $10
         bne     @scan_def
@done:  rts

@process:  sty     $11
         and     #$7f
         sta     $09
         lda     $1347,y
         sta     $08
         lda     $13c7,y
         sta     $07
         ldx     $09
         lda     $146e,x
         and     #$07
         sta     $0f
         cmp     #$06
         beq     @check_atk
         ldx     $07
         lda     $146e,x
         and     #$07
         cmp     $0f
         bcc     @check_atk
         lda     $6f
         beq     @scan_def_tbl
         sta     $12
         ldx     #$00
         lda     $09
@check_dup:  cmp     $1346,x
         beq     @next_entry
         inx
         dec     $12
         bne     @check_dup
@check_atk:  lda     $6f
         beq     @scan_def_tbl
         sta     $12
         ldx     #$00
@atk_loop:  lda     $13c6,x
         and     #$7f
         cmp     $08
         bne     @atk_next
         lda     $1346,x
         and     #$7f
         cmp     $09
         beq     @atk_next
         sta     $0a
         tay
         lda     $146e,y
         and     #$07
         cmp     $0f
         bcs     @atk_next
         lda     $6e
         eor     #$ff
         clc
         adc     #$80
         sta     $0d
         ldy     #$7f
@def_check:  lda     $13c6,y
         and     #$7f
         cmp     $07
         bne     @def_next
         lda     $1346,y
         and     #$7f
         cmp     $0a
         beq     @atk_next
@def_next:  dey
         dec     $0d
         bne     @def_check
         lda     #$00
         sta     $1346,x
@atk_next:  inx
         dec     $12
         bne     @atk_loop
@scan_def_tbl:  lda     $6e
         eor     #$ff
         clc
         adc     #$80
         sta     $12
         ldx     #$7f
@def_loop:  lda     $13c6,x
         and     #$7f
         cmp     $08
         bne     @def_next2
         lda     $1346,x
         and     #$7f
         cmp     $07
         beq     @def_next2
         sta     $0a
         tay
         lda     $0f
         cmp     #$06
         beq     @check_atk2
         lda     $146e,y
         and     #$07
         cmp     $0f
         bcs     @def_next2
         lda     $1345,x
         bpl     @check_atk2
         and     #$7f
         tay
         lda     $146e,y
         and     #$07
         cmp     $0f
         bcc     @remove_def
         bcs     @def_next2

@check_atk2:  lda     $6f
         beq     @remove_def
         sta     $0d
         ldy     #$00
@atk_loop2:  lda     $13c6,y
         and     #$7f
         cmp     $07
         bne     @atk_next2
         lda     $1346,y
         and     #$7f
         cmp     $0a
         beq     @def_next2
@atk_next2:  iny
         dec     $0d
         bne     @atk_loop2
@remove_def:  lda     #$00
         sta     $1346,x
@def_next2:  dex
         dec     $12
         bne     @def_loop
         ldy     $11
         jmp     @next_entry

; Build the static exchange evaluation (SEE) table at $1319
; Collects all attackers/defenders of a target square, ordered by piece value
build_exchange_tbl:   lda     $0a
         sta     $10
         ldx     #$0e
         lda     #$00
         sta     $05
         sta     $06
@clear_loop:  sta     $1319,x
         dex
         bne     @clear_loop
         sta     $0f
@process:  lda     $08
         ora     #$80
         sta     $1346,y
         lda     $13c6,y
         sta     $07
         and     #$7f
         tax
         lda     $146e,x
         bmi     @black_off
         ldx     #$00
         inc     $05
         bne     @set_type
@black_off:  ldx     #$07
         inc     $06
@set_type:  and     #$07
         sta     $0d
         lda     $07
         bpl     @white_off
         txa
         clc
         adc     #$06
         bne     @find_slot
@white_off:  txa
         clc
         adc     $0d
@find_slot:  tax
@slot_loop:  lda     $1319,x
         beq     @store
         and     #$f0
         beq     @pack_hi
         inx
         bne     @slot_loop
@pack_hi:  lda     $1319,x
         asl     A
         asl     A
         asl     A
         asl     A
@store:  ora     $0d
         sta     $1319,x
         lda     $0f
         beq     @next_def
@next_atk:  lda     $08
@dec_count:  dec     $10
         beq     @done
         iny
         cmp     $1346,y
         bne     @dec_count
         jmp     @process

@next_def:  lda     $08
@dec_def:  dec     $10
         bne     @prev_def
         lda     $6f
         sta     $10
         ldy     #$ff
         inc     $0f
         inc     $10
         jmp     @next_atk

@prev_def:  dey
         cmp     $1346,y
         bne     @dec_def
         jmp     @process

@done:  rts

; Static exchange evaluation (SEE) for target square $08
; Simulates the capture sequence to determine material gain/loss
; Returns result in A (relative to $80 as zero point)
static_exchange_eval:   ldx     $08
         lda     $146e,x
         sta     $13
         and     #$07
         tax
         lda     la634+223,x
         clc
         adc     #$80
         sta     $0d
         sta     $0e
         lda     #$00
         sta     $0f
         sta     $10
         sta     $12
         tax
         ldy     #$07
         lda     $13
         bpl     @eval_loop
         inc     $12
@eval_loop:  jsr     @get_next
         beq     @atk_done
         eor     #$ff
         adc     #$01
         clc
         adc     $0e
         sta     $0e
         cmp     $0f
         bcc     @try_defend
         lda     $0e
         sta     $0f
         lda     $0d
         sta     $11
@try_defend:  jsr     @get_next
         beq     @def_done
         adc     $0e
         sta     $0e
         cmp     $0d
         bcs     @eval_loop
         lda     $0e
         sta     $0d
         lda     $0f
         sta     $10
         jmp     @eval_loop

@atk_done:  lda     $0f
         cmp     $11
         bcc     @done
         lda     $11
@done:  rts

@def_done:  lda     $0d
         cmp     $10
         bcs     @done2
         lda     $10
@done2:  rts

@get_next:  lda     $12
         bne     @get_atk
         inc     $12
         lda     $06
         beq     @empty
         dec     $06
@find_def:  iny
         lda     $1319,y
         beq     @find_def
         pha
         lsr     A
         lsr     A
         lsr     A
         lsr     A
         sta     $1319,y
         dey
         bne     @unpack
@get_atk:  dec     $12
         lda     $05
         beq     @empty
         dec     $05
@find_atk:  inx
         lda     $1319,x
         beq     @find_atk
         pha
         lsr     A
         lsr     A
         lsr     A
         lsr     A
         sta     $1319,x
         dex
@unpack:  pla
         and     #$0f
         sty     $14
         tay
         lda     la634+223,y
         ldy     $14
         clc
@empty:  rts

; Full position evaluation (Sargon's POINTS routine)
; Evaluates: material balance ($6A), exchange values on each square,
; pawn structure ($6B), king safety, piece mobility, positional bonuses
; Output: $61/$62 = evaluation score (lo/hi), $62+$80 = final score
; $70/$71 = node counter (16-bit, for search depth control)
evaluate_position:   inc     $70
         bne     @init_vars
         inc     $71
         bne     @init_vars
         dec     $70
         dec     $71
@init_vars:  lda     #$00
         ldx     #$08
@zero_loop:  sta     $61,x
         dex
         bpl     @zero_loop
         jsr     build_attack_table
         jsr     prune_illegal
         lda     $6e
         eor     #$ff
         clc
         adc     #$80
         beq     @skip_king_eval
         sta     $0a
         ldy     #$7f
@piece_loop:  lda     $1346,y
         bmi     @next_piece
         beq     @next_piece
         sta     $08
         sty     $09
         jsr     build_exchange_tbl
         jsr     static_exchange_eval
         sec
         sbc     #$80
         bmi     @restore_y
         beq     @check_king_sq
         sta     $0d
         lda     $13
         eor     next_color
         bmi     @enemy_exchange
         lda     $0d
         cmp     $63
         bcc     @update_max
         sta     $63
@update_max:  lda     $67
         sec
         sbc     #$08
         sta     $67
@check_king_sq:  lda     $08
         cmp     $0c
         bne     @restore_y
         sta     $66
         beq     @restore_y

@enemy_exchange:  lda     $0d
         cmp     $64
         bcc     @update_2nd
         ldx     $64
         sta     $64
         txa
@update_2nd:  cmp     $65
         bcc     @king_safety
         sta     $65
@king_safety:  lda     $67
         clc
         adc     #$04
         sta     $67
@restore_y:  ldy     $09
@next_piece:  dey
         dec     $0a
         bne     @piece_loop
         lda     $66
         beq     @skip_king_eval
         lda     #$00
         sta     $65
@skip_king_eval:  lda     level+2
         beq     @pawn_eval
         jsr     eval_king_tropism
@pawn_eval:  jsr     @pawn_struct
         lda     $65
         asl     $63
         sec
         sbc     $63
         bit     next_color
         bpl     @adjust_sign
         eor     #$ff
         clc
         adc     #$01
@adjust_sign:  clc
         adc     $6a
         clc
         adc     $6a
         sta     $62
         lda     $64
         sec
         sbc     $63
         clc
         adc     $67
         bit     next_color
         bpl     @add_terms
         eor     #$ff
         clc
         adc     #$01
@add_terms:  and     #$ff
         jsr     @add_pos
         lda     $68
         jsr     @add_pos
         lda     $1e
         jsr     @add_pos
         lda     $1e
         jsr     @add_pos
         lda     $6b
         jsr     @add_pos
         lda     $6b
         jsr     @add_pos
         lda     next_color
         bpl     @final_score
         lda     $61
         clc
         eor     #$ff
         adc     #$01
         sta     $61
         lda     $62
         eor     #$ff
         adc     #$00
         sta     $62
@final_score:  lda     $62
         clc
         adc     #$80
         sta     $62
         rts

@add_pos:  clc
         bmi     @add_neg
         adc     $61
         sta     $61
         bcc     @done_pos
         inc     $62
@done_pos:  rts

@add_neg:  adc     $61
         sta     $61
         bcs     @done_neg
         dec     $62
@done_neg:  rts

@add4_pawn:  lda     #$04
@add_clc:  clc
@add_pawn:  adc     $6b
         sta     $6b
         rts

@pawn_struct:  lda     #$00
         sta     $0e
         sta     $11
         sta     $12
         sta     $6b
         sta     $0f
         sta     $10
         ldx     #$1f
@file_loop:  lda     #$06
         sta     $0d
@rank_loop:  lda     $146e,x
         and     #$07
         cmp     #$01
         bne     @advance_sq
         lda     $146e,x
         bmi     @black_pawn
         lda     $11
         beq     @white_pawn
         lda     #$fc
         jsr     @add_clc
@white_pawn:  lda     $0d
         sta     $11
         jmp     @advance_sq

@black_pawn:  lda     $12
         beq     @first_black
         jsr     @add4_pawn
         jmp     @advance_sq

@first_black:  lda     $0d
         sta     $12
@advance_sq:  txa
         clc
         adc     #$0a
         tax
         dec     $0d
         bne     @rank_loop
         lda     $12
         bne     @no_wp
         lda     $11
         beq     @check_bp
         lda     $0e
         ora     #$40
         sta     $0e
         jsr     @add4_pawn
         lda     move_number
         cmp     #$14
         bcc     @check_adj_w
         lda     #$07
         sec
         sbc     $11
         tay
         lda     #$00
         sec
@shift_loop:  rol     A
         dey
         bne     @shift_loop
         jsr     @add_pawn
@check_adj_w:  lda     $10
         beq     @check_pass_w
         cmp     $11
         beq     @adj_bonus
         sec
         sbc     #$01
         cmp     $11
         beq     @adj_bonus
         clc
         adc     #$02
         cmp     $11
         bne     @check_pass_w
@adj_bonus:  lda     #$02
         jsr     @add_clc
@check_pass_w:  lda     $0f
         beq     @isolated_w
         cmp     $11
         bcc     @check_bp
@isolated_w:  lda     $0e
         ora     #$80
         sta     $0e
@check_bp:  lda     $0f
         beq     @no_wp
         jsr     @add4_pawn
@no_wp:  lda     $11
         bne     @opp_file
         lda     $12
         beq     @check_opp
         lda     $0e
         ora     #$10
         sta     $0e
         lda     #$fc
         jsr     @add_clc
         lda     move_number
         cmp     #$14
         bcc     @check_adj_b
         lda     #$ff
         ldy     $12
@shift_bk:  dey
         beq     @add_bk_pen
         asl     A
         bne     @shift_bk
@add_bk_pen:  jsr     @add_clc
@check_adj_b:  lda     $0f
         beq     @check_pass_b
         cmp     $12
         beq     @adj_bonus_b
         clc
         adc     #$01
         cmp     $12
         beq     @adj_bonus_b
         sec
         sbc     #$02
         cmp     $12
         bne     @check_pass_b
@adj_bonus_b:  lda     #$fe
         jsr     @add_clc
@check_pass_b:  lda     $12
         cmp     $10
         bcc     @check_opp
         lda     $0e
         ora     #$20
         sta     $0e
@check_opp:  lda     $10
         beq     @opp_file
         lda     #$fc
         jsr     @add_clc
@opp_file:  lda     $0e
         and     #$04
         beq     @iso_check
         lda     $11
         beq     @check_semi
         cmp     $10
         beq     @adj_bonus_o
         clc
         adc     #$01
         cmp     $10
         beq     @adj_bonus_o
         sec
         sbc     #$02
         cmp     $10
         bne     @check_semi
@adj_bonus_o:  lda     #$02
         jsr     @add_clc
@check_semi:  lda     $0e
         and     #$08
         beq     @iso_check
         lda     $12
         beq     @semi_bonus
         cmp     $10
         bcc     @iso_check
@semi_bonus:  jsr     @add4_pawn
@iso_check:  lda     $0e
         and     #$01
         beq     @swap_sides
         lda     $12
         beq     @check_open
         cmp     $0f
         beq     @iso_penalty
         clc
         adc     #$ff
         cmp     $0f
         beq     @iso_penalty
         clc
         adc     #$02
         cmp     $0f
         bne     @check_open
@iso_penalty:  lda     #$fe
         jsr     @add_clc
@check_open:  lda     $0e
         and     #$02
         beq     @swap_sides
         lda     $0f
         cmp     $11
         bcc     @swap_sides
         lda     #$fc
         jsr     @add_clc
@swap_sides:  lda     $0e
         lsr     A
         lsr     A
         lsr     A
         lsr     A
         sta     $0e
         lda     $12
         sta     $0f
         lda     $11
         sta     $10
         lda     #$00
         sta     $11
         sta     $12
         txa
         sec
         sbc     #$3b
         tax
         cmp     #$27
         bne     @check_end
         jmp     @opp_file

@check_end:  cmp     #$ec
         bne     @next_file
         rts

@next_file:  jmp     @file_loop

; Evaluate positional bonus for the current move
; Adds bonuses/penalties for: pawn advancement, piece development,
; center control, king castling, 7th rank occupation, etc.
; Adjusts the $1E positional accumulator
eval_positional:   lda     $13
         and     #$07
         cmp     #$01
         bne     @not_pawn
         lda     move_number
         cmp     #$0a
         bcs     @midgame
         lda     $0b
         bit     $13
         bpl     @check_center
         sec
         sbc     #$32
@check_center:  cmp     #$22
         beq     @check_advance
         cmp     #$23
         beq     @check_advance
         lda     $0d
         and     #$20
         beq     @retreat_pen
         rts

@retreat_pen:  lda     #$f8
         jmp     @set_bonus

@check_advance:  sec
         sbc     $0c
         cmp     #$ec
         beq     @advance_bonus
         cmp     #$e2
         bne     @done
@advance_bonus:  lda     #$04
         jmp     @set_bonus

@midgame:  cmp     #$19
         bcs     @done
         lda     $13
         bmi     @bk_pos
         lda     $6c
         cmp     #$1a
         bcc     @wk_safe
         cmp     #$1d
         bcs     @done
         lda     #$00
         beq     @verify_castle

@wk_safe:  cmp     #$18
         bcs     @done
         lda     #$05
         bne     @verify_castle

@bk_pos:  lda     $6d
         cmp     #$60
         bcc     @bk_safe
         lda     #$ce
         bne     @verify_castle

@bk_safe:  cmp     #$5e
         bcs     @done
         cmp     #$5b
         bcc     @done
         lda     #$d3
@verify_castle:  clc
         adc     $0b
         cmp     #$27
         bcs     @done
         cmp     #$24
         bcc     @done
         lda     #$f4
         jmp     @set_bonus

@done:  rts

@not_pawn:  cmp     #$04
         bcc     @minor_piece
         cmp     #$06
         beq     @king_move
         lda     move_number
         cmp     #$07
         bcs     @done
         lda     #$f0
         jmp     @set_bonus

@king_move:  lda     $0d
         bpl     @king_early
         lda     $0c
         bit     $13
         bpl     @sub_king
         sec
         sbc     #$46
@sub_king:  sec
         sbc     #$0f
         cmp     #$0c
         beq     @set_bonus
         lda     #$06
         bne     @set_bonus

@king_early:  lda     move_number
         cmp     #$1e
         bcs     @done
         lda     #$f4
         bne     @set_bonus

@minor_piece:  lda     $0d
         and     #$10
         beq     @early_dev
         lda     #$0a
         bne     @store_bonus

@early_dev:  lda     move_number
         cmp     #$09
         bcs     @done
         lda     #$f8
         bne     @store_bonus

@store_bonus:  sta     $0f
         lda     move_number
         cmp     #$0f
         bcs     @apply_bonus
         lda     $0c
         bit     $13
         bpl     @check_7th
         sec
         sbc     #$1e
@check_7th:  cmp     #$2c
         beq     @on_7th
         cmp     #$2d
         bne     @apply_bonus
@on_7th:  sec
         sbc     #$0a
         bit     $13
         bpl     @check_pawn
         clc
         adc     #$32
@check_pawn:  tax
         lda     $146e,x
         and     #$07
         cmp     #$01
         bne     @apply_bonus
         lda     #$e8
@set_bonus:  sta     $0f
@apply_bonus:  lda     $0d
         and     #$01
         beq     @check_side
         lda     $13
         bmi     @add_bonus
@sub_bonus:  lda     $1e
         sec
         sbc     $0f
         sta     $1e
         rts

@check_side:  lda     $13
         bmi     @sub_bonus
@add_bonus:  lda     $1e
         clc
         adc     $0f
         sta     $1e
         rts

; Evaluate king tropism: distance between the two kings
; In endgames, closer kings favor the side with material advantage
; Adjusts $68 (king distance score) and clears $64 (exchange threshold)
eval_king_tropism:   lda     $6c
         ldy     #$00
@div10_wk:  cmp     #$0a
         bcc     @wk_done
         iny
         sec
         sbc     #$0a
         bne     @div10_wk
@wk_done:  sta     $0d
         sty     $0e
         lda     $6d
         ldy     #$00
@div10_bk:  cmp     #$0a
         bcc     @dist_calc
         iny
         sec
         sbc     #$0a
         bne     @div10_bk
@dist_calc:  sec
         sbc     $0d
         bmi     @store_dist
         eor     #$ff
         clc
         adc     #$01
@store_dist:  sta     $0d
         tya
         sec
         sbc     $0e
         bmi     @abs_rank
         eor     #$ff
         clc
         adc     #$01
@abs_rank:  clc
         adc     $0d
         clc
         adc     #$0e
         sta     $0d
         ldx     #$00
         lda     $6a
         bmi     @get_king
         inx
@get_king:  ldy     $6c,x
         lda     #$08
         sec
         sbc     la634+260,y
         asl     A
         clc
         adc     $0d
         asl     A
         asl     A
         sta     $68
         lda     $6a
         bpl     @sign_adj
         lda     $68
         eor     #$ff
         clc
         adc     #$01
         sta     $68
@sign_adj:  lda     #$00
         sta     $64
         rts

; =====================================================================
; SEARCH ALGORITHM (Sargon "PLYEX" routine)
; =====================================================================

; Make a move on the internal board
; Reads from/to from move list at ($8B),$8D
; Updates board array, handles pawn promotion, en passant, castling
; Records captured piece and move flags for unmake_move
; Also calls eval_positional to update positional score
make_move:   ldy     $8d
         lda     ($8b),y
         sta     $0b
         tax
         iny
         lda     ($8b),y
         sta     $0c
         lda     $146e,x
         sta     $13
         lda     #$00
         sta     $146e,x
         sta     $0d
         bit     $13
         bvs     @check_first
         lda     #$10
         sta     $0d
         lda     $13
         ora     #$40
         sta     $13
@check_first:  ldx     $0c
         lda     $146e,x
         sta     $14
         lda     $13
         sta     $146e,x
         and     #$07
         cmp     #$01
         beq     @pawn_move
         cmp     #$06
         bne     @eval_move
         jmp     @king_move

@eval_move:  jsr     eval_positional
         ldy     next_color+1
         lda     $0d
         sta     $1331,y
         lda     $14
         sta     $1327,y
         beq     @done
         and     #$07
         tax
         lda     $14
         bpl     @sub_piece
         lda     $6a
         clc
         adc     la634+223,x
         sta     $6a
         rts

@sub_piece:  lda     $6a
         sec
         sbc     la634+223,x
         sta     $6a
@done:  rts

@pawn_move:  lda     $0c
         cmp     #$5b
         bcs     @not_promote
         cmp     #$1d
         bcs     @check_ep
@not_promote:  lda     $0d
         ora     #$20
         sta     $0d
         lda     $146e,x
         ora     #$04
         sta     $146e,x
         sta     $13
         bmi     @black_promo
         lda     #$07             ; white pawn promotes: +7 to material
         .byte   $2c              ; BIT abs trick: skip next LDA
@black_promo:  lda     #$f9             ; black pawn promotes: -7 to material
         clc
         adc     $6a
         sta     $6a
         jmp     @eval_move

@check_ep:  lda     $0c
         sec
         sbc     $0b
         and     #$01
         beq     @eval_move
         lda     $14
         bne     @eval_move
         lda     $13
         bmi     @bk_ep_sq
         lda     #$f6             ; white en passant: captured pawn is 10 rows back
         .byte   $2c              ; BIT abs trick: skip next LDA
@bk_ep_sq:  lda     #$0a             ; black en passant: captured pawn is 10 rows forward
         clc
         adc     $0c
         tax
         lda     $146e,x
         sta     $14
         lda     #$00
         sta     $146e,x
         lda     $0d
         ora     #$40
         sta     $0d
         jmp     @eval_move

@king_move:  lda     $0c
         ldx     $13
         bmi     @bk_king
         sta     $6c              ; update white king position
         .byte   $2c              ; BIT abs trick: skip next STA
@bk_king:  sta     $6d              ; update black king position
         sta     $08
         sec
         sbc     $0b
         cmp     #$02
         beq     @queenside
         cmp     #$fe
         bne     @king_done
         inc     $08
         asl     A
         clc
         adc     $0b
         bne     @rook_from
@queenside:  dec     $08
         clc
         adc     $0b
         adc     #$01
@rook_from:  tax
         lda     $146e,x
         sta     $10
         lda     #$00
         sta     $146e,x
         lda     $10
         ora     #$40
         ldx     $08
         sta     $146e,x
         lda     $0d
         ora     #$80
         sta     $0d
@king_done:  jmp     @eval_move

; Unmake the last move: restore board state, piece positions, material
; Reverses everything done by make_move (promotion, EP, castling)
unmake_move:   ldy     $8d
         lda     ($8b),y
         sta     $0b
         iny
         lda     ($8b),y
         sta     $0c
         tax
         lda     $146e,x
         sta     $13
         ldy     next_color+1
         lda     $1327,y
         sta     $14
         sta     $146e,x
         lda     $1331,y
         sta     $0d
         and     #$10
         beq     @restore_from
         lda     $13
         and     #$bf
         sta     $13
@restore_from:  ldx     $0b
         lda     $13
         sta     $146e,x
         and     #$07
         cmp     #$01
         beq     @undo_ep
         cmp     #$06
         beq     @undo_king
         lda     $0d
         and     #$20
         bne     @undo_promo
@undo_eval:  inc     $0d
         jsr     eval_positional
         lda     $14
         beq     @done
         and     #$07
         tax
         lda     $14
         bmi     @sub_piece
         lda     $6a
         clc
         adc     la634+223,x
         sta     $6a
         rts

@sub_piece:  lda     $6a
         sec
         sbc     la634+223,x
         sta     $6a
@done:  rts

@undo_promo:  lda     $13
         and     #$fb
         sta     $13
         sta     $146e,x
         bpl     @bk_promo
         lda     #$07             ; undo white promotion: -7 material
         .byte   $2c              ; BIT abs trick: skip next LDA
@bk_promo:  lda     #$f9             ; undo black promotion: +7 material
         clc
         adc     $6a
         sta     $6a
         jmp     @undo_eval

@undo_ep:  bit     $0d
         bvc     @undo_eval
         ldx     $0c
         lda     #$00
         sta     $146e,x
         lda     $13
         bmi     @bk_ep
         lda     #$f6             ; white: restore ep pawn 10 rows back
         .byte   $2c              ; BIT abs trick: skip next LDA
@bk_ep:  lda     #$0a             ; black: restore ep pawn 10 rows forward
         clc
         adc     $0c
         tax
         lda     $14
         sta     $146e,x
         jmp     @undo_eval

@undo_king:  ldx     $0b
         lda     $13
         bmi     @bk_king
         stx     $6c              ; restore white king position
         .byte   $2c              ; BIT abs trick: skip next STX
@bk_king:  stx     $6d              ; restore black king position
         lda     $0d
         bpl     @undo_eval
         lda     $0c
         sta     $08
         sec
         sbc     $0b
         cmp     #$02
         beq     @queenside
         inc     $08
         asl     A
         clc
         adc     $0b
         bne     @rook_dest
@queenside:  dec     $08
         clc
         adc     $0b
         adc     #$01
@rook_dest:  sta     $07
         ldx     $08
         lda     $146e,x
         and     #$bf
         sta     $10
         lda     #$00
         sta     $146e,x
         ldx     $07
         lda     $10
         sta     $146e,x
         jmp     @undo_eval

; Sort the move list by priority (selection sort)
; Captures and moves to important squares are prioritized
; Uses piece value and target square to calculate sort key
sort_moves:   ldy     next_color+1
         lda     $1445,y
         sta     $07
         lda     $144f,y
         sta     $08
         ldy     #$00
@outer_loop:  lda     ($8b),y
         beq     @done
         sty     $0f
         jsr     @calc_priority
@save_best:  lda     $11
         sta     $12
         sty     $10
@inner_loop:  iny
         iny
         lda     ($8b),y
         beq     @end_pass
         jsr     @calc_priority
         lda     $12
         cmp     $11
         bcs     @inner_loop
         bcc     @save_best

@end_pass:  lda     $12
         beq     @done
         ldy     $0f
         lda     ($8b),y
         sta     $11
         iny
         lda     ($8b),y
         sta     $12
         ldy     $10
         lda     ($8b),y
         sta     $0d
         iny
         lda     ($8b),y
         sta     $0e
         lda     $12
         sta     ($8b),y
         dey
         lda     $11
         sta     ($8b),y
         ldy     $0f
         lda     $0d
         sta     ($8b),y
         iny
         lda     $0e
         sta     ($8b),y
         iny
         jmp     @outer_loop

@done:  rts

@calc_priority:  iny
         lda     ($8b),y
         dey
         tax
         lda     $146e,x
         and     #$07
         asl     A
         asl     A
         sta     $11
         bne     @priority_done
         lda     $07
         cmp     ($8b),y
         bne     @priority_done
         inc     $11
         cpx     $08
         bne     @priority_done
         inc     $11
@priority_done:  rts

; PLYEX: Main alpha-beta search routine (recursive)
; Iterates through move list, tries each move, recurses to deeper plies
; Uses alpha-beta pruning with aspiration windows
; At leaf nodes, calls evaluate_position for static eval
; Score stored in $61/$62, best move tracked via store_best_move
plyex:   ldy     $8d
         lda     ($8b),y
         beq     @end_of_moves
         jsr     try_make_move
         bcc     @legal_move
         jmp     @next_move

@legal_move:  ldy     next_color+1
         cpy     level+1
         bcs     @at_max_depth
@go_deeper:  jsr     @push_ply
         jsr     init_move_gen
         jsr     sort_moves
         jmp     plyex

@end_of_moves:  lda     $1d
         bne     @check_cutoff
         dey
         dey
         sty     $8d
         jsr     is_own_king_checked
         bcc     @not_in_check
         lda     next_color+1
         sta     $61
         lda     #$00
         sta     $62
         jmp     @inc_count

@not_in_check:  lda     #$00
         sta     $61
         lda     #$80
         sta     $62
         jmp     @inc_count

@check_cutoff:  ldy     next_color+1
         cpy     #$01
         bne     @go_back
         rts

@go_back:  jsr     @pop_ply
         lda     scoreL_stack,y
         eor     #$ff
         clc
         adc     #$01
         sta     $61
         lda     scoreH_stack,y
         eor     #$ff
         adc     #$00
         sta     $62
         jmp     @compare_score

@at_max_depth:  jsr     alpha_beta_cutoff
         lda     next_color+1
         cmp     level
         bcc     @undo_and_score
         cmp     level+1
         bne     @undo_and_score
         lda     $69
         bne     @go_deeper
@undo_and_score:  jsr     unmake_move
@inc_count:  inc     $1d
@compare_score:  ldy     next_color+1
         lda     $62
         cmp     $002f,y
         bcc     @next_move
         bne     @better_move
         lda     $0022,y
         cmp     $61
         bcs     @next_move
@better_move:  lda     $61
         sta     $0022,y
         lda     $62
         sta     $002f,y
         jsr     store_best_move
         lda     $61
         eor     #$ff
         clc
         adc     #$01
         sta     $61
         lda     $62
         eor     #$ff
         adc     #$00
         sta     $62
         cmp     $002e,y
         bcc     @check_cutoff
         bne     @next_move
         lda     $0021,y
         cmp     $61
         bcs     @check_cutoff
@next_move:  ldy     next_color+1
         lda     $8d
         clc
         adc     #$02
         sta     $133b,y
         sta     $8d
         jmp     plyex

@push_ply:  lda     next_color
         eor     #$80
         sta     next_color
         bmi     @set_ply_ptrs
         inc     move_number
@set_ply_ptrs:  ldy     next_color+1
         lda     $0021,y
         sta     scoreL_stack,y
         lda     $002e,y
         sta     scoreH_stack,y
         inc     next_color+1
         rts

@pop_ply:  lda     next_color
         eor     #$80
         sta     next_color
         bpl     @dec_ply
         dec     move_number
@dec_ply:  dec     next_color+1
         lda     $1459,y
         sta     $8e
         lda     $1463,y
         sta     $8f
         ldy     next_color+1
         lda     $1459,y
         sta     $8b
         lda     $1463,y
         sta     $8c
         lda     $133b,y
         sta     $8d
         jsr     unmake_move
         ldy     next_color+1
         cpy     #$01
         bne     @pop_done
         lda     $1fe2
         eor     #$0a
         ora     #$40
         sta     $1fe2
@pop_done:  rts

; Store the best move found at current ply level
; At ply 1: updates the principal variation display
; At ply 2: saves second-best move for hint feature
store_best_move:   lda     $1327,y
         bne     @check_ply
         lda     $0b
         sta     $1445,y
         lda     $0c
         sta     $144f,y
@check_ply:  cpy     #$01
         bne     @ply2
         ldx     $8d
         beq     @display_pv
@shift_pv:  lda     $1000,x
         sta     $1002,x
         dex
         bne     @shift_pv
         lda     $0b
         sta     $1001
         lda     $0c
         sta     $1002
@display_pv:  jsr     display_move_full
         ldy     next_color+1
         lda     $b5
         sta     $9f
         lda     $b6
         sta     $b4
         rts

@ply2:  cpy     #$02
         bne     @done
         lda     $0b
         sta     $b5
         lda     $0c
         sta     $b6
@done:  rts

; Determine if search should continue deeper or evaluate statically
; Below max depth: use quick material-based eval for alpha-beta cutoff
; At/above max depth: run full evaluate_position
; Also checks if current side's king is in check (enables quiescence)
alpha_beta_cutoff:   lda     level+1
         cmp     level
         bcs     @full_eval
         lda     $6a
         asl     A
         sta     $62
         lda     #$00
         sta     $61
         lda     next_color
         bpl     @adjust_sign
         lda     $61
         eor     #$ff
         clc
         adc     #$01
         sta     $61
         lda     $62
         eor     #$ff
         adc     #$00
         sta     $62
@adjust_sign:  lda     $62
         clc
         adc     #$81
         sta     $62
         ldy     next_color+1
         cmp     $002f,y
         bcc     @check_in_check
         bne     @full_eval
         lda     $0022,y
         cmp     $61
         bcs     @check_in_check
@full_eval:  jmp     evaluate_position

@check_in_check:  lda     next_color
         eor     #$80
         jsr     is_king_checked
         lda     #$00
         rol     A
         sta     $69
         rts

; Check if current side's king is in check (uses next_color)
is_own_king_checked:   lda     next_color
; Check if king of given color (A) is in check
is_king_checked:   bmi     @black_king
         ldx     $6c              ; white king position
         .byte   $2c              ; BIT abs trick: skip next LDX
@black_king:  ldx     $6d              ; black king position
         lda     $146e,x
         sta     $13
         jmp     is_king_attacked

; =====================================================================
; ITERATIVE DEEPENING AND OPENING BOOK
; =====================================================================

; Main entry point for computer move calculation
; Uses iterative deepening: searches depth 1, 2, 3... up to max level
; Widens aspiration window on fail-high/fail-low
; First checks opening book before starting search
calc_move:
         jsr     init_board_state
         lda     #$00
         sta     $1e
         sta     $70
         sta     $71
         ldx     #$0a
@clear_loop:  sta     $1445,x
         sta     $144f,x
         sta     $20,x
         sta     $2d,x
         dex
         bne     @clear_loop
         lda     #$01
         sta     $8e
         lda     #$10
         sta     $8f
         lda     #$01
         sta     level+1
         jsr     init_move_gen
         lda     $8e
         sta     $145b
         lda     $8f
         sta     $1465
         lda     $1c
         bne     @iter_loop
         jsr     opening_book_lookup
@iter_loop:  lda     level+1
         ora     #$70
         sta     $1fe3
         jsr     plyex
         lda     scoreH_stack
         beq     @done
         cmp     #$ff
         bne     @deepen
@done:  rts

@deepen:  inc     level+1
         lda     level+1
         cmp     #$03
         bcc     @check_depth
         cmp     level
         bcs     @check_window
         jmp     @restart_search

@check_window:  lda     scoreH_stack
         cmp     $2e
         bcc     @fail_low
         bne     @widen_beta
         lda     $21
         cmp     scoreL_stack
         bcs     @fail_low
@widen_beta:  lda     scoreL_stack
         eor     #$ff
         clc
         adc     #$01
         sta     $61
         lda     scoreH_stack
         eor     #$ff
         adc     #$00
         sta     $62
         cmp     $2f
         bcc     @fail_high
         bne     @set_window
         lda     $22
         cmp     $61
         bcs     @fail_high
@set_window:  lda     #$e0
         clc
         adc     scoreL_stack
         sta     $21
         lda     scoreH_stack
         adc     #$ff
         sta     $2e
         lda     #$e0
         clc
         adc     $61
         sta     $22
         lda     $62
         adc     #$ff
         sta     $2f
@check_depth:  lda     level+1
         cmp     #$0a
         beq     @done
         cmp     level
         beq     @restart_search
         ldx     level
         lda     $71
         cmp     la634+266,x
         bcs     @done
         bcc     @restart_search

@fail_low:  lda     $21
         eor     #$ff
         sta     $22
         lda     $2e
         eor     #$ff
         sta     $2f
         lda     #$00
         sta     $21
         sta     $2e
         beq     @dec_depth

@fail_high:  lda     $22
         eor     #$ff
         sta     $21
         lda     $2f
         eor     #$ff
         sta     $2e
         lda     #$00
         sta     $22
         sta     $2f
@dec_depth:  dec     level+1
@restart_search:  lda     #$00
         sta     $8d
         sta     $133c
         lda     $21
         sta     scoreL_stack
         lda     $2e
         sta     scoreH_stack
         lda     $9f
         sta     $b5
         lda     $b4
         sta     $b6
         lda     $145b
         sta     $8e
         lda     $1465
         sta     $8f
         jmp     @iter_loop

; Initialize board state: compute material balance ($6A), locate kings
; ($6C/$6D), count total material ($07), set endgame flag (level+2)
init_board_state:   lda     #$00
         sta     level+2
         sta     $6a
         sta     $07
         ldx     #$15
@piece_loop:  lda     $146e,x
         beq     @next_sq
         cmp     #$ff
         beq     @next_sq
         sta     $13
         and     #$07
         tay
         cmp     #$06
         bne     @add_value
         lda     $13
         bmi     @bk_king
         stx     $6c
         bne     @add_value
@bk_king:  stx     $6d
@add_value:  lda     $13
         bmi     @sub_value
         lda     $6a
         clc
         adc     la634+223,y
         jmp     @store_bal

@sub_value:  lda     $6a
         sec
         sbc     la634+223,y
@store_bal:  sta     $6a
         lda     $07
         clc
         adc     la634+223,y
         sta     $07
@next_sq:  inx
         cpx     #$63
         bcc     @piece_loop
         lda     $07
         cmp     #$2e
         bcs     @done
         lda     $6a
         bpl     @check_endgame
         eor     #$ff
         clc
         adc     #$01
@check_endgame:  cmp     #$05
         bcc     @done
         sta     level+2
@done:  rts

.if      .defined(USE_VIC_BOOK_FIX)
    .include "sargon_2_vic20_book_fix.S"
.elseif  .defined(USE_VIC_BOOK)
    .include "sargon_2_vic20_book.S"
.elseif  .defined(USE_CPM_BOOK)
    .include "sargon_21_cpm_book.S"
.else
    .error "No openings book defined. Please define one of the USE_* flags."
.endif

; Opening book lookup: traverse the book tree to find current position
; Book format: each node has a bitmap of children, followed by move+pointer pairs
; $9C = last move played (halved for book encoding)
; If found, plays a random book move; if not, sets $1C flag to stop consulting
opening_book_lookup:   lsr     $9c
         ldy     #$00
         lda     move_number
         cmp     #$01
         bne     @search_book
         lda     #<lopenings
         sta     opening_ptr
         lda     #>lopenings
         sta     opening_ptr+1
         lda     human_color
         beq     @select_move
@search_book:  lda     (opening_ptr),y
         ldx     #$01
@count_children:  lsr     A
         bcc     @shift_bits
         inx
@shift_bits:  cmp     #$00
         bne     @count_children
         lda     $9c
         iny
@match_move:  cmp     (opening_ptr),y
         beq     @found_match
         dex
         beq     @book_fail
         jsr     next_child
         bcc     @match_move
@book_fail:  lda     #$50
         sta     $1c
         rts

@found_match:  jsr     goto_child
         bcc     @select_move
         rts

@select_move:  ldy     #$00
         lda     (opening_ptr),y
         ora     #$80
         sta     $0d
         iny
         lda     vic_raster
         sta     $0e
@random_loop:  lsr     $0e
         bcs     @play_move
         lda     $0d
         beq     @use_first
         lsr     $0d
         bcc     @random_loop
         jsr     next_child
         bne     @random_loop
@use_first:  ldy     #$01
@play_move:  lda     (opening_ptr),y
         asl     A
         sta     $8d
         jsr     goto_child
         jsr     make_move
         jsr     unmake_move
         jsr     store_best_move
         lda     #$50
         sta     scoreH_stack
         lda     #$00
         sta     scoreL_stack
         pla
         pla
         rts

; Navigate to a child node in the opening book tree
; Reads 2-byte pointer at (opening_ptr),Y+1; $FF = end of book
goto_child:
         iny
         lda     (opening_ptr),y
         cmp     #$ff
         beq     @end_of_book
         sta     $0d
         iny
         lda     (opening_ptr),y
         sta     opening_ptr+1
         lda     $0d
         sta     opening_ptr
         clc
         rts

@end_of_book:  sta     $1c
         sec
         rts

; Skip to the next sibling node in the opening book tree
next_child:
         sta     $0f
         iny
         lda     (opening_ptr),y
         cmp     #$ff
         beq     @skip_ptr
         iny
@skip_ptr:  iny
         lda     $0f
         clc
         rts

