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
            return token_new(
                tokens.TOK_END,
                span.span_new(
                    self.filename,
                    self.current_position(),
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
        let sp: span.Span = span.span_new(self.filename, pos, pos);
        errors.begin_error_at(sp);
        errors.libc.fprintf(errors.libc.stderr,
                            "unknown token: `%c`" as ^int8,
                            self.pop_char());
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
    def scan_numeric(&mut self) -> Token {
    }

}

# Helpers
# =============================================================================

def is_whitespace(c: char) -> bool {
    c == ' ' or c == '\n' or c == '\t' or c == '\r';
}

def is_numeric(c: char) -> bool {
    libc.isdigit(c as int32) <> 0;
}

# Driver (Test)
# =============================================================================

def main() {
    # Construct a new tokenizer.
    let mut tokenizer: Tokenizer = tokenizer_new("-", libc.stdin);

    # Iterate through each token in the input stream.
    loop {
        let tok: Token = tokenizer.next();

        # Print token if we're still error-free
        if errors.count == 0 { tok.println(); }

        # Stop if we reach the end.
        if tok.tag == tokens.TOK_END { break; }
    }

    # Dispose of the tokenizer.
    tokenizer.dispose();

    # Return to the environment.
    libc.exit(0 if errors.count == 0 else -1);
}
