import string;
import ast;
import libc;
import types;
import list;
import llvm;
import dict;

# Tags
# -----------------------------------------------------------------------------
# Enumeration of the `kinds` of objects a code handle may refer to.

let TAG_MODULE: int = 1;
let TAG_STATIC_SLOT: int = 2;
let TAG_TYPE: int = 3;
let TAG_VALUE: int = 4;
let TAG_INT_TYPE: int = 5;
let TAG_FLOAT_TYPE: int = 6;
let TAG_FUNCTION_TYPE: int = 7;
let TAG_FUNCTION: int = 8;
let TAG_PARAMETER: int = 9;
let TAG_BOOL_TYPE: int = 10;
let TAG_VOID_TYPE: int = 11;
let TAG_LOCAL_SLOT: int = 12;
let TAG_TUPLE_TYPE: int = 13;
let TAG_STRUCT: int = 14;
let TAG_STRUCT_TYPE: int = 15;
let TAG_MEMBER: int = 16;
let TAG_POINTER_TYPE: int = 17;
let TAG_ARRAY_TYPE: int = 18;
let TAG_EXTERN_FUNC: int = 19;
let TAG_EXTERN_STATIC: int = 20;
let TAG_CHAR_TYPE: int = 21;
let TAG_STR_TYPE: int = 23;
let TAG_ATTACHED_FUNCTION: int = 22;
let TAG_REFERENCE_TYPE: int = 24;
let TAG_TUPLE: int = 25;

# Value categories
# -----------------------------------------------------------------------------
# Enumeration of the possible value catergories: l or rvalue

let VC_LVALUE: int = 1;
let VC_RVALUE: int = 2;

# Scope chain
# -----------------------------------------------------------------------------
# This internally is a list of dictinoaries that are for managing
# the local scope of a specific function.

struct Scope {
    # The list of dictionaries that comprise the scope chain.
    chain: list.List
}

let make_scope(): Scope -> {
    let sc: Scope;
    sc.chain = list.List.new(types.PTR);
    sc;
}

let make_nil_scope(): *Scope -> { 0 as *Scope; }

implement Scope {

    # Dispose the scope chain.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> {
        # Dispose of each dict.
        let mut i: int = 0;
        while i as uint < self.chain.size {
            let m: *mut dict.Dictionary =
                self.chain.get_ptr(i) as *dict.Dictionary;
            m.dispose();
            i = i + 1;
        }

        # Dispose of the entire list.
        self.chain.dispose();
    }

    # Check if a name exists in the scope chain.
    # -------------------------------------------------------------------------
    let contains(self, name: str): bool -> {
        let mut i: int = -1;
        while i >= -(self.chain.size as int) {
            let m: *mut dict.Dictionary =
                self.chain.get_ptr(i) as *dict.Dictionary;

            if m.contains(name) {
                return true;
            };

            i = i - 1;
        }
        false;
    }

    # Get a name from the scope chain.
    # -------------------------------------------------------------------------
    let get(self, name: str): *Handle -> {
        let mut i: int = -1;
        while i >= -(self.chain.size as int) {
            let m: *mut dict.Dictionary =
                self.chain.get_ptr(i) as *dict.Dictionary;

            if m.contains(name) {
                return m.get_ptr(name) as *Handle;
            };

            i = i - 1;
        }
        make_nil();
    }

    # Insert an item into the current block in the scope chain.
    # -------------------------------------------------------------------------
    let insert(mut self, name: str, handle: *Handle) -> {
        # Get the current block.
        let m: *mut dict.Dictionary =
            self.chain.get_ptr(-1) as *dict.Dictionary;

        # Push in the handle.
        m.set_ptr(name, handle as *int8);
    }

    # Push another scope into the chain.
    # -------------------------------------------------------------------------
    let push(mut self) -> {
        let m: *mut dict.Dictionary = libc.malloc(
            (((0 as *dict.Dictionary) + 1) - (0 as *dict.Dictionary)) as int64)
            as *dict.Dictionary;
        *m = dict.make(2048);
        self.chain.push_ptr(m as *int8);
    }

    # Pop a scope from the chain.
    # -------------------------------------------------------------------------
    let pop(mut self) -> {
        let m: *mut dict.Dictionary =
            self.chain.get_ptr(-1) as *dict.Dictionary;

        m.dispose();
        self.chain.erase(-1);
    }

}

# Type
# -----------------------------------------------------------------------------
# A basic struct just remembers what its llvm handle is.

struct Type {
    handle: *llvm.LLVMOpaqueType,
    bits: int64
}

struct IntegerType {
    handle: *llvm.LLVMOpaqueType,
    bits: int64,
    signed: bool,
    machine: bool
}

struct FloatType {
    handle: *llvm.LLVMOpaqueType,
    bits: int64
}

let make_type(handle: *llvm.LLVMOpaqueType): *Handle -> {
    # Build the module.
    let ty: *Type = libc.malloc(size_of(Type)) as *Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_TYPE, ty as *int8);
}

let make_void_type(handle: *llvm.LLVMOpaqueType): *Handle -> {
    # Build the module.
    let ty: *Type = libc.malloc(size_of(Type)) as *Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_VOID_TYPE, ty as *int8);
}

let make_float_type(handle: *llvm.LLVMOpaqueType, bits: int64): *Handle -> {
    # Build the module.
    let ty: *FloatType = libc.malloc(size_of(FloatType)) as *FloatType;
    ty.handle = handle;
    ty.bits = bits;

    # Wrap in a handle.
    make(TAG_FLOAT_TYPE, ty as *int8);
}

let make_bool_type(handle: *llvm.LLVMOpaqueType): *Handle -> {
    # Build the module.
    let ty: *Type = libc.malloc(size_of(Type)) as *Type;
    ty.handle = handle;
    ty.bits = 0;  # FIXME: Get the size of this struct using sizeof.

    # Wrap in a handle.
    make(TAG_BOOL_TYPE, ty as *int8);
}

let make_char_type(): *Handle -> {
    # Build the module.
    let ty: *Type = libc.malloc(size_of(Type)) as *Type;
    ty.handle = llvm.LLVMInt32Type();
    ty.bits = 0;  # FIXME: Get the size of this struct using sizeof.

    # Wrap in a handle.
    make(TAG_CHAR_TYPE, ty as *int8);
}

let make_str_type(): *Handle -> {
    # Build the module.
    let ty: *Type = libc.malloc(size_of(Type)) as *Type;
    ty.handle = llvm.LLVMPointerType(llvm.LLVMInt8Type(), 0);
    ty.bits = 0;  # FIXME: Get the size of this struct using sizeof.

    # Wrap in a handle.
    make(TAG_STR_TYPE, ty as *int8);
}

let make_int_type(handle: *llvm.LLVMOpaqueType, signed: bool,
                  bits: int64, machine: bool): *Handle -> {
    # Build the module.
    let ty = libc.malloc(size_of(IntegerType)) as *IntegerType;
    ty.handle = handle;
    ty.signed = signed;
    ty.bits = bits;
    ty.machine = machine;

    # Wrap in a handle.
    make(TAG_INT_TYPE, ty as *int8);
}

let typename(handle: *Handle): string.String -> {
    let ty: *Type = handle._object as *Type;

    # Allocate some space for the name.
    let mut name: string.String = string.String.new();

    # Figure out what we are.
    if      handle._tag == TAG_VOID_TYPE { name.extend("nothing"); }
    else if handle._tag == TAG_BOOL_TYPE { name.extend("bool"); }
    else if handle._tag == TAG_CHAR_TYPE { name.extend("char"); }
    else if handle._tag == TAG_STR_TYPE  { name.extend("str"); }
    else if handle._tag == TAG_INT_TYPE {
        let int_ty: *IntegerType = handle._object as *IntegerType;
        if not int_ty.signed { name.append('u'); };
        name.extend("int");
        if not int_ty.machine
        {
            if      int_ty.bits ==   8 { name.extend(  "8"); }
            else if int_ty.bits ==  16 { name.extend( "16"); }
            else if int_ty.bits ==  32 { name.extend( "32"); }
            else if int_ty.bits ==  64 { name.extend( "64"); }
            else if int_ty.bits == 128 { name.extend("128"); };
            0; # HACK!
        };
        0; # HACK!
    } else if handle._tag == TAG_FLOAT_TYPE {
        let f_ty: *FloatType = handle._object as *FloatType;
        name.extend("float");
        if      f_ty.bits == 32 { name.extend("32"); }
        else if f_ty.bits == 64 { name.extend("64"); };
    } else if handle._tag == TAG_STRUCT_TYPE {
        let s_ty: *StructType = handle._object as *StructType;
        name.extend(s_ty.name.data() as str);
    } else if handle._tag == TAG_POINTER_TYPE {
        let p_ty: *PointerType = handle._object as *PointerType;
        name.append("*");
        let mut ptr_name: string.String = typename(p_ty.pointee);
        name.extend(ptr_name.data() as str);
        ptr_name.dispose();
        0; # HACK!
    } else if handle._tag == TAG_REFERENCE_TYPE {
        let p_ty: *ReferenceType = handle._object as *ReferenceType;
        name.append("&");
        let mut ptr_name: string.String = typename(p_ty.pointee);
        name.extend(ptr_name.data() as str);
        ptr_name.dispose();
        0; # HACK!
    } else if handle._tag == TAG_ARRAY_TYPE {
        let a_ty: *ArrayType = handle._object as *ArrayType;
        let mut el_name: string.String = typename(a_ty.element);
        name.extend(el_name.data() as str);
        el_name.dispose();
        name.append("[");

        let len: uint = llvm.LLVMGetArrayLength(a_ty.handle);
        let int_: int8[100];
        libc.memset(&int_[0] as *int8, 0, 100);
        libc.snprintf(&int_[0] as str, 100, "%d", len);
        name.extend(&int_[0] as str);

        name.append("]");
    } else if handle._tag == TAG_TUPLE_TYPE {
        let tup_ty: *TupleType = handle._object as *TupleType;
        name.append("(");

        let mut i: int = 0;
        while i as uint < tup_ty.elements.size {
            let han: *Handle = tup_ty.elements.get_ptr(i) as *Handle;
            let mut e_name: string.String = typename(han);
            if i > 0 { name.extend(", "); };
            name.extend(e_name.data() as str);
            e_name.dispose();
            i = i + 1;
        }

        if i == 1 { name.append(","); };

        name.append(")");
    } else if handle._tag == TAG_FUNCTION_TYPE {
        let fn_ty: *FunctionType = handle._object as *FunctionType;
        name.extend("delegate(");

        let mut i: int = 0;
        while i as uint < fn_ty.parameters.size {
            let param_han: *Handle = fn_ty.parameters.get_ptr(i) as *Handle;
            let param: *Parameter = param_han._object as *Parameter;
            let mut p_name: string.String = typename(param.type_);
            if i > 0 { name.extend(", "); };
            name.extend(p_name.data() as str);
            p_name.dispose();
            i = i + 1;
        }

        name.append(")");

        if not isnil(fn_ty.return_type) {
            if fn_ty.return_type._tag != TAG_VOID_TYPE {
                name.extend(" -> ");
                let mut ret_name: string.String = typename(fn_ty.return_type);
                name.extend(ret_name.data() as str);
                ret_name.dispose();
            };
        };
    };

    # Return the name.
    name;
}

# Pointer type
# -----------------------------------------------------------------------------

struct PointerType {
    handle: *llvm.LLVMOpaqueType,
    bits: int64,
    mutable: bool,
    pointee: *Handle
}

let make_pointer_type(pointee: *Handle, mutable: bool, handle: *llvm.LLVMOpaqueType): *Handle -> {
    # Build the parameter.
    let han: *PointerType = libc.malloc(size_of(PointerType)) as *PointerType;
    han.handle = handle;
    han.mutable = mutable;
    han.pointee = pointee;
    han.bits = 0;  # FIXME: Get the actual size of this struct with sizeof

    # Wrap in a handle.
    make(TAG_POINTER_TYPE, han as *int8);
}

# Reference type
# -----------------------------------------------------------------------------

struct ReferenceType {
    handle: *llvm.LLVMOpaqueType,
    bits: int64,
    mutable: bool,
    pointee: *Handle
}

let make_reference_type(pointee: *Handle, mutable: bool, handle: *llvm.LLVMOpaqueType): *Handle -> {
    # Build the parameter.
    let han: *ReferenceType = libc.malloc(size_of(ReferenceType)) as *ReferenceType;
    han.handle = handle;
    han.mutable = mutable;
    han.pointee = pointee;
    han.bits = 0;  # FIXME: Get the actual size of this struct with sizeof

    # Wrap in a handle.
    make(TAG_REFERENCE_TYPE, han as *int8);
}

# Array type
# -----------------------------------------------------------------------------

struct ArrayType {
    handle: *llvm.LLVMOpaqueType,
    bits: int64,
    element: *Handle,
    size: uint
}

let make_array_type(element: *Handle, size: uint, handle: *llvm.LLVMOpaqueType): *Handle -> {
    # Build the parameter.
    let han: *ArrayType = libc.malloc(size_of(ArrayType)) as *ArrayType;
    han.handle = handle;
    han.element = element;
    han.bits = 0;  # FIXME: Get the actual size of this struct with sizeof
    han.size = size;

    # Wrap in a handle.
    make(TAG_ARRAY_TYPE, han as *int8);
}

# Function type
# -----------------------------------------------------------------------------
# A function struct needs to remember its return struct and its parameters.

struct Parameter {
    name: string.String,
    type_: *mut Handle,
    default: *mut Handle,
    variadic: bool
}

struct FunctionType {
    handle: *llvm.LLVMOpaqueType,
    bits: int64,
    name: string.String,
    unqualified_name: string.String,
    namespace: list.List,
    return_type: *mut Handle,
    parameters: list.List,
    parameter_map: dict.Dictionary
}

let make_parameter(name: str, type_: *Handle,
                   default: *Handle, variadic: bool): *Handle -> {
    # Build the parameter.
    let param: *Parameter = libc.malloc(size_of(Parameter)) as *Parameter;
    param.name = string.String.new();
    if not string.isnil(name) {
        param.name.extend(name);
    };
    param.type_ = type_;
    param.default = default;
    param.variadic = variadic;

    # Wrap in a handle.
    make(TAG_PARAMETER, param as *int8);
}

let make_function_type(
        name: str,
        mut namespace: list.List,
        mut unqualified_name: str,
        handle: *llvm.LLVMOpaqueType,
        return_type: *Handle,
        parameters: list.List): *Handle -> {
    # Build the function.
    let func: *FunctionType = libc.malloc(size_of(FunctionType)) as *FunctionType;
    func.handle = handle;
    func.name = string.String.new();
    func.namespace = namespace.clone();
    func.name.extend(name);
    func.unqualified_name = string.String.new();
    func.unqualified_name.extend(unqualified_name);
    func.return_type = return_type;
    func.parameters = parameters.clone();
    func.parameter_map = dict.make(64);
    func.bits = 0;  # FIXME: Get the size of this struct with sizeof

    # Fill the named parameter map.
    let mut idx: int = 0;
    while idx as uint < parameters.size
    {
        let param_han: *Handle = parameters.get_ptr(idx) as *Handle;
        let param: *Parameter = param_han._object as *Parameter;
        if param.name.size() > 0 {
            func.parameter_map.set_uint(param.name.data() as str, idx as uint);
        };
        idx = idx + 1;
    }

    # Wrap in a handle.
    make(TAG_FUNCTION_TYPE, func as *int8);
}

# Structure type
# -----------------------------------------------------------------------------

struct Member {
    name: string.String,
    type_: *mut Handle,
    index: uint,
    default: *mut Handle
}

struct StructType {
    handle: *llvm.LLVMOpaqueType,
    bits: int64,
    context: *ast.Struct,
    name: string.String,
    namespace: list.List,
    members: list.List,
    member_map: dict.Dictionary
}

let make_member(name: str, type_: *Handle, index: uint, default: *Handle): *Handle -> {
    # Build the parameter.
    let mem: *Member = libc.malloc(size_of(Member)) as *Member;
    mem.name = string.String.new();
    mem.name.extend(name);
    mem.type_ = type_;
    mem.index = index;
    mem.default = default;

    # Wrap in a handle.
    make(TAG_MEMBER, mem as *int8);
}

let make_struct_type(name: str,
                     context: *ast.Struct,
                     namespace: list.List,
                     handle: *llvm.LLVMOpaqueType): *Handle -> {
    # Build the function.
    let st: *StructType = libc.malloc(size_of(StructType)) as *StructType;
    st.handle = handle;
    st.context = context;
    st.name = string.String.new();
    st.name.extend(name);
    st.namespace = namespace.clone();
    st.member_map = dict.make(64);
    st.bits = 0;  # FIXME: Get the size of this struct with sizeof.

    # Wrap in a handle.
    make(TAG_STRUCT_TYPE, st as *int8);
}

# Tuple type
# -----------------------------------------------------------------------------

struct TupleType {
    handle: *llvm.LLVMOpaqueType,
    bits: int64,
    elements: list.List
}

let make_tuple_type(
        handle: *llvm.LLVMOpaqueType,
        elements: list.List): *Handle -> {
    # Build the tuple.
    let func: *TupleType = libc.malloc(size_of(TupleType)) as *TupleType;
    func.handle = handle;
    func.elements = elements.clone();
    func.bits = 0;  # FIXME: Get the size of this struct with sizeof.

    # Wrap in a handle.
    make(TAG_TUPLE_TYPE, func as *int8);
}

# Gets if this handle is a type.
# -----------------------------------------------------------------------------
let is_type(handle: *Handle): bool -> {
    handle._tag == TAG_TYPE or
    handle._tag == TAG_BOOL_TYPE or
    handle._tag == TAG_CHAR_TYPE or
    handle._tag == TAG_STR_TYPE or
    handle._tag == TAG_FUNCTION_TYPE or
    handle._tag == TAG_INT_TYPE or
    handle._tag == TAG_TUPLE_TYPE or
    handle._tag == TAG_STRUCT_TYPE or
    handle._tag == TAG_POINTER_TYPE or
    handle._tag == TAG_REFERENCE_TYPE or
    handle._tag == TAG_FLOAT_TYPE or
    handle._tag == TAG_ARRAY_TYPE;
}

# Gets the struct of the thing.
# -----------------------------------------------------------------------------
let type_of(handle: *Handle): *Handle -> {
    if handle._tag == TAG_STATIC_SLOT {
        let slot: *StaticSlot = handle._object as *StaticSlot;
        return slot.type_;
        0; # HACK!
    } else if handle._tag == TAG_LOCAL_SLOT {
        let slot: *LocalSlot = handle._object as *LocalSlot;
        return slot.type_;
        0; # HACK!
    } else if handle._tag == TAG_VALUE {
        let val: *Value = handle._object as *Value;
        return val.type_;
        0; # HACK!
    } else if handle._tag == TAG_PARAMETER {
        let val: *Parameter = handle._object as *Parameter;
        return val.type_;
        0; # HACK!
    } else if handle._tag == TAG_STRUCT {
        let val: *Struct = handle._object as *Struct;
        return val.type_;
        0; # HACK!
    } else if handle._tag == TAG_MEMBER {
        let mem: *Member = handle._object as *Member;
        return mem.type_;
        0; # HACK!
    } else if handle._tag == TAG_ATTACHED_FUNCTION {
        let val: *Function = handle._object as *Function;
        return val.type_;
        0; # HACK!
    } else if handle._tag == TAG_TUPLE {
        let val: *Tuple = handle._object as *Tuple;
        return val.type_;
        0; # HACK!
    };
    return make_nil();
}

# Static Slot
# -----------------------------------------------------------------------------
# A slot keeps its name with it for now. It'll contain later its struct and
# other designators.

struct StaticSlot {
    context: *ast.SlotDecl,
    name: string.String,
    namespace: list.List,
    qualified_name: string.String,
    type_: *Handle,
    handle: *llvm.LLVMOpaqueValue
}

let make_static_slot(
        context: *ast.SlotDecl,
        name: str,
        namespace: list.List,
        type_: *Handle,
        handle: *llvm.LLVMOpaqueValue): *Handle -> {
    # Build the slot.
    let slot: *StaticSlot = libc.malloc(size_of(StaticSlot)) as *StaticSlot;
    slot.context = context;
    slot.name = string.String.new();
    slot.name.extend(name);
    slot.namespace = namespace.clone();
    slot.qualified_name = string.join(".", slot.namespace);
    slot.qualified_name.append(".");
    slot.qualified_name.extend(name);
    slot.handle = handle;
    slot.type_ = type_;

    # Wrap in a handle.
    make(TAG_STATIC_SLOT, slot as *int8);
}

implement StaticSlot {

    # Dispose the slot and its resources.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> { self.name.dispose(); }

}

# Local Slot
# -----------------------------------------------------------------------------

struct LocalSlot {
    type_: *Handle,
    handle: *llvm.LLVMOpaqueValue,
    mutable: bool
}

let make_local_slot(
        type_: *Handle,
        mutable: bool,
        handle: *llvm.LLVMOpaqueValue): *Handle -> {
    # Build the slot.
    let slot: *LocalSlot = libc.malloc(size_of(LocalSlot)) as *LocalSlot;
    slot.handle = handle;
    slot.type_ = type_;
    slot.mutable = mutable;

    # Wrap in a handle.
    make(TAG_LOCAL_SLOT, slot as *int8);
}

# Structure
# -----------------------------------------------------------------------------

struct Struct {
    context: *ast.Struct,
    name: string.String,
    namespace: list.List,
    qualified_name: string.String,
    type_: *Handle,
    handle: *llvm.LLVMOpaqueValue
}

let make_struct(
        context: *ast.Struct,
        name: str,
        namespace: list.List,
        type_: *Handle,
        handle: *llvm.LLVMOpaqueValue): *Handle -> {
    # Build the item.
    let item: *Struct = libc.malloc(size_of(Struct)) as *Struct;
    item.context = context;
    item.name = string.String.new();
    item.name.extend(name);
    item.namespace = namespace.clone();
    item.qualified_name = string.join(".", item.namespace);
    item.qualified_name.append(".");
    item.qualified_name.extend(name);
    item.handle = handle;
    item.type_ = type_;

    # Wrap in a handle.
    make(TAG_STRUCT, item as *int8);
}


implement Struct {

    # Dispose the item and its resources.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> {
        self.name.dispose();
        self.namespace.dispose();
    }

}

# Tuple
# -----------------------------------------------------------------------------

struct Tuple {
    type_: *Handle,
    handles: list.List,
    assignable: bool
}

let make_tuple(type_: *Handle, handles: list.List, assignable: bool): *Handle ->
{
    # Build the module.
    let tup: *Tuple = libc.malloc(size_of(Tuple)) as *Tuple;
    tup.type_ = type_;
    tup.handles = handles.clone();
    tup.assignable = assignable;

    # Wrap in a handle.
    make(TAG_TUPLE, tup as *int8);
}

# Module
# -----------------------------------------------------------------------------
# A module just keeps its name with it. Its purpose in the scope is
# to allow name resolution.

struct Module {
    name: string.String,
    namespace: list.List,
    qualified_name: string.String
}

let make_module(
        name: str,
        namespace: list.List): *Handle -> {
    # Build the module.
    let mod: *Module = libc.malloc(size_of(Module)) as *Module;
    mod.name = string.String.new();
    mod.name.extend(name);
    mod.namespace = namespace.clone();
    mod.qualified_name = string.join(".", mod.namespace);
    mod.qualified_name.append(".");
    mod.qualified_name.extend(name);

    # Wrap in a handle.
    make(TAG_MODULE, mod as *int8);
}

implement Module {

    # Dispose the module and its resources.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> { self.name.dispose(); }

}

# Value
# -----------------------------------------------------------------------------
# A value remembers its struct and the llvm handle.

struct Value {
    type_: *Handle,
    handle: *llvm.LLVMOpaqueValue,
    category: int
}

let make_value_c(context: *ast.Node,
                 type_: *Handle,
                 category: int,
                 handle: *llvm.LLVMOpaqueValue): *Handle -> {
    # Build the module.
    let val: *Value = libc.malloc(size_of(Value)) as *Value;
    val.handle = handle;
    val.type_ = type_;
    val.category = category;

    # Wrap in a handle.
    make_c(context, TAG_VALUE, val as *int8);
}


let make_value(type_: *Handle,
               category: int,
               handle: *llvm.LLVMOpaqueValue): *Handle -> {
    make_value_c(0 as *ast.Node, type_, category, handle);
}

# Function
# -----------------------------------------------------------------------------

struct Function {
    context: *ast.FuncDecl,
    handle: *llvm.LLVMOpaqueValue,
    namespace: list.List,
    name: string.String,
    qualified_name: string.String,
    type_: *mut Handle,
    scope: Scope
}

let make_function(
        context: *ast.FuncDecl,
        name: str,
        namespace: list.List,
        type_: *Handle,
        handle: *llvm.LLVMOpaqueValue): *Handle -> {
    # Build the function.
    let func: *Function = libc.malloc(size_of(Function)) as *Function;
    func.context = context;
    func.handle = handle;
    func.name = string.String.new();
    func.name.extend(name);
    func.namespace = namespace.clone();
    func.qualified_name = string.join(".", func.namespace);
    func.qualified_name.append(".");
    func.qualified_name.extend(name);
    func.type_ = type_;
    func.scope = make_scope();

    # Push the top scope block for the function.
    func.scope.push();

    # Wrap in a handle.
    make(TAG_FUNCTION, func as *int8);
}

# Attached function
# -----------------------------------------------------------------------------

struct AttachedFunction {
    context: *ast.FuncDecl,
    handle: *llvm.LLVMOpaqueValue,
    namespace: list.List,
    name: string.String,
    qualified_name: string.String,
    type_: *mut Handle,
    scope: Scope,
    attached_type: *mut Handle,
    attached_type_node: *ast.Node
}

let make_attached_function(
        context: *ast.FuncDecl,
        name: str,
        namespace: list.List,
        attached_type_node: *ast.Node): *Handle -> {
    # Build the function.
    let func: *AttachedFunction = libc.malloc(size_of(AttachedFunction)) as *AttachedFunction;
    func.context = context;
    func.handle = 0 as *llvm.LLVMOpaqueValue;
    func.name = string.String.new();
    func.name.extend(name);
    func.namespace = namespace.clone();
    # func.qualified_name = string.join(".", func.namespace);
    # func.qualified_name.append(".");
    # func.qualified_name.extend(name);
    func.type_ = make_nil();
    func.scope = make_scope();
    func.attached_type = make_nil();
    func.attached_type_node = attached_type_node;

    # Push the top scope block for the function.
    func.scope.push();

    # Wrap in a handle.
    make(TAG_ATTACHED_FUNCTION, func as *int8);
}

# External static
# -----------------------------------------------------------------------------

struct ExternStatic {
    context: *ast.ExternStaticSlot,
    name: string.String,
    namespace: list.List,
    qualified_name: string.String,
    type_: *mut Handle,
    handle: *llvm.LLVMOpaqueValue
}

let make_extern_static(
        context: *ast.ExternStaticSlot,
        name: str,
        namespace: list.List,
        type_: *Handle,
        handle: *llvm.LLVMOpaqueValue): *Handle -> {
    # Build the function.
    let slot: *ExternStatic = libc.malloc(size_of(ExternStatic)) as *ExternStatic;
    slot.context = context;
    slot.handle = handle;
    slot.name = string.String.new();
    slot.name.extend(name);
    slot.namespace = namespace.clone();
    slot.qualified_name = string.join(".", slot.namespace);
    slot.qualified_name.append(".");
    slot.qualified_name.extend(name);
    slot.type_ = type_;

    # Wrap in a handle.
    make(TAG_EXTERN_STATIC, slot as *int8);
}

# External function
# -----------------------------------------------------------------------------

struct ExternFunction {
    context: *ast.ExternFunc,
    handle: *llvm.LLVMOpaqueValue,
    namespace: list.List,
    name: string.String,
    qualified_name: string.String,
    type_: *mut Handle
}

let make_extern_function(
        context: *ast.ExternFunc,
        name: str,
        namespace: list.List,
        type_: *Handle,
        handle: *llvm.LLVMOpaqueValue): *Handle -> {
    # Build the function.
    let func: *ExternFunction = libc.malloc(size_of(ExternFunction)) as *ExternFunction;
    func.context = context;
    func.handle = handle;
    func.name = string.String.new();
    func.name.extend(name);
    func.namespace = namespace.clone();
    func.qualified_name = string.join(".", func.namespace);
    func.qualified_name.append(".");
    func.qualified_name.extend(name);
    func.type_ = type_;

    # Wrap in a handle.
    make(TAG_EXTERN_FUNC, func as *int8);
}

# Handle
# -----------------------------------------------------------------------------
# A handle is an intermediary `handle` to a pre-code-generation object such
# as a module, a temporary value, a function, etc.
#
# Handles are strictly allocated on the heap and calling dispose on them
# frees their memory.

struct Handle {
    _context: *ast.Node,
    _tag: int,
    _object: *int8
}

# let HANDLE_SIZE: uint = ((0 as *Handle) + 1) - (0 as *Handle);

implement Handle {
    let _dispose(mut self) -> { dispose(&self); }
}

implement Function { # HACK: Re-arrange when we can.

    # Dispose the function and its resources.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> {
        # Dispose of the type.
        self.type_._dispose();

        # Dispose of the name.
        self.name.dispose();
    }

}

implement FunctionType { # HACK: Re-arrange when we can.

    # Dispose the function and its resources.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> {
        # Dispose of each parameter.
        let mut i: uint = 0;
        while i < self.parameters.size {
            let param_han: *mut Handle =
                self.parameters.get_ptr(i as int) as *Handle;

            param_han._dispose();
            i = i + 1;
        }

        # Dispose of the parameter list and map.
        self.parameters.dispose();
        self.parameter_map.dispose();
    }

}

implement Parameter { # HACK: Re-arrange when we can.

    # Dispose the parameter and its resources.
    # -------------------------------------------------------------------------
    let dispose(mut self) -> {
        self.name.dispose();
        self.default._dispose();
    }

}

# Dispose the handle and its bound object.
# -----------------------------------------------------------------------------
let dispose(this: *Handle) -> {
    # Return if we are nil.
    if isnil(this) { return; };

    # Dispose the object (if we need to).
    if this._tag == TAG_MODULE {
        let mod: *mut Module = (this._object as *Module);
        mod.dispose();
        0;  #HACK!
    } else if this._tag == TAG_STATIC_SLOT {
        let slot: *mut StaticSlot = (this._object as *StaticSlot);
        slot.dispose();
        0;  #HACK!
    } else if this._tag == TAG_FUNCTION {
        let fn: *mut Function = (this._object as *Function);
        fn.dispose();
        0;  #HACK!
    } else if this._tag == TAG_FUNCTION_TYPE {
        let fn: *mut FunctionType = (this._object as *FunctionType);
        fn.dispose();
        0;  #HACK!
    } else if this._tag == TAG_PARAMETER {
        let p: *mut Parameter = (this._object as *Parameter);
        p.dispose();
        0;  #HACK!
    } else if this._tag == TAG_TYPE {
        let p: *mut Struct = (this._object as *Struct);
        p.dispose();
        0;  #HACK!
    };

    # Free the object.
    libc.free(this._object);
    if this._object != 0 as *int8 {
        # Free ourself.
        libc.free(this as *int8);
    };

    # Remember.
    this._object = 0 as *int8;
}

# Create a handle allocation
# -----------------------------------------------------------------------------
let make(tag: int, object: *int8): *Handle -> {
    make_c(0 as *ast.Node, tag, object);
}

let make_c(context: *ast.Node, tag: int, object: *int8): *Handle -> {
    let handle: *Handle = libc.malloc(size_of(Handle)) as *Handle;
    handle._tag = tag;
    handle._object = object;
    handle._context = context;
    handle;
}

# Create a NIL handle that is used to indicate a null generation.
# -----------------------------------------------------------------------------
let make_nil(): *Handle -> { 0 as *Handle; }

# Test for a NIL handle.
# -----------------------------------------------------------------------------
let isnil(handle: *Handle): bool -> {
    (handle == 0 as *Handle) or ispoison(handle);
}

# Create a POISON handle that is used to indicate a failed generation.
# -----------------------------------------------------------------------------
let make_poison(): *Handle -> { -1 as *Handle; }

# Test for a POISON handle.
# -----------------------------------------------------------------------------
let ispoison(handle: *Handle): bool -> { handle == -1 as *Handle; }
