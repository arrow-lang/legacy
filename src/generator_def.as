import ast;
import code;
import errors;
import dict;
import generator_;
import generator_util;
import llvm;
import resolver;
import builder;

# Generate the `definition` of each "item".
# -----------------------------------------------------------------------------
def generate(&mut g: generator_.Generator) {
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
            # Do nothing; these do not need definitions.
            continue;
        }
        else
        {
            errors.begin_error();
            errors.fprintf(errors.stderr, "not implemented: generator_def.generate(%d)" as ^int8, val._tag);
            errors.end();
            code.make_nil();
        }
    }
}

# Static slot [TAG_STATIC_SLOT]
# -----------------------------------------------------------------------------
def generate_static_slot(&mut g: generator_.Generator, qname: str,
                         x: ^code.StaticSlot) -> ^code.Handle
{
    # Is this static slot been defined previously ...
    let init: ^llvm.LLVMOpaqueValue;
    init = llvm.LLVMGetInitializer(x.handle);
    if init <> 0 as ^llvm.LLVMOpaqueValue {
        # ... yes; wrap and return it.
        return code.make_value(x.type_, init);
    }

    # If we have an initializer ...
    let val_han: ^code.Handle;
    if not ast.isnull(x.context.initializer)
    {
        # Resolve the type of the initializer.
        let typ: ^code.Handle;
        typ = resolver.resolve_in_t(
            &g, &x.context.initializer, &x.namespace, x.type_);
        if code.isnil(typ) { return code.make_nil(); }

        # Build the initializer
        let han: ^code.Handle;
        han = builder.build_in(
            &g, &x.context.initializer, &x.namespace,
            code.make_nil_scope(), typ);
        if code.isnil(han) { return code.make_nil(); }

        # Coerce this to a value.
        val_han = to_value(g, han, true);
    }
    else
    {
        # Get the type out of the static slot.
        let typ: ^code.Type = x.type_._object as ^code.Type;

        # Create a zero initializer for the type.
        let val: ^llvm.LLVMOpaqueValue = llvm.LLVMConstNull(typ.handle);

        # Wrap in a value.
        val_han = code.make_value(x.type_, val);
    }

    # Set the initializer on the static slot.
    let val: ^code.Value = val_han._object as ^code.Value;
    llvm.LLVMSetInitializer(x.handle, val.handle);

    # Return the initializer.
    val_han;
}

# Function [TAG_FUNCTION]
# -----------------------------------------------------------------------------
def generate_function(&mut g: generator_.Generator, qname: str,
                      x: ^code.Function)
{
    # Skip if this function been generated or is available externally.
    if llvm.LLVMCountBasicBlocks(x.handle) > 0 { return; }

    # Create the entry basic block for the function definition.
    let entry: ^llvm.LLVMOpaqueBasicBlock;
    entry = llvm.LLVMAppendBasicBlock(x.handle, "" as ^int8);

    # Remember the insert block.
    let cur_block: ^llvm.LLVMOpaqueBasicBlock;
    cur_block = llvm.LLVMGetInsertBlock(g.irb);

    # Set the insertion point.
    llvm.LLVMPositionBuilderAtEnd(g.irb, entry);

    # Pull out the type node.
    let type_: ^code.FunctionType = x.type_._object as ^code.FunctionType;

    # Allocate the parameter nodes into the local scope.
    let mut i: int = 0;
    while i as uint < type_.parameters.size {
        # Get the parameter node.
        let prm_han: ^code.Handle = type_.parameters.at_ptr(i) as ^code.Handle;
        let prm: ^code.Parameter = prm_han._object as ^code.Parameter;

        # Get the type handle.
        let prm_type: ^code.Type = prm.type_._object as ^code.Type;

        # Allocate this param.
        let val: ^llvm.LLVMOpaqueValue;
        val = llvm.LLVMBuildAlloca(g.irb, prm_type.handle, prm.name.data());

        # Get the parameter handle.
        let prm_val: ^llvm.LLVMOpaqueValue;
        prm_val = llvm.LLVMGetParam(x.handle, i as uint32);

        # Store the parameter in the allocation.
        llvm.LLVMBuildStore(g.irb, prm_val, val);

        # Insert into the local scope.
        x.scope.insert(prm.name.data() as str, code.make_local_slot(
            prm.type_, val));

        # Continue.
        i = i + 1;
    }

    # Pull out the nodes that correspond to this function.
    let nodes: ^ast.Nodes = g.nodes.get_ptr(qname) as ^ast.Nodes;

    # Create a namespace for the function definition.
    let mut ns: list.List = x.namespace.clone();
    ns.push_str(x.name.data() as str);

    # Get the ret type target
    let ret_type_target: ^code.Handle = type_.return_type;
    if ret_type_target._tag == code.TAG_VOID_TYPE {
        ret_type_target = code.make_nil();
    }

    # Iterate over the nodes in the function.
    let mut i: int = 0;
    let mut res: ^code.Handle = code.make_nil();
    while i as uint < (nodes^).size() {
        let node: ast.Node = (nodes^).get(i);
        i = i + 1;

        # Resolve the type of the node.
        let cur_count: uint = errors.count;
        let target: ^code.Handle = resolver.resolve_in(
            &g, &node, &ns, &x.scope, ret_type_target);
        if cur_count < errors.count { continue; }

        # Build the node.
        let han: ^code.Handle = builder.build_in(
            &g, &node, &ns, &x.scope, target);

        # Set the last handle as our value.
        if i as uint >= (nodes^).size() {
            res = han;
        }
    }

    # Has the function been terminated?
    let last_block: ^llvm.LLVMOpaqueBasicBlock =
        llvm.LLVMGetLastBasicBlock(x.handle);
    let last_terminator: ^llvm.LLVMOpaqueValue =
        llvm.LLVMGetBasicBlockTerminator(last_block);
    if last_terminator == 0 as ^llvm.LLVMOpaqueValue {
        # Not terminated; we need to close the function.
        if code.isnil(res) {
            llvm.LLVMBuildRetVoid(g.irb);
        } else {
            if type_.return_type._tag == code.TAG_VOID_TYPE {
                llvm.LLVMBuildRetVoid(g.irb);
            } else {
                let val_han: ^code.Handle = to_value(g, res, false);
                let typ: ^code.Handle = code.type_of(val_han) as ^code.Handle;
                if typ._tag == code.TAG_VOID_TYPE {
                    llvm.LLVMBuildRetVoid(g.irb);
                } else {
                    let val: ^code.Value = val_han._object as ^code.Value;
                    llvm.LLVMBuildRet(g.irb, val.handle);
                }
            }
        }
    }

    # Dispose.
    ns.dispose();

    # Reset to the old insert block.
    llvm.LLVMPositionBuilderAtEnd(g.irb, cur_block);
}

# def _gen_def_function(&mut self, qname: str, x: ^code.Function)
#         -> ^code.Handle {

#     # Has this function been generated?
#     if llvm.LLVMCountBasicBlocks(x.handle) > 0 {
#         # Yes; skip.
#         return code.make_nil();
#     }

#     # Create a basic block for the function definition.
#     let entry: ^llvm.LLVMOpaqueBasicBlock;
#     entry = llvm.LLVMAppendBasicBlock(x.handle, "" as ^int8);

#     # Remember the insert block.
#     let cur_block: ^llvm.LLVMOpaqueBasicBlock;
#     cur_block = llvm.LLVMGetInsertBlock(self.irb);

#     # Set the insertion point.
#     llvm.LLVMPositionBuilderAtEnd(self.irb, entry);

#     # Pull out the type node.
#     let type_: ^code.FunctionType = x.type_._object as ^code.FunctionType;

#     # Allocate the parameter nodes into the local scope.
#     let mut i: int = 0;
#     while i as uint < type_.parameters.size {
#         # Get the parameter node.
#         let prm_han: ^code.Handle =
#             type_.parameters.at_ptr(i) as ^code.Handle;
#         let prm: ^code.Parameter = prm_han._object as ^code.Parameter;

#         # Get the type handle.
#         let prm_type: ^code.Type = prm.type_._object as ^code.Type;

#         # Allocate this param.
#         let val: ^llvm.LLVMOpaqueValue;
#         val = llvm.LLVMBuildAlloca(self.irb, prm_type.handle, prm.name.data());

#         # Get the parameter handle.
#         let prm_val: ^llvm.LLVMOpaqueValue;
#         prm_val = llvm.LLVMGetParam(x.handle, i as uint32);

#         # Store the parameter in the allocation.
#         llvm.LLVMBuildStore(self.irb, prm_val, val);

#         # Insert into the local scope.
#         x.scope.insert(prm.name.data() as str, code.make_local_slot(
#             prm.type_, val));

#         # Continue.
#         i = i + 1;
#     }

#     # Pull out the nodes that correspond to this function.
#     let nodes: ^ast.Nodes = self.nodes.get_ptr(qname) as ^ast.Nodes;

#     # Create a namespace for the function definition.
#     let mut ns: list.List = x.namespace.clone();
#     ns.push_str(x.name.data() as str);

#     # Get the ret type target
#     let ret_type_target: ^code.Handle = type_.return_type;
#     if ret_type_target._tag == code.TAG_VOID_TYPE {
#         ret_type_target = code.make_nil();
#     }

#     # Iterate over the nodes in the function.
#     let mut i: int = 0;
#     let mut res: ^code.Handle = code.make_nil();
#     while i as uint < (nodes^).size() {
#         let node: ast.Node = (nodes^).get(i);
#         i = i + 1;

#         # Resolve the type of the node.
#         let cur_count: uint = errors.count;
#         let target: ^code.Handle = resolve_type_in(
#             &self, &node, ret_type_target, &x.scope, &ns);
#         if cur_count < errors.count { continue; }

#         # Build the node.
#         let han: ^code.Handle = build_in(
#             &self, target, &x.scope, &node, &ns);

#         # Set the last handle as our value.
#         if i as uint >= (nodes^).size() {
#             res = han;
#         }
#     }

#     # Has the function been terminated?
#     let last_block: ^llvm.LLVMOpaqueBasicBlock =
#         llvm.LLVMGetLastBasicBlock(x.handle);
#     let last_terminator: ^llvm.LLVMOpaqueValue =
#         llvm.LLVMGetBasicBlockTerminator(last_block);
#     if last_terminator == 0 as ^llvm.LLVMOpaqueValue {
#         # Not terminated; we need to close the function.
#         if code.isnil(res) {
#             llvm.LLVMBuildRetVoid(self.irb);
#         } else {
#             if type_.return_type._tag == code.TAG_VOID_TYPE {
#                 llvm.LLVMBuildRetVoid(self.irb);
#             } else {
#                 let val_han: ^code.Handle = self._to_value(res, false);
#                 let typ: ^code.Handle = code.type_of(val_han) as ^code.Handle;
#                 if typ._tag == code.TAG_VOID_TYPE {
#                     llvm.LLVMBuildRetVoid(self.irb);
#                 } else {
#                     let val: ^code.Value = val_han._object as ^code.Value;
#                     llvm.LLVMBuildRet(self.irb, val.handle);
#                 }
#             }
#         }
#     }

#     # Dispose.
#     ns.dispose();

#     # Reset to the old insert block.
#     llvm.LLVMPositionBuilderAtEnd(self.irb, cur_block);

#     # FIXME: Function defs always resolve to the address of the function.
#     code.make_nil();
# }

# Internal
# =============================================================================

# Coerce an arbitary handle to a value.
# -----------------------------------------------------------------------------
def to_value(&mut g: generator_.Generator,
             handle: ^code.Handle, static_: bool) -> ^code.Handle
{
    if handle._tag == code.TAG_STATIC_SLOT
    {
        let slot: ^code.StaticSlot = handle._object as ^code.StaticSlot;
        if static_
        {
            # Pull out the initializer.
            generate_static_slot(g, slot.name.data() as str, slot);
        }
        else
        {
            # Load the static slot value.
            let val: ^llvm.LLVMOpaqueValue;
            val = llvm.LLVMBuildLoad(g.irb, slot.handle, "" as ^int8);

            # Wrap it in a handle.
            code.make_value(slot.type_, val);
        }
    }
    else if handle._tag == code.TAG_LOCAL_SLOT
    {
        # Load the local slot value.
        let slot: ^code.LocalSlot = handle._object as ^code.LocalSlot;
        let val: ^llvm.LLVMOpaqueValue;
        val = llvm.LLVMBuildLoad(g.irb, slot.handle, "" as ^int8);

        # Wrap it in a handle.
        code.make_value(slot.type_, val);
    }
    else if handle._tag == code.TAG_VALUE
    {
        # Clone the value object.
        let val: ^code.Value = handle._object as ^code.Value;
        code.make_value(val.type_, val.handle);
    }
    else {
        # No idea how to handle this.
        code.make_nil();
    }
}
