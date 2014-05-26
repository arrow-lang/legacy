# Do some tests.
def main() {
    assert(take(10) == 10);
    assert(take(60) == 60);
}

# Return the only argument.
def take(x: int8): int8 { x; }
