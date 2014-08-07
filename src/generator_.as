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

# A loop struct that contains continue and break jump points.
# -----------------------------------------------------------------------------
struct Loop { continue_: *llvm.LLVMOpaqueBasicBlock,
                 break_: *llvm.LLVMOpaqueBasicBlock }

# A code generator that is capable of going from an arbitrary node in the
# AST into a llvm module.
# =============================================================================
struct Generator {
    # The LLVM module that encapsulates the IR.
    mod: *mut llvm.LLVMOpaqueModule,

    # A LLVM instruction builder that simplifies much of the IR generation
    # process by managing what block we're on, etc.
    irb: *mut llvm.LLVMOpaqueBuilder,

    # A LLVM target machine.
    target_machine: *mut llvm.LLVMOpaqueTargetMachine,

    # The LLVM target data.
    target_data: *llvm.LLVMOpaqueTargetData,

    # A dictionary of "items" that have been declared. These can be
    # `types`, `functions`, or `modules`.
    items: dict.Dictionary,

    # A dictionary parallel to "items" that is the nodes left over
    # from extracting the "items".
    nodes: dict.Dictionary,

    # A "set" (faked from the dict) of imported modules.
    imported_modules: dict.Dictionary,

    # List of functions to be attached.
    attached_functions: list.List,

    # The stack of namespaces that represent our current "item" scope.
    ns: list.List,

    # The top-level namespace.
    top_ns: string.String,

    # Jump table for the type resolver.
    type_resolvers: (delegate(*mut Generator, *ast.Node, *mut code.Scope, *code.Handle) -> *code.Handle)[100],

    # Jump table for the builder.
    builders: (delegate(*mut Generator, *ast.Node, *mut code.Scope, *code.Handle) -> *code.Handle)[100],

    # Stack of loops (for break and continue).
    loops: list.List,

    # The current function being generated.
    current_function: *code.Function,

    # The current self being generated.
    current_self: *code.Handle
}

implement Generator {

    # Dispose of internal resources used during code generation.
    # -------------------------------------------------------------------------
    let dispose(self) -> {
        # Dispose of the LLVM module.
        llvm.LLVMDisposeModule(self.mod);

        # Dispose of the instruction builder.
        llvm.LLVMDisposeBuilder(self.irb);

        # Dispose of the target machine.
        llvm.LLVMDisposeTargetMachine(self.target_machine);

        # Dispose of our "items" dictionary.
        # FIXME: Dispose of each "item".
        self.items.dispose();
        self.nodes.dispose();
        self.imported_modules.dispose();
        self.attached_functions.dispose();

        # Dispose of our namespace list.
        self.ns.dispose();

        # Dispose of our loop stack.
        self.loops.dispose();
    }

}
