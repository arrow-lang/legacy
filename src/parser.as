import libc;
import tokenizer;
import tokens;
import ast;
import errors;

# Token buffer -- cur_tok is the current token the parser is looking at.
# -----------------------------------------------------------------------------
let mut cur_tok: int = tokens.TOK_SEMICOLON;
let mut next_tok: int = tokens.TOK_SEMICOLON;
def bump_token() -> int {
    cur_tok = next_tok;
    next_tok = tokenizer.get_next_token();
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
    expr.text.extend(tokenizer.current_num.data() as str);

    # Consume our token.
    bump_token();

    # Return our node.
    node;
}

# Float expression
# -----------------------------------------------------------------------------
# float_expr = <float>
# -----------------------------------------------------------------------------
def parse_float_expr() -> ast.Node {
    # Allocate space for the float expression literal.
    let node: ast.Node = ast.make(ast.TAG_FLOAT);
    let expr: ^ast.FloatExpr = ast.unwrap(node) as ^ast.FloatExpr;

    # Store the text for the float literal.
    expr.text.extend(tokenizer.current_num.data() as str);

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
    if ast.isnull(result) {
        # Consume the next token if its a ")"
        if cur_tok == tokens.TOK_RPAREN { bump_token(); }

        # Return null.
        return result;
    }

    if cur_tok <> tokens.TOK_RPAREN {
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected `)`" as ^int8);
        errors.end();

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
         if cur_tok == tokens.TOK_IF                { 015; }  # if
    else if cur_tok == tokens.TOK_EQ                { 030; }  # =
    else if cur_tok == tokens.TOK_PLUS_EQ           { 030; }  # +=
    else if cur_tok == tokens.TOK_MINUS_EQ          { 030; }  # -=
    else if cur_tok == tokens.TOK_STAR_EQ           { 030; }  # *=
    else if cur_tok == tokens.TOK_FSLASH_EQ         { 030; }  # /=
    else if cur_tok == tokens.TOK_FSLASH_FSLASH_EQ  { 030; }  # //=
    else if cur_tok == tokens.TOK_PERCENT_EQ        { 030; }  # %=
    else if cur_tok == tokens.TOK_RETURN            { 040; }  # return
    else if cur_tok == tokens.TOK_AND               { 060; }  # and
    else if cur_tok == tokens.TOK_OR                { 060; }  # or
    else if cur_tok == tokens.TOK_EQ_EQ             { 090; }  # ==
    else if cur_tok == tokens.TOK_LCARET_RCARET     { 090; }  # <>
    else if cur_tok == tokens.TOK_LCARET            { 090; }  # <
    else if cur_tok == tokens.TOK_LCARET_EQ         { 090; }  # <=
    else if cur_tok == tokens.TOK_RCARET            { 090; }  # >
    else if cur_tok == tokens.TOK_RCARET_EQ         { 090; }  # >=
    else if cur_tok == tokens.TOK_PLUS              { 120; }  # +
    else if cur_tok == tokens.TOK_MINUS             { 120; }  # -
    else if cur_tok == tokens.TOK_STAR              { 150; }  # *
    else if cur_tok == tokens.TOK_FSLASH            { 150; }  # /
    else if cur_tok == tokens.TOK_FSLASH_FSLASH     { 150; }  # //
    else if cur_tok == tokens.TOK_PERCENT           { 150; }  # %
    else if cur_tok == tokens.TOK_DOT               { 190; }  # .
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
         if cur_tok == tokens.TOK_DOT               { ASSOC_LEFT; }   # .
    else if cur_tok == tokens.TOK_IF                { ASSOC_LEFT; }   # if
    else if cur_tok == tokens.TOK_EQ                { ASSOC_RIGHT; }  # =
    else if cur_tok == tokens.TOK_PLUS_EQ           { ASSOC_RIGHT; }  # +=
    else if cur_tok == tokens.TOK_MINUS_EQ          { ASSOC_RIGHT; }  # -=
    else if cur_tok == tokens.TOK_STAR_EQ           { ASSOC_RIGHT; }  # *=
    else if cur_tok == tokens.TOK_FSLASH_EQ         { ASSOC_RIGHT; }  # /=
    else if cur_tok == tokens.TOK_FSLASH_FSLASH_EQ  { ASSOC_RIGHT; }  # //=
    else if cur_tok == tokens.TOK_PERCENT_EQ        { ASSOC_RIGHT; }  # %=
    else if cur_tok == tokens.TOK_AND               { ASSOC_LEFT; }   # and
    else if cur_tok == tokens.TOK_OR                { ASSOC_LEFT; }   # or
    else if cur_tok == tokens.TOK_EQ_EQ             { ASSOC_LEFT; }   # ==
    else if cur_tok == tokens.TOK_LCARET_RCARET     { ASSOC_LEFT; }   # <>
    else if cur_tok == tokens.TOK_LCARET            { ASSOC_LEFT; }   # <
    else if cur_tok == tokens.TOK_LCARET_EQ         { ASSOC_LEFT; }   # <=
    else if cur_tok == tokens.TOK_RCARET            { ASSOC_LEFT; }   # >
    else if cur_tok == tokens.TOK_RCARET_EQ         { ASSOC_LEFT; }   # >=
    else if cur_tok == tokens.TOK_PLUS              { ASSOC_LEFT; }   # +
    else if cur_tok == tokens.TOK_MINUS             { ASSOC_LEFT; }   # -
    else if cur_tok == tokens.TOK_STAR              { ASSOC_LEFT; }   # *
    else if cur_tok == tokens.TOK_FSLASH            { ASSOC_LEFT; }   # /
    else if cur_tok == tokens.TOK_FSLASH_FSLASH     { ASSOC_LEFT; }   # //
    else if cur_tok == tokens.TOK_PERCENT           { ASSOC_LEFT; }   # %
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
#       | "/=" | "%=" | "if" | "." | "//" | "//="
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
            if      binop == tokens.TOK_PLUS              { ast.TAG_ADD; }
            else if binop == tokens.TOK_MINUS             { ast.TAG_SUBTRACT; }
            else if binop == tokens.TOK_STAR              { ast.TAG_MULTIPLY; }
            else if binop == tokens.TOK_FSLASH            { ast.TAG_DIVIDE; }
            else if binop == tokens.TOK_FSLASH_FSLASH     { ast.TAG_INTEGER_DIVIDE; }
            else if binop == tokens.TOK_PERCENT           { ast.TAG_MODULO; }
            else if binop == tokens.TOK_AND               { ast.TAG_LOGICAL_AND; }
            else if binop == tokens.TOK_OR                { ast.TAG_LOGICAL_OR; }
            else if binop == tokens.TOK_EQ_EQ             { ast.TAG_EQ; }
            else if binop == tokens.TOK_LCARET_RCARET     { ast.TAG_NE; }
            else if binop == tokens.TOK_LCARET            { ast.TAG_LT; }
            else if binop == tokens.TOK_LCARET_EQ         { ast.TAG_LE; }
            else if binop == tokens.TOK_RCARET            { ast.TAG_GT; }
            else if binop == tokens.TOK_RCARET_EQ         { ast.TAG_GE; }
            else if binop == tokens.TOK_EQ                { ast.TAG_ASSIGN; }
            else if binop == tokens.TOK_PLUS_EQ           { ast.TAG_ASSIGN_ADD; }
            else if binop == tokens.TOK_MINUS_EQ          { ast.TAG_ASSIGN_SUB; }
            else if binop == tokens.TOK_STAR_EQ           { ast.TAG_ASSIGN_MULT; }
            else if binop == tokens.TOK_FSLASH_EQ         { ast.TAG_ASSIGN_DIV; }
            else if binop == tokens.TOK_FSLASH_FSLASH_EQ  { ast.TAG_ASSIGN_INT_DIV; }
            else if binop == tokens.TOK_PERCENT_EQ        { ast.TAG_ASSIGN_MOD; }
            else if binop == tokens.TOK_IF                { ast.TAG_SELECT_OP; }
            else { 0; };

        if tag == ast.TAG_SELECT_OP and cur_tok == tokens.TOK_ELSE {
            # If we matched an <expr> "if" <expr> check to see if
            # there is an "else" adjacent. If so this turns into a
            # conditional expression.
            let node: ast.Node = ast.make(ast.TAG_CONDITIONAL);
            let expr: ^ast.ConditionalExpr =
                ast.unwrap(node) as ^ast.ConditionalExpr;

            expr.lhs = lhs;
            expr.condition = rhs;

            # Consume the "else" token.
            bump_token();

            # Parse the expression for the RHS.
            expr.rhs = parse_expr();
            if ast.isnull(expr.rhs) { return ast.null(); }

            lhs = node;
        } else if tag <> 0 {
            # Merge LHS/RHS into a binary expression node.
            let node: ast.Node = ast.make(tag);
            let expr: ^ast.BinaryExpr = ast.unwrap(node) as ^ast.BinaryExpr;
            expr.lhs = lhs;
            expr.rhs = rhs;
            lhs = node;
        }
    }

    # Unreachable code.
    return ast.null();
}

# Member expression
# -----------------------------------------------------------------------------
def parse_member_expr(mut lhs: ast.Node) -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_MEMBER);
    let mem: ^ast.BinaryExpr = ast.unwrap(node) as ^ast.BinaryExpr;
    mem.lhs = lhs;

    # Consume the "." token.
    bump_token();

    if cur_tok <> tokens.TOK_IDENTIFIER {
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected identifier" as ^int8);
        errors.end();

        return ast.null();
    }

    # Parse the identifier.
    mem.rhs = parse_ident();
    if ast.isnull(mem.rhs) { return ast.null(); }

    # Return our constructed node.
    node;
}

# Index expression
# -----------------------------------------------------------------------------
def parse_index_expr(mut lhs: ast.Node) -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_INDEX);
    let idx: ^ast.IndexExpr = ast.unwrap(node) as ^ast.IndexExpr;
    idx.expression = lhs;

    # Consume the "[" token.
    bump_token();

    # Parse the subscript expression.
    idx.subscript = parse_expr();
    if ast.isnull(idx.subscript) { return ast.null(); }

    if cur_tok <> tokens.TOK_RBRACKET {
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected `]`" as ^int8);
        errors.end();

        return ast.null();
    }

    # Consume the "]" token.
    bump_token();

    # Return our constructed node.
    node;
}

# Call expression
# -----------------------------------------------------------------------------
def parse_call_expr(mut lhs: ast.Node) -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_CALL);
    let cal: ^ast.CallExpr = ast.unwrap(node) as ^ast.CallExpr;
    cal.expression = lhs;

    # Consume the "(" token.
    bump_token();

    # Parse the arguments.
    let mut in_named_arguments: bool = false;
    let mut error: bool = false;
    while cur_tok <> tokens.TOK_RPAREN {
        # Declare the argument node.
        let arg_node: ast.Node = ast.make(ast.TAG_CALL_ARG);
        let arg: ^ast.Argument = ast.unwrap(arg_node) as ^ast.Argument;

        # This is a named argument if we have a ( ident "=" ) sequence.
        if cur_tok == tokens.TOK_IDENTIFIER and next_tok == tokens.TOK_EQ {
            # Read in the name.
            arg.name = parse_ident();
            if ast.isnull(arg.name) { return ast.null(); }

            # Consume the "=" token.
            bump_token();

            # Mark that we have entered the land of named arguments.
            in_named_arguments = true;
        } else if in_named_arguments and ast.isnull(arg.name) {
            # If we didn't get a named argument but are in the
            # land of named arguments throw an error.
            error_consume_until(tokens.TOK_RPAREN);
            errors.begin_error();
            errors.fprintf(errors.stderr, "non-keyword argument after keyword argument" as ^int8);
            errors.end();
            error = true;
            break;
        }

        # Parse the argument expression.
        arg.expression = parse_expr();
        if ast.isnull(arg.expression) { return ast.null(); }

        # Push the argument onto the arguments list.
        cal.arguments.push(arg_node);

        # Is there a "," to continue the argument list.
        if cur_tok == tokens.TOK_COMMA {
            # Consume the "comma" token.
            bump_token();

            # Is there another comma?
            if cur_tok == tokens.TOK_COMMA {
                # Consume the errorenous comma.
                bump_token();
                error_consume_until(tokens.TOK_RPAREN);

                errors.begin_error();
                errors.fprintf(errors.stderr, "unexpected `,`" as ^int8);
                errors.end();

                return ast.null();
            }

            # Continue looking for arguments.
            continue;
        }

        # Break out; no more arguments.
        break;
    }

    if cur_tok <> tokens.TOK_RPAREN {
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected `)`" as ^int8);
        errors.end();

        return ast.null();
    } else if error {
        # Consume the ")" token.
        bump_token();

        return ast.null();
    }

    # Consume the ")" token.
    bump_token();

    # Return our constructed node.
    node;
}

# Postfix expression (with a specific LHS)
# -----------------------------------------------------------------------------
def parse_postfix_lhs(mut lhs: ast.Node) -> ast.Node {
    # Delegate to the appropriate postfix parse.
    let expr: ast.Node;
    if cur_tok == tokens.TOK_LPAREN {
        expr = parse_call_expr(lhs);
    } else if cur_tok == tokens.TOK_LBRACKET {
        expr = parse_index_expr(lhs);
    } else if cur_tok == tokens.TOK_DOT {
        expr = parse_member_expr(lhs);
    }

    # Return nil if that didn't succeed.
    if ast.isnull(expr) { return ast.null(); }

    # Are we consuming this as a postfix expression?
    if cur_tok == tokens.TOK_LPAREN
            or cur_tok == tokens.TOK_LBRACKET
            or cur_tok == tokens.TOK_DOT {
        # Consume this as an LHS to a postfix expression.
        parse_postfix_lhs(expr);
    } else {
        # Nope; just return the expression.
        expr;
    }
}

# Postfix expression
# -----------------------------------------------------------------------------
# postfix_expr = primary_expr
#              | postfix_expr "(" [ arguments ] ")"
#              | postfix_expr "[" expr "]"
# -----------------------------------------------------------------------------
def parse_postfix_expr() -> ast.Node {
    # Attempt to parse the `invoked` expression as a primary expression.
    let operand: ast.Node = parse_primary_expr();

    # Return nil if that didn't succeed.
    if ast.isnull(operand) { return ast.null(); }

    # Are we consuming this operand as a postfix expression?
    if cur_tok == tokens.TOK_LPAREN
            or cur_tok == tokens.TOK_LBRACKET
            or cur_tok == tokens.TOK_DOT {
        # Consume the operand as an LHS to a postfix expression.
        parse_postfix_lhs(operand);
    } else {
        # Nope; just return the primary expression.
        operand;
    }
}

# Unary expression
# -----------------------------------------------------------------------------
# unary_expr = postfix_expr
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
        return parse_postfix_expr();
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
    } else if cur_tok == tokens.TOK_FLOAT {
        parse_float_expr();
    } else if cur_tok == tokens.TOK_TRUE or cur_tok == tokens.TOK_FALSE {
        parse_bool_expr();
    } else if cur_tok == tokens.TOK_LPAREN {
        parse_paren_expr();
    } else if cur_tok == tokens.TOK_IDENTIFIER {
        parse_ident();
    } else if cur_tok == tokens.TOK_IF {
        parse_select_expr();
    } else if cur_tok == tokens.TOK_TYPE {
        parse_type_expr();
    } else {
        if cur_tok == tokens.TOK_RETURN {
            bump_token();
            errors.begin_error();
            errors.fprintf(errors.stderr, "unexpected `return`" as ^int8);
            errors.end();
        }

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
    decl.name.extend(tokenizer.current_id.data() as str);

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
    } else if cur_tok == tokens.TOK_TYPE {
        # A type deferrence expression.
        # Declare the node.
        let node: ast.Node = ast.make(ast.TAG_TYPE_EXPR);
        let expr: ^ast.TypeExpr = ast.unwrap(node) as ^ast.TypeExpr;

        # Consume the `type` token.
        bump_token();

        # There must be a "(" next to start the type expression.
        if cur_tok <> tokens.TOK_LPAREN {
            error_consume_until(tokens.TOK_RPAREN);
            errors.begin_error();
            errors.fprintf(errors.stderr, "expected `(`" as ^int8);
            errors.end();

            return ast.null();
        }

        # Consume the "(" token.
        bump_token();

        # Parse the expression.
        expr.expression = parse_expr();
        if ast.isnull(expr.expression) { return ast.null(); }

        # There must be a ")" next to end the type expression.
        if cur_tok <> tokens.TOK_RPAREN {
            error_consume();
            errors.begin_error();
            errors.fprintf(errors.stderr, "expected `(`" as ^int8);
            errors.end();

            return ast.null();
        }

        # Consume the ")" token.
        bump_token();

        # Return the expr.
        node;
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
        error_consume();
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected `:` (static slots must have a type annotation)" as ^int8);
        errors.end();

        return ast.null();
    }

    # Consume the ":" token.
    bump_token();

    # There should be a type expression next.
    decl.type_ = parse_type_expr();
    if ast.isnull(decl.type_) { return ast.null(); }

    # There must be an "=" next to indicate the start of the initializer
    # for this static slot.
    if cur_tok == tokens.TOK_EQ {
        # Consume the "=" and parse the initializer expression.
        bump_token();
        decl.initializer = parse_expr();
        if ast.isnull(decl.initializer) { return ast.null(); }
    } else {
        error_consume();
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected `=` (static slots must have an initializer)" as ^int8);
        errors.end();

        return ast.null();
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
        if ast.isnull(decl.type_) { return ast.null(); }
    }

    # There can be an "=" next to indicate the start of the initialzier
    # for this static slot.
    if cur_tok == tokens.TOK_EQ {
        # Consume the "=" and parse the initializer expression.
        bump_token();
        decl.initializer = parse_expr();
        if ast.isnull(decl.initializer) { return ast.null(); }
    } else {
        # There is no initializer.
        decl.initializer = ast.null();
    }

    # Return our constructed declaration.
    node;
}

# Selection expression branch
# -----------------------------------------------------------------------------
# select-branch = expr "{" { statement } "}"
# -----------------------------------------------------------------------------
def parse_select_branch(condition: bool) -> ast.Node {
    # Declare the branch node.
    let node: ast.Node = ast.make(ast.TAG_SELECT_BRANCH);
    let mut branch: ^ast.SelectBranch = ast.unwrap(node) as ^ast.SelectBranch;
    let mut failed: bool = false;

    if condition {
        # Expect and parse the condition expression.
        branch.condition = parse_expr();
        if ast.isnull(branch.condition) { return ast.null(); }
    }

    # Parse the block.
    if not parse_block(branch.nodes) { return ast.null(); }

    # Return our parsed node.
    node;
}

# Selection expression
# -----------------------------------------------------------------------------
# select-expr = "if" select-branch
# -----------------------------------------------------------------------------
def parse_select_expr() -> ast.Node {
    # Declare the selection expr node.
    let node: ast.Node = ast.make(ast.TAG_SELECT);
    let select: ^ast.SelectExpr = ast.unwrap(node) as ^ast.SelectExpr;
    let have_else: bool = false;
    let branch: ast.Node;

    loop {
        # Consume the "if" token.
        bump_token();

        # Parse the branch.
        branch = parse_select_branch(true);
        if ast.isnull(branch) { return ast.null(); }

        # Append the branch to the selection expression.
        select.branches.push(branch);

        # Check for an "else" branch.
        if cur_tok == tokens.TOK_ELSE {
            have_else = true;

            # Consume the "else" token.
            bump_token();

            # Check for an adjacent "if" token (which would make this
            # an "else if" and part of this selection expression).
            if cur_tok == tokens.TOK_IF {
                have_else = false;

                # Loop back and parse another branch.
                continue;
            }
        }

        # We're done here.
        break;
    }

    # Parse the trailing "else" (if we have one).
    if have_else {
        # Parse the condition-less branch.
        branch = parse_select_branch(false);
        if ast.isnull(branch) { return ast.null(); }

        # Append the branch to the selection expression.
        select.branches.push(branch);
    }

    # Return the parsed node.
    node;
}

# Function parameter
# -----------------------------------------------------------------------------
# param = [ "mut" ] ident ":" type
# -----------------------------------------------------------------------------
def parse_param() -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_FUNC_PARAM);
    let param: ^ast.FuncParam = ast.unwrap(node) as ^ast.FuncParam;

    # Check if we are mutable.
    param.mutable = cur_tok == tokens.TOK_MUT;

    # If we are then consume the "mut" token.
    if param.mutable { bump_token(); }

    # There should be an identifier next.
    if cur_tok == tokens.TOK_IDENTIFIER {
        param.id = parse_ident();
        if ast.isnull(param.id) { return ast.null(); }
    }

    # There must be a ":" next to start the type annotation.
    if cur_tok <> tokens.TOK_COLON {
        # FIXME: Report a nice error message.
        return ast.null();
    }

    # Consume the ":" token.
    bump_token();

    # There should be a type expression next.
    param.type_ = parse_type_expr();
    if ast.isnull(param.type_) {
        # FIXME: Report a nice error message.
        return ast.null();
    }

    # There can be an "=" next to indicate the start of the default.
    if cur_tok == tokens.TOK_EQ {
        # Consume the "=" and parse the default expression.
        bump_token();
        param.default = parse_expr();
        if ast.isnull(param.default) {
            # FIXME: Report a nice error message.
            return ast.null();
        }
    } else {
        # There is no default.
        param.default = ast.null();
    }

    # Return the parsed node.
    node;
}

# Function parameters
# -----------------------------------------------------------------------------
# params = "(" [ param { "," param } ] ")"
# -----------------------------------------------------------------------------
def parse_params(&mut params: ast.Nodes) -> bool {
    # Consume the "(" token.
    bump_token();

    while       cur_tok <> tokens.TOK_RPAREN
            and cur_tok <> tokens.TOK_LBRACE
            and cur_tok <> tokens.TOK_RARROW
            and cur_tok <> tokens.TOK_SEMICOLON
            and cur_tok <> tokens.TOK_DEF
            and cur_tok <> tokens.TOK_END {
        # Parse the param.
        let param: ast.Node = parse_param();
        if ast.isnull(param) { return false; }

        # Append the branch to the selection expression.
        params.push(param);

        # Is there a "," to continue the parameter list.
        if cur_tok == tokens.TOK_COMMA {
            # Consume the "comma" token.
            bump_token();

            # Is there another comma?
            if cur_tok == tokens.TOK_COMMA {
                # Consume the errorenous comma.
                bump_token();
                error_consume();

                errors.begin_error();
                errors.fprintf(errors.stderr, "unexpected `,`" as ^int8);
                errors.end();

                return false;
            }

            # Continue looking for parameters.
            continue;
        }

        # We're done.
        break;
    }

    # There must be a ")" next to start the parameter list.
    if cur_tok <> tokens.TOK_RPAREN {
        error_consume();
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected `)`" as ^int8);
        errors.end();

        return false;
    }

    # Consume the ")" token.
    bump_token();

    # Everything looks good.
    true;
}

# Function Declaration
# -----------------------------------------------------------------------------
# function-decl = "def" ident params [ "->" type ] block
# -----------------------------------------------------------------------------
def parse_function_decl() -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_FUNC_DECL);
    let mut func: ^ast.FuncDecl = ast.unwrap(node) as ^ast.FuncDecl;

    # Consume the "def" token.
    bump_token();

    # There should be an identifier next.
    func.id = parse_ident();

    # There should be a parameter list next.
    if not parse_params(func.params) { return ast.null(); }

    # There can be a "->" next to indicate the start of the return type.
    if cur_tok == tokens.TOK_RARROW {
        # Consume the "->" and parse the return type expression.
        bump_token();
        func.return_type = parse_type_expr();
        if ast.isnull(func.return_type) { return ast.null(); }
    } else {
        # There is no return type.
        func.return_type = ast.null();
    }

    # Parse the function block.
    if not parse_block(func.nodes) { return ast.null(); }

    # Return the constructed node.
    node;
}

# Unsafe block
# -----------------------------------------------------------------------------
# unsafe-block = "unsafe" block
# -----------------------------------------------------------------------------
def parse_unsafe_block() -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_UNSAFE);
    let mut unsafe_: ^ast.UnsafeBlock = ast.unwrap(node) as ^ast.UnsafeBlock;

    # Consume the "unsafe" token.
    bump_token();

    # Parse the unsafe block.
    if not parse_block(unsafe_.nodes) { return ast.null(); }

    # Return the constructed node.
    node;
}

# Return expression
# -----------------------------------------------------------------------------
# return-expr = "return" [ expr ] ";"
# -----------------------------------------------------------------------------
def parse_return_expr() -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_RETURN);
    let mut ret: ^ast.ReturnExpr = ast.unwrap(node) as ^ast.ReturnExpr;

    # Capture the prec of the `return` token.
    let return_prec: int = get_binop_tok_precedence();

    # Consume the "return" token.
    bump_token();

    # Continue the return expression.
    if cur_tok <> tokens.TOK_SEMICOLON {
        ret.expression = parse_primary_expr();
        if ast.isnull(ret.expression) { return ast.null(); }

        # Parse the remainder of the `return` value expression.
        ret.expression = parse_binop_rhs(return_prec, 0, ret.expression);

        # Parse the remainder of the `return` expression (capturing those
        # now allowed binary operators like `if`).
        node = parse_binop_rhs(0, 0, node);
    }

    # Return the constructed node.
    node;
}

# Import
# -----------------------------------------------------------------------------
# import = "import" ident { "." ident }
# -----------------------------------------------------------------------------
def parse_import() -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_IMPORT);
    let mut imp: ^ast.Import = ast.unwrap(node) as ^ast.Import;

    # Consume the "import" token.
    bump_token();

    loop {
        # There must be at least one `ident` next.
        if cur_tok <> tokens.TOK_IDENTIFIER {
            error_consume();
            errors.begin_error();
            errors.fprintf(errors.stderr, "expected `identifier`" as ^int8);
            errors.end();

            return ast.null();
        }

        # Parse the identifier token and push it onto the collection.
        let id: ast.Node = parse_ident();
        imp.ids.push(id);

        # Continue if there is a `.` next.
        if cur_tok == tokens.TOK_DOT {
            # Consume the `.`
            bump_token();

            # Match the next id.
            continue;
        }

        # We're done.
        break;
    }

    # Return the constructed node.
    node;
}

# Statement
# -----------------------------------------------------------------------------
# statement = primary_expr ";"
#           | slot_decl ";"
# -----------------------------------------------------------------------------
def parse_statement() -> ast.Node {
    if cur_tok == tokens.TOK_STATIC { return parse_static_decl(); }
    if cur_tok == tokens.TOK_LET    { return parse_local_decl(); }
    if cur_tok == tokens.TOK_UNSAFE { return parse_unsafe_block(); }
    if cur_tok == tokens.TOK_MODULE { return parse_module(); }
    if cur_tok == tokens.TOK_RETURN { return parse_return_expr(); }
    if cur_tok == tokens.TOK_IMPORT { return parse_import(); }

    if cur_tok == tokens.TOK_SEMICOLON {
        bump_token();              # consume the semicolon
        return parse_statement();  # and parse again
    }

    if cur_tok == tokens.TOK_DEF {
        # Functions are only declarations if they are named.
        if next_tok == tokens.TOK_IDENTIFIER {
            return parse_function_decl();
        }
    }

    if cur_tok == tokens.TOK_LBRACE {
        # Parse a random block expression.
        return parse_block_expr();
    }

    # Maybe we have an expression.
    parse_expr();
}

# error_consume -- Consume errorneous tokens / nodes as much as possible.
# -----------------------------------------------------------------------------
def error_consume() {
    while       cur_tok <> tokens.TOK_END
            and cur_tok <> tokens.TOK_SEMICOLON
            and cur_tok <> tokens.TOK_DEF {
        bump_token();
    }
}

# error_consume_until
# -----------------------------------------------------------------------------
def error_consume_until(tok: int) {
    while       cur_tok <> tok
            and cur_tok <> tokens.TOK_SEMICOLON {
        bump_token();
    }
}

# Block expression
# -----------------------------------------------------------------------------
# block-expr = block
# -----------------------------------------------------------------------------
def parse_block_expr() -> ast.Node {
    # Declare the node.
    let node: ast.Node = ast.make(ast.TAG_BLOCK);
    let mut block: ^ast.Block = ast.unwrap(node) as ^ast.Block;

    # Parse the unsafe block.
    if not parse_block(block.nodes) { return ast.null(); }

    # Return the constructed node.
    node;
}

# Block
# -----------------------------------------------------------------------------
# block = "{" { statement } "}"
# -----------------------------------------------------------------------------
def parse_block(&mut nodes: ast.Nodes) -> bool {
    # There must be a "{" next to start the block.
    if cur_tok <> tokens.TOK_LBRACE {
        error_consume();
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected `{`" as ^int8);
        errors.end();

        return false;
    }

    # Consume the "{" token.
    bump_token();

    # Iterate and attempt to match statements until the block is closed.
    let mut matched: ast.Node;
    while       cur_tok <> tokens.TOK_RBRACE
            and cur_tok <> tokens.TOK_END {
        # Attempt to parse an expression.
        matched = parse_statement();
        if ast.isnull(matched) {
            # Error'd out; attempt to consume the expression.
            continue;
        }

        # Matched the full sub-rule; append the node to the module.
        nodes.push(matched);
    }

    # There must be a "}" next to start the block.
    if cur_tok <> tokens.TOK_RBRACE {
        error_consume();
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected `}`" as ^int8);
        errors.end();

        false;
    } else {
        # Consume the "}" token.
        bump_token();

        # Everything looks fine.
        true;
    }

}

# Module
# -----------------------------------------------------------------------------
# module = "module" ident "{" { statement } "}"
# -----------------------------------------------------------------------------
def parse_module() -> ast.Node {
    # Declare the module decl node.
    let node: ast.Node = ast.make(ast.TAG_MODULE);
    let mod: ^ast.ModuleDecl = ast.unwrap(node) as ^ast.ModuleDecl;

    # Consume the "module" token.
    bump_token();

    # Check for and attempt to consume an identifier.
    if cur_tok == tokens.TOK_IDENTIFIER {
        mod.id = parse_ident();
        if ast.isnull(mod.id) { return ast.null(); }
    } else {
        errors.begin_error();
        errors.fprintf(errors.stderr, "expected identifier" as ^int8);
        errors.end();

        return ast.null();
    }

    # Iterate and attempt to match statements.
    if not parse_block(mod.nodes) { return ast.null(); }

    # Return our node.
    node;
}

# Top
# -----------------------------------------------------------------------------
# top = { statement }
# -----------------------------------------------------------------------------
def parse_top() -> ast.Node {
    # Declare the module decl node.
    let node: ast.Node = ast.make(ast.TAG_MODULE);
    let mod: ^ast.ModuleDecl = ast.unwrap(node) as ^ast.ModuleDecl;

    # FIXME: Set the name of the module to the basename of the file.
    mod.id = ast.make(ast.TAG_IDENT);
    let id_decl: ^ast.Ident = ast.unwrap(mod.id) as ^ast.Ident;
    id_decl.name.extend("_");

    # Iterate and attempt to match statements.
    let mut matched: ast.Node;
    loop {
        # Are we at the end?
        if cur_tok == tokens.TOK_END {
            # We're done here.
            break;
        }

        # Attempt to parse an expression.
        matched = parse_statement();
        if ast.isnull(matched) {
            # Error'd out; attempt to consume the expression.
            continue;
        }

        # Matched the full sub-rule; append the node to the module.
        mod.nodes.push(matched);
    }

    # Return our node.
    node;
}

# Parse
# -----------------------------------------------------------------------------
def parse() -> ast.Node {
    # Prime the token buffer.
    bump_token();

    # Parse the top-level module.
    let node: ast.Node = parse_top();
    node;
}

# Main
# -----------------------------------------------------------------------------
def main() {
    # Parse the top-level module.
    let node: ast.Node = parse();

    if errors.count == 0 {
        # Dump the top-level module.
        ast.dump(node);

        # Exit and return success.
        libc.exit(0);
    } else {
        # Return failure.
        libc.exit(-1);
    }
}
