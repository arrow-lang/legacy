foreign "C" import "llvm-c/Core.h";

import string;
import ast;
import libc;
import list;
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

# Scope chain
# -----------------------------------------------------------------------------
# This internally is a list of dictinoaries that are for managing
# the local scope of a specific function.

type Scope {
    # The list of dictionaries that comprise the scope chain.
    chain: list.List
}

implement Scope {

    # Insert an item into the current block in the scope chain.
    # -------------------------------------------------------------------------
    def insert(&mut self, name: str, handle: ^code.Handle) {
    }

    # Push another scope into the chain.
    # -------------------------------------------------------------------------
    def push(&mut self) {
        let m: ^mut dict.Dictonary = libc.malloc(
            ((0 as ^dict.Dictonary) + 1) - (0 as ^dict.Dictonary));
        m^ = dict.make(2048);
        self.chain.push_ptr(&m);
    }

    # Pop a scope from the chain.
    # -------------------------------------------------------------------------
    def pop(&mut self) {
        let m: ^mut dict.Dictonary = self.chain.at_ptr(-1) as ^dict.Dictonary;
        (m^).dispose();
        self.chain.erase(-1);
    }

}

# Type
# -----------------------------------------------------------------------------
# A basic type just remembers what its llvm handle is.

type Type { handle: ^LLVMOpaqueType }

type IntegerType {
    handle: ^LLVMOpaqueType,
    bits: uint,
    signed: bool
}

type FloatType {
    handle: ^LLVMOpaqueType,
    bits: uint
}

let TYPE_SIZE: uint = ((0 as ^Type) + 1) - (0 as ^Type);
let INT_TYPE_SIZE: uint = ((0 as ^IntegerType) + 1) - (0 as ^IntegerType);
let FLOAT_TYPE_SIZE: uint = ((0 as ^FloatType) + 1) - (0 as ^FloatType);

def make_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE) as ^Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_TYPE, ty as ^void);
}

def make_void_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE) as ^Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_VOID_TYPE, ty as ^void);
}

def make_float_type(handle: ^LLVMOpaqueType, bits: uint) -> ^Handle {
    # Build the module.
    let ty: ^FloatType = libc.malloc(FLOAT_TYPE_SIZE) as ^FloatType;
    ty.handle = handle;
    ty.bits = bits;

    # Wrap in a handle.
    make(TAG_FLOAT_TYPE, ty as ^void);
}

def make_bool_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE) as ^Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_BOOL_TYPE, ty as ^void);
}

def make_int_type(handle: ^LLVMOpaqueType, signed: bool,
                  bits: uint) -> ^Handle {
    # Build the module.
    let ty: ^IntegerType = libc.malloc(INT_TYPE_SIZE) as ^IntegerType;
    ty.handle = handle;
    ty.signed = signed;
    ty.bits = bits;

    # Wrap in a handle.
    make(TAG_INT_TYPE, ty as ^void);
}

def typename(handle: ^Handle) -> string.String {
    let ty: ^Type = handle._object as ^Type;

    # Allocate some space for the name.
    let mut name: string.String = string.make();

    # Figure out what we are.
    if      handle._tag == TAG_BOOL_TYPE { name.extend("bool"); }
    else if handle._tag == TAG_INT_TYPE {
        let int_ty: ^IntegerType = handle._object as ^IntegerType;
        if not int_ty.signed { name.append('u'); }
        name.extend("int");
        if      int_ty.bits ==   8 { name.extend(  "8"); }
        else if int_ty.bits ==  16 { name.extend( "16"); }
        else if int_ty.bits ==  32 { name.extend( "32"); }
        else if int_ty.bits ==  64 { name.extend( "64"); }
        else if int_ty.bits == 128 { name.extend("128"); }
    } else if handle._tag == TAG_FLOAT_TYPE {
        let f_ty: ^FloatType = handle._object as ^FloatType;
        name.extend("float");
        if      f_ty.bits == 32 { name.extend("32"); }
        else if f_ty.bits == 64 { name.extend("64"); }
    }

    # Return the name.
    name;
}

# Function type
# -----------------------------------------------------------------------------
# A function type needs to remember its return type and its parameters.

type Parameter {
    mut name: string.String,
    type_: ^mut Handle,
    default: ^mut Handle
}

type FunctionType {
    handle: ^LLVMOpaqueType,
    return_type: ^mut Handle,
    mut parameters: list.List
}

let PARAMETER_SIZE: uint = ((0 as ^Parameter) + 1) - (0 as ^Parameter);

let FUNCTION_TYPE_SIZE: uint = ((0 as ^FunctionType) + 1) - (0 as ^FunctionType);

def make_parameter(name: str, type_: ^Handle,
                   default: ^Handle) -> ^Handle {
    # Build the parameter.
    let param: ^Parameter = libc.malloc(PARAMETER_SIZE) as ^Parameter;
    param.name = string.make();
    param.name.extend(name);
    param.type_ = type_;
    param.default = default;

    # Wrap in a handle.
    make(TAG_PARAMETER, param as ^void);
}

def make_function_type(
        handle: ^LLVMOpaqueType,
        return_type: ^Handle,
        parameters: list.List) -> ^Handle {
    # Build the function.
    let func: ^FunctionType = libc.malloc(FUNCTION_TYPE_SIZE) as ^FunctionType;
    func.handle = handle;
    func.return_type = return_type;
    func.parameters = parameters;

    # Wrap in a handle.
    make(TAG_FUNCTION_TYPE, func as ^void);
}

# Gets if this handle is a type.
# -----------------------------------------------------------------------------
def is_type(handle: ^Handle) -> bool {
    handle._tag == TAG_TYPE or
    handle._tag == TAG_BOOL_TYPE or
    handle._tag == TAG_FUNCTION_TYPE or
    handle._tag == TAG_INT_TYPE or
    handle._tag == TAG_FLOAT_TYPE;
}

# Gets the type of the thing.
# -----------------------------------------------------------------------------
def type_of(handle: ^Handle) -> ^Handle {
    if handle._tag == TAG_STATIC_SLOT {
        let slot: ^StaticSlot = handle._object as ^StaticSlot;
        slot.type_;
    } else if handle._tag == TAG_VALUE {
        let val: ^Value = handle._object as ^Value;
        val.type_;
    } else if handle._tag == TAG_PARAMETER {
        let val: ^Parameter = handle._object as ^Parameter;
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
    context: ^ast.StaticSlotDecl,
    mut name: string.String,
    mut namespace: list.List,
    type_: ^Handle,
    handle: ^LLVMOpaqueValue
}

let STATIC_SLOT_SIZE: uint = ((0 as ^StaticSlot) + 1) - (0 as ^StaticSlot);

def make_static_slot(
        context: ^ast.StaticSlotDecl,
        name: str,
        &mut namespace: list.List,
        type_: ^Handle,
        handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the slot.
    let slot: ^StaticSlot = libc.malloc(STATIC_SLOT_SIZE) as ^StaticSlot;
    slot.context = context;
    slot.name = string.make();
    slot.name.extend(name);
    slot.namespace = namespace.clone();
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

# Module
# -----------------------------------------------------------------------------
# A module just keeps its name with it. Its purpose in the scope is
# to allow name resolution.

type Module {
    mut name: string.String,
    mut namespace: list.List
}

let MODULE_SIZE: uint = ((0 as ^Module) + 1) - (0 as ^Module);

def make_module(
        name: str,
        &mut namespace: list.List) -> ^Handle {
    # Build the module.
    let mod: ^Module = libc.malloc(MODULE_SIZE) as ^Module;
    mod.name = string.make();
    mod.name.extend(name);
    mod.namespace = namespace.clone();

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

type Value { type_: ^Handle, handle: ^LLVMOpaqueValue }

let VALUE_SIZE: uint = ((0 as ^Value) + 1) - (0 as ^Value);

def make_value(type_: ^Handle, handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the module.
    let val: ^Value = libc.malloc(VALUE_SIZE) as ^Value;
    val.handle = handle;
    val.type_ = type_;

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
    mut type_: ^mut Handle
}

let FUNCTION_SIZE: uint = ((0 as ^Function) + 1) - (0 as ^Function);

def make_function(
        context: ^ast.FuncDecl,
        name: str,
        &mut namespace: list.List,
        type_: ^Handle,
        handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the function.
    let func: ^Function = libc.malloc(FUNCTION_SIZE) as ^Function;
    func.context = context;
    func.handle = handle;
    func.name = string.make();
    func.name.extend(name);
    func.namespace = namespace.clone();
    func.type_ = type_;

    # Wrap in a handle.
    make(TAG_FUNCTION, func as ^void);
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

        # Dispose of the parameter list.
        self.parameters.dispose();
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
    let handle: ^Handle = libc.malloc(HANDLE_SIZE) as ^Handle;
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
