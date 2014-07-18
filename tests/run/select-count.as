let main() -> {
    let i5 = 5;
    let i7 = 7;

    let mut count: int;

    count = 0;
    if true {
        count = count + 1;
    };

    assert(count == 1);

    count = 0;
    if false {
        count = count + 1;
    };

    assert(count == 0);

    count = 0;
    if i5 < i7 {
        count = count + 1;
    };

    assert(count == 1);

    count = 0;
    if true {
        count = count + 1;
    } else {
        count = count - 1;
    };

    assert(count == 1);

    count = 0;
    if false {
        count = count + 1;
    } else {
        count = count - 1;
    };

    assert(count == -1);
}
