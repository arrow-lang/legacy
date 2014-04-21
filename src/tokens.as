# Tokens
# The enumeration of all possible tokens the tokenizer can produce.
# NOTE: Someone please replace this with enum Token {...} when we have
#   nominal enumerations in the language.
# ----------------------------------------------------------------------------

# "error" -- poison token to indicate an error in the token stream
let TOK_ERROR: int = -1;

# "end" -- End-of-stream
let TOK_END: int = -2;

# "line" -- End-of-line
let TOK_LINE: int = -3;

# "def" -- Function declaration
let TOK_DEF: int = -1001;

# "let" -- Local slot declaration
let TOK_LET: int = -1002;

# "static" -- Static slot declaration
let TOK_STATIC: int = -1003;

# "mut" -- Mutable slot or type modifier
let TOK_MUT: int = -1004;

# "true" -- Boolean true
let TOK_TRUE: int = -1005;

# "false" -- Boolean false
let TOK_FALSE: int = -1006;

# "self" -- The contextual instance bound to the method
let TOK_SELF: int = -1007;

# "as" -- Safe type cast operator
let TOK_AS: int = -1008;

# "and" -- Logical AND for boolean expressions
let TOK_AND: int = -1009;

# "or" -- Logical OR for boolean expressions
let TOK_OR: int = -1010;

# "not" -- Logical NOT for boolean expressions
let TOK_NOT: int = -1011;

# "if" -- Conditional statement
let TOK_IF: int = -1012;

# "else" -- Initiates the else clause of a conditional statement
let TOK_ELSE: int = -1013;

# "while" -- Condition-controlled loop
let TOK_WHILE: int = -1014;

# "loop" -- Infinite loop
let TOK_LOOP: int = -1015;

# "for" -- Collection-controlled loop
let TOK_FOR: int = -1016;

# "match" -- Pattern match expression
let TOK_MATCH: int = -1017;

# "break" -- Loop termination
let TOK_BREAK: int = -1018;

# "continue" -- Loop restart
let TOK_CONTINUE: int = -1019;

# "return" -- Immediate return from function
let TOK_RETURN: int = -1020;

# "type" -- Product type declaration
let TOK_TYPE: int = -1021;

# "enum" -- Sum type declaration
let TOK_ENUM: int = -1022;

# "module" -- Module declaration
let TOK_MODULE: int = -1023;

# "import" -- Import statement
let TOK_IMPORT: int = -1024;

# "use" -- Alias declaration
let TOK_USE: int = -1025;

# "foreign" -- Foreign interface statement
let TOK_FOREIGN: int = -1026;

# "unsafe" -- Unsafe indicator
let TOK_UNSAFE: int = -1027;

# "global" -- Global scope resolution indicator
let TOK_GLOBAL: int = -1028;

# "->" -- Function return type declarator
let TOK_RARROW: int = -2001;

# "+" -- Plus
let TOK_PLUS: int = -2002;

# "-" -- Minus
let TOK_MINUS: int = -2003;

# "*" -- Star
let TOK_STAR: int = -2004;

# "/" -- Forward slash
let TOK_FSLASH: int = -2005;

# "%" -- Percent
let TOK_PERCENT: int = -2006;

# "^" -- Hat
let TOK_HAT: int = -2007;

# "&" -- Ampersand
let TOK_AMPERSAND: int = -2008;

# "(" -- Left parenthesis
let TOK_LPAREN: int = -2009;

# ")" -- Right parenthesis
let TOK_RPAREN: int = -2010;

# "[" -- Left bracket
let TOK_LBRACKET: int = -2011;

# "]" -- Right bracket
let TOK_RBRACKET: int = -2012;

# "{" -- Left brace
let TOK_LBRACE: int = -2013;

# "}" -- Right brace
let TOK_RBRACE: int = -2014;

# ";" -- Semicolon
let TOK_SEMICOLON: int = -2015;

# ":" -- Colon
let TOK_COLON: int = -2016;

# "," -- Comma
let TOK_COMMA: int = -2017;

# "." -- Dot
let TOK_DOT: int = -2018;

# "<" -- Left caret
let TOK_LCARET: int = -2019;

# ">" -- Right caret
let TOK_RCARET: int = -2020;

# "<=" -- Left caret followed by equals to
let TOK_LCARET_EQ: int = -2021;

# ">=" -- Right caret followed by equals to
let TOK_RCARET_EQ: int = -2022;

# "==" -- Equals followed by an Equals
let TOK_EQ_EQ: int = -2023;

# "!=" -- Exclamation mark followed by an equals
let TOK_BANG_EQ: int = -2024;

# "=" -- Equal
let TOK_EQ: int = -2025;

# "+=" -- Plus followed by an equals
let TOK_PLUS_EQ: int = -2026;

# "-=" -- Minus followed by an equals
let TOK_MINUS_EQ: int = -2027;

# "*=" -- Star followed by an equals
let TOK_STAR_EQ: int = -2028;

# "/=" -- Forward slash followed by an equals
let TOK_FSLASH_EQ: int = -2029;

# "%=" -- Percent followed by an equals
let TOK_PERCENT_EQ: int = -2030;

# "//" -- Forward slash followed by another forward slash
let TOK_FSLASH_FSLASH: int = -2031;

# "//=" -- Forward slash followed by another forward slash followed by an equals
let TOK_FSLASH_FSLASH_EQ: int = -2032;

# "!" -- Bang operator
let TOK_BANG: int = -2033;

# "|" -- Pipe 
let TOK_PIPE: int = -2034;

# "identifier" -- Lexical identifier
let TOK_IDENTIFIER: int = -3001;

# "integer" -- Integral literal
let TOK_DEC_INTEGER: int = -4001;
let TOK_BIN_INTEGER: int = -4002;
let TOK_OCT_INTEGER: int = -4003;
let TOK_HEX_INTEGER: int = -4004;

# "float" -- Floating-point literal
let TOK_FLOAT: int = -4005;

# "string" -- String literal
let TOK_STRING: int = -4006;
