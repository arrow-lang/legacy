let main() -> {
    let mut a: int = 230;
    let mut c: int = 42;
    ((c)) = 30;
    (if true { a; } else { c; }) = 520 as int;
    assert(c == 30);
    assert(a == 520);
}
