def that(mut x: int) -> int {
    x = x + x;
    x = x * x;
}

def main() {
    assert(that(10) == 400);
    assert(that(50) == 10000);
    assert(that(80) == 25600);
}
