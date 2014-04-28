# Add a `slap` method to integers.
implement int { def slap(mut self) { self = -self; } }

# Implement the Printable trait.
implement Printable for int { def print(self) { std.print("{}", self); } }
implement Printable for str { def print(self) { std.print("{}", self); } }

# Implement the eq trait.
implement Eq for bool { def equals(self, other: Self) { self == Self; } }
