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
@LA020:  sta     $1dff,x        ; fill $1e00-$1efc (first page)
         sta     $1efc,x        ; fill $1efd-$1ff9 (second page)
         dex
         bne     @LA020
         rts

; draw_board_row - draw one row of the chess board on screen
; Uses ZP pointers: $57-$58 = screen dest, $59-$5a = source graphics,
;                   $5b-$5c = color RAM dest (screen + $7800)
; Copies 5 chars per cell across 15 rows to render the board grid.
draw_board_row:   pha
         ldx     #$03           ; copy 4 initial pointer bytes
@LA02D:  lda     @LA06A,x       ; load initial pointer values
         sta     $57,x          ; store to ZP pointers ($57-$5a)
         dex
         bpl     @LA02D
         ldx     #$0f           ; 15 rows to draw
@LA037:  ldy     #$00
         lda     $57            ; copy screen ptr low to color ptr
         sta     $5b
         clc
         lda     $58            ; color RAM = screen + $7800
         adc     #$78
         sta     $5c
@LA044:  lda     ($59),y        ; read source graphics char
         sta     ($57),y        ; write to screen RAM
         lda     #$01           ; white color
         sta     ($5b),y        ; write to color RAM
         iny
         cpy     #$05           ; 5 characters per cell
         bcc     @LA044
         lda     $5a            ; advance source ptr: swap high bytes
         sta     $58
         lda     $59            ; previous source low -> screen dest low
         sta     $57
         clc
         adc     #$16           ; advance source by 22 (screen width)
         sta     $59
         bcc     @LA062
         inc     $5a            ; carry into high byte
@LA062:  dex
         bne     @LA037
         jsr     clear_input_area
         pla
         rts

; Initial pointer values for draw_board_row
; $57-$58 = $1e11 (screen dest), $59-$5a = $1e27 (source graphics)
@LA06A:  .byte   $11            ; screen dest low byte
         .byte   $1e            ; screen dest high byte
         .byte   $27            ; source graphics low byte
         .byte   $1e            ; source graphics high byte

; clear_input_area - clear the 5-char input display area at bottom of board
; Fills screen $1f5b-$1f5f with space ($60) and sets color to white
clear_input_area:   ldy     #$04           ; 5 characters (0-4)
@LA070:  lda     #$60           ; space character (shifted)
         sta     $1f5b,y        ; clear screen position
         lda     #$01           ; white
         sta     $975b,y        ; set color RAM (screen + $7800)
         dey
         bpl     @LA070
         rts

; redraw_all_rows - redraw all 15 board rows
redraw_all_rows:   lda     #$0f           ; 15 rows
         sta     $00            ; loop counter
@LA082:  jsr     refresh_board
         dec     $00
         bne     @LA082
         rts

; handle_char_display - process a character for the move notation display
; If RETURN, resets board. Otherwise adds to 6-char buffer, wrapping when full.
handle_char_display:   ldx     $f9            ; current display position
         cmp     #$0d           ; RETURN key?
         beq     refresh_board  ; yes: redraw board and reset position
         inx
         cpx     #$06           ; display buffer full (6 chars)?
         bcc     @LA098         ; no: display the character
         jsr     refresh_board  ; yes: wrap - redraw board first
@LA098:  jmp     display_input_char

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
         bne     @LA0BB         ; skip clear if mid-input
         jsr     clear_input_area
@LA0BB:  jsr     draw_board_frame
         pla
         bit     $1f            ; check joystick flag (bit 7)
         bpl     @LA0C6         ; no joystick: continue with keyboard
         jmp     joystick_move  ; handle joystick input instead

@LA0C6:  cmp     #$0d           ; filter: ignore chars below RETURN
         bcc     get_move_loop
         cmp     #$4a           ; filter: ignore chars >= 'J'
         bcs     get_move_loop
         cmp     #$14           ; DELETE key?
         beq     get_move_delete
         cmp     #$0d           ; RETURN key?
         beq     @LA0E2
         ldy     $00            ; check buffer length
         cpy     #$05           ; max 5 characters?
         bcs     get_move_loop  ; buffer full: ignore
         jsr     buffer_input_char
         jmp     get_move_loop

@LA0E2:  jsr     process_input_char ; process RETURN
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
         bne     @LA105         ; key pressed: check which key
         jsr     read_joystick  ; no key: check joystick
         beq     poll_keyboard  ; no joystick either: keep polling
         lda     #$80           ; joystick active: set flag bit 7
         sta     $1f
@LA104:  rts

@LA105:  cmp     #$3f           ; '?' key?
         bne     @LA104         ; no: return with key in A
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
         beq     @LA13C
         cmp     #$0d           ; RETURN?
         beq     @LA14D         ; yes: reset position
         inx
         cpx     #$06           ; display full?
         bcc     display_input_char ; no: show the character
         rts                    ; yes: ignore

; Handle DELETE: erase character at current position
@LA13C:  lda     #$60           ; space character (shifted)
         cpx     #$00           ; at start of line?
         beq     @LA14D         ; yes: just reset
         sta     $1f5a,x        ; blank the character on screen
         dex
         beq     @LA14A         ; reached position 0
         bmi     @LA14D         ; underflow: reset
@LA14A:  stx     $f9            ; update display position
         rts

; Reset display position to 0
@LA14D:  ldx     #$00
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
@LA168:  dex                    ; inner loop
         bne     @LA168
         dey                    ; outer loop
         bne     @LA168
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
@LA174:  stx     $07            ; store current board position
@LA176:  jsr     highlight_square       ; blink current square
         jsr     read_joystick          ; check joystick/keys
         beq     @LA176                 ; no input, keep blinking
         cmp     #$0d                   ; RETURN/fire?
         beq     @LA188                 ; yes: select square
         jsr     handle_cursor          ; translate direction to board move
         jmp     @LA174                 ; loop with updated position

@LA188:  ldx     #$dc                   ; beep on selection
         jsr     play_beep
         lda     $ab                    ; file (0-7)
         clc
         adc     #$41                   ; convert to ASCII 'A'-'H'
         jsr     @LA1C5                 ; store in input buffer
         lda     $ac                    ; rank (0-7)
         eor     #$07                   ; flip rank (board is top-down)
         clc
         adc     #$31                   ; convert to ASCII '1'-'8'
         jsr     @LA1C5                 ; store in input buffer
         lda     $1f                    ; check move phase
         and     #$01
         bne     @LA1B0                 ; bit 0 set = to-square done
         lda     #$2d                   ; '-' separator between squares
         jsr     @LA1C5
         lda     #$81                   ; set flag: from-square entered
         sta     $1f
         bne     @LA176                 ; loop for to-square

@LA1B0:  ldx     #$05                   ; copy move from $0200 to $033c
@LA1B2:  lda     $0200,x
         sta     $033c,x
         dex
         bpl     @LA1B2
@LA1BB:  jsr     read_joystick          ; wait for joystick release
         bne     @LA1BB
         sta     $1f                    ; clear move phase flag
         jmp     get_move_done

; Store character to input buffer and echo it
@LA1C5:  ldy     $00                    ; current buffer index
         inc     $00
         sta     $0200,y
         jmp     process_input_char

; ---------------------------------------------------------------------
; read_joystick - Read VIC-20 joystick/keyboard via VIA registers
; Reads VIA port B ($9120/$9122) for fire button, VIA port A ($9111)
; for directions. Returns direction code in A:
;   $91=left, $11=right, $9d=up, $0d=down, $00=none
; Fire button returns $1d (same as cursor-right, acts as RETURN).
; ---------------------------------------------------------------------
read_joystick:   sei
         ldx     #$7f                   ; set VIA port B bit 7 as input
         stx     $9122                  ; write DDR-B
@LA1D5:  lda     $9120                  ; read port B (debounce: read twice)
         cmp     $9120
         bne     @LA1D5
         ldx     #$ff                   ; restore DDR-B to all outputs
         stx     $9122
         ldx     #$f7                   ; clear bit 3 of port B
         stx     $9120                  ; (active-low joystick select)
         cli
         and     #$80                   ; test fire button (bit 7)
         bne     @LA1EF                 ; not pressed: check directions

         .byte   $a9                    ; LDA #$1d (fire = cursor-right)
         .byte   $1d
         .byte   $60                    ; RTS

@LA1EF:  ldy     $9111                  ; read VIA port A (debounce)
         cpy     $9111
         bne     @LA1EF
         ldx     #$04                   ; check 4 direction bits
@LA1F9:  tya
         and     @LA206,x              ; test against bitmask
         beq     @LA202                 ; zero = direction active (active-low)
         dex
         bpl     @LA1F9
@LA202:  lda     @LA20B,x              ; look up result code
         rts

; Joystick direction bitmasks (active-low bits from VIA port A)
@LA206:  .byte   $00                    ; (sentinel - no match)
         .byte   $04                    ; left
         .byte   $08                    ; right
         .byte   $10                    ; up
         .byte   $20                    ; down
; Joystick direction result codes
@LA20B:  .byte   $00                    ; none
         .byte   $91                    ; left  (cursor-down key code)
         .byte   $11                    ; right (cursor-down reversed)
         .byte   $9d                    ; up    (cursor-left key code)
         .byte   $0d                    ; down  (RETURN key code)

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
         beq     @LA248
         ldy     #$f8                   ; wrap offset: cursor-right
         ldx     #$01                   ; delta: +1 (right)
         cmp     #$1d
         beq     @LA248
         ldy     #$b0                   ; wrap offset: cursor-down
         ldx     #$0a                   ; delta: +10 (down)
         cmp     #$91
         beq     @LA248
         ldy     #$50                   ; wrap offset: cursor-up
         ldx     #$f6                   ; delta: -10 (up)
         cmp     #$11
         beq     @LA248
         ldy     #$ff                   ; unknown key: no change
         rts

@LA248:  txa                            ; apply delta to current position
         clc
         adc     $07
         tax
         lda     $146e,x                ; check board array
         cmp     #$ff                   ; border sentinel?
         bne     @LA25B                 ; no: position is valid
         sty     $07                    ; yes: apply wrap offset
         txa
         clc
         adc     $07
         tax
@LA25B:  rts

; ---------------------------------------------------------------------
; flash_square / flash_n_times - Flash a board square
; flash_square: flashes 16 times. flash_n_times: count in A -> $a8.
; Toggles reverse video with a delay loop between each flash.
; ---------------------------------------------------------------------
flash_square:   lda     #$10           ; 16 flashes
flash_n_times:   sta     $a8            ; flash counter
@LA260:  jsr     flash_piece            ; toggle reverse video
         ldy     #$30                   ; delay loop
@LA265:  dex
         bne     @LA265
         dey
         bne     @LA265
         dec     $a8                    ; next flash
         bne     @LA260
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
         beq     @LA27E
         lda     #$80                   ; $80 = dark, $00 = light
@LA27E:  sta     $a9
         jsr     draw_blank_square      ; erase piece from source
         lda     $ad                    ; set destination coordinates
         sta     $ab
         lda     $ae
         sta     $ac
         lda     $aa                    ; piece byte
         beq     @LA295                 ; empty = no piece to draw
         jsr     draw_piece             ; draw piece at destination
         jsr     flash_square           ; flash at destination
@LA295:  rts

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
         beq     @LA2C0                 ; type 0 = empty square
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
         bmi     @LA2BE                 ; bit 7 set = black piece
         lda     #$00                   ; white piece: $a9 = $00
         beq     @LA2C0

@LA2BE:  lda     #$80                   ; black piece: $a9 = $80
@LA2C0:  sta     $a9
         lda     $a7                    ; piece type (with color bit)
         bne     @LA2D7                 ; non-empty: render it
         lda     #$01                   ; empty square: use blank entry
         sta     $a5
         clc
         lda     $ab                    ; determine blank square shade
         adc     $ac
         and     #$01
         beq     @LA2D5
         lda     #$80                   ; dark square
@LA2D5:  sta     $a9
@LA2D7:  jsr     render_piece
         rts

; ---------------------------------------------------------------------
; decode_piece_gfx - Decode piece byte into graphics table index
; Input: $aa = raw piece byte (bit7=color, bit6=moved, bits2-0=type)
; Maps piece type (1-6) to character table offset via @LA2EB lookup.
; Output: $aa = graphics index for piece_char_map
; ---------------------------------------------------------------------
decode_piece_gfx:   lda     $aa
         rol     A                      ; save bit 7 (color) in carry
         php
         ror     A                      ; restore A
         and     #$07                   ; isolate piece type (0-6)
         tax
         lda     @LA2EB,x              ; look up graphics offset
         plp                            ; restore carry (color bit)
         ror     A                      ; shift color into high bit of offset
         sta     $aa
         rts

; Piece type to graphics offset lookup table
; Index: 0=empty, 1=pawn, 2=knight, 3=bishop, 4=rook, 5=queen, 6=king
@LA2EB:  .byte   $00                    ; empty
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
@LA34D:  jsr     add_screen_offset      ; result: rank * 44 (2 screen rows)
         dex
         bne     @LA34D
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
         bcc     @LA381
         inc     $a4
@LA381:  jsr     calc_color_pos
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
@LA395:  lda     piece_char_map,x       ; get character code
         eor     $a9                    ; apply square color
         eor     #$80                   ; toggle reverse video bit
         sta     ($a3),y                ; write to screen RAM
         lda     #$01                   ; color = white
         sta     ($f7),y                ; write to color RAM
         dex
         dey
         bpl     @LA395                 ; next char in this row
         ldy     #$01                   ; reset column index
         lda     #$16                   ; advance one screen row (22 cols)
         jsr     add_screen_offset
         dec     $a5                    ; next row of 2x2 grid
         bne     @LA395
         rts

; ---------------------------------------------------------------------
; flash_piece - Flash a piece by toggling reverse video (XOR $80)
; XORs all 4 screen chars of the 2x2 piece grid with $80.
; ---------------------------------------------------------------------
flash_piece:   jsr     calc_screen_pos
@LA3B5:  lda     ($a3),y                ; read screen character
         eor     #$80                   ; toggle reverse video
         sta     ($a3),y
         dey
         bpl     @LA3B5
         ldy     #$01
         jsr     advance_row
         dex
         bne     @LA3B5
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
@LA3D4:  lda     $146e,x                ; read piece at square
         cmp     #$ff                   ; border sentinel?
         beq     @LA3F4                 ; skip borders
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
@LA3F4:  inx
         cpx     #$63                   ; last valid square + 1
         bne     @LA3D4
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
@LA40D:  lda     #$80                   ; blank space (top row of rank pair)
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
         bne     @LA40D
         ldy     #$00                   ; draw file letters (A-H) at bottom
         lda     #$41                   ; 'A'
         sta     $a5
@LA431:  lda     #$80                   ; space before letter
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
         bne     @LA431
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
@LA492:  iny
         lda     ($a5),y
         bne     @LA492
         tya                            ; Y = string length
         lsr     A                      ; length / 2
         sta     $a7
         lda     #$08                   ; centering offset
         sec
         sbc     $a7                    ; (22/2 - 3) - len/2
         jsr     add_screen_offset      ; advance screen pointer
         ldy     #$00
@LA4A5:  lda     ($a5),y                ; get next character
         beq     @LA4B4                 ; null terminator: done
         ora     #$40                   ; PETSCII to screen code
         sta     ($a3),y                ; write to screen RAM
         lda     #$01                   ; white color
         sta     ($f7),y                ; write to color RAM
         iny
         bne     @LA4A5
@LA4B4:  rts

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
@LA4C2:  lda     #$80                   ; blank character
         sta     ($a3),y
         lda     $20                    ; background color
         sta     ($f7),y
         dey
         bpl     @LA4C2
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
@LA4DD:  lda     ($57),y                ; copy ROM char data
         sta     ($59),y
         inc     $57
         inc     $59
         bne     @LA4EB
         inc     $58
         inc     $5a
@LA4EB:  lda     $5a                    ; done when dest reaches $1c00
         cmp     #$1c
         bne     @LA4DD
         lda     $59
         bne     @LA4DD
         sta     $5b                    ; inverted dest low = $1800
         lda     #$18
         sta     $5c                    ; inverted dest high
         lda     #$1c
         sta     $5a                    ; normal dest = $1c00
         lda     #<white_patterns       ; load white piece patterns
         sta     $57
         lda     #>white_patterns
         sta     $58
         jsr     @LA518                 ; copy + invert
         lda     #$d8                   ; set dest for black patterns
         sta     $59
         sta     $5b
         lda     #<black_patterns       ; load black piece patterns
         sta     $57
         lda     #>black_patterns
         sta     $58
@LA518:  ldy     #$00                   ; copy 216 bytes ($d8)
@LA51A:  lda     ($57),y                ; read pattern byte
         sta     ($59),y                ; store normal version
         eor     #$ff                   ; invert all bits
         sta     ($5b),y                ; store inverted version
         iny
         cpy     #$d8                   ; 27 chars * 8 bytes = 216
         bne     @LA51A
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
; +223: piece_values    - Material values: [0]=4,P=1,N=3,B=3,R=5,Q=9,K=10
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
; piece_values: material value by type [0]=4,P=1,N=3,B=3,R=5,Q=9,K=10
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
         .byte   $c6,$b1,$a0,$d4,$cf,$a0,$d3,$d4,$c1,$d2,$d4,$00  ; "F1 TO START"
; "GAME OR SETUP (G,S):"
lgame_or_setup:
         .byte   $13
         .byte   $0d
         .byte   $c7,$c1,$cd,$c5,$a0,$cf,$d2,$a0,$d3,$c5,$d4,$d5,$d0,$a0,$a8,$c7
         .byte   $ac,$d3,$a9,$ba,$00
; "YOUR COLOR (B,W):"
lchoose_color:
         .byte   $0d
         .byte   $d9,$cf,$d5,$d2,$a0,$c3,$cf,$cc,$cf,$d2,$a0,$a8,$c2,$ac,$d7,$a9
         .byte   $ba,$00
; "LEVEL OF PLAY (0-6):"
lchoose_level:
         .byte   $cc,$c5,$d6,$c5,$cc,$a0,$cf,$c6,$a0,$d0,$cc,$c1,$d9,$a0,$a8,$b0
         .byte   $ad,$b6,$a9,$ba,$00
; "NEXT COLOR(B,W):"
lnextcolor:
         .byte   $ce,$c5,$d8,$d4,$a0,$c3,$cf,$cc,$cf,$d2,$a8,$c2,$ac,$d7,$a9,$ba
         .byte   $00
; "MOVE NUMBER (NN):"
lmovenum:
         .byte   $cd,$cf,$d6,$c5,$a0,$ce,$d5,$cd,$c2,$c5,$d2,$a0,$a8,$ce,$ce,$a9
         .byte   $ba,$00
; "ADAPTED BY ANDY FINKEL"
ladapted:
         .byte   $0d,$0d,$0d,$0d,$35,$0d
         .byte   $c1,$c4,$c1,$d0,$d4,$c5,$c4,$a0,$c2,$d9,$a0,$c1,$ce,$c4,$d9,$a0
         .byte   $c6,$c9,$ce,$cb,$c5,$cc,$00
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
@LA918:  lda     vic_init_regs-1,y      ;   from vic_init_regs table
         sta     $8fff,y                ;   into $9000-$900f
         dey
         bne     @LA918
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
@LA93B:  lda     next_color             ; whose turn is it?
         cmp     human_color            ; if next_color == human_color,
         bne     @LA94C                 ;   SARGON plays (colors are swapped)
         sei                            ; disable interrupts for engine
         jsr     sargon_moves           ; computer makes its move
         cli
         jsr     @next_move             ; flip side and update move number
         jmp     @LA93B

@LA94C:  lda     #$03                   ; human's turn
         sta     $97a7                  ; set cursor color attribute
         jsr     human_moves            ; get and validate human's move
         jsr     @next_move             ; flip side and update move number
         jmp     @LA93B

; Flip next_color (white↔black), increment move_number after white moves
@next_move:
         lda     next_color
         eor     #$80                   ; toggle color (bit 7: 0=white, $80=black)
         sta     next_color
         bne     @LA967                 ; if now black's turn, skip increment
         inc     move_number            ; white just moved → next full move
         jmp     show_move_number

@LA967:  rts

; --- Welcome screen: show logo, wait for F1 or handle screen adjustments ---
@welcome:
         jsr     init_board_display     ; set up board display area
         ldx     #<lwelcome_msg
         ldy     #>lwelcome_msg
         jsr     input_string           ; display welcome message + SARGON II logo
@LA972:  jsr     k_getchar              ; wait for keypress
         cmp     #$85                   ; F1 pressed?
         beq     @LA9E4                 ;   yes → proceed to game/setup choice
         ldx     $028d                  ; check modifier keys
         cpx     #$07                   ; C=+CTRL+SHIFT?
         beq     @LA986                 ;   yes → show adapted-by credits
         jsr     @screen_x_offset       ; handle screen adjustment keys
         jmp     @LA972

@LA986:  jsr     set_board_cursor       ; show "adapted by" credits
         ldx     #<ladapted
         ldy     #>ladapted
         jsr     $ad27                  ; print string
         jmp     @LA972

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
         bne     @LA9E3
         inc     $20                    ; next foreground color
         lda     $20
         and     #$07                   ; wrap to 0-7
         sta     $20
         lda     $900f
         and     #$f8                   ; clear lower 3 bits
         ora     $20                    ; set new foreground color
         sta     $900f
@LA9E3:  rts

; --- Game or Setup choice ---
@LA9E4:  jsr     clear_fill_screen
         ldx     #<lgame_or_setup       ; "GAME OR SETUP (G,S)"
         ldy     #>lgame_or_setup
         jsr     input
         cmp     #$53                   ; 'S' for Setup?
         beq     @LA9F5
         jmp     @LAA65                 ; 'G' (or anything else) → new game

; --- Setup mode: edit board, then prompt for game state ---
@LA9F5:  jsr     board_editor           ; enter board editor
         jsr     clear_fill_screen
@LA9FB:  ldx     #<lnextcolor           ; "NEXT COLOR (W,B)"
         ldy     #>lnextcolor
         jsr     input
         ldx     #$00                   ; $00 = white
         cmp     #'W'
         beq     @LAA0E
         cmp     #'B'
         bne     @LA9FB                 ; invalid → ask again
         ldx     #$80                   ; $80 = black
@LAA0E:  stx     next_color
         lda     #$01
         sta     $1c
         ldx     #<lmovenum             ; "MOVE NUMBER?"
         ldy     #>lmovenum
         jsr     input_string
         lda     #$00
         sta     move_number
; Parse 1- or 2-digit move number from keyboard input
@LAA1F:  jsr     @LAA55                 ; get first digit (or RETURN)
         cmp     #$0d                   ; skip leading RETURNs
         beq     @LAA1F
         pha                            ; save first digit
         ora     #$80
         jsr     k_out_to_channel       ; echo it
         jsr     @LAA55                 ; get second digit (or RETURN)
         cmp     #$0d
         beq     @LAA49                 ; only 1 digit → skip tens calc
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
@LAA49:  pla                            ; units digit
         sec
         sbc     #$30                   ; convert ASCII → value
         clc
         adc     move_number            ; add to tens
         sta     move_number
         jmp     @LAA72                 ; skip normal init, go to color/level

; Helper: wait for a digit key (0-9) or RETURN
@LAA55:  jsr     wait_for_keypress
         cmp     #$0d                   ; RETURN?
         beq     @LAA64
         cmp     #$30                   ; < '0'?
         bcc     @LAA55                 ;   ignore
         cmp     #$3a                   ; > '9'?
         bcs     @LAA55                 ;   ignore
@LAA64:  rts

; --- Normal game init: white moves first, move 1, fresh board ---
@LAA65:  lda     #$00
         sta     next_color             ; white to move
         sta     $1c
         lda     #$01
         sta     move_number            ; start at move 1
         jsr     init_board             ; set up initial piece positions

; --- Common path: choose color and difficulty level ---
@LAA72:  ldx     #<lchoose_color        ; "YOUR COLOR (W,B)"
         ldy     #>lchoose_color
         jsr     input
         ldx     #$80                   ; assume black ($80)
         cmp     #'W'
         beq     @LAA85
         cmp     #'B'
         bne     @LAA72                 ; invalid → ask again
         ldx     #$00                   ; white ($00)
@LAA85:  stx     human_color
@LAA87:  ldx     #<lchoose_level        ; "LEVEL (0-6)"
         ldy     #>lchoose_level
         jsr     input
         cmp     #'0'                   ; validate range 0-6
         bcc     @LAA87
         cmp     #'7'
         bcs     @LAA87
         and     #$0f                   ; convert ASCII to value
         sta     level
         lda     #$00                   ; clear move history ($12fe-$1319)
         ldx     #$1b
@LAA9E:  sta     $12fe,x
         dex
         bpl     @LAA9E
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
@LAAAF:  sta     $146e,x                ; fill entire board array
         dex
         bpl     @LAAAF
         ldx     #$08                   ; 8 files (columns)
         ldy     #$00
@LAAB9:  lda     initial_pieces,y       ; white back rank piece type
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
         bne     @LAAB9
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
         bne     @LAAF6                 ; scoreH != 0 → not immediate mate
         lda     scoreL_stack
         cmp     #$01                   ; scoreH=0, scoreL=1 → checkmate
         beq     @mate0
@LAAF6:  jsr     check_draw             ; check for stalemate/draw
         bcs     @stalemate             ; carry set → stalemate
         jsr     push_history           ; record move in history
         ldx     #$b4                   ; play move confirmation beep
         jsr     play_beep
         jsr     show_and_check         ; animate move and check for check
         lda     scoreH_stack           ; check for mate-in-N
         cmp     #$ff                   ; $FF = negative score (forced mate)
         bne     @LAB23                 ; no mate-in-N → done
         lda     scoreL_stack
         cmp     #$fe                   ; $FFFE = mate-in-1 (immediate)
         beq     @LAB34                 ;   → show MATE
         ldx     #<lmatein2             ; show "MATE IN N" message
         ldy     #>lmatein2
         jsr     show_msg
         lda     scoreL_stack           ; compute N from score
         eor     #$ff                   ; invert
         lsr     A                      ; /2 (plies → moves)
         adc     #$6f                   ; + ASCII offset → digit char
         sta     $1f6c                  ; patch digit into screen display
@LAB23:  rts

@stalemate:
         ldx     #<lstalemate           ; display "STALEMATE"
         ldy     #>lstalemate
         jsr     show_msg
         jmp     @LAB3B                 ; → beep, wait, restart

@mate0:  lda     next_color             ; opponent is checkmated
         eor     #$80                   ; flip color (credits mating side)
         sta     next_color
@LAB34:  ldx     #<lmate                ; display "MATE"
         ldy     #>lmate
         jsr     show_msg
@LAB3B:  ldx     #$c8                   ; play end-of-game beep
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
@LAB4E:  cmp     #$0a                   ; value >= 10?
         bcc     @LAB5A                 ;   no → done with tens
         inc     $033c,x                ; tens digit++
         sec
         sbc     #$0a                   ; subtract 10
         bne     @LAB4E                 ; repeat if still >= 10
@LAB5A:  dex
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
         bcc     @LAB98                 ;   invalid
         cmp     #$39                   ; rank > '8'?
         bcs     @LAB98                 ;   invalid
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
         bcc     @LAB98                 ;   invalid
         cmp     #$49                   ; file > 'H'?
         bcs     @LAB98                 ;   invalid
         and     #$0f                   ; convert ASCII → 1-8
         clc
         adc     $0341                  ; + (rank+1)*10 → square index
         sta     $07,x                  ; store result
         dex                            ; advance buffer index
         dex                            ;   (skip past the 2 chars consumed)
         rts                            ; carry clear = success

@LAB98:  sec                            ; carry set = invalid input
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
@LABA5:  jsr     get_move_input         ; prompt and read move string
         ldx     #$04                   ; start parsing at buffer[4]
@LABAA:  jsr     parse_algebraic        ; parse rank+file → square index
         bcs     @LABBF                 ; parse error → invalid move
         bpl     @LABAA                 ; X >= 0 → parse second square
         jsr     validate_move          ; check move is in legal move list
         bcs     @LABBF                 ; not found → invalid move
         jsr     push_history           ; record move in history
         jsr     draw_board_frame       ; redraw board frame
         jmp     show_and_check         ; animate move, check for check

@LABBF:  ldx     #<linvalid_move        ; display "INVALID MOVE"
         ldy     #>linvalid_move
         jsr     show_msg
         ldx     #$aa                   ; play error beep
         jsr     play_beep
         jmp     @LABA5                 ; retry

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
@LABD6:  stx     $07                ; set current square
@LABD8:  jsr     highlight_square
         jsr     k_getchar
         beq     @LABD8             ; wait for keypress
         cmp     #$0d               ; RETURN?
         bne     @LABEB
         jsr     init_material      ; recalculate material totals
         jsr     clear_screen
         rts                        ; done - confirm setup

@LABEB:  jsr     handle_cursor      ; check if cursor key
         cpy     #$ff               ; was it a cursor key?
         bne     @LABD6             ; yes - moved to new square
         ldx     #$06               ; check piece letter keys P,N,B,R,Q,K
@LABF4:  cmp     lpnbrqk,x
         beq     @LABFF             ; found matching piece type
         dex
         bne     @LABF4
         txa                        ; X=0 means empty square
         beq     @LAC20
@LABFF:  stx     $aa                ; save piece type (1-6)
         jsr     wait_for_keypress  ; get color: W or B
         ldy     #$00               ; Y=$00 for white
         cmp     #$57               ; 'W'?
         beq     @LAC0C
         ldy     #$80               ; Y=$80 for black (bit 7)
@LAC0C:  tya
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
@LAC20:  ldx     $07
         sta     $146e,x            ; store piece on board
         sta     $aa
         jsr     decode_piece_gfx
         jsr     draw_piece         ; redraw the square
         ldx     $07
         jmp     @LABD8

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
         bmi     @LAC56             ; bit 7 set = castling
         bvc     return_no_check    ; bit 6 clear = normal move, done
         lda     #$0a               ; --- en passant handling ---
         bit     next_color         ; determine pawn capture direction
         bmi     @LAC4F             ; black moves down (+10)
         lda     #$f6               ; white moves up (-10)
@LAC4F:  clc
         adc     $08                ; captured pawn is adjacent to to-sq
         sta     $08
         bne     @LAC6B             ; remove captured pawn from board
@LAC56:  lda     $08                ; --- castling handling ---
         sec                        ; determine king direction
         sbc     $07
         cmp     #$02               ; king moved right 2 = kingside
         beq     @LAC64
         inc     $08                ; queenside: rook from col 1
         asl     A                  ;   (adjust from/to for rook)
         bne     @LAC68
@LAC64:  dec     $08                ; kingside: rook from col 8
         inc     $07
@LAC68:  clc
         adc     $07                ; calculate rook destination
@LAC6B:  sta     $07
         jmp     exec_board_move    ; move the rook / remove pawn

; ---------------------------------------------------------------------
; format_move_text - Format move into displayable text
; Normal moves: from/to in algebraic notation with '-' or 'X' (capture).
; Castling: "O-O" or "O-O-O". En passant: "PXPEP".
; $1328 = captured piece (non-zero = capture). Result in $033c-$0341.
; ---------------------------------------------------------------------
format_move_text:   bit     $1332          ; check special move flags
         bmi     @LAC9D                 ; bit 7 = castling
         bvs     @LAC97                 ; bit 6 = en passant
         ldx     #$01                   ; --- normal move ---
         lda     $0b                    ; convert from-square to notation
         jsr     byte_to_bcd
         ldx     #$04
         lda     $0c                    ; convert to-square to notation
         jsr     byte_to_bcd
         ldx     #$2d                   ; '-' separator (non-capture)
         lda     $1328                  ; captured piece?
         beq     @LAC8E
         ldx     #$58                   ; 'X' separator (capture)
@LAC8E:  stx     $033e                  ; store separator character
         ldx     #$3c                   ; point to $033c buffer
         ldy     #$03
         bne     @LACB0

@LAC97:  ldx     #<lpxpep               ; en passant: "PXPEP"
         ldy     #>lpxpep
         bne     @LACB0

@LAC9D:  lda     $0c                    ; --- castling ---
         sec
         sbc     $0b                    ; to - from
         cmp     #$02                   ; +2 = kingside
         beq     @LACAC
         ldx     #<looo                 ; queenside: "O-O-O"
         ldy     #>looo
         bne     @LACB0

@LACAC:  ldx     #<loo                  ; kingside: "O-O"
         ldy     #>loo
@LACB0:  lda     #$00
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
@LACD0:  cmp     #$0a               ; subtract 10s to get tens digit
         bcc     @LACDA
         inx
         sec
         sbc     #$0a
         bne     @LACD0
@LACDA:  clc
         adc     #$30               ; ones digit -> ASCII
         sta     $033d
         txa                        ; tens digit
         cmp     #$40               ; >= '@' (overflow)?
         bcs     @LACE9
         cmp     #$30               ; still '0' (leading zero)?
         bne     @LACEB
@LACE9:  lda     #$20               ; suppress: replace with space
@LACEB:  sta     $033c
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
@LAD18:  lda     ($05),y            ; get next character
         beq     @LAD26             ; null terminator - done
         sty     $a3                ; save index
         jsr     handle_char_display
         ldy     $a3                ; restore index
         iny
         bne     @LAD18
@LAD26:  rts

input_string:
         stx     $05
         sty     $06
         ldy     #$00
@LAD2D:  lda     ($05),y
         beq     @LAD37
         jsr     k_out_to_channel
         iny
         bne     @LAD2D
@LAD37:  rts

; ---------------------------------------------------------------------
; player_hint - Handle '?' key: show computer's expected response
; If search depth >= 2 plies, retrieves the computer's predicted reply
; ($9f=from, $b4=to) and previews it on the board.
; ---------------------------------------------------------------------
player_hint:   ldy     level+1
         cpy     #$02               ; at least 2 plies calculated?
         bcc     @LAD51             ; no - can't hint
         lda     $9f                ; predicted from-square
         sta     $07
         lda     $b4                ; predicted to-square
         sta     $0a
         jsr     validate_move      ; validate and make the hint move
         bcs     @LAD51             ; invalid - skip
         jsr     unmake_move        ; undo it (was just a preview)
         jsr     show_computer_move ; display the hint notation
@LAD51:  jmp     poll_keyboard      ; return to input loop

; ---------------------------------------------------------------------
; push_history - Push current move into move history buffer
; Shifts existing entries ($12fe-$131b) by 4 bytes to make room, then
; stores from ($0b), to ($0c), captured piece ($1328), flags ($1332).
; ---------------------------------------------------------------------
push_history:   ldx     #$17
@LAD56:  lda     $12fe,x            ; shift history buffer up by 4 bytes
         sta     $1302,x
         dex
         bpl     @LAD56
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
         bmi     @LAD81             ; if computer is black, negate
         eor     #$ff               ;   (two's complement negation)
         clc
         adc     #$01
@LAD81:  clc
         adc     #$80               ; shift to unsigned: $80 = even
         cmp     #$81               ; computer ahead in material?
         bcs     @LADD4             ; yes - don't accept draw
         lda     $12fe              ; --- repetition detection ---
         cmp     $130e              ; compare last from vs 4-ago from
         bne     @LADD4
         lda     $12ff              ; compare last to vs 4-ago to
         cmp     $130f
         bne     @LADD4
         lda     $1001              ; compare proposed from vs 4-ago from
         cmp     $130a
         bne     @LADD4
         lda     $1002              ; compare proposed to vs 4-ago to
         cmp     $130b
         bne     @LADD4
         lda     #$02               ; repetition detected - try alt move
         sta     $8d                ;   use move list entry #2
         jsr     try_move
         bcs     @LADD4             ; alt move illegal - fall through
         jsr     evaluate_position  ; evaluate the alternative
         lda     $1328              ; captured piece type
         and     #$07
         tax
         lda     piece_values,x     ; get its material value
         asl     A                  ; double it
         sec
         sbc     $63                ; compare vs opening book eval
         bmi     @LADD1             ; worse - undo and reject
         lda     $1003              ; accept alt: replace best move
         sta     $1001
         lda     $1004
         sta     $1002
         clc                        ; carry clear = legal/ok
         rts

@LADD1:  jsr     unmake_move        ; undo the alternative
@LADD4:  lda     #$00               ; try the original best move
         sta     $8d
         beq     try_move           ; (always branches)

; ---------------------------------------------------------------------
; validate_move - Validate a user's move
; Searches the move list ($1001+) for a from/to match ($07/$0a).
; If found, stores index in $9c/$8d and calls try_move.
; Returns: carry set = invalid/illegal, carry clear = legal.
; ---------------------------------------------------------------------
validate_move:   ldx     #$fe
@LADDC:  inx                        ; advance to next move pair
         inx
         lda     $1001,x            ; from-square in move list
         beq     return_illegal     ; end of list - not found
         cmp     $07                ; match from-square?
         bne     @LADDC
         lda     $1002,x            ; match to-square?
         cmp     $0a
         bne     @LADDC
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
         bne     @LAE14             ; not a pawn? skip color adjust
         bit     $13                ; check piece color (bit 7)
         bpl     @LAE14             ; white pawn? keep start index
         clc
         adc     #$04               ; black pawn: offset by +4 directions
@LAE14:  sta     $0f                ; $0f = current direction index
@LAE16:  ldx     $0f                ; --- begin direction loop ---
         lda     move_directions,x  ; get direction offset
         sta     $11                ; $11 = current step offset
         ldx     $07                ; x = from-square
@LAE1F:  clc                        ; --- step along ray ---
         txa
         adc     $11                ; x = next square in this direction
         tax
         lda     $146e,x            ; read board contents at target
         beq     @LAE33             ; empty square - can move here
         cmp     #$ff               ; border sentinel?
         beq     @LAE4C             ; yes - end this direction
         eor     $13                ; compare colors (bit 7 xor)
         bpl     @LAE4C             ; same color - blocked, next dir
         eor     $13                ; restore piece byte (enemy capture)
@LAE33:  sta     $0e                ; $0e = captured piece (0 if empty)
         lda     $0d
         cmp     #$01               ; is this a pawn?
         beq     @LAE53             ; yes - special pawn logic
         jsr     add_move           ; add move (from=$07, to=x)
         lda     $0e
         bne     @LAE4C             ; captured a piece - can't continue
         lda     $0d
         cmp     #$06               ; king?
         beq     @LAE4C             ; king moves one step only
         cmp     #$03               ; sliding piece (bishop=3,rook=4,queen=5)?
         bcs     @LAE1F             ; yes - continue along ray
@LAE4C:  inc     $0f                ; advance to next direction
         dec     $10                ; decrement remaining count
         bne     @LAE16             ; more directions? loop
         rts

; --- pawn move logic ---
; Directions at count >= 3 are captures; count < 3 are pushes.
@LAE53:  lda     $10                ; remaining direction count
         cmp     #$03               ; count >= 3?
         bcs     @LAE69             ; yes - this is a capture direction
         ; --- pawn push (count < 3) ---
         lda     $0e                ; target square contents
         bne     @LAE68             ; not empty? can't push - done
         jsr     add_move           ; empty - add single push
         bit     $13                ; check bit 6 (has piece moved?)
         bvs     @LAE68             ; bit 6 set = already moved, no double push
         dec     $10                ; consume one more direction
         bne     @LAE1F             ; continue to try double push
@LAE68:  rts

         ; --- pawn capture (count >= 3) ---
@LAE69:  lda     $0e                ; target square contents
         beq     @LAE73             ; empty - check en passant
         jsr     add_move           ; enemy piece present - add capture
         jmp     @LAE4C             ; next direction

@LAE73:  jsr     check_en_passant   ; empty diagonal - try en passant
         jmp     @LAE4C

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
         bpl     @LAE8C             ; white - no adjustment
         clc
         adc     #$0a               ; black: offset by +10 for rank check
@LAE8C:  cmp     #$3d               ; rank 5 lower bound
         bcc     @LAEBF             ; below rank 5? fail
         cmp     #$45               ; rank 5 upper bound +1
         bcs     @LAEBF             ; above rank 5? fail
         ; --- check last move was a 2-square pawn push ---
         lda     $0b                ; last move from-square
         sec
         sbc     $0c                ; minus last move to-square
         cmp     #$14               ; +20 = 2 ranks forward (white push)
         beq     @LAEA1
         cmp     #$ec               ; -20 = 2 ranks forward (black push)
         bne     @LAEBF             ; not a double push? fail
         ; --- verify the captured piece is a pawn ---
@LAEA1:  stx     $08                ; save en passant target square
         ldx     $0c                ; x = last move destination (enemy pawn)
         lda     $146e,x            ; read piece at that square
         and     #$07               ; mask to piece type
         cmp     #$01               ; is it a pawn?
         bne     @LAEBF             ; no - fail
         ; --- check enemy pawn is adjacent (±10 from capturer) ---
         txa                        ; a = enemy pawn square
         ldx     $08                ; restore target square
         sec
         sbc     $08                ; difference from target
         cmp     #$0a               ; +10 (one rank)?
         beq     @LAEBC
         cmp     #$f6               ; -10 (one rank)?
         bne     @LAEBF             ; no - fail
@LAEBC:  jmp     add_move           ; all conditions met - add move

@LAEBF:  rts

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
         jsr     @LAF13             ; check castling availability
         ; --- iterate all board squares ---
         ldx     #$15               ; first board square
         stx     $07
@LAEDF:  lda     $146e,x            ; read board contents
         beq     @LAEF7             ; empty square - skip
         cmp     #$ff
         beq     @LAEF7             ; border - skip
         eor     next_color         ; compare piece color to side-to-move
         bmi     @LAEF7             ; enemy piece - skip
         eor     next_color         ; restore piece byte
         sta     $13                ; $13 = full piece byte
         and     #$07               ; mask to piece type
         sta     $0d                ; $0d = piece type (1-6)
         jsr     gen_piece_moves
@LAEF7:  inc     $07                ; next square
         ldx     $07
         cpx     #$63               ; past last board square?
         bcc     @LAEDF             ; no - continue
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
@LAF13:  ldx     $6c                ; white king position
         lda     next_color
         bpl     @LAF1B             ; white to move? use $6c
         ldx     $6d                ; black king position
@LAF1B:  lda     $146e,x            ; king's piece byte
         and     #$40               ; bit 6 = has moved flag
         bne     @LAF79             ; king has moved - no castling
         lda     $146e,x
         sta     $13                ; save king's piece byte
         stx     $07                ; $07 = king's square
         jsr     is_king_attacked   ; is king currently in check?
         bcs     @LAF79             ; in check - can't castle
         ; --- try kingside first (rook at king+3, step toward king=-1) ---
         lda     #$02               ; 2 squares to verify (f&g files)
         sta     $12
         lda     #$ff               ; step = -1 (from rook toward king)
         sta     $09
         lda     #$03               ; offset +3: king to h-side rook
@LAF38:  clc
         adc     $07                ; x = rook's expected square
         tax
         lda     $146e,x            ; read piece at rook square
         and     #$7f               ; strip color bit
         cmp     #$04               ; unmoved rook? (type 4, bit 6 clear)
         bne     @LAF66             ; no rook or rook has moved - skip
         ; --- verify squares between king and rook are empty ---
@LAF45:  txa
         clc
         adc     $09                ; step toward king
         tax
         lda     $146e,x            ; square contents
         bne     @LAF66             ; not empty - can't castle
         lda     $12
         cmp     #$03               ; queenside extra square (b-file)?
         beq     @LAF5A             ; skip attack check for far square
         jsr     is_king_attacked   ; king passes through this square?
         bcs     @LAF66             ; attacked - can't castle
@LAF5A:  dec     $12                ; more squares to check?
         bne     @LAF45             ; yes - continue
         ; --- castling is legal - add the king's move ---
         txa                        ; x = king's destination
         sec
         sbc     $09                ; back up one step (king lands here)
         tax
         jsr     add_move           ; add castling move
         ; --- now try queenside (rook at king-4, step toward king=+1) ---
@LAF66:  lda     $09
         bpl     @LAF79             ; already did queenside? done
         ldx     $07                ; restore king square
         lda     #$03               ; 3 squares to verify (b,c,d files)
         sta     $12
         lda     #$01               ; step = +1 (from rook toward king)
         sta     $09
         lda     #$fc               ; offset -4: king to a-side rook
         jmp     @LAF38

@LAF79:  rts

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
@LAF84:  lda     #$fe               ; distance starts at -2
         sta     $0e                ; (will be $ff=adjacent after first inc)
         ldx     $0f
         lda     move_directions,x  ; get direction offset
         sta     $11
         ldx     $08                ; start from king square
         ; --- walk along this direction ---
@LAF91:  inc     $0e                ; advance distance counter
         clc
         txa
         adc     $11                ; step to next square
         tax
         lda     $146e,x            ; read board
         beq     @LAFA3             ; empty - keep walking (if sliding)
         cmp     #$ff               ; border?
         beq     @LAFA9             ; yes - next direction
         bne     @LAFB6             ; piece found - identify it

@LAFA3:  lda     $10                ; empty square: can we slide?
         cmp     #$09               ; directions 0-7 (counter >= 9) are sliding
         bcs     @LAF91             ; yes - continue walking
         ; --- advance to next direction ---
@LAFA9:  inc     $0f
         dec     $10
         bne     @LAF84             ; more directions? loop
         clc                        ; all clear - king not attacked
         bcc     @LAFB3

@LAFB2:  sec                        ; king IS attacked
@LAFB3:  ldx     $08                ; restore king square
         rts

         ; --- piece found: is it an enemy that attacks from here? ---
@LAFB6:  eor     $13                ; compare colors
         bpl     @LAFA9             ; friendly piece - no threat, next dir
         eor     $13                ; restore piece byte
         and     #$07               ; extract piece type
         sta     $0d
         lda     $10                ; direction counter
         cmp     #$09               ; counter >= 9? (directions 0-7: sliding)
         bcc     @LB007             ; counter < 9: knight directions (8-15)
         ; --- sliding directions (diagonal 0-3, orthogonal 4-7) ---
         lda     $0d
         cmp     #$05               ; queen?
         beq     @LAFB2             ; queen attacks on any sliding dir
         bit     $0e                ; check distance (bit 7 set = adjacent)
         bpl     @LAFD4             ; not adjacent - skip king check
         cmp     #$06               ; king? (attacks at distance 1 only)
         beq     @LAFB2             ; adjacent king - attacked!
@LAFD4:  lda     $10
         cmp     #$0d               ; counter >= 13? (directions 0-3: diagonals)
         bcc     @LAFFE             ; counter < 13: orthogonal dirs (4-7)
         ; --- diagonal directions (counter >= 13) ---
         lda     $0d
         cmp     #$03               ; bishop?
         beq     @LAFB2             ; bishop attacks on diagonal
         bit     $0e                ; adjacent? (for pawn check)
         bpl     @LAFA9             ; not adjacent - pawn can't reach
         cmp     #$01               ; pawn?
         bne     @LAFA9             ; not a pawn - no threat
         ; --- pawn attack direction check (depends on color) ---
         lda     $13                ; king's color
         bmi     @LAFF5             ; black king? check black's pawn dirs
         ; white king: pawns attack from dirs 14-15 (counter >= 15)
         lda     $10
         cmp     #$0f               ; counter 15-16 = directions 0-1 diag
         bcc     @LAFA9             ; wrong diagonal for white pawn attack
         jmp     @LAFB2             ; pawn attacks white king!

         ; black king: pawns attack from dirs 12-13 (counter < 15)
@LAFF5:  lda     $10
         cmp     #$0f
         bcs     @LAFA9             ; wrong diagonal for black pawn attack
         jmp     @LAFB2             ; pawn attacks black king!

         ; --- orthogonal directions (counter 5-8, i.e. dirs 4-7) ---
@LAFFE:  lda     $0d
         cmp     #$04               ; rook?
         bne     @LAFA9             ; not rook - no threat on orthogonal
         jmp     @LAFB2             ; rook attacks on orthogonal!

         ; --- knight directions (counter 1-8, i.e. dirs 8-15) ---
@LB007:  lda     $0d
         cmp     #$02               ; knight?
         bne     @LAFA9             ; not knight - no threat
         beq     @LAFB2             ; knight attacks from L-shape!

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
@LB01B:  lda     $146e,x            ; get piece at square
         beq     @LB02D             ; empty square - skip
         cmp     #$ff
         beq     @LB02D             ; border sentinel - skip
         sta     $13                ; $13 = piece (with color in bit 7)
         and     #$07
         sta     $0d                ; $0d = piece type (1-6)
         jsr     @LB036             ; evaluate this piece's mobility
@LB02D:  inc     $07                ; next square
         ldx     $07
         cpx     #$63               ; past last board square?
         bcc     @LB01B
         rts

         ; --- walk movement rays for piece at $07 ---
@LB036:  ldx     $0d                ; piece type index
         lda     move_dir_count,x   ; number of directions
         sta     $10                ; $10 = direction counter
         lda     move_dir_start,x   ; first direction index
         cmp     #$10               ; pawn? (dir start = $10)
         bne     @LB04F
         dec     $10                ; pawns: reduce count by 2
         dec     $10                ;   (only diagonal dirs for attack)
         bit     $13                ; check piece color
         bpl     @LB04F             ; white pawn - use default start
         clc
         adc     #$04               ; black pawn - offset to black dirs
@LB04F:  sta     $0f                ; $0f = current direction index
@LB051:  ldx     $0f
         lda     move_directions,x  ; get direction delta
         sta     $11                ; $11 = step delta for this ray
         ldx     $07                ; X = current square
         lda     #$00
         sta     $12                ; $12 = ray flags (bit5=attacked, bit6=blocked, bit0=moved, bit7=xray)
@LB05E:  clc                        ; --- step along ray ---
         txa
         adc     $11                ; add direction delta
         tax                        ; X = target square
         lda     $146e,x            ; get piece at target
         cmp     #$ff               ; off board?
         bne     @LB071
@LB06A:  inc     $0f                ; --- next direction ---
         dec     $10
         bne     @LB051
         rts

         ; --- found a piece (or empty) on ray ---
@LB071:  sta     $14                ; $14 = piece at target (with color)
         and     #$07
         sta     $0e                ; $0e = target piece type
         bit     $12                ; already encountered a piece on this ray?
         bvs     @LB0B2             ; yes - handle X-ray attack
         lda     centrality,x       ; positional score for this square
         lsr     A                  ; halve it
         bit     $13                ; check moving piece color
         bpl     @LB088             ; white: add centrality
         eor     #$ff               ; black: negate centrality
         clc
         adc     #$01
@LB088:  clc
         adc     $68                ; accumulate in positional score
         sta     $68
         lda     $14                ; target piece
         beq     @LB0E2             ; empty square - check if sliding piece continues
         eor     $13                ; compare colors (bit 7)
         bpl     @LB0CB             ; same color - it's a defender
         ; --- enemy piece found: add to attacker list ---
         lda     $0e
         cmp     #$06               ; target is enemy king?
         bne     @LB09F
         lda     #$01
         sta     $69                ; $69 = flag: attacking enemy king
@LB09F:  lda     $12
         and     #$01               ; already moved on this ray?
         bne     @LB0A7
         ora     #$40               ; bit 6: first piece encountered
@LB0A7:  ora     #$20               ; bit 5: has attacked
         sta     $12
         ldy     $6e                ; defender list pointer (grows down)
         dec     $6e
         jmp     @LB0D5             ; store in list

         ; --- X-ray: second piece found behind first ---
@LB0B2:  lda     $0e
         beq     @LB05E             ; empty - keep walking
         cmp     #$01
         beq     @LB06A             ; pawn behind - stop this ray
         lda     $14
         eor     $13                ; compare colors
         bpl     @LB06A             ; friendly behind - stop
         txa                        ; enemy behind enemy: X-ray attack
         ora     #$80               ; set bit 7 = X-ray flag on square
         tax
         lda     $12
         and     #$bf               ; clear bit 6 (blocked flag)
         jmp     @LB0A7             ; add to attacker list

         ; --- friendly piece found: add to defender list ---
@LB0CB:  lda     $12
         ora     #$01               ; bit 0: moved flag
         sta     $12
         ldy     $6f                ; attacker list pointer (grows up)
         inc     $6f
@LB0D5:  txa                        ; --- store entry in list ---
         sta     $1346,y            ; target square
         lda     $12
         and     #$80               ; keep X-ray flag
         ora     $07                ; combine with source square
         sta     $13c6,y            ; source square + flags
         ; --- check if piece continues along ray ---
@LB0E2:  lda     $0d                ; moving piece type
         cmp     #$03               ; sliding piece? (bishop+)
         bcs     @LB0EB
@LB0E8:  jmp     @LB06A             ; pawn/knight: next direction

         ; --- sliding piece ray continuation logic ---
@LB0EB:  cmp     #$06               ; king?
         beq     @LB0E8             ; king stops after one step
         bit     $12                ; already blocked on this ray?
         bvc     @LB0F6             ; no - check X-ray possibilities
@LB0F3:  jmp     @LB05E             ; continue walking ray

@LB0F6:  lda     $12
         and     #$20               ; has attacked on this ray?
         bne     @LB0E8             ; yes - stop (already found enemy)
         lda     $0e                ; target piece type
         beq     @LB0F3             ; empty - keep sliding
         ; --- X-ray compatibility checks ---
         ; Can the moving piece attack through the blocking piece?
         lda     $0d
         cmp     #$04               ; rook?
         bne     @LB119
         lda     $0e                ; piece blocking the ray
         cmp     #$04               ; rook behind rook?
         beq     @LB0F3             ; yes - continue (rook X-ray)
         cmp     #$05               ; queen behind rook?
         bne     @LB0E8             ; no match - stop
@LB110:  lda     $12                ; set X-ray attack flag
         ora     #$80
         sta     $12
         jmp     @LB05E             ; continue ray with X-ray

@LB119:  cmp     #$03               ; bishop?
         bne     @LB129
         lda     $0e
         cmp     #$01               ; pawn on diagonal?
         beq     @LB153             ; check pawn direction compatibility
         cmp     #$05               ; queen behind bishop?
         bne     @LB0E8             ; no match - stop
         beq     @LB110             ; yes - X-ray through

@LB129:  lda     $0e                ; queen ray continuation
         cmp     #$03               ; bishop blocking queen diagonal?
         bne     @LB138
         lda     $10                ; check if diagonal direction
         cmp     #$05
         bcc     @LB0E8             ; orthogonal dir - stop
         jmp     @LB05E             ; diagonal - continue

@LB138:  cmp     #$04               ; rook blocking queen orthogonal?
         bne     @LB145
         lda     $10
         cmp     #$05               ; check if orthogonal direction
         bcc     @LB0F3             ; orthogonal - continue
         jmp     @LB06A             ; diagonal - next direction

@LB145:  cmp     #$05               ; queen behind queen?
         beq     @LB0F3             ; yes - continue
         cmp     #$01               ; pawn blocking queen?
         bne     @LB0E8
         lda     $10
         cmp     #$05               ; diagonal direction?
         bcc     @LB0E8             ; no - stop
@LB153:  lda     $13                ; check pawn direction compatibility
         eor     $11                ; pawn color vs ray direction
         bmi     @LB0E8             ; wrong direction for this pawn - stop
         lda     $12
         ora     #$20               ; mark as attacked
         sta     $12
         jmp     @LB05E             ; continue ray

; --- prune_exchanges ---
; Prunes attack/defense exchange lists (Static Exchange Evaluation).
; Removes unfavorable exchanges from the attacker list at $1346.
; Checks if trades are worth evaluating based on piece values
; and available defenders.
prune_exchanges:   lda     $6e
         eor     #$ff               ; compute defender list count
         clc
         adc     #$80               ; = $7f - $6e (number of defenders)
         beq     @LB179             ; no defenders - nothing to prune
         sta     $10                ; $10 = defender count
         ldy     #$7f               ; start at top of defender list
@LB16F:  lda     $1346,y            ; get target square entry
         bmi     @LB17A             ; bit 7 set = attacker entry
@LB174:  dey                        ; next entry
         dec     $10
         bne     @LB16F
@LB179:  rts

         ; --- process attacker entry ---
@LB17A:  sty     $11                ; save current list position
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
         beq     @LB1B6             ; always evaluate king attacks
         ldx     $07
         lda     $146e,x            ; attacking piece
         and     #$07
         cmp     $0f                ; attacker value >= defender value?
         bcc     @LB1B6             ; attacker cheaper - evaluate trade
         ; --- attacker is more valuable: check if square is also attacked ---
         lda     $6f
         beq     @LB208             ; no attackers - skip to second pass
         sta     $12                ; $12 = attacker count
         ldx     #$00
         lda     $09                ; attacked square
@LB1AC:  cmp     $1346,x            ; is this square in attacker list?
         beq     @LB174             ; yes - square defended, skip pruning
         inx
         dec     $12
         bne     @LB1AC
         ; --- first pass: prune from attacker list ---
@LB1B6:  lda     $6f
         beq     @LB208             ; no attacker entries
         sta     $12                ; $12 = count
         ldx     #$00
@LB1BE:  lda     $13c6,x            ; source square of attacker
         and     #$7f
         cmp     $08                ; matches defender's target?
         bne     @LB203             ; no - skip
         lda     $1346,x            ; target of attack
         and     #$7f
         cmp     $09                ; same as attacked square?
         beq     @LB203             ; self-reference - skip
         sta     $0a                ; $0a = this attacker's target
         tay
         lda     $146e,y            ; piece at attacker's target
         and     #$07
         cmp     $0f                ; cheaper than defended piece?
         bcs     @LB203             ; no - not worth pruning
         ; --- check if any defender covers this target ---
         lda     $6e
         eor     #$ff
         clc
         adc     #$80
         sta     $0d                ; $0d = defender count
         ldy     #$7f
@LB1E7:  lda     $13c6,y            ; defender source
         and     #$7f
         cmp     $07                ; matches our source?
         bne     @LB1F9
         lda     $1346,y            ; defender target
         and     #$7f
         cmp     $0a                ; covers the attacked square?
         beq     @LB203             ; yes - don't prune, it's defended
@LB1F9:  dey
         dec     $0d
         bne     @LB1E7
         lda     #$00               ; no defender found
         sta     $1346,x            ; prune: remove attacker entry
@LB203:  inx
         dec     $12
         bne     @LB1BE
         ; --- second pass: prune from defender list ---
@LB208:  lda     $6e
         eor     #$ff
         clc
         adc     #$80
         sta     $12                ; $12 = defender count
         ldx     #$7f
@LB213:  lda     $13c6,x            ; defender source square
         and     #$7f
         cmp     $08                ; matches target?
         bne     @LB26E             ; no - skip
         lda     $1346,x            ; defender target
         and     #$7f
         cmp     $07                ; same as source piece?
         beq     @LB26E             ; self - skip
         sta     $0a                ; $0a = defender's target square
         tay
         lda     $0f                ; defended piece type
         cmp     #$06               ; king?
         beq     @LB24A             ; always check king defense
         lda     $146e,y            ; piece at defender target
         and     #$07
         cmp     $0f                ; cheaper than defended piece?
         bcs     @LB26E             ; no - keep entry
         lda     $1345,x            ; check adjacent list entry
         bpl     @LB24A             ; not an attacker entry
         and     #$7f
         tay
         lda     $146e,y            ; piece at adjacent entry
         and     #$07
         cmp     $0f                ; cheaper?
         bcc     @LB269             ; yes - prune
         bcs     @LB26E             ; no - keep

         ; --- check if any attacker covers this square ---
@LB24A:  lda     $6f
         beq     @LB269             ; no attackers
         sta     $0d
         ldy     #$00
@LB252:  lda     $13c6,y            ; attacker source
         and     #$7f
         cmp     $07                ; matches source?
         bne     @LB264
         lda     $1346,y            ; attacker target
         and     #$7f
         cmp     $0a                ; covers our target?
         beq     @LB26E             ; yes - keep (covered)
@LB264:  iny
         dec     $0d
         bne     @LB252
@LB269:  lda     #$00
         sta     $1346,x            ; prune: remove entry
@LB26E:  dex
         dec     $12
         bne     @LB213
         ldy     $11                ; restore list position
         jmp     @LB174             ; continue outer loop

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
@LB284:  sta     $1319,x            ; clear exchange table
         dex
         bne     @LB284
         sta     $0f                ; $0f = phase (0=defenders, 1=attackers)
         ; --- process one list entry ---
@LB28C:  lda     $08
         ora     #$80               ; mark as processed
         sta     $1346,y
         lda     $13c6,y            ; source square + flags
         sta     $07
         and     #$7f
         tax
         lda     $146e,x            ; get piece at source
         bmi     @LB2A6             ; black piece?
         ldx     #$00               ; white: table offset 0
         inc     $05                ; count friendly piece
         bne     @LB2AA
@LB2A6:  ldx     #$07               ; black: table offset 7
         inc     $06                ; count enemy piece
@LB2AA:  and     #$07
         sta     $0d                ; $0d = piece type
         lda     $07
         bpl     @LB2B8             ; no X-ray flag?
         txa                        ; X-ray: offset by 6 (pack separately)
         clc
         adc     #$06
         bne     @LB2BC
@LB2B8:  txa                        ; normal: offset by piece type
         clc
         adc     $0d
@LB2BC:  tax                        ; X = index into exchange table
@LB2BD:  lda     $1319,x            ; find empty slot
         beq     @LB2D0             ; empty - store here
         and     #$f0               ; high nibble free?
         beq     @LB2C9             ; yes - pack into high nibble
         inx                        ; both full - next slot
         bne     @LB2BD
@LB2C9:  lda     $1319,x            ; pack into high nibble
         asl     A
         asl     A
         asl     A
         asl     A
@LB2D0:  ora     $0d                ; combine with piece type
         sta     $1319,x
         lda     $0f                ; which phase?
         beq     @LB2E8             ; phase 0: scanning defenders
         ; --- phase 1: scan attacker list (growing up) ---
@LB2D9:  lda     $08                ; target square to match
@LB2DB:  dec     $10
         beq     @LB304             ; done
         iny
         cmp     $1346,y            ; find matching target
         bne     @LB2DB
         jmp     @LB28C             ; process entry

         ; --- phase 0: scan defender list (growing down) ---
@LB2E8:  lda     $08
@LB2EA:  dec     $10
         bne     @LB2FB
         lda     $6f                ; switch to attacker list
         sta     $10
         ldy     #$ff               ; start from beginning
         inc     $0f                ; phase = 1
         inc     $10
         jmp     @LB2D9

@LB2FB:  dey                        ; scan downward
         cmp     $1346,y            ; find matching target
         bne     @LB2EA
         jmp     @LB28C             ; process entry

@LB304:  rts

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
         bpl     @LB32A             ; white piece - start with enemy capture
         inc     $12                ; black piece - start with friendly
         ; --- main exchange loop ---
@LB32A:  jsr     @LB36E             ; get next enemy piece value
         beq     @LB35C             ; no more enemy pieces - done
         eor     #$ff               ; negate (enemy captures = loss)
         adc     #$01
         clc
         adc     $0e                ; subtract from running score
         sta     $0e
         cmp     $0f                ; new minimum?
         bcc     @LB344
         lda     $0e                ; update worst score
         sta     $0f
         lda     $0d                ; save current best
         sta     $11
@LB344:  jsr     @LB36E             ; get next friendly piece value
         beq     @LB365             ; no more friendly pieces - done
         adc     $0e                ; add to running score (recapture)
         sta     $0e
         cmp     $0d                ; new maximum?
         bcs     @LB32A             ; no - continue
         lda     $0e                ; update best score
         sta     $0d
         lda     $0f                ; save current worst
         sta     $10
         jmp     @LB32A             ; continue exchange

         ; --- no more enemy pieces: return min(worst, saved) ---
@LB35C:  lda     $0f
         cmp     $11
         bcc     @LB364
         lda     $11                ; return lesser extreme
@LB364:  rts

         ; --- no more friendly pieces: return max(best, saved) ---
@LB365:  lda     $0d
         cmp     $10
         bcs     @LB36D
         lda     $10                ; return lesser extreme
@LB36D:  rts

         ; --- extract next piece from exchange table ---
         ; Alternates between enemy (Y index) and friendly (X index).
         ; Returns piece value in A, Z flag set if no piece available.
@LB36E:  lda     $12                ; side toggle
         bne     @LB38B             ; nonzero = get friendly piece
         inc     $12                ; flip to friendly next time
         lda     $06                ; enemy pieces remaining?
         beq     @LB3AE             ; no - return Z=1
         dec     $06
@LB37A:  iny                        ; scan enemy side of table
         lda     $1319,y
         beq     @LB37A             ; skip empty slots
         pha
         lsr     A                  ; shift high nibble down
         lsr     A
         lsr     A
         lsr     A
         sta     $1319,y            ; leave high nibble for next extraction
         dey
         bne     @LB3A2
@LB38B:  dec     $12                ; flip to enemy next time
         lda     $05                ; friendly pieces remaining?
         beq     @LB3AE             ; no - return Z=1
         dec     $05
@LB393:  inx                        ; scan friendly side of table
         lda     $1319,x
         beq     @LB393             ; skip empty slots
         pha
         lsr     A                  ; shift high nibble down
         lsr     A
         lsr     A
         lsr     A
         sta     $1319,x            ; leave high nibble for next extraction
         dex
@LB3A2:  pla
         and     #$0f               ; low nibble = piece type
         sty     $14                ; save Y
         tay
         lda     piece_values,y     ; look up piece value
         ldy     $14                ; restore Y
         clc                        ; clear Z flag (piece found)
@LB3AE:  rts

; --- evaluate_position ---
; Main position evaluation function. Combines mobility, material
; exchanges, pawn structure, king proximity, and opening strategy.
; Score returned in $61/$62 (16-bit, centered at $80 = neutral).
; Negated for black (negamax convention).
evaluate_position:   inc     $70     ; increment node counter (lo)
         bne     @LB3BB
         inc     $71                ; increment node counter (hi)
         bne     @LB3BB
         dec     $70                ; clamp at $ffff
         dec     $71
@LB3BB:  lda     #$00
         ldx     #$08
@LB3BF:  sta     $61,x              ; clear eval accumulators $61-$69
         dex
         bpl     @LB3BF
         jsr     eval_mobility      ; build attack/defense lists + centrality
         jsr     prune_exchanges    ; remove unfavorable exchanges
         ; --- evaluate material exchanges ---
         lda     $6e
         eor     #$ff
         clc
         adc     #$80               ; count defender entries
         beq     @LB437             ; none - skip exchange eval
         sta     $0a                ; $0a = defender count
         ldy     #$7f               ; start at top of defender list
@LB3D7:  lda     $1346,y            ; target square entry
         bmi     @LB42A             ; attacker entry (bit 7) - skip
         beq     @LB42A             ; pruned entry - skip
         sta     $08                ; $08 = square to evaluate
         sty     $09                ; save list position
         jsr     build_exchange     ; build exchange table for this square
         jsr     static_exchange    ; evaluate the exchange
         sec
         sbc     #$80               ; remove $80 center bias
         bmi     @LB428             ; negative result - skip (loss)
         beq     @LB406             ; neutral - check if target square
         sta     $0d                ; $0d = exchange gain
         lda     $13
         eor     next_color         ; is it our piece?
         bmi     @LB410             ; no - enemy threat
         ; --- friendly exchange gain ---
         lda     $0d
         cmp     $63                ; better than current best?
         bcc     @LB3FF
         sta     $63                ; $63 = best own mobility/exchange
@LB3FF:  lda     $67
         sec
         sbc     #$08               ; penalize mobility (piece is pinned/traded)
         sta     $67                ; $67 = mobility balance
@LB406:  lda     $08                ; is this the move's target square?
         cmp     $0c
         bne     @LB428
         sta     $66                ; $66 = exchange target square
         beq     @LB428

         ; --- enemy threat ---
@LB410:  lda     $0d
         cmp     $64                ; worse than best enemy threat?
         bcc     @LB41B
         ldx     $64                ; demote current best to second
         sta     $64                ; $64 = best enemy threat
         txa
@LB41B:  cmp     $65                ; worse than second threat?
         bcc     @LB421
         sta     $65                ; $65 = second enemy threat
@LB421:  lda     $67
         clc
         adc     #$04               ; enemy threat improves mobility
         sta     $67
@LB428:  ldy     $09                ; restore list position
@LB42A:  dey
         dec     $0a
         bne     @LB3D7             ; next defender entry
         lda     $66                ; was target square exchanged?
         beq     @LB437
         lda     #$00
         sta     $65                ; clear second threat (target was in list)
         ; --- endgame king proximity ---
@LB437:  lda     level+2            ; endgame flag
         beq     @LB43E
         jsr     king_proximity     ; add king centralization score
         ; --- pawn structure evaluation ---
@LB43E:  jsr     @LB4C2             ; evaluate pawn structure -> $6b
         ; --- combine all scores ---
         lda     $65                ; second enemy threat
         asl     $63                ; double best own mobility
         sec
         sbc     $63                ; threats - 2*mobility
         bit     next_color
         bpl     @LB451
         eor     #$ff               ; negate for black
         clc
         adc     #$01
@LB451:  clc
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
         bpl     @LB46A
         eor     #$ff               ; negate for black
         clc
         adc     #$01
@LB46A:  and     #$ff
         jsr     @LB4A5             ; add to 16-bit accumulator $61/$62
         lda     $68                ; positional/centrality score
         jsr     @LB4A5
         lda     $1e                ; opening strategy bonus (x2)
         jsr     @LB4A5
         lda     $1e
         jsr     @LB4A5
         lda     $6b                ; pawn structure score (x2)
         jsr     @LB4A5
         lda     $6b
         jsr     @LB4A5
         ; --- negate score if playing black (negamax) ---
         lda     next_color
         bpl     @LB49D             ; white - keep sign
         lda     $61                ; negate 16-bit score
         clc
         eor     #$ff
         adc     #$01
         sta     $61
         lda     $62
         eor     #$ff
         adc     #$00
         sta     $62
@LB49D:  lda     $62                ; center around $80
         clc
         adc     #$80
         sta     $62
         rts

         ; --- add signed A to 16-bit accumulator $61/$62 ---
@LB4A5:  clc
         bmi     @LB4B1             ; negative value
         adc     $61                ; positive: add to low byte
         sta     $61
         bcc     @LB4B0
         inc     $62                ; propagate carry
@LB4B0:  rts

@LB4B1:  adc     $61                ; negative: add to low byte
         sta     $61
         bcs     @LB4B9
         dec     $62                ; propagate borrow
@LB4B9:  rts

         ; --- pawn structure score helpers ---
@LB4BA:  lda     #$04               ; +4 bonus (passed pawn)
@LB4BC:  clc                        ; entry for variable bonus/penalty
@LB4BD:  adc     $6b               ; add to pawn structure score
         sta     $6b
         rts

         ; --- pawn structure evaluation ---
         ; Scans each file (column) for pawns. Evaluates doubled,
         ; isolated, passed, and connected pawns. Score in $6b.
         ; $11/$12 = file of first white/black pawn per column.
         ; $0f/$10 = last file with friendly/enemy pawn.
@LB4C2:  lda     #$00
         sta     $0e                ; file characteristics flags
         sta     $11                ; white pawn file = none
         sta     $12                ; black pawn file = none
         sta     $6b                ; pawn structure score = 0
         sta     $0f                ; last friendly pawn file = none
         sta     $10                ; last enemy pawn file = none
         ldx     #$1f               ; start square (file A, rank 2)
@LB4D2:  lda     #$06               ; 6 ranks to scan per file
         sta     $0d                ; $0d = rank counter
@LB4D6:  lda     $146e,x            ; piece at square
         and     #$07
         cmp     #$01               ; pawn?
         bne     @LB502             ; no - next rank
         lda     $146e,x            ; check pawn color
         bmi     @LB4F4             ; black pawn
         ; --- white pawn found ---
         lda     $11                ; already found white pawn on this file?
         beq     @LB4ED
         lda     #$fc               ; yes - doubled pawn penalty (-4)
         jsr     @LB4BC
@LB4ED:  lda     $0d                ; record rank position
         sta     $11
         jmp     @LB502

         ; --- black pawn found ---
@LB4F4:  lda     $12                ; already found black pawn on this file?
         beq     @LB4FE
         jsr     @LB4BA             ; yes - doubled pawn bonus (+4 for us)
         jmp     @LB502

@LB4FE:  lda     $0d                ; record rank position
         sta     $12
@LB502:  txa
         clc
         adc     #$0a               ; advance one rank (stride 10)
         tax
         dec     $0d                ; next rank
         bne     @LB4D6
         ; --- analyze white pawn on this file (no black pawn) ---
         lda     $12                ; black pawn on this file?
         bne     @LB562             ; yes - skip to black pawn analysis
         lda     $11                ; white pawn on this file?
         beq     @LB55B             ; no - check semi-open file
         lda     $0e                ; white passed pawn (no black pawn ahead)
         ora     #$40               ; set passed pawn flag
         sta     $0e
         jsr     @LB4BA             ; passed pawn bonus (+4)
         lda     move_number
         cmp     #$14               ; after move 20?
         bcc     @LB532             ; no - skip advancement bonus
         lda     #$07               ; compute advancement bonus
         sec                        ; = 2^(7-rank) (exponential for
         sbc     $11                ;   advanced passed pawns)
         tay
         lda     #$00
         sec
@LB52B:  rol     A                  ; shift 1 left Y times
         dey
         bne     @LB52B
         jsr     @LB4BD             ; add advancement bonus
@LB532:  lda     $10                ; last enemy pawn file
         beq     @LB54D             ; none - skip connected check
         cmp     $11                ; on same file?
         beq     @LB548
         sec
         sbc     #$01               ; adjacent file?
         cmp     $11
         beq     @LB548
         clc
         adc     #$02               ; other adjacent file?
         cmp     $11
         bne     @LB54D
@LB548:  lda     #$02               ; connected pawns bonus (+2)
         jsr     @LB4BC
@LB54D:  lda     $0f                ; last friendly pawn file
         beq     @LB555             ; none
         cmp     $11                ; friendly pawn at/beyond white pawn?
         bcc     @LB55B             ; no - semi-open
@LB555:  lda     $0e                ; mark isolated/exposed
         ora     #$80
         sta     $0e
@LB55B:  lda     $0f                ; last friendly pawn file
         beq     @LB562             ; none
         jsr     @LB4BA             ; semi-open file penalty (+4 for enemy)
         ; --- analyze black pawn on this file (no white pawn) ---
@LB562:  lda     $11                ; white pawn present?
         bne     @LB5B8             ; yes - skip to cross-side analysis
         lda     $12                ; black pawn present?
         beq     @LB5AF             ; no - check semi-open file
         lda     $0e                ; black passed pawn
         ora     #$10               ; set enemy passed pawn flag
         sta     $0e
         lda     #$fc               ; passed pawn penalty (-4, good for enemy)
         jsr     @LB4BC
         lda     move_number
         cmp     #$14               ; after move 20?
         bcc     @LB588             ; no - skip advancement penalty
         lda     #$ff               ; compute advancement penalty
         ldy     $12                ; (exponential for advanced pawns)
@LB57F:  dey
         beq     @LB585
         asl     A                  ; shift left Y times
         bne     @LB57F
@LB585:  jsr     @LB4BC             ; add advancement penalty
@LB588:  lda     $0f                ; last friendly pawn file
         beq     @LB5A3             ; none - skip connected check
         cmp     $12                ; on same file?
         beq     @LB59E
         clc
         adc     #$01               ; adjacent file?
         cmp     $12
         beq     @LB59E
         sec
         sbc     #$02               ; other adjacent file?
         cmp     $12
         bne     @LB5A3
@LB59E:  lda     #$fe               ; connected enemy pawns penalty (-2)
         jsr     @LB4BC
@LB5A3:  lda     $12                ; black pawn at/beyond last enemy pawn?
         cmp     $10
         bcc     @LB5AF
         lda     $0e                ; mark exposed
         ora     #$20
         sta     $0e
@LB5AF:  lda     $10                ; last enemy pawn file
         beq     @LB5B8             ; none
         lda     #$fc               ; semi-open file penalty (-4)
         jsr     @LB4BC
         ; --- cross-side pawn structure analysis ---
         ; Uses flags from previous file iterations ($0e bits)
@LB5B8:  lda     $0e
         and     #$04               ; previous file had specific flag?
         beq     @LB5EA
         lda     $11                ; white pawn on this file?
         beq     @LB5D9             ; no - skip connected check
         cmp     $10                ; adjacent to last enemy pawn?
         beq     @LB5D4
         clc
         adc     #$01
         cmp     $10
         beq     @LB5D4
         sec
         sbc     #$02
         cmp     $10
         bne     @LB5D9
@LB5D4:  lda     #$02               ; connected pawn bonus (+2)
         jsr     @LB4BC
@LB5D9:  lda     $0e
         and     #$08               ; check exposure flag
         beq     @LB5EA
         lda     $12                ; black pawn present and advanced?
         beq     @LB5E7
         cmp     $10
         bcc     @LB5EA
@LB5E7:  jsr     @LB4BA             ; exposure bonus (+4)
@LB5EA:  lda     $0e
         and     #$01               ; check isolated flag
         beq     @LB61C
         lda     $12                ; black pawn connected to friendly?
         beq     @LB60B
         cmp     $0f                ; adjacent file?
         beq     @LB606
         clc
         adc     #$ff
         cmp     $0f
         beq     @LB606
         clc
         adc     #$02
         cmp     $0f
         bne     @LB60B
@LB606:  lda     #$fe               ; connected enemy penalty (-2)
         jsr     @LB4BC
@LB60B:  lda     $0e
         and     #$02               ; check another flag
         beq     @LB61C
         lda     $0f
         cmp     $11                ; friendly pawn at/beyond white pawn?
         bcc     @LB61C
         lda     #$fc               ; isolated pawn penalty (-4)
         jsr     @LB4BC
         ; --- advance to next file ---
@LB61C:  lda     $0e                ; shift flags right 4 bits
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
         bne     @LB63E
         jmp     @LB5B8             ; process cross-side flags first

@LB63E:  cmp     #$ec               ; done with all files?
         bne     @LB643
         rts                        ; yes - return

@LB643:  jmp     @LB4D2             ; next file column

; --- opening_strategy ---
; Applies opening/middlegame positional bonuses and penalties.
; Pawn center control, piece development, king safety, castling.
; Result added to $1e (positional bonus), sign depends on color.
; $0d bit 4 = capture, bit 0 = piece color.
opening_strategy:   lda     $13
         and     #$07
         cmp     #$01               ; pawn?
         bne     @LB6C4             ; no - check pieces
         ; --- pawn strategy ---
         lda     move_number
         cmp     #$0a               ; before move 10?
         bcs     @LB681             ; no - later pawn strategy
         ; --- early game pawn moves ---
         lda     $0b                ; source square of move
         bit     $13                ; check piece color
         bpl     @LB65D
         sec
         sbc     #$32               ; normalize black squares to white
@LB65D:  cmp     #$22               ; d-file pawn?
         beq     @LB671
         cmp     #$23               ; e-file pawn?
         beq     @LB671
         ; --- flank pawn ---
         lda     $0d
         and     #$20               ; was it a push (not capture)?
         beq     @LB66C
         rts                        ; capture with flank pawn - ok

@LB66C:  lda     #$f8               ; flank pawn push penalty (-8)
         jmp     @LB73C

         ; --- center pawn: check if advancing to d4/e4 ---
@LB671:  sec
         sbc     $0c                ; distance from source to target
         cmp     #$ec               ; one square advance?
         beq     @LB67C
         cmp     #$e2               ; two square advance?
         bne     @LB6C3             ; other - no bonus
@LB67C:  lda     #$04               ; center pawn advance bonus (+4)
         jmp     @LB73C

         ; --- later pawn moves (move 10-25): king safety ---
@LB681:  cmp     #$19               ; after move 25?
         bcs     @LB6C3             ; yes - no penalty
         lda     $13                ; check piece color
         bmi     @LB69F             ; black pawn
         ; --- white pawn near king ---
         lda     $6c                ; white king position
         cmp     #$1a               ; king on queenside?
         bcc     @LB697
         cmp     #$1d               ; king on kingside?
         bcs     @LB6C3             ; center king - no pawn penalty
         lda     #$00               ; offset for center-ish king
         beq     @LB6B3

@LB697:  cmp     #$18               ; king on far queenside?
         bcs     @LB6C3
         lda     #$05               ; offset for queenside king
         bne     @LB6B3

         ; --- black pawn near king ---
@LB69F:  lda     $6d                ; black king position
         cmp     #$60               ; king on queenside (black)?
         bcc     @LB6A9
         lda     #$ce               ; offset for queenside
         bne     @LB6B3

@LB6A9:  cmp     #$5e               ; king on kingside?
         bcs     @LB6C3
         cmp     #$5b
         bcc     @LB6C3
         lda     #$d3               ; offset for kingside
@LB6B3:  clc
         adc     $0b                ; add to source square
         cmp     #$27               ; pawn is in king's zone?
         bcs     @LB6C3             ; no - outside zone
         cmp     #$24
         bcc     @LB6C3             ; no - outside zone
         lda     #$f4               ; king pawn advance penalty (-12)
         jmp     @LB73C

@LB6C3:  rts

         ; --- piece strategy (type >= 2) ---
@LB6C4:  cmp     #$04               ; rook or queen? (type 4-5)
         bcc     @LB6F9             ; no - knight/bishop (type 2-3)
         cmp     #$06               ; king? (type 6)
         beq     @LB6D7             ; yes - king strategy
         ; --- rook/queen: penalize early development ---
         lda     move_number
         cmp     #$07               ; before move 7?
         bcs     @LB6C3             ; no - ok to develop now
         lda     #$f0               ; early rook/queen penalty (-16)
         jmp     @LB73C

         ; --- king strategy ---
@LB6D7:  lda     $0d
         bpl     @LB6EF             ; not a capture - check center penalty
         ; --- king capture (castling check) ---
         lda     $0c                ; target square
         bit     $13                ; check piece color
         bpl     @LB6E4
         sec
         sbc     #$46               ; normalize black to white coordinates
@LB6E4:  sec
         sbc     #$0f               ; check for castling target squares
         cmp     #$0c               ; castling square? (=$0c means castled)
         beq     @LB73C             ; yes - bonus = $0c (+12)
         lda     #$06               ; non-castling king move (+6)
         bne     @LB73C

         ; --- king in center: penalty before move 30 ---
@LB6EF:  lda     move_number
         cmp     #$1e               ; after move 30?
         bcs     @LB6C3             ; yes - no penalty
         lda     #$f4               ; early king center penalty (-12)
         bne     @LB73C

         ; --- knight/bishop strategy (type 2-3) ---
@LB6F9:  lda     $0d
         and     #$10               ; is it a capture?
         beq     @LB703
         lda     #$0a               ; capture bonus (+10)
         bne     @LB70D

@LB703:  lda     move_number
         cmp     #$09               ; before move 9?
         bcs     @LB6C3             ; no - no bonus needed
         lda     #$f8               ; non-development penalty (-8)
         bne     @LB70D

         ; --- minor piece development: check center control ---
@LB70D:  sta     $0f                ; save bonus/penalty
         lda     move_number
         cmp     #$0f               ; before move 15?
         bcs     @LB73E             ; no - skip center check
         lda     $0c                ; target square
         bit     $13                ; check piece color
         bpl     @LB71E
         sec
         sbc     #$1e               ; normalize black to white
@LB71E:  cmp     #$2c               ; d4 square?
         beq     @LB726
         cmp     #$2d               ; e4 square?
         bne     @LB73E             ; not center - use saved bonus
         ; --- piece develops to center: check if blocking center pawn ---
@LB726:  sec
         sbc     #$0a               ; look one rank back (d3/e3)
         bit     $13
         bpl     @LB730
         clc
         adc     #$32               ; adjust for black
@LB730:  tax
         lda     $146e,x            ; piece behind on same file
         and     #$07
         cmp     #$01               ; pawn behind?
         bne     @LB73E             ; no - use saved bonus
         lda     #$e8               ; blocks center pawn penalty (-24)
         ; --- apply bonus/penalty to $1e (sign depends on color) ---
@LB73C:  sta     $0f
@LB73E:  lda     $0d
         and     #$01               ; piece color bit
         beq     @LB750
         lda     $13
         bmi     @LB754             ; black piece + black side: add bonus
@LB748:  lda     $1e                ; subtract bonus (wrong color perspective)
         sec
         sbc     $0f
         sta     $1e
         rts

@LB750:  lda     $13
         bmi     @LB748             ; white piece + black side: subtract
@LB754:  lda     $1e                ; add bonus (matching color perspective)
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
@LB760:  cmp     #$0a
         bcc     @LB76A
         iny                        ; Y = rank
         sec
         sbc     #$0a
         bne     @LB760
@LB76A:  sta     $0d                ; $0d = white king file
         sty     $0e                ; $0e = white king rank
         lda     $6d                ; black king square
         ldy     #$00
         ; --- divmod 10: black king file/rank ---
@LB772:  cmp     #$0a
         bcc     @LB77C
         iny                        ; Y = black king rank
         sec
         sbc     #$0a
         bne     @LB772
         ; --- compute Manhattan distance between kings ---
@LB77C:  sec
         sbc     $0d                ; file difference (black - white)
         bmi     @LB786             ; already negative = abs ok
         eor     #$ff               ; negate to get -abs(file diff)
         clc
         adc     #$01
@LB786:  sta     $0d                ; $0d = -|file diff|
         tya                        ; black king rank
         sec
         sbc     $0e                ; rank difference (black - white)
         bmi     @LB793             ; already negative = abs ok
         eor     #$ff               ; negate to get -abs(rank diff)
         clc
         adc     #$01
@LB793:  clc
         adc     $0d                ; -|file diff| + -|rank diff|
         clc
         adc     #$0e               ; add 14 to center (always positive)
         sta     $0d                ; $0d = distance score (14 - Manhattan dist)
         ; --- select losing side's king for centrality penalty ---
         ldx     #$00               ; X=0: use white king ($6c)
         lda     $6a                ; material balance
         bmi     @LB7A2             ; black ahead - penalize white king
         inx                        ; X=1: use black king ($6d)
@LB7A2:  ldy     $6c,x              ; Y = losing king square
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
         bpl     @LB7BF             ; white ahead - keep positive
         lda     $68                ; negate score for black advantage
         eor     #$ff
         clc
         adc     #$01
         sta     $68
@LB7BF:  lda     #$00
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
         bvs     @LB7EA           ; yes - skip
         lda     #$10             ; first move: set "first-move" flag in $0d
         sta     $0d
         lda     $13
         ora     #$40             ; set has-moved bit on piece
         sta     $13
@LB7EA:  ldx     $0c              ; X = to-square
         lda     $146e,x          ; get piece at to-square (capture target)
         sta     $14              ; $14 = captured piece (0 if empty)
         lda     $13
         sta     $146e,x          ; place moving piece at to-square
         and     #$07             ; extract piece type
         cmp     #$01             ; pawn?
         beq     @LB82D           ; -> pawn special handling
         cmp     #$06             ; king?
         bne     @LB803           ; other piece -> normal completion
         jmp     @LB883           ; -> king special handling

         ; --- common move completion ---
@LB803:  jsr     opening_strategy   ; evaluate positional factors
         ldy     next_color+1       ; Y = current ply index
         lda     $0d
         sta     $1331,y            ; save move flags for undo
         lda     $14
         sta     $1327,y            ; save captured piece for undo
         beq     @LB82C             ; no capture -> done
         and     #$07               ; extract captured piece type
         tax
         lda     $14
         bpl     @LB824             ; white piece captured -> subtract
         lda     $6a                ; black piece captured: add its value
         clc
         adc     piece_values,x     ; material += piece value
         sta     $6a
         rts

@LB824:  lda     $6a                ; white piece captured: subtract value
         sec
         sbc     piece_values,x     ; material -= piece value
         sta     $6a
@LB82C:  rts

         ; --- pawn special handling ---
@LB82D:  lda     $0c              ; to-square
         cmp     #$5b             ; rank 8? (>= $5b)
         bcs     @LB837           ; -> promotion
         cmp     #$1d             ; rank 1? (< $1d)
         bcs     @LB856           ; no promotion -> check en passant
         ; --- pawn promotion: promote to queen ---
@LB837:  lda     $0d
         ora     #$20             ; set promotion flag
         sta     $0d
         lda     $146e,x          ; pawn type $01
         ora     #$04             ; set bit 2 -> type $05 (queen)
         sta     $146e,x
         sta     $13
         bmi     @LB84C           ; black pawn?
         lda     #$07             ; white: +7 (queen value - pawn value)
         .byte   $2c              ; BIT abs - skip next 2-byte instruction
@LB84C:  lda     #$f9             ; black: -7 (queen value - pawn value)
         clc
         adc     $6a              ; update material balance
         sta     $6a
         jmp     @LB803           ; -> common completion

         ; --- en passant check ---
@LB856:  lda     $0c              ; to-square
         sec
         sbc     $0b              ; to - from
         and     #$01             ; diagonal move? (file changed)
         beq     @LB803           ; straight push -> normal completion
         lda     $14              ; target square empty?
         bne     @LB803           ; occupied -> normal capture
         ; diagonal pawn move to empty square = en passant
         lda     $13
         bmi     @LB86A           ; black pawn?
         lda     #$f6             ; white: offset -10 (capture square behind)
         .byte   $2c              ; BIT abs - skip
@LB86A:  lda     #$0a             ; black: offset +10 (capture square behind)
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
         jmp     @LB803           ; -> common completion

         ; --- king special handling ---
@LB883:  lda     $0c              ; to-square
         ldx     $13              ; moving piece (king)
         bmi     @LB88C           ; black king?
         sta     $6c              ; update white king position
         .byte   $2c              ; BIT abs - skip
@LB88C:  sta     $6d              ; update black king position
         sta     $08              ; $08 = king destination
         sec
         sbc     $0b              ; delta = to - from
         cmp     #$02             ; moved +2? (kingside castle)
         beq     @LB8A3
         cmp     #$fe             ; moved -2? (queenside castle)
         bne     @LB8C4           ; not castling -> normal completion
         ; --- queenside castle: rook a-file -> d-file ---
         inc     $08              ; rook destination = king dest + 1
         asl     A                ; delta*2 = -4
         clc
         adc     $0b              ; from + (-4) = rook source (a-file)
         bne     @LB8AA           ; always taken
         ; --- kingside castle: rook h-file -> f-file ---
@LB8A3:  dec     $08              ; rook destination = king dest - 1
         clc
         adc     $0b              ; from + 2 = intermediate
         adc     #$01             ; + 1 = rook source (h-file)
@LB8AA:  tax                      ; X = rook source square
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
@LB8C4:  jmp     @LB803           ; -> common completion

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
         beq     @LB8F1             ; no -> skip
         lda     $13
         and     #$bf               ; clear has-moved bit (restore virgin state)
         sta     $13
@LB8F1:  ldx     $0b                ; X = from-square
         lda     $13
         sta     $146e,x            ; restore piece to from-square
         and     #$07               ; piece type
         cmp     #$01               ; pawn?
         beq     @LB942             ; -> undo pawn specials
         cmp     #$06               ; king?
         beq     @LB962             ; -> undo king specials
         lda     $0d
         and     #$20               ; promotion flag? (non-pawn promoted piece)
         bne     @LB92A             ; -> undo promotion
         ; --- common unmake completion ---
@LB908:  inc     $0d                ; flag for opening_strategy undo mode
         jsr     opening_strategy   ; undo positional evaluation
         lda     $14                ; captured piece
         beq     @LB929             ; no capture -> done
         and     #$07               ; piece type
         tax
         lda     $14
         bmi     @LB921             ; black piece? -> subtract
         lda     $6a                ; white piece restored: add value back
         clc
         adc     piece_values,x
         sta     $6a
         rts

@LB921:  lda     $6a                ; black piece restored: subtract value
         sec
         sbc     piece_values,x
         sta     $6a
@LB929:  rts

         ; --- undo promotion: restore queen back to pawn ---
@LB92A:  lda     $13
         and     #$fb             ; clear bit 2 -> type $05 (queen) back to $01 (pawn)
         sta     $13
         sta     $146e,x          ; update board
         bpl     @LB938           ; white pawn?
         lda     #$07             ; black: +7 (reverse the -7 from promote)
         .byte   $2c              ; BIT abs - skip
@LB938:  lda     #$f9             ; white: -7 (reverse the +7 from promote)
         clc
         adc     $6a              ; adjust material balance back
         sta     $6a
         jmp     @LB908           ; -> common unmake completion

         ; --- undo pawn specials ---
@LB942:  bit     $0d              ; en passant flag (bit 6)?
         bvc     @LB908           ; no -> common unmake
         ; --- undo en passant ---
         ldx     $0c              ; to-square
         lda     #$00
         sta     $146e,x          ; clear the to-square (captured pawn was not there)
         lda     $13
         bmi     @LB954           ; black pawn?
         lda     #$f6             ; white: offset -10 (pawn was one rank behind)
         .byte   $2c              ; BIT abs - skip
@LB954:  lda     #$0a             ; black: offset +10
         clc
         adc     $0c              ; compute captured pawn's square
         tax
         lda     $14              ; restored captured pawn
         sta     $146e,x          ; put it back on the board
         jmp     @LB908           ; -> common unmake completion

         ; --- undo king specials ---
@LB962:  ldx     $0b              ; from-square (original king position)
         lda     $13
         bmi     @LB96B           ; black king?
         stx     $6c              ; restore white king position
         .byte   $2c              ; BIT abs - skip
@LB96B:  stx     $6d              ; restore black king position
         lda     $0d              ; move flags
         bpl     @LB908           ; castling flag (bit 7)? no -> common unmake
         ; --- undo castling: move the rook back ---
         lda     $0c
         sta     $08              ; $08 = king destination (rook is near here)
         sec
         sbc     $0b              ; delta = to - from
         cmp     #$02             ; kingside castle?
         beq     @LB984
         ; queenside: rook is at king dest + 1
         inc     $08              ; rook current pos = king dest + 1
         asl     A                ; delta*2 = -4
         clc
         adc     $0b              ; from + (-4) = rook original square (a-file)
         bne     @LB98B           ; always taken
         ; kingside: rook is at king dest - 1
@LB984:  dec     $08              ; rook current pos = king dest - 1
         clc
         adc     $0b              ; from + 2 = intermediate
         adc     #$01             ; + 1 = rook original square (h-file)
@LB98B:  sta     $07              ; $07 = rook's original square
         ldx     $08              ; X = rook's current square (post-castle)
         lda     $146e,x          ; get the rook
         and     #$bf             ; clear has-moved bit (restore virgin state)
         sta     $10
         lda     #$00
         sta     $146e,x          ; clear rook's current square
         ldx     $07
         lda     $10
         sta     $146e,x          ; put rook back at original square
         jmp     @LB908           ; -> common unmake completion

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
@LB9B3:  lda     ($8b),y          ; end of list? (null terminator)
         beq     @LBA05
         sty     $0f              ; $0f = current position (slot to fill)
         jsr     @LBA06           ; compute priority of this move
@LB9BC:  lda     $11              ; save current best priority
         sta     $12
         sty     $10              ; $10 = index of best move so far
         ; --- inner loop: scan for higher-priority move ---
@LB9C2:  iny
         iny                      ; advance to next move (2 bytes per move)
         lda     ($8b),y          ; end of list?
         beq     @LB9D3
         jsr     @LBA06           ; compute priority
         lda     $12              ; compare with current best
         cmp     $11
         bcs     @LB9C2           ; current best >= this -> keep scanning
         bcc     @LB9BC           ; found better -> update best

         ; --- swap best move into current slot ---
@LB9D3:  lda     $12
         beq     @LBA05           ; priority 0 -> done (empty move?)
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
         jmp     @LB9B3           ; continue sorting

@LBA05:  rts

         ; --- compute move priority ---
         ; Returns $11 = priority: piece_type*4 + bonus for matching best move
@LBA06:  iny
         lda     ($8b),y          ; to-square
         dey
         tax
         lda     $146e,x          ; piece at to-square (target)
         and     #$07             ; piece type
         asl     A
         asl     A                ; type * 4
         sta     $11              ; base priority
         bne     @LBA24           ; non-zero type -> check best-move bonus
         lda     $07              ; does from-square match prev best?
         cmp     ($8b),y
         bne     @LBA24           ; no match
         inc     $11              ; +1 for matching from-square
         cpx     $08              ; does to-square match prev best?
         bne     @LBA24
         inc     $11              ; +1 for matching to-square
@LBA24:  rts

; ---------------------------------------------------------------------
; alpha_beta - Recursive alpha-beta minimax search
; Uses ply counter at next_color+1. Scores in $0022+y / $002f+y (lo/hi).
; Moves are iterated from the move list at ($8b)+$8d.
; Cutoffs prune branches where the opponent already has a better option.
; ---------------------------------------------------------------------
alpha_beta:   ldy     $8d              ; current move offset
         lda     ($8b),y            ; null move? (end of move list)
         beq     @LBA45             ; -> handle leaf / end of list
         jsr     try_move           ; make move, check legality
         bcc     @LBA33             ; legal move -> proceed
         jmp     @LBADC             ; illegal (leaves king in check) -> next move

@LBA33:  ldy     next_color+1       ; current ply depth
         cpy     level+1            ; reached max depth?
         bcs     @LBA88             ; -> leaf evaluation
         ; --- recurse deeper ---
@LBA39:  jsr     @LBAEB             ; push_search_state: flip side, inc ply
         jsr     gen_all_moves      ; generate opponent's moves
         jsr     sort_moves         ; sort by priority
         jmp     alpha_beta         ; recurse

         ; --- end of move list (null move encountered) ---
@LBA45:  lda     $1d                ; any legal moves found at this ply?
         bne     @LBA68             ; yes -> propagate score upward
         ; no legal moves found - check if in check
         dey
         dey
         sty     $8d                ; back up move pointer
         jsr     in_check           ; is current side in check?
         bcc     @LBA5D             ; not in check -> stalemate
         ; checkmate: score = ply index (deeper mate = worse)
         lda     next_color+1
         sta     $61                ; score lo = ply (minimal score)
         lda     #$00
         sta     $62                ; score hi = 0
         jmp     @LBA9C

         ; stalemate: score = $80,00 (draw)
@LBA5D:  lda     #$00
         sta     $61
         lda     #$80
         sta     $62
         jmp     @LBA9C

         ; --- propagate score upward ($1d flag set) ---
@LBA68:  ldy     next_color+1
         cpy     #$01               ; at top level (ply 1)?
         bne     @LBA6F
         rts                        ; yes -> return to caller

         ; pop search state and negate child's score (minimax negation)
@LBA6F:  jsr     @LBB06             ; pop_search_state: flip side, dec ply
         lda     scoreL_stack,y     ; negate the child's score
         eor     #$ff
         clc
         adc     #$01
         sta     $61                ; $61 = -child_score (lo)
         lda     scoreH_stack,y
         eor     #$ff
         adc     #$00
         sta     $62                ; $62 = -child_score (hi)
         jmp     @LBA9E             ; -> score comparison

         ; --- leaf evaluation ---
@LBA88:  jsr     lazy_eval          ; quick material-based pruning check
         lda     next_color+1
         cmp     level              ; at extended search depth?
         bcc     @LBA99
         cmp     level+1
         bne     @LBA99
         lda     $69                ; opponent in check? (set by lazy_eval)
         bne     @LBA39             ; yes -> extend search one more ply
@LBA99:  jsr     unmake_move        ; undo the move
@LBA9C:  inc     $1d                ; flag: at least one move evaluated

         ; --- score comparison: is this move better than current best? ---
@LBA9E:  ldy     next_color+1
         lda     $62                ; new score hi
         cmp     $002f,y            ; compare with best score hi
         bcc     @LBADC             ; worse -> skip to next move
         bne     @LBAB0             ; strictly better -> update best
         lda     $0022,y            ; hi bytes equal: compare lo bytes
         cmp     $61
         bcs     @LBADC             ; best >= new -> skip

         ; --- new best move found ---
@LBAB0:  lda     $61
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
         bcc     @LBA68             ; -best < parent -> no cutoff, continue
         bne     @LBADC             ; -best > parent -> cutoff! prune remaining
         lda     $0021,y            ; hi equal: compare lo
         cmp     $61
         bcs     @LBA68             ; parent >= -best -> no cutoff

         ; --- advance to next move in list ---
@LBADC:  ldy     next_color+1
         lda     $8d
         clc
         adc     #$02               ; each move is 2 bytes (from, to)
         sta     $133b,y            ; save move pointer for this ply
         sta     $8d
         jmp     alpha_beta         ; try next move

         ; --- push_search_state: go one ply deeper ---
@LBAEB:  lda     next_color         ; flip side to move
         eor     #$80
         sta     next_color
         bmi     @LBAF5             ; now black's turn? skip move counter
         inc     move_number        ; white moved: increment full-move number
@LBAF5:  ldy     next_color+1
         lda     $0021,y            ; save parent's alpha bound
         sta     scoreL_stack,y
         lda     $002e,y
         sta     scoreH_stack,y
         inc     next_color+1       ; increment ply counter
         rts

         ; --- pop_search_state: return one ply up ---
@LBB06:  lda     next_color         ; flip side back
         eor     #$80
         sta     next_color
         bpl     @LBB10             ; was black's turn? decrement move counter
         dec     move_number
@LBB10:  dec     next_color+1       ; decrement ply counter
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
         bne     @LBB40
         lda     $1fe2              ; toggle display indicator
         eor     #$0a               ; flip thinking animation
         ora     #$40
         sta     $1fe2
@LBB40:  rts

; ---------------------------------------------------------------------
; save_best - Save the current best move for the current ply
; At ply 1: updates the principal variation display and saves move.
; At ply 2: saves the "hint" move ($b5/$b6).
; Also records best-move from/to for move ordering in the next iteration
; if the move is not a capture ($1445/$144f arrays).
; ---------------------------------------------------------------------
save_best:   lda     $1327,y          ; was this a capture?
         bne     @LBB50             ; yes -> skip best-move recording
         lda     $0b                ; non-capture: record from-square
         sta     $1445,y            ;   for move ordering (killer move)
         lda     $0c
         sta     $144f,y            ;   record to-square
@LBB50:  cpy     #$01               ; at ply 1 (top level)?
         bne     @LBB79             ; no -> check ply 2
         ; --- ply 1: update principal variation ---
         ldx     $8d                ; current move index
         beq     @LBB6B             ; first move -> no shift needed
@LBB58:  lda     $1000,x            ; shift PV buffer right by 2
         sta     $1002,x            ;   to make room for new best move
         dex
         bne     @LBB58
         lda     $0b                ; insert current best move at front
         sta     $1001              ;   from-square
         lda     $0c
         sta     $1002              ;   to-square
@LBB6B:  jsr     show_computer_move ; display the move on screen
         ldy     next_color+1
         lda     $b5                ; rotate previous best moves
         sta     $9f                ;   $9f = previous $b5
         lda     $b6
         sta     $b4                ;   $b4 = previous $b6
         rts

@LBB79:  cpy     #$02               ; at ply 2?
         bne     @LBB85             ; no -> done
         lda     $0b                ; save hint move (opponent's best reply)
         sta     $b5                ;   from-square
         lda     $0c
         sta     $b6                ;   to-square
@LBB85:  rts

; ---------------------------------------------------------------------
; lazy_eval - Quick material-based evaluation for search pruning
; Computes rough score from material balance * 2 + $81 (centered).
; If this rough score can't beat the current best, skips the expensive
; full evaluation. Also checks if opponent is in check ($69 flag).
; ---------------------------------------------------------------------
lazy_eval:   lda     level+1
         cmp     level              ; at the deepest non-extended level?
         bcs     @LBBC1             ; beyond -> always do full eval
         lda     $6a                ; material balance
         asl     A                  ; double it (amplify material signal)
         sta     $62                ; rough score hi
         lda     #$00
         sta     $61                ; rough score lo = 0
         lda     next_color
         bpl     @LBBAA             ; white to move -> score is positive
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
@LBBAA:  lda     $62
         clc
         adc     #$81               ; center around $81 (neutral)
         sta     $62
         ldy     next_color+1
         cmp     $002f,y            ; can rough score beat current best?
         bcc     @LBBC4             ; no -> skip full eval (lazy cutoff)
         bne     @LBBC1             ; yes, strictly better -> full eval
         lda     $0022,y            ; hi equal: compare lo
         cmp     $61
         bcs     @LBBC4             ; still can't beat -> skip
@LBBC1:  jmp     evaluate_position  ; do full static evaluation

         ; --- lazy cutoff: just check if opponent is in check ---
@LBBC4:  lda     next_color
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
check_color:   bmi     @LBBD8       ; black? -> use black king pos
         ldx     $6c              ; X = white king square
         .byte   $2c              ; BIT abs - skip
@LBBD8:  ldx     $6d              ; X = black king square
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
@LBBEF:  sta     $1445,x            ; clear best-move from-squares
         sta     $144f,x            ; clear best-move to-squares
         sta     $20,x              ; clear alpha bounds
         sta     $2d,x              ; clear beta bounds
         dex
         bne     @LBBEF
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
         bne     @LBC1C             ; yes -> skip book
         jsr     opening_book       ; try to play from opening book

         ; --- iterative deepening loop ---
@LBC1C:  lda     level+1            ; display current search depth
         ora     #$70               ;   as screen code digit
         sta     $1fe3              ;   on screen
         jsr     alpha_beta         ; run search at current depth
         lda     scoreH_stack       ; check result: mate found?
         beq     @LBC2E             ; score hi = 0 -> mate for opponent, stop
         cmp     #$ff
         bne     @LBC2F             ; score hi != $ff -> not our mate
@LBC2E:  rts                        ; mate detected -> done

         ; --- increase depth and manage aspiration window ---
@LBC2F:  inc     level+1            ; go one ply deeper
         lda     level+1
         cmp     #$03               ; at least depth 3 before windowing?
         bcc     @LBC83             ; no -> just search again
         cmp     level              ; reached configured max level?
         bcs     @LBC3E             ; yes -> check window adjustment
         jmp     @LBCC0             ; below max level -> re-search

         ; --- aspiration window check ---
@LBC3E:  lda     scoreH_stack       ; did score beat the upper bound (fail high)?
         cmp     $2e
         bcc     @LBC98             ; score < beta -> fail low (flip window)
         bne     @LBC4C
         lda     $21
         cmp     scoreL_stack
         bcs     @LBC98             ; score <= alpha -> fail low
         ; --- score is within or above window: widen ---
@LBC4C:  lda     scoreL_stack       ; negate the score
         eor     #$ff
         clc
         adc     #$01
         sta     $61
         lda     scoreH_stack
         eor     #$ff
         adc     #$00
         sta     $62
         cmp     $2f               ; did negated score beat lower bound?
         bcc     @LBCAC            ; yes -> fail high from opponent's view
         bne     @LBC69
         lda     $22
         cmp     $61
         bcs     @LBCAC
         ; --- widen window by $20 (32) in both directions ---
@LBC69:  lda     #$e0               ; -$20 = $e0 (widen alpha down)
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
@LBC83:  lda     level+1
         cmp     #$0a               ; absolute max depth = 10?
         beq     @LBC2E             ; yes -> stop searching
         cmp     level              ; at configured max level?
         beq     @LBCC0             ; yes -> re-search at this depth
         ldx     level
         lda     $71                ; node counter hi
         cmp     node_limits,x      ; exceeded node limit for this level?
         bcs     @LBC2E             ; yes -> stop searching
         bcc     @LBCC0             ; no -> re-search

         ; --- fail low: flip and widen window ---
@LBC98:  lda     $21                ; swap and negate alpha -> beta
         eor     #$ff
         sta     $22
         lda     $2e
         eor     #$ff
         sta     $2f
         lda     #$00               ; reset alpha to zero
         sta     $21
         sta     $2e
         beq     @LBCBE             ; always taken -> decrease depth

         ; --- fail high: flip and widen window ---
@LBCAC:  lda     $22                ; swap and negate beta -> alpha
         eor     #$ff
         sta     $21
         lda     $2f
         eor     #$ff
         sta     $2e
         lda     #$00               ; reset beta to zero
         sta     $22
         sta     $2f
@LBCBE:  dec     level+1            ; decrease depth (re-search wider)

         ; --- re-search: reset state and loop ---
@LBCC0:  lda     #$00
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
         jmp     @LBC1C             ; -> re-enter iterative deepening loop

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
@LBCEE:  lda     $146e,x            ; get piece at square
         beq     @LBD27             ; empty -> skip
         cmp     #$ff               ; border sentinel?
         beq     @LBD27             ; yes -> skip
         sta     $13
         and     #$07               ; extract piece type
         tay
         cmp     #$06               ; king?
         bne     @LBD0A
         lda     $13                ; record king position
         bmi     @LBD08             ; black king?
         stx     $6c                ; save white king square
         bne     @LBD0A             ; always taken
@LBD08:  stx     $6d                ; save black king square
@LBD0A:  lda     $13
         bmi     @LBD17             ; black piece?
         lda     $6a                ; white piece: add value
         clc
         adc     piece_values,y
         jmp     @LBD1D

@LBD17:  lda     $6a                ; black piece: subtract value
         sec
         sbc     piece_values,y
@LBD1D:  sta     $6a
         lda     $07                ; accumulate total material (unsigned)
         clc
         adc     piece_values,y     ; total += piece value
         sta     $07
@LBD27:  inx                        ; next square
         cpx     #$63               ; past last square?
         bcc     @LBCEE             ; no -> continue scanning
         ; --- endgame detection ---
         lda     $07
         cmp     #$2e               ; total material >= 46?
         bcs     @LBD41             ; yes -> not endgame
         lda     $6a                ; |material_balance|
         bpl     @LBD3B
         eor     #$ff               ; negate if negative
         clc
         adc     #$01
@LBD3B:  cmp     #$05               ; imbalance >= 5 pawns?
         bcc     @LBD41             ; no -> no king proximity needed
         sta     level+2            ; enable endgame king proximity eval
@LBD41:  rts

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
         bne     @LBF76             ; no -> search for opponent's move
         ; --- initialize book pointer to root ---
         lda     #<lopenings
         sta     opening_ptr
         lda     #>lopenings
         sta     opening_ptr+1
         lda     human_color        ; human playing white?
         beq     @LBF9C             ; yes -> computer picks a response

         ; --- search for opponent's last move in book tree ---
@LBF76:  lda     (opening_ptr),y    ; bit-count byte: bits set = # children
         ldx     #$01               ; X = child counter (start at 1)
@LBF7A:  lsr     A                  ; count set bits
         bcc     @LBF7E
         inx                        ; one more child
@LBF7E:  cmp     #$00
         bne     @LBF7A             ; continue until all bits shifted out
         lda     $9c                ; move code to search for
         iny                        ; Y points to first move-index byte
@LBF85:  cmp     (opening_ptr),y    ; does this child match?
         beq     @LBF96             ; yes -> descend to that child
         dex                        ; one fewer child to check
         beq     @LBF91             ; no more children -> book exhausted
         jsr     next_child         ; skip to next sibling
         bcc     @LBF85             ; continue searching
         ; --- opponent's move not in book ---
@LBF91:  lda     #$50               ; mark book as exhausted
         sta     $1c
         rts

         ; --- found opponent's move: descend ---
@LBF96:  jsr     goto_child         ; follow pointer to child node
         bcc     @LBF9C             ; success -> pick our response
         rts                        ; leaf node ($FF) -> book exhausted

         ; --- pick a random response from available children ---
@LBF9C:  ldy     #$00
         lda     (opening_ptr),y    ; bit-count byte
         ora     #$80               ; set high bit as sentinel for shifting
         sta     $0d                ; $0d = child selector (shifts right)
         iny
         lda     vic_raster         ; VIC raster line = random seed
         sta     $0e                ; $0e = random bits (shifts right)
@LBFAA:  lsr     $0e                ; consume one random bit
         bcs     @LBFBD             ; bit=1 -> select current child
         lda     $0d                ; bit=0 -> try next child
         beq     @LBFBB             ; all children exhausted -> wrap to first
         lsr     $0d                ; shift child selector
         bcc     @LBFAA             ; bit was 0 (no child here) -> continue
         jsr     next_child         ; skip past this child's pointer
         bne     @LBFAA             ; always taken -> try next random bit
@LBFBB:  ldy     #$01               ; wrap around: select first child

         ; --- play the selected book move ---
@LBFBD:  lda     (opening_ptr),y    ; get move-index byte
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
         beq     @LBFED             ; yes -> book exhausted
         sta     $0d                ; save pointer lo
         iny
         lda     (opening_ptr),y    ; child pointer hi
         sta     opening_ptr+1      ; update opening_ptr
         lda     $0d
         sta     opening_ptr
         clc                        ; success
         rts

@LBFED:  sta     $1c                ; mark book as exhausted ($ff)
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
         beq     @LBFFB             ; yes -> skip only 1 byte
         iny                        ; skip pointer hi byte (2-byte pointer)
@LBFFB:  iny                        ; advance to next sibling's move-index
         lda     $0f                ; restore A
         clc
         rts

