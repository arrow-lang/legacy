import libc;
import types;
import list;

# Raw strings
# -----------------------------------------------------------------------------
let nil: str = (0 as *int8) as str;
let isnil(s: str): bool -> {
    return (s as *int8) == (0 as *int8);
}

# String
# -----------------------------------------------------------------------------
# A dynamic string that utilizes `list.as` internally.
#
# NOTE: `.dispose` must be called on a "used" string in order to deallocate
#       any used memory.
#
# TODO: slice

struct String {
    _data: list.List
}

implement String {

    # Construct a new string.
    # -------------------------------------------------------------------------
    let new(): String -> {
        return String(list.List.new(types.I8));
    }

    # Construct a new string from an existing `str`.
    # -------------------------------------------------------------------------
    let from_str(s: str): String -> {
        let res = String.new();
        res.extend(s);
        res;
    }

    # Dispose of the memory used in this string.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> {
        self._data.dispose();
    }

    # Clear the string.
    # -------------------------------------------------------------------------
    let clear(mut self) -> {
        self._data.clear();
    }

    # Gets the number of characters in the string.
    # -------------------------------------------------------------------------
    let size(self): uint -> {
        self._data.size;
    }

    # Perform a deep clone of the string and return the string.
    # -------------------------------------------------------------------------
    let clone(self): String -> {
        return String(self._data.clone());
    }

    # Append a character onto the string.
    # -------------------------------------------------------------------------
    let append(mut self, c: char) -> {
        self._data.element_size = types.sizeof(types.I8);
        self._data.push_i8(c as int8);
    }

    # Extend this buffer with the passed string.
    # -------------------------------------------------------------------------
    let extend(mut self, s: str) -> {
        # Ensure were good on size.
        self._data.element_size = types.sizeof(types.I8);

        # Ensure we have enough space.
        let size = libc.strlen(s) as uint;
        self._data.reserve(self._data.size + size + 1);

        # Copy in the string.
        libc.strcpy((self._data.elements + self._data.size) as str, s);

        # Update the size.
        self._data.size = self._data.size + size;
    }

    # Get the internal char buffer.
    # NOTE: This ensures that it is zero-terminated.
    # -------------------------------------------------------------------------
    let data(mut self): str -> {
        # Ensure we have +1 the size.
        self._data.reserve(self._data.size + 1);

        # Set the +1 to zero.
        let p = (self._data.elements + self._data.size) as *mut int8;
        *p = 0;

        # Return our buffer.
        return self._data.elements as str;
    }

    # Get if this string is equal to another string.
    # -------------------------------------------------------------------------
    let eq(mut self, mut other: String): bool -> {
        libc.strcmp(self.data(), other.data()) == 0;
    }

    # Get if this string is equal to another `str`.
    # -------------------------------------------------------------------------
    let eq_str(mut self, other: str): bool -> {
        libc.strcmp(self.data(), other) == 0;
    }

    # # Slice and return the substring between the given indices.
    # # -------------------------------------------------------------------------
    # def slice(&self, begin: int, end: int) -> String {
    #     # Ensure the indices are positive.
    #     let mut _beg: uint;
    #     if begin < 0 { _beg = self.size - ((-begin) as uint); }
    #     else         { _beg = begin as uint; }

    #     let mut _end: uint;
    #     if end < 0   { _end = self.size - ((-end) as uint); }
    #     else         { _end = end as uint; }

    #     # TODO: Assert that `begin` is before `end`.

    #     # Get length of slice.
    #     let n: uint = _end - _beg + 1;

    #     # TODO: Assert that this string has enough.

    #     # Create a big enough string.
    #     let mut res: String = make();
    #     res._data.reserve(n);
    #     res._data.size = n;

    #     # Get a pointer to the beginning.
    #     let &src_data: list.List = self._data;
    #     let &dst_data: list.List = res._data;
    #     let src: ^int8 = (src_data.elements as ^int8) + _beg;
    #     let dst: ^int8 = dst_data.elements;

    #     # Copy the data in there.
    #     libc.strncpy(dst, src, n as int32);

    #     # Return our string.
    #     res;
    # }

}

# Get the ordinal value of an ASCII character.
# -----------------------------------------------------------------------------
let ord(c: char): int8 -> { c as int8; }

# Get the character from an ordinal value.
# -----------------------------------------------------------------------------
let chr(c: int64): char -> { c as char; }

# Join a list of strings into one string separated by a character.
# -----------------------------------------------------------------------------
let join(separator: char, list: list.List): String -> {
    # Make a new string.
    let mut res = String.new();

    # Enumerate through the list and extend the res with each string.
    let mut i: int = 0;
    while i as uint < list.size {
        if i > 0 { res.append(separator); };
        res.extend(list.get_str(i));
        i = i + 1;
    }

    # Return the built string.
    res;
}

# Split a string into a list of strings using a separator character.
# -----------------------------------------------------------------------------
let split(separator: char, s: str): list.List -> {
    # Make a new list (of strings).
    let mut res = list.List.new(types.STR);

    # Enumerate through each 'token' of the string.
    let delimiters = [separator as int8, 0 as int8];
    let mut token = libc.strtok(s, (&delimiters[0]) as str);
    while not isnil(token) {
        res.push_str(token);
        token = libc.strtok(nil, (&delimiters[0]) as str);
    }

    # Return our list of strings.
    return res;
}

# Test driver
# =============================================================================

let main() -> {
    let mut l = list.List.new(types.STR);

    l.push_str("std");
    l.push_str("io");
    l.push_str("net");
    l.push_str("tcp");
    l.push_str("Server");

    let mut s = join(0x2e as int8, l);

    libc.puts(s.data());

    l.dispose();
    s.dispose();
}
