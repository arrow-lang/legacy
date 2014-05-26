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
import builder;

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
            or val._tag == code.TAG_STRUCT
        {
            generate_handle(g, key, val);
        }
    }
}

# Generate the `type` for the passed code handle.
# -----------------------------------------------------------------------------
def generate_handle(&mut g: generator_.Generator, qname: str,
                    handle: ^code.Handle)
    -> ^code.Handle
{
    # Resolve the type based on the tag of handle.
    if handle._tag == code.TAG_STATIC_SLOT
    {
        generate_static_slot(g, qname, handle._object as ^code.StaticSlot);
    }
    else if handle._tag == code.TAG_FUNCTION
    {
        generate_function(g, qname, handle._object as ^code.Function);
    }
    else if handle._tag == code.TAG_STRUCT
    {
        generate_struct(g, qname, handle._object as ^code.Struct);
    }
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
def generate_static_slot(&mut g: generator_.Generator,
                         qname: str, x: ^code.StaticSlot)
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

        # Build the final type.
        han = builder.build(
            &g, &x.context.type_,
            code.make_nil_scope(),
            han);
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
def generate_function(&mut g: generator_.Generator,
                      qname: str, x: ^code.Function)
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

        # Build the final type.
        ret_han = builder.build(
            &g, &x.context.return_type,
            code.make_nil_scope(),
            ret_han);
        if not code.is_type(ret_han) {
            ret_han = code.type_of(ret_han);
        }

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

        # Build the param type.
        ptype_handle = builder.build(
            &g, &p.type_,
            code.make_nil_scope(),
            ptype_handle);
        if not code.is_type(ptype_handle) {
            ptype_handle = code.type_of(ptype_handle);
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
    han = code.make_function_type(
        qname, x.namespace, x.name.data() as str, val, ret_han, params);
    x.type_ = han;

    # Dispose of dynamic memory.
    param_type_handles.dispose();

    # Return the type handle.
    han;
}

# Generate the type for the `struct`.
# -----------------------------------------------------------------------------
def generate_struct(&mut g: generator_.Generator, qname: str, x: ^code.Struct)
    -> ^code.Handle
{
    # Return our type if it is resolved.
    if not code.isnil(x.type_) { return x.type_; }

    # Return nil if we have been poisioned from a previous failure.
    if code.ispoison(x.type_) { return code.make_nil(); }

    # Build the `opaque` type handle.
    let val: ^llvm.LLVMOpaqueType;
    val = llvm.LLVMStructCreateNamed(
        llvm.LLVMGetGlobalContext(), qname as ^int8);

    # Create and store our type.
    let han: ^code.Handle;
    han = code.make_struct_type(qname, x.context, x.namespace, val);
    x.type_ = han;

    # Return the type handle.
    han;
}

# Generate the type for a member of the `struct`.
# -----------------------------------------------------------------------------
def generate_struct_member(&mut g: generator_.Generator,
                           x: ^code.StructType, name: str)
    -> ^code.Handle
{
    # Has this member been placed in the structure yet?
    if x.member_map.contains(name) {
        # Is this a poision from a previous failure?
        let han: ^code.Handle = x.member_map.get(name) as ^code.Handle;
        if code.ispoison(han) { return code.make_nil(); }

        if not code.isnil(han) {
            # Return the resolved type.
            let mem: ^code.Member = han._object as ^code.Member;
            return mem.type_;
        }
    }

    # Does this member exist on the structure?
    # FIXME: The AST should generate a dictionary for me to use here.
    let mut i: int = 0;
    let mnode: ast.Node;
    let m: ^ast.StructMem = 0 as ^ast.StructMem;
    while i as uint < x.context.nodes.size() {
        mnode = x.context.nodes.get(i);
        let mtmp: ^ast.StructMem = mnode.unwrap() as ^ast.StructMem;
        i = i + 1;

        # Check for the name.
        let id: ^ast.Ident = mtmp.id.unwrap() as ^ast.Ident;
        if id.name.eq_str(name) {
            # Found one; get out.
            m = mtmp;
            break;
        }
    }

    # Did we manage to find a member?
    if m == 0 as ^ast.StructMem {
        # Nope; report the error and bail.
        x.member_map.set_ptr(name, code.make_poison() as ^void);
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "type '%s' has no member '%s'" as ^int8,
                       x.name.data(), name);
        errors.end();
        return code.make_nil();
    }

    # Resolve the type of the structure member.
    let type_handle: ^code.Handle = resolver.resolve_in_t(
        &g, &m.type_, &x.namespace, code.make_nil());
    if code.isnil(type_handle) {
        x.member_map.set_ptr(name, code.make_poison() as ^void);
        return code.make_nil();
    }

    # Emplace the solid type.
    x.member_map.set_ptr(name, code.make_member(
        name,
        type_handle,
        (i as uint - 1) as uint,
        code.make_nil()) as ^void);

    # Return the type.
    type_handle;
}
