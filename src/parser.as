import libc;
import ast;
import errors;
import list;
import types;
import tokenizer;
import tokens;

# Associative "enum"
# -----------------------------------------------------------------------------
let ASSOC_RIGHT: int = 1;
let ASSOC_LEFT: int = 2;

# Parser
# =============================================================================
type Parser {
    # Name of the top-level module
    mut name: str,

    # Tokenizer
    mut tokenizer: tokenizer.Tokenizer,

    # Token buffer.
    # Tokens get pushed as they are read from the input stream and popped
    # when consumed. This is implemented as a list so that we can
    # roll back the stream or insert additional tokens.
    mut tokens: list.List,

    # Node stack.
    # Nodes get pushed as they are realized and popped as consumed.
    mut stack: ast.Nodes
}

def parser_new(name: str, tokenizer_: tokenizer.Tokenizer) -> Parser {
    let parser: Parser;
    parser.tokenizer = tokenizer_;
    parser.tokens = list.make_generic(tokenizer.TOKEN_SIZE);
    parser.stack = ast.make_nodes();
    parser.name = name;
    parser;
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
        let tok: tokenizer.Token = self.tokenizer.next();
        self.tokens.push(&tok as ^void);
        n = n - 1;
    }
}

# Peek ahead N tokens.
# -----------------------------------------------------------------------------
def peek_token(&mut self, count: uint) -> tokenizer.Token {
    # Request more tokens if we need them.
    if count > self.tokens.size {
        self.push_tokens(count - self.tokens.size);
    }

    # Return the requested token.
    let tok: ^tokenizer.Token;
    tok = self.tokens.at((count as int) - (self.tokens.size as int) - 1) as
        ^tokenizer.Token;
    tok^;
}

# Peek ahead N token tags.
# -----------------------------------------------------------------------------
def peek_token_tag(&mut self, count: uint) -> int {
    let tok: tokenizer.Token = self.peek_token(count);
    tok.tag;
}

# Pop a token off the buffer.
# -----------------------------------------------------------------------------
def pop_token(&mut self) -> tokenizer.Token {
    # Get the requested token.
    let tok: tokenizer.Token = self.peek_token(1);

    # Erase the top token.
    self.tokens.erase(0);

    # Return the erased token.
    tok;
}

# Consume until `token`.
# -----------------------------------------------------------------------------
def consume_until(&mut self, token: int) {
    let mut tok: tokenizer.Token = self.pop_token();
    while       tok.tag <> token
            and tok.tag <> tokens.TOK_SEMICOLON
            and tok.tag <> tokens.TOK_END {
        tok = self.pop_token();
    }
}

# Expect a token (and report an error).
# -----------------------------------------------------------------------------
def expect(&mut self, req: int) -> bool {
    # Check if we are the expected token.
    let tok: tokenizer.Token = self.pop_token();
    if tok.tag == req {
        # Return success.
        true;
    } else {
        # Report error.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "expected %s but found %s" as ^int8,
                       tokens.to_str(req),
                       tokens.to_str(tok.tag));
        errors.end();

        # Return failure.
        false;
    }
}

# Empty the stack into the passed `nodes`.
# -----------------------------------------------------------------------------
def empty_stack_to(&mut self, &mut nodes: ast.Nodes)
{
    let mut i: int = 0;
    while i as uint < self.stack.size()
    {
        nodes.push(self.stack.get(i));
        i = i + 1;
    }
    self.stack.clear();
}

# Begin the parsing process.
# -----------------------------------------------------------------------------
def parse(&mut self) -> ast.Node {
    # Declare the top-level module decl node.
    let node: ast.Node = ast.make(ast.TAG_MODULE);
    let mod: ^ast.ModuleDecl = node.unwrap() as ^ast.ModuleDecl;

    # Set the name of the top-level module.
    mod.id = ast.make(ast.TAG_IDENT);
    let id: ^ast.Ident = mod.id.unwrap() as ^ast.Ident;
    id.name.extend(self.name);

    # Iterate and attempt to match items until the stream is empty.
    while self.peek_token_tag(1) <> tokens.TOK_END {
        # Try and parse a module node.
        if self.parse_module_node() {
            # Consume the parsed node and push it into the module.
            self.empty_stack_to(mod.nodes);
        } else {
            # Clear the node stack.
            self.stack.clear();
        }
    }

    # Return our node.
    node;
}

# Module
# -----------------------------------------------------------------------------
# module = "module" ident "{" { module-node } "}" ;
# -----------------------------------------------------------------------------
def parse_module(&mut self) -> bool
{
    # Declare the module decl node.
    let node: ast.Node = ast.make(ast.TAG_MODULE);
    let mod: ^ast.ModuleDecl = node.unwrap() as ^ast.ModuleDecl;

    # Pop the `module` token.
    self.pop_token();

    # Expect and parse and the identifier.
    if not self._expect_parse_ident_to(mod.id) {
        self.consume_until(tokens.TOK_RBRACE);
        return false;
    }

    # Expect and parse the `{` token.
    if not self.expect(tokens.TOK_LBRACE) {
        self.consume_until(tokens.TOK_RBRACE);
        return false;
    }

    # Iterate and attempt to match items until the stream is empty.
    while self.peek_token_tag(1) <> tokens.TOK_RBRACE
            and self.peek_token_tag(1) <> tokens.TOK_END {
        # Try and parse a module node.
        if self.parse_module_node() {
            # Consume the parsed node and push it into the module.
            self.empty_stack_to(mod.nodes);
        } else {
            # Clear the node stack.
            self.stack.clear();
        }
    }

    # Expect and parse the `}` token.
    if not self.expect(tokens.TOK_RBRACE) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Loop
# -----------------------------------------------------------------------------
# loop = "loop" block ;
# while = "while" expression block ;
# -----------------------------------------------------------------------------
def parse_loop(&mut self) -> bool {
    let node: ast.Node = ast.make(ast.TAG_LOOP);
    let loopN: ^ast.Loop = node.unwrap() as ^ast.Loop;

    # Pop the `loop` or `while` token.
    let tok: tokenizer.Token = self.pop_token();

    # Expect and parse the condition if we are a `while` loop.
    if tok.tag == tokens.TOK_WHILE
    {
        if not self.parse_expr(false) { return false; }
        loopN.condition = self.stack.pop();
    }

    # Expect and parse the block.
    if not self.parse_block_expr() { return false; }
    loopN.block = self.stack.pop();

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Unsafe
# -----------------------------------------------------------------------------
# unsafe = "unsafe" "{" { statement } "}" ;
# -----------------------------------------------------------------------------
def parse_unsafe(&mut self) -> bool
{
    # Declare the unsafe block.
    let mut node: ast.Node;

    # Pop the `unsafe` token.
    self.pop_token();

    # Parse a block.
    if not self.parse_block_expr() { return false; }
    node = self.stack.pop();

    # Make this an unsafe block.
    node._set_tag(ast.TAG_UNSAFE);

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}


# Module node
# -----------------------------------------------------------------------------
# module-node = module | common-statement ;
# -----------------------------------------------------------------------------
def parse_module_node(&mut self) -> bool {
    # Peek ahead and see if we are a module `item`.
    let tok: tokenizer.Token = self.peek_token(1);
    if tok.tag == tokens.TOK_MODULE { return self.parse_module(); }
    if tok.tag == tokens.TOK_EXTERN { return self.parse_extern(); }

    if tok.tag == tokens.TOK_SEMICOLON {
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
    let tok: tokenizer.Token = self.peek_token(1);
    if tok.tag == tokens.TOK_UNSAFE { return self.parse_unsafe(); }
    # if tok.tag == tokens.TOK_MATCH  { return self.parse_match(); }
    if tok.tag == tokens.TOK_LOOP   { return self.parse_loop(); }
    if tok.tag == tokens.TOK_WHILE  { return self.parse_loop(); }
    if tok.tag == tokens.TOK_IMPORT { return self.parse_import(); }
    if tok.tag == tokens.TOK_STRUCT { return self.parse_struct(); }
    # if tok.tag == tokens.TOK_ENUM   { return self.parse_enum(); }
    # if tok.tag == tokens.TOK_USE    { return self.parse_use(); }
    if tok.tag == tokens.TOK_IMPL     { return self.parse_impl(); }
    if tok.tag == tokens.TOK_RETURN   { return self.parse_return(); }
    if tok.tag == tokens.TOK_BREAK    { return self.parse_break(); }
    if tok.tag == tokens.TOK_CONTINUE { return self.parse_continue(); }

    if tok.tag == tokens.TOK_LET or tok.tag == tokens.TOK_STATIC
    {
        if self.parse_slot() { return self.expect(tokens.TOK_SEMICOLON); }
        return false;
    }

    if tok.tag == tokens.TOK_DEF {
        # Functions are only declarations if they are named.
        if self.peek_token_tag(2) == tokens.TOK_IDENTIFIER {
            return self.parse_function();
        }
    }

    if tok.tag == tokens.TOK_LBRACE {
        # Block expression is treated as if it appeared in a
        # function (no `item` may appear inside).
        return self.parse_block_expr();
    }

    # We could still be an expression; forward.
    if self.parse_expr(true) { self.expect(tokens.TOK_SEMICOLON); }
    else                     { false; }
}

# Break
# -----------------------------------------------------------------------------
def parse_break(&mut self) -> bool
{
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_BREAK);

    # Pop the `break` token.
    self.pop_token();

    # Expect a `;`.
    if not self.expect(tokens.TOK_SEMICOLON) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Continue
# -----------------------------------------------------------------------------
def parse_continue(&mut self) -> bool
{
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_CONTINUE);

    # Pop the `break` token.
    self.pop_token();

    # Expect a `;`.
    if not self.expect(tokens.TOK_SEMICOLON) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Return
# -----------------------------------------------------------------------------
def parse_return(&mut self) -> bool
{
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_RETURN);
    let expr: ^ast.ReturnExpr = node.unwrap() as ^ast.ReturnExpr;

    # Pop the `return` token.
    self.pop_token();

    # If we haven't been terminated, attempt to continue.
    let tok: tokenizer.Token = self.peek_token(1);
    if tok.tag <> tokens.TOK_SEMICOLON and tok.tag <> tokens.TOK_IF {
        # Parse the direct value expression.
        if not self.parse_cast_expr() { return false; }

        # Try and continue the unary expression as a binary expression.
        if not self.parse_binop_rhs(0, 0, false) { return false; }
        expr.expression = self.stack.pop();
    }

    # Push our node.
    self.stack.push(node);

    if tok.tag <> tokens.TOK_SEMICOLON
    {
        # Parse the remainder of the `return` expression (capturing those
        # now allowed binary operators like `if`).
        if not self.parse_binop_rhs(0, 0, true) { return false; }

        # Expect a `;`.
        self.expect(tokens.TOK_SEMICOLON);
    }
    else {
        # Pop the `;` token.
        self.pop_token();

        # Return success.
        true;
    }
}

# Function declaration
# -----------------------------------------------------------------------------
def parse_function(&mut self) -> bool
{
    # Declare the function decl node.
    let node: ast.Node = ast.make(ast.TAG_FUNC_DECL);
    let decl: ^ast.FuncDecl = node.unwrap() as ^ast.FuncDecl;

    # Pop the `def` token.
    self.pop_token();

    # Expect an `identifier` next.
    if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
        self.expect(tokens.TOK_IDENTIFIER);
        return false;
    }

    # Parse and set the identifier (this shouldn't fail).
    if not self.parse_ident() { return false; }
    decl.id = self.stack.pop();

    # Check for and parse type type parameters.
    if not self.parse_type_params(decl.type_params) { return false; }

    # Parse the parameter list.
    if not self.parse_function_params(decl, true, false) {
        return false;
    }

    # Check for a return type annotation which would again
    # be preceeded by a `:` token.
    if self.peek_token_tag(1) == tokens.TOK_COLON
    {
        # Pop the `:` token.
        self.pop_token();

        # Parse and set the type.
        if not self.parse_type() { return false; }
        decl.return_type = self.stack.pop();
    }

    # Parse the function block next.
    if not self.parse_block_expr() { return false; }
    decl.block = self.stack.pop();

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Function parameter list
# -----------------------------------------------------------------------------
def parse_function_params(&mut self, fn: ^ast.FuncDecl,
                          require_names: bool,
                          self_: bool) -> bool
{
    # Expect a `(` token to start the parameter list.
    if not self.expect(tokens.TOK_LPAREN) { return false; }

    # Iterate through and parse each parameter.
    let mut idx: uint = 0;
    let found_self: bool = false;
    while self.peek_token_tag(1) <> tokens.TOK_RPAREN
    {
        # If we are allowed to have "self" ..
        if self_ and idx == 0 {
            # Check for `mut self` or `self` sequences.
            let found: bool = false;
            if self.peek_token_tag(1) == tokens.TOK_MUT and
               self.peek_token_tag(2) == tokens.TOK_SELF
            {
                # Found mutable self
                fn.instance = true;
                fn.mutable = true;
                self.pop_token();
                self.pop_token();
                found = true;
            }
            else if self.peek_token_tag(1) == tokens.TOK_SELF
            {
                # Found self
                fn.instance = true;
                fn.mutable = false;
                self.pop_token();
                found = true;
            }
            if found {
                # Peek and consume the `,` token if present; else, consume
                # tokens until we reach the `)`.
                if self._expect_sequence_continue(tokens.TOK_RPAREN) {
                    continue; }
                return false;
            }
        }

        # Parse the parameter.
        if not self.parse_function_param(require_names) { return false; }
        fn.params.push(self.stack.pop());

        # Push the idx counter.
        idx = idx + 1;

        # Peek and consume the `,` token if present; else, consume
        # tokens until we reach the `)`.
        if self._expect_sequence_continue(tokens.TOK_RPAREN) { continue; }
        return false;
    }

    # Expect a `)` token to close the parameter list.
    if not self.expect(tokens.TOK_RPAREN) { return false; }

    # Return success.
    true;
}

# Function parameter
# -----------------------------------------------------------------------------
def parse_function_param(&mut self, require_name: bool) -> bool
{
    # Declare the function param node.
    let node: ast.Node = ast.make(ast.TAG_FUNC_PARAM);
    let param: ^ast.FuncParam = node.unwrap() as ^ast.FuncParam;

    # Check for a `mut` token which would make the slot mutable.
    if self.peek_token_tag(1) == tokens.TOK_MUT
    {
        # Pop the `mut` token.
        self.pop_token();

        # Make the slot mutable.
        param.mutable = true;
    }

    if require_name
    {
        # Expect an `identifier` next.
        if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
            self.expect(tokens.TOK_IDENTIFIER);
            return false;
        }

        # Parse and set the identifier (this shouldn't fail).
        if not self.parse_ident() { return false; }
        param.id = self.stack.pop();

        # Check for a type annotation which would be preceeded by a `:` token.
        if self.peek_token_tag(1) == tokens.TOK_COLON
        {
            # Pop the `:` token.
            self.pop_token();

            # Parse and set the type.
            if not self.parse_type() { return false; }
            param.type_ = self.stack.pop();
        }
    }
    else
    {
        # Check for an `identifier` `:` sequence.
        if self.peek_token_tag(1) == tokens.TOK_IDENTIFIER and
                self.peek_token_tag(2) == tokens.TOK_COLON
        {
            # Parse and set the identifier (this shouldn't fail).
            if not self.parse_ident() { return false; }
            param.id = self.stack.pop();

            # Pop the `:` token.
            self.pop_token();

        }

        # Parse and set the type.
        if not self.parse_type() { return false; }
        param.type_ = self.stack.pop();
    }

    # Check for an default which would be preceeded by a `=` token.
    if self.peek_token_tag(1) == tokens.TOK_EQ
    {
        # Pop the `=` token.
        self.pop_token();

        # Parse and set the default.
        if not self.parse_expr(false) { return false; }
        param.default = self.stack.pop();
    }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Expression
# -----------------------------------------------------------------------------
# expr = unary-expr | binop-rhs ;
# -----------------------------------------------------------------------------
def parse_expr(&mut self, statement: bool) -> bool {
    # Try and parse a unary expression.
    if not self.parse_cast_expr() { return false; }

    # Try and continue the unary expression as a binary expression.
    self.parse_binop_rhs(0, 0, statement);

    # TODO: Try and continue the binary expression into a postfix
    #   control flow statement.
}

# (Possible) Cast Expression
# -----------------------------------------------------------------------------
def parse_cast_expr(&mut self) -> bool {
    # Attempt to parse the `operand` as a unary expression.
    if not self.parse_unary_expr() { return false; }

    # Are we a `cast` expression.
    if self.peek_token_tag(1) <> tokens.TOK_AS {
        # No; just return the unary expression.
        return true;
    }

    # Declare and allocate the node.
    let node: ast.Node = ast.make(ast.TAG_CAST);
    let expr: ^ast.CastExpr = node.unwrap() as ^ast.CastExpr;
    expr.operand = self.stack.pop();

    # Pop the `as` token.
    self.pop_token();

    # Try and parse a type expression as the target type.
    if not self.parse_type() {
        self.consume_until(tokens.TOK_SEMICOLON);
        return false;
    }

    expr.type_ = self.stack.pop();

    # Push our operand.
    self.stack.push(node);

    # Return success.
    true;
}

# Binary expression
# -----------------------------------------------------------------------------
# binary-expr = unary-expr binary-op unary-expr ;
# binary-op  = "+"  | "-"  | "*"  | "/"  | "%"  | "and" | "or" | "==" | "!="
#            | ">"  | "<"  | "<=" | ">=" | "="  | ":="  | "+=" | "-=" | "*="
#            | "/=" | "%=" | "if" | "."  | "//" | "//="
# -----------------------------------------------------------------------------
def parse_binop_rhs(&mut self, mut expr_prec: int, mut expr_assoc: int,
                    statement: bool) -> bool {
    loop {
        # Get the token precedence (if it is a binary operator token).
        let tok: tokenizer.Token = self.peek_token(1);
        let tok_prec: int = self.get_binop_tok_precedence(tok.tag);
        let tok_assoc: int = self.get_binop_tok_associativity(tok.tag);

        # If the stack is too full; get out.
        if self.stack.size() > 1 { return true; }

        # If the proceeding token is not a binary operator token
        # or the token binds less tightly and is left-associative,
        # get out of the precedence parser.
        if tok_prec == -1 { return true; }
        if tok_prec < expr_prec and expr_assoc == ASSOC_LEFT { return true; }

        if tok.tag == tokens.TOK_IF
        {
            # An expression of the form `x if y` may be a postfix control
            # flow statement or the beginning of a ternary expression that
            # can be continued in the expression chain.

            # Parse the <if {condition} ...> as a postfix selection
            # statement. If it only sees <if {condition}> it will pop
            # the LHS and apply a `SelectOp` on it.
            # If it sees <if {condition} else {y}> it will pop the
            # LHS and apply a `ConditionalExpr` on it. It it sees
            # a complete <if-expression> then it will partition if the
            # LHS can stand alone.
            if self.parse_postfix_selection()
            {
                # If an expression of the form <{x} if {condition} else {y}>
                # is what remains then this could possibly continue.
                let top: ast.Node = self.stack.get(-1);
                if top.tag == ast.TAG_CONDITIONAL
                {
                    # Try and continue the expression.
                    return self.parse_binop_rhs(
                        tok_prec + 1, tok_assoc, statement);
                }

                # If this is not a coinditional and this is not a
                # statement; this cannot be a select-op.
                if not statement and top.tag == ast.TAG_SELECT_OP
                {
                    errors.begin_error();
                    errors.libc.fprintf(errors.libc.stderr,
                                   "unexpected postfix selection statement" as ^int8);
                    errors.end();

                    # Return failure.
                    return false;
                }

                # Return success.
                return true;
            }

            # Return failure.
            return false;
        }

        # Pop the LHS from the stack.
        let lhs: ast.Node = self.stack.pop();

        # We know this is a normal binary operator.
        self.pop_token();

        # Parse the RHS of this expression.
        if not self.parse_cast_expr() { return false; }

        # If the binary operator binds less tightly with RHS than the
        # operator after RHS, let the pending operator take RHS as its LHS.
        let nprec: int = self.get_binop_tok_precedence(self.peek_token_tag(1));
        if tok_prec < nprec or (tok_assoc == ASSOC_RIGHT and tok_prec == nprec)
        {
            if not self.parse_binop_rhs(tok_prec + 1, tok_assoc, statement)
            {
                return false;
            }
        }

        # Pop the RHS from the stack.
        let rhs: ast.Node = self.stack.pop();

        # We have a complete binary expression.
        # Determine the AST tag.
        let tag: int = self.get_binop_tok_tag(tok.tag);
        if tag <> 0
        {
            # Merge LHS/RHS into a binary expression node.
            let node: ast.Node = ast.make(tag);
            let expr: ^ast.BinaryExpr = ast.unwrap(node) as ^ast.BinaryExpr;
            expr.lhs = lhs;
            expr.rhs = rhs;

            # Push our node on the stack.
            self.stack.push(node);
        }
    }

    # Should never reach here normally.
    false;
}

# Postfix selection
# -----------------------------------------------------------------------------
def parse_postfix_selection(&mut self) -> bool
{
    # Pop the LHS (or selection body) from the stack.
    let lhs: ast.Node = self.stack.pop();

    # Pop the `if` token.
    self.pop_token();

    # Attempt to parse a condition expression.
    if not self.parse_expr(false) { return false; }
    let condition: ast.Node = self.stack.pop();

    # Is there a `{` token following (if so we could very well be
    # a full selection expression)?
    if self.peek_token_tag(1) == tokens.TOK_LBRACE
    {
        # It is an error to have a full selection expression in
        # the postfix space.
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "unexpected selection statement" as ^int8);
        errors.end();

        # Return failure.
        return false;
    }

    # Else is there a `else` directly following, then this is a
    # conditional expression.
    if self.peek_token_tag(1) == tokens.TOK_ELSE
    {
        # Merge into a conditional expression.
        let node: ast.Node = ast.make(ast.TAG_CONDITIONAL);
        let expr: ^ast.ConditionalExpr = ast.unwrap(node) as ^ast.ConditionalExpr;
        expr.lhs = lhs;
        expr.condition = condition;

        # Consume the "else" token.
        self.pop_token();

        # Parse the RHS (or false case).
        let res: bool = self.parse_expr(false);
        if not res { return false; }
        expr.rhs = self.stack.pop();

        # Push our node on the stack.
        self.stack.push(node);

        # Return success.
        return true;
    }

    # Merge into a postfix selection operation.
    let node: ast.Node = ast.make(ast.TAG_SELECT_OP);
    let expr: ^ast.BinaryExpr = ast.unwrap(node) as ^ast.BinaryExpr;
    expr.lhs = lhs;
    expr.rhs = condition;

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
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
    let tok: tokenizer.Token = self.peek_token(1);
    if tok.tag <> tokens.TOK_PLUS
        and tok.tag <> tokens.TOK_MINUS
        and tok.tag <> tokens.TOK_NOT
        and tok.tag <> tokens.TOK_BANG
        and tok.tag <> tokens.TOK_STAR
        and tok.tag <> tokens.TOK_AMPERSAND
    {
        return self.parse_postfix_expr();
    }

    # Is this an address-of expression then carry on a bit differently.
    if tok.tag == tokens.TOK_AMPERSAND
    {
        return self.parse_address_of_expr();
    }

    # This -is- a unary expression; carry on.
    self.pop_token();

    # Parse the operand of this expression.
    if not self.parse_unary_expr() { return false; }
    let operand: ast.Node = self.stack.pop();

    # Determine the AST tag for this unary expression.
    # FIXME: Replace with a HashMap<int, int> when available
    let tag: int =
        if      tok.tag == tokens.TOK_PLUS  { ast.TAG_PROMOTE; }
        else if tok.tag == tokens.TOK_MINUS { ast.TAG_NUMERIC_NEGATE; }
        else if tok.tag == tokens.TOK_NOT   { ast.TAG_LOGICAL_NEGATE; }
        else if tok.tag == tokens.TOK_BANG  { ast.TAG_BITNEG; }
        else if tok.tag == tokens.TOK_STAR  { ast.TAG_DEREF; }
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

# Address-of expression
# -----------------------------------------------------------------------------
def parse_address_of_expr(&mut self) -> bool {
    # Pop the `&` token.
    self.pop_token();

    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_ADDRESS_OF);
    let expr: ^ast.AddressOfExpr = node.unwrap() as ^ast.AddressOfExpr;

    # Is there a 'mut' next to indicate a mutable address-of?
    if self.peek_token_tag(1) == tokens.TOK_MUT
    {
        # Set us as mutable.
        expr.mutable = true;

        # Pop the `mut` token.
        self.pop_token();
    }

    # Parse the operand of this expression.
    if not self.parse_unary_expr() { return false; }
    expr.operand = self.stack.pop();

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
def parse_postfix_expr(&mut self) -> bool
{
    # Attempt to parse the `operand` as a primary expression.
    if not self.parse_primary_expr() { return false; }

    # Can we possibly consume this as a postfix expression ?
    let tok: tokenizer.Token = self.peek_token(1);
    if     tok.tag == tokens.TOK_LPAREN     # Call expression
        or tok.tag == tokens.TOK_LBRACKET   # Index expression
        or tok.tag == tokens.TOK_DOT        # Member expression
    {
        if not self.parse_postfix_expr_operand()
        {
            return false;
        }
    }

    # Push our node on the stack.
    self.stack.push(self.stack.pop());

    # Return success.
    true;
}

def parse_postfix_expr_operand(&mut self) -> bool
{
    # Recurse downwards depending on our token.
    let tok: tokenizer.Token = self.peek_token(1);
    if tok.tag == tokens.TOK_LPAREN
    {
        if not self.parse_call_expr() { return false; }
    }
    else if tok.tag == tokens.TOK_DOT
    {
        if not self.parse_member_expr() { return false; }
    }
    else if tok.tag == tokens.TOK_LBRACKET
    {
        if not self.parse_index_expr() { return false; }
    }

    # Should we continue the postfix expression?
    let tok: tokenizer.Token = self.peek_token(1);
    if     tok.tag == tokens.TOK_LPAREN     # Call expression
        or tok.tag == tokens.TOK_LBRACKET   # Index expression
        or tok.tag == tokens.TOK_DOT        # Member expression
    {
        if not self.parse_postfix_expr_operand()
        {
            return false;
        }
    }

    # Return success.
    true;
}

# Call expression
# -----------------------------------------------------------------------------
def parse_call_expr(&mut self) -> bool
{
    # Declare and allocate the node.
    let node: ast.Node = ast.make(ast.TAG_CALL);
    let expr: ^ast.CallExpr = node.unwrap() as ^ast.CallExpr;

    # Pop the expression in the stack as our expression.
    expr.expression = self.stack.pop();

    # Pop the `(` token.
    self.pop_token();

    # Enumerate until we reach the `)` token.
    let mut in_named_args: bool = false;
    while self.peek_token_tag(1) <> tokens.TOK_RPAREN {
        # Declare the argument node.
        let arg_node: ast.Node = ast.make(ast.TAG_CALL_ARG);
        let arg: ^ast.Argument = ast.unwrap(arg_node) as ^ast.Argument;

        # This is a named argument if we have a ( `ident` `:` ) sequence.
        if      self.peek_token_tag(1) == tokens.TOK_IDENTIFIER
            and self.peek_token_tag(2) == tokens.TOK_COLON
        {
            # Expect and parse the identifier.
            if not self._expect_parse_ident_to(arg.name) {
                self.consume_until(tokens.TOK_RPAREN);
                return false;
            }

            # Pop the `:` token.
            self.pop_token();

            # Mark that we have entered the land of named arguments.
            in_named_args = true;
        }
        else if in_named_args
        {
            # If we didn't get a named argument but are in the
            # land of named arguments throw an error.
            self.consume_until(tokens.TOK_RPAREN);

            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr, "non-keyword argument after keyword argument" as ^int8);
            errors.end();

            return false;
        }

        # Parse an expression node for the argument.
        if not self.parse_expr(false) { return false; }
        arg.expression = self.stack.pop();

        # Push the argument into our arguments collection.
        expr.arguments.push(arg_node);

        # Peek and consume the `,` token if present; else, consume
        # tokens until we reach the `)`.
        if self._expect_sequence_continue(tokens.TOK_RPAREN) { continue; }
        return false;
    }

    # Expect a `)` token.
    if not self.expect(tokens.TOK_RPAREN) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Index expression
# -----------------------------------------------------------------------------
def parse_index_expr(&mut self) -> bool {
    # Declare and allocate the node.
    let node: ast.Node = ast.make(ast.TAG_INDEX);
    let expr: ^ast.IndexExpr = node.unwrap() as ^ast.IndexExpr;

    # Pop the expression in the stack as our expression.
    expr.expression = self.stack.pop();

    # Pop the `[` token.
    self.pop_token();

    # Parse an expression node for the argument.
    if not self.parse_expr(false) { return false; }
    expr.subscript = self.stack.pop();

    # Expect a `]` token.
    if not self.expect(tokens.TOK_RBRACKET) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Pointer type
# -----------------------------------------------------------------------------
def parse_pointer_type(&mut self) -> bool
{
    # This is a pointer-to the next type.
    # Declare and allocate the node.
    let mut node: ast.Node = ast.make(ast.TAG_POINTER_TYPE);
    let expr: ^ast.PointerType = node.unwrap() as ^ast.PointerType;

    # Pop the `*` token.
    self.pop_token();

    # Check for a `mut` token and make the pointee mutable.
    if self.peek_token_tag(1) == tokens.TOK_MUT
    {
        # Set us as mutable.
        expr.mutable = true;

        # Pop the `mut` token.
        self.pop_token();
    }

    # Attempt to parse a type next.
    if not self.parse_type() { return false; }
    expr.pointee = self.stack.pop();

    # Push our pointer node.
    self.stack.push(node);

    # Return success.
    true;
}

# Array type
# -----------------------------------------------------------------------------
def parse_array_type(&mut self) -> bool
{
    # This is an array of the previous type node.
    # Declare and allocate the node.
    let mut node: ast.Node = ast.make(ast.TAG_ARRAY_TYPE);
    let expr: ^ast.ArrayType = node.unwrap() as ^ast.ArrayType;

    # Pop the previous type node as our primary element type.
    expr.element = self.stack.pop();

    # Pop the `[` token.
    self.pop_token();

    # Attempt to parse the size expression next.
    if not self.parse_expr(false) { return false; }
    expr.size = self.stack.pop();

    # Expect a `]` token.
    if not self.expect(tokens.TOK_RBRACKET) { return false; }

    # Push our pointer node.
    self.stack.push(node);

    # Attempt to continue the type expression with "[" to
    # mean an array type.
    if self.peek_token_tag(1) == tokens.TOK_LBRACKET { self.parse_array_type(); }
    else { true; }
}

# Paren Type
# -----------------------------------------------------------------------------
def parse_paren_type(&mut self) -> bool
{
    # Consume the `(` token.
    self.pop_token();

    # Check for an immediate `)` token that would close an empty tuple.
    if self.peek_token_tag(1) == tokens.TOK_RPAREN
    {
        # Consume the `)` token.
        self.pop_token();

        # Allocate and create the node for the tuple.
        # Return immediately.
        self.stack.push(ast.make(ast.TAG_TUPLE_TYPE));
        return true;
    }

    # Check for a { "identifier" `:` } sequence that indicates a tuple (and
    # the initial member named).
    let mut in_tuple: bool = false;
    let mut node: ast.Node;
    if      self.peek_token_tag(1) == tokens.TOK_IDENTIFIER
        and self.peek_token_tag(2) == tokens.TOK_COLON
    {
        # Declare we are in a tuple (to continue parsing).
        in_tuple = true;

        # Allocate and create a tuple member node.
        node = ast.make(ast.TAG_TUPLE_TYPE_MEM);
        let mem: ^ast.TupleExprMem = node.unwrap() as ^ast.TupleExprMem;

        # Parse an identifier.
        if not self.parse_ident() { return false; }
        mem.id = self.stack.pop();

        # Pop the `:` token.
        self.pop_token();

        # Parse an expression node.
        if not self.parse_type() { return false; }
        mem.expression = self.stack.pop();
    }
    # Check for a { ":" "identifier" } sequence that indicates a tuple (and
    # the initial member named).
    else if self.peek_token_tag(1) == tokens.TOK_COLON
        and self.peek_token_tag(2) == tokens.TOK_IDENTIFIER
    {
        # Declare we are in a tuple (to continue parsing).
        in_tuple = true;

        # Allocate and create a tuple member node.
        node = ast.make(ast.TAG_TUPLE_TYPE_MEM);
        let mem: ^ast.TupleTypeMem = node.unwrap() as ^ast.TupleTypeMem;

        # Pop the `:` token.
        self.pop_token();

        # Parse an identifier.
        if not self.parse_ident() { return false; }
        mem.id = self.stack.pop();

        # Push the identifier as the expression.
        mem.type_ = mem.id;
    }
    # Could be a tuple with an initial member unnamed or just a
    # parenthetical expression.
    else
    {
        # Parse an expression node.
        if not self.parse_type() { return false; }

        # Check for a comma that would make this a tuple.
        if self.peek_token_tag(1) == tokens.TOK_COMMA
        {
            # Declare we are in a tuple (to continue parsing).
            in_tuple = true;

            # Allocate and create a tuple member node.
            node = ast.make(ast.TAG_TUPLE_TYPE_MEM);
            let mem: ^ast.TupleTypeMem = node.unwrap() as ^ast.TupleTypeMem;

            # Switch the node with the member node.
            mem.type_ = self.stack.pop();
        }
        else
        {
            # Switch the node with the member node.
            node = self.stack.pop();
        }
    }

    # Continue parsing if we are a tuple.
    if in_tuple
    {
        # Allocate and create the node for the tuple.
        let tup_node: ast.Node = ast.make(ast.TAG_TUPLE_TYPE);
        let expr: ^ast.TupleType = tup_node.unwrap() as ^ast.TupleType;

        # Push the initial node.
        expr.nodes.push(node);

        if self.peek_token_tag(1) == tokens.TOK_COMMA
        {
            # Pop the `,` token and continue the tuple.
            self.pop_token();

            # Enumerate until we reach the `)` token.
            while self.peek_token_tag(1) <> tokens.TOK_RPAREN {
                # Allocate and create a tuple member node.
                let mem_node: ast.Node = ast.make(ast.TAG_TUPLE_TYPE_MEM);
                let mem: ^ast.TupleTypeMem =
                    mem_node.unwrap() as ^ast.TupleTypeMem;

                # Check for a { "identifier" `:` } sequence that indicates
                # a named member.
                if      self.peek_token_tag(1) == tokens.TOK_IDENTIFIER
                    and self.peek_token_tag(2) == tokens.TOK_COLON
                {
                    # Parse an identifier.
                    if not self.parse_ident_expr() { return false; }
                    mem.id = self.stack.pop();

                    # Pop the `:` token.
                    self.pop_token();

                    # Parse an expression node.
                    if not self.parse_type() { return false; }
                    mem.type_ = self.stack.pop();
                }
                # Check for a { `:` "identifier" } sequence that indicates
                # a named member and expression (shorthand).
                else if self.peek_token_tag(1) == tokens.TOK_COLON
                    and self.peek_token_tag(2) == tokens.TOK_IDENTIFIER
                {
                    # Pop the `:` token.
                    self.pop_token();

                    # Parse an identifier.
                    if not self.parse_ident_expr() { return false; }
                    mem.id = self.stack.pop();
                    mem.type_ = mem.id;
                }
                else
                {
                    # Parse an expression node.
                    if not self.parse_type() { return false; }
                    mem.type_ = self.stack.pop();
                }

                # Push the node.
                expr.nodes.push(mem_node);

                # Peek and consume the `,` token if present; else, consume
                # tokens until we reach the `)`.
                if self._expect_sequence_continue(tokens.TOK_RPAREN) {
                    continue; }
                return false;
            }
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

# Delegate Type
# -----------------------------------------------------------------------------
def parse_delegate_type(&mut self) -> bool
{
    # Declare and allocate the node.
    let mut node: ast.Node = ast.make(ast.TAG_DELEGATE);
    let expr: ^ast.Delegate = node.unwrap() as ^ast.Delegate;

    # Consume the `delegate` token.
    self.pop_token();

    # Parse the parameter list.
    if not self.parse_function_params(expr as ^ast.FuncDecl, false, false) {
        return false;
    }

    # Check for a return type which would
    # be preceeded by a `->` token.
    if self.peek_token_tag(1) == tokens.TOK_RARROW
    {
        # Pop the `->` token.
        self.pop_token();

        # Parse and set the type.
        if not self.parse_type() { return false; }
        expr.return_type = self.stack.pop();
    }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Type
# -----------------------------------------------------------------------------
# type = path | tuple-type | function-type | array-type ;
# tuple-type = "(" path "," ")"
#            | "(" path { "," path } [ "," ] ")" ;
# -----------------------------------------------------------------------------
def parse_type(&mut self) -> bool
{
    # Check if we are a `type(..)` expression.
    let tok: tokenizer.Token = self.peek_token(1);
    if tok.tag == tokens.TOK_TYPE { return self.parse_type_expr(); }

    # Delegate based on what we are.
    let rv: bool =
        if      tok.tag == tokens.TOK_IDENTIFIER { self.parse_ident_expr(); }
        else if tok.tag == tokens.TOK_LPAREN     { self.parse_paren_type(); }
        else if tok.tag == tokens.TOK_DELEGATE   { self.parse_delegate_type(); }
        else if tok.tag == tokens.TOK_STAR       { self.parse_pointer_type(); }
        else
        {
            # Expected some kind of type expression node.
            self.consume_until(tokens.TOK_SEMICOLON);
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "expected %s, %s, %s or %s but found %s" as ^int8,
                           tokens.to_str(tokens.TOK_STAR),
                           tokens.to_str(tokens.TOK_IDENTIFIER),
                           tokens.to_str(tokens.TOK_LPAREN),
                           tokens.to_str(tokens.TOK_DELEGATE),
                           tokens.to_str(tok.tag));
            errors.end();

            # Return failure.
            false;
        };
    if not rv { return false; }

    # Attempt to continue the type expression with "[" to
    # mean an array type.
    if self.peek_token_tag(1) == tokens.TOK_LBRACKET { self.parse_array_type(); }
    else { true; }
}

# Type expression
# -----------------------------------------------------------------------------
def parse_type_expr(&mut self) -> bool
{
    # Declare and allocate the node.
    let mut node: ast.Node = ast.make(ast.TAG_TYPE_EXPR);
    let expr: ^ast.TypeExpr = node.unwrap() as ^ast.TypeExpr;

    # Pop the `type` token.
    self.pop_token();

    # Check if we have a `(` next.
    if self.peek_token_tag(1) <> tokens.TOK_LPAREN
    {
        # We are actually a type box.
        node._set_tag(ast.TAG_TYPE_BOX);
    }
    else
    {
        # Expect a `(` token to open the expression.
        if not self.expect(tokens.TOK_LPAREN) { return false; }

        # Try to parse a general expression.
        if not self.parse_expr(false) { return false; }
        expr.expression = self.stack.pop();

        # Expect a `)` token to close the expression.
        if not self.expect(tokens.TOK_RPAREN) { return false; }
    }

    # Push our node.
    self.stack.push(node);

    # Return success.
    true;
}

# Member expression
# -----------------------------------------------------------------------------
def parse_member_expr(&mut self) -> bool
{
    # Declare and allocate the node.
    let node: ast.Node = ast.make(ast.TAG_MEMBER);
    let expr: ^ast.BinaryExpr = node.unwrap() as ^ast.BinaryExpr;

    # Pop the operand in the stack as our operand.
    expr.lhs = self.stack.pop();

    # Pop the `.` token.
    self.pop_token();

    # Expect and parse the identifier.
    if not self._expect_parse_ident_to(expr.rhs) { return false; }

    # Push our operand.
    self.stack.push(node);

    # Return success.
    true;
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
    let tok: tokenizer.Token = self.peek_token(1);
    if     tok.tag == tokens.TOK_BIN_INTEGER
        or tok.tag == tokens.TOK_OCT_INTEGER
        or tok.tag == tokens.TOK_DEC_INTEGER
        or tok.tag == tokens.TOK_HEX_INTEGER
    {
        self.parse_integer_expr();
    }
    else if tok.tag == tokens.TOK_FLOAT
    {
        self.parse_float_expr();
    }
    else if tok.tag == tokens.TOK_TRUE or tok.tag == tokens.TOK_FALSE
    {
        self.parse_bool_expr();
    }
    else if tok.tag == tokens.TOK_STRING
    {
        self.parse_string_expr();
    }
    else if tok.tag == tokens.TOK_LPAREN
    {
        self.parse_paren_expr();
    }
    else if tok.tag == tokens.TOK_LBRACKET
    {
        self.parse_array_expr();
    }
    else if tok.tag == tokens.TOK_IDENTIFIER
    {
        self.parse_ident();
    }
    else if tok.tag == tokens.TOK_TYPE
    {
        self.parse_type_expr();
    }
    else if tok.tag == tokens.TOK_GLOBAL
    {
        self.parse_global_expr();
    }
    else if tok.tag == tokens.TOK_SELF
    {
        self.parse_self_expr();
    }
    else if tok.tag == tokens.TOK_IF
    {
        self.parse_select_expr();
    }
    else if tok.tag == tokens.TOK_LBRACE
    {
        # This is some kind of block.
        self.parse_block_expr();
    }
    else
    {
        # Consume erroneous token.
        self.pop_token();

        # Not an expression; diagnose possible problems.
        if tok.tag == tokens.TOK_RETURN or tok.tag == tokens.TOK_COMMA
        {
            # Print error.
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr, "unexpected %s" as ^int8,
                           tokens.to_str(tok.tag));
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
    let tok: tokenizer.Token = self.peek_token(1);
    inte.base =
        if      tok.tag == tokens.TOK_DEC_INTEGER { 10; }
        else if tok.tag == tokens.TOK_HEX_INTEGER { 16; }
        else if tok.tag == tokens.TOK_OCT_INTEGER { 8; }
        else if tok.tag == tokens.TOK_BIN_INTEGER { 2; }
        else { 0; };  # NOTE: Not possible to get here

    # Store the text for the integer literal.
    inte.text.extend(tok.text.data() as str);

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
    let tok: tokenizer.Token = self.pop_token();
    inte.text.extend(tok.text.data() as str);

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
    boole.value = self.peek_token_tag(1) == tokens.TOK_TRUE;
    self.pop_token();

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# String expression
# -----------------------------------------------------------------------------
def parse_string_expr(&mut self) -> bool
{
    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_STRING);
    let expr: ^ast.StringExpr = node.unwrap() as ^ast.StringExpr;

    # Store the text for the string literal.
    let tok: tokenizer.Token = self.pop_token();
    expr.text.extend(tok.text.data() as str);

    # Iterate and consume any adjacent strings.
    loop
    {
        # Get next token.
        tok = self.peek_token(1);
        if tok.tag <> tokens.TOK_STRING { break; }

        # Store the text for the string literal.
        expr.text.extend(tok.text.data() as str);

        # Consume our token.
        self.pop_token();
    }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Identifier
# -----------------------------------------------------------------------------
def parse_ident(&mut self) -> bool
{
    # Ensure we are at an `ident` token.
    let tok: tokenizer.Token = self.peek_token(1);
    if not self.expect(tokens.TOK_IDENTIFIER) { return false; }

    # Allocate and create the node.
    let node: ast.Node = ast.make(ast.TAG_IDENT);
    let idente: ^ast.Ident = node.unwrap() as ^ast.Ident;

    # Store the text for the identifier.
    idente.name.extend(tok.text.data() as str);

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Identifier expression
# -----------------------------------------------------------------------------
def parse_ident_expr(&mut self) -> bool
{
    # Attempt to parse an identifier.
    if not self.parse_ident() { return false; }

    # Try to consume a member expression into the identifier (eg. ".Point")
    while self.peek_token_tag(1) == tokens.TOK_DOT
            and self.peek_token_tag(2) == tokens.TOK_IDENTIFIER {
        # Pop the `.` token.
        self.pop_token();

        # Parse the next identifier.
        if not self.parse_ident() { return false; }

        # Construct and push a member expression.
        let node: ast.Node = ast.make(ast.TAG_MEMBER);
        let expr: ^ast.BinaryExpr = node.unwrap() as ^ast.BinaryExpr;
        expr.rhs = self.stack.pop();
        expr.lhs = self.stack.pop();
        self.stack.push(node);
    }

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
    if self.peek_token_tag(1) == tokens.TOK_RPAREN
    {
        # Consume the `)` token.
        self.pop_token();

        # Allocate and create the node for the tuple.
        # Return immediately.
        self.stack.push(ast.make(ast.TAG_TUPLE_EXPR));
        return true;
    }

    # Check for a { "identifier" `:` } sequence that indicates a tuple (and
    # the initial member named).
    let mut in_tuple: bool = false;
    let mut node: ast.Node;
    if      self.peek_token_tag(1) == tokens.TOK_IDENTIFIER
        and self.peek_token_tag(2) == tokens.TOK_COLON
    {
        # Declare we are in a tuple (to continue parsing).
        in_tuple = true;

        # Allocate and create a tuple member node.
        node = ast.make(ast.TAG_TUPLE_EXPR_MEM);
        let mem: ^ast.TupleExprMem = node.unwrap() as ^ast.TupleExprMem;

        # Parse an identifier.
        if not self.parse_ident() { return false; }
        mem.id = self.stack.pop();

        # Pop the `:` token.
        self.pop_token();

        # Parse an expression node.
        if not self.parse_expr(false) { return false; }
        mem.expression = self.stack.pop();
    }
    # Check for a { ":" "identifier" } sequence that indicates a tuple (and
    # the initial member named).
    else if self.peek_token_tag(1) == tokens.TOK_COLON
        and self.peek_token_tag(2) == tokens.TOK_IDENTIFIER
    {
        # Declare we are in a tuple (to continue parsing).
        in_tuple = true;

        # Allocate and create a tuple member node.
        node = ast.make(ast.TAG_TUPLE_EXPR_MEM);
        let mem: ^ast.TupleExprMem = node.unwrap() as ^ast.TupleExprMem;

        # Pop the `:` token.
        self.pop_token();

        # Parse an identifier.
        if not self.parse_ident() { return false; }
        mem.id = self.stack.pop();

        # Push the identifier as the expression.
        mem.expression = mem.id;
    }
    # Could be a tuple with an initial member unnamed or just a
    # parenthetical expression.
    else
    {
        # Parse an expression node.
        if not self.parse_expr(false) { return false; }

        # Check for a comma that would make this a tuple.
        if self.peek_token_tag(1) == tokens.TOK_COMMA
        {
            # Declare we are in a tuple (to continue parsing).
            in_tuple = true;

            # Allocate and create a tuple member node.
            node = ast.make(ast.TAG_TUPLE_EXPR_MEM);
            let mem: ^ast.TupleExprMem = node.unwrap() as ^ast.TupleExprMem;

            # Switch the node with the member node.
            mem.expression = self.stack.pop();
        }
        else
        {
            # Switch the node with the member node.
            node = self.stack.pop();
        }
    }

    # Continue parsing if we are a tuple.
    if in_tuple
    {
        # Allocate and create the node for the tuple.
        let tup_node: ast.Node = ast.make(ast.TAG_TUPLE_EXPR);
        let expr: ^ast.TupleExpr = tup_node.unwrap() as ^ast.TupleExpr;

        # Push the initial node.
        expr.nodes.push(node);

        if self.peek_token_tag(1) == tokens.TOK_COMMA
        {
            # Pop the `,` token and continue the tuple.
            self.pop_token();

            # Enumerate until we reach the `)` token.
            while self.peek_token_tag(1) <> tokens.TOK_RPAREN {
                # Allocate and create a tuple member node.
                let mem_node: ast.Node = ast.make(ast.TAG_TUPLE_EXPR_MEM);
                let mem: ^ast.TupleExprMem =
                    mem_node.unwrap() as ^ast.TupleExprMem;

                # Check for a { "identifier" `:` } sequence that indicates
                # a named member.
                if      self.peek_token_tag(1) == tokens.TOK_IDENTIFIER
                    and self.peek_token_tag(2) == tokens.TOK_COLON
                {
                    # Parse an identifier.
                    if not self.parse_ident() { return false; }
                    mem.id = self.stack.pop();

                    # Pop the `:` token.
                    self.pop_token();

                    # Parse an expression node.
                    if not self.parse_expr(false) { return false; }
                    mem.expression = self.stack.pop();
                }
                # Check for a { `:` "identifier" } sequence that indicates
                # a named member and expression (shorthand).
                else if self.peek_token_tag(1) == tokens.TOK_COLON
                    and self.peek_token_tag(2) == tokens.TOK_IDENTIFIER
                {
                    # Pop the `:` token.
                    self.pop_token();

                    # Parse an identifier.
                    if not self.parse_ident() { return false; }
                    mem.id = self.stack.pop();
                    mem.expression = mem.id;
                }
                else
                {
                    # Parse an expression node.
                    if not self.parse_expr(false) { return false; }
                    mem.expression = self.stack.pop();
                }

                # Push the node.
                expr.nodes.push(mem_node);

                # Peek and consume the `,` token if present; else, consume
                # tokens until we reach the `)`.
                if self._expect_sequence_continue(tokens.TOK_RPAREN) {
                    continue; }
                return false;
            }
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
    while self.peek_token_tag(1) <> tokens.TOK_RBRACKET {
        # Parse an expression node.
        if not self.parse_expr(false) { return false; }
        expr.nodes.push(self.stack.pop());

        # Peek and consume the `,` token if present; else, consume
        # tokens until we reach the `]`.
        if self._expect_sequence_continue(tokens.TOK_RBRACKET) { continue; }
        return false;
    }

    # Expect a `]` token.
    if not self.expect(tokens.TOK_RBRACKET) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Block expression
# -----------------------------------------------------------------------------
def parse_block_expr(&mut self) -> bool
{
    # Allocate and create the node.
    let mut node: ast.Node = ast.make(ast.TAG_BLOCK);
    let expr: ^ast.Block = node.unwrap() as ^ast.Block;

    # Expect and consume the `{` token.
    if not self.expect(tokens.TOK_LBRACE) { return false; }

    # Iterate and attempt to match statements.
    while self.peek_token_tag(1) <> tokens.TOK_RBRACE {
        # Try and parse a node.
        if not self.parse_common_statement() {
            # Bad news.
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        } else {
            # Consume the parsed node and push it into the module.
            self.empty_stack_to(expr.nodes);
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

# Self expression
# -----------------------------------------------------------------------------
def parse_self_expr(&mut self) -> bool
{
    # Consume the `self` token.
    self.pop_token();

    # Allocate and create the node.
    # Push our node on the stack.
    self.stack.push(ast.make(ast.TAG_SELF));

    # Return success.
    true;
}

# Select expression
# -----------------------------------------------------------------------------
def parse_select_expr(&mut self) -> bool
{
    # Declare the selection expr node.
    let node: ast.Node = ast.make(ast.TAG_SELECT);
    let select: ^mut ast.SelectExpr = ast.unwrap(node) as ^ast.SelectExpr;
    let mut else_: bool = false;

    # Parse the selection expression
    if not self.parse_select_expr_inner(select^, else_) { return false; }
    if not self.parse_select_expr_else(select^, else_) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

def parse_select_expr_inner(
    &mut self, &mut x: ast.SelectExpr, &mut have_else: bool) -> bool
{
    # If we are already at `else` then drop.
    if have_else { return true; }

    loop
    {
        # Consume the `if` token.
        self.pop_token();

        # Parse the branch.
        let branch: ast.Node = self.parse_select_branch(true);
        if ast.isnull(branch) { return false; }

        # Append the branch to the selection expression.
        x.branches.push(branch);

        # Check for an "else" branch.
        if self.peek_token_tag(1) == tokens.TOK_ELSE {
            have_else = true;

            # Consume the "else" token.
            self.pop_token();

            # Check for an adjacent "if" token (which would make this
            # an "else if" and part of this selection expression).
            if self.peek_token_tag(1) == tokens.TOK_IF {
                have_else = false;

                # Loop back and parse another branch.
                continue;
            }
        }

        # We're done here.
        break;
    }

    # Return success.
    true;
}

def parse_select_expr_else(
    &mut self, &mut x: ast.SelectExpr, &mut have_else: bool) -> bool
{
    # Parse the trailing "else" (if we have one).
    if have_else {
        # Parse the condition-less branch.
        let branch: ast.Node = self.parse_select_branch(false);
        if ast.isnull(branch) { return false; }

        # Append the branch to the selection expression.
        x.branches.push(branch);
    }

    # Return success.
    true;
}

def parse_select_branch(&mut self, condition: bool) -> ast.Node
{
    # Declare the branch node.
    let node: ast.Node = ast.make(ast.TAG_SELECT_BRANCH);
    let mut branch: ^ast.SelectBranch = ast.unwrap(node) as ^ast.SelectBranch;

    if condition {
        # Expect and parse the condition expression.
        if not self.parse_expr(false) { return ast.null(); }
        branch.condition = self.stack.pop();
    }

    # Expect and parse the block.
    if not self.parse_block_expr() { return ast.null(); }
    branch.block = self.stack.pop();

    # Return our parsed node.
    node;
}

# Type Parameters
# -----------------------------------------------------------------------------
def parse_type_params(&mut self, &mut params: ast.Nodes) -> bool
{
    if self.peek_token_tag(1) == tokens.TOK_LCARET
    {
        # Pop the `<` token.
        self.pop_token();

        # Enumerate until we reach the final `>`.
        while self.peek_token_tag(1) <> tokens.TOK_RCARET
        {
            # Declare the type parameter node.
            let node: ast.Node = ast.make(ast.TAG_TYPE_PARAM);
            let param: ^ast.TypeParam =  node.unwrap() as ^ast.TypeParam;

            # Bail if we don't have an identifier next.
            if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
                self.consume_until(tokens.TOK_RCARET);
                self.expect(tokens.TOK_IDENTIFIER);
                return false;
            }

            # Parse and set the identifier (this shouldn't fail).
            if not self.parse_ident_expr() {
                self.consume_until(tokens.TOK_RCARET);
                return false;
            }

            param.id = self.stack.pop();

            # Push the type parameter.
            params.push(node);

            # Peek and consume the `,` token if present; else, consume
            # tokens until we reach the `>`.
            if self._expect_sequence_continue(tokens.TOK_RCARET) { continue; }
            return false;
        }

        # Pop the `>` token.
        self.pop_token();
    }

    # Return true.
    return true;
}

# Structure
# -----------------------------------------------------------------------------
def parse_struct(&mut self) -> bool {
    # Allocate space for the node
    let struct_node : ast.Node = ast.make(ast.TAG_STRUCT);
    let struct_ : ^ast.Struct =  struct_node.unwrap() as ^ast.Struct;

    # Take and remove "struct"
    self.pop_token();

    # Bail if we don't have an identifier next.
    if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
        self.expect(tokens.TOK_IDENTIFIER);
        self.consume_until(tokens.TOK_RBRACE);
        return false;
    }

    # Parse and set the identifier (this shouldn't fail).
    if not self.parse_ident() { return false; }
    struct_.id = self.stack.pop();

    # Check for and parse type type parameters.
    if not self.parse_type_params(struct_.type_params) { return false; }

    if not self.expect(tokens.TOK_LBRACE) {
        self.consume_until(tokens.TOK_RBRACE);
        return false;
    }

    while self.peek_token_tag(1) <> tokens.TOK_RBRACE {

        let mut struct_mem_node: ast.Node = ast.make(ast.TAG_STRUCT_MEM);
        let struct_mem : ^ast.StructMem = struct_mem_node.unwrap() as ^ast.StructMem;
        let is_static: bool = false;

        if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
            # Report the error.
            self.expect(tokens.TOK_IDENTIFIER);
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        if not self.parse_ident() { return false; }

        # We got an identifier!
        struct_mem.id = self.stack.pop();

        # Now, we'd better get a colon, or shit's going to get real
        if not self.expect(tokens.TOK_COLON) {
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        # Now for a type!
        if not self.parse_type() {
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        struct_mem.type_ = self.stack.pop();

        if self.peek_token_tag(1) == tokens.TOK_EQ {
            # Consume the "="
            self.pop_token() ;

            if not self.parse_expr(false) {
                self.consume_until(tokens.TOK_RBRACE);
                return false;
            }

            struct_mem.initializer =self.stack.pop();
        }

        # Push the node.
        struct_.nodes.push(struct_mem_node);

        # Peek and consume the `,` token if present; else, consume
        # tokens until we reach the `}`.
        if self._expect_sequence_continue(tokens.TOK_RBRACE) { continue; }
        return false;
    }

    # Expect and parse the `}` token.
    if not self.expect(tokens.TOK_RBRACE) { return false; }

    # Push our node on the stack.
    self.stack.push(struct_node);

    # Return success.
    true;
}

# Slot
# -----------------------------------------------------------------------------
def parse_slot(&mut self) -> bool
{
    # Determine our tag.
    let tag: int =
        if self.peek_token_tag(1) == tokens.TOK_STATIC { ast.TAG_STATIC_SLOT; }
        else { ast.TAG_LOCAL_SLOT; };

    # Allocate space for the node
    let node: ast.Node = ast.make(tag);
    let slot: ^ast.StaticSlotDecl =  node.unwrap() as ^ast.StaticSlotDecl;

    # Pop the decl token.
    self.pop_token();

    # Check for a `mut` token which would make the slot mutable.
    if self.peek_token_tag(1) == tokens.TOK_MUT
    {
        # Pop the `mut` token.
        self.pop_token();

        # Make the slot mutable.
        slot.mutable = true;
    }

    # Bail if we don't have an identifier next.
    if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
        self.expect(tokens.TOK_IDENTIFIER);
        self.consume_until(tokens.TOK_SEMICOLON);
        return false;
    }

    # Parse and set the identifier (this shouldn't fail).
    if not self.parse_ident() { return false; }
    slot.id = self.stack.pop();

    # Check for a type annotation which would be preceeded by a `:` token.
    if self.peek_token_tag(1) == tokens.TOK_COLON
    {
        # Pop the `:` token.
        self.pop_token();

        # Parse and set the type.
        if not self.parse_type() { return false; }
        slot.type_ = self.stack.pop();
    }

    # Check for an initializer which would be preceeded by a `=` token.
    if self.peek_token_tag(1) == tokens.TOK_EQ
    {
        # Pop the `=` token.
        self.pop_token();

        # Parse and set the initializer.
        if not self.parse_expr(false) { return false; }
        slot.initializer = self.stack.pop();
    }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Implement
# -----------------------------------------------------------------------------
def parse_impl(&mut self) -> bool
{
    # Allocate space for the node.
    let node: ast.Node = ast.make(ast.TAG_IMPLEMENT);
    let impl: ^ast.Implement =  node.unwrap() as ^ast.Implement;

    # Pop the `implement` token.
    self.pop_token();

    # Parse and set the type.
    if not self.parse_type() { return false; }
    impl.type_ = self.stack.pop();

    # Expect and parse the initial `{` token.
    if not self.expect(tokens.TOK_LBRACE) {
        self.consume_until(tokens.TOK_RBRACE);
        return false;
    }

    # Enumerate until we reach the `}` token.
    while self.peek_token_tag(1) <> tokens.TOK_RBRACE {
        # Expect and parse a `let`
        if not self.expect(tokens.TOK_LET) {
            self.consume_until(tokens.TOK_RBRACE);
            return false;
        }

        # Expect a `let identifier` token to start the named function
        # declaration.
        if not (self.peek_token_tag(1) == tokens.TOK_IDENTIFIER)
        {
            let tok: int = self.peek_token_tag(1);
            self.consume_until(tokens.TOK_RBRACE);
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
               "expected %s but found %s" as ^int8,
               tokens.to_str(tokens.TOK_IDENTIFIER),
               tokens.to_str(tok));
            errors.end();
            return false;
        }

        # Declare the function decl node.
        let fnnode: ast.Node = ast.make(ast.TAG_FUNC_DECL);
        let decl: ^ast.FuncDecl = fnnode.unwrap() as ^ast.FuncDecl;

        # Parse and set the identifier (this shouldn't fail).
        if not self.parse_ident() { return false; }
        decl.id = self.stack.pop();

        # Check for and parse type type parameters.
        if not self.parse_type_params(decl.type_params) { return false; }

        # Parse the parameter list.
        if not self.parse_function_params(decl, true, true) {
            return false;
        }

        # Check for a return type annotation which would again
        # be preceeded by a `:` token.
        if self.peek_token_tag(1) == tokens.TOK_COLON
        {
            # Pop the `:` token.
            self.pop_token();

            # Parse and set the type.
            if not self.parse_type() { return false; }
            decl.return_type = self.stack.pop();
        }

        # Expect an `->` token.
        if not self.peek_token_tag(1) == tokens.TOK_RARROW {
            let tok: int = self.peek_token_tag(1);
            self.consume_until(tokens.TOK_RBRACE);
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
               "expected %s but found %s" as ^int8,
               tokens.to_str(tokens.TOK_RARROW),
               tokens.to_str(tok));
            errors.end();
            return false;
        }

        # Pop the `->` token.
        self.pop_token();

        # Parse the function block next.
        if not self.parse_block_expr() { return false; }
        decl.block = self.stack.pop();

        # Push us into our node stack.
        impl.methods.push(fnnode);
    }

    # Expect and parse the `}` token.
    if not self.expect(tokens.TOK_RBRACE) { return false; }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Import
# -----------------------------------------------------------------------------
def parse_import(&mut self) -> bool
{
    # Allocate space for the node
    let node: ast.Node = ast.make(ast.TAG_IMPORT);
    let slot: ^ast.Import =  node.unwrap() as ^ast.Import;

    # Pop the `import` token.
    self.pop_token();

    # There should be at least one identifier next.
    if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
        self.expect(tokens.TOK_IDENTIFIER);
        self.consume_until(tokens.TOK_SEMICOLON);
        return false;
    }

    # Iterate and push each identifier.
    while self.peek_token_tag(1) <> tokens.TOK_SEMICOLON {
        # Expect and consume an identifier.
        if not self.parse_ident() {
            self.consume_until(tokens.TOK_SEMICOLON);
            return false;
        }

        # Push the ID node.
        slot.ids.push(self.stack.pop());

        # Check for a comma or the end.
        let tok: tokenizer.Token = self.peek_token(1);
        if tok.tag == tokens.TOK_DOT { self.pop_token(); continue; }
        else if tok.tag <> tokens.TOK_SEMICOLON {
            # Expected a comma and didn't receive one.. consume tokens until
            # we reach the end.
            self.consume_until(tokens.TOK_SEMICOLON);
            errors.begin_error();
            errors.libc.fprintf(errors.libc.stderr,
                           "expected %s or %s but found %s" as ^int8,
                           tokens.to_str(tokens.TOK_DOT),
                           tokens.to_str(tokens.TOK_SEMICOLON),
                           tokens.to_str(tok.tag));
            errors.end();
            return false;
        }
    }

    # Expect a semicolon to close us.
    if not self.expect(tokens.TOK_SEMICOLON) { return false; }

    # Push our node.
    self.stack.push(node);

    # Return success.
    true;
}

# External
# -----------------------------------------------------------------------------
def parse_extern(&mut self) -> bool
{
    # Pop the `extern` token.
    self.pop_token();

    # This could either be `static` or `def`.
    let tok: tokenizer.Token = self.peek_token(1);
    let res: bool =
        if      tok.tag == tokens.TOK_STATIC { self.parse_extern_static(); }
        else if tok.tag == tokens.TOK_DEF { self.parse_extern_function(); }
        else { false; };
    if not res { return false; }

    # Expect a semicolon to close us.
    self.expect(tokens.TOK_SEMICOLON);
}

# External Static
# -----------------------------------------------------------------------------
def parse_extern_static(&mut self) -> bool
{
    # Allocate space for the node
    let node: ast.Node = ast.make(ast.TAG_EXTERN_STATIC);
    let slot: ^ast.ExternStaticSlot =  node.unwrap() as ^ast.ExternStaticSlot;

    # Pop the `static` token.
    self.pop_token();

    # Check for a `mut` token which would make the slot mutable.
    if self.peek_token_tag(1) == tokens.TOK_MUT
    {
        # Pop the `mut` token.
        self.pop_token();

        # Make the slot mutable.
        slot.mutable = true;
    }

    # Bail if we don't have an identifier next.
    if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
        self.expect(tokens.TOK_IDENTIFIER);
        self.consume_until(tokens.TOK_SEMICOLON);
        return false;
    }

    # Parse and set the identifier (this shouldn't fail).
    if not self.parse_ident() { return false; }
    slot.id = self.stack.pop();

    # Check for a type annotation which would be preceeded by a `:` token.
    if self.peek_token_tag(1) == tokens.TOK_COLON
    {
        # Pop the `:` token.
        self.pop_token();

        # Parse and set the type.
        if not self.parse_type() { return false; }
        slot.type_ = self.stack.pop();
    }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# External Function
# -----------------------------------------------------------------------------
def parse_extern_function(&mut self) -> bool
{
    # Allocate space for the node
    let node: ast.Node = ast.make(ast.TAG_EXTERN_FUNC);
    let decl: ^ast.ExternFunc =  node.unwrap() as ^ast.ExternFunc;

    # Pop the `def` token.
    self.pop_token();

    # Expect an `identifier` next.
    if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
        self.expect(tokens.TOK_IDENTIFIER);
        return false;
    }

    # Parse and set the identifier (this shouldn't fail).
    if not self.parse_ident() { return false; }
    decl.id = self.stack.pop();

    # Parse the parameter list.
    if not self.parse_function_params(decl as ^ast.FuncDecl, false, false) {
        return false;
    }

    # Check for a return type annotation which would again
    # be preceeded by a `:` token.
    if self.peek_token_tag(1) == tokens.TOK_COLON
    {
        # Pop the `:` token.
        self.pop_token();

        # Parse and set the type.
        if not self.parse_type() { return false; }
        decl.return_type = self.stack.pop();
    }

    # Push our node on the stack.
    self.stack.push(node);

    # Return success.
    true;
}

# Expect a sequence continuation or the end of the sequence.
# -----------------------------------------------------------------------------
def _expect_sequence_continue(&mut self, end: int) -> bool
{
    let tok: tokenizer.Token = self.peek_token(1);
    if tok.tag == tokens.TOK_COMMA { self.pop_token(); return true; }
    else if tok.tag <> end {
        # Expected a comma and didn't receive one.. consume tokens until
        # we reach the end.
        self.consume_until(end);
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                       "expected %s or %s but found %s" as ^int8,
                       tokens.to_str(tokens.TOK_COMMA),
                       tokens.to_str(end),
                       tokens.to_str(tok.tag));
        errors.end();
        return false;
    }

    # Done anyway.
    return true;
}

# Expect and parse an identifier node.
# -----------------------------------------------------------------------------
def _expect_parse_ident(&mut self) -> bool
{
    # Expect an `identifier` next.
    if self.peek_token_tag(1) <> tokens.TOK_IDENTIFIER {
        # Report the error.
        self.expect(tokens.TOK_IDENTIFIER);
        return false;
    }

    # Parse the identifier.
    if not self.parse_ident() { return false; }

    # Return success.
    true;
}

# Expect and parse an identifier node (into a passed slot).
# -----------------------------------------------------------------------------
def _expect_parse_ident_to(&mut self, &mut node: ast.Node) -> bool
{
    # Expect and parse the identifier.
    if not self._expect_parse_ident() { return false; }

    # Push into the passed node.
    node = self.stack.pop();

    # Return success.
    true;
}

# Get the binary operator token precedence.
# -----------------------------------------------------------------------------
def get_binop_tok_precedence(&self, tok: int) -> int {
         if tok == tokens.TOK_IF                { 015; }  # if
    else if tok == tokens.TOK_EQ                { 030; }  # =
    else if tok == tokens.TOK_PLUS_EQ           { 030; }  # +=
    else if tok == tokens.TOK_MINUS_EQ          { 030; }  # -=
    else if tok == tokens.TOK_STAR_EQ           { 030; }  # *=
    else if tok == tokens.TOK_FSLASH_EQ         { 030; }  # /=
    else if tok == tokens.TOK_FSLASH_FSLASH_EQ  { 030; }  # //=
    else if tok == tokens.TOK_PERCENT_EQ        { 030; }  # %=
    else if tok == tokens.TOK_AND               { 060; }  # and
    else if tok == tokens.TOK_OR                { 060; }  # or
    else if tok == tokens.TOK_EQ_EQ             { 090; }  # ==
    else if tok == tokens.TOK_BANG_EQ           { 090; }  # !=
    else if tok == tokens.TOK_LCARET            { 090; }  # <
    else if tok == tokens.TOK_LCARET_EQ         { 090; }  # <=
    else if tok == tokens.TOK_RCARET            { 090; }  # >
    else if tok == tokens.TOK_RCARET_EQ         { 090; }  # >=
    else if tok == tokens.TOK_AMPERSAND         { 110; }  # &
    else if tok == tokens.TOK_PIPE              { 110; }  # |
    else if tok == tokens.TOK_HAT               { 110; }  # ^
    else if tok == tokens.TOK_PLUS              { 120; }  # +
    else if tok == tokens.TOK_MINUS             { 120; }  # -
    else if tok == tokens.TOK_STAR              { 150; }  # *
    else if tok == tokens.TOK_FSLASH            { 150; }  # /
    else if tok == tokens.TOK_FSLASH_FSLASH     { 150; }  # //
    else if tok == tokens.TOK_PERCENT           { 150; }  # %
    else if tok == tokens.TOK_DOT               { 190; }  # .
    else {
        # Not a binary operator.
        -1;
    }
}

# Get the binary operator token associativity.
# -----------------------------------------------------------------------------
def get_binop_tok_associativity(&self, tok: int) -> int {
         if tok == tokens.TOK_DOT               { ASSOC_LEFT; }   # .
    else if tok == tokens.TOK_IF                { ASSOC_LEFT; }   # if
    else if tok == tokens.TOK_EQ                { ASSOC_RIGHT; }  # =
    else if tok == tokens.TOK_PLUS_EQ           { ASSOC_RIGHT; }  # +=
    else if tok == tokens.TOK_MINUS_EQ          { ASSOC_RIGHT; }  # -=
    else if tok == tokens.TOK_STAR_EQ           { ASSOC_RIGHT; }  # *=
    else if tok == tokens.TOK_FSLASH_EQ         { ASSOC_RIGHT; }  # /=
    else if tok == tokens.TOK_FSLASH_FSLASH_EQ  { ASSOC_RIGHT; }  # //=
    else if tok == tokens.TOK_PERCENT_EQ        { ASSOC_RIGHT; }  # %=
    else if tok == tokens.TOK_AMPERSAND         { ASSOC_LEFT; }   # &
    else if tok == tokens.TOK_PIPE              { ASSOC_LEFT; }   # |
    else if tok == tokens.TOK_HAT               { ASSOC_LEFT; }   # ^
    else if tok == tokens.TOK_AND               { ASSOC_LEFT; }   # and
    else if tok == tokens.TOK_OR                { ASSOC_LEFT; }   # or
    else if tok == tokens.TOK_EQ_EQ             { ASSOC_LEFT; }   # ==
    else if tok == tokens.TOK_BANG_EQ           { ASSOC_LEFT; }   # !=
    else if tok == tokens.TOK_LCARET            { ASSOC_LEFT; }   # <
    else if tok == tokens.TOK_LCARET_EQ         { ASSOC_LEFT; }   # <=
    else if tok == tokens.TOK_RCARET            { ASSOC_LEFT; }   # >
    else if tok == tokens.TOK_RCARET_EQ         { ASSOC_LEFT; }   # >=
    else if tok == tokens.TOK_PLUS              { ASSOC_LEFT; }   # +
    else if tok == tokens.TOK_MINUS             { ASSOC_LEFT; }   # -
    else if tok == tokens.TOK_STAR              { ASSOC_LEFT; }   # *
    else if tok == tokens.TOK_FSLASH            { ASSOC_LEFT; }   # /
    else if tok == tokens.TOK_FSLASH_FSLASH     { ASSOC_LEFT; }   # //
    else if tok == tokens.TOK_PERCENT           { ASSOC_LEFT; }   # %
    else {
        # Not a binary operator.
        -1;
    }
}

# Get the binary operator token tag (in the AST).
# -----------------------------------------------------------------------------
def get_binop_tok_tag(&self, tok: int) -> int
{
    if      tok == tokens.TOK_PLUS              { ast.TAG_ADD; }
    else if tok == tokens.TOK_MINUS             { ast.TAG_SUBTRACT; }
    else if tok == tokens.TOK_STAR              { ast.TAG_MULTIPLY; }
    else if tok == tokens.TOK_FSLASH            { ast.TAG_DIVIDE; }
    else if tok == tokens.TOK_FSLASH_FSLASH     { ast.TAG_INTEGER_DIVIDE; }
    else if tok == tokens.TOK_PERCENT           { ast.TAG_MODULO; }
    else if tok == tokens.TOK_AND               { ast.TAG_LOGICAL_AND; }
    else if tok == tokens.TOK_OR                { ast.TAG_LOGICAL_OR; }
    else if tok == tokens.TOK_EQ_EQ             { ast.TAG_EQ; }
    else if tok == tokens.TOK_BANG_EQ           { ast.TAG_NE; }
    else if tok == tokens.TOK_LCARET            { ast.TAG_LT; }
    else if tok == tokens.TOK_LCARET_EQ         { ast.TAG_LE; }
    else if tok == tokens.TOK_RCARET            { ast.TAG_GT; }
    else if tok == tokens.TOK_RCARET_EQ         { ast.TAG_GE; }
    else if tok == tokens.TOK_AMPERSAND         { ast.TAG_BITAND; }
    else if tok == tokens.TOK_PIPE              { ast.TAG_BITOR; }
    else if tok == tokens.TOK_HAT               { ast.TAG_BITXOR; }
    else if tok == tokens.TOK_EQ                { ast.TAG_ASSIGN; }
    else if tok == tokens.TOK_PLUS_EQ           { ast.TAG_ASSIGN_ADD; }
    else if tok == tokens.TOK_MINUS_EQ          { ast.TAG_ASSIGN_SUB; }
    else if tok == tokens.TOK_STAR_EQ           { ast.TAG_ASSIGN_MULT; }
    else if tok == tokens.TOK_FSLASH_EQ         { ast.TAG_ASSIGN_DIV; }
    else if tok == tokens.TOK_FSLASH_FSLASH_EQ  { ast.TAG_ASSIGN_INT_DIV; }
    else if tok == tokens.TOK_PERCENT_EQ        { ast.TAG_ASSIGN_MOD; }
    else if tok == tokens.TOK_IF                { ast.TAG_SELECT_OP; }
    else { 0; }
}

} # Parser

# Test driver using `stdin`.
# =============================================================================
def main() {
    # Declare the tokenizer.
    let mut t: tokenizer.Tokenizer = tokenizer.tokenizer_new(
        "-", libc.stdin);

    # Declare the parser.
    let mut p: Parser = parser_new("_", t);

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
