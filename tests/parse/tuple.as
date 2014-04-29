# Express automatic tuple types in a literal fashion.
();  # ok, empty tuple (man, so useless)
(231,);
(231, 21.21);
(32, false,);
(32, 42, 42, 3232e-1,);

# Declare various slots for automatic tuple types.
let q: (int, bool);
let w: (int, int,);
let e: (int, str, float64,);
let y: (uint,);

# Assign some tuples into those slots.
q = (32, true,);
w = (432, 32);
y = (135161,);

# # Declare and initialize various slots for automatic tuple types.
let z: (int,) = (324,);
let x: (int, int,) = (324, 12);
let c: (int, int, int, int) = (523, 23, 321, 12);
