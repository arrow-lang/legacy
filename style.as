# Notes
# -----------------------------------------------------------------------------
# Uniform style is key
# Parameter type annotations are 100% optional for anonymous functions
# Parameter type annotations are optional for named function declarations
#   however for maximum performance or type safety they can be added (arrow
#   would infer thet types of the parameters by how they are used in
#   the function).
# Return type annotations are 100% optional for all functions.

# Slot declaration
# -----------------------------------------------------------------------------
let mut number = 42  # mutable
let opposite = true  # immutable

# Assignment
# -----------------------------------------------------------------------------
# ok, type of `number` is now the set of traits implemented by the types
# directly influencing the lexical slot
number = "Hello"

# Conditions
# -----------------------------------------------------------------------------
if opposite { number = 1.2 }
number = 1.2 if opposite

# Named function declaration
# -----------------------------------------------------------------------------

# Declare a named function item that takes no parameters
# and returns unit (with an empty function body).
main() -> { }

# Declares a named function item that takes no parameters
# and returns `int` (with an empty function body).
main(): int -> { }

# Declares a named function item that takes a single parameter `x` of type
# `int` that returns the expression `x * x`.
square(x: int) -> x * x
square(x: int): int -> { x * x }
square(x: int) -> { x * x }
square(x: int) -> { return x *  }

# Additional functions
cube(x) -> square(x) * x

# Function that returns a function that ..
some(x) -> (y) -> x ** y;

# Anonymous function declaration
# -----------------------------------------------------------------------------

# Equivalent to the named `square` function except for scoping. Named "items"
# are mutually recursive while "let" bindings are lexically scoped.
let square = (x) -> { x * x }
let square = (x) -> x * x
let square = x -> { x * x }
let square = x -> x * x

# Additional functions
let pow = (x, exp) -> x ** exp

# Arrays
# -----------------------------------------------------------------------------
let song = ["do", "re", "mi", "fa", "so"]
let list = [1, 2, 3, 4]

let mut growable = [45]
growable.append(61)
growable.extend(list)

let bitlist = [1, 0, 1,
               0, 0, 1,
               1, 1, 0]

# Tuples
# -----------------------------------------------------------------------------
let point = (65, 1)
let result = (someValue, false)
let singers = (Jagger: "Rock", Elvis: "Roll")
let kids = (brother: (name: "Max", age: 11),
            sister:  (name: "Ida", age:  9))

# External function declaration
# -----------------------------------------------------------------------------
extern exit(status: int32);
extern puts(s: str): int32;
extern "stdcall" puts(s: str): int32;
extern "C" puts(s: str): int32;

# External global variables
# -----------------------------------------------------------------------------
extern stdout: *FILE;
extern errno: int;

# Structures
# -----------------------------------------------------------------------------
struct Point { x: int, y: int }
struct Box<T> { value: T }

# Implement (methods) on existing types
# -----------------------------------------------------------------------------
implement Point {
    # `self` is a keyword and if present the function is an instance method
    to_str(self): str -> { }
    add(self, other: Point): Point -> { }
    sub(self, other: Point): Point -> { }

    # this is an attached or `static` method
    new(x: int, y: int): Point -> { }
}

# Class (tentative feature)
# -----------------------------------------------------------------------------
class Point {
    x: int;
    y: int;
    to_str(self): str -> { }
    make(x: int, y: int): Point -> { }
    add(other: Point): Point -> { }
    sub(other: Point): Point -> { }
}

# Enumeration (sum types)
# -----------------------------------------------------------------------------
enum Color { Red, Green, Blue }
enum Suit { Clubs, Diamonds, Hearts, Spades }
enum List { Nil, Cons(int, List = Nil) }
enum Tree { Leaf, Node(int, Tree = Leaf, Tree = Leaf) }

# Enumerations may have type-parameters (along with all nominal types)
enum Option<T> {
    Some(T),
    None
}

# Function types
# -----------------------------------------------------------------------------
call(fn: (int, bool): int) -> { }   # takes a 2 param fn that returns int
call(fn: (int, bool): ()) -> { }    # takes a 2 param fn
call(fn: (): ()) -> { }             # takes a 0 param fn that returns unit
ret(): (): () -> { }                # returns a 0 param fn that returns unit
ret(): (int, bool): bool -> { }     # returns a 2 param fn that returns bool
ret(): (int, bool): () -> { }       # returns a 2 param fn that returns unit
