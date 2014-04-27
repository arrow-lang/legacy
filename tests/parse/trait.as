# Declare a trait for integers.
trait Integer<T> {
    def add(self: T, y: T) -> T;
    def sub(self: T, y: T) -> T;
}

# Declare a trait for printing.
trait Printable {
    def print(self);
}

# Declare a parameterized trait.
trait Sequence<T> {
    def set(self, index: int);
    def get(self) -> T;
    def size(self) -> uint;
}

# Equality trait.
trait Eq {
    def equals(self, other: Self) -> bool;
}

# Implement the Printable trait.
implement Printable for int { def print(self) { std.print("{}", self); } }
implement Printable for str { def print(self) { std.print("{}", self); } }

# Implement the eq trait.
implement Eq for bool { def equals(self, other: Self) { self == Self; } }
