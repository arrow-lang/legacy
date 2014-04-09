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
    mut type_resolvers: (def (^mut Generator, ^ast.Node) -> ^code.Handle)[100]
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
    self.type_resolvers[ast.TAG_LOGICAL_AND] = resolve_logical_expr_b;
    self.type_resolvers[ast.TAG_LOGICAL_OR] = resolve_logical_expr_b;
    self.type_resolvers[ast.TAG_LOGICAL_NEGATE] = resolve_logical_expr_u;
    self.type_resolvers[ast.TAG_IDENT] = resolve_type_ident;
    self.type_resolvers[ast.TAG_TYPE_EXPR] = resolve_type_expr;

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

        # Does this item need its `type` resolved?
        if val._tag == code.TAG_STATIC_SLOT {
            self._gen_decl_static_slot(key, val._object as ^code.StaticSlot);
        }
    }
}

def _gen_decl_static_slot(&mut self, qname: str, x: ^code.StaticSlot) {
    # Get the type node out of the handle.
    let type_: ^code.Type = x.type_._object as ^code.Type;

    # Add the global slot declaration to the IR.
    # TODO: Set priv, vis, etc.
    llvm.LLVMAddGlobal(self.mod, type_.handle, qname as ^int8);
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
        if val._tag == code.TAG_STATIC_SLOT {
            self._gen_type(val, false);
        }
    }
}

def _gen_type(&mut self, handle: ^code.Handle, explicit: bool)
        -> ^code.Handle {
    # Resolve the type.
    if handle._tag == code.TAG_STATIC_SLOT {
        self._gen_type_static_slot(handle._object as ^code.StaticSlot,
                                       explicit);
    } else {
        return code.make_nil();
    }
}

def _gen_type_static_slot(&mut self, x: ^code.StaticSlot, explicit: bool)
        -> ^code.Handle {
    # Is our type resolved?
    if x.type_ <> 0 as ^code.Handle {
        # Yes; return it.
        x.type_;
    } else {
        # Get and resolve the type node.
        let han: ^code.Handle = resolve_type_in(
            &self, &x.context.type_, &x.namespace);

        if han == 0 as ^code.Handle { return code.make_nil(); }

        # Store the type handle.
        x.type_ = han;

        # Return our type.
        han;
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
                      signed: bool) {
    let han: ^code.Handle = code.make_int_type(val, signed);
    self.items.set_ptr(name, han as ^void);
}

# Declare a float type in `global` scope.
# -----------------------------------------------------------------------------
def _declare_float_type(&mut self, name: str, val: ^llvm.LLVMOpaqueType) {
    let han: ^code.Handle = code.make_float_type(val);
    self.items.set_ptr(name, han as ^void);
}

# Declare "basic" types
# -----------------------------------------------------------------------------
def _declare_basic_types(&mut self) {
    # Boolean
    self.items.set_ptr("bool", code.make_bool_type(
        llvm.LLVMInt1Type()) as ^void);

    # Signed machine-independent integers
    self._declare_int_type(  "int8",   llvm.LLVMInt8Type(), true);
    self._declare_int_type( "int16",  llvm.LLVMInt16Type(), true);
    self._declare_int_type( "int32",  llvm.LLVMInt32Type(), true);
    self._declare_int_type( "int64",  llvm.LLVMInt64Type(), true);
    self._declare_int_type("int128", llvm.LLVMIntType(128), true);

    # Unsigned machine-independent integers
    self._declare_int_type(  "uint8",   llvm.LLVMInt8Type(), false);
    self._declare_int_type( "uint16",  llvm.LLVMInt16Type(), false);
    self._declare_int_type( "uint32",  llvm.LLVMInt32Type(), false);
    self._declare_int_type( "uint64",  llvm.LLVMInt64Type(), false);
    self._declare_int_type("uint128", llvm.LLVMIntType(128), false);

    # Floating-points
    self._declare_float_type("float32", llvm.LLVMFloatType());
    self._declare_float_type("float64", llvm.LLVMDoubleType());

    # TODO: Unsigned machine-dependent integer

    # TODO: Signed machine-dependent integer

    # TODO: UTF-32 Character

    # TODO: UTF-8 String
}

} # implement Generator

# Type resolvers
# =============================================================================

# Resolve an arbitrary type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_type(g: ^mut Generator, node: ^ast.Node)
        -> ^code.Handle {
    resolve_type_in(g, node, &g.ns);
}

# Resolve an arbitrary type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_type_in(g: ^mut Generator, node: ^ast.Node, ns: ^list.List)
        -> ^code.Handle {
    # Get the type resolution func.
    let res_fn: def (^mut Generator, ^ast.Node) -> ^code.Handle
        = g.type_resolvers[node.tag];

    # Save the current namespace.
    let old_ns: list.List = g.ns;

    # Set our namespace.
    g.ns = ns^;

    # Resolve the type.
    let han: ^code.Handle = res_fn(g, node);

    # Unset our namespace.
    g.ns = old_ns;

    # Return the resolved type.
    han;
}

# Resolve an `identifier` for a type.
# -----------------------------------------------------------------------------
def resolve_type_ident(g: ^mut Generator, node: ^ast.Node) -> ^code.Handle {
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
                item._object as ^code.StaticSlot, false);
        } else {
            # Return nil.
            code.make_nil();
        }
    } else {
        # Return the type reference.
        item;
    }
}

# Resolve a `type expression` for a type -- type(..)
# -----------------------------------------------------------------------------
def resolve_type_expr(g: ^mut Generator, node: ^ast.Node) -> ^code.Handle {
    # An arbitrary type deferrence expression.

    # Unwrap the type expression.
    let x: ^ast.TypeExpr = (node^).unwrap() as ^ast.TypeExpr;

    # Resolve the expression.
    resolve_type(g, &x.expression);
}

# Resolve a `boolean expression` for its type.
# -----------------------------------------------------------------------------
def resolve_bool_expr(g: ^mut Generator, node: ^ast.Node) -> ^code.Handle {
    # Wonder what the type of this is.
    (g^).items.get_ptr("bool") as ^code.Handle;
}

# Resolve a binary logical expression.
# -----------------------------------------------------------------------------
def resolve_logical_expr_b(g: ^mut Generator, node: ^ast.Node)
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
def resolve_logical_expr_u(g: ^mut Generator, node: ^ast.Node)
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
