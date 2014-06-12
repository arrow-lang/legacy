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
                            self.pop_char();
                            self.buffer.append(ch);
                        }
                        else if ch <> "_"
                        {
                            break;
                        }
                    }
                }
                else if tag == tokens.TOK_OCT_INTEGER
                {
                    loop
                    {
                        let ch: char = self.peek_char(1);
                        if in_range(ch, "0", "7")
                        {
                            self.pop_char();
                            self.buffer.append(ch);
                        }
                        else if ch <> "_"
                        {
                            break;
                        }
                    }
                }
                else if tag == tokens.TOK_HEX_INTEGER
                {
                    loop
                    {
                        let ch: char = self.peek_char(1);
                        if libc.isxdigit(ch as int32) <> 0
                        {
                            self.pop_char();
                            self.buffer.append(ch);
                        }
                        else if ch <> "_"
                        {
                            break;
                        }
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
                self.pop_char();
                self.buffer.append(ch);
            } else if ch <> "_" {
                break;
            }
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
                    self.pop_char();
                    self.buffer.append(ch);
                } else if ch <> "_" {
                    break;
                }
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
                    self.pop_char();
                    self.buffer.append(ch);
                } else if ch <> "_" {
                    break;
                }
            }
        }

        # Build and return our numeric.
        return token_new(
            tag, span.span_new(self.filename, pos, self.current_position()),
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

# Driver (Test)
# =============================================================================

def main() {
    # Construct a new tokenizer.
    let mut tokenizer: Tokenizer = tokenizer_new("-", libc.stdin);

    # Iterate through each token in the input stream.
    loop {
        # Get current errors
        let count: uint = errors.count;

        # Get the next token
        let mut tok: Token = tokenizer.next();

        # Print token if we're error-free
        if errors.count <= count { tok.println(); }

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
