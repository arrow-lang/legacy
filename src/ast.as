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
struct Node { tag: int, data: *int8 }

implement Node {
    let unwrap(self): *int8 -> { self.data; }
    let _set_tag(mut self, tag: int) -> { self.tag = tag; }
}

# Generic collection of AST "nodes" that can store a
# heterogeneous linked-list of nodes.
struct Nodes { elements: list.List }

let make_nodes(): Nodes -> {
    let nodes: Nodes;
    nodes.elements = list.make_generic(_sizeof(TAG_NODE));
    nodes;
}

let new_nodes(): *Nodes -> {
    let node: Node = make(TAG_NODES);
    node.data as *Nodes;
}

implement Nodes {

    let dispose(mut self) -> { self.elements.dispose(); }

    let size(self): uint -> { self.elements.size; }

    let push(mut self, el: Node) -> {
        # Ensure our `element_size` is set correctly.
        self.elements.element_size = _sizeof(TAG_NODE);

        # Push the node onto our list.
        self.elements.push(&el);
    }

    let pop(mut self): Node -> {
        let ptr: *Node = self.elements.get(-1) as *Node;
        let val: Node = *ptr;
        self.elements.erase(-1);
        val;
    }

    let get(self, i: int): Node -> {
        let ptr: *Node = self.elements.get(i) as *Node;
        *ptr;
    }

    let clear(mut self) -> {
        self.elements.clear();
    }

}

# Expression type for integral literals with a distinct base like "2321".
struct IntegerExpr { base: int8, text: string.String }

# Expression type for float literals.
struct FloatExpr { text: string.String }

# Expression type for a boolean literal
struct BooleanExpr { value: bool }

# Expression type for a string literal
struct StringExpr { text: string.String }

implement StringExpr {

    let count(mut self): uint -> {
        let mut l: list.List = self.unescape();
        let n: uint = l.size;
        l.dispose();
        return n;
    }

    let unescape(mut self): list.List -> {
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
                if buffer.size < 2 { buffer.push_i8(c); };
                if buffer.size == 2 {
                    # We've gotten exactly 2 more characters.
                    # Parse a hexadecimal from the text.
                    let data: *int8 = buffer.elements;
                    (data + 2)* = 0;
                    let val: int64 = libc.strtol(data, 0, 16);

                    # Write out this single byte into bytes.
                    bytes.push_i8(val as int8);

                    # Clear the temp buffer.
                    buffer.clear();

                    # No longer in a UTF-8 escape sequence.
                    in_utf8_escape = false;
                };
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
                else if c == (('x' as char) as int8)  { in_utf8_escape = true; };
                # else if (c == 'u')  { in_utf16_escape = true; }
                # else if (c == 'U')  { in_utf32_escape = true; }

                # No longer in an escape sequence.
                in_escape = false;
            } else {
                if c == (('\\' as char) as int8) {
                    # Mark that we are in an escape sequence.
                    in_escape = true;
                    void;
                } else {
                    # Push the character.
                    bytes.push_i8(c);
                };
            };
        };

        # Dispose.
        buffer.dispose();

        # Return the bytes.
        bytes;
    }

}

# "Generic" binary expression type.
struct BinaryExpr { lhs: Node, rhs: Node }

# Pointer type.
struct PointerType { mutable: bool, pointee: Node }

# Cast expression.
struct CastExpr { operand: Node, type_: Node }

# Index expression type.
struct IndexExpr { expression: Node, subscript: Node }

# Conditional expression.
struct ConditionalExpr { lhs: Node, rhs: Node, condition: Node }

# "Generic" unary expression type.
struct UnaryExpr { operand: Node }

# Address of expression
struct AddressOfExpr { operand: Node, mutable: bool }

# Module declaration that contains a sequence of nodes.
struct ModuleDecl { id: Node, nodes: Nodes }

# Unsafe block.
struct UnsafeBlock { nodes: Nodes }

# Block.
struct Block { nodes: Nodes }

# ArrayExpr.
struct ArrayExpr { nodes: Nodes }

# PostfixExpr
struct PostfixExpr { operand: Node, expression: Node }

# RecordExpr.
struct RecordExpr { nodes: Nodes }

# SequenceExpr
struct SequenceExpr { nodes: Nodes }

# RecordExprMem
struct RecordExprMem { id: Node, expression: Node }

# TupleExpr.
struct TupleExpr { nodes: Nodes }

# TupleExprMem
struct TupleExprMem { id: Node, expression: Node }

# TupleType.
struct TupleType { nodes: Nodes }

# TupleTypeMem
struct TupleTypeMem { id: Node, type_: Node }

# Return expression.
struct ReturnExpr { expression: Node }

# Type expression.
struct TypeExpr { expression: Node }

# Selection expression.
struct SelectExpr { branches: Nodes }

# Selection branch.
struct SelectBranch { condition: Node, block: Node }

# Loop
struct Loop { condition: Node, block: Node }

# Function declaration.
struct FuncDecl {
    id: Node,
    return_type: Node,
    params: Nodes,
    type_params: Nodes,
    instance: bool,
    mutable: bool,
    block: Node
}

# Function delegate
struct Delegate {
    id: Node,
    return_type: Node,
    params: Nodes
}

# External function declaration.
struct ExternFunc {
    id: Node,
    return_type: Node,
    params: Nodes
}

# Function parameter.
struct FuncParam {
    id: Node,
    type_: Node,
    mutable: bool,
    default: Node,
    variadic: bool
}

# External static slot.
struct ExternStaticSlot {
    id: Node,
    type_: Node,
    mutable: bool
}

struct SizeOf {
    type_: Node
}

# Local slot declaration.
struct SlotDecl {
    id: Node,
    type_: Node,
    mutable: bool,
    initializer: Node
}

# TypeParam
struct TypeParam { id: Node, default: Node, variadic: bool, bounds: Node }

# Struct
struct Struct { nodes: Nodes, id: Node, type_params: Nodes }

# StructMem
struct StructMem { id: Node, type_: Node, initializer: Node }

# Call expression
struct CallExpr { expression: Node, arguments: Nodes }

# Call arguments
struct Argument { expression: Node, name: Node }

# Identifier.
struct Ident { name: string.String }

# Pointer type.
struct PointerType { mutable: bool, pointee: Node }

# Array type.
struct ArrayType { element: Node, size: Node }

# Import
# ids: ordered collection of the identifiers that make up the `x.y.z` name
#      to import.
struct Import { ids: Nodes }

# Implement Block
struct Implement { type_: Node, methods: Nodes }

# Global
struct Empty { }

# sizeof -- Get the size required for a specific node tag.
# -----------------------------------------------------------------------------
let _sizeof(tag: int): uint -> {
    if tag == TAG_INTEGER {
        size_of(IntegerExpr);
    } else if tag == TAG_FLOAT {
        size_of(FloatExpr);
    } else if tag == TAG_STRING {
        size_of(StringExpr);
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
        size_of(BinaryExpr);
    } else if tag == TAG_CONDITIONAL {
        size_of(ConditionalExpr);
    } else if tag == TAG_PROMOTE
           or tag == TAG_NUMERIC_NEGATE
           or tag == TAG_BITNEG
           or tag == TAG_DEREF
           or tag == TAG_LOGICAL_NEGATE {
        size_of(UnaryExpr);
    }
    else if tag == TAG_MODULE  { size_of(ModuleDecl); }
    else if tag == TAG_SIZEOF  { size_of(SizeOf); }
    else if tag == TAG_ADDRESS_OF  { size_of(AddressOfExpr); }
    else if tag == TAG_UNSAFE  { size_of(UnsafeBlock); }
    else if tag == TAG_BLOCK   { size_of(Block); }
    else if tag == TAG_ARRAY_EXPR { size_of(ArrayExpr); }
    else if tag == TAG_TUPLE_EXPR { size_of(TupleExpr); }
    else if tag == TAG_TUPLE_TYPE { size_of(TupleType); }
    else if tag == TAG_IMPLEMENT { size_of(Implement); }
    else if tag == TAG_NODE    { size_of(Node); }
    else if tag == TAG_NODES   { size_of(Nodes); }
    else if tag == TAG_BOOLEAN { size_of(BooleanExpr); }
    else if tag == TAG_IDENT   { size_of(Ident); }
    else if tag == TAG_POINTER_TYPE   { size_of(PointerType); }
    else if tag == TAG_ARRAY_TYPE     { size_of(ArrayType); }
    else if tag == TAG_IMPORT  { size_of(Import); }
    else if tag == TAG_INDEX   { size_of(IndexExpr); }
    else if tag == TAG_DELEGATE  { size_of(Delegate); }
    else if tag == TAG_CAST    { size_of(CastExpr); }
    else if tag == TAG_CALL    { size_of(CallExpr); }
    else if tag == TAG_LOOP    { size_of(Loop); }
    else if tag == TAG_CALL_ARG{ size_of(Argument); }
    else if tag == TAG_TYPE_PARAM{ size_of(TypeParam); }
    else if tag == TAG_EXTERN_STATIC { size_of(ExternStaticSlot); }
    else if tag == TAG_EXTERN_FUNC { size_of(ExternFunc); }
    else if tag == TAG_SLOT {
        size_of(SlotDecl);
    } else if tag == TAG_SELECT {
        size_of(SelectExpr);
    } else if tag == TAG_SELECT_BRANCH {
        size_of(SelectBranch);
    } else if tag == TAG_FUNC_DECL {
        size_of(FuncDecl);
    } else if tag == TAG_FUNC_PARAM {
        size_of(FuncParam);
    } else if tag == TAG_RETURN {
        size_of(ReturnExpr);
    } else if tag == TAG_TYPE_EXPR {
        size_of(TypeExpr);
    } else if tag == TAG_GLOBAL
           or tag == TAG_BREAK
           or tag == TAG_SELF
           or tag == TAG_CONTINUE {
        size_of(Empty);
    } else if tag == TAG_TUPLE_EXPR_MEM {
        size_of(TupleExprMem);
    } else if tag == TAG_TUPLE_TYPE_MEM {
        size_of(TupleTypeMem);
    } else if tag == TAG_STRUCT {
        size_of(Struct);
    } else if tag == TAG_STRUCT_MEM {
        size_of(StructMem);
    } else if tag == TAG_POSTFIX_EXPR {
        size_of(PostfixExpr);
    }
    else { 0; };
}

# make -- Allocate space for a node in the AST
# -----------------------------------------------------------------------------
let make(tag: int): Node -> {
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
let unwrap(node: Node): *int8 -> { node.unwrap(); }

# null -- Get a null node.
# -----------------------------------------------------------------------------
let null(): Node -> {
    let mut node: Node;
    node.tag = 0;
    node.data = 0;
    node;
}

# isnull -- Check for a null node.
# -----------------------------------------------------------------------------
let isnull(node: Node): bool -> { node.tag == 0; }

# dump -- Dump a textual representation of the node to stdout.
# -----------------------------------------------------------------------------
let mut dump_table: delegate(*libc.FILE, Node)[100];
let mut dump_indent: int = 0;
let mut dump_initialized: bool = false;
let dump(node: Node) -> { fdump(libc.stdout, node); }
let fdump(stream: *libc.FILE, node: Node) -> {
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
    };

    print_indent(stream);
    let dump_fn: delegate(*libc.FILE, Node) = dump_table[node.tag];
    let node_ptr: *Node = &node;
    dump_fn(stream, node_ptr);
}

# print_indent
# -----------------------------------------------------------------------------
let print_indent(stream: *libc.FILE) -> {
    let mut dump_indent_i: int = 0;
    while dump_indent > dump_indent_i {
        libc.fprintf(stream, "  ");
        dump_indent_i = dump_indent_i + 1;
    }
}

# dump_boolean_expr
# -----------------------------------------------------------------------------
let dump_boolean_expr(stream: *libc.FILE, node: Node) -> {
    let x: *BooleanExpr = unwrap(node) as *BooleanExpr;
    libc.fprintf(stream, "BooleanExpr <?> %s\n", "true" if x.value else "false");
}

# dump_integer_expr
# -----------------------------------------------------------------------------
let dump_integer_expr(stream: *libc.FILE, node: Node) -> {
    let x: *IntegerExpr = unwrap(node) as *IntegerExpr;
    libc.fprintf(stream, "IntegerExpr <?> %s (%d)\n", x.text.data(), x.base);
}

# dump_float_expr
# -----------------------------------------------------------------------------
let dump_float_expr(stream: *libc.FILE, node: Node) -> {
    let x: *FloatExpr = unwrap(node) as *FloatExpr;
    libc.fprintf(stream, "FloatExpr <?> %s\n", x.text.data());
}

# dump_string_expr
# -----------------------------------------------------------------------------
let dump_string_expr(stream: *libc.FILE, node: Node) -> {
    let x: *StringExpr = unwrap(node) as *StringExpr;
    libc.fprintf(stream, "StringExpr <?> %s\n", x.text.data());
}

# dump_binop_expr
# -----------------------------------------------------------------------------
let dump_binop_expr(stream: *libc.FILE, node: Node) -> {
    let x: *BinaryExpr = unwrap(node) as *BinaryExpr;
    if node.tag == TAG_ADD {
        libc.fprintf(stream, "AddExpr <?>\n");
    } else if node.tag == TAG_SUBTRACT {
        libc.fprintf(stream, "SubtractExpr <?>\n");
    } else if node.tag == TAG_MULTIPLY {
        libc.fprintf(stream, "MultiplyExpr <?>\n");
    } else if node.tag == TAG_DIVIDE {
        libc.fprintf(stream, "DivideExpr <?>\n");
    }  else if node.tag == TAG_INTEGER_DIVIDE {
        libc.fprintf(stream, "IntDivideExpr <?>\n");
    } else if node.tag == TAG_MODULO {
        libc.fprintf(stream, "ModuloExpr <?>\n");
    } else if node.tag == TAG_LOGICAL_AND {
        libc.fprintf(stream, "LogicalAndExpr <?>\n");
    } else if node.tag == TAG_LOGICAL_OR {
        libc.fprintf(stream, "LogicalOrExpr <?>\n");
    } else if node.tag == TAG_EQ {
        libc.fprintf(stream, "EQExpr <?>\n");
    } else if node.tag == TAG_NE {
        libc.fprintf(stream, "NEExpr <?>\n");
    } else if node.tag == TAG_LT {
        libc.fprintf(stream, "LTExpr <?>\n");
    } else if node.tag == TAG_LE {
        libc.fprintf(stream, "LEExpr <?>\n");
    } else if node.tag == TAG_GT {
        libc.fprintf(stream, "GTExpr <?>\n");
    } else if node.tag == TAG_GE {
        libc.fprintf(stream, "GEExpr <?>\n");
    } else if node.tag == TAG_ASSIGN {
        libc.fprintf(stream, "AssignExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_ADD {
        libc.fprintf(stream, "AssignAddExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_SUB {
        libc.fprintf(stream, "AssignSubtractExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_MULT {
        libc.fprintf(stream, "AssignMultiplyExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_DIV {
        libc.fprintf(stream, "AssignDivideExpr <?>\n");
    }  else if node.tag == TAG_ASSIGN_INT_DIV {
        libc.fprintf(stream, "AssignIntDivideExpr <?>\n");
    } else if node.tag == TAG_ASSIGN_MOD {
        libc.fprintf(stream, "AssignModuloExpr <?>\n");
    } else if node.tag == TAG_SELECT_OP {
        libc.fprintf(stream, "SelectOpExpr <?>\n");
    } else if node.tag == TAG_MEMBER {
        libc.fprintf(stream, "MemberExpr <?>\n");
    } else if node.tag == TAG_BITOR {
        libc.fprintf(stream, "BitOrExpr <?>\n");
    } else if node.tag == TAG_BITXOR {
        libc.fprintf(stream, "BitXorExpr <?>\n");
    } else if node.tag == TAG_BITAND {
        libc.fprintf(stream, "BitAndExpr <?>\n");
    };
    dump_indent = dump_indent + 1;
    fdump(stream, x.lhs);
    fdump(stream, x.rhs);
    dump_indent = dump_indent - 1;
}

# dump_index_expr
# -----------------------------------------------------------------------------
let dump_index_expr(stream: *libc.FILE, node: Node) -> {
    let x: *IndexExpr = unwrap(node) as *IndexExpr;
    libc.fprintf(stream, "IndexExpr <?>\n");
    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    fdump(stream, x.subscript);
    dump_indent = dump_indent - 1;
}

# dump_cast_expr
# -----------------------------------------------------------------------------
let dump_cast_expr(stream: *libc.FILE, node: Node) -> {
    let x: *CastExpr = unwrap(node) as *CastExpr;
    libc.fprintf(stream, "CastExpr <?>\n");
    dump_indent = dump_indent + 1;
    fdump(stream, x.operand);
    fdump(stream, x.type_);
    dump_indent = dump_indent - 1;
}

# dump_call_arg
# -----------------------------------------------------------------------------
let dump_call_arg(stream: *libc.FILE, node: Node) -> {
    let x: *Argument = unwrap(node) as *Argument;
    libc.fprintf(stream, "Argument <?>");
    if not isnull(x.name) {
        let id: *Ident = unwrap(x.name) as *Ident;
        libc.fprintf(stream, " %s", id.name.data());
    };
    libc.fprintf(stream, "\n");
    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    dump_indent = dump_indent - 1;
}

# dump_call_expr
# -----------------------------------------------------------------------------
let dump_call_expr(stream: *libc.FILE, node: Node) -> {
    let x: *CallExpr = unwrap(node) as *CallExpr;
    libc.fprintf(stream, "CallExpr <?>\n");
    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    dump_nodes(stream, "Arguments", x.arguments);
    dump_indent = dump_indent - 1;
}

# dump_unary_expr
# -----------------------------------------------------------------------------
let dump_unary_expr(stream: *libc.FILE, node: Node) -> {
    let x: *UnaryExpr = unwrap(node) as *UnaryExpr;
    if node.tag == TAG_PROMOTE {
        libc.fprintf(stream, "NumericPromoteExpr <?>\n");
    } else if node.tag == TAG_NUMERIC_NEGATE {
        libc.fprintf(stream, "NumericNegateExpr <?>\n");
    } else if node.tag == TAG_LOGICAL_NEGATE {
        libc.fprintf(stream, "LogicalNegateExpr <?>\n");
    } else if node.tag == TAG_BITNEG {
        libc.fprintf(stream, "BitNegExpr <?>\n");
    } else if node.tag == TAG_DEREF {
        libc.fprintf(stream, "DerefExpr <?>\n");
    };
    dump_indent = dump_indent + 1;
    fdump(stream, x.operand);
    dump_indent = dump_indent - 1;
}

# dump_address_of
# -----------------------------------------------------------------------------
let dump_address_of(stream: *libc.FILE, node: Node) -> {
    let x: *AddressOfExpr = unwrap(node) as *AddressOfExpr;
    libc.fprintf(stream, "AddressOfExpr <?>");
    if x.mutable { libc.fprintf(stream, " mut"); };
    libc.fprintf(stream, "\n");

    dump_indent = dump_indent + 1;
    fdump(stream, x.operand);
    dump_indent = dump_indent - 1;
}

# dump_module
# -----------------------------------------------------------------------------
let dump_module(stream: *libc.FILE, node: Node) -> {
    let x: *ModuleDecl = unwrap(node) as *ModuleDecl;
    libc.fprintf(stream, "ModuleDecl <?> ");
    let id: *Ident = unwrap(x.id) as *Ident;
    libc.fprintf(stream, "%s", id.name.data());
    libc.fprintf(stream, "\n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_unsafe_block
# -----------------------------------------------------------------------------
let dump_unsafe_block(stream: *libc.FILE, node: Node) -> {
    let x: *UnsafeBlock = unwrap(node) as *UnsafeBlock;
    libc.fprintf(stream, "UnsafeBlock <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_block_expr
# -----------------------------------------------------------------------------
let dump_block_expr(stream: *libc.FILE, node: Node) -> {
    let x: *Block = unwrap(node) as *Block;
    libc.fprintf(stream, "Block <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Nodes", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_seq_expr
# -----------------------------------------------------------------------------
let dump_seq_expr(stream: *libc.FILE, node: Node) -> {
    let x: *SequenceExpr = unwrap(node) as *SequenceExpr;
    libc.fprintf(stream, "SequenceExpr <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Members", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_array_expr
# -----------------------------------------------------------------------------
let dump_array_expr(stream: *libc.FILE, node: Node) -> {
    let x: *ArrayExpr = unwrap(node) as *ArrayExpr;
    libc.fprintf(stream, "ArrayExpr <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Elements", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_tuple_expr_mem
# -----------------------------------------------------------------------------
let dump_tuple_expr_mem(stream: *libc.FILE, node: Node) -> {
    let x: *TupleExprMem = unwrap(node) as *TupleExprMem;
    libc.fprintf(stream, "TupleExprMem <?>");
    if not isnull(x.id)
    {
        let id: *Ident = unwrap(x.id) as *Ident;
        libc.fprintf(stream, " %s\n", id.name.data());
    }
    else
    {
        libc.fprintf(stream, "\n");
    };

    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    dump_indent = dump_indent - 1;
}

# dump_tuple_type_mem
# -----------------------------------------------------------------------------
let dump_tuple_type_mem(stream: *libc.FILE, node: Node) -> {
    let x: *TupleTypeMem = unwrap(node) as *TupleTypeMem;
    libc.fprintf(stream, "TupleTypeMem <?>");
    if not isnull(x.id)
    {
        let id: *Ident = unwrap(x.id) as *Ident;
        libc.fprintf(stream, " %s\n", id.name.data());
    }
    else
    {
        libc.fprintf(stream, "\n");
    };

    dump_indent = dump_indent + 1;
    fdump(stream, x.type_);
    dump_indent = dump_indent - 1;
}

# dump_postfix_expr
# -----------------------------------------------------------------------------
let dump_postfix_expr(stream: *libc.FILE, node: Node) -> {
    let x: *PostfixExpr = unwrap(node) as *PostfixExpr;
    libc.fprintf(stream, "PostfixExpr <?>\n");

    dump_indent = dump_indent + 1;
    fdump(stream, x.operand);
    fdump(stream, x.expression);
    dump_indent = dump_indent - 1;
}

# dump_struct
# -----------------------------------------------------------------------------
let dump_struct(stream: *libc.FILE, node: Node) -> {
    let x: *Struct = unwrap(node) as *Struct;
    libc.fprintf(stream, "Struct <?> ");
    let id: *Ident = unwrap(x.id) as *Ident;
    libc.fprintf(stream, "%s", id.name.data());
    libc.fprintf(stream, "\n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Type Parameters", x.type_params);
    dump_nodes(stream, "Members", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_implement
# -----------------------------------------------------------------------------
let dump_implement(stream: *libc.FILE, node: Node) -> {
    let x: *Implement = unwrap(node) as *Implement;
    libc.fprintf(stream, "Implement <?>\n");

    dump_indent = dump_indent + 1;
    fdump(stream, x.type_);
    dump_nodes(stream, "Methods", x.methods);
    dump_indent = dump_indent - 1;
}

# dump_type_param
# -----------------------------------------------------------------------------
let dump_type_param(stream: *libc.FILE, node: Node) -> {
    let x: *TypeParam = unwrap(node) as *TypeParam;
    libc.fprintf(stream, "TypeParam <?> ");
    if x.variadic { libc.fprintf(stream, "variadic "); };
    let id: *Ident = unwrap(x.id) as *Ident;
    libc.fprintf(stream, "%s", id.name.data());
    libc.fprintf(stream, "\n");

    dump_indent = dump_indent + 1;
    if not isnull(x.default) { fdump(stream, x.default); };
    if not isnull(x.bounds)  { fdump(stream, x.bounds);  };
    dump_indent = dump_indent - 1;
}

# dump_struct_mem
# -----------------------------------------------------------------------------
let dump_struct_mem(stream: *libc.FILE, node: Node) -> {
    let x: *StructMem = unwrap(node) as *StructMem;
    libc.fprintf(stream, "StructMem <?> ");
    let id: *Ident = unwrap(x.id) as *Ident;
    libc.fprintf(stream, "%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    fdump(stream, x.type_);
    if not isnull(x.initializer) { fdump(stream, x.initializer); };
    dump_indent = dump_indent - 1;
}

# dump_tuple_expr
# -----------------------------------------------------------------------------
let dump_tuple_expr(stream: *libc.FILE, node: Node) -> {
    let x: *TupleExpr = unwrap(node) as *TupleExpr;
    libc.fprintf(stream, "TupleExpr <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Elements", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_tuple_type
# -----------------------------------------------------------------------------
let dump_tuple_type(stream: *libc.FILE, node: Node) -> {
    let x: *TupleType = unwrap(node) as *TupleType;
    libc.fprintf(stream, "TupleType <?>\n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Elements", x.nodes);
    dump_indent = dump_indent - 1;
}

# dump_ident
# -----------------------------------------------------------------------------
let dump_ident(stream: *libc.FILE, node: Node) -> {
    let x: *Ident = unwrap(node) as *Ident;
    libc.fprintf(stream, "Ident <?> %s\n", x.name.data());
}

# dump_extern_static_slot
# -----------------------------------------------------------------------------
let dump_extern_static_slot(stream: *libc.FILE, node: Node) -> {
    let x: *ExternStaticSlot = unwrap(node) as *ExternStaticSlot;
    libc.fprintf(stream, "ExternStaticSlot <?> ");
    if x.mutable { libc.fprintf(stream, "mut "); };
    let id: *Ident = unwrap(x.id) as *Ident;
    libc.fprintf(stream, "%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { fdump(stream, x.type_); };
    dump_indent = dump_indent - 1;
}

# dump_slot
# -----------------------------------------------------------------------------
let dump_slot(stream: *libc.FILE, node: Node) -> {
    let x: *SlotDecl = unwrap(node) as *SlotDecl;
    libc.fprintf(stream, "SlotDecl <?> ");
    if x.mutable { libc.fprintf(stream, "mut "); };
    let id: *Ident = unwrap(x.id) as *Ident;
    libc.fprintf(stream, "%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { fdump(stream, x.type_); };
    if not isnull(x.initializer) { fdump(stream, x.initializer); };
    dump_indent = dump_indent - 1;
}

# dump_nodes
# -----------------------------------------------------------------------------
let dump_nodes(stream: *libc.FILE, name: str, nodes: Nodes) -> {
    print_indent(stream);
    libc.fprintf(stream, "%s <?> \n", name);

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
let dump_select_expr(stream: *libc.FILE, node: Node) -> {
    let x: *SelectExpr = unwrap(node) as *SelectExpr;
    libc.fprintf(stream, "SelectExpr <?> \n");

    dump_indent = dump_indent + 1;
    dump_nodes(stream, "Branches", x.branches);
    dump_indent = dump_indent - 1;
}

# dump_select_branch
# -----------------------------------------------------------------------------
let dump_select_branch(stream: *libc.FILE, node: Node) -> {
    let x: *SelectBranch = unwrap(node) as *SelectBranch;
    libc.fprintf(stream, "SelectBranch <?> \n");

    dump_indent = dump_indent + 1;
    if not isnull(x.condition) { fdump(stream, x.condition); };
    fdump(stream, x.block);
    dump_indent = dump_indent - 1;
}

# dump_loop
# -----------------------------------------------------------------------------
let dump_loop(stream: *libc.FILE, node: Node) -> {
    let x: *Loop = unwrap(node) as *Loop;
    libc.fprintf(stream, "Loop <?> \n");

    dump_indent = dump_indent + 1;
    if not isnull(x.condition) { fdump(stream, x.condition); };
    fdump(stream, x.block);
    dump_indent = dump_indent - 1;
}

# dump_conditional_expr
# -----------------------------------------------------------------------------
let dump_conditional_expr(stream: *libc.FILE, node: Node) -> {
    let x: *ConditionalExpr = unwrap(node) as *ConditionalExpr;
    libc.fprintf(stream, "ConditionalExpr <?> \n");

    dump_indent = dump_indent + 1;
    fdump(stream, x.condition);
    fdump(stream, x.lhs);
    fdump(stream, x.rhs);
    dump_indent = dump_indent - 1;
}

# dump_extern_func
# -----------------------------------------------------------------------------
let dump_extern_func(stream: *libc.FILE, node: Node) -> {
    let x: *ExternFunc = unwrap(node) as *ExternFunc;
    libc.fprintf(stream, "ExternFunc <?> ");
    let id: *Ident = unwrap(x.id) as *Ident;
    libc.fprintf(stream, "%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.return_type) { fdump(stream, x.return_type); };
    dump_nodes(stream, "Parameters", x.params);
    dump_indent = dump_indent - 1;
}

# dump_func_decl
# -----------------------------------------------------------------------------
let dump_func_decl(stream: *libc.FILE, node: Node) -> {
    let x: *FuncDecl = unwrap(node) as *FuncDecl;
    if x.mutable { libc.fprintf(stream, "Mutable "); };
    if x.instance { libc.fprintf(stream, "Member "); };
    libc.fprintf(stream, "FuncDecl <?> ");
    let id: *Ident = unwrap(x.id) as *Ident;
    libc.fprintf(stream, "%s\n", id.name.data());

    dump_indent = dump_indent + 1;
    if not isnull(x.return_type) { fdump(stream, x.return_type); };
    dump_nodes(stream, "Type Parameters", x.type_params);
    dump_nodes(stream, "Parameters", x.params);
    fdump(stream, x.block);
    dump_indent = dump_indent - 1;
}

# dump_delegate
# -----------------------------------------------------------------------------
let dump_delegate(stream: *libc.FILE, node: Node) -> {
    let x: *Delegate = unwrap(node) as *Delegate;
    libc.fprintf(stream, "Delegate <?>\n");

    dump_indent = dump_indent + 1;
    if not isnull(x.return_type) { fdump(stream, x.return_type); };
    dump_nodes(stream, "Parameters", x.params);
    dump_indent = dump_indent - 1;
}

# dump_func_param
# -----------------------------------------------------------------------------
let dump_func_param(stream: *libc.FILE, node: Node) -> {
    let x: *FuncParam = unwrap(node) as *FuncParam;
    if x.variadic { libc.fprintf(stream, "Variadic "); };
    if x.mutable { libc.fprintf(stream, "Mutable "); };
    libc.fprintf(stream, "FuncParam <?>");
    if x.mutable { libc.fprintf(stream, " mut"); };
    if not isnull(x.id) {
        let id: *Ident = unwrap(x.id) as *Ident;
        libc.fprintf(stream, " %s\n", id.name.data());
    } else {
        libc.fprintf(stream, "\n");
    };

    dump_indent = dump_indent + 1;
    if not isnull(x.type_) { fdump(stream, x.type_); };
    if not isnull(x.default) { fdump(stream, x.default); };
    dump_indent = dump_indent - 1;
}

# dump_pointer_type
# -----------------------------------------------------------------------------
let dump_pointer_type(stream: *libc.FILE, node: Node) -> {
    let x: *PointerType = unwrap(node) as *PointerType;
    libc.fprintf(stream, "PointerType <?>");
    if x.mutable { libc.fprintf(stream, " mut"); };
    libc.fprintf(stream, "\n");

    dump_indent = dump_indent + 1;
    fdump(stream, x.pointee);
    dump_indent = dump_indent - 1;
}

# dump_array_type
# -----------------------------------------------------------------------------
let dump_array_type(stream: *libc.FILE, node: Node) -> {
    let x: *ArrayType = unwrap(node) as *ArrayType;
    libc.fprintf(stream, "ArrayType <?>\n");

    dump_indent = dump_indent + 1;
    fdump(stream, x.size);
    fdump(stream, x.element);
    dump_indent = dump_indent - 1;
}

# dump_return_expr
# -----------------------------------------------------------------------------
let dump_return_expr(stream: *libc.FILE, node: Node) -> {
    let x: *ReturnExpr = unwrap(node) as *ReturnExpr;
    libc.fprintf(stream, "ReturnExpr <?> \n");

    dump_indent = dump_indent + 1;
    if not isnull(x.expression) { fdump(stream, x.expression); };
    dump_indent = dump_indent - 1;
}

# dump_sizeof
# -----------------------------------------------------------------------------
let dump_sizeof(stream: *libc.FILE, node: Node) -> {
    let x: *SizeOf = unwrap(node) as *SizeOf;
    libc.fprintf(stream, "SizeOf <?> \n");

    dump_indent = dump_indent + 1;
    fdump(stream, x.type_);
    dump_indent = dump_indent - 1;
}

# dump_type_expr
# -----------------------------------------------------------------------------
let dump_type_expr(stream: *libc.FILE, node: Node) -> {
    let x: *TypeExpr = unwrap(node) as *TypeExpr;
    libc.fprintf(stream, "TypeExpr <?> \n");

    dump_indent = dump_indent + 1;
    fdump(stream, x.expression);
    dump_indent = dump_indent - 1;
}

# dump_type_box
# -----------------------------------------------------------------------------
let dump_type_box(stream: *libc.FILE, node: Node) -> {
    libc.fprintf(stream, "TypeBox <?> \n");
}

# dump_global
# -----------------------------------------------------------------------------
let dump_global(stream: *libc.FILE, node: Node) -> {
    libc.fprintf(stream, "Global <?> \n");
}

# dump_self
# -----------------------------------------------------------------------------
let dump_self(stream: *libc.FILE, node: Node) -> {
    libc.fprintf(stream, "Self <?> \n");
}

# dump_break
# -----------------------------------------------------------------------------
let dump_break(stream: *libc.FILE, node: Node) -> {
    libc.fprintf(stream, "Break <?> \n");
}

# dump_continue
# -----------------------------------------------------------------------------
let dump_continue(stream: *libc.FILE, node: Node) -> {
    libc.fprintf(stream, "Continue <?> \n");
}

# dump_import
# -----------------------------------------------------------------------------
let dump_import(stream: *libc.FILE, node: Node) -> {
    let x: *Import = unwrap(node) as *Import;
    libc.fprintf(stream, "Import <?> ");

    let mut i: int = 0;
    while i as uint < x.ids.size() {
        let node: Node = x.ids.get(i);
        let id: *Ident = node.unwrap() as *Ident;
        if i > 0 { libc.fprintf(stream, "."); };
        libc.fprintf(stream, "%s", id.name.data());
        i = i + 1;
    }

    libc.fprintf(stream, "\n");
}
