macro unless {
    expression $@ expression "else" expression => {
        $0 if not $1 else $2
    }

    expression $@ expression => {
        $0 if not $1
    }

    $@ expression block => {
        if not $0 $1
    }
}

macro while {
    $@ expression block => {
        loop { if $0 { break } $1 }
    }
}

macro until {
    $@ expression block => {
        loop { if not $0 { break } $1 }
    }
}

macro for {
    $@ pattern "in" expression block => {
        let iter = $1.iter()
        until iter.empty() {
            pattern = iter.next
            $2
        }
    }
}

macro do {
    expression => $0()
    expression expression => $0($1)
    expression expression { "," expression } => $0($1${, $2})
}

macro echo identifier => std.println("$0")

macro until {
    $@ expression block => {
        while not $0 $1
    }
}

echo hello
# > println("hello")

until condition { echo goodbye }
# > while not condition { println("goodbye") }


# =============================================================================

# macro name { production => rule }
# a production may consist of N atoms:
#   expression, literal, string, integer, block, type, pattern, identifier
# a production may further consist of literal integers
# a production may further consist of punctuators to control the matching
# a production may contain [ .. ] or { .. } with the same semantics as EBNF
# $<integer> in a rule match the atoms in a production
# $@ in a production refers to the introduced predicate (
#   the macro item name or symbol)

# 1) Declare macro
macro bail => return;

bail;
#> return

# 2) Function-like macro with params
macro bail(expression) => return $0;

bail(40);
#> return 40;

# .) Declare a macro with a param (no parens)
macro bail expression => return $0;

bail 40;
#> return 40;

# 3) Function-like macro doing a bit more
macro factorial {
    (0) => 1,
    (integer) => $0 * factorial($0 - 1)
}

factorial(0);
#=> 1

factorial(2);
#1> 2 * factorial(1)
#2> 2 * 1 * factorial(0)
#3> 2 * 1 * 0
#=> 2

factorial(5);
#.> 5 * 4 * 3 * 2 * 1 * 0
#=> 120

# 4) This is equiv. to 3) because of macro overloading
macro factorial(0) => 1;
macro factorial(integer) => $0 * factorial($0 - 1);

# 5) introduce an `until` keyword
macro until {
    expression block => {
        loop { if not $0 { break; } $1 }
    }
}

until true { 40; }
#> while not true { 40; }

# 6) something insane
# Transform an expression optionally followed by at least one expression
# into the first expression being invoked by the latter
# expressions, if present.
macro do expression [ expression { , expression } ] => $0($[$1${, $2}]);

# 7) Introduce the class keyword
# Figure it out...

# 8) Introduce a new "swap" operator
# Little iffy on the `as ".."` to introduce new tokens
macro swap as "<->" expression $@ expression => ($0, $1) = ($1, $0);

# 9) Introduce the spaceship operator
macro spaceship as "<=>" expression $@ expression => {
    0 if $0 == $1 else (1 if $0 < $1 else -1);
}
