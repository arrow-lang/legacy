import types;
import libc;
import string;
import llvm;
import ast;
import list;
import code;
import errors;
import dict;
import generator_;
import generator_util;
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
        else if val._tag == code.TAG_ATTACHED_FUNCTION
        {
            generate_attached_function(g, key,
                                       val._object as ^code.AttachedFunction);
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
                or val._tag == code.TAG_STRUCT
                or val._tag == code.TAG_EXTERN_STATIC
                or val._tag == code.TAG_EXTERN_FUNC
        {
            # Do nothing; these do not need definitions.
            continue;
        }
        else
        {
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr, "not implemented: generator_def.generate(%d)" as ^int8, val._tag);
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
        return code.make_value(x.type_, code.VC_RVALUE, init);
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
        val_han = to_value(g, han, code.VC_RVALUE, true);
    }
    else
    {
        # Get the type out of the static slot.
        let typ: ^code.Type = x.type_._object as ^code.Type;

        # Create a zero initializer for the type.
        let val: ^llvm.LLVMOpaqueValue = llvm.LLVMConstNull(typ.handle);

        # Wrap in a value.
        val_han = code.make_value(x.type_, code.VC_RVALUE, val);
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
    # Set the current function.
    let prev_fn: ^code.Function = g.current_function;
    g.current_function = x;

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
        val = llvm.LLVMBuildAlloca(
            g.irb, prm_type.handle,
            prm.name.data());

        # Get the parameter handle.
        let prm_val: ^llvm.LLVMOpaqueValue;
        prm_val = llvm.LLVMGetParam(x.handle, i as uint32);

        # Store the parameter in the allocation.
        llvm.LLVMBuildStore(g.irb, prm_val, val);

        # Insert into the local scope.
        x.scope.insert(prm.name.data() as str, code.make_local_slot(
            prm.type_, false, val));

        # Continue.
        i = i + 1;
    }

    # Pull out the nodes that correspond to this function.
    let blk_node: ast.Node = x.context.block;
    let blk: ^ast.Block = blk_node.unwrap() as ^ast.Block;

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
    while i as uint < blk.nodes.size() {
        let node: ast.Node = blk.nodes.get(i);
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
        if i as uint >= blk.nodes.size() {
            res = han;
        }
    }

    # Have we encountered errors?
    if errors.count > 0 { return; }

    # Has the function been terminated?
    let last_block: ^llvm.LLVMOpaqueBasicBlock =
        llvm.LLVMGetLastBasicBlock(x.handle);
    if not generator_util.is_terminated(last_block) {
        # Not terminated; we need to close the function.
        if code.isnil(res)
        {
            # We did not get a result; but we need to check if we
            # "should" have gotten a result.
            if type_.return_type._tag == code.TAG_VOID_TYPE
            {
                llvm.LLVMBuildRetVoid(g.irb);
                void;
            }
            else
            {
                # We should have gotten a result.
                # Report error.
                let mut s_typename: string.String =
                    code.typename(type_.return_type);
                errors.begin_error();
                errors.libc.fprintf(errors.libc.stderr,
                               "mismatched types: expected '%s' but found nothing" as ^int8,
                               s_typename.data());
                errors.end();

                # Dispose.
                s_typename.dispose();
            }
        }
        else
        {
            if type_.return_type._tag == code.TAG_VOID_TYPE
            {
                llvm.LLVMBuildRetVoid(g.irb);
            }
            else
            {
                let val_han: ^code.Handle = to_value(
                    g, res, code.VC_RVALUE, false);
                let typ: ^code.Handle = code.type_of(val_han) as ^code.Handle;
                if not generator_util.type_compatible(
                    type_.return_type,
                    typ)
                {
                    return;
                }

                if typ._tag == code.TAG_VOID_TYPE
                {
                    llvm.LLVMBuildRetVoid(g.irb);
                }
                else
                {
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

    # Unset the current function.
    g.current_function = prev_fn;
}

# Attached Function [TAG_ATTACHED_FUNCTION]
# -----------------------------------------------------------------------------
def generate_attached_function(&mut g: generator_.Generator, qname: str,
                               x: ^code.AttachedFunction)
{
    # Generate as a normal function.
    generate_function(g, qname, x as ^code.Function);
}

# Internal
# =============================================================================

# Check if this handle is an assignable l-value.
# -----------------------------------------------------------------------------
def is_assignable(&mut g: generator_.Generator, handle: ^code.Handle) -> bool
{
    if handle._tag == code.TAG_STATIC_SLOT { true; }
    else if handle._tag == code.TAG_LOCAL_SLOT {
        true;
    }
    else if handle._tag == code.TAG_VALUE {
        let val: ^code.Value = handle._object as ^code.Value;
        val.category == code.VC_LVALUE;
    }
    else if handle._tag == code.TAG_TUPLE {
        let val: ^code.Tuple = handle._object as ^code.Tuple;
        val.assignable;
    }
    else if handle._tag == code.TAG_FUNCTION {
        false;
    }
    else if handle._tag == code.TAG_ATTACHED_FUNCTION {
        false;
    }
    else if handle._tag == code.TAG_EXTERN_STATIC {
        true;
    }
    else if handle._tag == code.TAG_EXTERN_FUNC {
        false;
    }
    else {
        # No idea how to handle this.
        false;
    }
}

# Coerce an arbitary handle to a value.
# -----------------------------------------------------------------------------
def to_value(&mut g: generator_.Generator,
             handle: ^code.Handle,
             category: int,
             static_: bool) -> ^code.Handle
{
    if handle._tag == code.TAG_STATIC_SLOT
    {
        let slot: ^code.StaticSlot = handle._object as ^code.StaticSlot;
        if category == code.VC_RVALUE
        {
            if static_
            {
                # Pull out the initializer.
                generate_static_slot(g, slot.name.data() as str, slot);
            }
            else if slot.type_._tag == code.TAG_ARRAY_TYPE
            {
                # We have an array type.
                # Wrap it in a handle.
                code.make_value(slot.type_, category, slot.handle);
            }
            else
            {
                # Load the static slot value.
                let val: ^llvm.LLVMOpaqueValue;
                val = llvm.LLVMBuildLoad(g.irb, slot.handle, "" as ^int8);

                # Wrap it in a handle.
                code.make_value(slot.type_, category, val);
            }
        }
        else
        {
            # Wrap and return the slot as an lvalue.
            code.make_value(slot.type_, code.VC_LVALUE, slot.handle);
        }
    }
    else if handle._tag == code.TAG_LOCAL_SLOT
    {
        let slot: ^code.LocalSlot = handle._object as ^code.LocalSlot;
        if category == code.VC_RVALUE
        {
            if slot.type_._tag == code.TAG_ARRAY_TYPE
            {
                # We have an array type.
                # Wrap it in a handle.
                code.make_value(slot.type_, category, slot.handle);
            }
            else
            {
                # Load the local slot value.
                let val: ^llvm.LLVMOpaqueValue;
                val = llvm.LLVMBuildLoad(g.irb, slot.handle, "" as ^int8);

                # Wrap it in a handle.
                code.make_value(slot.type_, code.VC_RVALUE, val);
            }
        }
        else
        {
            # Wrap and return the slot as an lvalue.
            code.make_value(slot.type_, code.VC_LVALUE, slot.handle);
        }
    }
    else if handle._tag == code.TAG_VALUE
    {
        let val: ^code.Value = handle._object as ^code.Value;
        if category == 0 or category == val.category
        {
            # Clone the value object.
            code.make_value_c(handle._context, val.type_, val.category,
                              val.handle);
        }
        else if category == code.VC_RVALUE
        {
            if val.type_._tag == code.TAG_ARRAY_TYPE
            {
                # We have an array type.
                # Wrap it in a handle.
                code.make_value(val.type_, category, val.handle);
            }
            else
            {
                # Perform a "LOAD" and get the r-value from the l-value.
                let obj: ^llvm.LLVMOpaqueValue;
                obj = llvm.LLVMBuildLoad(g.irb, val.handle, "" as ^int8);

                # Wrap it in a handle.
                code.make_value(val.type_, code.VC_RVALUE, obj);
            }
        }
        else
        {
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr, "cannot coerce a r-value as a l-value" as ^int8);
            errors.end();
            code.make_nil();
        }
    }
    else if handle._tag == code.TAG_FUNCTION {
        # Get the function handle.
        let fn: ^code.Function = handle._object as ^code.Function;

        # Get the type of the function.
        let fn_type_handle: ^code.Handle = fn.type_;
        let fn_type: ^code.Type = fn_type_handle._object as ^code.Type;

        # Create a handle of the function.
        code.make_value(fn_type_handle, code.VC_LVALUE, fn.handle);
    }
    else if handle._tag == code.TAG_ATTACHED_FUNCTION {
        # Get the function handle.
        let fn: ^code.AttachedFunction = handle._object as ^code.AttachedFunction;

        # Get the type of the function.
        let fn_type_handle: ^code.Handle = fn.type_;
        let fn_type: ^code.Type = fn_type_handle._object as ^code.Type;

        # Create a handle of the function.
        code.make_value(fn_type_handle, code.VC_LVALUE, fn.handle);
    }
    else if handle._tag == code.TAG_EXTERN_STATIC {
        # Get the handle.
        let slot: ^code.ExternStatic = handle._object as ^code.ExternStatic;

        # Get the type of the handle.
        let type_handle: ^code.Handle = slot.type_;
        let type_: ^code.Type = type_handle._object as ^code.Type;

        # Ensure our external handle has been declared.
        # FIXME: This should be handled in a utility
        if slot.handle == 0 as ^llvm.LLVMOpaqueValue
        {
            slot.handle = llvm.LLVMAddGlobal(
                g.mod, type_.handle, slot.name.data());
        }

        let val: ^llvm.LLVMOpaqueValue;
        if category == code.VC_RVALUE {
            # Load the slot value.
            val = llvm.LLVMBuildLoad(g.irb, slot.handle, "" as ^int8);
        } else {
            # Use the slot handle.
            val = slot.handle;
        }

        # Create a handle of the function.
        code.make_value(type_handle, code.VC_LVALUE, val);
    }
    else if handle._tag == code.TAG_EXTERN_FUNC {
        # Get the function handle.
        let fn: ^code.ExternFunction = handle._object as ^code.ExternFunction;

        # Get the type of the function.
        let fn_type_handle: ^code.Handle = fn.type_;
        let fn_type: ^code.Type = fn_type_handle._object as ^code.Type;

        # Ensure our external handle has been declared.
        # FIXME: This should be handled in a utility
        if fn.handle == 0 as ^llvm.LLVMOpaqueValue
        {
            # Add the function to the module.
            fn.handle = llvm.LLVMAddFunction(
                g.mod, fn.name.data(), fn_type.handle);
        }

        # Create a handle of the function.
        code.make_value(fn_type_handle, code.VC_LVALUE, fn.handle);
    }
    else if handle._tag == code.TAG_TUPLE {
        # Get us as a tuple.
        let tuple_: ^code.Tuple = handle._object as ^code.Tuple;

        # Get our target (tuple) type
        let type_: ^code.Handle = tuple_.type_;
        let tuple_type: ^code.TupleType = type_._object as ^code.TupleType;

        # Create and zero a list to hold the entire argument list.
        let mut argl: list.List = list.make(types.PTR);
        argl.reserve(tuple_type.elements.size);
        argl.size = tuple_type.elements.size;
        libc.memset(argl.elements as ^void, 0, (argl.size * argl.element_size) as int32);
        let argv: ^mut ^llvm.LLVMOpaqueValue = argl.elements as ^^llvm.LLVMOpaqueValue;

        # Iterate through each element in the tuple and push into the
        # argument list.
        let mut i: int = 0;
        while i as uint < tuple_.handles.size
        {
            # Get the handle out.
            let han: ^code.Handle = tuple_.handles.at_ptr(i) as ^code.Handle;

            # Resolve the type of the element expression.
            let el_type: ^code.Handle = tuple_type.elements.at_ptr(i) as ^code.Handle;

            # Coerce this to a value.
            let val_han: ^code.Handle = to_value(
                g, han, code.VC_RVALUE, false);

            # Cast the value to the target type.
            let cast_han: ^code.Handle = generator_util.cast(
                g, val_han, el_type, false);
            if code.isnil(cast_han) { return code.make_nil(); }
            let cast_val: ^code.Value = cast_han._object as ^code.Value;

            # Emplace in the argument list.
            (argv + i)^ = cast_val.handle;

            # Dispose.
            code.dispose(val_han);
            code.dispose(cast_han);

            # Increment
            i = i + 1;
        }

        # We can only generate an initial "constant" structure for a
        # purely constant literal.
        # Collect indicies and values of non-constant members of the
        # literal.
        let mut nonconst_values: list.List = list.make(types.PTR);
        let mut nonconst_indicies: list.List = list.make(types.INT);
        i = 0;
        while i as uint < argl.size {
            let arg: ^llvm.LLVMOpaqueValue = (argv + i)^;
            i = i + 1;

            # Is this not some kind of "constant"?
            if llvm.LLVMIsConstant(arg) == 0 {
                # Yep; store and zero out the value.
                nonconst_indicies.push_int(i - 1);
                nonconst_values.push_ptr(arg as ^void);
                (argv + (i - 1))^ = llvm.LLVMGetUndef(llvm.LLVMTypeOf(arg));
            }
        }

        # Build the "call" instruction (and create the constant struct).
        let mut val: ^llvm.LLVMOpaqueValue;
        val = llvm.LLVMConstStruct(argv, argl.size as uint32, false);

        # Iterate through our non-constant values and push them in.
        i = 0;
        while i as uint < nonconst_indicies.size {
            let arg: ^llvm.LLVMOpaqueValue = nonconst_values.at_ptr(i) as
                ^llvm.LLVMOpaqueValue;
            let idx: int = nonconst_indicies.at_int(i);
            i = i + 1;

            # Build the `insertvalue` instruction.
            val = llvm.LLVMBuildInsertValue(
                g.irb, val, arg, idx as uint32, "" as ^int8);
        }

        # Dispose of dynamic memory.
        nonconst_values.dispose();
        nonconst_indicies.dispose();
        argl.dispose();

        if category == code.VC_LVALUE {
            # Converting a `tuple` to an l-value really just involves
            # temporarily storing the tuple and returning its address.
            let slot_val: ^llvm.LLVMOpaqueValue =
                llvm.LLVMBuildAlloca(g.irb, llvm.LLVMTypeOf(val),
                                     "" as ^int8);

            # Store this in the temp. slot.
            llvm.LLVMBuildStore(g.irb, val, slot_val);

            # Wrap and return the value.
            code.make_value(type_, code.VC_LVALUE, slot_val);
        } else {
            # Wrap and return the value.
            code.make_value(type_, code.VC_RVALUE, val);
        }
    }
    else {
        # No idea how to handle this.
        code.make_nil();
    }
}

# Assignment
# -----------------------------------------------------------------------------
def assign(&mut g: generator_.Generator,
           target: ^code.Handle,
           lhs: ^code.Handle,
           rhs: ^code.Handle) {

    # Perform the assignment (based on what we have in the LHS).
    if ((lhs._tag == code.TAG_STATIC_SLOT) or
        (lhs._tag == code.TAG_EXTERN_STATIC))
    {
        # Coerce the operand to its value.
        let rhs_val_han: ^code.Handle = to_value(g, rhs, code.VC_RVALUE, false);
        if code.isnil(rhs_val_han) { return; }

        # Cast the operand to the target type.
        let rhs_han: ^code.Handle = generator_util.cast(
            g, rhs_val_han, target, false);
        if code.isnil(rhs_han) { return; }

        # Cast to a value.
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Get the real object.
        let slot: ^code.StaticSlot = lhs._object as ^code.StaticSlot;

        # Ensure that we are mutable.
        if not slot.context.mutable {
            # Report error and return nil.
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "cannot assign to immutable static item" as ^int8);
            errors.end();
            return;
        }

        # Build the `STORE` operation.
        llvm.LLVMBuildStore(g.irb, rhs_val.handle, slot.handle);

        # Dispose.
        code.dispose(rhs_val_han);
        code.dispose(rhs_han);
    } else if lhs._tag == code.TAG_LOCAL_SLOT {
        # Coerce the operand to its value.
        let rhs_val_han: ^code.Handle = to_value(g, rhs, code.VC_RVALUE, false);
        if code.isnil(rhs_val_han) { return; }

        # Cast the operand to the target type.
        let rhs_han: ^code.Handle = generator_util.cast(
            g, rhs_val_han, target, false);
        if code.isnil(rhs_han) { return; }

        # Cast to a value.
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Get the real object.
        let slot: ^code.LocalSlot = lhs._object as ^code.LocalSlot;

        # Ensure that we are mutable.
        if not slot.mutable {
            # Report error and return nil.
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "re-assignment to immutable local slot" as ^int8);
            errors.end();
            return;
        }

        # Build the `STORE` operation.
        llvm.LLVMBuildStore(g.irb, rhs_val.handle, slot.handle);

        # Dispose.
        code.dispose(rhs_val_han);
        code.dispose(rhs_han);
    } else if lhs._tag == code.TAG_VALUE {
        # Coerce the operand to its value.
        let rhs_val_han: ^code.Handle = to_value(g, rhs, code.VC_RVALUE, false);
        if code.isnil(rhs_val_han) { return; }

        # Cast the operand to the target type.
        let rhs_han: ^code.Handle = generator_util.cast(
            g, rhs_val_han, target, false);
        if code.isnil(rhs_han) { return; }

        # Cast to a value.
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Get the value.
        let value: ^code.Value = lhs._object as ^code.Value;
        if value.category == code.VC_RVALUE {
            # Report error and return nil.
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "left-hand side expression is not assignable" as ^int8);
            errors.end();
            return;
        }

        # Build the `STORE` operation.
        llvm.LLVMBuildStore(g.irb, rhs_val.handle, value.handle);

        # Dispose.
        code.dispose(rhs_val_han);
        code.dispose(rhs_han);
    } else if lhs._tag == code.TAG_TUPLE {
        # Get this as a tuple.
        let tuple_: ^code.Tuple = lhs._object as ^code.Tuple;
        if not tuple_.assignable {
            # Report error and return nil.
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "left-hand side expression is not assignable" as ^int8);
            errors.end();
            return;
        }

        # Coerce the operand to its value.
        let rhs_val_han: ^code.Handle = to_value(g, rhs, code.VC_LVALUE, false);
        if code.isnil(rhs_val_han) { return; }

        # Cast to a value.
        let rhs_val: ^code.Value = rhs_val_han._object as ^code.Value;

        # We know that we are assignable; perform the assignment for each
        # element (LHS) to the correct offset of the tuple value (RHS).
        let mut i: int = 0;
        while i as uint < tuple_.handles.size {
            # Build an accessor to the member of the tuple.
            let val: ^llvm.LLVMOpaqueValue =
                llvm.LLVMBuildStructGEP(
                    g.irb, rhs_val.handle, i as uint32, "" as ^int8);

            # Get the element handle.
            let el: ^code.Handle = tuple_.handles.at_ptr(i) as ^code.Handle;

            # Get the type of the element.
            let el_type: ^code.Handle = code.type_of(el);

            # Build the rhs handle
            let rhs_el_han: ^code.Handle = code.make_value(
                el_type, code.VC_LVALUE, val);

            # Perform the assignment operation.
            assign(g, el_type, el, rhs_el_han);

            # Increment index.
            i = i + 1;
        }

        # Dispose.
        code.dispose(rhs_val_han);
    }
}
