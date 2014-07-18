struct Point { x: int, y: int }
struct Box { value: bool }
struct Line { begin: Point, end: Point }

let main() -> {
    let a = Point(30, 60);
    let b = Point(y: 60, x: 30);
    let c = Box(false);
    let d = Box(value: true);

    assert(a.x == 30);
    assert(a.y == 60);
    assert(b.y == a.y);
    assert(b.x == a.x);
    assert(not c.value);
    assert(d.value);

    let m = Line(b, a);
    let n = Line(end: a, begin: b);
    assert(m.begin.x == n.begin.x);
    assert(m.begin.y == n.begin.y);
    assert(m.end.x == n.end.x);
    assert(m.end.y == n.end.y);
}
