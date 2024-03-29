import generator_;
import code;
import ast;
import list;
import errors;
import generator_util;

# API
# =============================================================================

# Build an arbitrary node.
# -----------------------------------------------------------------------------
let build(g: *mut generator_.Generator, node: *ast.Node,
          scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    build_in(g, node, &g.ns, scope, target);
}

# Build an arbitrary node.
# -----------------------------------------------------------------------------
let build_in(g: *mut generator_.Generator, node: *ast.Node, ns: *list.List,
             scope: *mut code.Scope, target: *code.Handle): *code.Handle ->
{
    # Get the build func.
    let fn = g.builders[node.tag];

    # FIXME: Bail if we don't have a builder.
    # if (fn as *void) as uint == 0 {
    #     errors.begin_error();
    #     errors.libc.fprintf(errors.libc.stderr, "not implemented: build(%d)" as *int8, node.tag);
    #     errors.end();

    #     return code.make_nil();
    # }

    # Save and set the namespace.
    let old_ns: list.List = g.ns;
    g.ns = *ns;

    # Resolve the type.
    let han: *code.Handle = fn(g, node, scope, target);

    # Unset our namespace.
    g.ns = old_ns;

    # Return the resolved type.
    han;
}
