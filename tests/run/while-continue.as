let main() -> {
    let mut counter: int = 10;
    let mut i: uint = 0;
    while counter > 0 {
        counter = counter - 1;
        if counter < 5 { continue; };
        i = i + 1;
    }
    assert(i == 5);
}
