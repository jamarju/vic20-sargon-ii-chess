# Sargon II VIC-20 Disassembly - Annotation Status

## What was done

Two prior annotation passes (worktrees `relabel` and `relabel2`) were merged into a single definitive version, taking the best of both:

- **From relabel**: rich, detailed comments and well-chosen global label names, by Opus 4.6 high effort
- **From relabel2**: all 399 local labels renamed from hex (`@LA020`) to descriptive names (`@fill_loop`, `@check_key`, etc.), by Opus 4.6 high effort in plan mode.

After merging, the following additional work was done:

### Comment inconsistencies resolved
Eight contradictions between the two versions were identified and corrected:
- Castling labels (`@queenside` mislabeling kingside code)
- Attacker/defender swap (`@enemy` labeling friendly-piece code)
- Center square check mislabeled as 7th rank
- Piece values comment corrected to match actual bytes
- VIC-20 joystick VIA pin mapping corrected (PB7=joy-right, PA5=fire)
- `handle_cursor` direction comments fixed
- `draw_board_row` description corrected

### Magic memory addresses replaced with named variables
~90 equate definitions added, covering:
- Zero-page game variables ($00-$f9)
- Evaluation engine state ($61-$71)
- Search engine pointers ($8b-$9f)
- Graphics/display vars ($a3-$ae)
- All major RAM data structures: board array, move lists, exchange tables, killer moves, per-ply stacks, move history ($1000-$146e)

### String data cleaned up
Raw hex byte sequences for PETSCII strings converted to `HiAscii` macro calls for readability (welcome screen, menu prompts, credits).

### Formatting
Source formatted with `nice65 -c` (lowercase mnemonics, consistent indentation).

## Validation

All changes verified by binary comparison: the assembled .prg files are byte-identical to the originals.

## Files

- `SargonII.S` - main source (fully annotated)
- `build.sh` - builds .prg binaries
- `sargon_2_vic20_book.S` - original VIC-20 openings book
- `sargon_21_cpm_book.S` - CP/M version openings book
- `sargon_2_vic20_book_fix.S` - VIC-20 book with bug fix
