

# NOTES:
# # In order to support mutual recursion in all spaces we re-arrange (sort)
# # declaration nodes according to their priority. In certain cases,
# # tags 3 to 7 can recurse by name reference so to support that,
# # if we detect a name error in which case we stop,
# # push it to the bottom (of 7) and continue (with a counter to check
# # for recursion).

# let _nodesize: uint = ast._sizeof(ast.TAG_NODE);
# # 1 - modules
# let mut mod_nodes: list.List = list.make_generic(_nodesize);
# # TODO: 2 - imports
# # let mut imp_nodes: list.List = list.make_generic(_nodesize);
# # TODO: 3 - use
# # TODO: 4 - opaque types (structs / enums / type)
# # let mut type_nodes: list.List = list.make_generic(_nodesize);
# # 5 - static declaration
# let mut static_nodes: list.List = list.make_generic(_nodesize);
# # 6 - function prototypes
# let mut fn_nodes: list.List = list.make_generic(_nodesize);
# # 7 - type bodies (structs / enums / type)
# # 8 - static declaration initializer
# # 9 - function bodies
# # 10 - other nodes
# let mut other_nodes: list.List = list.make_generic(_nodesize);

# # Enumerate through each node and sort it.
# let mut iter: ast.NodesIterator = ast.iter_nodes(nodes);
# while not ast.iter_empty(iter) {
#     let node: ast.Node = ast.iter_next(iter);
#     let lst: ^mut list.List =
#         if      node.tag == ast.TAG_MODULE        { &mod_nodes; }
#         else if node.tag == ast.TAG_STATIC_SLOT   { &static_nodes; }
#         else if node.tag == ast.TAG_FUNC_DECL     { &fn_nodes; }
#         # else if node.tag == ast.TAG_IMPORT        { &imp_nodes; }
#         # else if node.tag == ast.TAG_STRUCT_DECL   { type_nodes; }
#         # else if node.tag == ast.TAG_ENUM_DECL     { type_nodes; }
#         # else if node.tag == ast.TAG_TYPE_DECL     { type_nodes; }
#         # else if node.tag == ast.TAG_USE_DECL      { type_nodes; }
#         else { &other_nodes; };

#     (lst^).push(&node as ^void);
# }
