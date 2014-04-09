def sat_add(x: uint) -> uint {
    let mut ret: uint = x + 1;
    if ret < x { ret = x; }
    ret;
}

def main() {
    assert(sat_add(-1 as uint) == -1 as uint);
}
