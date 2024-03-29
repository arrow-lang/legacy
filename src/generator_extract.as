import string;
import types;
import errors;
import libc;
import llvm;
import code;
import ast;
import list;
import generator_;
import generator_util;
import tokenizer;
import parser;

# Extract declaration "items" from the AST and build our list of namespaced
# items.
# -----------------------------------------------------------------------------
let extract(mut g: generator_.Generator, node: ast.Node): bool ->
{
    # Delegate to an appropriate function to handle the item
    # extraction.
    if node.tag == ast.TAG_MODULE
    {
        extract_module(g, node.unwrap() as *ast.ModuleDecl);
    }
    else if node.tag == ast.TAG_FUNC_DECL
    {
        extract_function(g, node.unwrap() as *ast.FuncDecl);
    }
    else if node.tag == ast.TAG_SLOT
    {
        extract_static_slot(g, node.unwrap() as *ast.SlotDecl);
    }
    else if node.tag == ast.TAG_STRUCT
    {
        extract_struct(g, node.unwrap() as *ast.Struct);
    }
    else if node.tag == ast.TAG_EXTERN_FUNC
    {
        extract_extern_function(g, node.unwrap() as *ast.ExternFunc);
    }
    else if node.tag == ast.TAG_EXTERN_STATIC
    {
        extract_extern_static(g, node.unwrap() as *ast.ExternStaticSlot);
    }
    else if node.tag == ast.TAG_IMPORT
    {
        extract_import(g, node.unwrap() as *ast.Import);
    }
    else if node.tag == ast.TAG_IMPLEMENT
    {
        extract_implement(g, node.unwrap() as *ast.Implement);
    }
    else { return false; };

    # Return success.
    true;
}

# Extract a sequence of items.
# -----------------------------------------------------------------------------
let extract_items(mut g: generator_.Generator,
                  extra: *mut ast.Nodes, nodes: ast.Nodes) ->
{
    # Enumerate through each node and forward them to `_extract_item`.
    let mut i: int = 0;
    while i as uint < nodes.size() {
        let node: ast.Node = nodes.get(i);
        i = i + 1;
        if not extract(g, node) { extra.push(node); };
    }
}

# Extract a "module" item.
# -----------------------------------------------------------------------------
let extract_module(mut g: generator_.Generator, x: *ast.ModuleDecl) ->
{
    # Build the qual name for this module.
    let id: *ast.Ident = x.id.unwrap() as *ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a `code` handle for this module.
    let han: *code.Handle = code.make_module(id.name.data() as str, g.ns);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as *int8);

    # Set us as the `top` namespace if there isn't one yet.
    if g.top_ns.size() == 0  { g.top_ns.extend(id.name.data() as str); };

    # Push our name onto the namespace stack.
    g.ns.push_str(id.name.data() as str);

    # Generate each node in the module and place items that didn't
    # get extracted into the new node block.
    let nodes: *mut ast.Nodes = ast.new_nodes();
    extract_items(g, nodes, x.nodes);
    g.nodes.set_ptr(qname.data() as str, nodes as *int8);

    # Pop our name off the namespace stack.
    g.ns.erase(-1);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract a "function" item.
# -----------------------------------------------------------------------------
let extract_function(mut g: generator_.Generator, x: *ast.FuncDecl) ->
{
    # Build the qual name for this function.
    let id: *ast.Ident = x.id.unwrap() as *ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a `code` handle for the function (ignoring the type for now).
    let han: *code.Handle = code.make_function(
        x, id.name.data() as str, g.ns, code.make_nil(),
        0 as *llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as *int8);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract a "static slot" item.
# -----------------------------------------------------------------------------
let extract_static_slot(mut g: generator_.Generator, x: *ast.SlotDecl) ->
{
    # Build the qual name for this slot.
    let id: *ast.Ident = x.id.unwrap() as *ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a solid handle for the slot (ignoring the type for now).
    let han: *code.Handle = code.make_static_slot(
        x, id.name.data() as str, g.ns,
        code.make_nil(),
        0 as *llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as *int8);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract a "structure" item.
# -----------------------------------------------------------------------------
let extract_struct(mut g: generator_.Generator, x: *ast.Struct) ->
{
    # Build the qualified name for this item.
    let id: *ast.Ident = x.id.unwrap() as *ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a solid handle for the item (ignoring the type for now).
    let han: *code.Handle = code.make_struct(
        x, id.name.data() as str, g.ns,
        code.make_nil(),
        0 as *llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as *int8);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract external "function" item.
# -----------------------------------------------------------------------------
let extract_extern_function(mut g: generator_.Generator, x: *ast.ExternFunc) ->
{
    # Build the qual name for this function "item".
    let id: *ast.Ident = x.id.unwrap() as *ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a `code` handle for the function (ignoring the type for now).
    let han: *code.Handle = code.make_extern_function(
        x, id.name.data() as str, g.ns, code.make_nil(),
        0 as *llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as *int8);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract external "static" item.
# -----------------------------------------------------------------------------
let extract_extern_static(mut g: generator_.Generator,
                          x: *ast.ExternStaticSlot) ->
{
    # Build the qual name for this function "item".
    let id: *ast.Ident = x.id.unwrap() as *ast.Ident;
    let mut qname: string.String = generator_util.qualify_name(
        g, id.name.data() as str);

    # Create a `code` handle for the function (ignoring the type for now).
    let han: *code.Handle = code.make_extern_static(
        x, id.name.data() as str, g.ns, code.make_nil(),
        0 as *llvm.LLVMOpaqueValue);

    # Set us as an `item`.
    g.items.set_ptr(qname.data() as str, han as *int8);

    # Dispose of dynamic memory.
    qname.dispose();
}

# Extract "implement" block.
# -----------------------------------------------------------------------------
let extract_implement(mut g: generator_.Generator, x: *ast.Implement) ->
{
    # We should iterate through each member function and extract
    # it separately as a "instance" or "attached" function bound to the
    # type node.
    let mut i: int = 0;
    while i as uint < x.methods.size() {
        let node: ast.Node = x.methods.get(i);
        i = i + 1;

        extract_attached_function(g, &x.type_, node.unwrap() as *ast.FuncDecl);
    }
}

# Extract an "attached function" item.
# -----------------------------------------------------------------------------
let extract_attached_function(mut g: generator_.Generator,
                              type_: *ast.Node,
                              x: *ast.FuncDecl) ->
{
    # Build the name for this function.
    let id: *ast.Ident = x.id.unwrap() as *ast.Ident;

    # Create a `code` handle for the function (ignoring the type for now).
    let han: *code.Handle = code.make_attached_function(
        x, id.name.data() as str, g.ns, type_);

    # Push this into the "attached" function list.
    g.attached_functions.push_ptr(han as *int8);
}

# Extract "import"
# -----------------------------------------------------------------------------
let extract_import(mut g: generator_.Generator, x: *ast.Import) ->
{
    # Build the filename to import.
    # TODO: Handle importing folders and ./index.as, etc.
    let id0_node: ast.Node = x.ids.get(0);
    let id0: *ast.Ident = id0_node.unwrap() as *ast.Ident;

    # Check if this module (from its name) has been imported before.
    if g.imported_modules.contains(id0.name.data() as str) {
        # Yes; just skip out. We're done here.
        return;
    };

    # Iterate through our available import paths and attempt to find our
    # file.
    let mut i: uint = 0;
    let mut found = false;
    let mut filename = string.String.new();

    while i < g.import_paths.size {
        # Build the filename.
        filename.clear();
        filename.extend(g.import_paths.get_str(i));
        # FIXME: We need a solid path manipulation library
        # Ensure we have a "[..]/"
        if filename._data.get_i8(-1) != ("/" as char) as int8 {
            filename.append("/");
        };
        i = i + 1;
        filename.extend(id0.name.data() as str);
        filename.extend(".as");

        # Check if the filename exists.
        if posix.access(filename.data(), 0) != 0 { continue; };

        # Found us a match; break.
        found = true;
        break;
    }

    if not found
    {
        errors.begin_error();
        errors.libc.fprintf(errors.libc.stderr,
                            "cannot find module for '%s'",
                            id0.name.data());
        errors.end();
        return;
    };

    # Open a stream to the file.
    let stream = libc.fopen(filename.data(), "r");

    # NOTE: There should be a "Compiler" class or module.
    # Declare the tokenizer.
    let fn: *int8 = filename.data() as *int8;
    let mut t: tokenizer.Tokenizer = tokenizer.Tokenizer.new(
        fn as str, stream);

    # Determine the "module name"
    let mut module_name = string.String.new();
    module_name.extend(posix.basename(filename.data()));
    let endptr = libc.strrchr(module_name.data(), ("." as char) as uint8);
    *(endptr as *int8) = 0;

    # Declare the parser.
    let mut p: parser.Parser = parser.parser_new(module_name.data(), t);

    # Parse the AST from the standard input.
    let unit: ast.Node = p.parse();

    # Dispose.
    filename.dispose();
    t.dispose();
    p.dispose();

    # Isolate the module in its own empty namespace block.
    let mut ns: list.List = list.List.new(types.STR);
    let mut old_ns: list.List = g.ns;
    g.ns = ns;

    # Push us in the as an "imported module".
    g.imported_modules.set_i8(id0.name.data() as str, 1);

    # Pass us on to the module extractor.
    extract_module(g, unit.unwrap() as *ast.ModuleDecl);

    # Put the old ns back.
    g.ns = old_ns;

    # Dispose.
    ns.dispose();
}
