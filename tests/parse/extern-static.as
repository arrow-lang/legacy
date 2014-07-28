
# NOTE: "int" or "uint" should be replaced by something like
#       "std.libc.int" or "std.libc.size_t" so that the compiler will insert
#       the appropriate type for the target platform.

extern let mut errno: int;
extern let stdout: *int8;
