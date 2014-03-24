foreign "C" import "stdio.h";
foreign "C" import "ctype.h";
import asciz;

# Blocking
# -----------------------------------------------------------------------------
# [ ] Proper static data
# [ ] Fully test imports (in combination with successive foreign imports)
# [ ] Implicit-adjacent string concatenation

# Wishlist
# -----------------------------------------------------------------------------
# [ ] Simple enumerations

# Todo
# -----------------------------------------------------------------------------
# [ ] Tokenize ourself
# [ ] Return location span along with token
# [ ] Refactor
# [ ]   - Perhaps separate some things to keep this file smaller
# [ ] Fully test both good and bad sets of data (eg. trigger all errors)
# [ ] Ensure a new line token is always produced
# [ ] Fix numerical handling (lots of refactor needed there)
# [ ] Error "counting"

# The lexer returns tokens [0-255] to if its an unknown symbol, otherwise
# one of the known symbols.
# -----------------------------------------------------------------------------

# "error" -- poison token to indicate an error in the token stream
let TOK_ERROR: int = -1;

# "end" -- End-of-stream
let TOK_END: int = -2;

# "line" -- End-of-line
let TOK_LINE: int = -3;

# "def" -- Function declaration
let TOK_DEF: int = -1001;

# "let" -- Local slot declaration
let TOK_LET: int = -1002;

# "static" -- Static slot declaration
let TOK_STATIC: int = -1003;

# "mut" -- Mutable slot or type modifier
let TOK_MUT: int = -1004;

# "true" -- Boolean true
let TOK_TRUE: int = -1005;

# "false" -- Boolean false
let TOK_FALSE: int = -1006;

# "self" -- The contextual instance bound to the method
let TOK_SELF: int = -1007;

# "as" -- Safe type cast operator
let TOK_AS: int = -1008;

# "and" -- Logical AND for boolean expressions
let TOK_AND: int = -1009;

# "or" -- Logical OR for boolean expressions
let TOK_OR: int = -1010;

# "not" -- Logical NOT for boolean expressions
let TOK_NOT: int = -1011;

# "if" -- Conditional statement
let TOK_IF: int = -1012;

# "else" -- Initiates the else clause of a conditional statement
let TOK_ELSE: int = -1013;

# "while" -- Condition-controlled loop
let TOK_WHILE: int = -1014;

# "loop" -- Infinite loop
let TOK_LOOP: int = -1015;

# "for" -- Collection-controlled loop
let TOK_FOR: int = -1016;

# "match" -- Pattern match expression
let TOK_MATCH: int = -1017;

# "break" -- Loop termination
let TOK_BREAK: int = -1018;

# "continue" -- Loop restart
let TOK_CONTINUE: int = -1019;

# "return" -- Immediate return from function
let TOK_RETURN: int = -1020;

# "type" -- Product type declaration
let TOK_TYPE: int = -1021;

# "enum" -- Sum type declaration
let TOK_ENUM: int = -1022;

# "module" -- Module declaration
let TOK_MODULE: int = -1023;

# "import" -- Import statement
let TOK_IMPORT: int = -1024;

# "use" -- Alias declaration
let TOK_USE: int = -1025;

# "foreign" -- Foreign interface statement
let TOK_FOREIGN: int = -1026;

# "unsafe" -- Unsafe indicator
let TOK_UNSAFE: int = -1027;

# "->" -- Function return type declarator
let TOK_RARROW: int = -2001;

# "+" -- Plus
let TOK_PLUS: int = -2002;

# "-" -- Minus
let TOK_MINUS: int = -2003;

# "*" -- Star
let TOK_STAR: int = -2004;

# "/" -- Forward slash
let TOK_FSLASH: int = -2005;

# "%" -- Percent
let TOK_PERCENT: int = -2006;

# "^" -- Hat
let TOK_HAT: int = -2007;

# "&" -- Ampersand
let TOK_AMPERSAND: int = -2008;

# "(" -- Left parenthesis
let TOK_LPAREN: int = -2009;

# ")" -- Right parenthesis
let TOK_RPAREN: int = -2010;

# "[" -- Left bracket
let TOK_LBRACKET: int = -2011;

# "]" -- Right bracket
let TOK_RBRACKET: int = -2012;

# "{" -- Left brace
let TOK_LBRACE: int = -2013;

# "}" -- Right brace
let TOK_RBRACE: int = -2014;

# ";" -- Semicolon
let TOK_SEMICOLON: int = -2015;

# ":" -- Colon
let TOK_COLON: int = -2016;

# "," -- Comma
let TOK_COMMA: int = -2017;

# "." -- Dot
let TOK_DOT: int = -2018;

# "<" -- Left caret
let TOK_LCARET: int = -2019;

# ">" -- Right caret
let TOK_RCARET: int = -2020;

# "<=" -- Left caret followed by equals to
let TOK_LCARET_EQ: int = -2021;

# ">=" -- Right caret followed by equals to
let TOK_RCARET_EQ: int = -2022;

# "==" -- Equals followed by and Equals
let TOK_EQ_EQ: int = -2023;

# "<>" -- Left caret followed by a right caret
let TOK_LCARET_RCARET: int = -2024;

# "=" -- Equal
let TOK_EQ: int = -2025;

# "+=" -- Plus followed by an equals
let TOK_PLUS_EQ: int = -2026;

# "-=" -- Minus followed by an equals
let TOK_MINUS_EQ: int = -2027;

# "*=" -- Star followed by an equals
let TOK_STAR_EQ: int = -2028;

# "/=" -- Forward slash followed by an equals
let TOK_FSLASH_EQ: int = -2029;

# "%=" -- Percent followed by an equals
let TOK_PERCENT_EQ: int = -2030;

# "identifier" -- Lexical identifier
let TOK_IDENTIFIER: int = -3001;

# "integer" -- Integral literal
let TOK_DEC_INTEGER: int = -4001;
let TOK_BIN_INTEGER: int = -4002;
let TOK_OCT_INTEGER: int = -4003;
let TOK_HEX_INTEGER: int = -4004;

# "float" -- Floating-point literal
let TOK_FLOAT: int = -4005;

# The last token read from input stream.
let mut lchar: int = asciz.ord(' ');

# The 1-character look-ahead buffer.
let mut nchar: int = asciz.ord(' ');

# The 2-character look-ahead buffer.
let mut nnchar: int = asciz.ord(' ');

# The current identifier being consumed by the tokenizer.
let mut current_id: asciz.String;

# The current number being consumed by the tokenizer.
let mut current_num: asciz.String;

# print_error -- Print an error message.
# -----------------------------------------------------------------------------
def print_error(m: str) {
    printf("error: %s\n" as ^int8, m);
}

# bump -- Advance the tokenizer by a single character.
# -----------------------------------------------------------------------------
def bump() -> int {
    let temp: int = lchar;
    lchar = nchar;
    nchar = nnchar;
    nnchar = getchar();
    temp;
}

# is_whitespace -- Test if the passed character constitutes whitespace.
# -----------------------------------------------------------------------------
def is_whitespace(c: int) -> bool {
    c == asciz.ord(' ') or
    c == asciz.ord('\n') or
    c == asciz.ord('\t') or
    c == asciz.ord('\r');
}

# is_alphabetic -- Test if the passed character is alphabetic.
# -----------------------------------------------------------------------------
def is_alphabetic(c: int) -> bool {
    isalpha(c as int32) <> 0;
}

# is_alphanumeric -- Test if the passed character is alphanumeric.
# -----------------------------------------------------------------------------
def is_alphanumeric(c: int) -> bool {
    isalnum(c as int32) <> 0;
}

# is_numeric -- Test if the passed character is numeric.
# -----------------------------------------------------------------------------
def is_numeric(c: int) -> bool {
    isdigit(c as int32) <> 0;
}

# consume_whitespace -- Eat whitespace.
# -----------------------------------------------------------------------------
def consume_whitespace() { while is_whitespace(lchar) { bump(); } }

# scan_identifier -- Scan for and match and identifier or keyword.
# -----------------------------------------------------------------------------
# identifier = [A-Za-z_][A-Za-z_0-9]*
# -----------------------------------------------------------------------------
def scan_identifier() -> int {
    # Clear the identifier buffer.
    asciz.clear(current_id);

    # Continue through the input stream until we are no longer part
    # of a possible identifier.
    loop {
        asciz.push(current_id, bump());
        if not is_alphanumeric(lchar) and
                not lchar == asciz.ord('_') {
            break;
        }
    }

    # Check for and return keyword tokens instead of the identifier.
    # TODO: A hash-table would better serve this.
    if asciz.eq_str(current_id, "def")        { return TOK_DEF; }
    if asciz.eq_str(current_id, "let")        { return TOK_LET; }
    if asciz.eq_str(current_id, "static")     { return TOK_STATIC; }
    if asciz.eq_str(current_id, "mut")        { return TOK_MUT; }
    if asciz.eq_str(current_id, "true")       { return TOK_TRUE; }
    if asciz.eq_str(current_id, "false")      { return TOK_FALSE; }
    if asciz.eq_str(current_id, "self")       { return TOK_SELF; }
    if asciz.eq_str(current_id, "as")         { return TOK_AS; }
    if asciz.eq_str(current_id, "and")        { return TOK_AND; }
    if asciz.eq_str(current_id, "or")         { return TOK_OR; }
    if asciz.eq_str(current_id, "not")        { return TOK_NOT; }
    if asciz.eq_str(current_id, "if")         { return TOK_IF; }
    if asciz.eq_str(current_id, "else")       { return TOK_ELSE; }
    if asciz.eq_str(current_id, "for")        { return TOK_FOR; }
    if asciz.eq_str(current_id, "while")      { return TOK_WHILE; }
    if asciz.eq_str(current_id, "loop")       { return TOK_LOOP; }
    if asciz.eq_str(current_id, "match")      { return TOK_MATCH; }
    if asciz.eq_str(current_id, "break")      { return TOK_BREAK; }
    if asciz.eq_str(current_id, "continue")   { return TOK_CONTINUE; }
    if asciz.eq_str(current_id, "return")     { return TOK_RETURN; }
    if asciz.eq_str(current_id, "type")       { return TOK_TYPE; }
    if asciz.eq_str(current_id, "enum")       { return TOK_ENUM; }
    if asciz.eq_str(current_id, "module")     { return TOK_MODULE; }
    if asciz.eq_str(current_id, "import")     { return TOK_IMPORT; }
    if asciz.eq_str(current_id, "use")        { return TOK_USE; }
    if asciz.eq_str(current_id, "foreign")    { return TOK_FOREIGN; }
    if asciz.eq_str(current_id, "unsafe")     { return TOK_UNSAFE; }

    # Scanned identifier does not match any defined keyword.
    return TOK_IDENTIFIER;
}

# scan_numeric -- Scan for and produce a numeric token.
# -----------------------------------------------------------------------------
# numeric = integer | float
# digit = [0-9]
# integer = dec_integer | hex_integer | bin_integer | oct_integer
# dec_integer = {digit}({digit}|_)*
# bin_integer = 0[bB][0-1]([0-1]|_)*
# oct_integer = 0[oO][0-7]([0-7]|_)*
# hex_integer = 0[xX][0-9A-Fa-f]([0-9A-Fa-f]|_)*
# exp = [Ee][-+]?{digit}({digit}|_)*
# float = {digit}({digit}|_)*\.{digit}({digit}|_)*{exp}?
#       | {digit}({digit}|_)*{exp}?
# -----------------------------------------------------------------------------
def scan_numeric() -> int {
    # Declare our expected token; we don't know yet.
    let current_tok: int = 0;

    # Clear the current_num buffer for user.
    asciz.clear(current_num);

    # If we are currently a zero ...
    if lchar == asciz.ord('0') {
        # ... Peek ahead and check if we are a base-prefixed numeric.
        current_tok =
            if nchar == asciz.ord('b') or nchar == asciz.ord('B') {
                bump();
                TOK_BIN_INTEGER;
            } else if nchar == asciz.ord('x') or nchar == asciz.ord('X') {
                bump();
                TOK_HEX_INTEGER;
            } else if nchar == asciz.ord('o') or nchar == asciz.ord('O') {
                bump();
                TOK_OCT_INTEGER;
            } else {
                # We are not a base-prefixed integer.
                0;
            };

        if current_tok == 0 {
            # We are not dealing with a base_prefixed numeric.
            asciz.push(current_num, lchar);
        } else if current_tok == TOK_BIN_INTEGER {
            # Scan for the remainder of this binary numeric.
            # TODO: This could probably be reduced into a single
            #   loop that uses a function pointer taken from an anon function
            #   to make the check.
            loop {
                bump();
                if asciz.in_range(lchar, '0', '1') {
                    asciz.push(current_num, lchar);
                } else if lchar <> asciz.ord('_') {
                    break;
                }
            }
            return current_tok;
        } else if current_tok == TOK_HEX_INTEGER {
            # Scan for the remainder of this hexadecimal numeric.
            loop {
                bump();
                if isxdigit(lchar as int32) <> 0 {
                    asciz.push(current_num, lchar);
                } else if lchar <> asciz.ord('_') {
                    break;
                }
            }
            return current_tok;
        } else if current_tok == TOK_OCT_INTEGER {
            # Scan for the remainder of this octal numeric.
            loop {
                bump();
                if asciz.in_range(lchar, '0', '7') {
                    asciz.push(current_num, lchar);
                } else if lchar <> asciz.ord('_') {
                    break;
                }
            }
            return current_tok;
        }
    }

    # We are at least a decimal numeric.
    current_tok = TOK_DEC_INTEGER;

    # Scan for the remainder of the integral part of the numeric.
    while is_numeric(lchar) {
        asciz.push(current_num, lchar);
        bump();
    }

    # Check for a period (which could indicate the continuation into a
    # floating-point token or
    if lchar == asciz.ord('.') {
        # Peek a character ahead and ensure it is a digit (we need at
        # least one digit to count this as a valid floating-point token).
        if not is_numeric(nchar) {
            # We are just a plain numeric token.
            return current_tok;
        }

        # We are now a floating point token.
        current_tok = TOK_FLOAT;

        # Push the period and bump to the next token.
        asciz.push(current_num, bump());

        # Scan the fractional part of the numeric.
        while is_numeric(lchar) {
            asciz.push(current_num, lchar);
            bump();
        }
    }

    # Check for an 'e' or 'E' character that could indicate an exponent on
    # this numeric constant.
    if lchar == asciz.ord('e') or lchar == asciz.ord('E') {
        # Ensure that we are followed by an optinally-prefixed digit (
        # otherwise this e is just an e).
        if not is_numeric(nchar) and not (
                (nchar == asciz.ord('+') or nchar == asciz.ord('-'))
                    and is_numeric(nnchar)) {
            # We are just an e.
            return current_tok;
        }

        # We are now a floating point token (if we weren't one before).
        current_tok = TOK_FLOAT;

        # Push the 'e' or 'E' and the next character onto the buffer.
        asciz.push(current_num, bump());
        asciz.push(current_num, bump());

        # Scan the exponent part of the numeric.
        while is_numeric(lchar) {
            asciz.push(current_num, lchar);
            bump();
        }
    }

    # We've matched a numeric; return the token.
    return current_tok;
}

# scan_string -- Scan for and produce a string token.
# -----------------------------------------------------------------------------
# [...]
# -----------------------------------------------------------------------------
# [...]

# scan_punctuator -- Scan for and match a punctuator token.
# -----------------------------------------------------------------------------
def scan_punctuator() -> int {
    # First attempt to match those that are unambigious in that
    # if the current character matches it is the token.
    if      lchar == asciz.ord('(') { bump(); return TOK_LPAREN; }
    else if lchar == asciz.ord(')') { bump(); return TOK_RPAREN; }
    else if lchar == asciz.ord('[') { bump(); return TOK_LBRACKET; }
    else if lchar == asciz.ord(']') { bump(); return TOK_RBRACKET; }
    else if lchar == asciz.ord('{') { bump(); return TOK_LBRACE; }
    else if lchar == asciz.ord('}') { bump(); return TOK_RBRACE; }
    else if lchar == asciz.ord(';') { bump(); return TOK_SEMICOLON; }
    else if lchar == asciz.ord(':') { bump(); return TOK_COLON; }
    else if lchar == asciz.ord(',') { bump(); return TOK_COMMA; }
    else if lchar == asciz.ord('.') { bump(); return TOK_DOT; }
    else if lchar == asciz.ord('^') { bump(); return TOK_HAT; }
    else if lchar == asciz.ord('&') { bump(); return TOK_AMPERSAND; }

    # Next take a peek at the next character and disambiguate the following
    # punctuators.
    if lchar == 0x2B {
        bump();
        if lchar == 0x3D { bump(); return TOK_PLUS_EQ; }
        return TOK_PLUS;
    } else if lchar == 0x2D {
        bump();
        if lchar == 0x3D { bump(); return TOK_MINUS_EQ; }
        if lchar == 0x3C { bump(); return TOK_RARROW; }
        return TOK_MINUS;
    } else if lchar == 0x2A {
        bump();
        if lchar == 0x3D { bump(); return TOK_STAR_EQ; }
        return TOK_STAR;
    } else if lchar == 0x2F {
        bump();
        if lchar == 0x3D { bump(); return TOK_FSLASH_EQ; }
        return TOK_FSLASH;
    } else if lchar == 0x25 {
        bump();
        if lchar == 0x3D { bump(); return TOK_PERCENT_EQ; }
        return TOK_PERCENT;
    } else if lchar == 0x3C {
        bump();
        if lchar == 0x3D { bump(); return TOK_LCARET_EQ; }
        if lchar == 0x3E { bump(); return TOK_LCARET_RCARET; }
        return TOK_LCARET;
    } else if lchar == 0x3E {
        bump();
        if lchar == 0x3D { bump(); return TOK_RCARET_EQ; }
        return TOK_RCARET;
    } else if lchar == 0x3D {
        bump();
        if lchar == 0x3D { bump(); return TOK_EQ_EQ; }
        return TOK_EQ;
    }

    # Didn't match a punctuator token.
    0;
}

# get_next_token -- Return the next token from stdin.
# -----------------------------------------------------------------------------
def get_next_token() -> int {
    # Skip any whitespace.
    consume_whitespace();

    # Check if we've reached the end of the stream and the send the END token.
    if lchar == asciz.EOF { return TOK_END; }

    # Check for an alphabetic or '_' character which signals the beginning
    # of an identifier.
    if is_alphabetic(lchar) or lchar == asciz.ord('_') {
        # Scan for and match the identifier
        return scan_identifier();
    }

    # Check for a leading digit that would indicate the start of a
    # numeric token.
    if is_numeric(lchar) {
        # Scan for and match the numeric token.
        return scan_numeric();
    }

    # Check for and consume a string token.
    # [ ... ]

    # Check for and attempt to consume punctuators (eg. "+").
    let possible_token: int = scan_punctuator();
    if possible_token <> 0 { return possible_token; }

    # Consume and ignore line comments; returning the next token
    # following the line comment.
    if lchar == asciz.ord('#') {
        loop {
            bump();
            if lchar == -1 { break; }
            else if lchar == 0x0A or lchar == 0x0D {
                return get_next_token();
            }
        }
    }

    # No idea what we have; return a poison token.
    printf("error: unknown token: '%c'\n" as ^int8, lchar);
    lchar = getchar();
    return TOK_ERROR;
}

# println_token -- Print the token representation.
# -----------------------------------------------------------------------------
def println_token(token: int) {
    if token == TOK_ERROR {
        printf("<error>\n" as ^int8);
    } else if token == TOK_END {
        printf("<end>\n" as ^int8);
    } else if token == TOK_LINE {
        printf("<line>\n" as ^int8);
    } else if token <= -1000 and token > -2000 {
        printf("<keyword> '" as ^int8);
        asciz.print(current_id);
        printf("'\n" as ^int8);
    } else if token == TOK_IDENTIFIER {
        printf("<identifier> '" as ^int8);
        asciz.print(current_id);
        printf("'\n" as ^int8);
    } else if token == TOK_DEC_INTEGER {
        printf("<decimal integer> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == TOK_BIN_INTEGER {
        printf("<binary integer> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == TOK_OCT_INTEGER {
        printf("<octal integer> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == TOK_HEX_INTEGER {
        printf("<hexadecimal integer> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == TOK_FLOAT {
        printf("<floating-point> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == TOK_RARROW {
        printf("<punctuator> '->'\n" as ^int8);
    } else if token == TOK_PLUS {
        printf("<punctuator> '+'\n" as ^int8);
    } else if token == TOK_MINUS {
        printf("<punctuator> '-'\n" as ^int8);
    } else if token == TOK_STAR {
        printf("<punctuator> '*'\n" as ^int8);
    } else if token == TOK_FSLASH {
        printf("<punctuator> '/'\n" as ^int8);
    } else if token == TOK_PERCENT {
        printf("<punctuator> '%'\n" as ^int8);
    } else if token == TOK_HAT {
        printf("<punctuator> '^'\n" as ^int8);
    } else if token == TOK_AMPERSAND {
        printf("<punctuator> '&'\n" as ^int8);
    } else if token == TOK_LPAREN {
        printf("<punctuator> '('\n" as ^int8);
    } else if token == TOK_RPAREN {
        printf("<punctuator> ')'\n" as ^int8);
    } else if token == TOK_LBRACKET {
        printf("<punctuator> '['\n" as ^int8);
    } else if token == TOK_RBRACKET {
        printf("<punctuator> ']'\n" as ^int8);
    } else if token == TOK_LBRACE {
        printf("<punctuator> '{'\n" as ^int8);
    } else if token == TOK_RBRACE {
        printf("<punctuator> '}'\n" as ^int8);
    } else if token == TOK_SEMICOLON {
        printf("<punctuator> ';'\n" as ^int8);
    } else if token == TOK_COLON {
        printf("<punctuator> ':'\n" as ^int8);
    } else if token == TOK_COMMA {
        printf("<punctuator> ','\n" as ^int8);
    } else if token == TOK_DOT {
        printf("<punctuator> '.'\n" as ^int8);
    } else if token == TOK_LCARET {
        printf("<punctuator> '<'\n" as ^int8);
    } else if token == TOK_RCARET {
        printf("<punctuator> '>'\n" as ^int8);
    } else if token == TOK_LCARET_EQ {
        printf("<punctuator> '<='\n" as ^int8);
    } else if token == TOK_RCARET_EQ {
        printf("<punctuator> '>='\n" as ^int8);
    } else if token == TOK_EQ_EQ {
        printf("<punctuator> '=='\n" as ^int8);
    } else if token == TOK_LCARET_RCARET {
        printf("<punctuator> '<>'\n" as ^int8);
    } else if token == TOK_EQ {
        printf("<punctuator> '='\n" as ^int8);
    } else if token == TOK_PLUS_EQ {
        printf("<punctuator> '+='\n" as ^int8);
    } else if token == TOK_MINUS_EQ {
        printf("<punctuator> '-='\n" as ^int8);
    } else if token == TOK_STAR_EQ {
        printf("<punctuator> '*='\n" as ^int8);
    } else if token == TOK_FSLASH_EQ {
        printf("<punctuator> '/='\n" as ^int8);
    } else if token == TOK_PERCENT_EQ {
        printf("<punctuator> '%='\n" as ^int8);
    }
}

def main() {
    let tok: int;
    loop {
        tok = get_next_token();
        println_token(tok);
        if tok == TOK_END { break; }
    }
}
