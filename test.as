
extern def puts(str);

let check_1(): bool -> {
    puts("check_1");
    return true;
}

let check_2(): bool -> {
    puts("check_2");
    return true;
}

let check_3(): bool -> {
    puts("check_3");
    return true;
}

let check_4(): bool -> {
    puts("check_4");
    return true;
}

let main() -> {

    # let condition = true & false;

    let condition = check_1() ^ not not not !!check_2();
    assert(condition);

    # if check_1() and check_2() {
    #     puts("true");
    # } else {
    #     puts("false");
    # };
}
