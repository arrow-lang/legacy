module libc { extern def exit(int32); }
def main(): int {
    let res: int32 = 30;
    libc.exit(res);
    return -1;
}
