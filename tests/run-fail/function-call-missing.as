let some(a: int): int -> { a; }
let that(a: int, b: bool): int -> { a; }
let main() -> {
    some();
    that(b: false);
    that();
}
