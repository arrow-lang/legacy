
let nil(val: *int8): *int8 -> {
    if val == 0 as *int8 { return 0 as *int8; };
    return 1 as *int8;
}

let main() -> {
    let null: *int8 = 0 as *int8;
    assert(nil(null) == null);
}
