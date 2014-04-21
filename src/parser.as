import libc;
import ast;
import errors;
import list;
import types;
import tokenizer;
import tokens;

# Parser
# =============================================================================
type Parser {
    # Token buffer.
    # Tokens get pushed as they are read from the input stream and popped
    # when consumed. This is implemented as a list so that we can
    # roll back the stream or insert additional tokens.
    tokens: list.List
}

implement Parser {

# Dispose of internal resources used during parsing.
# -----------------------------------------------------------------------------
def dispose(&mut self) {
    # Dispose of the token buffer.
    self.tokens.dispose();
}

# Begin the parsing process.
# -----------------------------------------------------------------------------
def parse(&mut self, name: str) -> ast.Node {
    # Initialize the token buffer.
    self.tokens = list.make(types.INT);

    # Declare the top-level module decl node.
    let node: ast.Node = ast.make(ast.TAG_MODULE);
    let mod: ^ast.ModuleDecl = node.unwrap() as ^ast.ModuleDecl;

    # Set the name of the top-level module.
    mod.id = ast.make(ast.TAG_IDENT);
    let id: ^ast.Ident = mod.id.unwrap() as ^ast.Ident;
    id.name.extend(name);

    # Iterate and attempt to match items until the stream is empty.
    let mut tok: int = self.peek_token(1);
    while tok <> tokens.TOK_END {
        # Try and parse a module node.
        self.parse_module_node(mod.nodes);

        # Peek the next token.
        tok = self.peek_token(1);
    }

    # Return our node.
    node;
}

# Module node
# -----------------------------------------------------------------------------
# module-node = module | common-statement ;
# -----------------------------------------------------------------------------
def parse_module_node(&mut self, &mut nodes: ast.Nodes) -> bool {
    # Peek ahead and see if we are a module `item`.
    let tok: int = self.peek_token(1);
    if tok == tokens.TOK_MODULE { return self.parse_module(nodes); }

    if tok == tokens.TOK_SEMICOLON {
        # Consume the semicolon and attempt to match the next item.
        self.pop_token();
        return self.parse_module_node(nodes);
    }

    # We could still be a common statement.
    self.parse_common_statement(nodes);
}

# "Common" statement
# -----------------------------------------------------------------------------
# common-statement = local-slot | unsafe | match | while | loop | static-slot
#                  | import | struct | enum | use | implement | function
#                  | block-expr | expr ;
# -----------------------------------------------------------------------------
def parse_common_statement(&mut self, &mut nodes: ast.Nodes) -> bool {
    # Peek ahead and see if we are a common statement.
    let tok: int = self.peek_token(1);
    # if tok == tokens.TOK_LET    { return self.parse_local_slot(nodes); }
    # if tok == tokens.TOK_UNSAFE { return self.parse_unsafe(nodes); }
    # if tok == tokens.TOK_MATCH  { return self.parse_match(nodes); }
    # if tok == tokens.TOK_LOOP   { return self.parse_loop(nodes); }
    # if tok == tokens.TOK_WHILE  { return self.parse_while(nodes); }
    # if tok == tokens.TOK_STATIC { return self.parse_static_slot(nodes); }
    # if tok == tokens.TOK_IMPORT { return self.parse_import(nodes); }
    # if tok == tokens.TOK_STRUCT { return self.parse_struct(nodes); }
    # if tok == tokens.TOK_ENUM   { return self.parse_enum(nodes); }
    # if tok == tokens.TOK_USE    { return self.parse_use(nodes); }
    # if tok == tokens.TOK_IMPL   { return self.parse_impl(nodes); }

    # if tok == tokens.TOK_DEF {
    #     # Functions are only declarations if they are named.
    #     if self.peek_token(2) == tokens.TOK_IDENTIFER {
    #         return self.parse_function(nodes);
    #     }
    # }

    # if tok == tokens.TOK_LBRACE {
    #     # Block expression is treated as if it appeared in a
    #     # function (no `item` may appear inside).
    #     return self.parse_block_expr(nodes);
    # }

    # We could still be an expression; forward.
    self.parse_expr(nodes);
}

# Expression
# -----------------------------------------------------------------------------
# expr = unary-expr | binop-rhs ;
# -----------------------------------------------------------------------------
def parse_expr(&mut self, &mut nodes: ast.Nodes) -> bool {
    # Try and parse a unary expression.
    let res: ast.Node = self.parse_unary_expr(nodes);
    if ast.isnull(res) { return false; }

    # Try and continue the unary expression as a binary expression.
    self.parse_binop_rhs(nodes, 0, 0, res);
}

# Unary expression
# -----------------------------------------------------------------------------
# unary-expr = unary-op postfix-expr ;
# unary-op = "+" | "-" | "not" | "!" ;
# -----------------------------------------------------------------------------
def parse_unary_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node {
    # If this is not a unary expression then forward us to check for a
    # postfix expression.
    let tok: int = self.peek_token(1);
    if tok <> tokens.TOK_PLUS
            and tok <> tokens.TOK_MINUS
            and tok <> tokens.TOK_NOT
            and tok <> tokens.TOK_BANG {
        return self.parse_postfix_expr(nodes);
    }

    # This -is- a unary expression; carry on.
    self.pop_token();

    # Parse the operand of this expression.
    let operand: ast.Node = self.parse_unary_expr(nodes);
    if ast.isnull(operand) { return ast.null(); }

    # Determine the AST tag for this unary expression.
    # FIXME: Replace with a HashMap<int, int> when available
    let tag: int =
        if      tok == tokens.TOK_PLUS  { ast.TAG_PLUS; }
        else if tok == tokens.TOK_MINUS { ast.TAG_NUMERIC_NEGATE; }
        else if tok == tokens.TOK_NOT   { ast.TAG_LOGICAL_NEGATE; }
        else if tok == tokens.TOK_BANG  { ast.TAG_NEGATE; }
        else { 0; }  # Shouldn't happen.

    # Allocate and create the node.
    let node: ast.Node = ast.make(tag);
    let expr: ^ast.UnaryExpr = node.unwrap() as ^ast.UnaryExpr;
    expr.operand = operand;

    # Return our constructed node.
    node;
}

# Postfix expression
# -----------------------------------------------------------------------------
# postfix-expr = primary-expr
#              | postfix-expr "[" expr "]"
#              | postfix-expr "(" arguments ")"
#              | postfix-expr "." identifier
#              | postfix-expr "{" record-members "}"
#              | postfix-expr "{" sequence-members "}"
#              ;
# -----------------------------------------------------------------------------
def parse_postfix_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node {
    # Attempt to parse the `operand` as a primary expression.
    let operand: ast.Node = self.parse_primary_expr();
    if ast.isnull(operand) { return ast.null(); }

    # TODO: Implement
    # DEBUG: Pretend this cannot be a postifx expression.
    operand;
}

# Primary expression
# -----------------------------------------------------------------------------
# primary-expr = integer-expr | float-expr | bool-expr | paren-expr
#              | identifier | select-expr | type-expr | global-expr
#              | array-expr | block-expr ;
# -----------------------------------------------------------------------------
def parse_primary_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # FIXME: Replace this with a Map<int, ..>
    let tok: int = self.peek_token(1);
    if     tok == tokens.TOK_BIN_INTEGER
        or tok == tokens.TOK_OCT_INTEGER
        or tok == tokens.TOK_DEC_INTEGER
        or tok == tokens.TOK_HEX_INTEGER
    {
        self.parse_integer_expr(nodes);
    }
    else if tok == tokens.TOK_FLOAT
    {
        self.parse_float_expr(nodes);
    }
    else if tok == tokens.TOK_TRUE or tok == tokens.TOK_FALSE
    {
        self.parse_bool_expr(nodes);
    }
    else if tok == tokens.TOK_LPAREN
    {
        self.parse_paren_expr(nodes);
    }
    else if tok == tokens.TOK_LBRACKET
    {
        self.parse_array_expr(nodes);
    }
    else if tok == tokens.TOK_IDENTIFER
    {
        self.parse_ident_expr(nodes);
    }
    else if tok == tokens.TOK_TYPE
    {
        self.parse_type_expr(nodes);
    }
    else if tok == tokens.TOK_GLOBAL
    {
        self.parse_global_expr(nodes);
    }
    else if tok == tokens.TOK_IF
    {
        self.parse_select_expr(nodes);
    }
    else if tok == tokens.TOK_LBRACE
    {
        self.parse_brace_expr(nodes);
    }
    else
    {
        # Not an expression; diagnose possible problems.
        if tok == tokens.TOK_RETURN
        {
            errors.begin_error();
            errors.fprintf(errors.stderr, "unexpected `return`" as ^int8);
            errors.end();
        }

        # Return nil.
        ast.null();
    }
}

# Integer expression
# -----------------------------------------------------------------------------
def parse_integer_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_INTEGER);
    let inte: ^ast.IntegerExpr = node.unwrap() as ^ast.IntegerExpr;

    # Determine the base for the integer literal.
    let tok: int = self.peek_token(1);
    inte.base =
        if      tok == tokens.TOK_DEC_INTEGER { 10; }
        else if tok == tokens.TOK_HEX_INTEGER { 16; }
        else if tok == tokens.TOK_OCT_INTEGER { 8; }
        else if tok == tokens.TOK_BIN_INTEGER { 2; }
        else { 0; };  # NOTE: Not possible to get here

    # Store the text for the integer literal.
    inte.text.extend(tokenizer.current_num.data() as str);

    # Consume the token.
    self.pop_token();

    # Return our node.
    node;
}

# Float expression
# -----------------------------------------------------------------------------
def parse_float_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_FLOAT);
    let inte: ^ast.FLoatExpr = node.unwrap() as ^ast.FLoatExpr;

    # Store the text for the float literal.
    expr.text.extend(tokenizer.current_num.data() as str);

    # Consume our token.
    self.pop_token();

    # Return our node.
    node;
}

# Boolean expression
# -----------------------------------------------------------------------------
def parse_bool_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_BOOLEAN);
    let boole: ^ast.BooleanExpr = node.unwrap() as ^ast.BooleanExpr;

    # Set our value and consume our token.
    boole.value = self.pop_token() == tokens.TOK_TRUE;

    # Return our node.
    node;
}

# Parenthesised expression
# -----------------------------------------------------------------------------
def parse_paren_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Consume the "(" token.
    self.pop_token();

    # Attempt to consume an expression.
    let expr: ast.Node = self.parse_expr();

}

} # Parser

# Test driver using `stdin`.
# =============================================================================
def main() {
    # Declare the parser.
    let mut p: Parser;

    # Walk the token stream and parse out the AST.
    let unit: ast.Node = p.parse();
    if errors.count > 0 { libc.exit(-1); }

    # Print the AST to `stdout`.
    # FIXME: unit.dump();
    ast.dump(unit);

    # Dispose of any resources used.
    p.dispose();
    # unit.dispose();

    # Exit success back to the environment.
    libc.exit(0);
}
