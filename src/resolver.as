import generator_;
import code;
import ast;
import list;
import errors;
import generator_util;

# API
# =============================================================================

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_t(g: ^mut generator_.Generator, node: ^ast.Node,
              target: ^code.Handle)
    -> ^code.Handle
{
    resolve_in(g, node, &g.ns, code.make_nil_scope(), target);
}

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_st(g: ^mut generator_.Generator, node: ^ast.Node,
               scope: ^code.Scope,
               target: ^code.Handle)
    -> ^code.Handle
{
    resolve_in(g, node, &g.ns, scope, target);
}

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_s(g: ^mut generator_.Generator, node: ^ast.Node,
              scope: ^code.Scope)
    -> ^code.Handle
{
    resolve_in(g, node, &g.ns, scope, code.make_nil());
}

# Resolve an arbitrary targeted type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_in_t(g: ^mut generator_.Generator, node: ^ast.Node,
                 ns: ^list.List,
                 target: ^code.Handle)
    -> ^code.Handle
{
    resolve_in(g, node, ns, code.make_nil_scope(), target);
}

# Resolve an arbitrary type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve(g: ^mut generator_.Generator, node: ^ast.Node)
    -> ^code.Handle
{
    resolve_in(g, node, &g.ns, code.make_nil_scope(), code.make_nil());
}

# Resolve an arbitrary type expression from an AST node.
# -----------------------------------------------------------------------------
def resolve_in(g: ^mut generator_.Generator, node: ^ast.Node, ns: ^list.List,
               scope: ^code.Scope, target: ^code.Handle)
    -> ^code.Handle
{
    # Get the type resolution func.
    let res_fn: def (^mut generator_.Generator, ^ast.Node,
                     ^code.Scope, ^code.Handle)
            -> ^code.Handle
        = g.type_resolvers[node.tag];

    # Bail if we don't have a resolver.
    if (res_fn as ^void) as uint == 0 {
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr, "not implemented: resolve(%d)" as ^int8, node.tag);
        errors.end();

        return code.make_nil();
    }

    # Save the current namespace.
    let old_ns: list.List = g.ns;
    g.ns = ns^;

    # Resolve the type.
    let han: ^code.Handle = res_fn(g, node, scope, target);

    # Unset.
    g.ns = old_ns;

    # FIXME: Ensure that we are type compatible.
    # if not code.isnil(han) {
    #     if not code.isnil(target) {
    #         if not _type_compatible(target, han) {
    #             return code.make_nil();
    #         }
    #     }
    # }

    # Return our handle.
    han;
}
