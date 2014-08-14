all: word_jumble

clean:
	@- rm -rf $(wildcard *.o)
	@- rm -rf $(wildcard word_jumble)

word_jumble.o: word_jumble.as
	@ ../build/arrow -L ../src $^ | opt -O3 -S | llc -filetype=obj > $@

word_jumble: word_jumble.o
	@ gcc -o $@ $^
