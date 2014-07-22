
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

# Gets the size (in bytes) of the type by tag.
let sizeof(tag: int): uint -> {
         if tag ==   I8 { size_of(  int8); }
    else if tag ==  I16 { size_of( int16); }
    else if tag ==  I32 { size_of( int32); }
    else if tag ==  I64 { size_of( int64); }
    else if tag == I128 { size_of(int128); }
    else if tag ==   U8 { size_of( uint16); }
    else if tag ==  U16 { size_of( uint16); }
    else if tag ==  U32 { size_of( uint32); }
    else if tag ==  U64 { size_of( uint64); }
    else if tag == U128 { size_of(uint128); }
    else if tag == F32  { size_of(float32); }
    else if tag == F64  { size_of(float64); }
    else if tag == CHAR { size_of(char); }
    else if tag == STR  { size_of(*uint); }
    else if tag == INT  { size_of(int); }
    else if tag == UINT { size_of(uint); }
    else if tag == PTR  { size_of(*uint); }
    else { 0; };
}
