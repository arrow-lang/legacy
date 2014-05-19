def main() {
    let som = if true { 50; } else { return; };
    assert(som == 50);
    let val = if false { 10; } else { return; };
    assert(false);
}
