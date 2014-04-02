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

implement String {

    # Dispose of the memory used in this string.
    # -------------------------------------------------------------------------
    def dispose(&mut self) { self._data.dispose(); }

    # Gets the number of characters in the string.
    # -------------------------------------------------------------------------
    def size(&self) -> uint { self._data.size; }

    # Append a character onto the string.
    # -------------------------------------------------------------------------
    def append(&mut self, c: char) { self._data.push_i8(c as int8); }

    # Extend this buffer with the passed string.
    # -------------------------------------------------------------------------
    def extend(&mut self, s: str) {
        # Get the list.
        let &mut l: list.List = self._data;

        # Ensure we have enough space.
        let size: uint = libc.strlen(s as ^int8);
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

}

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

    let mut m: list.List = list.make(types.STR);

    # Push two strings.
    m.push_str("Hello");
    m.push_str("World");
    m.push_str("Pushing");
    m.push_str("in");
    m.push_str("some");
    m.push_str("strings");

    let mut s: String = join(".", m);

    printf("%s\n", s.data());

    m.dispose();
    s.dispose();

}
