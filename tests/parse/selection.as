# Selection statments are semantically identical to their C cousins except
# that the parenthesis are optional around the condition and the braces
# are required.
if true { x = 42; }

# Selection statments may have any number of condition branches followed
# by a single branch without a condition.
let x = 2;
if      x <   10 {  }
else if x <  100 {  }
else if x < 1000 {  }
else             {  }

# A selection statement may be postfixed (eg. used as a binary
# operator) to invert the standard order.
let y: int;
y = 320 if some_condition;

# Postfixed selection statements are evaluated left-to-right. The following:
z = 420 if some if some_else;

# Translates to:
if some_else { if some { z = 420; } }

# Adding an else clause to the postfixed if turns it into a ternary operator.
42 if some_condition else 83;

# Which makes this valid syntax:
if x >= 1 {  } if some_condition else if x >= 6 {  } else {  } if condition;

# Which is semantically equivalent to:
if some_condition {
    if x >= 1 {  }
} else {
    if condition {
        if x >= 6 {  }
        else {  }
    }
}

# Several selection expressions in a row:
if condition { }
if some_condition { }
if some_other_condition { }

# Some more forms using structure and sequence expressions
# if <expression> <block>
if point { }

# if <sequence expression> <block>
if point { } { }

# if <sequence expression> <block> <block>
if point { } { } { }

# if <structure expression> <block>
if point { x: 10 } { }

# if <structure expression> <block> <block>
if point { x: 20, y: 50 } { } { }

# if <sequence expression> <block>
if point { 10 } { }
if point { 10 } { 10; }

# if <expression> <block>
if point { 10; }