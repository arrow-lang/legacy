def factorial(n: int64) -> int64 {
    n * factorial(n - 1) if n <> 0 else 1;
}

def main() {
    assert(factorial( 0) ==       1);
    assert(factorial( 1) ==       1);
    assert(factorial( 2) ==       2);
    assert(factorial( 3) ==       6);
    assert(factorial( 4) ==      24);
    assert(factorial( 5) ==     120);
    assert(factorial( 6) ==     720);
    assert(factorial( 7) ==    5040);
    assert(factorial( 8) ==   40320);
    assert(factorial( 9) ==  362880);
    assert(factorial(10) == 3628800);
}

# macro unless {
#     expression $@ expression "else" expression => {
#         $0 if not $1 else $2
#     }

#     expression $@ expression => {
#         $0 if not $1
#     }

#     $@ expression block => {
#         if not $0 $1
#     }
# }

# macro while {
#     $@ expression block => {
#         loop { if $0 { break } $1 }
#     }
# }

# macro until {
#     $@ expression block => {
#         loop { if not $0 { break } $1 }
#     }
# }

# macro for {
#     $@ pattern "in" expression block => {
#         let iter = $1.iter()
#         until iter.empty() {
#             pattern = iter.next
#             $2
#         }
#     }
# }
