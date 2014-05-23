# struct Point { x: int, y: int }
# struct Box { value: Point }

# def main() {
#     let value = Point(60, 40);
#     let box = Box(value: value);
#     assert(box.value.x == 60);
# }

def main() {
    # let m = a;
    # let a: *int;
    let mut x = 50;
    let m = &mut x;
    *m = 20;
    assert(x == 20);
}

# struct Name {
#     d: type(e),
#     e: type(b),
#     c: type(Box.x),
#     a: int = Box.x ** 2,
#     b: type(a),
# }

# struct Box { x: int, y: type(Name.d) }

# class Entity {
#     value: int;
#     other: bool;

#     def static_method() {
#     }

#     def method(self) {
#     }
# }
