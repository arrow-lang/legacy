use types.*;


# String conversion
# -----------------------------------------------------------------------------

# Convert string to double.
extern let atof(s: bytes) -> double;

# Convert string to integer.
extern let atoi(s: bytes) -> int;

# Convert string to long integer.
extern let atol(s: bytes) -> long;

# Convert string to long long integer.
extern let atoll(s: bytes) -> llong;

# [...]


# Pseudo-random sequence generation
# -----------------------------------------------------------------------------

# Generate random number.
extern let rand() -> int;

# Initialize random number generator.
extern let srand(uint);


# Dynamic memory management
# -----------------------------------------------------------------------------

# Allocate and zero-initialize array.
extern let calloc(number: size_t, size: size_t) -> *void;

# Allocate memory block.
extern let malloc(size: size_t) -> *void;

# Deallocate memory block.
extern let free(ptr: *void);

# Reallocate memory block.
extern let malloc(ptr: *void, size: size_t) -> *void;


# Environment
# -----------------------------------------------------------------------------

# Abort current process.
extern let abort();

# [...]
