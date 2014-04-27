# Declare a degenerate enumerations.
enum Suit { Clubs, Diamonds, Hearts, Spades }

# Declare a degenerate enumeration where we specify the
# discriminator value manually.
enum Chemical { Hydrogen = 1, Oxygen = 2, Water = 3 }

# Declare a degenerate enumeration where we specify the
# discriminator type manually (it would normally default to
# an integral type large enough to fit all values).
enum Color: int128 { Red, Green, Blue }

# Declare some tagged unions.
enum Option { Some(int), None }
enum Result { Ok(int), Error(int) }
enum List { Nil, Cons(int, List = Nil) }
enum Tree { Leaf, Node(int, Tree = Leaf, Tree = Leaf) }

# Declare some unions with type parameters.
enum Option<T> { Some(T), None }
enum Result<T, E> { Ok(T), Error(E) }
