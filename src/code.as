foreign "C" import "llvm-c/Core.h";

import string;
import libc;
import list;

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

# Type
# -----------------------------------------------------------------------------
# A basic type just remembers what its llvm handle is.

type Type { handle: ^LLVMOpaqueType }

type IntegerType {
    handle: ^LLVMOpaqueType,
    signed: bool
}

let TYPE_SIZE: uint = ((0 as ^Type) + 1) - (0 as ^Type);
let INT_TYPE_SIZE: uint = ((0 as ^IntegerType) + 1) - (0 as ^IntegerType);

def make_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE) as ^Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_TYPE, ty as ^void);
}

def make_float_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE) as ^Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_FLOAT_TYPE, ty as ^void);
}

def make_int_type(handle: ^LLVMOpaqueType, signed: bool) -> ^Handle {
    # Build the module.
    let ty: ^IntegerType = libc.malloc(INT_TYPE_SIZE) as ^IntegerType;
    ty.handle = handle;
    ty.signed = signed;

    # Wrap in a handle.
    make(TAG_INT_TYPE, ty as ^void);
}

# Function type
# -----------------------------------------------------------------------------
# A function type needs to remember its return type and its parameters.

type Parameter {
    mut name: string.String,
    type_: ^mut Handle
}

type FunctionType {
    handle: ^LLVMOpaqueType,
    return_type: ^mut Handle,
    mut parameters: list.List
}

let PARAMETER_SIZE: uint = ((0 as ^Parameter) + 1) - (0 as ^Parameter);

let FUNCTION_TYPE_SIZE: uint = ((0 as ^FunctionType) + 1) - (0 as ^FunctionType);

def make_parameter(&mut name: string.String, type_: ^Handle) -> ^Handle {
    # Build the parameter.
    let param: ^Parameter = libc.malloc(PARAMETER_SIZE) as ^Parameter;
    param.name = name.clone();
    param.type_ = type_;

    # Wrap in a handle.
    make(TAG_PARAMETER, param as ^void);
}

def make_function_type(
        handle: ^LLVMOpaqueType,
        return_type: ^Handle,
        &mut parameters: list.List) -> ^Handle {
    # Build the function.
    let func: ^FunctionType = libc.malloc(FUNCTION_TYPE_SIZE) as ^FunctionType;
    func.return_type = return_type;
    func.parameters = parameters;

    # Wrap in a handle.
    make(TAG_FUNCTION_TYPE, func as ^void);
}

implement Parameter {

    # Dispose the parameter and its resources.
    # -------------------------------------------------------------------------
    def dispose(&mut self) {
        # Dispose of the name.
        self.name.dispose();
    }

}

# Static Slot
# -----------------------------------------------------------------------------
# A slot keeps its name with it for now. It'll contain later its type and
# other designators.

type StaticSlot {
    mut name: string.String,
    type_: ^Handle,
    handle: ^LLVMOpaqueValue
}

let STATIC_SLOT_SIZE: uint = ((0 as ^StaticSlot) + 1) - (0 as ^StaticSlot);

def make_static_slot(
        &name: string.String,
        type_: ^Handle,
        handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the slot.
    let slot: ^StaticSlot = libc.malloc(STATIC_SLOT_SIZE) as ^StaticSlot;
    slot.name = name.clone();
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

type Module { mut name: string.String }

let MODULE_SIZE: uint = ((0 as ^Module) + 1) - (0 as ^Module);

def make_module(&mut name: string.String) -> ^Handle {
    # Build the module.
    let mod: ^Module = libc.malloc(MODULE_SIZE) as ^Module;
    mod.name = name.clone();

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
    mut name: string.String,
    mut type_: ^mut Handle
}

let FUNCTION_SIZE: uint = ((0 as ^Function) + 1) - (0 as ^Function);

def make_function(
        &mut name: string.String,
        type_: ^Handle) -> ^Handle {
    # Build the function.
    let func: ^Function = libc.malloc(FUNCTION_SIZE) as ^Function;
    func.name = name.clone();
    func.type_ = type_;

    # Wrap in a handle.
    make(TAG_FUNCTION, func as ^void);
}

# Coerce an arbitary handle to a value.
# -----------------------------------------------------------------------------
# This can cause a LOAD.
def to_value(b: ^LLVMOpaqueBuilder, handle: ^Handle) -> ^Handle {
    if handle._tag == TAG_STATIC_SLOT {
        let slot: ^StaticSlot = handle._object as ^StaticSlot;

        # Load the static slot value.
        let val: ^LLVMOpaqueValue;
        val = LLVMBuildLoad(b, slot.handle, "" as ^int8);

        # Wrap it in a handle.
        make_value(slot.type_, val);
    } else if handle._tag == TAG_VALUE {
        # Clone the value object.
        let val: ^Value = handle._object as ^Value;
        make_value(val.type_, val.handle);
    } else {
        # No idea how to handle this.
        make_nil();
    }
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

# Dispose the handle and its bound object.
# -----------------------------------------------------------------------------
def dispose(self: ^Handle) {
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

    # Free ourself.
    libc.free(self as ^void);
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
def isnil(handle: ^Handle) -> bool { handle == 0 as ^Handle; }
