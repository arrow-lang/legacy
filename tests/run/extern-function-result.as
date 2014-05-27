module libc { extern def pow(float64, float64): float64; }
def main() {
    let m = libc.pow(5, 2);
    assert(m == 25);
}
