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
import resolvers;

# Builders
# =============================================================================

# Identifier [TAG_IDENT]
# -----------------------------------------------------------------------------
def ident(g: ^mut generator_.Generator, node: ^ast.Node,
          scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
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
            scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
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
            scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
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
          scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
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

# Local Slot [TAG_LOCAL_SLOT]
# -----------------------------------------------------------------------------
def local_slot(g: ^mut generator_.Generator, node: ^ast.Node,
               scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the node to its proper type.
    let x: ^ast.LocalSlotDecl = (node^).unwrap() as ^ast.LocalSlotDecl;

    # Get the name out of the node.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;

    # Get and resolve the type node (if we have one).
    let type_han: ^code.Handle = code.make_nil();
    let type_: ^code.Type = 0 as ^code.Type;
    if not ast.isnull(x.type_) {
        type_han = resolver.resolve(g, &x.type_);
        type_ = type_han._object as ^code.Type;
    }

    # Get and resolve the initializer (if we have one).
    let init: ^llvm.LLVMOpaqueValue = 0 as ^llvm.LLVMOpaqueValue;
    if not ast.isnull(x.initializer) {
        # Resolve the type of the initializer.
        let typ: ^code.Handle;
        typ = resolver.resolve_st(g, &x.initializer, scope, type_han);
        if code.isnil(typ) { return code.make_nil(); }

        # Check and set
        if code.isnil(type_han) {
            type_han = typ;
            type_ = type_han._object as ^code.Type;
        }

        # Build the initializer
        let han: ^code.Handle;
        han = builder.build(g, &x.initializer, scope, typ);
        if code.isnil(han) { return code.make_nil(); }

        # Cast it to the target value.
        let cast_han: ^code.Handle = generator_util.cast(g^, han, type_han);

        # Coerce this to a value.
        let val_han: ^code.Handle = generator_def.to_value(
            g^, cast_han, false);
        let val: ^code.Value = val_han._object as ^code.Value;
        init = val.handle;
    }

    # Build a stack allocation.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMBuildAlloca(g.irb, type_.handle, id.name.data());

    # Build the store.
    if init <> 0 as ^llvm.LLVMOpaqueValue {
        llvm.LLVMBuildStore(g.irb, init, val);
    }

    # Wrap.
    let han: ^code.Handle;
    han = code.make_local_slot(type_han, x.mutable, val);

    # Insert into the current local scope block.
    (scope^).insert(id.name.data() as str, han);

    # Return.
    han;
}

# Call [TAG_CALL]
# -----------------------------------------------------------------------------
def call(g: ^mut generator_.Generator, node: ^ast.Node,
         scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
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
        let han: ^code.Handle = builder.build(g, &a.expression, scope, typ);
        if code.isnil(han) { return code.make_nil(); }

        # Coerce this to a value.
        let val_han: ^code.Handle = generator_def.to_value(g^, han, false);

        # Cast the value to the target type.
        let cast_han: ^code.Handle = generator_util.cast(g^, val_han, typ);
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

# Binary arithmetic
# -----------------------------------------------------------------------------
def arithmetic_b_operands(g: ^mut generator_.Generator, node: ^ast.Node,
                          scope: ^mut code.Scope, target: ^code.Handle)
    -> (^code.Handle, ^code.Handle)
{
    let res: (^code.Handle, ^code.Handle) = (code.make_nil(), code.make_nil());

    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve each operand for its type.
    let lhs_ty: ^code.Handle = resolver.resolve_st(g, &x.lhs, scope, target);
    let rhs_ty: ^code.Handle = resolver.resolve_st(g, &x.rhs, scope, target);

    # Build each operand.
    let lhs: ^code.Handle = builder.build(g, &x.lhs, scope, lhs_ty);
    let rhs: ^code.Handle = builder.build(g, &x.rhs, scope, rhs_ty);
    if code.isnil(lhs) or code.isnil(rhs) { return res; }

    # Coerce the operands to values.
    let lhs_val_han: ^code.Handle = generator_def.to_value(g^, lhs, false);
    let rhs_val_han: ^code.Handle = generator_def.to_value(g^, rhs, false);
    if code.isnil(lhs_val_han) or code.isnil(rhs_val_han) { return res; }

    # Create a tuple result.
    res = (lhs_val_han, rhs_val_han);
    res;
}

# Relational [TAG_EQ, TAG_NE, TAG_LT, TAG_LE, TAG_GT, TAG_GE]
# -----------------------------------------------------------------------------
def relational(g: ^mut generator_.Generator, node: ^ast.Node,
               scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = arithmetic_b_operands(
        g, node, scope, code.make_nil());
    if code.isnil(lhs_val_han) or code.isnil(rhs_val_han) {
        # Return nil.
        return code.make_nil();
    }

    # Resolve our type.
    let type_: ^code.Handle = resolvers.type_common(
        &x.lhs,
        code.type_of(lhs_val_han),
        &x.rhs,
        code.type_of(rhs_val_han));
    if code.isnil(type_) {
        # Return nil.
        return code.make_nil();
    }

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = generator_util.cast(g^, lhs_val_han, type_);
    let rhs_han: ^code.Handle = generator_util.cast(g^, rhs_val_han, type_);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the comparison instruction.
    let val: ^llvm.LLVMOpaqueValue;
    if type_._tag == code.TAG_INT_TYPE
            or type_._tag == code.TAG_BOOL_TYPE {
        # Get the comparison opcode to use.
        let mut opc: int32 = -1;
        if      node.tag == ast.TAG_EQ { opc = 32; }
        else if node.tag == ast.TAG_NE { opc = 33; }
        else if node.tag == ast.TAG_GT { opc = 34; }
        else if node.tag == ast.TAG_GE { opc = 35; }
        else if node.tag == ast.TAG_LT { opc = 36; }
        else if node.tag == ast.TAG_LE { opc = 37; }

        # Switch to signed if neccessary.
        if node.tag <> ast.TAG_EQ and node.tag <> ast.TAG_NE {
            let typ: ^code.IntegerType = type_._object as ^code.IntegerType;
            if typ.signed {
                opc = opc + 4;
            }
        }

        # Build the `ICMP` instruction.
        val = llvm.LLVMBuildICmp(
            g.irb,
            opc,
            lhs_val.handle, rhs_val.handle, "" as ^int8);
    } else if type_._tag == code.TAG_FLOAT_TYPE {
        # Get the comparison opcode to use.
        let mut opc: int32 = -1;
        if      node.tag == ast.TAG_EQ { opc = 1; }
        else if node.tag == ast.TAG_NE { opc = 6; }
        else if node.tag == ast.TAG_GT { opc = 2; }
        else if node.tag == ast.TAG_GE { opc = 3; }
        else if node.tag == ast.TAG_LT { opc = 4; }
        else if node.tag == ast.TAG_LE { opc = 5; }

        # Build the `FCMP` instruction.
        val = llvm.LLVMBuildFCmp(
            g.irb,
            opc,
            lhs_val.handle, rhs_val.handle, "" as ^int8);
    }

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(target, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Unary Arithmetic [TAG_PROMOTE, TAG_NUMERIC_NEGATE, TAG_LOGICAL_NEGATE,
#                   TAG_BITNEG]
# -----------------------------------------------------------------------------
def arithmetic_u(g: ^mut generator_.Generator, node: ^ast.Node,
                 scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the node to its proper type.
    let x: ^ast.UnaryExpr = (node^).unwrap() as ^ast.UnaryExpr;

    # Resolve the operand for its type.
    let operand_ty: ^code.Handle = resolver.resolve_st(
        g, &x.operand, scope, target);

    # Build each operand.
    let operand_ty_han: ^code.Type = operand_ty._object as ^code.Type;
    let operand: ^code.Handle = builder.build(
        g, &x.operand, scope, operand_ty);
    if code.isnil(operand) { return code.make_nil(); }

    # Coerce the operands to values.
    let operand_val_han: ^code.Handle = generator_def.to_value(
        g^, operand, false);
    if code.isnil(operand_val_han) { return code.make_nil(); }

    # Cast to values.
    let operand_val: ^code.Value = operand_val_han._object as ^code.Value;

    # Build the instruction.
    let val: ^llvm.LLVMOpaqueValue = operand_val.handle;
    if target._tag == code.TAG_INT_TYPE {
        # Build the correct operation.
        if node.tag == ast.TAG_NUMERIC_NEGATE {
            # Build the `RSUB 1` instruction.
            val = llvm.LLVMBuildSub(
                g.irb,
                llvm.LLVMConstInt(operand_ty_han.handle, 1, false),
                operand_val.handle, "" as ^int8);
        } else if node.tag == ast.TAG_BITNEG {
            # Build the `NEG` instruction.
            val = llvm.LLVMBuildNeg(
                g.irb,
                operand_val.handle, "" as ^int8);
        }
    } else if target._tag == code.TAG_FLOAT_TYPE {
        # Build the correct operation.
        if node.tag == ast.TAG_NUMERIC_NEGATE {
            # Build the `RSUB 1` instruction.
            val = llvm.LLVMBuildSub(
                g.irb,
                llvm.LLVMConstReal(operand_ty_han.handle, 1.0),
                operand_val.handle, "" as ^int8);
        }
    } else if target._tag == code.TAG_BOOL_TYPE {
        # Build the correct operation.
        if node.tag == ast.TAG_BITNEG or node.tag == ast.TAG_LOGICAL_NEGATE {
            # Build the `RSUB 1` instruction.
            val = llvm.LLVMBuildNeg(
                g.irb,
                operand_val.handle, "" as ^int8);
        }
    }

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(target, val);

    # Dispose.
    code.dispose(operand_val_han);

    # Return our wrapped result.
    han;
}

# Binary Arithmetic [TAG_ADD, TAG_SUBTRACT, TAG_MULTIPLY,
#                    TAG_DIVIDE, TAG_MODULO]
# -----------------------------------------------------------------------------
def arithmetic_b(g: ^mut generator_.Generator, node: ^ast.Node,
                 scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = arithmetic_b_operands(
        g, node, scope, code.make_nil());
    if code.isnil(lhs_val_han) or code.isnil(rhs_val_han) {
        # Return nil.
        return code.make_nil();
    }

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = generator_util.cast(g^, lhs_val_han, target);
    let rhs_han: ^code.Handle = generator_util.cast(g^, rhs_val_han, target);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the instruction.
    let val: ^llvm.LLVMOpaqueValue;
    if target._tag == code.TAG_INT_TYPE {
        # Get the internal type.
        let typ: ^code.IntegerType = target._object as ^code.IntegerType;

        # Build the correct operation.
        if node.tag == ast.TAG_ADD {
            # Build the `ADD` instruction.
            val = llvm.LLVMBuildAdd(
                g.irb,
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if node.tag == ast.TAG_SUBTRACT {
            # Build the `SUB` instruction.
            val = llvm.LLVMBuildSub(
                g.irb,
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if node.tag == ast.TAG_MULTIPLY {
            # Build the `MUL` instruction.
            val = llvm.LLVMBuildMul(
                g.irb,
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if node.tag == ast.TAG_DIVIDE or node.tag == ast.TAG_INTEGER_DIVIDE {
            # Build the `DIV` instruction.
            if typ.signed {
                val = llvm.LLVMBuildSDiv(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "" as ^int8);
            } else {
                val = llvm.LLVMBuildUDiv(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "" as ^int8);
            }
        } else if node.tag == ast.TAG_MODULO {
            # Build the `MOD` instruction.
            if typ.signed {
                val = llvm.LLVMBuildSRem(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "" as ^int8);
            } else {
                val = llvm.LLVMBuildURem(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "" as ^int8);
            }
        }
    } else if target._tag == code.TAG_FLOAT_TYPE {
        # Build the correct operation.
        if node.tag == ast.TAG_ADD {
            # Build the `ADD` instruction.
            val = llvm.LLVMBuildFAdd(
                g.irb,
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if node.tag == ast.TAG_SUBTRACT {
            # Build the `SUB` instruction.
            val = llvm.LLVMBuildFSub(
                g.irb,
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if node.tag == ast.TAG_MULTIPLY {
            # Build the `MUL` instruction.
            val = llvm.LLVMBuildFMul(
                g.irb,
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if node.tag == ast.TAG_DIVIDE or node.tag == ast.TAG_INTEGER_DIVIDE {
            # Build the `DIV` instruction.
            val = llvm.LLVMBuildFDiv(
                g.irb,
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if node.tag == ast.TAG_MODULO {
            # Build the `MOD` instruction.
            val = llvm.LLVMBuildFRem(
                g.irb,
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        }
    }

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(target, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Integer Divide [TAG_INTEGER_DIVIDE]
# -----------------------------------------------------------------------------
def integer_divide(g: ^mut generator_.Generator, node: ^ast.Node,
                   scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Perform a normal division.
    let han: ^code.Handle;
    han = arithmetic_b(g, node, scope, target);

    # FIXME: Perform a `floor` on the result.

    # Return the result.
    han;
}

# Return [TAG_RETURN]
# -----------------------------------------------------------------------------
def return_(g: ^mut generator_.Generator, node: ^ast.Node,
            scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the "ploymorphic" node to its proper type.
    let x: ^ast.ReturnExpr = (node^).unwrap() as ^ast.ReturnExpr;

    # Generate a handle for the expression (if we have one.)
    if not ast.isnull(x.expression) {
        let expr: ^code.Handle = builder.build(
            g, &x.expression, scope, target);
        if code.isnil(expr) { return code.make_nil(); }

        # Coerce the expression to a value.
        let val_han: ^code.Handle = generator_def.to_value(g^, expr, false);
        let val: ^code.Value = val_han._object as ^code.Value;

        # Create the `RET` instruction.
        llvm.LLVMBuildRet(g.irb, val.handle);

        # Dispose.
        code.dispose(expr);
        code.dispose(val_han);
    } else {
        # Create the void `RET` instruction.
        llvm.LLVMBuildRetVoid(g.irb);
        void;  #HACK
    }

    # Nothing is forwarded from a `return`.
    code.make_nil();
}

# Assignment [TAG_ASSIGN]
# -----------------------------------------------------------------------------
def assign(g: ^mut generator_.Generator, node: ^ast.Node,
           scope: ^mut code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Unwrap the "ploymorphic" node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve each operand for its type.
    let lhs_ty: ^code.Handle = resolver.resolve_st(g, &x.lhs, scope, target);
    let rhs_ty: ^code.Handle = resolver.resolve_st(g, &x.rhs, scope, target);
    if code.isnil(lhs_ty) or code.isnil(rhs_ty) { return code.make_nil(); }

    # Build each operand.
    let lhs: ^code.Handle = builder.build(g, &x.lhs, scope, lhs_ty);
    let rhs: ^code.Handle = builder.build(g, &x.rhs, scope, rhs_ty);
    if code.isnil(lhs) or code.isnil(rhs) { return code.make_nil(); }

    # Coerce the operand to its value.
    let rhs_val_han: ^code.Handle = generator_def.to_value(g^, rhs, false);
    if code.isnil(rhs_val_han) { return code.make_nil(); }

    # Cast the operand to the target type.
    let rhs_han: ^code.Handle = generator_util.cast(g^, rhs_val_han, target);

    # Cast to a value.
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Perform the assignment (based on what we have in the LHS).
    if lhs._tag == code.TAG_STATIC_SLOT {
        # Get the real object.
        let slot: ^code.StaticSlot = lhs._object as ^code.StaticSlot;

        # Ensure that we are mutable.
        if not slot.context.mutable {
            # Report error and return nil.
            errors.begin_error();
            errors.fprintf(errors.stderr,
                           "cannot assign to immutable static item" as ^int8);
            errors.end();
            return code.make_nil();
        }

        # Build the `STORE` operation.
        llvm.LLVMBuildStore(g.irb, rhs_val.handle, slot.handle);
    } else if lhs._tag == code.TAG_LOCAL_SLOT {
        # Get the real object.
        let slot: ^code.LocalSlot = lhs._object as ^code.LocalSlot;

        # Ensure that we are mutable.
        if not slot.mutable {
            # Report error and return nil.
            errors.begin_error();
            errors.fprintf(errors.stderr,
                           "re-assignment to immutable local slot" as ^int8);
            errors.end();
            return code.make_nil();
        }

        # Build the `STORE` operation.
        llvm.LLVMBuildStore(g.irb, rhs_val.handle, slot.handle);
    } else {
        # Report error and return nil.
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "left-hand side expression is not assignable" as ^int8);
        errors.end();
        return code.make_nil();
    }

    # Dispose.
    code.dispose(rhs_val_han);
    code.dispose(rhs_han);

    # Return the RHS.
    rhs;
}
