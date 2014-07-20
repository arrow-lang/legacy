# foreign "C" import "string.h";
# foreign "C" import "stdlib.h";
# foreign "C" import "libgen.h";
# foreign "C" import "stdio.h";
# foreign "C" import "ctype.h";
# foreign "C" import "unistd.h";
# foreign "C" import "getopt.h";
# foreign "C" import "sys/poll.h";

# string.h
# -----------------------------------------------------------------------------

# Copying
extern def memcpy(destination: *int8, source: *int8, n: uint): *int8;
extern def memmove(destination: *int8, source: *int8, n: uint): *int8;

# stdlib.h
# -----------------------------------------------------------------------------

# Dynamic memory management
extern def malloc(size: uint): *int8;
extern def calloc(n: uint, size: uint): *int8;
extern def realloc(ptr: *int8, size: uint): *int8;
extern def free(ptr: *int8);
