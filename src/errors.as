foreign "C" import "stdio.h";
foreign "C" import "unistd.h";

# Error count
let mut count: uint = 0;

# print_location
# -----------------------------------------------------------------------------
def print_location() {
    fprintf(stderr, "_:" as ^int8);
}

# begin
# -----------------------------------------------------------------------------
def begin() {
    if isatty(2) <> 0 {
        fprintf(stderr, "\x1b[1;37m" as ^int8);
    }
    print_location();
}

# begin_error
# -----------------------------------------------------------------------------
def begin_error() {
    begin();
    print_error();
}

# end
# -----------------------------------------------------------------------------
def end() {
    if isatty(2) <> 0 {
        fprintf(stderr, "\x1b[0m" as ^int8);
    }
    fprintf(stderr, "\n" as ^int8);
}

# print_error
# -----------------------------------------------------------------------------
def print_error() {
    if isatty(2) <> 0 {
        fprintf(stderr, "\x1b[1;31m" as ^int8);
    }

    count = count + 1;
    fprintf(stderr, " error: " as ^int8);

    if isatty(2) <> 0 {
        fprintf(stderr, "\x1b[1;37m" as ^int8);
    }
}
