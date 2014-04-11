import libc;
import list;
import string;

# [ ] Add '.dispose' methods to dispose of memory

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
let TAG_ASSIGN_ADD      : int = 25;             # AssignAddExpr
let TAG_ASSIGN_SUB      : int = 26;             # AssignSubtractExpr
let TAG_ASSIGN_MULT     : int = 27;             # AssignMultiplyExpr
let TAG_ASSIGN_DIV      : int = 28;             # AssignDivideExpr
let TAG_ASSIGN_MOD      : int = 29;             # AssignModuloExpr
let TAG_SELECT          : int = 30;             # SelectExpr
let TAG_SELECT_BRANCH   : int = 31;             # SelectBranch
let TAG_SELECT_OP       : int = 32;             # SelectOpExpr
let TAG_CONDITIONAL     : int = 33;             # ConditionalExpr
let TAG_FUNC_DECL       : int = 34;             # FuncDecl
let TAG_FUNC_PARAM      : int = 35;             # FuncParam
let TAG_FLOAT           : int = 36;             # Float
let TAG_UNSAFE          : int = 37;             # UnsafeBlock
let TAG_RETURN          : int = 38;             # ReturnExpr
let TAG_BLOCK           : int = 39;             # Block
let TAG_MEMBER          : int = 40;             # MemberExpr
let TAG_NODE            : int = 41;             # Node
let TAG_IMPORT          : int = 42;             # Import
let TAG_CALL            : int = 43;             # CallExpr
let TAG_INDEX           : int = 44;             # IndexExpr
let TAG_CALL_ARG        : int = 45;             # Argument
let TAG_TYPE_EXPR       : int = 46;             # TypeExpr
let TAG_INTEGER_DIVIDE  : int = 47;             # IntDivideExpr
let TAG_ASSIGN_INT_DIV  : int = 48;             # AssignIntDivideExpr

# AST node defintions
# -----------------------------------------------------------------------------

# Generic AST "node" that can store a node generically.
# NOTE: This is filthy polymorphism.
type Node { tag: int, data: ^void }

implement Node {
    def unwrap(&self) -> ^void { self.data; }
}

# Generic collection of AST "nodes" that can store a
# heterogeneous linked-list of nodes.
type Nodes { mut elements: list.List }

def new_nodes() -> ^Nodes {
    let node: Node = make(TAG_NODES);
    node.data as ^Nodes;
}

implement Nodes {

    def size(&self) -> uint { self.elements.size; }

    def push(&mut self, el: Node) {
        # Ensure our `element_size` is set correctly.
        self.elements.element_size = _sizeof(TAG_NODE);

        # Push the node onto our list.
        self.elements.push(&el as ^void);
    }

    def get(&self, i: int) -> Node {
        let ptr: ^Node = self.elements.at(i) as ^Node;
        ptr^;
    }

}

# Expression type for integral literals with a distinct base like "2321".
type IntegerExpr { base: int8, mut text: string.String }

# Expression type for float literals.
type FloatExpr { mut text: string.String }

# Expression type for a boolean literal
type BooleanExpr { value: bool }

# "Generic" binary expression type.
type BinaryExpr { lhs: Node, rhs: Node }

# Index expression type.
type IndexExpr { expression: Node, subscript: Node }

# Conditional expression.
type ConditionalExpr { lhs: Node, rhs: Node, condition: Node }

# "Generic" unary expression type.
type UnaryExpr { operand: Node }

# Module declaration that contains a sequence of nodes.
type ModuleDecl { id: Node, mut nodes: Nodes }

# Unsafe block.
type UnsafeBlock { mut nodes: Nodes }

# Block.
type Block { mut nodes: Nodes }

# Return expression.
type ReturnExpr { expression: Node }

# Type expression.
type TypeExpr { expression: Node }

# Selection expression.
type SelectExpr { mut branches: Nodes }

# Selection branch.
type SelectBranch { condition: Node, mut nodes: Nodes }

# Function declaration.
type FuncDecl {
    id: Node,
    return_type: Node,
    mut params: Nodes,
    mut nodes: Nodes
}

# Function parameter.
type FuncParam {
    id: Node,
    type_: Node,
    mutable: bool,
    default: Node
}

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

# Call expression
type CallExpr { expression: Node, mut arguments: Nodes }

# Call arguments
type Argument { expression: Node, name: Node }

# Identifier.
type Ident { mut name: string.String }

# Import
# ids: ordered collection of the identifiers that make up the `x.y.z` name
#      to import.
type Import { mut ids: Nodes }

# sizeof -- Get the size required for a specific node tag.
# -----------------------------------------------------------------------------
# FIXME: Replace this monster with type(T).size as soon as humanely possible
def _sizeof(tag: int) -> uint {
    if tag == TAG_INTEGER {
        let tmp: IntegerExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_FLOAT {
        let tmp: FloatExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_ADD
           or tag == TAG_SUBTRACT
           or tag == TAG_MULTIPLY
           or tag == TAG_DIVIDE
           or tag == TAG_INTEGER_DIVIDE
           or tag == TAG_MODULO
           or tag == TAG_LOGICAL_AND
           or tag == TAG_LOGICAL_OR
           or tag == TAG_EQ
           or tag == TAG_NE
           or tag == TAG_LT
           or tag == TAG_LE
           or tag == TAG_GT
           or tag == TAG_GE
           or tag == TAG_ASSIGN
           or tag == TAG_ASSIGN_ADD
           or tag == TAG_ASSIGN_SUB
           or tag == TAG_ASSIGN_MULT
           or tag == TAG_ASSIGN_DIV
           or tag == TAG_ASSIGN_INT_DIV
           or tag == TAG_ASSIGN_MOD
           or tag == TAG_SELECT_OP
           or tag == TAG_MEMBER {
        let tmp: BinaryExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_CONDITIONAL {
        let tmp: ConditionalExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_PROMOTE
           or tag == TAG_NUMERIC_NEGATE
           or tag == TAG_LOGICAL_NEGATE {
        let tmp: UnaryExpr;
        ((&tmp + 1) - &tmp);
    }
    else if tag == TAG_MODULE  { let tmp: ModuleDecl; ((&tmp + 1) - &tmp); }
    else if tag == TAG_UNSAFE  { let tmp: UnsafeBlock; ((&tmp + 1) - &tmp); }
    else if tag == TAG_BLOCK   { let tmp: Block; ((&tmp + 1) - &tmp); }
    else if tag == TAG_NODE    { let tmp: Node; ((&tmp + 1) - &tmp); }
    else if tag == TAG_NODES   { let tmp: Nodes; ((&tmp + 1) - &tmp); }
    else if tag == TAG_BOOLEAN { let tmp: BooleanExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_IDENT   { let tmp: Ident; ((&tmp + 1) - &tmp); }
    else if tag == TAG_IMPORT  { let tmp: Import; ((&tmp + 1) - &tmp); }
    else if tag == TAG_INDEX   { let tmp: IndexExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_CALL    { let tmp: CallExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_CALL_ARG{ let tmp: Argument; ((&tmp + 1) - &tmp); }
    else if tag == TAG_STATIC_SLOT {
        let tmp: StaticSlotDecl;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_LOCAL_SLOT {
        let tmp: LocalSlotDecl;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_SELECT {
        let tmp: SelectExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_SELECT_BRANCH {
        let tmp: SelectBranch;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_FUNC_DECL {
        let tmp: FuncDecl;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_FUNC_PARAM {
        let tmp: FuncParam;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_RETURN {
        let tmp: ReturnExpr;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_TYPE_EXPR {
        let tmp: TypeExpr;
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
    node.data = libc.calloc(_sizeof(tag), 1);

    # Return the node.
    node;
}

# unwrap -- Pull out the actual node data of a generic AST node.
# -----------------------------------------------------------------------------
def unwrap(&node: Node) -> ^void { node.unwrap(); }

# null -- Get a null node.
# -----------------------------------------------------------------------------
def null() -> Node {
    let mut node: Node;
    node.tag = 0;
    node.data = 0 as ^void;
    node;
}

# isnull -- Check for a null node.
# -----------------------------------------------------------------------------
def isnull(&node: Node) -> bool { node.tag == 0; }

# dump -- Dump a textual representation of the node to stdout.
# -----------------------------------------------------------------------------
let mut dump_table: def(^Node)[100];
let mut dump_indent: int = 0;
let mut dump_initialized: bool = false;
def dump(&node: Node) {
    if not dump_initialized {
        dump_table[TAG_INTEGER] = dump_integer_expr;
        dump_table[TAG_FLOAT] = dump_float_expr;
        dump_table[TAG_BOOLEAN] = dump_boolean_expr;
        dump_table[TAG_ADD] = dump_binop_expr;
        dump_table[TAG_SUBTRACT] = dump_binop_expr;
        dump_table[TAG_MULTIPLY] = dump_binop_expr;
        dump_table[TAG_DIVIDE] = dump_binop_expr;
        dump_table[TAG_INTEGER_DIVIDE] = dump_binop_expr;
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
        dump_table[TAG_ASSIGN_ADD] = dump_binop_expr;
        dump_table[TAG_ASSIGN_SUB] = dump_binop_expr;
        dump_table[TAG_ASSIGN_MULT] = dump_binop_expr;
        dump_table[TAG_ASSIGN_DIV] = dump_binop_expr;
        dump_table[TAG_ASSIGN_INT_DIV] = dump_binop_expr;
        dump_table[TAG_ASSIGN_MOD] = dump_binop_expr;
        dump_table[TAG_SELECT_OP] = dump_binop_expr;
        dump_table[TAG_STATIC_SLOT] = dump_static_slot;
        dump_table[TAG_LOCAL_SLOT] = dump_local_slot;
        dump_table[TAG_IDENT] = dump_ident;
        dump_table[TAG_SELECT] = dump_select_expr;
        dump_table[TAG_SELECT_BRANCH] = dump_select_branch;
        dump_table[TAG_CONDITIONAL] = dump_conditional_expr;
        dump_table[TAG_FUNC_DECL] = dump_func_decl;
        dump_table[TAG_FUNC_PARAM] = dump_func_param;
        dump_table[TAG_UNSAFE] = dump_unsafe_block;
        dump_table[TAG_BLOCK] = dump_block_expr;
        dump_table[TAG_RETURN] = dump_return_expr;
        dump_table[TAG_MEMBER] = dump_binop_expr;
        dump_table[TAG_IMPORT] = dump_import;
        dump_table[TAG_INDEX] = dump_index_expr;
        dump_table[TAG_CALL] = dump_call_expr;
        dump_table[TAG_CALL_ARG] = dump_call_arg;
        dump_table[TAG_TYPE_EXPR] = dump_type_expr;
        dump_initialized = true;
    }

    print_indent();
    let dump_fn: def(^Node) = dump_table[node.tag];
    let node_ptr: ^Node = &node;
    dump_fn(node_ptr);
}

# print_indent
# -----------------------------------------------------------------------------
def print_indent() {
    let mut dump_indent_i: int = 0;
    while dump_indent > dump_indent_i {
        printf("  ");
        dump_indent_i = dump_indent_i + 1;
    }
}

# dump_boolean_expr
# -----------------------------------------------------------------------------
def dump_boolean_expr(node: ^Node) {
    let x: ^BooleanExpr = unwrap(node^) as ^BooleanExpr;
    printf("BooleanExpr <?> %s\n", "true" if x.value else "false");
}

# dump_integer_expr
# -----------------------------------------------------------------------------
def dump_integer_expr(node: ^Node) {
    let x: ^IntegerExpr = unwrap(node^) as ^IntegerExpr;
    printf("IntegerExpr <?> %s (%d)\n", x.text.data(), x.base);
}

# dump_float_expr
# -----------------------------------------------------------------------------
def dump_float_expr(node: ^Node) {
    let x: ^FloatExpr = unwrap(node^) as ^FloatExpr;
    printf("FloatExpr <?> %s\n", x.text.data());
}

# dump_binop_expr
# -----------------------------------------------------------------------------
def dump_binop_expr(node: ^Node) {
    let x: ^BinaryExpr = unwrap(node^) as ^BinaryExpr;
    if node.tag == TAG_ADD {
        printf("AddExpr <?>\n");
    } else if node.tag == TAG_SUBTRACT {
        printf("SubtractExpr <?>\n");
    } else if node.tag == TAG_MULTIPLY {
        printf("MultiplyExpr <?>\n");
    } else if node.tag == TAG_DIVIDE {
        printf("DivideExpr <?>\n");
    }  else if node.tag == TAG_INTEGER_DIVIDE {
        printf("IntDivideExpr <?>\n");
    } else if node.tag == TAG_MODULO {
        printf("ModuloExpr <?>\n");
    } else if node.tag == TAG_LOGICAL_AND {
        printf("LogicalAndExpr <?>\n");
    } else if node.tag == TAG_LOGICAL_OR {
        printf("LogicalOrExpr <?>\n");
    } else if node.tag == TAG_EQ {
        printf("EQExpr <?>\n");
    } else if node.tag == TAG_NE {
        printf("NEExpr <?>\n");
    } else if node.tag == TAG_LT {
        printf("LTExpr <?>\n");
    } else if node.tag == TAG_LE {
        printf("LEExpr <?>\n");
    } else if node.tag == TAG_GT {
        printf("GTExpr <?>\n");
    } else if node.tag == TAG_GE {
        printf("GEExpr <?>\n");
    } else if node.tag == TAG_ASSIGN {
        printf("AssignExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_ADD {
        printf("AssignAddExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_SUB {
        printf("AssignSubtractExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_MULT {
        printf("AssignMultiplyExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_DIV {
        printf("AssignDivideExpr <?>\n");
    }  else if node.tag == TAG_ASSIGN_INT_DIV {
        printf("AssignIntDivideExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_MOD {
        printf("AssignModuloExpr <?>\n");
    } else if node.tag == TAG_SELECT_OP {
        printf("SelectOpExpr <?>\n");
    } else if node.tag == TAG_MEMBER {
        printf("MemberExpr <?>\n");
    }
    dump_indent = dump_indent + 1;
    dump(x.lhs);
    dump(x.rhs);
    dump_indent = dump_indent - 1;
}

# dump_index_expr
# -----------------------------------------------------------------------------
def dump_index_expr(node: ^Node) {
    let x: ^IndexExpr = unwrap(node^) as ^IndexExpr;
    printf("IndexExpr <?>\n");
    dump_indent = dump_indent + 1;
    dump(x.expression);
    dump(x.subscript);
    dump_indent = dump_indent - 1;
}

# dump_call_arg
# -----------------------------------------------------------------------------
def dump_call_arg(node: ^Node) {
    let x: ^Argument = unwrap(node^) as ^Argument;
    printf("Argument <?>");
    if not isnull(x.name) {
        let id: ^Ident = unwrap(x.name) as ^Ident;
        printf(" %s", id.name.data());
    }
    printf("\n");
    dump_indent = dump_indent + 1;
    dump(x.expression);
    dump_indent = dump_indent - 1;
}

# dump_call_expr
# -----------------------------------------------------------------------------
def dump_call_expr(node: ^Node) {
    let x: ^CallExpr = unwrap(node^) as ^CallExpr;
    printf("CallExpr <?>\n");
    dump_indent = dump_indent + 1;
    dump(x.expression);
    dump_nodes("Arguments", x.arguments);
    dump_indent = dump_indent - 1;
}

# dump_unary_expr
# -----------------------------------------------------------------------------
def dump_unary_expr(node: ^Node) {
    let x: ^UnaryExpr = unwrap(node^) as ^UnaryExpr;
    if node.tag == TAG_PROMOTE {
        printf("NumericPromoteExpr <?>\n");
    } else if node.tag == TAG_NUMERIC_NEGATE {
        printf("NumericNegateExpr <?>\n");
    } else if node.tag == TAG_LOGICAL_NEGATE {
        printf("LogicalNegateExpr <?>\n");
    }
    dump_indent = dump_indent + 1;
    dump(x.operand);
    dump_indent = dump_indent - 1;
}

# dump_module
# -----------------------------------------------------------------------------
def dump_module(node: ^Node) {
    let x: ^ModuleDecl = unwrap(node^) as ^ModuleDecl;
    printf("ModuleDecl <?> ");
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s", id.name.data());
    printf("\n");

    dump_indent = dump_indent + 1;
    dump_nodes("Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_unsafe_block
# -----------------------------------------------------------------------------
def dump_unsafe_block(node: ^Node) {
    let x: ^UnsafeBlock = unwrap(node^) as ^UnsafeBlock;
    printf("UnsafeBlock <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes("Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_block_expr
# -----------------------------------------------------------------------------
def dump_block_expr(node: ^Node) {
    let x: ^Block = unwrap(node^) as ^Block;
    printf("Block <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes("Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_ident
# -----------------------------------------------------------------------------
def dump_ident(node: ^Node) {
    let x: ^Ident = unwrap(node^) as ^Ident;
    printf("Ident <?> %s\n", x.name.data());
}

# dump_static_slot
# -----------------------------------------------------------------------------
def dump_static_slot(node: ^Node) {
    let x: ^StaticSlotDecl = unwrap(node^) as ^StaticSlotDecl;
    printf("StaticSlotDecl <?> ");
    if x.mutable { printf("mut "); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    dump(x.type_);
    if not isnull(x.initializer) { dump(x.initializer); }
    dump_indent = dump_indent - 1;
}

# dump_local_slot
# -----------------------------------------------------------------------------
def dump_local_slot(node: ^Node) {
    let x: ^LocalSlotDecl = unwrap(node^) as ^LocalSlotDecl;
    printf("LocalSlotDecl <?> ");
    if x.mutable { printf("mut "); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { dump(x.type_); }
    if not isnull(x.initializer) { dump(x.initializer); }
    dump_indent = dump_indent - 1;
}

# dump_nodes
# -----------------------------------------------------------------------------
def dump_nodes(name: str, &nodes: Nodes) {
    print_indent();
    printf("%s <?> \n", name);

    # Enumerate through each node.
    dump_indent = dump_indent + 1;
    let mut i: int = 0;
    while i as uint < nodes.size() {
        let node: Node = nodes.get(i);
        dump(node);
        i = i + 1;
    }
    dump_indent = dump_indent - 1;
}

# dump_select_expr
# -----------------------------------------------------------------------------
def dump_select_expr(node: ^Node) {
    let x: ^SelectExpr = unwrap(node^) as ^SelectExpr;
    printf("SelectExpr <?> \n");

    dump_indent = dump_indent + 1;
    dump_nodes("Branches", x.branches);
    dump_indent = dump_indent - 1;
}

# dump_select_branch
# -----------------------------------------------------------------------------
def dump_select_branch(node: ^Node) {
    let x: ^SelectBranch = unwrap(node^) as ^SelectBranch;
    printf("SelectBranch <?> \n");

    dump_indent = dump_indent + 1;
    if not isnull(x.condition) { dump(x.condition); }
    dump_nodes("Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_conditional_expr
# -----------------------------------------------------------------------------
def dump_conditional_expr(node: ^Node) {
    let x: ^ConditionalExpr = unwrap(node^) as ^ConditionalExpr;
    printf("ConditionalExpr <?> \n");

    dump_indent = dump_indent + 1;
    dump(x.condition);
    dump(x.lhs);
    dump(x.rhs);
    dump_indent = dump_indent - 1;
}

# dump_func_decl
# -----------------------------------------------------------------------------
def dump_func_decl(node: ^Node) {
    let x: ^FuncDecl = unwrap(node^) as ^FuncDecl;
    printf("FuncDecl <?> ");
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.return_type) { dump(x.return_type); }
    dump_nodes("Parameters", x.params);
    dump_nodes("Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_func_param
# -----------------------------------------------------------------------------
def dump_func_param(node: ^Node) {
    let x: ^FuncParam = unwrap(node^) as ^FuncParam;
    printf("FuncParam <?> ");
    if x.mutable { printf("mut "); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    dump(x.type_);
    if not isnull(x.default) { dump(x.default); }
    dump_indent = dump_indent - 1;
}

# dump_return_expr
# -----------------------------------------------------------------------------
def dump_return_expr(node: ^Node) {
    let x: ^ReturnExpr = unwrap(node^) as ^ReturnExpr;
    printf("ReturnExpr <?> \n");

    dump_indent = dump_indent + 1;
    if not isnull(x.expression) { dump(x.expression); }
    dump_indent = dump_indent - 1;
}

# dump_type_expr
# -----------------------------------------------------------------------------
def dump_type_expr(node: ^Node) {
    let x: ^TypeExpr = unwrap(node^) as ^TypeExpr;
    printf("TypeExpr <?> \n");

    dump_indent = dump_indent + 1;
    dump(x.expression);
    dump_indent = dump_indent - 1;
}

# dump_import
# -----------------------------------------------------------------------------
def dump_import(node: ^Node) {
    let x: ^Import = unwrap(node^) as ^Import;
    printf("Import <?> ");

    let mut i: int = 0;
    while i as uint < x.ids.size() {
        let node: Node = x.ids.get(i);
        let id: ^Ident = node.unwrap() as ^Ident;
        if i > 0 { printf("."); }
        printf("%s", id.name.data());
        i = i + 1;
    }

    printf("\n");
}
