foreign "C" import "stdio.h";
foreign "C" import "ctype.h";
import asciz;
import tokens;

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
# [ ] Error "counting"
# -----------------------------------------------------------------------------

# Kinds of string literals.
let STR_SINGLE: int = 1;
let STR_DOUBLE: int = 2;

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

# The current string being consumed by the tokenizer.
let mut cur_str: asciz.String;

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

# scan_identifier -- Scan for and match an identifier or keyword.
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
    if asciz.eq_str(current_id, "def")      { return tokens.TOK_DEF; }
    if asciz.eq_str(current_id, "let")      { return tokens.TOK_LET; }
    if asciz.eq_str(current_id, "static")   { return tokens.TOK_STATIC; }
    if asciz.eq_str(current_id, "mut")      { return tokens.TOK_MUT; }
    if asciz.eq_str(current_id, "true")     { return tokens.TOK_TRUE; }
    if asciz.eq_str(current_id, "false")    { return tokens.TOK_FALSE; }
    if asciz.eq_str(current_id, "self")     { return tokens.TOK_SELF; }
    if asciz.eq_str(current_id, "as")       { return tokens.TOK_AS; }
    if asciz.eq_str(current_id, "and")      { return tokens.TOK_AND; }
    if asciz.eq_str(current_id, "or")       { return tokens.TOK_OR; }
    if asciz.eq_str(current_id, "not")      { return tokens.TOK_NOT; }
    if asciz.eq_str(current_id, "if")       { return tokens.TOK_IF; }
    if asciz.eq_str(current_id, "else")     { return tokens.TOK_ELSE; }
    if asciz.eq_str(current_id, "for")      { return tokens.TOK_FOR; }
    if asciz.eq_str(current_id, "while")    { return tokens.TOK_WHILE; }
    if asciz.eq_str(current_id, "loop")     { return tokens.TOK_LOOP; }
    if asciz.eq_str(current_id, "match")    { return tokens.TOK_MATCH; }
    if asciz.eq_str(current_id, "break")    { return tokens.TOK_BREAK; }
    if asciz.eq_str(current_id, "continue") { return tokens.TOK_CONTINUE; }
    if asciz.eq_str(current_id, "return")   { return tokens.TOK_RETURN; }
    if asciz.eq_str(current_id, "type")     { return tokens.TOK_TYPE; }
    if asciz.eq_str(current_id, "enum")     { return tokens.TOK_ENUM; }
    if asciz.eq_str(current_id, "module")   { return tokens.TOK_MODULE; }
    if asciz.eq_str(current_id, "import")   { return tokens.TOK_IMPORT; }
    if asciz.eq_str(current_id, "use")      { return tokens.TOK_USE; }
    if asciz.eq_str(current_id, "foreign")  { return tokens.TOK_FOREIGN; }
    if asciz.eq_str(current_id, "unsafe")   { return tokens.TOK_UNSAFE; }

    # Scanned identifier does not match any defined keyword.
    return tokens.TOK_IDENTIFIER;
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
                tokens.TOK_BIN_INTEGER;
            } else if nchar == asciz.ord('x') or nchar == asciz.ord('X') {
                bump();
                tokens.TOK_HEX_INTEGER;
            } else if nchar == asciz.ord('o') or nchar == asciz.ord('O') {
                bump();
                tokens.TOK_OCT_INTEGER;
            } else {
                # We are not a base-prefixed integer.
                0;
            };

        if current_tok == tokens.TOK_BIN_INTEGER {
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
        } else if current_tok == tokens.TOK_HEX_INTEGER {
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
        } else if current_tok == tokens.TOK_OCT_INTEGER {
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
    current_tok = tokens.TOK_DEC_INTEGER;

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
        current_tok = tokens.TOK_FLOAT;

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
        current_tok = tokens.TOK_FLOAT;

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
# xdigit = [0-9a-fa-F]
# str = \'([^'\\]|\\[#'"\\abfnrtv0]|\\[xX]{xdigit}{2})*\'
#     | \"([^"\\]|\\[#'"\\abfnrtv0]|\\[xX]{xdigit}{2})*\"
# -----------------------------------------------------------------------------
def scan_string() -> int {
    # What kind of string are we dealing with here; we're either single-quoted
    # or double-quoted.
    let current_tok: int = tokens.TOK_STRING;
    let kind: int =
        if lchar == asciz.ord('"') {
            STR_DOUBLE;
        } else {
            STR_SINGLE;
        };

    # Bump past the quote character.
    bump();

    # Clear the string buffer.
    asciz.clear(cur_str);

    # Loop and consume the string token.
    let in_escape: bool = false;
    let in_byte_escape: bool = false;
    loop {
        if in_escape {
            # Bump the character onto the buffer.
            asciz.push(cur_str, bump());

            # Check if we have an extension control character.
            if lchar == asciz.ord('x') or lchar == asciz.ord('X') {
                in_byte_escape = true;
            }

            # No longer in an escape sequence.
            in_escape = false;
        } else if in_byte_escape {
            # Bump two characters.
            asciz.push(cur_str, bump());
            asciz.push(cur_str, bump());

            # No longer in a byte-escape sequence.
            in_byte_escape = false;
        } else {
            if lchar == asciz.ord('\\') {
                # Mark that we're now in an escape sequence.
                in_escape = true;

                # Bump the character onto the buffer.
                asciz.push(cur_str, bump());
            } else if (kind == STR_SINGLE and lchar == asciz.ord("'")) or
                      (kind == STR_DOUBLE and lchar == asciz.ord('"')) {
                # Found the closing quote; we're done.
                bump();
                break;
            } else {
                # Bump the character onto the buffer.
                asciz.push(cur_str, bump());
            }
        }
    }

    # Matched the string token.
    current_tok;
}

# scan_punctuator -- Scan for and match a punctuator token.
# -----------------------------------------------------------------------------
def scan_punctuator() -> int {
    # First attempt to match those that are unambigious in that
    # if the current character matches it is the token.
    if      lchar == asciz.ord('(') { bump(); return tokens.TOK_LPAREN; }
    else if lchar == asciz.ord(')') { bump(); return tokens.TOK_RPAREN; }
    else if lchar == asciz.ord('[') { bump(); return tokens.TOK_LBRACKET; }
    else if lchar == asciz.ord(']') { bump(); return tokens.TOK_RBRACKET; }
    else if lchar == asciz.ord('{') { bump(); return tokens.TOK_LBRACE; }
    else if lchar == asciz.ord('}') { bump(); return tokens.TOK_RBRACE; }
    else if lchar == asciz.ord(';') { bump(); return tokens.TOK_SEMICOLON; }
    else if lchar == asciz.ord(',') { bump(); return tokens.TOK_COMMA; }
    else if lchar == asciz.ord('.') { bump(); return tokens.TOK_DOT; }
    else if lchar == asciz.ord('^') { bump(); return tokens.TOK_HAT; }
    else if lchar == asciz.ord('&') { bump(); return tokens.TOK_AMPERSAND; }

    # Next take a peek at the next character and disambiguate the following
    # punctuators.
    if lchar == asciz.ord('+') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_PLUS_EQ; }
        return tokens.TOK_PLUS;
    } else if lchar == asciz.ord('-') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_MINUS_EQ; }
        if lchar == asciz.ord('>') { bump(); return tokens.TOK_RARROW; }
        return tokens.TOK_MINUS;
    } else if lchar == asciz.ord('*') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_STAR_EQ; }
        return tokens.TOK_STAR;
    } else if lchar == asciz.ord('/') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_FSLASH_EQ; }
        return tokens.TOK_FSLASH;
    } else if lchar == asciz.ord('%') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_PERCENT_EQ; }
        return tokens.TOK_PERCENT;
    } else if lchar == asciz.ord('<') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_LCARET_EQ; }
        if lchar == asciz.ord('>') { bump(); return tokens.TOK_LCARET_RCARET; }
        return tokens.TOK_LCARET;
    } else if lchar == asciz.ord('>') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_RCARET_EQ; }
        return tokens.TOK_RCARET;
    } else if lchar == asciz.ord('=') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_EQ_EQ; }
        return tokens.TOK_EQ;
    } else if lchar == asciz.ord(':') {
        bump();
        if lchar == asciz.ord('=') { bump(); return tokens.TOK_COLON_EQ; }
        return tokens.TOK_COLON;
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
    if lchar == asciz.EOF { return tokens.TOK_END; }

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
    if lchar == asciz.ord("'") or lchar == asciz.ord('"') {
        # Scan the entire string token.
        return scan_string();
    }

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
    return tokens.TOK_ERROR;
}

# println_token -- Print the token representation.
# -----------------------------------------------------------------------------
def println_token(token: int) {
    if token == tokens.TOK_ERROR {
        printf("<error>\n" as ^int8);
    } else if token == tokens.TOK_END {
        printf("<end>\n" as ^int8);
    } else if token == tokens.TOK_LINE {
        printf("<line>\n" as ^int8);
    } else if token <= -1000 and token > -2000 {
        printf("<keyword> '" as ^int8);
        asciz.print(current_id);
        printf("'\n" as ^int8);
    } else if token == tokens.TOK_IDENTIFIER {
        printf("<identifier> '" as ^int8);
        asciz.print(current_id);
        printf("'\n" as ^int8);
    } else if token == tokens.TOK_DEC_INTEGER {
        printf("<decimal integer> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == tokens.TOK_BIN_INTEGER {
        printf("<binary integer> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == tokens.TOK_OCT_INTEGER {
        printf("<octal integer> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == tokens.TOK_HEX_INTEGER {
        printf("<hexadecimal integer> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == tokens.TOK_FLOAT {
        printf("<floating-point> '" as ^int8);
        asciz.print(current_num);
        printf("'\n" as ^int8);
    } else if token == tokens.TOK_STRING  {
        printf("<string> '" as ^int8);
        asciz.print(cur_str);
        printf("'\n" as ^int8);
    } else if token == tokens.TOK_RARROW {
        printf("<punctuator> '->'\n" as ^int8);
    } else if token == tokens.TOK_PLUS {
        printf("<punctuator> '+'\n" as ^int8);
    } else if token == tokens.TOK_MINUS {
        printf("<punctuator> '-'\n" as ^int8);
    } else if token == tokens.TOK_STAR {
        printf("<punctuator> '*'\n" as ^int8);
    } else if token == tokens.TOK_FSLASH {
        printf("<punctuator> '/'\n" as ^int8);
    } else if token == tokens.TOK_PERCENT {
        printf("<punctuator> '%'\n" as ^int8);
    } else if token == tokens.TOK_HAT {
        printf("<punctuator> '^'\n" as ^int8);
    } else if token == tokens.TOK_AMPERSAND {
        printf("<punctuator> '&'\n" as ^int8);
    } else if token == tokens.TOK_LPAREN {
        printf("<punctuator> '('\n" as ^int8);
    } else if token == tokens.TOK_RPAREN {
        printf("<punctuator> ')'\n" as ^int8);
    } else if token == tokens.TOK_LBRACKET {
        printf("<punctuator> '['\n" as ^int8);
    } else if token == tokens.TOK_RBRACKET {
        printf("<punctuator> ']'\n" as ^int8);
    } else if token == tokens.TOK_LBRACE {
        printf("<punctuator> '{'\n" as ^int8);
    } else if token == tokens.TOK_RBRACE {
        printf("<punctuator> '}'\n" as ^int8);
    } else if token == tokens.TOK_SEMICOLON {
        printf("<punctuator> ';'\n" as ^int8);
    } else if token == tokens.TOK_COLON {
        printf("<punctuator> ':'\n" as ^int8);
    } else if token == tokens.TOK_COMMA {
        printf("<punctuator> ','\n" as ^int8);
    } else if token == tokens.TOK_DOT {
        printf("<punctuator> '.'\n" as ^int8);
    } else if token == tokens.TOK_LCARET {
        printf("<punctuator> '<'\n" as ^int8);
    } else if token == tokens.TOK_RCARET {
        printf("<punctuator> '>'\n" as ^int8);
    } else if token == tokens.TOK_LCARET_EQ {
        printf("<punctuator> '<='\n" as ^int8);
    } else if token == tokens.TOK_RCARET_EQ {
        printf("<punctuator> '>='\n" as ^int8);
    } else if token == tokens.TOK_EQ_EQ {
        printf("<punctuator> '=='\n" as ^int8);
    } else if token == tokens.TOK_LCARET_RCARET {
        printf("<punctuator> '<>'\n" as ^int8);
    } else if token == tokens.TOK_EQ {
        printf("<punctuator> '='\n" as ^int8);
    } else if token == tokens.TOK_PLUS_EQ {
        printf("<punctuator> '+='\n" as ^int8);
    } else if token == tokens.TOK_MINUS_EQ {
        printf("<punctuator> '-='\n" as ^int8);
    } else if token == tokens.TOK_STAR_EQ {
        printf("<punctuator> '*='\n" as ^int8);
    } else if token == tokens.TOK_FSLASH_EQ {
        printf("<punctuator> '/='\n" as ^int8);
    } else if token == tokens.TOK_PERCENT_EQ {
        printf("<punctuator> '%='\n" as ^int8);
    } else if token == tokens.TOK_COLON_EQ {
        printf("<punctuator> ':='\n" as ^int8);
    }
}

def main() {
    let tok: int;
    loop {
        tok = get_next_token();
        println_token(tok);
        if tok == tokens.TOK_END { break; }
    }
}
