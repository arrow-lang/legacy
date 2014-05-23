def main() {
    let x: int = 10;
    let y: *int = &x;
    let a: *int = &x;
    let z: *int = y;
    let w: **int = &z;

    assert(y == z);
    assert(y == a);
    assert(z != w);
}
