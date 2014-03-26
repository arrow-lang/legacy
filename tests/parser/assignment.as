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
