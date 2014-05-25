# Express automatic tuple types in a literal fashion.
();  # ok, empty tuple (man, so useless)
(231,);
(231, 21.21);
(32, false,);
(32, 42, 42, 3232e-1,);

# Declare various slots for automatic tuple types.
let a: (int, bool);
let b: (int, int,);
let c: (int, str, float64,);
let d: (uint,);
let e: (a: int, b: str, c: float64);
let f: (a: int, b: uint,);
let g: (a: bool);
let h: (a: bool, int);
let i: (int, a: bool);

# Assign some tuples into those slots.
a = (3214, false);
b = (62, 26,);
# c = (2351, "sdhs", 321.1672,);
d = (2872,);
# e = (a: 26526, b: "eysdgfh", c: 236.213);
e = (:a, :b, c: 21.21);
f = (a: 235, b: 235,);
g = (a: false);
g = (:a);
h = (a: false, 51);
h = (:a, 51);
i = (734, a: true);
i = (231, :a);
