def test_bool() {
    assert(true == true);
    assert(false <> true);
    assert(not true == false);

    assert(not true < false);
    assert(not true <= false);
    assert(true > false);
    assert(true >= false);

    assert(false < true);
    assert(false <= true);
    assert(not false > true);
    assert(not false >= true);

    assert(not false > true and not true < false);
    assert(false > true or true > false);
    assert(false < true and true > false);
    assert(not false and true);
    assert(true and not false);

    assert(false > true or true);
    assert(true or false > true);
    assert(not true or true);
    assert(true or not true);
}

def test_int() {
    assert(12 == 12);
    assert(12 <> 40);
    assert(not 12 == 40);

    assert(12 < 40);
    assert(40 > 12);
    assert(40 >= 40);
    assert(40 >= 34);
    assert(32 <= 32);
    assert(12 <= 32);

    assert(50 > 20 or 30 < 20);
    assert(not 40 == 30 and 30 > 20);
}

def main() {
    test_bool();
    test_int();
}
