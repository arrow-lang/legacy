def test_assign() {
    let mut x: int;
    let y: int = x = 10;
    let mut z: int;
    assert(x == 10);
    assert(y == 10);
    z = x = 11;
    assert(x == 11);
    assert(z == 11);
    z = x = 12;
    assert(x == 12);
    assert(z == 12);
}

# def test_assign_op() {
#     let mut x: int = 0;
#     let y: int = x += 10;
#     let mut z;
#     assert(x == 10);
#     assert(y == 10);
#     z = x += 11;
#     assert(x == 21);
#     assert(z == 21);
#     z = x += 12;
#     assert(x == 33);
#     assert(z == 32);
# }

def main() {
    test_assign();
    # test_assign_op();
}
