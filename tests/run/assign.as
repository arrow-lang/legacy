def main() {
    static mut rv = 20;
    static mut rb = 50;
    assert(rv == 20);
    assert(rb == 50);
    rv = rb = 0;
    assert(rv == 0);
    assert(rb == 0);
}
