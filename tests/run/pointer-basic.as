def main() {
    let a:  int = 10;
    let b: *int = &a;
    let c:  int = *b;
    assert(c == a);
}
