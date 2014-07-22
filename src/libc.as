
# string.h
# -----------------------------------------------------------------------------

# Copying
extern let memcpy(destination: *int8, source: *int8, n: uint) -> *int8;
extern let memmove(destination: *int8, source: *int8, n: uint) -> *int8;
extern let strcpy(destination: str, source: str) -> str;

# Comparison
extern let memcmp(*int8, *int8, n: uint) -> int64;
extern let strcmp(str, str) -> int64;
extern let strncmp(str, str, n: uint) -> int64;

# Other
extern let memset(*int8, int8, n: uint) -> *int8;
extern let strlen(s: str) -> uint;

# stdlib.h
# -----------------------------------------------------------------------------

# Dynamic memory management
extern let malloc(size: uint) -> *int8;
extern let calloc(n: uint, size: uint) -> *int8;
extern let realloc(ptr: *int8, size: uint) -> *int8;
extern let free(ptr: *int8);

# stdio.h
# -----------------------------------------------------------------------------

# Formatted input/output
# extern let fprintf(FILE*, str, ...) -> int64;
extern let printf(str, ...) -> int64;

# Character input/output
extern let puts(str) -> int64;
