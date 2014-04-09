def main() {
    let mut x: int8 = -12;
    let y: int8 = -12;
    x = x + 1;
    x = x - 1;
    assert(x == y);
}
