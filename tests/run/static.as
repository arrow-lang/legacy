# Declare 3 static slots.
static a: int = 621;
static b: uint = 253232;
static c: bool = false;
static m: float32 = 21e32;

# Declare 2 mutable static slots.
static mut d: uint128 = 24395295902525925312;
static mut e: float64 = 3.12;

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
    static m: float32 = 32.32e-7;
    static n: int32 = 2352532;

    # Define a nested function.
    def nested() {
        # With more static data.
        static m: int = 312;
        static a: bool = true;
    }

    # Assert the values of the "safe" statics.

    # Assert the values of the "unsafe" statics.
    # FIXME: As soon as "unsafe" is implemented this stuff needs to go
    #        in an unsafe block.
    unsafe {
    }
}
