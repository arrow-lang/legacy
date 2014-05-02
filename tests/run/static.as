# Declare 3 static slots.
static a: int32 = 621;
static b: uint32 = 253232;
static c: bool = true;
static m: float32 = 410;

# Declare 2 mutable static slots.
static mut d: uint128 = 2439529590252;
static mut e: float64 = 2.0;

# Declare some modules containing static slots.
module extra {
    static a: bool = true;
    static b: bool = false;

    module more {
        static o: uint8 = 210;
        static p: int8 = 122;
    }
}

def main() {
    # Declare a couple statics in here.
    static m: float32 = 32.5;
    static n: int32 = 2352532;

    # Define a nested function.
    def nested() {
        # With more static data.
        static m: int32 = 312;
        static a: bool = true;
    }

    # Assert the values of the "safe" statics.
    # assert(a == 621);
    # assert(b == 253232);
    assert(c);
    # assert(global.m == 410);
    # assert(extra.a);
    # assert(not extra.b);
    # assert(extra.a == true);
    # assert(extra.b == false);
    # assert(extra.more.o == 210);
    # assert(extra.more.p == 122);
    # assert(m == 32.5);
    # assert(n == 2352532);
    # assert(nested.m == 312);
    # assert(nested.a == true);

    # Assert the values of the "unsafe" statics.
    # FIXME: As soon as "unsafe" is implemented this stuff needs to go
    #        in an unsafe block.
    # unsafe {
    # assert(d == 2439529590252);
    # assert(e == 2.0);
    # }
}
