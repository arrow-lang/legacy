import libc;
import string;
import tokens;
import list;
import types;
import errors;
import span;

# Token
# =============================================================================

type Token {
    #! Tag (identifier) of the token type.
    tag: int,

    #! Span in which the token occurs.
    mut span: span.Span,

    #! Textual content of the token (if the tag indicates it should)
    mut text: string.String
}

let TOKEN_SIZE: uint = ((0 as ^Token) + 1) - (0 as ^Token);

implement Token {

    def dispose(&mut self) {
        # Dispose of contained resources.
        self.span.dispose();
        self.text.dispose();
    }

    def println(&self) {
        # Print location span
        self.span.print();
        printf(": ");

        # Print simple tokens
        if      self.tag == tokens.TOK_END           { printf("end"); }
        else if self.tag == tokens.TOK_ERROR         { printf("error"); }

        # Print numeric tokens
        else if self.tag == tokens.TOK_BIN_INTEGER
        {
            printf("binary integer '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_OCT_INTEGER
        {
            printf("octal integer '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_HEX_INTEGER
        {
            printf("hexadecimal integer '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_DEC_INTEGER
        {
            printf("decimal integer '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_FLOAT
        {
            printf("floating-point '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_STRING
        {
            printf("string '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_IDENTIFIER
        {
            printf("identifier '%s'", self.text.data());
        }
        else if self.tag > -2000 and self.tag < -1000 {
            # TODO: Replace this with a map or something
            printf("keyword: '");
            if self.tag == tokens.TOK_DEF {
                printf("def");
            }
            else if self.tag == tokens.TOK_LET {
                printf("let");
            }
            else if self.tag == tokens.TOK_STATIC {
                printf("static");
            }
            else if self.tag == tokens.TOK_MUT {
                printf("mut");
            }
            else if self.tag == tokens.TOK_TRUE {
                printf("true");
            }
            else if self.tag == tokens.TOK_FALSE {
                printf("false");
            }
            else if self.tag == tokens.TOK_SELF {
                printf("self");
            }
            else if self.tag == tokens.TOK_AS {
                printf("as");
            }
            else if self.tag == tokens.TOK_AND {
                printf("and");
            }
            else if self.tag == tokens.TOK_OR {
                printf("or");
            }
            else if self.tag == tokens.TOK_NOT {
                printf("not");
            }
            else if self.tag == tokens.TOK_IF {
                printf("if");
            }
            else if self.tag == tokens.TOK_ELSE {
                printf("else");
            }
            else if self.tag == tokens.TOK_WHILE {
                printf("while");
            }
            else if self.tag == tokens.TOK_LOOP {
                printf("loop");
            }
            else if self.tag == tokens.TOK_FOR {
                printf("for");
            }
            else if self.tag == tokens.TOK_MATCH {
                printf("match");
            }
            else if self.tag == tokens.TOK_BREAK {
                printf("break");
            }
            else if self.tag == tokens.TOK_CONTINUE {
                printf("continue");
            }
            else if self.tag == tokens.TOK_RETURN {
                printf("return");
            }
            else if self.tag == tokens.TOK_TYPE {
                printf("type");
            }
            else if self.tag == tokens.TOK_ENUM {
                printf("enum");
            }
            else if self.tag == tokens.TOK_MODULE {
                printf("module");
            }
            else if self.tag == tokens.TOK_IMPORT {
                printf("import");
            }
            else if self.tag == tokens.TOK_USE {
                printf("use");
            }
            else if self.tag == tokens.TOK_FOREIGN {
                printf("foreign");
            }
            else if self.tag == tokens.TOK_UNSAFE {
                printf("unsafe");
            }
            else if self.tag == tokens.TOK_GLOBAL {
                printf("global");
            }
            else if self.tag == tokens.TOK_STRUCT {
                printf("struct");
            }
            else if self.tag == tokens.TOK_IMPL {
                printf("impl");
            }
            else if self.tag == tokens.TOK_EXTERN {
                printf("extern");
            }
            printf("'");
        }
        else if self.tag > -3000 and self.tag < -2000 {
            # TODO: Replace this with a map or something
            printf("punctuator: '");
            if self.tag == tokens.TOK_RARROW {
                printf("->");
            } else if self.tag == tokens.TOK_PLUS {
                printf("+");
            } else if self.tag == tokens.TOK_MINUS {
                printf("-");
            } else if self.tag == tokens.TOK_STAR {
                printf("*");
            } else if self.tag == tokens.TOK_FSLASH {
                printf("/");
            } else if self.tag == tokens.TOK_PERCENT {
                printf("%");
            } else if self.tag == tokens.TOK_HAT {
                printf("^");
            } else if self.tag == tokens.TOK_AMPERSAND {
                printf("&");
            } else if self.tag == tokens.TOK_LPAREN {
                printf("(");
            } else if self.tag == tokens.TOK_RPAREN {
                printf(")");
            } else if self.tag == tokens.TOK_LBRACKET {
                printf("[");
            } else if self.tag == tokens.TOK_RBRACKET {
                printf("]");
            } else if self.tag == tokens.TOK_LBRACE {
                printf("{");
            } else if self.tag == tokens.TOK_RBRACE {
                printf("}");
            } else if self.tag == tokens.TOK_SEMICOLON {
                printf(";");
            } else if self.tag == tokens.TOK_COLON {
                printf(":");
            } else if self.tag == tokens.TOK_COMMA {
                printf(",");
            } else if self.tag == tokens.TOK_DOT {
                printf(".");
            } else if self.tag == tokens.TOK_LCARET {
                printf("<");
            } else if self.tag == tokens.TOK_RCARET {
                printf(">");
            } else if self.tag == tokens.TOK_LCARET_EQ {
                printf("<=");
            } else if self.tag == tokens.TOK_RCARET_EQ {
                printf(">=");
            } else if self.tag == tokens.TOK_EQ_EQ {
                printf("==");
            } else if self.tag == tokens.TOK_BANG_EQ {
                printf("!=");
            } else if self.tag == tokens.TOK_EQ {
                printf("=");
            } else if self.tag == tokens.TOK_PLUS_EQ {
                printf("+=");
            } else if self.tag == tokens.TOK_MINUS_EQ {
                printf("-=");
            } else if self.tag == tokens.TOK_STAR_EQ {
                printf("*=");
            } else if self.tag == tokens.TOK_FSLASH_EQ {
                printf("/=");
            } else if self.tag == tokens.TOK_PERCENT_EQ {
                printf("%=");
            } else if self.tag == tokens.TOK_FSLASH_FSLASH {
                printf("//");
            } else if self.tag == tokens.TOK_FSLASH_FSLASH_EQ {
                printf("//=");
            } else if self.tag == tokens.TOK_BANG {
                printf("!");
            } else if self.tag == tokens.TOK_PIPE {
                printf("|");
            } else if self.tag == tokens.TOK_RFARROW {
                printf("=>");
            }
            printf("'");
        }

        # Terminate with a newline
        printf("\n");
    }

}

# FIXME: Move to an "attached" function when possible.
def token_new(tag: int, span_: span.Span, text: str) -> Token {
    let tok: Token;
    tok.tag = tag;
    tok.span = span_;
    tok.text = string.make();
    tok.text.extend(text);
    return tok;
}

# Tokenizer
# =============================================================================

type Tokenizer {
    #! Filename that the stream is from.
    filename: str,

    #! Input stream to read the characters from.
    stream: ^libc._IO_FILE,

    #! Input buffer for the incoming character stream.
    mut chars: list.List,

    #! Text buffer for constructing tokens.
    mut buffer: string.String,

    #! Current row offset in the stream.
    mut row: int,

    #! Current column offset in the stream.
    mut column: int
}

# FIXME: Move to an "attached" function when possible.
def tokenizer_new(filename: str, stream: ^libc._IO_FILE) -> Tokenizer {
    let tokenizer: Tokenizer;
    tokenizer.filename = filename;
    tokenizer.stream = stream;
    tokenizer.chars = list.make(types.CHAR);
    tokenizer.buffer = string.make();
    tokenizer.row = 0;
    tokenizer.column = 0;
    return tokenizer;
}

implement Tokenizer {

    def dispose(&mut self) {
        # Dispose of contained resources.
        # libc.fclose(self.stream);
        self.chars.dispose();
        self.buffer.dispose();
    }

    def current_position(&self) -> span.Position {
        return span.position_new(self.column, self.row);
    }

    def push_chars(&mut self, count: uint) {
        let mut n: uint = count;
        while n > 0 {
            # Attempt to read the next character from the input stream.
            let next: int8;
            let read: int64 = libc.fread(&next as ^void, 1, 1, self.stream);
            if read == 0 {
                # Nothing was read; push an EOF.
                self.chars.push_char(-1 as char);
            } else {
                # Push the character read.
                self.chars.push_char(next as char);
            }

            # Increment our count.
            n = n - 1;
        }
    }

    def peek_char(&mut self, count: uint) -> char {
        # Request more characters if we need them.
        if count > self.chars.size {
            self.push_chars(count - self.chars.size);
        }

        # Return the requested token.
        self.chars.at_char((count as int) - (self.chars.size as int) - 1);
    }

    def pop_char(&mut self) -> char {
        # Get the requested char.
        let ch: char = self.peek_char(1);

        # Erase the top char.
        self.chars.erase(0);

        # Increment the current position in the stream.
        # Normalize line ending styles.
        self.column = self.column + 1;
        if ch == "\n"
        {
            # UNIX
            self.column = 0;
            self.row = self.row + 1;
        }
        else if ch == "\r" and self.peek_char(1) == "\n"
        {
            # WINDOWS
            ch = "\n";
            self.chars.erase(0);
            self.column = 0;
            self.row = self.row + 1;
        }
        else if ch == "\r"
        {
            # MAC
            ch = "\n";
            self.column = 0;
            self.row = self.row + 1;
        }

        # Return the erased char.
        ch;
    }

    def consume_whitespace(&mut self) {
        while is_whitespace(self.peek_char(1)) {
            self.pop_char();
        }
    }

    def next(&mut self) -> Token {
        # Skip and consume any whitespace characters.
        self.consume_whitespace();

        # Check if we've reached the end of the stream ...
        if self.peek_char(1) == -1 {
            # ... and return the <end> token.
            let pos: span.Position = self.current_position();
            self.pop_char();
            return token_new(
                tokens.TOK_END,
                span.span_new(
                    self.filename,
                    pos,
                    self.current_position()), "");
        }

        # Check for a leading digit that would indicate the start of a
        # numeric token.
        if is_numeric(self.peek_char(1)) {
            # Scan for and match the numeric token.
            return self.scan_numeric();
        }

        # Check for and consume a string token.
        if self.peek_char(1) == "'" or self.peek_char(1) == '"' {
            # Scan the entire string token.
            return self.scan_string();
        }

        # Consume and ignore line comments; returning the next token
        # following the line comment.
        if self.peek_char(1) == "#" {
            loop {
                # Pop (and the drop) the next character.
                self.pop_char();

                # Check if the single-line comment is done.
                let ch: char = self.peek_char(1);
                if ch == -1 or ch == "\r" or ch == "\n" {
                    return self.next();
                }
            }
        }

        # Check for and attempt to consume punctuators (eg. "+").
        let possible_token: Token = self.scan_punctuator();
        if possible_token.tag <> 0 { return possible_token; }

        # Check for an alphabetic or '_' character which signals the beginning
        # of an identifier.
        let ch: char = self.peek_char(1);
        if is_alphabetic(ch) or ch == "_" {
            # Scan for and match the identifier
            return self.scan_identifier();
        }

        # No idea what we have; print an error.
        let pos: span.Position = self.current_position();
        let ch: char = self.pop_char();
        let sp: span.Span = span.span_new(
            self.filename, pos, self.current_position());
        errors.begin_error_at(sp);
        errors.libc.fprintf(errors.libc.stderr,
                            "unknown token: `%c`" as ^int8, ch);
        errors.end();

        # Return the error token.
        return token_new(tokens.TOK_ERROR, sp, "");
    }

    # scan_numeric -- Scan for and produce a numeric token.
    # -------------------------------------------------------------------------
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
    # -------------------------------------------------------------------------
    def scan_numeric(&mut self) -> Token
    {
        # Declare a local var to store the tag.
        let tag: int = 0;

        # Remember the current position.
        let pos: span.Position = self.current_position();

        # Clear the current buffer.
        self.buffer.clear();

        # Check for a possible base-prefixed numeric.
        # If we are currently a zero ...
        if self.peek_char(1) == "0"
        {
            # ... peek ahead and determine if we -are- a base-prefixed
            #   numeric.
            let ch: char = self.peek_char(2);
            let nch: char = self.peek_char(3);
            tag =
                if (ch == "b" or ch == "B") and in_range(nch, "0", "1")
                {
                    tokens.TOK_BIN_INTEGER;
                }
                else if (ch == "x" or ch == "X")
                    and libc.isxdigit(nch as int32) <> 0
                {
                    tokens.TOK_HEX_INTEGER;
                }
                else if (ch == "o" or ch == "O") and in_range(nch, "0", "7")
                {
                    tokens.TOK_OCT_INTEGER;
                }
                else
                {
                    # Not a base-prefixed integer.
                    0;
                };

            if tag <> 0
            {
                # Pop the base-prefix.
                self.pop_char();
                self.pop_char();

                # Continue according to -which- base-prefixed numeric we are.
                # TODO: Once we can do something like partializing a function
                #   we could replace the three loops with one.
                if tag == tokens.TOK_BIN_INTEGER
                {
                    loop
                    {
                        let ch: char = self.peek_char(1);
                        if in_range(ch, "0", "1")
                        {
                            self.buffer.append(ch);
                        }
                        else if ch <> "_"
                        {
                            break;
                        }
                        self.pop_char();
                    }
                }
                else if tag == tokens.TOK_OCT_INTEGER
                {
                    loop
                    {
                        let ch: char = self.peek_char(1);
                        if in_range(ch, "0", "7")
                        {
                            self.buffer.append(ch);
                        }
                        else if ch <> "_"
                        {
                            break;
                        }
                        self.pop_char();
                    }
                }
                else if tag == tokens.TOK_HEX_INTEGER
                {
                    loop
                    {
                        let ch: char = self.peek_char(1);
                        if libc.isxdigit(ch as int32) <> 0
                        {
                            self.buffer.append(ch);
                        }
                        else if ch <> "_"
                        {
                            break;
                        }
                        self.pop_char();
                    }
                }

                # Build and return our base-prefixed numeric token.
                return token_new(
                    tag,
                    span.span_new(self.filename, pos, self.current_position()),
                    self.buffer.data() as str);
            }
        }

        # We could be a deicmal or floating numeric at this point.
        tag = tokens.TOK_DEC_INTEGER;

        # Scan for the remainder of the integral part of the numeric.
        loop {
            let ch: char = self.peek_char(1);
            if is_numeric(ch) {
                self.buffer.append(ch);
            } else if ch <> "_" {
                break;
            }
            self.pop_char();
        }

        # Check for a period followed by a numeric (which would indicate
        # that we are a floating numeric)
        if self.peek_char(1) == "." and is_numeric(self.peek_char(2))
        {
            # We are now a floating numeric.
            tag = tokens.TOK_FLOAT;

            # Push the period and bump to the next token.
            self.buffer.append(self.pop_char());

            # Scan the fractional part of the numeric.
            loop {
                let ch: char = self.peek_char(1);
                if is_numeric(ch) {
                    self.buffer.append(ch);
                } else if ch <> "_" {
                    break;
                }
                self.pop_char();
            }
        }

        # Check for a an "e" or "E" character that would indicate
        # an exponent portion
        if (self.peek_char(1) == "e" or self.peek_char(1) == "E")
            and (is_numeric(self.peek_char(2))
                or self.peek_char(2) == "+"
                or self.peek_char(2) == "-")
        {
            # We are now a floating numeric.
            tag = tokens.TOK_FLOAT;

            # Push the `e` and the next character.
            self.buffer.append(self.pop_char());
            self.buffer.append(self.pop_char());

            # Scan the fractional part of the numeric.
            loop {
                let ch: char = self.peek_char(1);
                if is_numeric(ch) {
                    self.buffer.append(ch);
                } else if ch <> "_" {
                    break;
                }
                self.pop_char();
            }
        }

        # Build and return our numeric.
        return token_new(
            tag, span.span_new(self.filename, pos, self.current_position()),
            self.buffer.data() as str);
    }

    # scan_identifier -- Scan for and match an identifier or keyword.
    # -------------------------------------------------------------------------
    # identifier = [A-Za-z_][A-Za-z_0-9]*
    # -------------------------------------------------------------------------
    def scan_identifier(&mut self) -> Token {
        # Remember the current position.
        let pos: span.Position = self.current_position();

        # Clear the buffer.
        self.buffer.clear();

        # Continue through the input stream until we are no longer part
        # of a possible identifier.
        loop {
            self.buffer.append(self.pop_char());
            if not is_alphanumeric(self.peek_char(1)) and
                    not self.peek_char(1) == "_" {
                break;
            }
        }

        # Check for and return keyword tokens instead of the identifier.
        # TODO: A hash-table would better serve this.
        let tag: int = 0;
             if self.buffer.eq_str("def")       { tag = tokens.TOK_DEF; }
        else if self.buffer.eq_str("let")       { tag = tokens.TOK_LET; }
        else if self.buffer.eq_str("static")    { tag = tokens.TOK_STATIC; }
        else if self.buffer.eq_str("mut")       { tag = tokens.TOK_MUT; }
        else if self.buffer.eq_str("true")      { tag = tokens.TOK_TRUE; }
        else if self.buffer.eq_str("false")     { tag = tokens.TOK_FALSE; }
        else if self.buffer.eq_str("self")      { tag = tokens.TOK_SELF; }
        else if self.buffer.eq_str("as")        { tag = tokens.TOK_AS; }
        else if self.buffer.eq_str("and")       { tag = tokens.TOK_AND; }
        else if self.buffer.eq_str("or")        { tag = tokens.TOK_OR; }
        else if self.buffer.eq_str("not")       { tag = tokens.TOK_NOT; }
        else if self.buffer.eq_str("if")        { tag = tokens.TOK_IF; }
        else if self.buffer.eq_str("else")      { tag = tokens.TOK_ELSE; }
        else if self.buffer.eq_str("for")       { tag = tokens.TOK_FOR; }
        else if self.buffer.eq_str("while")     { tag = tokens.TOK_WHILE; }
        else if self.buffer.eq_str("loop")      { tag = tokens.TOK_LOOP; }
        else if self.buffer.eq_str("match")     { tag = tokens.TOK_MATCH; }
        else if self.buffer.eq_str("break")     { tag = tokens.TOK_BREAK; }
        else if self.buffer.eq_str("continue")  { tag = tokens.TOK_CONTINUE; }
        else if self.buffer.eq_str("return")    { tag = tokens.TOK_RETURN; }
        else if self.buffer.eq_str("type")      { tag = tokens.TOK_TYPE; }
        else if self.buffer.eq_str("enum")      { tag = tokens.TOK_ENUM; }
        else if self.buffer.eq_str("module")    { tag = tokens.TOK_MODULE; }
        else if self.buffer.eq_str("import")    { tag = tokens.TOK_IMPORT; }
        else if self.buffer.eq_str("use")       { tag = tokens.TOK_USE; }
        else if self.buffer.eq_str("foreign")   { tag = tokens.TOK_FOREIGN; }
        else if self.buffer.eq_str("unsafe")    { tag = tokens.TOK_UNSAFE; }
        else if self.buffer.eq_str("global")    { tag = tokens.TOK_GLOBAL; }
        else if self.buffer.eq_str("struct")    { tag = tokens.TOK_STRUCT; }
        else if self.buffer.eq_str("implement") { tag = tokens.TOK_IMPL; }
        else if self.buffer.eq_str("extern")    { tag = tokens.TOK_EXTERN; }


        # Return the token.
        if tag == 0 {
            # Scanned identifier does not match any defined keyword.
            # Update the current_id.
            token_new(
                tokens.TOK_IDENTIFIER,
                span.span_new(self.filename, pos, self.current_position()),
                self.buffer.data() as str);
        } else {
            # Return the keyword token.
            token_new(
                tag,
                span.span_new(self.filename, pos, self.current_position()),
                "");
        }
    }

    # scan_punctuator -- Scan for and match a punctuator token.
    # -------------------------------------------------------------------------
    def scan_punctuator(&mut self) -> Token {
        # TODO: This scanning could probably be replaced by something
        #   creative in a declarative manner.

        # First attempt to match those that are unambigious in that
        # if the current character matches it is the token.
        let pos: span.Position = self.current_position();
        let ch: char = self.peek_char(1);
        let tag: int = 0;
        if      ch == "(" { tag = tokens.TOK_LPAREN; }
        else if ch == ")" { tag = tokens.TOK_RPAREN; }
        else if ch == "[" { tag = tokens.TOK_LBRACKET; }
        else if ch == "]" { tag = tokens.TOK_RBRACKET; }
        else if ch == "{" { tag = tokens.TOK_LBRACE; }
        else if ch == "}" { tag = tokens.TOK_RBRACE; }
        else if ch == ";" { tag = tokens.TOK_SEMICOLON; }
        else if ch == "," { tag = tokens.TOK_COMMA; }
        else if ch == "." { tag = tokens.TOK_DOT; }
        else if ch == "^" { tag = tokens.TOK_HAT; }
        else if ch == "&" { tag = tokens.TOK_AMPERSAND; }
        else if ch == "|" { tag = tokens.TOK_PIPE; }
        else if ch == ":" { tag = tokens.TOK_COLON; }

        # If we still need to continue ...
        if tag <> 0 { self.pop_char(); }
        else
        {
            # Start looking forward and attempt to disambiguate the
            # following punctuators.
            if ch == "+" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_PLUS_EQ;
                } else {
                    tag = tokens.TOK_PLUS;
                }
            } else if ch == "-" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_MINUS_EQ;
                } else if self.peek_char(1) == ">" {
                    self.pop_char();
                    tag = tokens.TOK_RARROW;
                } else {
                    tag = tokens.TOK_MINUS;
                }
            } else if ch == "*" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_STAR_EQ;
                } else {
                    tag = tokens.TOK_STAR;
                }
            } else if ch == "/" {
                self.pop_char();
                if self.peek_char(1) == "/" {
                    self.pop_char();
                    if self.peek_char(1) == "=" {
                        self.pop_char();
                        tag = tokens.TOK_FSLASH_FSLASH_EQ;
                    } else {
                        tag = tokens.TOK_FSLASH_FSLASH;
                    }
                } else if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_FSLASH_EQ;
                } else {
                    tag = tokens.TOK_FSLASH;
                }
            } else if ch == "%" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_PERCENT_EQ;
                } else {
                    tag = tokens.TOK_PERCENT;
                }
            } else if ch == "<" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_LCARET_EQ;
                } else {
                    tag = tokens.TOK_LCARET;
                }
            } else if ch == ">" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_RCARET_EQ;
                } else {
                    tag = tokens.TOK_RCARET;
                }
            } else if ch == "=" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_EQ_EQ;
                } else if self.peek_char(1) == ">" {
                    self.pop_char();
                    tag = tokens.TOK_RFARROW;
                } else {
                    tag = tokens.TOK_EQ;
                }
            } else if ch == "!" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_BANG_EQ;
                } else {
                    tag = tokens.TOK_BANG;
                }
            }
        }

        # If we matched a token, return it; else, return nil.
        if tag <> 0 {
            token_new(
                tag,
                span.span_new(self.filename, pos, self.current_position()),
                "");
        } else {
            token_new(0, span.span_null(), "");
        }
    }

    # scan_string -- Scan for and produce a string token.
    # -------------------------------------------------------------------------
    # xdigit = [0-9a-fa-F]
    # str = \'([^'\\]|\\[#'"\\abfnrtv0]|\\[xX]{xdigit}{2})*\'
    #     | \"([^"\\]|\\[#'"\\abfnrtv0]|\\[xX]{xdigit}{2})*\"
    # -------------------------------------------------------------------------
    def scan_string(&mut self) -> Token {
        # Remember the current position.
        let pos: span.Position = self.current_position();

        # What kind of string are we dealing with here; we're either
        # single-quoted or double-quoted.
        let current_tok: int = tokens.TOK_STRING;
        let quotes: int =
            if self.peek_char(1) == '"' {
                2;
            } else {
                1;
            };

        # Bump past the quote character.
        self.pop_char();

        # Clear the string buffer.
        self.buffer.clear();

        # Loop and consume the string token.
        let in_escape: bool = false;
        let in_byte_escape: bool = false;
        loop {
            if in_escape {
                # Bump the character onto the buffer.
                self.buffer.append(self.pop_char());

                # Check if we have an extension control character.
                if self.peek_char(1) == 'x' or self.peek_char(1) == 'X' {
                    in_byte_escape = true;
                }

                # No longer in an escape sequence.
                in_escape = false;
            } else if in_byte_escape {
                # Bump two characters.
                self.buffer.append(self.pop_char());
                self.buffer.append(self.pop_char());

                # No longer in a byte-escape sequence.
                in_byte_escape = false;
            } else {
                if self.peek_char(1) == '\\' {
                    # Mark that we're now in an escape sequence.
                    in_escape = true;

                    # Bump the character onto the buffer.
                    self.buffer.append(self.pop_char());
                } else if (quotes == 1 and self.peek_char(1) == "'") or
                          (quotes == 2 and self.peek_char(1) == '"') {
                    # Found the closing quote; we're done.
                    self.pop_char();
                    break;
                } else {
                    # Bump the character onto the buffer.
                    self.buffer.append(self.pop_char());
                }
            }
        }

        # Matched the string token.
        return token_new(
            tokens.TOK_STRING,
            span.span_new(self.filename, pos, self.current_position()),
            self.buffer.data() as str);
    }
}

# Helpers
# =============================================================================

# is_whitespace -- Test if the passed character constitutes whitespace.
# -----------------------------------------------------------------------------
def is_whitespace(c: char) -> bool {
    c == ' ' or c == '\n' or c == '\t' or c == '\r';
}

# is_numeric -- Test if the passed character is numeric.
# -----------------------------------------------------------------------------
def is_numeric(c: char) -> bool {
    libc.isdigit(c as int32) <> 0;
}

# Test if the char is in the passed range.
# -----------------------------------------------------------------------------
def in_range(c: char, s: char, e: char) -> bool {
    (c as int8) >= (s as int8) and (c as int8) <= (e as int8);
}

# is_alphabetic -- Test if the passed character is alphabetic.
# -----------------------------------------------------------------------------
def is_alphabetic(c: char) -> bool {
    libc.isalpha(c as int32) <> 0;
}

# is_alphanumeric -- Test if the passed character is alphanumeric.
# -----------------------------------------------------------------------------
def is_alphanumeric(c: char) -> bool {
    libc.isalnum(c as int32) <> 0;
}

# Driver (Test)
# =============================================================================

def main() {
    # Construct a new tokenizer.
    let mut tokenizer: Tokenizer = tokenizer_new("-", libc.stdin);

    # Iterate through each token in the input stream.
    loop {
        # Get the next token
        let mut tok: Token = tokenizer.next();

        # Print token if we're error-free
        if errors.count == 0 {
            tok.println();
        }

        # Stop if we reach the end.
        if tok.tag == tokens.TOK_END { break; }

        # Dispose of the token.
        tok.dispose();
    }

    # Dispose of the tokenizer.
    tokenizer.dispose();

    # Return to the environment.
    libc.exit(0 if errors.count == 0 else -1);
}
