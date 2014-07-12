def main() {
    let mut rv = 20;
    let mut rb = 50;
    assert(rv == 20);
    assert(rb == 50);
    rv = rb = 0;
    assert(rv == 0);
    assert(rb == 0);
}
