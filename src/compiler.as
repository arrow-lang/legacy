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

    # Build options "description"
    let desc: libc.option[3];
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

    # ..end
    opt.name = 0 as ^int8;
    opt.has_arg = 0;
    opt.flag = 0 as ^int32;
    opt.val = 0;
    desc[1] = opt;

    while libc.optind < argc {
        # Initate the option parsing
        let option_index: int32 = 0;
        let c: int = libc.getopt_long(
            argc as int32, argv,
            "Vo:" as ^int8,
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
