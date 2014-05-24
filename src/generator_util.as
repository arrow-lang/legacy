import types;
import ast;
import generator_;
import llvm;
import code;
import string;
import list;

# Declare a type in `global` scope.
# -----------------------------------------------------------------------------
def declare_type(&mut g: generator_.Generator, name: str,
                 val: ^llvm.LLVMOpaqueType) {
    let han: ^code.Handle = code.make_type(val);
    g.items.set_ptr(name, han as ^void);
}

# Declare an integral type in `global` scope.
# -----------------------------------------------------------------------------
def declare_int_type(&mut g: generator_.Generator, name: str,
                     val: ^llvm.LLVMOpaqueType,
                     signed: bool, bits: uint) {
    let han: ^code.Handle = code.make_int_type(val, signed, bits);
    g.items.set_ptr(name, han as ^void);
}

# Declare a float type in `global` scope.
# -----------------------------------------------------------------------------
def declare_float_type(&mut g: generator_.Generator, name: str,
                       val: ^llvm.LLVMOpaqueType,
                       bits: uint) {
    let han: ^code.Handle = code.make_float_type(val, bits);
    g.items.set_ptr(name, han as ^void);
}

# Declare "basic" types
# -----------------------------------------------------------------------------
def declare_basic_types(&mut g: generator_.Generator) {
    # Boolean
    g.items.set_ptr("bool", code.make_bool_type(llvm.LLVMInt1Type()) as ^void);

    # Signed machine-independent integers
    declare_int_type(g,   "int8",   llvm.LLVMInt8Type(), true,   8);
    declare_int_type(g,  "int16",  llvm.LLVMInt16Type(), true,  16);
    declare_int_type(g,  "int32",  llvm.LLVMInt32Type(), true,  32);
    declare_int_type(g,  "int64",  llvm.LLVMInt64Type(), true,  64);
    declare_int_type(g, "int128", llvm.LLVMIntType(128), true, 128);

    # Unsigned machine-independent integers
    declare_int_type(g,   "uint8",   llvm.LLVMInt8Type(), false,   8);
    declare_int_type(g,  "uint16",  llvm.LLVMInt16Type(), false,  16);
    declare_int_type(g,  "uint32",  llvm.LLVMInt32Type(), false,  32);
    declare_int_type(g,  "uint64",  llvm.LLVMInt64Type(), false,  64);
    declare_int_type(g, "uint128", llvm.LLVMIntType(128), false, 128);

    # Floating-points
    declare_float_type(g, "float32", llvm.LLVMFloatType(), 32);
    declare_float_type(g, "float64", llvm.LLVMDoubleType(), 64);

    # Unsigned machine-dependent integer
    # FIXME: Find how big this really is.
    declare_int_type(g,  "uint",  llvm.LLVMInt64Type(), false, 64);

    # Signed machine-dependent integer
    # FIXME: Find how big this really is.
    declare_int_type(g,  "int",  llvm.LLVMInt64Type(), true, 64);

    # TODO: UTF-32 Character

    # TODO: UTF-8 String
}

# Declare `assert` built-in function
# -----------------------------------------------------------------------------
def declare_assert(&mut g: generator_.Generator) {
    # Build the LLVM type for the `abort` fn.
    let abort_type: ^llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMVoidType(), 0 as ^^llvm.LLVMOpaqueType, 0, 0);

    # Build the LLVM function for `abort`.
    let abort_fn: ^llvm.LLVMOpaqueValue = llvm.LLVMAddFunction(
        g.mod, "abort" as ^int8, abort_type);

    # Build the LLVM type.
    let param: ^llvm.LLVMOpaqueType = llvm.LLVMInt1Type();
    let type_obj: ^llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMVoidType(), &param, 1, 0);

    # Create a `solid` handle to the parameter.
    let phandle: ^code.Handle = g.items.get_ptr("bool") as ^code.Handle;

    # Create a `solid` handle to the parameters.
    let mut params: list.List = list.make(types.PTR);
    params.push_ptr(code.make_parameter(
        "condition", phandle, code.make_nil()) as ^void);

    # Create a `solid` handle to the function type.
    let type_: ^code.Handle = code.make_function_type(
        "", list.make(types.STR), "", type_obj,
        code.make_void_type(llvm.LLVMVoidType()),
        params);

    # Build the LLVM function declaration.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMAddFunction(g.mod, "assert" as ^int8, type_obj);

    # Create a `solid` handle to the function.
    let mut ns: list.List = list.make(types.STR);
    let fn: ^code.Handle = code.make_function(
        0 as ^ast.FuncDecl, "assert", ns, type_, val);

    # Set in the global scope.
    g.items.set_ptr("assert", fn as ^void);

    # Build the LLVM function definition.
    # Add the basic blocks.
    let entry_block: ^llvm.LLVMOpaqueBasicBlock;
    let then_block: ^llvm.LLVMOpaqueBasicBlock;
    let merge_block: ^llvm.LLVMOpaqueBasicBlock;
    entry_block = llvm.LLVMAppendBasicBlock(val, "" as ^int8);
    then_block = llvm.LLVMAppendBasicBlock(val, "" as ^int8);
    merge_block = llvm.LLVMAppendBasicBlock(val, "" as ^int8);

    # Grab the single argument.
    llvm.LLVMPositionBuilderAtEnd(g.irb, entry_block);
    let phandle: ^llvm.LLVMOpaqueValue = llvm.LLVMGetParam(val, 0);

    # Add a conditional branch on the single argument.
    llvm.LLVMBuildCondBr(g.irb, phandle, merge_block, then_block);

    # Add the call to `abort`.
    llvm.LLVMPositionBuilderAtEnd(g.irb, then_block);
    llvm.LLVMBuildCall(g.irb, abort_fn, 0 as ^^llvm.LLVMOpaqueValue, 0,
                       "" as ^int8);
    llvm.LLVMBuildBr(g.irb, merge_block);

    # Add the `ret void` instruction to terminate the function.
    llvm.LLVMPositionBuilderAtEnd(g.irb, merge_block);
    llvm.LLVMBuildRetVoid(g.irb);
}

# Declare the `main` function.
# -----------------------------------------------------------------------------
def declare_main(&mut g: generator_.Generator) {
    # Qualify a module main name.
    let mut name: string.String = string.make();
    name.extend(g.top_ns.data() as str);
    name.append('.');
    name.extend("main");

    # Was their a main function defined?
    let module_main_fn: ^llvm.LLVMOpaqueValue = 0 as ^llvm.LLVMOpaqueValue;
    if g.items.contains(name.data() as str) {
        let module_main_han: ^code.Handle;
        module_main_han = g.items.get_ptr(name.data() as str) as ^code.Handle;
        let module_main_fn_han: ^code.Function;
        module_main_fn_han = module_main_han._object as ^code.Function;
        module_main_fn = module_main_fn_han.handle;
    }

    # Build the LLVM type for the `main` fn.
    let main_type: ^llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMInt32Type(), 0 as ^^llvm.LLVMOpaqueType, 0, 0);

    # Build the LLVM function for `main`.
    let main_fn: ^llvm.LLVMOpaqueValue = llvm.LLVMAddFunction(
        g.mod, "main" as ^int8, main_type);

    # Build the LLVM function definition.
    let entry_block: ^llvm.LLVMOpaqueBasicBlock;
    entry_block = llvm.LLVMAppendBasicBlock(main_fn, "" as ^int8);
    llvm.LLVMPositionBuilderAtEnd(g.irb, entry_block);

    if module_main_fn <> 0 as ^llvm.LLVMOpaqueValue {
        # Create a `call` to the module main method.
        llvm.LLVMBuildCall(
            g.irb, module_main_fn,
            0 as ^^llvm.LLVMOpaqueValue, 0,
            "" as ^int8);
    }

    # Create a constant 0.
    let zero: ^llvm.LLVMOpaqueValue;
    zero = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, false);

    # Add the `ret void` instruction to terminate the function.
    llvm.LLVMBuildRet(g.irb, zero);

    # Dispose.
    name.dispose();

}

# Qualify a name in context of the passed namespace.
# -----------------------------------------------------------------------------
def qualify_name_in(s: str, ns: list.List) -> string.String {
    let mut qn: string.String;
    qn = string.join(".", ns);
    if qn.size() > 0 { qn.append('.'); }
    qn.extend(s);
    qn;
}

# Qualify the passed name in the current namespace.
# -----------------------------------------------------------------------------
def qualify_name(&mut g: generator_.Generator, s: str) -> string.String {
    qualify_name_in(s, g.ns);
}

# Get the "item" using the scoping rules in the passed scope and namespace.
# -----------------------------------------------------------------------------
def get_scoped_item_in(&mut g: generator_.Generator, s: str,
                       scope: ^code.Scope, _ns: list.List) -> ^code.Handle
{
    # Check if the name is declared in the passed local scope.
    if scope <> 0 as ^code.Scope {
        if (scope^).contains(s) {
            # Get and return the item.
            return (scope^).get(s);
        }
    }

    # Qualify the name reference and match against the enclosing
    # scopes by resolving inner-most first and popping namespaces until
    # a match.
    let mut qname: string.String = string.make();
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
        }

        # Do we have any namespaces left.
        if ns.size > 0 {
            ns.erase(-1);
        } else {
            # Out of namespaces to pop.
            break;
        }
    }

    # If we matched; return the item.
    if matched {
        g.items.get_ptr(qname.data() as str) as ^code.Handle;
    } else {
        code.make_nil();
    }
}

# Check if two types are the same.
# -----------------------------------------------------------------------------
def is_same_type(a: ^code.Handle, b: ^code.Handle) -> bool
{
    if a._tag == code.TAG_POINTER_TYPE and a._tag == b._tag
    {
        # These are both pointers; move to the pointee types.
        let a_type: ^code.PointerType = a._object as ^code.PointerType;
        let b_type: ^code.PointerType = b._object as ^code.PointerType;
        return is_same_type(a_type.pointee, b_type.pointee);
    }

    # Perform an address check.
    return a._object == b._object;
}

# Build a "sizeof" expression for a specific type handle.
# -----------------------------------------------------------------------------
def sizeof(&mut g: generator_.Generator, han: ^code.Handle) -> ^code.Handle
{
    # Get the type handle.
    let type_: ^code.Type = han._object as ^code.Type;

    # Build the `sizeof` instruction.
    let val: ^llvm.LLVMOpaqueValue = llvm.LLVMSizeOf(type_.handle);

    # Wrap and return it.
    code.make_value(g.items.get_ptr("uint") as ^code.Handle,
                    code.VC_RVALUE, val);
}

# Create a cast from a value to a type.
# -----------------------------------------------------------------------------
def cast(&mut g: generator_.Generator, handle: ^code.Handle,
         type_: ^code.Handle) -> ^code.Handle
{
    # Get the value of the handle.
    let src_val: ^code.Value = handle._object as ^code.Value;

    # Get the type of the value handle.
    let src_han: ^code.Handle = src_val.type_;

    # Get the src/dst types.
    let src: ^code.Type = src_han._object as ^code.Type;
    let dst: ^code.Type = type_._object as ^code.Type;

    # Are these the "same" type?
    if is_same_type(src_han, type_) {
        # Wrap and return our val.
        return code.make_value(type_, src_val.category, src_val.handle);
    }

    # Build the cast.
    let val: ^llvm.LLVMOpaqueValue;
    if src_han._tag == code.TAG_INT_TYPE and src_han._tag == type_._tag {
        # Get the int_ty out.
        let src_int: ^code.IntegerType = src as ^code.IntegerType;
        let dst_int: ^code.IntegerType = dst as ^code.IntegerType;

        if dst_int.bits > src_int.bits {
            # Create a ZExt or SExt.
            if src_int.signed {
                val = llvm.LLVMBuildSExt(g.irb, src_val.handle, dst.handle,
                                         "" as ^int8);
            } else {
                val = llvm.LLVMBuildZExt(g.irb, src_val.handle, dst.handle,
                                         "" as ^int8);
            }
        } else {
            # Create a Trunc
            val = llvm.LLVMBuildTrunc(g.irb, src_val.handle, dst.handle,
                                      "" as ^int8);
        }
    } else if src_han._tag == code.TAG_FLOAT_TYPE
            and src_han._tag == type_._tag {
        # Get float_ty out.
        let src_f: ^code.FloatType = src as ^code.FloatType;
        let dst_f: ^code.FloatType = dst as ^code.FloatType;

        if dst_f.bits > src_f.bits {
            # Create a Ext
            val = llvm.LLVMBuildFPExt(g.irb, src_val.handle, dst.handle,
                                      "" as ^int8);
        } else {
            # Create a Trunc
            val = llvm.LLVMBuildFPTrunc(g.irb, src_val.handle, dst.handle,
                                        "" as ^int8);
        }
    } else if src_han._tag == code.TAG_FLOAT_TYPE
            and type_._tag == code.TAG_INT_TYPE {
        # Get ty out.
        let src_ty: ^code.FloatType = src as ^code.FloatType;
        let dst_ty: ^code.IntegerType = dst as ^code.IntegerType;

        if dst_ty.signed {
            val = llvm.LLVMBuildFPToSI(g.irb, src_val.handle, dst.handle,
                                       "" as ^int8);
        } else {
            val = llvm.LLVMBuildFPToUI(g.irb, src_val.handle, dst.handle,
                                       "" as ^int8);
        }
    } else if src_han._tag == code.TAG_INT_TYPE
            and type_._tag == code.TAG_FLOAT_TYPE {
        # Get ty out.
        let src_ty: ^code.IntegerType = src as ^code.IntegerType;
        let dst_ty: ^code.FloatType = dst as ^code.FloatType;

        if src_ty.signed {
            val = llvm.LLVMBuildSIToFP(g.irb, src_val.handle, dst.handle,
                                       "" as ^int8);
        } else {
            val = llvm.LLVMBuildUIToFP(g.irb, src_val.handle, dst.handle,
                                       "" as ^int8);
        }
    } else if src_han._tag == code.TAG_POINTER_TYPE
          and type_._tag == src_han._tag {
        # We need to convert one pointer type to the other.
        # This is pretty easy (its just a bitcast).
        val = llvm.LLVMBuildPointerCast(
            g.irb, src_val.handle, dst.handle, "" as ^int8);
    } else if src_han._tag == code.TAG_POINTER_TYPE
          and type_._tag == code.TAG_INT_TYPE
    {
        # We need to convert this pointer to an integral type.
        val = llvm.LLVMBuildPtrToInt(
            g.irb, src_val.handle, dst.handle, "" as ^int8);
    }
    else if src_han._tag == code.TAG_INT_TYPE
          and type_._tag == code.TAG_POINTER_TYPE
    {
        # We need to convert this integer to an pointer type.
        val = llvm.LLVMBuildIntToPtr(
            g.irb, src_val.handle, dst.handle, "" as ^int8);
    }

    # Wrap and return.
    code.make_value(type_, code.VC_RVALUE, val);
}
