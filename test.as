static a: int;
def main() {
    static a: bool = true;
    assert(a);
    assert(global.a == 0);
}
