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
# expr = primary binop_rhs
# -----------------------------------------------------------------------------
def parse_expr() -> ast.Node {
    let result: ast.Node = parse_primary_expr();
    if ast.isnull(result) { return result; }

    return parse_binop_rhs(0, result);
}

# Binary operator token precedence
# -----------------------------------------------------------------------------
def get_binop_tok_precedence() -> int {
    if      cur_tok == tokens.TOK_PLUS        { 020; }
    else if cur_tok == tokens.TOK_MINUS       { 020; }
    else if cur_tok == tokens.TOK_STAR        { 040; }
    else if cur_tok == tokens.TOK_FSLASH      { 040; }
    else if cur_tok == tokens.TOK_PERCENT     { 040; }
    else {
        # Not a binary operator.
        -1;
    }
}

# Binary expression RHS
# -----------------------------------------------------------------------------
# binop_rhs = { binop primary }
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
        let rhs: ast.Node = parse_primary_expr();
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
            if      binop == tokens.TOK_PLUS        { ast.TAG_ADD; }
            else if binop == tokens.TOK_MINUS       { ast.TAG_SUBTRACT; }
            else if binop == tokens.TOK_STAR        { ast.TAG_MULTIPLY; }
            else if binop == tokens.TOK_FSLASH      { ast.TAG_DIVIDE; }
            else if binop == tokens.TOK_PERCENT     { ast.TAG_MODULO; }
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

# Primary expression
# -----------------------------------------------------------------------------
# primary_expr = integer_expr
# -----------------------------------------------------------------------------
def parse_primary_expr() -> ast.Node {
    if cur_tok == tokens.TOK_BIN_INTEGER
            or cur_tok == tokens.TOK_OCT_INTEGER
            or cur_tok == tokens.TOK_DEC_INTEGER
            or cur_tok == tokens.TOK_HEX_INTEGER {
        parse_integer_expr();
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
