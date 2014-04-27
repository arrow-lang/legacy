# Slot assignment.
# Usage-based type inference will make 'x' and 'int'.
# Because 'x' is immutable it can only be assigned to once.
let x;
x = 423;

# Mutable slot assignment.
let mut y: int;
y = 432;
y = 43;
y = 8293;

# Chained assignment.
let a: int;
let b: int;
let c: int;
a = b = c = 0;

# Augmented assignment.
let mut z: int = 20;
z *= 31;
z /= 5;
z += 2;
z -= 494;
z %= 11;
