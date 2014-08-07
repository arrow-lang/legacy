# foreign "C" import "llvm-c/Core.h";
# foreign "C" import "llvm-c/Analysis.h";
# foreign "C" import "llvm-c/ExecutionEngine.h";
# foreign "C" import "llvm-c/Target.h";
# foreign "C" import "llvm-c/Transforms/Scalar.h";

# Represents an individual value in LLVM IR.
struct LLVMOpaqueValue { }

# Each value in the LLVM IR has a type
struct LLVMOpaqueType { }

# Obtain an integer type from the global context with a specified bit
# width.
extern let LLVMInt1Type() -> *LLVMOpaqueType;
extern let LLVMInt8Type() -> *LLVMOpaqueType;
extern let LLVMInt16Type() -> *LLVMOpaqueType;
extern let LLVMInt32Type() -> *LLVMOpaqueType;
extern let LLVMInt64Type() -> *LLVMOpaqueType;
extern let LLVMIntType(uint32) -> *LLVMOpaqueType;

# Obtain the length of an array type.
extern let LLVMGetArrayLength(*LLVMOpaqueType) -> uint32;

# Create a pointer type that points to a defined type.
extern let LLVMPointerType(*LLVMOpaqueType, uint32) -> *LLVMOpaqueType;
