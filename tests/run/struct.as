struct Point { x: int, y: int }
struct Box { value: bool }

def main() {
    let a = Point(30, 60);
    let b = Point(y: 60, x: 30);
    let c = Box(false);
    let d = Box(value: true);

    assert(a.x == 30);
    assert(a.y == 30);
    assert(b.y == a.y);
    assert(b.x == a.x);
    assert(not c.value);
    assert(d.value);
}
