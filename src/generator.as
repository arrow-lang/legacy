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

# declare_int_type -- Declare an integral type in `global` scope.
# -----------------------------------------------------------------------------
def _declare_int_type(name: str, val: ^LLVMOpaqueType, signed: bool) {
    let han: ^code.Handle = code.make_int_type(val, signed);
    _global.set_ptr(name, han as ^void);
}

# declare_float_type -- Declare a float type in `global` scope.
# -----------------------------------------------------------------------------
def _declare_float_type(name: str, val: ^LLVMOpaqueType) {
    let han: ^code.Handle = code.make_float_type(val);
    _global.set_ptr(name, han as ^void);
}

# declare_builtin_types
# -----------------------------------------------------------------------------
def _declare_primitive_types() {
    # Boolean
    _declare_type("bool", LLVMInt1Type());

    # Signed machine-independent integers
    _declare_int_type(  "int8",   LLVMInt8Type(), true);
    _declare_int_type( "int16",  LLVMInt16Type(), true);
    _declare_int_type( "int32",  LLVMInt32Type(), true);
    _declare_int_type( "int64",  LLVMInt64Type(), true);
    _declare_int_type("int128", LLVMIntType(128), true);

    # Unsigned machine-independent integers
    _declare_int_type(  "uint8",   LLVMInt8Type(), false);
    _declare_int_type( "uint16",  LLVMInt16Type(), false);
    _declare_int_type( "uint32",  LLVMInt32Type(), false);
    _declare_int_type( "uint64",  LLVMInt64Type(), false);
    _declare_int_type("uint128", LLVMIntType(128), false);

    # Floating-points
    _declare_float_type("float32", LLVMFloatType());
    _declare_float_type("float64", LLVMDoubleType());

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
        gen_table[ast.TAG_BOOLEAN] = generate_bool_expr;
        gen_table[ast.TAG_ADD] = generate_add_expr;
        gen_table[ast.TAG_SUBTRACT] = generate_sub_expr;
        gen_table[ast.TAG_MULTIPLY] = generate_mult_expr;
        gen_table[ast.TAG_DIVIDE] = generate_div_expr;
        gen_table[ast.TAG_MODULO] = generate_mod_expr;
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
        gen_table[ast.TAG_RETURN] = generate_return_expr;
        gen_table[ast.TAG_MEMBER] = generate_member_expr;
        gen_table[ast.TAG_CALL] = generate_call_expr;
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

# Generate `bool` expression.
# -----------------------------------------------------------------------------
def generate_bool_expr(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.BooleanExpr = ast.unwrap(node^) as ^ast.BooleanExpr;

    # Generate a llvm val for the boolean expression.
    let val: ^LLVMOpaqueValue;
    val = LLVMConstInt(LLVMInt1Type(), 1 if x.value else 0, false);

    # Wrap and return the value.
    code.make_value(_global.get_ptr("bool") as ^code.Handle, val);
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
    han = code.make_static_slot(qual_name, type_handle, val);

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
    let ret_type_handle: ^code.Handle = code.make_nil();
    let error: bool = false;
    let void_: bool = false;
    if ast.isnull(x.return_type) {
        void_ = true;
        ret_type = LLVMVoidType();
    } else {
        ret_type_handle = generate(&x.return_type);
        if code.isnil(ret_type_handle) { error = true; }
        let ret_type_obj: ^code.Type = ret_type_handle._object as ^code.Type;
        ret_type = ret_type_obj.handle;
    }

    if not error {
        # Resolve the type for each function parameter.
        let mut params: list.List = list.make(types.PTR);
        let mut param_type_handles: list.List = list.make(types.PTR);
        let mut piter: ast.NodesIterator = ast.iter_nodes(x.params);
        while not ast.iter_empty(piter) {
            let pnode: ast.Node = ast.iter_next(piter);
            let p: ^ast.FuncParam = pnode.unwrap() as ^ast.FuncParam;

            # Resolve the type.
            let ptype_handle: ^code.Handle = generate(&p.type_);
            if code.isnil(ptype_handle) { error = true; break; }
            let ptype_obj: ^code.Type = ptype_handle._object as ^code.Type;

            # Emplace the type handle.
            param_type_handles.push_ptr(ptype_obj.handle as ^void);

            # Unwrap the parameter name.
            let param_id: ^ast.Ident = p.id.unwrap() as ^ast.Ident;
            let param_name: ast.arena.Store = param_id.name;

            # Emplace a solid parameter.
            params.push_ptr(code.make_parameter(
                param_name._data as str,
                ptype_handle,
                code.make_nil()) as ^void);
        }

        if not error {
            # Resolve the function type.
            let type_: ^LLVMOpaqueType;
            type_ = LLVMFunctionType(
                ret_type,
                param_type_handles.elements as ^^LLVMOpaqueType,
                param_type_handles.size as uint32,
                0);

            # Create a solid handle for the function type.
            let tyhan: ^code.Handle;
            tyhan = code.make_function_type(type_, ret_type_handle, params);

            # Build the qual name for this slot.
            let mut qual_name: string.String = _qualify_name(
                name._data as str);

            # Add the function declaration to the IR.
            let handle: ^LLVMOpaqueValue;
            handle = LLVMAddFunction(_module, qual_name.data(), type_);

            # Create a solid handle for the function.
            let han: ^code.Handle;
            han = code.make_function(handle, qual_name, tyhan);

            # Set us in the global scope.
            _global.set_ptr(qual_name.data() as str, han as ^void);

            # Generate the function definition.
            generate_func_def(x, han);

            # Dispose of dynamic memory.
            qual_name.dispose();
        }
    }

    # Declarations return nothing.
    code.make_nil();
}

def generate_func_def(node: ^ast.FuncDecl, handle: ^code.Handle) {
    let x: ^code.Function = handle._object as ^code.Function;

    # Create a basic block for the function definition.
    let entry: ^LLVMOpaqueBasicBlock;
    entry = LLVMAppendBasicBlock(x.handle, "" as ^int8);

    # Remember the insert block.
    let cur_block: ^LLVMOpaqueBasicBlock;
    cur_block = LLVMGetInsertBlock(_builder);

    # Set the insertion point.
    LLVMPositionBuilderAtEnd(_builder, entry);

    # Push our name onto the namespace stack.
    _namespace.push_str(x.name.data() as str);

    # TODO: Insert the parameters onto the local stack as slots.

    # Generate each node in the function.
    generate_nodes(node.nodes);

    # Pop our name off the namespace stack.
    _namespace.erase(-1);

    # Reset to the old insert block.
    LLVMPositionBuilderAtEnd(_builder, cur_block);
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
    } else if lhs._tag == code.TAG_FUNCTION {
        # Resolve the LHS as a function.
        let mod: ^code.Function = lhs._object as ^code.Function;

        # Build the qualified member name.
        let mut qual_name: string.String = mod.name.clone();
        qual_name.append('.');
        qual_name.extend(name._data as str);

        # All members of a function are `static`. Is this member present?
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

# Generate a `call` expression.
# -----------------------------------------------------------------------------
def generate_call_expr(node: ^ast.Node) -> ^code.Handle {
    # Unwrap the "ploymorphic" node to its proper type.
    let x: ^ast.CallExpr = (node^).unwrap() as ^ast.CallExpr;

    # A `call` contains the `invoked` expression and a sequence of arguments
    # that are to be applied to the formal function parameters. An
    # argument can be named in which it applies to a specific parameter;
    # else, the argument is applied strictly in sequence. A parameter may
    # have a default value that is to be used if there is not a matching
    # argument in the call expression.
    # Ex. Point(1) Point(x=1) Point(5, y=2) Point(y=2)

    # Generate the `invoked` expression.
    let expr: ^code.Handle = generate(&x.expression);
    if code.isnil(expr) { return code.make_nil(); }

    # Determine how to get a function handle from the expression.
    let handle: ^LLVMOpaqueValue = 0 as ^LLVMOpaqueValue;
    if expr._tag == code.TAG_FUNCTION {
        # Just grab the function handle.
        let fn: ^code.Function = expr._object as ^code.Function;
        handle = fn.handle;
    }

    if handle == 0 as ^LLVMOpaqueValue {
        # Don't know what to do.
        # FIXME: Report an error.
        code.make_nil();
    } else {
        # First we create a list to hold the entire argument list.
        let mut args: list.List = list.make(types.PTR);

        # Enumerate the parameters and push an equivalent amount
        # of blank arguments.
        # let mut iter: ^ast.NodesIterator = ast.iter_nodes(x.arguments);
        # while ast.iter_empty(iter) {
        #     args.push_ptr(0 as ^void);
        #     ast.iter_next(iter);
        # }

        # Enumerate the arguments and set the parameters in turn to each
        # generated argument expression.
        # iter = ast.iter_nodes(x.arguments);

        # Build the `call` instruction.
        LLVMBuildCall(
            _builder, handle, 0 as ^^LLVMOpaqueValue, 0, "" as ^int8);

        # Dispose of dynamic memory.
        args.dispose();

        # Return nil.
        code.make_nil();
    }
}

# Generate a `return` expression.
# -----------------------------------------------------------------------------
def generate_return_expr(node: ^ast.Node) -> ^code.Handle {
    # Unwrap the "ploymorphic" node to its proper type.
    let x: ^ast.ReturnExpr = (node^).unwrap() as ^ast.ReturnExpr;

    # Generate a handle for the expression (if we have one.)
    if not ast.isnull(x.expression) {
        let expr: ^code.Handle = generate(&x.expression);
        if code.isnil(expr) { return code.make_nil(); }

        # Coerce the expression to a value.
        let val_han: ^code.Handle = code.to_value(_builder, expr);
        let val: ^code.Value = val_han._object as ^code.Value;

        # Create the `RET` instruction.
        LLVMBuildRet(_builder, val.handle);

        # Dispose.
        code.dispose(expr);
        code.dispose(val_han);
    } else {
        # Create the void `RET` instruction.
        LLVMBuildRetVoid(_builder);
        void;  #HACK
    }

    # Nothing is forwarded from a `return`.
    code.make_nil();
}

# Generate the LHS and RHS of a binary expression.
# -----------------------------------------------------------------------------
def generate_binexpr_ops(x: ^ast.BinaryExpr) -> (^code.Handle, ^code.Handle) {
    # Coerce the operands to values.
    let lhs_han: ^code.Handle = code.make_nil();
    let rhs_han: ^code.Handle = code.make_nil();

    # Generate a handle for the LHS.
    let lhs: ^code.Handle = generate(&x.lhs);
    if not code.isnil(lhs) {
        # Coerce the operands to values.
        lhs_han = code.to_value(_builder, lhs);
    }

    # Generate a handle for the RHS.
    let rhs: ^code.Handle = generate(&x.rhs);
    if not code.isnil(rhs) {
        # Coerce the operands to values.
        rhs_han = code.to_value(_builder, rhs);
    }

    # Return the handles.
    let res: (^code.Handle, ^code.Handle) = (lhs_han, rhs_han);
    res;
}

# Generate an addition operation.
# -----------------------------------------------------------------------------
def generate_add_expr(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Generate the operands.
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (lhs_han, rhs_han) = generate_binexpr_ops(x);

    # If either of them are nil; return nil.
    if code.isnil(lhs_han) or code.isnil(rhs_han) {
        # Dispose.
        code.dispose(lhs_han);
        code.dispose(rhs_han);

        # Return nil.
        code.make_nil();
    } else {
        # Get the values.
        let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Create the ADD operation.
        let han: ^LLVMOpaqueValue;
        if lhs_val.type_._tag == code.TAG_FLOAT_TYPE {
            han = LLVMBuildFAdd(
                _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if lhs_val.type_._tag == code.TAG_INT_TYPE {
            han = LLVMBuildAdd(
                _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else {
            # FIXME: Report proper error message.
            han = 0 as ^LLVMOpaqueValue;
        }

        if han == 0 as ^LLVMOpaqueValue {
            code.make_nil();
        } else {
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
    }
}

# Generate a subtraction operation.
# -----------------------------------------------------------------------------
def generate_sub_expr(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Generate the operands.
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (lhs_han, rhs_han) = generate_binexpr_ops(x);

    # If either of them are nil; return nil.
    if code.isnil(lhs_han) or code.isnil(rhs_han) {
        # Dispose.
        code.dispose(lhs_han);
        code.dispose(rhs_han);

        # Return nil.
        code.make_nil();
    } else {
        # Get the values.
        let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Create the SUB operation.
        let han: ^LLVMOpaqueValue;
        if lhs_val.type_._tag == code.TAG_FLOAT_TYPE {
            han = LLVMBuildFSub(
                _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if lhs_val.type_._tag == code.TAG_INT_TYPE {
            han = LLVMBuildSub(
                _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else {
            # FIXME: Report proper error message.
            han = 0 as ^LLVMOpaqueValue;
        }

        if han == 0 as ^LLVMOpaqueValue {
            code.make_nil();
        } else {
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
    }
}

# Generate a multiplication operation.
# -----------------------------------------------------------------------------
def generate_mult_expr(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Generate the operands.
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (lhs_han, rhs_han) = generate_binexpr_ops(x);

    # If either of them are nil; return nil.
    if code.isnil(lhs_han) or code.isnil(rhs_han) {
        # Dispose.
        code.dispose(lhs_han);
        code.dispose(rhs_han);

        # Return nil.
        code.make_nil();
    } else {
        # Get the values.
        let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Create the MULT operation.
        let han: ^LLVMOpaqueValue;
        if lhs_val.type_._tag == code.TAG_FLOAT_TYPE {
            han = LLVMBuildFMul(
                _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if lhs_val.type_._tag == code.TAG_INT_TYPE {
            han = LLVMBuildMul(
                _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else {
            # FIXME: Report proper error message.
            han = 0 as ^LLVMOpaqueValue;
        }

        if han == 0 as ^LLVMOpaqueValue {
            code.make_nil();
        } else {
            # Wrap and return the value.
            let val: ^code.Handle;
            val = code.make_value(lhs_val.type_, han);

            # Dispose.
            code.dispose(lhs_han);
            code.dispose(rhs_han);

            # Return our wrapped result.
            val;
        }
    }
}

# Generate a division operation.
# -----------------------------------------------------------------------------
def generate_div_expr(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Generate the operands.
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (lhs_han, rhs_han) = generate_binexpr_ops(x);

    # If either of them are nil; return nil.
    if code.isnil(lhs_han) or code.isnil(rhs_han) {
        # Dispose.
        code.dispose(lhs_han);
        code.dispose(rhs_han);

        # Return nil.
        code.make_nil();
    } else {
        # Get the values.
        let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Create the DIV operation.
        let han: ^LLVMOpaqueValue;
        if lhs_val.type_._tag == code.TAG_FLOAT_TYPE {
            han = LLVMBuildFDiv(
                _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if lhs_val.type_._tag == code.TAG_INT_TYPE {
            # Figure out if this signed or not.
            let int_type: ^code.IntegerType = lhs_val.type_._object as ^code.IntegerType;
            if int_type.signed {
                LLVMBuildSDiv(
                    _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
            } else {
                LLVMBuildUDiv(
                    _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
            }
        } else {
            # FIXME: Report proper error message.
            han = 0 as ^LLVMOpaqueValue;
        }

        if han == 0 as ^LLVMOpaqueValue {
            code.make_nil();
        } else {
            # Wrap and return the value.
            let val: ^code.Handle;
            val = code.make_value(lhs_val.type_, han);

            # Dispose.
            code.dispose(lhs_han);
            code.dispose(rhs_han);

            # Return our wrapped result.
            val;
        }
    }
}

# Generate a modulo operation.
# -----------------------------------------------------------------------------
def generate_mod_expr(node: ^ast.Node) -> ^code.Handle {
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Generate the operands.
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (lhs_han, rhs_han) = generate_binexpr_ops(x);

    # If either of them are nil; return nil.
    if code.isnil(lhs_han) or code.isnil(rhs_han) {
        # Dispose.
        code.dispose(lhs_han);
        code.dispose(rhs_han);

        # Return nil.
        code.make_nil();
    } else {
        # Get the values.
        let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Create the DIV operation.
        let han: ^LLVMOpaqueValue;
        if lhs_val.type_._tag == code.TAG_FLOAT_TYPE {
            han = LLVMBuildFRem(
                _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if lhs_val.type_._tag == code.TAG_INT_TYPE {
            # Figure out if this signed or not.
            let int_type: ^code.IntegerType = lhs_val.type_._object as ^code.IntegerType;
            if int_type.signed {
                han = LLVMBuildSRem(
                    _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
            } else {
                han = LLVMBuildURem(
                    _builder, lhs_val.handle, rhs_val.handle, "" as ^int8);
            }
        } else {
            # FIXME: Report proper error message.
            han = 0 as ^LLVMOpaqueValue;
        }

        if han == 0 as ^LLVMOpaqueValue {
            code.make_nil();
        } else {
            # Wrap and return the value.
            let val: ^code.Handle;
            val = code.make_value(lhs_val.type_, han);

            # Dispose.
            code.dispose(lhs_han);
            code.dispose(rhs_han);

            # Return our wrapped result.
            val;
        }
    }
}

# TODO: Generate a DIV expression (with good features.. haha)
# -----------------------------------------------------------------------------
# def generate_div_expr(node: *ast.Node) -> code.Handle {
#     # Unwrap the "ploymorphic" node to its proper type.
#     x := node.unwrap() as *ast.BinaryExpr;

#     # Generate the operands.
#     (lhs, rhs) := generate_binexpr_ops(x);

#     # If either operand failed then return nil.
#     if lhs == code.nil or rhs == code.nil { return code.nil; }

#     # Generate the `DIV` operation.
#     han := match type(lhs) {
#         code.FloatType => {
#             # Floating-point division generates the `FDIV` instruction.
#             LLVMBuildFDiv(_b, lhs.handle, rhs.handle);
#         }

#         code.IntegerType => {
#             # Instruction for integral division depends
#             # on the sign (`SDIV` for signed and `UDIV` for unsigned).
#             (LLVMBuildSDiv if lhs.signed else LLVMBuildUDiv)(
#                 _b, lhs.handle, rhs.handle
#             );
#         }

#         _ => {
#             # No idea how to handle this.
#             # FIXME: Report proper error message.
#             return code.nil;
#         }
#     }

#     # Wrap and return the value.
#     return code.Value(lhs.type_, han);
# }
