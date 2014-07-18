
extern def printf(str, int);

struct Point {
    x: int,
    y: int,
}

implement Point {
    let println(self) -> {
        printf("(%d, ", self.x);
        printf("%d)", self.y);
        printf("%c", 0x0a);
    }
}

let println_all(points: Point[2]) -> {
    Point.println(points[0]);
    Point.println(points[1]);

    # FIXME: Man #11 is going to fix a lot
    # points[0].println();
    # points[1].println();
}

let main() -> {
    println_all([
        Point(5, 20),
        Point(15, 69),
    ]);
}
