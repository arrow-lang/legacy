foreign "C" import "llvm-c/Core.h";

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

# Value categories
# -----------------------------------------------------------------------------
# Enumeration of the possible value catergories: l or rvalue

let VC_LVALUE: int = 1;
let VC_RVALUE: int = 2;

# Scope chain
# -----------------------------------------------------------------------------
# This internally is a list of dictinoaries that are for managing
# the local scope of a specific function.

type Scope {
    # The list of dictionaries that comprise the scope chain.
    mut chain: list.List
}

def make_scope() -> Scope {
    let sc: Scope;
    sc.chain = list.make(types.PTR);
    sc;
}

def make_nil_scope() -> ^Scope { 0 as ^Scope; }

implement Scope {

    # Dispose the scope chain.
    # -------------------------------------------------------------------------
    def dispose(&mut self) {
        # Dispose of each dict.
        let mut i: int = 0;
        while i as uint < self.chain.size {
            let m: ^mut dict.Dictionary =
                self.chain.at_ptr(i) as ^dict.Dictionary;
            (m^).dispose();
            i = i + 1;
        }

        # Dispose of the entire list.
        self.chain.dispose();
    }

    # Check if a name exists in the scope chain.
    # -------------------------------------------------------------------------
    def contains(&self, name: str) -> bool {
        let mut i: int = -1;
        while i >= -(self.chain.size as int) {
            let m: ^mut dict.Dictionary =
                self.chain.at_ptr(i) as ^dict.Dictionary;

            if (m^).contains(name) {
                return true;
            }

            i = i - 1;
        }
        false;
    }

    # Get a name from the scope chain.
    # -------------------------------------------------------------------------
    def get(&self, name: str) -> ^Handle {
        let mut i: int = -1;
        while i >= -(self.chain.size as int) {
            let m: ^mut dict.Dictionary =
                self.chain.at_ptr(i) as ^dict.Dictionary;

            if (m^).contains(name) {
                return (m^).get_ptr(name) as ^Handle;
            }

            i = i - 1;
        }
        make_nil();
    }

    # Insert an item into the current block in the scope chain.
    # -------------------------------------------------------------------------
    def insert(&mut self, name: str, handle: ^Handle) {
        # Get the current block.
        let m: ^mut dict.Dictionary =
            self.chain.at_ptr(-1) as ^dict.Dictionary;

        # Push in the handle.
        (m^).set_ptr(name, handle as ^void);
    }

    # Push another scope into the chain.
    # -------------------------------------------------------------------------
    def push(&mut self) {
        let m: ^mut dict.Dictionary = libc.malloc(
            (((0 as ^dict.Dictionary) + 1) - (0 as ^dict.Dictionary)) as int64)
            as ^dict.Dictionary;
        m^ = dict.make(2048);
        self.chain.push_ptr(m as ^void);
    }

    # Pop a scope from the chain.
    # -------------------------------------------------------------------------
    def pop(&mut self) {
        let m: ^mut dict.Dictionary =
            self.chain.at_ptr(-1) as ^dict.Dictionary;

        (m^).dispose();
        self.chain.erase(-1);
    }

}

# Type
# -----------------------------------------------------------------------------
# A basic type just remembers what its llvm handle is.

type Type {
    handle: ^LLVMOpaqueType,
    bits: int64
}

type IntegerType {
    handle: ^LLVMOpaqueType,
    bits: int64,
    signed: bool,
    machine: bool
}

type FloatType {
    handle: ^LLVMOpaqueType,
    bits: int64
}

let TYPE_SIZE: uint = ((0 as ^Type) + 1) - (0 as ^Type);
let INT_TYPE_SIZE: uint = ((0 as ^IntegerType) + 1) - (0 as ^IntegerType);
let FLOAT_TYPE_SIZE: uint = ((0 as ^FloatType) + 1) - (0 as ^FloatType);

def make_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE as int64) as ^Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_TYPE, ty as ^void);
}

def make_void_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE as int64) as ^Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_VOID_TYPE, ty as ^void);
}

def make_float_type(handle: ^LLVMOpaqueType, bits: int64) -> ^Handle {
    # Build the module.
    let ty: ^FloatType = libc.malloc(FLOAT_TYPE_SIZE as int64) as ^FloatType;
    ty.handle = handle;
    ty.bits = bits;

    # Wrap in a handle.
    make(TAG_FLOAT_TYPE, ty as ^void);
}

def make_bool_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE as int64) as ^Type;
    ty.handle = handle;
    ty.bits = 0;  # FIXME: Get the size of this type using sizeof.

    # Wrap in a handle.
    make(TAG_BOOL_TYPE, ty as ^void);
}

def make_char_type() -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE as int64) as ^Type;
    ty.handle = LLVMInt32Type();
    ty.bits = 0;  # FIXME: Get the size of this type using sizeof.

    # Wrap in a handle.
    make(TAG_CHAR_TYPE, ty as ^void);
}

def make_str_type() -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE as int64) as ^Type;
    ty.handle = LLVMPointerType(LLVMInt8Type(), 0);
    ty.bits = 0;  # FIXME: Get the size of this type using sizeof.

    # Wrap in a handle.
    make(TAG_STR_TYPE, ty as ^void);
}

def make_int_type(handle: ^LLVMOpaqueType, signed: bool,
                  bits: int64, machine: bool) -> ^Handle {
    # Build the module.
    let ty: ^IntegerType = libc.malloc(INT_TYPE_SIZE as int64) as ^IntegerType;
    ty.handle = handle;
    ty.signed = signed;
    ty.bits = bits;
    ty.machine = machine;

    # Wrap in a handle.
    make(TAG_INT_TYPE, ty as ^void);
}

def typename(handle: ^Handle) -> string.String {
    let ty: ^Type = handle._object as ^Type;

    # Allocate some space for the name.
    let mut name: string.String = string.make();

    # Figure out what we are.
    if      handle._tag == TAG_VOID_TYPE { name.extend("nothing"); }
    else if handle._tag == TAG_BOOL_TYPE { name.extend("bool"); }
    else if handle._tag == TAG_CHAR_TYPE { name.extend("char"); }
    else if handle._tag == TAG_STR_TYPE  { name.extend("str"); }
    else if handle._tag == TAG_INT_TYPE {
        let int_ty: ^IntegerType = handle._object as ^IntegerType;
        if not int_ty.signed { name.append('u'); }
        name.extend("int");
        if not int_ty.machine
        {
            if      int_ty.bits ==   8 { name.extend(  "8"); }
            else if int_ty.bits ==  16 { name.extend( "16"); }
            else if int_ty.bits ==  32 { name.extend( "32"); }
            else if int_ty.bits ==  64 { name.extend( "64"); }
            else if int_ty.bits == 128 { name.extend("128"); }
        }
    } else if handle._tag == TAG_FLOAT_TYPE {
        let f_ty: ^FloatType = handle._object as ^FloatType;
        name.extend("float");
        if      f_ty.bits == 32 { name.extend("32"); }
        else if f_ty.bits == 64 { name.extend("64"); }
    } else if handle._tag == TAG_STRUCT_TYPE {
        let s_ty: ^StructType = handle._object as ^StructType;
        name.extend(s_ty.name.data() as str);
    } else if handle._tag == TAG_POINTER_TYPE {
        let p_ty: ^PointerType = handle._object as ^PointerType;
        name.append("*");
        let mut ptr_name: string.String = typename(p_ty.pointee);
        name.extend(ptr_name.data() as str);
        ptr_name.dispose();
    } else if handle._tag == TAG_REFERENCE_TYPE {
        let p_ty: ^ReferenceType = handle._object as ^ReferenceType;
        name.append("&");
        let mut ptr_name: string.String = typename(p_ty.pointee);
        name.extend(ptr_name.data() as str);
        ptr_name.dispose();
    } else if handle._tag == TAG_ARRAY_TYPE {
        let a_ty: ^ArrayType = handle._object as ^ArrayType;
        let mut el_name: string.String = typename(a_ty.element);
        name.extend(el_name.data() as str);
        el_name.dispose();
        name.append("[");

        let len: uint = LLVMGetArrayLength(a_ty.handle);
        let int_: int8[100];
        libc.memset(&int_[0] as ^void, 0, 100);
        libc.snprintf(&int_[0], 100, "%d" as ^int8, len);
        name.extend(&int_[0] as str);

        name.append("]");
    } else if handle._tag == TAG_FUNCTION_TYPE {
        let fn_ty: ^FunctionType = handle._object as ^FunctionType;
        name.extend("delegate(");

        let mut i: int = 0;
        while i as uint < fn_ty.parameters.size {
            let param_han: ^Handle = fn_ty.parameters.at_ptr(i) as ^Handle;
            let param: ^Parameter = param_han._object as ^Parameter;
            let mut p_name: string.String = typename(param.type_);
            if i > 0 { name.append(","); }
            name.extend(p_name.data() as str);
            p_name.dispose();
            i = i + 1;
        }

        name.append(")");

        if not isnil(fn_ty.return_type) {
            if not fn_ty.return_type._tag == TAG_VOID_TYPE {
                name.extend(" -> ");
                let mut ret_name: string.String = typename(fn_ty.return_type);
                name.extend(ret_name.data() as str);
                ret_name.dispose();
            }
        }
    }

    # Return the name.
    name;
}

# Pointer type
# -----------------------------------------------------------------------------

type PointerType {
    handle: ^LLVMOpaqueType,
    bits: int64,
    mutable: bool,
    mut pointee: ^Handle
}

let POINTER_TYPE_SIZE: uint = ((0 as ^PointerType) + 1) - (0 as ^PointerType);

def make_pointer_type(pointee: ^Handle, mutable: bool, handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the parameter.
    let han: ^PointerType = libc.malloc(POINTER_TYPE_SIZE as int64) as ^PointerType;
    han.handle = handle;
    han.mutable = mutable;
    han.pointee = pointee;
    han.bits = 0;  # FIXME: Get the actual size of this type with sizeof

    # Wrap in a handle.
    make(TAG_POINTER_TYPE, han as ^void);
}

# Reference type
# -----------------------------------------------------------------------------

type ReferenceType {
    handle: ^LLVMOpaqueType,
    bits: int64,
    mutable: bool,
    mut pointee: ^Handle
}

let REFERENCE_TYPE_SIZE: uint = ((0 as ^ReferenceType) + 1) - (0 as ^ReferenceType);

def make_reference_type(pointee: ^Handle, mutable: bool, handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the parameter.
    let han: ^ReferenceType = libc.malloc(POINTER_TYPE_SIZE as int64) as ^ReferenceType;
    han.handle = handle;
    han.mutable = mutable;
    han.pointee = pointee;
    han.bits = 0;  # FIXME: Get the actual size of this type with sizeof

    # Wrap in a handle.
    make(TAG_REFERENCE_TYPE, han as ^void);
}

# Array type
# -----------------------------------------------------------------------------

type ArrayType {
    handle: ^LLVMOpaqueType,
    bits: int64,
    mut element: ^Handle,
    size: uint
}

let ARRAY_TYPE_SIZE: uint = ((0 as ^ArrayType) + 1) - (0 as ^ArrayType);

def make_array_type(element: ^Handle, size: uint, handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the parameter.
    let han: ^ArrayType = libc.malloc(ARRAY_TYPE_SIZE as int64) as ^ArrayType;
    han.handle = handle;
    han.element = element;
    han.bits = 0;  # FIXME: Get the actual size of this type with sizeof
    han.size = size;

    # Wrap in a handle.
    make(TAG_ARRAY_TYPE, han as ^void);
}

# Function type
# -----------------------------------------------------------------------------
# A function type needs to remember its return type and its parameters.

type Parameter {
    mut name: string.String,
    type_: ^mut Handle,
    default: ^mut Handle,
    variadic: bool
}

type FunctionType {
    handle: ^LLVMOpaqueType,
    bits: int64,
    mut name: string.String,
    mut unqualified_name: string.String,
    mut namespace: list.List,
    return_type: ^mut Handle,
    mut parameters: list.List,
    mut parameter_map: dict.Dictionary
}

let PARAMETER_SIZE: uint = ((0 as ^Parameter) + 1) - (0 as ^Parameter);

let FUNCTION_TYPE_SIZE: uint = ((0 as ^FunctionType) + 1) - (0 as ^FunctionType);

def make_parameter(name: str, type_: ^Handle,
                   default: ^Handle, variadic: bool) -> ^Handle {
    # Build the parameter.
    let param: ^Parameter = libc.malloc(PARAMETER_SIZE as int64) as ^Parameter;
    param.name = string.make();
    if name <> string.Nil {
        param.name.extend(name);
    }
    param.type_ = type_;
    param.default = default;
    param.variadic = variadic;

    # Wrap in a handle.
    make(TAG_PARAMETER, param as ^void);
}

def make_function_type(
        name: str,
        mut namespace: list.List,
        mut unqualified_name: str,
        handle: ^LLVMOpaqueType,
        return_type: ^Handle,
        parameters: list.List) -> ^Handle {
    # Build the function.
    let func: ^FunctionType = libc.malloc(FUNCTION_TYPE_SIZE as int64) as ^FunctionType;
    func.handle = handle;
    func.name = string.make();
    func.namespace = namespace.clone();
    func.name.extend(name);
    func.unqualified_name = string.make();
    func.unqualified_name.extend(unqualified_name);
    func.return_type = return_type;
    func.parameters = parameters;
    func.parameter_map = dict.make(64);
    func.bits = 0;  # FIXME: Get the size of this type with sizeof

    # Fill the named parameter map.
    let mut idx: int = 0;
    while idx as uint < parameters.size
    {
        let param_han: ^Handle = parameters.at_ptr(idx) as ^Handle;
        let param: ^Parameter = param_han._object as ^Parameter;
        if param.name.size() > 0 {
            func.parameter_map.set_uint(param.name.data() as str, idx as uint);
        }
        idx = idx + 1;
    }

    # Wrap in a handle.
    make(TAG_FUNCTION_TYPE, func as ^void);
}

# Structure type
# -----------------------------------------------------------------------------

type Member {
    mut name: string.String,
    type_: ^mut Handle,
    index: uint,
    default: ^mut Handle
}

type StructType {
    handle: ^LLVMOpaqueType,
    bits: int64,
    context: ^ast.Struct,
    mut name: string.String,
    mut namespace: list.List,
    mut members: list.List,
    mut member_map: dict.Dictionary
}

let MEMBER_SIZE: uint = ((0 as ^Member) + 1) - (0 as ^Member);

let STRUCT_TYPE_SIZE: uint = ((0 as ^StructType) + 1) - (0 as ^StructType);

def make_member(name: str, type_: ^Handle, index: uint, default: ^Handle) -> ^Handle {
    # Build the parameter.
    let mem: ^Member = libc.malloc(MEMBER_SIZE as int64) as ^Member;
    mem.name = string.make();
    mem.name.extend(name);
    mem.type_ = type_;
    mem.index = index;
    mem.default = default;

    # Wrap in a handle.
    make(TAG_MEMBER, mem as ^void);
}

def make_struct_type(name: str,
                     context: ^ast.Struct,
                     namespace: list.List,
                     handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the function.
    let st: ^StructType = libc.malloc(STRUCT_TYPE_SIZE as int64) as ^StructType;
    st.handle = handle;
    st.context = context;
    st.name = string.make();
    st.name.extend(name);
    st.namespace = namespace.clone();
    st.member_map = dict.make(64);
    st.bits = 0;  # FIXME: Get the size of this type with sizeof.

    # Wrap in a handle.
    make(TAG_STRUCT_TYPE, st as ^void);
}

# Tuple type
# -----------------------------------------------------------------------------

type TupleType {
    handle: ^LLVMOpaqueType,
    bits: int64,
    mut elements: list.List
}

let TUPLE_TYPE_SIZE: uint = ((0 as ^TupleType) + 1) - (0 as ^TupleType);

def make_tuple_type(
        handle: ^LLVMOpaqueType,
        elements: list.List) -> ^Handle {
    # Build the tuple.
    let func: ^TupleType = libc.malloc(TUPLE_TYPE_SIZE as int64) as ^TupleType;
    func.handle = handle;
    func.elements = elements;
    func.bits = 0;  # FIXME: Get the size of this type with sizeof.

    # Wrap in a handle.
    make(TAG_TUPLE_TYPE, func as ^void);
}

# Gets if this handle is a type.
# -----------------------------------------------------------------------------
def is_type(handle: ^Handle) -> bool {
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

# Gets the type of the thing.
# -----------------------------------------------------------------------------
def type_of(handle: ^Handle) -> ^Handle {
    if handle._tag == TAG_STATIC_SLOT {
        let slot: ^StaticSlot = handle._object as ^StaticSlot;
        slot.type_;
    } else if handle._tag == TAG_LOCAL_SLOT {
        let slot: ^LocalSlot = handle._object as ^LocalSlot;
        slot.type_;
    } else if handle._tag == TAG_VALUE {
        let val: ^Value = handle._object as ^Value;
        val.type_;
    } else if handle._tag == TAG_PARAMETER {
        let val: ^Parameter = handle._object as ^Parameter;
        val.type_;
    } else if handle._tag == TAG_STRUCT {
        let val: ^Struct = handle._object as ^Struct;
        val.type_;
    } else if handle._tag == TAG_MEMBER {
        let mem: ^Member = handle._object as ^Member;
        mem.type_;
    } else if handle._tag == TAG_ATTACHED_FUNCTION {
        let val: ^Function = handle._object as ^Function;
        val.type_;
    } else {
        make_nil();
    }
}

# Static Slot
# -----------------------------------------------------------------------------
# A slot keeps its name with it for now. It'll contain later its type and
# other designators.

type StaticSlot {
    context: ^ast.SlotDecl,
    mut name: string.String,
    mut namespace: list.List,
    mut qualified_name: string.String,
    type_: ^Handle,
    handle: ^LLVMOpaqueValue
}

let STATIC_SLOT_SIZE: uint = ((0 as ^StaticSlot) + 1) - (0 as ^StaticSlot);

def make_static_slot(
        context: ^ast.SlotDecl,
        name: str,
        &mut namespace: list.List,
        type_: ^Handle,
        handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the slot.
    let slot: ^StaticSlot = libc.malloc(STATIC_SLOT_SIZE as int64) as ^StaticSlot;
    slot.context = context;
    slot.name = string.make();
    slot.name.extend(name);
    slot.namespace = namespace.clone();
    slot.qualified_name = string.join(".", slot.namespace);
    slot.qualified_name.append(".");
    slot.qualified_name.extend(name);
    slot.handle = handle;
    slot.type_ = type_;

    # Wrap in a handle.
    make(TAG_STATIC_SLOT, slot as ^void);
}

implement StaticSlot {

    # Dispose the slot and its resources.
    # -------------------------------------------------------------------------
    def dispose(&mut self) { self.name.dispose(); }

}

# Local Slot
# -----------------------------------------------------------------------------

type LocalSlot {
    type_: ^Handle,
    handle: ^LLVMOpaqueValue,
    mutable: bool
}

let LOCAL_SLOT_SIZE: uint = ((0 as ^LocalSlot) + 1) - (0 as ^LocalSlot);

def make_local_slot(
        type_: ^Handle,
        mutable: bool,
        handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the slot.
    let slot: ^LocalSlot = libc.malloc(LOCAL_SLOT_SIZE as int64) as ^LocalSlot;
    slot.handle = handle;
    slot.type_ = type_;
    slot.mutable = mutable;

    # Wrap in a handle.
    make(TAG_LOCAL_SLOT, slot as ^void);
}

# Structure
# -----------------------------------------------------------------------------

type Struct {
    context: ^ast.Struct,
    mut name: string.String,
    mut namespace: list.List,
    mut qualified_name: string.String,
    type_: ^Handle,
    handle: ^LLVMOpaqueValue
}

let STRUCT_SIZE: uint = ((0 as ^Struct) + 1) - (0 as ^Struct);

def make_struct(
        context: ^ast.Struct,
        name: str,
        &mut namespace: list.List,
        type_: ^Handle,
        handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the item.
    let item: ^Struct = libc.malloc(STRUCT_SIZE as int64) as ^Struct;
    item.context = context;
    item.name = string.make();
    item.name.extend(name);
    item.namespace = namespace.clone();
    item.qualified_name = string.join(".", item.namespace);
    item.qualified_name.append(".");
    item.qualified_name.extend(name);
    item.handle = handle;
    item.type_ = type_;

    # Wrap in a handle.
    make(TAG_STRUCT, item as ^void);
}


implement Struct {

    # Dispose the item and its resources.
    # -------------------------------------------------------------------------
    def dispose(&mut self) {
        self.name.dispose();
        self.namespace.dispose();
    }

}

# Module
# -----------------------------------------------------------------------------
# A module just keeps its name with it. Its purpose in the scope is
# to allow name resolution.

type Module {
    mut name: string.String,
    mut namespace: list.List,
    mut qualified_name: string.String
}

let MODULE_SIZE: uint = ((0 as ^Module) + 1) - (0 as ^Module);

def make_module(
        name: str,
        &mut namespace: list.List) -> ^Handle {
    # Build the module.
    let mod: ^Module = libc.malloc(MODULE_SIZE as int64) as ^Module;
    mod.name = string.make();
    mod.name.extend(name);
    mod.namespace = namespace.clone();
    mod.qualified_name = string.join(".", mod.namespace);
    mod.qualified_name.append(".");
    mod.qualified_name.extend(name);

    # Wrap in a handle.
    make(TAG_MODULE, mod as ^void);
}

implement Module {

    # Dispose the module and its resources.
    # -------------------------------------------------------------------------
    def dispose(&mut self) { self.name.dispose(); }

}

# Value
# -----------------------------------------------------------------------------
# A value remembers its type and the llvm handle.

type Value {
    type_: ^Handle,
    handle: ^LLVMOpaqueValue,
    category: int
}

let VALUE_SIZE: uint = ((0 as ^Value) + 1) - (0 as ^Value);

def make_value(type_: ^Handle,
               category: int,
               handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the module.
    let val: ^Value = libc.malloc(VALUE_SIZE as int64) as ^Value;
    val.handle = handle;
    val.type_ = type_;
    val.category = category;

    # Wrap in a handle.
    make(TAG_VALUE, val as ^void);
}

# Function
# -----------------------------------------------------------------------------

type Function {
    context: ^ast.FuncDecl,
    handle: ^LLVMOpaqueValue,
    mut namespace: list.List,
    mut name: string.String,
    mut qualified_name: string.String,
    mut type_: ^mut Handle,
    mut scope: Scope
}

let FUNCTION_SIZE: uint = ((0 as ^Function) + 1) - (0 as ^Function);

def make_function(
        context: ^ast.FuncDecl,
        name: str,
        &mut namespace: list.List,
        type_: ^Handle,
        handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the function.
    let func: ^Function = libc.malloc(FUNCTION_SIZE as int64) as ^Function;
    func.context = context;
    func.handle = handle;
    func.name = string.make();
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
    make(TAG_FUNCTION, func as ^void);
}

# Attached function
# -----------------------------------------------------------------------------

type AttachedFunction {
    context: ^ast.FuncDecl,
    handle: ^LLVMOpaqueValue,
    mut namespace: list.List,
    mut name: string.String,
    mut qualified_name: string.String,
    mut type_: ^mut Handle,
    mut scope: Scope,
    mut attached_type: ^mut Handle,
    mut attached_type_node: ^ast.Node
}

let ATTACHED_FUNCTION_SIZE: uint = ((0 as ^AttachedFunction) + 1) - (0 as ^AttachedFunction);

def make_attached_function(
        context: ^ast.FuncDecl,
        name: str,
        &mut namespace: list.List,
        attached_type_node: ^ast.Node) -> ^Handle {
    # Build the function.
    let func: ^AttachedFunction = libc.malloc(ATTACHED_FUNCTION_SIZE as int64) as ^AttachedFunction;
    func.context = context;
    func.handle = 0 as ^LLVMOpaqueValue;
    func.name = string.make();
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
    make(TAG_ATTACHED_FUNCTION, func as ^void);
}

# External function
# -----------------------------------------------------------------------------

type ExternFunction {
    context: ^ast.ExternFunc,
    handle: ^LLVMOpaqueValue,
    mut namespace: list.List,
    mut name: string.String,
    mut qualified_name: string.String,
    mut type_: ^mut Handle
}

let EXTERN_FUNCTION_SIZE: uint = ((0 as ^ExternFunction) + 1) - (0 as ^ExternFunction);

def make_extern_function(
        context: ^ast.ExternFunc,
        name: str,
        &mut namespace: list.List,
        type_: ^Handle,
        handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the function.
    let func: ^ExternFunction = libc.malloc(EXTERN_FUNCTION_SIZE as int64) as ^ExternFunction;
    func.context = context;
    func.handle = handle;
    func.name = string.make();
    func.name.extend(name);
    func.namespace = namespace.clone();
    func.qualified_name = string.join(".", func.namespace);
    func.qualified_name.append(".");
    func.qualified_name.extend(name);
    func.type_ = type_;

    # Wrap in a handle.
    make(TAG_EXTERN_FUNC, func as ^void);
}

# Handle
# -----------------------------------------------------------------------------
# A handle is an intermediary `handle` to a pre-code-generation object such
# as a module, a temporary value, a function, etc.
#
# Handles are strictly allocated on the heap and calling dispose on them
# frees their memory.

type Handle {
    _tag: int,
    _object: ^void
}

let HANDLE_SIZE: uint = ((0 as ^Handle) + 1) - (0 as ^Handle);

implement Handle {
    def _dispose(&mut self) { dispose(&self); }
}

implement Function { # HACK: Re-arrange when we can.

    # Dispose the function and its resources.
    # -------------------------------------------------------------------------
    def dispose(&mut self) {
        # Dispose of the type.
        (self.type_^)._dispose();

        # Dispose of the name.
        self.name.dispose();
    }

}

implement FunctionType { # HACK: Re-arrange when we can.

    # Dispose the function and its resources.
    # -------------------------------------------------------------------------
    def dispose(&mut self) {
        # Dispose of each parameter.
        let mut i: uint = 0;
        while i < self.parameters.size {
            let param_han: ^mut Handle =
                self.parameters.at_ptr(i as int) as ^Handle;

            (param_han^)._dispose();
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
    def dispose(&mut self) {
        self.name.dispose();
        (self.default^)._dispose();
    }

}

# Dispose the handle and its bound object.
# -----------------------------------------------------------------------------
def dispose(&self: ^Handle) {
    # Return if we are nil.
    if isnil(self) { return; }

    # Dispose the object (if we need to).
    if self._tag == TAG_MODULE {
        let mod: ^mut Module = (self._object as ^Module);
        (mod^).dispose();
    } else if self._tag == TAG_STATIC_SLOT {
        let slot: ^mut StaticSlot = (self._object as ^StaticSlot);
        (slot^).dispose();
    } else if self._tag == TAG_FUNCTION {
        let fn: ^mut Function = (self._object as ^Function);
        (fn^).dispose();
    } else if self._tag == TAG_FUNCTION_TYPE {
        let fn: ^mut FunctionType = (self._object as ^FunctionType);
        (fn^).dispose();
    } else if self._tag == TAG_PARAMETER {
        let p: ^mut Parameter = (self._object as ^Parameter);
        (p^).dispose();
    } else if self._tag == TAG_STRUCT {
        let p: ^mut Struct = (self._object as ^Struct);
        (p^).dispose();
    }

    # Free the object.
    libc.free(self._object);
    if self._object <> 0 as ^void {
        # Free ourself.
        libc.free(self as ^void);
    }

    # Remember.
    self._object = 0 as ^void;
}

# Create a handle allocation
# -----------------------------------------------------------------------------
def make(tag: int, object: ^void) -> ^Handle {
    let handle: ^Handle = libc.malloc(HANDLE_SIZE as int64) as ^Handle;
    handle._tag = tag;
    handle._object = object;
    handle;
}

# Create a NIL handle that is used to indicate a null generation.
# -----------------------------------------------------------------------------
def make_nil() -> ^Handle { 0 as ^Handle; }

# Test for a NIL handle.
# -----------------------------------------------------------------------------
def isnil(handle: ^Handle) -> bool {
    (handle == 0 as ^Handle) or ispoison(handle);
}

# Create a POISON handle that is used to indicate a failed generation.
# -----------------------------------------------------------------------------
def make_poison() -> ^Handle { -1 as ^Handle; }

# Test for a POISON handle.
# -----------------------------------------------------------------------------
def ispoison(handle: ^Handle) -> bool { handle == -1 as ^Handle; }
