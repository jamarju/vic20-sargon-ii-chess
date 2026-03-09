#!/bin/bash -e
# Build both variants and compare against reference binaries

f=SargonII.S
a=2000

echo "Building VIC book variant..."
cl65 -l PRG/SargonII-raw-$a-vic-book.lst -d -t none -o PRG/SargonII-raw-$a-vic-book.prg -C vic20-asm.cfg --asm-args -DUSE_VIC_BOOK "$f" -t vic20 --start-addr 0x$a

echo "Building CPM book variant..."
cl65 -l PRG/SargonII-raw-$a-cpm-book.lst -d -t none -o PRG/SargonII-raw-$a-cpm-book.prg -C vic20-asm.cfg --asm-args -DUSE_CPM_BOOK "$f" -t vic20 --start-addr 0x$a

echo "Comparing binaries..."
cmp PRG/SargonII-raw-$a-vic-book.prg PRG/SargonII-raw-$a-vic-book.prg.REF
cmp PRG/SargonII-raw-$a-cpm-book.prg PRG/SargonII-raw-$a-cpm-book.prg.REF

echo "PASS: Both binaries match reference."
