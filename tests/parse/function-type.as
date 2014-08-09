# Functions are first-class objects and are a valid type for a
# slot declaration.
let static_fn: delegate() = name;

# A more complex function type.
let more_fn: delegate(int, bool) -> int;

# A function type that takes a function and
# returns a function that returns an int.
let fn_fn: delegate(delegate(int) -> int) -> delegate(int) -> int;

# A named function that fulfils the above type.
let fn_fn_named(fn: delegate(int) -> int): (delegate(int) -> int) -> {
    fn;
}
