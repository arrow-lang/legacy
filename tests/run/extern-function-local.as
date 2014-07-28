module libc { extern let exit(int32); }
let main(): int -> {
    let res: int32 = 30;
    libc.exit(res);
    return -1;
}
