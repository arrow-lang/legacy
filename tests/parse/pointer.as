
# Pointers are declared using the C-style "*" symbol but as a prefix to
# the type rather than a suffix.
let x: *int;
let x: ***int;

# Pointers and their values are both immutable by default.
let mut x: *int;        # mutable pointer to an immutable value
let x: *mut int;        # immutable pointer to a mutable value
let mut x: *mut int;    # mutable pointer to a mutable value
let x: *mut *int;
let x: *mut *mut int;
let x: *mut *mut *int;
let x: *mut *mut *mut int;

# An address of an existing value can be taken with the "&" symbol prefix; this
# can create a pointer (much like in "C").
# NOTE: An immutable pointer is inferred by default; use "&mut " to take a
#       "mutable" address.
let y = 73;
let x = &y;
let a = 73;
let x = &mut a;
let x: *mut int = &a;  # semantic error because &a is '*int' not '*mut int'

# The value of a pointer can be loaded by the unary "*" operator (
# much like in "C").
let x: int;
let y: *int = &x;
let z: int = *y;
let w: int = *&y;
