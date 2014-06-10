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
    tag: uint,

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
}

# FIXME: Move to an "attached" function when possible.
def token_new(tag: uint, span: Span, text: str) -> Token {
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
    #! Input stream to read the characters from.
    stream: ^libc._IO_FILE,

    #! Input buffer for the incoming character stream.
    mut chars: list.List,

    #! Text buffer for constructing tokens.
    mut buffer: string.String
}

# FIXME: Move to an "attached" function when possible.
def tokenizer_new(stream: ^libc._IO_FILE) -> Tokenizer {
    let tokenizer: Tokenizer;
    tokenizer.stream = stream;
    tokenizer.chars = list.make(types.U8);
    tokenizer.buffer = string.make();
    return tokenizer;
}

implement Tokenizer {

    def dispose(&mut self) {
        # Dispose of contained resources.
        libc.fclose(self.stream);
        self.chars.dispose();
        self.buffer.dispose();
    }

}

# Driver (Test)
# =============================================================================

def main() {
    # Reopen "stdin" for binary mode (and so it can be closed).
    let stream: ^libc._IO_FILE = libc.freopen(
        0 as ^int8, "wb" as ^int8, libc.stdin);

    # Construct a new tokenizer.
    let mut tokenizer: Tokenizer = tokenizer_new(stream);

    # Iterate through each token in the input stream.
    # loop {
    #     let tok: Token = tokenizer.next();
    #     tok.println();
    #     if tok.tag == tokens.TOK_END { break; }
    # }

    # Dispose of the tokenizer.
    tokenizer.dispose();

    # Return success to the environment.
    libc.exit(0);
}
