def main() {
    let mut counter: int = 10;
    while counter > 0 {
        if counter <= 5 { break; };
        counter = counter - 1;
    }
    assert(counter == 5);
}
