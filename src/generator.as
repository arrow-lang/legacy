foreign "C" import "llvm-c/Core.h";
foreign "C" import "llvm-c/Analysis.h";
foreign "C" import "llvm-c/ExecutionEngine.h";
foreign "C" import "llvm-c/Target.h";
foreign "C" import "llvm-c/Transforms/Scalar.h";

module libc {
    foreign "C" import "stdlib.h";
    foreign "C" import "stdio.h";
}

import ast;
import parser;
import errors;
import dict;
import list;

# Some process variables
let mut _module: ^LLVMOpaqueModule;
let mut _builder: ^LLVMOpaqueBuilder;
let mut _global: dict.Dictionary = dict.make();

# Termination cleanup.
libc.atexit(dispose);
def dispose() {
    LLVMDisposeModule(_module);
    _global.dispose();
}

def main() {
    # Parse the AST from the standard input.
    let unit: ast.Node = parser.parse();
    if errors.count > 0 { libc.exit(-1); }

    # Construct a LLVM module to hold the geneated IR.
    _module = LLVMModuleCreateWithName("_" as ^int8);

    # Construct an instruction builder.
    _builder = LLVMCreateBuilder();

    # Walk the AST and generate the LLVM IR.
    generate(&unit);

    # Output the generated LLVM IR.
    LLVMDumpModule(_module);

    # Return success back to the envrionment.
    libc.exit(0);
}

# generate -- "Generic" generation dispatcher
# -----------------------------------------------------------------------------
let mut gen_table: (def(^ast.Node) -> ^LLVMOpaqueValue)[100];
let mut gen_initialized: bool = false;
def generate(node: ^ast.Node) {
    if not gen_initialized {
        gen_table[ast.TAG_INTEGER] = generate_nil;
        gen_table[ast.TAG_FLOAT] = generate_nil;
        gen_table[ast.TAG_BOOLEAN] = generate_nil;
        gen_table[ast.TAG_ADD] = generate_nil;
        gen_table[ast.TAG_SUBTRACT] = generate_nil;
        gen_table[ast.TAG_MULTIPLY] = generate_nil;
        gen_table[ast.TAG_DIVIDE] = generate_nil;
        gen_table[ast.TAG_MODULO] = generate_nil;
        gen_table[ast.TAG_MODULE] = generate_module;
        gen_table[ast.TAG_PROMOTE] = generate_nil;
        gen_table[ast.TAG_NUMERIC_NEGATE] = generate_nil;
        gen_table[ast.TAG_LOGICAL_NEGATE] = generate_nil;
        gen_table[ast.TAG_LOGICAL_AND] = generate_nil;
        gen_table[ast.TAG_LOGICAL_OR] = generate_nil;
        gen_table[ast.TAG_EQ] = generate_nil;
        gen_table[ast.TAG_NE] = generate_nil;
        gen_table[ast.TAG_LT] = generate_nil;
        gen_table[ast.TAG_LE] = generate_nil;
        gen_table[ast.TAG_GT] = generate_nil;
        gen_table[ast.TAG_GE] = generate_nil;
        gen_table[ast.TAG_ASSIGN] = generate_nil;
        gen_table[ast.TAG_ASSIGN_ADD] = generate_nil;
        gen_table[ast.TAG_ASSIGN_SUB] = generate_nil;
        gen_table[ast.TAG_ASSIGN_MULT] = generate_nil;
        gen_table[ast.TAG_ASSIGN_DIV] = generate_nil;
        gen_table[ast.TAG_ASSIGN_MOD] = generate_nil;
        gen_table[ast.TAG_SELECT_OP] = generate_nil;
        gen_table[ast.TAG_STATIC_SLOT] = generate_static_slot;
        gen_table[ast.TAG_LOCAL_SLOT] = generate_nil;
        gen_table[ast.TAG_IDENT] = generate_ident;
        gen_table[ast.TAG_SELECT] = generate_nil;
        gen_table[ast.TAG_SELECT_BRANCH] = generate_nil;
        gen_table[ast.TAG_CONDITIONAL] = generate_nil;
        gen_table[ast.TAG_FUNC_DECL] = generate_func_decl;
        gen_table[ast.TAG_FUNC_PARAM] = generate_nil;
        gen_table[ast.TAG_UNSAFE] = generate_nil;
        gen_table[ast.TAG_BLOCK] = generate_nil;
        gen_table[ast.TAG_RETURN] = generate_nil;
        gen_table[ast.TAG_MEMBER] = generate_nil;
        gen_initialized = true;
    }

    let gen_fn: def(^ast.Node) -> ^LLVMOpaqueValue = gen_table[node.tag];
    let node_ptr: ^ast.Node = node;
    gen_fn(node_ptr);
}

# generate_nil
# -----------------------------------------------------------------------------
def generate_nil(node: ^ast.Node) -> ^LLVMOpaqueValue {
    printf("generate %d\n", node.tag);
    0 as ^LLVMOpaqueValue;
}

# generate_ident
# -----------------------------------------------------------------------------
def generate_ident(node: ^ast.Node) -> ^LLVMOpaqueValue {
    let x: ^ast.Ident = ast.unwrap(node^) as ^ast.Ident;

    # Get the name for the identifier.
    let name: ast.arena.Store = x.name;

    # Check for the identifier in the `global` scope.
    let handle: ^LLVMOpaqueValue;
    handle = _global.get_ptr(name._data as str) as ^LLVMOpaqueValue;

    # Create a load instruction to get at the value.
    LLVMBuildLoad(_builder, handle, "" as ^int8);
}

# generate_integer_expr
# -----------------------------------------------------------------------------
def generate_integer_expr(node: ^ast.Node) -> ^LLVMOpaqueValue {
    # Nothing generated.
    0 as ^LLVMOpaqueValue;
}

# generate_nodes
# -----------------------------------------------------------------------------
def generate_nodes(&nodes: ast.Nodes) {
    # Enumerate through each node.
    let mut iter: ast.NodesIterator = ast.iter_nodes(nodes);
    while not ast.iter_empty(iter) {
        let node: ast.Node = ast.iter_next(iter);
        generate(&node);
    }
}

# generate_module
# -----------------------------------------------------------------------------
def generate_module(node: ^ast.Node) -> ^LLVMOpaqueValue {
    let x: ^ast.ModuleDecl = ast.unwrap(node^) as ^ast.ModuleDecl;

    # Generate each node in the module.
    generate_nodes(x.nodes);

    # Nothing generated.
    0 as ^LLVMOpaqueValue;
}

# generate_static_slot
# -----------------------------------------------------------------------------
def generate_static_slot(node: ^ast.Node) -> ^LLVMOpaqueValue {
    let x: ^ast.StaticSlotDecl = ast.unwrap(node^) as ^ast.StaticSlotDecl;

    # Get the name for the slot.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let name: ast.arena.Store = id.name;

    # Resolve the slot type.
    let type_: ^LLVMOpaqueType;
    type_ = LLVMInt32Type();

    # Add the global slot declaration to the IR.
    let handle: ^LLVMOpaqueValue;
    handle = LLVMAddGlobal(_module, type_, name._data);

    # Set us in the global scope.
    _global.set_ptr(name._data as str, handle as ^void);

    # Slot declarations return nothing.
    0 as ^LLVMOpaqueValue;
}

# generate_func_decl
# -----------------------------------------------------------------------------
def generate_func_decl(node: ^ast.Node) -> ^LLVMOpaqueValue {
    let x: ^ast.FuncDecl = (node^).unwrap() as ^ast.FuncDecl;

    # Get the name for the function.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let name: ast.arena.Store = id.name;

    # Resolve the function type.
    let type_: ^LLVMOpaqueType;
    type_ = LLVMFunctionType(LLVMVoidType(),
                             0 as ^^LLVMOpaqueType,
                             0,
                             0);

    # Add the function declaration to the IR.
    let handle: ^LLVMOpaqueValue;
    handle = LLVMAddFunction(_module, name._data, type_);

    # Create a basic block for the function definition.
    let block_handle: ^LLVMOpaqueBasicBlock;
    block_handle = LLVMAppendBasicBlock(handle, "" as ^int8);

    # Set the insertion point.
    LLVMPositionBuilderAtEnd(_builder, block_handle);

    # Generate each node in the function.
    generate_nodes(x.nodes);

    # Return the constructed node.
    handle;
}
