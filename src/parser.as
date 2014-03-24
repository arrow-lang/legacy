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
let mut last_char: int = asciz.ord(' ');

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
    let temp: int = last_char;
    last_char = getchar();
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
def consume_whitespace() { while is_whitespace(last_char) { bump(); } }

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
        if not is_alphanumeric(last_char) and
                not last_char == asciz.ord('_') {
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
    # Clear the current_num buffer for user.
    asciz.clear(current_num);

    # If we are currently a zero ...
    if last_char == asciz.ord('0') {
        # ... Peek ahead and check if we are a base-prefixed numeric.
        let pchar: int = getchar();
        let current_tok: int =
            if pchar == asciz.ord('b') or pchar == asciz.ord('B') {
                TOK_BIN_INTEGER;
            } else if pchar == asciz.ord('x') or pchar == asciz.ord('X') {
                TOK_HEX_INTEGER;
            } else if pchar == asciz.ord('o') or pchar == asciz.ord('O') {
                TOK_OCT_INTEGER;
            } else {
                # We are not a base-prefixed integer.
                0;
            };

        if current_tok == 0 {
            # We are not dealing with a base_prefixed numeric.
            asciz.push(current_num, last_char);
            last_char = pchar;
        } else if current_tok == TOK_BIN_INTEGER {
            # Scan for the remainder of this binary numeric.
            # TODO: This could probably be reduced into a single
            #   loop that uses a function pointer taken from an anon function
            #   to make the check.
            loop {
                bump();
                if asciz.in_range(last_char, '0', '1') {
                    asciz.push(current_num, last_char);
                } else if last_char <> asciz.ord('_') {
                    break;
                }
            }
            return current_tok;
        } else if current_tok == TOK_HEX_INTEGER {
            # Scan for the remainder of this hexadecimal numeric.
            loop {
                bump();
                if isxdigit(last_char as int32) <> 0 {
                    asciz.push(current_num, last_char);
                } else if last_char <> asciz.ord('_') {
                    break;
                }
            }
            return current_tok;
        } else if current_tok == TOK_OCT_INTEGER {
            # Scan for the remainder of this octal numeric.
            loop {
                bump();
                if asciz.in_range(last_char, '0', '7') {
                    asciz.push(current_num, last_char);
                } else if last_char <> asciz.ord('_') {
                    break;
                }
            }
            return current_tok;
        }
    }

    # Scan for the remainder of the integral part of the numeric.
    while is_numeric(last_char) {
        asciz.push(current_num, last_char);
        bump();
    }

    # We've matched a numeric; return the token.
    return TOK_DEC_INTEGER;

    # # Check for a '.' that would mean we are continuing this decimal integer
    # # into a floating-point token.
    # if last_char == asciz.ord('.') {
    #     # We need to have at least one digit after the period to make this a
    #     # floating-point numeric.
    #     last_char = getchar();
    #     if is_numeric(last_char) {
    #         # Scan for the remainder of the fractional part of the numeric.
    #         while is_numeric(last_char) {
    #             asciz.push(current_num, last_char);
    #             bump();
    #         }

    #         # We've matched a floating-point token.
    #         return TOK_FLOAT;
    #     } else {
    #         # We didn't want this.
    #         # ungetc(last_char as int32, 1 as ^_IO_FILE);
    #         last_char = 3;
    #     }
    # }

    # # We've matched a numeric; return the token.
    # return TOK_DEC_INTEGER;
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
    let uchar: int = last_char;
    last_char = getchar();
    if      uchar == 0x28 { return TOK_LPAREN; }
    else if uchar == 0x29 { return TOK_RPAREN; }
    else if uchar == 0x5B { return TOK_LBRACKET; }
    else if uchar == 0x5D { return TOK_RBRACKET; }
    else if uchar == 0x7B { return TOK_LBRACE; }
    else if uchar == 0x7D { return TOK_RBRACE; }
    else if uchar == 0x3B { return TOK_SEMICOLON; }
    else if uchar == 0x3A { return TOK_COLON; }
    else if uchar == 0x2C { return TOK_COMMA; }
    else if uchar == 0x2E { return TOK_DOT; }
    else if uchar == 0x5E { return TOK_HAT; }
    else if uchar == 0x26 { return TOK_AMPERSAND; }

    # Next take a peek at the next character and disambiguate the following
    # punctuators.
    if uchar == 0x2B {
        if last_char == 0x3D { return TOK_PLUS_EQ; }
        return TOK_PLUS;
    } else if uchar == 0x2D {
        if last_char == 0x3D { return TOK_MINUS_EQ; }
        if last_char == 0x3C { return TOK_RARROW; }
        return TOK_MINUS;
    } else if uchar == 0x2A {
        if last_char == 0x3D { return TOK_STAR_EQ; }
        return TOK_STAR;
    } else if uchar == 0x2F {
        if last_char == 0x3D { return TOK_FSLASH_EQ; }
        return TOK_FSLASH;
    } else if uchar == 0x25 {
        if last_char == 0x3D { return TOK_PERCENT_EQ; }
        return TOK_PERCENT;
    } else if uchar == 0x3C {
        if last_char == 0x3D { return TOK_LCARET_EQ; }
        if last_char == 0x3E { return TOK_LCARET_RCARET; }
        return TOK_LCARET;
    } else if uchar == 0x3E {
        if last_char == 0x3D { return TOK_RCARET_EQ; }
        return TOK_RCARET;
    } else if uchar == 0x3D {
        if last_char == 0x3D { return TOK_EQ_EQ; }
        return TOK_EQ;
    }

    # Didn't match a punctuator token.
    last_char = uchar;
    0;
}

# get_next_token -- Return the next token from stdin.
# -----------------------------------------------------------------------------
def get_next_token() -> int {
    # Skip any whitespace.
    consume_whitespace();

    # Check if we've reached the end of the stream and the send the END token.
    if last_char == asciz.EOF { return TOK_END; }

    # Check for an alphabetic or '_' character which signals the beginning
    # of an identifier.
    if is_alphabetic(last_char) or last_char == asciz.ord('_') {
        # Scan for and match the identifier
        return scan_identifier();
    }

    # Check for a leading digit that would indicate the start of a
    # numeric token.
    if is_numeric(last_char) {
        # Scan for and match the numeric token.
        return scan_numeric();
    }

    # if isdigit(last_char as int32) <> 0 {
    #     # digit = [0-9]
    #     # exp = [Ee][-+]?{digit}+
    #     # dec_integer = {digit}{digit}*
    #     # hex_integer = 0[xX]{digit}{digit}*
    #     # oct_integer = 0[oO][0-7][0-7]*
    #     # bin_integer = 0[bB][0-1][0-1]*
    #     # float = {digit}{digit}*\.{digit}{digit}*{exp}?
    #     #       | {digit}{digit}*{exp}?
    #     let mut current_tok: int = 0;
    #     let mut pchar: int = 0;

    #     # Clear out the current number for use.
    #     asciz.clear(current_num);

    #     if last_char == 0x30 {
    #         # Peek ahead and see if we are dealing with
    #         # a base-prefixed numeric.
    #         pchar = getchar() as int;
    #         current_tok =
    #             if      pchar == 0x78 or pchar == 0x58 { TOK_HEX_INTEGER; }
    #             else if pchar == 0x6F or pchar == 0x4F { TOK_OCT_INTEGER; }
    #             else if pchar == 0x62 or pchar == 0x42 { TOK_BIN_INTEGER; }
    #             else { 0; };

    #         # If we are not dealing with a base-prefixed numeric check if we
    #         # are still dealing with a number.
    #         if current_tok == 0
    #                 and isxdigit(pchar as int32) == 0
    #                 and pchar <> 0x2E
    #                 and pchar <> 0x65
    #                 and pchar <> 0x45 {
    #             # This is no longer a number; grab the zero and return us.
    #             asciz.push(current_num, last_char);
    #             last_char = pchar;
    #             return TOK_DEC_INTEGER;
    #         }

    #         # We are still a number.
    #         last_char = getchar();
    #     } else {
    #         # We are now tentatively a decimal number.
    #         current_tok = TOK_DEC_INTEGER;
    #     }

    #     # Enumerate through the input stream until we are no longer
    #     # a number.
    #     loop {
    #         asciz.push(current_num, last_char);
    #         last_char = getchar();
    #         if isxdigit(last_char as int32) == 0 { break; }
    #     }

    #     # Check if the next character continues the number token
    #     # into a floating-point token.
    #     if last_char <> 0x2E and pchar <> 0x65 and pchar <> 0x45 {
    #         # We have stopped being a number; return us.
    #         return current_tok;
    #     } else if current_tok <> TOK_DEC_INTEGER {
    #         # We are a base-prefixed integeral number; we cannot be
    #         # a floating-point number; raise an error and return poison.
    #         if current_tok == TOK_OCT_INTEGER {
    #             print_error("octal floating-point literal is not supported");
    #         } else if current_tok == TOK_HEX_INTEGER {
    #             print_error("hexadecimal floating-point literal is not supported");
    #         } else if current_tok == TOK_BIN_INTEGER {
    #             print_error("binary floating-point literal is not supported");
    #         }
    #         return TOK_ERROR;
    #     }

    #     if last_char == 0x2E {  # last_char == '.'
    #         # We are now a floating-point token.
    #         current_tok = TOK_FLOAT;

    #         # Push the period onto to buffer.
    #         asciz.push(current_num, last_char);

    #         # Enumerate through the input stream until we are no longer
    #         # a number.
    #         loop {
    #             last_char = getchar();
    #             if isdigit(last_char as int32) == 0 { break; }
    #             asciz.push(current_num, last_char);
    #         }
    #     }

    #     if last_char == 0x65 or last_char == 0x45 {
    #         # We are now a floating-point token.
    #         current_tok = TOK_FLOAT;

    #         # Push the e/E onto to buffer.
    #         asciz.push(current_num, last_char);

    #         # Ensure there is at least one number after the e/E.
    #         last_char = getchar();
    #         if isdigit(last_char as int32) == 0{
    #             # There is not at least one number of the e/E; report
    #             # an error and return a poison token.
    #             print_error("exponent has no digits");
    #             return TOK_ERROR;
    #         }

    #         # Enumerate through the input stream until we are no longer
    #         # a number.
    #         asciz.push(current_num, last_char);
    #         loop {
    #             last_char = getchar();
    #             if isdigit(last_char as int32) == 0 { break; }
    #             asciz.push(current_num, last_char);
    #         }
    #     }

    #     # Ensure that there is not a trailing period.
    #     if last_char == 0x2E {
    #         print_error("invalid suffix on floating-point literal");
    #         return TOK_ERROR;
    #     }

    #     # Return the token indicator.
    #     return current_tok;
    # }

    # Check for and consume a string token.
    # [ ... ]

    # Check for and attempt to consume punctuators (eg. "+").
    let possible_token: int = scan_punctuator();
    if possible_token <> 0 { return possible_token; }

    # Consume and ignore line comments; returning the next token
    # following the line comment.
    if last_char == asciz.ord('#') {
        loop {
            last_char = getchar();
            if last_char == -1 { break; }
            else if last_char == 0x0A or last_char == 0x0D {
                return get_next_token();
            }
        }
    }

    # No idea what we have; return a poison token.
    printf("error: unknown token: '%c'\n" as ^int8, last_char);
    last_char = getchar();
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
