def main() {
    let a: int8 = 32;
    let b: int8 = 63;
    let mut m: (*int8)[2];
    m[0] = a;
    m[1] = b;
    assert(m[0] == 32);
    assert(m[1] == 63);
}
