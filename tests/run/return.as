# A function that has an explicit return statement returning nothing.
def main() {
    one();
    assert(some() == 4);
    assert(that() == 9);
    return;
}

# A function that returns nothing.
def one() { }

# A function that explicitly returns something.
def some(): int32 { return 4; }

# A function that implicitly returns something.
def that(): int32 { 9; }
