# Declare an array of 20 ints.
# let a: int[20];

# Utilize the array.
a[2];
a[5] = 3420;

# Declare an array of 10 tuples.
# let b: (int, bool)[10];

# Declare an array of 5 functions.
# let c: def()[5];

# Declare an array of 5 arrays of 45 functions.
# let d: (def() -> int)[45][5];

# Utilize the array.
(d)[4][41];
d[a[1]][a[2]];

# Declare a reference to a 5 x 5 matrix.
# let &m: int[5][5];
# let &m: int[5][5];

# Declare a pointer to a 5 x 5 matrix of mutable pointers.
# let m: *mut int[1];

# Declare a 5 x 5 matrix of pointers.
# let m: (*int)[5][5];

# Declare an array of 10 things.
# struct Thing { }
# let t: Thing[5 * 2];

# Declare a blob with a matrix.
# struct Blob { m: uint[5][5] }
# let b: Blob[12];
