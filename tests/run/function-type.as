# Declare a function that prints something.
def printer() { printf("Hello\n"); }

# Declare a named function that takes a function.
def call_twice(fn: def()) { fn(); fn(); }

# Declare a function that takes and returns an int.
def some(x: int): int { x; }

# Declare a named function that returns a function.
def that(): def(int): int { some; }

def main() {
    # Declare a slot for a function type that takes and returns an int.
    let action: def(int): int = that();

    # Declare a slot for a function that takes and returns nothing.
    let pure: def() = printer;

    # Invoke the higher-order function to call us twice.
    call_twice(printer);
    call_twice(pure);

    # Print the result of returning.
    printf("%d\n", action(3210));
    printf("%d\n", that()(3210));
}
