foreign "C" import "stdlib.h";
foreign "C" import "stdio.h";
foreign "C" import "string.h";

# Arena allocation
# -----------------------------------------------------------------------------
# The basic idea is that the arena is this giant buffer that is ever-growing.
# It is not deallocated until program termination.

# The data buffer; the "arena".
let mut _data: ^int8 = 0 as ^int8;

# The current size of the arena.
let mut _size: uint = 0;

# The current capacity of the arena.
let mut _capacity: uint = 0;

# A store is a "handle" to data managed on the arena.
type Store { _data: ^int8, _size: uint }

# reserve -- Ensure that there is 'n' bytes of space on the arena.
# -----------------------------------------------------------------------------
def reserve(mut n: uint) {
    # Check existing capacity and short-circuit if
    # we are already at a sufficient capacity.
    if n <= _capacity { return; }

    # Ensure that we reserve space in chunks of 4 KiB.
    n = n + (n % 0x1000);

    # Reallocate memory to the new requested capacity.
    _data = realloc(_data as ^void, n) as ^int8;

    # Update capacity.
    _capacity = n;
}

# alloc -- Allocate 'n' bytes of 'data' in the arena.
# -----------------------------------------------------------------------------
def alloc(n: uint) -> Store {
    # Ensure that there is enough capacity in the arena.
    if _size + n >= _capacity { reserve(_size + n); }

    # Build the data handle.
    let data: Store;
    data._data = _data + _size;
    data._size = n;

    # Increment the arena size.
    _size = _size + n;

    # Clear out the data.
    memset(data._data as ^void, 0, n);

    # Return our allocated handle.
    data;
}

# drop -- Drop the entire arena.
# -----------------------------------------------------------------------------
def drop() {
    free(_data as ^void);
    _size = _capacity = 0;
}

# Register the drop on program exit.
atexit(drop);
