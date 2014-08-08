import libc;
import posix;
import span;

# Error count
let mut count: uint = 0;

# print_location
# -----------------------------------------------------------------------------
let print_location() -> {
    libc.fprintf(libc.stderr, "_:");
}

# begin
# -----------------------------------------------------------------------------
let begin() -> {
    if posix.isatty(2) != 0 {
        libc.fprintf(libc.stderr, "\x1b[1;37m");
    };
}

# begin_error
# -----------------------------------------------------------------------------
let begin_error() -> {
    begin();
    print_error();
}

# begin_error_at
# -----------------------------------------------------------------------------
let begin_error_at(s: span.Span) -> {
    if posix.isatty(2) != 0 {
        libc.fprintf(libc.stderr, "\x1b[1;37m");
    };
    s.fprint(libc.stderr);
    libc.fprintf(libc.stderr, ": ");
    print_error();
}

# end
# -----------------------------------------------------------------------------
let end() -> {
    if posix.isatty(2) != 0 {
        libc.fprintf(libc.stderr, "\x1b[0m");
    };
    libc.fprintf(libc.stderr, "\n");
}

# print_error
# -----------------------------------------------------------------------------
let print_error() -> {
    if posix.isatty(2) != 0 {
        libc.fprintf(libc.stderr, "\x1b[1;31m");
    };

    count = count + 1;
    libc.fprintf(libc.stderr, "error: ");

    if posix.isatty(2) != 0 {
        libc.fprintf(libc.stderr, "\x1b[1;37m");
    };
}
