foreign "C" import "llvm-c/Core.h";
foreign "C" import "llvm-c/Analysis.h";
foreign "C" import "llvm-c/ExecutionEngine.h";
foreign "C" import "llvm-c/Target.h";
foreign "C" import "llvm-c/Transforms/Scalar.h";

import string;
import libc;
import ast;
import parser;
import errors;
import dict;
import list;
import types;
import code;

# Some process variables
let mut _module: ^LLVMOpaqueModule;
let mut _builder: ^LLVMOpaqueBuilder;
let mut _global: dict.Dictionary = dict.make();
let mut _namespace: list.List = list.make(types.STR);

# Termination cleanup.
libc.atexit(dispose);
def dispose() {
    LLVMDisposeModule(_module);
    # FIXME: Dispose of each handle in the global scope.
    _global.dispose();
    _namespace.dispose();
}

def main() {
    # Parse the AST from the standard input.
    let unit: ast.Node = parser.parse();
    if errors.count > 0 { libc.exit(-1); }

    # Insert the primitive types into the global scope.
    _declare_primitive_types();

    # Construct a LLVM module to hold the geneated IR.
    _module = LLVMModuleCreateWithName("_" as ^int8);

    # Construct an instruction builder.
    _builder = LLVMCreateBuilder();

    # Walk the AST and generate the LLVM IR.
    generate(&unit);

    # Output the generated LLVM IR.
    let data: ^int8 = LLVMPrintModuleToString(_module);
    printf("%s", data);
    LLVMDisposeMessage(data);

    # Return success back to the envrionment.
    libc.exit(0);
}

# declare_type -- Declare a type in `global` scope.
# -----------------------------------------------------------------------------
def _declare_type(name: str, val: ^LLVMOpaqueType) {
    let han: ^code.Handle = code.make_type(val);
    _global.set_ptr(name, han as ^void);
}

# declare_builtin_types
# -----------------------------------------------------------------------------
def _declare_primitive_types() {
    # Boolean
    _declare_type("bool", LLVMInt1Type());

    # Signed machine-independent integers
    _declare_type(  "int8",   LLVMInt8Type());
    _declare_type( "int16",  LLVMInt16Type());
    _declare_type( "int32",  LLVMInt32Type());
    _declare_type( "int64",  LLVMInt64Type());
    _declare_type("int128", LLVMIntType(128));

    # Unsigned machine-independent integers
    _declare_type(  "uint8",   LLVMInt8Type());
    _declare_type( "uint16",  LLVMInt16Type());
    _declare_type( "uint32",  LLVMInt32Type());
    _declare_type( "uint64",  LLVMInt64Type());
    _declare_type("uint128", LLVMIntType(128));

    # Floating-points
    _declare_type("float32", LLVMFloatType());
    _declare_type("float64", LLVMDoubleType());

    # TODO: Unsigned machine-dependent integer

    # TODO: Signed machine-dependent integer

    # TODO: UTF-32 Character

    # TODO: UTF-8 String
}

# Qualify the passed name in the passed namespace.
# -----------------------------------------------------------------------------
def _qualify_name_in(s: str, ns: list.List) -> string.String {
    let mut qn: string.String;
    qn = string.join(".", ns);
    if qn.size() > 0 { qn.append('.'); }
    qn.extend(s);
    qn;
}

# Qualify the passed name in the current namespace.
# -----------------------------------------------------------------------------
def _qualify_name(s: str) -> string.String {
    _qualify_name_in(s, _namespace);
}

# generate -- "Generic" generation dispatcher
# -----------------------------------------------------------------------------
let mut gen_table: (def(^ast.Node) -> ^code.Handle)[100];
let mut gen_initialized: bool = false;
def generate(node: ^ast.Node) -> ^code.Handle {
    if not gen_initialized {
        gen_table[ast.TAG_INTEGER] = generate_nil;
        gen_table[ast.TAG_FLOAT] = generate_nil;
        gen_table[ast.TAG_BOOLEAN] = generate_nil;
        gen_table[ast.TAG_ADD] = generate_add_expr;
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
        gen_table[ast.TAG_MEMBER] = generate_member_expr;
        gen_initialized = true;
    }

    let gen_fn: def(^ast.Node) -> ^code.Handle = gen_table[node.tag];
    let node_ptr: ^ast.Node = node;
    gen_fn(node_ptr);
}

# generate_nil
# -----------------------------------------------------------------------------
def generate_nil(node: ^ast.Node) -> ^code.Handle {
    printf("generate %d\n", node.tag);

    # Generate a nil handle.
    code.make_nil();
}

# generate_ident
# -----------------------------------------------------------------------------
def generate_ident(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.Ident = ast.unwrap(node^) as ^ast.Ident;
    let val: ^LLVMOpaqueValue;

    # Get the name for the identifier.
    let name_data: ast.arena.Store = x.name;
    let name: str = name_data._data as str;

    # Qualify the name reference and match against the enclosing
    # scopes by resolving inner-most first and popping namespaces until
    # a match.
    let mut qual_name: string.String = string.make();
    let mut namespace: list.List = _namespace.clone();
    let mut matched: bool = false;
    loop {
        # Qualify the name by joining the namespaces.
        qual_name.dispose();
        qual_name = _qualify_name_in(name, namespace);

        # Check for the qualified identifier in the `global` scope.
        if _global.contains(qual_name.data() as str) {
            # Found it in the currently resolved scope.
            matched = true;
            break;
        }

        # Do we have any namespaces left.
        if namespace.size > 0 {
            namespace.erase(-1);
        } else {
            # Out of namespaces to pop.
            break;
        }
    }

    # Check if we still haven't found it.
    # HACK: Weird type target saying we're returning a bool
    if not matched {
        # FIXME: Report an error.
        code.make_nil();
    } else {
        # Retrieve the `global` identifier.
        let han: ^code.Handle;
        han = _global.get_ptr(qual_name.data() as str) as ^code.Handle;

        # Dispose of dynamic memory.
        qual_name.dispose();
        namespace.dispose();

        # Return our resolved handle.
        han;
    }
}

# generate_integer_expr
# -----------------------------------------------------------------------------
def generate_integer_expr(node: ^ast.Node) -> ^code.Handle {
    # ..
    # LLVMConstIntOfString(...)

    # Nothing generated.
    # Generate a nil handle.
    code.make_nil();
}

# generate_nodes
# -----------------------------------------------------------------------------
def generate_nodes(&nodes: ast.Nodes) {

    # In order to support mutual recursion in all spaces we separate out
    # declarations from the other nodes.

    let _nodesize: uint = ast._sizeof(ast.TAG_NODE);
    let mut decl_nodes: list.List = list.make_generic(_nodesize);
    let mut other_nodes: list.List = list.make_generic(_nodesize);

    let mut iter: ast.NodesIterator = ast.iter_nodes(nodes);
    while not ast.iter_empty(iter) {
        let node: ast.Node = ast.iter_next(iter);
        if node.tag == ast.TAG_STATIC_SLOT
                or node.tag == ast.TAG_MODULE
                or node.tag == ast.TAG_FUNC_DECL {
            decl_nodes.push(&node as ^void);
        } else {
            other_nodes.push(&node as ^void);
        }
    }

    # For declarations, order doesn't matter and if a name error
    # is detected it is skipped in the declaration stack and we continue
    # to recurse the declarations until there are none left. If recursion
    # is detected then we stop and report an error.

    # Enumerate and generate each declaration node.
    # NOTE: Keep track of declaration nodes that need their body generated
    #       later.

    let mut i: uint = 0;
    while i < decl_nodes.size {
        generate(decl_nodes.at(i as int) as ^ast.Node);
        i = i + 1;
    }

    # Then generate each node that is the body of a declaration node.

    # Then generate any remaining nodes (in lexical order).

    i = 0;
    while i < other_nodes.size {
        generate(other_nodes.at(i as int) as ^ast.Node);
        i = i + 1;
    }

    # Dispose of temporary lists.
    decl_nodes.dispose();
    other_nodes.dispose();

}

# generate_module
# -----------------------------------------------------------------------------
def generate_module(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.ModuleDecl = ast.unwrap(node^) as ^ast.ModuleDecl;

    # Get the name for the module.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let name: ast.arena.Store = id.name;

    # Build the qual name for this module.
    let mut qual_name: string.String = _qualify_name(name._data as str);

    # Create a solid handle for the module.
    let han: ^code.Handle;
    han = code.make_module(qual_name);

    # Set us in the global scope.
    _global.set_ptr(qual_name.data() as str, han as ^void);

    # Push our name onto the namespace stack.
    _namespace.push_str(name._data as str);

    # Generate each node in the module.
    generate_nodes(x.nodes);

    # Pop our name off the namespace stack.
    _namespace.erase(-1);

    # Dispose of dynamic memory.
    qual_name.dispose();

    # Nothing generated.
    code.make_nil();
}

# generate_static_slot
# -----------------------------------------------------------------------------
def generate_static_slot(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.StaticSlotDecl = ast.unwrap(node^) as ^ast.StaticSlotDecl;

    # Get the name for the slot.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let name: ast.arena.Store = id.name;

    # Build the qual name for this slot.
    let mut qual_name: string.String = _qualify_name(name._data as str);

    # Resolve the slot type handle.
    let type_handle: ^code.Handle = generate(&x.type_);
    if code.isnil(type_handle) { return code.make_nil(); }
    let type_obj: ^code.Type = type_handle._object as ^code.Type;

    # Add the global slot declaration to the IR.
    let val: ^LLVMOpaqueValue;
    val = LLVMAddGlobal(_module, type_obj.handle, qual_name.data());

    # Create a solid handle for the slot.
    let han: ^code.Handle;
    han = code.make_static_slot(qual_name, type_obj, val);

    # Set us in the global scope.
    _global.set_ptr(qual_name.data() as str, han as ^void);

    # Dispose of dynamic memory.
    qual_name.dispose();

    # Declarations return nothing.
    code.make_nil();
}

# generate_func_decl
# -----------------------------------------------------------------------------
def generate_func_decl(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.FuncDecl = (node^).unwrap() as ^ast.FuncDecl;

    # Get the name for the function.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let name: ast.arena.Store = id.name;

    # Resolve the function return type handle.
    let ret_type: ^LLVMOpaqueType;
    let error: bool = false;
    let void_: bool = false;
    if ast.isnull(x.return_type) {
        void_ = true;
        ret_type = LLVMVoidType();
    } else {
        let ret_type_handle: ^code.Handle = generate(&x.return_type);
        if code.isnil(ret_type_handle) { error = true; }
        let ret_type_obj: ^code.Type = ret_type_handle._object as ^code.Type;
        ret_type = ret_type_obj.handle;
    }

    if not error {
        # Resolve the function type.
        let type_: ^LLVMOpaqueType;
        type_ = LLVMFunctionType(ret_type,
                                 0 as ^^LLVMOpaqueType,
                                 0,
                                 0);

        # Build the qual name for this slot.
        let mut qual_name: string.String = _qualify_name(name._data as str);

        # Add the function declaration to the IR.
        let handle: ^LLVMOpaqueValue;
        handle = LLVMAddFunction(_module, qual_name.data(), type_);

        # Create a basic block for the function definition.
        let block_handle: ^LLVMOpaqueBasicBlock;
        block_handle = LLVMAppendBasicBlock(handle, "" as ^int8);

        # Remember the insert block.
        let old_block: ^LLVMOpaqueBasicBlock;
        old_block = LLVMGetInsertBlock(_builder);

        # Set the insertion point.
        LLVMPositionBuilderAtEnd(_builder, block_handle);

        # Push our name onto the namespace stack.
        _namespace.push_str(name._data as str);

        # Generate each node in the function.
        generate_nodes(x.nodes);

        # Pop our name off the namespace stack.
        _namespace.erase(-1);

        # Reset to the old insert block.
        LLVMPositionBuilderAtEnd(_builder, old_block);

        # Dispose of dynamic memory.
        qual_name.dispose();
    }

    # Declarations return nothing.
    code.make_nil();
}

# generate_member_expr
# -----------------------------------------------------------------------------
def generate_member_expr(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Generate a handle for the LHS.
    let lhs: ^code.Handle = generate(&x.lhs);
    if code.isnil(lhs) { return code.make_nil(); }

    # Resolve the RHS as an identifier.
    let id: ^ast.Ident = x.rhs.unwrap() as ^ast.Ident;
    let name: ast.arena.Store = id.name;

    if lhs._tag == code.TAG_MODULE {
        # Resolve the LHS as a module.
        let mod: ^code.Module = lhs._object as ^code.Module;

        # Build the qualified member name.
        let mut qual_name: string.String = mod.name.clone();
        qual_name.append('.');
        qual_name.extend(name._data as str);

        # All members of a module are `static`. Is this member present?
        if not _global.contains(qual_name.data() as str) {
            # FIXME: Report an error.
            return code.make_nil();
        }

        # Retrieve the member.
        let han: ^code.Handle;
        han = _global.get_ptr(qual_name.data() as str) as ^code.Handle;

        # Dispose of dynamic memory.
        qual_name.dispose();

        # Return our resolved handle.
        han;
    } else {
        # FIXME: Report an error.
        code.make_nil();
    }
}

# Generate an addition operation.
# -----------------------------------------------------------------------------
def generate_add_expr(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Generate a handle for the LHS.
    let lhs: ^code.Handle = generate(&x.lhs);
    if code.isnil(lhs) { return code.make_nil(); }

    # Generate a handle for the RHS.
    let rhs: ^code.Handle = generate(&x.rhs);
    if code.isnil(rhs) { return code.make_nil(); }

    # Coerce the operands to values.
    let lhs_han: ^code.Handle = code.to_value(_builder, lhs);
    let rhs_han: ^code.Handle = code.to_value(_builder, rhs);
    if code.isnil(lhs_han) or code.isnil(rhs_han) { return code.make_nil(); }

    # Get the values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Create the ADD operation.
    let han: ^LLVMOpaqueValue;
    han = LLVMBuildAdd(_builder, lhs_val.handle, rhs_val.handle, "" as ^int8);

    # Wrap and return the value.
    # NOTE: We are just using the LHS type right now. Type coercion, etc. has
    #       to happen.
    let val: ^code.Handle;
    val = code.make_value(lhs_val.type_, han);

    # Dispose.
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    val;
}
