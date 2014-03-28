# Declare some "new" types
# Think of these as "strong" typedefs from C.
type Inches = int;
type Seconds = float64;

# Declare slots of these by using the type or record constructor provided.
a := Inches(32);
b := Seconds(62);

# An explicit cast can be used to get at the source type.
ai2 = a as int;
bi2 = b as float64;
