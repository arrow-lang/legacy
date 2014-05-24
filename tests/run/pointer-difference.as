struct Point { x: int32, y: int32 }

def main() {
    let nil = 0 as *int8;
    let mut length = (nil + 10) - nil;
    assert(length == 10);
    let nil2 = 0 as *int16;
    let mut length2 = (nil2 + 5) - nil2;
    assert(length2 == 5);
}
