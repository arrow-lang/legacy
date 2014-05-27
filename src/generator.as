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
import generator_;
import generator_util;
import generator_extract;
import generator_def;
import generator_decl;
import generator_type;
import builders;
import resolvers;

# Begin the generation process seeded by the passed AST node.
# =============================================================================
def generate(&mut g: generator_.Generator, name: str, &node: ast.Node) {
    # Ensure the x86 target is initialized.
    # NOTE: We should first ask configuration what our target is
    #   and attempt to initialize the right target.
    llvm.LLVMInitializeX86Target();
    llvm.LLVMInitializeX86TargetInfo();

    # Construct a LLVM module to hold the geneated IR.
    g.mod = llvm.LLVMModuleCreateWithName(name as ^int8);

    # Discern the triple for our target machine.
    # TODO: This should be a configuration option.
    # FIXME: At the very least this should be output with a verbose flag
    #        for debugging.
    let triple: ^int8 = llvm.LLVMGetDefaultTargetTriple();
    let error_: ^int8;
    let target_ref: ^llvm.LLVMTarget;
    if llvm.LLVMGetTargetFromTriple(triple, &target_ref, &error_) <> 0 {
        # Failed to get a valid target.
        errors.count = 1;
        return;
    }

    # Construct a target machine.
    # TODO: Pull together a list of features
    g.target_machine = llvm.LLVMCreateTargetMachine(
        target_ref, triple, "" as ^int8, "" as ^int8,
        2,  #  llvm.LLVMCodeGenLevelDefault,
        0,  #  llvm.LLVMRelocDefault,
        0); #  llvm.LLVMCodeModelDefault);

    # Set the target triple.
    llvm.LLVMSetTarget(g.mod, triple);

    # Get and set the data layout.
    g.target_data =
        llvm.LLVMGetTargetMachineData(g.target_machine);
    let data_layout: ^int8 = llvm.LLVMCopyStringRepOfTargetData(
        g.target_data);
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
    g.ns = list.make(types.STR);
    g.top_ns = string.make();
    g.loops = list.make_generic(generator_.LOOP_SIZE);

    # Build the "type resolution" jump table.
    libc.memset(&g.type_resolvers[0] as ^void, 0, (100 * ptr_size) as int32);
    g.type_resolvers[ast.TAG_IDENT] = resolvers.ident;
    g.type_resolvers[ast.TAG_INTEGER] = resolvers.integer;
    g.type_resolvers[ast.TAG_BOOLEAN] = resolvers.boolean;
    g.type_resolvers[ast.TAG_FLOAT] = resolvers.float;
    g.type_resolvers[ast.TAG_CALL] = resolvers.call;
    g.type_resolvers[ast.TAG_PROMOTE] = resolvers.arithmetic_u;
    g.type_resolvers[ast.TAG_NUMERIC_NEGATE] = resolvers.arithmetic_u;
    g.type_resolvers[ast.TAG_LOGICAL_NEGATE] = resolvers.arithmetic_u;
    g.type_resolvers[ast.TAG_BITNEG] = resolvers.arithmetic_u;
    g.type_resolvers[ast.TAG_ADD] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_SUBTRACT] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_MULTIPLY] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_DIVIDE] = resolvers.divide;
    g.type_resolvers[ast.TAG_INTEGER_DIVIDE] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_MODULO] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_BITAND] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_BITOR] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_BITXOR] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_EQ] = resolvers.relational;
    g.type_resolvers[ast.TAG_NE] = resolvers.relational;
    g.type_resolvers[ast.TAG_LT] = resolvers.relational;
    g.type_resolvers[ast.TAG_LE] = resolvers.relational;
    g.type_resolvers[ast.TAG_GT] = resolvers.relational;
    g.type_resolvers[ast.TAG_GE] = resolvers.relational;
    g.type_resolvers[ast.TAG_TUPLE_EXPR] = resolvers.tuple;
    g.type_resolvers[ast.TAG_TUPLE_TYPE] = resolvers.tuple_type;
    g.type_resolvers[ast.TAG_RETURN] = resolvers.pass;
    g.type_resolvers[ast.TAG_ASSIGN] = resolvers.assign;
    g.type_resolvers[ast.TAG_LOCAL_SLOT] = resolvers.pass;
    g.type_resolvers[ast.TAG_CONDITIONAL] = resolvers.conditional;
    g.type_resolvers[ast.TAG_SELECT] = resolvers.select;
    g.type_resolvers[ast.TAG_MEMBER] = resolvers.member;
    g.type_resolvers[ast.TAG_POINTER_TYPE] = resolvers.pointer_type;
    g.type_resolvers[ast.TAG_ADDRESS_OF] = resolvers.address_of;
    g.type_resolvers[ast.TAG_DEREF] = resolvers.dereference;
    g.type_resolvers[ast.TAG_CAST] = resolvers.cast;
    g.type_resolvers[ast.TAG_LOOP] = resolvers.loop_;
    g.type_resolvers[ast.TAG_BREAK] = resolvers.pass;
    g.type_resolvers[ast.TAG_CONTINUE] = resolvers.pass;
    g.type_resolvers[ast.TAG_ARRAY_TYPE] = resolvers.array_type;
    g.type_resolvers[ast.TAG_INDEX] = resolvers.index;
    g.type_resolvers[ast.TAG_ARRAY_EXPR] = resolvers.array;

    # Build the "builder" jump table.
    libc.memset(&g.builders[0] as ^void, 0, (100 * ptr_size) as int32);
    g.builders[ast.TAG_IDENT] = builders.ident;
    g.builders[ast.TAG_INTEGER] = builders.integer;
    g.builders[ast.TAG_BOOLEAN] = builders.boolean;
    g.builders[ast.TAG_FLOAT] = builders.float;
    g.builders[ast.TAG_CALL] = builders.call;
    g.builders[ast.TAG_PROMOTE] = builders.arithmetic_u;
    g.builders[ast.TAG_NUMERIC_NEGATE] = builders.arithmetic_u;
    g.builders[ast.TAG_LOGICAL_NEGATE] = builders.arithmetic_u;
    g.builders[ast.TAG_BITNEG] = builders.arithmetic_u;
    g.builders[ast.TAG_ADD] = builders.arithmetic_b;
    g.builders[ast.TAG_SUBTRACT] = builders.arithmetic_b;
    g.builders[ast.TAG_MULTIPLY] = builders.arithmetic_b;
    g.builders[ast.TAG_DIVIDE] = builders.arithmetic_b;
    g.builders[ast.TAG_MODULO] = builders.arithmetic_b;
    g.builders[ast.TAG_BITAND] = builders.arithmetic_b;
    g.builders[ast.TAG_BITOR] = builders.arithmetic_b;
    g.builders[ast.TAG_BITXOR] = builders.arithmetic_b;
    g.builders[ast.TAG_INTEGER_DIVIDE] = builders.integer_divide;
    g.builders[ast.TAG_EQ] = builders.relational;
    g.builders[ast.TAG_NE] = builders.relational;
    g.builders[ast.TAG_LT] = builders.relational;
    g.builders[ast.TAG_LE] = builders.relational;
    g.builders[ast.TAG_GT] = builders.relational;
    g.builders[ast.TAG_GE] = builders.relational;
    g.builders[ast.TAG_RETURN] = builders.return_;
    g.builders[ast.TAG_ASSIGN] = builders.assign;
    g.builders[ast.TAG_LOCAL_SLOT] = builders.local_slot;
    g.builders[ast.TAG_CONDITIONAL] = builders.conditional;
    g.builders[ast.TAG_SELECT] = builders.select;
    g.builders[ast.TAG_MEMBER] = builders.member;
    g.builders[ast.TAG_ADDRESS_OF] = builders.address_of;
    g.builders[ast.TAG_DEREF] = builders.dereference;
    g.builders[ast.TAG_CAST] = builders.cast;
    g.builders[ast.TAG_LOOP] = builders.loop_;
    g.builders[ast.TAG_BREAK] = builders.break_;
    g.builders[ast.TAG_CONTINUE] = builders.continue_;
    g.builders[ast.TAG_ARRAY_TYPE] = builders.array_type;
    g.builders[ast.TAG_POINTER_TYPE] = builders.pointer_type;
    g.builders[ast.TAG_INDEX] = builders.index;
    g.builders[ast.TAG_ARRAY_EXPR] = builders.array;
    g.builders[ast.TAG_TUPLE_TYPE] = builders.tuple_type;

    # Add basic type definitions.
    generator_util.declare_basic_types(g);

    # Add `assert` built-in.
    generator_util.declare_assert(g);

    # Generation is a complex beast. So we first need to break apart
    # the declarations or "items" from the nodes. As all nodes are owned
    # by "some" declaration (`module`, `function`, `struct`, etc.) this
    # effectually removes the AST structure.
    generator_extract.extract(g, node);
    if errors.count > 0 { return; }

    # Next we resolve the type of each item that we extracted.
    generator_type.generate(g);
    if errors.count > 0 { return; }

    # Next we generate decls for each "item".
    generator_decl.generate(g);
    if errors.count > 0 { return; }

    # # Next we generate defs for each "item".
    generator_def.generate(g);
    if errors.count > 0 { return; }

    # Generate a main function.
    generator_util.declare_main(g);
}

# Test driver using `stdin`.
# =============================================================================
def main() {
    # Declare the parser.
    let mut p: parser.Parser;

    # Parse the AST from the standard input.
    let unit: ast.Node = p.parse("_");
    if errors.count > 0 { libc.exit(-1); }

    # Declare the generator.
    let mut g: generator_.Generator;

    # Walk the AST and generate the LLVM IR.
    generate(g, "_", unit);
    if errors.count > 0 { libc.exit(-1); }

    # Output the generated LLVM IR.
    let data: ^int8 = llvm.LLVMPrintModuleToString(g.mod);
    printf("%s", data);
    llvm.LLVMDisposeMessage(data);

    # Dispose of the resources used.
    g.dispose();

    # Return success back to the envrionment.
    libc.exit(0);
}
