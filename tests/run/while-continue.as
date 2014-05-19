def main() {
    let mut counter: int = 10;
    while counter > 0 {
        counter = counter - 1;
        if counter < 5 { continue; }
    }
    assert(counter == 4);
}
