module libc { extern def exit(int32); }
let main(): int -> { libc.exit(10); return -1; }
