This is Sargon II Chess for the Commodore VIC-20 relocated to RAM ($2000) so that it can be played from a RAM expansion cartridge (minimum 8 KB).

Game functionality, openings table, bugs (shifted intro screen?), etc. are preserved as in the original.

**NEW 2024-12-01**: An enhanced version including Sargon 2.1 CP/M version of the openings book is now also available!

The only change is that `RESTORE` will bring you to the intro screen in addition to the original combination (`RUN/STOP` + `RESTORE`).

## Requirements (MacOs)

Install cc65 toolchain:

```
brew install cc65
```

Get exomizer binary from: http://www.popelganda.de/relaunch64.html (tested version 2.0.9).

## Build

```
./build.sh
```

## Pre-compiled versions

- `PRG/SargonII-2000-vic-book.prg` is the original version with buggy openings table (see discussion below). Needs 8KB expansion (block 1 from $2000-$3fff).
- `PRG/SargonII-2000-cpm-book.prg` is the fixed version with CP/M openings table. Because of the extended openings book size, this version needs 16KB expansion (blocks 1 and 2 from $2000-$5fff).

## Openings bug

The openings book entry for blacks after whites play first move C2-C4 is corrupted. This is how that entry looks like in the VIC-20 version:

```
@TBEA6: .byte   $1b
        .byte   $05
        .word   @TBEB5
        .byte   $09
        .word   @TBECC
        .byte   $08
        .word   @TBEF5
        .byte   $04
        .word   @TBF06
        .word   @TBF0D
```

By contrast, this is the same entry in the CP/M version:

```
@L347A: .byte   $1B
        .byte   $05
        .word   @L348A
        .byte   $09
        .word   @L34A1
        .byte   $08
        .word   @L34CA
        .byte   $04
        .word   @L34DE
        .byte   $12    ; !!!
        .word   @L34E5
```

To force the bug: 

- Get [IceBroLite](https://github.com/Sakrac/IceBroLite)
- Load Vice (xvic) from it
- "Connect" if not done already
- On the breakpoints tab, enter a breakpoint (type: "Break") just before the VIC raster line is read:
    - $3fa5 (VIC-20 openings version)
    - $4461 (CP/M openings version)
- Run the program, choose whites, play your first move: C2-C4.
- The program will break just before the VIC raster line is read.
- F10 to step through reading the scanline.
- Now the computer chooses its next moving using the scanline as a pseudo-RNG by selecting Nth move where N is the first non-zero bit starting from the LSb. Let's force it to choose the buggy move by forcing the scanline value to $20: go to the registers tab, click on A's value and set it to 20, then ESC.

Now, instead of chossing sensible move index $12 (18 decimal), it chooses move index $0d (low byte of address $BF0D) which translates to the weird move G7-G5 and the link to the next entry is unpredictable as it now points outside of the book table! In fact, while the computer thinks he's playing by the book, you can do stuff like H2-H4, to which the computer responds with an E7-E5 and allows you to capture the pawn H4xG5:

![Bug in VIC-20 openings table](img/openings_sargon2_vic20_bug_mini.png)

When you do the same in the CP/M openings book, the computer actually plays move $12 (G8-F6):

![Bug in CP/M openings table](img/openings_sargon2_vic20_fix_mini.png)

The openings table is extracted from the [CP/M version of Sargon 2.1](https://www.icl1900.co.uk/unix4fun/z80pack/ftp/chess.tgz):

For preservation purposes I included the DSK file. You can extract the `sargon2.com` binary from it, then extract the openings book:

```
brew install cpmtools
cpmcp chess.dsk 0:sargon2.com sargon2.com
dd if=sargon2.com of=sargon21_book.bin bs=1 skip=12803 count=1756
```

### Additional details on the openings book issue

I debugged the openings book issue further and the following info may be useful to whoever wants to understand the internals further. The value in  `$9c` (after the LSR in $3f60, originally $bf60) contains the index to a list of all possibly legal moves for the current board position. Eg.

- B1-A3: $00  ; Knight from B1 to A3
- B1-C3: $01  ; Knight from B1 to C3
- G1-F3: $02  ; Knight from G1 to F3
- G1-H3: $03  ; Knight from G1 to H3
- A2-A3: $04  ; Pawn from A2 to A3
- A2-A4: $05  ; Pawn from A2 to A4
- B2-B3: $06  ; Pawn from B2 to B3
- B2-B4: $07  ; Pawn from B2 to B4
- C2-C3: $08  ; Pawn from C2 to C3
- C2-C4: $09  ; Pawn from C2 to C4
- E2-E4: $0d  ; Pawn from E2 to E4

The ordering of indexes (wild guess) is:

- Sort first by moving piece (col A-H, then row 1-8)
- Then each piece appears to have its own sub-ordering, eg: starting pawns: first 1 step, then 2 steps. 

Blacks use the same ordering (from the white's perspective). Example for blacks:

- C7-C6: $04
- C7-C5: $05
- G8-F6: $12

## Credits:

- [6502bench SourceGen](https://6502bench.com) made disassembling and relocating this super easy. THANKS!
- Thanks [Stefano](https://github.com/jamarju/vic20-sargon-ii-chess/issues/1) for the Sargon 2.1 CP/M pointer and manually diffing the VIC-20 and CP/M versions!

Original Sargon II Chess code by: Dan and Kathleen 'Kathe' Spracklen.

## Links:

 * ["Sargon, a Computer Chess Program", Dan and Kathe Spracklen](http://web.archive.org/web/20070614114334/http://madscientistroom.org/chm/Sargon.html)
 