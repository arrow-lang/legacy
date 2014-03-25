foreign "C" import "stdlib.h";
import tokenizer;
import tokens;
import ast;

# Token buffer -- cur_tok is the current token the parser is looking at.
# -----------------------------------------------------------------------------
let mut cur_tok: int;
def bump_token() -> int {
    cur_tok = tokenizer.get_next_token();
    cur_tok;
}

# Boolean expression
# -----------------------------------------------------------------------------
# boolean_expr = <true> | <false>
# -----------------------------------------------------------------------------
def parse_bool_expr() -> ast.Node {
    # Allocate space for the boolean expression.
    let node: ast.Node = ast.make(ast.TAG_BOOLEAN);
    let expr: ^ast.BooleanExpr = ast.unwrap(node) as ^ast.BooleanExpr;

    # Set our value.
    expr.value = cur_tok == tokens.TOK_TRUE;

    # Consume the token and return our node.
    bump_token();
    node;
}

# Integer expression
# -----------------------------------------------------------------------------
# integer_expr = <dec_integer>
#              | <hex_integer>
#              | <bin_integer>
#              | <oct_integer>
# -----------------------------------------------------------------------------
def parse_integer_expr() -> ast.Node {
    # Allocate space for the integer expression literal.
    let node: ast.Node = ast.make(ast.TAG_INTEGER);
    let expr: ^ast.IntegerExpr = ast.unwrap(node) as ^ast.IntegerExpr;

    # Determine the base for the integer literal.
    expr.base =
        if      cur_tok == tokens.TOK_DEC_INTEGER { 10; }
        else if cur_tok == tokens.TOK_HEX_INTEGER { 16; }
        else if cur_tok == tokens.TOK_OCT_INTEGER { 8; }
        else if cur_tok == tokens.TOK_BIN_INTEGER { 2; }
        else { 0; };  # NOTE: Not possible to get here

    # Store the text for the integer literal.
    expr.text = ast.arena.alloc(tokenizer.current_num.size + 1);
    let xs: &ast.arena.Store = expr.text;
    tokenizer.asciz.memcpy(
        xs._data as ^void,
        &tokenizer.current_num.buffer[0] as ^void,
        tokenizer.current_num.size);

    # Consume our token.
    bump_token();

    # Return our node.
    node;
}

# Parenthesized expression
# -----------------------------------------------------------------------------
# paren_expr = '(' expr ')'
# -----------------------------------------------------------------------------
def parse_paren_expr() -> ast.Node {
    bump_token();  # Eat '('
    let result: ast.Node = parse_expr();
    if ast.isnull(result) { return result; }

    if cur_tok <> tokens.TOK_RPAREN {
        printf("error: expected ')'\n");
        return ast.null();
    }

    bump_token();  # Eat ')'
    result;
}

# Expression
# -----------------------------------------------------------------------------
# expr = unary binop_rhs
# -----------------------------------------------------------------------------
def parse_expr() -> ast.Node {
    let result: ast.Node = parse_unary_expr();
    if ast.isnull(result) { return result; }

    return parse_binop_rhs(0, result);
}

# Binary operator token precedence
# -----------------------------------------------------------------------------
def get_binop_tok_precedence() -> int {
         if cur_tok == tokens.TOK_AND            { 010; }  # and
    else if cur_tok == tokens.TOK_OR             { 010; }  # or
    else if cur_tok == tokens.TOK_EQ_EQ          { 020; }  # ==
    else if cur_tok == tokens.TOK_LCARET_RCARET  { 020; }  # <>
    else if cur_tok == tokens.TOK_LCARET         { 020; }  # <
    else if cur_tok == tokens.TOK_LCARET_EQ      { 020; }  # <=
    else if cur_tok == tokens.TOK_RCARET         { 020; }  # >
    else if cur_tok == tokens.TOK_RCARET_EQ      { 020; }  # >=
    else if cur_tok == tokens.TOK_PLUS           { 040; }  # +
    else if cur_tok == tokens.TOK_MINUS          { 040; }  # -
    else if cur_tok == tokens.TOK_STAR           { 060; }  # *
    else if cur_tok == tokens.TOK_FSLASH         { 060; }  # /
    else if cur_tok == tokens.TOK_PERCENT        { 060; }  # %
    else {
        # Not a binary operator.
        -1;
    }
}

# Binary expression RHS
# -----------------------------------------------------------------------------
# binop_rhs = { binop unary }
# binop = <plus>
#       | <minus>
#       | <fslash>
#       | <star>
#       | <percent>
# -----------------------------------------------------------------------------
def parse_binop_rhs(mut expr_prec: int, mut lhs: ast.Node) -> ast.Node {
    loop {
        # Get the token precedence (if it is a binary operator token).
        let tok_prec: int = get_binop_tok_precedence();

        # If this is a binop that binds at least as tightly as the
        # current binop, consume it, otherwise we are done.
        if tok_prec < expr_prec { return lhs; }

        # Okay; this is a binary operator token; consume and move on.
        let binop: int = cur_tok;
        bump_token();

        # Parse the RHS of this binary expression.
        let rhs: ast.Node = parse_unary_expr();
        if ast.isnull(rhs) { return ast.null(); }

        # If binop binds less tightly with RHS than the operator after
        # RHS, let the pending operator take RHS as its LHS.
        let next_prec: int = get_binop_tok_precedence();
        if tok_prec < next_prec {
            rhs = parse_binop_rhs(tok_prec + 1, rhs);
            if ast.isnull(rhs) { return ast.null(); }
        }

        # Determine the AST tag.
        let tag: int =
            if      binop == tokens.TOK_PLUS           { ast.TAG_ADD; }
            else if binop == tokens.TOK_MINUS          { ast.TAG_SUBTRACT; }
            else if binop == tokens.TOK_STAR           { ast.TAG_MULTIPLY; }
            else if binop == tokens.TOK_FSLASH         { ast.TAG_DIVIDE; }
            else if binop == tokens.TOK_PERCENT        { ast.TAG_MODULO; }
            else if binop == tokens.TOK_AND            { ast.TAG_LOGICAL_AND; }
            else if binop == tokens.TOK_OR             { ast.TAG_LOGICAL_OR; }
            else if binop == tokens.TOK_EQ_EQ          { ast.TAG_EQ; }
            else if binop == tokens.TOK_LCARET_RCARET  { ast.TAG_NE; }
            else if binop == tokens.TOK_LCARET         { ast.TAG_LT; }
            else if binop == tokens.TOK_LCARET_EQ      { ast.TAG_LE; }
            else if binop == tokens.TOK_RCARET         { ast.TAG_GT; }
            else if binop == tokens.TOK_RCARET_EQ      { ast.TAG_GE; }
            else { 0; };  # Cannot happen.

        # Merge LHS/RHS into a binary expression node.
        let node: ast.Node = ast.make(tag);
        let expr: ^ast.BinaryExpr = ast.unwrap(node) as ^ast.BinaryExpr;
        expr.lhs = lhs;
        expr.rhs = rhs;
        lhs = node;
    }

    # Unreachable code.
    return ast.null();
}

# Unary expression
# -----------------------------------------------------------------------------
# unary_expr = primary_expr
#            | "+" unary_expr
#            | "-" unary_expr
#            | "not" unary_expr
# -----------------------------------------------------------------------------
def parse_unary_expr() -> ast.Node {
    # If the current token is not a unary operator then it must be a
    # primary expression.
    if cur_tok <> tokens.TOK_PLUS
            and cur_tok <> tokens.TOK_MINUS
            and cur_tok <> tokens.TOK_NOT {
        return parse_primary_expr();
    }

    # Okay; this is a unary operator token; consume and move on.
    let opc: int = cur_tok;
    bump_token();

    # Parse the RHS of this unary expression.
    let operand: ast.Node = parse_unary_expr();
    if ast.isnull(operand) { return ast.null(); }

    # Determine the AST tag.
    let tag: int =
        if      opc == tokens.TOK_PLUS      { ast.TAG_PROMOTE; }
        else if opc == tokens.TOK_MINUS     { ast.TAG_NUMERIC_NEGATE; }
        else if opc == tokens.TOK_NOT       { ast.TAG_LOGICAL_NEGATE; }
        else { 0; };  # Cannot happen.

    # Create a unary expression node.
    let node: ast.Node = ast.make(tag);
    let expr: ^ast.UnaryExpr = ast.unwrap(node) as ^ast.UnaryExpr;
    expr.operand = operand;

    # Return our constructed node.
    node;
}

# Primary expression
# -----------------------------------------------------------------------------
# primary_expr = integer_expr | paren_expr | boolean_expr
# -----------------------------------------------------------------------------
def parse_primary_expr() -> ast.Node {
    if cur_tok == tokens.TOK_BIN_INTEGER
            or cur_tok == tokens.TOK_OCT_INTEGER
            or cur_tok == tokens.TOK_DEC_INTEGER
            or cur_tok == tokens.TOK_HEX_INTEGER {
        parse_integer_expr();
    } else if cur_tok == tokens.TOK_TRUE or cur_tok == tokens.TOK_FALSE {
        parse_bool_expr();
    } else if cur_tok == tokens.TOK_LPAREN {
        parse_paren_expr();
    } else {
        # Not sure what we have.
        ast.null();
    }
}

# Module
# -----------------------------------------------------------------------------
# module = { primary_expr <semicolon> }
# -----------------------------------------------------------------------------
def parse_module() -> ast.Node {
    # Declare the module decl node.
    let node: ast.Node = ast.make(ast.TAG_MODULE);
    let mod: ^ast.ModuleDecl = ast.unwrap(node) as ^ast.ModuleDecl;

    # Iterate and attempt to match a primary expression followed
    # by a semicolon.
    let mut matched: ast.Node;
    loop {
        # Attempt to parse an expression.
        matched = parse_expr();
        if ast.isnull(matched) {
            # Didn't match anything.
            break;
        }

        # Look for a semicolon to terminate the expression.
        if cur_tok <> tokens.TOK_SEMICOLON {
            printf("error: expected ';'\n");
            return node;
        }

        # Consume the semicolon.
        bump_token();

        # Matched the full sub-rule; append the node to the module.
        ast.push(mod.nodes, matched);
    }

    # Return our node.
    node;
}

# Main
# -----------------------------------------------------------------------------
def main() {
    # Prime the token buffer.
    bump_token();

    # Parse the top-level module.
    let node: ast.Node = parse_module();

    # Dump the top-level module.
    ast.dump(node);

    # Exit and return success.
    exit(0);
}
