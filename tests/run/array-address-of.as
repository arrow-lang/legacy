def main() {
    let x: int[10];
    let p: *int = &x[0];
    assert(p == &x[0]);
    assert(&x[9] - p == 9);
}
