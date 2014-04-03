foreign "C" import "llvm-c/Core.h";

import string;
import libc;

# Tags
# -----------------------------------------------------------------------------
# Enumeration of the `kinds` of objects a code handle may refer to.

let TAG_MODULE: int = 1;
let TAG_STATIC_SLOT: int = 2;
let TAG_TYPE: int = 3;
let TAG_VALUE: int = 4;

# Type
# -----------------------------------------------------------------------------
# A basic type just remembers what its llvm handle is.

type Type { handle: ^LLVMOpaqueType }

let TYPE_SIZE: uint = ((0 as ^Type) + 1) - (0 as ^Type);

def make_type(handle: ^LLVMOpaqueType) -> ^Handle {
    # Build the module.
    let ty: ^Type = libc.malloc(TYPE_SIZE) as ^Type;
    ty.handle = handle;

    # Wrap in a handle.
    make(TAG_TYPE, ty as ^void);
}

# Static Slot
# -----------------------------------------------------------------------------
# A slot keeps its name with it for now. It'll contain later its type and
# other designators.

type StaticSlot {
    mut name: string.String,
    type_: ^Type,
    handle: ^LLVMOpaqueValue
}

let STATIC_SLOT_SIZE: uint = ((0 as ^StaticSlot) + 1) - (0 as ^StaticSlot);

def make_static_slot(
        &name: string.String,
        type_: ^Type,
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

type Value { type_: ^Type, handle: ^LLVMOpaqueValue }

let VALUE_SIZE: uint = ((0 as ^Value) + 1) - (0 as ^Value);

def make_value(type_: ^Type, handle: ^LLVMOpaqueValue) -> ^Handle {
    # Build the module.
    let val: ^Value = libc.malloc(VALUE_SIZE) as ^Value;
    val.handle = handle;
    val.type_ = type_;

    # Wrap in a handle.
    make(TAG_VALUE, val as ^void);
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
