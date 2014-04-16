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
