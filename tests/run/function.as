module extra {
    # Declare a function inside a module.
    let inside(): bool -> { return false; }
}

# Declare a series of functions.
let a(): bool -> { return false; }
let b(): bool -> { return false; }
let x(): bool -> { return true; }
let y(): bool -> { return false; }
let z(): bool -> { return false; }

# Declare the `main` function.
let main() -> {

    # Assert some values that the functions return.
    assert(x());
    assert(not y());
    assert(not b());
    assert(not extra.inside());

    # Explicitly return nothing.
    return;
}
