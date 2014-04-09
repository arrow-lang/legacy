
# Introduce a random block that should do nothing.
def f() -> int {
    {
        3;
    }
}

# Test that f is 3
def main() { assert(f() == 3); }
