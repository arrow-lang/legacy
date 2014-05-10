def main() {
    # Declare static and local slots for various tuples.
    # -------------------------------------------------------------------------
    static a: (int, bool) = (451, false);
    static b: (int, int,) = (51, 122);
    static d: (uint,) = (72385,);
    let f1: (a: int, b: uint,) = (861, 124);
    static f2s: (a: int, b: uint,) = (b: 124, a: 861);
    let f2: (a: int, b: uint,) = (b: 124, a: 861);
    let f3: (a: int, b: uint,) = (a: 861, b: 124);
    let h: (a: bool, int) = (a: false, 59);
    let i: (int, a: bool) = (69, a: true);

    # Assert: `a`
    # -------------------------------------------------------------------------
    static mut a_0: int;
    static mut a_1: bool;
    (a_0, a_1) = a;
    assert(a_0 == 451);
    assert(not a_1);

    # Assert: `b`
    # -------------------------------------------------------------------------
    let b_0: int;
    let b_1: int;
    (b_0, b_1) = b;
    assert(b_0 == 51);
    assert(b_1 == 122);

    # Assert: `d`
    # -------------------------------------------------------------------------
    let d_0: int;
    (d_0,) = d;
    assert(b_0 == 72385);

    # Assert: `f`
    # -------------------------------------------------------------------------
    let mut f_a: int;
    let mut f_b: uint;
    (f_a, f_b) = f1;
    assert(f_a == 861);
    assert(f_b == 124);
    assert(f1.a == f_a);
    assert(f1.b == f_b);
    assert(f2.a == f_a);
    assert(f2.b == f_b);
    assert(f2s.a == f_a);
    assert(f2s.b == f_b);
    assert(f3.a == f_a);
    assert(f3.b == f_b);
    f_b = 0;
    f_a = 0;
    (b: f_b, a: f_a) = f1;
    assert(f_a == 861);
    assert(f_b == 124);
    assert(f1.a == f_a);
    assert(f1.b == f_b);
    assert(f2.a == f_a);
    assert(f2.b == f_b);
    assert(f2s.a == f_a);
    assert(f2s.b == f_b);
    assert(f3.a == f_a);
    assert(f3.b == f_b);
}
