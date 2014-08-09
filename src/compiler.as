import libc;
import posix;
import errors;
import string;
import tokenizer;
import parser;
import generator;
import generator_;

let show_help() -> {
    libc.printf(
        "Usage: arrow [options] file\n\n"
        "Options:\n"
        "  -h               Display this information\n"
        "  -o <file>        Place the output into <file>\n"
        "  -V, --version    Display version information\n"
        "  -L <directory>   Add <directory> to module search path\n"
        "  --tokenize       Tokenize the input file and print the tokens\n"
        "  --parse          Parse the input file and print the AST\n");
}

let main(argc: int32, argv: *str): int32 -> {
    # Prepare flags and state.
    let mut show_version: int32 = 0;
    let mut tokenize_only: int32 = 0;
    let mut parse_only: int32 = 0;
    let mut filename: str = string.nil;
    let mut output_filename: str = string.nil;

    # Build available options.
    let long_options = [
        # --version
        posix.option("version", 0, (&show_version as *int), 1),

        # --tokenize
        posix.option("tokenize", 0, (&tokenize_only as *int), 1),

        # --parse
        posix.option("parse", 0, (&parse_only as *int), 1),

        # [end]
        posix.option(string.nil, 0, 0 as *int, 0)
    ];

    # Parse and iterate through the resultant options
    while posix.optind < argc {
        let option_idx = 0;
        let c = posix.getopt_long(argc, argv, "hVo:", &long_options[0],
                                  &option_idx);

        if c == -1 {
            # No option was matched
            if string.isnil(filename) {
                # Assume this is the input filename
                filename = *(argv + posix.optind);
            } else {
                # We have too many filenames.
                errors.begin();
                errors.print_error();
                libc.fprintf(libc.stderr, "too many input files");
                errors.end();

                # FIXME: The `current_function` should be being detected
                #        and the target type context should auto-cast this
                #        to int32 (it is not).
                return -1 as int32;
            };

            # Move along
            posix.optind = posix.optind + 1;
        } else {
            # Handle short options
            if (c as char) == "h" {
                show_help();
                return 0;
            } else if (c as char) == "V" {
                show_version = 1;
            } else if (c as char) == "o" {
                output_filename = posix.optarg;
            };
        };
    }

    # Check for set flags.
    if show_version != 0 {
        libc.printf("Arrow 0.1.0\n");
        return 0;
    };

    # Check for a `stdin` stream.
    let fds = posix.pollfd(0, 0x0001, 0);
    let ret = posix.poll(&fds, 1, 0);
    let mut stream: *libc.FILE;
    let mut has_stream = false;
    let mut module_name = string.String.new();
    if ret == 1 and string.isnil(filename) {
        # `stdin` has data and no filename was passed
        filename = "-";
        module_name.append("_");
        stream = libc.stdin;
    } else if not string.isnil(filename) {
        # filename was passed
        has_stream = true;
        stream = libc.fopen(filename, "r");

        if stream == 0 as *libc.FILE {
            # file cannot be opened for read
            # FIXME: Get acutal error code and say that message instead
            errors.begin();
            errors.print_error();
            libc.fprintf(libc.stderr, "no such file or directory: '%s'",
                         filename);
            errors.end();

            return -1 as int32;
        };

        # Calculate the module name.
        module_name.extend(posix.basename(filename));
        let endptr = libc.strrchr(module_name.data(), ("." as char) as uint8);
        *(endptr as *int8) = 0;

    } else {
        # no filename was passed and `stdin` has no data
        errors.begin();
        errors.print_error();
        libc.fprintf(libc.stderr, "no input filename given and 'stdin' "
                                  "is empty");
        errors.end();

        return -1 as int32;
    };

    # Declare an output stream
    let mut out_stream: *libc.FILE;
    let mut has_out_stream: bool = false;
    if string.isnil(output_filename) {
        out_stream = libc.stdout;
    } else {
        out_stream = libc.fopen(output_filename, "w");
        has_out_stream = true;
    };

    # Declare the tokenizer.
    let mut t: tokenizer.Tokenizer = tokenizer.Tokenizer.new(filename, stream);

    if tokenize_only != 0 {
        # Iterate through each token in the input stream.
        loop {
            # Get the next token
            let mut tok = t.next();

            # Print token if we're error-free
            if errors.count == 0 { tok.fprintln(out_stream); };

            # Stop if we reach the end.
            if tok.tag == tokens.TOK_END { break; };

            # Dispose of the token.
            tok.dispose();
        }

        # Dispose
        t.dispose();

        # Return
        return (-1 if errors.count > 0 else 0) as int32;
    };

    # Declare the parser.
    let mut p: parser.Parser = parser.parser_new(module_name.data(), t);

    # Parse the AST from the standard input.
    let unit: ast.Node = p.parse();
    if errors.count > 0 { libc.exit(-1); };

    if parse_only != 0 {
        # Print the AST.
        ast.fdump(out_stream, unit);

        # Dispose
        t.dispose();
        p.dispose();

        # Return
        return (-1 if errors.count > 0 else 0) as int32;
    };

    # Die if we had errors.
    if errors.count > 0 { libc.exit(-1); };

    # Declare the generator.
    let mut g: generator_.Generator;

    # Walk the AST and generate the LLVM IR.
    generator.generate(g, module_name.data(), unit);
    if errors.count > 0 { libc.exit(-1); };

    # Output the generated LLVM IR.
    let data = llvm.LLVMPrintModuleToString(g.mod);
    libc.fprintf(out_stream, "%s", data);
    llvm.LLVMDisposeMessage(data);

    # Close the streams.
    if has_stream { libc.fclose(stream); };
    if has_out_stream { libc.fclose(out_stream); };

    # Dispose
    t.dispose();
    p.dispose();
    g.dispose();

    # Return
    return (-1 if errors.count > 0 else 0) as int32;
}
