import libc;
import types;

# List
# -----------------------------------------------------------------------------
# A pseudo-generic dynamic list that works for any type defined in `types.as`.
#
# NOTE: `.dispose` must be called a "used" list in order to deallocate
#       any used memory.
#
# - [ ] Implement .erase(<index>)
# - [ ] Implement .remove_*(<value>)
# - [ ] Implement .contains_*(<value>)
# - [ ] Implement .iter()
# - [ ] Implement .empty()
# - [ ] Implement .size()
# - [ ] Implement .clear()
# - [ ] Implement .front_*()
# - [ ] Implement .back_*()
# - [ ] Implement .insert_*(<index>, <value>)

type List {
    mut tag: int,
    mut element_size: uint,
    mut size: uint,
    mut capacity: uint,
    mut elements: ^mut void
}

def make(tag: int) -> List {
    let list: List;
    libc.memset(&list as ^void, 0, (&list + 1) - &list);
    list.tag = tag;
    list.element_size = types.sizeof(tag);
    list;
}

def make_generic(size: uint) -> List {
    let list: List;
    libc.memset(&list as ^void, 0, (&list + 1) - &list);
    list.tag = 0;
    list.element_size = size;
    list;
}

implement List {

    def dispose(&mut self) {
        # If the underlying type is disposable then enumerate and dispose
        # each element.
        if types.is_disposable(self.tag) {
            let mut i: uint = 0;
            let mut x: ^^void = self.elements as ^^void;
            while i < self.size {
                libc.free(x^);
                x = x + 1;
                i = i + 1;
            }
        }

        # Free the contiguous chunk of memory used for the list.
        libc.free(self.elements);
    }

    def reserve(&mut self, capacity: uint) {
        # Check existing capacity and short-circuit if
        # we are already at a sufficient capacity.
        if capacity <= self.capacity { return; }

        # Ensure that we reserve space in chunks of 10.
        capacity = capacity + (capacity % 10);

        # Reallocate memory to the new requested capacity.
        self.elements = libc.realloc(
            self.elements, capacity * self.element_size);

        # Update capacity.
        self.capacity = capacity;
    }

    def push(&mut self, el: ^void) {
        # Delegate if we can't handle it here.
        if self.tag == types.STR { self.push_str(el as str); return; }

        # Request additional memory if needed.
        if self.size == self.capacity { self.reserve(self.capacity + 1); }

        # Move element into the container.
        libc.memcpy(self.elements + (self.size * self.element_size),
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

    def push_str (&mut self, el: str) {
        # Request additional memory if needed.
        if self.size == self.capacity { self.reserve(self.capacity + 1); }

        # Allocate space in the container.
        let ref: ^^void = (self.elements + self.size) as ^^void;
        ref^ = libc.calloc(libc.strlen(el as ^int8) + 1, 1);

        # Move the element into the container.
        libc.memcpy(ref^, el as ^void, libc.strlen(el as ^int8));

        # Increment size to keep track of element insertion.
        self.size = self.size + 1;
    }

    def at(&mut self, index: int) -> ^void {
        let mut _index: uint;

        # Handle negative indexing.
        if index < 0 { _index = self.size - ((-index) as uint); }
        else         { _index = index as uint; }

        # Return the element offset.
        (self.elements + (_index * self.element_size));
    }

    def at_i8(&mut self, index: int) -> int8 {
        let p: ^int8 = self.at(index) as ^int8;
        p^;
    }

    def at_i16(&mut self, index: int) -> int16 {
        let p: ^int16 = self.at(index) as ^int16;
        p^;
    }

    def at_i32(&mut self, index: int) -> int32 {
        let p: ^int32 = self.at(index) as ^int32;
        p^;
    }

    def at_i64(&mut self, index: int) -> int64 {
        let p: ^int64 = self.at(index) as ^int64;
        p^;
    }

    def at_i128(&mut self, index: int) -> int128 {
        let p: ^int128 = self.at(index) as ^int128;
        p^;
    }

    def at_u8(&mut self, index: int) -> uint8 {
        let p: ^uint8 = self.at(index) as ^uint8;
        p^;
    }

    def at_u16(&mut self, index: int) -> uint16 {
        let p: ^uint16 = self.at(index) as ^uint16;
        p^;
    }

    def at_u32(&mut self, index: int) -> uint32 {
        let p: ^uint32 = self.at(index) as ^uint32;
        p^;
    }

    def at_u64(&mut self, index: int) -> uint64 {
        let p: ^uint64 = self.at(index) as ^uint64;
        p^;
    }

    def at_u128(&mut self, index: int) -> uint128 {
        let p: ^uint128 = self.at(index) as ^uint128;
        p^;
    }

    def at_str(&mut self, index: int) -> str {
        let p: ^str = self.at(index) as ^str;
        p^;
    }

    def at_int(&mut self, index: int) -> int {
        let p: ^int = self.at(index) as ^int;
        p^;
    }

    def at_uint(&mut self, index: int) -> uint {
        let p: ^uint = self.at(index) as ^uint;
        p^;
    }
    
    def erase(&mut self, index: int) {
        let mut _index: uint;
		
        # Handle negative indexing.
        if index < 0 { _index = self.size - ((-index) as uint); }
        else         { _index = index as uint; }
        
        # If we're dealing with a disposable type, we need to free
        if types.is_disposable(self.tag) {
            libc.free((self.elements + (_index * self.element_size))^ as ^void);
        }
        
        # Move everything past index one place to the left, overwriting index
        libc.memmove(self.elements + (_index * self.element_size),
                     self.elements + ((_index + 1) * self.element_size),
                     self.element_size * (self.size - (_index + 1)));
        
        self.size = self.size - 1;
	}
    
    # Note, this removes ALL elements equal to el
    def remove(&mut self, el: ^void) {
        let mut index :uint = 0;
        let mut eq :int;
        
        while index < self.size {
            # See if the element at this index matches el
            # We need to make sure it isn't a str, handle those differently
            if self.tag <> types.STR {
                eq = libc.memcmp(self.elements + (index * self.element_size),
                                 el, self.element_size);
            } else {
                # If string, compare value pointed to by value at index
                eq = libc.memcmp((self.elements + (index * self.element_size))^ as ^void,
                                 el, libc.strlen(el as ^int8));
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
    
}

def main() {
    let mut m: List = make(types.STR);

    # Push two strings.
    m.push_str("Hello");
    m.push_str("World");
    m.push_str("!\n");
    m.push_str("Pushing");
    m.push_str("in");
    m.push_str("some");
    m.push_str("strings.");

    # Print them all.
    let mut i: uint = 0;
    while i < m.size {
        printf("%s ", m.at_str(i as int));
        i = i + 1;
    }
    printf("\n");
    
    # Remove a couple, a couple different ways.
    m.erase(4);
    m.remove_str("some");
    
    # Second line should now be "Pushing strings."
    i = 0;
    while i < m.size {
        printf("%s ", m.at_str(i as int));
        i = i + 1;
    }

    m.dispose();
}
