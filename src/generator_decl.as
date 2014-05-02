import dict;
import llvm;
import errors;
import code;
import generator_;

# Generate the `declaration` of each declaration "item".
# -----------------------------------------------------------------------------
def generate(&mut g: generator_.Generator)
{
    # Iterate over the "items" dictionary.
    let mut i: dict.Iterator = g.items.iter();
    let mut key: str;
    let mut ptr: ^void;
    let mut val: ^code.Handle;
    while not i.empty() {
        # Grab the next "item"
        (key, ptr) = i.next();
        val = ptr as ^code.Handle;

        if val._tag == code.TAG_STATIC_SLOT
        {
            generate_static_slot(g, key, val._object as ^code.StaticSlot);
            void;
        }
        else if val._tag == code.TAG_FUNCTION
        {
            generate_function(g, key, val._object as ^code.Function);
            void;
        }
        else if    val._tag == code.TAG_TYPE
                or val._tag == code.TAG_INT_TYPE
                or val._tag == code.TAG_FLOAT_TYPE
                or val._tag == code.TAG_VOID_TYPE
                or val._tag == code.TAG_LOCAL_SLOT
                or val._tag == code.TAG_BOOL_TYPE
                or val._tag == code.TAG_MODULE
        {
            # Do nothing; these do not need declarations.
            continue;
        }
        else
        {
            errors.begin_error();
            errors.fprintf(errors.stderr, "not implemented: generator_decl.generate(%d)" as ^int8, val._tag);
            errors.end();
            code.make_nil();
        }
    }
}

# Static slot [TAG_STATIC_SLOT]
# -----------------------------------------------------------------------------
def generate_static_slot(&mut g: generator_.Generator, qname: str,
                         x: ^code.StaticSlot)
{
    # Get the type node out of the handle.
    let type_: ^code.Type = x.type_._object as ^code.Type;

    # Add the global slot declaration to the IR.
    # TODO: Set priv, vis, etc.
    x.handle = llvm.LLVMAddGlobal(g.mod, type_.handle, qname as ^int8);

    # Set if this is constant.
    llvm.LLVMSetGlobalConstant(x.handle, not x.context.mutable);
}

# Function [TAG_FUNCTION]
# -----------------------------------------------------------------------------
def generate_function(&mut g: generator_.Generator, qname: str,
                      x: ^code.Function)
{
    if x.handle == 0 as ^llvm.LLVMOpaqueValue {
        # Get the type node out of the handle.
        let type_: ^code.FunctionType = x.type_._object as ^code.FunctionType;

        # Add the function to the module.
        # TODO: Set priv, vis, etc.
        x.handle = llvm.LLVMAddFunction(g.mod, qname as ^int8, type_.handle);
    }
}
