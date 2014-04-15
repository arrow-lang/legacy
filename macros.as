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
