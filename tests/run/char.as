extern def printf(str, char);
let main() -> {
    # Declare a character.
    let mut endl: char;

    # Assign it to 0x0A (newline).
    endl = 0x0A;

    # # Print some stuff followed by the character (which is now newline).
    # printf("Hello World%c", endl);

    # # Declare some characters.
    # let a: char = 'A';
    # let b: char = '\xc2\xa7';
    # let single_quote: char = "'";
    # let double_quote: char = '"';

    # # # Print the characters.
    # printf("%c", a);
    # printf("%c", b);
    # printf("%c", single_quote);
    # printf("%c", double_quote);
    # printf("%c", endl);
}
