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

    # Jump table for the type resolver.
    mut type_resolvers: (def (^mut Generator, ^code.Handle, ^ast.Node) -> ^code.Handle)[100],

    # Jump table for the builder.
    mut builders: (def (^mut Generator, ^code.Handle, ^ast.Node) -> ^code.Handle)[100]
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

    # Add basic type definitions.
    self._declare_basic_types();

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

# Get the "item" using the scoping rules in the passed namespace.
# -----------------------------------------------------------------------------
def _get_scoped_item_in(&self, s: str, _ns: list.List) -> ^code.Handle {
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
        han = build_in(&self, typ, &x.context.initializer, &x.namespace);
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

    # Pull out the nodes that correspond to this function.
    let nodes: ^ast.Nodes = self.nodes.get_ptr(qname) as ^ast.Nodes;

    # Create a namespace for the function definition.
    let mut ns: list.List = x.namespace.clone();
    ns.push_str(x.name.data() as str);

    # Iterate over the nodes in the function.
    let mut iter: ast.NodesIterator = ast.iter_nodes(nodes^);
    while not ast.iter_empty(iter) {
        let node: ast.Node = ast.iter_next(iter);
        # Resolve the type of the node.
        let target: ^code.Handle = resolve_type_in(
            &self, &node, type_.return_type, &ns);
        if code.isnil(target) { continue; }

        # Build the node.
        let han: ^code.Handle = build_in(
            &self, target, &node, &ns);

        # Drop it.
        code.dispose(han);
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
    # Get the type node out of the handle.
    let type_: ^code.FunctionType = x.type_._object as ^code.FunctionType;

    # Add the function to the module.
    # TODO: Set priv, vis, etc.
    x.handle = llvm.LLVMAddFunction(self.mod, qname as ^int8, type_.handle);
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
            &self, &x.context.type_, code.make_nil(), &x.namespace);

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
                &self, &x.context.return_type, code.make_nil(), &x.namespace);

            if ret_han == 0 as ^code.Handle {
                # Failed to resolve type; mark us as poisioned.
                x.type_ = code.make_poison();
                return code.make_nil();
            }

            # Get the ret type handle.
            let ret_typ: ^code.Type = ret_han._object as ^code.Type;
            ret_typ_han = ret_typ.handle;
        }


        # Build the LLVM type handle.
        let val: ^llvm.LLVMOpaqueType;
        val = llvm.LLVMFunctionType(
            ret_typ_han, 0 as ^^llvm.LLVMOpaqueType, 0, 0);

        # Create and store our type.
        let han: ^code.Handle;
        han = code.make_function_type(val, ret_han, list.make(types.PTR));
        x.type_ = han;

        # Return the type handle.
        han;
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
    let mut iter: ast.NodesIterator = ast.iter_nodes(nodes);
    while not ast.iter_empty(iter) {
        let node: ast.Node = ast.iter_next(iter);
        if not self._extract_item(node) {
            ast.push(extra^, node);
        }
    }
}

def _extract_item_mod(&mut self, x: ^ast.ModuleDecl) {
    # Unwrap the name for the module.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let name: ast.arena.Store = id.name;

    # Build the qual name for this module.
    let mut qname: string.String = self._qualify_name(name._data as str);

    # Create a solid handle for the module.
    let han: ^code.Handle = code.make_module(name._data as str, self.ns);

    # Set us as an `item`.
    self.items.set_ptr(qname.data() as str, han as ^void);

    # Push our name onto the namespace stack.
    self.ns.push_str(name._data as str);

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
    let name: ast.arena.Store = id.name;

    # Build the qual name for this function.
    let mut qname: string.String = self._qualify_name(name._data as str);

    # Create a solid handle for the function (ignoring the type for now).
    let han: ^code.Handle = code.make_function(
        x, name._data as str, self.ns, code.make_nil(),
        0 as ^llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    self.items.set_ptr(qname.data() as str, han as ^void);

    # Push our name onto the namespace stack.
    self.ns.push_str(name._data as str);

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
    let name: ast.arena.Store = id.name;

    # Build the qual name for this slot.
    let mut qname: string.String = self._qualify_name(name._data as str);

    # Create a solid handle for the slot (ignoring the type for now).
    let han: ^code.Handle = code.make_static_slot(
        x, name._data as str, self.ns,
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

} # implement Generator

# Type conversion
# =============================================================================

# Attempt to resolve a single compatible type from two passed
# types. Respects integer and float promotion rules.
# -----------------------------------------------------------------------------
def _type_common(a_ctx: ^ast.Node, a: ^code.Handle,
                 b_ctx: ^ast.Node, b: ^code.Handle) -> ^code.Handle {
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
        } else if a_ty.signed and a_ty.bits > b_ty.bits {
            a;
        } else if b_ty.signed and b_ty.bits > a_ty.bits {
            b;
        } else if a_ctx.tag == ast.TAG_INTEGER {
            b;
        } else if b_ctx.tag == ast.TAG_INTEGER {
            a;
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

# Type resolvers
# =============================================================================

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_targeted_type(g: ^mut Generator, target: ^code.Handle,
                          node: ^ast.Node)
        -> ^code.Handle {
    resolve_type_in(g, node, target, &g.ns);
}

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_targeted_type_in(g: ^mut Generator, target: ^code.Handle,
                          node: ^ast.Node, ns: ^list.List)
        -> ^code.Handle {
    resolve_type_in(g, node, target, ns);
}

# Resolve an arbitrary type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_type(g: ^mut Generator, node: ^ast.Node)
        -> ^code.Handle {
    resolve_type_in(g, node, code.make_nil(), &g.ns);
}

# Resolve an arbitrary type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_type_in(g: ^mut Generator, node: ^ast.Node, target: ^code.Handle,
                    ns: ^list.List)
        -> ^code.Handle {
    # Get the type resolution func.
    let res_fn: def (^mut Generator, ^code.Handle, ^ast.Node) -> ^code.Handle
        = g.type_resolvers[node.tag];

    # Save the current namespace.
    let old_ns: list.List = g.ns;
    g.ns = ns^;

    # Resolve the type.
    let han: ^code.Handle = res_fn(g, target, node);

    # Unset.
    g.ns = old_ns;

    # Return the resolved type.
    han;
}

# Resolve an `identifier` for a type.
# -----------------------------------------------------------------------------
def resolve_type_ident(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # A simple identifier; this refers directly to a "named" type
    # in the current scope or any enclosing outer scope.

    # Unwrap the name for the id.
    let id: ^ast.Ident = (node^).unwrap() as ^ast.Ident;
    let name: ast.arena.Store = id.name;

    # Retrieve the item with scope resolution rules.
    let item: ^code.Handle = (g^)._get_scoped_item_in(name._data as str, g.ns);

    if item == 0 as ^code.Handle {
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "name '%s' is not defined" as ^int8,
                       name._data);
        errors.end();

        return code.make_nil();
    }

    if not code.is_type(item) {
        # Extract type from identifier.
        if item._tag == code.TAG_STATIC_SLOT {
            # This is a static slot; get its type.
            (g^)._gen_type_static_slot(
                item._object as ^code.StaticSlot);
        } else {
            # Return nil.
            code.make_nil();
        }
    } else {
        # Return the type reference.
        item;
    }
}

# Resolve the identity type.
# -----------------------------------------------------------------------------
def resolve_type_id(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Return what were targeted with.
    _;
}

# Resolve a `type expression` for a type -- type(..)
# -----------------------------------------------------------------------------
def resolve_type_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # An arbitrary type deferrence expression.

    # Unwrap the type expression.
    let x: ^ast.TypeExpr = (node^).unwrap() as ^ast.TypeExpr;

    # Resolve the expression.
    resolve_type(g, &x.expression);
}

# Resolve a `boolean expression` for its type.
# -----------------------------------------------------------------------------
def resolve_bool_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Wonder what the type of this is.
    (g^).items.get_ptr("bool") as ^code.Handle;
}

# Resolve an `integer expression` for its type.
# -----------------------------------------------------------------------------
def resolve_int_expr(g: ^mut Generator, target: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    if code.isnil(target) {
        # FIXME: This should be `int` as soon as we can make it so.
        (g^).items.get_ptr("int64") as ^code.Handle;
    } else {
        # Return the targeted type.
        target;
    }
}

# Resolve a `float expression` for its type.
# -----------------------------------------------------------------------------
def resolve_float_expr(g: ^mut Generator, target: ^code.Handle,
                       node: ^ast.Node)
        -> ^code.Handle {
    if code.isnil(target) {
        (g^).items.get_ptr("float64") as ^code.Handle;
    } else {
        # Return the targeted type.
        target;
    }
}

# Resolve a binary logical expression.
# -----------------------------------------------------------------------------
def resolve_logical_expr_b(g: ^mut Generator, _: ^code.Handle,
                           node: ^ast.Node)
        -> ^code.Handle {

    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve the types of the operands.
    let lhs: ^code.Handle = resolve_type(g, &x.lhs);
    let rhs: ^code.Handle = resolve_type(g, &x.rhs);
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
                           node: ^ast.Node)
        -> ^code.Handle {

    # Unwrap the node to its proper type.
    let x: ^ast.UnaryExpr = (node^).unwrap() as ^ast.UnaryExpr;

    # Resolve the types of the operand.
    let operand: ^code.Handle = resolve_type(g, &x.operand);
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
def resolve_add_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, node);
}

# Resolve an `sub` expression.
# -----------------------------------------------------------------------------
def resolve_sub_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, node);
}

# Resolve an `mul` expression.
# -----------------------------------------------------------------------------
def resolve_mul_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, node);
}

# Resolve an `mod` expression.
# -----------------------------------------------------------------------------
def resolve_mod_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, node);
}

# Resolve an `int_div` expression.
# -----------------------------------------------------------------------------
def resolve_int_div_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Resolve this as an arithmetic binary expression.
    resolve_arith_expr_b(g, _, node);
}

# Resolve an `div` expression.
# -----------------------------------------------------------------------------
def resolve_div_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve the types of the operands.
    let lhs: ^code.Handle = resolve_type(g, &x.lhs);
    let rhs: ^code.Handle = resolve_type(g, &x.rhs);
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
def resolve_arith_expr_b(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Resolve the types of the operands.
    let lhs: ^code.Handle = resolve_type(g, &x.lhs);
    let rhs: ^code.Handle = resolve_type(g, &x.rhs);
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

# Builders
# =============================================================================

# Build an arbitrary node.
# -----------------------------------------------------------------------------
def build(g: ^mut Generator, target: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    build_in(g, target, node, &g.ns);
}

# Build an arbitrary node.
# -----------------------------------------------------------------------------
def build_in(g: ^mut Generator, target: ^code.Handle,
             node: ^ast.Node, ns: ^list.List)
        -> ^code.Handle {
    # Get the build func.
    let fn: def (^mut Generator, ^code.Handle, ^ast.Node) -> ^code.Handle
        = g.builders[node.tag];

    # Save and set the namespace.
    let old_ns: list.List = g.ns;
    g.ns = ns^;

    # Resolve the type.
    let han: ^code.Handle = fn(g, target, node);

    # Unset our namespace.
    g.ns = old_ns;

    # Return the resolved type.
    han;
}

# Build a `boolean` expression.
# -----------------------------------------------------------------------------
def build_bool_expr(g: ^mut Generator, target: ^code.Handle, node: ^ast.Node)
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
def build_int_expr(g: ^mut Generator, target: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.IntegerExpr = (node^).unwrap() as ^ast.IntegerExpr;

    # Get the type handle from the target.
    let typ: ^code.Type = target._object as ^code.Type;

    # Get the text out of the node.
    let text: ast.arena.Store = x.text;

    # Build a llvm val for the boolean expression.
    let val: ^llvm.LLVMOpaqueValue;
    if target._tag == code.TAG_INT_TYPE {
        val = llvm.LLVMConstIntOfString(typ.handle, text._data,
                                        x.base as uint8);
    } else {
        val = llvm.LLVMConstRealOfString(typ.handle, text._data);
    }

    # Wrap and return the value.
    code.make_value(target, val);
}

# Build a `float` expression.
# -----------------------------------------------------------------------------
def build_float_expr(g: ^mut Generator, target: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.FloatExpr = (node^).unwrap() as ^ast.FloatExpr;

    # Get the type handle from the target.
    let typ: ^code.Type = target._object as ^code.Type;

    # Get the text out of the node.
    let text: ast.arena.Store = x.text;

    # Build a llvm val for the boolean expression.
    let val: ^llvm.LLVMOpaqueValue;
    val = llvm.LLVMConstRealOfString(typ.handle, text._data);

    # Wrap and return the value.
    code.make_value(target, val);
}

# Build an `ident` expression.
# -----------------------------------------------------------------------------
def build_ident_expr(g: ^mut Generator, target: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the node to its proper type.
    let x: ^ast.Ident = (node^).unwrap() as ^ast.Ident;

    # Unwrap the name for the id.
    let name: ast.arena.Store = x.name;

    # Retrieve the item with scope resolution rules.
    let item: ^code.Handle = (g^)._get_scoped_item_in(name._data as str, g.ns);
    if item == 0 as ^code.Handle {
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "name '%s' is not defined" as ^int8,
                       name._data);
        errors.end();

        return code.make_nil();
    }

    # Return the item.
    item;
}

# Build a `return`.
# -----------------------------------------------------------------------------
def build_ret(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Unwrap the "ploymorphic" node to its proper type.
    let x: ^ast.ReturnExpr = (node^).unwrap() as ^ast.ReturnExpr;

    # Generate a handle for the expression (if we have one.)
    if not ast.isnull(x.expression) {
        let expr: ^code.Handle = build(g, _, &x.expression);
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
def build_expr_b(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> (^code.Handle, ^code.Handle, ^code.Handle) {
    let res: (^code.Handle, ^code.Handle, ^code.Handle) = (
        code.make_nil(), code.make_nil(), code.make_nil());

    # Unwrap the node to its proper type.
    let x: ^ast.BinaryExpr = (node^).unwrap() as ^ast.BinaryExpr;

    # Build each operand.
    let lhs: ^code.Handle = build(g, _, &x.lhs);
    let rhs: ^code.Handle = build(g, _, &x.rhs);
    if code.isnil(lhs) or code.isnil(rhs) { return res; }

    # Coerce the operands to values.
    let lhs_val_han: ^code.Handle = (g^)._to_value(lhs, false);
    let rhs_val_han: ^code.Handle = (g^)._to_value(rhs, false);
    if code.isnil(lhs_val_han) or code.isnil(rhs_val_han) { return res; }

    # Resolve our type.
    let target: ^code.Handle = resolve_targeted_type(g, _, node);

    # Cast each operand to the target type.
    let lhs_han: ^code.Handle = (g^)._cast(lhs_val_han, target);
    let rhs_han: ^code.Handle = (g^)._cast(rhs_val_han, target);

    # Dispose.
    code.dispose(lhs_val_han);
    code.dispose(rhs_val_han);

    # Create a tuple result.
    res = (target, lhs_han, rhs_han);
    res;
}

# Build an `add` expression.
# -----------------------------------------------------------------------------
def build_add_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let type_: ^code.Handle;
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (type_, lhs_han, rhs_han) = build_expr_b(g, _, node);

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
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `sub` expression.
# -----------------------------------------------------------------------------
def build_sub_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let type_: ^code.Handle;
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (type_, lhs_han, rhs_han) = build_expr_b(g, _, node);

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
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `mul` expression.
# -----------------------------------------------------------------------------
def build_mul_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let type_: ^code.Handle;
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (type_, lhs_han, rhs_han) = build_expr_b(g, _, node);

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
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `int div` expression.
# -----------------------------------------------------------------------------
def build_int_div_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let type_: ^code.Handle;
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (type_, lhs_han, rhs_han) = build_expr_b(g, _, node);

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
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `div` expression.
# -----------------------------------------------------------------------------
def build_div_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let type_: ^code.Handle;
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (type_, lhs_han, rhs_han) = build_expr_b(g, _, node);

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
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Build an `mod` expression.
# -----------------------------------------------------------------------------
def build_mod_expr(g: ^mut Generator, _: ^code.Handle, node: ^ast.Node)
        -> ^code.Handle {
    # Build each operand.
    let type_: ^code.Handle;
    let lhs_han: ^code.Handle;
    let rhs_han: ^code.Handle;
    (type_, lhs_han, rhs_han) = build_expr_b(g, _, node);

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
    code.dispose(lhs_han);
    code.dispose(rhs_han);

    # Return our wrapped result.
    han;
}

# Test driver using `stdin`.
# =============================================================================
def main() {
    # Parse the AST from the standard input.
    let unit: ast.Node = parser.parse();
    if errors.count > 0 { libc.exit(-1); }

    # Insert an `assert` function.
    # _declare_assert();

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
