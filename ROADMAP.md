# 0.0.1
 - [ ] Function declarations (nested)
 - [P] Basic types (bool, int8, int16, int32, int64, uint8, uint16, uint32, uint64, float32, float64)
 - [ ] Function call expression
 - [P] Local slot declaration
 - [P] Static slot declaration
 - [P] Unary expressions
 - [P] Binary expressions
 - [P] Relational and logical expressions
 - [P] Mixed mode arithmetic (allow 32.2 + 32, etc.)
 - [.] "Safe" cast expressions
 - [ ] Selection statement (if x { ... } else { ... })
 - [P] Mutable slot declaration (static and local)
 - [P] Slot assignment: =
 - [.] Augmented assignment: += -= /= *= %=
 - [P] Type inference (declaration)
 - [P] Type inference (usage)
 - [ ] Location span information (for error messages)
 - [ ] REPL (complete)
 - [ ] Front-end (complete); eg. flags, etc.
 - [ ] Strong unit / regression test suite (match all error cases)

# 0.0.2
 - [ ] Ternary expression -- a if condition else b
 - [ ] Postfix selection statement -- a if condition
 - [ ] Structure declaration -- struct Point{x: int, y: int}
 - [ ] Structure expression -- Point{x: 0, y: 32}
 - [ ] Tuple type expression
 - [ ] "New" type declaration -- type Point = (int, int);
 - [ ] Multiple slot declaration -- let (x: int, y: int) = (3, 32);
 - [ ] Tuple unpacking -- (x, y) = (32, 32)
 - [ ] Structure unpacking -- {x, y} = point
 - [ ] Iteration statement -- while condition { ... } / loop { ...}
 - [ ] Break / continue statements
 - [ ] Parameter calling convention-less (eg. point optimization)
 - [ ] Array type declaration -- let x: int[3]

# 0.0.3
 - [ ] Enumeration declaration
 - [ ] Implement declaration
 - [ ] Switch pattern matching -- match <expression> { <constant> => ... }
 - [ ] Enumeration variant pattern matching / destructuring

# 0.0.4
 - [ ] Traits (and added functionality to implement)
 - [ ] Trait-bounded slots
 - [ ] Dynamic dispatch

# 0.0.5
 - [ ] Parametric types
 - [ ] Extensive semantic analysis to support type inference for parametric types

# 0.0.6
 - [ ] Add "_" to operate as the blank identifier
 - [ ] Add ".." to indicate "the rest" of a pattern
