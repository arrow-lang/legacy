let test_if() -> {
    let rs: bool = if true { true; } else { false; };
    assert(rs);
}

let test_else() -> {
    let rs: bool = if false { false; } else { true; };
    assert(rs);
}

let test_elseif1() -> {
    let rs: bool = if true { true; } else if true { false; } else { false; };
    assert(rs);
}

let test_elseif2() -> {
    let rs: bool = if false { false; } else if true { true; } else { false; };
    assert(rs);
}

let test_elseif3() -> {
    let rs: bool = if false { false; } else if false { false; } else { true; };
    assert(rs);
}

let test_inferrence() -> {
    let rs = if true { true; } else { false; };
    assert(rs);
}

let test_if_as_if_condition() -> {
    let rs1: bool = if if false { false; } else { true; } { true; } else { false; };
    assert(rs1);
    let rs2: bool = if if true { false; } else { true; } { false; } else { true; };
    assert(rs2);
}

let test_if_as_block_result() -> {
    let rs: bool = if true { if false { false; } else { true; }; } else { false; };
    assert(rs);
}

let main() -> {
    test_if();
    test_else();
    test_elseif1();
    test_elseif2();
    test_elseif3();
    test_inferrence();
    test_if_as_if_condition();
    test_if_as_block_result();
}
