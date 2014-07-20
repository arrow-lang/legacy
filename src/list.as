import libc;
import types;

# List
# =============================================================================
# A pseudo-generic dynamic list that works for any type defined in `types.as`.
#
# NOTE: `.dispose` must be called on a "used" list in order to deallocate
#       any used memory.
#
# TODO: Allow creation with a specific element size (instead of the tag)
# TODO: set_*
# TODO: contains_*
# TODO: push_str, push_ptr
# TODO: get_str, get_ptr
# TODO: pop_*
# TODO: remove_*
# TODO: contains_*
# TODO: empty
# TODO: clear
# TODO: insert_*

struct List {
    tag: int,
    element_size: uint,
    size: uint,
    capacity: uint,
    elements: *mut int8
}

implement List {

    # Construct a new list (and remember the contained element type).
    # -------------------------------------------------------------------------
    let new(tag: int): List -> {
        return List(tag: tag,
                    element_size: types.sizeof(tag),
                    size: 0,
                    capacity: 0,
                    elements: 0 as *mut int8);
    }

    # Perform a clone of the list and return the list.
    # -------------------------------------------------------------------------
    let clone(self): List -> {
        # Make the new list.
        let mut res = List.new(self.tag);

        # Reserve enough space.
        res.reserve(self.capacity);

        # If this is a simple list then just do a `memcpy`.
        if not types.is_disposable(self.tag) {
            libc.memcpy(res.elements, self.elements,
                        self.size * self.element_size);
            res.size = self.size;
        } else {
            # We need to do it the long way.
            let mut i: int = 0;
            while i as uint < self.size {
                res.push(self.get(i));
                i = i + 1;
            }
        };

        # Return the list.
        res;
    }

    # Reserve additional memory for `capacity` elements to be pushed onto
    # the list. This allows for O(1) insertion if the number of elements
    # is known before a series of `push` statements.
    # -------------------------------------------------------------------------
    let reserve(mut self, capacity: uint) -> {
        # Check existing capacity and short-circuit if
        # we are already at a sufficient capacity.
        if capacity <= self.capacity { return; };

        # Ensure that we reserve space in chunks of 10 and update capacity.
        self.capacity = capacity + (10 - (capacity % 10));

        # Reallocate memory to the new requested capacity.
        self.elements = libc.realloc(self.elements,
                                     capacity * self.element_size);
    }

    # Dispose of the resources used by this dynamic list.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> {
        # If the underylying type needs to be disposed ..
        if types.is_disposable(self.tag) {
            # Iterate through each element and free its memory.
            let mut i: uint = 0;
            let mut x: **int8 = self.elements as **int8;
            while i < self.size {
                libc.free(*x);
                x = x + 1;
                i = i + 1;
            }
        };

        # Free the memory used for the list.
        libc.free(self.elements);
    }

    # Push an element onto the list. The list is expanded if there is not
    # enough room.
    # -------------------------------------------------------------------------
    let push(mut self, element: *int8) -> {
        # Request additional memory if needed.
        if self.size == self.capacity { self.reserve(self.capacity + 1); };

        # Move element into the container.
        libc.memcpy(self.elements + self.size * self.element_size,
                    element, self.element_size);

        # Increment size to keep track of element insertion.
        self.size = self.size + 1;
    }

    let   push_i8(mut self, el:   int8) -> { self.push(&el as *int8); }
    let  push_i16(mut self, el:  int16) -> { self.push(&el as *int8); }
    let  push_i32(mut self, el:  int32) -> { self.push(&el as *int8); }
    let  push_i64(mut self, el:  int64) -> { self.push(&el as *int8); }
    let push_i128(mut self, el: int128) -> { self.push(&el as *int8); }

    let   push_u8(mut self, el:   uint8) -> { self.push(&el as *int8); }
    let  push_u16(mut self, el:  uint16) -> { self.push(&el as *int8); }
    let  push_u32(mut self, el:  uint32) -> { self.push(&el as *int8); }
    let  push_u64(mut self, el:  uint64) -> { self.push(&el as *int8); }
    let push_u128(mut self, el: uint128) -> { self.push(&el as *int8); }

    let  push_int(mut self, el:  int) -> { self.push(&el as *int8); }
    let push_uint(mut self, el: uint) -> { self.push(&el as *int8); }

    let push_char(mut self, el: char) -> { self.push(&el as *int8); }

    # Get an element at `index` from the start of the list (negative indicies
    # offset from the size of the list). Attempting to access an element
    # out-of-bounds of the current size is undefined.
    # -------------------------------------------------------------------------
    let get(self, index: int): *int8 -> {
        # Handle negative indexing.
        let mut _index: uint =
            if index < 0 { self.size - ((-index) as uint); }
            else         { index as uint; };

        # Return the element offset.
        return (self.elements + (_index * self.element_size)) as *int8;
    }

    let   get_i8(self, idx: int):   int8 -> { return *self.get(idx); }
    let  get_i16(self, idx: int):  int16 -> { return *(self.get(idx) as *int16); }
    let  get_i32(self, idx: int):  int32 -> { return *(self.get(idx) as *int32); }
    let  get_i64(self, idx: int):  int64 -> { return *(self.get(idx) as *int64); }
    let get_i128(self, idx: int): int128 -> { return *(self.get(idx) as *int128); }

    let   get_u8(self, idx: int):   uint8 -> { return *self.get(idx); }
    let  get_u16(self, idx: int):  uint16 -> { return *(self.get(idx) as *uint16); }
    let  get_u32(self, idx: int):  uint32 -> { return *(self.get(idx) as *uint32); }
    let  get_u64(self, idx: int):  uint64 -> { return *(self.get(idx) as *uint64); }
    let get_u128(self, idx: int): uint128 -> { return *(self.get(idx) as *uint128); }

    let get_int(self, idx: int): int -> { return *(self.get(idx) as *int); }
    let get_uint(self, idx: int): uint -> { return *(self.get(idx) as *uint); }

    let get_char(self, idx: int): char -> { return *(self.get(idx) as *char); }

    # Erase the element at `index` in the list. This is O(1) for elements
    # at the end of the list and O(n) for any other element (where `n` is
    # the number of elements between the erased element and the end of the
    # list).
    # -------------------------------------------------------------------------
    let erase(mut self, index: int) -> {
        let mut _index: uint;
        let el_size: uint = self.element_size;

        # Handle negative indexing.
        if index < 0 { _index = self.size - ((-index) as uint); }
        else         { _index = index as uint; };

        # If we're dealing with a disposable type, we need to free
        if types.is_disposable(self.tag) {
            let x: **int8 = (self.elements + (_index * el_size)) as **int8;
            libc.free(*x);
        };

        if _index < self.size - 1 {
            # Move everything past index one place to the left,
            # overwriting index.
            libc.memmove((self.elements + (_index * el_size)),
                         (self.elements + ((_index + 1) * el_size)),
                         (self.element_size * (self.size - (_index + 1))) as int32);
        };

        # Decrement the size to keep track of the element erasure.
        self.size = self.size - 1;
    }

}

# Test driver
# =============================================================================

extern def printf(str, int8);

let main() -> {
    let mut l = List.new(types.I8);
    l.push_i8(12);
    l.push_i8(62);
    l.push_i8(82);
    assert(l.get_i8(0) == 12);
    assert(l.get_i8(-1) == 82);
    assert(l.get_i8(2) == 82);
    assert(l.get_i8(1) == 62);
    assert(l.size == 3);
    l.erase(-1);
    assert(l.size == 2);
    let ln = l.clone();
    assert(ln.size == 2);
    assert(ln.get_i8(-1) == 62);
    l.dispose();
}
