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
        # Attempt to parse a primary expression.
        matched = parse_primary_expr();
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
