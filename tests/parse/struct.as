# Some anonymous structure expressions
{x: 10};
{y: 20,};
{a: 20, b: false, c: 3.123};

# Declare a few nominal structures.
struct Point {x: int, y:str,}
struct Point {x: int, y:str}
struct Box {a: bool,}
struct Box {mut a: bool}
struct Nil {}

# Declare some structures with static members.
struct StaticPoint {static x: int = -3}
struct StaticPoint {static mut x: int = 3}

# Declare structures with type parameters.
struct Box<T> { value: T }
struct Point<T, U> { x: T, y: U }
struct Vector<T: Numeric> { x: T, y: T, z: T }
struct Strange<T: Num+Freeze> { a: T }
