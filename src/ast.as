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
let TAG_GLOBAL          : int = 49;             # Global
let TAG_ARRAY_EXPR      : int = 50;             # ArrayExpr
let TAG_TUPLE_EXPR      : int = 51;             # TupleExpr
# let TAG_RECORD_EXPR     : int = 52;             # RecordExpr
let TAG_TUPLE_EXPR_MEM  : int = 53;             # RecordExprMem
# let TAG_SEQ_EXPR        : int = 54;             # SequenceExpr
let TAG_STRUCT          : int = 55;             # Struct
let TAG_STRUCT_MEM      : int = 56;             # StructMem
# let TAG_STRUCT_SMEM     : int = 57;             # StructSMem
let TAG_POSTFIX_EXPR    : int = 58;             # PostfixExpr
let TAG_BITAND          : int = 59;             # BitAndExpr
let TAG_BITOR           : int = 60;             # BitOrExpr
let TAG_BITXOR          : int = 61;             # BitXorExpr
let TAG_BITNEG          : int = 62;             # BitNegExpr
let TAG_TYPE_PARAM      : int = 63;             # TypeParam
let TAG_CAST            : int = 64;             # CastExpr
let TAG_TYPE_BOX        : int = 65;             # TypeBox
let TAG_LOOP            : int = 66;             # Loop
let TAG_BREAK           : int = 67;             # Break
let TAG_CONTINUE        : int = 68;             # Continue
let TAG_POINTER_TYPE    : int = 69;             # PointerType
let TAG_ADDRESS_OF      : int = 70;             # AddressOfExpr
let TAG_DEREF           : int = 71;             # DerefExpr
let TAG_ARRAY_TYPE      : int = 72;             # ArrayType
let TAG_TUPLE_TYPE      : int = 73;             # TupleType
let TAG_TUPLE_TYPE_MEM  : int = 74;             # TupleTypeMem
let TAG_EXTERN_STATIC   : int = 75;             # ExternStaticSlot
let TAG_EXTERN_FUNC     : int = 76;             # ExternFunc

# AST node defintions
# -----------------------------------------------------------------------------

# Generic AST "node" that can store a node generically.
# NOTE: This is filthy polymorphism.
type Node { tag: int, data: ^void }

implement Node {
    def unwrap(&self) -> ^void { self.data; }
    def _set_tag(&mut self, tag: int) { self.tag = tag; }
}

# Generic collection of AST "nodes" that can store a
# heterogeneous linked-list of nodes.
type Nodes { mut elements: list.List }

def make_nodes() -> Nodes {
    let nodes: Nodes;
    nodes.elements = list.make_generic(_sizeof(TAG_NODE));
    nodes;
}

def new_nodes() -> ^Nodes {
    let node: Node = make(TAG_NODES);
    node.data as ^Nodes;
}

implement Nodes {

    def dispose(&mut self) { self.elements.dispose(); }

    def size(&self) -> uint { self.elements.size; }

    def push(&mut self, el: Node) {
        # Ensure our `element_size` is set correctly.
        self.elements.element_size = _sizeof(TAG_NODE);

        # Push the node onto our list.
        self.elements.push(&el as ^void);
    }

    def pop(&mut self) -> Node {
        let ptr: ^Node = self.elements.at(-1) as ^Node;
        let val: Node = ptr^;
        self.elements.erase(-1);
        val;
    }

    def get(&self, i: int) -> Node {
        let ptr: ^Node = self.elements.at(i) as ^Node;
        ptr^;
    }

    def clear(&mut self) { self.elements.clear(); }

}

# Expression type for integral literals with a distinct base like "2321".
type IntegerExpr { base: int8, mut text: string.String }

# Expression type for float literals.
type FloatExpr { mut text: string.String }

# Expression type for a boolean literal
type BooleanExpr { value: bool }

# "Generic" binary expression type.
type BinaryExpr { mut lhs: Node, mut rhs: Node }

# Pointer type.
type PointerType { mutable: bool, pointee: Node }

# Cast expression.
type CastExpr { operand: Node, type_: Node }

# Index expression type.
type IndexExpr { expression: Node, subscript: Node }

# Conditional expression.
type ConditionalExpr { lhs: Node, rhs: Node, condition: Node }

# "Generic" unary expression type.
type UnaryExpr { operand: Node }

# Address of expression
type AddressOfExpr { operand: Node, mutable: bool }

# Module declaration that contains a sequence of nodes.
type ModuleDecl { mut id: Node, mut nodes: Nodes }

# Unsafe block.
type UnsafeBlock { mut nodes: Nodes }

# Block.
type Block { mut nodes: Nodes }

# ArrayExpr.
type ArrayExpr { mut nodes: Nodes }

# PostfixExpr
type PostfixExpr { operand: Node, expression: Node }

# RecordExpr.
type RecordExpr { mut nodes: Nodes }

# SequenceExpr
type SequenceExpr { mut nodes: Nodes }

# RecordExprMem
type RecordExprMem { mut id: Node, expression: Node }

# TupleExpr.
type TupleExpr { mut nodes: Nodes }

# TupleExprMem
type TupleExprMem { mut id: Node, expression: Node }

# TupleType.
type TupleType { mut nodes: Nodes }

# TupleTypeMem
type TupleTypeMem { mut id: Node, type_: Node }

# Return expression.
type ReturnExpr { expression: Node }

# Type expression.
type TypeExpr { expression: Node }

# Selection expression.
type SelectExpr { mut branches: Nodes }

# Selection branch.
type SelectBranch { condition: Node, block: Node }

# Loop
type Loop { condition: Node, block: Node }

# Function declaration.
type FuncDecl {
    mut id: Node,
    return_type: Node,
    mut type_params: Nodes,
    mut params: Nodes,
    block: Node
}

# External function declaration.
type ExternFunc {
    mut id: Node,
    return_type: Node,
    mut params: Nodes
}

# Function parameter.
type FuncParam {
    mut id: Node,
    type_: Node,
    mutable: bool,
    default: Node
}

# Static slot declaration.
type StaticSlotDecl {
    mut id: Node,
    type_: Node,
    mutable: bool,
    initializer: Node
}

# External static slot.
type ExternStaticSlot {
    mut id: Node,
    type_: Node,
    mutable: bool
}

# Local slot declaration.
type LocalSlotDecl {
    mut id: Node,
    type_: Node,
    mutable: bool,
    initializer: Node
}

# TypeParam
type TypeParam { mut id: Node, default: Node, variadic: bool, bounds: Node }

# Struct
type Struct { mut nodes: Nodes, mut id: Node, mut type_params: Nodes }

# StructMem
type StructMem { mut id: Node, type_: Node, initializer: Node }

# Call expression
type CallExpr { expression: Node, mut arguments: Nodes }

# Call arguments
type Argument { expression: Node, mut name: Node }

# Identifier.
type Ident { mut name: string.String }

# Pointer type.
type PointerType { mutable: bool, mut pointee: Node }

# Array type.
type ArrayType { mut element: Node, mut size: Node }

# Import
# ids: ordered collection of the identifiers that make up the `x.y.z` name
#      to import.
type Import { mut ids: Nodes }

# Global
type Empty { }

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
           or tag == TAG_BITOR
           or tag == TAG_BITXOR
           or tag == TAG_BITAND
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
           or tag == TAG_BITNEG
           or tag == TAG_DEREF
           or tag == TAG_LOGICAL_NEGATE {
        let tmp: UnaryExpr;
        ((&tmp + 1) - &tmp);
    }
    else if tag == TAG_MODULE  { let tmp: ModuleDecl; ((&tmp + 1) - &tmp); }
    else if tag == TAG_ADDRESS_OF  { let tmp: AddressOfExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_UNSAFE  { let tmp: UnsafeBlock; ((&tmp + 1) - &tmp); }
    else if tag == TAG_BLOCK   { let tmp: Block; ((&tmp + 1) - &tmp); }
    else if tag == TAG_ARRAY_EXPR { let tmp: ArrayExpr; ((&tmp + 1) - &tmp); }
    # else if tag == TAG_SEQ_EXPR  { let tmp: SequenceExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_TUPLE_EXPR { let tmp: TupleExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_TUPLE_TYPE { let tmp: TupleType; ((&tmp + 1) - &tmp); }
    else if tag == TAG_NODE    { let tmp: Node; ((&tmp + 1) - &tmp); }
    else if tag == TAG_NODES   { let tmp: Nodes; ((&tmp + 1) - &tmp); }
    else if tag == TAG_BOOLEAN { let tmp: BooleanExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_IDENT   { let tmp: Ident; ((&tmp + 1) - &tmp); }
    else if tag == TAG_POINTER_TYPE   { let tmp: PointerType; ((&tmp + 1) - &tmp); }
    else if tag == TAG_ARRAY_TYPE     { let tmp: ArrayType; ((&tmp + 1) - &tmp); }
    else if tag == TAG_IMPORT  { let tmp: Import; ((&tmp + 1) - &tmp); }
    else if tag == TAG_INDEX   { let tmp: IndexExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_CAST    { let tmp: CastExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_CALL    { let tmp: CallExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_LOOP    { let tmp: Loop; ((&tmp + 1) - &tmp); }
    else if tag == TAG_CALL_ARG{ let tmp: Argument; ((&tmp + 1) - &tmp); }
    else if tag == TAG_TYPE_PARAM{ let tmp: TypeParam; ((&tmp + 1) - &tmp); }
    else if tag == TAG_EXTERN_STATIC { let tmp: ExternStaticSlot; ((&tmp + 1) - &tmp); }
    else if tag == TAG_EXTERN_FUNC { let tmp: ExternFunc; ((&tmp + 1) - &tmp); }
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
    } else if tag == TAG_GLOBAL
           or tag == TAG_BREAK
           or tag == TAG_CONTINUE {
        let tmp: Empty;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_TUPLE_EXPR_MEM {
        let tmp: TupleExprMem;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_TUPLE_TYPE_MEM {
        let tmp: TupleTypeMem;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_STRUCT {
        let tmp: Struct;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_STRUCT_MEM {
        let tmp: StructMem;
        ((&tmp + 1) - &tmp);
    } else if tag == TAG_POSTFIX_EXPR {
        let tmp: PostfixExpr;
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
    node.data = libc.calloc(_sizeof(tag) as int64, 1);

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
        dump_table[TAG_BITNEG] = dump_unary_expr;
        dump_table[TAG_NUMERIC_NEGATE] = dump_unary_expr;
        dump_table[TAG_LOGICAL_NEGATE] = dump_unary_expr;
        dump_table[TAG_DEREF] = dump_unary_expr;
        dump_table[TAG_ADDRESS_OF] = dump_address_of;
        dump_table[TAG_LOGICAL_AND] = dump_binop_expr;
        dump_table[TAG_LOGICAL_OR] = dump_binop_expr;
        dump_table[TAG_EQ] = dump_binop_expr;
        dump_table[TAG_NE] = dump_binop_expr;
        dump_table[TAG_LT] = dump_binop_expr;
        dump_table[TAG_LE] = dump_binop_expr;
        dump_table[TAG_GT] = dump_binop_expr;
        dump_table[TAG_GE] = dump_binop_expr;
        dump_table[TAG_BITOR] = dump_binop_expr;
        dump_table[TAG_BITAND] = dump_binop_expr;
        dump_table[TAG_BITXOR] = dump_binop_expr;
        dump_table[TAG_ASSIGN] = dump_binop_expr;
        dump_table[TAG_ASSIGN_ADD] = dump_binop_expr;
        dump_table[TAG_ASSIGN_SUB] = dump_binop_expr;
        dump_table[TAG_ASSIGN_MULT] = dump_binop_expr;
        dump_table[TAG_ASSIGN_DIV] = dump_binop_expr;
        dump_table[TAG_ASSIGN_INT_DIV] = dump_binop_expr;
        dump_table[TAG_ASSIGN_MOD] = dump_binop_expr;
        dump_table[TAG_SELECT_OP] = dump_binop_expr;
        dump_table[TAG_STATIC_SLOT] = dump_static_slot;
        dump_table[TAG_EXTERN_STATIC] = dump_extern_static_slot;
        dump_table[TAG_EXTERN_FUNC] = dump_extern_func;
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
        dump_table[TAG_CAST] = dump_cast_expr;
        dump_table[TAG_CALL] = dump_call_expr;
        dump_table[TAG_CALL_ARG] = dump_call_arg;
        dump_table[TAG_TYPE_EXPR] = dump_type_expr;
        dump_table[TAG_TYPE_BOX] = dump_type_box;
        dump_table[TAG_GLOBAL] = dump_global;
        dump_table[TAG_BREAK] = dump_break;
        dump_table[TAG_CONTINUE] = dump_continue;
        dump_table[TAG_ARRAY_EXPR] = dump_array_expr;
        # dump_table[TAG_SEQ_EXPR] = dump_seq_expr;
        dump_table[TAG_TUPLE_EXPR] = dump_tuple_expr;
        dump_table[TAG_TUPLE_TYPE] = dump_tuple_type;
        # dump_table[TAG_RECORD_EXPR] = dump_record_expr;
        dump_table[TAG_TUPLE_EXPR_MEM] = dump_tuple_expr_mem;
        dump_table[TAG_TUPLE_TYPE_MEM] = dump_tuple_type_mem;
        dump_table[TAG_STRUCT] = dump_struct;
        dump_table[TAG_STRUCT_MEM] = dump_struct_mem;
        dump_table[TAG_POSTFIX_EXPR] = dump_postfix_expr;
        dump_table[TAG_TYPE_PARAM] = dump_type_param;
        dump_table[TAG_LOOP] = dump_loop;
        dump_table[TAG_POINTER_TYPE] = dump_pointer_type;
        dump_table[TAG_INDEX] = dump_index_expr;
        dump_table[TAG_ARRAY_TYPE] = dump_array_type;
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
    } else if node.tag == TAG_BITOR {
        printf("BitOrExpr <?>\n");
    } else if node.tag == TAG_BITXOR {
        printf("BitXorExpr <?>\n");
    } else if node.tag == TAG_BITAND {
        printf("BitAndExpr <?>\n");
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

# dump_cast_expr
# -----------------------------------------------------------------------------
def dump_cast_expr(node: ^Node) {
    let x: ^CastExpr = unwrap(node^) as ^CastExpr;
    printf("CastExpr <?>\n");
    dump_indent = dump_indent + 1;
    dump(x.operand);
    dump(x.type_);
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
    } else if node.tag == TAG_BITNEG {
        printf("BitNegExpr <?>\n");
    } else if node.tag == TAG_DEREF {
        printf("DerefExpr <?>\n");
    }
    dump_indent = dump_indent + 1;
    dump(x.operand);
    dump_indent = dump_indent - 1;
}

# dump_address_of
# -----------------------------------------------------------------------------
def dump_address_of(node: ^Node) {
    let x: ^AddressOfExpr = unwrap(node^) as ^AddressOfExpr;
    printf("AddressOfExpr <?>");
    if x.mutable { printf(" mut"); }
    printf("\n");

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

# dump_seq_expr
# -----------------------------------------------------------------------------
def dump_seq_expr(node: ^Node) {
    let x: ^SequenceExpr = unwrap(node^) as ^SequenceExpr;
    printf("SequenceExpr <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes("Members", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_array_expr
# -----------------------------------------------------------------------------
def dump_array_expr(node: ^Node) {
    let x: ^ArrayExpr = unwrap(node^) as ^ArrayExpr;
    printf("ArrayExpr <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes("Elements", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_tuple_expr_mem
# -----------------------------------------------------------------------------
def dump_tuple_expr_mem(node: ^Node) {
    let x: ^TupleExprMem = unwrap(node^) as ^TupleExprMem;
    printf("TupleExprMem <?>");
    if not isnull(x.id)
    {
        let id: ^Ident = unwrap(x.id) as ^Ident;
        printf(" %s\n", id.name.data());
    }
    else
    {
        printf("\n");
    }

    dump_indent = dump_indent + 1;
    dump(x.expression);
    dump_indent = dump_indent - 1;
}

# dump_tuple_type_mem
# -----------------------------------------------------------------------------
def dump_tuple_type_mem(node: ^Node) {
    let x: ^TupleTypeMem = unwrap(node^) as ^TupleTypeMem;
    printf("TupleTypeMem <?>");
    if not isnull(x.id)
    {
        let id: ^Ident = unwrap(x.id) as ^Ident;
        printf(" %s\n", id.name.data());
    }
    else
    {
        printf("\n");
    }

    dump_indent = dump_indent + 1;
    dump(x.type_);
    dump_indent = dump_indent - 1;
}

# dump_postfix_expr
# -----------------------------------------------------------------------------
def dump_postfix_expr(node: ^Node) {
    let x: ^PostfixExpr = unwrap(node^) as ^PostfixExpr;
    printf("PostfixExpr <?>\n");

    dump_indent = dump_indent + 1;
    dump(x.operand);
    dump(x.expression);
    dump_indent = dump_indent - 1;
}

# dump_struct
# -----------------------------------------------------------------------------
def dump_struct(node: ^Node) {
    let x: ^Struct = unwrap(node^) as ^Struct;
    printf("Struct <?> ");
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s", id.name.data());
    printf("\n");

    dump_indent = dump_indent + 1;
    dump_nodes("Type Parameters", x.type_params);
    dump_nodes("Members", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_type_param
# -----------------------------------------------------------------------------
def dump_type_param(node: ^Node) {
    let x: ^TypeParam = unwrap(node^) as ^TypeParam;
    printf("TypeParam <?> ");
    if x.variadic { printf("variadic "); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s", id.name.data());
    printf("\n");

    dump_indent = dump_indent + 1;
    if not isnull(x.default) { dump(x.default); }
    if not isnull(x.bounds)  { dump(x.bounds);  }
    dump_indent = dump_indent - 1;
}

# dump_struct_mem
# -----------------------------------------------------------------------------
def dump_struct_mem(node: ^Node) {
    let x: ^StructMem = unwrap(node^) as ^StructMem;
    printf("StructMem <?> ");
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    dump(x.type_);
    if not isnull(x.initializer) { dump(x.initializer); }
    dump_indent = dump_indent - 1;
}

# dump_tuple_expr
# -----------------------------------------------------------------------------
def dump_tuple_expr(node: ^Node) {
    let x: ^TupleExpr = unwrap(node^) as ^TupleExpr;
    printf("TupleExpr <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes("Elements", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_tuple_type
# -----------------------------------------------------------------------------
def dump_tuple_type(node: ^Node) {
    let x: ^TupleType = unwrap(node^) as ^TupleType;
    printf("TupleType <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes("Elements", x.nodes);
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
    if not isnull(x.type_) { dump(x.type_); }
    if not isnull(x.initializer) { dump(x.initializer); }
    dump_indent = dump_indent - 1;
}

# dump_extern_static_slot
# -----------------------------------------------------------------------------
def dump_extern_static_slot(node: ^Node) {
    let x: ^ExternStaticSlot = unwrap(node^) as ^ExternStaticSlot;
    printf("ExternStaticSlot <?> ");
    if x.mutable { printf("mut "); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { dump(x.type_); }
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
    dump(x.block);
    dump_indent = dump_indent - 1;
}

# dump_loop
# -----------------------------------------------------------------------------
def dump_loop(node: ^Node) {
    let x: ^Loop = unwrap(node^) as ^Loop;
    printf("Loop <?> \n");

    dump_indent = dump_indent + 1;
    if not isnull(x.condition) { dump(x.condition); }
    dump(x.block);
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

# dump_extern_func
# -----------------------------------------------------------------------------
def dump_extern_func(node: ^Node) {
    let x: ^ExternFunc = unwrap(node^) as ^ExternFunc;
    printf("ExternFunc <?> ");
    let id: ^Ident = unwrap(x.id) as ^Ident;
    printf("%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.return_type) { dump(x.return_type); }
    dump_nodes("Parameters", x.params);
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
    dump_nodes("Type Parameters", x.type_params);
    dump_nodes("Parameters", x.params);
    dump(x.block);
    dump_indent = dump_indent - 1;
}

# dump_func_param
# -----------------------------------------------------------------------------
def dump_func_param(node: ^Node) {
    let x: ^FuncParam = unwrap(node^) as ^FuncParam;
    printf("FuncParam <?>");
    if x.mutable { printf(" mut"); }
    if not isnull(x.id) {
        let id: ^Ident = unwrap(x.id) as ^Ident;
        printf(" %s\n", id.name.data());
    } else {
        printf("\n");
    }

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { dump(x.type_); }
    if not isnull(x.default) { dump(x.default); }
    dump_indent = dump_indent - 1;
}

# dump_pointer_type
# -----------------------------------------------------------------------------
def dump_pointer_type(node: ^Node) {
    let x: ^PointerType = unwrap(node^) as ^PointerType;
    printf("PointerType <?>");
    if x.mutable { printf(" mut"); }
    printf("\n");

    dump_indent = dump_indent + 1;
    dump(x.pointee);
    dump_indent = dump_indent - 1;
}

# dump_array_type
# -----------------------------------------------------------------------------
def dump_array_type(node: ^Node) {
    let x: ^ArrayType = unwrap(node^) as ^ArrayType;
    printf("ArrayType <?>\n");

    dump_indent = dump_indent + 1;
    dump(x.size);
    dump(x.element);
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

# dump_type_box
# -----------------------------------------------------------------------------
def dump_type_box(node: ^Node) {
    printf("TypeBox <?> \n");
}

# dump_global
# -----------------------------------------------------------------------------
def dump_global(node: ^Node) {
    printf("Global <?> \n");
}

# dump_break
# -----------------------------------------------------------------------------
def dump_break(node: ^Node) {
    printf("Break <?> \n");
}

# dump_continue
# -----------------------------------------------------------------------------
def dump_continue(node: ^Node) {
    printf("Continue <?> \n");
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
