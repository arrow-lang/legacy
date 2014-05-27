def main() {
    # Declare an array of 20 ints.
    let a: int[20];

    # Implicit cast it to an array of 20 floats.
    let f: float32[20] = a;

    # Explicit cast it to an array of 20 ints.
    let u1 = f as int32[20];

    # Declare an array of 1 int8's
    let i: int8[1] = [14];
}
