# [x] locally assign functions to slots
# [x] call locally assigned functions
# [ ] 1, 2 in arrays
# [ ] 1, 2 in function parameters
# [ ] extern functions
# [ ] attached functions
# [x] typename
# [x] type_common
# [ ] ^ with arguments


def strange(): delegate(int, bool) -> delegate(bool) -> { }

extern def puts(str);
def print() { puts("Hello World"); }
# def some()
# def print_2() { puts("Hello World 2"); }

def main() {
    let m = print;
    let mut m2 = print;
    let x: delegate(int);
    # m2 = m;
    # m();
    # m2();
    # m();
    # (m if false else m2)();
    # m3();
}
