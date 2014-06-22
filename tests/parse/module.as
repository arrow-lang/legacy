# Declare a module.
module math {

    # Declare a type in this module.
    struct Point { x: int, y: int }

    # Declare a few variables in this module.
    static a: int = 23;
    let b: float64 = 42.2;
    let mut o: Point;

    # Declare a function in this module.
    def pow(a: float64, mut i: uint): float64 { }

}

def main() {

    # Declare a variable of a type from the module.
    let o: math.Point;

    # Invoke a function from the module.
    let result: float64 = math.pow(math.b, 2);

}
