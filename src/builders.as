import llvm;
import libc;
import types;
import generator_;
import code;
import ast;
import list;
import errors;
import generator_util;
import generator_def;
import builder;
import resolver;

# Builders
# =============================================================================

# Identifier [TAG_IDENT]
# -----------------------------------------------------------------------------
def ident(g: ^mut generator_.Generator, node: ^ast.Node,
          scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Retrieve the item with scope resolution rules.
    let id: ^ast.Ident = (node^).unwrap() as ^ast.Ident;
    let item: ^code.Handle = generator_util.get_scoped_item_in(
        g^, id.name.data() as str, scope, g.ns);

    # Return the item.
    item;
}

# Boolean [TAG_BOOLEAN]
# -----------------------------------------------------------------------------
def boolean(g: ^mut generator_.Generator, node: ^ast.Node,
            scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the node to its proper type.
    let x: ^ast.BooleanExpr = (node^).unwrap() as ^ast.BooleanExpr;

    # Build a llvm val for the boolean expression.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMConstInt(llvm.LLVMInt1Type(), (1 if x.value else 0), false);

    # Wrap and return the value.
    code.make_value(target, val);
}

# Integer [TAG_INTEGER]
# -----------------------------------------------------------------------------
def integer(g: ^mut generator_.Generator, node: ^ast.Node,
            scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the node to its proper type.
    let x: ^ast.IntegerExpr = (node^).unwrap() as ^ast.IntegerExpr;

    # Get the type handle from the target.
    let typ: ^code.Type = target._object as ^code.Type;

    # Build a llvm val for the boolean expression.
    let val: ^llvm.LLVMOpaqueValue;
    if target._tag == code.TAG_INT_TYPE
    {
        val = llvm.LLVMConstIntOfString(
            typ.handle, x.text.data(), x.base as uint8);
    }
    else
    {
        val = llvm.LLVMConstRealOfString(typ.handle, x.text.data());
    }

    # Wrap and return the value.
    code.make_value(target, val);
}

# Floating-point [TAG_FLOAT]
# -----------------------------------------------------------------------------
def float(g: ^mut generator_.Generator, node: ^ast.Node,
          scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the node to its proper type.
    let x: ^ast.FloatExpr = (node^).unwrap() as ^ast.FloatExpr;

    # Get the type handle from the target.
    let typ: ^code.Type = target._object as ^code.Type;

    # Build a llvm val for the boolean expression.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMConstRealOfString(typ.handle, x.text.data());

    # Wrap and return the value.
    code.make_value(target, val);
}

# Call [TAG_CALL]
# -----------------------------------------------------------------------------
def call(g: ^mut generator_.Generator, node: ^ast.Node,
         scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the node to its proper type.
    let x: ^ast.CallExpr = (node^).unwrap() as ^ast.CallExpr;

    # Build the called expression.
    let expr: ^code.Handle = builder.build(g, &x.expression, scope, target);
    if code.isnil(expr) { return code.make_nil(); }

    # Pull out the function handle and its type.
    let fn: ^llvm.LLVMOpaqueValue;
    let type_: ^code.FunctionType;
    if expr._tag == code.TAG_FUNCTION {
        let fn_han: ^code.Function = expr._object as ^code.Function;
        type_ = fn_han.type_._object as ^code.FunctionType;
        fn = fn_han.handle;
    }

    # First we create and zero a list to hold the entire argument list.
    let mut argl: list.List = list.make(types.PTR);
    argl.reserve(type_.parameters.size);
    argl.size = type_.parameters.size;
    libc.memset(argl.elements as ^void, 0, argl.size * argl.element_size);
    let argv: ^mut ^llvm.LLVMOpaqueValue =
        argl.elements as ^^llvm.LLVMOpaqueValue;

    # Iterate through each argument, build, and push them into
    # their appropriate position in the argument list.
    let mut i: int = 0;
    while i as uint < x.arguments.size()
    {
        # Get the specific argument.
        let anode: ast.Node = x.arguments.get(i);
        i = i + 1;
        let a: ^ast.Argument = anode.unwrap() as ^ast.Argument;

        # Find the parameter index.
        # NOTE: The parser handles making sure no positional arg
        #   comes after a keyword arg.
        let mut param_idx: uint = 0;
        if ast.isnull(a.name)
        {
            # An unnamed argument just corresponds to the sequence.
            param_idx = i as uint - 1;
        }
        else
        {
            # Get the name data for the id.
            let id: ^ast.Ident = a.name.unwrap() as ^ast.Ident;

            # Check for the existance of this argument.
            if not type_.parameter_map.contains(id.name.data() as str)
            {
                errors.begin_error();
                errors.fprintf(errors.stderr,
                               "unexpected keyword argument '%s'" as ^int8,
                               id.name.data());
                errors.end();
                return code.make_nil();
            }

            # Check if we already have one of these.
            if (argv + param_idx)^ <> 0 as ^llvm.LLVMOpaqueValue {
                errors.begin_error();
                errors.fprintf(errors.stderr,
                               "got multiple values for argument '%s'" as ^int8,
                               id.name.data());
                errors.end();
                return code.make_nil();
            }

            # Pull the named argument index.
            param_idx = type_.parameter_map.get_uint(id.name.data() as str);
        }

        # Resolve the type of the argument expression.
        let typ: ^code.Handle = resolver.resolve_st(
            g, &a.expression, scope,
            code.type_of(type_.parameters.at_ptr(param_idx as int) as ^code.Handle));
        if code.isnil(typ) { return code.make_nil(); }

        # Build the argument expression node.
        let han: ^code.Handle = builder.build(g, &a.expression, scope, target);
        if code.isnil(han) { return code.make_nil(); }

        # Coerce this to a value.
        let val_han: ^code.Handle = generator_def.to_value(g^, han, true);

        # Cast the value to the target type.
        let cast_han: ^code.Handle = generator_util.cast(g^, val_han, target);
        let cast_val: ^code.Value = cast_han._object as ^code.Value;

        # Emplace in the argument list.
        (argv + param_idx)^ = cast_val.handle;

        # Dispose.
        code.dispose(val_han);
        code.dispose(cast_han);
    }

    # Check for missing arguments.
    i = 0;
    let mut error: bool = false;
    while i as uint < argl.size {
        let arg: ^llvm.LLVMOpaqueValue = (argv + i)^;
        if arg == 0 as ^llvm.LLVMOpaqueValue
        {
            # Get formal name
            let prm_han: ^code.Handle =
                type_.parameters.at_ptr(i) as ^code.Handle;
            let prm: ^code.Parameter =
                prm_han._object as ^code.Parameter;

            # Report
            errors.begin_error();
            errors.fprintf(errors.stderr,
                           "missing required parameter '%s'" as ^int8,
                           prm.name.data());
            errors.end();
            error = true;
        }

        i = i + 1;
    }
    if error { return code.make_nil(); }

    # Build the `call` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMBuildCall(
        g.irb, fn, argv, argl.size as uint32, "" as ^int8);

    # Dispose of dynamic memory.
    argl.dispose();

    if code.isnil(type_.return_type) {
        # Return nil.
        code.make_nil();
    } else {
        # Wrap and return the value.
        code.make_value(type_.return_type, val);
    }
}
