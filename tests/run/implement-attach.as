implement bool { false_(): bool -> { return false; } }
implement int { zero(): int -> { return 0; } }

struct Point { x: int, y: int }

implement Point {
    origin(): Point -> { return Point(0, 0); }
    x_intercept(y: int): Point -> { return Point(:y, x: 0); }
    y_intercept(x: int): Point -> { return Point(:x, y: 0); }
}

def main() {
# let main() -> {
    assert(not bool.false_());
    assert(int.zero() == 0);
    assert(Point.origin().x == 0);
    assert(Point.origin().y == 0);
    assert(Point.x_intercept(10).y == 10);
    assert(Point.x_intercept(10).x == 0);
    assert(Point.y_intercept(10).y == 0);
    assert(Point.y_intercept(10).x == 10);
}
