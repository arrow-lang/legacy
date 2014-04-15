import llvm;
import string;
import libc;
import ast;
import parser;
import errors;
import dict;
import list;
import types;
import code;

# A code generator that is capable of going from an arbitrary node in the
# AST into a llvm module.
# =============================================================================
type Generator {
    # The LLVM module that encapsulates the IR.
    mod: ^mut llvm.LLVMOpaqueModule,

    # A LLVM instruction builder that simplifies much of the IR generation
    # process by managing what block we're on, etc.
    irb: ^mut llvm.LLVMOpaqueBuilder,

    # A dictionary of "items" that have been declared. These can be
    # `types`, `functions`, or `modules`.
    mut items: dict.Dictionary,

    # A dictionary parallel to "items" that is the nodes left over
    # from extracting the "items".
    mut nodes: dict.Dictionary,

    # The stack of namespaces that represent our current "item" scope.
    mut ns: list.List,

    # The top-level namespace.
    mut top_ns: string.String,

    # Jump table for the type resolver.
    mut type_resolvers: (def (^mut Generator, ^code.Handle, ^code.Scope, ^ast.Node) -> ^code.Handle)[100],

    # Jump table for the builder.
    mut builders: (def (^mut Generator, ^code.Handle, ^mut code.Scope, ^ast.Node) -> ^code.Handle)[100]
}

implement Generator {

# Dispose of internal resources used during code generation.
# -----------------------------------------------------------------------------
def dispose(&mut self) {
    # Dispose of the LLVM module.
    llvm.LLVMDisposeModule(self.mod);

    # Dispose of the instruction builder.
    llvm.LLVMDisposeBuilder(self.irb);

    # Dispose of our "items" dictionary.
    # FIXME: Dispose of each "item".
    self.items.dispose();
    self.nodes.dispose();

    # Dispose of our namespace list.
    self.ns.dispose();
}

# Begin the generation process seeded by the passed AST node.
# -----------------------------------------------------------------------------
def generate(&mut self, name: str, &node: ast.Node) {
    # Construct a LLVM module to hold the geneated IR.
    self.mod = llvm.LLVMModuleCreateWithName(name as ^int8);

    # Construct an instruction builder.
    self.irb = llvm.LLVMCreateBuilder();

    # Initialize the internal data structures.
    self.items = dict.make(65535);
    self.nodes = dict.make(65535);
    self.ns = list.make(types.STR);
    self.top_ns = string.make();

    # Build the type resolution jump table.
    self.type_resolvers[ast.TAG_BOOLEAN] = resolve_bool_expr;
    self.type_resolvers[ast.TAG_INTEGER] = resolve_int_expr;
    self.type_resolvers[ast.TAG_FLOAT] = resolve_float_expr;
    self.type_resolvers[ast.TAG_ADD] = resolve_add_expr;
    self.type_resolvers[ast.TAG_SUBTRACT] = resolve_sub_expr;
    self.type_resolvers[ast.TAG_MULTIPLY] = resolve_mul_expr;
    self.type_resolvers[ast.TAG_DIVIDE] = resolve_div_expr;
    self.type_resolvers[ast.TAG_INTEGER_DIVIDE] = resolve_int_div_expr;
    self.type_resolvers[ast.TAG_MODULO] = resolve_mod_expr;
    self.type_resolvers[ast.TAG_LOGICAL_AND] = resolve_logical_expr_b;
    self.type_resolvers[ast.TAG_LOGICAL_OR] = resolve_logical_expr_b;
    self.type_resolvers[ast.TAG_LOGICAL_NEGATE] = resolve_logical_expr_u;
    self.type_resolvers[ast.TAG_IDENT] = resolve_type_ident;
    self.type_resolvers[ast.TAG_TYPE_EXPR] = resolve_type_expr;
    self.type_resolvers[ast.TAG_RETURN] = resolve_type_id;
    self.type_resolvers[ast.TAG_LOCAL_SLOT] = resolve_type_id;
    self.type_resolvers[ast.TAG_CALL] = resolve_call_expr;
    self.type_resolvers[ast.TAG_EQ] = resolve_eq_expr;
    self.type_resolvers[ast.TAG_NE] = resolve_ne_expr;
    self.type_resolvers[ast.TAG_MEMBER] = resolve_member_expr;
    self.type_resolvers[ast.TAG_GLOBAL] = resolve_global;
    self.type_resolvers[ast.TAG_CONDITIONAL] = resolve_conditional_expr;

    # Build the builder jump table.
    self.builders[ast.TAG_BOOLEAN] = build_bool_expr;
    self.builders[ast.TAG_INTEGER] = build_int_expr;
    self.builders[ast.TAG_FLOAT] = build_float_expr;
    self.builders[ast.TAG_IDENT] = build_ident_expr;
    self.builders[ast.TAG_ADD] = build_add_expr;
    self.builders[ast.TAG_INTEGER_DIVIDE] = build_int_div_expr;
    self.builders[ast.TAG_DIVIDE] = build_div_expr;
    self.builders[ast.TAG_SUBTRACT] = build_sub_expr;
    self.builders[ast.TAG_MULTIPLY] = build_mul_expr;
    self.builders[ast.TAG_MODULO] = build_mod_expr;
    self.builders[ast.TAG_RETURN] = build_ret;
    self.builders[ast.TAG_CALL] = build_call_expr;
    self.builders[ast.TAG_EQ] = build_eq_expr;
    self.builders[ast.TAG_NE] = build_ne_expr;
    self.builders[ast.TAG_MEMBER] = build_member_expr;
    self.builders[ast.TAG_LOGICAL_NEGATE] = build_logical_neg_expr;
    self.builders[ast.TAG_LOCAL_SLOT] = build_local_slot;
    self.builders[ast.TAG_CONDITIONAL] = build_conditional_expr;

    # Add basic type definitions.
    self._declare_basic_types();

    # Add `assert` built-in.
    self._declare_assert();

    # Generation is a complex beast. So we first need to break apart
    # the declarations or "items" from the nodes. As all nodes are owned
    # by "some" declaration (`module`, `function`, `struct`, etc.) this
    # effectually removes the AST structure.
    self._extract_item(node);
    if errors.count > 0 { return; }

    # Next we resolve the type of each item that we extracted.
    self._gen_types();
    if errors.count > 0 { return; }

    # Next we generate decls for each "item".
    self._gen_decls();
    if errors.count > 0 { return; }

    # Next we generate defs for each "item".
    self._gen_defs();
    if errors.count > 0 { return; }

    # Generate a main function.
    self._declare_main();
}

# Coerce an arbitary handle to a value.
# -----------------------------------------------------------------------------
# This can cause a LOAD.
def _to_value(&mut self, handle: ^code.Handle, static_: bool) -> ^code.Handle {
    if handle._tag == code.TAG_STATIC_SLOT {
        let slot: ^code.StaticSlot = handle._object as ^code.StaticSlot;
        if static_ {
            # Pull out the initializer.
            self._gen_def_static_slot(slot.name.data() as str, slot);
        } else {
            # Load the static slot value.
            let val: ^llvm.LLVMOpaqueValue;
            val = llvm.LLVMBuildLoad(self.irb, slot.handle, "" as ^int8);

            # Wrap it in a handle.
            code.make_value(slot.type_, val);
        }
    } else if handle._tag == code.TAG_LOCAL_SLOT {
        let slot: ^code.LocalSlot = handle._object as ^code.LocalSlot;
        # Load the local slot value.
        let val: ^llvm.LLVMOpaqueValue;
        val = llvm.LLVMBuildLoad(self.irb, slot.handle, "" as ^int8);

        # Wrap it in a handle.
        code.make_value(slot.type_, val);
    } else if handle._tag == code.TAG_VALUE {
        # Clone the value object.
        let val: ^code.Value = handle._object as ^code.Value;
        code.make_value(val.type_, val.handle);
    } else {
        # No idea how to handle this.
        code.make_nil();
    }
}

# Create a cast from a value to a type.
# -----------------------------------------------------------------------------
def _cast(&mut self, handle: ^code.Handle, type_: ^code.Handle)
        -> ^code.Handle {
    # Get the value of the handle.
    let src_val: ^code.Value = handle._object as ^code.Value;

    # Get the type of the value handle.
    let src_han: ^code.Handle = src_val.type_;

    # Get the src/dst types.
    let src: ^code.Type = src_han._object as ^code.Type;
    let dst: ^code.Type = type_._object as ^code.Type;

    # Are these the "same" type?
    if src == dst {
        # Wrap and return our val.
        return code.make_value(type_, src_val.handle);
    }

    # Build the cast.
    let val: ^llvm.LLVMOpaqueValue;
    if src_han._tag == code.TAG_INT_TYPE and src_han._tag == type_._tag {
        # Get the int_ty out.
        let src_int: ^code.IntegerType = src as ^code.IntegerType;
        let dst_int: ^code.IntegerType = dst as ^code.IntegerType;

        if dst_int.bits > src_int.bits {
            # Create a ZExt or SExt.
            if src_int.signed {
                val = llvm.LLVMBuildSExt(self.irb, src_val.handle, dst.handle,
                                         "" as ^int8);
            } else {
                val = llvm.LLVMBuildZExt(self.irb, src_val.handle, dst.handle,
                                         "" as ^int8);
            }
        } else {
            # Create a Trunc
            val = llvm.LLVMBuildTrunc(self.irb, src_val.handle, dst.handle,
                                      "" as ^int8);
        }
    } else if src_han._tag == code.TAG_FLOAT_TYPE
            and src_han._tag == type_._tag {
        # Get float_ty out.
        let src_f: ^code.FloatType = src as ^code.FloatType;
        let dst_f: ^code.FloatType = dst as ^code.FloatType;

        if dst_f.bits > src_f.bits {
            # Create a Ext
            val = llvm.LLVMBuildFPExt(self.irb, src_val.handle, dst.handle,
                                      "" as ^int8);
        } else {
            # Create a Trunc
            val = llvm.LLVMBuildFPTrunc(self.irb, src_val.handle, dst.handle,
                                        "" as ^int8);
        }
    } else if src_han._tag == code.TAG_FLOAT_TYPE
            and type_._tag == code.TAG_INT_TYPE {
        # Get ty out.
        let src_ty: ^code.FloatType = src as ^code.FloatType;
        let dst_ty: ^code.IntegerType = dst as ^code.IntegerType;

        if dst_ty.signed {
            val = llvm.LLVMBuildFPToSI(self.irb, src_val.handle, dst.handle,
                                       "" as ^int8);
        } else {
            val = llvm.LLVMBuildFPToUI(self.irb, src_val.handle, dst.handle,
                                       "" as ^int8);
        }
    } else if src_han._tag == code.TAG_INT_TYPE
            and type_._tag == code.TAG_FLOAT_TYPE {
        # Get ty out.
        let src_ty: ^code.IntegerType = src as ^code.IntegerType;
        let dst_ty: ^code.FloatType = dst as ^code.FloatType;

        if src_ty.signed {
            val = llvm.LLVMBuildSIToFP(self.irb, src_val.handle, dst.handle,
                                       "" as ^int8);
        } else {
            val = llvm.LLVMBuildUIToFP(self.irb, src_val.handle, dst.handle,
                                       "" as ^int8);
        }
    }

    # Wrap and return.
    code.make_value(type_, val);
}

# Qualify a name in context of the passed namespace.
# -----------------------------------------------------------------------------
def _qualify_name_in(&self, s: str, ns: list.List) -> string.String {
    let mut qn: string.String;
    qn = string.join(".", ns);
    if qn.size() > 0 { qn.append('.'); }
    qn.extend(s);
    qn;
}

# Qualify the passed name in the current namespace.
# -----------------------------------------------------------------------------
def _qualify_name(&self, s: str) -> string.String {
    self._qualify_name_in(s, self.ns);
}

# Get the "item" using the scoping rules in the passed scope and namespace.
# -----------------------------------------------------------------------------
def _get_scoped_item_in(&self, s: str, scope: ^code.Scope, _ns: list.List)
        -> ^code.Handle {
    # Check if the name is declared in the passed local scope.
    if scope <> 0 as ^code.Scope {
        if (scope^).contains(s) {
            # Get and return the item.
            return (scope^).get(s);
        }
    }

    # Qualify the name reference and match against the enclosing
    # scopes by resolving inner-most first and popping namespaces until
    # a match.
    let mut qname: string.String = string.make();
    let mut ns: list.List = _ns.clone();
    let mut matched: bool = false;
    loop {
        # Qualify the name by joining the namespaces.
        qname.dispose();
        qname = self._qualify_name_in(s, ns);

        # Check for the qualified identifier in the `global` scope.
        if self.items.contains(qname.data() as str) {
            # Found it in the currently resolved scope.
            matched = true;
            break;
        }

        # Do we have any namespaces left.
        if ns.size > 0 {
            ns.erase(-1);
        } else {
            # Out of namespaces to pop.
            break;
        }
    }

    # If we matched; return the item.
    if matched {
        self.items.get_ptr(qname.data() as str) as ^code.Handle;
    } else {
        code.make_nil();
    }
}

# Generate the `definition` of each "item".
# -----------------------------------------------------------------------------
def _gen_defs(&mut self) {
    # Iterate over the "items" dictionary.
    let mut i: dict.Iterator = self.items.iter();
    let mut key: str;
    let mut ptr: ^void;
    let mut val: ^code.Handle;
    while not i.empty() {
        # Grab the next "item"
        (key, ptr) = i.next();
        val = ptr as ^code.Handle;

        if val._tag == code.TAG_STATIC_SLOT {
            self._gen_def_static_slot(key, val._object as ^code.StaticSlot);
        } else if val._tag == code.TAG_FUNCTION {
            self._gen_def_function(key, val._object as ^code.Function);
        }
    }
}

def _gen_def_static_slot(&mut self, qname: str, x: ^code.StaticSlot)
        -> ^code.Handle {
    # Is our def resolved?
    let init: ^llvm.LLVMOpaqueValue;
    init = llvm.LLVMGetInitializer(x.handle);
    if init <> 0 as ^llvm.LLVMOpaqueValue {
        # Yes; wrap and return it.
        code.make_value(x.type_, init);
    } else {
        # Resolve the type of the initializer.
        let typ: ^code.Handle;
        typ = resolve_targeted_type_in(
            &self, x.type_, &x.context.initializer, &x.namespace);
        if code.isnil(typ) { return code.make_nil(); }

        # Build the initializer
        let han: ^code.Handle;
        han = build_in(&self, typ, code.make_nil_scope(),
                       &x.context.initializer,
                       &x.namespace);
        if code.isnil(han) { return code.make_nil(); }

        # Coerce this to a value.
        let val_han: ^code.Handle = self._to_value(han, true);
        let val: ^code.Value = val_han._object as ^code.Value;

        # Set the initializer on the static slot.
        llvm.LLVMSetInitializer(x.handle, val.handle);

        # Dispose.
        code.dispose(val_han);

        # Return the initializer.
        han;
    }
}

def _gen_def_function(&mut self, qname: str, x: ^code.Function)
        -> ^code.Handle {

    # Has this function been generated?
    if llvm.LLVMCountBasicBlocks(x.handle) > 0 {
        # Yes; skip.
        return code.make_nil();
    }

    # Create a basic block for the function definition.
    let entry: ^llvm.LLVMOpaqueBasicBlock;
    entry = llvm.LLVMAppendBasicBlock(x.handle, "" as ^int8);

    # Remember the insert block.
    let cur_block: ^llvm.LLVMOpaqueBasicBlock;
    cur_block = llvm.LLVMGetInsertBlock(self.irb);

    # Set the insertion point.
    llvm.LLVMPositionBuilderAtEnd(self.irb, entry);

    # Pull out the type node.
    let type_: ^code.FunctionType = x.type_._object as ^code.FunctionType;

    # Allocate the parameter nodes into the local scope.
    let mut i: int = 0;
    while i as uint < type_.parameters.size {
        # Get the parameter node.
        let prm_han: ^code.Handle =
            type_.parameters.at_ptr(i) as ^code.Handle;
        let prm: ^code.Parameter = prm_han._object as ^code.Parameter;

        # Get the type handle.
        let prm_type: ^code.Type = prm.type_._object as ^code.Type;

        # Allocate this param.
        let val: ^llvm.LLVMOpaqueValue;
        val = llvm.LLVMBuildAlloca(self.irb, prm_type.handle, prm.name.data());

        # Get the parameter handle.
        let prm_val: ^llvm.LLVMOpaqueValue;
        prm_val = llvm.LLVMGetParam(x.handle, i as uint32);

        # Store the parameter in the allocation.
        llvm.LLVMBuildStore(self.irb, prm_val, val);

        # Insert into the local scope.
        x.scope.insert(prm.name.data() as str, code.make_local_slot(
            prm.type_, val));

        # Continue.
        i = i + 1;
    }

    # Pull out the nodes that correspond to this function.
    let nodes: ^ast.Nodes = self.nodes.get_ptr(qname) as ^ast.Nodes;

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
        let target: ^code.Handle = resolve_type_in(
            &self, &node, ret_type_target, &x.scope, &ns);
        if cur_count < errors.count { continue; }

        # Build the node.
        let han: ^code.Handle = build_in(
            &self, target, &x.scope, &node, &ns);

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
            llvm.LLVMBuildRetVoid(self.irb);
        } else {
            if type_.return_type._tag == code.TAG_VOID_TYPE {
                llvm.LLVMBuildRetVoid(self.irb);
            } else {
                let val_han: ^code.Handle = self._to_value(res, false);
                let typ: ^code.Handle = code.type_of(val_han) as ^code.Handle;
                if typ._tag == code.TAG_VOID_TYPE {
                    llvm.LLVMBuildRetVoid(self.irb);
                } else {
                    let val: ^code.Value = val_han._object as ^code.Value;
                    llvm.LLVMBuildRet(self.irb, val.handle);
                }
            }
        }
    }

    # Dispose.
    ns.dispose();

    # Reset to the old insert block.
    llvm.LLVMPositionBuilderAtEnd(self.irb, cur_block);

    # FIXME: Function defs always resolve to the address of the function.
    code.make_nil();
}

# Generate the `declaration` of each declaration "item".
# -----------------------------------------------------------------------------
def _gen_decls(&mut self) {
    # Iterate over the "items" dictionary.
    let mut i: dict.Iterator = self.items.iter();
    let mut key: str;
    let mut ptr: ^void;
    let mut val: ^code.Handle;
    while not i.empty() {
        # Grab the next "item"
        (key, ptr) = i.next();
        val = ptr as ^code.Handle;

        if val._tag == code.TAG_STATIC_SLOT {
            self._gen_decl_static_slot(key, val._object as ^code.StaticSlot);
        } else if val._tag == code.TAG_FUNCTION {
            self._gen_decl_function(key, val._object as ^code.Function);
        }
    }
}

def _gen_decl_static_slot(&mut self, qname: str, x: ^code.StaticSlot) {
    # Get the type node out of the handle.
    let type_: ^code.Type = x.type_._object as ^code.Type;

    # Add the global slot declaration to the IR.
    # TODO: Set priv, vis, etc.
    x.handle = llvm.LLVMAddGlobal(self.mod, type_.handle, qname as ^int8);

    # Set if this is constant.
    llvm.LLVMSetGlobalConstant(x.handle, not x.context.mutable);
}

def _gen_decl_function(&mut self, qname: str, x: ^code.Function) {
    if x.handle == 0 as ^llvm.LLVMOpaqueValue {
        # Get the type node out of the handle.
        let type_: ^code.FunctionType = x.type_._object as ^code.FunctionType;

        # Add the function to the module.
        # TODO: Set priv, vis, etc.
        x.handle = llvm.LLVMAddFunction(self.mod, qname as ^int8,
                                        type_.handle);
    }
}

# Generate the `type` of each declaration "item".
# -----------------------------------------------------------------------------
def _gen_types(&mut self) {
    # Iterate over the "items" dictionary.
    let mut i: dict.Iterator = self.items.iter();
    let mut key: str;
    let mut ptr: ^void;
    let mut val: ^code.Handle;
    while not i.empty() {
        # Grab the next "item"
        (key, ptr) = i.next();
        val = ptr as ^code.Handle;

        # Does this item need its `type` resolved?
        if val._tag == code.TAG_STATIC_SLOT
                or val._tag == code.TAG_FUNCTION {
            self._gen_type(val);
        }
    }
}

def _gen_type(&mut self, handle: ^code.Handle)
        -> ^code.Handle {
    # Resolve the type.
    if handle._tag == code.TAG_STATIC_SLOT {
        self._gen_type_static_slot(handle._object as ^code.StaticSlot);
    } else if handle._tag == code.TAG_FUNCTION {
        self._gen_type_func(handle._object as ^code.Function);
    } else {
        return code.make_nil();
    }
}

def _gen_type_static_slot(&mut self, x: ^code.StaticSlot)
        -> ^code.Handle {
    # Is our type resolved?
    if not code.isnil(x.type_) {
        # Yes; return it.
        x.type_;
    } else if not code.ispoison(x.type_) {
        # Get and resolve the type node.
        let han: ^code.Handle = resolve_type_in(
            &self, &x.context.type_, code.make_nil(),
            code.make_nil_scope(),
            &x.namespace);

        if han == 0 as ^code.Handle {
            # Failed to resolve type; mark us as poisioned.
            x.type_ = code.make_poison();
            return code.make_nil();
        }

        # Store the type handle.
        x.type_ = han;

        # Return our type.
        han;
    } else {
        # Return nil.
        code.make_nil();
    }
}

def _gen_type_func(&mut self, x: ^code.Function) -> ^code.Handle {
    # Is our type resolved?
    if not code.isnil(x.type_) {
        # Yes; return it.
        x.type_;
    } else if not code.ispoison(x.type_) {
        # Get the ret type handle.
        let ret_han: ^code.Handle = code.make_nil();
        let ret_typ_han: ^llvm.LLVMOpaqueType;
        if ast.isnull(x.context.return_type) {
            ret_typ_han = llvm.LLVMVoidType();
            ret_han = code.make_void_type(ret_typ_han);
            ret_typ_han;  # HACK!
        } else {
            # Get and resolve the return type.
            ret_han = resolve_type_in(
                &self, &x.context.return_type, code.make_nil(),
                &x.scope, &x.namespace);

            if ret_han == 0 as ^code.Handle {
                # Failed to resolve type; mark us as poisioned.
                x.type_ = code.make_poison();
                return code.make_nil();
            }

            # Get the ret type handle.
            let ret_typ: ^code.Type = ret_han._object as ^code.Type;
            ret_typ_han = ret_typ.handle;
        }

        # Resolve the type of each parameter.
        let mut params: list.List = list.make(types.PTR);
        let mut param_type_handles: list.List = list.make(types.PTR);
        let mut i: int = 0;
        let mut error: bool = false;
        while i as uint < x.context.params.size() {
            let pnode: ast.Node = x.context.params.get(i);
            i = i + 1;
            let p: ^ast.FuncParam = pnode.unwrap() as ^ast.FuncParam;

            # Resolve the type.
            let ptype_handle: ^code.Handle = resolve_type_in(
                &self, &p.type_, code.make_nil(), &x.scope, &x.namespace);
            if code.isnil(ptype_handle) { error = true; break; }
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

        if error { code.make_nil(); }
        else {
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
    } else {
        # Return nil.
        code.make_nil();
    }
}

# Extract declaration "items" from the AST and build our list of namespaced
# items.
# -----------------------------------------------------------------------------
def _extract_item(&mut self, node: ast.Node) -> bool {
    # Delegate to an appropriate function to handle the item
    # extraction.
    if node.tag == ast.TAG_MODULE {
        self._extract_item_mod(node.unwrap() as ^ast.ModuleDecl);
        true;
    } else if node.tag == ast.TAG_FUNC_DECL {
        self._extract_item_func(node.unwrap() as ^ast.FuncDecl);
        true;
    } else if node.tag == ast.TAG_STATIC_SLOT {
        self._extract_item_static_slot(node.unwrap() as ^ast.StaticSlotDecl);
        true;
    } else {
        false;
    }
}

def _extract_items(&mut self, extra: ^mut ast.Nodes, &nodes: ast.Nodes) {
    # Enumerate through each node and forward them to `_extract_item`.
    let mut i: int = 0;
    while i as uint < nodes.size() {
        let node: ast.Node = nodes.get(i);
        i = i + 1;
        if not self._extract_item(node) {
            (extra^).push(node);
        }
    }
}

def _extract_item_mod(&mut self, x: ^ast.ModuleDecl) {
    # Unwrap the name for the module.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;

    # Build the qual name for this module.
    let mut qname: string.String = self._qualify_name(
        id.name.data() as str);

    # Create a solid handle for the module.
    let han: ^code.Handle = code.make_module(
        id.name.data() as str, self.ns);

    # Set us as an `item`.
    self.items.set_ptr(qname.data() as str, han as ^void);

    # Set us as the `top` namespace if there isn't one yet.
    if self.top_ns.size() == 0  {
        self.top_ns.extend(id.name.data() as str);
    }

    # Push our name onto the namespace stack.
    self.ns.push_str(id.name.data() as str);

    # Generate each node in the module and place items that didn't
    # get extracted into the new node block.
    let nodes: ^mut ast.Nodes = ast.new_nodes();
    self._extract_items(nodes, x.nodes);
    self.nodes.set_ptr(qname.data() as str, nodes as ^void);

    # Pop our name off the namespace stack.
    self.ns.erase(-1);

    # Dispose of dynamic memory.
    qname.dispose();
}

def _extract_item_func(&mut self, x: ^ast.FuncDecl) {
    # Unwrap the name for the function.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;

    # Build the qual name for this function.
    let mut qname: string.String = self._qualify_name(id.name.data() as str);

    # Create a solid handle for the function (ignoring the type for now).
    let han: ^code.Handle = code.make_function(
        x, id.name.data() as str, self.ns, code.make_nil(),
        0 as ^llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    self.items.set_ptr(qname.data() as str, han as ^void);

    # Push our name onto the namespace stack.
    self.ns.push_str(id.name.data() as str);

    # Generate each node in the module and place items that didn't
    # get extracted into the new node block.
    let nodes: ^mut ast.Nodes = ast.new_nodes();
    self._extract_items(nodes, x.nodes);
    self.nodes.set_ptr(qname.data() as str, nodes as ^void);

    # Pop our name off the namespace stack.
    self.ns.erase(-1);

    # Dispose of dynamic memory.
    qname.dispose();
}

def _extract_item_static_slot(&mut self, x: ^ast.StaticSlotDecl) {
    # Unwrap the name for the slot.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;

    # Build the qual name for this slot.
    let mut qname: string.String = self._qualify_name(id.name.data() as str);

    # Create a solid handle for the slot (ignoring the type for now).
    let han: ^code.Handle = code.make_static_slot(
        x, id.name.data() as str, self.ns,
        code.make_nil(),
        0 as ^llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    self.items.set_ptr(qname.data() as str, han as ^void);
}

# Declare a type in `global` scope.
# -----------------------------------------------------------------------------
def _declare_type(&mut self, name: str, val: ^llvm.LLVMOpaqueType) {
    let han: ^code.Handle = code.make_type(val);
    self.items.set_ptr(name, han as ^void);
}

# Declare an integral type in `global` scope.
# -----------------------------------------------------------------------------
def _declare_int_type(&mut self, name: str, val: ^llvm.LLVMOpaqueType,
                      signed: bool, bits: uint) {
    let han: ^code.Handle = code.make_int_type(val, signed, bits);
    self.items.set_ptr(name, han as ^void);
}

# Declare a float type in `global` scope.
# -----------------------------------------------------------------------------
def _declare_float_type(&mut self, name: str, val: ^llvm.LLVMOpaqueType,
                        bits: uint) {
    let han: ^code.Handle = code.make_float_type(val, bits);
    self.items.set_ptr(name, han as ^void);
}

# Declare "basic" types
# -----------------------------------------------------------------------------
def _declare_basic_types(&mut self) {
    # Boolean
    self.items.set_ptr("bool", code.make_bool_type(
        llvm.LLVMInt1Type()) as ^void);

    # Signed machine-independent integers
    self._declare_int_type(  "int8",   llvm.LLVMInt8Type(), true,   8);
    self._declare_int_type( "int16",  llvm.LLVMInt16Type(), true,  16);
    self._declare_int_type( "int32",  llvm.LLVMInt32Type(), true,  32);
    self._declare_int_type( "int64",  llvm.LLVMInt64Type(), true,  64);
    self._declare_int_type("int128", llvm.LLVMIntType(128), true, 128);

    # Unsigned machine-independent integers
    self._declare_int_type(  "uint8",   llvm.LLVMInt8Type(), false,   8);
    self._declare_int_type( "uint16",  llvm.LLVMInt16Type(), false,  16);
    self._declare_int_type( "uint32",  llvm.LLVMInt32Type(), false,  32);
    self._declare_int_type( "uint64",  llvm.LLVMInt64Type(), false,  64);
    self._declare_int_type("uint128", llvm.LLVMIntType(128), false, 128);

    # Floating-points
    self._declare_float_type("float32", llvm.LLVMFloatType(), 32);
    self._declare_float_type("float64", llvm.LLVMDoubleType(), 64);

    # TODO: Unsigned machine-dependent integer

    # TODO: Signed machine-dependent integer

    # TODO: UTF-32 Character

    # TODO: UTF-8 String
}

# Declare `assert` built-in function
# -----------------------------------------------------------------------------
def _declare_assert(&mut self) {
    # Build the LLVM type for the `abort` fn.
    let abort_type: ^llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMVoidType(), 0 as ^^llvm.LLVMOpaqueType, 0, 0);

    # Build the LLVM function for `abort`.
    let abort_fn: ^llvm.LLVMOpaqueValue = llvm.LLVMAddFunction(
        self.mod, "abort" as ^int8, abort_type);

    # Build the LLVM type.
    let param: ^llvm.LLVMOpaqueType = llvm.LLVMInt1Type();
    let type_obj: ^llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMVoidType(), &param, 1, 0);

    # Create a `solid` handle to the parameter.
    let phandle: ^code.Handle = self.items.get_ptr("bool") as ^code.Handle;

    # Create a `solid` handle to the parameters.
    let mut params: list.List = list.make(types.PTR);
    params.push_ptr(code.make_parameter(
        "condition", phandle, code.make_nil()) as ^void);

    # Create a `solid` handle to the function type.
    let type_: ^code.Handle = code.make_function_type(
        type_obj, code.make_void_type(llvm.LLVMVoidType()), params);

    # Build the LLVM function declaration.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMAddFunction(self.mod, "assert" as ^int8, type_obj);

    # Create a `solid` handle to the function.
    let mut ns: list.List = list.make(types.STR);
    let fn: ^code.Handle = code.make_function(
        0 as ^ast.FuncDecl, "assert", ns, type_, val);

    # Set in the global scope.
    self.items.set_ptr("assert", fn as ^void);

    # Build the LLVM function definition.
    # Add the basic blocks.
    let entry_block: ^llvm.LLVMOpaqueBasicBlock;
    let then_block: ^llvm.LLVMOpaqueBasicBlock;
    let merge_block: ^llvm.LLVMOpaqueBasicBlock;
    entry_block = llvm.LLVMAppendBasicBlock(val, "" as ^int8);
    then_block = llvm.LLVMAppendBasicBlock(val, "" as ^int8);
    merge_block = llvm.LLVMAppendBasicBlock(val, "" as ^int8);

    # Grab the single argument.
    llvm.LLVMPositionBuilderAtEnd(self.irb, entry_block);
    let phandle: ^llvm.LLVMOpaqueValue = llvm.LLVMGetParam(val, 0);

    # Add a conditional branch on the single argument.
    llvm.LLVMBuildCondBr(self.irb, phandle, merge_block, then_block);

    # Add the call to `abort`.
    llvm.LLVMPositionBuilderAtEnd(self.irb, then_block);
    llvm.LLVMBuildCall(self.irb, abort_fn, 0 as ^^llvm.LLVMOpaqueValue, 0,
                       "" as ^int8);
    llvm.LLVMBuildBr(self.irb, merge_block);

    # Add the `ret void` instruction to terminate the function.
    llvm.LLVMPositionBuilderAtEnd(self.irb, merge_block);
    llvm.LLVMBuildRetVoid(self.irb);
}

# Declare the `main` function.
# -----------------------------------------------------------------------------
def _declare_main(&mut self) {

    # Qualify a module main name.
    let mut name: string.String = string.make();
    name.extend(self.top_ns.data() as str);
    name.append('.');
    name.extend("main");

    # Was their a main function defined?
    let module_main_fn: ^llvm.LLVMOpaqueValue = 0 as ^llvm.LLVMOpaqueValue;
    if self.items.contains(name.data() as str) {
        let module_main_han: ^code.Handle;
        module_main_han = self.items.get_ptr(name.data() as str) as ^code.Handle;
        let module_main_fn_han: ^code.Function;
        module_main_fn_han = module_main_han._object as ^code.Function;
        module_main_fn = module_main_fn_han.handle;
    }

    # Build the LLVM type for the `main` fn.
    let main_type: ^llvm.LLVMOpaqueType = llvm.LLVMFunctionType(
        llvm.LLVMInt32Type(), 0 as ^^llvm.LLVMOpaqueType, 0, 0);

    # Build the LLVM function for `main`.
    let main_fn: ^llvm.LLVMOpaqueValue = llvm.LLVMAddFunction(
        self.mod, "main" as ^int8, main_type);

    # Build the LLVM function definition.
    let entry_block: ^llvm.LLVMOpaqueBasicBlock;
    entry_block = llvm.LLVMAppendBasicBlock(main_fn, "" as ^int8);
    llvm.LLVMPositionBuilderAtEnd(self.irb, entry_block);

    if module_main_fn <> 0 as ^llvm.LLVMOpaqueValue {
        # Create a `call` to the module main method.
        llvm.LLVMBuildCall(
            self.irb, module_main_fn,
            0 as ^^llvm.LLVMOpaqueValue, 0,
            "" as ^int8);
    }

    # Create a constant 0.
    let zero: ^llvm.LLVMOpaqueValue;
    zero = llvm.LLVMConstInt(llvm.LLVMInt32Type(), 0, false);

    # Add the `ret void` instruction to terminate the function.
    llvm.LLVMBuildRet(self.irb, zero);

    # Dispose.
    name.dispose();

}

} # implement Generator

# Type conversion
# =============================================================================

# Attempt to resolve a single compatible type from two passed
# types. Respects integer and float promotion rules.
# -----------------------------------------------------------------------------
def _type_common(a_ctx: ^ast.Node, a: ^code.Handle,
                 b_ctx: ^ast.Node, b: ^code.Handle) -> ^code.Handle {
    # If the types are the same, bail.
    let a_ty: ^code.Type = a._object as ^code.Type;
    let b_ty: ^code.Type = b._object as ^code.Type;
    if a == b { return a; }

    # Figure out a common type.
    if a._tag == code.TAG_INT_TYPE and b._tag == a._tag {
        # Determine the integer with the greatest rank.
        let a_ty: ^code.IntegerType = a._object as ^code.IntegerType;
        let b_ty: ^code.IntegerType = b._object as ^code.IntegerType;

        # If the sign is identical then compare the bit size.
        if a_ty.signed == b_ty.signed {
            if a_ty.bits > b_ty.bits {
                a;
            } else {
                b;
            }
        } else if a_ctx.tag == ast.TAG_INTEGER {
            b;
        } else if b_ctx.tag == ast.TAG_INTEGER {
            a;
        } else if a_ty.signed and a_ty.bits > b_ty.bits {
            a;
        } else if b_ty.signed and b_ty.bits > a_ty.bits {
            b;
        } else {
            # The integer types are not strictly compatible.
            # Return nil.
            code.make_nil();
        }
    } else if a._tag == code.TAG_FLOAT_TYPE and b._tag == a._tag {
        # Determine the float with the greatest rank.
        let a_ty: ^code.FloatType = a._object as ^code.FloatType;
        let b_ty: ^code.FloatType = b._object as ^code.FloatType;

        # Chose the float type with greater rank.
        if a_ty.bits > b_ty.bits {
            a;
        } else {
            b;
        }
    } else if a._tag == code.TAG_FLOAT_TYPE and b._tag == code.TAG_INT_TYPE {
        # No matter what the float or int type is the float has greater rank.
        a;
    } else if b._tag == code.TAG_FLOAT_TYPE and a._tag == code.TAG_INT_TYPE {
        # No matter what the float or int type is the float has greater rank.
        b;
    } else {
        # No common type resolution.
        # Return nil.
        code.make_nil();
    }
}

def _type_compatible(d: ^code.Handle, s: ^code.Handle) -> bool {
    # Get the type handles.
    let s_ty: ^code.Type = s._object as ^code.Type;
    let d_ty: ^code.Type = d._object as ^code.Type;

    # If these are the `same` then were okay.
    if s_ty == d_ty { return true; }
    else if s_ty.handle == d_ty.handle { return true; }
    else if s._tag == code.TAG_INT_TYPE and d._tag == code.TAG_INT_TYPE {
        return true;
    }

    # Report error.
    let mut s_typename: string.String = code.typename(s);
    let mut d_typename: string.String = code.typename(d);
    errors.begin_error();
    errors.fprintf(errors.stderr,
                   "mismatched types: expected '%s' but found '%s'" as ^int8,
                   d_typename.data(), s_typename.data());
    errors.end();

    # Dispose.
    s_typename.dispose();
    d_typename.dispose();

    # Return false.
    false;
}

# Type resolvers
# =============================================================================

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_targeted_type(g: ^mut Generator, target: ^code.Handle,
                          node: ^ast.Node)
        -> ^code.Handle {
    resolve_type_in(g, node, target, code.make_nil_scope(), &g.ns);
}

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_st_type(g: ^mut Generator, target: ^code.Handle,
                    scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    resolve_type_in(g, node, target, scope, &g.ns);
}

# Resolve an arbitrary scoped type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_scoped_type(g: ^mut Generator, scope: ^code.Scope,
                        node: ^ast.Node)
        -> ^code.Handle {
    resolve_type_in(g, node, code.make_nil(), scope, &g.ns);
}

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_targeted_type_in(g: ^mut Generator, target: ^code.Handle,
                             node: ^ast.Node, ns: ^list.List)
        -> ^code.Handle {
    resolve_type_in(g, node, target, code.make_nil_scope(), ns);
}

# Resolve an arbitrary type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_type(g: ^mut Generator, node: ^ast.Node)
        -> ^code.Handle {
    resolve_type_in(g, node, code.make_nil(), code.make_nil_scope(), &g.ns);
}

# Resolve an arbitrary type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_type_in(g: ^mut Generator, node: ^ast.Node, target: ^code.Handle,
                    scope: ^code.Scope, ns: ^list.List)
        -> ^code.Handle {
    # Get the type resolution func.
    let res_fn: def (^mut Generator, ^code.Handle, ^code.Scope, ^ast.Node)
            -> ^code.Handle
        = g.type_resolvers[node.tag];

    # Save the current namespace.
    let old_ns: list.List = g.ns;
    g.ns = ns^;

    # Resolve the type.
    let han: ^code.Handle = res_fn(g, target, scope, node);

    # Unset.
    g.ns = old_ns;

    # Ensure that we are type compatible.
    let mut error: bool = false;
    if not code.isnil(han) {
        if not code.isnil(target) {
            if not _type_compatible(target, han) {
                error = true;
            }
        }
    }

    # Return our handle or nil.
    if error { code.make_nil(); }
    else { han; }
}

# Resolve a type from an item.
# -----------------------------------------------------------------------------
def _type_of(g: ^mut Generator, item: ^code.Handle) -> ^code.Handle {
    if not code.is_type(item) {
        # Extract type from identifier.
        if item._tag == code.TAG_STATIC_SLOT {
            # This is a static slot; get its type.
            (g^)._gen_type_static_slot(item._object as ^code.StaticSlot);
        } else if item._tag == code.TAG_LOCAL_SLOT {
            # This is a local slot; just return the type.
            let slot: ^code.LocalSlot = item._object as ^code.LocalSlot;
            slot.type_;
        } else if item._tag == code.TAG_FUNCTION {
            # This is a function; get its type.
            (g^)._gen_type_func(item._object as ^code.Function);
        } else if item._tag == code.TAG_MODULE {
            # This is a module; deal with it.
            item;
        } else {
            # Return nil.
            code.make_nil();
        }
    } else {
        # Return the type reference.
        item;
    }
}

# Resolve an `identifier` for a type.
# -----------------------------------------------------------------------------
def resolve_type_ident(g: ^mut Generator, _: ^code.Handle,
                       scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # A simple identifier; this refers directly to a "named" type
    # in the current scope or any enclosing outer scope.

    # Unwrap the name for the id.
    let id: ^ast.Ident = (node^).unwrap() as ^ast.Ident;

    # Retrieve the item with scope resolution rules.
    let item: ^code.Handle = (g^)._get_scoped_item_in(
        id.name.data() as str, scope, g.ns);

    if item == 0 as ^code.Handle {
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "name '%s' is not defined" as ^int8,
                       id.name.data());
        errors.end();

        return code.make_nil();
    }

    # Resolve the item for its type.
    _type_of(g, item);
}

# Resolve the identity type.
# -----------------------------------------------------------------------------
def resolve_type_id(g: ^mut Generator, _: ^code.Handle, scope: ^code.Scope,
                    node: ^ast.Node)
        -> ^code.Handle {
    # Return what were targeted with.
    _;
}

# Resolve a `type expression` for a type -- type(..)
# -----------------------------------------------------------------------------
def resolve_type_expr(g: ^mut Generator, _: ^code.Handle, scope: ^code.Scope,
                      node: ^ast.Node)
        -> ^code.Handle {
    # An arbitrary type deferrence expression.

    # Unwrap the type expression.
    let x: ^ast.TypeExpr = (node^).unwrap() as ^ast.TypeExpr;

    # Resolve the expression.
    resolve_scoped_type(g, scope, &x.expression);
}

# Resolve a `boolean expression` for its type.
# -----------------------------------------------------------------------------
def resolve_bool_expr(g: ^mut Generator, _: ^code.Handle, scope: ^code.Scope,
                      node: ^ast.Node)
        -> ^code.Handle {
    # Wonder what the type of this is.
    (g^).items.get_ptr("bool") as ^code.Handle;
}

# Resolve an `integer expression` for its type.
# -----------------------------------------------------------------------------
def resolve_int_expr(g: ^mut Generator, target: ^code.Handle,
                     scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    if not code.isnil(target) {
        if (target._tag == code.TAG_INT_TYPE
                or target._tag == code.TAG_FLOAT_TYPE) {
            # Return the targeted type.
            target;
        } else {
            # FIXME: This should be `int` as soon as we can make it so.
            (g^).items.get_ptr("int64") as ^code.Handle;
        }
    } else {
        # FIXME: This should be `int` as soon as we can make it so.
        (g^).items.get_ptr("int64") as ^code.Handle;
    }
}

# Resolve a `float expression` for its type.
# -----------------------------------------------------------------------------
def resolve_float_expr(g: ^mut Generator, target: ^code.Handle,
                       scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    if not code.isnil(target) {
        if target._tag == code.TAG_FLOAT_TYPE {
            # Return the targeted type.
            target;
        } else {
            (g^).items.get_ptr("float64") as ^code.Handle;
        }
    } else {
        (g^).items.get_ptr("float64") as ^code.Handle;
    }
}

# Resolve a binary logical expression.
# -----------------------------------------------------------------------------
def resolve_logical_expr_b(g: ^mut Generator, _: ^code.Handle,
                           scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {

    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve the types of the operands.
    let lhs: ^code.Handle = resolve_scoped_type(g, scope, &x.lhs);
    let rhs: ^code.Handle = resolve_scoped_type(g, scope, &x.rhs);
    if code.isnil(lhs) or code.isnil(rhs) { return code.make_nil(); }

    # Ensure that we are dealing strictly with booleans.
    if lhs._tag <> code.TAG_BOOL_TYPE or rhs._tag <> code.TAG_BOOL_TYPE {
        # Determine the operation.
        let opname: str =
            if node.tag == ast.TAG_LOGICAL_AND { "and"; }
            else { "or"; };

        # Get formal type names.
        let mut lhs_name: string.String = code.typename(lhs);
        let mut rhs_name: string.String = code.typename(rhs);

        # Report error.
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "binary operation '%s' cannot be applied to types '%s' and '%s'" as ^int8,
                       opname, lhs_name.data(), rhs_name.data());
        errors.end();

        # Dispose.
        lhs_name.dispose();
        rhs_name.dispose();

        # Return nil.
        return code.make_nil();
    }

    # Return the bool type.
    (g^).items.get_ptr("bool") as ^code.Handle;
}

# Resolve an unary logical expression.
# -----------------------------------------------------------------------------
def resolve_logical_expr_u(g: ^mut Generator, _: ^code.Handle,
                           scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {

    # Unwrap the node to its proper type.
    let x: ^ast.UnaryExpr = (node^).unwrap() as ^ast.UnaryExpr;

    # Resolve the types of the operand.
    let operand: ^code.Handle = resolve_scoped_type(g, scope, &x.operand);
    if code.isnil(operand) { return code.make_nil(); }

    # Ensure that we are dealing strictly with a boolean.
    if operand._tag <> code.TAG_BOOL_TYPE {
        # Get formal type name.
        let mut name: string.String = code.typename(operand);

        # Report error.
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "unary operation 'not' cannot be applied to type '%s'" as ^int8,
                       name.data());
        errors.end();

        # Dispose.
        name.dispose();

        # Return nil.
        return code.make_nil();
    }

    # Return the bool type.
    (g^).items.get_ptr("bool") as ^code.Handle;
}

# Resolve an `add` expression.
# -----------------------------------------------------------------------------
def resolve_add_expr(g: ^mut Generator, _: ^code.Handle,
                     scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, scope, node);
}

# Resolve an `sub` expression.
# -----------------------------------------------------------------------------
def resolve_sub_expr(g: ^mut Generator, _: ^code.Handle,
                     scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, scope, node);
}

# Resolve an `mul` expression.
# -----------------------------------------------------------------------------
def resolve_mul_expr(g: ^mut Generator, _: ^code.Handle,
                     scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, scope, node);
}

# Resolve an `mod` expression.
# -----------------------------------------------------------------------------
def resolve_mod_expr(g: ^mut Generator, _: ^code.Handle,
                     scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, scope, node);
}

# Resolve an `int_div` expression.
# -----------------------------------------------------------------------------
def resolve_int_div_expr(g: ^mut Generator, _: ^code.Handle,
                         scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, scope, node);
}

# Resolve an `div` expression.
# -----------------------------------------------------------------------------
def resolve_div_expr(g: ^mut Generator, _: ^code.Handle,
                     scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve the types of the operands.
    let lhs: ^code.Handle = resolve_scoped_type(g, scope, &x.lhs);
    let rhs: ^code.Handle = resolve_scoped_type(g, scope, &x.rhs);
    if code.isnil(lhs) or code.isnil(rhs) { return code.make_nil(); }

    # Ensure that lhs and rhs are either int or float type.
    if (lhs._tag == code.TAG_FLOAT_TYPE or lhs._tag == code.TAG_INT_TYPE)
            and (rhs._tag == code.TAG_FLOAT_TYPE
                    or rhs._tag == code.TAG_INT_TYPE) {
        if rhs._tag == code.TAG_INT_TYPE and lhs._tag == rhs._tag {
            # They are both integers; return a float64
            (g^).items.get_ptr("float64") as ^code.Handle;
        } else {
            # Both of the types are float; resolve the common type (floats
            # will come out).
            _type_common(&x.lhs, lhs, &x.rhs, rhs);
        }
    } else {
        # Get formal type names.
        let mut lhs_name: string.String = code.typename(lhs);
        let mut rhs_name: string.String = code.typename(rhs);

        # Report error.
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "no binary operation '/' can be applied to types '%s' and '%s'" as ^int8,
                       lhs_name.data(), rhs_name.data());
        errors.end();

        # Dispose.
        lhs_name.dispose();
        rhs_name.dispose();

        # Return nil.
        code.make_nil();
    }
}

# Resolve an `arithmetic` binary expression.
# -----------------------------------------------------------------------------
def resolve_arith_expr_b(g: ^mut Generator, _: ^code.Handle,
                         scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve the types of the operands.
    let lhs: ^code.Handle = resolve_scoped_type(g, scope, &x.lhs);
    let rhs: ^code.Handle = resolve_scoped_type(g, scope, &x.rhs);
    if code.isnil(lhs) or code.isnil(rhs) { return code.make_nil(); }

    # Attempt to perform common type resolution between the two types.
    let ty: ^code.Handle = _type_common(&x.lhs, lhs, &x.rhs, rhs);
    if code.isnil(ty) {
        # Determine the operation.
        let opname: str =
            if node.tag == ast.TAG_ADD { "+"; }
            else if node.tag == ast.TAG_SUBTRACT { "-"; }
            else if node.tag == ast.TAG_MULTIPLY { "*"; }
            else if node.tag == ast.TAG_DIVIDE { "/"; }
            else if node.tag == ast.TAG_MODULO { "%"; }
            else if node.tag == ast.TAG_INTEGER_DIVIDE { "//"; }
            else { "?"; };  # can't get here

        # Get formal type names.
        let mut lhs_name: string.String = code.typename(lhs);
        let mut rhs_name: string.String = code.typename(rhs);

        # Report error.
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "no binary operation '%s' can be applied to types '%s' and '%s'" as ^int8,
                       opname, lhs_name.data(), rhs_name.data());
        errors.end();

        # Dispose.
        lhs_name.dispose();
        rhs_name.dispose();

        # Return nil.
        code.make_nil();
    } else {
        # Worked; return the type.
        ty;
    }
}

# Resolve an `EQ` expression.
# -----------------------------------------------------------------------------
def resolve_eq_expr(g: ^mut Generator, _: ^code.Handle,
                    scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    let han: ^code.Handle = resolve_arith_expr_b(
        g, code.make_nil(), scope, node);
    if code.isnil(han) { return code.make_nil(); }

    # Then ignore the resultant type and send back a boolean.
    (g^).items.get_ptr("bool") as ^code.Handle;
}

# Resolve a conditional expression.
# -----------------------------------------------------------------------------
def resolve_conditional_expr(g: ^mut Generator, _: ^code.Handle,
                    scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, code.make_nil(), scope, node);
}

# Resolve an `NE` expression.
# -----------------------------------------------------------------------------
def resolve_ne_expr(g: ^mut Generator, _: ^code.Handle,
                    scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    let han: ^code.Handle = resolve_arith_expr_b(
        g, code.make_nil(), scope, node);
    if code.isnil(han) { return code.make_nil(); }

    # Then ignore the resultant type and send back a boolean.
    (g^).items.get_ptr("bool") as ^code.Handle;
}

# Resolve a `call` expression.
# -----------------------------------------------------------------------------
def resolve_call_expr(g: ^mut Generator, _: ^code.Handle,
                      scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.CallExpr = (node^).unwrap() as ^ast.CallExpr;

    # Resolve the type of the call expression.
    let expr: ^code.Handle = resolve_type(g, &x.expression);
    if code.isnil(expr) { return code.make_nil(); }

    # Ensure that we are dealing strictly with a function type.
    if expr._tag <> code.TAG_FUNCTION_TYPE {
        # Get formal type name.
        let mut name: string.String = code.typename(expr);

        # Report error.
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "type '%s' is not a function" as ^int8,
                       name.data());
        errors.end();

        # Dispose.
        name.dispose();

        # Return nil.
        return code.make_nil();
    }

    # Get it as a function type.
    let ty: ^code.FunctionType = expr._object as ^code.FunctionType;

    # Return the already resolve return type.
    ty.return_type;
}

# Resolve a `global`.
# -----------------------------------------------------------------------------
def resolve_global(g: ^mut Generator, _: ^code.Handle,
                   scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Return the targeted type.
    _;
}

# Resolve a `member` expression.
# -----------------------------------------------------------------------------
def resolve_member_expr(g: ^mut Generator, _: ^code.Handle,
                        scope: ^code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Get the name out of the rhs.
    let rhs_id: ^ast.Ident = x.rhs.unwrap() as ^ast.Ident;

    # Check if this is a special member resolution (`global.`)
    let mut item: ^code.Handle;
    if x.lhs.tag == ast.TAG_GLOBAL {
        # Build the namespace.
        let mut ns: list.List = list.make(types.STR);
        ns.push_str(g.top_ns.data() as str);

        # Attempt to resolve the member.
        item = (g^)._get_scoped_item_in(rhs_id.name.data() as str, scope, ns);

        # Do we have this item?
        if item == 0 as ^code.Handle {
            # No; report and bail.
             errors.begin_error();
             errors.fprintf(errors.stderr,
                            "name '%s' is not defined" as ^int8,
                            rhs_id.name.data());
             errors.end();
             return code.make_nil();
        }

        # Dispose.
        ns.dispose();
    } else {
        # Resolve the type of the lhs.
        let lhs: ^code.Handle = resolve_type(g, &x.lhs);
        if code.isnil(lhs) { return code.make_nil(); }

        # Attempt to get an `item` out of the LHS.
        if lhs._tag == code.TAG_MODULE {
            let mod: ^code.Module = lhs._object as ^code.Module;

            # Build the namespace.
            let mut ns: list.List = mod.namespace.clone();
            ns.push_str(mod.name.data() as str);

            # Attempt to resolve the member.
            item = (g^)._get_scoped_item_in(
                rhs_id.name.data() as str, scope, ns);

            # Do we have this item?
            if item == 0 as ^code.Handle {
                # No; report and bail.
                 errors.begin_error();
                 errors.fprintf(errors.stderr,
                                "module '%s' has no member '%s'" as ^int8,
                                mod.name.data(), rhs_id.name.data());
                 errors.end();
                 return code.make_nil();
            }

            # Dispose.
            ns.dispose();
        } else {
            # Not sure how to resolve this.
            # NOTE: Should be impossible to get here.
            return code.make_nil();
        }
    }

    # Resolve the item for its type.
    _type_of(g, item);
}

# Builders
# =============================================================================

# Build an arbitrary node.
# -----------------------------------------------------------------------------
def build(g: ^mut Generator, target: ^code.Handle, scope: ^mut code.Scope,
          node: ^ast.Node) -> ^code.Handle {
    build_in(g, target, scope, node, &g.ns);
}

# Build an arbitrary node.
# -----------------------------------------------------------------------------
def build_in(g: ^mut Generator, target: ^code.Handle, scope: ^mut code.Scope,
             node: ^ast.Node, ns: ^list.List)
        -> ^code.Handle {
    # Get the build func.
    let fn: def (^mut Generator, ^code.Handle, ^mut code.Scope, ^ast.Node)
            -> ^code.Handle
        = g.builders[node.tag];

    # Save and set the namespace.
    let old_ns: list.List = g.ns;
    g.ns = ns^;

    # Resolve the type.
    let han: ^code.Handle = fn(g, target, scope, node);

    # Unset our namespace.
    g.ns = old_ns;

    # Return the resolved type.
    han;
}

# Build a `boolean` expression.
# -----------------------------------------------------------------------------
def build_bool_expr(g: ^mut Generator, target: ^code.Handle,
                    scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BooleanExpr = (node^).unwrap() as ^ast.BooleanExpr;

    # Build a llvm val for the boolean expression.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMConstInt(llvm.LLVMInt1Type(), 1 if x.value else 0, false);

    # Wrap and return the value.
    code.make_value(target, val);
}

# Build an `integral` expression.
# -----------------------------------------------------------------------------
def build_int_expr(g: ^mut Generator, target: ^code.Handle,
                   scope: ^mut code.Scope,
                   node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.IntegerExpr = (node^).unwrap() as ^ast.IntegerExpr;

    # Get the type handle from the target.
    let typ: ^code.Type = target._object as ^code.Type;

    # Build a llvm val for the boolean expression.
    let val: ^llvm.LLVMOpaqueValue;
    if target._tag == code.TAG_INT_TYPE {
        val = llvm.LLVMConstIntOfString(typ.handle, x.text.data(),
                                        x.base as uint8);
    } else {
        val = llvm.LLVMConstRealOfString(typ.handle, x.text.data());
    }

    # Wrap and return the value.
    code.make_value(target, val);
}

# Build a `float` expression.
# -----------------------------------------------------------------------------
def build_float_expr(g: ^mut Generator, target: ^code.Handle,
                     scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.FloatExpr = (node^).unwrap() as ^ast.FloatExpr;

    # Get the type handle from the target.
    let typ: ^code.Type = target._object as ^code.Type;

    # Build a llvm val for the boolean expression.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMConstRealOfString(typ.handle, x.text.data());

    # Wrap and return the value.
    code.make_value(target, val);
}

# Build an `ident` expression.
# -----------------------------------------------------------------------------
def build_ident_expr(g: ^mut Generator, target: ^code.Handle,
                     scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.Ident = (node^).unwrap() as ^ast.Ident;

    # Retrieve the item with scope resolution rules.
    let item: ^code.Handle = (g^)._get_scoped_item_in(
        x.name.data() as str, scope, g.ns);

    # Return the item.
    item;
}

# Build a `return`.
# -----------------------------------------------------------------------------
def build_ret(g: ^mut Generator, _: ^code.Handle, scope: ^mut code.Scope,
              node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the "ploymorphic" node to its proper type.
    let x: ^ast.ReturnExpr = (node^).unwrap() as ^ast.ReturnExpr;

    # Generate a handle for the expression (if we have one.)
    if not ast.isnull(x.expression) {
        let expr: ^code.Handle = build(g, _, scope, &x.expression);
        if code.isnil(expr) { return code.make_nil(); }

        # Coerce the expression to a value.
        let val_han: ^code.Handle = (g^)._to_value(expr, false);
        let val: ^code.Value = val_han._object as ^code.Value;

        # Create the `RET` instruction.
        llvm.LLVMBuildRet(g.irb, val.handle);

        # Dispose.
        code.dispose(expr);
        code.dispose(val_han);
    } else {
        # Create the void `RET` instruction.
        llvm.LLVMBuildRetVoid(g.irb);
        void;  #HACK
    }

    # Nothing is forwarded from a `return`.
    code.make_nil();
}

# Build the operands for a binary expression.
# -----------------------------------------------------------------------------
def build_expr_b(g: ^mut Generator, _: ^code.Handle, scope: ^mut code.Scope,
                 node: ^ast.Node)
        -> (^code.Handle, ^code.Handle) {
    let res: (^code.Handle, ^code.Handle) = (code.make_nil(), code.make_nil());

    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve each operand for its type.
    let lhs_ty: ^code.Handle = resolve_st_type(g, _, scope, &x.lhs);
    let rhs_ty: ^code.Handle = resolve_st_type(g, _, scope, &x.rhs);

    # Build each operand.
    let lhs: ^code.Handle = build(g, lhs_ty, scope, &x.lhs);
    let rhs: ^code.Handle = build(g, rhs_ty, scope, &x.rhs);
    if code.isnil(lhs) or code.isnil(rhs) { return res; }

    # Coerce the operands to values.
    let lhs_val_han: ^code.Handle = (g^)._to_value(lhs, false);
    let rhs_val_han: ^code.Handle = (g^)._to_value(rhs, false);
    if code.isnil(lhs_val_han) or code.isnil(rhs_val_han) { return res; }

    # Create a tuple result.
    res = (lhs_val_han, rhs_val_han);
    res;
}

# Build an `add` expression.
# -----------------------------------------------------------------------------
def build_add_expr(g: ^mut Generator, _: ^code.Handle,
                   scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, _, scope, node);

    # Resolve our type.
    let type_: ^code.Handle = resolve_st_type(g, _, scope, node);

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
    let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the `add` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    if type_._tag == code.TAG_INT_TYPE {
        val = llvm.LLVMBuildAdd(g.irb,
                                lhs_val.handle, rhs_val.handle, "" as ^int8);
    } else if type_._tag == code.TAG_FLOAT_TYPE {
        val = llvm.LLVMBuildFAdd(g.irb,
                                 lhs_val.handle, rhs_val.handle, "" as ^int8);
    }

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(type_, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `sub` expression.
# -----------------------------------------------------------------------------
def build_sub_expr(g: ^mut Generator, _: ^code.Handle,
                   scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, _, scope, node);

    # Resolve our type.
    let type_: ^code.Handle = resolve_st_type(g, _, scope, node);

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
    let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the `sub` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    if type_._tag == code.TAG_INT_TYPE {
        val = llvm.LLVMBuildSub(g.irb,
                                lhs_val.handle, rhs_val.handle, "" as ^int8);
    } else if type_._tag == code.TAG_FLOAT_TYPE {
        val = llvm.LLVMBuildFSub(g.irb,
                                 lhs_val.handle, rhs_val.handle, "" as ^int8);
    }

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(type_, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `mul` expression.
# -----------------------------------------------------------------------------
def build_mul_expr(g: ^mut Generator, _: ^code.Handle,
                   scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, _, scope, node);

    # Resolve our type.
    let type_: ^code.Handle = resolve_st_type(g, _, scope, node);

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
    let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the `mul` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    if type_._tag == code.TAG_INT_TYPE {
        val = llvm.LLVMBuildMul(g.irb,
                                lhs_val.handle, rhs_val.handle, "" as ^int8);
    } else if type_._tag == code.TAG_FLOAT_TYPE {
        val = llvm.LLVMBuildFMul(g.irb,
                                 lhs_val.handle, rhs_val.handle, "" as ^int8);
    }

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(type_, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `int div` expression.
# -----------------------------------------------------------------------------
def build_int_div_expr(g: ^mut Generator, _: ^code.Handle,
                       scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, _, scope, node);

    # Resolve our type.
    let type_: ^code.Handle = resolve_st_type(g, _, scope, node);

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
    let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the `int div` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    if type_._tag == code.TAG_INT_TYPE {
        let int_ty: ^code.IntegerType = type_._object as ^code.IntegerType;
        if int_ty.signed {
            val = llvm.LLVMBuildSDiv(
                g.irb, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else {
            val = llvm.LLVMBuildUDiv(
                g.irb, lhs_val.handle, rhs_val.handle, "" as ^int8);
        }
    } else if type_._tag == code.TAG_FLOAT_TYPE {
        val = llvm.LLVMBuildFDiv(g.irb,
                                 lhs_val.handle, rhs_val.handle, "" as ^int8);
        # FIXME: Insert FLOOR intrinsic here!
    }

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(type_, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `div` expression.
# -----------------------------------------------------------------------------
def build_div_expr(g: ^mut Generator, _: ^code.Handle,
                   scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, _, scope, node);

    # Resolve our type.
    let type_: ^code.Handle = resolve_st_type(g, _, scope, node);

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
    let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the `div` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMBuildFDiv(g.irb,
                             lhs_val.handle, rhs_val.handle, "" as ^int8);

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(type_, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `mod` expression.
# -----------------------------------------------------------------------------
def build_mod_expr(g: ^mut Generator, _: ^code.Handle,
                   scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, _, scope, node);

    # Resolve our type.
    let type_: ^code.Handle = resolve_st_type(g, _, scope, node);

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
    let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the `mod` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    if type_._tag == code.TAG_INT_TYPE {
        let int_ty: ^code.IntegerType = type_._object as ^code.IntegerType;
        if int_ty.signed {
            val = llvm.LLVMBuildSRem(
                g.irb, lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else {
            val = llvm.LLVMBuildURem(
                g.irb, lhs_val.handle, rhs_val.handle, "" as ^int8);
        }
    } else if type_._tag == code.TAG_FLOAT_TYPE {
        val = llvm.LLVMBuildFRem(g.irb,
                                 lhs_val.handle, rhs_val.handle, "" as ^int8);
    }

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(type_, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build a `conditional` expression.
# -----------------------------------------------------------------------------
def build_conditional_expr(g: ^mut Generator, _: ^code.Handle,
                           scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.ConditionalExpr = (node^).unwrap() as ^ast.ConditionalExpr;

    # Build the condition.
    let cond_han: ^code.Handle;
    cond_han = build(g, g.items.get_ptr("bool") as ^code.Handle,
                     scope, &x.condition);
    if code.isnil(cond_han) { return code.make_nil(); }
    let cond_val_han: ^code.Handle = (g^)._to_value(cond_han, false);
    let cond_val: ^code.Value = cond_val_han._object as ^code.Value;
    if code.isnil(cond_val_han) { return code.make_nil(); }

    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, _, scope, node);

    # Resolve our type.
    let type_: ^code.Handle = resolve_st_type(g, _, scope, node);

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
    let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

    # Cast to values.
    let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
    let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

    # Build the `select` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMBuildSelect(
        g.irb, cond_val.handle, lhs_val.handle, rhs_val.handle, "" as ^int8);

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(type_, val);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `EQ` expression.
# -----------------------------------------------------------------------------
def build_eq_expr(g: ^mut Generator, _: ^code.Handle, scope: ^mut code.Scope,
                  node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, code.make_nil(), scope, node);

    # Resolve our type.
    let type_: ^code.Handle = _type_common(
        &x.lhs, code.type_of(lhs_val_han), &x.rhs, code.type_of(rhs_val_han));
    if code.isnil(type_) {
        code.make_nil();
    } else {
        # Cast each operand to the target type.
        let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
        let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

        # Cast to values.
        let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Build the `EQ` instruction.
        let val: ^llvm.LLVMOpaqueValue;
        if type_._tag == code.TAG_INT_TYPE
                or type_._tag == code.TAG_BOOL_TYPE {
            val = llvm.LLVMBuildICmp(
                g.irb,
                32, # IntEQ
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if type_._tag == code.TAG_FLOAT_TYPE {
            val = llvm.LLVMBuildFCmp(
                g.irb,
                1, # RealOEQ
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        }

        # Wrap and return the value.
        let han: ^code.Handle;
        han = code.make_value(_, val);

        # Dispose.
        code.dispose(lhs_val_han);
        code.dispose(rhs_val_han);
        code.dispose(lhs_han);
        code.dispose(rhs_han);

        # Return our wrapped result.
        han;
    }
}

# Build a `NE` expression.
# -----------------------------------------------------------------------------
def build_ne_expr(g: ^mut Generator, _: ^code.Handle,
                  scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Build each operand.
    let lhs_val_han: ^code.Handle;
    let rhs_val_han: ^code.Handle;
    (lhs_val_han, rhs_val_han) = build_expr_b(g, code.make_nil(), scope, node);

    # Resolve our type.
    let type_: ^code.Handle = _type_common(
        &x.lhs, code.type_of(lhs_val_han), &x.rhs, code.type_of(rhs_val_han));
    if code.isnil(type_) {
        code.make_nil();
    } else {
        # Cast each operand to the target type.
        let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, type_);
        let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, type_);

        # Cast to values.
        let lhs_val: ^code.Value = lhs_han._object as ^code.Value;
        let rhs_val: ^code.Value = rhs_han._object as ^code.Value;

        # Build the `EQ` instruction.
        let val: ^llvm.LLVMOpaqueValue;
        if type_._tag == code.TAG_INT_TYPE {
            val = llvm.LLVMBuildICmp(
                g.irb,
                33, # IntNE
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        } else if type_._tag == code.TAG_FLOAT_TYPE {
            val = llvm.LLVMBuildFCmp(
                g.irb,
                6, # RealONE
                lhs_val.handle, rhs_val.handle, "" as ^int8);
        }

        # Wrap and return the value.
        let han: ^code.Handle;
        han = code.make_value(_, val);

        # Dispose.
        code.dispose(lhs_val_han);
        code.dispose(rhs_val_han);
        code.dispose(lhs_han);
        code.dispose(rhs_han);

        # Return our wrapped result.
        han;
    }
}

# Build a `not` expression.
# -----------------------------------------------------------------------------
def build_logical_neg_expr(g: ^mut Generator, _: ^code.Handle,
                           scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.UnaryExpr = (node^).unwrap() as ^ast.UnaryExpr;

    # Resolve each operand for its type.
    let op_ty: ^code.Handle = resolve_st_type(
        g, g.items.get_ptr("bool") as ^code.Handle, scope, &x.operand);

    # Build each operand.
    let op: ^code.Handle = build(g, op_ty, scope, &x.operand);
    if code.isnil(op) { return code.make_nil(); }

    # Coerce the operands to values.
    let op_val_han: ^code.Handle = (g^)._to_value(op, false);
    if code.isnil(op_val_han) { return code.make_nil(); }

    # Cast to values.
    let op_val: ^code.Value = op_val_han._object as ^code.Value;

    # Build the `NEG` instruction.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMBuildXor(
        g.irb,
        op_val.handle,
        llvm.LLVMConstInt(llvm.LLVMInt1Type(), 1, false),
        "" as ^int8);

    # Dispose.
    code.dispose(op_val_han);

    # Wrap and return the value.
    let han: ^code.Handle;
    han = code.make_value(_, val);
}

# Build a `call` expression.
# -----------------------------------------------------------------------------
def build_call_expr(g: ^mut Generator, _: ^code.Handle,
                    scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.CallExpr = (node^).unwrap() as ^ast.CallExpr;

    # Build the called expression.
    let expr: ^code.Handle = build(g, _, scope, &x.expression);
    if code.isnil(expr) { return code.make_nil(); }

    # Get the function handle.
    let fn: ^llvm.LLVMOpaqueValue;
    let type_: ^code.FunctionType;
    if expr._tag == code.TAG_FUNCTION {
        let fn_han: ^code.Function = expr._object as ^code.Function;
        type_ = fn_han.type_._object as ^code.FunctionType;
        fn = fn_han.handle;
    }

    # Wrap and return the value.
    # First we create a list to hold the entire argument list.
    let mut args: list.List = list.make(types.PTR);

    # Enumerate the parameters and push an equivalent amount
    # of blank arguments.
    let mut i: int = 0;
    while i as uint < type_.parameters.size {
        args.push_ptr(0 as ^void);
        i = i + 1;
    }

    # Enumerate the arguments and set the parameters in turn to each
    # generated argument expression.
    let data: ^mut ^llvm.LLVMOpaqueValue
        = args.elements as ^^llvm.LLVMOpaqueValue;
    i = 0;
    let mut j: int = 0;
    let mut error: bool = false;
    while not error and j as uint < x.arguments.size() {
        let anode: ast.Node = x.arguments.get(j);
        j = j + 1;
        let a: ^ast.Argument = anode.unwrap() as ^ast.Argument;

        # Find the parameter index.
        let mut pi: int = 0;
        # NOTE: The parser handles making sure no positional arg
        #   comes after a keyword arg.
        if ast.isnull(a.name) {
            # Push the value as an argument in sequence.
            pi = i;
            i = i + 1;
        } else {
            # Get the name data for the id.
            let id: ^ast.Ident = a.name.unwrap() as ^ast.Ident;

            # Find the parameter index.
            pi = 0;
            while pi as uint < type_.parameters.size {
                let prm_han: ^code.Handle =
                    type_.parameters.at_ptr(pi) as ^code.Handle;
                let prm: ^code.Parameter =
                    prm_han._object as ^code.Parameter;
                if prm.name.eq_str(id.name.data() as str) {
                    break;
                }
                pi = pi + 1;
            }

            # If we didn't find one ...
            if pi as uint == type_.parameters.size {
                errors.begin_error();
                errors.fprintf(errors.stderr,
                               "unexpected keyword argument '%s'" as ^int8,
                               id.name.data());
                errors.end();
                error = true;
            }

            # If we already have one ...
            if (data + pi)^ <> 0 as ^llvm.LLVMOpaqueValue {
                errors.begin_error();
                errors.fprintf(errors.stderr,
                               "got multiple values for argument '%s'" as ^int8,
                               id.name.data());
                errors.end();
                error = true;
            }

            # TODO: Detect dup keyword args
        }

        # Resolve the type of the node.
        let target: ^code.Handle = resolve_st_type(
            g, code.type_of(type_.parameters.at_ptr(pi) as ^code.Handle),
            scope, &a.expression);
        if code.isnil(target) { error = true; break; }

        # Build the node.
        let han: ^code.Handle = build(g, target, scope, &a.expression);
        if code.isnil(han) { error = true; break; }

        # Coerce this to a value.
        let val_han: ^code.Handle = (g^)._to_value(han, true);

        # Cast the value to the target type.
        let cast_han: ^code.Handle = (g^)._cast(val_han, target);
        let cast_val: ^code.Value = cast_han._object as ^code.Value;

        # Emplace in the argument list.
        (data + pi)^ = cast_val.handle;

        # Dispose.
        code.dispose(val_han);
        code.dispose(cast_han);
    }

    if not error {
        # Check for missing arguments.
        i = 0;
        while i as uint < args.size {
            let arg: ^llvm.LLVMOpaqueValue = (data + i)^;
            if arg == 0 as ^llvm.LLVMOpaqueValue {
                # Get formal name
                let prm_han: ^code.Handle =
                    type_.parameters.at_ptr(i) as ^code.Handle;
                let prm: ^code.Parameter =
                    prm_han._object as ^code.Parameter;

                # Report
                errors.begin_error();
                errors.fprintf(errors.stderr,
                               "missing required parameter '%s'" as ^int8,
                               prm.name.data());
                errors.end();
                error = true;
            }

            i = i + 1;
        }

        if not error {
            # Build the `call` instruction.
            let val: ^llvm.LLVMOpaqueValue;
            val = llvm.LLVMBuildCall(g.irb, fn, data,
                                     args.size as uint32, "" as ^int8);

            # Dispose of dynamic memory.
            args.dispose();

            if code.isnil(type_.return_type) {
                # Return nil.
                code.make_nil();
            } else {
                # Wrap and return the value.
                code.make_value(type_.return_type, val);
            }
        } else {
            # Return nil.
            code.make_nil();
        }
    } else {
        # Return nil.
        code.make_nil();
    }
}

# Build a `member` expression.
# -----------------------------------------------------------------------------
def build_member_expr(g: ^mut Generator, _: ^code.Handle,
                      scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Get the name out of the rhs.
    let rhs_id: ^ast.Ident = x.rhs.unwrap() as ^ast.Ident;

    # Check if this is a special member resolution (`global.`)
    let mut item: ^code.Handle;
    if x.lhs.tag == ast.TAG_GLOBAL {
        # Build the namespace.
        let mut ns: list.List = list.make(types.STR);
        ns.push_str(g.top_ns.data() as str);

        # Attempt to resolve the member.
        item = (g^)._get_scoped_item_in(rhs_id.name.data() as str, scope, ns);

        # Dispose.
        ns.dispose();
    } else {
        # Resolve the operand for its type.
        let lhs_ty: ^code.Handle = resolve_st_type(
            g, code.make_nil(), scope, &x.lhs);

        # Build each operand.
        let lhs: ^code.Handle = build(g, lhs_ty, scope, &x.lhs);
        if code.isnil(lhs) { return code.make_nil(); }

        # Attempt to get an `item` out of the LHS.
        if lhs._tag == code.TAG_MODULE {
            let mod: ^code.Module = lhs._object as ^code.Module;

            # Extend our namespace.
            let mut ns: list.List = mod.namespace.clone();
            ns.push_str(mod.name.data() as str);

            # Attempt to resolve the member.
            item = (g^)._get_scoped_item_in(
                rhs_id.name.data() as str, scope, ns);

            # Dispose.
            ns.dispose();
        }
    }

    # Return our item.
    item;
}

# Build a local slot declaration.
# -----------------------------------------------------------------------------
def build_local_slot(g: ^mut Generator, _: ^code.Handle,
                     scope: ^mut code.Scope, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.LocalSlotDecl = (node^).unwrap() as ^ast.LocalSlotDecl;

    # Get the name out of the node.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;

    # Get and resolve the type node (if we have one).
    let type_han: ^code.Handle = code.make_nil();
    let type_: ^code.Type = 0 as ^code.Type;
    if not ast.isnull(x.type_) {
        type_han = resolve_type(g, &x.type_);
        type_ = type_han._object as ^code.Type;
    }

    # Get and resolve the initializer (if we have one).
    let init: ^llvm.LLVMOpaqueValue = 0 as ^llvm.LLVMOpaqueValue;
    if not ast.isnull(x.initializer) {
        # Resolve the type of the initializer.
        let typ: ^code.Handle;
        typ = resolve_st_type(g, type_han, scope, &x.initializer);
        if code.isnil(typ) { return code.make_nil(); }

        # Check and set
        if code.isnil(type_han) {
            type_han = typ;
            type_ = type_han._object as ^code.Type;
        }

        # Build the initializer
        let han: ^code.Handle;
        han = build(g, typ, scope, &x.initializer);
        if code.isnil(han) { return code.make_nil(); }

        # Coerce this to a value.
        let val_han: ^code.Handle = (g^)._to_value(han, true);
        let val: ^code.Value = val_han._object as ^code.Value;
        init = val.handle;
    }

    # Build a stack allocation.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMBuildAlloca(g.irb, type_.handle, id.name.data());

    # Build the store.
    if init <> 0 as ^llvm.LLVMOpaqueValue {
        llvm.LLVMBuildStore(g.irb, init, val);
    }

    # Wrap.
    let han: ^code.Handle;
    han = code.make_local_slot(type_han, val);

    # Insert into the current local scope block.
    (scope^).insert(id.name.data() as str, han);

    # Return.
    han;
}

# Test driver using `stdin`.
# =============================================================================
def main() {
    # Parse the AST from the standard input.
    let unit: ast.Node = parser.parse();
    if errors.count > 0 { libc.exit(-1); }

    # Declare the generator.
    let mut g: Generator;

    # Walk the AST and generate the LLVM IR.
    g.generate("_", unit);
    if errors.count > 0 { libc.exit(-1); }

    # Insert a `main` function.
    # _declare_main();

    # Output the generated LLVM IR.
    let data: ^int8 = llvm.LLVMPrintModuleToString(g.mod);
    printf("%s", data);
    llvm.LLVMDisposeMessage(data);

    # Dispose of the resources used.
    g.dispose();

    # Return success back to the envrionment.
    libc.exit(0);
}
