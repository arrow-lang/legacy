# Create a product type 'Point'
struct Point { x: int, y: int }

# Use 'Point' in various ways
let mut origin: Point;
origin.x = 3;
(origin.x) = 10;
((&(origin.x))^) = 15;
((origin)).x = 21;

# Create some crazy paths
std.io.stdio.stdout;
((std.io)).stdio.stdout;
