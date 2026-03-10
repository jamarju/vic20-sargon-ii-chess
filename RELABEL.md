This is Sargon II chess for VIC-20 disassembly:

Main source code is sargonII.S.

There are several versions of the opening book, included conditionally:

```
.if      .defined(USE_VIC_BOOK_FIX)
    .include "sargon_2_vic20_book_fix.S"
.elseif  .defined(USE_VIC_BOOK)
    .include "sargon_2_vic20_book.S"
.elseif  .defined(USE_CPM_BOOK)
    .include "sargon_21_cpm_book.S"
.else
    .error "No openings book defined. Please define one of the USE_* flags."
.endif
```

- sargon_2_vic20_book.S: original VIC-20 openings book
- sargon_21_cpm_book.S: CPM version openings book, can be actually used in VIC-20 with a bigger expansion
- sargon_2_vic20_book_fix.S: original VIC-20 book + fix for a bug surfaced during the study of the CPM book

Additionally:

- build.sh: builds the .prg binaries from the sources.

I've already labelled some of the variables and routines in the source code. Your task is to doublecheck and finish my work. In other words: label the WHOLE sargonII.S and add comments to it, so that it can be easily studied and understood.

Work autonomously until ALL labels have been understood and have proper, understandable names, and the comments are sufficient for any chess + 6502 enthusiasts to understand this piece of historic software.

As a suggestion, the .S has lots of whitespaces that are helpful for humans but probably a waste of your tokens. Perhaps you may start coalescing multiple whitespaces into just one. Won't break the syntax and may go easier on your context.

You may also modularize the code into several .S files if this helps you to digest the code better.

cl65 is already installed.

As a validation check, your relabelled + commented source code must compile into the same exact binary, so use `cmp`, you may use `cmp` to test this.

Prefer proactivity over asking me questions.

Godspeed!
