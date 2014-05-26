def main() {
    let mut m: int8[2];
    m[0] = m[1] = 86;
    let mut pm: *int8[2] = &m;
    assert((*pm)[0] == 86);
    assert((*pm)[1] == 86);
}
