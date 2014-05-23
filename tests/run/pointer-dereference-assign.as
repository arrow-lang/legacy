def main() {
    let mut a = 230;
    let mut b = &a;
    *b = 30;
    assert(a == 30);
    assert(*b == 30);
    ((*b)) = 610;
    assert(a == 610);
    assert(*b == 610);
}
