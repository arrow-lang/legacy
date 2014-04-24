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
    mut tokens: list.List,

    # Node stack.
    # Nodes get pushed as they are realized and popped as consumed.
    mut stack: ast.Nodes
}

implement Parser {

# Dispose of internal resources used during parsing.
# -----------------------------------------------------------------------------
def dispose(&mut self) {
    # Dispose of the token buffer.
    self.tokens.dispose();

    # Dispose of the node stack.
    self.stack.dispose();
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

    # Initialize the node stack.
    self.stack = ast.make_nodes();

    # Declare the top-level module decl node.
    let node: ast.Node = ast.make(ast.TAG_MODULE);
    let mod: ^ast.ModuleDecl = node.unwrap() as ^ast.ModuleDecl;

    # Set the name of the top-level module.
    mod.id = ast.make(ast.TAG_IDENT);
    let id: ^ast.Ident = mod.id.unwrap() as ^ast.Ident;
    id.name.extend(name);

    # Iterate and attempt to match items until the stream is empty.
    while self.peek_token(1) <> tokens.TOK_END {
        # Try and parse a module node.
        if self.parse_module_node() {
            # Consume the parsed node and push it into the module.
            mod.nodes.push(self.stack.pop());
        } else {
            # Clear the node stack.
            self.stack.clear();
        }
    }

    # Return our node.
    node;
}

# Module node
# -----------------------------------------------------------------------------
# module-node = module | common-statement ;
# -----------------------------------------------------------------------------
def parse_module_node(&mut self) -> bool {
    # Peek ahead and see if we are a module `item`.
    let tok: int = self.peek_token(1);
    # if tok == tokens.TOK_MODULE { return self.parse_module(nodes); }

    if tok == tokens.TOK_SEMICOLON {
        # Consume the semicolon and attempt to match the next item.
        self.pop_token();
        return self.parse_module_node();
    }

    # We could still be a common statement.
    self.parse_common_statement();
}

# "Common" statement
# -----------------------------------------------------------------------------
# common-statement = local-slot | unsafe | match | while | loop | static-slot
#                  | import | struct | enum | use | implement | function
#                  | block-expr | expr ;
# -----------------------------------------------------------------------------
def parse_common_statement(&mut self) -> bool {
    # Peek ahead and see if we are a common statement.
    let tok: int = self.peek_token(1);
    # if tok == tokens.TOK_LET    { return self.parse_local_slot(); }
    # if tok == tokens.TOK_UNSAFE { return self.parse_unsafe(); }
    # if tok == tokens.TOK_MATCH  { return self.parse_match(); }
    # if tok == tokens.TOK_LOOP   { return self.parse_loop(); }
    # if tok == tokens.TOK_WHILE  { return self.parse_while(); }
    # if tok == tokens.TOK_STATIC { return self.parse_static_slot(); }
    # if tok == tokens.TOK_IMPORT { return self.parse_import(); }
    if tok == tokens.TOK_STRUCT { return self.parse_struct(); }
    # if tok == tokens.TOK_ENUM   { return self.parse_enum(); }
    # if tok == tokens.TOK_USE    { return self.parse_use(); }
    # if tok == tokens.TOK_IMPL   { return self.parse_impl(); }

    # if tok == tokens.TOK_DEF {
    #     # Functions are only declarations if they are named.
    #     if self.peek_token(2) == tokens.TOK_IDENTIFIER {
    #         return self.parse_function(nodes);
    #     }
    # }

    # Checks to see if its an anon struct expression
    # If not, resume parsing as a block
    if tok == tokens.TOK_LBRACE {
        # if not ({ x :)
        if not (    self.peek_token(2) == tokens.TOK_IDENTIFIER
                and self.peek_token(3) == tokens.TOK_COLON)
        {
            # Block expression is treated as if it appeared in a
            # function (no `item` may appear inside).
            return self.parse_block_expr();
        }
    }

    # We could still be an expression; forward.
    if self.parse_expr() { self.expect(tokens.TOK_SEMICOLON); }
    else                 { false; }
}

def parse_struct(&mut self) -> bool {

    # Allocate space for the node
    let struct_node : ast.Node = ast.make(ast.TAG_STRUCT);
    let structN : ^ast.Struct =  struct_node.unwrap() as ^ast.Struct;

    # Take and remove "struct"
    self.pop_token();

    if not self.parse_ident_expr() { 
        self.consume_until(tokens.TOK_RBRACE);
        return false; 
    }

    # Set the identifier attribute of the last item added to the stack
    # (If we have gotten this far, its an identifier)
    structN.id = self.stack.pop();

    if not  self.expect(tokens.TOK_LBRACE) { 
        self.consume_until(tokens.TOK_RBRACE);
        return false; 
    }

    while self.peek_token(1) <> tokens.TOK_RBRACE {

        let mut struct_mem_node: ast.Node = ast.make(ast.TAG_STRUCT_MEM);
        let struct_mem : ^ast.StructMem = struct_mem_node.unwrap() as ^ast.StructMem;
        let is_static: bool = false;

        if self.peek_token(1) == tokens.TOK_STATIC {
            #We know its a static struct, lets change our node
            struct_mem_node._set_tag(ast.TAG_STRUCT_SMEM);
            is_static = true;
            self.pop_token();
        }

        if self.peek_token(1) == tokens.TOK_MUT {
            #We know its a static struct, lets change our node
            struct_mem.mutable = true;
            self.pop_token();
        }

        if self.peek_token(1) <> tokens.TOK_IDENTIFIER {
            # Report the error.
            self.expect(tokens.TOK_IDENTIFIER);
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        if not self.parse_ident_expr() { return false; }

        # We got an identifier!
        struct_mem.id = self.stack.pop();



        # Now, we'd better get a colon, or shit's going to get real
        if not self.expect(tokens.TOK_COLON) {
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        # Now for a type!
        if not self.parse_ident_expr() {
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        struct_mem.type_ = self.stack.pop();

        if self.peek_token(1) == tokens.TOK_EQ {
            # Consume the "="
            self.pop_token() ;

            if not self.parse_expr() { 
                self.consume_until(tokens.TOK_RBRACE);
                return false; 
            }

            struct_mem.initializer =self.stack.pop();
        } else if is_static {
            # Should probably throw an error message, too lazy to however.
            errors.begin_error();
            errors.fprintf(errors.stderr,
                           "expected %s but found %s (static members must have an initializer)" as ^int8,
                           tokens.to_str(tokens.TOK_EQ),
                           tokens.to_str(self.peek_token(1)));
            errors.end();
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        # Push the node.
        structN.nodes.push(struct_mem_node);

        let tok: int = self.peek_token(1);
        if tok == tokens.TOK_COMMA { self.pop_token(); continue; }
        
        else if tok <> tokens.TOK_RBRACE {
            self.consume_until(tokens.TOK_RBRACE);
            errors.begin_error();
            errors.fprintf(errors.stderr,
                           "expected %s or %s but found %s" as ^int8,
                           tokens.to_str(tokens.TOK_COMMA),
                           tokens.to_str(tokens.TOK_RBRACE),
                           tokens.to_str(tok));
            errors.end();
            return false;

        # Done here; too bad.
    }

    # THIS SHOULD NEVER HAPPEN
    break;

    }

    # Push our node on the stack.
    self.stack.push(struct_node);

    # Return success.
    true;
}

# Expression
# -----------------------------------------------------------------------------
# expr = unary-expr | binop-rhs ;
# -----------------------------------------------------------------------------
def parse_expr(&mut self) -> bool {
    # Try and parse a unary expression.
    if not self.parse_unary_expr() { return false; }

    # Try and continue the unary expression as a binary expression.
    # self.parse_binop_rhs(0, 0);
    true;
}

# Unary expression
# -----------------------------------------------------------------------------
# unary-expr = unary-op postfix-expr ;
# unary-op = "+" | "-" | "not" | "!" ;
# -----------------------------------------------------------------------------
def parse_unary_expr(&mut self) -> bool {
    # If this is not a unary expression then forward us to check for a
    # postfix expression.
    let tok: int = self.peek_token(1);
    if tok <> tokens.TOK_PLUS
        and tok <> tokens.TOK_MINUS
        and tok <> tokens.TOK_NOT
        # and tok <> tokens.TOK_BANG
    {
        return self.parse_postfix_expr();
    }

    # This -is- a unary expression; carry on.
    self.pop_token();

    # Parse the operand of this expression.
    if not self.parse_unary_expr() { return false; }
    let operand: ast.Node = self.stack.pop();

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

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
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
def parse_postfix_expr(&mut self) -> bool {
    # Attempt to parse the `operand` as a primary expression.
    # TODO: Implement
    self.parse_primary_expr();
}

# Primary expression
# -----------------------------------------------------------------------------
# primary-expr = integer-expr | float-expr | bool-expr | paren-expr
#              | identifier | select-expr | type-expr | global-expr
#              | array-expr | block-expr ;
# -----------------------------------------------------------------------------
def parse_primary_expr(&mut self) -> bool
{
    # FIXME: Replace this with a Map<int, ..>
    let tok: int = self.peek_token(1);
    if     tok == tokens.TOK_BIN_INTEGER
        or tok == tokens.TOK_OCT_INTEGER
        or tok == tokens.TOK_DEC_INTEGER
        or tok == tokens.TOK_HEX_INTEGER
    {
        self.parse_integer_expr();
    }
    else if tok == tokens.TOK_FLOAT
    {
        self.parse_float_expr();
    }
    else if tok == tokens.TOK_TRUE or tok == tokens.TOK_FALSE
    {
        self.parse_bool_expr();
    }
    else if tok == tokens.TOK_LPAREN
    {
        self.parse_paren_expr();
    }
    else if tok == tokens.TOK_LBRACKET
    {
        self.parse_array_expr();
    }
    else if tok == tokens.TOK_IDENTIFIER
    {
        self.parse_ident_expr();
    }
    # else if tok == tokens.TOK_TYPE
    # {
    #     self.parse_type_expr();
    # }
    else if tok == tokens.TOK_GLOBAL
    {
        self.parse_global_expr();
    }
    # else if tok == tokens.TOK_IF
    # {
    #     self.parse_select_expr();
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
            self.parse_record_expr();
        }
        else
        {
            # This is some kind of block.
            self.parse_block_expr();
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
        false;
    }
}

# Integer expression
# -----------------------------------------------------------------------------
def parse_integer_expr(&mut self) -> bool
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

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Float expression
# -----------------------------------------------------------------------------
def parse_float_expr(&mut self) -> bool
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_FLOAT);
    let inte: ^ast.FloatExpr = node.unwrap() as ^ast.FloatExpr;

    # Store the text for the float literal.
    inte.text.extend(tokenizer.current_num.data() as str);

    # Consume our token.
    self.pop_token();

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Boolean expression
# -----------------------------------------------------------------------------
def parse_bool_expr(&mut self) -> bool
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_BOOLEAN);
    let boole: ^ast.BooleanExpr = node.unwrap() as ^ast.BooleanExpr;

    # Set our value and consume our token.
    boole.value = self.pop_token() == tokens.TOK_TRUE;

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Identifier expression
# -----------------------------------------------------------------------------
def parse_ident_expr(&mut self) -> bool
{
    # Ensure we are at an `ident` token.
    if not self.expect(tokens.TOK_IDENTIFIER) { return false; }

    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_IDENT);
    let idente: ^ast.Ident = node.unwrap() as ^ast.Ident;

    # Store the text for the identifier.
    idente.name.extend(tokenizer.current_id.data() as str);

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Parenthetical expression
# -----------------------------------------------------------------------------
def parse_paren_expr(&mut self) -> bool
{
    # Consume the `(` token.
    self.pop_token();

    # Check for an immediate `)` token that would close an empty tuple.
    if self.peek_token(1) == tokens.TOK_RPAREN
    {
        # Consume the `)` token.
        self.pop_token();

        # Allocate and create the node for the tuple.
        # Return immediately.
        self.stack.push(ast.make(ast.TAG_TUPLE_EXPR));
        return true;
    }

    # Parse an expression node.
    if not self.parse_expr() { return false; }
    let node: ast.Node = self.stack.pop();

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

        # Enumerate until we reach the `)` token.
        while self.peek_token(1) <> tokens.TOK_RPAREN {
            # Parse an expression node.
            if not self.parse_expr() { return false; }
            expr.nodes.push(self.stack.pop());

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
                return false;
            }

            # Done here; too bad.
            break;
        }

        # Switch our node.
        node = tup_node;
    }

    # Expect a `)` token.
    self.expect(tokens.TOK_RPAREN);

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Array expression
# -----------------------------------------------------------------------------
def parse_array_expr(&mut self) -> bool
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_ARRAY_EXPR);
    let expr: ^ast.ArrayExpr = node.unwrap() as ^ast.ArrayExpr;

    # Consume the `[` token.
    self.pop_token();

    # Enumerate until we reach the `]` token.
    while self.peek_token(1) <> tokens.TOK_RBRACKET {
        # Parse an expression node.
        if not self.parse_expr() { return false; }
        expr.nodes.push(self.stack.pop());

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
            return false;
        }

        # Done here; too bad.
        break;
    }

    # Expect a `]` token.
    if not self.expect(tokens.TOK_RBRACKET) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Record expression
# -----------------------------------------------------------------------------
def parse_record_expr(&mut self) -> bool
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_RECORD_EXPR);
    let expr: ^ast.RecordExpr = node.unwrap() as ^ast.RecordExpr;

    # Consume the `{` token.
    self.pop_token();

    # Enumerate until we reach the `}` token.
    let mut error: bool = false;
    while self.peek_token(1) <> tokens.TOK_RBRACE {
        # Allocate and create a member node.
        let member_node: ast.Node = ast.make(ast.TAG_RECORD_EXPR_MEM);
        let member: ^ast.RecordExprMem =
            member_node.unwrap() as ^ast.RecordExprMem;

        if self.peek_token(1) <> tokens.TOK_IDENTIFIER {
            # Report the error.
            self.expect(tokens.TOK_IDENTIFIER);
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        # Parse the identifier.
        if not self.parse_ident_expr() { error = true; break; }
        member.id = self.stack.pop();

        # Expect a `:` token.
        if not self.expect(tokens.TOK_COLON) {
            self.consume_until(tokens.TOK_RBRACE);
            error = true; break;
        }

        # Parse an expression node.
        if not self.parse_expr() {
            self.consume_until(tokens.TOK_RBRACE);
            error = true; break;
        }
        member.expression = self.stack.pop();

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
            error = true; break;
        }

        # Done here; too bad.
        break;
    }

    if error { false; }
    else {
        # Expect a `}` token.
        if self.expect(tokens.TOK_RBRACE) {
            # Push our node on the stack.
            self.stack.push(node);

            # Return success.
            true;
        }
        else { false; }
    }
}

# Block expression
# -----------------------------------------------------------------------------
def parse_block_expr(&mut self) -> bool
{
    # Parse a brace expression.
    if not self.parse_brace_expr() { return false; }
    let mut node: ast.Node = self.stack.pop();

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
            return false;
        }
    }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Brace expression
# -----------------------------------------------------------------------------
def parse_brace_expr(&mut self) -> bool
{
    # Allocate and create the node.
    # Note that we assume we are a sequence until proven otherwise.
    let mut node: ast.Node = ast.make(ast.TAG_SEQ_EXPR);
    let expr: ^ast.SequenceExpr = node.unwrap() as ^ast.SequenceExpr;

    # Expect and consume the `{` token.
    if not self.expect(tokens.TOK_LBRACE) { return false; }

    # Iterate and attempt to match statements.
    while self.peek_token(1) <> tokens.TOK_RBRACE {
        # If we are still a sequence ...
        # ... and If we could possibly be an expression ...
        if  node.tag == ast.TAG_SEQ_EXPR
                and self._possible_expr(self.peek_token(1))
        {
            # Parse the expression node directly.
            if not self.parse_expr() {
                self.consume_until(tokens.TOK_RBRACE);
                return false;
            }

            # Push the expression node.
            expr.nodes.push(self.stack.pop());

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
                    return false;
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
                return false;
            }

            # We are a one-element sequence.
            break;
        }

        # Try and parse a node.
        if not self.parse_common_statement() {
            # Bad news.
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        } else {
            # Pop and push in.
            expr.nodes.push(self.stack.pop());
        }
    }

    # Expect and consume the `}` token.
    if not self.expect(tokens.TOK_RBRACE) {
        self.consume_until(tokens.TOK_RBRACE);
        return false;
    }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Global expression
# -----------------------------------------------------------------------------
def parse_global_expr(&mut self) -> bool
{
    # Consume the `global` token.
    self.pop_token();

    # Allocate and create the node.
    # Push our node on the stack.
    self.stack.push(ast.make(ast.TAG_GLOBAL));

    # Return success.
    true;
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
