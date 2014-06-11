import libc;
import string;
import tokens;
import list;
import types;

# Position
# =============================================================================

type Position {
    column: int,  #< Column offset
    row: int      #< Row offset
}

implement Position {
    def isnull(&self) -> bool {
        return self.column == -1 and self.row == -1;
    }
}

# FIXME: Remove when types have default constructors.
def position_new(column: int, row: int) -> Position {
    let pos: Position;
    pos.column = column;
    pos.row = row;
    return pos;
}

# FIXME: Move to an "attached" function when possible.
def position_null() -> Position {
    let pos: Position;
    pos.column = -1;
    pos.row = -1;
    return pos;
}

# Span
# =============================================================================

type Span {
    #! Full path to the file in which this span occurred.
    mut filename: string.String,

    #! Initial position in the referenced file.
    begin: Position,

    #! Final position in the referenced file.
    end: Position
}

implement Span {
    def dispose(&mut self) {
        # Dispose of contained resources.
        self.filename.dispose();
    }

    def isnull(&self) -> bool {
        return self.filename.size() == 0;
    }

    def print(&self) {
        if self.isnull() { printf("(nil)"); return; }

        if libc.strcmp(self.filename.data() as ^int8, "-" as ^int8) == 0 {
            printf("<stdin>:");
        } else {
            printf("%s:", self.filename.data());
        }

        if self.begin.row == self.end.row
        {
            printf("%d:%d-%d",
                   self.begin.row + 1,
                   self.begin.column + 1,
                   self.end.column + 1);
        }
    }
}

# FIXME: Move to an "attached" function when possible.
def span_new(filename: str, begin: Position, end: Position) -> Span {
    let span: Span;
    span.filename = string.make();
    span.filename.extend(filename);
    span.begin = begin;
    span.end = end;
    return span;
}

# FIXME: Move to an "attached" function when possible.
def span_null() -> Span {
    let span: Span;
    span.filename = string.make();
    span.begin = position_null();
    span.end = position_null();
    return span;
}

# Token
# =============================================================================

type Token {
    #! Tag (identifier) of the token type.
    tag: int,

    #! Span in which the token occurs.
    mut span: Span,

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
        self.span.print();
        printf(": ");

        if self.tag == tokens.TOK_END {
            printf("<end>");
        }

        printf("\n");
    }

}

# FIXME: Move to an "attached" function when possible.
def token_new(tag: int, span: Span, text: str) -> Token {
    let tok: Token;
    tok.tag = tag;
    tok.span = span;
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

        # Return the <end> token.
        return token_new(
            tokens.TOK_END,
            span_new(
                self.filename,
                position_new(self.column, self.row),
                position_new(self.column, self.row)), "");
    }

}

# Helpers
# =============================================================================

def is_whitespace(c: char) -> bool {
    c == ' ' or c == '\n' or c == '\t' or c == '\r';
}

# Driver (Test)
# =============================================================================

def main() {
    # Construct a new tokenizer.
    let mut tokenizer: Tokenizer = tokenizer_new("-", libc.stdin);

    # Iterate through each token in the input stream.
    loop {
        let tok: Token = tokenizer.next();
        tok.println();
        if tok.tag == tokens.TOK_END { break; }
    }

    # Dispose of the tokenizer.
    tokenizer.dispose();

    # Return success to the environment.
    libc.exit(0);
}
