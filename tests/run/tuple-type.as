struct Thing { }

let main() -> {
    # Declare a tuple of basic types.
    let a: (int,);
    let b: (bool, int);
    let c: (float64, int);

    # Declare a tuple of a pointer to an array of pointers.
    let w: (*(*int)[1],);
}
