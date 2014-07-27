import libc;
import list;
import types;
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
let TAG_SLOT            : int = 22;             # SlotDecl
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
let TAG_STRING          : int = 77;             # StringExpr
let TAG_IMPLEMENT       : int = 78;             # Implement
let TAG_SELF            : int = 79;             # Self
let TAG_DELEGATE        : int = 80;             # Delegate
let TAG_SIZEOF          : int = 81;             # SizeOf

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

# Expression type for a string literal
type StringExpr { mut text: string.String }

implement StringExpr {

    def count(mut self) -> uint {
        let mut l: list.List = self.unescape();
        let n: uint = l.size;
        l.dispose();
        return n;
    }

    def unescape(mut self) -> list.List {
        # Unescape the textual content of the string into a list of bytes.
        # Iterate and construct bytes from the string.
        let mut chars: list.List = self.text._data;
        let mut bytes: list.List = list.make(types.I8);
        bytes.reserve(1);
        let mut buffer: list.List = list.make(types.I8);
        let mut i: int = 0;
        let mut in_escape: bool = false;
        let mut in_utf8_escape: bool = false;
        while i as uint < chars.size {
            let c: int8 = chars.at_i8(i);
            i = i + 1;

            if in_utf8_escape {
                # Get more characters
                if buffer.size < 2 { buffer.push_i8(c); }
                if buffer.size == 2 {
                    # We've gotten exactly 2 more characters.
                    # Parse a hexadecimal from the text.
                    let data: ^int8 = buffer.elements;
                    (data + 2)^ = 0;
                    let val: int64 = libc.strtol(data, 0 as ^^int8, 16);

                    # Write out this single byte into bytes.
                    bytes.push_i8(val as int8);

                    # Clear the temp buffer.
                    buffer.clear();

                    # No longer in a UTF-8 escape sequence.
                    in_utf8_escape = false;
                }
                void;
            } else if in_escape {
                # Check what do on the control character.
                if      c == (('\\' as char) as int8) { bytes.push_i8(('\\' as char) as int8); }
                else if c == (('n' as char) as int8)  { bytes.push_i8(('\n' as char) as int8); }
                else if c == (('r' as char) as int8)  { bytes.push_i8(('\r' as char) as int8); }
                else if c == (('f' as char) as int8)  { bytes.push_i8(('\f' as char) as int8); }
                else if c == (('a' as char) as int8)  { bytes.push_i8(('\a' as char) as int8); }
                else if c == (('b' as char) as int8)  { bytes.push_i8(('\b' as char) as int8); }
                else if c == (('v' as char) as int8)  { bytes.push_i8(('\v' as char) as int8); }
                else if c == (('t' as char) as int8)  { bytes.push_i8(('\t' as char) as int8); }
                else if c == (('"' as char) as int8)  { bytes.push_i8(('\"' as char) as int8); }
                else if c == (('\'' as char) as int8) { bytes.push_i8(('\'' as char) as int8); }
                else if c == (('x' as char) as int8)  { in_utf8_escape = true; }
                # else if (c == 'u')  { in_utf16_escape = true; }
                # else if (c == 'U')  { in_utf32_escape = true; }

                # No longer in an escape sequence.
                in_escape = false;
                void;
            } else {
                if c == (('\\' as char) as int8) {
                    # Mark that we are in an escape sequence.
                    in_escape = true;
                    void;
                } else {
                    # Push the character.
                    bytes.push_i8(c);
                }
            }
        }

        # Dispose.
        buffer.dispose();

        # Return the bytes.
        bytes;
    }

}

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
    mut params: Nodes,
    mut type_params: Nodes,
    instance: bool,
    mutable: bool,
    block: Node
}

# Function delegate
type Delegate {
    mut id: Node,
    return_type: Node,
    mut params: Nodes
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
    default: Node,
    variadic: bool
}

# External static slot.
type ExternStaticSlot {
    mut id: Node,
    type_: Node,
    mutable: bool
}

type SizeOf {
    type_: Node
}

# Local slot declaration.
type SlotDecl {
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

# Implement Block
type Implement { mut type_: Node, mut methods: Nodes }

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
    } else if tag == TAG_STRING {
        let tmp: StringExpr;
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
    else if tag == TAG_SIZEOF  { let tmp: SizeOf; ((&tmp + 1) - &tmp); }
    else if tag == TAG_ADDRESS_OF  { let tmp: AddressOfExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_UNSAFE  { let tmp: UnsafeBlock; ((&tmp + 1) - &tmp); }
    else if tag == TAG_BLOCK   { let tmp: Block; ((&tmp + 1) - &tmp); }
    else if tag == TAG_ARRAY_EXPR { let tmp: ArrayExpr; ((&tmp + 1) - &tmp); }
    # else if tag == TAG_SEQ_EXPR  { let tmp: SequenceExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_TUPLE_EXPR { let tmp: TupleExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_TUPLE_TYPE { let tmp: TupleType; ((&tmp + 1) - &tmp); }
    else if tag == TAG_IMPLEMENT { let tmp: Implement; ((&tmp + 1) - &tmp); }
    else if tag == TAG_NODE    { let tmp: Node; ((&tmp + 1) - &tmp); }
    else if tag == TAG_NODES   { let tmp: Nodes; ((&tmp + 1) - &tmp); }
    else if tag == TAG_BOOLEAN { let tmp: BooleanExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_IDENT   { let tmp: Ident; ((&tmp + 1) - &tmp); }
    else if tag == TAG_POINTER_TYPE   { let tmp: PointerType; ((&tmp + 1) - &tmp); }
    else if tag == TAG_ARRAY_TYPE     { let tmp: ArrayType; ((&tmp + 1) - &tmp); }
    else if tag == TAG_IMPORT  { let tmp: Import; ((&tmp + 1) - &tmp); }
    else if tag == TAG_INDEX   { let tmp: IndexExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_DELEGATE  { let tmp: Delegate; ((&tmp + 1) - &tmp); }
    else if tag == TAG_CAST    { let tmp: CastExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_CALL    { let tmp: CallExpr; ((&tmp + 1) - &tmp); }
    else if tag == TAG_LOOP    { let tmp: Loop; ((&tmp + 1) - &tmp); }
    else if tag == TAG_CALL_ARG{ let tmp: Argument; ((&tmp + 1) - &tmp); }
    else if tag == TAG_TYPE_PARAM{ let tmp: TypeParam; ((&tmp + 1) - &tmp); }
    else if tag == TAG_EXTERN_STATIC { let tmp: ExternStaticSlot; ((&tmp + 1) - &tmp); }
    else if tag == TAG_EXTERN_FUNC { let tmp: ExternFunc; ((&tmp + 1) - &tmp); }
    else if tag == TAG_SLOT {
        let tmp: SlotDecl;
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
           or tag == TAG_SELF
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
let mut dump_table: def(^libc._IO_FILE, ^Node)[100];
let mut dump_indent: int = 0;
let mut dump_initialized: bool = false;
def dump(&node: Node) { fdump(libc.stdout, node); }
def fdump(stream: ^libc._IO_FILE, &node: Node) {
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
        dump_table[TAG_SIZEOF] = dump_sizeof;
        dump_table[TAG_ASSIGN] = dump_binop_expr;
        dump_table[TAG_ASSIGN_ADD] = dump_binop_expr;
        dump_table[TAG_ASSIGN_SUB] = dump_binop_expr;
        dump_table[TAG_ASSIGN_MULT] = dump_binop_expr;
        dump_table[TAG_ASSIGN_DIV] = dump_binop_expr;
        dump_table[TAG_ASSIGN_INT_DIV] = dump_binop_expr;
        dump_table[TAG_ASSIGN_MOD] = dump_binop_expr;
        dump_table[TAG_SELECT_OP] = dump_binop_expr;
        dump_table[TAG_EXTERN_STATIC] = dump_extern_static_slot;
        dump_table[TAG_EXTERN_FUNC] = dump_extern_func;
        dump_table[TAG_SLOT] = dump_slot;
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
        dump_table[TAG_SELF] = dump_self;
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
        dump_table[TAG_STRING] = dump_string_expr;
        dump_table[TAG_IMPORT] = dump_import;
        dump_table[TAG_IMPLEMENT] = dump_implement;
        dump_table[TAG_DELEGATE] = dump_delegate;
        dump_initialized = true;
    }

    print_indent(stream);
    let dump_fn: def(^libc._IO_FILE, ^Node) = dump_table[node.tag];
    let node_ptr: ^Node = &node;
    dump_fn(stream, node_ptr);
}

# print_indent
# -----------------------------------------------------------------------------
def print_indent(stream: ^libc._IO_FILE) {
    let mut dump_indent_i: int = 0;
    while dump_indent > dump_indent_i {
        libc.fprintf(stream, "  " as ^int8);
        dump_indent_i = dump_indent_i + 1;
    }
}

# dump_boolean_expr
# -----------------------------------------------------------------------------
def dump_boolean_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^BooleanExpr = unwrap(node^) as ^BooleanExpr;
    libc.fprintf(stream, "BooleanExpr <?> %s\n" as ^int8, "true" if x.value else "false");
}

# dump_integer_expr
# -----------------------------------------------------------------------------
def dump_integer_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^IntegerExpr = unwrap(node^) as ^IntegerExpr;
    libc.fprintf(stream, "IntegerExpr <?> %s (%d)\n" as ^int8, x.text.data(), x.base);
}

# dump_float_expr
# -----------------------------------------------------------------------------
def dump_float_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^FloatExpr = unwrap(node^) as ^FloatExpr;
    libc.fprintf(stream, "FloatExpr <?> %s\n" as ^int8, x.text.data());
}

# dump_string_expr
# -----------------------------------------------------------------------------
def dump_string_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^StringExpr = unwrap(node^) as ^StringExpr;
    libc.fprintf(stream, "StringExpr <?> %s\n" as ^int8, x.text.data());
}

# dump_binop_expr
# -----------------------------------------------------------------------------
def dump_binop_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^BinaryExpr = unwrap(node^) as ^BinaryExpr;
    if node.tag == TAG_ADD {
        libc.fprintf(stream, "AddExpr <?>\n" as ^int8);
    } else if node.tag == TAG_SUBTRACT {
        libc.fprintf(stream, "SubtractExpr <?>\n" as ^int8);
    } else if node.tag == TAG_MULTIPLY {
        libc.fprintf(stream, "MultiplyExpr <?>\n" as ^int8);
    } else if node.tag == TAG_DIVIDE {
        libc.fprintf(stream, "DivideExpr <?>\n" as ^int8);
    }  else if node.tag == TAG_INTEGER_DIVIDE {
        libc.fprintf(stream, "IntDivideExpr <?>\n" as ^int8);
    } else if node.tag == TAG_MODULO {
        libc.fprintf(stream, "ModuloExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LOGICAL_AND {
        libc.fprintf(stream, "LogicalAndExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LOGICAL_OR {
        libc.fprintf(stream, "LogicalOrExpr <?>\n" as ^int8);
    } else if node.tag == TAG_EQ {
        libc.fprintf(stream, "EQExpr <?>\n" as ^int8);
    } else if node.tag == TAG_NE {
        libc.fprintf(stream, "NEExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LT {
        libc.fprintf(stream, "LTExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LE {
        libc.fprintf(stream, "LEExpr <?>\n" as ^int8);
    } else if node.tag == TAG_GT {
        libc.fprintf(stream, "GTExpr <?>\n" as ^int8);
    } else if node.tag == TAG_GE {
        libc.fprintf(stream, "GEExpr <?>\n" as ^int8);
    } else if node.tag == TAG_ASSIGN {
        libc.fprintf(stream, "AssignExpr <?>\n" as ^int8);
    } else if node.tag == TAG_ASSIGN_ADD {
        libc.fprintf(stream, "AssignAddExpr <?>\n" as ^int8);
    } else if node.tag == TAG_ASSIGN_SUB {
        libc.fprintf(stream, "AssignSubtractExpr <?>\n" as ^int8);
    } else if node.tag == TAG_ASSIGN_MULT {
        libc.fprintf(stream, "AssignMultiplyExpr <?>\n" as ^int8);
    } else if node.tag == TAG_ASSIGN_DIV {
        libc.fprintf(stream, "AssignDivideExpr <?>\n" as ^int8);
    }  else if node.tag == TAG_ASSIGN_INT_DIV {
        libc.fprintf(stream, "AssignIntDivideExpr <?>\n" as ^int8);
    } else if node.tag == TAG_ASSIGN_MOD {
        libc.fprintf(stream, "AssignModuloExpr <?>\n" as ^int8);
    } else if node.tag == TAG_SELECT_OP {
        libc.fprintf(stream, "SelectOpExpr <?>\n" as ^int8);
    } else if node.tag == TAG_MEMBER {
        libc.fprintf(stream, "MemberExpr <?>\n" as ^int8);
    } else if node.tag == TAG_BITOR {
        libc.fprintf(stream, "BitOrExpr <?>\n" as ^int8);
    } else if node.tag == TAG_BITXOR {
        libc.fprintf(stream, "BitXorExpr <?>\n" as ^int8);
    } else if node.tag == TAG_BITAND {
        libc.fprintf(stream, "BitAndExpr <?>\n" as ^int8);
    }
    dump_indent = dump_indent + 1;
    fdump(stream, x.lhs);
    fdump(stream, x.rhs);
    dump_indent = dump_indent - 1;
}

# dump_index_expr
# -----------------------------------------------------------------------------
def dump_index_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^IndexExpr = unwrap(node^) as ^IndexExpr;
    libc.fprintf(stream, "IndexExpr <?>\n" as ^int8);
    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    fdump(stream, x.subscript);
    dump_indent = dump_indent - 1;
}

# dump_cast_expr
# -----------------------------------------------------------------------------
def dump_cast_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^CastExpr = unwrap(node^) as ^CastExpr;
    libc.fprintf(stream, "CastExpr <?>\n" as ^int8);
    dump_indent = dump_indent + 1;
    fdump(stream, x.operand);
    fdump(stream, x.type_);
    dump_indent = dump_indent - 1;
}

# dump_call_arg
# -----------------------------------------------------------------------------
def dump_call_arg(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^Argument = unwrap(node^) as ^Argument;
    libc.fprintf(stream, "Argument <?>" as ^int8);
    if not isnull(x.name) {
        let id: ^Ident = unwrap(x.name) as ^Ident;
        libc.fprintf(stream, " %s" as ^int8, id.name.data());
    }
    libc.fprintf(stream, "\n" as ^int8);
    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    dump_indent = dump_indent - 1;
}

# dump_call_expr
# -----------------------------------------------------------------------------
def dump_call_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^CallExpr = unwrap(node^) as ^CallExpr;
    libc.fprintf(stream, "CallExpr <?>\n" as ^int8);
    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    dump_nodes(stream, "Arguments", x.arguments);
    dump_indent = dump_indent - 1;
}

# dump_unary_expr
# -----------------------------------------------------------------------------
def dump_unary_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^UnaryExpr = unwrap(node^) as ^UnaryExpr;
    if node.tag == TAG_PROMOTE {
        libc.fprintf(stream, "NumericPromoteExpr <?>\n" as ^int8);
    } else if node.tag == TAG_NUMERIC_NEGATE {
        libc.fprintf(stream, "NumericNegateExpr <?>\n" as ^int8);
    } else if node.tag == TAG_LOGICAL_NEGATE {
        libc.fprintf(stream, "LogicalNegateExpr <?>\n" as ^int8);
    } else if node.tag == TAG_BITNEG {
        libc.fprintf(stream, "BitNegExpr <?>\n" as ^int8);
    } else if node.tag == TAG_DEREF {
        libc.fprintf(stream, "DerefExpr <?>\n" as ^int8);
    }
    dump_indent = dump_indent + 1;
    fdump(stream, x.operand);
    dump_indent = dump_indent - 1;
}

# dump_address_of
# -----------------------------------------------------------------------------
def dump_address_of(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^AddressOfExpr = unwrap(node^) as ^AddressOfExpr;
    libc.fprintf(stream, "AddressOfExpr <?>" as ^int8);
    if x.mutable { libc.fprintf(stream, " mut" as ^int8); }
    libc.fprintf(stream, "\n" as ^int8);

    dump_indent = dump_indent + 1;
    fdump(stream, x.operand);
    dump_indent = dump_indent - 1;
}

# dump_module
# -----------------------------------------------------------------------------
def dump_module(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^ModuleDecl = unwrap(node^) as ^ModuleDecl;
    libc.fprintf(stream, "ModuleDecl <?> " as ^int8);
    let id: ^Ident = unwrap(x.id) as ^Ident;
    libc.fprintf(stream, "%s" as ^int8, id.name.data());
    libc.fprintf(stream, "\n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_unsafe_block
# -----------------------------------------------------------------------------
def dump_unsafe_block(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^UnsafeBlock = unwrap(node^) as ^UnsafeBlock;
    libc.fprintf(stream, "UnsafeBlock <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_block_expr
# -----------------------------------------------------------------------------
def dump_block_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^Block = unwrap(node^) as ^Block;
    libc.fprintf(stream, "Block <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_seq_expr
# -----------------------------------------------------------------------------
def dump_seq_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^SequenceExpr = unwrap(node^) as ^SequenceExpr;
    libc.fprintf(stream, "SequenceExpr <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Members", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_array_expr
# -----------------------------------------------------------------------------
def dump_array_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^ArrayExpr = unwrap(node^) as ^ArrayExpr;
    libc.fprintf(stream, "ArrayExpr <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Elements", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_tuple_expr_mem
# -----------------------------------------------------------------------------
def dump_tuple_expr_mem(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^TupleExprMem = unwrap(node^) as ^TupleExprMem;
    libc.fprintf(stream, "TupleExprMem <?>" as ^int8);
    if not isnull(x.id)
    {
        let id: ^Ident = unwrap(x.id) as ^Ident;
        libc.fprintf(stream, " %s\n" as ^int8, id.name.data());
    }
    else
    {
        libc.fprintf(stream, "\n" as ^int8);
    }

    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    dump_indent = dump_indent - 1;
}

# dump_tuple_type_mem
# -----------------------------------------------------------------------------
def dump_tuple_type_mem(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^TupleTypeMem = unwrap(node^) as ^TupleTypeMem;
    libc.fprintf(stream, "TupleTypeMem <?>" as ^int8);
    if not isnull(x.id)
    {
        let id: ^Ident = unwrap(x.id) as ^Ident;
        libc.fprintf(stream, " %s\n" as ^int8, id.name.data());
    }
    else
    {
        libc.fprintf(stream, "\n" as ^int8);
    }

    dump_indent = dump_indent + 1;
    fdump(stream, x.type_);
    dump_indent = dump_indent - 1;
}

# dump_postfix_expr
# -----------------------------------------------------------------------------
def dump_postfix_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^PostfixExpr = unwrap(node^) as ^PostfixExpr;
    libc.fprintf(stream, "PostfixExpr <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    fdump(stream, x.operand);
    fdump(stream, x.expression);
    dump_indent = dump_indent - 1;
}

# dump_struct
# -----------------------------------------------------------------------------
def dump_struct(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^Struct = unwrap(node^) as ^Struct;
    libc.fprintf(stream, "Struct <?> " as ^int8);
    let id: ^Ident = unwrap(x.id) as ^Ident;
    libc.fprintf(stream, "%s" as ^int8, id.name.data());
    libc.fprintf(stream, "\n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Type Parameters", x.type_params);
    dump_nodes(stream, "Members", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_implement
# -----------------------------------------------------------------------------
def dump_implement(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^Implement = unwrap(node^) as ^Implement;
    libc.fprintf(stream, "Implement <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    fdump(stream, x.type_);
    dump_nodes(stream, "Methods", x.methods);
    dump_indent = dump_indent - 1;
}

# dump_type_param
# -----------------------------------------------------------------------------
def dump_type_param(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^TypeParam = unwrap(node^) as ^TypeParam;
    libc.fprintf(stream, "TypeParam <?> " as ^int8);
    if x.variadic { libc.fprintf(stream, "variadic " as ^int8); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    libc.fprintf(stream, "%s" as ^int8, id.name.data());
    libc.fprintf(stream, "\n" as ^int8);

    dump_indent = dump_indent + 1;
    if not isnull(x.default) { fdump(stream, x.default); }
    if not isnull(x.bounds)  { fdump(stream, x.bounds);  }
    dump_indent = dump_indent - 1;
}

# dump_struct_mem
# -----------------------------------------------------------------------------
def dump_struct_mem(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^StructMem = unwrap(node^) as ^StructMem;
    libc.fprintf(stream, "StructMem <?> " as ^int8);
    let id: ^Ident = unwrap(x.id) as ^Ident;
    libc.fprintf(stream, "%s\n" as ^int8, id.name.data());

    dump_indent = dump_indent + 1;
    fdump(stream, x.type_);
    if not isnull(x.initializer) { fdump(stream, x.initializer); }
    dump_indent = dump_indent - 1;
}

# dump_tuple_expr
# -----------------------------------------------------------------------------
def dump_tuple_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^TupleExpr = unwrap(node^) as ^TupleExpr;
    libc.fprintf(stream, "TupleExpr <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Elements", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_tuple_type
# -----------------------------------------------------------------------------
def dump_tuple_type(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^TupleType = unwrap(node^) as ^TupleType;
    libc.fprintf(stream, "TupleType <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Elements", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_ident
# -----------------------------------------------------------------------------
def dump_ident(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^Ident = unwrap(node^) as ^Ident;
    libc.fprintf(stream, "Ident <?> %s\n" as ^int8, x.name.data());
}

# dump_extern_static_slot
# -----------------------------------------------------------------------------
def dump_extern_static_slot(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^ExternStaticSlot = unwrap(node^) as ^ExternStaticSlot;
    libc.fprintf(stream, "ExternStaticSlot <?> " as ^int8);
    if x.mutable { libc.fprintf(stream, "mut " as ^int8); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    libc.fprintf(stream, "%s\n" as ^int8, id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { fdump(stream, x.type_); }
    dump_indent = dump_indent - 1;
}

# dump_slot
# -----------------------------------------------------------------------------
def dump_slot(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^SlotDecl = unwrap(node^) as ^SlotDecl;
    libc.fprintf(stream, "SlotDecl <?> " as ^int8);
    if x.mutable { libc.fprintf(stream, "mut " as ^int8); }
    let id: ^Ident = unwrap(x.id) as ^Ident;
    libc.fprintf(stream, "%s\n" as ^int8, id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { fdump(stream, x.type_); }
    if not isnull(x.initializer) { fdump(stream, x.initializer); }
    dump_indent = dump_indent - 1;
}

# dump_nodes
# -----------------------------------------------------------------------------
def dump_nodes(stream: ^libc._IO_FILE, name: str, &nodes: Nodes) {
    print_indent(stream);
    libc.fprintf(stream, "%s <?> \n" as ^int8, name);

    # Enumerate through each node.
    dump_indent = dump_indent + 1;
    let mut i: int = 0;
    while i as uint < nodes.size() {
        let node: Node = nodes.get(i);
        fdump(stream, node);
        i = i + 1;
    }
    dump_indent = dump_indent - 1;
}

# dump_select_expr
# -----------------------------------------------------------------------------
def dump_select_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^SelectExpr = unwrap(node^) as ^SelectExpr;
    libc.fprintf(stream, "SelectExpr <?> \n" as ^int8);

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Branches", x.branches);
    dump_indent = dump_indent - 1;
}

# dump_select_branch
# -----------------------------------------------------------------------------
def dump_select_branch(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^SelectBranch = unwrap(node^) as ^SelectBranch;
    libc.fprintf(stream, "SelectBranch <?> \n" as ^int8);

    dump_indent = dump_indent + 1;
    if not isnull(x.condition) { fdump(stream, x.condition); }
    fdump(stream, x.block);
    dump_indent = dump_indent - 1;
}

# dump_loop
# -----------------------------------------------------------------------------
def dump_loop(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^Loop = unwrap(node^) as ^Loop;
    libc.fprintf(stream, "Loop <?> \n" as ^int8);

    dump_indent = dump_indent + 1;
    if not isnull(x.condition) { fdump(stream, x.condition); }
    fdump(stream, x.block);
    dump_indent = dump_indent - 1;
}

# dump_conditional_expr
# -----------------------------------------------------------------------------
def dump_conditional_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^ConditionalExpr = unwrap(node^) as ^ConditionalExpr;
    libc.fprintf(stream, "ConditionalExpr <?> \n" as ^int8);

    dump_indent = dump_indent + 1;
    fdump(stream, x.condition);
    fdump(stream, x.lhs);
    fdump(stream, x.rhs);
    dump_indent = dump_indent - 1;
}

# dump_extern_func
# -----------------------------------------------------------------------------
def dump_extern_func(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^ExternFunc = unwrap(node^) as ^ExternFunc;
    libc.fprintf(stream, "ExternFunc <?> " as ^int8);
    let id: ^Ident = unwrap(x.id) as ^Ident;
    libc.fprintf(stream, "%s\n" as ^int8, id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.return_type) { fdump(stream, x.return_type); }
    dump_nodes(stream, "Parameters", x.params);
    dump_indent = dump_indent - 1;
}

# dump_func_decl
# -----------------------------------------------------------------------------
def dump_func_decl(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^FuncDecl = unwrap(node^) as ^FuncDecl;
    if x.mutable { libc.fprintf(stream, "Mutable " as ^int8); }
    if x.instance { libc.fprintf(stream, "Member " as ^int8); }
    libc.fprintf(stream, "FuncDecl <?> " as ^int8);
    let id: ^Ident = unwrap(x.id) as ^Ident;
    libc.fprintf(stream, "%s\n" as ^int8, id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.return_type) { fdump(stream, x.return_type); }
    dump_nodes(stream, "Type Parameters", x.type_params);
    dump_nodes(stream, "Parameters", x.params);
    fdump(stream, x.block);
    dump_indent = dump_indent - 1;
}

# dump_delegate
# -----------------------------------------------------------------------------
def dump_delegate(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^Delegate = unwrap(node^) as ^Delegate;
    libc.fprintf(stream, "Delegate <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    if not isnull(x.return_type) { fdump(stream, x.return_type); }
    dump_nodes(stream, "Parameters", x.params);
    dump_indent = dump_indent - 1;
}

# dump_func_param
# -----------------------------------------------------------------------------
def dump_func_param(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^FuncParam = unwrap(node^) as ^FuncParam;
    if x.variadic { libc.fprintf(stream, "Variadic " as ^int8); }
    if x.mutable { libc.fprintf(stream, "Mutable " as ^int8); }
    libc.fprintf(stream, "FuncParam <?>" as ^int8);
    if x.mutable { libc.fprintf(stream, " mut" as ^int8); }
    if not isnull(x.id) {
        let id: ^Ident = unwrap(x.id) as ^Ident;
        libc.fprintf(stream, " %s\n" as ^int8, id.name.data());
    } else {
        libc.fprintf(stream, "\n" as ^int8);
    }

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { fdump(stream, x.type_); }
    if not isnull(x.default) { fdump(stream, x.default); }
    dump_indent = dump_indent - 1;
}

# dump_pointer_type
# -----------------------------------------------------------------------------
def dump_pointer_type(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^PointerType = unwrap(node^) as ^PointerType;
    libc.fprintf(stream, "PointerType <?>" as ^int8);
    if x.mutable { libc.fprintf(stream, " mut" as ^int8); }
    libc.fprintf(stream, "\n" as ^int8);

    dump_indent = dump_indent + 1;
    fdump(stream, x.pointee);
    dump_indent = dump_indent - 1;
}

# dump_array_type
# -----------------------------------------------------------------------------
def dump_array_type(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^ArrayType = unwrap(node^) as ^ArrayType;
    libc.fprintf(stream, "ArrayType <?>\n" as ^int8);

    dump_indent = dump_indent + 1;
    fdump(stream, x.size);
    fdump(stream, x.element);
    dump_indent = dump_indent - 1;
}

# dump_return_expr
# -----------------------------------------------------------------------------
def dump_return_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^ReturnExpr = unwrap(node^) as ^ReturnExpr;
    libc.fprintf(stream, "ReturnExpr <?> \n" as ^int8);

    dump_indent = dump_indent + 1;
    if not isnull(x.expression) { fdump(stream, x.expression); }
    dump_indent = dump_indent - 1;
}

# dump_sizeof
# -----------------------------------------------------------------------------
def dump_sizeof(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^SizeOf = unwrap(node^) as ^SizeOf;
    libc.fprintf(stream, "SizeOf <?> \n" as ^int8);

    dump_indent = dump_indent + 1;
    fdump(stream, x.type_);
    dump_indent = dump_indent - 1;
}

# dump_type_expr
# -----------------------------------------------------------------------------
def dump_type_expr(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^TypeExpr = unwrap(node^) as ^TypeExpr;
    libc.fprintf(stream, "TypeExpr <?> \n" as ^int8);

    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    dump_indent = dump_indent - 1;
}

# dump_type_box
# -----------------------------------------------------------------------------
def dump_type_box(stream: ^libc._IO_FILE, node: ^Node) {
    libc.fprintf(stream, "TypeBox <?> \n" as ^int8);
}

# dump_global
# -----------------------------------------------------------------------------
def dump_global(stream: ^libc._IO_FILE, node: ^Node) {
    libc.fprintf(stream, "Global <?> \n" as ^int8);
}

# dump_self
# -----------------------------------------------------------------------------
def dump_self(stream: ^libc._IO_FILE, node: ^Node) {
    libc.fprintf(stream, "Self <?> \n" as ^int8);
}

# dump_break
# -----------------------------------------------------------------------------
def dump_break(stream: ^libc._IO_FILE, node: ^Node) {
    libc.fprintf(stream, "Break <?> \n" as ^int8);
}

# dump_continue
# -----------------------------------------------------------------------------
def dump_continue(stream: ^libc._IO_FILE, node: ^Node) {
    libc.fprintf(stream, "Continue <?> \n" as ^int8);
}

# dump_import
# -----------------------------------------------------------------------------
def dump_import(stream: ^libc._IO_FILE, node: ^Node) {
    let x: ^Import = unwrap(node^) as ^Import;
    libc.fprintf(stream, "Import <?> " as ^int8);

    let mut i: int = 0;
    while i as uint < x.ids.size() {
        let node: Node = x.ids.get(i);
        let id: ^Ident = node.unwrap() as ^Ident;
        if i > 0 { libc.fprintf(stream, "." as ^int8); }
        libc.fprintf(stream, "%s" as ^int8, id.name.data());
        i = i + 1;
    }

    libc.fprintf(stream, "\n" as ^int8);
}
