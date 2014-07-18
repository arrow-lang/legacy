# Assign nothing to a static slot
static nil = 0 as *int8;
let main() -> {
    assert(nil == 0 as *int8);
}
