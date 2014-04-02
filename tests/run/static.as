# Declare 3 static slots.
static a: bool = false;
static b: int = -235;
static c: float64 = 5.12;

# Declare 2 mutable static slots.
static mut d: float32 = 32.1;
static mut e: uint = 66;

# Declare some modules containing static slots.
module extra {
    static a: int = 30;
    static b: bool = true;

    module more {
        static o: uint128 = 9622;
        static p: uint8 = 210;
    }
}

def main() {
    # Declare a couple statics in here.
    static m: int = 30;
    static n: bool = false;

    # Define a nested function.
    def nested() {
        # With more static data.
        static m: float32 = 320.32;
        static a: float64 = 923.23582395;
    }

    extra.a;

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
