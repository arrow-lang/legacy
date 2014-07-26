import string;
import libc;

# Position
# =============================================================================

struct Position {
    column: int,  #< Column offset
    row: int      #< Row offset
}

implement Position {
    let nil(): Position -> {
        return Position(-1, -1);
    }

    let isnull(self): bool -> {
        return self.column == -1 and self.row == -1;
    }
}

# Span
# =============================================================================

struct Span {
    # Full path to the file in which this span occurred.
    filename: string.String,

    # Initial position in the referenced file.
    begin: Position,

    # Final position in the referenced file.
    end: Position
}

implement Span {
    let nil(): Span -> {
        return Span(string.String.new(), Position.nil(), Position.nil());
    }

    let dispose(mut self) -> {
        # Dispose of contained resources.
        self.filename.dispose();
    }

    let isnil(self): bool -> {
        return self.filename.size() == 0;
    }

    let print(self) -> {
        self.fprint(libc.stdout);
    }

    let fprint(self, stream: *libc.FILE) -> {
        if self.isnil() {
            libc.fprintf(stream, "(nil)");
            return;
        };

        if libc.strcmp(self.filename.data(), "-") == 0 {
            libc.fprintf(stream, "<stdin>:");
        } else {
            libc.fprintf(stream, "%s:", self.filename.data());
        };

        # TODO: Support multi-line span printing
        if self.begin.row == self.end.row {
            libc.fprintf(stream, "%d:%d-%d",
                self.begin.row + 1,
                self.begin.column + 1,
                self.end.column + 1);
        };
    }
}
