# Declare a function that returns the `double` function.
def that() -> type(double) { double; }

# Declare a function that doubles its argument that is bound to the type
# of a static declared below.
def double(a: type(x)) -> type(x * 2) { a * 2; }

# Declare an unsigned integral static.
static x: uint = 40;
