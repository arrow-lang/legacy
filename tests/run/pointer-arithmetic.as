
extern def malloc(uint): *mut uint8;
extern def free(*uint8);

def magic(mut m: *mut uint8): uint {
    # Increment the pointer.
    m = m + 1;

    # Set some memory.
    *m = 21;

    # Check it.
    assert(*m == 21);

    # Increment the pointer (again).
    m = m + 1;

    # Check it (again).
    assert(*(m - 1) == 21);

    # Decrement the pointer.
    m = m - 2;

    # Check it (again, again).
    assert(*(m + 1) == *(m + 1));
    assert(*(m + 1) == 21);
    assert( (m + 1) == m + 1);

    # We win.
    42;
}

def main() {
    # Allocate a 10-byte buffer.
    let mut m = malloc(10);

    # Set values.
    let mut counter = 0;
    while counter < 9 {
        *(m + counter) = counter;
        counter = counter + 1;
    }

    # Perform magic.
    magic(m);

    # Free the buffer.
    free(m);
}