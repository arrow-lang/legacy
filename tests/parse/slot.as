# Static slot declaration declares a slot with a static storage duration.
# Static slots are inherited in the scope of nested functions.
let a: int = 0;
let b: int = 320;

# Perhaps allow a thread-local directive like this in the future?
# @thread_local static x: int;

# Static slots can be declared *mutable* which allows further modification
# of the value at the slot. Looking at or updating the value of a *mutable*
# static slot is considered "unsafe".
let mut c: int = 0;
let mut c: int = (23 * 3209);

# Local slot declaration declares a slot in the local space of a function.
# Local slots are not inherited in the scope of nested functions.
let d: int;

# Local slot declaration with an initializer. By default local slots are
# not initialized and attempting to access them is a compiler error.
let e: int = 3402;

# Local slot declaration dropping the type (inferred typing based on
# context, initializer [if present], and usage).
let f;
let g = 42;

# Local mutable slot declaration. It is not considered "unsafe" to read or
# write a locally mutable slot.
let mut h;
let mut i: int;
let mut j: int = 26;

# # Multiple local slot declarations. The way it works / is implemented is that
# # a local slot declaration can use a pattern to match the right-hand
# # expression. Note that this is not possible for static slot declarations.
# # TODO: Below requires tuples to be understood by the parser.
# let (x, y, z, w): (int, bool, float64, str) = (32, false, 243.5, "sg");
# let mut (x, y, z, w): (int, bool, float64, str) = (32, false, 243.5, "sg");
# let (x, y, z, w): (int, bool, float64, str) = (32, false, 243.5, "sg");
# let (x, y, z, w): (int, bool, float64, str);
# let mut (x, y, z, w): (int, bool, float64, str);
# let mut (x, y, z, w) = (32, false, 243.5, "sg");
# let (x, y, z, w) = (32, false, 243.5, "sg");
# let (x, y, z, w);
# let mut (x, y, z, w);
