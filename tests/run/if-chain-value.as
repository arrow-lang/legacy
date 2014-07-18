let main() -> {
    let mut condition: bool = false;
    if condition == false {
        assert(not condition);
        condition = true;
    } else if condition != true {
        condition = true;
    };
    assert(condition);
}
