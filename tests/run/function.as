static q: int = 32;

module extra {
    static q76: int = 32;
    def inside() { }
}

def main() {
    static t: int = 32;
    def nested() { }
}

def a() { }
def b() { }
def x() { }
def y() { }
def z() { }

# let mut x: *int = &32;
# let &y = *x;
# assert(y == 32);
# assert(y == *x);
# x == y == z == w
