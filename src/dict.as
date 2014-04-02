import libc;
import types;

# Dictionary
# -----------------------------------------------------------------------------
# An unordered hash-map that uses strings as keys and allows
# any first-class type to be stored as a value.
#
# - [ ] Allow the dictionary to resize automatically
# - [ ] Implement .erase("...")
# - [ ] Implement .contains("...")
# - [ ] Implement .iter()
# - [ ] Implement .empty()
# - [ ] Implement .size()
# - [ ] Implement .clear()

type Bucket {
    key: ^int8,
    tag: int,
    value: ^void,
    next: ^mut Bucket
}

type Dictionary {
    size: uint,
    capacity: uint,
    buckets: ^Bucket
}

let BUCKET_SIZE: uint = (((0 as ^Bucket) + 1) - (0 as ^Bucket));

def hash_str(key: str) -> uint {
    let mut hash: uint = 2166136261;
    let mut c: ^int8 = key as ^int8;
    while c^ <> 0 {
        hash = (16777619 * hash) bitxor (c^ as uint);
        c = c + 1;
    }
    hash;
}

implement Bucket {

    def _set_value(&mut self, tag: int, value: ^void) {
        if tag <> types.PTR {
            # Deallocate the existing space.
            libc.free(self.value);
        }

        # Set the tag.
        self.tag = tag;

        if tag == types.STR {
            # Allocate space for the value in the bucket.
            self.value = libc.calloc(libc.strlen(value as ^int8) + 1, 1);

            # Copy in the value.
            libc.strcpy(self.value as ^int8, value as ^int8);
            0;
        } else if tag == types.PTR {
            # Set the value.
            self.value = value;
            0;
        } else {
            # Allocate space for the value in the bucket.
            let size: uint = types.sizeof(tag);
            self.value = libc.malloc(size);

            # Copy in the value.
            libc.memcpy(self.value, value, size);
            0;
        }
    }

    def dispose(&mut self) {
        # Deallocate `key` space.
        libc.free(self.key as ^void);

        # Deallocate `value` space.
        if self.tag <> types.PTR { libc.free(self.value); }
    }

    def contains(&self, key: str) -> bool {
        # Check if this bucket is not empty.
        if self.key <> 0 as ^int8 {
            # Check if this _is_ the bucket in question.
            if libc.strcmp(self.key, key as ^int8) == 0 {
                # This _is_ the bucket.
                return true;
            }

            # This is not the bucket; check the next one.
            if self.next <> 0 as ^Bucket {
                return (self.next^).contains(key);
            }
        }

        # Found nothing.
        false;
    }

    def get(&self, key: str) -> ^void {
        # Check if this bucket is not empty.
        if self.key <> 0 as ^int8 {
            # Check if this _is_ the bucket in question.
            if libc.strcmp(self.key, key as ^int8) == 0 {
                # This _is_ the bucket. Just get the value.
                return self.value;
            }

            # This is not the bucket; check the next one.
            if self.next <> 0 as ^Bucket {
                return (self.next^).get(key);
            }
        }

        # Found nothing.
        0 as ^void;
    }

    def set(&mut self, key: str, tag: int, value: ^void) {
        # Check if this bucket is not empty.
        if self.key <> 0 as ^int8 {
            # Check if this _is_ the bucket in question.
            if libc.strcmp(self.key, key as ^int8) == 0 {
                # This _is_ the bucket. Just set the value.
                self._set_value(tag, value);
                return;
            }

            # This is not the bucket; check the next one.
            if self.next == 0 as ^Bucket {
                # The next bucket doesn't exist; lets make one.
                self.next = libc.calloc(BUCKET_SIZE, 1) as ^Bucket;
            }

            # Continue on the set the bucket.
            (self.next^).set(key, tag, value);
            return;
        }

        # This bucket is empty.
        # Allocate space for the key and copy in the key.
        self.key = libc.malloc(libc.strlen(key as ^int8) + 1) as ^int8;
        libc.strcpy(self.key, key as ^int8);

        # Set the value.
        self._set_value(tag, value);
    }

}

implement Dictionary {

    def dispose(&mut self) {
        # Enumerate each bucket chain and free the key and values.
        let mut i: uint = 0;
        let mut b: ^mut Bucket = self.buckets;
        while i < self.capacity {
            (b^).dispose();
            b = b + 1;
            i = i + 1;
        }

        # Free the memory taken up by the buckets themselves.
        libc.free(self.buckets as ^void);
    }

    def contains(&self, key: str) -> bool {
        # Hash the string key.
        let hash: uint = hash_str(key) bitand (self.capacity - 1);

        # Grab the bucket offset by the result of the bounded hash function.
        let mut b: ^mut Bucket = self.buckets + hash;
        self.size = self.size + 1;

        # Check if the bucket contains us.
        (b^).contains(key);
    }

    def set(&mut self, key: str, tag: int, value: ^void) {
        # Hash the string key.
        let hash: uint = hash_str(key) bitand (self.capacity - 1);

        # Grab the bucket offset by the result of the bounded hash function.
        let mut b: ^mut Bucket = self.buckets + hash;
        self.size = self.size + 1;

        # Set this in the bucket chain.
        (b^).set(key, tag, value);
    }

    def set_i8(&mut self, key: str, value: int8) {
        self.set(key, types.I8, &value as ^void);
    }

    def set_i16(&mut self, key: str, value: int16) {
        self.set(key, types.I16, &value as ^void);
    }

    def set_i32(&mut self, key: str, value: int32) {
        self.set(key, types.I32, &value as ^void);
    }

    def set_i64(&mut self, key: str, value: int64) {
        self.set(key, types.I64, &value as ^void);
    }

    def set_i128(&mut self, key: str, value: int128) {
        self.set(key, types.I128, &value as ^void);
    }

    def set_u8(&mut self, key: str, value: int8) {
        self.set(key, types.U8, &value as ^void);
    }

    def set_u16(&mut self, key: str, value: int16) {
        self.set(key, types.U16, &value as ^void);
    }

    def set_u32(&mut self, key: str, value: int32) {
        self.set(key, types.U32, &value as ^void);
    }

    def set_u64(&mut self, key: str, value: int64) {
        self.set(key, types.U64, &value as ^void);
    }

    def set_u128(&mut self, key: str, value: int128) {
        self.set(key, types.U128, &value as ^void);
    }

    def set_int(&mut self, key: str, value: int) {
        self.set(key, types.INT, &value as ^void);
    }

    def set_uint(&mut self, key: str, value: uint) {
        self.set(key, types.UINT, &value as ^void);
    }

    def set_str(&mut self, key: str, value: str) {
        self.set(key, types.STR, &value as ^void);
    }

    def set_ptr(&mut self, key: str, value: ^void) {
        self.set(key, types.PTR, value as ^void);
    }

    def get(&self, key: str) -> ^void {
        # Hash the string key.
        let hash: uint = hash_str(key) bitand (self.capacity - 1);

        # Grab the bucket offset by the result of the bounded hash function.
        let mut b: ^mut Bucket = self.buckets + hash;
        self.size = self.size + 1;

        # Get this from the bucket chain.
        let value: ^void = (b^).get(key) as ^void;
        value;
    }

    def get_i8(&self, key: str) -> int8 {
        let p: ^int8 = self.get(key) as ^int8;
        p^;
    }

    def get_i16(&mut self, key: str) -> int16 {
        let p: ^int16 = self.get(key) as ^int16;
        p^;
    }

    def get_i32(&mut self, key: str) -> int32 {
        let p: ^int32 = self.get(key) as ^int32;
        p^;
    }

    def get_i64(&mut self, key: str) -> int64 {
        let p: ^int64 = self.get(key) as ^int64;
        p^;
    }

    def get_i128(&mut self, key: str) -> int128 {
        let p: ^int128 = self.get(key) as ^int128;
        p^;
    }

    def get_u8(&mut self, key: str) -> uint8 {
        let p: ^uint8 = self.get(key) as ^uint8;
        p^;
    }

    def get_u16(&mut self, key: str) -> uint16 {
        let p: ^uint16 = self.get(key) as ^uint16;
        p^;
    }

    def get_u32(&mut self, key: str) -> uint32 {
        let p: ^uint32 = self.get(key) as ^uint32;
        p^;
    }

    def get_u64(&mut self, key: str) -> uint64 {
        let p: ^uint64 = self.get(key) as ^uint64;
        p^;
    }

    def get_u128(&mut self, key: str) -> uint128 {
        let p: ^uint128 = self.get(key) as ^uint128;
        p^;
    }

    def get_str(&mut self, key: str) -> str {
        let p: ^str = self.get(key) as ^str;
        p^;
    }

    def get_int(&mut self, key: str) -> int {
        let p: ^int = self.get(key) as ^int;
        p^;
    }

    def get_uint(&mut self, key: str) -> uint {
        let p: ^uint = self.get(key) as ^uint;
        p^;
    }

    def get_ptr(&mut self, key: str) -> ^void {
        let p: ^void = self.get(key) as ^void;
        p;
    }

}

def make() -> Dictionary {
    let table: Dictionary;
    # FIXME: This is a fixed-size dictionary. Make it double in size
    #        when it hits 60% full or something.
    table.buckets = libc.calloc(65535, BUCKET_SIZE) as ^Bucket;
    table.capacity = 65535;
    table.size = 0;
    table;
}

def main() {
    # Allocate a new table.
    let mut m: Dictionary = make();
    m.set_str("apple", "fruit");
    printf("%s\n", m.get_str("apple"));

    # Dispose of the required resources for the table.
    m.dispose();
}
