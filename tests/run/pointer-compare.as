let main() -> {
    let x: int = 10;
    let y: *int = &x;
    let a: *int = &x;
    let z: *int = y;
    let w: **int = &z;
    let e: **int = &a;

    assert(y == z);
    assert(y == a);
    assert(e != w);
}
