def main() {
    let mut condition: bool = false;
    if condition == false {
        assert(not condition);
        condition = true;
    };
    assert(condition);
}
