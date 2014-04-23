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
    mut tokens: list.List
}

implement Parser {

# Dispose of internal resources used during parsing.
# -----------------------------------------------------------------------------
def dispose(&mut self) {
    # Dispose of the token buffer.
    self.tokens.dispose();
}

# Push N tokens onto the buffer.
# -----------------------------------------------------------------------------
def push_tokens(&mut self, count: uint) {
    let mut n: uint = count;
    while n > 0 {
        self.tokens.push_int(tokenizer.get_next_token());
        n = n - 1;
    }
}

# Peek ahead N tokens.
# -----------------------------------------------------------------------------
def peek_token(&mut self, count: uint) -> int {
    # Request more tokens if we need them.
    if count > self.tokens.size {
        self.push_tokens(count - self.tokens.size);
    }

    # Return the requested token.
    self.tokens.at_int((count as int) - (self.tokens.size as int) - 1);
}

# Pop a token off the buffer.
# -----------------------------------------------------------------------------
def pop_token(&mut self) -> int {
    # Get the requested token.
    let tok: int = self.peek_token(1);

    # Erase the top token.
    self.tokens.erase(0);

    # Return the erased token.
    tok;
}

# Consume until `token`.
# -----------------------------------------------------------------------------
def consume_until(&mut self, token: int) {
    let mut tok: int = self.pop_token();
    while       tok <> token
            and tok <> tokens.TOK_SEMICOLON {
        tok = self.pop_token();
    }
}

# Expect a token (and report an error).
# -----------------------------------------------------------------------------
def expect(&mut self, req: int) -> bool {
    # Check if we are the expected token.
    let tok: int = self.pop_token();
    if tok == req {
        # Return success.
        true;
    } else {
        # Report error.
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "expected %s but found %s" as ^int8,
                       tokens.to_str(req),
                       tokens.to_str(tok));
        errors.end();

        # Return failure.
        false;
    }
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
    # if tok == tokens.TOK_MODULE { return self.parse_module(nodes); }

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
    #     if self.peek_token(2) == tokens.TOK_IDENTIFIER {
    #         return self.parse_function(nodes);
    #     }
    # }

    if tok == tokens.TOK_LBRACE {
        if not (    self.peek_token(2) == tokens.TOK_IDENTIFIER
                and self.peek_token(3) == tokens.TOK_COLON)
        {
            # Block expression is treated as if it appeared in a
            # function (no `item` may appear inside).
            let node: ast.Node = self.parse_block_expr(nodes);
            if ast.isnull(node) { return false; }
            nodes.push(node);
            return true;
        }
    }

    # We could still be an expression; forward.
    if self.parse_expr_to(nodes) { self.expect(tokens.TOK_SEMICOLON); }
    else                         { false; }
}

# Expression
# -----------------------------------------------------------------------------
# expr = unary-expr | binop-rhs ;
# -----------------------------------------------------------------------------
def parse_expr_to(&mut self, &mut nodes: ast.Nodes) -> bool {
    # Try and parse a unary expression.
    let res: ast.Node = self.parse_expr(nodes);
    if ast.isnull(res) { return false; }

    # Push our node into the stack.
    nodes.push(res);

    # Return success.
    true;
}

def parse_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node {
    # Try and parse a unary expression.
    let res: ast.Node = self.parse_unary_expr(nodes);
    if ast.isnull(res) { return ast.null(); }

    # TODO: Try and continue the unary expression as a binary expression.
    # self.parse_binop_rhs(nodes, 0, 0, res);
    res;
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
        # and tok <> tokens.TOK_BANG
    {
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
        if      tok == tokens.TOK_PLUS  { ast.TAG_PROMOTE; }
        else if tok == tokens.TOK_MINUS { ast.TAG_NUMERIC_NEGATE; }
        else if tok == tokens.TOK_NOT   { ast.TAG_LOGICAL_NEGATE; }
        # else if tok == tokens.TOK_BANG  { ast.TAG_NEGATE; }
        else { 0; };  # Shouldn't happen.

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
    let operand: ast.Node = self.parse_primary_expr(nodes);
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
    else if tok == tokens.TOK_IDENTIFIER
    {
        self.parse_ident_expr(nodes);
    }
    # else if tok == tokens.TOK_TYPE
    # {
    #     self.parse_type_expr(nodes);
    # }
    else if tok == tokens.TOK_GLOBAL
    {
        self.parse_global_expr(nodes);
    }
    # else if tok == tokens.TOK_IF
    # {
    #     self.parse_select_expr(nodes);
    # }
    else if tok == tokens.TOK_LBRACE
    {
        # A block expression (not in a postfix position) can be a `block`
        # or a `record` expression.
        if      self.peek_token(2) == tokens.TOK_IDENTIFIER
            and self.peek_token(3) == tokens.TOK_COLON
        {
            # A record expression /always/ starts like `{` `identifier` `:`
            # There cannot be an "empty" record expression.
            self.parse_record_expr(nodes);
        }
        else
        {
            # This is some kind of block.
            self.parse_block_expr(nodes);
        }
    }
    else
    {
        # Consume erroneous token.
        self.pop_token();

        # Not an expression; diagnose possible problems.
        if tok == tokens.TOK_RETURN or tok == tokens.TOK_COMMA
        {
            # Print error.
            errors.begin_error();
            errors.fprintf(errors.stderr, "unexpected %s" as ^int8,
                           tokens.to_str(tok));
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
    let inte: ^ast.FloatExpr = node.unwrap() as ^ast.FloatExpr;

    # Store the text for the float literal.
    inte.text.extend(tokenizer.current_num.data() as str);

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

# Identifier expression
# -----------------------------------------------------------------------------
def parse_ident_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_IDENT);
    let idente: ^ast.Ident = node.unwrap() as ^ast.Ident;

    # Store the text for the identifier.
    idente.name.extend(tokenizer.current_id.data() as str);

    # Consume the `identifier` token.
    self.pop_token();

    # Return our node.
    node;
}

# Parenthetical expression
# -----------------------------------------------------------------------------
def parse_paren_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Consume the `(` token.
    self.pop_token();

    # Check for an immediate `)` token that would close an empty tuple.
    if self.peek_token(1) == tokens.TOK_RPAREN
    {
        # Consume the `)` token.
        self.pop_token();

        # Allocate and create the node for the tuple.
        # Return the node immediately.
        return ast.make(ast.TAG_TUPLE_EXPR);
    }

    # Parse an expression node.
    let mut node: ast.Node = self.parse_expr(nodes);

    # Check for a comma that would begin a tuple.
    if self.peek_token(1) == tokens.TOK_COMMA
    {
        # Consume the `,` token.
        self.pop_token();

        # Allocate and create the node for the tuple.
        let tup_node: ast.Node = ast.make(ast.TAG_TUPLE_EXPR);
        let expr: ^ast.TupleExpr = tup_node.unwrap() as ^ast.TupleExpr;

        # Push the initial node.
        expr.nodes.push(node);

        # Switch our node.
        node = tup_node;

        # Enumerate until we reach the `)` token.
        while self.peek_token(1) <> tokens.TOK_RPAREN {
            # Parse an expression node.
            if not self.parse_expr_to(expr.nodes) { return ast.null(); }

            # Peek and consume the `,` token if present.
            let tok: int = self.peek_token(1);
            if tok == tokens.TOK_COMMA { self.pop_token(); continue; }
            else if tok <> tokens.TOK_RPAREN {
                # Expected a comma and didn't receive one.. consume tokens
                # until we reach a `)`.
                self.consume_until(tokens.TOK_RPAREN);
                errors.begin_error();
                errors.fprintf(errors.stderr,
                               "expected %s or %s but found %s" as ^int8,
                               tokens.to_str(tokens.TOK_COMMA),
                               tokens.to_str(tokens.TOK_RPAREN),
                               tokens.to_str(tok));
                errors.end();
                return ast.null();
            }

            # Done here; too bad.
            break;
        }
    }

    # Expect a `)` token.
    self.expect(tokens.TOK_RPAREN);

    # Return our node.
    node;
}

# Array expression
# -----------------------------------------------------------------------------
def parse_array_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_ARRAY_EXPR);
    let expr: ^ast.ArrayExpr = node.unwrap() as ^ast.ArrayExpr;

    # Consume the `[` token.
    self.pop_token();

    # Enumerate until we reach the `]` token.
    while self.peek_token(1) <> tokens.TOK_RBRACKET {
        # Parse an expression node.
        if not self.parse_expr_to(expr.nodes) { return ast.null(); }

        # Peek and consume the `,` token if present.
        let tok: int = self.peek_token(1);
        if tok == tokens.TOK_COMMA { self.pop_token(); continue; }
        else if tok <> tokens.TOK_RBRACKET {
            # Expected a comma and didn't receive one.. consume tokens until
            # we reach a `]`.
            self.consume_until(tokens.TOK_RBRACKET);
            errors.begin_error();
            errors.fprintf(errors.stderr,
                           "expected %s or %s but found %s" as ^int8,
                           tokens.to_str(tokens.TOK_COMMA),
                           tokens.to_str(tokens.TOK_RBRACKET),
                           tokens.to_str(tok));
            errors.end();
            return ast.null();
        }

        # Done here; too bad.
        break;
    }

    # Expect a `]` token.
    if not self.expect(tokens.TOK_RBRACKET) { return ast.null(); }

    # Return our node.
    node;
}

# Record expression
# -----------------------------------------------------------------------------
def parse_record_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_RECORD_EXPR);
    let expr: ^ast.RecordExpr = node.unwrap() as ^ast.RecordExpr;

    # Consume the `{` token.
    self.pop_token();

    # Enumerate until we reach the `}` token.
    while self.peek_token(1) <> tokens.TOK_RBRACE {
        # Allocate and create a member node.
        let member_node: ast.Node = ast.make(ast.TAG_RECORD_EXPR_MEM);
        let member: ^ast.RecordExprMem =
            member_node.unwrap() as ^ast.RecordExprMem;

        if self.peek_token(1) <> tokens.TOK_IDENTIFIER {
            # Report the error.
            self.expect(tokens.TOK_IDENTIFIER);
            self.consume_until(tokens.TOK_RBRACE);
            return ast.null();
        }

        # Parse the identifier.
        member.id = self.parse_ident_expr(nodes);

        # Expect a `:` token.
        if not self.expect(tokens.TOK_COLON) {
            self.consume_until(tokens.TOK_RBRACE);
            return ast.null();
        }

        # Parse an expression node.
        member.expression = self.parse_expr(expr.nodes);
        if ast.isnull(member.expression) {
            self.consume_until(tokens.TOK_RBRACE);
            return ast.null();
        }

        # Push the node.
        expr.nodes.push(member_node);

        # Peek and consume the `,` token if present.
        let tok: int = self.peek_token(1);
        if tok == tokens.TOK_COMMA { self.pop_token(); continue; }
        else if tok <> tokens.TOK_RBRACE {
            # Expected a comma and didn't receive one.. consume tokens until
            # we reach a `}`.
            self.consume_until(tokens.TOK_RBRACE);
            errors.begin_error();
            errors.fprintf(errors.stderr,
                           "expected %s or %s but found %s" as ^int8,
                           tokens.to_str(tokens.TOK_COMMA),
                           tokens.to_str(tokens.TOK_RBRACE),
                           tokens.to_str(tok));
            errors.end();
            return ast.null();
        }

        # Done here; too bad.
        break;
    }

    # Expect a `}` token.
    if not self.expect(tokens.TOK_RBRACE) { return ast.null(); }

    # Return our node.
    node;
}

# Block expression
# -----------------------------------------------------------------------------
def parse_block_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Parse a brace expression.
    let mut node: ast.Node = self.parse_brace_expr(nodes);

    # If we are a sequence expr ...
    if node.tag == ast.TAG_SEQ_EXPR
    {
        # ... and we have <= 1 members
        let expr: ^ast.SequenceExpr = node.unwrap() as ^ast.SequenceExpr;
        if expr.nodes.size() <= 1
        {
            # Transpose us as a block.
            node._set_tag(ast.TAG_BLOCK);
        }
        else
        {
            # Die; sequence expressions except in a postfix situation
            # are illegal.
            errors.begin_error();
            errors.fprintf(errors.stderr,
                           "expected `block` but found `sequence` (a sequence expression must be prefixed by a nominal type)" as ^int8);
            errors.end();
            return ast.null();
        }
    }

    # Return our node.
    node;
}

# Brace expression
# -----------------------------------------------------------------------------
def parse_brace_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Allocate and create the node.
    # Note that we assume we are a sequence until proven otherwise.
    let mut node: ast.Node = ast.make(ast.TAG_SEQ_EXPR);
    let expr: ^ast.SequenceExpr = node.unwrap() as ^ast.SequenceExpr;

    # Expect and consume the `{` token.
    if not self.expect(tokens.TOK_LBRACE) { return ast.null(); }

    # Iterate and attempt to match statements.
    while self.peek_token(1) <> tokens.TOK_RBRACE {
        # If we are still a sequence ...
        # ... and If we could possibly be an expression ...
        if  node.tag == ast.TAG_SEQ_EXPR
                and self._possible_expr(self.peek_token(1))
        {
            # Parse the expression node directly.
            let expr_node: ast.Node = self.parse_expr(nodes);
            if ast.isnull(expr_node) {
                self.consume_until(tokens.TOK_RBRACE);
                return ast.null();
            }

            # Push the expression node.
            expr.nodes.push(expr_node);

            # Peek and consume the `,` token if present.
            let tok: int = self.peek_token(1);
            if tok == tokens.TOK_COMMA
            {
                # We are definitely a sequence; no questsions, continue.
                self.pop_token();
                continue;
            }
            if tok <> tokens.TOK_RBRACE
            {
                if expr.nodes.elements.size > 1
                {
                    # We know we are sequence; this is an error.
                    self.consume_until(tokens.TOK_RBRACE);
                    errors.begin_error();
                    errors.fprintf(errors.stderr,
                                   "expected %s or %s but found %s" as ^int8,
                                   tokens.to_str(tokens.TOK_COMMA),
                                   tokens.to_str(tokens.TOK_RBRACE),
                                   tokens.to_str(tok));
                    errors.end();
                    return ast.null();
                }

                # No `,` and no `}` -- we are some kind of block, expect
                # an `;`.
                if self.expect(tokens.TOK_SEMICOLON)
                {
                    # All good; continue onwards as a block.
                    node._set_tag(ast.TAG_BLOCK);
                    continue;
                }

                # Bad news; no idea what we are.
                self.consume_until(tokens.TOK_RBRACE);
                return ast.null();
            }

            # We are a one-element sequence.
            break;
        }

        # Try and parse a node.
        if not self.parse_common_statement(nodes) {
            # Bad news.
            self.consume_until(tokens.TOK_RBRACE);
            return ast.null();
        }
    }

    # Expect and consume the `}` token.
    if not self.expect(tokens.TOK_RBRACE) {
        self.consume_until(tokens.TOK_RBRACE);
        return ast.null();
    }

    # Return the constructed node.
    node;
}

# Global expression
# -----------------------------------------------------------------------------
def parse_global_expr(&mut self, &mut nodes: ast.Nodes) -> ast.Node
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_GLOBAL);

    # Consume the `global` token.
    self.pop_token();

    # Return our node.
    node;
}

# Check if a token could possibly begin an expression.
# -----------------------------------------------------------------------------
def _possible_expr(&mut self, tok: int) -> bool {
    let tok: int = self.peek_token(1);
    if tok == tokens.TOK_LET    { false; }
    if tok == tokens.TOK_UNSAFE { false; }
    if tok == tokens.TOK_MATCH  { false; }
    if tok == tokens.TOK_LOOP   { false; }
    if tok == tokens.TOK_WHILE  { false; }
    if tok == tokens.TOK_STATIC { false; }
    if tok == tokens.TOK_IMPORT { false; }
    if tok == tokens.TOK_STRUCT { false; }
    if tok == tokens.TOK_ENUM   { false; }
    if tok == tokens.TOK_USE    { false; }
    if tok == tokens.TOK_IMPL   { false; }

    if tok == tokens.TOK_DEF {
        if self.peek_token(2) == tokens.TOK_IDENTIFIER { false; }
    }

    if tok == tokens.TOK_LBRACE {
        if not (    self.peek_token(2) == tokens.TOK_IDENTIFIER
                and self.peek_token(3) == tokens.TOK_COLON)
        {
            true;
        }
    }

    true;
}

} # Parser


# Test driver using `stdin`.
# =============================================================================
def main() {
    # Declare the parser.
    let mut p: Parser;

    # Walk the token stream and parse out the AST.
    let unit: ast.Node = p.parse("_");
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
