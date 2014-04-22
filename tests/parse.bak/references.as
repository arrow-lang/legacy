# # Declare a couple slots that are references.
# let mut y: int = 32;
# let &x: int;
# x = y;
# # x <is> now y
# x == 32;
# y = 61;
# x == 61;

# # Declare a mutable reference.
# let &mut z: int = y;
# z += 32;
# y == 93;

# # Declare a function that explicitly takes a reference.
# # Functions by -default- capture all arguments by immutable reference.
# def func(&x: int) { }

# # To force a function to capture an argument by copy you can ask for
# # a mutable value.
# def func(mut x: int) { }

# # To take an "out" parameter you can ask for a mutable reference.
# def func(&mut x: int) { x = 32; }

# # Immutable reference parameters can be bound from variables or constants.
# # Mutable reference parameters can only be bound from a mutable slot.

# # Functions can further return both a mutable and an immutable reference.
# # By default functions return by-value.
# def func() -> &int { y; }
# def func() -> &mut int { y; }
