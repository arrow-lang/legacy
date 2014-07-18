# Make two normal static slots.
static x = 50;
static y = 60;

# Make a third the product of the first two.
static z = x * y;

# Ensure that we did this correctly.
let main() -> { assert(z == x * y); }
