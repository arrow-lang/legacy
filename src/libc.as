
# ctype.h
# -----------------------------------------------------------------------------

extern let isalpha(int64) -> int64;
extern let isalnum(int64) -> int64;
extern let isdigit(int64) -> int64;
extern let isxdigit(int64) -> int64;

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

# Environment
extern let exit(status: int32);

# stdio.h
# -----------------------------------------------------------------------------

# FILE Handle
struct FILE { }

# Streams
extern let stdout: *FILE;
extern let stdin: *FILE;
extern let stderr: *FILE;

# File access
extern let fopen(filename: str, mode: str) -> *FILE;
extern let fclose(*FILE);

# Formatted input/output
extern let fprintf(*FILE, str, ...) -> int64;
extern let printf(str, ...) -> int64;
extern let snprintf(str, uint64, str, ...) -> int32;

# Character input/output
extern let puts(str) -> int64;

# Direct input/output
extern let fread(*int8, size: uint, count: uint, stream: *FILE) -> uint;

# Error-handling
extern let perror(str);
