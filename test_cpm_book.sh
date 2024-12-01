#!/bin/bash -e
cl65 -t none -o sargon21_cpm_book_original_location.bin sargon21_cpm_book_original_location.S
dd if=CPM/sargon2.com of=sargon21_book.bin bs=1 skip=12803 count=1754 status=none
if cmp sargon21_book.bin sargon21_cpm_book_original_location.bin; then
    echo -e "\x1b[32mAssembled and original books match!\x1b[0m"
else
    echo -e "\x1b[31mAssembled and original books do not match!\x1b[0m"
fi
rm sargon21_book.bin sargon21_cpm_book_original_location.bin
