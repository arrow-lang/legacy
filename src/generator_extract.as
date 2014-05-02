import string;
import types;
import llvm;
import code;
import ast;
import list;
import generator_;
import generator_util;

# Extract declaration "items" from the AST and build our list of namespaced
# items.
# -----------------------------------------------------------------------------
def extract(&mut g: generator_.Generator, node: ast.Node) -> bool
{
    # Delegate to an appropriate function to handle the item
    # extraction.
    if node.tag == ast.TAG_MODULE
    {
        extract_module(g, node.unwrap() as ^ast.ModuleDecl);
    }
    else if node.tag == ast.TAG_FUNC_DECL
    {
        extract_function(g, node.unwrap() as ^ast.FuncDecl);
    }
    else if node.tag == ast.TAG_STATIC_SLOT
    {
        extract_static_slot(g, node.unwrap() as ^ast.StaticSlotDecl);
    }
    else if node.tag == ast.TAG_STRUCT
    {
        extract_struct(g, node.unwrap() as ^ast.Struct);
    }
    else { return false; }

    # Return success.
    true;
}

# Extract a sequence of items.
# -----------------------------------------------------------------------------
def extract_items(&mut g: generator_.Generator,
                  extra: ^mut ast.Nodes, &nodes: ast.Nodes)
{
    # Enumerate through each node and forward them to `_extract_item`.
    let mut i: int = 0;
    while i as uint < nodes.size() {
        let node: ast.Node = nodes.get(i);
        i = i + 1;
        if not extract(g, node) { (extra^).push(node); }
    }
}

# Extract a "module" item.
# -----------------------------------------------------------------------------
def extract_module(&mut g: generator_.Generator, x: ^ast.ModuleDecl)
{
    # Build the qual name for this module.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a `code` handle for this module.
    let han: ^code.Handle = code.make_module(id.name.data() as str, g.ns);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as ^void);

    # Set us as the `top` namespace if there isn't one yet.
    if g.top_ns.size() == 0  { g.top_ns.extend(id.name.data() as str); }

    # Push our name onto the namespace stack.
    g.ns.push_str(id.name.data() as str);

    # Generate each node in the module and place items that didn't
    # get extracted into the new node block.
    let nodes: ^mut ast.Nodes = ast.new_nodes();
    extract_items(g, nodes, x.nodes);
    g.nodes.set_ptr(qname.data() as str, nodes as ^void);

    # Pop our name off the namespace stack.
    g.ns.erase(-1);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract a "function" item.
# -----------------------------------------------------------------------------
def extract_function(&mut g: generator_.Generator, x: ^ast.FuncDecl)
{
    # Build the qual name for this function.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a `code` handle for the function (ignoring the type for now).
    let han: ^code.Handle = code.make_function(
        x, id.name.data() as str, g.ns, code.make_nil(),
        0 as ^llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as ^void);

    # Set us as the `top` namespace if there isn't one yet.
    if g.top_ns.size() == 0  { g.top_ns.extend(id.name.data() as str); }

    # Push our name onto the namespace stack.
    g.ns.push_str(id.name.data() as str);

    # Generate each node in the module and place items that didn't
    # get extracted into the new node block.
    let nodes: ^mut ast.Nodes = ast.new_nodes();
    let blk_node: ast.Node = x.block;
    let blk: ^ast.Block = blk_node.unwrap() as ^ast.Block;
    extract_items(g, nodes, blk.nodes);
    g.nodes.set_ptr(qname.data() as str, nodes as ^void);

    # Pop our name off the namespace stack.
    g.ns.erase(-1);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract a "static slot" item.
# -----------------------------------------------------------------------------
def extract_static_slot(&mut g: generator_.Generator, x: ^ast.StaticSlotDecl)
{
    # Build the qual name for this slot.
    let id: ^ast.Ident = x.id.unwrap() as ^ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a solid handle for the slot (ignoring the type for now).
    let han: ^code.Handle = code.make_static_slot(
        x, id.name.data() as str, g.ns,
        code.make_nil(),
        0 as ^llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as ^void);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract a "structure" item.
# -----------------------------------------------------------------------------
def extract_struct(&mut g: generator_.Generator, x: ^ast.Struct)
{
    errors.begin_error();
    errors.fprintf(errors.stderr, "not implemented: extract_struct" as ^int8);
    errors.end();
}
