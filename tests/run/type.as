let main() -> {
    # Assert the values of the static slots.
    assert( s2 == false);
    assert(s18 == 12);
    assert(s21 == s5);
    assert( s5 == 186);
    assert(s12 == 15);
    assert(s16 == 31);
    assert( s9 == s8);
    assert(s10 == 235);
    assert( s0 == true);
    assert(s13 == 682);
    assert(s11 == false);
    assert(s14 == 682);
    assert( s1 == true);
    assert(s15 == 42);
    assert( s6 == 625789);
    assert( s7 == 31);
    assert( s3 == false);
    assert( s8 == 12);
    assert(s23 == 3012);
    assert(s17 == 15);
    assert( s4 == true);
    assert(s19 == 12);
    assert(s20 == 31);

#     # Assert some type properties of various expressions.
#     assert(type(s1).size() >= 1);
#     assert(type(s2).size() >= 1);
#     assert(type(s3).size() >= 1);
#     assert(type(s4).size() == type(bool).size());
#     assert(type(s5).size() >= 8);
#     assert(type(s6).size() == 16);
#     assert(type(s7).size() == 8);
#     assert(type(s8).size() == 4);
#     assert(type(s9).size() == 4);
#     assert(type(s10).size() == 4);
#     assert(type(type(s10).size()).size() >= 4);

#     # Assert some properties of various typenames.
#     assert(type(int8).size() == 8);
#     assert(type(int16).size() == 16);
#     assert(type(int32).size() == 32);
#     assert(type(int64).size() == 64);
#     assert(type(int128).size() == 128);
#     assert(type(uint8).size() == 8);
#     assert(type(uint16).size() == 16);
#     assert(type(uint32).size() == 32);
#     assert(type(uint64).size() == 64);
#     assert(type(uint128).size() == 128);
#     assert(type(bool).size() >= 1);

#     # Assert type equivalence of various expressions.
#     # NOTE: Type equality is `strict`; eg. `def(bool) -> bool` is technically
#     #       compatible with `type(neg)` but `type(neg) == type(def(bool) -> bool)`
#     #       is false.
#     assert(type(s1) == type(s2));
#     assert(type(s1) == type(bool));
#     assert(type(s3) == type(s4));
#     assert(type(int32) == type(int32));
#     assert(type(bool) == type(bool));
#     assert(type(float32) == type(float32));
#     assert(type(float32) == type(s8));
#     assert(type(int32) == type(s10));
#     assert(type(type(s10).size()) == type(uint64));  # FIXME: This should be `uint` once we get machine types
#     assert(type(assert(false)) == type(bool));
#     assert(type(that()(a=s2)) == type(bool));
#     assert(type(that()) == type(neg));
#     assert(type(that) == type(that));

#     # Assert that `that` returns `neg` properly.
#     assert(that()(a=s2));

#     # TODO: Assert typenames once `type(..).name()` is a thing
}

# Declare a function that returns the `neg` function.
# def that() -> type(neg) { neg; }

# Declare a function that negates its argument that is bound to the type
# of a static declared below.
# def neg(a: type(s2)) -> type(not a) { not a; }

# Declare some static slots that are deferred to various expressions.
static  s2: type(s11 or false) = false;
static s18: type(s5 % s14) = 12;
static s21: type(s5) = s5;
static  s5: type(20) = 186;
static s12: type(1.21) = 15;
static s16: type(s13 / s8) = 31;
static  s9: type(s8 * s8) = s8;
static s10: type(s8 // s8) = 235;
static  s0: bool = true;
static s13: type(s5 + s14) = 682;
static s11: type(s0) = false;
static s14: uint32 = 682;
static  s1: type(false) = true;
static s15: type(s13 * s8 + s6) = 42;
static  s6: uint128 = 625789;
static  s7: type(10 / s5) = 31;
static  s3: type(type(s2)) = false;
static  s8: type(float32) = 12;
static s23: type(s8) = 3012;
static s17: type(s13 // s8) = 15;
static  s4: type(not s2) = true;
static s19: type(s5 % s8) = 12;
static s20: type(20 / 30) = 31;
