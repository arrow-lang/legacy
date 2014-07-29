import libc;
import types;

# Dictionary
# -----------------------------------------------------------------------------
# An unordered hash-map that uses strings as keys and allows
# any first-class type to be stored as a value.
#
# - [ ] Allow the dictionary to resize automatically
# - [ ] Implement .erase("...")
# - [ ] Implement .empty()
# - [ ] Implement .size()
# - [ ] Implement .clear()

struct Bucket {
    key: *int8,
    tag: int,
    value: *void,
    next: *mut Bucket
}

struct Dictionary {
    size: uint,
    capacity: uint,
    buckets: *Bucket
}

struct Iterator {
    buckets: *Bucket,
    bucket: *Bucket,
    key: str,
    index: uint,
    size: uint,
    capacity: uint,
    count: uint
}

let BUCKET_SIZE: uint = (((0 as *Bucket) + 1) - (0 as *Bucket));

let hash_str(key: str): uint -> {
    let mut hash: uint = 2166136261;
    let mut c: *int8 = key as *int8;
    while *c != 0 {
        hash = (16777619 * hash) ^ (*c as uint);
        c = c + 1;
    }
    hash;
}

implement Bucket {

    let _set_value(mut self, tag: int, value: *void) -> {
        if tag != types.PTR {
            # Deallocate the existing space.
            libc.free(self.value);
        };

        # Set the tag.
        self.tag = tag;

        if tag == types.STR {
            # Allocate space for the value in the bucket.
            self.value = libc.calloc(libc.strlen(value as *int8) + 1, 1);

            # Copy in the value.
            libc.strcpy(self.value as *int8, value as *int8);
            0;
        } else if tag == types.PTR {
            # Set the value.
            self.value = value;
            0;
        } else {
            # Allocate space for the value in the bucket.
            let size: uint = types.sizeof(tag);
            self.value = libc.malloc(size as int64);

            # Copy in the value.
            libc.memcpy(self.value, value, size as int32);
            0;
        }
        ;
    }

    let dispose(mut self) -> {
        # Deallocate `key` space.
        libc.free(self.key as *void);

        # Deallocate `value` space.
        if self.tag != types.PTR { libc.free(self.value); };
    }

    let contains(self, key: str): bool -> {
        # Check if this bucket is not empty.
        if self.key != 0 as *int8 {
            # Check if this _is_ the bucket in question.
            if libc.strcmp(self.key, key as *int8) == 0 {
                # This _is_ the bucket.
                return true;
            };

            # This is not the bucket; check the next one.
            if self.next != 0 as *Bucket {
                return (*(self.next)).contains(key);
            };
        };

        # Found nothing.
        false;
    }

    let get(self, key: str): *void -> {
        # Check if this bucket is not empty.
        if self.key != 0 as *int8 {
            # Check if this _is_ the bucket in question.
            if libc.strcmp(self.key, key as *int8) == 0 {
                # This _is_ the bucket. Just get the value.
                return self.value;
            };

            # This is not the bucket; check the next one.
            if self.next != 0 as *Bucket {
                return (*(self.next)).get(key);
            };
        };

        # Found nothing.
        0 as *void;
    }

    let set(key: str, tag: int, value: *void) -> {
        # Check if this bucket is not empty.
        if self.key != 0 as *int8 {
            # Check if this _is_ the bucket in question.
            if libc.strcmp(self.key, key as *int8) == 0 {
                # This _is_ the bucket. Just set the value.
                self._set_value(tag, value);
                return;
            };

            # This is not the bucket; check the next one.
            if self.next == 0 as *Bucket {
                # The next bucket doesn't exist; lets make one.
                self.next = libc.calloc(BUCKET_SIZE as int64, 1) as *Bucket;
            }

            # Continue on the set the bucket.
            (*(self.next)).set(key, tag, value);
            return;
        };

        # This bucket is empty.
        # Allocate space for the key and copy in the key.
        self.key = libc.malloc(libc.strlen(key as *int8) + 1) as *int8;
        libc.strcpy(self.key, key as *int8);

        # Set the value.
        self._set_value(tag, value);
    }

}

implement Dictionary {

    let dispose(mut self) -> {
        # Enumerate each bucket chain and free the key and values.
        let mut i: uint = 0;
        let mut b: *mut Bucket = self.buckets;
        while i < self.capacity {
            (*b).dispose();
            b = b + 1;
            i = i + 1;
        }

        # Free the memory taken up by the buckets themselves.
        libc.free(self.buckets as *void);
    }

    let contains(self, key: str): bool -> {
        # Hash the string key.
        let hash: uint = hash_str(key) & (self.capacity - 1);

        # Grab the bucket offset by the result of the bounded hash function.
        let mut b: *mut Bucket = self.buckets + hash;

        # Check if the bucket contains us.
        (*b).contains(key);
    }

    let set(mut self, key: str, tag: int, value: *void) -> {
        # Hash the string key.
        let hash: uint = hash_str(key) & (self.capacity - 1);

        # Grab the bucket offset by the result of the bounded hash function.
        let mut b: *mut Bucket = self.buckets + hash;

        # Increment size if its new.
        if not ((*b).contains(key)) { self.size = self.size + 1; }

        # Set this in the bucket chain.
        (*b).set(key, tag, value);
    }

    let set_i8(mut self, key: str, value: int8) -> {
        self.set(key, types.I8, &value as *void);
    }

    let set_i16(mut self, key: str, value: int16) -> {
        self.set(key, types.I16, &value as *void);
    }

    let set_i32(mut self, key: str, value: int32) -> {
        self.set(key, types.I32, &value as *void);
    }

    let set_i64(mut self, key: str, value: int64) -> {
        self.set(key, types.I64, &value as *void);
    }

    let set_i128(mut self, key: str, value: int128) -> {
        self.set(key, types.I128, &value as *void);
    }

    let set_u8(mut self, key: str, value: int8) -> {
        self.set(key, types.U8, &value as *void);
    }

    let set_u16(mut self, key: str, value: int16) -> {
        self.set(key, types.U16, &value as *void);
    }

    let set_u32(mut self, key: str, value: int32) -> {
        self.set(key, types.U32, &value as *void);
    }

    let set_u64(mut self, key: str, value: int64) -> {
        self.set(key, types.U64, &value as *void);
    }

    let set_u128(mut self, key: str, value: int128) -> {
        self.set(key, types.U128, &value as *void);
    }

    let set_int(mut self, key: str, value: int) -> {
        self.set(key, types.INT, &value as *void);
    }

    let set_uint(mut self, key: str, value: uint) -> {
        self.set(key, types.UINT, &value as *void);
    }

    let set_str(mut self, key: str, value: str) -> {
        self.set(key, types.STR, &value as *void);
    }

    let set_ptr(mut self, key: str, value: *void) -> {
        self.set(key, types.PTR, value as *void);
    }

    let get(self, key: str): *void -> {
        # Hash the string key.
        let hash: uint = hash_str(key) & (self.capacity - 1);

        # Grab the bucket offset by the result of the bounded hash function.
        let mut b: *mut Bucket = self.buckets + hash;

        # Get this from the bucket chain.
        let value: *void = (*b).get(key) as *void;
        value;
    }

    let get_i8(self, key: str): int8 -> {
        let p: *int8 = self.get(key) as *int8;
        *p;
    }

    let get_i16(self, key: str): int16 -> {
        let p: *int16 = self.get(key) as *int16;
        *p;
    }

    let get_i32(self, key: str): int32 -> {
        let p: *int32 = self.get(key) as *int32;
        *p;
    }

    let get_i64(self, key: str): int64 -> {
        let p: *int64 = self.get(key) as *int64;
        *p;
    }

    let get_i128(self, key: str): int128 -> {
        let p: *int128 = self.get(key) as *int128;
        *p;
    }

    let get_u8(self, key: str): uint8 -> {
        let p: *uint8 = self.get(key) as *uint8;
        *p;
    }

    let get_u16(self, key: str): uint16 -> {
        let p: *uint16 = self.get(key) as *uint16;
        *p;
    }

    let get_u32(self, key: str): uint32 -> {
        let p: *uint32 = self.get(key) as *uint32;
        *p;
    }

    let get_u64(self, key: str): uint64 -> {
        let p: *uint64 = self.get(key) as *uint64;
        *p;
    }

    let get_u128(self, key: str): uint128 -> {
        let p: *uint128 = self.get(key) as *uint128;
        *p;
    }

    let get_str(self, key: str): str -> {
        let p: *str = self.get(key) as *str;
        *p;
    }

    let get_int(self, key: str): int -> {
        let p: *int = self.get(key) as *int;
        *p;
    }

    let get_uint(self, key: str): uint -> {
        let p: *uint = self.get(key) as *uint;
        *p;
    }

    let get_ptr(self, key: str): *void -> {
        let p: *void = self.get(key) as *void;
        p;
    }

    let iter(mut self): Iterator -> {
        let iter: Iterator;
        iter.buckets = self.buckets;
        iter.bucket = 0 as *Bucket;
        iter.index = 0;
        iter.count = 0;
        iter.capacity = self.capacity;
        iter.size = self.size;
        iter.key = "";
        iter;
    }

}

implement Iterator {

    let next(mut self): (str, *void) -> {

        # Get a bucket with contents.
        loop {
            # printf("check: %p\n", self.bucket);
            # Is the current bucket empty? (Initial)
            if self.bucket == 0 as *Bucket {
                # Move to the first bucket.
                self.bucket = self.buckets;
            } else if self.bucket.next == 0 as *Bucket {
                # Is the current bucket exhausted?
                # Yes; move to the next bucket in the chain.
                self.index = self.index + 1;
                self.bucket = self.buckets + self.index;
            } else {
                # Move to `next` key in the bucket.
                self.bucket = self.bucket.next;
            };

            # Is there something in this bucket.
            if self.bucket.key != 0 as *int8 { break; };

            # No; keep going.
        }

        # Increment count.
        self.count = self.count + 1;

        # Get the `key` and `value` out of the bucket.
        let key_str: str = self.bucket.key as str;
        let val: *void = self.bucket.value;
        let res: (str, *void) = (key_str, val);
        res;

    }

    let next_i8(mut self): (str, int8) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *int8 = ptr as *int8;
        let res: (str, int8) = (key, *val);
        res;
    }

    let next_i16(mut self): (str, int16) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *int16 = ptr as *int16;
        let res: (str, int16) = (key, *val);
        res;
    }

    let next_i32(mut self): (str, int32) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *int32 = ptr as *int32;
        let res: (str, int32) = (key, *val);
        res;
    }

    let next_i64(mut self): (str, int64) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *int64 = ptr as *int64;
        let res: (str, int64) = (key, *val);
        res;
    }

    let next_i128(mut self): (str, int128) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *int128 = ptr as *int128;
        let res: (str, int128) = (key, *val);
        res;
    }

    let next_u8(mut self): (str, uint8) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *uint8 = ptr as *uint8;
        let res: (str, uint8) = (key, *val);
        res;
    }

    let next_u16(mut self): (str, uint16) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *uint16 = ptr as *uint16;
        let res: (str, uint16) = (key, *val);
        res;
    }

    let next_u32(mut self): (str, uint32) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *uint32 = ptr as *uint32;
        let res: (str, uint32) = (key, *val);
        res;
    }

    let next_u64(mut self): (str, uint64) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *uint64 = ptr as *uint64;
        let res: (str, uint64) = (key, *val);
        res;
    }

    let next_u128(mut self): (str, uint128) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *uint128 = ptr as *uint128;
        let res: (str, uint128) = (key, *val);
        res;
    }

    let next_int(mut self): (str, int) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *int = ptr as *int;
        let res: (str, int) = (key, *val);
        res;
    }

    let next_uint(mut self): (str, uint) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *uint = ptr as *uint;
        let res: (str, uint) = (key, *val);
        res;
    }

    let next_str(mut self): (str, str) -> {
        let key: str;
        let ptr: *void;
        (key, ptr) = self.next();
        let val: *str = ptr as *str;
        let res: (str, str) = (key, *val);
        res;
    }

    let empty(self): bool -> {
        self.count >= self.size or
        self.index >= self.capacity;
    }

}

let make(size: uint): Dictionary -> {
    let table: Dictionary;
    # FIXME: This is a fixed-size dictionary. Make it double in size
    #        when it hits 60% full or something.
    table.buckets = libc.calloc(size as int64, BUCKET_SIZE as int64) as *Bucket;
    table.capacity = size;
    table.size = 0;
    table;
}

let main() -> {
    # Allocate a new table.
    let mut m: Dictionary = make(32);
    m.set_i8("bool", 10);
    m.set_i8("int8", 10);
    m.set_i8("int16", 10);
    m.set_i8("int32", 10);
    m.set_i8("int64", 10);
    m.set_i8("int128", 10);
    m.set_i8("uint8", 10);
    m.set_i8("uint16", 10);
    m.set_i8("uint32", 10);
    m.set_i8("uint64", 10);
    m.set_i8("uint128", 10);
    m.set_i8("float32", 10);
    m.set_i8("float64", 10);
    m.set_i8("_", 10);
    m.set_i8("_.sxxz1", 10);
    printf("------------------------------------------------------------\n");

    # Iterate over the dictionary items.
    let mut iter: Iterator = m.iter();
    while not iter.empty() {
        let key: str;
        let value: int8;
        (key, value) = iter.next_i8();
        printf("%s: %d\n", key, value);
    }

    # Dispose of the required resources for the table.
    m.dispose();
}
