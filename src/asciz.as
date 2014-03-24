foreign "C" import "string.h";
foreign "C" import "stdio.h";

type String {
    buffer: int8[1024],
    size: uint
}

let EOF: int8 = -1;

def ord(c: char) -> int8 {
    c as int8;
}

def in_range(c: int, s: char, e: char) -> bool {
    c >= (s as int8) and c <= (e as int8);
}

def clear(&mut self: String) {
    # Initialize the string buffer.
    self.buffer[0] = 0x00;
    self.size = 0;
}

def push(&mut self: String, c: int) {
    # Push a new ASCII character on to the string buffer.
    self.buffer[self.size] = c as int8;
    self.size = self.size + 1;
}

def pushc(&mut self: String, c: char) {
    push(self, c as int);
}

def eq(&self: String, &other: String) -> bool {
    # Compare both strings and return true if they are equal.
    self.buffer[self.size] = 0x0;
    other.buffer[other.size] = 0x0;
    strcmp(&self.buffer[0], &other.buffer[0]) == 0;
}

def eq_str(&self: String, other: str) -> bool {
    # Compare both strings and return true if they are equal.
    self.buffer[self.size] = 0x0;
    strcmp(&self.buffer[0], other as ^int8) == 0;
}

def print(&self: String) {
    # Print the ASCII string.
    self.buffer[self.size] = 0x0;
    printf("%s" as ^int8, &self.buffer[0]);
}

def println_str(s: str) {
    printf("%s\n" as ^int8, s as ^int8);
}

def println(&self: String) {
    # Print the ASCII string.
    self.buffer[self.size] = 0x0;
    printf("%s\n" as ^int8, &self.buffer[0]);
}
