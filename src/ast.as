foreign "C" import "stdio.h";
import arena;

# AST tag defintions
# -----------------------------------------------------------------------------
# AST tags are just an enumeration of all possible nodes.
let TAG_INTEGER   : int = 1;              # IntegerExpr
let TAG_ADD       : int = 2;              # AddExpr
let TAG_SUBTRACT  : int = 3;              # SubtractExpr
let TAG_MODULE    : int = 4;              # ModuleDecl
let TAG_NODES     : int = 5;              # Nodes

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

# Binary expression type for an "addition" operation.
type AddExpr { lhs: Node, rhs: Node }

# Binary expression type for a "subtraction" operation.
type SubtractExpr { lhs: Node, rhs: Node }

# Module declaration that contains a sequence of nodes.
type ModuleDecl { nodes: Nodes }

# sizeof -- Get the size required for a specific node tag.
# -----------------------------------------------------------------------------
# FIXME: Replace this monster with type(T).size as soon as humanely possible
def _sizeof(tag: int) -> uint {
    if tag == TAG_INTEGER {
        let tmp: IntegerExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_ADD
           or tag == TAG_SUBTRACT {
        let tmp: AddExpr;
        ((&tmp + 1) - &tmp);
   } else if tag == TAG_MODULE {
        let tmp: ModuleDecl;
        ((&tmp + 1) - &tmp);
   } else if tag == TAG_NODES {
        let tmp: Nodes;
        ((&tmp + 1) - &tmp);
   } else {
        0;
   }
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

    # Set the next pointer.
    block.next = nodes.next;
    nodes.next = m.data;
}

# length -- Gets the length of the Nodes list.
# -----------------------------------------------------------------------------
def length(&nodes: Nodes) -> uint {
    if isnull(nodes.self) { return 0; }
    let mut count: uint = 1;
    let mut m: arena.Store = nodes.next;
    let mut block: ^Nodes = m._data as ^Nodes;
    loop {
        if block == 0 as ^Nodes { break; }
        count = count + 1;
        m = block.next;
        block = m._data as ^Nodes;
    }
    count;
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
let mut dump_table: def(^Node)[7];
let mut dump_indent: int = 0;
let mut dump_initialized: bool = false;
def dump(&node: Node) {
    if not dump_initialized {
        dump_table[TAG_INTEGER] = dump_integer_expr;
        dump_table[TAG_MODULE] = dump_module;
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

# dump_integer_expr
# -----------------------------------------------------------------------------
def dump_integer_expr(node: ^Node) {
    let x: ^IntegerExpr = unwrap(node^) as ^IntegerExpr;
    let xs: arena.Store = x.text;
    printf("IntegerExpr <?> 'int' %s (%d)\n" as ^int8, xs._data, x.base);
}

# dump_module
# -----------------------------------------------------------------------------
def dump_module(node: ^Node) {
    let x: ^ModuleDecl = unwrap(node^) as ^ModuleDecl;
    printf("ModuleDecl <?> (%d)\n" as ^int8, length(x.nodes));

    # Enumerate through each node in the module.
    dump_indent = dump_indent + 1;
    let mut iter: NodesIterator = iter_nodes(x.nodes);
    while not iter_empty(iter) {
        let node: Node = iter_next(iter);
        dump(node);
    }
    dump_indent = dump_indent - 1;
}
