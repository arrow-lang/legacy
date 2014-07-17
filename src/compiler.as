import libc;
import llvm;
import ast;
import errors;
import parser;
import tokens;
import tokenizer;
import generator;
import generator_;

def main(argc: int, argv: ^^int8) {

    # sadly, no implicit string concatination in the old compiler
    let help: str = ("Usage: arrow [options] file...\nCommand\t\t\tDescription\n-h\t\t\tShows the help screen\n-o\t\t\tset output filename (if not provided, outputs to stdout)\n--version, -V\t\tprint version and exit\n-L\t\t\tadds a path to the default lookup path\n");

    # Build options "description"
    let desc: libc.option[50];
    let opt: libc.option;

    # -o <output_filename>
    let output_filename: ^int8 = 0 as ^int8;

    # <filename>
    let filename: ^int8 = 0 as ^int8;

    # --version
    let show_version: bool = false;
    opt.name = "version" as ^int8;
    opt.has_arg = 0;
    opt.flag = &show_version as ^int32;
    opt.val = 1;
    desc[0] = opt;

    # --parse
    let parse_only: bool = false;
    opt.name = "parse" as ^int8;
    opt.has_arg = 0;
    opt.flag = &parse_only as ^int32;
    opt.val = 1;
    desc[1] = opt;

    # --tokenize
    let tokenize_only: bool = false;
    opt.name = "tokenize" as ^int8;
    opt.has_arg = 0;
    opt.flag = &tokenize_only as ^int32;
    opt.val = 1;
    desc[2] = opt;

    # ..end
    opt.name = 0 as ^int8;
    opt.has_arg = 0;
    opt.flag = 0 as ^int32;
    opt.val = 0;
    desc[3] = opt;

    while libc.optind < argc {
        # Initate the option parsing
        let option_index: int32 = 0;
        let c: int = libc.getopt_long(
            argc as int32, argv,
            "hVo:" as ^int8,
            &desc[0], &option_index);

        # Detect the end of the options.
        if c == -1 {
            # Check this argument.
            if filename == 0 as ^int8 {
                filename = (argv + libc.optind)^;
            }

            # Move along.
            libc.optind = libc.optind + 1;

            # HACK!
            void;
        } else {
            # Handle "option" arguments.
            if c as char == "V" {
                show_version = true;
            } else if c as char == "o" {
                output_filename = libc.optarg;
            } else if c as char == "h"{
                printf(help);
                libc.exit(0);
            }

            # HACK!
            void;
        }
    }

    # Show the version and exit if asked.
    if show_version {
        printf("arrow 0.0.1\n");
        libc.exit(0);
    }

    # Check for a stdin stream
    let fds: libc.pollfd;
    let ret: int;
    fds.fd = 0; # this is STDIN
    fds.events = 0x0001;
    ret = libc.poll(&fds, 1, 0);
    let file: ^libc._IO_FILE;
    let has_file: bool = false;
    if ret == 1 and filename == 0 as ^int8 {
        filename = "-" as ^int8;
        file = libc.stdin;
        void;
    } else if filename <> 0 as ^int8 {
        has_file = true;
        file = libc.fopen(filename, "r" as ^int8);
        void;
    } else {
        errors.begin();
        errors.print_error();
        errors.libc.fprintf(errors.libc.stderr,
            "no input filename given and `stdin` is empty" as ^int8);
        errors.end();
        libc.exit(-1);
        void;
    }

    # Declare the tokenizer.
    let mut t: tokenizer.Tokenizer = tokenizer.tokenizer_new(
        filename as str, file);

    # If we were to tokenize only; show the token stream and exit.
    if tokenize_only
    {
        let mut outstream: ^libc._IO_FILE;
        if output_filename <> 0 as ^int8 {
            outstream = libc.fopen(output_filename, "w" as ^int8);
        }

        # Iterate through each token in the input stream.
        loop {
            # Get the next token
            let mut tok: tokenizer.Token = t.next();

            # Print token if we're error-free
            if errors.count == 0 {
                if output_filename <> 0 as ^int8 {
                    tok.fprintln(outstream);
                } else {
                    tok.println();
                }
            }

            # Stop if we reach the end.
            if tok.tag == tokens.TOK_END { break; }

            # Dispose of the token.
            tok.dispose();
        }

        if output_filename <> 0 as ^int8 {
            libc.fclose(outstream);
        }

        # Dispose of the tokenizer.
        t.dispose();

        # Exit
        if errors.count > 0 { libc.exit(-1); }
        libc.exit(0);
    }

    # Determine the "module name"
    let module_name: str =
        if has_file {
            # HACK: HACK: HACK: nuff said
            (filename + libc.strlen(filename) - 3)^ = 0;
            filename as str;
        } else {
            "_";
        };

    # Declare the parser.
    let mut p: parser.Parser = parser.parser_new(module_name, t);

    # Parse the AST from the standard input.
    let unit: ast.Node = p.parse();
    if errors.count > 0 { libc.exit(-1); }

    # If we were to parse only; show the AST stream and exit.
    if parse_only
    {
        let mut outstream: ^libc._IO_FILE;
        if output_filename <> 0 as ^int8 {
            outstream = libc.fopen(output_filename, "w" as ^int8);
        }

        # Print the AST.
        if output_filename == 0 as ^int8 {
            ast.dump(unit);
        } else {
            ast.fdump(outstream, unit);
        }

        if output_filename <> 0 as ^int8 {
            libc.fclose(outstream);
        }

        # Dispose of the tokenizer and parser.
        t.dispose();
        p.dispose();

        # Exit successfully
        libc.exit(0);
    }

    # Close the stream.
    if has_file { libc.fclose(file); }

    # Die if we had errors.
    if errors.count > 0 { libc.exit(-1); }

    # Declare the generator.
    let mut g: generator_.Generator;

    # Walk the AST and generate the LLVM IR.
    generator.generate(g, "_", unit);
    if errors.count > 0 { libc.exit(-1); }

    # Output the generated LLVM IR.
    let data: ^int8 = llvm.LLVMPrintModuleToString(g.mod);

    if output_filename == 0 as ^int8 {
        printf("%s", data);
    } else {
        let outstream: ^libc._IO_FILE =
            libc.fopen(output_filename, "w" as ^int8);
        libc.fprintf(outstream, "%s" as ^int8, data);
        libc.fclose(outstream);
    }

    llvm.LLVMDisposeMessage(data);

    # Dispose of the resources used.
    # g.dispose();
    p.dispose();
    t.dispose();

    # Exit successfully
    libc.exit(0);
}
