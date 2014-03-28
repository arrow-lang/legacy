# Express automatic tuple types in a literal fashion.
(231,);
(231, 21.21);
(32, false,);
(32, 42, 42, 3232,);
("Hello", "World");
("Goodbye",);

# Declare various slots for automatic tuple types.
let q: (int, bool);
let w: (int, int,);
let e: (int, str, float64,);
let y: (uint,);

# Assign some tuples into those slots.
q = (32, true,);
w = (432, 32);
e = (2, "SIOJDGOHS", 32.31);
y = (135161,);

# Declare and initialize various slots for automatic tuple types.
let z: (int,) = (324,);
let x: (int, int,) = (324, 12);
let c: (int, int, int, int) = (523, 23, 321, 12);
let v: (str, int, bool, char) = ("ssgsd", 32, true, 'A');

# Destructure the types with type inference.
let (a1,) = a;
let (b1,) = b;
let (c1, c2) = c;
(d1, d2) := d;
(e1, e2) := e;
(f1, f2,) := f;

# Destructure some automatic tuple types with assignment.
let i1: int;
let i2: int;
let f: float32;
(f,) = (32.124,);
(i1, i2) = (32, 32);
