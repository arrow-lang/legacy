import libc;
import string;
import tokens;
import list;
import types;
import errors;
import span;

# Token
# =============================================================================

struct Token {
    #! Tag (identifier) of the token type.
    tag: int,

    #! Span in which the token occurs.
    span: span.Span,

    #! Textual content of the token (if the tag indicates it should)
    text: string.String
}

implement Token {

    let new(tag: int, span: span.Span, text: str): Token -> {
        return Token(tag, span.clone(), string.String.from_str(text));
    }

    let dispose(mut self) -> {
        # Dispose of contained resources.
        self.span.dispose();
        self.text.dispose();
    }

    let println(self) -> {
        self.fprintln(libc.stdout);
    }

    let fprintln(self, stream: *libc.FILE) -> {
        # Print location span
        self.span.fprint(stream);
        libc.fprintf(stream, ": ");

        # Print simple tokens
        if      self.tag == tokens.TOK_END      { libc.fprintf(stream, "end"); }
        else if self.tag == tokens.TOK_ERROR    { libc.fprintf(stream, "error"); }

        # Print numeric tokens
        else if self.tag == tokens.TOK_BIN_INTEGER
        {
            libc.fprintf(stream, "binary integer '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_OCT_INTEGER
        {
            libc.fprintf(stream, "octal integer '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_HEX_INTEGER
        {
            libc.fprintf(stream, "hexadecimal integer '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_DEC_INTEGER
        {
            libc.fprintf(stream, "decimal integer '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_FLOAT
        {
            libc.fprintf(stream, "floating-point '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_STRING
        {
            libc.fprintf(stream, "string '%s'", self.text.data());
        }
        else if self.tag == tokens.TOK_IDENTIFIER
        {
            libc.fprintf(stream, "identifier '%s'", self.text.data());
        }
        else if self.tag > -2000 and self.tag < -1000 {
            # TODO: Replace this with a map or something
            libc.fprintf(stream, "keyword: '");
            if self.tag == tokens.TOK_LET {
                libc.fprintf(stream, "let");
            }
            else if self.tag == tokens.TOK_STATIC {
                libc.fprintf(stream, "static");
            }
            else if self.tag == tokens.TOK_MUT {
                libc.fprintf(stream, "mut");
            }
            else if self.tag == tokens.TOK_TRUE {
                libc.fprintf(stream, "true");
            }
            else if self.tag == tokens.TOK_FALSE {
                libc.fprintf(stream, "false");
            }
            else if self.tag == tokens.TOK_SELF {
                libc.fprintf(stream, "self");
            }
            else if self.tag == tokens.TOK_AS {
                libc.fprintf(stream, "as");
            }
            else if self.tag == tokens.TOK_AND {
                libc.fprintf(stream, "and");
            }
            else if self.tag == tokens.TOK_OR {
                libc.fprintf(stream, "or");
            }
            else if self.tag == tokens.TOK_NOT {
                libc.fprintf(stream, "not");
            }
            else if self.tag == tokens.TOK_IF {
                libc.fprintf(stream, "if");
            }
            else if self.tag == tokens.TOK_ELSE {
                libc.fprintf(stream, "else");
            }
            else if self.tag == tokens.TOK_WHILE {
                libc.fprintf(stream, "while");
            }
            else if self.tag == tokens.TOK_LOOP {
                libc.fprintf(stream, "loop");
            }
            else if self.tag == tokens.TOK_FOR {
                libc.fprintf(stream, "for");
            }
            else if self.tag == tokens.TOK_MATCH {
                libc.fprintf(stream, "match");
            }
            else if self.tag == tokens.TOK_BREAK {
                libc.fprintf(stream, "break");
            }
            else if self.tag == tokens.TOK_CONTINUE {
                libc.fprintf(stream, "continue");
            }
            else if self.tag == tokens.TOK_RETURN {
                libc.fprintf(stream, "return");
            }
            else if self.tag == tokens.TOK_TYPE {
                libc.fprintf(stream, "type");
            }
            else if self.tag == tokens.TOK_ENUM {
                libc.fprintf(stream, "enum");
            }
            else if self.tag == tokens.TOK_MODULE {
                libc.fprintf(stream, "module");
            }
            else if self.tag == tokens.TOK_IMPORT {
                libc.fprintf(stream, "import");
            }
            else if self.tag == tokens.TOK_USE {
                libc.fprintf(stream, "use");
            }
            else if self.tag == tokens.TOK_FOREIGN {
                libc.fprintf(stream, "foreign");
            }
            else if self.tag == tokens.TOK_UNSAFE {
                libc.fprintf(stream, "unsafe");
            }
            else if self.tag == tokens.TOK_GLOBAL {
                libc.fprintf(stream, "global");
            }
            else if self.tag == tokens.TOK_STRUCT {
                libc.fprintf(stream, "struct");
            }
            else if self.tag == tokens.TOK_IMPL {
                libc.fprintf(stream, "impl");
            }
            else if self.tag == tokens.TOK_EXTERN {
                libc.fprintf(stream, "extern");
            }
            else if self.tag == tokens.TOK_DELEGATE {
                libc.fprintf(stream, "delegate");
            }
            else if self.tag == tokens.TOK_SIZEOF {
                libc.fprintf(stream, "sizeof");
            };
            libc.fprintf(stream, "'");
        }
        else if self.tag > -3000 and self.tag < -2000 {
            # TODO: Replace this with a map or something
            libc.fprintf(stream, "punctuator: '");
            if self.tag == tokens.TOK_RARROW {
                libc.fprintf(stream, "->");
            } else if self.tag == tokens.TOK_PLUS {
                libc.fprintf(stream, "+");
            } else if self.tag == tokens.TOK_MINUS {
                libc.fprintf(stream, "-");
            } else if self.tag == tokens.TOK_STAR {
                libc.fprintf(stream, "*");
            } else if self.tag == tokens.TOK_FSLASH {
                libc.fprintf(stream, "/");
            } else if self.tag == tokens.TOK_PERCENT {
                libc.fprintf(stream, "%%");
            } else if self.tag == tokens.TOK_HAT {
                libc.fprintf(stream, "^");
            } else if self.tag == tokens.TOK_AMPERSAND {
                libc.fprintf(stream, "&");
            } else if self.tag == tokens.TOK_LPAREN {
                libc.fprintf(stream, "(");
            } else if self.tag == tokens.TOK_RPAREN {
                libc.fprintf(stream, ")");
            } else if self.tag == tokens.TOK_LBRACKET {
                libc.fprintf(stream, "[");
            } else if self.tag == tokens.TOK_RBRACKET {
                libc.fprintf(stream, "]");
            } else if self.tag == tokens.TOK_LBRACE {
                libc.fprintf(stream, "{");
            } else if self.tag == tokens.TOK_RBRACE {
                libc.fprintf(stream, "}");
            } else if self.tag == tokens.TOK_SEMICOLON {
                libc.fprintf(stream, ";");
            } else if self.tag == tokens.TOK_COLON {
                libc.fprintf(stream, ":");
            } else if self.tag == tokens.TOK_COMMA {
                libc.fprintf(stream, ",");
            } else if self.tag == tokens.TOK_DOT {
                libc.fprintf(stream, ".");
            } else if self.tag == tokens.TOK_LCARET {
                libc.fprintf(stream, "<");
            } else if self.tag == tokens.TOK_RCARET {
                libc.fprintf(stream, ">");
            } else if self.tag == tokens.TOK_LCARET_EQ {
                libc.fprintf(stream, "<=");
            } else if self.tag == tokens.TOK_RCARET_EQ {
                libc.fprintf(stream, ">=");
            } else if self.tag == tokens.TOK_EQ_EQ {
                libc.fprintf(stream, "==");
            } else if self.tag == tokens.TOK_BANG_EQ {
                libc.fprintf(stream, "!=");
            } else if self.tag == tokens.TOK_EQ {
                libc.fprintf(stream, "=");
            } else if self.tag == tokens.TOK_PLUS_EQ {
                libc.fprintf(stream, "+=");
            } else if self.tag == tokens.TOK_MINUS_EQ {
                libc.fprintf(stream, "-=");
            } else if self.tag == tokens.TOK_STAR_EQ {
                libc.fprintf(stream, "*=");
            } else if self.tag == tokens.TOK_FSLASH_EQ {
                libc.fprintf(stream, "/=");
            } else if self.tag == tokens.TOK_PERCENT_EQ {
                libc.fprintf(stream, "%=");
            } else if self.tag == tokens.TOK_FSLASH_FSLASH {
                libc.fprintf(stream, "//");
            } else if self.tag == tokens.TOK_FSLASH_FSLASH_EQ {
                libc.fprintf(stream, "//=");
            } else if self.tag == tokens.TOK_BANG {
                libc.fprintf(stream, "!");
            } else if self.tag == tokens.TOK_ELLIPSIS {
                libc.fprintf(stream, "...");
            } else if self.tag == tokens.TOK_PIPE {
                libc.fprintf(stream, "|");
            } else if self.tag == tokens.TOK_RFARROW {
                libc.fprintf(stream, "=>");
            };
            libc.fprintf(stream, "'");
        };

        # Terminate with a newline
        libc.fprintf(stream, "\n");
    }

}

# Tokenizer
# =============================================================================

struct Tokenizer {
    #! Filename that the stream is from.
    filename: str,

    #! Input stream to read the characters from.
    stream: *libc.FILE,

    #! Input buffer for the incoming character stream.
    chars: list.List,

    #! Text buffer for constructing tokens.
    buffer: string.String,

    #! Current row offset in the stream.
    row: int,

    #! Current column offset in the stream.
    column: int
}

implement Tokenizer {

    let new(filename: str, stream: *libc.FILE): Tokenizer -> {
        return Tokenizer(filename: filename, stream: stream,
                         chars: list.List.new(types.CHAR),
                         buffer: string.String.new(),
                         row: 0,
                         column: 0);
    }

    let shallow_clone(self): Tokenizer -> {
        return Tokenizer(filename: self.filename,
                         stream: self.stream,
                         chars: self.chars,
                         buffer: self.buffer,
                         row: self.row,
                         column: self.column);
    }

    let dispose(mut self) -> {
        # Dispose of contained resources.
        # FIXME: Need to close the file if this is not `stdin`
        # libc.fclose(self.stream);
        self.chars.dispose();
        self.buffer.dispose();
    }

    let current_position(self): span.Position -> {
        return span.Position(self.column, self.row);
    }

    let push_chars(mut self, count: uint) -> {
        let mut n: uint = count;
        while n > 0 {
            # Attempt to read the next character from the input stream.
            let next: int8;
            let read = libc.fread(&next, 1, 1, self.stream);
            if read == 0 {
                # Nothing was read; push an EOF.
                self.chars.push_char(-1 as char);
            } else {
                # Push the character read.
                self.chars.push_char(next as char);
            };

            # Increment our count.
            n = n - 1;
        }
    }

    let peek_char(mut self, count: uint): char -> {
        # Request more characters if we need them.
        if count > self.chars.size {
            self.push_chars(count - self.chars.size);
        };

        # Return the requested token.
        self.chars.get_char((count as int) - (self.chars.size as int) - 1);
    }

    let pop_char(mut self): char -> {
        # Get the requested char.
        let mut ch: char = self.peek_char(1);

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
            ch = ("\n" as char);
            self.chars.erase(0);
            self.column = 0;
            self.row = self.row + 1;
        }
        else if ch == "\r"
        {
            # MAC
            ch = ("\n" as char);
            self.column = 0;
            self.row = self.row + 1;
        };

        # Return the erased char.
        ch;
    }

    let consume_whitespace(mut self) -> {
        while is_whitespace(self.peek_char(1)) {
            self.pop_char();
        }
    }

    let next(mut self): Token -> {
        # Skip and consume any whitespace characters.
        self.consume_whitespace();

        # Check if we've reached the end of the stream ...
        if self.peek_char(1) == -1 as char {
            # ... and return the <end> token.
            let pos = self.current_position();
            self.pop_char();
            return Token.new(
                tokens.TOK_END,
                span.Span.new(
                    self.filename,
                    pos,
                    self.current_position()), "");
        };

        # Check for a leading digit that would indicate the start of a
        # numeric token.
        if is_numeric(self.peek_char(1)) {
            # Scan for and match the numeric token.
            return self.scan_numeric();
        };

        # Check for and consume a string token.
        if self.peek_char(1) == "'" or self.peek_char(1) == '"' {
            # Scan the entire string token.
            return self.scan_string();
        };

        # Consume and ignore line comments; returning the next token
        # following the line comment.
        if self.peek_char(1) == "#" {
            loop {
                # Pop (and the drop) the next character.
                self.pop_char();

                # Check if the single-line comment is done.
                let ch: char = self.peek_char(1);
                if ch == (-1 as char) or ch == "\r" or ch == "\n" {
                    return self.next();
                };
            }
        };

        # Check for and attempt to consume punctuators (eg. "+").
        let possible_token: Token = self.scan_punctuator();
        if possible_token.tag != 0 { return possible_token; };

        # Check for an alphabetic or '_' character which signals the beginning
        # of an identifier.
        let ch: char = self.peek_char(1);
        if is_alphabetic(ch) or ch == "_" {
            # Scan for and match the identifier
            return self.scan_identifier();
        };

        # No idea what we have; print an error.
        let pos: span.Position = self.current_position();
        let ch: char = self.pop_char();
        let sp: span.Span = span.Span.new(
            self.filename, pos, self.current_position());
        errors.begin_error_at(sp);
        errors.libc.fprintf(errors.libc.stderr,
                            "unknown token: `%c`", ch);
        errors.end();

        # Return the error token.
        return Token.new(tokens.TOK_ERROR, sp, "");
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
    let scan_numeric(mut self): Token -> {
        # Declare a local var to store the tag.
        let mut tag: int = 0;

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
                    and libc.isxdigit(nch as int32) != 0
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

            if tag != 0
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
                        else if ch != "_"
                        {
                            break;
                        };
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
                        else if ch != "_"
                        {
                            break;
                        };
                        self.pop_char();
                    }
                }
                else if tag == tokens.TOK_HEX_INTEGER
                {
                    loop
                    {
                        let ch: char = self.peek_char(1);
                        if libc.isxdigit(ch as int32) != 0
                        {
                            self.buffer.append(ch);
                        }
                        else if ch != "_"
                        {
                            break;
                        };
                        self.pop_char();
                    }
                };

                # Build and return our base-prefixed numeric token.
                return Token.new(
                    tag,
                    span.Span.new(self.filename, pos, self.current_position()),
                    self.buffer.data() as str);
            };
        };

        # We could be a deicmal or floating numeric at this point.
        tag = tokens.TOK_DEC_INTEGER;

        # Scan for the remainder of the integral part of the numeric.
        loop {
            let ch: char = self.peek_char(1);
            if is_numeric(ch) {
                self.buffer.append(ch);
            } else if ch != "_" {
                break;
            };
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
                } else if ch != "_" {
                    break;
                };
                self.pop_char();
            }
        };

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
                } else if ch != "_" {
                    break;
                };
                self.pop_char();
            }
        };

        # Build and return our numeric.
        return Token.new(
            tag, span.Span.new(self.filename, pos, self.current_position()),
            self.buffer.data() as str);
    }

    # scan_identifier -- Scan for and match an identifier or keyword.
    # -------------------------------------------------------------------------
    # identifier = [A-Za-z_][A-Za-z_0-9]*
    # -------------------------------------------------------------------------
    let scan_identifier(mut self): Token -> {
        # Remember the current position.
        let pos: span.Position = self.current_position();

        # Clear the buffer.
        self.buffer.clear();

        # Continue through the input stream until we are no longer part
        # of a possible identifier.
        loop {
            self.buffer.append(self.pop_char());
            if not is_alphanumeric(self.peek_char(1)) and
                    self.peek_char(1) != "_" {
                break;
            };
        }

        # Check for and return keyword tokens instead of the identifier.
        # TODO: A hash-table would better serve this.
        let mut tag: int = 0;
             if self.buffer.eq_str("let")       { tag = tokens.TOK_LET; }
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
        else if self.buffer.eq_str("delegate")  { tag = tokens.TOK_DELEGATE; }
        else if self.buffer.eq_str("size_of")   { tag = tokens.TOK_SIZEOF; };

        # Return the token.
        if tag == 0 {
            # Scanned identifier does not match any defined keyword.
            # Update the current_id.
            Token.new(
                tokens.TOK_IDENTIFIER,
                span.Span.new(self.filename, pos, self.current_position()),
                self.buffer.data() as str);
        } else {
            # Return the keyword token.
            Token.new(
                tag,
                span.Span.new(self.filename, pos, self.current_position()),
                "");
        };
    }

    # scan_punctuator -- Scan for and match a punctuator token.
    # -------------------------------------------------------------------------
    let scan_punctuator(mut self): Token -> {
        # TODO: This scanning could probably be replaced by something
        #   creative in a declarative manner.

        # First attempt to match those that are unambigious in that
        # if the current character matches it is the token.
        let pos: span.Position = self.current_position();
        let ch: char = self.peek_char(1);
        let mut tag: int = 0;
        if      ch == "(" { tag = tokens.TOK_LPAREN; }
        else if ch == ")" { tag = tokens.TOK_RPAREN; }
        else if ch == "[" { tag = tokens.TOK_LBRACKET; }
        else if ch == "]" { tag = tokens.TOK_RBRACKET; }
        else if ch == "{" { tag = tokens.TOK_LBRACE; }
        else if ch == "}" { tag = tokens.TOK_RBRACE; }
        else if ch == ";" { tag = tokens.TOK_SEMICOLON; }
        else if ch == "," { tag = tokens.TOK_COMMA; }
        else if ch == "^" { tag = tokens.TOK_HAT; }
        else if ch == "&" { tag = tokens.TOK_AMPERSAND; }
        else if ch == "|" { tag = tokens.TOK_PIPE; }
        else if ch == ":" { tag = tokens.TOK_COLON; };

        # If we still need to continue ...
        if tag != 0 { self.pop_char(); }
        else
        {
            # Start looking forward and attempt to disambiguate the
            # following punctuators.
            if ch == "." {
                self.pop_char();
                if self.peek_char(1) == "." and self.peek_char(2) == "." {
                    self.pop_char();
                    self.pop_char();
                    tag = tokens.TOK_ELLIPSIS;
                } else {
                    tag = tokens.TOK_DOT;
                };
            } else if ch == "+" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_PLUS_EQ;
                } else {
                    tag = tokens.TOK_PLUS;
                };
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
                };
            } else if ch == "*" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_STAR_EQ;
                } else {
                    tag = tokens.TOK_STAR;
                };
            } else if ch == "/" {
                self.pop_char();
                if self.peek_char(1) == "/" {
                    self.pop_char();
                    if self.peek_char(1) == "=" {
                        self.pop_char();
                        tag = tokens.TOK_FSLASH_FSLASH_EQ;
                    } else {
                        tag = tokens.TOK_FSLASH_FSLASH;
                    };
                } else if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_FSLASH_EQ;
                } else {
                    tag = tokens.TOK_FSLASH;
                };
            } else if ch == "%" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_PERCENT_EQ;
                } else {
                    tag = tokens.TOK_PERCENT;
                };
            } else if ch == "<" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_LCARET_EQ;
                } else {
                    tag = tokens.TOK_LCARET;
                };
            } else if ch == ">" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_RCARET_EQ;
                } else {
                    tag = tokens.TOK_RCARET;
                };
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
                };
            } else if ch == "!" {
                self.pop_char();
                if self.peek_char(1) == "=" {
                    self.pop_char();
                    tag = tokens.TOK_BANG_EQ;
                } else {
                    tag = tokens.TOK_BANG;
                };
            };
        };

        # If we matched a token, return it; else, return nil.
        if tag != 0 {
            Token.new(
                tag,
                span.Span.new(self.filename, pos, self.current_position()),
                "");
        } else {
            Token.new(0, span.Span.nil(), "");
        };
    }

    # scan_string -- Scan for and produce a string token.
    # -------------------------------------------------------------------------
    # xdigit = [0-9a-fa-F]
    # str = \'([^'\\]|\\[#'"\\abfnrtv0]|\\[xX]{xdigit}{2})*\'
    #     | \"([^"\\]|\\[#'"\\abfnrtv0]|\\[xX]{xdigit}{2})*\"
    # -------------------------------------------------------------------------
    let scan_string(mut self): Token -> {
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
        let mut in_escape: bool = false;
        let mut in_byte_escape: bool = false;
        loop {
            if in_escape {
                # Bump the character onto the buffer.
                self.buffer.append(self.pop_char());

                # Check if we have an extension control character.
                if self.peek_char(1) == 'x' or self.peek_char(1) == 'X' {
                    in_byte_escape = true;
                };

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
                };
            };
        }

        # Matched the string token.
        return Token.new(
            tokens.TOK_STRING,
            span.Span.new(self.filename, pos, self.current_position()),
            self.buffer.data() as str);
    }
}

# Helpers
# =============================================================================

# is_whitespace -- Test if the passed character constitutes whitespace.
# -----------------------------------------------------------------------------
let is_whitespace(c: char): bool -> {
    c == ' ' or c == '\n' or c == '\t' or c == '\r';
}

# is_numeric -- Test if the passed character is numeric.
# -----------------------------------------------------------------------------
let is_numeric(c: char): bool -> {
    libc.isdigit(c as int8) != 0;
}

# Test if the char is in the passed range.
# -----------------------------------------------------------------------------
let in_range(c: char, s: char, e: char): bool -> {
    (c as int8) >= (s as int8) and (c as int8) <= (e as int8);
}

# is_alphabetic -- Test if the passed character is alphabetic.
# -----------------------------------------------------------------------------
let is_alphabetic(c: char): bool -> {
    libc.isalpha(c as int8) != 0;
}

# is_alphanumeric -- Test if the passed character is alphanumeric.
# -----------------------------------------------------------------------------
let is_alphanumeric(c: char): bool -> {
    libc.isalnum(c as int8) != 0;
}

# Driver (Test)
# =============================================================================

let main(): int -> {
    # Construct a new tokenizer.
    let mut tokenizer = Tokenizer.new("-", libc.stdin);

    # Iterate through each token in the input stream.
    loop {
        # Get the next token
        let mut tok: Token = tokenizer.next();

        # Print token if we're error-free
        if errors.count == 0 {
            tok.println();
        };

        # Stop if we reach the end.
        if tok.tag == tokens.TOK_END { break; };

        # Dispose of the token.
        tok.dispose();
    }

    # Dispose of the tokenizer.
    tokenizer.dispose();

    # Return to the environment.
    return 0 if errors.count == 0 else -1;
}
