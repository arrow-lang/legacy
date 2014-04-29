# Functions are first-class objects and are a valid type for a
# slot declaration.
static static_fn: def() = name;

# A more complex function type.
let more_fn: def(int, bool): int;

# A function type that takes a function and
# returns a function that returns an int.
let fn_fn: def(def(int): int): def(int): int;

# A named function that fulfils the above type.
def fn_fn_named(fn: def(int): int): def(int): int {
    fn;
}
