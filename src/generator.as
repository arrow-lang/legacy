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
    # Construct a LLVM module to hold the geneated IR.
    g.mod = llvm.LLVMModuleCreateWithName(name as ^int8);

    # Construct an instruction builder.
    g.irb = llvm.LLVMCreateBuilder();

    # Initialize the internal data structures.
    let ptr_size: uint = types.sizeof(types.PTR);
    g.items = dict.make(65535);
    g.nodes = dict.make(65535);
    g.ns = list.make(types.STR);
    g.top_ns = string.make();

    # Build the "type resolution" jump table.
    libc.memset(&g.type_resolvers[0] as ^void, 0, 100 * ptr_size);
    g.type_resolvers[ast.TAG_IDENT] = resolvers.ident;
    g.type_resolvers[ast.TAG_INTEGER] = resolvers.integer;
    g.type_resolvers[ast.TAG_BOOLEAN] = resolvers.boolean;
    g.type_resolvers[ast.TAG_FLOAT] = resolvers.float;
    g.type_resolvers[ast.TAG_CALL] = resolvers.call;
    g.type_resolvers[ast.TAG_ADD] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_SUBTRACT] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_MULTIPLY] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_DIVIDE] = resolvers.divide;
    g.type_resolvers[ast.TAG_INTEGER_DIVIDE] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_MODULO] = resolvers.arithmetic_b;
    g.type_resolvers[ast.TAG_EQ] = resolvers.relational;
    g.type_resolvers[ast.TAG_NE] = resolvers.relational;
    g.type_resolvers[ast.TAG_LT] = resolvers.relational;
    g.type_resolvers[ast.TAG_LE] = resolvers.relational;
    g.type_resolvers[ast.TAG_GT] = resolvers.relational;
    g.type_resolvers[ast.TAG_GE] = resolvers.relational;
    g.type_resolvers[ast.TAG_TUPLE_EXPR] = resolvers.tuple;

    # Build the "builder" jump table.
    libc.memset(&g.builders[0] as ^void, 0, 100 * ptr_size);
    g.builders[ast.TAG_IDENT] = builders.ident;
    g.builders[ast.TAG_INTEGER] = builders.integer;
    g.builders[ast.TAG_BOOLEAN] = builders.boolean;
    g.builders[ast.TAG_FLOAT] = builders.float;
    g.builders[ast.TAG_CALL] = builders.call;
    g.builders[ast.TAG_ADD] = builders.arithmetic_b;
    g.builders[ast.TAG_SUBTRACT] = builders.arithmetic_b;
    g.builders[ast.TAG_MULTIPLY] = builders.arithmetic_b;
    g.builders[ast.TAG_DIVIDE] = builders.arithmetic_b;
    g.builders[ast.TAG_MODULO] = builders.arithmetic_b;
    g.builders[ast.TAG_INTEGER_DIVIDE] = builders.integer_divide;
    g.builders[ast.TAG_EQ] = builders.relational;
    g.builders[ast.TAG_NE] = builders.relational;
    g.builders[ast.TAG_LT] = builders.relational;
    g.builders[ast.TAG_LE] = builders.relational;
    g.builders[ast.TAG_GT] = builders.relational;
    g.builders[ast.TAG_GE] = builders.relational;

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
