import libc;
import types;

# List
# -----------------------------------------------------------------------------
# A pseudo-generic dynamic list that works for any type defined in `types.as`.
#
# NOTE: `.dispose` must be called a "used" list in order to deallocate
#       any used memory.
#
# - [ ] Add .iter()
# - [ ] Add .index_*(<el>) and use it to implement the internals of .remove and .contains
# - [ ] Add .count_*(<el>) because python has it on their lists
# - [ ] Add .shift_*() -- Removes the first element from and returns it.
# - [ ] Add .unshift_*(<el>) -- Prepend an element to the vector.
# - [ ] Add .pop_*() -- Removes the last element from a vector and returns it
# - [ ] Add .reverse() -- python has it
# - [ ] Add .sort() -- python has it
# - [ ] Add .truncate(<size>) -- Shorten a vector, dropping excess elements.
# - [ ] Add .unique() -- de-duplicate the list (c++ has it)
# - [ ] Consider renaming `push` to `append` so its cousin `extend` could be added nicely

type List {
    mut tag: int,
    mut element_size: uint,
    mut size: uint,
    mut capacity: uint,
    mut elements: ^mut int8
}

def make(tag: int) -> List {
    let list: List;
    list.tag = tag;
    list.element_size = types.sizeof(tag);
    list.size = 0;
    list.capacity = 0;
    list.elements = 0 as ^int8;
    list;
}

def make_generic(size: uint) -> List {
    let list: List;
    list.tag = 0;
    list.element_size = size;
    list.size = 0;
    list.capacity = 0;
    list.elements = 0 as ^int8;
    list;
}

implement List {

    # Dispose of the memory managed by this list.
    # -------------------------------------------------------------------------
    def dispose(&mut self) {
        # If the underlying type is disposable then enumerate and dispose
        # each element.
        if types.is_disposable(self.tag) {
            let mut i: uint = 0;
            let mut x: ^^int8 = self.elements as ^^int8;
            while i < self.size {
                libc.free(x^ as ^void);
                x = x + 1;
                i = i + 1;
            }
        }

        # Free the contiguous chunk of memory used for the list.
        libc.free(self.elements as ^void);
    }

    # Perform a deep clone of the list and return the list.
    # -------------------------------------------------------------------------
    def clone(&self) -> List {
        # Make the new list.
        let mut new: List = make(self.tag);

        # Reserve enough space.
        new.reserve(self.capacity);

        # If this is a simple (no managed memory) list then just do a `memcpy`.
        if not types.is_disposable(self.tag) {
            libc.memcpy(new.elements as ^void, self.elements as ^void,
                        self.size * self.element_size);
            new.size = self.size;
            void;
        } else {
            # We need to do it the long way.
            if self.tag == types.STR {
                let mut i: int = 0;
                while i as uint < self.size {
                    new.push_str(self.at_str(i));
                    i = i + 1;
                }
            }
        }

        # Return the new list.
        new;
    }

    # Reserve additional memory for `capacity` elements to be pushed onto
    # the list. This allows for O(1) insertion if the number of elements
    # is known before a series of `push` statements.
    # -------------------------------------------------------------------------
    def reserve(&mut self, capacity: uint) {
        # Check existing capacity and short-circuit if
        # we are already at a sufficient capacity.
        if capacity <= self.capacity { return; }

        # Ensure that we reserve space in chunks of 10.
        capacity = capacity + (10 - capacity % 10);

        # Reallocate memory to the new requested capacity.
        self.elements = libc.realloc(
            self.elements as ^void, capacity * self.element_size) as ^int8;

        # Update capacity.
        self.capacity = capacity;
    }

    # Push an element onto the list. The list is expanded if there is not
    # enough room.
    # -------------------------------------------------------------------------
    def push(&mut self, el: ^void) {
        # Delegate if we can't handle it here.
        if self.tag == types.STR { self.push_str(el as str); return; }

        # Request additional memory if needed.
        if self.size == self.capacity { self.reserve(self.capacity + 1); }

        # Move element into the container.
        libc.memcpy((self.elements + (self.size * self.element_size)) as ^void,
                    el, self.element_size);

        # Increment size to keep track of element insertion.
        self.size = self.size + 1;
    }

    def push_i8  (&mut self, el:   int8)  { self.push(&el as ^void); }
    def push_i16 (&mut self, el:  int16)  { self.push(&el as ^void); }
    def push_i32 (&mut self, el:  int32)  { self.push(&el as ^void); }
    def push_i64 (&mut self, el:  int64)  { self.push(&el as ^void); }
    def push_i128(&mut self, el: int128)  { self.push(&el as ^void); }
    def push_u8  (&mut self, el:   int8)  { self.push(&el as ^void); }
    def push_u16 (&mut self, el:  int16)  { self.push(&el as ^void); }
    def push_u32 (&mut self, el:  int32)  { self.push(&el as ^void); }
    def push_u64 (&mut self, el:  int64)  { self.push(&el as ^void); }
    def push_u128(&mut self, el: int128)  { self.push(&el as ^void); }
    def push_int (&mut self, el:    int)  { self.push(&el as ^void); }
    def push_uint(&mut self, el:   uint)  { self.push(&el as ^void); }

    def push_ptr (&mut self, el:  ^void)  {
        # Request additional memory if needed.
        if self.size == self.capacity { self.reserve(self.capacity + 1); }

        # Move the element into the container.
        let elp: ^^void = self.elements as ^^void;
        let elx: ^^void = elp + self.size;
        elx^ = el;

        # Increment size to keep track of element insertion.
        self.size = self.size + 1;
    }

    def push_str (&mut self, el: str) {
        # Request additional memory if needed.
        if self.size == self.capacity { self.reserve(self.capacity + 1); }

        # Allocate space in the container.
        let offset: uint = self.size * self.element_size;
        let ref: ^^int8 = (self.elements + offset) as ^^int8;
        ref^ = libc.calloc(libc.strlen(el as ^int8) + 1, 1) as ^int8;

        # Move the element into the container.
        libc.memcpy(ref^ as ^void, el as ^void, libc.strlen(el as ^int8));

        # Increment size to keep track of element insertion.
        self.size = self.size + 1;
    }

    # Get an element at `index` from the start of the list (negative indicies
    # offset from the size of the list). Attempting to access an element
    # out-of-bounds of the current size is undefined.
    # -------------------------------------------------------------------------
    def at(&self, index: int) -> ^void {
        # Handle negative indexing.
        let mut _index: uint;
        if index < 0 { _index = self.size - ((-index) as uint); }
        else         { _index = index as uint; }

        # Return the element offset.
        (self.elements + (_index * self.element_size)) as ^void;
    }

    def at_i8(&self, index: int) -> int8 {
        let p: ^int8 = self.at(index) as ^int8;
        p^;
    }

    def at_i16(&self, index: int) -> int16 {
        let p: ^int16 = self.at(index) as ^int16;
        p^;
    }

    def at_i32(&self, index: int) -> int32 {
        let p: ^int32 = self.at(index) as ^int32;
        p^;
    }

    def at_i64(&self, index: int) -> int64 {
        let p: ^int64 = self.at(index) as ^int64;
        p^;
    }

    def at_i128(&self, index: int) -> int128 {
        let p: ^int128 = self.at(index) as ^int128;
        p^;
    }

    def at_u8(&self, index: int) -> uint8 {
        let p: ^uint8 = self.at(index) as ^uint8;
        p^;
    }

    def at_u16(&self, index: int) -> uint16 {
        let p: ^uint16 = self.at(index) as ^uint16;
        p^;
    }

    def at_u32(&self, index: int) -> uint32 {
        let p: ^uint32 = self.at(index) as ^uint32;
        p^;
    }

    def at_u64(&self, index: int) -> uint64 {
        let p: ^uint64 = self.at(index) as ^uint64;
        p^;
    }

    def at_u128(&self, index: int) -> uint128 {
        let p: ^uint128 = self.at(index) as ^uint128;
        p^;
    }

    def at_str(&self, index: int) -> str {
        let p: ^uint = self.at(index) as ^uint;
        (p^ as ^int8) as str;
    }

    def at_int(&self, index: int) -> int {
        let p: ^int = self.at(index) as ^int;
        p^;
    }

    def at_uint(&self, index: int) -> uint {
        let p: ^uint = self.at(index) as ^uint;
        p^;
    }

    def at_ptr(&self, index: int) -> ^void {
        # Handle negative indexing.
        let mut _index: uint;
        if index < 0 { _index = self.size - ((-index) as uint); }
        else         { _index = index as uint; }

        # Return the element offset.
        let elp: ^^void = self.elements as ^^void;
        let elx: ^^void = elp + _index;
        elx^;
    }

    # Erase the element at `index` in the list. This is O(1) for elements
    # at the end of the list and O(n) for any other element (where `n` is
    # the number of elements between the erased element and the end of the
    # list).
    # -------------------------------------------------------------------------
    def erase(&mut self, index: int) {
        let _index: uint;
        let el_size: uint = self.element_size;

        # Handle negative indexing.
        if index < 0 { _index = self.size - ((-index) as uint); }
        else         { _index = index as uint; }

        # If we're dealing with a disposable type, we need to free
        if types.is_disposable(self.tag) {
            let x: ^^int8 = (self.elements + (_index * el_size)) as ^^int8;
            libc.free(x^ as ^void);
        }

        if _index < self.size - 1 {
            # Move everything past index one place to the left,
            # overwriting index.
            libc.memmove((self.elements + (_index * el_size)) as ^void,
                         (self.elements + ((_index + 1) * el_size)) as ^void,
                         self.element_size * (self.size - (_index + 1)));
        }

        # Decrement the size to keep track of the element erasure.
        self.size = self.size - 1;
    }

    # Remove 'all' elements that compare equal to `el`.
    # -------------------------------------------------------------------------
    def remove(&mut self, el: ^void) {
        let mut index :uint = 0;
        let mut eq :int;

        while index < self.size {
            # See if the element at this index matches el
            # We need to make sure it isn't a str, handle those differently
            if self.tag <> types.STR {
                eq = libc.memcmp((self.elements + (index * self.element_size)) as ^void,
                                 el, self.element_size);
            } else {
                # If string, compare value pointed to by value at index
                let data: ^^int8 = (self.elements + (index * self.element_size)) as ^^int8;
                eq = libc.strcmp(data^, el^ as ^int8);
            }

            if eq == 0 {
                self.erase(index as int);

                # Correct the index, so index + 1 later on
                # doesn't cause a skip
                index = index - 1;
            }

            index = index + 1;
        }
    }

    def remove_i8  (&mut self, el:   int8)  { self.remove(&el as ^void); }
    def remove_i16 (&mut self, el:  int16)  { self.remove(&el as ^void); }
    def remove_i32 (&mut self, el:  int32)  { self.remove(&el as ^void); }
    def remove_i64 (&mut self, el:  int64)  { self.remove(&el as ^void); }
    def remove_i128(&mut self, el: int128)  { self.remove(&el as ^void); }
    def remove_u8  (&mut self, el:   int8)  { self.remove(&el as ^void); }
    def remove_u16 (&mut self, el:  int16)  { self.remove(&el as ^void); }
    def remove_u32 (&mut self, el:  int32)  { self.remove(&el as ^void); }
    def remove_u64 (&mut self, el:  int64)  { self.remove(&el as ^void); }
    def remove_u128(&mut self, el: int128)  { self.remove(&el as ^void); }
    def remove_int (&mut self, el:    int)  { self.remove(&el as ^void); }
    def remove_uint(&mut self, el:   uint)  { self.remove(&el as ^void); }
    def remove_str (&mut self, el:    str)  { self.remove(&el as ^void); }

    # Check if `el` compares equal to an element in the list.
    # -------------------------------------------------------------------------
    def contains(&mut self, el: ^void) -> bool {
        let mut index :uint = 0;
        let mut eq :int = -1;

        while index < self.size {
            # See if the element at this index matches el
            # We need to make sure it isn't a str, handle those differently
            if self.tag <> types.STR {
                eq = libc.memcmp((self.elements + (index * self.element_size)) as ^void,
                                 el, self.element_size);
            } else {
                # If string, compare value pointed to by value at index
                let data: ^^int8 = (self.elements + (index * self.element_size)) as ^^int8;
                eq = libc.strcmp(data^, el^ as ^int8);
            }

            # The compiler can't handle an explicit "return true;" here
            # so break out
            if eq == 0 {
                break;
            }
        }

        # Inefficient, but it's the only way to get it to compile
        eq == 0;
    }

    def contains_i8  (&mut self, el:   int8) -> bool { self.contains(&el as ^void); }
    def contains_i16 (&mut self, el:  int16) -> bool { self.contains(&el as ^void); }
    def contains_i32 (&mut self, el:  int32) -> bool { self.contains(&el as ^void); }
    def contains_i64 (&mut self, el:  int64) -> bool { self.contains(&el as ^void); }
    def contains_i128(&mut self, el: int128) -> bool { self.contains(&el as ^void); }
    def contains_u8  (&mut self, el:   int8) -> bool { self.contains(&el as ^void); }
    def contains_u16 (&mut self, el:  int16) -> bool { self.contains(&el as ^void); }
    def contains_u32 (&mut self, el:  int32) -> bool { self.contains(&el as ^void); }
    def contains_u64 (&mut self, el:  int64) -> bool { self.contains(&el as ^void); }
    def contains_u128(&mut self, el: int128) -> bool { self.contains(&el as ^void); }
    def contains_int (&mut self, el:    int) -> bool { self.contains(&el as ^void); }
    def contains_uint(&mut self, el:   uint) -> bool { self.contains(&el as ^void); }
    def contains_str (&mut self, el:    str) -> bool { self.contains(&el as ^void); }

    # Returns true if the list contains no elements.
    # -------------------------------------------------------------------------
    def empty(&mut self) -> bool { self.size == 0; }

    # Gets the number of elements in the list.
    # -------------------------------------------------------------------------
    def size(&mut self) -> uint { self.size; }

    # This is very lazy, if you've allocated a huge list previously
    # and you won't need a list that large again any time soon,
    # it wastes a lot of memory
    # It is fast, however, and easy.
    def clear(&mut self) {
        libc.memset(self.elements as ^void, 0, self.size * self.element_size);
        self.size = 0;
    }

    def front(&mut self) -> ^void { self.at(0); }

    def front_i8  (&mut self) -> int8 {
        let mut p: ^int8 = self.at(0) as ^int8; p^; }

    def front_i16 (&mut self) -> int16 {
        let mut p: ^int16 = self.at(0) as ^int16; p^; }

    def front_i32 (&mut self) -> int32 {
        let mut p: ^int32 = self.at(0) as ^int32; p^; }

    def front_i64 (&mut self) -> int64 {
        let mut p: ^int64 = self.at(0) as ^int64; p^; }

    def front_i128(&mut self) -> int128 {
        let mut p: ^int128 = self.at(0) as ^int128; p^; }

    def front_u8  (&mut self) -> uint8 {
        let mut p: ^uint8 = self.at(0) as ^uint8; p^; }

    def front_u16 (&mut self) -> uint16 {
        let mut p: ^uint16 = self.at(0) as ^uint16; p^; }

    def front_u32 (&mut self) -> uint32 {
        let mut p: ^uint32 = self.at(0) as ^uint32; p^; }

    def front_u64 (&mut self) -> uint64 {
        let mut p: ^uint64 = self.at(0) as ^uint64; p^; }

    def front_u128(&mut self) -> uint128 {
        let mut p: ^uint128 = self.at(0) as ^uint128; p^; }

    def front_int (&mut self) -> int {
        let mut p: ^int = self.at(0) as ^int; p^; }

    def front_uint(&mut self) -> uint {
        let mut p: ^uint = self.at(0) as ^uint; p^; }

    def front_str (&mut self) -> str {
        let mut p: ^int8 = self.at(0) as ^int8; (p^ as ^int8) as str; }


    def back(&mut self) -> ^void { self.at((self.size - 1) as int); }

    def back_i8  (&mut self) -> int8 {
        let mut p: ^int8 = self.at((self.size - 1) as int) as ^int8; p^; }

    def back_i16 (&mut self) -> int16 {
        let mut p: ^int16 = self.at((self.size - 1) as int) as ^int16; p^; }

    def back_i32 (&mut self) -> int32 {
        let mut p: ^int32 = self.at((self.size - 1) as int) as ^int32; p^; }

    def back_i64 (&mut self) -> int64 {
        let mut p: ^int64 = self.at((self.size - 1) as int) as ^int64; p^; }

    def back_i128(&mut self) -> int128 {
        let mut p: ^int128 = self.at((self.size - 1) as int) as ^int128; p^; }

    def back_u8  (&mut self) -> uint8 {
        let mut p: ^uint8 = self.at((self.size - 1) as int) as ^uint8; p^; }

    def back_u16 (&mut self) -> uint16 {
        let mut p: ^uint16 = self.at((self.size - 1) as int) as ^uint16; p^; }

    def back_u32 (&mut self) -> uint32 {
        let mut p: ^uint32 = self.at((self.size - 1) as int) as ^uint32; p^; }

    def back_u64 (&mut self) -> uint64 {
        let mut p: ^uint64 = self.at((self.size - 1) as int) as ^uint64; p^; }

    def back_u128(&mut self) -> uint128 {
        let mut p: ^uint128 = self.at((self.size - 1) as int) as ^uint128; p^; }

    def back_int (&mut self) -> int {
        let mut p: ^int = self.at((self.size - 1) as int) as ^int; p^; }

    def back_uint(&mut self) -> uint {
        let mut p: ^uint = self.at((self.size - 1) as int) as ^uint; p^; }

    def back_str (&mut self) -> str {
        let mut p: ^int8 = self.at((self.size - 1) as int) as ^int8; (p^ as ^int8) as str; }


    def insert(&mut self, index: int, el: ^void) {
        let mut _index: uint;

        # Handle negative indexing.
        if index < 0 { _index = self.size - ((-index) as uint); }
        else         { _index = index as uint; }

        # Delegate if we can't handle it here.
        if self.tag == types.STR { self.push_str(el as str); return; }

        # Request additional memory if needed.
        if self.size == self.capacity { self.reserve(self.capacity + 1); }

        # Move everything past index one place to the right
        libc.memmove((self.elements + ((_index + 1) * self.element_size)) as ^void,
                     (self.elements + (_index * self.element_size)) as ^void,
                     self.element_size * (self.size - (_index + 1)));

         # Move element into the container.
        libc.memcpy((self.elements + ((index as uint) * self.element_size)) as ^void,
                    el, self.element_size);

        self.size = self.size + 1;
    }

    def insert_i8  (&mut self, index: int, el:   int8)  { self.insert(index, &el as ^void); }
    def insert_i16 (&mut self, index: int, el:  int16)  { self.insert(index, &el as ^void); }
    def insert_i32 (&mut self, index: int, el:  int32)  { self.insert(index, &el as ^void); }
    def insert_i64 (&mut self, index: int, el:  int64)  { self.insert(index, &el as ^void); }
    def insert_i128(&mut self, index: int, el: int128)  { self.insert(index, &el as ^void); }
    def insert_u8  (&mut self, index: int, el:   int8)  { self.insert(index, &el as ^void); }
    def insert_u16 (&mut self, index: int, el:  int16)  { self.insert(index, &el as ^void); }
    def insert_u32 (&mut self, index: int, el:  int32)  { self.insert(index, &el as ^void); }
    def insert_u64 (&mut self, index: int, el:  int64)  { self.insert(index, &el as ^void); }
    def insert_u128(&mut self, index: int, el: int128)  { self.insert(index, &el as ^void); }
    def insert_int (&mut self, index: int, el:    int)  { self.insert(index, &el as ^void); }
    def insert_uint(&mut self, index: int, el:   uint)  { self.insert(index, &el as ^void); }

    def insert_str (&mut self, index: int, el: str) {
        let mut _index: uint;

        # Handle negative indexing.
        if index < 0 { _index = self.size - ((-index) as uint); }
        else         { _index = index as uint; }

        # Request additional memory if needed.
        if self.size == self.capacity { self.reserve(self.capacity + 1); }

        # Move everything past index one place to the right
        libc.memmove((self.elements + ((_index + 1) * self.element_size)) as ^void,
                     (self.elements + (_index * self.element_size)) as ^void,
                     self.element_size * (self.size - (_index + 1)));

        # Allocate space in the container.
        let offset: uint = (index as uint) * self.element_size;
        let ref: ^^int8 = (self.elements + offset) as ^^int8;
        ref^ = libc.calloc(libc.strlen(el as ^int8) + 1, 1) as ^int8;

        # Move the element into the container.
        libc.memcpy(ref^ as ^void, el as ^void, libc.strlen(el as ^int8));

        # Increment size to keep track of element insertion.
        self.size = self.size + 1;
    }

}


def main() {
    let mut l: List = make(types.PTR);
    l.push_ptr("10" as ^void);
    l.push_ptr("623" as ^void);
    l.push_ptr("60" as ^void);
    l.push_ptr("51" as ^void);
    l.push_ptr("99921" as ^void);

    let mut i: uint = 0;
    while i < l.size {
        printf("%s \n", l.at_ptr(i as int));
        i = i + 1;
    }

    l.dispose();

    # let mut i: uint = 0;
    # while i < il.size {
    #     printf("%d -> %d\n", i, il.at_int(i as int));
    #     i = i + 1;
    # }

    # il.dispose();

    # printf("------------------------------------------------\n");

    # let mut m: List = make(types.STR);

    # # Push two strings.
    # m.push_str("Hello");
    # m.push_str("World");
    # m.push_str("!\n");
    # m.push_str("Pushing");
    # m.push_str("in");
    # m.push_str("some");
    # m.push_str("strings");

    # # Print them all.
    # let mut i: uint = 0;
    # while i < m.size {
    #     printf("%s ", m.at_str(i as int));
    #     i = i + 1;
    # }
    # printf("\n");

    # # Remove a couple, a couple different ways.
    # m.erase(4);
    # m.remove_str("some");

    # # Second line should now be "Pushing strings."
    # i = 0;
    # while i < m.size {
    #     printf("%s ", m.at_str(i as int));
    #     i = i + 1;
    # }
    # printf("\n");

    # m.dispose();

    # Exit properly.
    libc.exit(0);
}
