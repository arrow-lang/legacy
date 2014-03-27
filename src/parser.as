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
# boolean_expr = "true" | "false"
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

    return parse_binop_rhs(0, 0, result);
}

# Binary operator token precedence
# -----------------------------------------------------------------------------
def get_binop_tok_precedence() -> int {
         if cur_tok == tokens.TOK_EQ             { 005; }  # =
    else if cur_tok == tokens.TOK_PLUS_EQ        { 005; }  # +=
    else if cur_tok == tokens.TOK_MINUS_EQ       { 005; }  # -=
    else if cur_tok == tokens.TOK_STAR_EQ        { 005; }  # *=
    else if cur_tok == tokens.TOK_FSLASH_EQ      { 005; }  # /=
    else if cur_tok == tokens.TOK_PERCENT_EQ     { 005; }  # %=
    else if cur_tok == tokens.TOK_COLON_EQ       { 005; }  # :=
    else if cur_tok == tokens.TOK_AND            { 010; }  # and
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

# Binary operator token associativity
# -----------------------------------------------------------------------------
let ASSOC_RIGHT: int = 1;
let ASSOC_LEFT: int = 2;
def get_binop_tok_associativity() -> int {
         if cur_tok == tokens.TOK_EQ             { ASSOC_RIGHT; }  # =
    else if cur_tok == tokens.TOK_PLUS_EQ        { ASSOC_RIGHT; }  # +=
    else if cur_tok == tokens.TOK_MINUS_EQ       { ASSOC_RIGHT; }  # -=
    else if cur_tok == tokens.TOK_STAR_EQ        { ASSOC_RIGHT; }  # *=
    else if cur_tok == tokens.TOK_FSLASH_EQ      { ASSOC_RIGHT; }  # /=
    else if cur_tok == tokens.TOK_PERCENT_EQ     { ASSOC_RIGHT; }  # %=
    else if cur_tok == tokens.TOK_COLON_EQ       { ASSOC_RIGHT; }  # :=
    else if cur_tok == tokens.TOK_AND            { ASSOC_LEFT; }  # and
    else if cur_tok == tokens.TOK_OR             { ASSOC_LEFT; }  # or
    else if cur_tok == tokens.TOK_EQ_EQ          { ASSOC_LEFT; }  # ==
    else if cur_tok == tokens.TOK_LCARET_RCARET  { ASSOC_LEFT; }  # <>
    else if cur_tok == tokens.TOK_LCARET         { ASSOC_LEFT; }  # <
    else if cur_tok == tokens.TOK_LCARET_EQ      { ASSOC_LEFT; }  # <=
    else if cur_tok == tokens.TOK_RCARET         { ASSOC_LEFT; }  # >
    else if cur_tok == tokens.TOK_RCARET_EQ      { ASSOC_LEFT; }  # >=
    else if cur_tok == tokens.TOK_PLUS           { ASSOC_LEFT; }  # +
    else if cur_tok == tokens.TOK_MINUS          { ASSOC_LEFT; }  # -
    else if cur_tok == tokens.TOK_STAR           { ASSOC_LEFT; }  # *
    else if cur_tok == tokens.TOK_FSLASH         { ASSOC_LEFT; }  # /
    else if cur_tok == tokens.TOK_PERCENT        { ASSOC_LEFT; }  # %
    else {
        # Not a binary operator.
        -1;
    }
}

# Binary expression RHS
# -----------------------------------------------------------------------------
# binop_rhs = { binop unary }
# binop = "+"  | "-"  | "*"  | "/"  | "%" | "and" | "or" | "==" | "<>"
#       | ">"  | "<"  | "<=" | ">=" | "=" | ":="  | "+=" | "-=" | "*="
#       | "/=" | "%="
# -----------------------------------------------------------------------------
def parse_binop_rhs(mut expr_prec: int, expr_assoc: int, mut lhs: ast.Node) -> ast.Node {
    loop {
        # Get the token precedence (if it is a binary operator token).
        let tok_prec: int = get_binop_tok_precedence();
        let tok_assoc: int = get_binop_tok_associativity();

        # If this is a binop that binds at least as tightly as the
        # current binop, consume it, otherwise we are done.
        if tok_prec == -1 { return lhs; }
        if tok_prec < expr_prec and expr_assoc <> ASSOC_RIGHT { return lhs; }

        # Okay; this is a binary operator token; consume and move on.
        let binop: int = cur_tok;
        bump_token();

        # Parse the RHS of this binary expression.
        let rhs: ast.Node = parse_unary_expr();
        if ast.isnull(rhs) { return ast.null(); }

        # If binop binds less tightly with RHS than the operator after
        # RHS, let the pending operator take RHS as its LHS.
        let next_prec: int = get_binop_tok_precedence();
        if tok_prec < next_prec or (
                tok_assoc == ASSOC_RIGHT and tok_prec == next_prec) {
            rhs = parse_binop_rhs(tok_prec + 1, tok_assoc, rhs);
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
            else if binop == tokens.TOK_EQ             { ast.TAG_ASSIGN; }
            else if binop == tokens.TOK_PLUS_EQ        { ast.TAG_ASSIGN_ADD; }
            else if binop == tokens.TOK_MINUS_EQ       { ast.TAG_ASSIGN_SUB; }
            else if binop == tokens.TOK_STAR_EQ        { ast.TAG_ASSIGN_MULT; }
            else if binop == tokens.TOK_FSLASH_EQ      { ast.TAG_ASSIGN_DIV; }
            else if binop == tokens.TOK_PERCENT_EQ     { ast.TAG_ASSIGN_MOD; }
            else { 0; };

        if tag <> 0 {
            # Merge LHS/RHS into a binary expression node.
            let node: ast.Node = ast.make(tag);
            let expr: ^ast.BinaryExpr = ast.unwrap(node) as ^ast.BinaryExpr;
            expr.lhs = lhs;
            expr.rhs = rhs;
            lhs = node;
        } else if binop == tokens.TOK_COLON_EQ {
            # This is a special binary operator. The LHS may only be an
            # identifier or a tuple and places expecting. Meaning this is
            # not chainable. It is not valid inside function calls however
            # function calls will reject it not us (as we don't know where
            # we are being used).
            let node: ast.Node = ast.make(ast.TAG_LOCAL_SLOT);
            let decl: ^ast.LocalSlotDecl =
                ast.unwrap(node) as ^ast.LocalSlotDecl;

            if lhs.tag <> ast.TAG_IDENT {
                # FIXME: Throw a nice error for this later.
                return ast.null();
            }

            # Set the id.
            decl.id = lhs;

            # We are not mutable.
            decl.mutable = false;

            # Set the rhs as the initializer.
            decl.initializer = rhs;

            # Return our node.
            return node;
        }
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

    # # Consume our token.
    # bump_token();

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
    } else if cur_tok == tokens.TOK_IDENTIFIER {
        parse_ident();
    } else {
        # Not sure what we have.
        ast.null();
    }
}

# Identifier
# -----------------------------------------------------------------------------
# ident = <ident>
# -----------------------------------------------------------------------------
def parse_ident() -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_IDENT);
    let decl: ^ast.Ident = ast.unwrap(node) as ^ast.Ident;

    # Store the text for the identifier.
    decl.name = ast.arena.alloc(tokenizer.current_id.size + 1);
    let xs: &ast.arena.Store = decl.name;
    tokenizer.asciz.memcpy(
        xs._data as ^void,
        &tokenizer.current_id.buffer[0] as ^void,
        tokenizer.current_id.size);

    # Consume the "ident" token.
    bump_token();

    # Return our constructed node.
    node;
}

# Type expression
# -----------------------------------------------------------------------------
# type_expr = ident
# -----------------------------------------------------------------------------
def parse_type_expr() -> ast.Node {
    if cur_tok == tokens.TOK_IDENTIFIER {
        # A simple typename.
        parse_ident();
    } else {
        # Currently don't parse fancy types.
        ast.null();
    }
}

# Static slot declaration
# -----------------------------------------------------------------------------
# static_declaration_member = [ "mut" ] identifier
# static_decl = "static" local_declaration_member ":" type [ "=" expression ]
# -----------------------------------------------------------------------------
def parse_static_decl() -> ast.Node {
    # Declare the static decl node.
    let node: ast.Node = ast.make(ast.TAG_STATIC_SLOT);
    let decl: ^ast.StaticSlotDecl = ast.unwrap(node) as ^ast.StaticSlotDecl;

    # Consume the "static" token.
    bump_token();

    # Check if we are mutable.
    decl.mutable = cur_tok == tokens.TOK_MUT;

    # If we are then consume the "mut" token.
    if decl.mutable { bump_token(); }

    # There should be an identifier next.
    if cur_tok == tokens.TOK_IDENTIFIER {
        decl.id = parse_ident();
        if ast.isnull(decl.id) { return ast.null(); }
    }

    # There must be a ":" next to start the type annotation.
    if cur_tok <> tokens.TOK_COLON {
        # FIXME: Report a nice error message.
        return ast.null();
    }

    # Consume the ":" token.
    bump_token();

    # There should be a type expression next.
    decl.type_ = parse_type_expr();
    if ast.isnull(decl.type_) {
        # FIXME: Report a nice error message.
        return ast.null();
    }

    # There can be an "=" next to indicate the start of the initializer
    # for this static slot.
    if cur_tok == tokens.TOK_EQ {
        # Consume the "=" and parse the initializer expression.
        bump_token();
        decl.initializer = parse_expr();
        if ast.isnull(decl.initializer) {
            # FIXME: Report a nice error message.
            return ast.null();
        }
    } else {
        # There is no initializer.
        decl.initializer = ast.null();
    }

    # Return our constructed declaration.
    node;
}

# Local slot declaration
# -----------------------------------------------------------------------------
# local_declaration_member = [ "mut" ] identifier
# local_decl = "let" local_declaration_member [ ":" type ] [ "=" expression ]
# -----------------------------------------------------------------------------
def parse_local_decl() -> ast.Node {
    # Declare the static decl node.
    let node: ast.Node = ast.make(ast.TAG_LOCAL_SLOT);
    let decl: ^ast.LocalSlotDecl = ast.unwrap(node) as ^ast.LocalSlotDecl;

    # Consume the "let" token.
    bump_token();

    # Check if we are mutable.
    decl.mutable = cur_tok == tokens.TOK_MUT;

    # If we are then consume the "mut" token.
    if decl.mutable { bump_token(); }

    # There should be an identifier next.
    if cur_tok == tokens.TOK_IDENTIFIER {
        decl.id = parse_ident();
        if ast.isnull(decl.id) { return ast.null(); }
    }

    # There can be a ":" next to start the type annotation.
    if cur_tok == tokens.TOK_COLON {
        # Consume the ":" token.
        bump_token();

        # There should be a type expression next.
        decl.type_ = parse_type_expr();
        if ast.isnull(decl.type_) {
            # FIXME: Report a nice error message.
            return ast.null();
        }
    }

    # There can be an "=" next to indicate the start of the initialzier
    # for this static slot.
    if cur_tok == tokens.TOK_EQ {
        # Consume the "=" and parse the initializer expression.
        bump_token();
        decl.initializer = parse_expr();
        if ast.isnull(decl.initializer) {
            # FIXME: Report a nice error message.
            return ast.null();
        }
    } else {
        # There is no initializer.
        decl.initializer = ast.null();
    }

    # Return our constructed declaration.
    node;
}

# Selection expression
# -----------------------------------------------------------------------------
# ...
# -----------------------------------------------------------------------------
def parse_selection_expr() -> ast.Node {
    # Declare the selection expr node.
    let node: ast.Node = ast.make(ast.TAG_SELECT);
    let mod: ^ast.ModuleDecl = ast.unwrap(node) as ^ast.ModuleDecl;

}

# Statements
# -----------------------------------------------------------------------------
# statement = primary_expr
#           | slot_decl
# -----------------------------------------------------------------------------
def parse_statement() -> ast.Node {
    if cur_tok == tokens.TOK_STATIC {
        parse_static_decl();
    } else if cur_tok == tokens.TOK_LET {
        parse_local_decl();
    } else {
        # Maybe we have an expression.
        parse_expr();
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
        matched = parse_statement();
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
