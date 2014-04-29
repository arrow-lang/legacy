# [ ] Call (both ast and even a stub function exist: parse_call_expr)
#     tests/parse/call.as

# [ ] Member expressions (both ast and even a stub function exist: parse_member_expr)
#     tests/parse/path.as

# [ ] Index expressions (both ast and even a stub function exist: parse_member_expr)
#     tests/parse/index.as

# [ ] Import (ast exists)
#     tests/parse/import.as

# [ ] While
#     tests/parse/while.as

# [ ] Loop
#     tests/parse/loop.as

# [ ] Enumerates
#     tests/parse/enum.as

# [ ] Implement
#     tests/parse/implement.as
#       - Member functions
implement int { def func(self) { } def attached() { } }

# Member functions start with "self" (its a keyword / token) to indicate
# that they are an instance method. Member functions without `self` are
# "attached" functions or "class" methods.

# [ ] Trait -- "trait" name "{" ... "}"
#       - Member function "signatures" followed by `;`
#       - Member functions (think of them as default implementation
#                           of the interface)
#     tests/parse/trait.as
