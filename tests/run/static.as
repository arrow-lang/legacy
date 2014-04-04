# Declare 3 static slots.
static a: bool = false;
static b: bool = true;
static c: bool = false;
static m: bool = false;

# Declare 2 mutable static slots.
static mut d: bool = true;
static mut e: bool = false;

# Declare some modules containing static slots.
module extra {
    static a: bool = true;
    static b: bool = false;

    module more {
        static o: bool = false;
        static p: bool = true;
    }
}

def main() {
    # Declare a couple statics in here.
    static m: bool = true;
    static n: bool = false;

    # Define a nested function.
    def nested() {
        # With more static data.
        static m: bool = false;
        static a: bool = true;
    }

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
