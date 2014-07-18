module libc { extern def pow(float64, float64): float64; }
let main() -> {
    let m = libc.pow(5, 2);
    assert(m == 25);
}
