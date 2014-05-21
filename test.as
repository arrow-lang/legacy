struct Point { x: int, y: int }
struct Box { value: Point }

def main() {
    let value = Point(60, 40);
    let box = Box(value: value);
    assert(box.value.x == 60);
}
