def even(x: uint): bool {
    if x < 2 { false; }
    else if x == 2 { true; }
    else { even(x - 2); };
}

def main() {
    assert(even(2));
    assert(even(300));
    assert(even(512));
    assert(not even(31));
}
