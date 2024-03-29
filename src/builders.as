import string;
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
let ident(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Retrieve the item with scope resolution rules.
    let id: *ast.Ident = node.unwrap() as *ast.Ident;
    let item: *code.Handle = generator_util.get_scoped_item_in(
        *g, id.name.data() as str, scope, g.ns);

    # Return the item.
    item;
}

# Self [TAG_SELF]
# -----------------------------------------------------------------------------
let self_(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Handle "self" identical to an identifier.
    # Retrieve the item with scope resolution rules.
    let item: *code.Handle = generator_util.get_scoped_item_in(
        *g, "self", scope, g.ns);

    # Return the item.
    item;
}

# Boolean [TAG_BOOLEAN]
# -----------------------------------------------------------------------------
let boolean(g: *mut generator_.Generator, node: *ast.Node,
            scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BooleanExpr = node.unwrap() as *ast.BooleanExpr;

    # Build a llvm val for the boolean expression.
    let val = llvm.LLVMConstInt(llvm.LLVMInt1Type(), (1 if x.value else 0), false);

    # Wrap and return the value.
    code.make_value(target, code.VC_RVALUE, val);
}

# Size Of [TAG_SIZEOF]
# -----------------------------------------------------------------------------
let sizeof(g: *mut generator_.Generator, node: *ast.Node,
           scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.SizeOf = node.unwrap() as *ast.SizeOf;

    # Resolve the type of the expression.
    let mut typ: *code.Handle;
    typ = resolver.resolve_s(g, &x.type_, scope);
    if code.isnil(typ) { return code.make_nil(); };

    # Build and return the sizeof.
    generator_util.build_sizeof(*g, typ);
}

# Integer [TAG_INTEGER]
# -----------------------------------------------------------------------------
let integer(g: *mut generator_.Generator, node: *ast.Node,
            scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.IntegerExpr = node.unwrap() as *ast.IntegerExpr;

    # Get the type handle from the target.
    let typ: *code.Type = target._object as *code.Type;

    # Build a llvm val for the boolean expression.
    let mut val: *llvm.LLVMOpaqueValue;
    if target._tag == code.TAG_INT_TYPE
    {
        val = llvm.LLVMConstIntOfString(
            typ.handle, x.text.data(), x.base as uint8);
    }
    else
    {
        val = llvm.LLVMConstRealOfString(typ.handle, x.text.data());
    };

    # Wrap and return the value.
    code.make_value(target, code.VC_RVALUE, val);
}

# Floating-point [TAG_FLOAT]
# -----------------------------------------------------------------------------
let float(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.FloatExpr = node.unwrap() as *ast.FloatExpr;

    # Get the type handle from the target.
    let typ: *code.Type = target._object as *code.Type;

    # Build a llvm val for the boolean expression.
    let val = llvm.LLVMConstRealOfString(typ.handle, x.text.data());

    # Wrap and return the value.
    code.make_value(target, code.VC_RVALUE, val);
}

# String [TAG_STRING]
# -----------------------------------------------------------------------------
let string_(g: *mut generator_.Generator, node: *ast.Node,
            scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.StringExpr = node.unwrap() as *ast.StringExpr;

    # Get the type handle from the target.
    let typ: *code.Type = target._object as *code.Type;

    # Unescape the string.
    let mut bytes: list.List = x.unescape();

    # Close the text.
    let raw_bytes: *int8 = bytes.elements;
    *(raw_bytes + bytes.size) = 0;

    # Build a llvm val for the ASCII string.
    let val = llvm.LLVMBuildGlobalStringPtr(g.irb, raw_bytes as str, "");

    # Dispose.
    bytes.dispose();

    # Wrap and return the value.
    code.make_value_c(node, target, code.VC_RVALUE, val);
}

# Local Slot [TAG_SLOT]
# -----------------------------------------------------------------------------
let local_slot(g: *mut generator_.Generator, node: *ast.Node,
               scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.SlotDecl = node.unwrap() as *ast.SlotDecl;

    # Get the name out of the node.
    let id: *ast.Ident = x.id.unwrap() as *ast.Ident;

    # Get and build the type node (if we have one).
    let mut type_han: *code.Handle = code.make_nil();
    let mut type_: *code.Type = 0 as *code.Type;
    if not ast.isnull(x.type_) {
        # Resolve the initial type.
        type_han = resolver.resolve_s(g, &x.type_, scope);
        if code.isnil(type_han) { return code.make_nil(); };
        type_ = type_han._object as *code.Type;
    };

    # Get and resolve the initializer (if we have one).
    let mut init: *llvm.LLVMOpaqueValue = 0 as *llvm.LLVMOpaqueValue;
    if not ast.isnull(x.initializer) {
        # Resolve the type of the initializer.
        let mut typ: *code.Handle;
        typ = resolver.resolve_st(g, &x.initializer, scope, type_han);
        if code.isnil(typ) { return code.make_nil(); };

        # Check and set
        if code.isnil(type_han) {
            type_han = typ;
            type_ = type_han._object as *code.Type;
        };# else {
        #     # Ensure that the types are compatible.
        #     if not generator_util.type_compatible(type_han, typ) {
        #         return code.make_nil();
        #     }
        # }

        # Build the initializer
        let han = builder.build(g, &x.initializer, scope, typ);
        if code.isnil(han) { return code.make_nil(); };

        # Coerce this to a value.
        let val_han: *code.Handle = generator_def.to_value(
            *g, han, code.VC_RVALUE, false);

        # Cast it to the target value.
        let cast_han: *code.Handle = generator_util.cast(
            *g, val_han, type_han, false);
        if code.isnil(cast_han) { return code.make_nil(); };
        let cast_val: *code.Value = cast_han._object as *code.Value;
        init = cast_val.handle;
    };

    # Build a stack allocation.
    let val = llvm.LLVMBuildAlloca(
        g.irb, generator_util.alter_type_handle(type_han), id.name.data());

    # Build the store.
    if init != 0 as *llvm.LLVMOpaqueValue {
        llvm.LLVMBuildStore(g.irb, init, val);
    };

    # Wrap.
    let han = code.make_local_slot(type_han, x.mutable, val);

    # Insert into the current local scope block.
    scope.insert(id.name.data() as str, han);

    # Return.
    han;
}

# Member [TAG_MEMBER]
# -----------------------------------------------------------------------------
let member(g: *mut generator_.Generator, node: *ast.Node,
           scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let mut lhs: *code.Handle;
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Get the name out of the rhs.
    let rhs_id: *ast.Ident = x.rhs.unwrap() as *ast.Ident;

    # Check if this is a special member resolution (`global.`)
    let mut item: *code.Handle;
    if x.lhs.tag == ast.TAG_GLOBAL {
        # Build the namespace.
        let mut ns: list.List = list.List.new(types.STR);
        ns.push_str(g.top_ns.data() as str);

        # Attempt to resolve the member.
        item = generator_util.get_scoped_item_in(
            *g, rhs_id.name.data() as str, scope, ns);

        # Dispose.
        ns.dispose();
        0; # HACK
    } else {
        # Build the operand.
        lhs = builder.build(
            g, &x.lhs, scope, code.make_nil());
        if code.isnil(lhs) { return code.make_nil(); };

        if lhs._tag != code.TAG_MODULE {

            # If we are dealing with a pointer / reference.. obtain the value
            # that is the right most pointee
            loop
            {
                let lhs_type_handle: *code.Handle = code.type_of(lhs);
                if lhs_type_handle._tag == code.TAG_POINTER_TYPE
                {
                    let ref: *code.PointerType = lhs_type_handle._object as
                        *code.PointerType;
                    let lhs_val: *code.Value = lhs._object as *code.Value;
                    let mut load_val: *llvm.LLVMOpaqueValue =
                        llvm.LLVMBuildLoad(g.irb, lhs_val.handle, "");
                    lhs = code.make_value(ref.pointee, code.VC_LVALUE, load_val);
                    0; # HACK
                }
                else if lhs_type_handle._tag == code.TAG_REFERENCE_TYPE
                {
                    let ref: *code.ReferenceType = lhs_type_handle._object as
                        *code.ReferenceType;
                    let lhs_val: *code.Value = lhs._object as *code.Value;
                    let mut load_val: *llvm.LLVMOpaqueValue =
                        llvm.LLVMBuildLoad(g.irb, lhs_val.handle, "");
                    lhs = code.make_value(ref.pointee, code.VC_LVALUE, load_val);
                    0; # HACK
                }
                else
                {
                    break;
                };
            }
            0; # HACK
        };

        # Attempt to get an `item` out of the LHS.
        if lhs._tag == code.TAG_MODULE
        {
            let mod: *code.Module = lhs._object as *code.Module;

            # Extend our namespace.
            let mut ns: list.List = mod.namespace.clone();
            ns.push_str(mod.name.data() as str);

            # Attempt to resolve the member.
            item = generator_util.get_scoped_item_in(
                *g, rhs_id.name.data() as str, scope, ns);

            # Dispose.
            ns.dispose();
            0; # HACK
        }
        else if lhs._tag == code.TAG_FUNCTION
        {
            let fn: *code.Function = lhs._object as *code.Function;

            # Extend our namespace.
            let mut ns: list.List = fn.namespace.clone();
            ns.push_str(fn.name.data() as str);

            # Attempt to resolve the member.
            item = generator_util.get_scoped_item_in(
                *g, rhs_id.name.data() as str, scope, ns);

            # Dispose.
            ns.dispose();
            0; # HACK
        }
        else if lhs._tag == code.TAG_STRUCT
        {
            let type_: *code.Handle = code.type_of(lhs);

            # Check for an attached function.
            item = generator_util.get_attached_function(
                *g, type_, rhs_id.name.data() as str);
            if not code.isnil(item) {
                # We have an attached function.
                return item;
            };
        }
        else if code.is_type(lhs)
        {
           # Check for an attached function.
           item = generator_util.get_attached_function(
               *g, lhs, rhs_id.name.data() as str);
           if not code.isnil(item) {
               # We have an attached function.
               return item;
           };
        }
        else if    lhs._tag == code.TAG_VALUE
                or lhs._tag == code.TAG_LOCAL_SLOT
        {
            # Continue based on the type of the value.
            let value: *code.Value = lhs._object as *code.Value;
            let type_: *code.Handle = value.type_;
            if type_._tag == code.TAG_STRUCT_TYPE
            {
                # Get the structural type.
                let struct_: *code.StructType = type_._object as
                    *code.StructType;

                # Check for an attached function.
                item = generator_util.get_attached_function(
                    *g, type_, rhs_id.name.data() as str);
                if not code.isnil(item) {
                    # We have an attached member function.
                    g.current_self = lhs;
                    return item;
                };

                # Get the index of the member.
                let member_han: *code.Handle = struct_.member_map.get_ptr(
                    rhs_id.name.data() as str) as *code.Handle;
                let member: *code.Member = member_han._object as *code.Member;
                let idx: uint = member.index;

                # Build an accessor to the member.
                let val: *llvm.LLVMOpaqueValue =
                    llvm.LLVMBuildStructGEP(
                        g.irb, value.handle, idx as uint32, "");

                # Wrap and return a lvalue.
                let han = code.make_value(member.type_, code.VC_LVALUE, val);

                # Return our wrapped result.
                return han;
            };
        };
    };

    # Return our item.
    item;
}

# Call [TAG_CALL]
# -----------------------------------------------------------------------------
let call_function(g: *mut generator_.Generator, node: *ast.CallExpr,
                  scope: *mut code.Scope,
                  handle: *llvm.LLVMOpaqueValue,
                  type_: *code.FunctionType): *code.Handle ->
{
    # First we create and zero a list to hold the entire argument list.
    let mut argl: list.List = list.List.new(types.PTR);
    argl.reserve(type_.parameters.size);
    argl.size = type_.parameters.size;
    libc.memset(argl.elements as *int8, 0, (argl.size * argl.element_size) as int32);
    let mut argv: *mut *llvm.LLVMOpaqueValue =
        argl.elements as *mut *llvm.LLVMOpaqueValue;

    # If we are dealing with an "instance" function then push in self.
    let mut self_idx: uint = 0;
    if type_.parameter_map.contains("self") {
        if not code.isnil(g.current_self) {
            self_idx = 1;
            let self_param_idx: int =
                type_.parameter_map.get_uint("self") as int;
            let self_param_han: *code.Handle =
                type_.parameters.get_ptr(self_param_idx) as *code.Handle;
            let self_param: *code.Parameter = self_param_han._object as
                *code.Parameter;
            let self_han: *code.Handle = g.current_self;
            let self_val_han: *code.Handle = generator_def.to_value(
                *g, self_han, code.VC_RVALUE, false);
            let self_val_: *code.Value = self_val_han._object as *code.Value;
            let self_cast_han: *code.Handle = generator_util.cast(
                *g, self_val_han, self_param.type_, false);
            if code.isnil(self_cast_han) { return code.make_nil(); };
            let self_val: *code.Value = self_cast_han._object as *code.Value;
            *(argv + 0) = self_val.handle;
            g.current_self = code.make_nil();
        };
    };

    # Iterate through each argument, build, and push them into
    # their appropriate position in the argument list.
    let mut i: int = 0;
    let mut param_idx: uint = self_idx;
    let mut variadic_index: uint = 0;
    let mut variadic: bool = false;
    while i as uint < node.arguments.size()
    {
        # Get the specific argument.
        let anode: ast.Node = node.arguments.get(i);
        i = i + 1;
        let a: *ast.Argument = anode.unwrap() as *ast.Argument;

        # Find the parameter index.
        # NOTE: The parser handles making sure no positional arg
        #   comes after a keyword arg.
        if not ast.isnull(a.name)
        {
            # Get the name data for the id.
            let id: *ast.Ident = a.name.unwrap() as *ast.Ident;

            # Check for the existance of this argument.
            if not type_.parameter_map.contains(id.name.data() as str)
            {
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                               "unexpected keyword argument '%s'",
                               id.name.data());
                errors.end();
                return code.make_nil();
            };

            # Pull the named argument index.
            param_idx = type_.parameter_map.get_uint(id.name.data() as str);

            # Check if we already have one of these.
            if *(argv + param_idx) != 0 as *llvm.LLVMOpaqueValue {
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                               "got multiple values for argument '%s'",
                               id.name.data());
                errors.end();
                return code.make_nil();
            };
        };

        # Ensure that we haven't run off the parameter list.
        if type_.parameters.size <= param_idx {
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                                "too many arguments in call");
            errors.end();
            return code.make_nil();
        };

        # Get the parameter.
        let prm_han: *code.Handle = type_.parameters.get_ptr(
            param_idx as int) as *code.Handle;
        let prm: *code.Parameter = prm_han._object as *code.Parameter;

        # Resolve the type of the argument expression.
        let mut typ: *code.Handle = code.make_nil();
        let mut param_typ: *code.Handle = code.make_nil();
        if not prm.variadic {
            param_typ = code.type_of(prm_han);
            typ = resolver.resolve_st(g, &a.expression, scope, param_typ);
            if code.isnil(typ) { return code.make_nil(); };
        } else {
            variadic = true;
            typ = resolver.resolve_st(g, &a.expression, scope,
                                      code.make_nil());
            if code.isnil(typ) { return code.make_nil(); };
        };

        # Build the argument expression node.
        let han: *code.Handle = builder.build(g, &a.expression, scope, typ);
        if code.isnil(han) { return code.make_nil(); };

        # Coerce this to a value.
        let val_han: *code.Handle = generator_def.to_value(
            *g, han, code.VC_RVALUE, false);

        if not prm.variadic {
            # Cast the value to the target type.
            let cast_han: *code.Handle = generator_util.cast(
                *g, val_han, param_typ, false);
            if code.isnil(cast_han) { return code.make_nil(); };
            let cast_val: *code.Value = cast_han._object as *code.Value;

            # Emplace in the argument list.
            *(argv + param_idx) = cast_val.handle;

            # Dispose.
            code.dispose(cast_han);
        } else {
            # Get the value handle
            let val: *code.Value = val_han._object as *code.Value;

            # Make more room.
            if variadic_index > 0 {
                argl.reserve(argl.size + 1);
                argv = argl.elements as **llvm.LLVMOpaqueValue;
                argl.size = argl.size + 1;
            };

            # Emplace in the argument list.
            (*(argv + (param_idx + variadic_index))) = val.handle;
            variadic_index = variadic_index + 1;
            0; # HACK
        };

        # Dispose.
        code.dispose(val_han);

        if ast.isnull(a.name) and not variadic {
            # Increment parameter index.
            param_idx = param_idx + 1;
        };
    }

    # Check for missing arguments.
    i = 0;
    let mut error: bool = false;
    while i as uint < argl.size {
        let arg: *llvm.LLVMOpaqueValue = *(argv + i);
        if arg == 0 as *llvm.LLVMOpaqueValue
        {
            # Get formal name
            let prm_han: *code.Handle =
                type_.parameters.get_ptr(i) as *code.Handle;
            let prm: *code.Parameter =
                prm_han._object as *code.Parameter;

            if prm.variadic {
                # Decrement size and break.
                argl.size = argl.size - 1;
                break;
            };

            # Report
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "missing required parameter '%s'",
                           prm.name.data());
            errors.end();
            error = true;
        };

        i = i + 1;
    }
    if error { return code.make_nil(); };

    # Build the `call` instruction.
    let val = llvm.LLVMBuildCall(
        g.irb, handle, argv, argl.size as uint32, "");

    # Dispose of dynamic memory.
    argl.dispose();

    if code.isnil(type_.return_type) {
        # Return nil.
        code.make_nil();
    } else {
        # Wrap and return the value.
        code.make_value(type_.return_type, code.VC_RVALUE, val);
    };
}

let call_default_ctor(g: *mut generator_.Generator, node: *ast.CallExpr,
                      scope: *mut code.Scope,
                      x: *code.Struct,
                      type_: *code.StructType): *code.Handle ->
{
    # We need to create a constant value of our structure type.

    # First we create and zero a list to hold the entire argument list.
    let mut argl: list.List = list.List.new(types.PTR);
    argl.reserve(type_.members.size);
    argl.size = type_.members.size;
    libc.memset(argl.elements as *int8, 0, (argl.size * argl.element_size) as int32);
    let argv: *mut *llvm.LLVMOpaqueValue =
        argl.elements as *llvm.LLVMOpaqueValue;

    # Iterate through each argument, build, and push them into
    # their appropriate position in the argument list.
    let mut i: int = 0;
    while i as uint < node.arguments.size()
    {
        # Get the specific argument.
        let anode: ast.Node = node.arguments.get(i);
        i = i + 1;
        let a: *ast.Argument = anode.unwrap() as *ast.Argument;

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
            let id: *ast.Ident = a.name.unwrap() as *ast.Ident;

            # Check for the existance of this argument.
            if not type_.member_map.contains(id.name.data() as str)
            {
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                               "unexpected keyword argument '%s'",
                               id.name.data());
                errors.end();
                return code.make_nil();
            };

            # Pull the named argument index.
            let phan: *code.Handle =
                type_.member_map.get_ptr(id.name.data() as str) as
                    *code.Handle;
            let pnode: *code.Member = phan._object as *code.Member;
            param_idx = pnode.index;

            # Check if we already have one of these.
            if *(argv + param_idx) != 0 as *llvm.LLVMOpaqueValue {
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                               "got multiple values for argument '%s'",
                               id.name.data());
                errors.end();
                return code.make_nil();
            };
        };

        # Ensure that we haven't run off the parameter list.
        if type_.members.size <= param_idx {
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                                "too many arguments in call");
            errors.end();
            return code.make_nil();
        };

        # Resolve the type of the argument expression.
        let param_typ: *code.Handle = code.type_of(
            type_.members.get_ptr(param_idx as int) as *code.Handle);
        let typ: *code.Handle = resolver.resolve_st(
            g, &a.expression, scope, param_typ);
        if code.isnil(typ) { return code.make_nil(); };

        # Build the argument expression node.
        let han: *code.Handle = builder.build(g, &a.expression, scope, typ);
        if code.isnil(han) { return code.make_nil(); };

        # Coerce this to a value.
        let val_han: *code.Handle = generator_def.to_value(
            *g, han, code.VC_RVALUE, false);

        # Cast the value to the target type.
        let cast_han: *code.Handle = generator_util.cast(
            *g, val_han, param_typ, false);
        if code.isnil(cast_han) { return code.make_nil(); };
        let cast_val: *code.Value = cast_han._object as *code.Value;

        # Emplace in the argument list.
        *(argv + param_idx) = cast_val.handle;

        # Dispose.
        code.dispose(val_han);
        code.dispose(cast_han);
    }

    # Check for missing arguments.
    i = 0;
    let mut error: bool = false;
    while i as uint < argl.size {
        let arg: *llvm.LLVMOpaqueValue = *(argv + i);
        if arg == 0 as *llvm.LLVMOpaqueValue
        {
            # Get formal name
            let prm_han: *code.Handle =
                type_.members.get_ptr(i) as *code.Handle;
            let prm: *code.Member =
                prm_han._object as *code.Member;

            # Do we have a "default" argument

            # Report
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "missing required parameter '%s'",
                           prm.name.data());
            errors.end();
            error = true;
        };

        i = i + 1;
    }
    if error { return code.make_nil(); };

    # We can only generate an initial "constant" structure for a
    # purely constant literal.
    # Collect indicies and values of non-constant members of the
    # literal.
    let mut nonconst_values: list.List = list.List.new(types.PTR);
    let mut nonconst_indicies: list.List = list.List.new(types.INT);
    i = 0;
    while i as uint < argl.size {
        let arg: *llvm.LLVMOpaqueValue = *(argv + i);
        i = i + 1;

        # Is this not some kind of "constant"?
        if llvm.LLVMIsConstant(arg) == 0 {
            # Yep; store and zero out the value.
            nonconst_indicies.push_int(i - 1);
            nonconst_values.push_ptr(arg as *int8);
            *(argv + (i - 1)) = llvm.LLVMGetUndef(llvm.LLVMTypeOf(arg));
        };
    }

    # Build the "call" instruction (and create the constant struct).
    let mut val: *llvm.LLVMOpaqueValue;
    val = llvm.LLVMConstNamedStruct(type_.handle, argv, argl.size as uint32);

    # Iterate through our non-constant values and push them in.
    i = 0;
    while i as uint < nonconst_indicies.size {
        let arg: *llvm.LLVMOpaqueValue = nonconst_values.get_ptr(i) as
            *llvm.LLVMOpaqueValue;
        let idx: int = nonconst_indicies.get_int(i);
        i = i + 1;

        # Build the `insertvalue` instruction.
        val = llvm.LLVMBuildInsertValue(
            g.irb, val, arg, idx as uint32, "");
    }

    # Dispose of dynamic memory.
    nonconst_values.dispose();
    nonconst_indicies.dispose();
    argl.dispose();

    # Wrap and return the value.
    code.make_value(x.type_, code.VC_RVALUE, val);
}

let call(g: *mut generator_.Generator, node: *ast.Node,
         scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.CallExpr = node.unwrap() as *ast.CallExpr;

    # Build the called expression.
    let type_: *code.Handle = resolver.resolve_s(g, &x.expression, scope);
    let expr: *code.Handle = builder.build(
        g, &x.expression, scope, type_);
    if code.isnil(expr) { return code.make_nil(); };

    # Pull out the handle and its type.
    if expr._tag == code.TAG_FUNCTION
    {
        let mut type_: *code.FunctionType;
        let fn_han: *code.Function = expr._object as *code.Function;
        type_ = fn_han.type_._object as *code.FunctionType;
        return call_function(g, x, scope, fn_han.handle, type_);
    }
    else if expr._tag == code.TAG_ATTACHED_FUNCTION
    {
        let mut type_: *code.FunctionType;
        let fn_han: *code.Function = expr._object as *code.Function;
        type_ = fn_han.type_._object as *code.FunctionType;
        return call_function(g, x, scope, fn_han.handle, type_);
    }
    else if expr._tag == code.TAG_LOCAL_SLOT
    {
        let slot: *code.LocalSlot = expr._object as *code.LocalSlot;
        let type_handle: *code.Handle = slot.type_;
        if type_handle._tag == code.TAG_FUNCTION_TYPE
        {
            let type_ = type_handle._object as *code.FunctionType;

            # Load the function handle from the function object.
            let handle: *llvm.LLVMOpaqueValue = llvm.LLVMBuildLoad(
                g.irb, slot.handle, "");

            # Call the function normally.
            return call_function(g, x, scope, handle, type_);
        };
        0;#0HACK
    }
    else if expr._tag == code.TAG_VALUE
    {
        let val: *code.Value = expr._object as *code.Value;
        let type_handle: *code.Handle = val.type_;
        if type_handle._tag == code.TAG_FUNCTION_TYPE
        {
            let type_ = type_handle._object as *code.FunctionType;

            # Load the function handle from the function object.
            let handle: *llvm.LLVMOpaqueValue = llvm.LLVMBuildLoad(
                g.irb, val.handle, "");

            # Call the function normally.
            return call_function(g, x, scope, handle, type_);
        };
    }
    else if expr._tag == code.TAG_EXTERN_FUNC
    {
        let mut type_: *code.FunctionType;
        let fn_han: *code.ExternFunction =
            expr._object as *code.ExternFunction;
        type_ = fn_han.type_._object as *code.FunctionType;

        # Ensure our external handle has been declared.
        # FIXME: This should be handled in a utility
        if fn_han.handle == 0 as *llvm.LLVMOpaqueValue
        {
            # Check for the function in the module.
            fn_han.handle = llvm.LLVMGetNamedFunction(g.mod, fn_han.name.data());
            if fn_han.handle == 0 as *llvm.LLVMOpaqueValue
            {
                # Add the function to the module.
                fn_han.handle = llvm.LLVMAddFunction(
                    g.mod, fn_han.name.data(), type_.handle);
            };
        };

        # Delegate off to `call_function`
        return call_function(
            g, x, scope, fn_han.handle, type_);
    }
    else if expr._tag == code.TAG_STRUCT
    {
        let mut type_: *code.StructType;
        let han: *code.Struct = expr._object as *code.Struct;
        type_ = han.type_._object as *code.StructType;
        return call_default_ctor(g, x, scope, han, type_);
    };

    # No idea how to handle this (shouldn't be able to get here).
    code.make_nil();
}

# Binary arithmetic
# -----------------------------------------------------------------------------
let arithmetic_b_operands(g: *mut generator_.Generator, node: *ast.Node,
                          scope: *mut code.Scope, target: *code.Handle):
    (*code.Handle, *code.Handle) ->
{
    let mut res: (*code.Handle, *code.Handle) = (code.make_nil(), code.make_nil());

    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Resolve each operand for its type.
    let lhs_ty: *code.Handle = resolver.resolve_st(g, &x.lhs, scope, target);
    let rhs_ty: *code.Handle = resolver.resolve_st(g, &x.rhs, scope, target);

    # Build each operand.
    let lhs: *code.Handle = builder.build(g, &x.lhs, scope, lhs_ty);
    let rhs: *code.Handle = builder.build(g, &x.rhs, scope, rhs_ty);
    if code.isnil(lhs) or code.isnil(rhs) { return res; };

    # Coerce the operands to values.
    let lhs_val_han: *code.Handle = generator_def.to_value(
        *g, lhs, code.VC_RVALUE, false);
    let rhs_val_han: *code.Handle = generator_def.to_value(
        *g, rhs, code.VC_RVALUE, false);
    if code.isnil(lhs_val_han) or code.isnil(rhs_val_han) { return res; };

    # Create a tuple result.
    res = (lhs_val_han, rhs_val_han);
    res;
}

# Logical [TAG_LOGICAL_AND, TAG_LOGICAL_OR]
# -----------------------------------------------------------------------------
let logical(g: *mut generator_.Generator, node: *ast.Node,
            scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Get the current basic block and resolve our current function handle.
    let cur_block: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMGetInsertBlock(g.irb);
    let cur_fn: *llvm.LLVMOpaqueValue = llvm.LLVMGetBasicBlockParent(
        cur_block);

    # Resolve each operand for its type.
    let lhs_ty: *code.Handle = resolver.resolve_st(g, &x.lhs, scope, target);
    let rhs_ty: *code.Handle = resolver.resolve_st(g, &x.rhs, scope, target);

    # Build the left operand.
    let lhs: *code.Handle = builder.build(g, &x.lhs, scope, lhs_ty);
    let lhs_val_han: *code.Handle = generator_def.to_value(
        *g, lhs, code.VC_RVALUE, false);
    let lhs_val: *code.Value = lhs_val_han._object as *code.Value;

    # Create the three neccessary basic blocks: then, else, merge.
    let mut then_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");
    let mut else_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");
    let mut merge_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");

    # Create the conditional branch.
    if node.tag == ast.TAG_LOGICAL_AND {
        llvm.LLVMBuildCondBr(g.irb, lhs_val.handle, then_b, else_b);
    } else {
        llvm.LLVMBuildCondBr(g.irb, lhs_val.handle, else_b, then_b);
    };

    # Switch to the `then` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, then_b);

    # Build the right operand.
    let rhs: *code.Handle = builder.build(g, &x.rhs, scope, rhs_ty);
    let rhs_val_han: *code.Handle = generator_def.to_value(
        *g, rhs, code.VC_RVALUE, false);
    let rhs_val: *code.Value = rhs_val_han._object as *code.Value;

    # Create a branch to the `merge` block.
    llvm.LLVMBuildBr(g.irb, merge_b);

    # Insert the `else` block after our current block.
    then_b = llvm.LLVMGetInsertBlock(g.irb);
    llvm.LLVMMoveBasicBlockAfter(else_b, then_b);

    # Switch to the `else` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, else_b);

    # Create a branch to the `merge` block.
    llvm.LLVMBuildBr(g.irb, merge_b);

    # Insert the `else` block after our current block.
    else_b = llvm.LLVMGetInsertBlock(g.irb);
    llvm.LLVMMoveBasicBlockAfter(merge_b, else_b);

    # Switch to the `merge` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, merge_b);

    # Create a `PHI` node.
    let type_han: *code.Type = target._object as *code.Type;
    let type_val: *llvm.LLVMOpaqueType = type_han.handle;
    let mut val: *llvm.LLVMOpaqueValue;
    let bool_val: *llvm.LLVMOpaqueValue = llvm.LLVMConstInt(
        type_val, 0 if node.tag == ast.TAG_LOGICAL_AND else 1, false);
    val = llvm.LLVMBuildPhi(g.irb, type_val, "");
    llvm.LLVMAddIncoming(val, &rhs_val.handle, &then_b, 1);
    llvm.LLVMAddIncoming(val, &bool_val, &else_b, 1);

    # Wrap and return the value.
    let han = code.make_value(target, code.VC_RVALUE, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);

    # Return our wrapped result.
    han;
}

# Logical Or [TAG_LOGICAL_OR]
# -----------------------------------------------------------------------------
let logical_or(g: *mut generator_.Generator, node: *ast.Node,
               scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Get the current basic block and resolve our current function handle.
    let cur_block: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMGetInsertBlock(g.irb);
    let cur_fn: *llvm.LLVMOpaqueValue = llvm.LLVMGetBasicBlockParent(
        cur_block);

    # Resolve each operand for its type.
    let lhs_ty: *code.Handle = resolver.resolve_st(g, &x.lhs, scope, target);
    let rhs_ty: *code.Handle = resolver.resolve_st(g, &x.rhs, scope, target);

    # Build the left operand.
    let lhs: *code.Handle = builder.build(g, &x.lhs, scope, lhs_ty);
    let lhs_val_han: *code.Handle = generator_def.to_value(
        *g, lhs, code.VC_RVALUE, false);
    let lhs_val: *code.Value = lhs_val_han._object as *code.Value;

    # Create the three neccessary basic blocks: then, else, merge.
    let then_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");
    let else_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");
    let merge_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");

    # Create the conditional branch.
    llvm.LLVMBuildCondBr(g.irb, lhs_val.handle, else_b, then_b);

    # Switch to the `then` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, then_b);

    # Build the right operand.
    let rhs: *code.Handle = builder.build(g, &x.rhs, scope, rhs_ty);
    let rhs_val_han: *code.Handle = generator_def.to_value(
        *g, rhs, code.VC_RVALUE, false);
    let rhs_val: *code.Value = rhs_val_han._object as *code.Value;

    # Create a branch to the `merge` block.
    llvm.LLVMBuildBr(g.irb, merge_b);

    # Switch to the `else` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, else_b);

    # Create a branch to the `merge` block.
    llvm.LLVMBuildBr(g.irb, merge_b);

    # Switch to the `merge` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, merge_b);

    # Create a `PHI` node.
    let type_han: *code.Type = target._object as *code.Type;
    let type_val: *llvm.LLVMOpaqueType = type_han.handle;
    let mut val: *llvm.LLVMOpaqueValue;
    let bool_val: *llvm.LLVMOpaqueValue = llvm.LLVMConstInt(
        type_val, 1, false);
    val = llvm.LLVMBuildPhi(g.irb, type_val, "");
    llvm.LLVMAddIncoming(val, &rhs_val.handle, &then_b, 1);
    llvm.LLVMAddIncoming(val, &bool_val, &else_b, 1);

    # Wrap and return the value.
    let han = code.make_value(target, code.VC_RVALUE, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);

    # Return our wrapped result.
    han;
}

# Relational [TAG_EQ, TAG_NE, TAG_LT, TAG_LE, TAG_GT, TAG_GE]
# -----------------------------------------------------------------------------
let relational(g: *mut generator_.Generator, node: *ast.Node,
               scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Build each operand.
    let mut lhs_val_han: *code.Handle;
    let mut rhs_val_han: *code.Handle;
    let tup = arithmetic_b_operands(
        g, node, scope, code.make_nil());
    (lhs_val_han, rhs_val_han) = tup;
    if code.isnil(lhs_val_han) or code.isnil(rhs_val_han) {
        # Return nil.
        return code.make_nil();
    };

    # Resolve our type.
    let type_: *code.Handle = resolvers.type_common(
        &x.lhs,
        code.type_of(lhs_val_han),
        &x.rhs,
        code.type_of(rhs_val_han));
    if code.isnil(type_) {
        # Return nil.
        return code.make_nil();
    };

    # Cast each operand to the target type.
    let lhs_han: *code.Handle = generator_util.cast(
        *g, lhs_val_han, type_, false);
    let rhs_han: *code.Handle = generator_util.cast(
        *g, rhs_val_han, type_, false);
    if code.isnil(lhs_han) { return code.make_nil(); };
    if code.isnil(rhs_han) { return code.make_nil(); };

    # Cast to values.
    let lhs_val: *code.Value = lhs_han._object as *code.Value;
    let rhs_val: *code.Value = rhs_han._object as *code.Value;

    # Get the common comparison opcode to use.
    let mut opc: int32 = -1;
    if      node.tag == ast.TAG_EQ { opc = 32; }
    else if node.tag == ast.TAG_NE { opc = 33; }
    else if node.tag == ast.TAG_GT { opc = 34; }
    else if node.tag == ast.TAG_GE { opc = 35; }
    else if node.tag == ast.TAG_LT { opc = 36; }
    else if node.tag == ast.TAG_LE { opc = 37; };

    # Build the comparison instruction.
    let mut val: *llvm.LLVMOpaqueValue;
    if type_._tag == code.TAG_INT_TYPE
            or type_._tag == code.TAG_BOOL_TYPE
            or type_._tag == code.TAG_CHAR_TYPE
    {
        # Switch to signed if neccessary.
        if node.tag != ast.TAG_EQ and node.tag != ast.TAG_NE {
            let typ: *code.IntegerType = type_._object as *code.IntegerType;
            if typ.signed {
                opc = opc + 4;
            };
        };

        # Build the `ICMP` instruction.
        val = llvm.LLVMBuildICmp(
            g.irb,
            opc,
            lhs_val.handle, rhs_val.handle, "");
    }
    else if type_._tag == code.TAG_FLOAT_TYPE
    {
        # Get the floating-point comparison opcode to use.
        if      node.tag == ast.TAG_EQ { opc = 1; }
        else if node.tag == ast.TAG_NE { opc = 6; }
        else if node.tag == ast.TAG_GT { opc = 2; }
        else if node.tag == ast.TAG_GE { opc = 3; }
        else if node.tag == ast.TAG_LT { opc = 4; }
        else if node.tag == ast.TAG_LE { opc = 5; };

        # Build the `FCMP` instruction.
        val = llvm.LLVMBuildFCmp(
            g.irb,
            opc,
            lhs_val.handle, rhs_val.handle, "");
    }
    else if type_._tag == code.TAG_POINTER_TYPE
    {
        # Retrieve our integral pointer type.
        let uintptr: *code.Handle = g.items.get_ptr("uint") as *code.Handle;
        let uintptr_ty: *code.Type = uintptr._object as *code.Type;

        # Convert both the left- and right-hand side expressions
        # to integral expressions.
        let mut lhs_int_val: *llvm.LLVMOpaqueValue;
        let mut rhs_int_val: *llvm.LLVMOpaqueValue;
        lhs_int_val = llvm.LLVMBuildPtrToInt(
            g.irb, lhs_val.handle, uintptr_ty.handle, "");
        rhs_int_val = llvm.LLVMBuildPtrToInt(
            g.irb, rhs_val.handle, uintptr_ty.handle, "");

        # Build the `ICMP` instruction.
        val = llvm.LLVMBuildICmp(
            g.irb,
            opc,
            lhs_int_val, rhs_int_val, "");
    }
    else if type_._tag == code.TAG_STR_TYPE
    {
        # Does 'strcoll' exist in the module.
        let mut strcoll_fn = llvm.LLVMGetNamedFunction(g.mod, "strcoll");
        if strcoll_fn == 0 as *llvm.LLVMOpaqueValue {
            # No; emplace it in the module.
            let arg_types = [llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0),
                             llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0)];
            let fn_type = llvm.LLVMFunctionType(
                llvm.LLVMInt32Type(), &arg_types[0], 2, 0);
            strcoll_fn = llvm.LLVMAddFunction(g.mod, "strcoll", fn_type);
        };

        # Build a `call` to strcoll with our operands.
        let args = [lhs_val.handle, rhs_val.handle];
        let tmp = llvm.LLVMBuildCall(g.irb, strcoll_fn, &args[0], 2, "");

        # Build an `icmp` according to our operation.
        if node.tag != ast.TAG_EQ and node.tag != ast.TAG_NE {
            opc = opc + 4;
        };
        let zero_val = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, false);
        val = llvm.LLVMBuildICmp(g.irb, opc, tmp, zero_val, "");
    };

    # Wrap and return the value.
    let han = code.make_value(target, code.VC_RVALUE, val);

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
let arithmetic_u(g: *mut generator_.Generator, node: *ast.Node,
                 scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.UnaryExpr = node.unwrap() as *ast.UnaryExpr;

    # Resolve the operand for its type.
    let operand_ty: *code.Handle = resolver.resolve_st(
        g, &x.operand, scope, target);

    # Build each operand.
    let operand_ty_han: *code.Type = operand_ty._object as *code.Type;
    let operand: *code.Handle = builder.build(
        g, &x.operand, scope, operand_ty);
    if code.isnil(operand) { return code.make_nil(); };

    # Coerce the operands to values.
    let operand_val_han: *code.Handle = generator_def.to_value(
        *g, operand, code.VC_RVALUE, false);
    if code.isnil(operand_val_han) { return code.make_nil(); };

    # Cast to values.
    let operand_val: *code.Value = operand_val_han._object as *code.Value;

    # Build the instruction.
    let mut val: *llvm.LLVMOpaqueValue = operand_val.handle;
    if target._tag == code.TAG_INT_TYPE {
        # Build the correct operation.
        if node.tag == ast.TAG_NUMERIC_NEGATE {
            # Build the `NEG` instruction.
            val = llvm.LLVMBuildNeg(
                g.irb,
                operand_val.handle, "");
        } else if node.tag == ast.TAG_BITNEG {
            # Build the `NOT` instruction.
            val = llvm.LLVMBuildNot(
                g.irb,
                operand_val.handle, "");
        };
    } else if target._tag == code.TAG_FLOAT_TYPE {
        # Build the correct operation.
        if node.tag == ast.TAG_NUMERIC_NEGATE {
            # Build the `NEG` instruction.
            val = llvm.LLVMBuildNeg(
                g.irb,
                operand_val.handle, "");
        };
    } else if target._tag == code.TAG_BOOL_TYPE {
        # Build the correct operation.
        if node.tag == ast.TAG_BITNEG or node.tag == ast.TAG_LOGICAL_NEGATE {
            # Build the `NOT` instruction.
            val = llvm.LLVMBuildNot(
                g.irb,
                operand_val.handle, "");
        };
    };

    # Wrap and return the value.
    let han = code.make_value(target, code.VC_RVALUE, val);

    # Dispose.
    code.dispose(operand_val_han);

    # Return our wrapped result.
    han;
}

# Binary Arithmetic [TAG_ADD, TAG_SUBTRACT, TAG_MULTIPLY,
#                    TAG_DIVIDE, TAG_MODULO, TAG_BITAND, TAG_BITOR, TAG_BITXOR]
# -----------------------------------------------------------------------------
let arithmetic_b(g: *mut generator_.Generator, node: *ast.Node,
                 scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Build each operand.
    let mut lhs_val_han: *code.Handle;
    let mut rhs_val_han: *code.Handle;
    let tup = arithmetic_b_operands(
        g, node, scope, code.make_nil());
    (lhs_val_han, rhs_val_han) = tup;
    if code.isnil(lhs_val_han) or code.isnil(rhs_val_han) {
        # Return nil.
        return code.make_nil();
    };

    # Build the instruction.
    let mut val: *llvm.LLVMOpaqueValue;
    if target._tag == code.TAG_INT_TYPE
    {
        # Pull out the types of the operands.
        let lhs_ty_han: *code.Handle = code.type_of(lhs_val_han);
        let rhs_ty_han: *code.Handle = code.type_of(rhs_val_han);

        # If both the LHS and RHS are pointers we are finding the
        # difference.
        if      rhs_ty_han._tag == code.TAG_POINTER_TYPE
            and lhs_ty_han._tag == code.TAG_POINTER_TYPE
        {
            # Cast to values.
            let lhs_val: *code.Value = lhs_val_han._object as *code.Value;
            let rhs_val: *code.Value = rhs_val_han._object as *code.Value;

            # Get the target type handle.
            let target_ty: *code.Type = target._object as *code.Type;

            # Convert both to integers.
            let mut lhs: *llvm.LLVMOpaqueValue;
            let mut rhs: *llvm.LLVMOpaqueValue;
            lhs = llvm.LLVMBuildPtrToInt(
                g.irb, lhs_val.handle, target_ty.handle, "");
            rhs = llvm.LLVMBuildPtrToInt(
                g.irb, rhs_val.handle, target_ty.handle, "");

            # Find the length.
            val = llvm.LLVMBuildSub(g.irb, lhs, rhs, "");

            # Get the size (in bytes) of the underlying type.
            let lhs_ty: *code.PointerType = lhs_ty_han._object as
                *code.PointerType;
            let size_han: *code.Handle =
                generator_util.build_sizeof(*g, lhs_ty.pointee);
            let size_val: *code.Value = size_han._object as *code.Value;

            # Perform an integral division to find the -number- of elements.
            val = llvm.LLVMBuildExactSDiv(
                g.irb, val, size_val.handle, "");
            0;
        }
        else
        {
            # Cast each operand to the target type.
            let lhs_han: *code.Handle = generator_util.cast(
                *g, lhs_val_han, target, false);
            let rhs_han: *code.Handle = generator_util.cast(
                *g, rhs_val_han, target, false);
            if code.isnil(lhs_han) { return code.make_nil(); };
            if code.isnil(rhs_han) { return code.make_nil(); };

            # Cast to values.
            let lhs_val: *code.Value = lhs_han._object as *code.Value;
            let rhs_val: *code.Value = rhs_han._object as *code.Value;

            # Get the internal type.
            let typ: *code.IntegerType = target._object as *code.IntegerType;

            # Build the correct operation.
            if node.tag == ast.TAG_ADD {
                # Build the `ADD` instruction.
                val = llvm.LLVMBuildAdd(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "");
            } else if node.tag == ast.TAG_SUBTRACT {
                # Build the `SUB` instruction.
                val = llvm.LLVMBuildSub(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "");
            } else if node.tag == ast.TAG_MULTIPLY {
                # Build the `MUL` instruction.
                val = llvm.LLVMBuildMul(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "");
            } else if node.tag == ast.TAG_DIVIDE
                   or node.tag == ast.TAG_INTEGER_DIVIDE {
                # Build the `DIV` instruction.
                if typ.signed {
                    val = llvm.LLVMBuildSDiv(
                        g.irb,
                        lhs_val.handle, rhs_val.handle, "");
                } else {
                    val = llvm.LLVMBuildUDiv(
                        g.irb,
                        lhs_val.handle, rhs_val.handle, "");
                };
            } else if node.tag == ast.TAG_MODULO {
                # Build the `MOD` instruction.
                if typ.signed {
                    val = llvm.LLVMBuildSRem(
                        g.irb,
                        lhs_val.handle, rhs_val.handle, "");
                } else {
                    val = llvm.LLVMBuildURem(
                        g.irb,
                        lhs_val.handle, rhs_val.handle, "");
                };
            } else if node.tag == ast.TAG_BITAND {
                # Build the `AND` instruction.
                val = llvm.LLVMBuildAnd(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "");
            } else if node.tag == ast.TAG_BITOR {
                # Build the `OR` instruction.
                val = llvm.LLVMBuildOr(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "");
            } else if node.tag == ast.TAG_BITXOR {
                # Build the `XOR` instruction.
                val = llvm.LLVMBuildXor(
                    g.irb,
                    lhs_val.handle, rhs_val.handle, "");
            };

            # Dispose.
            code.dispose(lhs_han);
            code.dispose(rhs_han);
        };
        0; #HACK!
    }
    else if target._tag == code.TAG_FLOAT_TYPE
    {
        # Cast each operand to the target type.
        let lhs_han: *code.Handle = generator_util.cast(
            *g, lhs_val_han, target, false);
        let rhs_han: *code.Handle = generator_util.cast(
            *g, rhs_val_han, target, false);
        if code.isnil(lhs_han) { return code.make_nil(); };
        if code.isnil(rhs_han) { return code.make_nil(); };

        # Cast to values.
        let lhs_val: *code.Value = lhs_han._object as *code.Value;
        let rhs_val: *code.Value = rhs_han._object as *code.Value;

        # Build the correct operation.
        if node.tag == ast.TAG_ADD {
            # Build the `ADD` instruction.
            val = llvm.LLVMBuildFAdd(
                g.irb,
                lhs_val.handle, rhs_val.handle, "");
        } else if node.tag == ast.TAG_SUBTRACT {
            # Build the `SUB` instruction.
            val = llvm.LLVMBuildFSub(
                g.irb,
                lhs_val.handle, rhs_val.handle, "");
        } else if node.tag == ast.TAG_MULTIPLY {
            # Build the `MUL` instruction.
            val = llvm.LLVMBuildFMul(
                g.irb,
                lhs_val.handle, rhs_val.handle, "");
        } else if node.tag == ast.TAG_DIVIDE or node.tag == ast.TAG_INTEGER_DIVIDE {
            # Build the `DIV` instruction.
            val = llvm.LLVMBuildFDiv(
                g.irb,
                lhs_val.handle, rhs_val.handle, "");
        } else if node.tag == ast.TAG_MODULO {
            # Build the `MOD` instruction.
            val = llvm.LLVMBuildFRem(
                g.irb,
                lhs_val.handle, rhs_val.handle, "");
        };

        # Dispose.
        code.dispose(lhs_han);
        code.dispose(rhs_han);
    }
    else if target._tag == code.TAG_BOOL_TYPE
    {
        # Cast to values.
        let lhs_val: *code.Value = lhs_val_han._object as *code.Value;
        let rhs_val: *code.Value = rhs_val_han._object as *code.Value;

        if node.tag == ast.TAG_BITAND {
            # Build the `AND` instruction.
            val = llvm.LLVMBuildAnd(
                g.irb,
                lhs_val.handle, rhs_val.handle, "");
        } else if node.tag == ast.TAG_BITOR {
            # Build the `OR` instruction.
            val = llvm.LLVMBuildOr(
                g.irb,
                lhs_val.handle, rhs_val.handle, "");
        } else if node.tag == ast.TAG_BITXOR {
            # Build the `XOR` instruction.
            val = llvm.LLVMBuildXor(
                g.irb,
                lhs_val.handle, rhs_val.handle, "");
        };
    }
    else if target._tag == code.TAG_POINTER_TYPE
    {
        # Cast to values.
        let lhs_val: *code.Value = lhs_val_han._object as *code.Value;
        let rhs_val: *code.Value = rhs_val_han._object as *code.Value;

        # Pull out the types of the operands.
        let lhs_ty_han: *code.Handle = code.type_of(lhs_val_han);
        let rhs_ty_han: *code.Handle = code.type_of(rhs_val_han);

        # A binary expression with a target of a pointer type could
        # be a addition or subtraction with an integral type (
        # moving the pointer) or it could be two pointer types (difference
        # to find the size).
        if node.tag == ast.TAG_ADD
        {
            if lhs_ty_han._tag == code.TAG_POINTER_TYPE
            {
                # Build the pointer offset access.
                val = llvm.LLVMBuildGEP(
                    g.irb, lhs_val.handle, &rhs_val.handle, 1,
                    "");
            }
            else if rhs_ty_han._tag == code.TAG_POINTER_TYPE
            {
                # Build the pointer offset access.
                val = llvm.LLVMBuildGEP(
                    g.irb, rhs_val.handle, &lhs_val.handle, 1,
                    "");
            };
        }
        else if node.tag == ast.TAG_SUBTRACT
        {
            if      lhs_ty_han._tag == code.TAG_POINTER_TYPE
                and rhs_ty_han._tag == code.TAG_INT_TYPE
            {
                # Negate the integer.
                let rhs = llvm.LLVMBuildNeg(g.irb, rhs_val.handle, "");

                # Build the pointer offset access.
                val = llvm.LLVMBuildGEP(
                    g.irb, lhs_val.handle, &rhs, 1,
                    "");
            }
            else if rhs_ty_han._tag == code.TAG_POINTER_TYPE
                and lhs_ty_han._tag == code.TAG_INT_TYPE
            {
                # Negate the integer.
                let lhs = llvm.LLVMBuildNeg(g.irb, lhs_val.handle, "");

                # Build the pointer offset access.
                val = llvm.LLVMBuildGEP(
                    g.irb, rhs_val.handle, &lhs, 1,
                    "");
            };
        };
    };

    # Wrap and return the value.
    let han = code.make_value(target, code.VC_RVALUE, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);

    # Return our wrapped result.
    han;
}

# Integer Divide [TAG_INTEGER_DIVIDE]
# -----------------------------------------------------------------------------
let integer_divide(g: *mut generator_.Generator, node: *ast.Node,
                   scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Perform a normal division.
    let han = arithmetic_b(g, node, scope, target);

    # FIXME: Perform a `floor` on the result.

    # Return the result.
    han;
}

# Return [TAG_RETURN]
# -----------------------------------------------------------------------------
let return_(g: *mut generator_.Generator, node: *ast.Node,
            scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the "ploymorphic" node to its proper type.
    let x: *ast.ReturnExpr = node.unwrap() as *ast.ReturnExpr;

    # Get the return type of the current function.
    let cur_fn_type: *code.FunctionType =
        g.current_function.type_._object as *code.FunctionType;
    let target_type: *code.Handle = cur_fn_type.return_type;

    # Generate a handle for the expression (if we have one.)
    if not ast.isnull(x.expression) {
        # Resolve the type of the expression.
        let type_: *code.Handle = resolver.resolve_st(
            g, &x.expression, scope, target_type);

        # Build the expression.
        let expr: *code.Handle = builder.build(
            g, &x.expression, scope, type_);
        if code.isnil(expr) { return code.make_nil(); };

        # Coerce the expression to a value.
        let val_han: *code.Handle = generator_def.to_value(
            *g, expr, code.VC_RVALUE, false);
        let val: *code.Value = val_han._object as *code.Value;

        # Create the `RET` instruction.
        llvm.LLVMBuildRet(g.irb, val.handle);

        # Dispose.
        code.dispose(val_han);
    } else {
        # Create the void `RET` instruction.
        llvm.LLVMBuildRetVoid(g.irb);
        0;  #HACK
    };

    # Nothing is forwarded from a `return`.
    code.make_nil();
}

# Assignment [TAG_ASSIGN]
# -----------------------------------------------------------------------------
let assign(g: *mut generator_.Generator, node: *ast.Node,
           scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the "ploymorphic" node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Resolve each operand for its type.
    let lhs_ty: *code.Handle = resolver.resolve_st(g, &x.lhs, scope, target);
    let rhs_ty: *code.Handle = resolver.resolve_st(g, &x.rhs, scope, target);
    if code.isnil(lhs_ty) or code.isnil(rhs_ty) { return code.make_nil(); };

    # Build each operand.
    let lhs: *code.Handle = builder.build(g, &x.lhs, scope, lhs_ty);
    let rhs: *code.Handle = builder.build(g, &x.rhs, scope, rhs_ty);
    if code.isnil(lhs) or code.isnil(rhs) { return code.make_nil(); };

    # Run the assignment operation.
    generator_def.assign(*g, target, lhs, rhs);

    # Return the RHS.
    rhs;
}

# Conditional Expression [TAG_CONDITIONAL]
# -----------------------------------------------------------------------------
let conditional(g: *mut generator_.Generator, node: *ast.Node,
                scope: *code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.ConditionalExpr = node.unwrap() as *ast.ConditionalExpr;

    # Build the condition.
    let mut cond_han = builder.build(
        g, &x.condition, scope, g.items.get_ptr("bool") as *code.Handle);
    if code.isnil(cond_han) { return code.make_nil(); };
    let cond_val_han: *code.Handle = generator_def.to_value(
        (*g), cond_han, code.VC_RVALUE, false);
    let cond_val: *code.Value = cond_val_han._object as *code.Value;
    if code.isnil(cond_val_han) { return code.make_nil(); };

    # Get the current basic block and resolve our current function handle.
    let cur_block: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMGetInsertBlock(g.irb);
    let cur_fn: *llvm.LLVMOpaqueValue = llvm.LLVMGetBasicBlockParent(
        cur_block);

    # Create the three neccessary basic blocks: then, else, merge.
    let mut then_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");
    let mut else_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");
    let mut merge_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
        cur_fn, "");

    # Create the conditional branch.
    llvm.LLVMBuildCondBr(g.irb, cond_val.handle, then_b, else_b);

    # Switch to the `then` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, then_b);

    # Build the `lhs` operand.
    let lhs: *code.Handle = builder.build(g, &x.lhs, scope, target);
    if code.isnil(lhs) { return code.make_nil(); };
    let lhs_val_han: *code.Handle = generator_def.to_value(
        *g, lhs, 0, false);
    if code.isnil(lhs_val_han) { return code.make_nil(); };
    let lhs_han: *code.Handle = generator_util.cast(
        *g, lhs_val_han, target, false);
    if code.isnil(lhs_han) { return code.make_nil(); };
    let lhs_val: *code.Value = lhs_han._object as *code.Value;

    # Add an unconditional branch to the `merge` block.
    llvm.LLVMBuildBr(g.irb, merge_b);

    # Switch to the `else` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, else_b);

    # Build the `rhs` operand.
    let rhs: *code.Handle = builder.build(g, &x.rhs, scope ,target);
    if code.isnil(rhs) { return code.make_nil(); };
    let rhs_val_han: *code.Handle = generator_def.to_value(
        *g, rhs,
        (+code.VC_RVALUE if lhs_val.category == code.VC_RVALUE else 0),
        false);
    if code.isnil(rhs_val_han) { return code.make_nil(); };
    let rhs_han: *code.Handle = generator_util.cast(
        *g, rhs_val_han, target, false);
    let rhs_val: *code.Value = rhs_han._object as *code.Value;

    # Add an unconditional branch to the `merge` block.
    llvm.LLVMBuildBr(g.irb, merge_b);

    # Switch to the `merge` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, merge_b);

    # Create a `PHI` node.
    let type_han: *code.Type = target._object as *code.Type;
    let mut type_val: *llvm.LLVMOpaqueType = type_han.handle;
    if rhs_val.category == code.VC_LVALUE {
        type_val = llvm.LLVMTypeOf(rhs_val.handle);
    };
    let val = llvm.LLVMBuildPhi(g.irb, type_val, "");
    llvm.LLVMAddIncoming(val, &lhs_val.handle, &then_b, 1);
    llvm.LLVMAddIncoming(val, &rhs_val.handle, &else_b, 1);

    # Wrap and return the value.
    let han = code.make_value(target, rhs_val.category, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Block
# -----------------------------------------------------------------------------
let block(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.Block = node.unwrap() as *ast.Block;

    # Build each node in the branch.
    let mut j: int = 0;
    let mut res: *code.Handle = code.make_nil();
    while j as uint < x.nodes.size() {
        # Resolve this node.
        let n: ast.Node = x.nodes.get(j);
        j = j + 1;

        # Resolve the type of the node.
        let cur_count: uint = errors.count;
        let typ: *code.Handle = resolver.resolve_st(
            g, &n, scope, target);
        if cur_count < errors.count { continue; };

        # Build the node.
        let han: *code.Handle = builder.build(g, &n, scope, typ);
        if not code.isnil(han) {
            if j as uint == x.nodes.size() {
                let val_han: *code.Handle = generator_def.to_value(
                    *g, han, code.VC_RVALUE, false);
                res = val_han;
            };
        };
    }

    # Return the final result.
    res;
}

# Selection [TAG_SELECT]
# -----------------------------------------------------------------------------
let select(g: *mut generator_.Generator, node: *ast.Node,
           scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.SelectExpr = node.unwrap() as *ast.SelectExpr;
    let mut has_value: bool = target._tag != code.TAG_VOID_TYPE;

    # Get the type target for each node.
    let mut type_target: *code.Handle = target;
    if type_target._tag == code.TAG_VOID_TYPE {
        type_target = code.make_nil();
    };

    # Get the current basic block and resolve our current function handle.
    let cur_block: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMGetInsertBlock(g.irb);
    let cur_fn: *llvm.LLVMOpaqueValue = llvm.LLVMGetBasicBlockParent(
        cur_block);

    # Iterate through each branch in the select statement.
    # Generate each if/elif block chain until we get to the last branch.
    let mut i: int = 0;
    let mut values: list.List = list.List.new(types.PTR);
    let mut blocks: list.List = list.List.new(types.PTR);
    let bool_ty: *code.Handle = g.items.get_ptr("bool") as *code.Handle;
    while i as uint < x.branches.size() {
        let brn: ast.Node = x.branches.get(i);
        let br: *ast.SelectBranch = brn.unwrap() as *ast.SelectBranch;
        let blk_node: ast.Node = br.block;
        let blk: *ast.Block = blk_node.unwrap() as *ast.Block;

        # The last branch (else) is signaled by having no condition.
        if ast.isnull(br.condition) { break; };

        # Build the condition.
        let cond_han = builder.build(g, &br.condition, scope, bool_ty);
        if code.isnil(cond_han) { return code.make_nil(); };
        let cond_val_han: *code.Handle = generator_def.to_value(
            *g, cond_han, code.VC_RVALUE, false);
        let cond_val: *code.Value = cond_val_han._object as *code.Value;
        if code.isnil(cond_val_han) { return code.make_nil(); };

        # Create and append the `then` block.
        let mut then_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
            cur_fn, "");

        # Create a `next` block.
        let mut next_b: *llvm.LLVMOpaqueBasicBlock = llvm.LLVMAppendBasicBlock(
            cur_fn, "");

        # Insert the `conditional branch` for this branch.
        llvm.LLVMBuildCondBr(g.irb, cond_val.handle, then_b, next_b);

        # Switch to the `then` block.
        llvm.LLVMPositionBuilderAtEnd(g.irb, then_b);

        # Build each node in the branch.
        let blk_val_han: *code.Handle = block(
            g, &blk_node, scope, type_target);

        # If we are not terminated ...
        if not generator_util.is_terminated(llvm.LLVMGetInsertBlock(g.irb))
        {
            # And if we are expecting a value ...
            if has_value {
                # Cast the block value to our target type.
                let val_han: *code.Handle = generator_def.to_value(
                    *g, blk_val_han, code.VC_RVALUE, false);
                let cast_han: *code.Handle = generator_util.cast(
                    *g, val_han, type_target, false);
                if code.isnil(cast_han) { return code.make_nil(); };
                let val: *code.Value = cast_han._object as *code.Value;

                # Update our value list.
                values.push_ptr(val.handle as *int8);
            };
        }
        else if has_value {
            # Push an undefined value.
            let type_target_: *code.Type = type_target._object as *code.Type;
            let undef: *llvm.LLVMOpaqueValue = llvm.LLVMGetUndef(
                type_target_.handle);
            values.push_ptr(undef as *int8);
        };

        # Update the branch list.
        blocks.push_ptr(llvm.LLVMGetInsertBlock(g.irb) as *int8);

        # Insert the `next` block after our current block.
        llvm.LLVMMoveBasicBlockAfter(next_b, llvm.LLVMGetInsertBlock(g.irb));

        # Replace the outer-block with our new "merge" block.
        llvm.LLVMPositionBuilderAtEnd(g.irb, next_b);

        # Increment branch iterator.
        i = i + 1;
    }

    # Use the last elided block for our final "else" block.
    let mut merge_b: *llvm.LLVMOpaqueBasicBlock;
    if i as uint < x.branches.size() {
        let brn: ast.Node = x.branches.get(-1);
        let br: *ast.SelectBranch = brn.unwrap() as *ast.SelectBranch;

        # Build each node in the branch.
        let blk_val_han: *code.Handle = block(
            g, &br.block, scope, type_target);

        # If we are not terminated ...
        if not generator_util.is_terminated(llvm.LLVMGetInsertBlock(g.irb))
        {
            # And if we are expecting a value ...
            if has_value {
                # Cast the block value to our target type.
                let val_han: *code.Handle = generator_def.to_value(
                    *g, blk_val_han, code.VC_RVALUE, false);
                let cast_han: *code.Handle = generator_util.cast(
                    *g, val_han, type_target, false);
                if code.isnil(cast_han) { return code.make_nil(); };
                let val: *code.Value = cast_han._object as *code.Value;

                # Update our value list.
                values.push_ptr(val.handle as *int8);
            };
        }
        else if has_value {
            # Push an undefined value.
            let type_target_: *code.Type = type_target._object as *code.Type;
            let undef: *llvm.LLVMOpaqueValue = llvm.LLVMGetUndef(
                type_target_.handle);
            values.push_ptr(undef as *int8);
        };

        # Update the branch list.
        blocks.push_ptr(llvm.LLVMGetInsertBlock(g.irb) as *int8);

        # Create the last "merge" block.
        merge_b = llvm.LLVMAppendBasicBlock(cur_fn, "");
    } else {
        # There is no else block; use it as a merge block.
        merge_b = llvm.LLVMGetLastBasicBlock(cur_fn);
    };

    # Iterate through the established branches and have them return to
    # the "merge" block (if they are not otherwise terminated).
    i = 0;
    while i as uint < blocks.size {
        let bb: *llvm.LLVMOpaqueBasicBlock =
            blocks.get_ptr(i) as *llvm.LLVMOpaqueBasicBlock;
        i = i + 1;

        # Has this been terminated?
        if not generator_util.is_terminated(bb)
        {
            # No; add the branch.
            # Set the insertion point.
            llvm.LLVMPositionBuilderAtEnd(g.irb, bb);

            # Insert the non-conditional branch.
            llvm.LLVMBuildBr(g.irb, merge_b);
        };
    }

    # Re-establish our insertion point.
    llvm.LLVMPositionBuilderAtEnd(g.irb, merge_b);

    if values.size > 0 {
        # Insert the PHI node corresponding to the built values.
        let type_han: *code.Type = type_target._object as *code.Type;
        let mut val = llvm.LLVMBuildPhi(g.irb, type_han.handle, "");
        llvm.LLVMAddIncoming(
            val,
            values.elements as *llvm.LLVMOpaqueValue,
            blocks.elements as *llvm.LLVMOpaqueBasicBlock,
            values.size as uint32);

        # Wrap and return the value.
        let mut han = code.make_value(type_target, code.VC_RVALUE, val);

        # Dispose.
        blocks.dispose();
        values.dispose();

        # Wrap and return the PHI.
        return han;
    };# else {
        # Dispose.
        blocks.dispose();
        values.dispose();

        # Return nil.
        code.make_nil();
    # };
}

# Address Of [TAG_ADDRESS_OF]
# -----------------------------------------------------------------------------
let address_of(g: *mut generator_.Generator, node: *ast.Node,
               scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.AddressOfExpr = node.unwrap() as *ast.AddressOfExpr;

    # Resolve the operand for its type.
    let operand_ty: *code.Handle = resolver.resolve_s(g, &x.operand, scope);

    # Build each operand.
    let operand_ty_han: *code.Type = operand_ty._object as *code.Type;
    let operand: *code.Handle = builder.build(
        g, &x.operand, scope, operand_ty);
    if code.isnil(operand) { return code.make_nil(); };

    # Coerce the operands to values.
    let operand_val_han: *code.Handle = generator_def.to_value(
        *g, operand, code.VC_LVALUE, false);
    if code.isnil(operand_val_han) { return code.make_nil(); };

    # Cast to values.
    let operand_val: *code.Value = operand_val_han._object as *code.Value;

    # If we are dealing with a reference; load its value
    let mut val: *llvm.LLVMOpaqueValue = operand_val.handle;
    if operand_ty._tag == code.TAG_REFERENCE_TYPE
    {
        val = llvm.LLVMBuildLoad(g.irb, val, "");
    };

    # Wrap and return the value (the direct address).
    let han = code.make_value(target, code.VC_RVALUE, val);

    # Dispose.
    code.dispose(operand_val_han);

    # Return our wrapped result.
    han;
}

# Dereference [TAG_DEREF]
# -----------------------------------------------------------------------------
let dereference(g: *mut generator_.Generator, node: *ast.Node,
                scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.UnaryExpr = node.unwrap() as *ast.UnaryExpr;

    # Resolve the operand for its type.
    let operand_ty: *code.Handle = resolver.resolve_s(g, &x.operand, scope);

    # Grab the "pointee".
    let operand_ptr_ty = operand_ty._object as *code.PointerType;

    # Build the operand.
    let operand_ty_han: *code.Type = operand_ty._object as *code.Type;
    let operand: *code.Handle = builder.build(
        g, &x.operand, scope, operand_ty);
    if code.isnil(operand) { return code.make_nil(); };

    # Coerce the operand to values.
    let operand_val_han: *code.Handle = generator_def.to_value(
        *g, operand, code.VC_RVALUE, false);
    if code.isnil(operand_val_han) { return code.make_nil(); };

    # Cast to value.
    let operand_val: *code.Value = operand_val_han._object as *code.Value;

    # Wrap and return the value (the direct address).
    let han = code.make_value(operand_ptr_ty.pointee, code.VC_LVALUE,
                              operand_val.handle);

    # Dispose.
    code.dispose(operand_val_han);

    # Return our wrapped result.
    han;
}

# Cast [TAG_CAST]
# -----------------------------------------------------------------------------
let cast(g: *mut generator_.Generator, node: *ast.Node,
         scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.BinaryExpr = node.unwrap() as *ast.BinaryExpr;

    # Resolve the operand for its type.
    let operand_ty: *code.Handle = resolver.resolve_s(g, &x.lhs, scope);

    # Build each operand.
    let operand_ty_han: *code.Type = operand_ty._object as *code.Type;
    let operand: *code.Handle = builder.build(
        g, &x.lhs, scope, operand_ty);
    if code.isnil(operand) { return code.make_nil(); };

    # Coerce the operands to values.
    let operand_val_han: *code.Handle = generator_def.to_value(
        *g, operand, code.VC_RVALUE, false);
    if code.isnil(operand_val_han) { return code.make_nil(); };

    # Perform the cast.
    let cast_han: *code.Handle = generator_util.cast(
        *g, operand_val_han, target, true);
    if code.isnil(cast_han) { return code.make_nil(); };

    # Get the value.
    let operand_val: *code.Value = cast_han._object as *code.Value;

    # Wrap and return the value (the direct address).
    let han = code.make_value(target, code.VC_RVALUE, operand_val.handle);

    # Dispose.
    code.dispose(operand_val_han);
    code.dispose(cast_han);

    # Return our wrapped result.
    han;
}

# Loop [TAG_LOOP]
# -----------------------------------------------------------------------------
let loop_(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x = node.unwrap() as *ast.Loop;

    # Get the current basic block and resolve our current function handle.
    let cur_block = llvm.LLVMGetInsertBlock(g.irb);
    let cur_fn = llvm.LLVMGetBasicBlockParent(cur_block);

    # Create and append the `condition` block.
    let mut cond_b = llvm.LLVMAppendBasicBlock(cur_fn, "");

    # Create and append the `merge` block.
    let mut merge_b = llvm.LLVMAppendBasicBlock(cur_fn, "");

    # Insert the `branch` for this block.
    llvm.LLVMBuildBr(g.irb, cond_b);

    # Switch to the `condition` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, cond_b);

    # Do we have a condition to generate ...
    let mut loop_b: *llvm.LLVMOpaqueBasicBlock;
    if not ast.isnull(x.condition)
    {
        # Create and append the `loop` block.
        loop_b = llvm.LLVMAppendBasicBlock(cur_fn, "");

        # Yes; build the condition.
        let bool_ty = g.items.get_ptr("bool") as *code.Handle;
        let cond_han = builder.build(g, &x.condition, scope, bool_ty);
        if code.isnil(cond_han) { return code.make_nil(); };
        let cond_val_han = generator_def.to_value(
            *g, cond_han, code.VC_RVALUE, false);
        let cond_val = cond_val_han._object as *code.Value;
        if code.isnil(cond_val_han) { return code.make_nil(); };

        # Insert the `conditional branch` for this branch.
        llvm.LLVMBuildCondBr(g.irb, cond_val.handle, loop_b, merge_b);
        0;  # HACK
    }
    else
    {
        # Nope; the loop block is the condition block.
        loop_b = cond_b;
        0;  # HACK
    };

    # Move the `loop` block after our current block.
    llvm.LLVMMoveBasicBlockAfter(loop_b, llvm.LLVMGetInsertBlock(g.irb));

    # Switch to the `loop` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, loop_b);

    # Push our "loop" onto the loop stack.
    let mut loop_: generator_.Loop;
    loop_.break_ = merge_b;
    loop_.continue_ = cond_b;
    g.loops.push(&loop_ as *int8);

    # Build each node in the branch.
    block(g, &x.block, scope, code.make_nil());

    # Pop our "loop" from the loop stack.
    g.loops.erase(-1);

    # Update our block reference.
    loop_b = llvm.LLVMGetInsertBlock(g.irb);

    # If our loop has not been terminated we need to terminate
    # with a branch back to the condition block.
    if not generator_util.is_terminated(loop_b) {
        llvm.LLVMBuildBr(g.irb, cond_b);
    };

    # Move the `merge` block after our current loop block.
    llvm.LLVMMoveBasicBlockAfter(merge_b, llvm.LLVMGetInsertBlock(g.irb));

    # Switch to the `merge` block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, merge_b);

    # Return nil (void).
    code.make_nil();
}

# Break [TAG_BREAK]
# -----------------------------------------------------------------------------
let break_(g: *mut generator_.Generator, node: *ast.Node,
           scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Are we in a loop?
    if g.loops.size == 0
    {
        # No; error and bail.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "'break' statement not in loop statement");
        errors.end();
        return code.make_nil();
    };

    # Get the top-most loop.
    let loop_: *generator_.Loop = g.loops.get(-1) as *generator_.Loop;

    # Build a `branch` to the condition block of the top-most loop.
    llvm.LLVMBuildBr(g.irb, loop_.break_);

    # Return nil (void).
    code.make_nil();
}

# Continue [TAG_CONTINUE]
# -----------------------------------------------------------------------------
let continue_(g: *mut generator_.Generator, node: *ast.Node,
              scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Are we in a loop?
    if g.loops.size == 0
    {
        # No; error and bail.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "'continue' statement not in loop statement");
        errors.end();
        return code.make_nil();
    };

    # Get the top-most loop.
    let loop_: *generator_.Loop = g.loops.get(-1) as *generator_.Loop;

    # Build a `branch` to the merge block of the top-most loop.
    llvm.LLVMBuildBr(g.irb, loop_.continue_);

    # Return nil (void).
    code.make_nil();
}

# Index Expression [TAG_INDEX]
# -----------------------------------------------------------------------------
let index(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.IndexExpr = node.unwrap() as *ast.IndexExpr;

    # Resolve the operand for its type.
    let expr_ty: *code.Handle = resolver.resolve_s(g, &x.expression, scope);
    let sub_ty: *code.Handle = resolver.resolve_s(g, &x.subscript, scope);

    # Build each operand.
    let expr: *code.Handle = builder.build(g, &x.expression, scope, expr_ty);
    let sub: *code.Handle = builder.build(g, &x.subscript, scope, sub_ty);
    if code.isnil(expr) { return code.make_nil(); };
    if code.isnil(sub) { return code.make_nil(); };

    # Coerce the operands to values.
    let expr_val_han: *code.Handle = generator_def.to_value(
        *g, expr, code.VC_RVALUE, false);
    let sub_val_han: *code.Handle = generator_def.to_value(
        *g, sub, code.VC_RVALUE, false);
    if code.isnil(expr_val_han) { return code.make_nil(); };
    if code.isnil(sub_val_han) { return code.make_nil(); };

    # Cast to values.
    let expr_val: *code.Value = expr_val_han._object as *code.Value;
    let sub_val: *code.Value = sub_val_han._object as *code.Value;

    # Build an index list.
    let mut indicies: list.List = list.List.new(types.PTR);
    indicies.reserve(2);
    let mut idxs: **llvm.LLVMOpaqueValue =
        indicies.elements as **llvm.LLVMOpaqueValue;
    let zero_val: *llvm.LLVMOpaqueValue =
        llvm.LLVMConstInt(llvm.LLVMTypeOf(sub_val.handle), 0, false);
    (*(idxs + 0)) = zero_val;
    (*(idxs + 1)) = sub_val.handle;

    # Build the `GEP` instruction.
    let val = llvm.LLVMBuildInBoundsGEP(
        g.irb, expr_val.handle,
        idxs, 2, "");

    # Wrap and return the value (the direct address).
    let han = code.make_value(target, code.VC_LVALUE, val);

    # Dispose.
    code.dispose(expr_val_han);
    code.dispose(sub_val_han);
    indicies.dispose();

    # Return our wrapped result.
    han;
}

# Array [TAG_ARRAY]
# -----------------------------------------------------------------------------
let array(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.ArrayExpr = node.unwrap() as *ast.ArrayExpr;

    # Get the type of the target expression.
    # FIXME: Resolve our own type.
    let array_type: *code.ArrayType = target._object as *code.ArrayType;

    # Iterate and build each element in the array.
    let mut valuel: list.List = list.List.new(types.PTR);
    valuel.reserve(x.nodes.size());
    valuel.size = x.nodes.size();
    let values: **llvm.LLVMOpaqueValue = valuel.elements as
        **llvm.LLVMOpaqueValue;
    let mut i: int = 0;
    while i as uint < x.nodes.size()
    {
        # Get the specific element.
        let enode: ast.Node = x.nodes.get(i);

        # Build the argument expression node.
        let han: *code.Handle = builder.build(
            g, &enode, scope, array_type.element);
        if code.isnil(han) { return code.make_nil(); };

        # Coerce this to a value.
        let val_han: *code.Handle = generator_def.to_value(
            *g, han, code.VC_RVALUE, false);

        # Cast the value to the target type.
        let cast_han: *code.Handle = generator_util.cast(
            *g, val_han, array_type.element, false);
        if code.isnil(cast_han) { return code.make_nil(); };
        let cast_val: *code.Value = cast_han._object as *code.Value;

        # Emplace in the argument list.
        *(values + i) =  cast_val.handle;

        # Advance forward.
        i = i + 1;
    }

    # We can only generate an initial "constant" structure for a
    # purely constant literal.
    # Collect indicies and values of non-constant members of the
    # literal.
    let el_type_han: *code.Handle = array_type.element as *code.Handle;
    let el_type: *code.Type = el_type_han._object as *code.Type;
    let mut nonconst_values: list.List = list.List.new(types.PTR);
    let mut nonconst_indicies: list.List = list.List.new(types.INT);
    i = 0;
    while i as uint < valuel.size {
        let arg: *llvm.LLVMOpaqueValue = *(values + i);
        i = i + 1;

        # Is this not some kind of "constant"?
        if llvm.LLVMIsConstant(arg) == 0 {
            # Yep; store and zero out the value.
            nonconst_indicies.push_int(i - 1);
            nonconst_values.push_ptr(arg as *int8);
            *(values + (i - 1)) = llvm.LLVMGetUndef(el_type.handle);
        };
    }

    # Build the `array` instruction (and create the constant array).
    let mut val: *llvm.LLVMOpaqueValue;
    val = llvm.LLVMConstArray(
        generator_util.alter_type_handle(el_type_han), values,
        valuel.size as uint32);

    # Create a temporary allocation.
    let mut ptr: *llvm.LLVMOpaqueValue;
    ptr = llvm.LLVMBuildAlloca(g.irb, array_type.handle, "");

    # FIXME: Copy in what we have.
    # Store what we have.
    llvm.LLVMBuildStore(g.irb, val, ptr);

    # Iterate through our non-constant values and push them in.
    let sub_type: *llvm.LLVMOpaqueType = llvm.LLVMInt64Type();
    i = 0;
    let mut indicies: list.List = list.List.new(types.PTR);
    indicies.reserve(2);
    let mut idxs: **llvm.LLVMOpaqueValue =
        indicies.elements as **llvm.LLVMOpaqueValue;
    let zero_val: *llvm.LLVMOpaqueValue =
        llvm.LLVMConstInt(sub_type, 0, false);
    (*(idxs + 0)) = zero_val;
    while i as uint < nonconst_indicies.size {
        let arg: *llvm.LLVMOpaqueValue = nonconst_values.get_ptr(i) as
            *llvm.LLVMOpaqueValue;
        let idx: int = nonconst_indicies.get_int(i);

        # Build an `offset` pointer.
        (*(idxs + 1)) = llvm.LLVMConstInt(sub_type, idx as uint64, false);
        let mut tmp: *llvm.LLVMOpaqueValue;
        tmp = llvm.LLVMBuildInBoundsGEP(g.irb, ptr, idxs, 2, "");

        # Build the `store` instruction.
        llvm.LLVMBuildStore(g.irb, arg, tmp);

        # Advance.
        i = i + 1;
    }

    # Dispose of dynamic memory.
    nonconst_values.dispose();
    nonconst_indicies.dispose();
    valuel.dispose();
    # indicies.dispose();

    # Load the value.
    ptr = llvm.LLVMBuildLoad(g.irb, ptr, "");

    # Wrap and return the value.
    code.make_value(target, code.VC_RVALUE, ptr);
}

# Tuple [TAG_TUPLE_EXPR]
# -----------------------------------------------------------------------------
let tuple(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Unwrap the node to its proper type.
    let x: *ast.TupleExpr = node.unwrap() as *ast.TupleExpr;

    # Get our target (tuple) type
    # FIXME: Resolve our own type
    let tuple_type: *code.TupleType = target._object as *code.TupleType;

    # Iterate through each argument, build, and push them into
    # their appropriate position in the argument list.
    let mut handles: list.List = list.List.new(types.PTR);
    let mut i: int = 0;
    let mut assignable: bool = false;
    while i as uint < x.nodes.size()
    {
        # Get the specific element.
        let enode: ast.Node = x.nodes.get(i);
        let e: *ast.TupleExprMem = enode.unwrap() as *ast.TupleExprMem;

        # Resolve the type of the element expression.
        let param_typ: *code.Handle = tuple_type.elements.get_ptr(i) as *code.Handle;
        let typ: *code.Handle = resolver.resolve_st(
            g, &e.expression, scope, param_typ);
        if code.isnil(typ) { return code.make_nil(); };

        # Build the element expression node.
        let han: *code.Handle = builder.build(g, &e.expression, scope, typ);
        if code.isnil(han) { return code.make_nil(); };

        if (i == 0) | assignable {
            # Are we still assignable?
            assignable = generator_def.is_assignable(*g, han);
        };

        # Push this into our handle list.
        handles.push_ptr(han as *int8);

        # Increment our counter
        i = i + 1;
    }

    # Create a solid `tuple` object.
    let mut tup: *code.Handle;
    tup = code.make_tuple(target, handles, assignable);

    # Dispose.
    handles.dispose();

    # Return our constructed tuple.
    tup;
}
