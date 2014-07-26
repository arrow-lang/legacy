
# unistd.h
# -----------------------------------------------------------------------------

# isatty - test whether a file descriptor refers to a terminal
extern let isatty(int64) -> int64;

# poll.h
# -----------------------------------------------------------------------------

struct pollfd {
    fd: int64,
    events: int16,
    revents: int16,
}

# wait for some event on a file descriptor
extern let poll(*pollfd, int64, int64) -> int64;
