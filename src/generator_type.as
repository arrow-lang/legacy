import generator_;
import generator_util;
import generator_util;
import resolver;

# Generate the `type` of each declaration "item".
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

        # Does this item need its `type` resolved?
        if     val._tag == code.TAG_STATIC_SLOT
            or val._tag == code.TAG_FUNCTION
        {
            generate_handle(g, val);
        }
    }
}

# Generate the `type` for the passed code handle.
# -----------------------------------------------------------------------------
def generate_handle(&mut g: generator_.Generator, handle: ^code.Handle)
    -> ^code.Handle
{
    # Resolve the type based on the tag of handle.
    if handle._tag == code.TAG_STATIC_SLOT
    {
        generate_static_slot(g, handle._object as ^code.StaticSlot);
    }
    else if handle._tag == code.TAG_FUNCTION
    {
        generate_function(g, handle._object as ^code.Function);
    }
    # else if handle._tag == code.TAG_STRUCT
    # {
    #     generate_struct(g, handle._object as ^code.Struct);
    # }
    # else if handle._tag == code.TAG_STRUCT_MEM
    # {
    #     generate_struct_mem(g, handle._object as ^code.StructMem);
    # }
    else
    {
        errors.begin_error();
        errors.fprintf(errors.stderr, "not implemented: generator_type.generate_handle(%d)" as ^int8, handle._tag);
        errors.end();
        code.make_nil();
    }
}

# Generate the type for the `static slot`.
# -----------------------------------------------------------------------------
def generate_static_slot(&mut g: generator_.Generator, x: ^code.StaticSlot)
    -> ^code.Handle
{
    # Return our type if it is resolved.
    if not code.isnil(x.type_) { return x.type_; }

    # Return nil if we have been poisioned from a previous failure.
    if code.ispoison(x.type_) { return code.make_nil(); }

    # Get and resolve the type node.
    let han: ^code.Handle = resolver.resolve_in(
        &g, &x.context.type_, &x.namespace,
        code.make_nil_scope(),
        code.make_nil());

    # Store and return our type handle (or poision if we failed).
    x.type_ = code.make_poison() if code.isnil(han) else han;
}

# Generate the type for the `function`.
# -----------------------------------------------------------------------------
def generate_function(&mut g: generator_.Generator, x: ^code.Function)
    -> ^code.Handle
{
    # Return our type if it is resolved.
    if not code.isnil(x.type_) { return x.type_; }

    # Return nil if we have been poisioned from a previous failure.
    if code.ispoison(x.type_) { return code.make_nil(); }

    # FIXME: NOT IMPLEMENTED!!
    errors.begin_error();
    errors.fprintf(errors.stderr, "not implemented: generate_function" as ^int8);
    errors.end();

    return code.make_nil();
}
