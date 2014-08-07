import llvm;
import string;
import libc;
import ast;
import parser;
import errors;
import dict;
import list;
import types;
import code;
import tokenizer;
import generator_;
import generator_util;
# import generator_extract;
# import generator_def;
# import generator_decl;
# import generator_type;
# import generator_realize;
# import builders;
# import resolvers;

# Begin the generation process seeded by the passed AST node.
# =============================================================================
let generate(mut g: generator_.Generator, name: str, node: ast.Node) -> {
    # Ensure the x86 target is initialized.
    # NOTE: We should first ask configuration what our target is
    #   and attempt to initialize the right target.
    llvm.LLVMInitializeX86Target();
    llvm.LLVMInitializeX86TargetInfo();

    # Construct a LLVM module to hold the geneated IR.
    g.mod = llvm.LLVMModuleCreateWithName(name);

    # Discern the triple for our target machine.
    # TODO: This should be a configuration option.
    # FIXME: At the very least this should be output with a verbose flag
    #        for debugging.
    let triple: str = llvm.LLVMGetDefaultTargetTriple();
    let mut error_: str;
    let target_ref: *llvm.LLVMTarget;
    if llvm.LLVMGetTargetFromTriple(triple, &target_ref, &error_) != 0 {
        # Failed to get a valid target.
        errors.count = 1;
        return;
    };

    # Construct a target machine.
    # TODO: Pull together a list of features
    g.target_machine = llvm.LLVMCreateTargetMachine(
        target_ref, triple, "", "",
        2,  #  llvm.LLVMCodeGenLevelDefault,
        0,  #  llvm.LLVMRelocDefault,
        0); #  llvm.LLVMCodeModelDefault);

    # Set the target triple.
    llvm.LLVMSetTarget(g.mod, triple);

    # Get and set the data layout.
    g.target_data = llvm.LLVMGetTargetMachineData(g.target_machine);
    let data_layout = llvm.LLVMCopyStringRepOfTargetData(g.target_data);
    llvm.LLVMSetDataLayout(g.mod, data_layout);

    # Dispose of the used triple.
    llvm.LLVMDisposeMessage(triple);
    llvm.LLVMDisposeMessage(data_layout);

    # Construct an instruction builder.
    g.irb = llvm.LLVMCreateBuilder();

    # Initialize the internal data structures.
    let ptr_size: uint = types.sizeof(types.PTR);
    g.items = dict.make(65535);
    g.nodes = dict.make(65535);
    g.imported_modules = dict.make(65535);
    g.ns = list.List.new(types.STR);
    g.top_ns = string.String.new();
    g.loops = list.List.with_element_size(size_of(generator_.Loop));
    g.attached_functions = list.List.new(types.PTR);
    g.current_self = code.make_nil();

    # Build the "type resolution" jump table.
    libc.memset(&g.type_resolvers[0] as *int8, 0, (100 * ptr_size) as int32);
#     g.type_resolvers[ast.TAG_IDENT] = resolvers.ident;
#     g.type_resolvers[ast.TAG_INTEGER] = resolvers.integer;
#     g.type_resolvers[ast.TAG_BOOLEAN] = resolvers.boolean;
#     g.type_resolvers[ast.TAG_FLOAT] = resolvers.float;
#     g.type_resolvers[ast.TAG_CALL] = resolvers.call;
#     g.type_resolvers[ast.TAG_LOGICAL_AND] = resolvers.logical;
#     g.type_resolvers[ast.TAG_LOGICAL_OR] = resolvers.logical;
#     g.type_resolvers[ast.TAG_PROMOTE] = resolvers.arithmetic_u;
#     g.type_resolvers[ast.TAG_NUMERIC_NEGATE] = resolvers.arithmetic_u;
#     g.type_resolvers[ast.TAG_LOGICAL_NEGATE] = resolvers.arithmetic_u;
#     g.type_resolvers[ast.TAG_BITNEG] = resolvers.arithmetic_u;
#     g.type_resolvers[ast.TAG_ADD] = resolvers.arithmetic_b;
#     g.type_resolvers[ast.TAG_SUBTRACT] = resolvers.arithmetic_b;
#     g.type_resolvers[ast.TAG_MULTIPLY] = resolvers.arithmetic_b;
#     g.type_resolvers[ast.TAG_DIVIDE] = resolvers.divide;
#     g.type_resolvers[ast.TAG_INTEGER_DIVIDE] = resolvers.arithmetic_b;
#     g.type_resolvers[ast.TAG_MODULO] = resolvers.arithmetic_b;
#     g.type_resolvers[ast.TAG_BITAND] = resolvers.arithmetic_b;
#     g.type_resolvers[ast.TAG_BITOR] = resolvers.arithmetic_b;
#     g.type_resolvers[ast.TAG_BITXOR] = resolvers.arithmetic_b;
#     g.type_resolvers[ast.TAG_EQ] = resolvers.relational;
#     g.type_resolvers[ast.TAG_NE] = resolvers.relational;
#     g.type_resolvers[ast.TAG_LT] = resolvers.relational;
#     g.type_resolvers[ast.TAG_LE] = resolvers.relational;
#     g.type_resolvers[ast.TAG_GT] = resolvers.relational;
#     g.type_resolvers[ast.TAG_GE] = resolvers.relational;
#     g.type_resolvers[ast.TAG_TUPLE_EXPR] = resolvers.tuple;
#     g.type_resolvers[ast.TAG_TUPLE_TYPE] = resolvers.tuple_type;
#     g.type_resolvers[ast.TAG_RETURN] = resolvers.return_;
#     g.type_resolvers[ast.TAG_ASSIGN] = resolvers.assign;
#     g.type_resolvers[ast.TAG_SLOT] = resolvers.pass;
#     g.type_resolvers[ast.TAG_CONDITIONAL] = resolvers.conditional;
#     g.type_resolvers[ast.TAG_SELECT] = resolvers.select;
#     g.type_resolvers[ast.TAG_MEMBER] = resolvers.member;
#     g.type_resolvers[ast.TAG_POINTER_TYPE] = resolvers.pointer_type;
#     g.type_resolvers[ast.TAG_ADDRESS_OF] = resolvers.address_of;
#     g.type_resolvers[ast.TAG_DEREF] = resolvers.dereference;
#     g.type_resolvers[ast.TAG_CAST] = resolvers.cast;
#     g.type_resolvers[ast.TAG_LOOP] = resolvers.loop_;
#     g.type_resolvers[ast.TAG_BREAK] = resolvers.pass;
#     g.type_resolvers[ast.TAG_CONTINUE] = resolvers.pass;
#     g.type_resolvers[ast.TAG_ARRAY_TYPE] = resolvers.array_type;
#     g.type_resolvers[ast.TAG_INDEX] = resolvers.index;
#     g.type_resolvers[ast.TAG_ARRAY_EXPR] = resolvers.array;
#     g.type_resolvers[ast.TAG_STRING] = resolvers.string_;
#     g.type_resolvers[ast.TAG_SELF] = resolvers.self_;
#     g.type_resolvers[ast.TAG_DELEGATE] = resolvers.delegate;
#     g.type_resolvers[ast.TAG_SIZEOF] = resolvers.sizeof;

    # Build the "builder" jump table.
    libc.memset(&g.builders[0] as *int8, 0, (100 * ptr_size) as int32);
#     g.builders[ast.TAG_IDENT] = builders.ident;
#     g.builders[ast.TAG_SIZEOF] = builders.sizeof;
#     g.builders[ast.TAG_INTEGER] = builders.integer;
#     g.builders[ast.TAG_BOOLEAN] = builders.boolean;
#     g.builders[ast.TAG_FLOAT] = builders.float;
#     g.builders[ast.TAG_LOGICAL_AND] = builders.logical;
#     g.builders[ast.TAG_LOGICAL_OR] = builders.logical;
#     g.builders[ast.TAG_CALL] = builders.call;
#     g.builders[ast.TAG_PROMOTE] = builders.arithmetic_u;
#     g.builders[ast.TAG_NUMERIC_NEGATE] = builders.arithmetic_u;
#     g.builders[ast.TAG_LOGICAL_NEGATE] = builders.arithmetic_u;
#     g.builders[ast.TAG_BITNEG] = builders.arithmetic_u;
#     g.builders[ast.TAG_ADD] = builders.arithmetic_b;
#     g.builders[ast.TAG_SUBTRACT] = builders.arithmetic_b;
#     g.builders[ast.TAG_MULTIPLY] = builders.arithmetic_b;
#     g.builders[ast.TAG_DIVIDE] = builders.arithmetic_b;
#     g.builders[ast.TAG_MODULO] = builders.arithmetic_b;
#     g.builders[ast.TAG_BITAND] = builders.arithmetic_b;
#     g.builders[ast.TAG_BITOR] = builders.arithmetic_b;
#     g.builders[ast.TAG_BITXOR] = builders.arithmetic_b;
#     g.builders[ast.TAG_INTEGER_DIVIDE] = builders.integer_divide;
#     g.builders[ast.TAG_EQ] = builders.relational;
#     g.builders[ast.TAG_NE] = builders.relational;
#     g.builders[ast.TAG_LT] = builders.relational;
#     g.builders[ast.TAG_LE] = builders.relational;
#     g.builders[ast.TAG_GT] = builders.relational;
#     g.builders[ast.TAG_GE] = builders.relational;
#     g.builders[ast.TAG_RETURN] = builders.return_;
#     g.builders[ast.TAG_ASSIGN] = builders.assign;
#     g.builders[ast.TAG_SLOT] = builders.local_slot;
#     g.builders[ast.TAG_CONDITIONAL] = builders.conditional;
#     g.builders[ast.TAG_SELECT] = builders.select;
#     g.builders[ast.TAG_MEMBER] = builders.member;
#     g.builders[ast.TAG_ADDRESS_OF] = builders.address_of;
#     g.builders[ast.TAG_DEREF] = builders.dereference;
#     g.builders[ast.TAG_CAST] = builders.cast;
#     g.builders[ast.TAG_LOOP] = builders.loop_;
#     g.builders[ast.TAG_BREAK] = builders.break_;
#     g.builders[ast.TAG_CONTINUE] = builders.continue_;
#     # g.builders[ast.TAG_ARRAY_TYPE] = builders.array_type;
#     # g.builders[ast.TAG_POINTER_TYPE] = builders.pointer_type;
#     g.builders[ast.TAG_INDEX] = builders.index;
#     g.builders[ast.TAG_ARRAY_EXPR] = builders.array;
#     g.builders[ast.TAG_TUPLE_EXPR] = builders.tuple;
#     g.builders[ast.TAG_STRING] = builders.string_;
#     g.builders[ast.TAG_SELF] = builders.self_;

    # Add basic type definitions.
    generator_util.declare_basic_types(g);

    # Add `assert` built-in.
    generator_util.declare_assert(g);

#     # Generation is a complex beast. So we first need to break apart
#     # the declarations or "items" from the nodes. As all nodes are owned
#     # by "some" declaration (`module`, `function`, `struct`, etc.) this
#     # effectually removes the AST structure.
#     generator_extract.extract(g, node);
#     if errors.count > 0 { return; }

#     # Next we realize the type of each item that we extracted.
#     generator_realize.generate(g);
#     if errors.count > 0 { return; }

#     # Next we resolve the type of each item that we extracted.
#     generator_type.generate(g);
#     if errors.count > 0 { return; }

#     # Next we generate decls for each "item".
#     generator_decl.generate(g);
#     if errors.count > 0 { return; }

#     # Next we generate defs for each "item".
#     generator_def.generate(g);
#     if errors.count > 0 { return; }

    # Generate a main function.
    declare_main(g);
}

# Declare the `main` function.
# -----------------------------------------------------------------------------
let declare_main(mut g: generator_.Generator) -> {
    # Qualify a module main name.
    let mut name: string.String = string.String.new();
    name.extend(g.top_ns.data() as str);
    name.append('.');
    name.extend("main");

    # Was their a main function defined?
    let mut module_main_fn_returns: bool = false;
    let mut module_main_fn: *llvm.LLVMOpaqueValue = 0 as *llvm.LLVMOpaqueValue;
    let mut module_main_fn_han: *code.Function;
    let mut module_main_fn_type: *code.FunctionType;
    if g.items.contains(name.data() as str) {
        let mut module_main_han: *code.Handle;
        module_main_han = g.items.get_ptr(name.data() as str) as *code.Handle;
        module_main_fn_han = module_main_han._object as *code.Function;
        module_main_fn = module_main_fn_han.handle;
        let mut module_main_fn_type_han: *code.Handle = module_main_fn_han.type_;
        module_main_fn_type = module_main_fn_type_han._object as
            *code.FunctionType;

        # Does the module main function return?
        module_main_fn_returns =
            module_main_fn_type.return_type._tag != code.TAG_VOID_TYPE;

        # Does the module main function take arguments?
        if module_main_fn_type.parameters.size > 3 {
            # Yes; but too many.
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                                "too many parameters (4) for 'main': must be 0, 2, or 3");
            errors.end();

            return;
        } else if module_main_fn_type.parameters.size == 1 {
            # Yes; but not enough
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                                "only one parameter for 'main': must be 0, 2, or 3");
            errors.end();

            return;
        } else if module_main_fn_type.parameters.size > 0 {
            # Test the type of the first parameter of main.
            let mut param_han: *code.Handle = module_main_fn_type.parameters.get_ptr(0) as *code.Handle;
            let mut param: *code.Parameter = param_han._object as *code.Parameter;
            let mut param_type_match: bool = false;
            if param.type_._tag == code.TAG_INT_TYPE {
                let int_ty: *code.IntegerType = param.type_._object as *code.IntegerType;
                if int_ty.bits == 32 {
                    param_type_match = true;
                };
            };
            if not param_type_match {
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                                    "first parameter of 'main' (argument count) must be of type 'int32'");
                errors.end();

                return;
            };

            # Test the type of the second parameter of main.
            param_han = module_main_fn_type.parameters.get_ptr(1) as *code.Handle;
            param = param_han._object as *code.Parameter;
            param_type_match = false;
            if param.type_._tag == code.TAG_POINTER_TYPE {
                let ptrty: *code.PointerType = param.type_._object as *code.PointerType;
                if ptrty.pointee._tag == code.TAG_STR_TYPE {
                    param_type_match = true;
                };
            };
            if not param_type_match {
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                                    "second parameter of 'main' (argument array) must be of type '*str'");
                errors.end();

                return;
            };

            if module_main_fn_type.parameters.size == 3 {
                # Test the type of the third parameter of main.
                param_han = module_main_fn_type.parameters.get_ptr(2) as *code.Handle;
                param = param_han._object as *code.Parameter;
                param_type_match = false;
                if param.type_._tag == code.TAG_POINTER_TYPE {
                    let ptrty: *code.PointerType = param.type_._object as *code.PointerType;
                    if ptrty.pointee._tag == code.TAG_STR_TYPE {
                        param_type_match = true;
                    };
                };
                if not param_type_match {
                    errors.begin_error();
                    errors.libc.fprintf(errors.libc.stderr,
                                        "third parameter of 'main' (environment) must be of type '*str'");
                    errors.end();

                    return;
                };
            };
        };
    };

    # Build an array of argument types for the `main` fn.
    let mut main_param_types: list.List = list.List.new(types.PTR);
    main_param_types.push_ptr(llvm.LLVMInt32Type() as *int8);
    main_param_types.push_ptr(llvm.LLVMPointerType(llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0), 0) as *int8);
    main_param_types.push_ptr(llvm.LLVMPointerType(llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0), 0) as *int8);

    # Build the LLVM type for the `main` fn.
    let main_type: *llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMInt32Type(),
        main_param_types.elements as *llvm.LLVMOpaqueType,
        main_param_types.size as uint32, 0);

    # Build the LLVM function for `main`.
    let main_fn: *llvm.LLVMOpaqueValue = llvm.LLVMAddFunction(
        g.mod, "main", main_type);

    # Build the LLVM function definition.
    let mut entry_block: *llvm.LLVMOpaqueBasicBlock;
    entry_block = llvm.LLVMAppendBasicBlock(main_fn, "");
    llvm.LLVMPositionBuilderAtEnd(g.irb, entry_block);

    # Iterate and add argument places for main arguments.
    let mut main_args: list.List = list.List.new(types.PTR);
    let mut arg_idx: uint = 0;
    if module_main_fn != 0 as *llvm.LLVMOpaqueValue {
        while arg_idx < module_main_fn_type.parameters.size {
            # Get the parameter handle.
            let mut prm_val: *llvm.LLVMOpaqueValue;
            prm_val = llvm.LLVMGetParam(main_fn, arg_idx as uint32);

            # Push the parameter onto the argument list for main.
            main_args.push_ptr(prm_val as *int8);
            arg_idx = arg_idx + 1;
        }
    };

    let mut main_res: *llvm.LLVMOpaqueValue;
    if module_main_fn != 0 as *llvm.LLVMOpaqueValue {
        # Create a `call` to the module main method.
        main_res = llvm.LLVMBuildCall(
            g.irb, module_main_fn,
            main_args.elements as *llvm.LLVMOpaqueValue,
            main_args.size as uint32,
            "");
    };

    # Dispose
    main_param_types.dispose();
    main_args.dispose();

    # If the main is supposed to return ...
    if module_main_fn_returns
    {
        # # Wrap the value.
        # let val: *code.Handle = code.make_value(
        #     module_main_fn_type.return_type,
        #     code.VC_RVALUE,
        #     main_res);

        # # Coerce to value.
        # let val_han: *code.Handle = generator_def.to_value(
        #     g, val, code.VC_RVALUE, false);
        # if code.isnil(val_han) { return; };

        # # Build the cast.
        # let cast_han: *code.Handle = generator_util.cast(
        #     g, val, g.items.get_ptr("int32") as *code.Handle, true);
        # if code.isnil(cast_han) { return; };

        # # Get the value.
        # let cast_val: *code.Value = cast_han._object as *code.Value;

        # # Add the `ret` instruction to terminate the function.
        # llvm.LLVMBuildRet(g.irb, cast_val.handle);
    }
    else
    {
        # Create a constant 0.
        let mut zero: *llvm.LLVMOpaqueValue;
        zero = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, false);

        # Add the `ret int8` instruction to terminate the function.
        llvm.LLVMBuildRet(g.irb, zero);
    };

    # Dispose.
    name.dispose();
}
