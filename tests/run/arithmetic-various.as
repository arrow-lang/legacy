def main() {
    static a: int128 = 10;
    assert(a == a);
    assert(a - 10 == 0);
    assert(a // 10 == 1);
    assert(a * 16 == 160);
    assert(a * a * a == 1000);
    assert(a * a * a * a == 10000);
    assert(a * a // a * a == 100);
    # assert(a * a // a * a == 100);

    static b: int32 = 0x10101010;
    assert(b + 1 - 1 == b);
}
