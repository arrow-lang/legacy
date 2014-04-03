# Declare 3 static slots.
static a: int8 = 21;
static b: int8 = -23;
static c: int8 = 5;

# Declare 2 mutable static slots.
static mut d: int8 = 32;
static mut e: int8 = 66;

# Declare some modules containing static slots.
module extra {
    static a: int8 = 30;
    static b: int8 = 32;

    module more {
        static o: int8 = 22;
        static p: int8 = 10;
    }
}

def main() -> int8 {
    # Declare a couple statics in here.
    static m: int8 = 30;
    static n: int8 = 12;

    # Define a nested function.
    # def nested() {
    #     # With more static data.
    #     static m: float32 = 320.32;
    #     static a: float64 = 923.23582395;

    # }

    extra.more.p + extra.more.p + d + e + c + extra.a;

    # Assert the values of the "safe" statics.
    # assert(a == false);
    # assert(b == -235);
    # assert(c == 5.12);
    # assert(extra.a == 30);
    # assert(extra.b == true);
    # assert(extra.more.o == 9622);
    # assert(extra.more.p == 210);
    # assert(m == 30);
    # assert(main.m == 30);
    # assert(n == false);
    # assert(main.n == false);
    # assert(main.nested.m == 320.32);
    # assert(main.nested.a == 920.23582395);
    # assert(nested.m == 320.32);
    # assert(nested.a == 920.23582395);

    # Assert the values of the "unsafe" statics.
    # FIXME: As soon as "unsafe" is implemented this stuff needs to go
    #        in an unsafe block.
    # assert(d == 32.1);
    # assert(e == 66);
}
