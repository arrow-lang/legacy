# Selection statments are semantically identical to their C cousins except
# that the parenthesis are optional around the condition and the braces
# are required.
if true { x = 42; };

# Selection statments may have any number of condition branches followed
# by a single branch without a condition.
if      x <   10 {  }
else if x <  100 {  }
else if x < 1000 {  }
else             {  };

# A selection statement may be postfixed (eg. used as a binary
# operator) to invert the standard order.
y = 320 if some_condition;

# Is equivalent to:
if some_condition { y = 320; };

# Adding an else clause to the postfixed if turns it into a ternary operator.
42 if some_condition else 83;

# Which makes this valid syntax:
if x >= 1 {  } if some_condition else if x >= 6 {  } else {  };

# Which is semantically equivalent to:
if some_condition {
    if x >= 1 {  };
} else {
    if x >= 6 {  }
    else {  };
};

# Several selection expressions in a row:
if condition { };
if some_condition { };
if some_other_condition { };

# Some more forms using structure and sequence expressions
# if <expression> <block>
if point { };

# if <sequence expression> <block>
if point { } { };

# if <sequence expression> <block> <block>
if point { } { }; { }

# if <structure expression> <block>
if point { x: 10 } { };

# if <structure expression> <block> <block>
if point { x: 20, y: 50 } { }; { }

# if <sequence expression> <block>
if point { 10 } { };
if point { 10 } { 10; };

# if <expression> <block>
if point { 10; };

# if <if> <block>
if if false { true; } else { false; } { 20; };
if if false { true; } else { false; } { };

# Ensure some crazy selection combinations compile.
if cond { 10; } else { 20; } if other{20} == some{10} else { 50; };
