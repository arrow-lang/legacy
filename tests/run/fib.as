def fibonacci(n: int64, a1: int64 = 1, a2: int64 = 1) -> int64 {
    # if n == 0 { a1; }
    # else { fibonacci(n - 1, a2, a1 + a2); }
}

def main() {
    assert(fibonacci( 0) ==               1);
    # assert(fibonacci( 1) ==               1);
    # assert(fibonacci( 2) ==               2);
    # assert(fibonacci( 3) ==               3);
    # assert(fibonacci( 4) ==               5);
    # assert(fibonacci( 5) ==               8);
    # assert(fibonacci( 6) ==              13);
    # assert(fibonacci( 7) ==              21);
    # assert(fibonacci( 8) ==              34);
    # assert(fibonacci( 9) ==              55);
    # assert(fibonacci(10) ==              89);
    # assert(fibonacci(30) ==         1346269);
    # assert(fibonacci(40) ==       165580141);
    # assert(fibonacci(50) ==     20365011074);
    # assert(fibonacci(70) == 308061521170129);
}
