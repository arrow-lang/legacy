# Declare a function that returns the `double` function.
let that(): type(double) -> { double; }

# Declare a function that doubles its argument that is bound to the type
# of a static declared below.
let double(a: type(x)): type(x * 2) -> { a * 2; }

# Declare an unsigned integral static.
let x: uint = 40;

# Declare a value that is set to the type of a uint.
let u = type(x);

# Declare a slot for a type box.
let t: type;
let t: type(type);
