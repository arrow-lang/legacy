# Named function declarations begin with the "def" keyword.
def name() { }

# Parameters are specified comma-delimited inside the parenthesis.
def sum(x: int, y: int, y: int) { }

# Parameters may be given default values.
# All 3 of these are valid.
def defualt_sum1(x: int = 67, y: int) { }
def defualt_sum2(x: int, y: int = 0) { }
def defualt_sum3(x: int = 0, y: int = 0) { }

# The return type is specified using an ":" following the parameter list.
def read(): int { }

# Any non top-level statements may be present in the function block.
def some(): bool {
    # Declare a couple slots.
    static y: int = 32;
    let x: int = 43;
    let y: int;
    y = 436;

    # Returns may be explicit.
    # Otherwise the final value of the function is implicitly returned.
    true;
}

# Functions may be nested in other functions.
def main() {
    def nested(): int { 432; }
}

# Functions may be parameterized much like types.
def some<T>(a: T) { }

# Function parameters do not need to give the typename.
def add(a, b) { a + b; }
#=> def add<U, T: Add<U>>(a: T, b: U): type(a + b) { a + b; }
