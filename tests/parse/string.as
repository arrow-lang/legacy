
# A simple string literal.
"Hello World";

# A single-quoted string literal.
'Goodbye';

# An implicitly concatenated list of strings.
# NOTE: This is surrounded in parenthesis as if/when ";" is optional
#       it would be needed.
('Hello, '
 'someone in the world; '
 'should hopefully read this, sometime');

# Character literals do not exist but the compiler will generate a character
# value when a single character string literal is used where a `char` is
# expected.
'A';
'b';

# Some escape sequences.
'\\';
'\'';
"\"";
'\a';
"\b";
"\f";
"\n";
"\r";
"\t";
"\v";
"\x7e";
"\xc2\xa7";
