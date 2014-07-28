
# unistd.h
# -----------------------------------------------------------------------------

# isatty - test whether a file descriptor refers to a terminal
extern let isatty(int) -> int;

# getopt.h
# -----------------------------------------------------------------------------

struct option {
    name: str,
    has_arg: int,
    flag: *int,
    val: int,
}

extern let mut optind: int;

extern let getopt_long(argc: int, argv: *str,
                       shortopts: str, longopts: *option,
                       longind: *int) -> int;

# poll.h
# -----------------------------------------------------------------------------

struct pollfd {
    fd: int,
    events: int16,
    revents: int16,
}

# wait for some event on a file descriptor
extern let poll(*pollfd, int, int) -> int;
