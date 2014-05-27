import libc;
import types;
import list;

# String
# -----------------------------------------------------------------------------
# A dynamic string that utilizes `list.as` internally.
#
# NOTE: `.dispose` must be called a "used" string in order to deallocate
#       any used memory.

type String {
    mut _data: list.List
}

def make() -> String {
    let string: String;
    string._data = list.make(types.I8);
    string;
}

let Nil: str = (0 as ^int8) as str;

implement String {

    # Dispose of the memory used in this string.
    # -------------------------------------------------------------------------
    def dispose(&mut self) { self._data.dispose(); }

    # Clear the string.
    # -------------------------------------------------------------------------
    def clear(&mut self) { self._data.clear(); }

    # Gets the number of characters in the string.
    # -------------------------------------------------------------------------
    def size(&self) -> uint { self._data.size; }

    # Perform a deep clone of the string and return the string.
    # -------------------------------------------------------------------------
    def clone(&self) -> String {
        let string: String;
        string._data = self._data.clone();
        string;
    }

    # Append a character onto the string.
    # -------------------------------------------------------------------------
    def append(&mut self, c: char) {
        self._data.element_size = types.sizeof(types.I8);
        self._data.push_i8(c as int8);
    }

    # Extend this buffer with the passed string.
    # -------------------------------------------------------------------------
    def extend(&mut self, s: str) {
        # Ensure were good on size.
        self._data.element_size = types.sizeof(types.I8);

        # Get the list.
        let &mut l: list.List = self._data;

        # Ensure we have enough space.
        let size: uint = libc.strlen(s as ^int8) as uint;
        l.reserve(l.size + size + 1);

        # Copy in the string.
        libc.strcpy((l.elements + l.size) as ^int8, s as ^int8);

        # Update the size.
        l.size = l.size + size;
    }

    # Get the internal char buffer.
    # NOTE: This ensures that it is zero-terminated.
    # -------------------------------------------------------------------------
    def data(&mut self) -> ^int8 {
        # Get the list.
        let &mut l: list.List = self._data;

        # Ensure we have +1 the size.
        l.reserve(l.size + 1);

        # Set the +1 to zero.
        let p: ^int8 = (l.elements + l.size) as ^int8;
        p^ = 0;

        # Return our buffer.
        let x: ^int8 = l.elements as ^int8;
        x;
    }

    # Get if this string is equal to another string.
    # -------------------------------------------------------------------------
    def eq_str(&mut self, other: str) -> bool {
        libc.strcmp(self.data(), other as ^int8) == 0;
    }

    # Slice and return the substring between the given indices.
    # -------------------------------------------------------------------------
    def slice(&self, begin: int, end: int) -> String {
        # Ensure the indices are positive.
        let mut _beg: uint;
        if begin < 0 { _beg = self.size - ((-begin) as uint); }
        else         { _beg = begin as uint; }

        let mut _end: uint;
        if end < 0   { _end = self.size - ((-end) as uint); }
        else         { _end = end as uint; }

        # TODO: Assert that `begin` is before `end`.

        # Get length of slice.
        let n: uint = _end - _beg + 1;

        # TODO: Assert that this string has enough.

        # Create a big enough string.
        let mut res: String = make();
        res._data.reserve(n);
        res._data.size = n;

        # Get a pointer to the beginning.
        let &src_data: list.List = self._data;
        let &dst_data: list.List = res._data;
        let src: ^int8 = (src_data.elements as ^int8) + _beg;
        let dst: ^int8 = dst_data.elements;

        # Copy the data in there.
        libc.strncpy(dst, src, n as int32);

        # Return our string.
        res;
    }

}

# Get the ordinal value of an ASCII character.
# -----------------------------------------------------------------------------
def ord(c: char) -> int8 { c as int8; }

# Join a list of strings into one string separated by a character.
# -----------------------------------------------------------------------------
def join(separator: char, list: list.List) -> String {
    # Make a new string.
    let mut res: String = make();

    # Enumerate through the list and extend the res with each string.
    let mut i: int = 0;
    while i as uint < list.size {
        if i > 0 { res.append(separator); }
        res.extend(list.at_str(i));
        i = i + 1;
    }

    # Return the built string.
    res;
}

def main() {

    let mut s: String = make();
    s.extend("Hello World");

    let mut sm: String = s.slice(0, 2);

    printf("%s\n", sm.data());

    s.dispose();
    sm.dispose();


}
