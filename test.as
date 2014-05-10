# static c: uint = 10;
# static d: uint = 0;
# static mut global_: float32 = 3;
# def main() { let x = c; }

# def main()
# {
#     static a: (x: int, y: bool) = (10, false);
#     static b: (x: int, y: bool) = (y: true, x: 20);
#     static c = (a: 10);
#     static d: (a: int, b: uint);

#     assert(a.x == 10);
#     assert(not a.y);

#     assert(b.x == 20);
#     assert(b.y);
#     assert(main.b.y);

#     assert(c.a == 10);

#     assert(d.a == 0);
#     assert(d.b == 0);
# }

static x: int = 12094;
static mut value: (a: bool,);# = (false,);
static record: (int, uint, int8, uint128);
static v: bool = true;

def main() {
    value.a = false;
    assert(not value.a);
    value.a = true;
    assert(value.a);
}

# static x = -21356;
# static y: bool = false;
# def main() { assert(not (x:x, :y, 10, z: 20).y); }
# # def main() { assert(not (x:x, y:y, 10, z: 20).y); }


# call(10, x: 30, :y)
