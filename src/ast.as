foreign "C" import "stdio.h";
import arena;

# AST tag defintions
# -----------------------------------------------------------------------------
# AST tags are just an enumeration of all possible nodes.
let TAG_INTEGER         : int =  1;             # IntegerExpr
let TAG_ADD             : int =  2;             # AddExpr
let TAG_SUBTRACT        : int =  3;             # SubtractExpr
let TAG_MULTIPLY        : int =  4;             # MultiplyExpr
let TAG_DIVIDE          : int =  5;             # DivideExpr
let TAG_MODULO          : int =  6;             # ModuloExpr
let TAG_PROMOTE         : int =  7;             # NumericPromoteExpr
let TAG_NUMERIC_NEGATE  : int =  8;             # NumericNegateExpr
let TAG_LOGICAL_NEGATE  : int =  9;             # LogicalNegateExpr
let TAG_LOGICAL_AND     : int = 10;             # LogicalAndExpr
let TAG_LOGICAL_OR      : int = 11;             # LogicalOrExpr
let TAG_EQ              : int = 12;             # EQExpr
let TAG_NE              : int = 13;             # NEExpr
let TAG_LT              : int = 14;             # LTExpr
let TAG_LE              : int = 15;             # LEExpr
let TAG_GT              : int = 16;             # GTExpr
let TAG_GE              : int = 17;             # GEExpr
let TAG_MODULE          : int = 18;             # ModuleDecl
let TAG_NODES           : int = 19;             # Nodes
let TAG_BOOLEAN         : int = 20;             # BooleanExpr
let TAG_STATIC_SLOT     : int = 21;             # StaticSlotDecl
let TAG_LOCAL_SLOT      : int = 22;             # LocalSlotDecl
let TAG_IDENT           : int = 23;             # Ident
let TAG_ASSIGN          : int = 24;             # AssignExpr

# AST node defintions
# -----------------------------------------------------------------------------

# Generic AST "node" that can store a node generically.
# NOTE: This is filthy polymorphism.
type Node { tag: int, data: arena.Store }

# Generic collection of AST "nodes" that can store a
# heterogeneous linked-list of nodes.
type Nodes { self: Node, next: arena.Store }
type NodesIterator { current: ^Nodes }

# Expression type for integral literals with a distinct base like "2321".
type IntegerExpr { base: int8, text: arena.Store }

# Expression type for a boolean literal
type BooleanExpr { value: bool }

# "Generic" binary expression type.
type BinaryExpr { lhs: Node, rhs: Node }

# "Generic" unary expression type.
type UnaryExpr { operand: Node }

# Module declaration that contains a sequence of nodes.
type ModuleDecl { nodes: Nodes }

# Static slot declaration.
type StaticSlotDecl {
    id: Node,
    type_: Node,
    mutable: bool,
    initializer: Node
}

# Local slot declaration.
type LocalSlotDecl {
    id: Node,
    type_: Node,
    mutable: bool,
    initializer: Node
}

# Identifier.
type Ident { name: arena.Store }

# sizeof -- Get the size required for a specific node tag.
# -----------------------------------------------------------------------------
# FIXME: Replace this monster with type(T).size as soon as humanely possible
def _sizeof(tag: int) -> uint {
    if tag == TAG_INTEGER {
        let tmp: IntegerExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_ADD
           or tag == TAG_SUBTRACT
           or tag == TAG_MULTIPLY
           or tag == TAG_DIVIDE
           or tag == TAG_MODULO
           or tag == TAG_LOGICAL_AND
           or tag == TAG_LOGICAL_OR
           or tag == TAG_EQ
           or tag == TAG_NE
           or tag == TAG_LT
           or tag == TAG_LE
           or tag == TAG_GT
           or tag == TAG_GE
           or tag == TAG_ASSIGN {
        let tmp: BinaryExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_PROMOTE
           or tag == TAG_NUMERIC_NEGATE
           or tag == TAG_LOGICAL_NEGATE {
        let tmp: UnaryExpr;
        ((&tmp + 1) - &tmp);
    }
    else if tag == TAG_MODULE  { let tmp: ModuleDecl; ((&tmp + 1) - &tmp); }
    else if tag == TAG_NODES   { let tmp: Nodes; ((&tmp + 1) - &tmp); }
    else if tag == TAG_NODES   { let tmp: Nodes; ((&tmp + 1) - &tmp); }
    else if tag == TAG_BOOLEAN { let tmp: BooleanExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_IDENT   { let tmp: Ident; ((&tmp + 1) - &tmp); }
    else if tag == TAG_STATIC_SLOT {
        let tmp: StaticSlotDecl;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_LOCAL_SLOT {
        let tmp: LocalSlotDecl;
        ((&tmp + 1) - &tmp);
    }
    else { 0; }
}

# make -- Allocate space for a node in the AST
# -----------------------------------------------------------------------------
def make(tag: int) -> Node {
    # Create the node object.
    let node: Node;
    node.tag = tag;

    # Allocate a store on the arena.
    node.data = arena.alloc(_sizeof(tag));

    # Return the node.
    node;
}

# unwrap -- Pull out the actual node data of a generic AST node.
# -----------------------------------------------------------------------------
def unwrap(&node: Node) -> ^int8 {
    let store: arena.Store = node.data;
    store._data as ^int8;
}

# null -- Get a null node.
# -----------------------------------------------------------------------------
def null() -> Node {
    let mut node: Node;
    let &node_store: arena.Store = node.data;
    node.tag = 0;
    node_store._size = 0;
    node_store._data = 0 as ^int8;
    node;
}

# isnull -- Check for a null node.
# -----------------------------------------------------------------------------
def isnull(&node: Node) -> bool {
    node.tag == 0;
}

# push -- Push a node to the end of the Nodes list.
# -----------------------------------------------------------------------------
def push(&nodes: Nodes, &node: Node) {
    # Is this the initial node?
    if isnull(nodes.self) {
        # Yes; just store it in the block.
        nodes.self = node;
        return;
    }

    # Create a Nodes block to store the node.
    let m: Node = make(TAG_NODES);
    let block: ^Nodes = unwrap(m) as ^Nodes;
    block.self = node;

    # Find the end.
    let iter: ^Nodes = &nodes;
    loop {
        let &m2: arena.Store = iter.next;
        if m2._data == 0 as ^int8 { break; }
        iter = m2._data as ^Nodes;
    }

    # Set the next pointer.
    block.next = iter.next;
    iter.next = m.data;
}

# iter_nodes -- Make an iterator over Nodes.
# -----------------------------------------------------------------------------
def iter_nodes(&nodes: Nodes) -> NodesIterator {
    let mut iter: NodesIterator;
    iter.current = &nodes;
    iter;
}

# iter_empty -- Check if the iterator is empty.
# -----------------------------------------------------------------------------
def iter_empty(&iter: NodesIterator) -> bool {
    if iter.current == 0 as ^Nodes {
        true;
    } else if isnull(iter.current.self) {
        true;
    } else {
        false;
    }
}

# iter_next -- Advance the iterator.
# -----------------------------------------------------------------------------
def iter_next(&mut iter: NodesIterator) -> Node {
    let n: Node = iter.current.self;
    let m: arena.Store = iter.current.next;
    iter.current = m._data as ^Nodes;
    n;
}

# dump -- Dump a textual representation of the node to stdout.
# -----------------------------------------------------------------------------
let mut dump_table: def(^Node)[100];
let mut dump_indent: int = 0;
let mut dump_initialized: bool = false;
def dump(&node: Node) {
    if not dump_initialized {
        dump_table[TAG_INTEGER] = dump_integer_expr;
        dump_table[TAG_BOOLEAN] = dump_boolean_expr;
        dump_table[TAG_ADD] = dump_binop_expr;
        dump_table[TAG_SUBTRACT] = dump_binop_expr;
        dump_table[TAG_MULTIPLY] = dump_binop_expr;
        dump_table[TAG_DIVIDE] = dump_binop_expr;
        dump_table[TAG_MODULO] = dump_binop_expr;
        dump_table[TAG_MODULE] = dump_module;
        dump_table[TAG_PROMOTE] = dump_unary_expr;
        dump_table[TAG_NUMERIC_NEGATE] = dump_unary_expr;
        dump_table[TAG_LOGICAL_NEGATE] = dump_unary_expr;
        dump_table[TAG_LOGICAL_AND] = dump_binop_expr;
        dump_table[TAG_LOGICAL_OR] = dump_binop_expr;
        dump_table[TAG_EQ] = dump_binop_expr;
        dump_table[TAG_NE] = dump_binop_expr;
        dump_table[TAG_LT] = dump_binop_expr;
        dump_table[TAG_LE] = dump_binop_expr;
        dump_table[TAG_GT] = dump_binop_expr;
        dump_table[TAG_GE] = dump_binop_expr;
        dump_table[TAG_ASSIGN] = dump_binop_expr;
        dump_table[TAG_STATIC_SLOT] = dump_static_slot;
        dump_table[TAG_LOCAL_SLOT] = dump_local_slot;
        dump_table[TAG_IDENT] = dump_ident;
        dump_initialized = true;
    }

    let mut dump_indent_i: int = 0;
    while dump_indent > dump_indent_i {
        printf("  " as ^int8);
        dump_indent_i = dump_indent_i + 1;
    }

    let dump_fn: def(^Node) = dump_table[node.tag];
    let node_ptr: ^Node = &node;
    dump_fn(node_ptr);
}

# dump_boolean_expr
# -----------------------------------------------------------------------------
def dump_boolean_expr(node: ^Node) {
    let x: ^BooleanExpr = unwrap(node^) as ^BooleanExpr;
    printf("BooleanExpr <?> %s\n" as ^int8, "true" if x.value else "false");
}

# dump_integer_expr
# -----------------------------------------------------------------------------
def dump_integer_expr(node: ^Node) {
    let x: ^IntegerExpr = unwrap(node^) as ^IntegerExpr;
    let xs: arena.Store = x.text;
    printf("IntegerExpr <?> 'int' %s (%d)\n" as ^int8, xs._data, x.base);
}

# dump_binop_expr
# -----------------------------------------------------------------------------
def dump_binop_expr(node: ^Node) {
    let x: ^BinaryExpr = unwrap(node^) as ^BinaryExpr;
    if node.tag == TAG_ADD {
        printf("AddExpr <?>\n" as ^int8);
    } else if node.tag == TAG_SUBTRACT {
        printf("SubtractExpr <?>\n" as ^int8);
    } else if node.tag == TAG_MULTIPLY {
        printf("MultiplyExpr <?>\n" as ^int8);
    } else if node.tag == TAG_DIVIDE {
        printf("DivideExpr <?>\n" as ^int8);
    } else if node.tag == TAG_MODULO {
        printf("ModuloExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LOGICAL_AND {
        printf("LogicalAndExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LOGICAL_OR {
        printf("LogicalOrExpr <?>\n" as ^int8);
    } else if node.tag == TAG_EQ {
        printf("EQExpr <?>\n" as ^int8);
    } else if node.tag == TAG_NE {
        printf("NEExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LT {
        printf("LTExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LE {
        printf("LEExpr <?>\n" as ^int8);
    } else if node.tag == TAG_GT {
        printf("GTExpr <?>\n" as ^int8);
    } else if node.tag == TAG_GE {
        printf("GEExpr <?>\n" as ^int8);
    } else if node.tag == TAG_ASSIGN {
        printf("AssignExpr <?>\n" as ^int8);
    }
    dump_indent = dump_indent + 1;
    dump(x.lhs);
    dump(x.rhs);
    dump_indent = dump_indent - 1;
}

# dump_unary_expr
# -----------------------------------------------------------------------------
def dump_unary_expr(node: ^Node) {
    let x: ^UnaryExpr = unwrap(node^) as ^UnaryExpr;
    if node.tag == TAG_PROMOTE {
        printf("NumericPromoteExpr <?>\n" as ^int8);
    } else if node.tag == TAG_NUMERIC_NEGATE {
        printf("NumericNegateExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LOGICAL_NEGATE {
        printf("LogicalNegateExpr <?>\n" as ^int8);
    }
    dump_indent = dump_indent + 1;
    dump(x.operand);
    dump_indent = dump_indent - 1;
}

# dump_module
# -----------------------------------------------------------------------------
def dump_module(node: ^Node) {
    let x: ^ModuleDecl = unwrap(node^) as ^ModuleDecl;
    printf("ModuleDecl <?>\n" as ^int8);

    # Enumerate through each node in the module.
    dump_indent = dump_indent + 1;
    let mut iter: NodesIterator = iter_nodes(x.nodes);
    while not iter_empty(iter) {
        let node: Node = iter_next(iter);
        dump(node);
    }
    dump_indent = dump_indent - 1;
}

# dump_type
# -----------------------------------------------------------------------------
def dump_type(node: ^Node) {
    if node.tag == TAG_IDENT {
        let x: ^Ident = unwrap(node^) as ^Ident;
        let xs: arena.Store = x.name;
        printf("%s" as ^int8, xs._data);
    }
}

# dump_ident
# -----------------------------------------------------------------------------
def dump_ident(node: ^Node) {
    let x: ^Ident = unwrap(node^) as ^Ident;
    let xs: arena.Store = x.name;
    printf("Ident <?> %s\n" as ^int8, xs._data);
}

# dump_static_slot
# -----------------------------------------------------------------------------
def dump_static_slot(node: ^Node) {
    let x: ^StaticSlotDecl = unwrap(node^) as ^StaticSlotDecl;
    printf("StaticSlotDecl <?> " as ^int8);
    if x.mutable { printf("mut " as ^int8); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    let xs: arena.Store = id.name;
    printf("%s" as ^int8, xs._data);
    printf(" '" as ^int8);
    dump_type(&x.type_);
    printf("'\n" as ^int8);

    dump_indent = dump_indent + 1;
    if not isnull(x.initializer) { dump(x.initializer); }
    dump_indent = dump_indent - 1;
}

# dump_local_slot
# -----------------------------------------------------------------------------
def dump_local_slot(node: ^Node) {
    let x: ^LocalSlotDecl = unwrap(node^) as ^LocalSlotDecl;
    printf("LocalSlotDecl <?> " as ^int8);
    if x.mutable { printf("mut " as ^int8); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    let xs: arena.Store = id.name;
    printf("%s" as ^int8, xs._data);
    if not isnull(x.type_) {
        printf(" '" as ^int8);
        dump_type(&x.type_);
        printf("'" as ^int8);
    }
    printf("\n" as ^int8);

    dump_indent = dump_indent + 1;
    if not isnull(x.initializer) { dump(x.initializer); }
    dump_indent = dump_indent - 1;
}