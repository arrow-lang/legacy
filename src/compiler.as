import libc;
import posix;
# import llvm;
# import ast;
import errors;
# import parser;
import tokens;
import tokenizer;
# import generator;
# import generator_;

let main(argc: int, argv: **int8) -> {
    # Build help text
    let help: str = (
        "Usage: arrow [options] file\n"
        "Options:\n"
        "  -h               Display this information\n"
        "  -o <file>        Place the output into <file>\n"
        "  -V, --version    Display version information\n"
        "  -L <directory>   Add <directory> to module search path\n");

    # Build options "description"
    let desc: posix.option[50];
    let opt: posix.option;

    # -o <output_filename>
    let output_filename = "";

    # <filename>
    let mut filename: str = "";

    # --version
    let show_version: bool = false;
    opt.name = "version";
    opt.has_arg = 0;
    opt.flag = &show_version as *int;
    opt.val = 1;
    desc[0] = opt;

    # # --parse
    # let parse_only: bool = false;
    # opt.name = "parse" as *int8;
    # opt.has_arg = 0;
    # opt.flag = &parse_only as *int32;
    # opt.val = 1;
    # desc[1] = opt;

    # --tokenize
    let tokenize_only: bool = false;
    opt.name = "tokenize";
    opt.has_arg = 0;
    opt.flag = &tokenize_only as *int;
    opt.val = 1;
    desc[2] = opt;

    # ..end
    opt.name = "";
    opt.has_arg = 0;
    opt.flag = 0 as *int;
    opt.val = 0;
    desc[3] = opt;

    while libc.optind < argc {
        # Initate the option parsing
        let option_index: int32 = 0;
        let c: int = libc.getopt_long(
            argc, argv,
            "hVo:",
            &desc[0], &option_index);

        # Detect the end of the options.
        if c == -1 {
            # Check this argument.
            if libc.strcmp(filename, "") == 0 {
                filename = *(argv + libc.optind);
            };

            # Move along.
            libc.optind = libc.optind + 1;
        } else {
            # Handle "option" arguments.
            if c as char == "V" {
                show_version = true;
            } else if c as char == "o" {
                output_filename = libc.optarg;
            } else if c as char == "h"{
                libc.printf(help);
                libc.exit(0);
            };
        };
    };

    # Show the version and exit if asked.
    if show_version {
        libc.printf("arrow 0.1.0\n");
        libc.exit(0);
    };

    # Check for a stdin stream
    let fds: posix.pollfd;
    let mut ret: int;
    fds.fd = 0; # this is STDIN
    fds.events = 0x0001;
    ret = posix.poll(&fds, 1, 0);
    let mut file: *libc.FILE;
    let mut has_file: bool = false;
    if ret == 1 and (libc.strcmp(filename, "") == 0) {
        filename = "-";
        file = libc.stdin;
    } else if (libc.strcmp(filename, "") != 0) {
        file = libc.fopen(filename, "r");
        has_file = true;
    } else {
        errors.begin();
        errors.print_error();
        libc.fprintf(libc.stderr,
                     "no input filename given and `stdin` is empty");
        errors.end();
        libc.exit(-1);
    };

    # Declare the tokenizer.
    # FIXME: `filename is not defined`
    let mut t: tokenizer.Tokenizer = tokenizer.Tokenizer.new(
        "?", file);

    # If we were to tokenize only; show the token stream and exit.
    if tokenize_only
    {
        # let mut outstream: *libc.FILE;
        if libc.strcmp(output_filename, "") != 0 {
            outstream = libc.fopen(output_filename, "w");
        };

        # Iterate through each token in the input stream.
        loop {
            # Get the next token
            let mut tok: tokenizer.Token = t.next();

            # Print token if we're error-free
            if errors.count == 0 {
                if libc.strcmp(output_filename, "") != 0 {
                    tok.fprintln(outstream);
                } else {
                    tok.println();
                };
            };

            # Stop if we reach the end.
            if tok.tag == tokens.TOK_END { break; };

            # Dispose of the token.
            tok.dispose();
        }

        if libc.strcmp(output_filename, "") != 0 {
            libc.fclose(outstream);
        };

        # Dispose of the tokenizer.
        t.dispose();

        # Exit
        if errors.count > 0 { libc.exit(-1); };
        libc.exit(0);
    };

    # # Determine the "module name"
    # let module_name =
    #     if has_file {
    #         # HACK: HACK: HACK: nuff said
    #         (filename + libc.strlen(filename) - 3)^ = 0;
    #         filename as str;
    #     } else {
    #         "_";
    #     };

    # # Declare the parser.
    # let mut p: parser.Parser = parser.parser_new(module_name, t);

    # # Parse the AST from the standard input.
    # let unit: ast.Node = p.parse();
    # if errors.count > 0 { libc.exit(-1); }

    # # If we were to parse only; show the AST stream and exit.
    # if parse_only
    # {
    #     let mut outstream: *libc.FILE;
    #     if output_filename != 0 as *int8 {
    #         outstream = libc.fopen(output_filename, "w" as *int8);
    #     }

    #     # Print the AST.
    #     if output_filename == 0 as *int8 {
    #         ast.dump(unit);
    #     } else {
    #         ast.fdump(outstream, unit);
    #     }

    #     if output_filename != 0 as *int8 {
    #         libc.fclose(outstream);
    #     }

    #     # Dispose of the tokenizer and parser.
    #     t.dispose();
    #     p.dispose();

    #     # Exit successfully
    #     libc.exit(0);
    # }

    # # Close the stream.
    # if has_file { libc.fclose(file); }

    # # Die if we had errors.
    # if errors.count > 0 { libc.exit(-1); }

    # # Declare the generator.
    # let mut g: generator_.Generator;

    # # Walk the AST and generate the LLVM IR.
    # generator.generate(g, "_", unit);
    # if errors.count > 0 { libc.exit(-1); }

    # # Output the generated LLVM IR.
    # let data: *int8 = llvm.LLVMPrintModuleToString(g.mod);

    # if output_filename == 0 as *int8 {
    #     printf("%s", data);
    # } else {
    #     let outstream: *libc.FILE =
    #         libc.fopen(output_filename, "w" as *int8);
    #     libc.fprintf(outstream, "%s" as *int8, data);
    #     libc.fclose(outstream);
    # }

    # llvm.LLVMDisposeMessage(data);

    # Dispose of the resources used.
    # g.dispose();
    # p.dispose();
    t.dispose();

    # Exit successfully
    libc.exit(0);
}
