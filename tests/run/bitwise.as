def main() {
    let mut a: int = 1;
    let mut b: int = 2;
    a = a ^ b;
    b = b ^ a;
    a = a ^ b;
    assert(b == 1);
    assert(a == 2);
    assert(!0xf0 & 0xff == 0xf);
    assert(0xf0 | 0xf == 0xff);
    assert(0b1010_1010 | 0b0101_0101 == 0xff);
}
