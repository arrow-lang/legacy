
# unistd.h
# -----------------------------------------------------------------------------

# isatty - test whether a file descriptor refers to a terminal
extern let isatty(int) -> int;

# access - determine accessibility of a file
extern let access(str, int32) -> int32;

# getopt.h
# -----------------------------------------------------------------------------

struct option {
    name: str,
    has_arg: int32,
    flag: *int32,
    val: int32,
}

extern let mut optind: int32;
extern let mut optarg: str;

extern let getopt_long(argc: int32, argv: *str,
                       shortopts: str, longopts: *option,
                       longind: *int32) -> int32;

# poll.h
# -----------------------------------------------------------------------------

struct pollfd {
    fd: int32,
    events: int16,
    revents: int16,
}

# wait for some event on a file descriptor
extern let poll(*pollfd, int32, int32) -> int32;
