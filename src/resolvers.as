import generator_;
import code;
import ast;
import list;
import errors;
import generator_util;
import generator_type;

# Internal
# =============================================================================

# Resolve a type from an item.
# -----------------------------------------------------------------------------
def _type_of(g: ^mut generator_.Generator, item: ^code.Handle)
    -> ^code.Handle
{
    if not code.is_type(item) {
        # Extract type from identifier.
        if item._tag == code.TAG_STATIC_SLOT
        {
            # This is a static slot; get its type.
            generator_type.generate_static_slot(
                g^, item._object as ^code.StaticSlot);
        }
        else if item._tag == code.TAG_LOCAL_SLOT
        {
            # This is a local slot; just return the type.
            let slot: ^code.LocalSlot = item._object as ^code.LocalSlot;
            slot.type_;
        }
        else if item._tag == code.TAG_FUNCTION
        {
            # This is a static slot; get its type.
            generator_type.generate_function(
                g^, item._object as ^code.Function);
        }
        else if item._tag == code.TAG_MODULE
        {
            # This is a module; deal with it.
            item;
        }
        else
        {
            # Return nil.
            code.make_nil();
        }
    } else {
        # Return the type reference.
        item;
    }
}

# Resolvers
# =============================================================================

# Boolean [TAG_BOOLEAN]
# -----------------------------------------------------------------------------
def boolean(g: ^mut generator_.Generator, node: ^ast.Node,
            scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle
{
    # Yep; this is a boolean.
    (g^).items.get_ptr("bool") as ^code.Handle;
}

# Integer [TAG_INTEGER]
# -----------------------------------------------------------------------------
def integer(g: ^mut generator_.Generator, node: ^ast.Node,
            scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle
{
    if not code.isnil(target) {
        if (target._tag == code.TAG_INT_TYPE
                or target._tag == code.TAG_FLOAT_TYPE) {
            # Return the targeted type.
            return target;
        }
    }

    # Without context we default to `int`.
    (g^).items.get_ptr("int") as ^code.Handle;
}

# Floating-point [TAG_FLOAT]
# -----------------------------------------------------------------------------
def float(g: ^mut generator_.Generator, node: ^ast.Node,
          scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle
{
    if not code.isnil(target) {
        if (target._tag == code.TAG_FLOAT_TYPE) {
            # Return the targeted type.
            return target;
        }
    }

    # Without context we default to `float64`.
    (g^).items.get_ptr("float64") as ^code.Handle;
}

# Identifier [TAG_IDENT]
# -----------------------------------------------------------------------------
def ident(g: ^mut generator_.Generator, node: ^ast.Node,
          scope: ^code.Scope, target: ^code.Handle) -> ^code.Handle {
    # A simple identifier; this refers directly to a "named" type
    # in the current scope or any enclosing outer scope.

    # Retrieve the item with scope resolution rules.
    let id: ^ast.Ident = (node^).unwrap() as ^ast.Ident;
    let item: ^code.Handle = generator_util.get_scoped_item_in(
        g^, id.name.data() as str, scope, g.ns);

    # Bail if we weren't able to resolve this identifier.
    if code.isnil(item) {
        errors.begin_error();
        errors.fprintf(errors.stderr,
                       "name '%s' is not defined" as ^int8,
                       id.name.data());
        errors.end();
        return code.make_nil();
    }

    # Resolve the item for its type.
    return _type_of(g, item);
}
