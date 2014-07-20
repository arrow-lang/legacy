
# Enumeration of values that represent various built-in types for usage
# in pseudo-generic code.

let I8:   int =  1;      #    8-bit signed integer
let I16:  int =  2;      #   16-bit signed integer
let I32:  int =  3;      #   32-bit signed integer
let I64:  int =  4;      #   64-bit signed integer
let I128: int =  5;      #  128-bit signed integer

let U8:   int =  6;      #    8-bit unsigned integer
let U16:  int =  7;      #   16-bit unsigned integer
let U32:  int =  8;      #   32-bit unsigned integer
let U64:  int =  9;      #   64-bit unsigned integer
let U128: int = 10;      #  128-bit unsigned integer

let F32:  int = 11;      #   32-bit floating-point
let F64:  int = 12;      #   64-bit floating-point

let STR:  int = 13;      # managed pointer to 8-bit signed integer

let UINT: int = 14;      # machine unsigned integer
let INT:  int = 15;      # machine signed integer
let PTR:  int = 16;      # pointer (non-managed)

let CHAR: int = 17;      # character

# Gets if the type tag has individual memory that needs to be disposed.
let is_disposable(tag: int): bool -> {
    if tag == STR { true; }
    else { false; };
}

# Keep track of the size (in bytes) of the types.
let mut _sizes: uint[20];
_sizes[I8] = 1;
_sizes[I16] = 2;
_sizes[I32] = 4;
_sizes[I64] = 8;
_sizes[I128] = 16;
_sizes[U8] = 1;
_sizes[U16] = 2;
_sizes[U32] = 4;
_sizes[U64] = 8;
_sizes[U128] = 16;
_sizes[F32] = 4;
_sizes[F64] = 8;
_sizes[CHAR] = _sizes[U32];
_sizes[STR] = ((0 as *uint) + 1) - (0 as *uint);
_sizes[UINT] = ((0 as *uint) + 1) - (0 as *uint);
_sizes[INT] = ((0 as *int) + 1) - (0 as *int);
_sizes[PTR] = ((0 as *uint) + 1) - (0 as *uint);

# Gets the size (in bytes) of the type.
let sizeof(tag: int): uint -> {
    return _sizes[tag];
}
