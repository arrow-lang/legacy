# Declare a few nominal structures.
struct Point {x: int = 50, y: int = 20}
struct Nil {}

# Declare structures with type parameters.
struct Box<T> { value: T }
struct Point<T, U> { x: T, y: U }
# struct Vector<T: Numeric> { x: T, y: T, z: T }
# struct Strange<T: Num+Freeze> { a: T }
