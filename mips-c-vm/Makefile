vm: mips_vm.c mips_vm.h
	gcc $$(pkg-config --cflags --libs sdl2) mips_vm.c -o mips-vm

# Mars dumps data after program execution iirc
# and I wanted to make an assembler for the .data,
# so I made this mess. Only works if the file starts
# with .data, lol
data:
	csi -s assembler.scm $(masm)

text:
	Mars a dump .text Binary mips-text $(masm)

run:
	./mips-vm mips-text --data mips-data


mergesort: masm:=../mips-programs/mergesort.asm
mergesort: data text vm run

proj1-5: masm:=../mips-programs/proj1-5.asm
proj1-5: data text vm run

example: mergesort
