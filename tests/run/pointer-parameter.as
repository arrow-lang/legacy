def take(ref: *mut int) {
    assert(*ref == 10);
    *ref = 450;
}

def main() {
    let a = 10;
    let b = &a;
    take(b);
    assert(*b == 450);
}
