struct Point { x: int32, y: int32 }

let main() -> {
    let nil = 0 as *int8;
    let mut length = (nil + 10) - nil;
    assert(length == 10);

    let nil2 = 0 as *int16;
    let mut length2 = (nil2 + 5) - nil2;
    assert(length2 == 5);

    let nil3 = 0 as *Point;
    let mut length3 = (nil3 + 23) - nil3;
    assert(length3 == 23);
}
