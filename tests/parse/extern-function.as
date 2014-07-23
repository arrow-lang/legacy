
# NOTE: "int" or "uint" should be replaced by something like
#       "std.libc.int" or "std.libc.size_t" so that the compiler will insert
#       the appropriate type for the target platform.

# Create an extern specification for the "exit" function.
extern let exit(int);

# Create an extern specification for the "socket" function.
extern let socket(domain: int, type_: int, protocol: int) -> int;

# Create an extern specification for the "recv" function.
extern let recv(socket: int, buffer: *uint8, length: uint, flags: int) -> int;
