import libc;
import posix;
import span;

# Error count
let mut count: uint = 0;

# print_location
# -----------------------------------------------------------------------------
def print_location() {
    libc.fprintf(libc.stderr, "_:" as ^int8);
}

# begin
# -----------------------------------------------------------------------------
def begin() {
    if posix.isatty(2) <> 0 {
        libc.fprintf(libc.stderr, "\x1b[1;37m" as ^int8);
    }
}

# begin_error
# -----------------------------------------------------------------------------
def begin_error() {
    begin();
    print_error();
}

# begin_error_at
# -----------------------------------------------------------------------------
def begin_error_at(s: span.Span) {
    if posix.isatty(2) <> 0 {
        libc.fprintf(libc.stderr, "\x1b[1;37m" as ^int8);
    }
    s.fprint(libc.stderr);
    libc.fprintf(libc.stderr, ": " as ^int8);
    print_error();
}

# end
# -----------------------------------------------------------------------------
def end() {
    if posix.isatty(2) <> 0 {
        libc.fprintf(libc.stderr, "\x1b[0m" as ^int8);
    }
    libc.fprintf(libc.stderr, "\n" as ^int8);
}

# print_error
# -----------------------------------------------------------------------------
def print_error() {
    if posix.isatty(2) <> 0 {
        libc.fprintf(libc.stderr, "\x1b[1;31m" as ^int8);
    }

    count = count + 1;
    libc.fprintf(libc.stderr, "error: " as ^int8);

    if posix.isatty(2) <> 0 {
        libc.fprintf(libc.stderr, "\x1b[1;37m" as ^int8);
    }
}
