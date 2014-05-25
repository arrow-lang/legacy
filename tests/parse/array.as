# Declare some random array expressions using the literal notation.
[];
[4.123];
[1, 2, 3, 4923.312,];
[1, 2, 3];
[false, true];

# Declare various slots for arrays.
let a: int[15];  # 15 of int
let m: bool[4][15];  # 15 of 4 of bool
let t: (int, bool)[10];  # 10 tuples of int and bool

# Utilize.
m[4][41];
m[a[1]][a[2]];
a[4];
a[2];
a[5] = 3420;

# Declare a pointer to a mutable 5 x 5 matrix.
let m: *mut int[5][5];

# Declare a 5 x 5 matrix of pointers.
let m: (*int)[5][5];

# Declare a blob with a matrix.
struct Blob { m: uint[5][5] }
let b: Blob[12];
