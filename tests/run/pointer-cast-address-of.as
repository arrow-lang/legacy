def main() {
    let m: int16 = 0x7262;
    let p: *int8 = &(m as *int8);
    assert(m as *int8 == p);
}
