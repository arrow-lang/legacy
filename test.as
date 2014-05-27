
def main() {
    let m: ();
    let a = m;
}


def some(x: int, y: int) { }

some((3, 5)...);

let m = (6, 50);
some(m...);

let a = (y: 30, x: 50);
some(a...);


# "Hello {name}".format(name: "bob")
"Hello {name}".format(data...)

def format(s: str, ...params): str {
    if "name" in params { params[1] }
}
