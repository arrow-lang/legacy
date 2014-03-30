module llvm {
    foreign "C" import "llvm-c/Core.h";
    foreign "C" import "llvm-c/Analysis.h";
    foreign "C" import "llvm-c/ExecutionEngine.h";
    foreign "C" import "llvm-c/Target.h";
    foreign "C" import "llvm-c/Transforms/Scalar.h";
}

module libc {
    foreign "C" import "stdlib.h";
    foreign "C" import "stdio.h";
}

def main() {
    # Construct a LLVM module to hold the geneated IR.
    let mod: ^llvm.LLVMOpaqueModule;
    mod = llvm.LLVMModuleCreateWithName("_" as ^int8);

    # Output the generated LLVM IR.
    llvm.LLVMDumpModule(mod);

    # Dispose of the consructed LLVM module.
    llvm.LLVMDisposeModule(mod);

    # Return success back to the envrionment.
    libc.exit(0);
}
