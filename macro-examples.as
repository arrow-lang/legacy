# THINK OF 30 examples of macros for testing purposes

# macro name { production => rule }
# a production may consist of N atoms:
#   expression, literal, string, integer, block, type, pattern, identifier
# a production may further consist of literal integers
# a production may further consist of punctuators to control the matching
# a production may contain [ .. ] or { .. } with the same semantics as EBNF
# $<integer> in a rule match the atoms in a production
# $@ in a production refers to the introduced predicate (
#   the macro item name or symbol)

# -----------------------------------------------------------------------------
# Atoms:
#   Expression

# -----------------------------------------------------------------------------
# 1) Simple keyword replacement
macro bail => return;

bail;
#> { return; };

# -----------------------------------------------------------------------------
# 2) Functional macros
macro bail(Expression) => return $0;

bail(410);
#> { return 410; };

bail(some(30, 3021));
#> { return some(30, 3021); };

# -----------------------------------------------------------------------------
# 3) Macro resembling both 1 and 2 (optional qualifier)
macro bail [ "(" Expression ")" ] => return $[$0];

bail(30);
#> { return 30; };

bail;
#> { return; };

# -----------------------------------------------------------------------------
# 4) Dropping the parens from `bail`
macro bail [ Expression ] => return $[$0];

bail(30);
#> { return 30; };

bail;
#> { return; };

# -----------------------------------------------------------------------------
# 5) Some kind of log system

macro log_enabled(Identifier) => {
    std.logging.$0 <= std.logging.log_level();
}

macro log(Identifier, String) => {
    std.io.stdio.stderr.write($1) if log_enabled($0);
}

macro error(String) => log(ERROR, $0);

error("Oh noes!");
#> { std.io.stdio.stderr.write("Oh noes!") if { std.logging.ERROR <= std.logging.log_level(); } };
