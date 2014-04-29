# Declare an array of 20 ints.
let a: int[20];

# Utilize the array.
a[2];
a[5] = 3420;

# Declare an array of 10 tuples.
let b: (int, bool)[10];

# Utilize a crazy array.
(d)[4][41];
d[a[1]][a[2]];

# Declare an array of 10 things.
struct Thing { }
let t: Thing[5 * 2];

# Declare a blob with a matrix.
struct Blob { m: uint[5][5] }
let b: Blob[12];
