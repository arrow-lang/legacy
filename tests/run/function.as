module extra {
    # Declare a function inside a module.
    def inside() -> bool { return false; }
}

# Declare a series of functions.
def a() -> bool { return false; }
def b() -> bool { return false; }
def x() -> bool { return true; }
def y() -> bool { return false; }
def z() -> bool { return false; }

# Declare the `main` function.
def main() {
    # Declare a function inside a function.
    def nested() -> bool { return true; }

    # Assert some values that the functions return.
    assert(x());
    # assert(nested());
    # assert(not y());
    # assert(not b());
    # assert(main.nested());
    # assert(not extra.inside());

    # Explicitly return nothing.
    return;
}
