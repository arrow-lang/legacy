# Do some tests.
let main() -> {
    assert(take(10) == 10);
    assert(take(60) == 60);
}

# Return the only argument.
let take(x: int8): int8 -> { x; }
