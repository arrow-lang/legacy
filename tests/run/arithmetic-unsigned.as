let main() -> {
    assert(((0 as uint8) < (255 as uint8)));
    assert(((0 as uint8) <= (255 as uint8)));
    assert(((255 as uint8) > (0 as uint8)));
    assert(((255 as uint8) >= (0 as uint8)));
    assert((250 as uint8) // (10 as uint8) == (25 as uint8));
    assert((255 as uint8) % (10 as uint8) == (5 as uint8));
    assert(((0 as uint16) < (60000 as uint16)));
    assert(((0 as uint16) <= (60000 as uint16)));
    assert(((60000 as uint16) > (0 as uint16)));
    assert(((60000 as uint16) >= (0 as uint16)));
    assert((60000 as uint16) // (10 as uint16) == (6000 as uint16));
    assert((60005 as uint16) % (10 as uint16) == (5 as uint16));
    assert(((0 as uint32) < (4000000000 as uint32)));
    assert(((0 as uint32) <= (4000000000 as uint32)));
    assert(((4000000000 as uint32) > (0 as uint32)));
    assert(((4000000000 as uint32) >= (0 as uint32)));
    assert((4000000000 as uint32) // (10 as uint32) == (400000000 as uint32));
    assert((4000000005 as uint32) % (10 as uint32) == (5 as uint32));
}
