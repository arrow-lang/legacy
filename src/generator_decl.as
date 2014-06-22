import dict;
import llvm;
import list;
import ast;
import resolver;
import generator_type;
import types;
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
        else if val._tag == code.TAG_STRUCT
        {
            generate_struct(g, key, val._object as ^code.Struct);
            void;
        }
        else if    val._tag == code.TAG_TYPE
                or val._tag == code.TAG_INT_TYPE
                or val._tag == code.TAG_FLOAT_TYPE
                or val._tag == code.TAG_VOID_TYPE
                or val._tag == code.TAG_LOCAL_SLOT
                or val._tag == code.TAG_BOOL_TYPE
                or val._tag == code.TAG_CHAR_TYPE
                or val._tag == code.TAG_STR_TYPE
                or val._tag == code.TAG_MODULE
                or val._tag == code.TAG_EXTERN_FUNC
        {
            # Do nothing; these do not need declarations.
            continue;
        }
        else
        {
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr, "not implemented: generator_decl.generate(%d)" as ^int8, val._tag);
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

# Structure [TAG_STRUCT]
# -----------------------------------------------------------------------------
def generate_struct(&mut g: generator_.Generator, qname: str, x: ^code.Struct)
{
    if x.handle == 0 as ^llvm.LLVMOpaqueValue {
        # Get the type node out of the handle.
        let type_: ^code.StructType = x.type_._object as ^code.StructType;

        # Resolve the type for each member.
        let mut member_type_handles: list.List = list.make(types.PTR);
        let mut i: int = 0;
        while i as uint < x.context.nodes.size()
        {
            let mnode: ast.Node = x.context.nodes.get(i);
            let m: ^ast.StructMem = mnode.unwrap() as ^ast.StructMem;
            let member_id: ^ast.Ident = m.id.unwrap() as ^ast.Ident;
            i = i + 1;

            # Generate the type.
            let type_handle: ^code.Handle =
                generator_type.generate_struct_member(
                    g, type_, member_id.name.data() as str);

            # # Resolve the type.
            # let type_handle: ^code.Handle = resolver.resolve_in_t(
            #     &g, &m.type_, &x.namespace, code.make_nil());
            # if code.isnil(type_handle) {
            #     # Failed to resolve type; mark us as poisioned.
            #     x.type_ = code.make_poison();
            #     return;
            # }

            # Emplace the type handle.
            let type_obj: ^code.Type = type_handle._object as ^code.Type;
            member_type_handles.push_ptr(type_obj.handle as ^void);

            # # Emplace a solid member.
            # let member_id: ^ast.Ident = m.id.unwrap() as ^ast.Ident;
            # type_.members.push_ptr(code.make_member(
            #     member_id.name.data() as str,
            #     type_handle,
            #     (i as uint - 1) as uint,
            #     code.make_nil()) as ^void);
        }

        # Set the body for this structure.
        llvm.LLVMStructSetBody(
            type_.handle,
            member_type_handles.elements as ^^llvm.LLVMOpaqueType,
            member_type_handles.size as uint32,
            false);

        # Fill the member list.
        type_.members = list.make(types.PTR);
        type_.members.reserve(member_type_handles.size);
        type_.members.size = member_type_handles.size;
        let members: list.List = type_.members;
        let dat: ^^void = members.elements as ^^void;
        let mut iter: dict.Iterator = type_.member_map.iter();
        while not iter.empty() {
            let key: str;
            let value: ^void;
            (key, value) = iter.next();
            let han: ^code.Handle = value as ^code.Handle;
            let nod: ^code.Member = han._object as ^code.Member;
            (dat + nod.index)^ = han as ^void;
        }
    }
}
