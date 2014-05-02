import code;
import dict;
import list;
import types;
import errors;
import llvm;
import ast;
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

    # If we have a type node ...
    let han: ^code.Handle;
    if not ast.isnull(x.context.type_)
    {
        # ... get and resolve the type node.
        han = resolver.resolve_in(
            &g, &x.context.type_, &x.namespace,
            code.make_nil_scope(),
            code.make_nil());
    }
    else if not ast.isnull(x.context.initializer)
    {
        # ... else; resolve the initializer.
        han = resolver.resolve_in(
            &g, &x.context.initializer, &x.namespace,
            code.make_nil_scope(),
            code.make_nil());
    }
    else
    {
        # Bail; static slot declarations require either an initializer
        # or a type.
        errors.begin_error();
        errors.fprintf(errors.stderr, "static slots require either an an initializer or a type" as ^int8);
        errors.end();

        return code.make_nil();
    }

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

    # Resolve the return type.
    let ret_han: ^code.Handle = code.make_nil();
    let ret_typ_han: ^llvm.LLVMOpaqueType;
    if ast.isnull(x.context.return_type)
    {
        # No return type specified.
        # TODO: In the future this should resolve the type
        #   of the function body.
        # Use a void return type for now.
        ret_typ_han = llvm.LLVMVoidType();
        ret_han = code.make_void_type(ret_typ_han);
        ret_typ_han;  # HACK!
    }
    else
    {
        # Get and resolve the return type.
        ret_han = resolver.resolve_in(
            &g, &x.context.return_type, &x.namespace,
            &x.scope, code.make_nil());

        if code.isnil(ret_han) {
            # Failed to resolve type; mark us as poisioned.
            x.type_ = code.make_poison();
            return code.make_poison();
        }

        # Get the ret type handle.
        let ret_typ: ^code.Type = ret_han._object as ^code.Type;
        ret_typ_han = ret_typ.handle;
    }

    # Resolve the type for each parameter.
    let mut params: list.List = list.make(types.PTR);
    let mut param_type_handles: list.List = list.make(types.PTR);
    let mut i: int = 0;
    while i as uint < x.context.params.size()
    {
        let pnode: ast.Node = x.context.params.get(i);
        i = i + 1;
        let p: ^ast.FuncParam = pnode.unwrap() as ^ast.FuncParam;

        # Resolve the type.
        let ptype_handle: ^code.Handle = resolver.resolve_in(
            &g, &p.type_, &x.namespace, &x.scope, code.make_nil());
        if code.isnil(ptype_handle) {
            # Failed to resolve type; mark us as poisioned.
            x.type_ = code.make_poison();
            return code.make_poison();
        }

        let ptype_obj: ^code.Type = ptype_handle._object as ^code.Type;

        # Emplace the type handle.
        param_type_handles.push_ptr(ptype_obj.handle as ^void);

        # Emplace a solid parameter.
        let param_id: ^ast.Ident = p.id.unwrap() as ^ast.Ident;
        params.push_ptr(code.make_parameter(
            param_id.name.data() as str,
            ptype_handle,
            code.make_nil()) as ^void);
    }

    # Build the LLVM type handle.
    let val: ^llvm.LLVMOpaqueType;
    val = llvm.LLVMFunctionType(
        ret_typ_han,
        param_type_handles.elements as ^^llvm.LLVMOpaqueType,
        param_type_handles.size as uint32,
        0);

    # Create and store our type.
    let han: ^code.Handle;
    han = code.make_function_type(val, ret_han, params);
    x.type_ = han;

    # Dispose of dynamic memory.
    param_type_handles.dispose();

    # Return the type handle.
    han;
}
