# Some anonymous structure expressions
{x: 10};
{y: 20,};
{a: 20, b: false, c: 3.123};

# Some nominal structure expressions.
Point{x: 10};
Point{y: 20, x: 20};
Point{30, 10};
Point{};

# Some nominal structure expressions (using type parameters).
Box{10};
Box<float32>{30};
Box<int>(3);
Vector{30, 10.102};
Box<Box<int>>{Box<int>{20}};
