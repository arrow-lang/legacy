all: word_jumble

clean:
	@- rm -rf $(wildcard *.o)
	@- rm -rf $(wildcard word_jumble)

word_jumble.o: word_jumble.as
	@ (cd ../src; ../build/arrow ../examples/word_jumble.as | opt -O3 -S | llc -filetype=obj > ../examples/word_jumble.o)

word_jumble: word_jumble.o
	@ gcc -o $@ $^
