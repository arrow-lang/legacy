import llvm;
import string;
import libc;
import ast;
import parser;
import errors;
import dict;
import list;
import types;
import code;

# A code generator that is capable of going from an arbitrary node in the
# AST into a llvm module.
# =============================================================================
type Generator {
    # The LLVM module that encapsulates the IR.
    mod: ^mut llvm.LLVMOpaqueModule,

    # A LLVM instruction builder that simplifies much of the IR generation
    # process by managing what block we're on, etc.
    irb: ^mut llvm.LLVMOpaqueBuilder,

    # A dictionary of "items" that have been declared. These can be
    # `types`, `functions`, or `modules`.
    mut items: dict.Dictionary,

    # A dictionary parallel to "items" that is the nodes left over
    # from extracting the "items".
    mut nodes: dict.Dictionary,

    # The stack of namespaces that represent our current "item" scope.
    mut ns: list.List,

    # The top-level namespace.
    mut top_ns: string.String,

    # Jump table for the type resolver.
    mut type_resolvers: (def (^mut Generator, ^ast.Node, ^mut code.Scope, ^code.Handle) -> ^code.Handle)[100],

    # Jump table for the builder.
    mut builders: (def (^mut Generator, ^ast.Node, ^mut code.Scope, ^code.Handle) -> ^code.Handle)[100]
}

implement Generator {

    # Dispose of internal resources used during code generation.
    # -------------------------------------------------------------------------
    def dispose(self) {
        # Dispose of the LLVM module.
        llvm.LLVMDisposeModule(self.mod);

        # Dispose of the instruction builder.
        llvm.LLVMDisposeBuilder(self.irb);

        # Dispose of our "items" dictionary.
        # FIXME: Dispose of each "item".
        self.items.dispose();
        self.nodes.dispose();

        # Dispose of our namespace list.
        self.ns.dispose();
    }

}