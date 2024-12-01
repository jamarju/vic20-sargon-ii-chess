#!/bin/bash -e

f=SargonII.S
a=2000

# -t none needed so that upper case chars are not auto translated to hi ascii
cl65 -l PRG/SargonII-raw-$a-vic-book.lst -d -t none -o PRG/SargonII-raw-$a-vic-book.prg -C vic20-asm.cfg --asm-args -DUSE_VIC_BOOK "$f" -t vic20 --start-addr 0x$a
cl65 -l PRG/SargonII-raw-$a-cpm-book.lst -d -t none -o PRG/SargonII-raw-$a-cpm-book.prg -C vic20-asm.cfg --asm-args -DUSE_CPM_BOOK "$f" -t vic20 --start-addr 0x$a

exomizer sfx 8192 -t 52 -x1 PRG/SargonII-raw-$a-vic-book.prg -o PRG/SargonII-$a-vic-book.prg
exomizer sfx 8192 -t 52 -x1 PRG/SargonII-raw-$a-cpm-book.prg -o PRG/SargonII-$a-cpm-book.prg
