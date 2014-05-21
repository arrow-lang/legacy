def question(condition: bool): int {
    # Decide which value to return from this function.
    10 if condition else 20;
}

def main() {
    # Check the value result.
    assert(question(false) == 20);
    assert(question(true) == 10);

    # Decide which variable to set to 20.
    let mut x: int = 10;
    let mut y: int = 10;
    let b: bool = false;
    (x if b else y) = 20;
    assert(y == 20);
    assert(x == 10);

    # Ensure used as assignment works.
    let mut m: int = (231 if b else 32);
    assert(m == 32);

    # Ensure type coercion works.
    let x: float64 = (342.32 if b else 231);
}
