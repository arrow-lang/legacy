def main() {
    let m: int16 = 0x7262;
    let p: *int8 = &m as *int8;
    let a = *p;
    let b = *(p + 1);
    assert(a == 0x62);
    assert(b == 0x72);
}
