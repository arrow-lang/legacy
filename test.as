# struct Point { x: int, y: int }
# struct Box { value: Point }

# def main() {
#     let value = Point(60, 40);
#     let box = Box(value: value);
#     assert(box.value.x == 60);
# }

def main() {

    let m = 10;
    let pm = &m;
    let pm2 = pm + 1;
    let pm3 = (pm2 + 1) + 1;

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
