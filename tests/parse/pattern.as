# Destructure the types with type inference.
let (a1,) = a;
let (b1,) = b;
let (c1, c2) = c;

# Destructure some automatic tuple types with assignment.
let i1: int;
let i2: int;
let f: float32;
(f,) = (32.124,);
(i1, i2) = (32, 32);
