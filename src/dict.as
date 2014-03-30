module libc {
    foreign "C" import "stdlib.h";
    foreign "C" import "string.h";
}

# Dictionary
# -----------------------------------------------------------------------------
# An unordered hash-map that uses strings as keys and allows
# any first-class type to be stored as a value.

let TAG_INT8: uint = 1;

def _sizeof(tag: uint) -> uint {
    if tag == TAG_INT8 { 1; }
    else { 0; }
}

type Bucket {
    key: ^int8,
    tag: uint,
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
    def _set_value(&mut self, tag: uint, value: ^void) {
        # Deallocate the existing space.
        libc.free(self.value);

        # Allocate space for the value in the bucket.
        let size: uint = _sizeof(tag);
        self.value = libc.malloc(size);

        # Copy in the value.
        libc.memcpy(self.value, value, size);
    }

    def dispose(&mut self) {
        # Deallocate existing space.
        libc.free(self.key as ^void);
        libc.free(self.value);
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

    def set(&mut self, key: str, tag: uint, value: ^void) {
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

    def set_int8(&mut self, key: str, value: int8) {
        # Hash the string key.
        let hash: uint = hash_str(key) bitand (self.capacity - 1);

        # Grab the bucket offset by the result of the bounded hash function.
        let mut b: ^mut Bucket = self.buckets + hash;
        self.size = self.size + 1;

        # Set this in the bucket chain.
        (b^).set(key, TAG_INT8, &value as ^void);
    }

    def get_int8(&self, key: str) -> int8 {
        # Hash the string key.
        let hash: uint = hash_str(key) bitand (self.capacity - 1);

        # Grab the bucket offset by the result of the bounded hash function.
        let mut b: ^mut Bucket = self.buckets + hash;
        self.size = self.size + 1;

        # Get this from the bucket chain.
        let value: ^int8 = (b^).get(key) as ^int8;
        value^;
    }
}

def make(size: uint) -> Dictionary {
    let table: Dictionary;
    table.buckets = libc.calloc(size, BUCKET_SIZE) as ^Bucket;
    table.capacity = size;
    table.size = 0;
    table;
}

def main() {
    # Allocate a new table.
    let mut m: Dictionary = make(65536);
    m.set_int8("apple", 43);
    m.set_int8("orange", 43);
    m.set_int8("blue", 43);
    m.set_int8("banana", 43);
    m.set_int8("key", 43);
    m.set_int8("value", 43);
    m.set_int8("tomato", 43);
    m.set_int8("word", 43);
    m.set_int8("list", 43);
    m.set_int8("good", 43);
    m.set_int8("cool", 43);
    m.set_int8("balloon", 43);
    m.set_int8("balloon", 43);

    if (m.get_int8("balloon") <> 43) {
        libc.abort();
    }

    # Dispose of the required resources for the table.
    m.dispose();
}
