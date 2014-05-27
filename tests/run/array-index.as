def main() {
    let mut table: int[10];
    table[0] = 20;
    let x: int = table[0];
    assert(x == 20);
    assert(table[0] == 20);

    let mut matrix: int[5][5];
    matrix[0][1] = 20;
    assert(matrix[0][1] == 20);
}
