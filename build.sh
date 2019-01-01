f=SargonII.S
a=2000

# -t none need so that upper case chars are not auto translated to hi ascii
cl65 -d -t none -o SargonII-raw-$a.prg -C vic20-asm.cfg "$f" -t vic20 --start-addr 0x$a

exomizer sfx 8192 -t 52 -x1 SargonII-raw-$a.prg -o SargonII-$a.prg
