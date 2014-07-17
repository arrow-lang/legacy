extern def printf(str, int);

struct Point { x: int, y: int }

implement Point {
    let origin(): Point -> { return Point(0, 0); }

    let print(self) -> {
        printf("(%d", self.x);
        printf(", %d)", self.y);
    }

    let println(self) -> {
        # Point.print(self);
        self.print();
        printf("%c", 0x0a);
    }
}

def main(): int {
    let mut o = Point.origin();
    o.x = 43;
    o.println();
    return 0;
}
