foreign "C" import "string.h";
import asciz;

# Blocking
# -----------------------------------------------------------------------------
# [ ] Proper static data
# [ ] Dynamic-length strings
# [ ] Fully test imports (in combination with successive foreign imports)

# Wishlist
# -----------------------------------------------------------------------------
# [ ] Simple enumerations

# The lexer returns tokens [0-255] to if its an unknown symbol, otherwise
# one of the known symbols.
# -----------------------------------------------------------------------------

# "end" -- End-of-stream
let TOK_END: int = -1001;

# "def" -- Function declaration
let TOK_DEF: int = -1002;

# "let" -- Local slot declaration
let TOK_LET: int = -1003;

# "static" -- Static slot declaration
let TOK_STATIC: int = -1004;

# "mut" -- Mutable slot or type modifier
let TOK_MUT: int = -1005;

# "true" -- Boolean true
let TOK_TRUE: int = -1006;

# "false" -- Boolean false
let TOK_FALSE: int = -1007;

# "self" -- The contextual instance bound to the method
let TOK_SELF: int = -1008;

# "as" -- Safe type cast operator
let TOK_AS: int = -1009;

# "and" -- Logical AND for boolean expressions
let TOK_AND: int = -1010;

# "or" -- Logical OR for boolean expressions
let TOK_OR: int = -1011;

# "not" -- Logical NOT for boolean expressions
let TOK_NOT: int = -1012;

# "if" -- Conditional statement
let TOK_IF: int = -1013;

# "else" -- Initiates the else clause of a conditional statement
let TOK_ELSE: int = -1013;

# "while" -- Condition-controlled loop
let TOK_WHILE: int = -1014;

# "loop" -- Infinite loop
let TOK_LOOP: int = -1015;

# "match" -- Pattern match expression
let TOK_MATCH: int = -1016;

# "break" -- Loop termination
let TOK_BREAK: int = -1017;

# "continue" -- Loop restart
let TOK_CONTINUE: int = -1018;

# "return" -- Immediate return from function
let TOK_RETURN: int = -1019;

# "type" -- Product type declaration
let TOK_TYPE: int = -1020;

# "enum" -- Sum type declaration
let TOK_ENUM: int = -1021;

# "module" -- Module declaration
let TOK_MODULE: int = -1022;

# "import" -- Import statement
let TOK_IMPORT: int = -1023;

# "use" -- Alias declaration
let TOK_USE: int = -1024;

# "foreign" -- Foreign interface statement
let TOK_FOREIGN: int = -1025;

# "unsafe" -- Unsafe indicator
let TOK_UNSAFE: int = -1026;

# "identifier" -- Lexical identifier
let TOK_IDENTIFIER: int = -2001;

# "integer" -- Constant integral number
let TOK_INTEGER: int = -3001;

# The last token read from input stream.
let mut last_char: int8 = 0x20;

# The current identifier being consumed by the tokenizer.
let mut current_id: asciz.String;

# get_next_token -- Return the next token from stdin.
# -----------------------------------------------------------------------------
def get_next_token() -> int {
    # Skip any whitespace.
    while isspace(last_char) { last_char = getchar(); }

    # Check if we've reached the end of the stream and the send the END token.
    if last_char == -1 { return TOK_END; }

    # Check for and attempt to consume identifiers and keywords (eg. "def").
    if isalpha(last_char) {
        # identifier = [a-zA-Z][a-zA-Z0-9]*
        asciz.append(current_id, last_char);
        loop {
            last_char = getchar();
            if not isalnum(last_char) { break; }
            asciz.append(current_id, last_char);
        }

        # Check for and return keyword tokens instead of the identifier.
        if asciz.eq(current_id, "def")        { return TOK_DEF; }
        if asciz.eq(current_id, "let")        { return TOK_LET; }
        if asciz.eq(current_id, "static")     { return TOK_STATIC; }
        if asciz.eq(current_id, "mut")        { return TOK_MUT; }
        if asciz.eq(current_id, "true")       { return TOK_TRUE; }
        if asciz.eq(current_id, "false")      { return TOK_FALSE; }
        if asciz.eq(current_id, "self")       { return TOK_SELF; }
        if asciz.eq(current_id, "as")         { return TOK_AS; }
        if asciz.eq(current_id, "and")        { return TOK_AND; }
        if asciz.eq(current_id, "or")         { return TOK_OR; }
        if asciz.eq(current_id, "not")        { return TOK_NOT; }
        if asciz.eq(current_id, "if")         { return TOK_IF; }
        if asciz.eq(current_id, "else")       { return TOK_ELSE; }
        if asciz.eq(current_id, "for")        { return TOK_FOR; }
        if asciz.eq(current_id, "while")      { return TOK_WHILE; }
        if asciz.eq(current_id, "loop")       { return TOK_LOOP; }
        if asciz.eq(current_id, "match")      { return TOK_MATCH; }
        if asciz.eq(current_id, "break")      { return TOK_BREAK; }
        if asciz.eq(current_id, "continue")   { return TOK_CONTINUE; }
        if asciz.eq(current_id, "return")     { return TOK_RETURN; }
        if asciz.eq(current_id, "type")       { return TOK_TYPE; }
        if asciz.eq(current_id, "enum")       { return TOK_ENUM; }
        if asciz.eq(current_id, "module")     { return TOK_MODULE; }
        if asciz.eq(current_id, "import")     { return TOK_IMPORT; }
        if asciz.eq(current_id, "use")        { return TOK_USE; }
        if asciz.eq(current_id, "foreign")    { return TOK_FOREIGN; }
        if asciz.eq(current_id, "unsafe")     { return TOK_UNSAFE; }

        # Consumed identifier does not match any defined keyword.
        return TOK_IDENTIFIER;
    }

    # Check for and consume a numeric token.
    if isdigit(last_char) {
        # TODO: !!
        # digit = [0-9]
        # dec_integer = {digit}{digit}*
        # hex_integer = 0[xX]{digit}{digit}*
        # oct_integer = 0[oO][0-7][0-7]*
        # bin_integer = 0[bB][0-1][0-1]*
        # exp = [Ee][-+]?{digit}+
        # float = {digit}{digit}*\.{digit}{digit}*{exp}?
        #       | {digit}{digit}*{exp}?
        last_char = getchar();
    }

    # Check for and consume a string token.
    # [ ... ]

    # Consume and ignore line comments.
    if last_char == 0x23 {
        # comment = "#".*\n
        loop {
            last_char = getchar();
            if (last_char == -1)
                    or (last_char == 0x0A)
                    or (last_char == 0x0D) {
                break;
            }
        }
    }
}
