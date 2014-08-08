import code;
import dict;
import list;
import types;
import errors;
import llvm;
import ast;
import generator_;
import generator_util;
import resolver;
import builder;

# Perform type realization on those constructs that need a little extra help
# before type resolution.
# -----------------------------------------------------------------------------
let generate(mut g: generator_.Generator) ->
{
    # Iterate over the "attached functions" list.
    let mut n: int = 0;
    let mut val: *code.Handle;
    while n as uint < g.attached_functions.size {
        # Grab the next "attached function"
        val = g.attached_functions.get_ptr(n) as *code.Handle;
        n = n + 1;

        # Resolve its "type"
        generate_attached_function(g, val);
    }
}

# Generate the "type" for an attached function to attach to.
# -----------------------------------------------------------------------------
let generate_attached_function(mut g: generator_.Generator,
                               handle: *code.Handle) ->
{
    # Unwrap our real type.
    let x: *code.AttachedFunction = handle._object as *code.AttachedFunction;

    # Resolve the type handle that we are "attaching" to.
    let attached_type_handle: *code.Handle = resolver.resolve_in(
        &g, x.attached_type_node, &x.namespace,
        code.make_nil_scope(),
        code.make_nil());
    let attached_type: *code.Type = attached_type_handle._object as *code.Type;

    # Set the `attached_type` on the attached function.
    x.attached_type = attached_type_handle;

    # Build a `qualified` name for this type.
    x.qualified_name = generator_util.qualified_name_ref(attached_type_handle);
    x.qualified_name.append(".");
    x.qualified_name.extend(x.name.data() as str);

    # Realize us in the items dictionary.
    g.items.set_ptr(x.qualified_name.data() as str, handle as *int8);
}
