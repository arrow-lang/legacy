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
    while tok <> tokens.TOK_END { parse_item(mod.nodes); }

    # Return our node.
    node;
}

# Item
# -----------------------------------------------------------------------------
# item = module | static-slot | import | function | block | expression
# -----------------------------------------------------------------------------
def parse_item(&mut self, &mut nodes: ast.Nodes) -> bool {
    # Peek ahead and see if we are a module `item`.
    let tok: int = self.peek_token(1);
    if tok == tokens.TOK_MODULE { return self.parse_module(nodes); }
    if tok == tokens.TOK_IMPORT { return self.parse_import(nodes); }
    if tok == tokens.TOK_UNSAFE { return self.parse_unsafe(nodes); }
    if tok == tokens.TOK_STATIC { return self.parse_static_slot(nodes); }

    if tok == tokens.TOK_DEF {
        # Functions are only `items` if they are named.
        if self.peek_token(2) == tokens.TOK_IDENTIFER {
            return self.parse_function(nodes);
        }
    }

    if tok == tokens.TOK_LBRACE {
        # Block expression is treated as if it appeared in a
        # function (no `item` may appear inside).
        return self.parse_block(nodes);
    }

    if tok == tokens.TOK_SEMICOLON {
        # Consume the semicolon and attempt to match the next item.
        self.pop_token();
        return self.parse_item(nodes);
    }

    # We have decided that we are "not" an `item` but we could be
    # an expression; forward.
    self.parse_expression(nodes);
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
