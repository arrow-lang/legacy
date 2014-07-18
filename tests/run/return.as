# A function that has an explicit return statement returning nothing.
let main() -> {
    one();
    assert(some() == 4);
    assert(that() == 9);
    return;
}

# A function that returns nothing.
let one() -> { }

# A function that explicitly returns something.
let some(): int32 -> { return 4; }

# A function that implicitly returns something.
let that(): int32 -> { 9; }
