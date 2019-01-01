; Assembler: cc65 v2.17.0
; 6502bench SourceGen v1.0.0
         .setcpu "6502"
human_color =    $15
next_color =     $16
move_number =    $18
level    =       $19
scoreL_stack =   $23
scoreH_stack =   $30
opening_ptr =   $94
screen_page =    $0288
nmi_vector_l =   $0318
nmi_vector_h =   $0319
vic_raster =     $9004
b_init_ram =     $e3a4
b_init_vecs =    $e45b
b_init_hw =      $e518
k_ramtas =       $fd8d
k_init_regs =    $fdf9
k_init_vecs =    $ff8a
k_out_to_channel = $ffd2
k_getchar =      $ffe4
k_cursor_pos =   $fff0

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

LA009:   lda     #$93
         jmp     k_out_to_channel

LA00E:   jsr     LA019
LA011:   clc
         ldx     #$07
         ldy     #$06
         jmp     k_cursor_pos

LA019:   jsr     LA009
         lda     #$a0
         ldx     #$fd
@LA020:  sta     $1dff,x
         sta     $1efc,x
         dex
         bne     @LA020
         rts

LA02A:   pha
         ldx     #$03
@LA02D:  lda     @LA06A,x
         sta     $57,x
         dex
         bpl     @LA02D
         ldx     #$0f
@LA037:  ldy     #$00
         lda     $57
         sta     $5b
         clc
         lda     $58
         adc     #$78
         sta     $5c
@LA044:  lda     ($59),y
         sta     ($57),y
         lda     #$01
         sta     ($5b),y
         iny
         cpy     #$05
         bcc     @LA044
         lda     $5a
         sta     $58
         lda     $59
         sta     $57
         clc
         adc     #$16
         sta     $59
         bcc     @LA062
         inc     $5a
@LA062:  dex
         bne     @LA037
         jsr     LA06E
         pla
         rts

@LA06A:  .byte   $11
         .byte   $1e
         .byte   $27
         .byte   $1e

LA06E:   ldy     #$04
@LA070:  lda     #$60
         sta     $1f5b,y
         lda     #$01
         sta     $975b,y
         dey
         bpl     @LA070
         rts

LA07E:   lda     #$0f
         sta     $00
@LA082:  jsr     LA09E
         dec     $00
         bne     @LA082
         rts

LA08A:   ldx     $f9
         cmp     #$0d
         beq     LA09E
         inx
         cpx     #$06
         bcc     @LA098
         jsr     LA09E
@LA098:  jmp     LA152

LA09B:   jsr     LAD12
LA09E:   jsr     LA02A
         ldx     #$00
         stx     $f9
         rts

LA0A6:   ldx     #$00
         stx     $f9
         stx     $1f
LA0AC:   ldx     #$00
         stx     $00
LA0B0:   jsr     LA0F6
         pha
         lda     $f9
         bne     @LA0BB
         jsr     LA06E
@LA0BB:  jsr     LA3F9
         pla
         bit     $1f
         bpl     @LA0C6
         jmp     LA172

@LA0C6:  cmp     #$0d
         bcc     LA0B0
         cmp     #$4a
         bcs     LA0B0
         cmp     #$14
         beq     LA0ED
         cmp     #$0d
         beq     @LA0E2
         ldy     $00
         cpy     #$05
         bcs     LA0B0
         jsr     LA125
         jmp     LA0B0

@LA0E2:  jsr     LA12C
LA0E5:   ldx     #$00
         stx     $f9
         lda     $033c
         rts

LA0ED:   jsr     LA12C
         dec     $00
         bmi     LA0AC
         bpl     LA0B0

LA0F6:   jsr     k_getchar
         bne     @LA105
         jsr     LA1CF
         beq     LA0F6
         lda     #$80
         sta     $1f
@LA104:  rts

@LA105:  cmp     #$3f
         bne     @LA104
         jmp     LAD38

LA10C:   jsr     k_getchar
         beq     LA10C
         rts

input:   jsr     input_string
         jsr     LA10C
LA118:   pha
         ora     #$80
         jsr     k_out_to_channel
         lda     #$0d
         jsr     k_out_to_channel
         pla
         rts

LA125:   ldy     $00
         inc     $00
         sta     $033c,y
LA12C:   ldx     $f9
         cmp     #$14
         beq     @LA13C
         cmp     #$0d
         beq     @LA14D
         inx
         cpx     #$06
         bcc     LA152
         rts

@LA13C:  lda     #$60
         cpx     #$00
         beq     @LA14D
         sta     $1f5a,x
         dex
         beq     @LA14A
         bmi     @LA14D
@LA14A:  stx     $f9
         rts

@LA14D:  ldx     #$00
         stx     $f9
         rts

LA152:   stx     $f9
         ora     #$40
         sta     $1f5a,x
         pha
         lda     #$01
         sta     $975a,x
         pla
         rts

LA161:   stx     $900b
         ldx     #$80
         ldy     #$80
@LA168:  dex
         bne     @LA168
         dey
         bne     @LA168
         sty     $900b
         rts

LA172:   ldx     #$36
@LA174:  stx     $07
@LA176:  jsr     LA210
         jsr     LA1CF
         beq     @LA176
         cmp     #$0d
         beq     @LA188
         jsr     LA225
         jmp     @LA174

@LA188:  ldx     #$dc
         jsr     LA161
         lda     $ab
         clc
         adc     #$41
         jsr     @LA1C5
         lda     $ac
         eor     #$07
         clc
         adc     #$31
         jsr     @LA1C5
         lda     $1f
         and     #$01
         bne     @LA1B0
         lda     #$2d
         jsr     @LA1C5
         lda     #$81
         sta     $1f
         bne     @LA176

@LA1B0:  ldx     #$05
@LA1B2:  lda     $0200,x
         sta     $033c,x
         dex
         bpl     @LA1B2
@LA1BB:  jsr     LA1CF
         bne     @LA1BB
         sta     $1f
         jmp     LA0E5

@LA1C5:  ldy     $00
         inc     $00
         sta     $0200,y
         jmp     LA12C

LA1CF:   sei
         ldx     #$7f
         stx     $9122
@LA1D5:  lda     $9120
         cmp     $9120
         bne     @LA1D5
         ldx     #$ff
         stx     $9122
         ldx     #$f7
         stx     $9120
         cli
         and     #$80
         bne     @LA1EF

         .byte   $a9
         .byte   $1d
         .byte   $60

@LA1EF:  ldy     $9111
         cpy     $9111
         bne     @LA1EF
         ldx     #$04
@LA1F9:  tya
         and     @LA206,x
         beq     @LA202
         dex
         bpl     @LA1F9
@LA202:  lda     @LA20B,x
         rts

@LA206:  .byte   $00
         .byte   $04
         .byte   $08
         .byte   $10
         .byte   $20
@LA20B:  .byte   $00
         .byte   $91
         .byte   $11
         .byte   $9d
         .byte   $0d

LA210:   lda     $07
         jsr     LA311
         lda     $033c
         sta     $ab
         lda     $033d
         sta     $ac
         lda     #$02
         jsr     LA25E
         rts

LA225:   ldy     #$08
         ldx     #$ff
         cmp     #$9d
         beq     @LA248
         ldy     #$f8
         ldx     #$01
         cmp     #$1d
         beq     @LA248
         ldy     #$b0
         ldx     #$0a
         cmp     #$91
         beq     @LA248
         ldy     #$50
         ldx     #$f6
         cmp     #$11
         beq     @LA248
         ldy     #$ff
         rts

@LA248:  txa
         clc
         adc     $07
         tax
         lda     $146e,x
         cmp     #$ff
         bne     @LA25B
         sty     $07
         txa
         clc
         adc     $07
         tax
@LA25B:  rts

LA25C:   lda     #$10
LA25E:   sta     $a8
@LA260:  jsr     LA3B2
         ldy     #$30
@LA265:  dex
         bne     @LA265
         dey
         bne     @LA265
         dec     $a8
         bne     @LA260
         rts

LA270:   jsr     LA25C
         clc
         lda     $ab
         adc     $ac
         and     #$01
         beq     @LA27E
         lda     #$80
@LA27E:  sta     $a9
         jsr     LA386
         lda     $ad
         sta     $ab
         lda     $ae
         sta     $ac
         lda     $aa
         beq     @LA295
         jsr     LA296
         jsr     LA25C
@LA295:  rts

LA296:   lda     $aa
         and     #$bf
         sta     $a7
         beq     @LA2C0
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
         bmi     @LA2BE
         lda     #$00
         beq     @LA2C0

@LA2BE:  lda     #$80
@LA2C0:  sta     $a9
         lda     $a7
         bne     @LA2D7
         lda     #$01
         sta     $a5
         clc
         lda     $ab
         adc     $ac
         and     #$01
         beq     @LA2D5
         lda     #$80
@LA2D5:  sta     $a9
@LA2D7:  jsr     LA38A
         rts

LA2DB:   lda     $aa
         rol     A
         php
         ror     A
         and     #$07
         tax
         lda     @LA2EB,x
         plp
         ror     A
         sta     $aa
         rts

@LA2EB:  .byte   $00
         .byte   $02
         .byte   $06
         .byte   $08
         .byte   $04
         .byte   $0a
         .byte   $0c

LA2F2:   lda     $07
         jsr     LA311
         lda     $033c
         sta     $ab
         lda     $033d
         sta     $ac
         lda     $08
         jsr     LA311
         lda     $033c
         sta     $ad
         lda     $033d
         sta     $ae
         rts

LA311:   ldx     #$01
         jsr     LAB47
         dec     $033c
         lda     $033c
         and     #$07
         sta     $033c
         lda     #$38
         sec
         sbc     $033d
         sta     $033d
         rts

LA32B:   ldx     $08
         lda     $146e,x
         sta     $aa
         jsr     LA2F2
         jsr     LA2DB
         jsr     LA270
         rts

LA33C:   lda     #$00
         sta     $a3
         sta     $a4
         lda     $ac
         asl     A
         asl     A
         jsr     LA377
         lda     $a3
         ldx     #$0a
@LA34D:  jsr     LA377
         dex
         bne     @LA34D
         lda     #$00
         clc
         adc     $a3
         sta     $a3
         lda     #$1e
         adc     $a4
         sta     $a4
         lda     $ab
         asl     A
         jsr     LA377
         ldy     #$01
         ldx     #$02
         rts

LA36B:   lda     $a3
         sta     $f7
         clc
         lda     $a4
         adc     #$78
         sta     $f8
         rts

LA377:   pha
         clc
         adc     $a3
         sta     $a3
         bcc     @LA381
         inc     $a4
@LA381:  jsr     LA36B
         pla
         rts

LA386:   lda     #$01
         sta     $a5
LA38A:   jsr     LA33C
         lda     $a5
         asl     A
         asl     A
         stx     $a5
         tax
         dex
@LA395:  lda     LA528,x
         eor     $a9
         eor     #$80
         sta     ($a3),y
         lda     #$01
         sta     ($f7),y
         dex
         dey
         bpl     @LA395
         ldy     #$01
         lda     #$16
         jsr     LA377
         dec     $a5
         bne     @LA395
         rts

LA3B2:   jsr     LA33C
@LA3B5:  lda     ($a3),y
         eor     #$80
         sta     ($a3),y
         dey
         bpl     @LA3B5
         ldy     #$01
         jsr     LA3C7
         dex
         bne     @LA3B5
         rts

LA3C7:   pha
         lda     #$16
         jsr     LA377
         pla
         rts

LA3CF:   jsr     LA009
         ldx     #$15
@LA3D4:  lda     $146e,x
         cmp     #$ff
         beq     @LA3F4
         sta     $aa
         txa
         pha
         jsr     LA311
         jsr     LA2DB
         lda     $033c
         sta     $ab
         lda     $033d
         sta     $ac
         jsr     LA296
         pla
         tax
@LA3F4:  inx
         cpx     #$63
         bne     @LA3D4
LA3F9:   jsr     LA4B5
         lda     #$00
         sta     $a3
         lda     #$1e
         sta     $a4
         jsr     LA36B
         lda     #$78
         sta     $a5
         ldy     #$10
@LA40D:  lda     #$80
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         jsr     LA3C7
         lda     $a5
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         jsr     LA3C7
         dec     $a5
         lda     $a5
         cmp     #$70
         bne     @LA40D
         ldy     #$00
         lda     #$41
         sta     $a5
@LA431:  lda     #$80
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
         bne     @LA431
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

show_msg:
         stx     $a5
         sty     $a6
         jsr     LA4B5
         ldy     #$ff
@LA492:  iny
         lda     ($a5),y
         bne     @LA492
         tya
         lsr     A
         sta     $a7
         lda     #$08
         sec
         sbc     $a7
         jsr     LA377
         ldy     #$00
@LA4A5:  lda     ($a5),y
         beq     @LA4B4
         ora     #$40
         sta     ($a3),y
         lda     #$01
         sta     ($f7),y
         iny
         bne     @LA4A5
@LA4B4:  rts

LA4B5:   lda     #$60
         sta     $a3
         lda     #$1f
         sta     $a4
         jsr     LA36B
         ldy     #$15
@LA4C2:  lda     #$80
         sta     ($a3),y
         lda     $20
         sta     ($f7),y
         dey
         bpl     @LA4C2
         rts

LA4CE:   lda     #$00
         tay
         sta     $57
         sta     $59
         lda     #$1a
         sta     $5a
         lda     #$84
         sta     $58
@LA4DD:  lda     ($57),y
         sta     ($59),y
         inc     $57
         inc     $59
         bne     @LA4EB
         inc     $58
         inc     $5a
@LA4EB:  lda     $5a
         cmp     #$1c
         bne     @LA4DD
         lda     $59
         bne     @LA4DD
         sta     $5b
         lda     #$18
         sta     $5c
         lda     #$1c
         sta     $5a
         lda     #<la55c
         sta     $57
         lda     #>la55c
         sta     $58
         jsr     @LA518
         lda     #$d8
         sta     $59
         sta     $5b
         lda     #<la634
         sta     $57
         lda     #>la634
         sta     $58
@LA518:  ldy     #$00
@LA51A:  lda     ($57),y
         sta     ($59),y
         eor     #$ff
         sta     ($5b),y
         iny
         cpy     #$d8
         bne     @LA51A
         rts

LA528:   .byte   $00,$00,$00,$00,$1d,$1e,$1b,$1c,$03,$04,$01,$02,$22,$23,$1f,$21
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
vic_init_regs:
         .byte   $05,$19,$96,$2e,$00,$fe,$00,$00,$ff,$ff,$00,$00,$00,$00,$0f,$6d

nmi_handler:  

;--- ORIGINAL (14 bytes) ---
.if 0
         bit     $9111          ; 3
         jsr     $ffe1          ; 3
         beq     LA911          ; 2
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
         jmp     LA911          ; 3
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

         jsr     LA4CE
         jsr     LAAAB
LA911:   sei
         ldx     #$ff
         txs
         cli
         ldy     #$11
@LA918:  lda     vic_init_regs-1,y
         sta     $8fff,y
         dey
         bne     @LA918
         sty     $f9
         sty     $21
         sty     $22
         sty     $2e
         sty     $2f
         lda     #$05
         sta     $20
         jsr     @welcome
         jsr     LA3CF
         jsr     LA07E
         jsr     LACCC
@LA93B:  lda     next_color
         cmp     human_color
         bne     @LA94C
         sei
         jsr     sargon_moves
         cli
         jsr     @LA95A
         jmp     @LA93B

@LA94C:  lda     #$03
         sta     $97a7
         jsr     LAB9A
         jsr     @LA95A
         jmp     @LA93B

@LA95A:  lda     next_color
         eor     #$80
         sta     next_color
         bne     @LA967
         inc     move_number
         jmp     LACCC

@LA967:  rts

@welcome:
         jsr     LA00E
         ldx     #<lwelcome_msg
         ldy     #>lwelcome_msg
         jsr     input_string
@LA972:  jsr     k_getchar
         cmp     #$85
         beq     @LA9E4
         ldx     $028d
         cpx     #$07
         beq     @LA986
         jsr     @screen_x_offset
         jmp     @LA972

@LA986:  jsr     LA011
         ldx     #<ladapted
         ldy     #>ladapted
         jsr     $ad27
         jmp     @LA972

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
         bne     @LA9E3
         inc     $20
         lda     $20
         and     #$07
         sta     $20
         lda     $900f
         and     #$f8
         ora     $20
         sta     $900f
@LA9E3:  rts

@LA9E4:  jsr     LA019
         ldx     #<lgame_or_setup
         ldy     #>lgame_or_setup
         jsr     input
         cmp     #$53
         beq     @LA9F5
         jmp     @LAA65

@LA9F5:  jsr     LABCE
         jsr     LA019
@LA9FB:  ldx     #<lnextcolor
         ldy     #>lnextcolor
         jsr     input
         ldx     #$00
         cmp     #'W'
         beq     @LAA0E
         cmp     #'B'
         bne     @LA9FB
         ldx     #$80
@LAA0E:  stx     next_color
         lda     #$01
         sta     $1c
         ldx     #<lmovenum
         ldy     #>lmovenum
         jsr     input_string
         lda     #$00
         sta     move_number
@LAA1F:  jsr     @LAA55
         cmp     #$0d
         beq     @LAA1F
         pha
         ora     #$80
         jsr     k_out_to_channel
         jsr     @LAA55
         cmp     #$0d
         beq     @LAA49
         jsr     LA118
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
@LAA49:  pla
         sec
         sbc     #$30
         clc
         adc     move_number
         sta     move_number
         jmp     @LAA72

@LAA55:  jsr     LA10C
         cmp     #$0d
         beq     @LAA64
         cmp     #$30
         bcc     @LAA55
         cmp     #$3a
         bcs     @LAA55
@LAA64:  rts

@LAA65:  lda     #$00
         sta     next_color
         sta     $1c
         lda     #$01
         sta     move_number
         jsr     LAAAB
@LAA72:  ldx     #<lchoose_color
         ldy     #>lchoose_color
         jsr     input
         ldx     #$80
         cmp     #'W'
         beq     @LAA85
         cmp     #'B'
         bne     @LAA72
         ldx     #$00
@LAA85:  stx     human_color
@LAA87:  ldx     #<lchoose_level
         ldy     #>lchoose_level
         jsr     input
         cmp     #'0'
         bcc     @LAA87
         cmp     #'7'
         bcs     @LAA87
         and     #$0f
         sta     level
         lda     #$00
         ldx     #$1b
@LAA9E:  sta     $12fe,x
         dex
         bpl     @LAA9E
         lda     #$01
         sta     next_color+1
         jmp     LBCE4

LAAAB:   ldx     #$77
         lda     #$ff
@LAAAF:  sta     $146e,x
         dex
         bpl     @LAAAF
         ldx     #$08
         ldy     #$00
@LAAB9:  lda     la634+216,y
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
         bne     @LAAB9
         rts

sargon_moves:
         jsr     LA3F9
         lda     #$02
         sta     $97a7
         jsr     calc_move
         lda     scoreH_stack
         bne     @LAAF6
         lda     scoreL_stack
         cmp     #$01
         beq     @mate0
@LAAF6:  jsr     LAD76
         bcs     @stalemate
         jsr     LAD54
         ldx     #$b4
         jsr     LA161
         jsr     LAC32
         lda     scoreH_stack
         cmp     #$ff
         bne     @LAB23
         lda     scoreL_stack
         cmp     #$fe
         beq     @LAB34
         ldx     #<lmatein2
         ldy     #>lmatein2
         jsr     show_msg
         lda     scoreL_stack
         eor     #$ff
         lsr     A
         adc     #$6f
         sta     $1f6c
@LAB23:  rts

@stalemate:
         ldx     #<lstalemate
         ldy     #>lstalemate
         jsr     show_msg
         jmp     @LAB3B

@mate0:  lda     next_color
         eor     #$80
         sta     next_color
@LAB34:  ldx     #<lmate
         ldy     #>lmate
         jsr     show_msg
@LAB3B:  ldx     #$c8
         jsr     LA161
         cli
         jsr     LA10C
         jmp     LA911

LAB47:   tay
         lda     #$2f
         sta     $033c,x
         tya
@LAB4E:  cmp     #$0a
         bcc     @LAB5A
         inc     $033c,x
         sec
         sbc     #$0a
         bne     @LAB4E
@LAB5A:  dex
         ora     #$40
         sta     $033c,x
         rts

LAB61:   lda     $033c,x
         and     #$7f
         cmp     #$31
         bcc     @LAB98
         cmp     #$39
         bcs     @LAB98
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
         bcc     @LAB98
         cmp     #$49
         bcs     @LAB98
         and     #$0f
         clc
         adc     $0341
         sta     $07,x
         dex
         dex
         rts

@LAB98:  sec
         rts

LAB9A:   lda     #$01
         sta     $8e
         lda     #$10
         sta     $8f
         jsr     LAEC0
@LABA5:  jsr     LA0A6
         ldx     #$04
@LABAA:  jsr     LAB61
         bcs     @LABBF
         bpl     @LABAA
         jsr     LADDA
         bcs     @LABBF
         jsr     LAD54
         jsr     LA3F9
         jmp     LAC32

@LABBF:  ldx     #<linvalid_move
         ldy     #>linvalid_move
         jsr     show_msg
         ldx     #$aa
         jsr     LA161
         jmp     @LABA5

LABCE:   jsr     LA10C
         jsr     LA3CF
         ldx     #$15
@LABD6:  stx     $07
@LABD8:  jsr     LA210
         jsr     k_getchar
         beq     @LABD8
         cmp     #$0d
         bne     @LABEB
         jsr     LBCE4
         jsr     LA009
         rts

@LABEB:  jsr     LA225
         cpy     #$ff
         bne     @LABD6
         ldx     #$06
@LABF4:  cmp     lpnbrqk,x
         beq     @LABFF
         dex
         bne     @LABF4
         txa
         beq     @LAC20
@LABFF:  stx     $aa
         jsr     LA10C
         ldy     #$00
         cmp     #$57
         beq     @LAC0C
         ldy     #$80
@LAC0C:  tya
         ora     $aa
         sta     $aa
         jsr     LA10C
         ldy     $aa
         and     #$01
         lsr     A
         ror     A
         ror     A
         sta     $aa
         tya
         ora     $aa
@LAC20:  ldx     $07
         sta     $146e,x
         sta     $aa
         jsr     LA2DB
         jsr     LA296
         ldx     $07
         jmp     @LABD8

LAC32:   jsr     LACB6
         lda     $0b
         sta     $07
         lda     $0c
         sta     $08
         jsr     LA32B
         bit     $1332
         bmi     @LAC56
         bvc     LACB5
         lda     #$0a
         bit     next_color
         bmi     @LAC4F
         lda     #$f6
@LAC4F:  clc
         adc     $08
         sta     $08
         bne     @LAC6B
@LAC56:  lda     $08
         sec
         sbc     $07
         cmp     #$02
         beq     @LAC64
         inc     $08
         asl     A
         bne     @LAC68
@LAC64:  dec     $08
         inc     $07
@LAC68:  clc
         adc     $07
@LAC6B:  sta     $07
         jmp     LA32B

LAC70:   bit     $1332
         bmi     @LAC9D
         bvs     @LAC97
         ldx     #$01
         lda     $0b
         jsr     LAB47
         ldx     #$04
         lda     $0c
         jsr     LAB47
         ldx     #$2d
         lda     $1328
         beq     @LAC8E
         ldx     #$58
@LAC8E:  stx     $033e
         ldx     #$3c
         ldy     #$03
         bne     @LACB0

@LAC97:  ldx     #<lpxpep
         ldy     #>lpxpep
         bne     @LACB0

@LAC9D:  lda     $0c
         sec
         sbc     $0b
         cmp     #$02
         beq     @LACAC
         ldx     #<looo
         ldy     #>looo
         bne     @LACB0

@LACAC:  ldx     #<loo
         ldy     #>loo
@LACB0:  lda     #$00
         sta     $0341
LACB5:   rts

LACB6:   jsr     LAC70
         jsr     LA09B
LACBC:   lda     next_color
         eor     #$80
         jsr     LBBD3
         bcc     LACB5
         ldx     #<lcheck
         ldy     #>lcheck
         jmp     show_msg

LACCC:   ldx     #$30
         lda     move_number
@LACD0:  cmp     #$0a
         bcc     @LACDA
         inx
         sec
         sbc     #$0a
         bne     @LACD0
@LACDA:  clc
         adc     #$30
         sta     $033d
         txa
         cmp     #$40
         bcs     @LACE9
         cmp     #$30
         bne     @LACEB
@LACE9:  lda     #$20
@LACEB:  sta     $033c
         lda     #$00
         sta     $033e
         ldx     #$3c
         ldy     #$03
         jmp     LA09B

LACFA:   jsr     LA06E
         lda     #$00
         sta     $f9
         sta     $00
         jsr     LAC70
         jsr     LAD12
         lda     #$00
         sta     $f9
         sta     $00
         jmp     LACBC

LAD12:   stx     $05
         sty     $06
         ldy     #$00
@LAD18:  lda     ($05),y
         beq     @LAD26
         sty     $a3
         jsr     LA08A
         ldy     $a3
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

LAD38:   ldy     level+1
         cpy     #$02
         bcc     @LAD51
         lda     $9f
         sta     $07
         lda     $b4
         sta     $0a
         jsr     LADDA
         bcs     @LAD51
         jsr     LB8C7
         jsr     LACFA
@LAD51:  jmp     LA0F6

LAD54:   ldx     #$17
@LAD56:  lda     $12fe,x
         sta     $1302,x
         dex
         bpl     @LAD56
         lda     $0b
         sta     $12fe
         lda     $0c
         sta     $12ff
         lda     $1328
         sta     $1300
         lda     $1332
         sta     $1301
         rts

LAD76:   lda     $6a
         bit     human_color
         bmi     @LAD81
         eor     #$ff
         clc
         adc     #$01
@LAD81:  clc
         adc     #$80
         cmp     #$81
         bcs     @LADD4
         lda     $12fe
         cmp     $130e
         bne     @LADD4
         lda     $12ff
         cmp     $130f
         bne     @LADD4
         lda     $1001
         cmp     $130a
         bne     @LADD4
         lda     $1002
         cmp     $130b
         bne     @LADD4
         lda     #$02
         sta     $8d
         jsr     LADF2
         bcs     @LADD4
         jsr     LB3AF
         lda     $1328
         and     #$07
         tax
         lda     la634+223,x
         asl     A
         sec
         sbc     $63
         bmi     @LADD1
         lda     $1003
         sta     $1001
         lda     $1004
         sta     $1002
         clc
         rts

@LADD1:  jsr     LB8C7
@LADD4:  lda     #$00
         sta     $8d
         beq     LADF2

LADDA:   ldx     #$fe
@LADDC:  inx
         inx
         lda     $1001,x
         beq     LADFD
         cmp     $07
         bne     @LADDC
         lda     $1002,x
         cmp     $0a
         bne     @LADDC
         stx     $9c
         stx     $8d
LADF2:   jsr     LB7C4
         jsr     LBBD1
         bcc     LADFE
         jsr     LB8C7
LADFD:   sec
LADFE:   rts

LADFF:   ldx     $0d
         lda     la634+235,x
         sta     $10
         lda     la634+229,x
         cmp     #$10
         bne     @LAE14
         bit     $13
         bpl     @LAE14
         clc
         adc     #$04
@LAE14:  sta     $0f
@LAE16:  ldx     $0f
         lda     la634+242,x
         sta     $11
         ldx     $07
@LAE1F:  clc
         txa
         adc     $11
         tax
         lda     $146e,x
         beq     @LAE33
         cmp     #$ff
         beq     @LAE4C
         eor     $13
         bpl     @LAE4C
         eor     $13
@LAE33:  sta     $0e
         lda     $0d
         cmp     #$01
         beq     @LAE53
         jsr     LAE79
         lda     $0e
         bne     @LAE4C
         lda     $0d
         cmp     #$06
         beq     @LAE4C
         cmp     #$03
         bcs     @LAE1F
@LAE4C:  inc     $0f
         dec     $10
         bne     @LAE16
         rts

@LAE53:  lda     $10
         cmp     #$03
         bcs     @LAE69
         lda     $0e
         bne     @LAE68
         jsr     LAE79
         bit     $13
         bvs     @LAE68
         dec     $10
         bne     @LAE1F
@LAE68:  rts

@LAE69:  lda     $0e
         beq     @LAE73
         jsr     LAE79
         jmp     @LAE4C

@LAE73:  jsr     LAE83
         jmp     @LAE4C

LAE79:   lda     $07
         sta     ($8b),y
         iny
         txa
         sta     ($8b),y
         iny
         rts

LAE83:   lda     $07
         bit     $13
         bpl     @LAE8C
         clc
         adc     #$0a
@LAE8C:  cmp     #$3d
         bcc     @LAEBF
         cmp     #$45
         bcs     @LAEBF
         lda     $0b
         sec
         sbc     $0c
         cmp     #$14
         beq     @LAEA1
         cmp     #$ec
         bne     @LAEBF
@LAEA1:  stx     $08
         ldx     $0c
         lda     $146e,x
         and     #$07
         cmp     #$01
         bne     @LAEBF
         txa
         ldx     $08
         sec
         sbc     $08
         cmp     #$0a
         beq     @LAEBC
         cmp     #$f6
         bne     @LAEBF
@LAEBC:  jmp     LAE79

@LAEBF:  rts

LAEC0:   ldy     next_color+1
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
         jsr     @LAF13
         ldx     #$15
         stx     $07
@LAEDF:  lda     $146e,x
         beq     @LAEF7
         cmp     #$ff
         beq     @LAEF7
         eor     next_color
         bmi     @LAEF7
         eor     next_color
         sta     $13
         and     #$07
         sta     $0d
         jsr     LADFF
@LAEF7:  inc     $07
         ldx     $07
         cpx     #$63
         bcc     @LAEDF
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

@LAF13:  ldx     $6c
         lda     next_color
         bpl     @LAF1B
         ldx     $6d
@LAF1B:  lda     $146e,x
         and     #$40
         bne     @LAF79
         lda     $146e,x
         sta     $13
         stx     $07
         jsr     LAF7A
         bcs     @LAF79
         lda     #$02
         sta     $12
         lda     #$ff
         sta     $09
         lda     #$03
@LAF38:  clc
         adc     $07
         tax
         lda     $146e,x
         and     #$7f
         cmp     #$04
         bne     @LAF66
@LAF45:  txa
         clc
         adc     $09
         tax
         lda     $146e,x
         bne     @LAF66
         lda     $12
         cmp     #$03
         beq     @LAF5A
         jsr     LAF7A
         bcs     @LAF66
@LAF5A:  dec     $12
         bne     @LAF45
         txa
         sec
         sbc     $09
         tax
         jsr     LAE79
@LAF66:  lda     $09
         bpl     @LAF79
         ldx     $07
         lda     #$03
         sta     $12
         lda     #$01
         sta     $09
         lda     #$fc
         jmp     @LAF38

@LAF79:  rts

LAF7A:   stx     $08
         lda     #$10
         sta     $10
         lda     #$00
         sta     $0f
@LAF84:  lda     #$fe
         sta     $0e
         ldx     $0f
         lda     la634+242,x
         sta     $11
         ldx     $08
@LAF91:  inc     $0e
         clc
         txa
         adc     $11
         tax
         lda     $146e,x
         beq     @LAFA3
         cmp     #$ff
         beq     @LAFA9
         bne     @LAFB6

@LAFA3:  lda     $10
         cmp     #$09
         bcs     @LAF91
@LAFA9:  inc     $0f
         dec     $10
         bne     @LAF84
         clc
         bcc     @LAFB3

@LAFB2:  sec
@LAFB3:  ldx     $08
         rts

@LAFB6:  eor     $13
         bpl     @LAFA9
         eor     $13
         and     #$07
         sta     $0d
         lda     $10
         cmp     #$09
         bcc     @LB007
         lda     $0d
         cmp     #$05
         beq     @LAFB2
         bit     $0e
         bpl     @LAFD4
         cmp     #$06
         beq     @LAFB2
@LAFD4:  lda     $10
         cmp     #$0d
         bcc     @LAFFE
         lda     $0d
         cmp     #$03
         beq     @LAFB2
         bit     $0e
         bpl     @LAFA9
         cmp     #$01
         bne     @LAFA9
         lda     $13
         bmi     @LAFF5
         lda     $10
         cmp     #$0f
         bcc     @LAFA9
         jmp     @LAFB2

@LAFF5:  lda     $10
         cmp     #$0f
         bcs     @LAFA9
         jmp     @LAFB2

@LAFFE:  lda     $0d
         cmp     #$04
         bne     @LAFA9
         jmp     @LAFB2

@LB007:  lda     $0d
         cmp     #$02
         bne     @LAFA9
         beq     @LAFB2

LB00F:   lda     #$00
         sta     $6f
         lda     #$7f
         sta     $6e
         ldx     #$15
         stx     $07
@LB01B:  lda     $146e,x
         beq     @LB02D
         cmp     #$ff
         beq     @LB02D
         sta     $13
         and     #$07
         sta     $0d
         jsr     @LB036
@LB02D:  inc     $07
         ldx     $07
         cpx     #$63
         bcc     @LB01B
         rts

@LB036:  ldx     $0d
         lda     la634+235,x
         sta     $10
         lda     la634+229,x
         cmp     #$10
         bne     @LB04F
         dec     $10
         dec     $10
         bit     $13
         bpl     @LB04F
         clc
         adc     #$04
@LB04F:  sta     $0f
@LB051:  ldx     $0f
         lda     la634+242,x
         sta     $11
         ldx     $07
         lda     #$00
         sta     $12
@LB05E:  clc
         txa
         adc     $11
         tax
         lda     $146e,x
         cmp     #$ff
         bne     @LB071
@LB06A:  inc     $0f
         dec     $10
         bne     @LB051
         rts

@LB071:  sta     $14
         and     #$07
         sta     $0e
         bit     $12
         bvs     @LB0B2
         lda     la634+260,x
         lsr     A
         bit     $13
         bpl     @LB088
         eor     #$ff
         clc
         adc     #$01
@LB088:  clc
         adc     $68
         sta     $68
         lda     $14
         beq     @LB0E2
         eor     $13
         bpl     @LB0CB
         lda     $0e
         cmp     #$06
         bne     @LB09F
         lda     #$01
         sta     $69
@LB09F:  lda     $12
         and     #$01
         bne     @LB0A7
         ora     #$40
@LB0A7:  ora     #$20
         sta     $12
         ldy     $6e
         dec     $6e
         jmp     @LB0D5

@LB0B2:  lda     $0e
         beq     @LB05E
         cmp     #$01
         beq     @LB06A
         lda     $14
         eor     $13
         bpl     @LB06A
         txa
         ora     #$80
         tax
         lda     $12
         and     #$bf
         jmp     @LB0A7

@LB0CB:  lda     $12
         ora     #$01
         sta     $12
         ldy     $6f
         inc     $6f
@LB0D5:  txa
         sta     $1346,y
         lda     $12
         and     #$80
         ora     $07
         sta     $13c6,y
@LB0E2:  lda     $0d
         cmp     #$03
         bcs     @LB0EB
@LB0E8:  jmp     @LB06A

@LB0EB:  cmp     #$06
         beq     @LB0E8
         bit     $12
         bvc     @LB0F6
@LB0F3:  jmp     @LB05E

@LB0F6:  lda     $12
         and     #$20
         bne     @LB0E8
         lda     $0e
         beq     @LB0F3
         lda     $0d
         cmp     #$04
         bne     @LB119
         lda     $0e
         cmp     #$04
         beq     @LB0F3
         cmp     #$05
         bne     @LB0E8
@LB110:  lda     $12
         ora     #$80
         sta     $12
         jmp     @LB05E

@LB119:  cmp     #$03
         bne     @LB129
         lda     $0e
         cmp     #$01
         beq     @LB153
         cmp     #$05
         bne     @LB0E8
         beq     @LB110

@LB129:  lda     $0e
         cmp     #$03
         bne     @LB138
         lda     $10
         cmp     #$05
         bcc     @LB0E8
         jmp     @LB05E

@LB138:  cmp     #$04
         bne     @LB145
         lda     $10
         cmp     #$05
         bcc     @LB0F3
         jmp     @LB06A

@LB145:  cmp     #$05
         beq     @LB0F3
         cmp     #$01
         bne     @LB0E8
         lda     $10
         cmp     #$05
         bcc     @LB0E8
@LB153:  lda     $13
         eor     $11
         bmi     @LB0E8
         lda     $12
         ora     #$20
         sta     $12
         jmp     @LB05E

LB162:   lda     $6e
         eor     #$ff
         clc
         adc     #$80
         beq     @LB179
         sta     $10
         ldy     #$7f
@LB16F:  lda     $1346,y
         bmi     @LB17A
@LB174:  dey
         dec     $10
         bne     @LB16F
@LB179:  rts

@LB17A:  sty     $11
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
         beq     @LB1B6
         ldx     $07
         lda     $146e,x
         and     #$07
         cmp     $0f
         bcc     @LB1B6
         lda     $6f
         beq     @LB208
         sta     $12
         ldx     #$00
         lda     $09
@LB1AC:  cmp     $1346,x
         beq     @LB174
         inx
         dec     $12
         bne     @LB1AC
@LB1B6:  lda     $6f
         beq     @LB208
         sta     $12
         ldx     #$00
@LB1BE:  lda     $13c6,x
         and     #$7f
         cmp     $08
         bne     @LB203
         lda     $1346,x
         and     #$7f
         cmp     $09
         beq     @LB203
         sta     $0a
         tay
         lda     $146e,y
         and     #$07
         cmp     $0f
         bcs     @LB203
         lda     $6e
         eor     #$ff
         clc
         adc     #$80
         sta     $0d
         ldy     #$7f
@LB1E7:  lda     $13c6,y
         and     #$7f
         cmp     $07
         bne     @LB1F9
         lda     $1346,y
         and     #$7f
         cmp     $0a
         beq     @LB203
@LB1F9:  dey
         dec     $0d
         bne     @LB1E7
         lda     #$00
         sta     $1346,x
@LB203:  inx
         dec     $12
         bne     @LB1BE
@LB208:  lda     $6e
         eor     #$ff
         clc
         adc     #$80
         sta     $12
         ldx     #$7f
@LB213:  lda     $13c6,x
         and     #$7f
         cmp     $08
         bne     @LB26E
         lda     $1346,x
         and     #$7f
         cmp     $07
         beq     @LB26E
         sta     $0a
         tay
         lda     $0f
         cmp     #$06
         beq     @LB24A
         lda     $146e,y
         and     #$07
         cmp     $0f
         bcs     @LB26E
         lda     $1345,x
         bpl     @LB24A
         and     #$7f
         tay
         lda     $146e,y
         and     #$07
         cmp     $0f
         bcc     @LB269
         bcs     @LB26E

@LB24A:  lda     $6f
         beq     @LB269
         sta     $0d
         ldy     #$00
@LB252:  lda     $13c6,y
         and     #$7f
         cmp     $07
         bne     @LB264
         lda     $1346,y
         and     #$7f
         cmp     $0a
         beq     @LB26E
@LB264:  iny
         dec     $0d
         bne     @LB252
@LB269:  lda     #$00
         sta     $1346,x
@LB26E:  dex
         dec     $12
         bne     @LB213
         ldy     $11
         jmp     @LB174

LB278:   lda     $0a
         sta     $10
         ldx     #$0e
         lda     #$00
         sta     $05
         sta     $06
@LB284:  sta     $1319,x
         dex
         bne     @LB284
         sta     $0f
@LB28C:  lda     $08
         ora     #$80
         sta     $1346,y
         lda     $13c6,y
         sta     $07
         and     #$7f
         tax
         lda     $146e,x
         bmi     @LB2A6
         ldx     #$00
         inc     $05
         bne     @LB2AA
@LB2A6:  ldx     #$07
         inc     $06
@LB2AA:  and     #$07
         sta     $0d
         lda     $07
         bpl     @LB2B8
         txa
         clc
         adc     #$06
         bne     @LB2BC
@LB2B8:  txa
         clc
         adc     $0d
@LB2BC:  tax
@LB2BD:  lda     $1319,x
         beq     @LB2D0
         and     #$f0
         beq     @LB2C9
         inx
         bne     @LB2BD
@LB2C9:  lda     $1319,x
         asl     A
         asl     A
         asl     A
         asl     A
@LB2D0:  ora     $0d
         sta     $1319,x
         lda     $0f
         beq     @LB2E8
@LB2D9:  lda     $08
@LB2DB:  dec     $10
         beq     @LB304
         iny
         cmp     $1346,y
         bne     @LB2DB
         jmp     @LB28C

@LB2E8:  lda     $08
@LB2EA:  dec     $10
         bne     @LB2FB
         lda     $6f
         sta     $10
         ldy     #$ff
         inc     $0f
         inc     $10
         jmp     @LB2D9

@LB2FB:  dey
         cmp     $1346,y
         bne     @LB2EA
         jmp     @LB28C

@LB304:  rts

LB305:   ldx     $08
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
         bpl     @LB32A
         inc     $12
@LB32A:  jsr     @LB36E
         beq     @LB35C
         eor     #$ff
         adc     #$01
         clc
         adc     $0e
         sta     $0e
         cmp     $0f
         bcc     @LB344
         lda     $0e
         sta     $0f
         lda     $0d
         sta     $11
@LB344:  jsr     @LB36E
         beq     @LB365
         adc     $0e
         sta     $0e
         cmp     $0d
         bcs     @LB32A
         lda     $0e
         sta     $0d
         lda     $0f
         sta     $10
         jmp     @LB32A

@LB35C:  lda     $0f
         cmp     $11
         bcc     @LB364
         lda     $11
@LB364:  rts

@LB365:  lda     $0d
         cmp     $10
         bcs     @LB36D
         lda     $10
@LB36D:  rts

@LB36E:  lda     $12
         bne     @LB38B
         inc     $12
         lda     $06
         beq     @LB3AE
         dec     $06
@LB37A:  iny
         lda     $1319,y
         beq     @LB37A
         pha
         lsr     A
         lsr     A
         lsr     A
         lsr     A
         sta     $1319,y
         dey
         bne     @LB3A2
@LB38B:  dec     $12
         lda     $05
         beq     @LB3AE
         dec     $05
@LB393:  inx
         lda     $1319,x
         beq     @LB393
         pha
         lsr     A
         lsr     A
         lsr     A
         lsr     A
         sta     $1319,x
         dex
@LB3A2:  pla
         and     #$0f
         sty     $14
         tay
         lda     la634+223,y
         ldy     $14
         clc
@LB3AE:  rts

LB3AF:   inc     $70
         bne     @LB3BB
         inc     $71
         bne     @LB3BB
         dec     $70
         dec     $71
@LB3BB:  lda     #$00
         ldx     #$08
@LB3BF:  sta     $61,x
         dex
         bpl     @LB3BF
         jsr     LB00F
         jsr     LB162
         lda     $6e
         eor     #$ff
         clc
         adc     #$80
         beq     @LB437
         sta     $0a
         ldy     #$7f
@LB3D7:  lda     $1346,y
         bmi     @LB42A
         beq     @LB42A
         sta     $08
         sty     $09
         jsr     LB278
         jsr     LB305
         sec
         sbc     #$80
         bmi     @LB428
         beq     @LB406
         sta     $0d
         lda     $13
         eor     next_color
         bmi     @LB410
         lda     $0d
         cmp     $63
         bcc     @LB3FF
         sta     $63
@LB3FF:  lda     $67
         sec
         sbc     #$08
         sta     $67
@LB406:  lda     $08
         cmp     $0c
         bne     @LB428
         sta     $66
         beq     @LB428

@LB410:  lda     $0d
         cmp     $64
         bcc     @LB41B
         ldx     $64
         sta     $64
         txa
@LB41B:  cmp     $65
         bcc     @LB421
         sta     $65
@LB421:  lda     $67
         clc
         adc     #$04
         sta     $67
@LB428:  ldy     $09
@LB42A:  dey
         dec     $0a
         bne     @LB3D7
         lda     $66
         beq     @LB437
         lda     #$00
         sta     $65
@LB437:  lda     level+2
         beq     @LB43E
         jsr     LB75C
@LB43E:  jsr     @LB4C2
         lda     $65
         asl     $63
         sec
         sbc     $63
         bit     next_color
         bpl     @LB451
         eor     #$ff
         clc
         adc     #$01
@LB451:  clc
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
         bpl     @LB46A
         eor     #$ff
         clc
         adc     #$01
@LB46A:  and     #$ff
         jsr     @LB4A5
         lda     $68
         jsr     @LB4A5
         lda     $1e
         jsr     @LB4A5
         lda     $1e
         jsr     @LB4A5
         lda     $6b
         jsr     @LB4A5
         lda     $6b
         jsr     @LB4A5
         lda     next_color
         bpl     @LB49D
         lda     $61
         clc
         eor     #$ff
         adc     #$01
         sta     $61
         lda     $62
         eor     #$ff
         adc     #$00
         sta     $62
@LB49D:  lda     $62
         clc
         adc     #$80
         sta     $62
         rts

@LB4A5:  clc
         bmi     @LB4B1
         adc     $61
         sta     $61
         bcc     @LB4B0
         inc     $62
@LB4B0:  rts

@LB4B1:  adc     $61
         sta     $61
         bcs     @LB4B9
         dec     $62
@LB4B9:  rts

@LB4BA:  lda     #$04
@LB4BC:  clc
@LB4BD:  adc     $6b
         sta     $6b
         rts

@LB4C2:  lda     #$00
         sta     $0e
         sta     $11
         sta     $12
         sta     $6b
         sta     $0f
         sta     $10
         ldx     #$1f
@LB4D2:  lda     #$06
         sta     $0d
@LB4D6:  lda     $146e,x
         and     #$07
         cmp     #$01
         bne     @LB502
         lda     $146e,x
         bmi     @LB4F4
         lda     $11
         beq     @LB4ED
         lda     #$fc
         jsr     @LB4BC
@LB4ED:  lda     $0d
         sta     $11
         jmp     @LB502

@LB4F4:  lda     $12
         beq     @LB4FE
         jsr     @LB4BA
         jmp     @LB502

@LB4FE:  lda     $0d
         sta     $12
@LB502:  txa
         clc
         adc     #$0a
         tax
         dec     $0d
         bne     @LB4D6
         lda     $12
         bne     @LB562
         lda     $11
         beq     @LB55B
         lda     $0e
         ora     #$40
         sta     $0e
         jsr     @LB4BA
         lda     move_number
         cmp     #$14
         bcc     @LB532
         lda     #$07
         sec
         sbc     $11
         tay
         lda     #$00
         sec
@LB52B:  rol     A
         dey
         bne     @LB52B
         jsr     @LB4BD
@LB532:  lda     $10
         beq     @LB54D
         cmp     $11
         beq     @LB548
         sec
         sbc     #$01
         cmp     $11
         beq     @LB548
         clc
         adc     #$02
         cmp     $11
         bne     @LB54D
@LB548:  lda     #$02
         jsr     @LB4BC
@LB54D:  lda     $0f
         beq     @LB555
         cmp     $11
         bcc     @LB55B
@LB555:  lda     $0e
         ora     #$80
         sta     $0e
@LB55B:  lda     $0f
         beq     @LB562
         jsr     @LB4BA
@LB562:  lda     $11
         bne     @LB5B8
         lda     $12
         beq     @LB5AF
         lda     $0e
         ora     #$10
         sta     $0e
         lda     #$fc
         jsr     @LB4BC
         lda     move_number
         cmp     #$14
         bcc     @LB588
         lda     #$ff
         ldy     $12
@LB57F:  dey
         beq     @LB585
         asl     A
         bne     @LB57F
@LB585:  jsr     @LB4BC
@LB588:  lda     $0f
         beq     @LB5A3
         cmp     $12
         beq     @LB59E
         clc
         adc     #$01
         cmp     $12
         beq     @LB59E
         sec
         sbc     #$02
         cmp     $12
         bne     @LB5A3
@LB59E:  lda     #$fe
         jsr     @LB4BC
@LB5A3:  lda     $12
         cmp     $10
         bcc     @LB5AF
         lda     $0e
         ora     #$20
         sta     $0e
@LB5AF:  lda     $10
         beq     @LB5B8
         lda     #$fc
         jsr     @LB4BC
@LB5B8:  lda     $0e
         and     #$04
         beq     @LB5EA
         lda     $11
         beq     @LB5D9
         cmp     $10
         beq     @LB5D4
         clc
         adc     #$01
         cmp     $10
         beq     @LB5D4
         sec
         sbc     #$02
         cmp     $10
         bne     @LB5D9
@LB5D4:  lda     #$02
         jsr     @LB4BC
@LB5D9:  lda     $0e
         and     #$08
         beq     @LB5EA
         lda     $12
         beq     @LB5E7
         cmp     $10
         bcc     @LB5EA
@LB5E7:  jsr     @LB4BA
@LB5EA:  lda     $0e
         and     #$01
         beq     @LB61C
         lda     $12
         beq     @LB60B
         cmp     $0f
         beq     @LB606
         clc
         adc     #$ff
         cmp     $0f
         beq     @LB606
         clc
         adc     #$02
         cmp     $0f
         bne     @LB60B
@LB606:  lda     #$fe
         jsr     @LB4BC
@LB60B:  lda     $0e
         and     #$02
         beq     @LB61C
         lda     $0f
         cmp     $11
         bcc     @LB61C
         lda     #$fc
         jsr     @LB4BC
@LB61C:  lda     $0e
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
         bne     @LB63E
         jmp     @LB5B8

@LB63E:  cmp     #$ec
         bne     @LB643
         rts

@LB643:  jmp     @LB4D2

LB646:   lda     $13
         and     #$07
         cmp     #$01
         bne     @LB6C4
         lda     move_number
         cmp     #$0a
         bcs     @LB681
         lda     $0b
         bit     $13
         bpl     @LB65D
         sec
         sbc     #$32
@LB65D:  cmp     #$22
         beq     @LB671
         cmp     #$23
         beq     @LB671
         lda     $0d
         and     #$20
         beq     @LB66C
         rts

@LB66C:  lda     #$f8
         jmp     @LB73C

@LB671:  sec
         sbc     $0c
         cmp     #$ec
         beq     @LB67C
         cmp     #$e2
         bne     @LB6C3
@LB67C:  lda     #$04
         jmp     @LB73C

@LB681:  cmp     #$19
         bcs     @LB6C3
         lda     $13
         bmi     @LB69F
         lda     $6c
         cmp     #$1a
         bcc     @LB697
         cmp     #$1d
         bcs     @LB6C3
         lda     #$00
         beq     @LB6B3

@LB697:  cmp     #$18
         bcs     @LB6C3
         lda     #$05
         bne     @LB6B3

@LB69F:  lda     $6d
         cmp     #$60
         bcc     @LB6A9
         lda     #$ce
         bne     @LB6B3

@LB6A9:  cmp     #$5e
         bcs     @LB6C3
         cmp     #$5b
         bcc     @LB6C3
         lda     #$d3
@LB6B3:  clc
         adc     $0b
         cmp     #$27
         bcs     @LB6C3
         cmp     #$24
         bcc     @LB6C3
         lda     #$f4
         jmp     @LB73C

@LB6C3:  rts

@LB6C4:  cmp     #$04
         bcc     @LB6F9
         cmp     #$06
         beq     @LB6D7
         lda     move_number
         cmp     #$07
         bcs     @LB6C3
         lda     #$f0
         jmp     @LB73C

@LB6D7:  lda     $0d
         bpl     @LB6EF
         lda     $0c
         bit     $13
         bpl     @LB6E4
         sec
         sbc     #$46
@LB6E4:  sec
         sbc     #$0f
         cmp     #$0c
         beq     @LB73C
         lda     #$06
         bne     @LB73C

@LB6EF:  lda     move_number
         cmp     #$1e
         bcs     @LB6C3
         lda     #$f4
         bne     @LB73C

@LB6F9:  lda     $0d
         and     #$10
         beq     @LB703
         lda     #$0a
         bne     @LB70D

@LB703:  lda     move_number
         cmp     #$09
         bcs     @LB6C3
         lda     #$f8
         bne     @LB70D

@LB70D:  sta     $0f
         lda     move_number
         cmp     #$0f
         bcs     @LB73E
         lda     $0c
         bit     $13
         bpl     @LB71E
         sec
         sbc     #$1e
@LB71E:  cmp     #$2c
         beq     @LB726
         cmp     #$2d
         bne     @LB73E
@LB726:  sec
         sbc     #$0a
         bit     $13
         bpl     @LB730
         clc
         adc     #$32
@LB730:  tax
         lda     $146e,x
         and     #$07
         cmp     #$01
         bne     @LB73E
         lda     #$e8
@LB73C:  sta     $0f
@LB73E:  lda     $0d
         and     #$01
         beq     @LB750
         lda     $13
         bmi     @LB754
@LB748:  lda     $1e
         sec
         sbc     $0f
         sta     $1e
         rts

@LB750:  lda     $13
         bmi     @LB748
@LB754:  lda     $1e
         clc
         adc     $0f
         sta     $1e
         rts

LB75C:   lda     $6c
         ldy     #$00
@LB760:  cmp     #$0a
         bcc     @LB76A
         iny
         sec
         sbc     #$0a
         bne     @LB760
@LB76A:  sta     $0d
         sty     $0e
         lda     $6d
         ldy     #$00
@LB772:  cmp     #$0a
         bcc     @LB77C
         iny
         sec
         sbc     #$0a
         bne     @LB772
@LB77C:  sec
         sbc     $0d
         bmi     @LB786
         eor     #$ff
         clc
         adc     #$01
@LB786:  sta     $0d
         tya
         sec
         sbc     $0e
         bmi     @LB793
         eor     #$ff
         clc
         adc     #$01
@LB793:  clc
         adc     $0d
         clc
         adc     #$0e
         sta     $0d
         ldx     #$00
         lda     $6a
         bmi     @LB7A2
         inx
@LB7A2:  ldy     $6c,x
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
         bpl     @LB7BF
         lda     $68
         eor     #$ff
         clc
         adc     #$01
         sta     $68
@LB7BF:  lda     #$00
         sta     $64
         rts

LB7C4:   ldy     $8d
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
         bvs     @LB7EA
         lda     #$10
         sta     $0d
         lda     $13
         ora     #$40
         sta     $13
@LB7EA:  ldx     $0c
         lda     $146e,x
         sta     $14
         lda     $13
         sta     $146e,x
         and     #$07
         cmp     #$01
         beq     @LB82D
         cmp     #$06
         bne     @LB803
         jmp     @LB883

@LB803:  jsr     LB646
         ldy     next_color+1
         lda     $0d
         sta     $1331,y
         lda     $14
         sta     $1327,y
         beq     @LB82C
         and     #$07
         tax
         lda     $14
         bpl     @LB824
         lda     $6a
         clc
         adc     la634+223,x
         sta     $6a
         rts

@LB824:  lda     $6a
         sec
         sbc     la634+223,x
         sta     $6a
@LB82C:  rts

@LB82D:  lda     $0c
         cmp     #$5b
         bcs     @LB837
         cmp     #$1d
         bcs     @LB856
@LB837:  lda     $0d
         ora     #$20
         sta     $0d
         lda     $146e,x
         ora     #$04
         sta     $146e,x
         sta     $13
         bmi     @LB84C
         lda     #$07
         .byte   $2c
@LB84C:  lda     #$f9
         clc
         adc     $6a
         sta     $6a
         jmp     @LB803

@LB856:  lda     $0c
         sec
         sbc     $0b
         and     #$01
         beq     @LB803
         lda     $14
         bne     @LB803
         lda     $13
         bmi     @LB86A
         lda     #$f6
         .byte   $2c
@LB86A:  lda     #$0a
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
         jmp     @LB803

@LB883:  lda     $0c
         ldx     $13
         bmi     @LB88C
         sta     $6c
         .byte   $2c
@LB88C:  sta     $6d
         sta     $08
         sec
         sbc     $0b
         cmp     #$02
         beq     @LB8A3
         cmp     #$fe
         bne     @LB8C4
         inc     $08
         asl     A
         clc
         adc     $0b
         bne     @LB8AA
@LB8A3:  dec     $08
         clc
         adc     $0b
         adc     #$01
@LB8AA:  tax
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
@LB8C4:  jmp     @LB803

LB8C7:   ldy     $8d
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
         beq     @LB8F1
         lda     $13
         and     #$bf
         sta     $13
@LB8F1:  ldx     $0b
         lda     $13
         sta     $146e,x
         and     #$07
         cmp     #$01
         beq     @LB942
         cmp     #$06
         beq     @LB962
         lda     $0d
         and     #$20
         bne     @LB92A
@LB908:  inc     $0d
         jsr     LB646
         lda     $14
         beq     @LB929
         and     #$07
         tax
         lda     $14
         bmi     @LB921
         lda     $6a
         clc
         adc     la634+223,x
         sta     $6a
         rts

@LB921:  lda     $6a
         sec
         sbc     la634+223,x
         sta     $6a
@LB929:  rts

@LB92A:  lda     $13
         and     #$fb
         sta     $13
         sta     $146e,x
         bpl     @LB938
         lda     #$07
         .byte   $2c
@LB938:  lda     #$f9
         clc
         adc     $6a
         sta     $6a
         jmp     @LB908

@LB942:  bit     $0d
         bvc     @LB908
         ldx     $0c
         lda     #$00
         sta     $146e,x
         lda     $13
         bmi     @LB954
         lda     #$f6
         .byte   $2c
@LB954:  lda     #$0a
         clc
         adc     $0c
         tax
         lda     $14
         sta     $146e,x
         jmp     @LB908

@LB962:  ldx     $0b
         lda     $13
         bmi     @LB96B
         stx     $6c
         .byte   $2c
@LB96B:  stx     $6d
         lda     $0d
         bpl     @LB908
         lda     $0c
         sta     $08
         sec
         sbc     $0b
         cmp     #$02
         beq     @LB984
         inc     $08
         asl     A
         clc
         adc     $0b
         bne     @LB98B
@LB984:  dec     $08
         clc
         adc     $0b
         adc     #$01
@LB98B:  sta     $07
         ldx     $08
         lda     $146e,x
         and     #$bf
         sta     $10
         lda     #$00
         sta     $146e,x
         ldx     $07
         lda     $10
         sta     $146e,x
         jmp     @LB908

LB9A5:   ldy     next_color+1
         lda     $1445,y
         sta     $07
         lda     $144f,y
         sta     $08
         ldy     #$00
@LB9B3:  lda     ($8b),y
         beq     @LBA05
         sty     $0f
         jsr     @LBA06
@LB9BC:  lda     $11
         sta     $12
         sty     $10
@LB9C2:  iny
         iny
         lda     ($8b),y
         beq     @LB9D3
         jsr     @LBA06
         lda     $12
         cmp     $11
         bcs     @LB9C2
         bcc     @LB9BC

@LB9D3:  lda     $12
         beq     @LBA05
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
         jmp     @LB9B3

@LBA05:  rts

@LBA06:  iny
         lda     ($8b),y
         dey
         tax
         lda     $146e,x
         and     #$07
         asl     A
         asl     A
         sta     $11
         bne     @LBA24
         lda     $07
         cmp     ($8b),y
         bne     @LBA24
         inc     $11
         cpx     $08
         bne     @LBA24
         inc     $11
@LBA24:  rts

LBA25:   ldy     $8d
         lda     ($8b),y
         beq     @LBA45
         jsr     LADF2
         bcc     @LBA33
         jmp     @LBADC

@LBA33:  ldy     next_color+1
         cpy     level+1
         bcs     @LBA88
@LBA39:  jsr     @LBAEB
         jsr     LAEC0
         jsr     LB9A5
         jmp     LBA25

@LBA45:  lda     $1d
         bne     @LBA68
         dey
         dey
         sty     $8d
         jsr     LBBD1
         bcc     @LBA5D
         lda     next_color+1
         sta     $61
         lda     #$00
         sta     $62
         jmp     @LBA9C

@LBA5D:  lda     #$00
         sta     $61
         lda     #$80
         sta     $62
         jmp     @LBA9C

@LBA68:  ldy     next_color+1
         cpy     #$01
         bne     @LBA6F
         rts

@LBA6F:  jsr     @LBB06
         lda     scoreL_stack,y
         eor     #$ff
         clc
         adc     #$01
         sta     $61
         lda     scoreH_stack,y
         eor     #$ff
         adc     #$00
         sta     $62
         jmp     @LBA9E

@LBA88:  jsr     LBB86
         lda     next_color+1
         cmp     level
         bcc     @LBA99
         cmp     level+1
         bne     @LBA99
         lda     $69
         bne     @LBA39
@LBA99:  jsr     LB8C7
@LBA9C:  inc     $1d
@LBA9E:  ldy     next_color+1
         lda     $62
         cmp     $002f,y
         bcc     @LBADC
         bne     @LBAB0
         lda     $0022,y
         cmp     $61
         bcs     @LBADC
@LBAB0:  lda     $61
         sta     $0022,y
         lda     $62
         sta     $002f,y
         jsr     LBB41
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
         bcc     @LBA68
         bne     @LBADC
         lda     $0021,y
         cmp     $61
         bcs     @LBA68
@LBADC:  ldy     next_color+1
         lda     $8d
         clc
         adc     #$02
         sta     $133b,y
         sta     $8d
         jmp     LBA25

@LBAEB:  lda     next_color
         eor     #$80
         sta     next_color
         bmi     @LBAF5
         inc     move_number
@LBAF5:  ldy     next_color+1
         lda     $0021,y
         sta     scoreL_stack,y
         lda     $002e,y
         sta     scoreH_stack,y
         inc     next_color+1
         rts

@LBB06:  lda     next_color
         eor     #$80
         sta     next_color
         bpl     @LBB10
         dec     move_number
@LBB10:  dec     next_color+1
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
         jsr     LB8C7
         ldy     next_color+1
         cpy     #$01
         bne     @LBB40
         lda     $1fe2
         eor     #$0a
         ora     #$40
         sta     $1fe2
@LBB40:  rts

LBB41:   lda     $1327,y
         bne     @LBB50
         lda     $0b
         sta     $1445,y
         lda     $0c
         sta     $144f,y
@LBB50:  cpy     #$01
         bne     @LBB79
         ldx     $8d
         beq     @LBB6B
@LBB58:  lda     $1000,x
         sta     $1002,x
         dex
         bne     @LBB58
         lda     $0b
         sta     $1001
         lda     $0c
         sta     $1002
@LBB6B:  jsr     LACFA
         ldy     next_color+1
         lda     $b5
         sta     $9f
         lda     $b6
         sta     $b4
         rts

@LBB79:  cpy     #$02
         bne     @LBB85
         lda     $0b
         sta     $b5
         lda     $0c
         sta     $b6
@LBB85:  rts

LBB86:   lda     level+1
         cmp     level
         bcs     @LBBC1
         lda     $6a
         asl     A
         sta     $62
         lda     #$00
         sta     $61
         lda     next_color
         bpl     @LBBAA
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
         adc     #$81
         sta     $62
         ldy     next_color+1
         cmp     $002f,y
         bcc     @LBBC4
         bne     @LBBC1
         lda     $0022,y
         cmp     $61
         bcs     @LBBC4
@LBBC1:  jmp     LB3AF

@LBBC4:  lda     next_color
         eor     #$80
         jsr     LBBD3
         lda     #$00
         rol     A
         sta     $69
         rts

LBBD1:   lda     next_color
LBBD3:   bmi     @LBBD8
         ldx     $6c
         .byte   $2c
@LBBD8:  ldx     $6d
         lda     $146e,x
         sta     $13
         jmp     LAF7A

calc_move:
         jsr     LBCE4
         lda     #$00
         sta     $1e
         sta     $70
         sta     $71
         ldx     #$0a
@LBBEF:  sta     $1445,x
         sta     $144f,x
         sta     $20,x
         sta     $2d,x
         dex
         bne     @LBBEF
         lda     #$01
         sta     $8e
         lda     #$10
         sta     $8f
         lda     #$01
         sta     level+1
         jsr     LAEC0
         lda     $8e
         sta     $145b
         lda     $8f
         sta     $1465
         lda     $1c
         bne     @LBC1C
         jsr     LBF60
@LBC1C:  lda     level+1
         ora     #$70
         sta     $1fe3
         jsr     LBA25
         lda     scoreH_stack
         beq     @LBC2E
         cmp     #$ff
         bne     @LBC2F
@LBC2E:  rts

@LBC2F:  inc     level+1
         lda     level+1
         cmp     #$03
         bcc     @LBC83
         cmp     level
         bcs     @LBC3E
         jmp     @LBCC0

@LBC3E:  lda     scoreH_stack
         cmp     $2e
         bcc     @LBC98
         bne     @LBC4C
         lda     $21
         cmp     scoreL_stack
         bcs     @LBC98
@LBC4C:  lda     scoreL_stack
         eor     #$ff
         clc
         adc     #$01
         sta     $61
         lda     scoreH_stack
         eor     #$ff
         adc     #$00
         sta     $62
         cmp     $2f
         bcc     @LBCAC
         bne     @LBC69
         lda     $22
         cmp     $61
         bcs     @LBCAC
@LBC69:  lda     #$e0
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
@LBC83:  lda     level+1
         cmp     #$0a
         beq     @LBC2E
         cmp     level
         beq     @LBCC0
         ldx     level
         lda     $71
         cmp     la634+266,x
         bcs     @LBC2E
         bcc     @LBCC0

@LBC98:  lda     $21
         eor     #$ff
         sta     $22
         lda     $2e
         eor     #$ff
         sta     $2f
         lda     #$00
         sta     $21
         sta     $2e
         beq     @LBCBE

@LBCAC:  lda     $22
         eor     #$ff
         sta     $21
         lda     $2f
         eor     #$ff
         sta     $2e
         lda     #$00
         sta     $22
         sta     $2f
@LBCBE:  dec     level+1
@LBCC0:  lda     #$00
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
         jmp     @LBC1C

LBCE4:   lda     #$00
         sta     level+2
         sta     $6a
         sta     $07
         ldx     #$15
@LBCEE:  lda     $146e,x
         beq     @LBD27
         cmp     #$ff
         beq     @LBD27
         sta     $13
         and     #$07
         tay
         cmp     #$06
         bne     @LBD0A
         lda     $13
         bmi     @LBD08
         stx     $6c
         bne     @LBD0A
@LBD08:  stx     $6d
@LBD0A:  lda     $13
         bmi     @LBD17
         lda     $6a
         clc
         adc     la634+223,y
         jmp     @LBD1D

@LBD17:  lda     $6a
         sec
         sbc     la634+223,y
@LBD1D:  sta     $6a
         lda     $07
         clc
         adc     la634+223,y
         sta     $07
@LBD27:  inx
         cpx     #$63
         bcc     @LBCEE
         lda     $07
         cmp     #$2e
         bcs     @LBD41
         lda     $6a
         bpl     @LBD3B
         eor     #$ff
         clc
         adc     #$01
@LBD3B:  cmp     #$05
         bcc     @LBD41
         sta     level+2
@LBD41:  rts

lopenings:
         .byte   $0f
         .byte   $0d
         .byte   <@TBD52
         .byte   >@TBD52
         .byte   $0b
         .byte   <@TBE2B
         .byte   >@TBE2B
         .byte   $09
         .byte   <@TBEA6
         .byte   >@TBEA6
         .byte   $02
         .byte   <@TBF12
         .byte   >@TBF12
         .byte   $0f
         .byte   <@TBF45
         .byte   >@TBF45
@TBD52:  .byte   $3f
         .byte   $09
         .byte   <@TBD68
         .byte   >@TBD68
         .byte   $05
         .byte   <@TBDAB
         .byte   >@TBDAB
         .byte   $08
         .byte   <@TBDDE
         .byte   >@TBDDE
         .byte   $04
         .byte   <@TBDF7
         .byte   >@TBDF7
         .byte   $06
         .byte   <@TBE1C
         .byte   >@TBE1C
         .byte   $12
         .byte   <@TBE25
         .byte   >@TBE25
         .byte   $07
         .byte   <@TBE28
         .byte   >@TBE28
@TBD68:  .byte   $08
         .byte   $0d
         .byte   <@TBD6F
         .byte   >@TBD6F
         .byte   $18
         .byte   <@TBDA4
         .byte   >@TBDA4
@TBD6F:  .byte   $78
         .byte   $0f
         .byte   <@TBD7C
         .byte   >@TBD7C
         .byte   $1a
         .byte   <@TBD97
         .byte   >@TBD97
         .byte   $06
         .byte   $ff
         .byte   $09
         .byte   $ff
         .byte   $07
         .byte   $ff
@TBD7C:  .byte   $18
         .byte   $07
         .byte   <@TBD86
         .byte   >@TBD86
         .byte   $06
         .byte   <@TBD8F
         .byte   >@TBD8F
         .byte   $01
         .byte   <@TBD94
         .byte   >@TBD94
@TBD86:  .byte   $38
         .byte   $05
         .byte   $ff
         .byte   $0b
         .byte   $ff
         .byte   $18
         .byte   $ff
         .byte   $1b
         .byte   $ff
@TBD8F:  .byte   $02
         .byte   $19
         .byte   $ff
         .byte   $1c
         .byte   $ff
@TBD94:  .byte   $00
         .byte   $1c
         .byte   $ff
@TBD97:  .byte   $06
         .byte   $11
         .byte   <@TBD9F
         .byte   >@TBD9F
         .byte   $01
         .byte   $ff
         .byte   $17
         .byte   $ff
@TBD9F:  .byte   $01
         .byte   $01
         .byte   $ff
         .byte   $00
         .byte   $ff
@TBDA4:  .byte   $00
         .byte   $00
         .byte   <@TBDA8
         .byte   >@TBDA8
@TBDA8:  .byte   $00
         .byte   $0e
         .byte   $ff
@TBDAB:  .byte   $08
         .byte   $0d
         .byte   <@TBDB2
         .byte   >@TBDB2
         .byte   $01
         .byte   <@TBDDB
         .byte   >@TBDDB
@TBDB2:  .byte   $19
         .byte   $05
         .byte   <@TBDBF
         .byte   >@TBDBF
         .byte   $10
         .byte   <@TBDC6
         .byte   >@TBDC6
         .byte   $07
         .byte   <@TBDCD
         .byte   >@TBDCD
         .byte   $14
         .byte   <@TBDD4
         .byte   >@TBDD4
@TBDBF:  .byte   $00
         .byte   $11
         .byte   <@TBDC3
         .byte   >@TBDC3
@TBDC3:  .byte   $00
         .byte   $00
         .byte   $ff
@TBDC6:  .byte   $00
         .byte   $11
         .byte   <@TBDCA
         .byte   >@TBDCA
@TBDCA:  .byte   $00
         .byte   $00
         .byte   $ff
@TBDCD:  .byte   $00
         .byte   $11
         .byte   <@TBDD1
         .byte   >@TBDD1
@TBDD1:  .byte   $00
         .byte   $00
         .byte   $ff
@TBDD4:  .byte   $00
         .byte   $1b
         .byte   <@TBDD8
         .byte   >@TBDD8
@TBDD8:  .byte   $00
         .byte   $02
         .byte   $ff
@TBDDB:  .byte   $00
         .byte   $10
         .byte   $ff
@TBDDE:  .byte   $00
         .byte   $16
         .byte   <@TBDE2
         .byte   >@TBDE2
@TBDE2:  .byte   $00
         .byte   $08
         .byte   <@TBDE6
         .byte   >@TBDE6
@TBDE6:  .byte   $02
         .byte   $01
         .byte   <@TBDED
         .byte   >@TBDED
         .byte   $02
         .byte   <@TBDF2
         .byte   >@TBDF2
@TBDED:  .byte   $02
         .byte   $1d
         .byte   $ff
         .byte   $1f
         .byte   $ff
@TBDF2:  .byte   $02
         .byte   $1f
         .byte   $ff
         .byte   $07
         .byte   $ff
@TBDF7:  .byte   $08
         .byte   $16
         .byte   <@TBDFE
         .byte   >@TBDFE
         .byte   $0d
         .byte   <@TBE15
         .byte   >@TBE15
@TBDFE:  .byte   $00
         .byte   $06
         .byte   <@TBE02
         .byte   >@TBE02
@TBE02:  .byte   $0a
         .byte   $01
         .byte   <@TBE0C
         .byte   >@TBE0C
         .byte   $24
         .byte   <@TBE0F
         .byte   >@TBE0F
         .byte   $25
         .byte   <@TBE12
         .byte   >@TBE12
@TBE0C:  .byte   $00
         .byte   $00
         .byte   $ff
@TBE0F:  .byte   $00
         .byte   $00
         .byte   $ff
@TBE12:  .byte   $00
         .byte   $10
         .byte   $ff
@TBE15:  .byte   $00
         .byte   $06
         .byte   <@TBE19
         .byte   >@TBE19
@TBE19:  .byte   $00
         .byte   $01
         .byte   $ff
@TBE1C:  .byte   $00
         .byte   $16
         .byte   <@TBE20
         .byte   >@TBE20
@TBE20:  .byte   $02
         .byte   $19
         .byte   $ff
         .byte   $0b
         .byte   $ff
@TBE25:  .byte   $00
         .byte   $1d
         .byte   $ff
@TBE28:  .byte   $00
         .byte   $1d
         .byte   $ff
@TBE2B:  .byte   $09
         .byte   $12
         .byte   <@TBE35
         .byte   >@TBE35
         .byte   $07
         .byte   <@TBE64
         .byte   >@TBE64
         .byte   $0b
         .byte   <@TBE95
         .byte   >@TBE95
@TBE35:  .byte   $00
         .byte   $12
         .byte   <@TBE39
         .byte   >@TBE39
@TBE39:  .byte   $01
         .byte   $0d
         .byte   <@TBE40
         .byte   >@TBE40
         .byte   $0f
         .byte   <@TBE4F
         .byte   >@TBE4F
@TBE40:  .byte   $02
         .byte   $01
         .byte   <@TBE47
         .byte   >@TBE47
         .byte   $0e
         .byte   <@TBE4A
         .byte   >@TBE4A
@TBE47:  .byte   $00
         .byte   $19
         .byte   $ff
@TBE4A:  .byte   $08
         .byte   $08
         .byte   $ff
         .byte   $19
         .byte   $ff
@TBE4F:  .byte   $18
         .byte   $01
         .byte   <@TBE59
         .byte   >@TBE59
         .byte   $18
         .byte   <@TBE5E
         .byte   >@TBE5E
         .byte   $0e
         .byte   <@TBE61
         .byte   >@TBE61
@TBE59:  .byte   $02
         .byte   $14
         .byte   $ff
         .byte   $0d
         .byte   $ff
@TBE5E:  .byte   $00
         .byte   $0d
         .byte   $ff
@TBE61:  .byte   $00
         .byte   $14
         .byte   $ff
@TBE64:  .byte   $00
         .byte   $12
         .byte   <@TBE68
         .byte   >@TBE68
@TBE68:  .byte   $0a
         .byte   $07
         .byte   <@TBE72
         .byte   >@TBE72
         .byte   $05
         .byte   <@TBE81
         .byte   >@TBE81
         .byte   $00
         .byte   <@TBE8E
         .byte   >@TBE8E
@TBE72:  .byte   $08
         .byte   $01
         .byte   <@TBE79
         .byte   >@TBE79
         .byte   $18
         .byte   <@TBE7E
         .byte   >@TBE7E
@TBE79:  .byte   $02
         .byte   $1f
         .byte   $ff
         .byte   $07
         .byte   $ff
@TBE7E:  .byte   $00
         .byte   $1f
         .byte   $ff
@TBE81:  .byte   $08
         .byte   $0e
         .byte   <@TBE88
         .byte   >@TBE88
         .byte   $1c
         .byte   <@TBE8B
         .byte   >@TBE8B
@TBE88:  .byte   $00
         .byte   $1b
         .byte   $ff
@TBE8B:  .byte   $00
         .byte   $00
         .byte   $ff
@TBE8E:  .byte   $00
         .byte   $0e
         .byte   <@TBE92
         .byte   >@TBE92
@TBE92:  .byte   $00
         .byte   $1c
         .byte   $ff
@TBE95:  .byte   $02
         .byte   $12
         .byte   <@TBE9C
         .byte   >@TBE9C
         .byte   $14
         .byte   <@TBE9F
         .byte   >@TBE9F
@TBE9C:  .byte   $00
         .byte   $12
         .byte   $ff
@TBE9F:  .byte   $00
         .byte   $00
         .byte   <@TBEA3
         .byte   >@TBEA3
@TBEA3:  .byte   $00
         .byte   $01
         .byte   $ff
@TBEA6:  .byte   $1b
         .byte   $05
         .byte   <@TBEB5
         .byte   >@TBEB5
         .byte   $09
         .byte   <@TBECC
         .byte   >@TBECC
         .byte   $08
         .byte   <@TBEF5
         .byte   >@TBEF5
         .byte   $04
         .byte   <@TBF06
         .byte   >@TBF06
         .byte   <@TBF0D
         .byte   >@TBF0D
@TBEB5:  .byte   $01
         .byte   $01
         .byte   <@TBEBC
         .byte   >@TBEBC
         .byte   $05
         .byte   <@TBF53
         .byte   >@TBF53
@TBEBC:  .byte   $02
         .byte   $0f
         .byte   <@TBEC3
         .byte   >@TBEC3
         .byte   $13
         .byte   <@TBF50
         .byte   >@TBF50
@TBEC3:  .byte   $08
         .byte   $10
         .byte   <@TBEC9
         .byte   >@TBEC9
         .byte   $04
         .byte   $ff
@TBEC9:  .byte   $00
         .byte   $0f
         .byte   $ff
@TBECC:  .byte   $00
         .byte   $01
         .byte   <@TBED0
         .byte   >@TBED0
@TBED0:  .byte   $03
         .byte   $10
         .byte   <@TBEDA
         .byte   >@TBEDA
         .byte   $1b
         .byte   <@TBEE3
         .byte   >@TBEE3
         .byte   $07
         .byte   <@TBEF2
         .byte   >@TBEF2
@TBEDA:  .byte   $01
         .byte   $10
         .byte   <@TBEE0
         .byte   >@TBEE0
         .byte   $04
         .byte   $ff
@TBEE0:  .byte   $00
         .byte   $0e
         .byte   $ff
@TBEE3:  .byte   $01
         .byte   $10
         .byte   <@TBEEA
         .byte   >@TBEEA
         .byte   $04
         .byte   <@TBEEF
         .byte   >@TBEEF
@TBEEA:  .byte   $01
         .byte   $0e
         .byte   $ff
         .byte   $0a
         .byte   $ff
@TBEEF:  .byte   $00
         .byte   $13
         .byte   $ff
@TBEF2:  .byte   $00
         .byte   $10
         .byte   $ff
@TBEF5:  .byte   $00
         .byte   $05
         .byte   <@TBEF9
         .byte   >@TBEF9
@TBEF9:  .byte   $00
         .byte   $1b
         .byte   <@TBEFD
         .byte   >@TBEFD
@TBEFD:  .byte   $02
         .byte   $0e
         .byte   <@TBF03
         .byte   >@TBF03
         .byte   $0d
         .byte   $ff
@TBF03:  .byte   $00
         .byte   $0d
         .byte   $ff
@TBF06:  .byte   $00
         .byte   $05
         .byte   <@TBF0A
         .byte   >@TBF0A
@TBF0A:  .byte   $00
         .byte   $13
         .byte   $ff
@TBF0D:  .byte   $01
         .byte   $05
         .byte   $ff
         .byte   $01
         .byte   $ff
@TBF12:  .byte   $0a
         .byte   $07
         .byte   <@TBF1C
         .byte   >@TBF1C
         .byte   $05
         .byte   <@TBF37
         .byte   >@TBF37
         .byte   $12
         .byte   <@TBF42
         .byte   >@TBF42
@TBF1C:  .byte   $02
         .byte   $0d
         .byte   <@TBF23
         .byte   >@TBF23
         .byte   $08
         .byte   <@TBF34
         .byte   >@TBF34
@TBF23:  .byte   $02
         .byte   $06
         .byte   <@TBF2A
         .byte   >@TBF2A
         .byte   $1a
         .byte   <@TBF31
         .byte   >@TBF31
@TBF2A:  .byte   $00
         .byte   $02
         .byte   <@TBF2E
         .byte   >@TBF2E
@TBF2E:  .byte   $00
         .byte   $10
         .byte   $ff
@TBF31:  .byte   $00
         .byte   $02
         .byte   $ff
@TBF34:  .byte   $00
         .byte   $00
         .byte   $ff
@TBF37:  .byte   $00
         .byte   $0d
         .byte   <@TBF3B
         .byte   >@TBF3B
@TBF3B:  .byte   $00
         .byte   $10
         .byte   <@TBF3F
         .byte   >@TBF3F
@TBF3F:  .byte   $00
         .byte   $02
         .byte   $ff
@TBF42:  .byte   $00
         .byte   $0d
         .byte   $ff
@TBF45:  .byte   $00
         .byte   $07
         .byte   <@TBF49
         .byte   >@TBF49
@TBF49:  .byte   $00
         .byte   $03
         .byte   <@TBF4D
         .byte   >@TBF4D
@TBF4D:  .byte   $00
         .byte   $1a
         .byte   $ff
@TBF50:  .byte   $00
         .byte   $10
         .byte   $ff
@TBF53:  .byte   $00
         .byte   $13
         .byte   <@TBF57
         .byte   >@TBF57
@TBF57:  .byte   $02
         .byte   $0b
         .byte   <@TBF5D
         .byte   >@TBF5D
         .byte   $0e
         .byte   $ff
@TBF5D:  .byte   $00
         .byte   $00
         .byte   $ff

LBF60:   lsr     $9c
         ldy     #$00
         lda     move_number
         cmp     #$01
         bne     @LBF76
         lda     #<lopenings
         sta     opening_ptr
         lda     #>lopenings
         sta     opening_ptr+1
         lda     human_color
         beq     @LBF9C
@LBF76:  lda     (opening_ptr),y
         ldx     #$01
@LBF7A:  lsr     A
         bcc     @LBF7E
         inx
@LBF7E:  cmp     #$00
         bne     @LBF7A
         lda     $9c
         iny
@LBF85:  cmp     (opening_ptr),y
         beq     @LBF96
         dex
         beq     @LBF91
         jsr     @LBFF1
         bcc     @LBF85
@LBF91:  lda     #$50
         sta     $1c
         rts

@LBF96:  jsr     @LBFD9
         bcc     @LBF9C
         rts

@LBF9C:  ldy     #$00
         lda     (opening_ptr),y
         ora     #$80
         sta     $0d
         iny
         lda     vic_raster
         sta     $0e
@LBFAA:  lsr     $0e
         bcs     @LBFBD
         lda     $0d
         beq     @LBFBB
         lsr     $0d
         bcc     @LBFAA
         jsr     @LBFF1
         bne     @LBFAA
@LBFBB:  ldy     #$01
@LBFBD:  lda     (opening_ptr),y
         asl     A
         sta     $8d
         jsr     @LBFD9
         jsr     LB7C4
         jsr     LB8C7
         jsr     LBB41
         lda     #$50
         sta     scoreH_stack
         lda     #$00
         sta     scoreL_stack
         pla
         pla
         rts

@LBFD9:  iny
         lda     (opening_ptr),y
         cmp     #$ff
         beq     @LBFED
         sta     $0d
         iny
         lda     (opening_ptr),y
         sta     opening_ptr+1
         lda     $0d
         sta     opening_ptr
         clc
         rts

@LBFED:  sta     $1c
         sec
         rts

@LBFF1:  sta     $0f
         iny
         lda     (opening_ptr),y
         cmp     #$ff
         beq     @LBFFB
         iny
@LBFFB:  iny
         lda     $0f
         clc
         rts

