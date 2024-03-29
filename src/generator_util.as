import ast;
import libc;
import errors;
import types;
import generator_;
import llvm;
import code;
import string;
import list;

# Declare a type in `global` scope.
# -----------------------------------------------------------------------------
let declare_type(mut g: generator_.Generator, name: str,
                 val: *llvm.LLVMOpaqueType) -> {
    let han: *code.Handle = code.make_type(val);
    g.items.set_ptr(name, han as *int8);
}

# Declare an integral type in `global` scope.
# -----------------------------------------------------------------------------
let declare_int_type(mut g: generator_.Generator, name: str,
                     val: *llvm.LLVMOpaqueType,
                     signed: bool, bits: int, machine: bool) -> {
    let han: *code.Handle = code.make_int_type(val, signed, bits, machine);
    g.items.set_ptr(name, han as *int8);
}

# Declare a float type in `global` scope.
# -----------------------------------------------------------------------------
let declare_float_type(mut g: generator_.Generator, name: str,
                       val: *llvm.LLVMOpaqueType,
                       bits: int) -> {
    let han: *code.Handle = code.make_float_type(val, bits);
    g.items.set_ptr(name, han as *int8);
}

# Declare "basic" types
# -----------------------------------------------------------------------------
let declare_basic_types(mut g: generator_.Generator) -> {
    # Boolean
    g.items.set_ptr("bool", code.make_bool_type(llvm.LLVMInt1Type()) as *int8);

    # Signed machine-independent integers
    declare_int_type(g,   "int8",   llvm.LLVMInt8Type(), true,   8, false);
    declare_int_type(g,  "int16",  llvm.LLVMInt16Type(), true,  16, false);
    declare_int_type(g,  "int32",  llvm.LLVMInt32Type(), true,  32, false);
    declare_int_type(g,  "int64",  llvm.LLVMInt64Type(), true,  64, false);
    declare_int_type(g, "int128", llvm.LLVMIntType(128), true, 128, false);

    # Unsigned machine-independent integers
    declare_int_type(g,   "uint8",   llvm.LLVMInt8Type(), false,   8, false);
    declare_int_type(g,  "uint16",  llvm.LLVMInt16Type(), false,  16, false);
    declare_int_type(g,  "uint32",  llvm.LLVMInt32Type(), false,  32, false);
    declare_int_type(g,  "uint64",  llvm.LLVMInt64Type(), false,  64, false);
    declare_int_type(g, "uint128", llvm.LLVMIntType(128), false, 128, false);

    # Floating-points
    declare_float_type(g, "float32", llvm.LLVMFloatType(), 32);
    declare_float_type(g, "float64", llvm.LLVMDoubleType(), 64);

    # TODO: Machine-dependent integers
    declare_int_type(g, "uint",  llvm.LLVMIntType(64), false, 64, false);
    declare_int_type(g, "int",  llvm.LLVMIntType(64), true, 64, false);

    # UTF-32 Character
    let mut han: *code.Handle = code.make_char_type();
    g.items.set_ptr("char", han as *int8);

    # TODO: UTF-8 String
    # ASCII String
    han = code.make_str_type();
    g.items.set_ptr("str", han as *int8);
}

# Declare `platform` built-in module
# -----------------------------------------------------------------------------
let declare_platform(mut g: generator_.Generator, target: str) -> {
    # Split the target string into its component parts.
    let parts = string.split('-', target);

    # Create a 'platform' module.
    let ns = list.List.new(types.STR);
    let pmod_han = code.make_module("platform", ns);
    ns.push_str("platform");

    # Create a 'platform.os' static.
    let type_han = g.items.get_ptr("str") as *code.Handle;
    let type_ = type_han._object as *code.Type;
    let mut handle = llvm.LLVMAddGlobal(g.mod, type_.handle, "platform.os");
    llvm.LLVMSetLinkage(handle, 9);  # LLVMPrivateLinkage
    llvm.LLVMSetVisibility(handle, 1);  # LLVMHiddenVisibility
    llvm.LLVMSetGlobalConstant(handle, true);
    let mut val = llvm.LLVMBuildGlobalStringPtr(g.irb, parts.get_str(2), "");
    llvm.LLVMSetInitializer(handle, val);
    let pmod_os_han = code.make_static_slot(
        0 as *ast.SlotDecl, "os", ns, type_han, handle);

    # Create a 'platform.arch' static.
    handle = llvm.LLVMAddGlobal(g.mod, type_.handle, "platform.arch");
    llvm.LLVMSetLinkage(handle, 9);  # LLVMPrivateLinkage
    llvm.LLVMSetVisibility(handle, 1);  # LLVMHiddenVisibility
    llvm.LLVMSetGlobalConstant(handle, true);
    val = llvm.LLVMBuildGlobalStringPtr(g.irb, parts.get_str(0), "");
    llvm.LLVMSetInitializer(handle, val);
    let pmod_arch_han = code.make_static_slot(
        0 as *ast.SlotDecl, "arch", ns, type_han, handle);

    # Emplace these in the global scope.
    g.items.set_ptr("platform", pmod_han as *int8);
    g.items.set_ptr("platform.os", pmod_os_han as *int8);
    g.items.set_ptr("platform.arch", pmod_arch_han as *int8);
}

# Declare `assert` built-in function
# -----------------------------------------------------------------------------
let declare_assert(mut g: generator_.Generator) -> {
    # Build the LLVM type for the `abort` fn.
    let abort_type: *llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMVoidType(), 0 as **llvm.LLVMOpaqueType, 0, 0);

    # Build the LLVM function for `abort`.
    let abort_fn: *llvm.LLVMOpaqueValue = llvm.LLVMAddFunction(
        g.mod, "abort", abort_type);

    # Build the LLVM type.
    let param: *llvm.LLVMOpaqueType = llvm.LLVMInt1Type();
    let type_obj: *llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMVoidType(), &param, 1, 0);

    # Create a `solid` handle to the parameter.
    let phandle: *code.Handle = g.items.get_ptr("bool") as *code.Handle;

    # Create a `solid` handle to the parameters.
    let mut params: list.List = list.List.new(types.PTR);
    params.push_ptr(code.make_parameter(
        "condition", phandle, code.make_nil(), false) as *int8);

    # Create a `solid` handle to the function type.
    let type_: *code.Handle = code.make_function_type(
        "", list.List.new(types.STR), "", type_obj,
        code.make_void_type(llvm.LLVMVoidType()),
        params);

    # Build the LLVM function declaration.
    let mut val: *llvm.LLVMOpaqueValue;
    val = llvm.LLVMAddFunction(g.mod, "assert", type_obj);
    llvm.LLVMSetLinkage(val, 9);  # LLVMPrivateLinkage
    llvm.LLVMSetVisibility(val, 1);  # LLVMHiddenVisibility

    # Create a `solid` handle to the function.
    let mut ns: list.List = list.List.new(types.STR);
    let fn: *code.Handle = code.make_function(
        0 as *ast.FuncDecl, "assert", ns, type_, val);

    # Set in the global scope.
    g.items.set_ptr("assert", fn as *int8);

    # Build the LLVM function definition.
    # Add the basic blocks.
    let mut entry_block: *llvm.LLVMOpaqueBasicBlock;
    let mut then_block: *llvm.LLVMOpaqueBasicBlock;
    let mut merge_block: *llvm.LLVMOpaqueBasicBlock;
    entry_block = llvm.LLVMAppendBasicBlock(val, "");
    then_block = llvm.LLVMAppendBasicBlock(val, "");
    merge_block = llvm.LLVMAppendBasicBlock(val, "");

    # Grab the single argument.
    llvm.LLVMPositionBuilderAtEnd(g.irb, entry_block);
    let phandle: *llvm.LLVMOpaqueValue = llvm.LLVMGetParam(val, 0);

    # Add a conditional branch on the single argument.
    llvm.LLVMBuildCondBr(g.irb, phandle, merge_block, then_block);

    # Add the call to `abort`.
    llvm.LLVMPositionBuilderAtEnd(g.irb, then_block);
    llvm.LLVMBuildCall(g.irb, abort_fn, 0 as **llvm.LLVMOpaqueValue, 0,
                       "");
    llvm.LLVMBuildBr(g.irb, merge_block);

    # Add the `ret int8` instruction to terminate the function.
    llvm.LLVMPositionBuilderAtEnd(g.irb, merge_block);
    llvm.LLVMBuildRetVoid(g.irb);
}

# Qualify a name in context of the passed namespace.
# -----------------------------------------------------------------------------
let qualify_name_in(s: str, ns: list.List): string.String -> {
    let mut qn: string.String;
    qn = string.join(".", ns);
    if qn.size() > 0 { qn.append('.'); };
    qn.extend(s);
    qn;
}

# Qualify the passed name in the current namespace.
# -----------------------------------------------------------------------------
let qualify_name(mut g: generator_.Generator, s: str): string.String -> {
    qualify_name_in(s, g.ns);
}

# Get the "item" using the scoping rules in the passed scope and namespace.
# -----------------------------------------------------------------------------
let get_scoped_item_in(mut g: generator_.Generator, s: str,
                       scope: *code.Scope, _ns: list.List): *code.Handle ->
{
    # Check if the name is declared in the passed local scope.
    if scope != 0 as *code.Scope {
        if scope.contains(s) {
            # Get and return the item.
            return scope.get(s);
        };
    };

    # Qualify the name reference and match against the enclosing
    # scopes by resolving inner-most first and popping namespaces until
    # a match.
    let mut qname: string.String = string.String.new();
    let mut ns: list.List = _ns.clone();
    let mut matched: bool = false;
    loop {
        # Qualify the name by joining the namespaces.
        qname.dispose();
        qname = qualify_name_in(s, ns);

        # Check for the qualified identifier in the `global` scope.
        if g.items.contains(qname.data() as str) {
            # Found it in the currently resolved scope.
            matched = true;
            break;
        };

        # Do we have any namespaces left.
        if ns.size > 0 {
            # Ensure that we cannot refer to the resolving namespace
            # if we are a module.
            if libc.strcmp(ns.get_str(-1), s) == 0 {
                ns.erase(-1);
                qname.dispose();
                qname = qualify_name_in(s, ns);
                let han: *code.Handle =
                    g.items.get_ptr(qname.data() as str) as *code.Handle;
                if han._tag == code.TAG_MODULE {
                    break;
                };
                0; # HACK!
            } else {
                # Pop off the namespace.
                ns.erase(-1);
            };
        } else {
            # Out of namespaces to pop.
            break;
        };
    }

    # Dispose.
    ns.dispose();

    # If we didn't matched; return nil.
    if not matched { return code.make_nil(); };

    # Get the matched handle.
    let matched_han: *code.Handle =
        g.items.get_ptr(qname.data() as str) as *code.Handle;

    # Return the matched handle.
    matched_han;
}

# Check if two types are the same.
# -----------------------------------------------------------------------------
let is_same_type(a: *code.Handle, b: *code.Handle): bool ->
{
    if a._tag == code.TAG_POINTER_TYPE and a._tag == b._tag
    {
        # These are both pointers; move to the pointee types.
        let a_type: *code.PointerType = a._object as *code.PointerType;
        let b_type: *code.PointerType = b._object as *code.PointerType;
        return is_same_type(a_type.pointee, b_type.pointee);
        0; #HACK!
    }
    else if a._tag == code.TAG_REFERENCE_TYPE and a._tag == b._tag
    {
        # These are both pointers; move to the pointee types.
        let a_type: *code.ReferenceType = a._object as *code.ReferenceType;
        let b_type: *code.ReferenceType = b._object as *code.ReferenceType;
        return is_same_type(a_type.pointee, b_type.pointee);
        0; #HACK!
    }
    else if a._tag == code.TAG_VOID_TYPE and a._tag == b._tag {
        return true;
    }
    else if a._tag == code.TAG_ARRAY_TYPE and a._tag == b._tag
    {
        # These are both arrays; move to the element types.
        let a_type: *code.ArrayType = a._object as *code.ArrayType;
        let b_type: *code.ArrayType = b._object as *code.ArrayType;
        return a_type.size == b_type.size and
               is_same_type(a_type.element, b_type.element);
        0; #HACK!
    }
    else if a._tag == code.TAG_TUPLE_TYPE and a._tag == b._tag
    {
        # These are both tuples.
        let a_type: *code.TupleType = a._object as *code.TupleType;
        let b_type: *code.TupleType = b._object as *code.TupleType;

        # Short-circuit if the count is unmatched.
        if a_type.elements.size != b_type.elements.size { return false; };

        # Iterate through the elements and break if any element is
        # unmatched.
        let mut i: int = 0;
        while i as uint < a_type.elements.size {
            let a_el_han: *code.Handle = a_type.elements.get_ptr(i) as
                *code.Handle;
            let b_el_han: *code.Handle = b_type.elements.get_ptr(i) as
                *code.Handle;
            if not is_same_type(a_el_han, b_el_han) {
                return false;
            };
            i = i + 1;
        }

        # These tuples seems to be equivalent.
        return true;
    }
    else if a._tag == code.TAG_FUNCTION_TYPE and a._tag == b._tag
    {
        # These are both functions.
        let a_type: *code.FunctionType = a._object as *code.FunctionType;
        let b_type: *code.FunctionType = b._object as *code.FunctionType;

        # Short-circuit if the argument count is unmatched.
        if a_type.parameters.size != b_type.parameters.size { return false; };

        # Short-circuit if the return type is unmatched.
        if not is_same_type(a_type.return_type, b_type.return_type) {
            return false;
        };

        # Iterate through the arguments and break if any argument is
        # unmatched.
        let mut i: int = 0;
        while i as uint < a_type.parameters.size {
            let a_param_han: *code.Handle = a_type.parameters.get_ptr(i) as
                *code.Handle;
            let b_param_han: *code.Handle = b_type.parameters.get_ptr(i) as
                *code.Handle;
            let a_param: *code.Parameter = a_param_han._object as
                *code.Parameter;
            let b_param: *code.Parameter = b_param_han._object as
                *code.Parameter;
            if not is_same_type(a_param.type_, b_param.type_) {
                return false;
            };
            i = i + 1;
        }

        # These functions seems to be equivalent.
        return true;
    };

    # Perform an address check.
    return a._object == b._object;
}

# Build a "sizeof" expression for a specific type handle.
# -----------------------------------------------------------------------------
let build_sizeof(mut g: generator_.Generator, han: *code.Handle): *code.Handle ->
{
    # Get the type handle.
    let type_: *code.Type = han._object as *code.Type;

    # Build the `sizeof` instruction.
    let val: *llvm.LLVMOpaqueValue = llvm.LLVMSizeOf(type_.handle);

    # Wrap and return it.
    code.make_value(g.items.get_ptr("uint") as *code.Handle,
                    code.VC_RVALUE, val);
}

# Find the allocation size (in bytes).
# -----------------------------------------------------------------------------
let sizeof(mut g: generator_.Generator, typ: *llvm.LLVMOpaqueType): uint128 ->
{
    # Get the `sizeof` using llvm ABI.
    return llvm.LLVMABISizeOfType(g.target_data, typ);
}

# Create a cast from a value to a type.
# -----------------------------------------------------------------------------
let cast(mut g: generator_.Generator, handle: *code.Handle,
         type_: *code.Handle, _explicit: bool): *code.Handle ->
{
    # Get the value of the handle.
    let mut explicit: bool = _explicit;
    let src_val: *code.Value = handle._object as *code.Value;

    # Get the type of the value handle.
    let src_han: *code.Handle = src_val.type_;

    # Get the src/dst types.
    let src: *code.Type = src_han._object as *code.Type;
    let dst: *code.Type = type_._object as *code.Type;

    # Are these the "same" type?
    if is_same_type(src_han, type_) {
        # Wrap and return our val.
        return code.make_value(type_, src_val.category, src_val.handle);
    };

    # Get typenames ready.
    let mut s_typename: string.String = code.typename(src_han);
    let mut d_typename: string.String = code.typename(type_);

    # Build the cast.
    let mut val: *llvm.LLVMOpaqueValue = 0 as *llvm.LLVMOpaqueValue;
    let mut lst: list.List;
    if src_han._tag == code.TAG_INT_TYPE and src_han._tag == type_._tag {
        # Get the int_ty out.
        let src_int: *code.IntegerType = src as *code.IntegerType;
        let dst_int: *code.IntegerType = dst as *code.IntegerType;

        # If our source value is a "constant expression" then just
        # infer us to be an explicit cast
        if llvm.LLVMIsConstant(src_val.handle) != 0 { explicit = true; };

        if (not dst_int.machine and not src_int.machine) or explicit
        {
            if dst_int.bits >= src_int.bits
            {
                # Create a ZExt or SExt.
                if src_int.signed {
                    val = llvm.LLVMBuildSExt(g.irb, src_val.handle, dst.handle,
                                             "");
                } else {
                    val = llvm.LLVMBuildZExt(g.irb, src_val.handle, dst.handle,
                                             "");
                };
                0; # HACK
            }
            else # if explicit
            {
                # Create a Trunc
                val = llvm.LLVMBuildTrunc(g.irb, src_val.handle, dst.handle,
                                          "");
                0; # HACK
            };
        };
        0; #HACK!
    } else if src_han._tag == code.TAG_FLOAT_TYPE
            and src_han._tag == type_._tag {
        # Get float_ty out.
        let src_f: *code.FloatType = src as *code.FloatType;
        let dst_f: *code.FloatType = dst as *code.FloatType;

        if dst_f.bits > src_f.bits {
            # Create a Ext
            val = llvm.LLVMBuildFPExt(g.irb, src_val.handle, dst.handle,
                                      "");
        } else {
            # Create a Trunc
            val = llvm.LLVMBuildFPTrunc(g.irb, src_val.handle, dst.handle,
                                        "");
        };
        0; #HACK!
    } else if src_han._tag == code.TAG_FLOAT_TYPE
            and type_._tag == code.TAG_INT_TYPE {
        # Get ty out.
        let src_ty: *code.FloatType = src as *code.FloatType;
        let dst_ty: *code.IntegerType = dst as *code.IntegerType;

        if dst_ty.signed {
            val = llvm.LLVMBuildFPToSI(g.irb, src_val.handle, dst.handle,
                                       "");
        } else {
            val = llvm.LLVMBuildFPToUI(g.irb, src_val.handle, dst.handle,
                                       "");
        };
        0; #HACK!
    } else if src_han._tag == code.TAG_INT_TYPE
            and type_._tag == code.TAG_FLOAT_TYPE {
        # Get ty out.
        let src_ty: *code.IntegerType = src as *code.IntegerType;
        let dst_ty: *code.FloatType = dst as *code.FloatType;

        if src_ty.signed {
            val = llvm.LLVMBuildSIToFP(g.irb, src_val.handle, dst.handle,
                                       "");
        } else {
            val = llvm.LLVMBuildUIToFP(g.irb, src_val.handle, dst.handle,
                                       "");
        };
        0; #HACK!
    } else if src_han._tag == code.TAG_POINTER_TYPE
          and type_._tag == src_han._tag {
        # We need to convert one pointer type to the other.
        # This is pretty easy (its just a bitcast).
        val = llvm.LLVMBuildPointerCast(
            g.irb, src_val.handle, dst.handle, "");
    } else if src_han._tag == code.TAG_POINTER_TYPE
          and type_._tag == code.TAG_INT_TYPE
    {
        # We need to convert this pointer to an integral type.
        val = llvm.LLVMBuildPtrToInt(
            g.irb, src_val.handle, dst.handle, "");
    }
    else if src_han._tag == code.TAG_INT_TYPE
          and type_._tag == code.TAG_POINTER_TYPE
    {
        # We need to convert this integer to an pointer type.
        val = llvm.LLVMBuildIntToPtr(
            g.irb, src_val.handle, dst.handle, "");
    }
    else if src_han._tag == code.TAG_CHAR_TYPE
          and type_._tag == code.TAG_INT_TYPE
    {
        let int_ty: *code.IntegerType = type_._object as *code.IntegerType;
        if int_ty.bits >= 32 and not int_ty.signed {
            val = llvm.LLVMBuildZExt(g.irb, src_val.handle, dst.handle,
                                     "");
        }
        else if int_ty.bits > 32 and int_ty.signed {
            val = llvm.LLVMBuildSExt(g.irb, src_val.handle, dst.handle,
                                     "");
        }
        else if explicit {
            val = llvm.LLVMBuildTrunc(g.irb, src_val.handle, dst.handle,
                                      "");
        };
    }
    else if type_._tag == code.TAG_CHAR_TYPE
          and src_han._tag == code.TAG_INT_TYPE
    {
        let int_ty: *code.IntegerType = src_han._object as *code.IntegerType;
        if int_ty.bits <= 32 and int_ty.signed {
            val = llvm.LLVMBuildZExt(g.irb, src_val.handle, dst.handle,
                                     "");
        }
        else if int_ty.bits < 32 and not int_ty.signed {
            val = llvm.LLVMBuildSExt(g.irb, src_val.handle, dst.handle,
                                     "");
        }
        else if explicit {
            val = llvm.LLVMBuildTrunc(g.irb, src_val.handle, dst.handle,
                                      "");
        };
    }
    else if type_._tag == code.TAG_REFERENCE_TYPE
    {
        let ref_type: *code.ReferenceType = type_._object as *code.ReferenceType;
        let pointee_cast_han: *code.Handle = cast(
            g, handle, ref_type.pointee, explicit);
        if not code.isnil(pointee_cast_han) {
            let pointee_val_han: *code.Value = pointee_cast_han._object as
                *code.Value;
            if src_val.category == code.VC_LVALUE {
                val = src_val.handle;
            } else {
                # Try and optimize this if our previous value is a
                # LOAD operation.
                let opc: int = llvm.LLVMGetInstructionOpcode(src_val.handle);
                if opc == 27 {  # LLVMLoad
                    val = llvm.LLVMGetOperand(src_val.handle, 0);
                    llvm.LLVMInstructionEraseFromParent(src_val.handle);
                    val;
                } else {
                    let pointee_type: *code.Type = ref_type.pointee._object as
                        *code.Type;
                    let slot: *llvm.LLVMOpaqueValue =
                        llvm.LLVMBuildAlloca(
                            g.irb, pointee_type.handle, "");
                    llvm.LLVMBuildStore(g.irb, pointee_val_han.handle, slot);
                    val = slot;
                    0; #HACK
                };
                0; # HACK!
            };
        } else {
            return code.make_nil();
        };
    }
    else if explicit and type_._tag == code.TAG_STR_TYPE
           and src_han._tag == code.TAG_POINTER_TYPE
    {
        let ptr_ty: *code.PointerType = src_han._object as *code.PointerType;
        if ptr_ty.pointee._tag == code.TAG_INT_TYPE {
            let int_ty: *code.IntegerType = ptr_ty.pointee._object as *code.IntegerType;
            if int_ty.bits == 8 {
                val = src_val.handle;
            };
        };
    }
    else if explicit and src_han._tag == code.TAG_STR_TYPE
           and type_._tag == code.TAG_POINTER_TYPE
    {
        let ptr_ty: *code.PointerType = type_._object as *code.PointerType;
        if ptr_ty.pointee._tag == code.TAG_INT_TYPE {
            let int_ty: *code.IntegerType = ptr_ty.pointee._object as *code.IntegerType;
            if int_ty.bits == 8 {
                val = src_val.handle;
            };
        };
    }
    else if src_han._tag == code.TAG_STR_TYPE
            and type_._tag == code.TAG_CHAR_TYPE
    {
        # Converting a string to a char only works if we are coming from
        # a literal that is exactly 1 character
        if handle._context != 0 as *ast.Node {
            if handle._context.tag == ast.TAG_STRING {
                let string_: *ast.StringExpr = handle._context.unwrap() as *ast.StringExpr;
                let str_: ast.StringExpr = *string_;
                lst = str_.unescape();  # HACK!
                if lst.size == 1 {
                    # Find the ASCII value of this string
                    let c0: int8 = lst.get_i8(0);
                    let ty: *code.Type = type_._object as *code.Type;

                    # Create a constant int for this.
                    val = llvm.LLVMConstInt(ty.handle, c0 as uint64, false);
                };
                lst.dispose();
                val;
            };
        };
    };

    # If we got nothing, return nothing
    if val == 0 as *llvm.LLVMOpaqueValue {
        errors.begin_error();
        errors.libc.fprintf(
            errors.libc.stderr,
            "no %s conversion from '%s' to '%s'",
            ("explicit" if explicit else "implicit"),
            s_typename.data(), d_typename.data());
        errors.end();

        return code.make_nil();
    };

    # Dispose.
    s_typename.dispose();
    d_typename.dispose();

    # Wrap and return.
    code.make_value(type_, code.VC_RVALUE, val);
}

# Check if a Llvm basic block has been "terminated"
# -----------------------------------------------------------------------------
let is_terminated(block: *llvm.LLVMOpaqueBasicBlock): bool ->
{
    let terminator: *llvm.LLVMOpaqueValue =
        llvm.LLVMGetBasicBlockTerminator(block);
    return terminator != 0 as *llvm.LLVMOpaqueValue;
}

# Check if the two types are "compatible"
# -----------------------------------------------------------------------------
let type_compatible(d: *code.Handle, s: *code.Handle): bool -> {
    # Get the type handles.
    let s_ty: *code.Type = s._object as *code.Type;
    let d_ty: *code.Type = d._object as *code.Type;

    # If these are the `same` then were okay.
    if is_same_type(d, s) { return true; }
    else if s_ty.handle == d_ty.handle { return true; }
    else if s._tag == code.TAG_INT_TYPE and d._tag == code.TAG_INT_TYPE
    {
        return true;
    }
    else if d._tag == code.TAG_INT_TYPE and s._tag == code.TAG_CHAR_TYPE
    {
        return true;
    }
    else if d._tag == code.TAG_CHAR_TYPE and s._tag == code.TAG_INT_TYPE
    {
        return true;
    };

    # Report error.
    let mut s_typename: string.String = code.typename(s);
    let mut d_typename: string.String = code.typename(d);
    errors.begin_error();
    errors.libc.fprintf(errors.libc.stderr,
                   "mismatched types: expected '%s' but found '%s'",
                   d_typename.data(), s_typename.data());
    errors.end();

    # Dispose.
    s_typename.dispose();
    d_typename.dispose();

    # Return false.
    false;
}

# Get the qualified type name for this handle
# -----------------------------------------------------------------------------
let qualified_name_ref(han: *code.Handle): string.String -> {
    let typ: *code.Type = han._object as *code.Type;
    let mut m: string.String = string.String.new();
    m._data.reserve(64);
    let written: int = libc.snprintf(
        m.data(), 64, "%p", typ.handle);
    m._data.size = written as uint;
    let data: *mut int8 = m.data() as *int8;
    *(data + 0) = string.ord("_");
    *(data + 1) = string.ord("Z");
    m;
}

# Get an attached function
# -----------------------------------------------------------------------------
let get_attached_function(mut g: generator_.Generator,
                          type_: *code.Handle,
                          name: str): *code.Handle -> {
    let mut qn: string.String = qualified_name_ref(type_);
    qn.append(".");
    qn.extend(name);
    let item: *code.Handle = g.items.get_ptr(qn.data() as str) as *code.Handle;
    qn.dispose();
    item;
}

# Alter Type Handle
let alter_type_handle(type_handle: *code.Handle): *llvm.LLVMOpaqueType -> {
    let type_: *code.Type = type_handle._object as *code.Type;
    let mut handle: *llvm.LLVMOpaqueType = type_.handle;
    if type_handle._tag == code.TAG_FUNCTION_TYPE {
        # For functions we store them as function "pointers" but refer
        # to them as objects.
        handle = llvm.LLVMPointerType(handle, 0);
    };
    handle;
}
