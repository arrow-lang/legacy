struct Point { x: int, y: int }

implement Point {
    let origin(): Point -> { return Point(0, 0); }
}

let main() -> {
    let mut o = Point.origin();
    assert(o.x == 0);
    assert(o.y == 0);
}
