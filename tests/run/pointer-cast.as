def main() {
    let x: *int = (0xBA000 as *int);
    let y: int = (x as int);
    assert(y == 0xBA000);
}
