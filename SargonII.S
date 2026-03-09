; =====================================================================
; Sargon II Chess - VIC-20 Disassembly
; =====================================================================
; Original: Sargon II by Dan and Kathe Spracklen (Hayden Software, 1983)
; Platform: Commodore VIC-20 (unexpanded)
; Assembler: cc65 v2.17.0
; Disassembly: 6502bench SourceGen v1.0.0
;
; This is a disassembly/relabel of the Sargon II chess program for the
; VIC-20. The program uses custom character graphics for the board,
; KERNAL routines for I/O, and implements a minimax search with
; alpha-beta pruning for move evaluation.
; =====================================================================

         .setcpu "6502"

; ---------------------------------------------------------------------
; Zero page variables and system addresses
; ---------------------------------------------------------------------
human_color =    $15            ; color the human is playing (0=white)
next_color =     $16            ; side to move next
move_number =    $18            ; current full-move number
level    =       $19            ; difficulty/search depth level
scoreL_stack =   $23            ; score stack low bytes (minimax search)
scoreH_stack =   $30            ; score stack high bytes (minimax search)
opening_ptr =   $94             ; pointer into opening book data

; System/hardware addresses
screen_page =    $0288          ; OS: high byte of screen memory address
nmi_vector_l =   $0318          ; OS: NMI interrupt vector low byte
nmi_vector_h =   $0319          ; OS: NMI interrupt vector high byte
vic_raster =     $9004          ; VIC chip: raster line counter

; BASIC ROM routines
b_init_ram =     $e3a4          ; BASIC: initialize RAM pointers
b_init_vecs =    $e45b          ; BASIC: initialize vectors
b_init_hw =      $e518          ; BASIC: initialize hardware

; KERNAL ROM routines
k_ramtas =       $fd8d          ; KERNAL: RAM test and set
k_init_regs =    $fdf9          ; KERNAL: initialize I/O registers
k_init_vecs =    $ff8a          ; KERNAL: initialize KERNAL vectors
k_out_to_channel = $ffd2        ; KERNAL: output character (CHROUT)
k_getchar =      $ffe4          ; KERNAL: get character from keyboard (GETIN)
k_cursor_pos =   $fff0          ; KERNAL: set cursor position (PLOT)

; Data table aliases (embedded in black_patterns character data)
initial_pieces = black_patterns + 216  ; initial back rank piece types
piece_values   = black_patterns + 223  ; material value per piece type
move_dir_start = black_patterns + 229  ; starting direction index per piece type
move_dir_count = black_patterns + 235  ; number of move directions per piece type
move_directions = black_patterns + 242 ; direction offset table for move generation
centrality     = black_patterns + 260  ; positional centrality value per square
node_limits    = black_patterns + 266  ; search node limits per difficulty level

; =====================================================================
; Entry point - loaded at $2000 (originally $a000 autostart ROM)
; =====================================================================
         .org    $2000          ; original $a000

;--- PATCH (9 bytes) ---
; Replaces the CBM autostart ROM header with a direct startup sequence.
; The original header bytes (start vector, NMI vector, "A0CBM" signature)
; are replaced with initialization code for running from RAM.
         sei                    ; disable interrupts during init
         cld                    ; clear decimal mode
         jsr     k_ramtas       ; initialize RAM (test and set)
         jmp     start          ; jump to main initialization
         nop                    ; pad to 9 bytes
;--- PATCH ---

;--- ORIGINAL (9 bytes) ---
; Original autostart ROM header: start vector, NMI vector, "A0CBM" sig
.if 0
         .byte   <start
         .byte   >start
         .byte   <nmi_handler
         .byte   >nmi_handler
         .byte   $41            ; 'A'
         .byte   $30            ; '0'
         .byte   $c3            ; 'C' + $80
         .byte   $c2            ; 'B' + $80
         .byte   $cd            ; 'M' + $80
.endif
;--- END OF ORIGINAL ---

; =====================================================================
; Screen and board display routines
; =====================================================================

; clear_screen - output PETSCII clear screen character
clear_screen:   lda     #$93           ; PETSCII: clear screen
         jmp     k_out_to_channel

; init_board_display - clear screen and position cursor at the board area
init_board_display:   jsr     clear_fill_screen
; set_board_cursor - position cursor to col 7, row 6 (top-left of board)
set_board_cursor:   clc
         ldx     #$07           ; column 7
         ldy     #$06           ; row 6
         jmp     k_cursor_pos

; clear_fill_screen - clear screen and fill screen RAM with spaces
; Fills $1e00-$1fff with PETSCII space ($a0) to blank the display
clear_fill_screen:   jsr     clear_screen
         lda     #$a0           ; PETSCII space character
         ldx     #$fd           ; counter: 253 bytes x 2 passes = 506 bytes
@fill_loop:  sta     $1dff,x        ; fill $1e00-$1efc (first page)
         sta     $1efc,x        ; fill $1efd-$1ff9 (second page)
         dex
         bne     @fill_loop
         rts

; draw_board_row - scroll/refresh the status bar area on screen
; Uses ZP pointers: $57-$58 = screen dest, $59-$5a = source,
;                   $5b-$5c = color RAM dest (screen + $7800)
; Copies 5 chars wide across 15 rows, shifting content down by one line.
draw_board_row:   pha
         ldx     #$03           ; copy 4 initial pointer bytes
@load_ptrs:  lda     @ptr_data,x       ; load initial pointer values
         sta     $57,x          ; store to ZP pointers ($57-$5a)
         dex
         bpl     @load_ptrs
         ldx     #$0f           ; 15 rows to draw
@row_loop:  ldy     #$00
         lda     $57            ; copy screen ptr low to color ptr
         sta     $5b
         clc
         lda     $58            ; color RAM = screen + $7800
         adc     #$78
         sta     $5c
@col_loop:  lda     ($59),y        ; read source graphics char
         sta     ($57),y        ; write to screen RAM
         lda     #$01           ; white color
         sta     ($5b),y        ; write to color RAM
         iny
         cpy     #$05           ; 5 characters per cell
         bcc     @col_loop
         lda     $5a            ; advance source ptr: swap high bytes
         sta     $58
         lda     $59            ; previous source low -> screen dest low
         sta     $57
         clc
         adc     #$16           ; advance source by 22 (screen width)
         sta     $59
         bcc     @no_carry
         inc     $5a            ; carry into high byte
@no_carry:  dex
         bne     @row_loop
         jsr     clear_input_area
         pla
         rts

; Initial pointer values for draw_board_row
; $57-$58 = $1e11 (screen dest), $59-$5a = $1e27 (source graphics)
@ptr_data:  .byte   $11            ; screen dest low byte
         .byte   $1e            ; screen dest high byte
         .byte   $27            ; source graphics low byte
         .byte   $1e            ; source graphics high byte

; clear_input_area - clear the 5-char input display area at bottom of board
; Fills screen $1f5b-$1f5f with space ($60) and sets color to white
clear_input_area:   ldy     #$04           ; 5 characters (0-4)
@clr_loop:  lda     #$60           ; space character (shifted)
         sta     $1f5b,y        ; clear screen position
         lda     #$01           ; white
         sta     $975b,y        ; set color RAM (screen + $7800)
         dey
         bpl     @clr_loop
         rts

; redraw_all_rows - redraw all 15 board rows
redraw_all_rows:   lda     #$0f           ; 15 rows
         sta     $00            ; loop counter
@flash_loop:  jsr     refresh_board
         dec     $00
         bne     @flash_loop
         rts

; handle_char_display - process a character for the move notation display
; If RETURN, resets board. Otherwise adds to 6-char buffer, wrapping when full.
handle_char_display:   ldx     $f9            ; current display position
         cmp     #$0d           ; RETURN key?
         beq     refresh_board  ; yes: redraw board and reset position
         inx
         cpx     #$06           ; display buffer full (6 chars)?
         bcc     @show_it         ; no: display the character
         jsr     refresh_board  ; yes: wrap - redraw board first
@show_it:  jmp     display_input_char

; display_move_text - print move characters then refresh the board
display_move_text:   jsr     print_move_chars
; refresh_board - redraw board border row and reset input position counter
refresh_board:   jsr     draw_board_row
         ldx     #$00
         stx     $f9            ; reset input display position to 0
         rts

; ---------------------------------------------------------------------
; Move input routines
; ---------------------------------------------------------------------

; get_move_input - main input routine: get a complete move from the user
; Accepts algebraic notation chars (e.g. "E2E4"), DELETE, RETURN, '?' hint.
; Returns: A = first char of input buffer ($033c)
get_move_input:   ldx     #$00
         stx     $f9            ; reset display position
         stx     $1f            ; clear joystick flag
get_move_restart:   ldx     #$00
         stx     $00            ; reset input buffer index
get_move_loop:   jsr     poll_keyboard
         pha
         lda     $f9
         bne     @redraw         ; skip clear if mid-input
         jsr     clear_input_area
@redraw:  jsr     draw_board_frame
         pla
         bit     $1f            ; check joystick flag (bit 7)
         bpl     @check_key         ; no joystick: continue with keyboard
         jmp     joystick_move  ; handle joystick input instead

@check_key:  cmp     #$0d           ; filter: ignore chars below RETURN
         bcc     get_move_loop
         cmp     #$4a           ; filter: ignore chars >= 'J'
         bcs     get_move_loop
         cmp     #$14           ; DELETE key?
         beq     get_move_delete
         cmp     #$0d           ; RETURN key?
         beq     @enter_key
         ldy     $00            ; check buffer length
         cpy     #$05           ; max 5 characters?
         bcs     get_move_loop  ; buffer full: ignore
         jsr     buffer_input_char
         jmp     get_move_loop

@enter_key:  jsr     process_input_char ; process RETURN
get_move_done:   ldx     #$00
         stx     $f9            ; reset display position
         lda     $033c          ; return first char of input buffer
         rts

; Handle DELETE: remove last character and back up buffer index
get_move_delete:   jsr     process_input_char
         dec     $00            ; decrement buffer index
         bmi     get_move_restart ; underflow: restart input
         bpl     get_move_loop

; poll_keyboard - poll keyboard via KERNAL; also checks joystick
; If '?' pressed, jumps to player_hint. If joystick active, sets flag $1f.
poll_keyboard:   jsr     k_getchar      ; read keyboard
         bne     @check_hint         ; key pressed: check which key
         jsr     read_joystick  ; no key: check joystick
         beq     poll_keyboard  ; no joystick either: keep polling
         lda     #$80           ; joystick active: set flag bit 7
         sta     $1f
@done:  rts

@check_hint:  cmp     #$3f           ; '?' key?
         bne     @done         ; no: return with key in A
         jmp     player_hint    ; yes: show hint to player

; wait_for_keypress - busy-wait until a key is pressed
wait_for_keypress:   jsr     k_getchar
         beq     wait_for_keypress
         rts

; input (prompt_and_read) - print a prompt string, wait for keypress, echo it
input:   jsr     input_string   ; print the prompt string
         jsr     wait_for_keypress
; echo_char - echo character with high bit set (PETSCII shifted) + CR
echo_char:   pha
         ora     #$80           ; set high bit for shifted PETSCII
         jsr     k_out_to_channel
         lda     #$0d           ; carriage return
         jsr     k_out_to_channel
         pla
         rts

; buffer_input_char - store typed character into input buffer at $033c
buffer_input_char:   ldy     $00            ; current buffer index
         inc     $00            ; advance index
         sta     $033c,y        ; store char in input buffer
; process_input_char - process input char for visual display
; Handles RETURN (reset), DELETE (erase last), or normal char display.
process_input_char:   ldx     $f9            ; current display position
         cmp     #$14           ; DELETE?
         beq     @del_char
         cmp     #$0d           ; RETURN?
         beq     @reset_pos         ; yes: reset position
         inx
         cpx     #$06           ; display full?
         bcc     display_input_char ; no: show the character
         rts                    ; yes: ignore

; Handle DELETE: erase character at current position
@del_char:  lda     #$60           ; space character (shifted)
         cpx     #$00           ; at start of line?
         beq     @reset_pos         ; yes: just reset
         sta     $1f5a,x        ; blank the character on screen
         dex
         beq     @save_pos         ; reached position 0
         bmi     @reset_pos         ; underflow: reset
@save_pos:  stx     $f9            ; update display position
         rts

; Reset display position to 0
@reset_pos:  ldx     #$00
         stx     $f9
         rts

; display_input_char - display character at current position on input line
; Writes to screen RAM $1f5a+x and color RAM $975a+x
display_input_char:   stx     $f9            ; save new display position
         ora     #$40           ; convert to screen code (set bit 6)
         sta     $1f5a,x        ; write char to screen
         pha
         lda     #$01           ; white
         sta     $975a,x        ; set color
         pla
         rts

; play_beep - play a short beep sound via VIC sound register
play_beep:   stx     $900b          ; set VIC sound register (tone)
         ldx     #$80           ; delay outer counter
         ldy     #$80           ; delay inner counter
@delay:  dex                    ; inner loop
         bne     @delay
         dey                    ; outer loop
         bne     @delay
         sty     $900b          ; silence (Y=0 after loop)
         rts

; =====================================================================
; BOARD GRAPHICS - Joystick input, board rendering, and character setup
; =====================================================================

; ---------------------------------------------------------------------
; joystick_move - Handle move entry via joystick/cursor keys
; User navigates the board with cursor keys, presses RETURN/fire to
; select from-square then to-square. $07 = board position (cursor).
; From-square -> $ab, to-square -> $ac. Once both entered, copies
; the move to the input buffer at $0200/$033c.
; ---------------------------------------------------------------------
joystick_move:   ldx     #$36           ; initial cursor position
@set_square:  stx     $07            ; store current board position
@wait_joy:  jsr     highlight_square       ; blink current square
         jsr     read_joystick          ; check joystick/keys
         beq     @wait_joy                 ; no input, keep blinking
         cmp     #$0d                   ; RETURN/fire?
         beq     @enter_move                 ; yes: select square
         jsr     handle_cursor          ; translate direction to board move
         jmp     @set_square                 ; loop with updated position

@enter_move:  ldx     #$dc                   ; beep on selection
         jsr     play_beep
         lda     $ab                    ; file (0-7)
         clc
         adc     #$41                   ; convert to ASCII 'A'-'H'
         jsr     @store_char                 ; store in input buffer
         lda     $ac                    ; rank (0-7)
         eor     #$07                   ; flip rank (board is top-down)
         clc
         adc     #$31                   ; convert to ASCII '1'-'8'
         jsr     @store_char                 ; store in input buffer
         lda     $1f                    ; check move phase
         and     #$01
         bne     @copy_move                 ; bit 0 set = to-square done
         lda     #$2d                   ; '-' separator between squares
         jsr     @store_char
         lda     #$81                   ; set flag: from-square entered
         sta     $1f
         bne     @wait_joy                 ; loop for to-square

@copy_move:  ldx     #$05                   ; copy move from $0200 to $033c
@copy_loop:  lda     $0200,x
         sta     $033c,x
         dex
         bpl     @copy_loop
@wait_release:  jsr     read_joystick          ; wait for joystick release
         bne     @wait_release
         sta     $1f                    ; clear move phase flag
         jmp     get_move_done

; Store character to input buffer and echo it
@store_char:  ldy     $00                    ; current buffer index
         inc     $00
         sta     $0200,y
         jmp     process_input_char

; ---------------------------------------------------------------------
; read_joystick - Read VIC-20 joystick via VIA registers
; Reads VIA#2 port B ($9120) bit 7 for joy-right, VIA#1 port A ($9111)
; bits 2-5 for up/down/left/fire. Returns PETSCII key code in A:
;   joy-up    (PA2) -> $91   board up    (rank+10)
;   joy-down  (PA3) -> $11   board down  (rank-10)
;   joy-left  (PA4) -> $9d   board left  (file-1)
;   fire      (PA5) -> $0d   confirm/select (= RETURN)
;   joy-right (PB7) -> $1d   board right (file+1)
;   (none)          -> $00
; ---------------------------------------------------------------------
read_joystick:   sei
         ldx     #$7f                   ; set VIA port B bit 7 as input
         stx     $9122                  ; write DDR-B
@debounce:  lda     $9120                  ; read port B (debounce: read twice)
         cmp     $9120
         bne     @debounce
         ldx     #$ff                   ; restore DDR-B to all outputs
         stx     $9122
         ldx     #$f7                   ; clear bit 3 of port B
         stx     $9120                  ; (active-low joystick select)
         cli
         and     #$80                   ; test joy-right (PB7)
         bne     @read_col                 ; not pressed: check directions

         .byte   $a9                    ; LDA #$1d (joy-right = cursor-right)
         .byte   $1d
         .byte   $60                    ; RTS

@read_col:  ldy     $9111                  ; read VIA port A (debounce)
         cpy     $9111
         bne     @read_col
         ldx     #$04                   ; check 4 direction bits
@scan_dirs:  tya
         and     @dir_masks,x              ; test against bitmask
         beq     @found_dir                 ; zero = direction active (active-low)
         dex
         bpl     @scan_dirs
@found_dir:  lda     @dir_keys,x              ; look up result code
         rts

; Joystick direction bitmasks (active-low bits from VIA port A)
@dir_masks:  .byte   $00                    ; (sentinel - no match)
         .byte   $04                    ; PA2: joy-up
         .byte   $08                    ; PA3: joy-down
         .byte   $10                    ; PA4: joy-left
         .byte   $20                    ; PA5: fire
; Joystick direction -> PETSCII key code mapping
@dir_keys:  .byte   $00                    ; none
         .byte   $91                    ; joy-up    -> cursor-up
         .byte   $11                    ; joy-down  -> cursor-down
         .byte   $9d                    ; joy-left  -> cursor-left
         .byte   $0d                    ; fire -> RETURN (confirm)

; ---------------------------------------------------------------------
; highlight_square - Highlight current board square by flashing it
; Converts board index in $07 to notation, then flashes the square.
; ---------------------------------------------------------------------
highlight_square:   lda     $07
         jsr     square_to_notation
         lda     $033c                  ; file -> $ab
         sta     $ab
         lda     $033d                  ; rank -> $ac
         sta     $ac
         lda     #$02                   ; flash 2 times
         jsr     flash_n_times
         rts

; ---------------------------------------------------------------------
; handle_cursor - Translate cursor key code to board position change
; Board uses 10-wide mailbox layout (stride 10):
;   up=-10 ($f6), down=+10 ($0a), left=-1 ($ff), right=+1 ($01)
; Wraps at board edges using $146e border sentinels ($ff).
; Y = wrap offset if edge hit; X = direction delta.
; Returns: updated position in X register.
; ---------------------------------------------------------------------
handle_cursor:   ldy     #$08           ; wrap offset: cursor-left
         ldx     #$ff                   ; delta: -1 (left)
         cmp     #$9d
         beq     @apply_dir
         ldy     #$f8                   ; wrap offset: cursor-right
         ldx     #$01                   ; delta: +1 (right)
         cmp     #$1d
         beq     @apply_dir
         ldy     #$b0                   ; wrap offset: rank up
         ldx     #$0a                   ; delta: +10 (rank up)
         cmp     #$91                   ; cursor-up / joy-up
         beq     @apply_dir
         ldy     #$50                   ; wrap offset: rank down
         ldx     #$f6                   ; delta: -10 (rank down)
         cmp     #$11                   ; cursor-down / joy-down
         beq     @apply_dir
         ldy     #$ff                   ; unknown key: no change
         rts

@apply_dir:  txa                            ; apply delta to current position
         clc
         adc     $07
         tax
         lda     $146e,x                ; check board array
         cmp     #$ff                   ; border sentinel?
         bne     @done                 ; no: position is valid
         sty     $07                    ; yes: apply wrap offset
         txa
         clc
         adc     $07
         tax
@done:  rts

; ---------------------------------------------------------------------
; flash_square / flash_n_times - Flash a board square
; flash_square: flashes 16 times. flash_n_times: count in A -> $a8.
; Toggles reverse video with a delay loop between each flash.
; ---------------------------------------------------------------------
flash_square:   lda     #$10           ; 16 flashes
flash_n_times:   sta     $a8            ; flash counter
@flash_loop:  jsr     flash_piece            ; toggle reverse video
         ldy     #$30                   ; delay loop
@delay:  dex
         bne     @delay
         dey
         bne     @delay
         dec     $a8                    ; next flash
         bne     @flash_loop
         rts

; ---------------------------------------------------------------------
; animate_move - Animate a piece moving on screen
; Flashes source, blanks it, draws piece at destination, flashes again
; if capture. $ab/$ac=from col/row, $ad/$ae=dest col/row,
; $aa=piece byte, $a9=square color.
; ---------------------------------------------------------------------
animate_move:   jsr     flash_square           ; flash piece at source
         clc
         lda     $ab                    ; determine source square color
         adc     $ac                    ; col + row
         and     #$01                   ; odd = dark square
         beq     @set_bg
         lda     #$80                   ; $80 = dark, $00 = light
@set_bg:  sta     $a9
         jsr     draw_blank_square      ; erase piece from source
         lda     $ad                    ; set destination coordinates
         sta     $ab
         lda     $ae
         sta     $ac
         lda     $aa                    ; piece byte
         beq     @done                 ; empty = no piece to draw
         jsr     draw_piece             ; draw piece at destination
         jsr     flash_square           ; flash at destination
@done:  rts

; ---------------------------------------------------------------------
; draw_piece - Draw a piece on the board given piece byte in $aa
; Determines square color ($a9) from position and piece color bit.
; Handles empty squares (piece type 0) as blank squares.
; Piece byte: bit7=color(0=white,1=black), bit6=has-moved, bits2-0=type
; $a5 = graphics index, $a9 = square color ($00=light, $80=dark)
; ---------------------------------------------------------------------
draw_piece:   lda     $aa
         and     #$bf                   ; strip has-moved bit
         sta     $a7
         beq     @set_bg                 ; type 0 = empty square
         rol     A                      ; shift color bit (bit 7) into carry
         rol     A                      ; then into bit 0
         and     #$01                   ; isolate piece color
         sta     $a9
         lda     $ab                    ; compute square color from position
         clc
         adc     $ac                    ; col + row
         and     #$01                   ; parity
         eor     $a9                    ; XOR with piece color
         sta     $a9
         lda     $a7                    ; build graphics index:
         asl     A                      ; piece * 2
         ora     $a9                    ; + square color parity
         sta     $a5
         lda     $a7                    ; check piece color
         bmi     @black_bg                 ; bit 7 set = black piece
         lda     #$00                   ; white piece: $a9 = $00
         beq     @set_bg

@black_bg:  lda     #$80                   ; black piece: $a9 = $80
@set_bg:  sta     $a9
         lda     $a7                    ; piece type (with color bit)
         bne     @draw_it                 ; non-empty: render it
         lda     #$01                   ; empty square: use blank entry
         sta     $a5
         clc
         lda     $ab                    ; determine blank square shade
         adc     $ac
         and     #$01
         beq     @set_bg2
         lda     #$80                   ; dark square
@set_bg2:  sta     $a9
@draw_it:  jsr     render_piece
         rts

; ---------------------------------------------------------------------
; decode_piece_gfx - Decode piece byte into graphics table index
; Input: $aa = raw piece byte (bit7=color, bit6=moved, bits2-0=type)
; Maps piece type (1-6) to character table offset via @glyph_map lookup.
; Output: $aa = graphics index for piece_char_map
; ---------------------------------------------------------------------
decode_piece_gfx:   lda     $aa
         rol     A                      ; save bit 7 (color) in carry
         php
         ror     A                      ; restore A
         and     #$07                   ; isolate piece type (0-6)
         tax
         lda     @glyph_map,x              ; look up graphics offset
         plp                            ; restore carry (color bit)
         ror     A                      ; shift color into high bit of offset
         sta     $aa
         rts

; Piece type to graphics offset lookup table
; Index: 0=empty, 1=pawn, 2=knight, 3=bishop, 4=rook, 5=queen, 6=king
@glyph_map:  .byte   $00                    ; empty
         .byte   $02                    ; pawn
         .byte   $06                    ; knight
         .byte   $08                    ; bishop
         .byte   $04                    ; rook
         .byte   $0a                    ; queen
         .byte   $0c                    ; king

; ---------------------------------------------------------------------
; parse_move_squares - Parse from/to squares into algebraic notation
; Converts from-square ($07) and to-square ($08) board indices.
; Result: $ab/$ac = from file/rank, $ad/$ae = dest file/rank.
; ---------------------------------------------------------------------
parse_move_squares:   lda     $07            ; from-square index
         jsr     square_to_notation
         lda     $033c                  ; file (0-7)
         sta     $ab
         lda     $033d                  ; rank (0-7)
         sta     $ac
         lda     $08                    ; to-square index
         jsr     square_to_notation
         lda     $033c
         sta     $ad
         lda     $033d
         sta     $ae
         rts

; ---------------------------------------------------------------------
; square_to_notation - Convert board index to file (0-7) and rank (0-7)
; Input: A = board square index. Uses byte_to_bcd to split into
; tens (rank) and ones (file). Result in $033c (file) / $033d (rank).
; ---------------------------------------------------------------------
square_to_notation:   ldx     #$01
         jsr     byte_to_bcd            ; split A into BCD digits
         dec     $033c                  ; adjust file to 0-based
         lda     $033c
         and     #$07                   ; mask to 0-7
         sta     $033c                  ; file (A=0 .. H=7)
         lda     #$38                   ; '8' - flip rank (top=0)
         sec
         sbc     $033d
         sta     $033d                  ; rank (0-7, 0=rank 8)
         rts

; ---------------------------------------------------------------------
; exec_board_move - Animate a complete move on the board display
; Reads piece from board array at $146e, parses squares, decodes
; graphics, and calls animate_move.
; ---------------------------------------------------------------------
exec_board_move:   ldx     $08            ; to-square index
         lda     $146e,x                ; read piece at destination
         sta     $aa
         jsr     parse_move_squares
         jsr     decode_piece_gfx
         jsr     animate_move
         rts

; ---------------------------------------------------------------------
; calc_screen_pos - Calculate screen RAM address for a board square
; Input: $ab = column (0-7), $ac = rank (0-7)
; Computes: row * 22 + col * 2 + screen base ($1e00)
; Output: $a3/$a4 = screen address, $f7/$f8 = color RAM address
;         Y=1, X=2 (for 2x2 character rendering)
; ---------------------------------------------------------------------
calc_screen_pos:   lda     #$00
         sta     $a3                    ; clear screen pointer
         sta     $a4
         lda     $ac                    ; rank * 4
         asl     A
         asl     A
         jsr     add_screen_offset      ; add rank*4 to pointer
         lda     $a3                    ; multiply by ~5.5 to get rank*22
         ldx     #$0a                   ; (add current value 10 more times)
@mul_loop:  jsr     add_screen_offset      ; result: rank * 44 (2 screen rows)
         dex
         bne     @mul_loop
         lda     #$00                   ; add screen base address $1e00
         clc
         adc     $a3
         sta     $a3
         lda     #$1e                   ; high byte of screen base
         adc     $a4
         sta     $a4
         lda     $ab                    ; column * 2 (each square = 2 chars)
         asl     A
         jsr     add_screen_offset
         ldy     #$01                   ; Y = 1 (index for 2-char width)
         ldx     #$02                   ; X = 2 (row count for 2x2 grid)
         rts

; ---------------------------------------------------------------------
; calc_color_pos - Calculate color RAM address from screen address
; Color RAM = screen address + $7800 offset on VIC-20.
; Input: $a3/$a4 = screen address
; Output: $f7/$f8 = color RAM address
; ---------------------------------------------------------------------
calc_color_pos:   lda     $a3
         sta     $f7
         clc
         lda     $a4
         adc     #$78                   ; color RAM offset ($9600-$1e00=$7800)
         sta     $f8
         rts

; ---------------------------------------------------------------------
; add_screen_offset - Add A to screen pointer and update color RAM
; Input: A = offset value. Updates $a3/$a4 and $f7/$f8.
; ---------------------------------------------------------------------
add_screen_offset:   pha
         clc
         adc     $a3
         sta     $a3
         bcc     @no_carry
         inc     $a4
@no_carry:  jsr     calc_color_pos
         pla
         rts

; ---------------------------------------------------------------------
; draw_blank_square - Draw an empty square (4 blank characters)
; Falls through to render_piece with $a5 = 1 (blank entry index).
; ---------------------------------------------------------------------
draw_blank_square:   lda     #$01
         sta     $a5
; ---------------------------------------------------------------------
; render_piece - Render piece graphics at calculated screen position
; Uses piece_char_map indexed by $a5 to get 4 character codes (2x2).
; XORs with $a9 (square color) and $80 for correct appearance.
; Writes to both screen RAM ($a3/$a4) and color RAM ($f7/$f8).
; ---------------------------------------------------------------------
render_piece:   jsr     calc_screen_pos
         lda     $a5                    ; graphics index
         asl     A                      ; * 4 (each entry = 4 bytes)
         asl     A
         stx     $a5                    ; save row counter
         tax
         dex                            ; point to last byte of entry
@draw_loop:  lda     piece_char_map,x       ; get character code
         eor     $a9                    ; apply square color
         eor     #$80                   ; toggle reverse video bit
         sta     ($a3),y                ; write to screen RAM
         lda     #$01                   ; color = white
         sta     ($f7),y                ; write to color RAM
         dex
         dey
         bpl     @draw_loop                 ; next char in this row
         ldy     #$01                   ; reset column index
         lda     #$16                   ; advance one screen row (22 cols)
         jsr     add_screen_offset
         dec     $a5                    ; next row of 2x2 grid
         bne     @draw_loop
         rts

; ---------------------------------------------------------------------
; flash_piece - Flash a piece by toggling reverse video (XOR $80)
; XORs all 4 screen chars of the 2x2 piece grid with $80.
; ---------------------------------------------------------------------
flash_piece:   jsr     calc_screen_pos
@inv_loop:  lda     ($a3),y                ; read screen character
         eor     #$80                   ; toggle reverse video
         sta     ($a3),y
         dey
         bpl     @inv_loop
         ldy     #$01
         jsr     advance_row
         dex
         bne     @inv_loop
         rts

; ---------------------------------------------------------------------
; advance_row - Advance screen pointer by 22 bytes (one VIC-20 row)
; ---------------------------------------------------------------------
advance_row:   pha
         lda     #$16                   ; 22 columns per row
         jsr     add_screen_offset
         pla
         rts

; ---------------------------------------------------------------------
; draw_all_pieces - Draw all pieces on the board
; Iterates through board squares $15-$62 in the $146e board array,
; reads piece data, and draws each piece. Skips border sentinels ($ff).
; ---------------------------------------------------------------------
draw_all_pieces:   jsr     clear_screen
         ldx     #$15                   ; first valid board square
@piece_loop:  lda     $146e,x                ; read piece at square
         cmp     #$ff                   ; border sentinel?
         beq     @next_sq                 ; skip borders
         sta     $aa                    ; piece byte
         txa
         pha                            ; save board index
         jsr     square_to_notation     ; convert index to file/rank
         jsr     decode_piece_gfx       ; decode piece for rendering
         lda     $033c
         sta     $ab                    ; file
         lda     $033d
         sta     $ac                    ; rank
         jsr     draw_piece
         pla
         tax                            ; restore board index
@next_sq:  inx
         cpx     #$63                   ; last valid square + 1
         bne     @piece_loop
; ---------------------------------------------------------------------
; draw_board_frame - Draw board border with rank/file labels
; Draws rank numbers (8-1) on the left side using custom chars $78-$71,
; file letters (A-H) across the bottom. Also displays the current
; difficulty level and "SARGON II" title with special graphics.
; ---------------------------------------------------------------------
draw_board_frame:   jsr     clear_status_line
         lda     #$00                   ; screen pointer = $1e00 (top-left)
         sta     $a3
         lda     #$1e
         sta     $a4
         jsr     calc_color_pos
         lda     #$78                   ; rank digit char (starts at '8')
         sta     $a5
         ldy     #$10                   ; column 16 (right of board)
@rank_loop:  lda     #$80                   ; blank space (top row of rank pair)
         sta     ($a3),y
         lda     $20                    ; background color
         sta     ($f7),y
         jsr     advance_row            ; next screen row
         lda     $a5                    ; rank digit character
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         jsr     advance_row
         dec     $a5                    ; next rank (8->7->...->1)
         lda     $a5
         cmp     #$70                   ; done all 8 ranks?
         bne     @rank_loop
         ldy     #$00                   ; draw file letters (A-H) at bottom
         lda     #$41                   ; 'A'
         sta     $a5
@file_loop:  lda     #$80                   ; space before letter
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         iny
         lda     $a5                    ; file letter
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         inc     $a5                    ; next letter
         lda     $a5
         iny
         cmp     #$49                   ; past 'H'?
         bne     @file_loop
         clc                            ; display "LEVEL" label
         ldx     #$15                   ; row 21
         ldy     #$0c                   ; column 12
         jsr     k_cursor_pos
         ldx     #<@llevel
         ldy     #>@llevel
         jsr     input_string
         lda     level                  ; show current level digit
         ora     #$70                   ; convert to screen code
         sta     $1fe0                  ; poke into screen RAM
         clc                            ; display "SARGON II" title
         ldx     #$13                   ; row 19
         ldy     #$05                   ; column 5
         jsr     k_cursor_pos
         ldx     #<@lsargon
         ldy     #>@lsargon
         jmp     input_string

; "LEVEL     " (PETSCII high-ASCII)
@llevel: .byte   $cc,$c5,$d6,$c5,$cc,$a0,$a0,$a0,$a0,$a0,$00
; "SARGON II" with special graphics characters
@lsargon:
         .byte   $9f
         .byte   $12
         .byte   "5WXYZ23"
         .byte   $1d
         .byte   $34
         .byte   $05
         .byte   $92
         .byte   $00

; ---------------------------------------------------------------------
; show_msg - Display a centered message on the status line
; Input: X/Y = pointer to null-terminated string (lo/hi).
; Centers by computing (22 - strlen) / 2 as screen offset.
; Characters are ORed with $40 for PETSCII-to-screen conversion.
; ---------------------------------------------------------------------
show_msg:
         stx     $a5                    ; string pointer low
         sty     $a6                    ; string pointer high
         jsr     clear_status_line
         ldy     #$ff                   ; find string length
@len_loop:  iny
         lda     ($a5),y
         bne     @len_loop
         tya                            ; Y = string length
         lsr     A                      ; length / 2
         sta     $a7
         lda     #$08                   ; centering offset
         sec
         sbc     $a7                    ; (22/2 - 3) - len/2
         jsr     add_screen_offset      ; advance screen pointer
         ldy     #$00
@print_loop:  lda     ($a5),y                ; get next character
         beq     @done                 ; null terminator: done
         ora     #$40                   ; PETSCII to screen code
         sta     ($a3),y                ; write to screen RAM
         lda     #$01                   ; white color
         sta     ($f7),y                ; write to color RAM
         iny
         bne     @print_loop
@done:  rts

; ---------------------------------------------------------------------
; clear_status_line - Clear the 22-character status line at $1f60
; Fills with $80 (blank) and sets color to background ($20).
; ---------------------------------------------------------------------
clear_status_line:   lda     #$60           ; status line at $1f60
         sta     $a3
         lda     #$1f
         sta     $a4
         jsr     calc_color_pos
         ldy     #$15                   ; 22 characters (0-$15)
@clr_loop:  lda     #$80                   ; blank character
         sta     ($a3),y
         lda     $20                    ; background color
         sta     ($f7),y
         dey
         bpl     @clr_loop
         rts

; ---------------------------------------------------------------------
; init_charset - Initialize custom character set
; 1) Copies default ROM characters from $8400 to $1a00 (512 chars)
; 2) Loads white piece patterns from white_patterns to $1c00,
;    and their inverted versions (EOR $ff) to $1800.
; 3) Loads black piece patterns from black_patterns to char RAM,
;    with inverted copies for reverse-video rendering.
; 216 bytes = 27 custom characters x 8 bytes each per set.
; ---------------------------------------------------------------------
init_charset:   lda     #$00
         tay
         sta     $57                    ; src low = $8400 (char ROM)
         sta     $59                    ; dst low = $1a00 (char RAM)
         lda     #$1a
         sta     $5a                    ; dst high
         lda     #$84
         sta     $58                    ; src high
@copy_loop:  lda     ($57),y                ; copy ROM char data
         sta     ($59),y
         inc     $57
         inc     $59
         bne     @check_done
         inc     $58
         inc     $5a
@check_done:  lda     $5a                    ; done when dest reaches $1c00
         cmp     #$1c
         bne     @copy_loop
         lda     $59
         bne     @copy_loop
         sta     $5b                    ; inverted dest low = $1800
         lda     #$18
         sta     $5c                    ; inverted dest high
         lda     #$1c
         sta     $5a                    ; normal dest = $1c00
         lda     #<white_patterns       ; load white piece patterns
         sta     $57
         lda     #>white_patterns
         sta     $58
         jsr     @copy_block                 ; copy + invert
         lda     #$d8                   ; set dest for black patterns
         sta     $59
         sta     $5b
         lda     #<black_patterns       ; load black piece patterns
         sta     $57
         lda     #>black_patterns
         sta     $58
@copy_block:  ldy     #$00                   ; copy 216 bytes ($d8)
@byte_loop:  lda     ($57),y                ; read pattern byte
         sta     ($59),y                ; store normal version
         eor     #$ff                   ; invert all bits
         sta     ($5b),y                ; store inverted version
         iny
         cpy     #$d8                   ; 27 chars * 8 bytes = 216
         bne     @byte_loop
         rts

; ---------------------------------------------------------------------
; piece_char_map - 52 bytes mapping piece types to 4 screen chars each
; 13 entries (2x2 grid per piece): empty, 6 white, 6 black pieces.
; Each entry: top-right, top-left, bottom-right, bottom-left
; Entry 0 = blank square, entries 1-12 = pieces on light/dark squares
; ---------------------------------------------------------------------
piece_char_map:   .byte   $00,$00,$00,$00,$1d,$1e,$1b,$1c,$03,$04,$01,$02,$22,$23,$1f,$21
         .byte   $07,$08,$05,$06,$26,$27,$24,$25,$0b,$0c,$09,$0a,$2a,$2b,$28,$29
         .byte   $0f,$10,$0d,$0e,$2e,$2f,$2c,$2d,$13,$14,$11,$12,$2e,$2f,$30,$31
         .byte   $13,$14,$15,$16
; ---------------------------------------------------------------------
; white_patterns - 216 bytes of custom character data for white pieces
; 27 characters x 8 bytes each. These define the pixel patterns for
; the 2x2 character graphics of each white piece type on the board.
; Also includes border/decoration characters at the end.
; ---------------------------------------------------------------------
white_patterns:   .byte   $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$01,$03,$03,$03,$01,$0f
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
; ---------------------------------------------------------------------
; black_patterns - 216 bytes of custom character data for black pieces
; 27 characters x 8 bytes each. Same layout as white_patterns but for
; black piece graphics. Inverted copies (EOR $ff) are generated at
; init time for reverse-video rendering.
;
; Following the 216 bytes of character data, the remaining bytes encode
; packed game data tables (referenced via aliases at top of file):
;
; +216: initial_pieces  - Back rank setup: R,N,B,Q,K,B,N,R
; +223: piece_values    - Material values: empty=1,P=3,N=3,B=5,R=9,Q=10,K=16,border=8
; +229: move_dir_start  - Starting direction index per piece type
; +235: move_dir_count  - Number of move directions per piece type
; +242: move_directions - 24 direction offsets (diag, ortho, knight, pawn)
; +260: centrality      - Positional value per board square (0-8)
; +266: node_limits     - Search depth limits per difficulty level
;
; Centrality map (10-wide mailbox with borders, 8 rows):
;   0,1,2,3,3,2,1,0  (rows 1,8 - edges)
;   1,3,4,5,5,4,3,1  (rows 2,7)
;   2,4,6,7,7,6,4,2  (rows 3,6)
;   3,5,7,8,8,7,5,3  (rows 4,5 - center, highest values)
; ---------------------------------------------------------------------
black_patterns:   .byte   $ff,$fe,$fd,$fb,$fb,$fb,$e1,$ef,$ff,$7f,$bf,$df,$df,$df,$87,$f7
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
; Border/notation characters (4 chars for board decorations)
         .byte   $46,$66,$76,$7e,$5e,$4e,$46,$00,$e7,$e7,$e7,$e7,$e7,$e7,$e7,$00
         .byte   $30,$4e,$4c,$40,$4c,$4e,$38,$00
; initial_pieces: back rank piece types R,N,B,Q,K,B,N,R
         .byte   $04,$02,$03,$05,$06,$03,$02,$04
; piece_values: material value by type [0]=1,P=3,N=3,B=5,R=9,Q=10,K=16,[7]=8
         .byte   $01,$03,$03,$05,$09,$0a,$10,$08
; move_dir_start: first direction index per piece type
         .byte   $00,$04,$00,$00,$04,$08,$04,$04
; move_dir_count: number of directions per piece type
         .byte   $08,$08,$09,$0b,$f5,$f7,$0a,$f6
; move_directions: 24 direction offsets for move generation
;   diags: +11,+9,-11,-9  ortho: +1,-1,+10,-10
;   knight: +8,+19,+21,+12,-8,-19,-21,-12  pawn: +10,-10
         .byte   $01,$ff,$eb,$f4,$08,$13,$15,$0c
         .byte   $f8,$ed,$0b,$09,$0a,$0a,$f5,$f7,$f6,$f6
; node_limits: search limits per difficulty level (7 levels)
         .byte   $00,$01,$02,$05,$10,$20
         .byte   $80,$01,$02,$05,$10,$20,$80,$ff
; centrality: positional value per board square (10-wide mailbox rows)
         .byte   $00,$00,$01,$02,$03,$03,$02,$01
         .byte   $00,$00,$00,$01,$03,$04,$05,$05,$04,$03,$01,$00,$00,$02,$04,$06
         .byte   $07,$07,$06,$04,$02,$00,$00,$03,$05,$07,$08,$08,$07,$05,$03,$00
         .byte   $00,$03,$05,$07,$08,$08,$07,$05,$03,$00,$00,$02,$04,$06,$07,$07
         .byte   $06,$04,$02,$00,$00,$01,$03,$04,$05,$05,$04,$03,$01,$00,$00,$00
         .byte   $01,$02,$03,$03,$02,$01,$00,$00,$11,$a9

; ---------------------------------------------------------------------
; String constants - PETSCII-encoded, null-terminated
; Used for menus, prompts, and game messages. High-ASCII ($80+) bytes
; are PETSCII shifted characters. Control codes: $0d=RETURN, $1d=right.
; ---------------------------------------------------------------------
; Welcome screen: "SARGON II" title, "BY DAN & KATHE SPRACKLEN",
; "(C) 1979 HAYDEN BOOK CO., INC", "F1 TO START"
lwelcome_msg:
         .byte   $05                    ; PETSCII: white text
         .byte   $08                    ; PETSCII: disable Shift+C=
         .byte   "WXYZ23"               ; title graphic (custom charset)
         .byte   $a0                    ; HiAscii space
         .byte   $34                    ; title graphic (custom charset)
         .res    2,$0d                  ; 2x RETURN
         .byte   $1d                    ; cursor-right
         .byte   "IJ"                   ; title graphic (custom charset)
         .byte   $1d                    ; cursor-right
.macro   HiAscii Arg
         .repeat .strlen(Arg), I
         .byte   .strat(Arg, I) | $80
         .endrep
.endmacro
         HiAscii "BY DAN & KATHE"
         .byte   $1d,$4d,$4e            ; cursor-right + graphic chars
         .byte   $0d                    ; RETURN
         .byte   $1d,$4b,$4c            ; cursor-right + graphic chars
         .res    3,$1d                  ; 3x cursor-right
         HiAscii "SPRACKLEN"
         .res    4,$1d                  ; 4x cursor-right
         .byte   $4f,$50                ; graphic chars
         .res    4,$0d                  ; 4x RETURN
         .res    6,$1d                  ; 6x cursor-right
         HiAscii "(C)  1979"
         .byte   $0d,$1d               ; RETURN + cursor-right
         HiAscii "HAYDEN BOOK CO., INC"
         .res    2,$0d                  ; 2x RETURN
         .res    5,$1d                  ; 5x cursor-right
         HiAscii "F1 TO START"
         .byte   $00                    ; null terminator
lgame_or_setup:
         .byte   $13                    ; PETSCII: HOME
         .byte   $0d                    ; RETURN
         HiAscii "GAME OR SETUP (G,S):"
         .byte   $00
lchoose_color:
         .byte   $0d                    ; RETURN
         HiAscii "YOUR COLOR (B,W):"
         .byte   $00
lchoose_level:
         HiAscii "LEVEL OF PLAY (0-6):"
         .byte   $00
lnextcolor:
         HiAscii "NEXT COLOR(B,W):"
         .byte   $00
lmovenum:
         HiAscii "MOVE NUMBER (NN):"
         .byte   $00
ladapted:
         .res    4,$0d                  ; 4x RETURN
         .byte   $35                    ; graphic char (custom charset)
         .byte   $0d                    ; RETURN
         HiAscii "ADAPTED BY ANDY FINKEL"
         .byte   $00
; Game status messages (ASCII, null-terminated)
linvalid_move:
         .asciiz "INVALID MOVE"
lcheck:  .asciiz "CHECK"
lmate:   .asciiz "MATE"
lmatein2:
         .asciiz "MATE IN 2"
; Castling and special move notation strings
loo:     .asciiz " O-O "                ; kingside castling
looo:    .asciiz "O-O-O"                ; queenside castling
lpxpep:  .byte   "PXPEP"                ; en passant notation
; Piece letter lookup table (indexed by piece type)
lpnbrqk: .byte   $00                    ; sentinel (type 0 = empty)
         .asciiz "PNBRQK"
lstalemate:
         .asciiz "STALEMATE"

; ---------------------------------------------------------------------
; vic_init_regs - 16 bytes of VIC chip register values for screen setup
; Loaded into $9000-$900f at startup. Configures: columns=22, rows=23,
; screen/char memory pointers, raster, sound, and color registers.
; ---------------------------------------------------------------------
vic_init_regs:
         .byte   $05,$19,$96,$2e,$00,$fe,$00,$00,$ff,$ff,$00,$00,$00,$00,$0f,$6d

; ---------------------------------------------------------------------
; nmi_handler - NMI interrupt handler (RESTORE key)
; Original code checked RESTORE key status via $9111 and conditionally
; restarted. Patched version simply jumps to restart_game.
; ---------------------------------------------------------------------
nmi_handler:  

;--- ORIGINAL (14 bytes) ---
.if 0
         bit     $9111          ; 3
         jsr     $ffe1          ; 3
         beq     restart_game          ; 2
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
         jmp     restart_game          ; 3
         .res    2, $ea 
;--- END OF PATCH ---

; =====================================================================
; GAME LOOP AND INITIALIZATION
; Main entry point, game loop, move handling, and board setup routines.
; =====================================================================

; ---------------------------------------------------------------------
; start - Main entry point
; Initializes KERNAL vectors, NMI handler, screen page, VIC hardware,
; BASIC vectors/RAM, custom charset, and initial board position.
; Falls through to restart_game.
; ---------------------------------------------------------------------
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
         jsr     k_init_vecs    ; 3  ; init KERNAL I/O vectors
         jsr     k_init_regs    ; 3  ; init hardware registers

         lda     #<nmi_handler  ; 2  ; install custom NMI handler
         sta     nmi_vector_l   ; 3  ;   (RESTORE key → restart)
         lda     #>nmi_handler  ; 2
         sta     nmi_vector_h   ; 3

         lda     #$1e           ; 2  ; screen memory at $1e00
         sta     screen_page    ; 3
         jsr     b_init_hw      ; 3  ; init VIC chip
         jsr     b_init_vecs    ; 3  ; init BASIC vectors
         jsr     b_init_ram     ; 3  ; init BASIC RAM
;--- END OF PATCH ---

         jsr     init_charset         ; load custom chess piece charset
         jsr     init_board           ; set up initial board position
; ---------------------------------------------------------------------
; restart_game - Reset and start/restart a game
; Resets stack, loads VIC registers, clears state, shows welcome screen,
; draws board, then enters the main game loop.
; ---------------------------------------------------------------------
restart_game:   sei
         ldx     #$ff                   ; reset stack pointer
         txs
         cli
         ldy     #$11                   ; load 16 VIC registers
@init_vic:  lda     vic_init_regs-1,y      ;   from vic_init_regs table
         sta     $8fff,y                ;   into $9000-$900f
         dey
         bne     @init_vic
         sty     $f9                    ; clear state variables (Y=0)
         sty     $21
         sty     $22
         sty     $2e
         sty     $2f
         lda     #$05                   ; foreground color = green
         sta     $20
         jsr     @welcome               ; show welcome screen + get settings
         jsr     draw_all_pieces        ; draw all pieces on board
         jsr     redraw_all_rows        ; redraw board display
         jsr     show_move_number       ; show current move number
; --- Main game loop: alternates between human and computer moves ---
@game_loop:  lda     next_color             ; whose turn is it?
         cmp     human_color            ; if next_color == human_color,
         bne     @human_turn                 ;   SARGON plays (colors are swapped)
         sei                            ; disable interrupts for engine
         jsr     sargon_moves           ; computer makes its move
         cli
         jsr     @next_move             ; flip side and update move number
         jmp     @game_loop

@human_turn:  lda     #$03                   ; human's turn
         sta     $97a7                  ; set cursor color attribute
         jsr     human_moves            ; get and validate human's move
         jsr     @next_move             ; flip side and update move number
         jmp     @game_loop

; Flip next_color (white↔black), increment move_number after white moves
@next_move:
         lda     next_color
         eor     #$80                   ; toggle color (bit 7: 0=white, $80=black)
         sta     next_color
         bne     @done                 ; if now black's turn, skip increment
         inc     move_number            ; white just moved → next full move
         jmp     show_move_number

@done:  rts

; --- Welcome screen: show logo, wait for F1 or handle screen adjustments ---
@welcome:
         jsr     init_board_display     ; set up board display area
         ldx     #<lwelcome_msg
         ldy     #>lwelcome_msg
         jsr     input_string           ; display welcome message + SARGON II logo
@title_loop:  jsr     k_getchar              ; wait for keypress
         cmp     #$85                   ; F1 pressed?
         beq     @start_game                 ;   yes → proceed to game/setup choice
         ldx     $028d                  ; check modifier keys
         cpx     #$07                   ; C=+CTRL+SHIFT?
         beq     @show_adapted                 ;   yes → show adapted-by credits
         jsr     @screen_x_offset       ; handle screen adjustment keys
         jmp     @title_loop

@show_adapted:  jsr     set_board_cursor       ; show "adapted by" credits
         ldx     #<ladapted
         ldy     #>ladapted
         jsr     $ad27                  ; print string
         jmp     @title_loop

; --- Screen centering key handlers ---
; Cursor Right → adjust horizontal screen offset ($9000)
@screen_x_offset:
         tax
         lda     #$01
         cpx     #$1d                   ; cursor right?
         bne     @screen_y_offset
         clc
         adc     $9000                  ; increment X offset
         and     #$8f                   ; mask to valid range
         sta     $9000
         rts

; Cursor Down → adjust vertical screen offset ($9001)
@screen_y_offset:
         cpx     #$11                   ; cursor down?
         bne     @screen_scan_mode
         clc
         adc     $9001                  ; increment Y offset
         and     #$3f                   ; mask to valid range
         sta     $9001
         rts

; Key $8C → toggle interlace/scan mode
@screen_scan_mode:
         cpx     #$8c
         bne     @screen_bg_color
         lda     $9000
         eor     #$80                   ; toggle bit 7 (scan mode)
         sta     $9000
         rts

; F5 ($86) → cycle background color
@screen_bg_color:
         cpx     #$86
         bne     @screen_fg_color
         lda     $900f
         clc
         adc     #$10                   ; next background color (upper nibble)
         sta     $900f
         rts

; F7 ($87) → cycle foreground color
@screen_fg_color:
         cpx     #$87
         bne     @done2
         inc     $20                    ; next foreground color
         lda     $20
         and     #$07                   ; wrap to 0-7
         sta     $20
         lda     $900f
         and     #$f8                   ; clear lower 3 bits
         ora     $20                    ; set new foreground color
         sta     $900f
@done2:  rts

; --- Game or Setup choice ---
@start_game:  jsr     clear_fill_screen
         ldx     #<lgame_or_setup       ; "GAME OR SETUP (G,S)"
         ldy     #>lgame_or_setup
         jsr     input
         cmp     #$53                   ; 'S' for Setup?
         beq     @setup_mode
         jmp     @new_game                 ; 'G' (or anything else) → new game

; --- Setup mode: edit board, then prompt for game state ---
@setup_mode:  jsr     board_editor           ; enter board editor
         jsr     clear_fill_screen
@ask_color:  ldx     #<lnextcolor           ; "NEXT COLOR (W,B)"
         ldy     #>lnextcolor
         jsr     input
         ldx     #$00                   ; $00 = white
         cmp     #'W'
         beq     @set_color
         cmp     #'B'
         bne     @ask_color                 ; invalid → ask again
         ldx     #$80                   ; $80 = black
@set_color:  stx     next_color
         lda     #$01
         sta     $1c
         ldx     #<lmovenum             ; "MOVE NUMBER?"
         ldy     #>lmovenum
         jsr     input_string
         lda     #$00
         sta     move_number
; Parse 1- or 2-digit move number from keyboard input
@get_digit:  jsr     @read_digit                 ; get first digit (or RETURN)
         cmp     #$0d                   ; skip leading RETURNs
         beq     @get_digit
         pha                            ; save first digit
         ora     #$80
         jsr     k_out_to_channel       ; echo it
         jsr     @read_digit                 ; get second digit (or RETURN)
         cmp     #$0d
         beq     @ones_digit                 ; only 1 digit → skip tens calc
         jsr     echo_char              ; echo second digit
         tax
         pla                            ; retrieve first digit
         tay
         txa
         pha                            ; save second digit
         tya                            ; A = first digit (tens)
         sec
         sbc     #$30                   ; convert ASCII → value
         asl     A                      ; ×2
         sta     move_number
         asl     A                      ; ×4
         asl     A                      ; ×8
         clc
         adc     move_number            ; ×2 + ×8 = ×10
         sta     move_number            ; tens value
@ones_digit:  pla                            ; units digit
         sec
         sbc     #$30                   ; convert ASCII → value
         clc
         adc     move_number            ; add to tens
         sta     move_number
         jmp     @choose_color                 ; skip normal init, go to color/level

; Helper: wait for a digit key (0-9) or RETURN
@read_digit:  jsr     wait_for_keypress
         cmp     #$0d                   ; RETURN?
         beq     @digit_done
         cmp     #$30                   ; < '0'?
         bcc     @read_digit                 ;   ignore
         cmp     #$3a                   ; > '9'?
         bcs     @read_digit                 ;   ignore
@digit_done:  rts

; --- Normal game init: white moves first, move 1, fresh board ---
@new_game:  lda     #$00
         sta     next_color             ; white to move
         sta     $1c
         lda     #$01
         sta     move_number            ; start at move 1
         jsr     init_board             ; set up initial piece positions

; --- Common path: choose color and difficulty level ---
@choose_color:  ldx     #<lchoose_color        ; "YOUR COLOR (W,B)"
         ldy     #>lchoose_color
         jsr     input
         ldx     #$80                   ; assume black ($80)
         cmp     #'W'
         beq     @set_human
         cmp     #'B'
         bne     @choose_color                 ; invalid → ask again
         ldx     #$00                   ; white ($00)
@set_human:  stx     human_color
@choose_level:  ldx     #<lchoose_level        ; "LEVEL (0-6)"
         ldy     #>lchoose_level
         jsr     input
         cmp     #'0'                   ; validate range 0-6
         bcc     @choose_level
         cmp     #'7'
         bcs     @choose_level
         and     #$0f                   ; convert ASCII to value
         sta     level
         lda     #$00                   ; clear move history ($12fe-$1319)
         ldx     #$1b
@clear_hist:  sta     $12fe,x
         dex
         bpl     @clear_hist
         lda     #$01                   ; set initial color/move state
         sta     next_color+1
         jmp     init_material          ; compute initial material balance

; ---------------------------------------------------------------------
; init_board - Initialize board array with starting position
; Fills entire board ($146e-$14e5) with $FF (border sentinel), then
; places pieces: white back rank + pawns, black pawns + back rank,
; and clears empty ranks 3-6.
; Board layout uses 10×12 mailbox: rank = rows 2-9, file = cols 1-8.
; Piece encoding: bit 7 = color (0=white, 1=black), bits 0-2 = type.
; ---------------------------------------------------------------------
init_board:   ldx     #$77
         lda     #$ff                   ; $FF = border/sentinel
@fill_ff:  sta     $146e,x                ; fill entire board array
         dex
         bpl     @fill_ff
         ldx     #$08                   ; 8 files (columns)
         ldy     #$00
@setup_loop:  lda     initial_pieces,y       ; white back rank piece type
         sta     $1483,y                ; rank 1: white pieces (R,N,B,Q,K,B,N,R)
         ora     #$80                   ; set color bit for black
         sta     $14c9,y                ; rank 8: black pieces
         lda     #$01                   ; pawn type = 1
         sta     $148d,y                ; rank 2: white pawns
         ora     #$80
         sta     $14bf,y                ; rank 7: black pawns
         lda     #$00                   ; empty square = 0
         sta     $1497,y                ; rank 3: empty
         sta     $14a1,y                ; rank 4: empty
         sta     $14ab,y                ; rank 5: empty
         sta     $14b5,y                ; rank 6: empty
         iny
         dex
         bne     @setup_loop
         rts

; ---------------------------------------------------------------------
; sargon_moves - Computer's move routine
; Runs the search engine (calc_move), checks for checkmate/stalemate,
; and if a valid move is found, animates it on the board. Also detects
; and displays "MATE IN N" messages when a forced mate is found.
; ---------------------------------------------------------------------
sargon_moves:
         jsr     draw_board_frame
         lda     #$02                   ; set color attribute for computer
         sta     $97a7
         jsr     calc_move              ; run the search engine
         lda     scoreH_stack           ; check result score
         bne     @not_mate                 ; scoreH != 0 → not immediate mate
         lda     scoreL_stack
         cmp     #$01                   ; scoreH=0, scoreL=1 → checkmate
         beq     @mate0
@not_mate:  jsr     check_draw             ; check for stalemate/draw
         bcs     @stalemate             ; carry set → stalemate
         jsr     push_history           ; record move in history
         ldx     #$b4                   ; play move confirmation beep
         jsr     play_beep
         jsr     show_and_check         ; animate move and check for check
         lda     scoreH_stack           ; check for mate-in-N
         cmp     #$ff                   ; $FF = negative score (forced mate)
         bne     @done                 ; no mate-in-N → done
         lda     scoreL_stack
         cmp     #$fe                   ; $FFFE = mate-in-1 (immediate)
         beq     @show_mate                 ;   → show MATE
         ldx     #<lmatein2             ; show "MATE IN N" message
         ldy     #>lmatein2
         jsr     show_msg
         lda     scoreL_stack           ; compute N from score
         eor     #$ff                   ; invert
         lsr     A                      ; /2 (plies → moves)
         adc     #$6f                   ; + ASCII offset → digit char
         sta     $1f6c                  ; patch digit into screen display
@done:  rts

@stalemate:
         ldx     #<lstalemate           ; display "STALEMATE"
         ldy     #>lstalemate
         jsr     show_msg
         jmp     @wait_restart                 ; → beep, wait, restart

@mate0:  lda     next_color             ; opponent is checkmated
         eor     #$80                   ; flip color (credits mating side)
         sta     next_color
@show_mate:  ldx     #<lmate                ; display "MATE"
         ldy     #>lmate
         jsr     show_msg
@wait_restart:  ldx     #$c8                   ; play end-of-game beep
         jsr     play_beep
         cli
         jsr     wait_for_keypress      ; wait for any key
         jmp     restart_game           ; restart the game

; ---------------------------------------------------------------------
; byte_to_bcd - Convert byte to two ASCII decimal digits
; Input:  A = value to convert, X = buffer index (tens digit position)
; Output: $033c+x = tens digit (ASCII), $033c+x-1 = units (OR'd with $40)
; Used to format move coordinates for display.
; ---------------------------------------------------------------------
byte_to_bcd:   tay
         lda     #$2f                   ; $2f = '0'-1 (pre-decremented)
         sta     $033c,x                ; init tens digit position
         tya
@div10:  cmp     #$0a                   ; value >= 10?
         bcc     @store_ones                 ;   no → done with tens
         inc     $033c,x                ; tens digit++
         sec
         sbc     #$0a                   ; subtract 10
         bne     @div10                 ; repeat if still >= 10
@store_ones:  dex
         ora     #$40                   ; units digit: OR with $40 for display
         sta     $033c,x                ; store units digit
         rts

; ---------------------------------------------------------------------
; parse_algebraic - Parse algebraic notation (e.g. "E2") from input buffer
; Input:  X = index into input buffer $033c (points to rank digit)
; Output: $07+x = board square index, carry clear on success
;         Carry set on invalid input (rank not 1-8 or file not A-H)
; Square formula: (rank+1)*10 + file (10×12 mailbox indexing)
; Called twice per move: once for source square, once for destination.
; ---------------------------------------------------------------------
parse_algebraic:   lda     $033c,x
         and     #$7f                   ; strip high bit
         cmp     #$31                   ; rank < '1'?
         bcc     @invalid                 ;   invalid
         cmp     #$39                   ; rank > '8'?
         bcs     @invalid                 ;   invalid
         and     #$0f                   ; convert ASCII → 1-8
         clc
         adc     #$01                   ; rank+1
         asl     A                      ; ×2
         sta     $0341                  ; temp
         asl     A                      ; ×4
         asl     A                      ; ×8
         adc     $0341                  ; ×2 + ×8 = ×10 → (rank+1)*10
         sta     $0341
         dex
         lda     $033c,x                ; read file letter
         and     #$7f                   ; strip high bit
         cmp     #$41                   ; file < 'A'?
         bcc     @invalid                 ;   invalid
         cmp     #$49                   ; file > 'H'?
         bcs     @invalid                 ;   invalid
         and     #$0f                   ; convert ASCII → 1-8
         clc
         adc     $0341                  ; + (rank+1)*10 → square index
         sta     $07,x                  ; store result
         dex                            ; advance buffer index
         dex                            ;   (skip past the 2 chars consumed)
         rts                            ; carry clear = success

@invalid:  sec                            ; carry set = invalid input
         rts

; ---------------------------------------------------------------------
; human_moves - Handle the human player's turn
; Generates all legal moves, then loops: get input, parse algebraic
; notation for both from/to squares, validate against legal move list.
; If valid, animates the move. If invalid, shows error and retries.
; Move list stored at $1001 (from-squares) / $1010 (to-squares).
; ---------------------------------------------------------------------
human_moves:
         lda     #$01                   ; move list base address low
         sta     $8e                    ;   → $1001
         lda     #$10                   ; move list base address high
         sta     $8f                    ;   → $1010
         jsr     gen_all_moves          ; generate all legal moves
@input_loop:  jsr     get_move_input         ; prompt and read move string
         ldx     #$04                   ; start parsing at buffer[4]
@parse_loop:  jsr     parse_algebraic        ; parse rank+file → square index
         bcs     @bad_move                 ; parse error → invalid move
         bpl     @parse_loop                 ; X >= 0 → parse second square
         jsr     validate_move          ; check move is in legal move list
         bcs     @bad_move                 ; not found → invalid move
         jsr     push_history           ; record move in history
         jsr     draw_board_frame       ; redraw board frame
         jmp     show_and_check         ; animate move, check for check

@bad_move:  ldx     #<linvalid_move        ; display "INVALID MOVE"
         ldy     #>linvalid_move
         jsr     show_msg
         ldx     #$aa                   ; play error beep
         jsr     play_beep
         jmp     @input_loop                 ; retry

; =====================================================================
; MOVE DISPLAY AND VALIDATION
; Move formatting, display, special move handling (castling/en passant),
; move history, draw detection, and move validation routines.
; =====================================================================

; ---------------------------------------------------------------------
; board_editor - Manual board setup mode
; Iterates through squares $15-$62. Highlights current square, waits
; for input. RETURN confirms setup. Cursor keys navigate. Letter keys
; (P,N,B,R,Q,K) set piece type, then prompts W/B for color and K/Q
; for rook moved-status. Piece byte: bit7=color, bit6=moved, bits2-0=type.
; ---------------------------------------------------------------------
board_editor:   jsr     wait_for_keypress
         jsr     draw_all_pieces
         ldx     #$15               ; start at first board square
@set_sq:  stx     $07                ; set current square
@edit_loop:  jsr     highlight_square
         jsr     k_getchar
         beq     @edit_loop             ; wait for keypress
         cmp     #$0d               ; RETURN?
         bne     @move_cursor
         jsr     init_material      ; recalculate material totals
         jsr     clear_screen
         rts                        ; done - confirm setup

@move_cursor:  jsr     handle_cursor      ; check if cursor key
         cpy     #$ff               ; was it a cursor key?
         bne     @set_sq             ; yes - moved to new square
         ldx     #$06               ; check piece letter keys P,N,B,R,Q,K
@find_piece:  cmp     lpnbrqk,x
         beq     @set_piece             ; found matching piece type
         dex
         bne     @find_piece
         txa                        ; X=0 means empty square
         beq     @place_piece
@set_piece:  stx     $aa                ; save piece type (1-6)
         jsr     wait_for_keypress  ; get color: W or B
         ldy     #$00               ; Y=$00 for white
         cmp     #$57               ; 'W'?
         beq     @set_color
         ldy     #$80               ; Y=$80 for black (bit 7)
@set_color:  tya
         ora     $aa                ; combine color with piece type
         sta     $aa
         jsr     wait_for_keypress  ; get moved status: K or Q side
         ldy     $aa
         and     #$01               ; bit 0 of input -> bit 6 (moved flag)
         lsr     A                  ; shift bit 0 into bit 6 via
         ror     A                  ;   LSR then two RORs:
         ror     A                  ;   bit0 -> C -> bit7 -> bit6
         sta     $aa
         tya
         ora     $aa                ; combine all: color|moved|type
@place_piece:  ldx     $07
         sta     $146e,x            ; store piece on board
         sta     $aa
         jsr     decode_piece_gfx
         jsr     draw_piece         ; redraw the square
         ldx     $07
         jmp     @edit_loop

; ---------------------------------------------------------------------
; show_and_check - Display move notation and handle special moves
; Calls show_move_check for notation+check detection, then executes
; the main piece move. Also handles castling (moves the rook) and
; en passant (removes the captured pawn).
; $1332 move flags: bit 7 = castling, bit 6 = en passant.
; ---------------------------------------------------------------------
show_and_check:   jsr     show_move_check
         lda     $0b                ; from-square
         sta     $07
         lda     $0c                ; to-square
         sta     $08
         jsr     exec_board_move    ; move the piece on screen
         bit     $1332              ; check special move flags
         bmi     @castling             ; bit 7 set = castling
         bvc     return_no_check    ; bit 6 clear = normal move, done
         lda     #$0a               ; --- en passant handling ---
         bit     next_color         ; determine pawn capture direction
         bmi     @ep_black             ; black moves down (+10)
         lda     #$f6               ; white moves up (-10)
@ep_black:  clc
         adc     $08                ; captured pawn is adjacent to to-sq
         sta     $08
         bne     @do_rook             ; remove captured pawn from board
@castling:  lda     $08                ; --- castling handling ---
         sec                        ; determine king direction
         sbc     $07
         cmp     #$02               ; king moved right 2 = kingside
         beq     @kingside
         inc     $08                ; queenside: rook from col 1
         asl     A                  ;   (adjust from/to for rook)
         bne     @rook_from
@kingside:  dec     $08                ; kingside: rook from col 8
         inc     $07
@rook_from:  clc
         adc     $07                ; calculate rook destination
@do_rook:  sta     $07
         jmp     exec_board_move    ; move the rook / remove pawn

; ---------------------------------------------------------------------
; format_move_text - Format move into displayable text
; Normal moves: from/to in algebraic notation with '-' or 'X' (capture).
; Castling: "O-O" or "O-O-O". En passant: "PXPEP".
; $1328 = captured piece (non-zero = capture). Result in $033c-$0341.
; ---------------------------------------------------------------------
format_move_text:   bit     $1332          ; check special move flags
         bmi     @castling                 ; bit 7 = castling
         bvs     @en_passant                 ; bit 6 = en passant
         ldx     #$01                   ; --- normal move ---
         lda     $0b                    ; convert from-square to notation
         jsr     byte_to_bcd
         ldx     #$04
         lda     $0c                    ; convert to-square to notation
         jsr     byte_to_bcd
         ldx     #$2d                   ; '-' separator (non-capture)
         lda     $1328                  ; captured piece?
         beq     @set_sep
         ldx     #$58                   ; 'X' separator (capture)
@set_sep:  stx     $033e                  ; store separator character
         ldx     #$3c                   ; point to $033c buffer
         ldy     #$03
         bne     @print_str

@en_passant:  ldx     #<lpxpep               ; en passant: "PXPEP"
         ldy     #>lpxpep
         bne     @print_str

@castling:  lda     $0c                    ; --- castling ---
         sec
         sbc     $0b                    ; to - from
         cmp     #$02                   ; +2 = kingside
         beq     @kingside
         ldx     #<looo                 ; queenside: "O-O-O"
         ldy     #>looo
         bne     @print_str

@kingside:  ldx     #<loo                  ; kingside: "O-O"
         ldy     #>loo
@print_str:  lda     #$00
         sta     $0341                  ; null-terminate output string
return_no_check:   rts                    ; also used as "no check" return

; ---------------------------------------------------------------------
; show_move_check - Format move, display it, and check for check
; ---------------------------------------------------------------------
show_move_check:   jsr     format_move_text
         jsr     display_move_text
; ---------------------------------------------------------------------
; check_opponent - Check if opponent's king is in check
; Tests the opposite color from next_color (XOR $80).
; ---------------------------------------------------------------------
check_opponent:   lda     next_color
         eor     #$80               ; switch to opponent's color
         jsr     check_color        ; is that king in check?
         bcc     return_no_check    ; no - return
         ldx     #<lcheck           ; yes - display "CHECK"
         ldy     #>lcheck
         jmp     show_msg

; ---------------------------------------------------------------------
; show_move_number - Display current move number (e.g., "12.")
; Converts move_number to two ASCII digits, suppresses leading zero.
; ---------------------------------------------------------------------
show_move_number:   ldx     #$30           ; X = tens digit (ASCII '0')
         lda     move_number
@div10:  cmp     #$0a               ; subtract 10s to get tens digit
         bcc     @format
         inx
         sec
         sbc     #$0a
         bne     @div10
@format:  clc
         adc     #$30               ; ones digit -> ASCII
         sta     $033d
         txa                        ; tens digit
         cmp     #$40               ; >= '@' (overflow)?
         bcs     @blank
         cmp     #$30               ; still '0' (leading zero)?
         bne     @store_tens
@blank:  lda     #$20               ; suppress: replace with space
@store_tens:  sta     $033c
         lda     #$00
         sta     $033e              ; null-terminate
         ldx     #$3c
         ldy     #$03
         jmp     display_move_text

; ---------------------------------------------------------------------
; show_computer_move - Display the computer's move and check for check
; Clears the input area, formats the move notation, prints it, then
; checks if the move gives check to the opponent.
; ---------------------------------------------------------------------
show_computer_move:   jsr     clear_input_area
         lda     #$00
         sta     $f9                ; clear display state
         sta     $00
         jsr     format_move_text
         jsr     print_move_chars   ; print move notation to screen
         lda     #$00
         sta     $f9                ; reset display state
         sta     $00
         jmp     check_opponent     ; check if move gives check

; ---------------------------------------------------------------------
; print_move_chars - Print string to move notation area
; X/Y = pointer to null-terminated string. Each character is fed to
; handle_char_display for rendering in the move display area.
; ---------------------------------------------------------------------
print_move_chars:   stx     $05
         sty     $06
         ldy     #$00
@print_loop:  lda     ($05),y            ; get next character
         beq     @done             ; null terminator - done
         sty     $a3                ; save index
         jsr     handle_char_display
         ldy     $a3                ; restore index
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

; ---------------------------------------------------------------------
; player_hint - Handle '?' key: show computer's expected response
; If search depth >= 2 plies, retrieves the computer's predicted reply
; ($9f=from, $b4=to) and previews it on the board.
; ---------------------------------------------------------------------
player_hint:   ldy     level+1
         cpy     #$02               ; at least 2 plies calculated?
         bcc     @done             ; no - can't hint
         lda     $9f                ; predicted from-square
         sta     $07
         lda     $b4                ; predicted to-square
         sta     $0a
         jsr     validate_move      ; validate and make the hint move
         bcs     @done             ; invalid - skip
         jsr     unmake_move        ; undo it (was just a preview)
         jsr     show_computer_move ; display the hint notation
@done:  jmp     poll_keyboard      ; return to input loop

; ---------------------------------------------------------------------
; push_history - Push current move into move history buffer
; Shifts existing entries ($12fe-$131b) by 4 bytes to make room, then
; stores from ($0b), to ($0c), captured piece ($1328), flags ($1332).
; ---------------------------------------------------------------------
push_history:   ldx     #$17
@shift_loop:  lda     $12fe,x            ; shift history buffer up by 4 bytes
         sta     $1302,x
         dex
         bpl     @shift_loop
         lda     $0b                ; store from-square
         sta     $12fe
         lda     $0c                ; store to-square
         sta     $12ff
         lda     $1328              ; store captured piece
         sta     $1300
         lda     $1332              ; store move flags
         sta     $1301
         rts

; ---------------------------------------------------------------------
; check_draw - Check for draw conditions (repetition / stalemate)
; 1. If computer has material advantage, don't accept draws.
; 2. Compare last move + proposed move against 4-half-moves-ago history.
;    If they match, a repetition is detected.
; 3. On repetition: evaluate position to decide whether to accept the
;    repetition or try an alternative move from the move list.
; Returns: carry set = stalemate (no legal moves), carry clear = ok.
; ---------------------------------------------------------------------
check_draw:   lda     $6a            ; material balance
         bit     human_color
         bmi     @check_val             ; if computer is black, negate
         eor     #$ff               ;   (two's complement negation)
         clc
         adc     #$01
@check_val:  clc
         adc     #$80               ; shift to unsigned: $80 = even
         cmp     #$81               ; computer ahead in material?
         bcs     @no_draw             ; yes - don't accept draw
         lda     $12fe              ; --- repetition detection ---
         cmp     $130e              ; compare last from vs 4-ago from
         bne     @no_draw
         lda     $12ff              ; compare last to vs 4-ago to
         cmp     $130f
         bne     @no_draw
         lda     $1001              ; compare proposed from vs 4-ago from
         cmp     $130a
         bne     @no_draw
         lda     $1002              ; compare proposed to vs 4-ago to
         cmp     $130b
         bne     @no_draw
         lda     #$02               ; repetition detected - try alt move
         sta     $8d                ;   use move list entry #2
         jsr     try_move
         bcs     @no_draw             ; alt move illegal - fall through
         jsr     evaluate_position  ; evaluate the alternative
         lda     $1328              ; captured piece type
         and     #$07
         tax
         lda     piece_values,x     ; get its material value
         asl     A                  ; double it
         sec
         sbc     $63                ; compare vs opening book eval
         bmi     @undo             ; worse - undo and reject
         lda     $1003              ; accept alt: replace best move
         sta     $1001
         lda     $1004
         sta     $1002
         clc                        ; carry clear = legal/ok
         rts

@undo:  jsr     unmake_move        ; undo the alternative
@no_draw:  lda     #$00               ; try the original best move
         sta     $8d
         beq     try_move           ; (always branches)

; ---------------------------------------------------------------------
; validate_move - Validate a user's move
; Searches the move list ($1001+) for a from/to match ($07/$0a).
; If found, stores index in $9c/$8d and calls try_move.
; Returns: carry set = invalid/illegal, carry clear = legal.
; ---------------------------------------------------------------------
validate_move:   ldx     #$fe
@scan_loop:  inx                        ; advance to next move pair
         inx
         lda     $1001,x            ; from-square in move list
         beq     return_illegal     ; end of list - not found
         cmp     $07                ; match from-square?
         bne     @scan_loop
         lda     $1002,x            ; match to-square?
         cmp     $0a
         bne     @scan_loop
         stx     $9c                ; save move index
         stx     $8d
; ---------------------------------------------------------------------
; try_move - Attempt a move and check legality
; Makes the move, then checks if own king is in check.
; If in check, unmakes and returns carry set (illegal).
; ---------------------------------------------------------------------
try_move:   jsr     make_move
         jsr     in_check           ; own king in check after move?
         bcc     return_legal       ; no - move is legal
         jsr     unmake_move        ; yes - undo it
return_illegal:   sec                ; carry set = illegal
return_legal:   rts                ; carry clear = legal (or as set above)

; =====================================================================
; MOVE GENERATION
; =====================================================================

; ---------------------------------------------------------------------
; gen_piece_moves - Generate all pseudo-legal moves for one piece
; Input: $07=square, $0d=piece type (1-6), $13=full piece byte
; Uses direction tables to iterate through possible moves.
; Sliding pieces (bishop/rook/queen) follow rays; knight/king step once.
; Pawns have special handling for pushes, captures, and en passant.
; Moves are appended to the move list at ($8b),y.
; ---------------------------------------------------------------------
gen_piece_moves:   ldx     $0d
         lda     move_dir_count,x   ; number of directions for this piece
         sta     $10                ; $10 = remaining direction counter
         lda     move_dir_start,x   ; starting index into move_directions
         cmp     #$10               ; $10 = pawn direction start
         bne     @set_dir             ; not a pawn? skip color adjust
         bit     $13                ; check piece color (bit 7)
         bpl     @set_dir             ; white pawn? keep start index
         clc
         adc     #$04               ; black pawn: offset by +4 directions
@set_dir:  sta     $0f                ; $0f = current direction index
@dir_loop:  ldx     $0f                ; --- begin direction loop ---
         lda     move_directions,x  ; get direction offset
         sta     $11                ; $11 = current step offset
         ldx     $07                ; x = from-square
@ray_loop:  clc                        ; --- step along ray ---
         txa
         adc     $11                ; x = next square in this direction
         tax
         lda     $146e,x            ; read board contents at target
         beq     @empty_sq             ; empty square - can move here
         cmp     #$ff               ; border sentinel?
         beq     @next_dir             ; yes - end this direction
         eor     $13                ; compare colors (bit 7 xor)
         bpl     @next_dir             ; same color - blocked, next dir
         eor     $13                ; restore piece byte (enemy capture)
@empty_sq:  sta     $0e                ; $0e = captured piece (0 if empty)
         lda     $0d
         cmp     #$01               ; is this a pawn?
         beq     @pawn_move             ; yes - special pawn logic
         jsr     add_move           ; add move (from=$07, to=x)
         lda     $0e
         bne     @next_dir             ; captured a piece - can't continue
         lda     $0d
         cmp     #$06               ; king?
         beq     @next_dir             ; king moves one step only
         cmp     #$03               ; sliding piece (bishop=3,rook=4,queen=5)?
         bcs     @ray_loop             ; yes - continue along ray
@next_dir:  inc     $0f                ; advance to next direction
         dec     $10                ; decrement remaining count
         bne     @dir_loop             ; more directions? loop
         rts

; --- pawn move logic ---
; Directions at count >= 3 are captures; count < 3 are pushes.
@pawn_move:  lda     $10                ; remaining direction count
         cmp     #$03               ; count >= 3?
         bcs     @pawn_capture             ; yes - this is a capture direction
         ; --- pawn push (count < 3) ---
         lda     $0e                ; target square contents
         bne     @pawn_done             ; not empty? can't push - done
         jsr     add_move           ; empty - add single push
         bit     $13                ; check bit 6 (has piece moved?)
         bvs     @pawn_done             ; bit 6 set = already moved, no double push
         dec     $10                ; consume one more direction
         bne     @ray_loop             ; continue to try double push
@pawn_done:  rts

         ; --- pawn capture (count >= 3) ---
@pawn_capture:  lda     $0e                ; target square contents
         beq     @try_ep             ; empty - check en passant
         jsr     add_move           ; enemy piece present - add capture
         jmp     @next_dir             ; next direction

@try_ep:  jsr     check_en_passant   ; empty diagonal - try en passant
         jmp     @next_dir

; ---------------------------------------------------------------------
; add_move - Append a from/to move pair to the move list
; Stores from-square ($07) and to-square (x) at ($8b),y; advances y+2.
; ---------------------------------------------------------------------
add_move:   lda     $07                ; from-square
         sta     ($8b),y
         iny
         txa                        ; to-square
         sta     ($8b),y
         iny
         rts

; ---------------------------------------------------------------------
; check_en_passant - Test if pawn can capture en passant
; Conditions: pawn on rank 5, last move was 2-square pawn push,
; the captured pawn is adjacent, and target is ±10 from capturer.
; If valid, adds the en passant capture via add_move.
; ---------------------------------------------------------------------
check_en_passant:   lda     $07        ; capturing pawn's square
         bit     $13                ; check color (bit 7)
         bpl     @check_rank             ; white - no adjustment
         clc
         adc     #$0a               ; black: offset by +10 for rank check
@check_rank:  cmp     #$3d               ; rank 5 lower bound
         bcc     @no_ep             ; below rank 5? fail
         cmp     #$45               ; rank 5 upper bound +1
         bcs     @no_ep             ; above rank 5? fail
         ; --- check last move was a 2-square pawn push ---
         lda     $0b                ; last move from-square
         sec
         sbc     $0c                ; minus last move to-square
         cmp     #$14               ; +20 = 2 ranks forward (white push)
         beq     @save_to
         cmp     #$ec               ; -20 = 2 ranks forward (black push)
         bne     @no_ep             ; not a double push? fail
         ; --- verify the captured piece is a pawn ---
@save_to:  stx     $08                ; save en passant target square
         ldx     $0c                ; x = last move destination (enemy pawn)
         lda     $146e,x            ; read piece at that square
         and     #$07               ; mask to piece type
         cmp     #$01               ; is it a pawn?
         bne     @no_ep             ; no - fail
         ; --- check enemy pawn is adjacent (±10 from capturer) ---
         txa                        ; a = enemy pawn square
         ldx     $08                ; restore target square
         sec
         sbc     $08                ; difference from target
         cmp     #$0a               ; +10 (one rank)?
         beq     @store_ep
         cmp     #$f6               ; -10 (one rank)?
         bne     @no_ep             ; no - fail
@store_ep:  jmp     add_move           ; all conditions met - add move

@no_ep:  rts

; ---------------------------------------------------------------------
; gen_all_moves - Generate all pseudo-legal moves for current side
; Sets up move list pointers, checks castling, then iterates all
; board squares ($15-$62). For each friendly piece, calls
; gen_piece_moves. Terminates list with $00 and updates allocation ptr.
; ---------------------------------------------------------------------
gen_all_moves:   ldy     next_color+1   ; ply depth index
         lda     $8e                ; allocation pointer lo
         sta     $1459,y            ; save per-ply move list base lo
         sta     $8b                ; set current list base lo
         lda     $8f                ; allocation pointer hi
         sta     $1463,y            ; save per-ply move list base hi
         sta     $8c                ; set current list base hi
         lda     #$00
         sta     $133b,y            ; reset per-ply move index
         sta     $8d                ; reset current move index
         tay                        ; y=0 (move list write offset)
         jsr     @try_castle             ; check castling availability
         ; --- iterate all board squares ---
         ldx     #$15               ; first board square
         stx     $07
@piece_loop:  lda     $146e,x            ; read board contents
         beq     @next_piece             ; empty square - skip
         cmp     #$ff
         beq     @next_piece             ; border - skip
         eor     next_color         ; compare piece color to side-to-move
         bmi     @next_piece             ; enemy piece - skip
         eor     next_color         ; restore piece byte
         sta     $13                ; $13 = full piece byte
         and     #$07               ; mask to piece type
         sta     $0d                ; $0d = piece type (1-6)
         jsr     gen_piece_moves
@next_piece:  inc     $07                ; next square
         ldx     $07
         cpx     #$63               ; past last board square?
         bcc     @piece_loop             ; no - continue
         ; --- terminate move list and update allocation pointer ---
         lda     #$00
         sta     $1d
         sta     ($8b),y            ; write $00 terminator
         iny
         tya                        ; y = bytes written
         clc
         adc     $8e                ; advance allocation pointer
         sta     $8e
         lda     $8f
         adc     #$00
         sta     $8f
         rts

         ; --- castling check subroutine ---
         ; Checks both kingside and queenside castling.
         ; $09=step direction (+1 or -1), $12=squares to verify.
@try_castle:  ldx     $6c                ; white king position
         lda     next_color
         bpl     @check_moved             ; white to move? use $6c
         ldx     $6d                ; black king position
@check_moved:  lda     $146e,x            ; king's piece byte
         and     #$40               ; bit 6 = has moved flag
         bne     @castle_done             ; king has moved - no castling
         lda     $146e,x
         sta     $13                ; save king's piece byte
         stx     $07                ; $07 = king's square
         jsr     is_king_attacked   ; is king currently in check?
         bcs     @castle_done             ; in check - can't castle
         ; --- try kingside first (rook at king+3, step toward king=-1) ---
         lda     #$02               ; 2 squares to verify (f&g files)
         sta     $12
         lda     #$ff               ; step = -1 (from rook toward king)
         sta     $09
         lda     #$03               ; offset +3: king to h-side rook
@castle_dir:  clc
         adc     $07                ; x = rook's expected square
         tax
         lda     $146e,x            ; read piece at rook square
         and     #$7f               ; strip color bit
         cmp     #$04               ; unmoved rook? (type 4, bit 6 clear)
         bne     @try_other             ; no rook or rook has moved - skip
         ; --- verify squares between king and rook are empty ---
@check_path:  txa
         clc
         adc     $09                ; step toward king
         tax
         lda     $146e,x            ; square contents
         bne     @try_other             ; not empty - can't castle
         lda     $12
         cmp     #$03               ; queenside extra square (b-file)?
         beq     @path_clear             ; skip attack check for far square
         jsr     is_king_attacked   ; king passes through this square?
         bcs     @try_other             ; attacked - can't castle
@path_clear:  dec     $12                ; more squares to check?
         bne     @check_path             ; yes - continue
         ; --- castling is legal - add the king's move ---
         txa                        ; x = king's destination
         sec
         sbc     $09                ; back up one step (king lands here)
         tax
         jsr     add_move           ; add castling move
         ; --- now try queenside (rook at king-4, step toward king=+1) ---
@try_other:  lda     $09
         bpl     @castle_done             ; already did queenside? done
         ldx     $07                ; restore king square
         lda     #$03               ; 3 squares to verify (b,c,d files)
         sta     $12
         lda     #$01               ; step = +1 (from rook toward king)
         sta     $09
         lda     #$fc               ; offset -4: king to a-side rook
         jmp     @castle_dir

@castle_done:  rts

; ---------------------------------------------------------------------
; is_king_attacked - Check if king is under attack (in check)
; Input: x=king square, $13=king's piece byte (for color)
; Output: carry set=attacked, carry clear=safe. Restores x=$08.
; Walks all 16 directions from king using move_directions table.
; For each direction, checks if an enemy piece that could attack
; from that direction actually exists there.
; Direction mapping: 0-3=diagonal, 4-7=orthogonal, 8-15=knight.
; $0e tracks distance (starts at $fe; $ff=adjacent, bit 7 set).
; ---------------------------------------------------------------------
is_king_attacked:   stx     $08        ; save king square
         lda     #$10               ; 16 directions to check
         sta     $10                ; $10 = direction counter (counts down)
         lda     #$00
         sta     $0f                ; $0f = current direction index
         ; --- direction loop ---
@dir_loop:  lda     #$fe               ; distance starts at -2
         sta     $0e                ; (will be $ff=adjacent after first inc)
         ldx     $0f
         lda     move_directions,x  ; get direction offset
         sta     $11
         ldx     $08                ; start from king square
         ; --- walk along this direction ---
@ray_step:  inc     $0e                ; advance distance counter
         clc
         txa
         adc     $11                ; step to next square
         tax
         lda     $146e,x            ; read board
         beq     @empty_check             ; empty - keep walking (if sliding)
         cmp     #$ff               ; border?
         beq     @next_dir             ; yes - next direction
         bne     @found_piece             ; piece found - identify it

@empty_check:  lda     $10                ; empty square: can we slide?
         cmp     #$09               ; directions 0-7 (counter >= 9) are sliding
         bcs     @ray_step             ; yes - continue walking
         ; --- advance to next direction ---
@next_dir:  inc     $0f
         dec     $10
         bne     @dir_loop             ; more directions? loop
         clc                        ; all clear - king not attacked
         bcc     @restore_x

@attacked:  sec                        ; king IS attacked
@restore_x:  ldx     $08                ; restore king square
         rts

         ; --- piece found: is it an enemy that attacks from here? ---
@found_piece:  eor     $13                ; compare colors
         bpl     @next_dir             ; friendly piece - no threat, next dir
         eor     $13                ; restore piece byte
         and     #$07               ; extract piece type
         sta     $0d
         lda     $10                ; direction counter
         cmp     #$09               ; counter >= 9? (directions 0-7: sliding)
         bcc     @check_knight             ; counter < 9: knight directions (8-15)
         ; --- sliding directions (diagonal 0-3, orthogonal 4-7) ---
         lda     $0d
         cmp     #$05               ; queen?
         beq     @attacked             ; queen attacks on any sliding dir
         bit     $0e                ; check distance (bit 7 set = adjacent)
         bpl     @check_type             ; not adjacent - skip king check
         cmp     #$06               ; king? (attacks at distance 1 only)
         beq     @attacked             ; adjacent king - attacked!
@check_type:  lda     $10
         cmp     #$0d               ; counter >= 13? (directions 0-3: diagonals)
         bcc     @check_rook             ; counter < 13: orthogonal dirs (4-7)
         ; --- diagonal directions (counter >= 13) ---
         lda     $0d
         cmp     #$03               ; bishop?
         beq     @attacked             ; bishop attacks on diagonal
         bit     $0e                ; adjacent? (for pawn check)
         bpl     @next_dir             ; not adjacent - pawn can't reach
         cmp     #$01               ; pawn?
         bne     @next_dir             ; not a pawn - no threat
         ; --- pawn attack direction check (depends on color) ---
         lda     $13                ; king's color
         bmi     @pawn_bk             ; black king? check black's pawn dirs
         ; white king: pawns attack from dirs 14-15 (counter >= 15)
         lda     $10
         cmp     #$0f               ; counter 15-16 = directions 0-1 diag
         bcc     @next_dir             ; wrong diagonal for white pawn attack
         jmp     @attacked             ; pawn attacks white king!

         ; black king: pawns attack from dirs 12-13 (counter < 15)
@pawn_bk:  lda     $10
         cmp     #$0f
         bcs     @next_dir             ; wrong diagonal for black pawn attack
         jmp     @attacked             ; pawn attacks black king!

         ; --- orthogonal directions (counter 5-8, i.e. dirs 4-7) ---
@check_rook:  lda     $0d
         cmp     #$04               ; rook?
         bne     @next_dir             ; not rook - no threat on orthogonal
         jmp     @attacked             ; rook attacks on orthogonal!

         ; --- knight directions (counter 1-8, i.e. dirs 8-15) ---
@check_knight:  lda     $0d
         cmp     #$02               ; knight?
         bne     @next_dir             ; not knight - no threat
         beq     @attacked             ; knight attacks from L-shape!

; ============================================================
; POSITION EVALUATION
; ============================================================

; --- eval_mobility ---
; Evaluates piece mobility and builds attack/defense lists.
; Iterates board squares $15-$62. For each piece, walks its
; movement rays using direction tables. Accumulates centrality
; score in $68. Builds attacker list (grows up from 0, $6f=next)
; and defender list (grows down from $7f, $6e=next) at $1346
; (target squares) and $13c6 (source squares, bit 7=color).
eval_mobility:   lda     #$00
         sta     $6f                ; reset attacker list index
         lda     #$7f
         sta     $6e                ; reset defender list index
         ldx     #$15               ; start at first board square
         stx     $07                ; $07 = current square
@piece_loop:  lda     $146e,x            ; get piece at square
         beq     @next_sq             ; empty square - skip
         cmp     #$ff
         beq     @next_sq             ; border sentinel - skip
         sta     $13                ; $13 = piece (with color in bit 7)
         and     #$07
         sta     $0d                ; $0d = piece type (1-6)
         jsr     @scan_piece             ; evaluate this piece's mobility
@next_sq:  inc     $07                ; next square
         ldx     $07
         cpx     #$63               ; past last board square?
         bcc     @piece_loop
         rts

         ; --- walk movement rays for piece at $07 ---
@scan_piece:  ldx     $0d                ; piece type index
         lda     move_dir_count,x   ; number of directions
         sta     $10                ; $10 = direction counter
         lda     move_dir_start,x   ; first direction index
         cmp     #$10               ; pawn? (dir start = $10)
         bne     @set_start
         dec     $10                ; pawns: reduce count by 2
         dec     $10                ;   (only diagonal dirs for attack)
         bit     $13                ; check piece color
         bpl     @set_start             ; white pawn - use default start
         clc
         adc     #$04               ; black pawn - offset to black dirs
@set_start:  sta     $0f                ; $0f = current direction index
@dir_loop:  ldx     $0f
         lda     move_directions,x  ; get direction delta
         sta     $11                ; $11 = step delta for this ray
         ldx     $07                ; X = current square
         lda     #$00
         sta     $12                ; $12 = ray flags (bit5=attacked, bit6=blocked, bit0=moved, bit7=xray)
@ray_loop:  clc                        ; --- step along ray ---
         txa
         adc     $11                ; add direction delta
         tax                        ; X = target square
         lda     $146e,x            ; get piece at target
         cmp     #$ff               ; off board?
         bne     @found
@next_dir:  inc     $0f                ; --- next direction ---
         dec     $10
         bne     @dir_loop
         rts

         ; --- found a piece (or empty) on ray ---
@found:  sta     $14                ; $14 = piece at target (with color)
         and     #$07
         sta     $0e                ; $0e = target piece type
         bit     $12                ; already encountered a piece on this ray?
         bvs     @xray             ; yes - handle X-ray attack
         lda     centrality,x       ; positional score for this square
         lsr     A                  ; halve it
         bit     $13                ; check moving piece color
         bpl     @adjust_mob             ; white: add centrality
         eor     #$ff               ; black: negate centrality
         clc
         adc     #$01
@adjust_mob:  clc
         adc     $68                ; accumulate in positional score
         sta     $68
         lda     $14                ; target piece
         beq     @check_slide             ; empty square - check if sliding piece continues
         eor     $13                ; compare colors (bit 7)
         bpl     @friendly          ; same color - it's a defender
         ; --- enemy piece found: add to attacker list ---
         lda     $0e
         cmp     #$06               ; target is enemy king?
         bne     @own_piece
         lda     #$01
         sta     $69                ; $69 = flag: attacking enemy king
@own_piece:  lda     $12
         and     #$01               ; already moved on this ray?
         bne     @set_flags
         ora     #$40               ; bit 6: first piece encountered
@set_flags:  ora     #$20               ; bit 5: has attacked
         sta     $12
         ldy     $6e                ; defender list pointer (grows down)
         dec     $6e
         jmp     @store_atk             ; store in list

         ; --- X-ray: second piece found behind first ---
@xray:  lda     $0e
         beq     @ray_loop             ; empty - keep walking
         cmp     #$01
         beq     @next_dir             ; pawn behind - stop this ray
         lda     $14
         eor     $13                ; compare colors
         bpl     @next_dir             ; friendly behind - stop
         txa                        ; enemy behind enemy: X-ray attack
         ora     #$80               ; set bit 7 = X-ray flag on square
         tax
         lda     $12
         and     #$bf               ; clear bit 6 (blocked flag)
         jmp     @set_flags             ; add to attacker list

         ; --- friendly piece found: add to defender list ---
@friendly:  lda     $12
         ora     #$01               ; bit 0: moved flag
         sta     $12
         ldy     $6f                ; attacker list pointer (grows up)
         inc     $6f
@store_atk:  txa                        ; --- store entry in list ---
         sta     $1346,y            ; target square
         lda     $12
         and     #$80               ; keep X-ray flag
         ora     $07                ; combine with source square
         sta     $13c6,y            ; source square + flags
         ; --- check if piece continues along ray ---
@check_slide:  lda     $0d                ; moving piece type
         cmp     #$03               ; sliding piece? (bishop+)
         bcs     @check_king
@jmp_next_dir:  jmp     @next_dir             ; pawn/knight: next direction

         ; --- sliding piece ray continuation logic ---
@check_king:  cmp     #$06               ; king?
         beq     @jmp_next_dir             ; king stops after one step
         bit     $12                ; already blocked on this ray?
         bvc     @check_blocked             ; no - check X-ray possibilities
@jmp_ray:  jmp     @ray_loop             ; continue walking ray

@check_blocked:  lda     $12
         and     #$20               ; has attacked on this ray?
         bne     @jmp_next_dir             ; yes - stop (already found enemy)
         lda     $0e                ; target piece type
         beq     @jmp_ray             ; empty - keep sliding
         ; --- X-ray compatibility checks ---
         ; Can the moving piece attack through the blocking piece?
         lda     $0d
         cmp     #$04               ; rook?
         bne     @check_bishop
         lda     $0e                ; piece blocking the ray
         cmp     #$04               ; rook behind rook?
         beq     @jmp_ray             ; yes - continue (rook X-ray)
         cmp     #$05               ; queen behind rook?
         bne     @jmp_next_dir             ; no match - stop
@set_xray:  lda     $12                ; set X-ray attack flag
         ora     #$80
         sta     $12
         jmp     @ray_loop             ; continue ray with X-ray

@check_bishop:  cmp     #$03               ; bishop?
         bne     @check_q_r
         lda     $0e
         cmp     #$01               ; pawn on diagonal?
         beq     @same_dir             ; check pawn direction compatibility
         cmp     #$05               ; queen behind bishop?
         bne     @jmp_next_dir             ; no match - stop
         beq     @set_xray             ; yes - X-ray through

@check_q_r:  lda     $0e                ; queen ray continuation
         cmp     #$03               ; bishop blocking queen diagonal?
         bne     @check_rook
         lda     $10                ; check if diagonal direction
         cmp     #$05
         bcc     @jmp_next_dir             ; orthogonal dir - stop
         jmp     @ray_loop             ; diagonal - continue

@check_rook:  cmp     #$04               ; rook blocking queen orthogonal?
         bne     @check_queen
         lda     $10
         cmp     #$05               ; check if orthogonal direction
         bcc     @jmp_ray             ; orthogonal - continue
         jmp     @next_dir             ; diagonal - next direction

@check_queen:  cmp     #$05               ; queen behind queen?
         beq     @jmp_ray             ; yes - continue
         cmp     #$01               ; pawn blocking queen?
         bne     @jmp_next_dir
         lda     $10
         cmp     #$05               ; diagonal direction?
         bcc     @jmp_next_dir             ; no - stop
@same_dir:  lda     $13                ; check pawn direction compatibility
         eor     $11                ; pawn color vs ray direction
         bmi     @jmp_next_dir             ; wrong direction for this pawn - stop
         lda     $12
         ora     #$20               ; mark as attacked
         sta     $12
         jmp     @ray_loop             ; continue ray

; --- prune_exchanges ---
; Prunes attack/defense exchange lists (Static Exchange Evaluation).
; Removes unfavorable exchanges from the attacker list at $1346.
; Checks if trades are worth evaluating based on piece values
; and available defenders.
prune_exchanges:   lda     $6e
         eor     #$ff               ; compute defender list count
         clc
         adc     #$80               ; = $7f - $6e (number of defenders)
         beq     @done             ; no defenders - nothing to prune
         sta     $10                ; $10 = defender count
         ldy     #$7f               ; start at top of defender list
@scan_def:  lda     $1346,y            ; get target square entry
         bmi     @process             ; bit 7 set = attacker entry
@next_entry:  dey                        ; next entry
         dec     $10
         bne     @scan_def
@done:  rts

         ; --- process attacker entry ---
@process:  sty     $11                ; save current list position
         and     #$7f
         sta     $09                ; $09 = attacked square (clear bit 7)
         lda     $1347,y            ; next entry = defended piece square
         sta     $08                ; $08 = defender's target square
         lda     $13c7,y
         sta     $07                ; $07 = defender's source square
         ldx     $09
         lda     $146e,x            ; piece being attacked
         and     #$07
         sta     $0f                ; $0f = attacked piece type
         cmp     #$06               ; attacked piece is king?
         beq     @check_atk             ; always evaluate king attacks
         ldx     $07
         lda     $146e,x            ; attacking piece
         and     #$07
         cmp     $0f                ; attacker value >= defender value?
         bcc     @check_atk             ; attacker cheaper - evaluate trade
         ; --- attacker is more valuable: check if square is also attacked ---
         lda     $6f
         beq     @scan_def_tbl             ; no attackers - skip to second pass
         sta     $12                ; $12 = attacker count
         ldx     #$00
         lda     $09                ; attacked square
@check_dup:  cmp     $1346,x            ; is this square in attacker list?
         beq     @next_entry             ; yes - square defended, skip pruning
         inx
         dec     $12
         bne     @check_dup
         ; --- first pass: prune from attacker list ---
@check_atk:  lda     $6f
         beq     @scan_def_tbl             ; no attacker entries
         sta     $12                ; $12 = count
         ldx     #$00
@atk_loop:  lda     $13c6,x            ; source square of attacker
         and     #$7f
         cmp     $08                ; matches defender's target?
         bne     @atk_next             ; no - skip
         lda     $1346,x            ; target of attack
         and     #$7f
         cmp     $09                ; same as attacked square?
         beq     @atk_next             ; self-reference - skip
         sta     $0a                ; $0a = this attacker's target
         tay
         lda     $146e,y            ; piece at attacker's target
         and     #$07
         cmp     $0f                ; cheaper than defended piece?
         bcs     @atk_next             ; no - not worth pruning
         ; --- check if any defender covers this target ---
         lda     $6e
         eor     #$ff
         clc
         adc     #$80
         sta     $0d                ; $0d = defender count
         ldy     #$7f
@def_check:  lda     $13c6,y            ; defender source
         and     #$7f
         cmp     $07                ; matches our source?
         bne     @def_next
         lda     $1346,y            ; defender target
         and     #$7f
         cmp     $0a                ; covers the attacked square?
         beq     @atk_next             ; yes - don't prune, it's defended
@def_next:  dey
         dec     $0d
         bne     @def_check
         lda     #$00               ; no defender found
         sta     $1346,x            ; prune: remove attacker entry
@atk_next:  inx
         dec     $12
         bne     @atk_loop
         ; --- second pass: prune from defender list ---
@scan_def_tbl:  lda     $6e
         eor     #$ff
         clc
         adc     #$80
         sta     $12                ; $12 = defender count
         ldx     #$7f
@def_loop:  lda     $13c6,x            ; defender source square
         and     #$7f
         cmp     $08                ; matches target?
         bne     @def_next2             ; no - skip
         lda     $1346,x            ; defender target
         and     #$7f
         cmp     $07                ; same as source piece?
         beq     @def_next2             ; self - skip
         sta     $0a                ; $0a = defender's target square
         tay
         lda     $0f                ; defended piece type
         cmp     #$06               ; king?
         beq     @check_atk2             ; always check king defense
         lda     $146e,y            ; piece at defender target
         and     #$07
         cmp     $0f                ; cheaper than defended piece?
         bcs     @def_next2             ; no - keep entry
         lda     $1345,x            ; check adjacent list entry
         bpl     @check_atk2             ; not an attacker entry
         and     #$7f
         tay
         lda     $146e,y            ; piece at adjacent entry
         and     #$07
         cmp     $0f                ; cheaper?
         bcc     @remove_def             ; yes - prune
         bcs     @def_next2             ; no - keep

         ; --- check if any attacker covers this square ---
@check_atk2:  lda     $6f
         beq     @remove_def             ; no attackers
         sta     $0d
         ldy     #$00
@atk_loop2:  lda     $13c6,y            ; attacker source
         and     #$7f
         cmp     $07                ; matches source?
         bne     @atk_next2
         lda     $1346,y            ; attacker target
         and     #$7f
         cmp     $0a                ; covers our target?
         beq     @def_next2             ; yes - keep (covered)
@atk_next2:  iny
         dec     $0d
         bne     @atk_loop2
@remove_def:  lda     #$00
         sta     $1346,x            ; prune: remove entry
@def_next2:  dex
         dec     $12
         bne     @def_loop
         ldy     $11                ; restore list position
         jmp     @next_entry             ; continue outer loop

; --- build_exchange ---
; Builds piece exchange table at $1319 for static exchange eval.
; Packs two piece types per byte (low nibble first, high nibble).
; $05 = friendly count, $06 = enemy count.
; Y = list index on entry, $0a = entry count.
build_exchange:   lda     $0a
         sta     $10                ; $10 = remaining entries
         ldx     #$0e
         lda     #$00
         sta     $05                ; friendly piece count = 0
         sta     $06                ; enemy piece count = 0
@clear_loop:  sta     $1319,x            ; clear exchange table
         dex
         bne     @clear_loop
         sta     $0f                ; $0f = phase (0=defenders, 1=attackers)
         ; --- process one list entry ---
@process:  lda     $08
         ora     #$80               ; mark as processed
         sta     $1346,y
         lda     $13c6,y            ; source square + flags
         sta     $07
         and     #$7f
         tax
         lda     $146e,x            ; get piece at source
         bmi     @black_off             ; black piece?
         ldx     #$00               ; white: table offset 0
         inc     $05                ; count friendly piece
         bne     @set_type
@black_off:  ldx     #$07               ; black: table offset 7
         inc     $06                ; count enemy piece
@set_type:  and     #$07
         sta     $0d                ; $0d = piece type
         lda     $07
         bpl     @white_off             ; no X-ray flag?
         txa                        ; X-ray: offset by 6 (pack separately)
         clc
         adc     #$06
         bne     @find_slot
@white_off:  txa                        ; normal: offset by piece type
         clc
         adc     $0d
@find_slot:  tax                        ; X = index into exchange table
@slot_loop:  lda     $1319,x            ; find empty slot
         beq     @store             ; empty - store here
         and     #$f0               ; high nibble free?
         beq     @pack_hi             ; yes - pack into high nibble
         inx                        ; both full - next slot
         bne     @slot_loop
@pack_hi:  lda     $1319,x            ; pack into high nibble
         asl     A
         asl     A
         asl     A
         asl     A
@store:  ora     $0d                ; combine with piece type
         sta     $1319,x
         lda     $0f                ; which phase?
         beq     @next_def             ; phase 0: scanning defenders
         ; --- phase 1: scan attacker list (growing up) ---
@next_atk:  lda     $08                ; target square to match
@dec_count:  dec     $10
         beq     @done             ; done
         iny
         cmp     $1346,y            ; find matching target
         bne     @dec_count
         jmp     @process             ; process entry

         ; --- phase 0: scan defender list (growing down) ---
@next_def:  lda     $08
@dec_def:  dec     $10
         bne     @prev_def
         lda     $6f                ; switch to attacker list
         sta     $10
         ldy     #$ff               ; start from beginning
         inc     $0f                ; phase = 1
         inc     $10
         jmp     @next_atk

@prev_def:  dey                        ; scan downward
         cmp     $1346,y            ; find matching target
         bne     @dec_def
         jmp     @process             ; process entry

@done:  rts

; --- static_exchange ---
; Static Exchange Evaluation (SEE) for piece at square $08.
; Simulates a series of captures, alternating sides.
; Returns net material gain/loss in A (centered at $80).
; Tracks best (max) and worst (min) scores for minimax.
static_exchange:   ldx     $08
         lda     $146e,x            ; piece on target square
         sta     $13                ; save piece + color
         and     #$07
         tax
         lda     piece_values,x     ; get piece value
         clc
         adc     #$80               ; center around $80 (= 0)
         sta     $0d                ; $0d = best score (max)
         sta     $0e                ; $0e = running score
         lda     #$00
         sta     $0f                ; $0f = worst score (min)
         sta     $10                ; $10 = saved worst
         sta     $12                ; $12 = side toggle (0=friendly, 1=enemy)
         tax                        ; X = friendly table index
         ldy     #$07               ; Y = enemy table index
         lda     $13
         bpl     @eval_loop             ; white piece - start with enemy capture
         inc     $12                ; black piece - start with friendly
         ; --- main exchange loop ---
@eval_loop:  jsr     @get_next             ; get next enemy piece value
         beq     @atk_done             ; no more enemy pieces - done
         eor     #$ff               ; negate (enemy captures = loss)
         adc     #$01
         clc
         adc     $0e                ; subtract from running score
         sta     $0e
         cmp     $0f                ; new minimum?
         bcc     @try_defend
         lda     $0e                ; update worst score
         sta     $0f
         lda     $0d                ; save current best
         sta     $11
@try_defend:  jsr     @get_next             ; get next friendly piece value
         beq     @def_done             ; no more friendly pieces - done
         adc     $0e                ; add to running score (recapture)
         sta     $0e
         cmp     $0d                ; new maximum?
         bcs     @eval_loop             ; no - continue
         lda     $0e                ; update best score
         sta     $0d
         lda     $0f                ; save current worst
         sta     $10
         jmp     @eval_loop             ; continue exchange

         ; --- no more enemy pieces: return min(worst, saved) ---
@atk_done:  lda     $0f
         cmp     $11
         bcc     @done
         lda     $11                ; return lesser extreme
@done:  rts

         ; --- no more friendly pieces: return max(best, saved) ---
@def_done:  lda     $0d
         cmp     $10
         bcs     @done2
         lda     $10                ; return lesser extreme
@done2:  rts

         ; --- extract next piece from exchange table ---
         ; Alternates between enemy (Y index) and friendly (X index).
         ; Returns piece value in A, Z flag set if no piece available.
@get_next:  lda     $12                ; side toggle
         bne     @get_atk             ; nonzero = get friendly piece
         inc     $12                ; flip to friendly next time
         lda     $06                ; enemy pieces remaining?
         beq     @empty             ; no - return Z=1
         dec     $06
@find_def:  iny                        ; scan enemy side of table
         lda     $1319,y
         beq     @find_def             ; skip empty slots
         pha
         lsr     A                  ; shift high nibble down
         lsr     A
         lsr     A
         lsr     A
         sta     $1319,y            ; leave high nibble for next extraction
         dey
         bne     @unpack
@get_atk:  dec     $12                ; flip to enemy next time
         lda     $05                ; friendly pieces remaining?
         beq     @empty             ; no - return Z=1
         dec     $05
@find_atk:  inx                        ; scan friendly side of table
         lda     $1319,x
         beq     @find_atk             ; skip empty slots
         pha
         lsr     A                  ; shift high nibble down
         lsr     A
         lsr     A
         lsr     A
         sta     $1319,x            ; leave high nibble for next extraction
         dex
@unpack:  pla
         and     #$0f               ; low nibble = piece type
         sty     $14                ; save Y
         tay
         lda     piece_values,y     ; look up piece value
         ldy     $14                ; restore Y
         clc                        ; clear Z flag (piece found)
@empty:  rts

; --- evaluate_position ---
; Main position evaluation function. Combines mobility, material
; exchanges, pawn structure, king proximity, and opening strategy.
; Score returned in $61/$62 (16-bit, centered at $80 = neutral).
; Negated for black (negamax convention).
evaluate_position:   inc     $70     ; increment node counter (lo)
         bne     @init_vars
         inc     $71                ; increment node counter (hi)
         bne     @init_vars
         dec     $70                ; clamp at $ffff
         dec     $71
@init_vars:  lda     #$00
         ldx     #$08
@zero_loop:  sta     $61,x              ; clear eval accumulators $61-$69
         dex
         bpl     @zero_loop
         jsr     eval_mobility      ; build attack/defense lists + centrality
         jsr     prune_exchanges    ; remove unfavorable exchanges
         ; --- evaluate material exchanges ---
         lda     $6e
         eor     #$ff
         clc
         adc     #$80               ; count defender entries
         beq     @skip_king_eval             ; none - skip exchange eval
         sta     $0a                ; $0a = defender count
         ldy     #$7f               ; start at top of defender list
@piece_loop:  lda     $1346,y            ; target square entry
         bmi     @next_piece             ; attacker entry (bit 7) - skip
         beq     @next_piece             ; pruned entry - skip
         sta     $08                ; $08 = square to evaluate
         sty     $09                ; save list position
         jsr     build_exchange     ; build exchange table for this square
         jsr     static_exchange    ; evaluate the exchange
         sec
         sbc     #$80               ; remove $80 center bias
         bmi     @restore_y             ; negative result - skip (loss)
         beq     @check_king_sq             ; neutral - check if target square
         sta     $0d                ; $0d = exchange gain
         lda     $13
         eor     next_color         ; is it our piece?
         bmi     @enemy_exchange             ; no - enemy threat
         ; --- friendly exchange gain ---
         lda     $0d
         cmp     $63                ; better than current best?
         bcc     @update_max
         sta     $63                ; $63 = best own mobility/exchange
@update_max:  lda     $67
         sec
         sbc     #$08               ; penalize mobility (piece is pinned/traded)
         sta     $67                ; $67 = mobility balance
@check_king_sq:  lda     $08                ; is this the move's target square?
         cmp     $0c
         bne     @restore_y
         sta     $66                ; $66 = exchange target square
         beq     @restore_y

         ; --- enemy threat ---
@enemy_exchange:  lda     $0d
         cmp     $64                ; worse than best enemy threat?
         bcc     @update_2nd
         ldx     $64                ; demote current best to second
         sta     $64                ; $64 = best enemy threat
         txa
@update_2nd:  cmp     $65                ; worse than second threat?
         bcc     @king_safety
         sta     $65                ; $65 = second enemy threat
@king_safety:  lda     $67
         clc
         adc     #$04               ; enemy threat improves mobility
         sta     $67
@restore_y:  ldy     $09                ; restore list position
@next_piece:  dey
         dec     $0a
         bne     @piece_loop             ; next defender entry
         lda     $66                ; was target square exchanged?
         beq     @skip_king_eval
         lda     #$00
         sta     $65                ; clear second threat (target was in list)
         ; --- endgame king proximity ---
@skip_king_eval:  lda     level+2            ; endgame flag
         beq     @pawn_eval
         jsr     king_proximity     ; add king centralization score
         ; --- pawn structure evaluation ---
@pawn_eval:  jsr     @pawn_struct             ; evaluate pawn structure -> $6b
         ; --- combine all scores ---
         lda     $65                ; second enemy threat
         asl     $63                ; double best own mobility
         sec
         sbc     $63                ; threats - 2*mobility
         bit     next_color
         bpl     @adjust_sign
         eor     #$ff               ; negate for black
         clc
         adc     #$01
@adjust_sign:  clc
         adc     $6a                ; + material balance (twice)
         clc
         adc     $6a
         sta     $62                ; store high byte of score
         lda     $64                ; best enemy threat
         sec
         sbc     $63                ; - best own mobility
         clc
         adc     $67                ; + mobility balance
         bit     next_color
         bpl     @add_terms
         eor     #$ff               ; negate for black
         clc
         adc     #$01
@add_terms:  and     #$ff
         jsr     @add_pos             ; add to 16-bit accumulator $61/$62
         lda     $68                ; positional/centrality score
         jsr     @add_pos
         lda     $1e                ; opening strategy bonus (x2)
         jsr     @add_pos
         lda     $1e
         jsr     @add_pos
         lda     $6b                ; pawn structure score (x2)
         jsr     @add_pos
         lda     $6b
         jsr     @add_pos
         ; --- negate score if playing black (negamax) ---
         lda     next_color
         bpl     @final_score             ; white - keep sign
         lda     $61                ; negate 16-bit score
         clc
         eor     #$ff
         adc     #$01
         sta     $61
         lda     $62
         eor     #$ff
         adc     #$00
         sta     $62
@final_score:  lda     $62                ; center around $80
         clc
         adc     #$80
         sta     $62
         rts

         ; --- add signed A to 16-bit accumulator $61/$62 ---
@add_pos:  clc
         bmi     @add_neg             ; negative value
         adc     $61                ; positive: add to low byte
         sta     $61
         bcc     @done_pos
         inc     $62                ; propagate carry
@done_pos:  rts

@add_neg:  adc     $61                ; negative: add to low byte
         sta     $61
         bcs     @done_neg
         dec     $62                ; propagate borrow
@done_neg:  rts

         ; --- pawn structure score helpers ---
@add4_pawn:  lda     #$04               ; +4 bonus (passed pawn)
@add_clc:  clc                        ; entry for variable bonus/penalty
@add_pawn:  adc     $6b               ; add to pawn structure score
         sta     $6b
         rts

         ; --- pawn structure evaluation ---
         ; Scans each file (column) for pawns. Evaluates doubled,
         ; isolated, passed, and connected pawns. Score in $6b.
         ; $11/$12 = file of first white/black pawn per column.
         ; $0f/$10 = last file with friendly/enemy pawn.
@pawn_struct:  lda     #$00
         sta     $0e                ; file characteristics flags
         sta     $11                ; white pawn file = none
         sta     $12                ; black pawn file = none
         sta     $6b                ; pawn structure score = 0
         sta     $0f                ; last friendly pawn file = none
         sta     $10                ; last enemy pawn file = none
         ldx     #$1f               ; start square (file A, rank 2)
@file_loop:  lda     #$06               ; 6 ranks to scan per file
         sta     $0d                ; $0d = rank counter
@rank_loop:  lda     $146e,x            ; piece at square
         and     #$07
         cmp     #$01               ; pawn?
         bne     @advance_sq             ; no - next rank
         lda     $146e,x            ; check pawn color
         bmi     @black_pawn             ; black pawn
         ; --- white pawn found ---
         lda     $11                ; already found white pawn on this file?
         beq     @white_pawn
         lda     #$fc               ; yes - doubled pawn penalty (-4)
         jsr     @add_clc
@white_pawn:  lda     $0d                ; record rank position
         sta     $11
         jmp     @advance_sq

         ; --- black pawn found ---
@black_pawn:  lda     $12                ; already found black pawn on this file?
         beq     @first_black
         jsr     @add4_pawn             ; yes - doubled pawn bonus (+4 for us)
         jmp     @advance_sq

@first_black:  lda     $0d                ; record rank position
         sta     $12
@advance_sq:  txa
         clc
         adc     #$0a               ; advance one rank (stride 10)
         tax
         dec     $0d                ; next rank
         bne     @rank_loop
         ; --- analyze white pawn on this file (no black pawn) ---
         lda     $12                ; black pawn on this file?
         bne     @no_wp             ; yes - skip to black pawn analysis
         lda     $11                ; white pawn on this file?
         beq     @check_bp             ; no - check semi-open file
         lda     $0e                ; white passed pawn (no black pawn ahead)
         ora     #$40               ; set passed pawn flag
         sta     $0e
         jsr     @add4_pawn             ; passed pawn bonus (+4)
         lda     move_number
         cmp     #$14               ; after move 20?
         bcc     @check_adj_w             ; no - skip advancement bonus
         lda     #$07               ; compute advancement bonus
         sec                        ; = 2^(7-rank) (exponential for
         sbc     $11                ;   advanced passed pawns)
         tay
         lda     #$00
         sec
@shift_loop:  rol     A                  ; shift 1 left Y times
         dey
         bne     @shift_loop
         jsr     @add_pawn             ; add advancement bonus
@check_adj_w:  lda     $10                ; last enemy pawn file
         beq     @check_pass_w             ; none - skip connected check
         cmp     $11                ; on same file?
         beq     @adj_bonus
         sec
         sbc     #$01               ; adjacent file?
         cmp     $11
         beq     @adj_bonus
         clc
         adc     #$02               ; other adjacent file?
         cmp     $11
         bne     @check_pass_w
@adj_bonus:  lda     #$02               ; connected pawns bonus (+2)
         jsr     @add_clc
@check_pass_w:  lda     $0f                ; last friendly pawn file
         beq     @isolated_w             ; none
         cmp     $11                ; friendly pawn at/beyond white pawn?
         bcc     @check_bp             ; no - semi-open
@isolated_w:  lda     $0e                ; mark isolated/exposed
         ora     #$80
         sta     $0e
@check_bp:  lda     $0f                ; last friendly pawn file
         beq     @no_wp             ; none
         jsr     @add4_pawn             ; semi-open file penalty (+4 for enemy)
         ; --- analyze black pawn on this file (no white pawn) ---
@no_wp:  lda     $11                ; white pawn present?
         bne     @opp_file             ; yes - skip to cross-side analysis
         lda     $12                ; black pawn present?
         beq     @check_opp             ; no - check semi-open file
         lda     $0e                ; black passed pawn
         ora     #$10               ; set enemy passed pawn flag
         sta     $0e
         lda     #$fc               ; passed pawn penalty (-4, good for enemy)
         jsr     @add_clc
         lda     move_number
         cmp     #$14               ; after move 20?
         bcc     @check_adj_b             ; no - skip advancement penalty
         lda     #$ff               ; compute advancement penalty
         ldy     $12                ; (exponential for advanced pawns)
@shift_bk:  dey
         beq     @add_bk_pen
         asl     A                  ; shift left Y times
         bne     @shift_bk
@add_bk_pen:  jsr     @add_clc             ; add advancement penalty
@check_adj_b:  lda     $0f                ; last friendly pawn file
         beq     @check_pass_b             ; none - skip connected check
         cmp     $12                ; on same file?
         beq     @adj_bonus_b
         clc
         adc     #$01               ; adjacent file?
         cmp     $12
         beq     @adj_bonus_b
         sec
         sbc     #$02               ; other adjacent file?
         cmp     $12
         bne     @check_pass_b
@adj_bonus_b:  lda     #$fe               ; connected enemy pawns penalty (-2)
         jsr     @add_clc
@check_pass_b:  lda     $12                ; black pawn at/beyond last enemy pawn?
         cmp     $10
         bcc     @check_opp
         lda     $0e                ; mark exposed
         ora     #$20
         sta     $0e
@check_opp:  lda     $10                ; last enemy pawn file
         beq     @opp_file             ; none
         lda     #$fc               ; semi-open file penalty (-4)
         jsr     @add_clc
         ; --- cross-side pawn structure analysis ---
         ; Uses flags from previous file iterations ($0e bits)
@opp_file:  lda     $0e
         and     #$04               ; previous file had specific flag?
         beq     @iso_check
         lda     $11                ; white pawn on this file?
         beq     @check_semi             ; no - skip connected check
         cmp     $10                ; adjacent to last enemy pawn?
         beq     @adj_bonus_o
         clc
         adc     #$01
         cmp     $10
         beq     @adj_bonus_o
         sec
         sbc     #$02
         cmp     $10
         bne     @check_semi
@adj_bonus_o:  lda     #$02               ; connected pawn bonus (+2)
         jsr     @add_clc
@check_semi:  lda     $0e
         and     #$08               ; check exposure flag
         beq     @iso_check
         lda     $12                ; black pawn present and advanced?
         beq     @semi_bonus
         cmp     $10
         bcc     @iso_check
@semi_bonus:  jsr     @add4_pawn             ; exposure bonus (+4)
@iso_check:  lda     $0e
         and     #$01               ; check isolated flag
         beq     @swap_sides
         lda     $12                ; black pawn connected to friendly?
         beq     @check_open
         cmp     $0f                ; adjacent file?
         beq     @iso_penalty
         clc
         adc     #$ff
         cmp     $0f
         beq     @iso_penalty
         clc
         adc     #$02
         cmp     $0f
         bne     @check_open
@iso_penalty:  lda     #$fe               ; connected enemy penalty (-2)
         jsr     @add_clc
@check_open:  lda     $0e
         and     #$02               ; check another flag
         beq     @swap_sides
         lda     $0f
         cmp     $11                ; friendly pawn at/beyond white pawn?
         bcc     @swap_sides
         lda     #$fc               ; isolated pawn penalty (-4)
         jsr     @add_clc
         ; --- advance to next file ---
@swap_sides:  lda     $0e                ; shift flags right 4 bits
         lsr     A                  ; (carry forward from white to black
         lsr     A                  ;  side evaluation)
         lsr     A
         lsr     A
         sta     $0e
         lda     $12                ; save current pawns as "last file"
         sta     $0f                ; $0f = last friendly pawn file
         lda     $11
         sta     $10                ; $10 = last enemy pawn file
         lda     #$00
         sta     $11                ; reset for next file
         sta     $12
         txa                        ; adjust X to next file
         sec
         sbc     #$3b               ; step back by $3b (next column start)
         tax
         cmp     #$27               ; midpoint? (switch to black side)
         bne     @check_end
         jmp     @opp_file             ; process cross-side flags first

@check_end:  cmp     #$ec               ; done with all files?
         bne     @next_file
         rts                        ; yes - return

@next_file:  jmp     @file_loop             ; next file column

; --- opening_strategy ---
; Applies opening/middlegame positional bonuses and penalties.
; Pawn center control, piece development, king safety, castling.
; Result added to $1e (positional bonus), sign depends on color.
; $0d bit 4 = capture, bit 0 = piece color.
opening_strategy:   lda     $13
         and     #$07
         cmp     #$01               ; pawn?
         bne     @not_pawn             ; no - check pieces
         ; --- pawn strategy ---
         lda     move_number
         cmp     #$0a               ; before move 10?
         bcs     @midgame             ; no - later pawn strategy
         ; --- early game pawn moves ---
         lda     $0b                ; source square of move
         bit     $13                ; check piece color
         bpl     @check_center
         sec
         sbc     #$32               ; normalize black squares to white
@check_center:  cmp     #$22               ; d-file pawn?
         beq     @check_advance
         cmp     #$23               ; e-file pawn?
         beq     @check_advance
         ; --- flank pawn ---
         lda     $0d
         and     #$20               ; was it a push (not capture)?
         beq     @retreat_pen
         rts                        ; capture with flank pawn - ok

@retreat_pen:  lda     #$f8               ; flank pawn push penalty (-8)
         jmp     @set_bonus

         ; --- center pawn: check if advancing to d4/e4 ---
@check_advance:  sec
         sbc     $0c                ; distance from source to target
         cmp     #$ec               ; one square advance?
         beq     @advance_bonus
         cmp     #$e2               ; two square advance?
         bne     @done             ; other - no bonus
@advance_bonus:  lda     #$04               ; center pawn advance bonus (+4)
         jmp     @set_bonus

         ; --- later pawn moves (move 10-25): king safety ---
@midgame:  cmp     #$19               ; after move 25?
         bcs     @done             ; yes - no penalty
         lda     $13                ; check piece color
         bmi     @bk_pos             ; black pawn
         ; --- white pawn near king ---
         lda     $6c                ; white king position
         cmp     #$1a               ; king on queenside?
         bcc     @wk_safe
         cmp     #$1d               ; king on kingside?
         bcs     @done             ; center king - no pawn penalty
         lda     #$00               ; offset for center-ish king
         beq     @verify_castle

@wk_safe:  cmp     #$18               ; king on far queenside?
         bcs     @done
         lda     #$05               ; offset for queenside king
         bne     @verify_castle

         ; --- black pawn near king ---
@bk_pos:  lda     $6d                ; black king position
         cmp     #$60               ; king on queenside (black)?
         bcc     @bk_safe
         lda     #$ce               ; offset for queenside
         bne     @verify_castle

@bk_safe:  cmp     #$5e               ; king on kingside?
         bcs     @done
         cmp     #$5b
         bcc     @done
         lda     #$d3               ; offset for kingside
@verify_castle:  clc
         adc     $0b                ; add to source square
         cmp     #$27               ; pawn is in king's zone?
         bcs     @done             ; no - outside zone
         cmp     #$24
         bcc     @done             ; no - outside zone
         lda     #$f4               ; king pawn advance penalty (-12)
         jmp     @set_bonus

@done:  rts

         ; --- piece strategy (type >= 2) ---
@not_pawn:  cmp     #$04               ; rook or queen? (type 4-5)
         bcc     @minor_piece             ; no - knight/bishop (type 2-3)
         cmp     #$06               ; king? (type 6)
         beq     @king_move             ; yes - king strategy
         ; --- rook/queen: penalize early development ---
         lda     move_number
         cmp     #$07               ; before move 7?
         bcs     @done             ; no - ok to develop now
         lda     #$f0               ; early rook/queen penalty (-16)
         jmp     @set_bonus

         ; --- king strategy ---
@king_move:  lda     $0d
         bpl     @king_early             ; not a capture - check center penalty
         ; --- king capture (castling check) ---
         lda     $0c                ; target square
         bit     $13                ; check piece color
         bpl     @sub_king
         sec
         sbc     #$46               ; normalize black to white coordinates
@sub_king:  sec
         sbc     #$0f               ; check for castling target squares
         cmp     #$0c               ; castling square? (=$0c means castled)
         beq     @set_bonus             ; yes - bonus = $0c (+12)
         lda     #$06               ; non-castling king move (+6)
         bne     @set_bonus

         ; --- king in center: penalty before move 30 ---
@king_early:  lda     move_number
         cmp     #$1e               ; after move 30?
         bcs     @done             ; yes - no penalty
         lda     #$f4               ; early king center penalty (-12)
         bne     @set_bonus

         ; --- knight/bishop strategy (type 2-3) ---
@minor_piece:  lda     $0d
         and     #$10               ; is it a capture?
         beq     @early_dev
         lda     #$0a               ; capture bonus (+10)
         bne     @store_bonus

@early_dev:  lda     move_number
         cmp     #$09               ; before move 9?
         bcs     @done             ; no - no bonus needed
         lda     #$f8               ; non-development penalty (-8)
         bne     @store_bonus

         ; --- minor piece development: check center control ---
@store_bonus:  sta     $0f                ; save bonus/penalty
         lda     move_number
         cmp     #$0f               ; before move 15?
         bcs     @apply_bonus             ; no - skip center check
         lda     $0c                ; target square
         bit     $13                ; check piece color
         bpl     @check_center
         sec
         sbc     #$1e               ; normalize black to white
@check_center:  cmp     #$2c               ; d4 square?
         beq     @on_center
         cmp     #$2d               ; e4 square?
         bne     @apply_bonus             ; not center - use saved bonus
         ; --- piece develops to center: check if blocking center pawn ---
@on_center:  sec
         sbc     #$0a               ; look one rank back (d3/e3)
         bit     $13
         bpl     @check_pawn
         clc
         adc     #$32               ; adjust for black
@check_pawn:  tax
         lda     $146e,x            ; piece behind on same file
         and     #$07
         cmp     #$01               ; pawn behind?
         bne     @apply_bonus             ; no - use saved bonus
         lda     #$e8               ; blocks center pawn penalty (-24)
         ; --- apply bonus/penalty to $1e (sign depends on color) ---
@set_bonus:  sta     $0f
@apply_bonus:  lda     $0d
         and     #$01               ; piece color bit
         beq     @check_side
         lda     $13
         bmi     @add_bonus             ; black piece + black side: add bonus
@sub_bonus:  lda     $1e                ; subtract bonus (wrong color perspective)
         sec
         sbc     $0f
         sta     $1e
         rts

@check_side:  lda     $13
         bmi     @sub_bonus             ; white piece + black side: subtract
@add_bonus:  lda     $1e                ; add bonus (matching color perspective)
         clc
         adc     $0f
         sta     $1e
         rts

; --- king_proximity ---
; Endgame king evaluation. Computes Manhattan distance between
; kings ($6c=white, $6d=black). Penalizes losing side's king
; for distance from center and from enemy king.
; Result in $68 (king tropism), sign flipped if black is ahead.
king_proximity:   lda     $6c     ; white king square
         ldy     #$00
         ; --- divmod 10: extract file (A) and rank (Y) ---
@div10_wk:  cmp     #$0a
         bcc     @wk_done
         iny                        ; Y = rank
         sec
         sbc     #$0a
         bne     @div10_wk
@wk_done:  sta     $0d                ; $0d = white king file
         sty     $0e                ; $0e = white king rank
         lda     $6d                ; black king square
         ldy     #$00
         ; --- divmod 10: black king file/rank ---
@div10_bk:  cmp     #$0a
         bcc     @dist_calc
         iny                        ; Y = black king rank
         sec
         sbc     #$0a
         bne     @div10_bk
         ; --- compute Manhattan distance between kings ---
@dist_calc:  sec
         sbc     $0d                ; file difference (black - white)
         bmi     @store_dist             ; already negative = abs ok
         eor     #$ff               ; negate to get -abs(file diff)
         clc
         adc     #$01
@store_dist:  sta     $0d                ; $0d = -|file diff|
         tya                        ; black king rank
         sec
         sbc     $0e                ; rank difference (black - white)
         bmi     @abs_rank             ; already negative = abs ok
         eor     #$ff               ; negate to get -abs(rank diff)
         clc
         adc     #$01
@abs_rank:  clc
         adc     $0d                ; -|file diff| + -|rank diff|
         clc
         adc     #$0e               ; add 14 to center (always positive)
         sta     $0d                ; $0d = distance score (14 - Manhattan dist)
         ; --- select losing side's king for centrality penalty ---
         ldx     #$00               ; X=0: use white king ($6c)
         lda     $6a                ; material balance
         bmi     @get_king             ; black ahead - penalize white king
         inx                        ; X=1: use black king ($6d)
@get_king:  ldy     $6c,x              ; Y = losing king square
         lda     #$08
         sec
         sbc     centrality,y       ; 8 - centrality = edge penalty
         asl     A                  ; double edge penalty
         clc
         adc     $0d                ; + king distance score
         asl     A                  ; multiply total by 4
         asl     A
         sta     $68                ; store king tropism score
         ; --- negate if black has material advantage ---
         lda     $6a
         bpl     @sign_adj             ; white ahead - keep positive
         lda     $68                ; negate score for black advantage
         eor     #$ff
         clc
         adc     #$01
         sta     $68
@sign_adj:  lda     #$00
         sta     $64                ; clear best enemy threat
         rts

; =====================================================================
; SEARCH ENGINE
; =====================================================================

; ---------------------------------------------------------------------
; make_move - Execute a move on the internal board
; Input: move at ($8b)+$8d (two bytes: from-square, to-square)
; Sets $0b=from, $0c=to, $13=moving piece, $14=captured piece
; Handles pawn promotion, en passant, and castling as special cases.
; Updates material balance ($6a) and stores undo info at $1327/$1331+y.
; ---------------------------------------------------------------------
make_move:   ldy     $8d             ; Y = move list offset
         lda     ($8b),y          ; load from-square
         sta     $0b              ; $0b = from
         tax
         iny
         lda     ($8b),y          ; load to-square
         sta     $0c              ; $0c = to
         lda     $146e,x          ; get piece at from-square
         sta     $13              ; $13 = moving piece
         lda     #$00
         sta     $146e,x          ; clear from-square
         sta     $0d              ; $0d = move flags (initially 0)
         bit     $13              ; test bit 6: has piece moved before?
         bvs     @check_first           ; yes - skip
         lda     #$10             ; first move: set "first-move" flag in $0d
         sta     $0d
         lda     $13
         ora     #$40             ; set has-moved bit on piece
         sta     $13
@check_first:  ldx     $0c              ; X = to-square
         lda     $146e,x          ; get piece at to-square (capture target)
         sta     $14              ; $14 = captured piece (0 if empty)
         lda     $13
         sta     $146e,x          ; place moving piece at to-square
         and     #$07             ; extract piece type
         cmp     #$01             ; pawn?
         beq     @pawn_move           ; -> pawn special handling
         cmp     #$06             ; king?
         bne     @eval_move           ; other piece -> normal completion
         jmp     @king_move           ; -> king special handling

         ; --- common move completion ---
@eval_move:  jsr     opening_strategy   ; evaluate positional factors
         ldy     next_color+1       ; Y = current ply index
         lda     $0d
         sta     $1331,y            ; save move flags for undo
         lda     $14
         sta     $1327,y            ; save captured piece for undo
         beq     @done             ; no capture -> done
         and     #$07               ; extract captured piece type
         tax
         lda     $14
         bpl     @sub_piece             ; white piece captured -> subtract
         lda     $6a                ; black piece captured: add its value
         clc
         adc     piece_values,x     ; material += piece value
         sta     $6a
         rts

@sub_piece:  lda     $6a                ; white piece captured: subtract value
         sec
         sbc     piece_values,x     ; material -= piece value
         sta     $6a
@done:  rts

         ; --- pawn special handling ---
@pawn_move:  lda     $0c              ; to-square
         cmp     #$5b             ; rank 8? (>= $5b)
         bcs     @not_promote           ; -> promotion
         cmp     #$1d             ; rank 1? (< $1d)
         bcs     @check_ep           ; no promotion -> check en passant
         ; --- pawn promotion: promote to queen ---
@not_promote:  lda     $0d
         ora     #$20             ; set promotion flag
         sta     $0d
         lda     $146e,x          ; pawn type $01
         ora     #$04             ; set bit 2 -> type $05 (queen)
         sta     $146e,x
         sta     $13
         bmi     @black_promo           ; black pawn?
         lda     #$07             ; white: +7 (queen value - pawn value)
         .byte   $2c              ; BIT abs - skip next 2-byte instruction
@black_promo:  lda     #$f9             ; black: -7 (queen value - pawn value)
         clc
         adc     $6a              ; update material balance
         sta     $6a
         jmp     @eval_move           ; -> common completion

         ; --- en passant check ---
@check_ep:  lda     $0c              ; to-square
         sec
         sbc     $0b              ; to - from
         and     #$01             ; diagonal move? (file changed)
         beq     @eval_move           ; straight push -> normal completion
         lda     $14              ; target square empty?
         bne     @eval_move           ; occupied -> normal capture
         ; diagonal pawn move to empty square = en passant
         lda     $13
         bmi     @bk_ep_sq           ; black pawn?
         lda     #$f6             ; white: offset -10 (capture square behind)
         .byte   $2c              ; BIT abs - skip
@bk_ep_sq:  lda     #$0a             ; black: offset +10 (capture square behind)
         clc
         adc     $0c              ; compute captured pawn's square
         tax
         lda     $146e,x          ; get the captured pawn
         sta     $14              ; save as captured piece
         lda     #$00
         sta     $146e,x          ; remove captured pawn from board
         lda     $0d
         ora     #$40             ; set en passant flag
         sta     $0d
         jmp     @eval_move           ; -> common completion

         ; --- king special handling ---
@king_move:  lda     $0c              ; to-square
         ldx     $13              ; moving piece (king)
         bmi     @bk_king           ; black king?
         sta     $6c              ; update white king position
         .byte   $2c              ; BIT abs - skip
@bk_king:  sta     $6d              ; update black king position
         sta     $08              ; $08 = king destination
         sec
         sbc     $0b              ; delta = to - from
         cmp     #$02             ; moved +2? (kingside castle)
         beq     @kingside
         cmp     #$fe             ; moved -2? (queenside castle)
         bne     @king_done           ; not castling -> normal completion
         ; --- queenside castle: rook a-file -> d-file ---
         inc     $08              ; rook destination = king dest + 1
         asl     A                ; delta*2 = -4
         clc
         adc     $0b              ; from + (-4) = rook source (a-file)
         bne     @rook_from           ; always taken
         ; --- kingside castle: rook h-file -> f-file ---
@kingside:  dec     $08              ; rook destination = king dest - 1
         clc
         adc     $0b              ; from + 2 = intermediate
         adc     #$01             ; + 1 = rook source (h-file)
@rook_from:  tax                      ; X = rook source square
         lda     $146e,x          ; get the rook
         sta     $10
         lda     #$00
         sta     $146e,x          ; clear rook source square
         lda     $10
         ora     #$40             ; set has-moved bit on rook
         ldx     $08
         sta     $146e,x          ; place rook at destination
         lda     $0d
         ora     #$80             ; set castling flag
         sta     $0d
@king_done:  jmp     @eval_move           ; -> common completion

; ---------------------------------------------------------------------
; unmake_move - Reverse a move, restoring the board to its prior state
; Uses saved undo info from $1327+y (captured piece) and $1331+y (flags).
; Handles undo of promotion, en passant, and castling.
; ---------------------------------------------------------------------
unmake_move:   ldy     $8d              ; move list offset
         lda     ($8b),y            ; from-square
         sta     $0b
         iny
         lda     ($8b),y            ; to-square
         sta     $0c
         tax
         lda     $146e,x            ; piece currently at to-square
         sta     $13                ; $13 = moving piece
         ldy     next_color+1
         lda     $1327,y            ; restore captured piece
         sta     $14
         sta     $146e,x            ; put captured piece back at to-square
         lda     $1331,y            ; restore move flags
         sta     $0d
         and     #$10               ; first-move flag set?
         beq     @restore_from             ; no -> skip
         lda     $13
         and     #$bf               ; clear has-moved bit (restore virgin state)
         sta     $13
@restore_from:  ldx     $0b                ; X = from-square
         lda     $13
         sta     $146e,x            ; restore piece to from-square
         and     #$07               ; piece type
         cmp     #$01               ; pawn?
         beq     @undo_ep             ; -> undo pawn specials
         cmp     #$06               ; king?
         beq     @undo_king             ; -> undo king specials
         lda     $0d
         and     #$20               ; promotion flag? (non-pawn promoted piece)
         bne     @undo_promo             ; -> undo promotion
         ; --- common unmake completion ---
@undo_eval:  inc     $0d                ; flag for opening_strategy undo mode
         jsr     opening_strategy   ; undo positional evaluation
         lda     $14                ; captured piece
         beq     @done             ; no capture -> done
         and     #$07               ; piece type
         tax
         lda     $14
         bmi     @sub_piece             ; black piece? -> subtract
         lda     $6a                ; white piece restored: add value back
         clc
         adc     piece_values,x
         sta     $6a
         rts

@sub_piece:  lda     $6a                ; black piece restored: subtract value
         sec
         sbc     piece_values,x
         sta     $6a
@done:  rts

         ; --- undo promotion: restore queen back to pawn ---
@undo_promo:  lda     $13
         and     #$fb             ; clear bit 2 -> type $05 (queen) back to $01 (pawn)
         sta     $13
         sta     $146e,x          ; update board
         bpl     @bk_promo           ; white pawn?
         lda     #$07             ; black: +7 (reverse the -7 from promote)
         .byte   $2c              ; BIT abs - skip
@bk_promo:  lda     #$f9             ; white: -7 (reverse the +7 from promote)
         clc
         adc     $6a              ; adjust material balance back
         sta     $6a
         jmp     @undo_eval           ; -> common unmake completion

         ; --- undo pawn specials ---
@undo_ep:  bit     $0d              ; en passant flag (bit 6)?
         bvc     @undo_eval           ; no -> common unmake
         ; --- undo en passant ---
         ldx     $0c              ; to-square
         lda     #$00
         sta     $146e,x          ; clear the to-square (captured pawn was not there)
         lda     $13
         bmi     @bk_ep           ; black pawn?
         lda     #$f6             ; white: offset -10 (pawn was one rank behind)
         .byte   $2c              ; BIT abs - skip
@bk_ep:  lda     #$0a             ; black: offset +10
         clc
         adc     $0c              ; compute captured pawn's square
         tax
         lda     $14              ; restored captured pawn
         sta     $146e,x          ; put it back on the board
         jmp     @undo_eval           ; -> common unmake completion

         ; --- undo king specials ---
@undo_king:  ldx     $0b              ; from-square (original king position)
         lda     $13
         bmi     @bk_king           ; black king?
         stx     $6c              ; restore white king position
         .byte   $2c              ; BIT abs - skip
@bk_king:  stx     $6d              ; restore black king position
         lda     $0d              ; move flags
         bpl     @undo_eval           ; castling flag (bit 7)? no -> common unmake
         ; --- undo castling: move the rook back ---
         lda     $0c
         sta     $08              ; $08 = king destination (rook is near here)
         sec
         sbc     $0b              ; delta = to - from
         cmp     #$02             ; kingside castle?
         beq     @kingside
         ; queenside: rook is at king dest + 1
         inc     $08              ; rook current pos = king dest + 1
         asl     A                ; delta*2 = -4
         clc
         adc     $0b              ; from + (-4) = rook original square (a-file)
         bne     @rook_dest           ; always taken
         ; kingside: rook is at king dest - 1
@kingside:  dec     $08              ; rook current pos = king dest - 1
         clc
         adc     $0b              ; from + 2 = intermediate
         adc     #$01             ; + 1 = rook original square (h-file)
@rook_dest:  sta     $07              ; $07 = rook's original square
         ldx     $08              ; X = rook's current square (post-castle)
         lda     $146e,x          ; get the rook
         and     #$bf             ; clear has-moved bit (restore virgin state)
         sta     $10
         lda     #$00
         sta     $146e,x          ; clear rook's current square
         ldx     $07
         lda     $10
         sta     $146e,x          ; put rook back at original square
         jmp     @undo_eval           ; -> common unmake completion

; ---------------------------------------------------------------------
; sort_moves - Selection sort on the move list by priority
; Higher piece type = higher priority. Bonus for moves matching
; the best move from the previous iteration ($07/$08 = from/to).
; ---------------------------------------------------------------------
sort_moves:   ldy     next_color+1
         lda     $1445,y          ; best-move from-square from prev iteration
         sta     $07
         lda     $144f,y          ; best-move to-square from prev iteration
         sta     $08
         ldy     #$00             ; start at first move in list
         ; --- outer loop: find best remaining move ---
@outer_loop:  lda     ($8b),y          ; end of list? (null terminator)
         beq     @done
         sty     $0f              ; $0f = current position (slot to fill)
         jsr     @calc_priority           ; compute priority of this move
@save_best:  lda     $11              ; save current best priority
         sta     $12
         sty     $10              ; $10 = index of best move so far
         ; --- inner loop: scan for higher-priority move ---
@inner_loop:  iny
         iny                      ; advance to next move (2 bytes per move)
         lda     ($8b),y          ; end of list?
         beq     @end_pass
         jsr     @calc_priority           ; compute priority
         lda     $12              ; compare with current best
         cmp     $11
         bcs     @inner_loop           ; current best >= this -> keep scanning
         bcc     @save_best           ; found better -> update best

         ; --- swap best move into current slot ---
@end_pass:  lda     $12
         beq     @done           ; priority 0 -> done (empty move?)
         ldy     $0f              ; Y = current slot
         lda     ($8b),y          ; save move at current slot
         sta     $11
         iny
         lda     ($8b),y
         sta     $12
         ldy     $10              ; Y = best move position
         lda     ($8b),y          ; save best move
         sta     $0d
         iny
         lda     ($8b),y
         sta     $0e
         lda     $12              ; write current slot's move to best's position
         sta     ($8b),y
         dey
         lda     $11
         sta     ($8b),y
         ldy     $0f              ; write best move to current slot
         lda     $0d
         sta     ($8b),y
         iny
         lda     $0e
         sta     ($8b),y
         iny                      ; advance past swapped move
         jmp     @outer_loop           ; continue sorting

@done:  rts

         ; --- compute move priority ---
         ; Returns $11 = priority: piece_type*4 + bonus for matching best move
@calc_priority:  iny
         lda     ($8b),y          ; to-square
         dey
         tax
         lda     $146e,x          ; piece at to-square (target)
         and     #$07             ; piece type
         asl     A
         asl     A                ; type * 4
         sta     $11              ; base priority
         bne     @priority_done           ; non-zero type -> check best-move bonus
         lda     $07              ; does from-square match prev best?
         cmp     ($8b),y
         bne     @priority_done           ; no match
         inc     $11              ; +1 for matching from-square
         cpx     $08              ; does to-square match prev best?
         bne     @priority_done
         inc     $11              ; +1 for matching to-square
@priority_done:  rts

; ---------------------------------------------------------------------
; alpha_beta - Recursive alpha-beta minimax search
; Uses ply counter at next_color+1. Scores in $0022+y / $002f+y (lo/hi).
; Moves are iterated from the move list at ($8b)+$8d.
; Cutoffs prune branches where the opponent already has a better option.
; ---------------------------------------------------------------------
alpha_beta:   ldy     $8d              ; current move offset
         lda     ($8b),y            ; null move? (end of move list)
         beq     @end_of_moves             ; -> handle leaf / end of list
         jsr     try_move           ; make move, check legality
         bcc     @legal_move             ; legal move -> proceed
         jmp     @next_move             ; illegal (leaves king in check) -> next move

@legal_move:  ldy     next_color+1       ; current ply depth
         cpy     level+1            ; reached max depth?
         bcs     @at_max_depth             ; -> leaf evaluation
         ; --- recurse deeper ---
@go_deeper:  jsr     @push_ply             ; push_search_state: flip side, inc ply
         jsr     gen_all_moves      ; generate opponent's moves
         jsr     sort_moves         ; sort by priority
         jmp     alpha_beta         ; recurse

         ; --- end of move list (null move encountered) ---
@end_of_moves:  lda     $1d                ; any legal moves found at this ply?
         bne     @check_cutoff             ; yes -> propagate score upward
         ; no legal moves found - check if in check
         dey
         dey
         sty     $8d                ; back up move pointer
         jsr     in_check           ; is current side in check?
         bcc     @not_in_check             ; not in check -> stalemate
         ; checkmate: score = ply index (deeper mate = worse)
         lda     next_color+1
         sta     $61                ; score lo = ply (minimal score)
         lda     #$00
         sta     $62                ; score hi = 0
         jmp     @inc_count

         ; stalemate: score = $80,00 (draw)
@not_in_check:  lda     #$00
         sta     $61
         lda     #$80
         sta     $62
         jmp     @inc_count

         ; --- propagate score upward ($1d flag set) ---
@check_cutoff:  ldy     next_color+1
         cpy     #$01               ; at top level (ply 1)?
         bne     @go_back
         rts                        ; yes -> return to caller

         ; pop search state and negate child's score (minimax negation)
@go_back:  jsr     @pop_ply             ; pop_search_state: flip side, dec ply
         lda     scoreL_stack,y     ; negate the child's score
         eor     #$ff
         clc
         adc     #$01
         sta     $61                ; $61 = -child_score (lo)
         lda     scoreH_stack,y
         eor     #$ff
         adc     #$00
         sta     $62                ; $62 = -child_score (hi)
         jmp     @compare_score             ; -> score comparison

         ; --- leaf evaluation ---
@at_max_depth:  jsr     lazy_eval          ; quick material-based pruning check
         lda     next_color+1
         cmp     level              ; at extended search depth?
         bcc     @undo_and_score
         cmp     level+1
         bne     @undo_and_score
         lda     $69                ; opponent in check? (set by lazy_eval)
         bne     @go_deeper             ; yes -> extend search one more ply
@undo_and_score:  jsr     unmake_move        ; undo the move
@inc_count:  inc     $1d                ; flag: at least one move evaluated

         ; --- score comparison: is this move better than current best? ---
@compare_score:  ldy     next_color+1
         lda     $62                ; new score hi
         cmp     $002f,y            ; compare with best score hi
         bcc     @next_move             ; worse -> skip to next move
         bne     @better_move             ; strictly better -> update best
         lda     $0022,y            ; hi bytes equal: compare lo bytes
         cmp     $61
         bcs     @next_move             ; best >= new -> skip

         ; --- new best move found ---
@better_move:  lda     $61
         sta     $0022,y            ; update best score lo
         lda     $62
         sta     $002f,y            ; update best score hi
         jsr     save_best          ; save this move as best

         ; --- alpha-beta cutoff check ---
         ; negate our best score to compare against parent's bound
         lda     $61
         eor     #$ff
         clc
         adc     #$01
         sta     $61                ; $61 = -best_lo
         lda     $62
         eor     #$ff
         adc     #$00
         sta     $62                ; $62 = -best_hi
         cmp     $002e,y            ; compare -best with parent's score hi
         bcc     @check_cutoff             ; -best < parent -> no cutoff, continue
         bne     @next_move             ; -best > parent -> cutoff! prune remaining
         lda     $0021,y            ; hi equal: compare lo
         cmp     $61
         bcs     @check_cutoff             ; parent >= -best -> no cutoff

         ; --- advance to next move in list ---
@next_move:  ldy     next_color+1
         lda     $8d
         clc
         adc     #$02               ; each move is 2 bytes (from, to)
         sta     $133b,y            ; save move pointer for this ply
         sta     $8d
         jmp     alpha_beta         ; try next move

         ; --- push_search_state: go one ply deeper ---
@push_ply:  lda     next_color         ; flip side to move
         eor     #$80
         sta     next_color
         bmi     @set_ply_ptrs             ; now black's turn? skip move counter
         inc     move_number        ; white moved: increment full-move number
@set_ply_ptrs:  ldy     next_color+1
         lda     $0021,y            ; save parent's alpha bound
         sta     scoreL_stack,y
         lda     $002e,y
         sta     scoreH_stack,y
         inc     next_color+1       ; increment ply counter
         rts

         ; --- pop_search_state: return one ply up ---
@pop_ply:  lda     next_color         ; flip side back
         eor     #$80
         sta     next_color
         bpl     @dec_ply             ; was black's turn? decrement move counter
         dec     move_number
@dec_ply:  dec     next_color+1       ; decrement ply counter
         lda     $1459,y            ; restore child's move list pointer
         sta     $8e                ;   (for potential continuation)
         lda     $1463,y
         sta     $8f
         ldy     next_color+1
         lda     $1459,y            ; restore parent's move list pointer
         sta     $8b
         lda     $1463,y
         sta     $8c
         lda     $133b,y            ; restore parent's move index
         sta     $8d
         jsr     unmake_move        ; undo the move that got us here
         ldy     next_color+1
         cpy     #$01               ; back at top level?
         bne     @pop_done
         lda     $1fe2              ; toggle display indicator
         eor     #$0a               ; flip thinking animation
         ora     #$40
         sta     $1fe2
@pop_done:  rts

; ---------------------------------------------------------------------
; save_best - Save the current best move for the current ply
; At ply 1: updates the principal variation display and saves move.
; At ply 2: saves the "hint" move ($b5/$b6).
; Also records best-move from/to for move ordering in the next iteration
; if the move is not a capture ($1445/$144f arrays).
; ---------------------------------------------------------------------
save_best:   lda     $1327,y          ; was this a capture?
         bne     @check_ply             ; yes -> skip best-move recording
         lda     $0b                ; non-capture: record from-square
         sta     $1445,y            ;   for move ordering (killer move)
         lda     $0c
         sta     $144f,y            ;   record to-square
@check_ply:  cpy     #$01               ; at ply 1 (top level)?
         bne     @ply2             ; no -> check ply 2
         ; --- ply 1: update principal variation ---
         ldx     $8d                ; current move index
         beq     @display_pv             ; first move -> no shift needed
@shift_pv:  lda     $1000,x            ; shift PV buffer right by 2
         sta     $1002,x            ;   to make room for new best move
         dex
         bne     @shift_pv
         lda     $0b                ; insert current best move at front
         sta     $1001              ;   from-square
         lda     $0c
         sta     $1002              ;   to-square
@display_pv:  jsr     show_computer_move ; display the move on screen
         ldy     next_color+1
         lda     $b5                ; rotate previous best moves
         sta     $9f                ;   $9f = previous $b5
         lda     $b6
         sta     $b4                ;   $b4 = previous $b6
         rts

@ply2:  cpy     #$02               ; at ply 2?
         bne     @done             ; no -> done
         lda     $0b                ; save hint move (opponent's best reply)
         sta     $b5                ;   from-square
         lda     $0c
         sta     $b6                ;   to-square
@done:  rts

; ---------------------------------------------------------------------
; lazy_eval - Quick material-based evaluation for search pruning
; Computes rough score from material balance * 2 + $81 (centered).
; If this rough score can't beat the current best, skips the expensive
; full evaluation. Also checks if opponent is in check ($69 flag).
; ---------------------------------------------------------------------
lazy_eval:   lda     level+1
         cmp     level              ; at the deepest non-extended level?
         bcs     @full_eval             ; beyond -> always do full eval
         lda     $6a                ; material balance
         asl     A                  ; double it (amplify material signal)
         sta     $62                ; rough score hi
         lda     #$00
         sta     $61                ; rough score lo = 0
         lda     next_color
         bpl     @adjust_sign             ; white to move -> score is positive
         ; negate for black's perspective
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
         adc     #$81               ; center around $81 (neutral)
         sta     $62
         ldy     next_color+1
         cmp     $002f,y            ; can rough score beat current best?
         bcc     @check_in_check             ; no -> skip full eval (lazy cutoff)
         bne     @full_eval             ; yes, strictly better -> full eval
         lda     $0022,y            ; hi equal: compare lo
         cmp     $61
         bcs     @check_in_check             ; still can't beat -> skip
@full_eval:  jmp     evaluate_position  ; do full static evaluation

         ; --- lazy cutoff: just check if opponent is in check ---
@check_in_check:  lda     next_color
         eor     #$80               ; flip to opponent's color
         jsr     check_color        ; is opponent's king attacked?
         lda     #$00
         rol     A                  ; carry -> 1 if in check
         sta     $69                ; $69 = check extension flag
         rts

; ---------------------------------------------------------------------
; in_check / check_color - Test if a side's king is in check
; in_check: tests the side to move (next_color)
; check_color: tests the specified color (A: $00=white, $80=black)
; Returns carry set if king is attacked.
; ---------------------------------------------------------------------
in_check:   lda     next_color       ; current side to move
check_color:   bmi     @black_king       ; black? -> use black king pos
         ldx     $6c              ; X = white king square
         .byte   $2c              ; BIT abs - skip
@black_king:  ldx     $6d              ; X = black king square
         lda     $146e,x          ; get king piece byte
         sta     $13              ; $13 = king piece (for is_king_attacked)
         jmp     is_king_attacked ; check if any enemy piece attacks X

; ---------------------------------------------------------------------
; calc_move - Top-level search driver (iterative deepening)
; Initializes board evaluation, generates root moves, tries the
; opening book, then runs alpha-beta at increasing depths.
; Manages aspiration windows and checks node count limits.
; Returns with the best move in $1001/$1002.
; ---------------------------------------------------------------------
calc_move:
         jsr     init_material      ; compute material balance, find kings
         lda     #$00
         sta     $1e                ; clear search flags
         sta     $70                ; clear node counter lo
         sta     $71                ; clear node counter hi
         ldx     #$0a               ; clear arrays (10 entries)
@clear_loop:  sta     $1445,x            ; clear best-move from-squares
         sta     $144f,x            ; clear best-move to-squares
         sta     $20,x              ; clear alpha bounds
         sta     $2d,x              ; clear beta bounds
         dex
         bne     @clear_loop
         lda     #$01               ; set up root move list buffer
         sta     $8e                ;   at $1001
         lda     #$10
         sta     $8f
         lda     #$01
         sta     level+1            ; start at depth 1
         jsr     gen_all_moves      ; generate all root moves
         lda     $8e                ; save root move list pointer
         sta     $145b
         lda     $8f
         sta     $1465
         lda     $1c                ; opening book exhausted?
         bne     @iter_loop             ; yes -> skip book
         jsr     opening_book       ; try to play from opening book

         ; --- iterative deepening loop ---
@iter_loop:  lda     level+1            ; display current search depth
         ora     #$70               ;   as screen code digit
         sta     $1fe3              ;   on screen
         jsr     alpha_beta         ; run search at current depth
         lda     scoreH_stack       ; check result: mate found?
         beq     @done             ; score hi = 0 -> mate for opponent, stop
         cmp     #$ff
         bne     @deepen             ; score hi != $ff -> not our mate
@done:  rts                        ; mate detected -> done

         ; --- increase depth and manage aspiration window ---
@deepen:  inc     level+1            ; go one ply deeper
         lda     level+1
         cmp     #$03               ; at least depth 3 before windowing?
         bcc     @check_depth             ; no -> just search again
         cmp     level              ; reached configured max level?
         bcs     @check_window             ; yes -> check window adjustment
         jmp     @restart_search             ; below max level -> re-search

         ; --- aspiration window check ---
@check_window:  lda     scoreH_stack       ; did score beat the upper bound (fail high)?
         cmp     $2e
         bcc     @fail_low             ; score < beta -> fail low (flip window)
         bne     @widen_beta
         lda     $21
         cmp     scoreL_stack
         bcs     @fail_low             ; score <= alpha -> fail low
         ; --- score is within or above window: widen ---
@widen_beta:  lda     scoreL_stack       ; negate the score
         eor     #$ff
         clc
         adc     #$01
         sta     $61
         lda     scoreH_stack
         eor     #$ff
         adc     #$00
         sta     $62
         cmp     $2f               ; did negated score beat lower bound?
         bcc     @fail_high            ; yes -> fail high from opponent's view
         bne     @set_window
         lda     $22
         cmp     $61
         bcs     @fail_high
         ; --- widen window by $20 (32) in both directions ---
@set_window:  lda     #$e0               ; -$20 = $e0 (widen alpha down)
         clc
         adc     scoreL_stack
         sta     $21                ; new alpha lo = score - $20
         lda     scoreH_stack
         adc     #$ff
         sta     $2e                ; new alpha hi
         lda     #$e0               ; widen beta down
         clc
         adc     $61
         sta     $22                ; new beta lo = -score - $20
         lda     $62
         adc     #$ff
         sta     $2f                ; new beta hi

         ; --- depth limit and node count checks ---
@check_depth:  lda     level+1
         cmp     #$0a               ; absolute max depth = 10?
         beq     @done             ; yes -> stop searching
         cmp     level              ; at configured max level?
         beq     @restart_search             ; yes -> re-search at this depth
         ldx     level
         lda     $71                ; node counter hi
         cmp     node_limits,x      ; exceeded node limit for this level?
         bcs     @done             ; yes -> stop searching
         bcc     @restart_search             ; no -> re-search

         ; --- fail low: flip and widen window ---
@fail_low:  lda     $21                ; swap and negate alpha -> beta
         eor     #$ff
         sta     $22
         lda     $2e
         eor     #$ff
         sta     $2f
         lda     #$00               ; reset alpha to zero
         sta     $21
         sta     $2e
         beq     @dec_depth             ; always taken -> decrease depth

         ; --- fail high: flip and widen window ---
@fail_high:  lda     $22                ; swap and negate beta -> alpha
         eor     #$ff
         sta     $21
         lda     $2f
         eor     #$ff
         sta     $2e
         lda     #$00               ; reset beta to zero
         sta     $22
         sta     $2f
@dec_depth:  dec     level+1            ; decrease depth (re-search wider)

         ; --- re-search: reset state and loop ---
@restart_search:  lda     #$00
         sta     $8d                ; reset move index to start of list
         sta     $133c              ; clear ply 1 move pointer
         lda     $21                ; set initial alpha from window
         sta     scoreL_stack
         lda     $2e
         sta     scoreH_stack
         lda     $9f                ; restore best move from prev iteration
         sta     $b5
         lda     $b4
         sta     $b6
         lda     $145b              ; restore root move list pointer
         sta     $8e
         lda     $1465
         sta     $8f
         jmp     @iter_loop             ; -> re-enter iterative deepening loop

; ---------------------------------------------------------------------
; init_material - Initialize material balance and locate kings
; Scans all board squares ($15-$62). Tallies piece values into $6a
; (positive for white, negative for black). Records king positions
; in $6c (white) and $6d (black). If total material < $2e (endgame)
; and |material_balance| >= 5, enables king proximity evaluation.
; ---------------------------------------------------------------------
init_material:   lda     #$00
         sta     level+2            ; clear endgame flag
         sta     $6a                ; clear material balance
         sta     $07                ; clear total material accumulator
         ldx     #$15               ; first board square
@piece_loop:  lda     $146e,x            ; get piece at square
         beq     @next_sq             ; empty -> skip
         cmp     #$ff               ; border sentinel?
         beq     @next_sq             ; yes -> skip
         sta     $13
         and     #$07               ; extract piece type
         tay
         cmp     #$06               ; king?
         bne     @add_value
         lda     $13                ; record king position
         bmi     @bk_king             ; black king?
         stx     $6c                ; save white king square
         bne     @add_value             ; always taken
@bk_king:  stx     $6d                ; save black king square
@add_value:  lda     $13
         bmi     @sub_value             ; black piece?
         lda     $6a                ; white piece: add value
         clc
         adc     piece_values,y
         jmp     @store_bal

@sub_value:  lda     $6a                ; black piece: subtract value
         sec
         sbc     piece_values,y
@store_bal:  sta     $6a
         lda     $07                ; accumulate total material (unsigned)
         clc
         adc     piece_values,y     ; total += piece value
         sta     $07
@next_sq:  inx                        ; next square
         cpx     #$63               ; past last square?
         bcc     @piece_loop             ; no -> continue scanning
         ; --- endgame detection ---
         lda     $07
         cmp     #$2e               ; total material >= 46?
         bcs     @done             ; yes -> not endgame
         lda     $6a                ; |material_balance|
         bpl     @check_endgame
         eor     #$ff               ; negate if negative
         clc
         adc     #$01
@check_endgame:  cmp     #$05               ; imbalance >= 5 pawns?
         bcc     @done             ; no -> no king proximity needed
         sta     level+2            ; enable endgame king proximity eval
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

; ---------------------------------------------------------------------
; opening_book - Look up and play moves from the opening book
; The book is a tree: each node has a bit-count byte (# of children),
; followed by move-index bytes, followed by 2-byte child pointers
; ($FF = leaf). Move indices are board square indices / 2 ($9c).
; Uses VIC raster register as random seed to vary play.
; On success, pops return address and exits calc_move directly.
; ---------------------------------------------------------------------
opening_book:   lsr     $9c              ; square index / 2 = book move code
         ldy     #$00
         lda     move_number
         cmp     #$01               ; first move of the game?
         bne     @search_book             ; no -> search for opponent's move
         ; --- initialize book pointer to root ---
         lda     #<lopenings
         sta     opening_ptr
         lda     #>lopenings
         sta     opening_ptr+1
         lda     human_color        ; human playing white?
         beq     @select_move             ; yes -> computer picks a response

         ; --- search for opponent's last move in book tree ---
@search_book:  lda     (opening_ptr),y    ; bit-count byte: bits set = # children
         ldx     #$01               ; X = child counter (start at 1)
@count_children:  lsr     A                  ; count set bits
         bcc     @shift_bits
         inx                        ; one more child
@shift_bits:  cmp     #$00
         bne     @count_children             ; continue until all bits shifted out
         lda     $9c                ; move code to search for
         iny                        ; Y points to first move-index byte
@match_move:  cmp     (opening_ptr),y    ; does this child match?
         beq     @found_match             ; yes -> descend to that child
         dex                        ; one fewer child to check
         beq     @book_fail             ; no more children -> book exhausted
         jsr     next_child         ; skip to next sibling
         bcc     @match_move             ; continue searching
         ; --- opponent's move not in book ---
@book_fail:  lda     #$50               ; mark book as exhausted
         sta     $1c
         rts

         ; --- found opponent's move: descend ---
@found_match:  jsr     goto_child         ; follow pointer to child node
         bcc     @select_move             ; success -> pick our response
         rts                        ; leaf node ($FF) -> book exhausted

         ; --- pick a random response from available children ---
@select_move:  ldy     #$00
         lda     (opening_ptr),y    ; bit-count byte
         ora     #$80               ; set high bit as sentinel for shifting
         sta     $0d                ; $0d = child selector (shifts right)
         iny
         lda     vic_raster         ; VIC raster line = random seed
         sta     $0e                ; $0e = random bits (shifts right)
@random_loop:  lsr     $0e                ; consume one random bit
         bcs     @play_move             ; bit=1 -> select current child
         lda     $0d                ; bit=0 -> try next child
         beq     @use_first             ; all children exhausted -> wrap to first
         lsr     $0d                ; shift child selector
         bcc     @random_loop             ; bit was 0 (no child here) -> continue
         jsr     next_child         ; skip past this child's pointer
         bne     @random_loop             ; always taken -> try next random bit
@use_first:  ldy     #$01               ; wrap around: select first child

         ; --- play the selected book move ---
@play_move:  lda     (opening_ptr),y    ; get move-index byte
         asl     A                  ; * 2 = move list offset
         sta     $8d                ; set as current move pointer
         jsr     goto_child         ; advance book pointer to chosen child
         jsr     make_move          ; execute the move on the board
         jsr     unmake_move        ; undo it (save_best will record it)
         jsr     save_best          ; save as the chosen move
         lda     #$50               ; set score hi to $50 (book move marker)
         sta     scoreH_stack
         lda     #$00
         sta     scoreL_stack
         pla                        ; pop return address (skip rest of calc_move)
         pla
         rts                        ; return directly to calc_move's caller

; --- goto_child: advance opening_ptr to a child node ---
; Reads 2-byte pointer at (opening_ptr)+Y. If $FF: leaf (book end).
; Returns carry clear on success, carry set if leaf.
goto_child:
         iny                        ; skip past move-index byte
         lda     (opening_ptr),y    ; child pointer lo
         cmp     #$ff               ; leaf sentinel?
         beq     @end_of_book             ; yes -> book exhausted
         sta     $0d                ; save pointer lo
         iny
         lda     (opening_ptr),y    ; child pointer hi
         sta     opening_ptr+1      ; update opening_ptr
         lda     $0d
         sta     opening_ptr
         clc                        ; success
         rts

@end_of_book:  sta     $1c                ; mark book as exhausted ($ff)
         sec                        ; failure
         rts

; --- next_child: skip to the next sibling in the book ---
; Advances Y past the current child's 2-byte pointer (or 1-byte $FF leaf).
; Preserves A in $0f. Returns carry clear.
next_child:
         sta     $0f                ; save A (move code being searched)
         iny                        ; skip move-index byte
         lda     (opening_ptr),y    ; read pointer byte
         cmp     #$ff               ; leaf? (only 1 byte, not 2)
         beq     @skip_ptr             ; yes -> skip only 1 byte
         iny                        ; skip pointer hi byte (2-byte pointer)
@skip_ptr:  iny                        ; advance to next sibling's move-index
         lda     $0f                ; restore A
         clc
         rts

