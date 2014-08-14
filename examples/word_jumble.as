# Word Jumble
# The classic word jumble game where the player can ask for a hint.
import string;
import libc;

let input(): string.String -> {
    let mut buffer = string.String.new();
    let mut c = -1;
    loop {
        c = libc.getchar();
        if c == -1 or c == 0x0a { break; };
        buffer.append(c as char);
    }
    return buffer;
}

let main() -> {
    let NUM_WORDS = 5;
    let WORDS = [
        ("wall", "Do you feel you're banging your head against something?"),
        ("glasses", "These might help you see the answer."),
        ("labored", "Going slowly, isn't it?",),
        ("persistent", "Keep at it."),
        ("jumble", "It's what the game is all about."),
    ];

    # Seed the pseudo-random sequence generator.
    libc.srand(libc.time(0 as *int32));

    # Pick a "random" word to be jumbled.
    let choice = (libc.rand() % NUM_WORDS);
    #let (word, hint) = WORDS[choice];
    let mut word: str;
    let mut hint: str;
    (word, hint) = WORDS[choice];

    # Create a jumbled version of the chosen word.
    let mut jumble = string.String.from_str(word);
    let len = jumble.size() as int32;
    let mut idx: uint = 0;
    while idx < len as uint {
        let i1 = (libc.rand() % len);
        let i2 = (libc.rand() % len);
        let temp = jumble._data.get_i8(i1);
        *(jumble._data.elements + i1) = jumble._data.get_i8(i2);
        *(jumble._data.elements + i2) = temp;
        idx = idx + 1;
    }

    # Welcome the player.
    libc.printf("Welcome to Word Jumble!\n\n");
    libc.printf("Unscramble the letters to make a word.\n");
    libc.printf("Enter ’hint’ for a hint.\n");
    libc.printf("Enter ’quit’ to quit the game.\n\n");
    libc.printf("The jumble is: %s", jumble.data());

    # Enter the "guess" loop
    let mut guess = string.String.new();
    loop {
        # Ask for the "player's" guess
        libc.printf("\n\nYour guess: ");
        guess.dispose();
        guess = input();

        if guess.eq_str("quit") or guess.eq_str(word) {
            # Stop if 'quit' or the word is guessed
            break;
        }
        else if guess.eq_str("hint") {
            # Show the hint if asked
            libc.printf("%s", hint);
        }
        else {
            # Otherwise tell them sorry
            libc.printf("Sorry, that's not it.", hint);
        };
    }

    if guess.eq_str(word) {
        # Show them the victory message
        libc.printf("\nThat’s it! You guessed it!\n");
    };

    # Thank them for their time
    libc.printf("\nThanks for playing.\n");

    # Dispose.
    guess.dispose();
}
