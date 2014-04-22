import libc;
import string;
import tokens;

# Todo
# -----------------------------------------------------------------------------
# [ ] Return location span along with token
# [ ] Fully test both good and bad sets of data (eg. trigger all errors)
# -----------------------------------------------------------------------------

# Kinds of string literals.
let STR_SINGLE: int = 1;
let STR_DOUBLE: int = 2;

# The last token read from input stream.
let mut lchar: int = string.ord(' ');

# The 1-character look-ahead buffer.
let mut nchar: int = string.ord(' ');

# The 2-character look-ahead buffer.
let mut nnchar: int = string.ord(' ');

# The current buffer to play with by the tokenizer.
let mut current_buf: string.String = string.make();

# The current identifier being consumed by the tokenizer.
let mut current_id: string.String = string.make();

# The current number being consumed by the tokenizer.
let mut current_num: string.String = string.make();

# The current string being consumed by the tokenizer.
let mut cur_str: string.String = string.make();

# bump -- Advance the tokenizer by a single character.
# -----------------------------------------------------------------------------
def bump() -> int {
    let temp: int = lchar;
    lchar = nchar;
    nchar = nnchar;
    nnchar = libc.getchar();
    temp;
}


# Test if the char is in the passed range.
# -----------------------------------------------------------------------------
def in_range(c: int, s: char, e: char) -> bool {
    c >= (s as int8) and c <= (e as int8);
}

# is_whitespace -- Test if the passed character constitutes whitespace.
# -----------------------------------------------------------------------------
def is_whitespace(c: int) -> bool {
    c == string.ord(' ') or
    c == string.ord('\n') or
    c == string.ord('\t') or
    c == string.ord('\r');
}

# is_alphabetic -- Test if the passed character is alphabetic.
# -----------------------------------------------------------------------------
def is_alphabetic(c: int) -> bool {
    libc.isalpha(c as int32) <> 0;
}

# is_alphanumeric -- Test if the passed character is alphanumeric.
# -----------------------------------------------------------------------------
def is_alphanumeric(c: int) -> bool {
    libc.isalnum(c as int32) <> 0;
}

# is_numeric -- Test if the passed character is numeric.
# -----------------------------------------------------------------------------
def is_numeric(c: int) -> bool {
    libc.isdigit(c as int32) <> 0;
}

# consume_whitespace -- Eat whitespace.
# -----------------------------------------------------------------------------
def consume_whitespace() { while is_whitespace(lchar) { bump(); } }

# scan_identifier -- Scan for and match an identifier or keyword.
# -----------------------------------------------------------------------------
# identifier = [A-Za-z_][A-Za-z_0-9]*
# -----------------------------------------------------------------------------
def scan_identifier() -> int {
    # Clear the buffer.
    current_buf.clear();

    # Continue through the input stream until we are no longer part
    # of a possible identifier.
    loop {
        current_buf.append(bump() as char);
        if not is_alphanumeric(lchar) and
                not lchar == string.ord('_') {
            break;
        }
    }

    # Check for and return keyword tokens instead of the identifier.
    # TODO: A hash-table would better serve this.
    if current_buf.eq_str("def")      { return tokens.TOK_DEF; }
    if current_buf.eq_str("let")      { return tokens.TOK_LET; }
    if current_buf.eq_str("static")   { return tokens.TOK_STATIC; }
    if current_buf.eq_str("mut")      { return tokens.TOK_MUT; }
    if current_buf.eq_str("true")     { return tokens.TOK_TRUE; }
    if current_buf.eq_str("false")    { return tokens.TOK_FALSE; }
    if current_buf.eq_str("self")     { return tokens.TOK_SELF; }
    if current_buf.eq_str("as")       { return tokens.TOK_AS; }
    if current_buf.eq_str("and")      { return tokens.TOK_AND; }
    if current_buf.eq_str("or")       { return tokens.TOK_OR; }
    if current_buf.eq_str("not")      { return tokens.TOK_NOT; }
    if current_buf.eq_str("if")       { return tokens.TOK_IF; }
    if current_buf.eq_str("else")     { return tokens.TOK_ELSE; }
    if current_buf.eq_str("for")      { return tokens.TOK_FOR; }
    if current_buf.eq_str("while")    { return tokens.TOK_WHILE; }
    if current_buf.eq_str("loop")     { return tokens.TOK_LOOP; }
    if current_buf.eq_str("match")    { return tokens.TOK_MATCH; }
    if current_buf.eq_str("break")    { return tokens.TOK_BREAK; }
    if current_buf.eq_str("continue") { return tokens.TOK_CONTINUE; }
    if current_buf.eq_str("return")   { return tokens.TOK_RETURN; }
    if current_buf.eq_str("type")     { return tokens.TOK_TYPE; }
    if current_buf.eq_str("enum")     { return tokens.TOK_ENUM; }
    if current_buf.eq_str("module")   { return tokens.TOK_MODULE; }
    if current_buf.eq_str("import")   { return tokens.TOK_IMPORT; }
    if current_buf.eq_str("use")      { return tokens.TOK_USE; }
    if current_buf.eq_str("foreign")  { return tokens.TOK_FOREIGN; }
    if current_buf.eq_str("unsafe")   { return tokens.TOK_UNSAFE; }
    if current_buf.eq_str("global")   { return tokens.TOK_GLOBAL; }

    # Scanned identifier does not match any defined keyword.
    # Update the current_id.
    current_id.clear();
    current_id.extend(current_buf.data() as str);

    # Return the id label.
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
    current_num.clear();

    # If we are currently a zero ...
    if lchar == string.ord('0') {
        # ... Peek ahead and check if we are a base-prefixed numeric.
        current_tok =
            if nchar == string.ord('b') or nchar == string.ord('B') {
                bump();
                tokens.TOK_BIN_INTEGER;
            } else if nchar == string.ord('x') or nchar == string.ord('X') {
                bump();
                tokens.TOK_HEX_INTEGER;
            } else if nchar == string.ord('o') or nchar == string.ord('O') {
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
                if in_range(lchar, '0', '1') {
                    current_num.append(lchar as char);
                } else if lchar <> string.ord('_') {
                    break;
                }
            }
            return current_tok;
        } else if current_tok == tokens.TOK_HEX_INTEGER {
            # Scan for the remainder of this hexadecimal numeric.
            loop {
                bump();
                if libc.isxdigit(lchar as int32) <> 0 {
                    current_num.append(lchar as char);
                } else if lchar <> string.ord('_') {
                    break;
                }
            }
            return current_tok;
        } else if current_tok == tokens.TOK_OCT_INTEGER {
            # Scan for the remainder of this octal numeric.
            loop {
                bump();
                if in_range(lchar, '0', '7') {
                    current_num.append(lchar as char);
                } else if lchar <> string.ord('_') {
                    break;
                }
            }
            return current_tok;
        }
    }

    # We are at least a decimal numeric.
    current_tok = tokens.TOK_DEC_INTEGER;

    # Scan for the remainder of the integral part of the numeric.
    loop {
        if is_numeric(lchar) {
            current_num.append(lchar as char);
        } else if lchar <> string.ord('_') {
            break;
        }
        bump();
    }

    # Check for a period (which could indicate the continuation into a
    # floating-point token or
    if lchar == string.ord('.') {
        # Peek a character ahead and ensure it is a digit (we need at
        # least one digit to count this as a valid floating-point token).
        if not is_numeric(nchar) {
            # We are just a plain numeric token.
            return current_tok;
        }

        # We are now a floating point token.
        current_tok = tokens.TOK_FLOAT;

        # Push the period and bump to the next token.
        current_num.append(bump() as char);

        # Scan the fractional part of the numeric.
        while is_numeric(lchar) {
            current_num.append(lchar as char);
            bump();
        }
    }

    # Check for an 'e' or 'E' character that could indicate an exponent on
    # this numeric constant.
    if lchar == string.ord('e') or lchar == string.ord('E') {
        # Ensure that we are followed by an optinally-prefixed digit (
        # otherwise this e is just an e).
        if not is_numeric(nchar) and not (
                (nchar == string.ord('+') or nchar == string.ord('-'))
                    and is_numeric(nnchar)) {
            # We are just an e.
            return current_tok;
        }

        # We are now a floating point token (if we weren't one before).
        current_tok = tokens.TOK_FLOAT;

        # Push the 'e' or 'E' and the next character onto the buffer.
        current_num.append(bump() as char);
        current_num.append(bump() as char);

        # Scan the exponent part of the numeric.
        while is_numeric(lchar) {
            current_num.append(lchar as char);
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
        if lchar == string.ord('"') {
            STR_DOUBLE;
        } else {
            STR_SINGLE;
        };

    # Bump past the quote character.
    bump();

    # Clear the string buffer.
    cur_str.clear();

    # Loop and consume the string token.
    let in_escape: bool = false;
    let in_byte_escape: bool = false;
    loop {
        if in_escape {
            # Bump the character onto the buffer.
            cur_str.append(bump() as char);

            # Check if we have an extension control character.
            if lchar == string.ord('x') or lchar == string.ord('X') {
                in_byte_escape = true;
            }

            # No longer in an escape sequence.
            in_escape = false;
        } else if in_byte_escape {
            # Bump two characters.
            cur_str.append(bump() as char);
            cur_str.append(bump() as char);

            # No longer in a byte-escape sequence.
            in_byte_escape = false;
        } else {
            if lchar == string.ord('\\') {
                # Mark that we're now in an escape sequence.
                in_escape = true;

                # Bump the character onto the buffer.
                cur_str.append(bump() as char);
            } else if (kind == STR_SINGLE and lchar == string.ord("'")) or
                      (kind == STR_DOUBLE and lchar == string.ord('"')) {
                # Found the closing quote; we're done.
                bump();
                break;
            } else {
                # Bump the character onto the buffer.
                cur_str.append(bump() as char);
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
    if      lchar == string.ord('(') { bump(); return tokens.TOK_LPAREN; }
    else if lchar == string.ord(')') { bump(); return tokens.TOK_RPAREN; }
    else if lchar == string.ord('[') { bump(); return tokens.TOK_LBRACKET; }
    else if lchar == string.ord(']') { bump(); return tokens.TOK_RBRACKET; }
    else if lchar == string.ord('{') { bump(); return tokens.TOK_LBRACE; }
    else if lchar == string.ord('}') { bump(); return tokens.TOK_RBRACE; }
    else if lchar == string.ord(';') { bump(); return tokens.TOK_SEMICOLON; }
    else if lchar == string.ord(',') { bump(); return tokens.TOK_COMMA; }
    else if lchar == string.ord('.') { bump(); return tokens.TOK_DOT; }
    else if lchar == string.ord('^') { bump(); return tokens.TOK_HAT; }
    else if lchar == string.ord('&') { bump(); return tokens.TOK_AMPERSAND; }

    # Next take a peek at the next character and disambiguate the following
    # punctuators.
    if lchar == string.ord('+') {
        bump();
        if lchar == string.ord('=') { bump(); return tokens.TOK_PLUS_EQ; }
        return tokens.TOK_PLUS;
    } else if lchar == string.ord('-') {
        bump();
        if lchar == string.ord('=') { bump(); return tokens.TOK_MINUS_EQ; }
        if lchar == string.ord('>') { bump(); return tokens.TOK_RARROW; }
        return tokens.TOK_MINUS;
    } else if lchar == string.ord('*') {
        bump();
        if lchar == string.ord('=') { bump(); return tokens.TOK_STAR_EQ; }
        return tokens.TOK_STAR;
    } else if lchar == string.ord('/') {
        bump();
        if lchar == string.ord('=') { bump(); return tokens.TOK_FSLASH_EQ; }
        if lchar == string.ord('/') {
            bump();
            if lchar == string.ord('=') { bump(); return tokens.TOK_FSLASH_FSLASH_EQ; }
            return tokens.TOK_FSLASH_FSLASH;
        }
        return tokens.TOK_FSLASH;
    } else if lchar == string.ord('%') {
        bump();
        if lchar == string.ord('=') { bump(); return tokens.TOK_PERCENT_EQ; }
        return tokens.TOK_PERCENT;
    } else if lchar == string.ord('<') {
        bump();
        if lchar == string.ord('=') { bump(); return tokens.TOK_LCARET_EQ; }
        if lchar == string.ord('>') { bump(); return tokens.TOK_BANG_EQ; }
        return tokens.TOK_LCARET;
    } else if lchar == string.ord('>') {
        bump();
        if lchar == string.ord('=') { bump(); return tokens.TOK_RCARET_EQ; }
        return tokens.TOK_RCARET;
    } else if lchar == string.ord('=') {
        bump();
        if lchar == string.ord('=') { bump(); return tokens.TOK_EQ_EQ; }
        return tokens.TOK_EQ;
    } else if lchar == string.ord(':') {
        bump();
        return tokens.TOK_COLON;
    } else if lchar == string.ord('!') {
        bump();
        if lchar == string.ord("=") { bump(); return tokens.TOK_BANG_EQ; }
        return tokens.TOK_BANG;
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
    if lchar == -1 { return tokens.TOK_END; }

    # Check for an alphabetic or '_' character which signals the beginning
    # of an identifier.
    if is_alphabetic(lchar) or lchar == string.ord('_') {
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
    if lchar == string.ord("'") or lchar == string.ord('"') {
        # Scan the entire string token.
        return scan_string();
    }

    # Check for and attempt to consume punctuators (eg. "+").
    let possible_token: int = scan_punctuator();
    if possible_token <> 0 { return possible_token; }

    # Consume and ignore line comments; returning the next token
    # following the line comment.
    if lchar == string.ord('#') {
        loop {
            bump();
            if lchar == -1 { break; }
            else if lchar == 0x0A or lchar == 0x0D {
                return get_next_token();
            }
        }
    }

    # No idea what we have; return a poison token.
    printf("error: unknown token: '%c'\n", lchar);
    lchar = libc.getchar();
    return tokens.TOK_ERROR;
}

# println_token -- Print the token representation.
# -----------------------------------------------------------------------------
def println_token(token: int) {
    if token == tokens.TOK_ERROR {
        printf("<error>\n");
    } else if token == tokens.TOK_END {
        printf("<end>\n");
    } else if token == tokens.TOK_LINE {
        printf("<line>\n");
    } else if token <= -1000 and token > -2000 {
        printf("<keyword> '%s'\n", current_buf.data());
    } else if token == tokens.TOK_IDENTIFIER {
        printf("<identifier> '%s'\n", current_id.data());
    } else if token == tokens.TOK_DEC_INTEGER {
        printf("<decimal integer> '%s'\n", current_num.data());
    } else if token == tokens.TOK_BIN_INTEGER {
        printf("<binary integer> '%s'\n", current_num.data());
    } else if token == tokens.TOK_OCT_INTEGER {
        printf("<octal integer> '%s'\n", current_num.data());
    } else if token == tokens.TOK_HEX_INTEGER {
        printf("<hexadecimal integer> '%s'\n", current_num.data());
    } else if token == tokens.TOK_FLOAT {
        printf("<floating-point> '%s'\n", current_num.data());
    } else if token == tokens.TOK_STRING  {
        printf("<string> '%s'\n", cur_str.data());
    } else if token == tokens.TOK_RARROW {
        printf("<punctuator> '->'\n");
    } else if token == tokens.TOK_PLUS {
        printf("<punctuator> '+'\n");
    } else if token == tokens.TOK_MINUS {
        printf("<punctuator> '-'\n");
    } else if token == tokens.TOK_STAR {
        printf("<punctuator> '*'\n");
    } else if token == tokens.TOK_FSLASH {
        printf("<punctuator> '/'\n");
    } else if token == tokens.TOK_PERCENT {
        printf("<punctuator> '%'\n");
    } else if token == tokens.TOK_HAT {
        printf("<punctuator> '^'\n");
    } else if token == tokens.TOK_AMPERSAND {
        printf("<punctuator> '&'\n");
    } else if token == tokens.TOK_LPAREN {
        printf("<punctuator> '('\n");
    } else if token == tokens.TOK_RPAREN {
        printf("<punctuator> ')'\n");
    } else if token == tokens.TOK_LBRACKET {
        printf("<punctuator> '['\n");
    } else if token == tokens.TOK_RBRACKET {
        printf("<punctuator> ']'\n");
    } else if token == tokens.TOK_LBRACE {
        printf("<punctuator> '{'\n");
    } else if token == tokens.TOK_RBRACE {
        printf("<punctuator> '}'\n");
    } else if token == tokens.TOK_SEMICOLON {
        printf("<punctuator> ';'\n");
    } else if token == tokens.TOK_COLON {
        printf("<punctuator> ':'\n");
    } else if token == tokens.TOK_COMMA {
        printf("<punctuator> ','\n");
    } else if token == tokens.TOK_DOT {
        printf("<punctuator> '.'\n");
    } else if token == tokens.TOK_LCARET {
        printf("<punctuator> '<'\n");
    } else if token == tokens.TOK_RCARET {
        printf("<punctuator> '>'\n");
    } else if token == tokens.TOK_LCARET_EQ {
        printf("<punctuator> '<='\n");
    } else if token == tokens.TOK_RCARET_EQ {
        printf("<punctuator> '>='\n");
    } else if token == tokens.TOK_EQ_EQ {
        printf("<punctuator> '=='\n");
    } else if token == tokens.TOK_BANG_EQ {
        printf("<punctuator> '<>'\n");
    } else if token == tokens.TOK_EQ {
        printf("<punctuator> '='\n");
    } else if token == tokens.TOK_PLUS_EQ {
        printf("<punctuator> '+='\n");
    } else if token == tokens.TOK_MINUS_EQ {
        printf("<punctuator> '-='\n");
    } else if token == tokens.TOK_STAR_EQ {
        printf("<punctuator> '*='\n");
    } else if token == tokens.TOK_FSLASH_EQ {
        printf("<punctuator> '/='\n");
    } else if token == tokens.TOK_PERCENT_EQ {
        printf("<punctuator> '%='\n");
    } else if token == tokens.TOK_FSLASH_FSLASH {
        printf("<punctuator> '//'\n");
    } else if token == tokens.TOK_FSLASH_FSLASH_EQ {
        printf("<punctuator> '//='\n");
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
