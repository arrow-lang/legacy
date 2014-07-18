implement bool { let false_(): bool -> { return false; } }
implement int { let zero(): int -> { return 0; } }

struct Point { x: int, y: int }

implement Point {
    let origin(): Point -> { return Point(0, 0); }
}

def main() {
    assert(not bool.false_());
    assert(int.zero() == 0);

    let mut o = Point.origin();
    assert(o.x == 0);
    assert(o.y == 0);
}
