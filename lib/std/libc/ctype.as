use types.int;


# Character classification functions
# -----------------------------------------------------------------------------

# Check if character is alphanumeric.
extern let isalnum(c: int) -> int;

# Check if character is alphabetic.
extern let isalpha(c: int) -> int;

# Check if character is blank.
extern let isblank(c: int) -> int;

# Check if character is a control character.
extern let iscntrl(c: int) -> int;

# Check if character is decimal digit.
extern let isdigit(c: int) -> int;

# Check if character has graphical representation.
extern let isgraph(c: int) -> int;

# Check if character is lowercase letter.
extern let islower(c: int) -> int;

# Check if character is printable.
extern let isprint(c: int) -> int;

# Check if character is a punctuation character.
extern let ispunct(c: int) -> int;

# Check if character is a white-space.
extern let isspace(c: int) -> int;

# Check if character is uppercase letter.
extern let isupper(c: int) -> int;

# Check if character is hexadecimal digit.
extern let isxdigit(c: int) -> int;


# Character conversion functions
# -----------------------------------------------------------------------------

# Convert uppercase letter to lowercase
extern let tolower(c: int) -> int;

# Convert lowercase letter to uppercase
extern let toupper(c: int) -> int;
