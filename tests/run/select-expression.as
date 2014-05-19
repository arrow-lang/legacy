def main() {
    let x: int = if true { 10; } else { 30; };
    assert(x == 10);

    let y: int = -if x <= 10 { 50; } else { 20; };
    assert(y == -50);
}
