import generator_;
import code;
import libc;
import ast;
import llvm;
import list;
import string;
import types;
import errors;
import generator_util;
import generator_type;
import resolver;
import builder;
import generator_def;

# Resolve a type from an item.
# -----------------------------------------------------------------------------
let _type_of(g: *mut generator_.Generator, item: *code.Handle): *code.Handle -> {
    if not code.is_type(item) {
        # Extract type from identifier.
        if item._tag == code.TAG_STATIC_SLOT
        {
            # This is a static slot; get its type.
            let slot: *code.StaticSlot = item._object as *code.StaticSlot;
            return generator_type.generate_static_slot(
                *g, slot.qualified_name.data() as str, slot);
            0; #HACK
        }
        else if item._tag == code.TAG_LOCAL_SLOT
        {
            # This is a local slot; just return the type.
            let slot = item._object as *code.LocalSlot;
            return slot.type_;
            0; #HACK
        }
        else if item._tag == code.TAG_FUNCTION
        {
            # This is a static slot; get its type.
            let fn: *code.Function = item._object as *code.Function;
            return generator_type.generate_function(
                *g, fn.qualified_name.data() as str,
                item._object as *code.Function);
            0; #HACK
        }
        else if item._tag == code.TAG_EXTERN_FUNC
        {
            let fn: *code.ExternFunction = item._object as *code.ExternFunction;
            return generator_type.generate_extern_function(
                *g, fn.qualified_name.data() as str,
                item._object as *code.ExternFunction);
            0; #HACK
        }
        else if item._tag == code.TAG_EXTERN_STATIC
        {
            let slot: *code.ExternStatic = item._object as *code.ExternStatic;
            return generator_type.generate_extern_static(
                *g, slot.qualified_name.data() as str,
                item._object as *code.ExternStatic);
            0; #HACK
        }
        else if item._tag == code.TAG_MODULE
        {
            # This is a module; deal with it.
            let x = item;
            return x;
            0; #HACK
        }
        else if item._tag == code.TAG_STRUCT
        {
            # This is a struct; get its type.
            let st: *code.Struct = item._object as *code.Struct;
            return generator_type.generate_struct(
                *g, st.qualified_name.data() as str, st);
            0; #HACK
        }
        else
        {
            # Return nil.
            return code.make_nil();
        };
    } else {
        # Return the type reference.
        return item;
    #     0; #HACK
    };

    # Return nil.
    return code.make_nil();

}

# Attempt to resolve a single compatible type from two passed
# types. Respects integer and float promotion rules.
# -----------------------------------------------------------------------------
let type_common(a_ctx: *ast.Node, a: *code.Handle,
                b_ctx: *ast.Node, b: *code.Handle): *code.Handle -> {
    # If the types are the same, bail.
    let a_ty: *code.Type = a._object as *code.Type;
    let b_ty: *code.Type = b._object as *code.Type;
    if generator_util.is_same_type(a, b) { return a; };

    # Figure out a common type.
    if a._tag == code.TAG_INT_TYPE and b._tag == a._tag {
        # Determine the integer with the greatest rank.
        let ai_ty: *code.IntegerType = a._object as *code.IntegerType;
        let bi_ty: *code.IntegerType = b._object as *code.IntegerType;

        # If the sign is identical then compare the bit size.
        if ai_ty.signed == bi_ty.signed {
            if ai_ty.bits > bi_ty.bits {
                return a;
            } else {
                return b;
            };
        } else if a_ctx.tag == ast.TAG_INTEGER {
            return b;
        } else if b_ctx.tag == ast.TAG_INTEGER {
            return a;
        } else if ai_ty.signed and ai_ty.bits > bi_ty.bits {
            return a;
        } else if bi_ty.signed and bi_ty.bits > ai_ty.bits {
            return b;
        } else {
            # The integer types are not strictly compatible.
            # Return nil.
            return code.make_nil();
        };
        0; #HACK
    } else if a._tag == code.TAG_FLOAT_TYPE and b._tag == a._tag {
        # Determine the float with the greatest rank.
        let a_ty: *code.FloatType = a._object as *code.FloatType;
        let b_ty: *code.FloatType = b._object as *code.FloatType;

        # Chose the float type with greater rank.
        if a_ty.bits > b_ty.bits {
            return a;
        } else {
            return b;
        };
    } else if a._tag == code.TAG_FLOAT_TYPE and b._tag == code.TAG_INT_TYPE {
        # No matter what the float or int type is the float has greater rank.
        return a;
    } else if b._tag == code.TAG_FLOAT_TYPE and a._tag == code.TAG_INT_TYPE {
        # No matter what the float or int type is the float has greater rank.
        return b;
    } else if b._tag == code.TAG_STR_TYPE and a._tag == code.TAG_CHAR_TYPE {
        # A string will coerce to an explicit char if the string
        # is a literal and exactly 1 in length
        if b_ctx != 0 as *ast.Node {
            if b_ctx.tag == ast.TAG_STRING {
                let string_: *ast.StringExpr = b_ctx.unwrap() as *ast.StringExpr;
                if string_.count() == 1 {
                    return a;
                } else {
                    return code.make_nil();
                };
                0; #HACK
            } else {
                return code.make_nil();
            };
        } else {
            return code.make_nil();
        };
    };
    # } else {
        # No common type resolution.
        # Return nil.
        return code.make_nil();
    # };
}

# Resolve an `arithmetic` unary expression.
# -----------------------------------------------------------------------------
let arithmetic_u(g: *mut generator_.Generator, node: *ast.Node,
                 scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.UnaryExpr = node.unwrap() as *ast.UnaryExpr;

    # Resolve the type of the operand.
    let operand: *code.Handle = resolver.resolve_s(g, &x.operand, scope);
    if code.isnil(operand) { return code.make_nil(); };

    # Perform further resolution if needed.
    if node.tag == ast.TAG_LOGICAL_NEGATE
    {
        # A logical "not" must be applied to a boolean and returns a boolean.
        if operand._tag == code.TAG_BOOL_TYPE
        {
            return g.items.get_ptr("bool") as *code.Handle;
        };
    }
    else if     node.tag == ast.TAG_NUMERIC_NEGATE
            or  node.tag == ast.TAG_PROMOTE
    {
        # A numeric "-" or "+" must be applied to a numeric type.
        if      operand._tag == code.TAG_INT_TYPE
            or  operand._tag == code.TAG_FLOAT_TYPE
        {
            # Return the type we act on.
            return operand;
        };
    }
    else if node.tag == ast.TAG_BITNEG
    {
        # A bitwise "!" can be applied to a boolean or integral type.
         if      operand._tag == code.TAG_BOOL_TYPE
             or  operand._tag == code.TAG_INT_TYPE
         {
             # Return the type we act on.
             return operand;
         };
    };

    # Report an error.
    let name: str =
        if      node.tag == ast.TAG_LOGICAL_NEGATE { "not"; }
        else if node.tag == ast.TAG_NUMERIC_NEGATE { "-"; }
        else if node.tag == ast.TAG_BITNEG { "!"; }
        else if node.tag == ast.TAG_PROMOTE { "+"; }
        else { "?"; };

    let mut op_name: string.String = code.typename(operand);

    errors.begin_error();
    errors.libc.fprintf(errors.libc.stderr,
                   "no unary operation '%s' can be applied to type '%s'",
                   name, op_name.data());
    errors.end();

    op_name.dispose();

    return code.make_nil();
}

# Resolve an `arithmetic` binary expression.
# -----------------------------------------------------------------------------
let arithmetic_b(g: *mut generator_.Generator, node: *ast.Node,
                 scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Resolve the types of the operands.
    let lhs: *code.Handle = resolver.resolve_s(g, &x.lhs, scope);
    let rhs: *code.Handle = resolver.resolve_s(g, &x.rhs, scope);
    if code.isnil(lhs) or code.isnil(rhs) { return code.make_nil(); };

    # If we are dealing with addition or subtraction ...
    if node.tag == ast.TAG_ADD or node.tag == ast.TAG_SUBTRACT {
        # ... and we have a pointer type and an integral type ...
        if      lhs._tag == code.TAG_POINTER_TYPE
            and rhs._tag == code.TAG_INT_TYPE
        {
            # ... unilaterally resolve to the pointer type.
            return lhs;
        };
        if      lhs._tag == code.TAG_INT_TYPE
            and rhs._tag == code.TAG_POINTER_TYPE
        {
            # ... unilaterally resolve to the pointer type.
            return rhs;
        };
        if lhs._tag == code.TAG_POINTER_TYPE and rhs._tag == lhs._tag
        {
            if node.tag == ast.TAG_SUBTRACT
            {
                # The difference of two pointers.
                return g.items.get_ptr("uint") as *code.Handle;
            };
        };
    };

    # Attempt to perform common type resolution between the two types.
    let ty: *code.Handle = type_common(&x.lhs, lhs, &x.rhs, rhs);
    if code.isnil(ty) {
        # Determine the operation.
        let opname: str =
            if node.tag == ast.TAG_ADD { "+"; }
            else if node.tag == ast.TAG_SUBTRACT { "-"; }
            else if node.tag == ast.TAG_MULTIPLY { "*"; }
            else if node.tag == ast.TAG_DIVIDE { "/"; }
            else if node.tag == ast.TAG_MODULO { "%"; }
            else if node.tag == ast.TAG_INTEGER_DIVIDE { "//"; }
            else if node.tag == ast.TAG_EQ { "=="; }
            else if node.tag == ast.TAG_NE { "!="; }
            else if node.tag == ast.TAG_LT { "<"; }
            else if node.tag == ast.TAG_LE { "<="; }
            else if node.tag == ast.TAG_GT { ">"; }
            else if node.tag == ast.TAG_GE { ">="; }
            else if node.tag == ast.TAG_BITAND { "&"; }
            else if node.tag == ast.TAG_BITOR { "|"; }
            else if node.tag == ast.TAG_BITXOR { "*"; }
            else { "?"; };  # can't get here

        # Get formal type names.
        let mut lhs_name: string.String = code.typename(lhs);
        let mut rhs_name: string.String = code.typename(rhs);

        # Report error.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "no binary operation '%s' can be applied to types '%s' and '%s'",
                       opname, lhs_name.data(), rhs_name.data());
        errors.end();

        # Dispose.
        lhs_name.dispose();
        rhs_name.dispose();

        # Return nil.
        return code.make_nil();
        0; # HACK
    } else {
        # Worked; return the type.
        return ty;
        false; # HACK
    };
    return code.make_nil();
}

# Pass
# -----------------------------------------------------------------------------
let pass(g: *mut generator_.Generator, node: *ast.Node,
         scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Pass back what we got; check nothing.
    target;
}

# Boolean [TAG_BOOLEAN]
# -----------------------------------------------------------------------------
let boolean(g: *mut generator_.Generator, node: *ast.Node,
            scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Yep; this is a boolean.
    g.items.get_ptr("bool") as *code.Handle;
}

# Size Of [TAG_SIZEOF]
# -----------------------------------------------------------------------------
let sizeof(g: *mut generator_.Generator, node: *ast.Node,
           scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Yep; this is a boolean.
    g.items.get_ptr("uint") as *code.Handle;
}

# Integer [TAG_INTEGER]
# -----------------------------------------------------------------------------
let integer(g: *mut generator_.Generator, node: *ast.Node,
            scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    if not code.isnil(target) {
        if (target._tag == code.TAG_INT_TYPE
                or target._tag == code.TAG_FLOAT_TYPE) {
            # Return the targeted type.
            return target;
        };
    };

    # Without context we letault to `int`.
    g.items.get_ptr("int") as *code.Handle;
}

# Floating-point [TAG_FLOAT]
# -----------------------------------------------------------------------------
let float(g: *mut generator_.Generator, node: *ast.Node,
          scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    if not code.isnil(target) {
        if (target._tag == code.TAG_FLOAT_TYPE) {
            # Return the targeted type.
            return target;
        };
    };

    # Without context we letault to `float64`.
    g.items.get_ptr("float64") as *code.Handle;
}

# String [TAG_STRING]
# -----------------------------------------------------------------------------
let string_(g: *mut generator_.Generator, node: *ast.Node,
            scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Without context we letault to `str`.
    g.items.get_ptr("str") as *code.Handle;
}

# Identifier [TAG_IDENT]
# -----------------------------------------------------------------------------
let ident(g: *mut generator_.Generator, node: *ast.Node,
          scope: *code.Scope, target: *code.Handle): *code.Handle -> {
    # A simple identifier; this refers directly to a "named" type
    # in the current scope or any enclosing outer scope.

    # Retrieve the item with scope resolution rules.
    let id: *ast.Ident = node.unwrap() as *ast.Ident;
    let item: *code.Handle = generator_util.get_scoped_item_in(
        *g, id.name.data() as str, scope, g.ns);

    # Bail if we weren't able to resolve this identifier.
    if code.isnil(item) {
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "name '%s' is not defined",
                       id.name.data());
        errors.end();
        return code.make_nil();
    };

    # Resolve the item for its type.
    return _type_of(g, item);
}

# Self [TAG_SELF]
# -----------------------------------------------------------------------------
let self_(g: *mut generator_.Generator, node: *ast.Node,
          scope: *code.Scope, target: *code.Handle): *code.Handle -> {
    # Handle "self" identical to an identifier.
    # Retrieve the item with scope resolution rules.
    let item: *code.Handle = generator_util.get_scoped_item_in(
        *g, "self", scope, g.ns);

    # Bail if we weren't able to resolve this identifier.
    if code.isnil(item) {
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "name '%s' is not defined",
                       "self");
        errors.end();
        return code.make_nil();
    };

    # Resolve the item for its type.
    return _type_of(g, item);
}

# Assignment [TAG_ASSIGN]
# -----------------------------------------------------------------------------
let assign(g: *mut generator_.Generator, node: *ast.Node,
           scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Ensure that the types are compatible.
    let lhs: *code.Handle = resolver.resolve_s(g, &x.lhs, scope);
    let rhs: *code.Handle = resolver.resolve_s(g, &x.rhs, scope);
    if code.isnil(lhs) or code.isnil(rhs) { return code.make_nil(); };
    if not generator_util.type_compatible(lhs, rhs) { return code.make_nil(); };

    # An assignment resolves to the same type as its target.
    lhs;
}

# Member [TAG_MEMBER]
# -----------------------------------------------------------------------------
let member(g: *mut generator_.Generator, node: *ast.Node,
           scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let mut ns: list.List;
    let mut lhs: *code.Handle;
    let mut lhs_name: string.String;
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Get the name out of the rhs.
    let rhs_id: *ast.Ident = x.rhs.unwrap() as *ast.Ident;

    # Resolve the item reference in question.
    let mut item: *code.Handle;

    # Check if this is a global-qualified reference (`global.`).
    if x.lhs.tag == ast.TAG_GLOBAL
    {
        # Build the top-level namespace.
        ns = list.List.new(types.STR);
        ns.push_str(g.top_ns.data() as str);

        # Attempt to resolve the member.
        item = generator_util.get_scoped_item_in(
            *g, rhs_id.name.data() as str, scope, ns);

        # Dispose.
        ns.dispose();

        # Ensure we have a valid item.
        if code.isnil(item)
        {
             errors.begin_error();
             errors.libc.fprintf(errors.libc.stderr,
                            "name '%s' is not defined",
                            rhs_id.name.data());
             errors.end();
             return code.make_nil();
        };
    }
    else
    {
        # Resolve the type of the lhs.
        lhs = resolver.resolve_s(g, &x.lhs, scope);
        if code.isnil(lhs) { return code.make_nil(); };

        # If we are dealing with a pointer / reference.. obtain the type
        # that is the right most pointee
        while ((lhs._tag == code.TAG_POINTER_TYPE) or
               (lhs._tag == code.TAG_REFERENCE_TYPE))
        {
            if lhs._tag == code.TAG_POINTER_TYPE {
                let ptr: *code.PointerType = lhs._object as *code.PointerType;
                lhs = ptr.pointee;
                0;#HACK
            } else {
                let ref: *code.ReferenceType = lhs._object as *code.ReferenceType;
                lhs = ref.pointee;
                0;#HACK
            };
        }

        # Attempt to get an `item` out of the LHS.
        if lhs._tag == code.TAG_MODULE {
            let mod: *code.Module = lhs._object as *code.Module;

            # Build the namespace.
            let mut ns: list.List = mod.namespace.clone();
            ns.push_str(mod.name.data() as str);

            # Attempt to resolve the member.
            item = generator_util.get_scoped_item_in(
                *g, rhs_id.name.data() as str, scope, ns);

            # Do we have this item?
            if item == 0 as *code.Handle {
                # No; report and bail.
                 errors.begin_error();
                 errors.libc.fprintf(errors.libc.stderr,
                                "module '%s' has no member '%s'",
                                mod.name.data(), rhs_id.name.data());
                 errors.end();
                 return code.make_nil();
            };

            # Dispose.
            ns.dispose();
        } else if lhs._tag == code.TAG_STRUCT_TYPE {
            let struct_: *code.StructType = lhs._object as *code.StructType;

            # Check for an attached function.
            item = generator_util.get_attached_function(
                *g, lhs, rhs_id.name.data() as str);
            if not code.isnil(item) {
                # We have an attached function, probably.
                item = generator_type.generate_attached_function(
                    *g, "",
                    item._object as *code.AttachedFunction);
            } else {
                # Null us out.
                item = code.make_nil();
            };

            if code.isnil(item) {
                # Resolve the type of this specific structure member.
                item = generator_type.generate_struct_member(
                    *g, struct_, rhs_id.name.data() as str);
            };

            if code.isnil(item) {
                # Bail (error already reported).
                return code.make_nil();
            };
        } else if code.is_type(lhs) {
            # Check for an attached function.
            item = generator_util.get_attached_function(
                *g, lhs, rhs_id.name.data() as str);
            if not code.isnil(item) {
                # We have an attached function, probably.
                item = generator_type.generate_attached_function(
                    *g, "",
                    item._object as *code.AttachedFunction);
            } else {
                # Nope; report the error and bail.
                let mut typename: string.String = code.typename(lhs);
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                   "type '%s' has no member '%s'",
                   typename.data(), rhs_id.name.data());
                errors.end();
                typename.dispose();
                return code.make_nil();
            };
        } else {
            # Not sure how to resolve this.
            lhs_name = code.typename(lhs);

            # Report error.
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "member operation cannot be applied to type '%s'",
                           lhs_name.data());
            errors.end();

            # Dispose.
            lhs_name.dispose();

            # Return nil.
            return code.make_nil();
        };
    };

    # Resolve the item for its type.
    _type_of(g, item);
}

# Call [TAG_CALL]
# -----------------------------------------------------------------------------
let call(g: *mut generator_.Generator, node: *ast.Node,
         scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let mut ty: *code.FunctionType;
    let x: *ast.CallExpr = node.unwrap() as *ast.CallExpr;

    # Resolve the type of the call expression.
    let expr: *code.Handle = resolver.resolve_s(g, &x.expression, scope);
    if code.isnil(expr) { return code.make_nil(); };

    # Check what we are dealing with.
    if expr._tag == code.TAG_FUNCTION_TYPE
    {
        # Get it as a function type.
        ty = expr._object as *code.FunctionType;

        # Return the already resolved return type.
        ty.return_type;
    }
    else if expr._tag == code.TAG_STRUCT_TYPE
    {
        # Return ourself as invoking a structure returns a new one of us.
        expr;
    }
    else
    {
        # Get formal type name.
        let mut name: string.String = code.typename(expr);

        # Report error.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "type '%s' is not callable",
                       name.data());
        errors.end();

        # Dispose.
        name.dispose();

        # Return nil.
        code.make_nil();
    };
}

# Logical [TAG_LOGICAL_AND, TAG_LOGICAL_OR]
# -----------------------------------------------------------------------------
let logical(g: *mut generator_.Generator, node: *ast.Node,
            scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Resolve the type of the operands.
    let lhs: *code.Handle = resolver.resolve_s(g, &x.lhs, scope);
    if code.isnil(lhs) { return code.make_nil(); };
    let rhs: *code.Handle = resolver.resolve_s(g, &x.rhs, scope);
    if code.isnil(rhs) { return code.make_nil(); };

    # Ensure that we have a boolean.
    if lhs._tag != code.TAG_BOOL_TYPE {
        # Get formal type name.
        let mut ty_name: string.String = code.typename(lhs);

        # Report error.
        errors.begin_error();
        errors.libc.fprintf(
            errors.libc.stderr,
            "mismatched types: expected 'bool' but found '%s'",
            ty_name.data());

        errors.end();

        # Dispose.
        ty_name.dispose();

        # Return nil.
        return code.make_nil();
    };

    # Ensure that we have a boolean.
    if rhs._tag != code.TAG_BOOL_TYPE {
        # Get formal type name.
        let mut ty_name: string.String = code.typename(rhs);

        # Report error.
        errors.begin_error();
        errors.libc.fprintf(
            errors.libc.stderr,
            "mismatched types: expected 'bool' but found '%s'",
            ty_name.data());

        errors.end();

        # Dispose.
        ty_name.dispose();

        # Return nil.
        return code.make_nil();
    };

    # Ignore send back a boolean.
    g.items.get_ptr("bool") as *code.Handle;
}

# Relational [TAG_EQ, TAG_NE, TAG_LT, TAG_LE, TAG_GT, TAG_GE]
# -----------------------------------------------------------------------------
let relational(g: *mut generator_.Generator, node: *ast.Node,
               scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Resolve this as an arithmetic binary expression.
    let han: *code.Handle = arithmetic_b(g, node, scope, code.make_nil());
    if code.isnil(han) { return code.make_nil(); };

    # Then ignore the resultant type and send back a boolean.
    g.items.get_ptr("bool") as *code.Handle;
}

# Floating-point division [TAG_DIVIDE]
# -----------------------------------------------------------------------------
let divide(g: *mut generator_.Generator, node: *ast.Node,
           scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Resolve this as an arithmetic binary expression.
    let han: *code.Handle = arithmetic_b(g, node, scope, target);
    if code.isnil(han) { return code.make_nil(); };

    if han._tag == code.TAG_FLOAT_TYPE {
        # Return the floating-point type.
        han;
    } else {
        # Ignore the resultant type and send back a float64.
        g.items.get_ptr("float64") as *code.Handle;
    };
}

# Tuple [TAG_TUPLE_EXPR]
# -----------------------------------------------------------------------------
let tuple(g: *mut generator_.Generator, node: *ast.Node,
          scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.TupleExpr = node.unwrap() as *ast.TupleExpr;

    # Iterate through each element of the tuple.
    let mut i: int = 0;
    let mut elements: list.List = list.List.new(types.PTR);
    let mut eleme_type_handles: list.List = list.List.new(types.PTR);
    while i as uint < x.nodes.size()
    {
        # Get the specific element.
        let enode: ast.Node = x.nodes.get(i);
        i = i + 1;
        let e: *ast.TupleExprMem = enode.unwrap() as *ast.TupleExprMem;

        # Resolve the type of this element expression.
        let expr: *code.Handle = resolver.resolve_st(
            g, &e.expression, scope, target);
        if code.isnil(expr) { return code.make_nil(); };
        let typ: *code.Type = expr._object as *code.Type;

        # Push the type and its handle.
        elements.push_ptr(expr as *int8);
        eleme_type_handles.push_ptr(typ.handle as *int8);
    }

    # Build the LLVM type handle.
    let mut val: *llvm.LLVMOpaqueType;
    val = llvm.LLVMStructType(
        eleme_type_handles.elements as *llvm.LLVMOpaqueType,
        eleme_type_handles.size as uint32,
        0);

    # Create and store our type.
    let mut han: *code.Handle;
    han = code.make_tuple_type(val, elements);

    # Dispose of dynamic memory.
    eleme_type_handles.dispose();

    # Return the type handle.
    han;
}

# Tuple Type [TAG_TUPLE_TYPE]
# -----------------------------------------------------------------------------
let tuple_type(g: *mut generator_.Generator, node: *ast.Node,
               scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.TupleType = node.unwrap() as *ast.TupleType;

    # Iterate through each element of the tuple.
    let mut i: int = 0;
    let mut elements: list.List = list.List.new(types.PTR);
    let mut eleme_type_handles: list.List = list.List.new(types.PTR);
    while i as uint < x.nodes.size()
    {
        # Get the specific element.
        let enode: ast.Node = x.nodes.get(i);
        i = i + 1;
        let e: *ast.TupleTypeMem = enode.unwrap() as *ast.TupleTypeMem;

        # Resolve the type of this element expression.
        let expr: *code.Handle = resolver.resolve_st(
            g, &e.type_, scope, target);
        if code.isnil(expr) { return code.make_nil(); };
        let typ: *code.Type = expr._object as *code.Type;

        # Push the type and its handle.
        elements.push_ptr(expr as *int8);

        # Emplace the type handle.
        eleme_type_handles.push_ptr(typ.handle as *int8);
    }

    # Build the LLVM type handle.
    let mut val: *llvm.LLVMOpaqueType;
    val = llvm.LLVMStructType(
        eleme_type_handles.elements as *llvm.LLVMOpaqueType,
        eleme_type_handles.size as uint32,
        0);

    # Create and store our type.
    let mut han: *code.Handle;
    han = code.make_tuple_type(val, elements);

    # Dispose of dynamic memory.
    eleme_type_handles.dispose();

    # Return the type handle.
    han;
}

# Delegate [TAG_DELEGATE]
# -----------------------------------------------------------------------------
let delegate_(g: *mut generator_.Generator, node: *ast.Node,
              scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.Delegate = node.unwrap() as *ast.Delegate;

    # Resolve the return type.
    let ret_han: *code.Handle = generator_type._generate_return_type(
        *g,
        &x.return_type,
        &g.ns,
        scope);
    if code.isnil(ret_han) { return code.make_nil(); };
    let ret_typ: *code.Type = ret_han._object as *code.Type;
    let ret_typ_han: *llvm.LLVMOpaqueType = ret_typ.handle;

    # Resolve the type for each parameter.
    let mut params: list.List = list.List.new(types.PTR);
    let mut param_type_handles: list.List = list.List.new(types.PTR);
    let mut i: int = 0;
    while i as uint < x.params.size()
    {
        let pnode: ast.Node = x.params.get(i);
        i = i + 1;
        let p: *ast.FuncParam = pnode.unwrap() as *ast.FuncParam;
        if not generator_type._generate_func_param(
            *g, p, &g.ns, scope, params, param_type_handles, true)
        {
             return code.make_nil();
        };
    }

    # Build the LLVM type handle.
    let mut val: *llvm.LLVMOpaqueType;
    val = llvm.LLVMFunctionType(
        ret_typ_han,
        param_type_handles.elements as *llvm.LLVMOpaqueType,
        param_type_handles.size as uint32,
        0);

    # Create and store our type.
    let mut han: *code.Handle;
    han = code.make_function_type("", g.ns, "" as str, val, ret_han, params);

    # Dispose of dynamic memory.
    param_type_handles.dispose();

    # Return the type handle.
    han;
}

# Array [TAG_ARRAY_EXPR]
# -----------------------------------------------------------------------------
let array(g: *mut generator_.Generator, node: *ast.Node,
          scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.ArrayExpr = node.unwrap() as *ast.ArrayExpr;

    # Iterate through each element of the tuple.
    let mut i: int = 0;
    let mut type_han: *code.Handle = code.make_nil();
    let mut prev_el: ast.Node = ast.null();
    while i as uint < x.nodes.size()
    {
        # Get the specific element.
        let enode: ast.Node = x.nodes.get(i);

        # Resolve the type of this element expression.
        let han: *code.Handle = resolver.resolve_st(
            g, &enode, scope, target);
        if code.isnil(han) { return code.make_nil(); };

        if code.isnil(type_han) {
            # This is the first block; set the type_han directly.
            type_han = han;
        } else {
            # Need to resolve the common type between this and
            # the existing handle.
            let com_han: *code.Handle = type_common(
                &prev_el, type_han, &enode, han);
            if code.isnil(com_han) {
                # There was no common type found.
                # Get formal type names.
                let mut lhs_name: string.String = code.typename(type_han);
                let mut rhs_name: string.String = code.typename(han);

                # Report error.
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                               "no common type can be resolved for '%s' and '%s'",
                               lhs_name.data(), rhs_name.data());
                errors.end();

                # Dispose.
                lhs_name.dispose();
                rhs_name.dispose();

                return code.make_nil();
            };

            # Common type found; set as the new type han.
            type_han = com_han;
            0; # HACK
        };

        # Move along to the next node.
        prev_el = enode;
        i = i + 1;
    }

    # Build the LLVM type handle.
    let type_: *code.Type = type_han._object as *code.Type;
    let mut val: *llvm.LLVMOpaqueType;
    val = llvm.LLVMArrayType(
        generator_util.alter_type_handle(type_han),
        x.nodes.size() as uint32);

    # Create and store our type.
    let mut han: *code.Handle;
    han = code.make_array_type(type_han, x.nodes.size(), val);

    # Return the type handle.
    han;
}

# Conditional Expression [TAG_CONDITIONAL]
# -----------------------------------------------------------------------------
let conditional(g: *mut generator_.Generator, node: *ast.Node,
                scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.ConditionalExpr = node.unwrap() as *ast.ConditionalExpr;

    # Resolve the types of the operands.
    let lhs: *code.Handle = resolver.resolve_s(g, &x.lhs, scope);
    let rhs: *code.Handle = resolver.resolve_s(g, &x.rhs, scope);
    if code.isnil(lhs) or code.isnil(rhs) { return code.make_nil(); };

    # Attempt to perform common type resolution between the two types.
    let ty: *code.Handle = type_common(&x.lhs, lhs, &x.rhs, rhs);
    if code.isnil(ty) {
        # Get formal type names.
        let mut lhs_name: string.String = code.typename(lhs);
        let mut rhs_name: string.String = code.typename(rhs);

        # Report error.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "no common type can be resolved for '%s' and '%s'",
                       lhs_name.data(), rhs_name.data());
        errors.end();

        # Dispose.
        lhs_name.dispose();
        rhs_name.dispose();

        # Return nil.
        return code.make_nil();
    };

    # Resolve the type of the condition.
    let cond: *code.Handle = resolver.resolve_s(g, &x.condition, scope);
    if code.isnil(cond) { return code.make_nil(); };

    # Ensure that we have a boolean for the condition.
    if cond._tag != code.TAG_BOOL_TYPE {
        # Get formal type name.
        let mut ty_name: string.String = code.typename(cond);

        # Report error.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "mismatched types: expected 'bool' but found '%s'",
                       ty_name.data());
        errors.end();

        # Dispose.
        ty_name.dispose();

        # Return nil.
        return code.make_nil();
    };

    # Return the common type of the branches.
    ty;
}

# Selection [TAG_SELECT_EXPR]
# -----------------------------------------------------------------------------
let select(g: *mut generator_.Generator, node: *ast.Node,
           scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.SelectExpr = node.unwrap() as *ast.SelectExpr;

    # Iterate through the branches in a selection expression.
    let mut type_han: *code.Handle = code.make_nil();
    let mut has_value: bool = x.branches.size() > 1;
    let mut i: int = 0;
    let mut prev_br: ast.Node = ast.null();
    let bool_ty: *code.Handle = g.items.get_ptr("bool") as *code.Handle;
    let mut else_: bool = false;
    while i as uint < x.branches.size() {
        let brn: ast.Node = x.branches.get(i);
        let br: *ast.SelectBranch = brn.unwrap() as *ast.SelectBranch;
        let blk_node: ast.Node = br.block;
        let blk: *ast.Block = blk_node.unwrap() as *ast.Block;

        # Attempt to resolve the type of the condition and ensure it is of
        # the boolean type (only if there is a condition).
        if not ast.isnull(br.condition) {
            let cond_ty: *code.Handle = resolver.resolve_st(
                g, &br.condition, scope, bool_ty);
            if code.isnil(cond_ty) { return code.make_nil(); };
        } else {
            # There can only be a branch without a condition in
            # a select on the final `else` branch.
            else_ = true;
        };

        if has_value {
            # Is this block not empty (does it not have any nodes)?
            if blk.nodes.size() == 0 {
                # Yep; this expression no longer has value.
                has_value = false;
                break;
            };

            # Resolve the type of the final node in the block.
            let node: ast.Node = blk.nodes.get(-1);
            let han: *code.Handle = resolver.resolve_st(
                g, &node, scope, target);
            if code.isnil(han) {
                # This block does not resolve to a value; this causes
                # the entire select expression to not resolve to a
                # value.
                has_value = false;
                break;
            };

            if code.isnil(type_han) {
                # This is the first block; set the type_han directly.
                type_han = han;
            } else {
                # Need to resolve the common type between this and
                # the existing handle.
                let com_han: *code.Handle = type_common(
                    &prev_br, type_han, &brn, han);
                if code.isnil(com_han) {
                    # There was no common type found; silently treat
                    # this as a statement now.
                    has_value = false;
                    break;
                };

                # Common type found; set as the new type han.
                type_han = com_han;
                0; # HACK
            };
        };

        # Move along to the next branch.
        prev_br = brn;
        i = i + 1;
    }

    if not has_value or not else_ {
        # Return the void type.
        code.make_void_type(llvm.LLVMVoidType());
    } else {
        # Return the value type.
        type_han;
    };
}

# Pointer Type [TAG_POINTER_TYPE]
# -----------------------------------------------------------------------------
let pointer_type(g: *mut generator_.Generator, node: *ast.Node,
                 scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.PointerType = node.unwrap() as *ast.PointerType;

    # Resolve the types of the pointee.
    let pointee: *code.Handle = resolver.resolve_s(g, &x.pointee, scope);
    if code.isnil(pointee) { return code.make_nil(); };
    let pointee_type: *code.Type = pointee._object as *code.Type;

    # Create the llvm pointer to the pointee.
    let val = llvm.LLVMPointerType(pointee_type.handle, 0);

    # Return the new pointer type.
    code.make_pointer_type(pointee, x.mutable, val);
}

# Array Type [TAG_ARRAY_TYPE]
# -----------------------------------------------------------------------------
let array_type(g: *mut generator_.Generator, node: *ast.Node,
               scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.ArrayType = node.unwrap() as *ast.ArrayType;

    # Resolve the types of the pointee.
    let element: *code.Handle = resolver.resolve_s(g, &x.element, scope);
    if code.isnil(element) { return code.make_nil(); };
    let element_type: *code.Type = element._object as *code.Type;

    # Resolve the type of the size.
    let size_ty: *code.Handle = g.items.get_ptr("uint") as *code.Handle;
    let size: *code.Handle = resolver.resolve_st(g, &x.size, scope, size_ty);
    if code.isnil(size) { return code.make_nil(); };

    # Ensure we are dealing with a "integral" type.
    # Ensure this is unsigned.
    let mut error: bool = false;
    error = size._tag != code.TAG_INT_TYPE;
    if not error
    {
        let size_type: *code.IntegerType = size._object as *code.IntegerType;
        error = size_type.signed;
    };

    if error
    {
        # Report error.
        let mut s_typename: string.String = code.typename(size);
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "mismatched types: expected `unsigned integer` but found '%s'",
                       s_typename.data());
        errors.end();

        # Dispose.
        s_typename.dispose();

        # Return nil.
        return code.make_nil();
    };

    # Build the size.
    let mut size_han: *code.Handle;
    size_han = builder.build(g, &x.size, scope, size_ty);
    if code.isnil(size_han) { return code.make_nil(); };
    let size_val_han: *code.Handle = generator_def.to_value(
        *g, size_han, code.VC_RVALUE, true);
    let size_val: *code.Value = size_val_han._object as *code.Value;
    if code.isnil(size_val_han) { return code.make_nil(); };

    # If we are dealing with a `Constant` ...
    if llvm.LLVMIsConstant(size_val.handle) != 0
    {
        # TODO: We should implement a heuristic that would determine
        #   whether this is a heap-allocated array or not. Something
        #   like int[100000] shouldn't go on the stack as it just
        #   woudln't fit.

        # Get the size of the array out of the contsant value.
        let val: uint64 = llvm.LLVMConstIntGetZExtValue(size_val.handle);

        # Create the LLVM type.
        let mut handle: *llvm.LLVMOpaqueType;
        # handle = llvm.LLVMArrayType(element_type.handle, val as uint32);
        handle = llvm.LLVMArrayType(
            generator_util.alter_type_handle(element),
            val as uint32);

        # Return the new pointer type.
        code.make_array_type(element, val, handle);
    }
    else
    {
        # Else, make a variable length array on the heap.
        # TODO: This requires the concept of destructors to be implmented.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "not implemented: heap-allocated arrays");
        errors.end();
        code.make_nil();
    };
}

# Address Of Expression [TAG_ADDRESS_OF]
# -----------------------------------------------------------------------------
let address_of(g: *mut generator_.Generator, node: *ast.Node,
               scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.AddressOfExpr = node.unwrap() as *ast.AddressOfExpr;

    # Resolve the types of the operand.
    let pointee: *code.Handle = resolver.resolve_s(g, &x.operand, scope);
    if code.isnil(pointee) { return code.make_nil(); };
    let pointee_type: *code.Type = pointee._object as *code.Type;

    # Create the llvm pointer to the pointee.
    let mut val: *llvm.LLVMOpaqueType;
    val = llvm.LLVMPointerType(pointee_type.handle, 0);

    # Return the new pointer type.
    code.make_pointer_type(pointee, x.mutable, val);
}

# Dereference Expression [TAG_DEREF]
# -----------------------------------------------------------------------------
let dereference(g: *mut generator_.Generator, node: *ast.Node,
                scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.UnaryExpr = node.unwrap() as *ast.UnaryExpr;

    # Resolve the types of the operand.
    let operand: *code.Handle = resolver.resolve_s(g, &x.operand, scope);
    if code.isnil(operand) { return code.make_nil(); };

    # Ensure we are dealing with a pointer.
    if operand._tag != code.TAG_POINTER_TYPE
    {
        # Report error.
        let mut typename: string.String = code.typename(operand);
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "type `%s` cannot be dereferenced",
                       typename.data());
        errors.end();

        # Dispose.
        typename.dispose();

        # Bail.
        return code.make_nil();
    };

    # Return the pointee type.
    let operand_type: *code.PointerType = operand._object as *code.PointerType;
    return operand_type.pointee;
}

# Cast Expression [TAG_CAST]
# -----------------------------------------------------------------------------
let cast(g: *mut generator_.Generator, node: *ast.Node,
         scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # TODO: At the moment an "explicit" cast such as this has no rules
    #       and unilaterly attempts to cast anything to anything. It will
    #       grow rules eventually.

    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Resolve the destination type.
    let dest: *code.Handle = resolver.resolve_s(g, &x.rhs, scope);
    if code.isnil(dest) { return code.make_nil(); };

    # Return the destination type.
    dest;
}

# Loop [TAG_LOOP]
# -----------------------------------------------------------------------------
let loop_(g: *mut generator_.Generator, node: *ast.Node,
          scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.Loop = node.unwrap() as *ast.Loop;

    # Attempt to resolve the type of the condition and ensure it is of
    # the boolean type (only if there is a condition).
    let bool_ty: *code.Handle = g.items.get_ptr("bool") as *code.Handle;
    if not ast.isnull(x.condition) {
        let cond_ty: *code.Handle = resolver.resolve_st(
            g, &x.condition, scope, bool_ty);
        if code.isnil(cond_ty) { return code.make_nil(); };
    };

    # Loops resolve to nothing.
    code.make_void_type(llvm.LLVMVoidType());
}

# Index Expression [TAG_INDEX]
# -----------------------------------------------------------------------------
let index(g: *mut generator_.Generator, node: *ast.Node,
          scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.IndexExpr = node.unwrap() as *ast.IndexExpr;

    # Resolve the types of the operand.
    let mut operand: *code.Handle = resolver.resolve_s(g, &x.expression, scope);
    if code.isnil(operand) { return code.make_nil(); };

    # Pull out the reference if we are dealing with a reference type.
    if operand._tag == code.TAG_REFERENCE_TYPE {
        let ref: *code.ReferenceType = operand._object as *code.ReferenceType;
        operand = ref.pointee;
    };

    # Ensure we are dealing with an array.
    if operand._tag != code.TAG_ARRAY_TYPE
    {
        # Report error.
        let mut typename: string.String = code.typename(operand);
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "type `%s` cannot be indexed",
                       typename.data());
        errors.end();

        # Dispose.
        typename.dispose();

        # Bail.
        return code.make_nil();
    };

    # Resolve the type of the subscript.
    let subscript: *code.Handle = resolver.resolve_s(g, &x.subscript, scope);
    if code.isnil(operand) { return code.make_nil(); };

    # Ensure we are dealing with an integral type.
    if subscript._tag != code.TAG_INT_TYPE
    {
        # Report error.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "array subscript is not an integer");
        errors.end();

        # Bail.
        return code.make_nil();
    };

    # Return the element type.
    let operand_type: *code.ArrayType = operand._object as *code.ArrayType;
    return operand_type.element;
}

# Return statement [TAG_RETURN]
# -----------------------------------------------------------------------------
let return_(g: *mut generator_.Generator, node: *ast.Node,
            scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.ReturnExpr = node.unwrap() as *ast.ReturnExpr;

    # Get the return type of the current function.
    let cur_fn_type: *code.FunctionType =
        g.current_function.type_._object as *code.FunctionType;
    let target_type: *code.Handle = cur_fn_type.return_type;

    if not ast.isnull(x.expression)
    {
        # Resolve the types of the operand.
        let operand: *code.Handle = resolver.resolve_st(
            g, &x.expression, scope, target_type);
        if code.isnil(operand) { return code.make_nil(); };
        if not generator_util.type_compatible(target_type, operand)
        {
            return code.make_nil();
        };
    }
    else if not code.isnil(target_type)
    {
        if not generator_util.type_compatible(
            target_type, code.make_void_type(llvm.LLVMVoidType()))
        {
            return code.make_nil();
        };
    };

    # Return void (a return isn't worth anything, type-wise to the block).
    code.make_void_type(llvm.LLVMVoidType());
}
