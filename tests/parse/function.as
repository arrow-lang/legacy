# Named function declarations begin with the "def" keyword.
def name() { }

# Functions are invoked as follows:
name();

# Parameters are specified comma-delimited inside the parenthesis.
def sum(x: int, y: int, y: int) { }

# Functions pass in parameters much the same way.
sum(53, 3, 23);

# Parameters may be given default values.
# All 3 of these are valid.
def defualt_sum1(x: int = 0, y: int) { }
def defualt_sum2(x: int, y: int = 0) { }
def defualt_sum3(x: int = 0, y: int = 0) { }

# Keyword arguments are supported.
defualt_sum1(y=320);
defualt_sum2(320);
defualt_sum2(x=320);
defualt_sum3(y=320, x=32);

# The return type is specified using an "->" following the parameter list.
def read() -> int { }

# Any non top-level statements may be present in the function block.
def some() -> bool {
    # Declare a couple slots.
    static y: int = 32;
    let x: int = 43;
    let y: int;
    y = 436;

    # Returns may be explicit.
    # return false if x > y;

    # Otherwise the final value of the function is implicitly returned.
    true;
}

# Statics in functions may be accessed.
some.y == 32;

# Functions may be nested in other functions.
def main() {
    def nested() -> int { 432; }
}

# Invoking nested functions.
main.nested();

# Functions are first-class objects and are a valid type for a
# slot declaration.
# static static_fn: def() = name;

# A more complex function type.
# let more_fn: def(int, bool) -> int;

# A function type that takes a function and
# returns a function that returns an int.
# let fn_fn: def(def(int) -> int) -> def(int) -> int;

# A named function that fulfils the above type.
# def fn_fn_named(fn: def(int) -> int) -> def(int) -> int {
#     fn;
# }

# Functions may be declared unnamed and assigned anonymously into
# a slot of the function type. And use all forms of type inference.
# let anon_fn: def() = def() { };
# let anon_fn_type_inferred = def(x: int, y: bool) { };
# anon_fn_type := def(x, y) { x + y; };
# int_fn := def(x) { x; };
# fn_fn_named(int_fn)(32) == 32;
# fn_fn_named(def(x: int) { x; })(32) == 32;
# fn_fn_named(def(x: int) -> int { x; })(32) == 32;
# fn_fn_named(def(x) { x; })(32) == 32;
