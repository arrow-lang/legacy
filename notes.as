# [X] Add static / local slots
# [ ] Add function declarations
# [ ] Finish postfix expressions (index, call, member)
# [ ] Add identifier / path expressions
# [ ] Extend selection to remove mandatory semicolons
# [ ] Allow type expressions
# [ ]   - Tuples        (int,)
# [ ]   - Structures    {x: int}
# [ ]   - Functions     def(): int
# [ ]   - Arrays        int[10]
# [X] Refactor array/record/tuple expressions (code too similar)
# [X] Add modules
# [ ] Get generator working with new parser

# =============================================================================

# [ ] Enumerations (see tests/parse/enum.as)
enum Color { Red, Green, Blue }

# [ ] Bounds for a type parameter (
#       just `parse_ident_expr` for now as the transition to `parse_type_expr`
#       will automatically handle `T: U+V`)
struct Name<T: Color> { x: T }

# [ ] Patterns
#     Really just a group of things we already have.

let (x, y, z);
x = 10;
y = 20;
z = 60;

{y, ..} = Point{y: 30};
{xx: x} = Point{x: 60};

{value} = Box{10};

# [ ] Match expression
let x = match expression {
    possible => 20,
    value => 10,
    it => { 560; }
    could | might => 70,
    be => { 30; 10; }
};

let c = Color.Red;
let m = match c { Red => 30, _ => 0 };

# A match expression is of the form:
#   "match" expression "{" { arms } "}"

# Where a match `arm` is of the form:
#   expression "=>" expression [ "," ]
# or:
#   expression | expression | expression "=>" expression [ "," ]
