import string;
import libc;

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
        self.fprint(libc.stdout);
    }

    def fprint(&self, stream: ^libc._IO_FILE) {
        if self.isnull() {
            libc.fprintf(stream, "(nil)" as ^int8);
            return;
        }

        if libc.strcmp(self.filename.data() as ^int8, "-" as ^int8) == 0 {
            libc.fprintf(stream, "<stdin>:" as ^int8);
        } else {
            libc.fprintf(stream, "%s:" as ^int8, self.filename.data());
        }

        if self.begin.row == self.end.row
        {
            libc.fprintf(stream, "%d:%d-%d" as ^int8,
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
