struct Point { x: int32, y: int32 }

def main() {
    let nil = 0 as *int8;
    let mut length = (nil + 10) - nil;
    assert(length == 10);
    let o: Point;
    length = ((&o + 1) - &o);
    assert(length >= 8);
}
