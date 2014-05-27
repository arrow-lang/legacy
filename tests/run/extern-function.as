module libc { extern def exit(int32); }
def main(): int { libc.exit(10); return -1; }
