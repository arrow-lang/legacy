
# Core.h
# -----------------------------------------------------------------------------

# The top-level container for all other LLVM Intermediate Representation (IR)
# objects.
struct LLVMOpaqueModule { }

# Represents an individual value in LLVM IR.
struct LLVMOpaqueValue { }

# Each value in the LLVM IR has a type
struct LLVMOpaqueType { }

# Represents a basic block of instructions in LLVM IR.
struct LLVMOpaqueBasicBlock { }

# Represents an LLVM basic block builder.
struct LLVMOpaqueBuilder { }

# Destroy a module instance.
extern let LLVMDisposeModule(*LLVMOpaqueModule);

# Dispose of internally allocated memory.
extern let LLVMDisposeMessage(str);

# Create a new, empty module in the global context.
extern let LLVMModuleCreateWithName(str) -> *LLVMOpaqueModule;

# Return a string representation of the module.
extern let LLVMPrintModuleToString(*LLVMOpaqueModule) -> str;

# Set the data layout for a module.
extern let LLVMSetDataLayout(*LLVMOpaqueModule, str);

# Set the target triple for a module.
extern let LLVMSetTarget(*LLVMOpaqueModule, str);

# Add a function to a module under a specified name.
extern let LLVMAddFunction(*LLVMOpaqueModule, name: str, *LLVMOpaqueType)
    -> *LLVMOpaqueValue;

# Obtain a "void" type.
extern let LLVMVoidType() -> *LLVMOpaqueType;

# Obtain an integer type from the global context with a specified bit
# width.
extern let LLVMInt1Type() -> *LLVMOpaqueType;
extern let LLVMInt8Type() -> *LLVMOpaqueType;
extern let LLVMInt16Type() -> *LLVMOpaqueType;
extern let LLVMInt32Type() -> *LLVMOpaqueType;
extern let LLVMInt64Type() -> *LLVMOpaqueType;
extern let LLVMIntType(uint32) -> *LLVMOpaqueType;

# Optain a floating-point type from the global context.
extern let LLVMFloatType() -> *LLVMOpaqueType;
extern let LLVMDoubleType() -> *LLVMOpaqueType;

# Obtain the length of an array type.
extern let LLVMGetArrayLength(*LLVMOpaqueType) -> uint32;

# Create a pointer type that points to a defined type.
extern let LLVMPointerType(*LLVMOpaqueType, uint32) -> *LLVMOpaqueType;

# Obtain a function type consisting of a specified signature.
extern let LLVMFunctionType(
    *LLVMOpaqueTargetData, *LLVMOpaqueTargetData, uint32, uint32)
        -> *LLVMOpaqueType;

# Obtain the parameter at the specified index.
extern let LLVMGetParam(*LLVMOpaqueValue, index: uint) -> *LLVMOpaqueValue;

# Append a basic block to the end of a function using the global context.
extern let LLVMAppendBasicBlock(*LLVMOpaqueValue, name: str)
    -> *LLVMOpaqueBasicBlock;

# Obtain the terminator instruction for a basic block.
extern let LLVMGetBasicBlockTerminator(*LLVMOpaqueBasicBlock) -> *LLVMOpaqueValue;

# Constant expressions.
extern let LLVMConstInt(*LLVMOpaqueType, uint128, bool) -> *LLVMOpaqueValue;
extern let LLVMSizeOf(*LLVMOpaqueType) -> *LLVMOpaqueValue;
extern let LLVMIsConstant(*LLVMOpaqueValue) -> int64;

# This group contains functions that operate on global values.
extern let LLVMGetLinkage(*LLVMOpaqueValue) -> int32;
extern let LLVMSetLinkage(*LLVMOpaqueValue, int32);
extern let LLVMGetSection(*LLVMOpaqueValue) -> str;
extern let LLVMSetSection(*LLVMOpaqueValue, str);
extern let LLVMGetVisibility(*LLVMOpaqueValue) -> int32;
extern let LLVMSetVisibility(*LLVMOpaqueValue, int32);

# Obtain the code opcode for an individual instruction.
extern let LLVMGetInstructionOpcode(*LLVMOpaqueValue) -> uint32;

# Remove and delete an instruction.
extern let LLVMInstructionEraseFromParent(*LLVMOpaqueValue);

# Obtain an operand at a specific index in a llvm::User value.
extern let LLVMGetOperand(*LLVMOpaqueValue, uint32) -> *LLVMOpaqueValue;

# Instruction builders
extern let LLVMCreateBuilder() -> *LLVMOpaqueBuilder;
extern let LLVMDisposeBuilder(*LLVMOpaqueBuilder);
extern let LLVMPositionBuilderAtEnd(*LLVMOpaqueBuilder, *LLVMOpaqueBasicBlock);
extern let LLVMGetInsertBlock(*LLVMOpaqueBuilder) -> *LLVMOpaqueBuilder;
extern let LLVMBuildAlloca(*LLVMOpaqueBuilder, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildStore(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue) -> *LLVMOpaqueValue;
extern let LLVMBuildCall(*LLVMOpaqueBuilder, *LLVMOpaqueValue,
                         *LLVMOpaqueValue, uint,
                         str) -> *LLVMOpaqueValue;
extern let LLVMBuildRetVoid(*LLVMOpaqueBuilder) -> *LLVMOpaqueValue;
extern let LLVMBuildRet(*LLVMOpaqueBuilder, *LLVMOpaqueValue) -> *LLVMOpaqueValue;
extern let LLVMBuildBr(*LLVMOpaqueBuilder, *LLVMOpaqueBasicBlock);
extern let LLVMBuildCondBr(*LLVMOpaqueBuilder,
                           *LLVMOpaqueValue,
                           *LLVMOpaqueBasicBlock,
                           *LLVMOpaqueBasicBlock) -> *LLVMOpaqueValue;
extern let LLVMBuildPointerCast(*LLVMOpaqueBuilder,
                                *LLVMOpaqueValue,
                                *LLVMOpaqueType,
                                str) -> *LLVMOpaqueValue;

extern let LLVMBuildTrunc(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildZExt(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildSExt(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildFPToUI(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildFPToSI(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildUIToFP(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildSIToFP(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildFPTrunc(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildFPExt(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildPtrToInt(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildIntToPtr(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;


# TargetMachine.h
# -----------------------------------------------------------------------------

struct LLVMOpaqueTargetMachine { }

struct LLVMTarget { }

# Creates a new llvm::TargetMachine. See llvm::Target::createTargetMachine
extern let LLVMCreateTargetMachine(
    *LLVMTarget, str, str, str, int32, int32, int32)
        -> *LLVMOpaqueTargetMachine;

# Dispose the LLVMTargetMachineRef instance generated by
# LLVMCreateTargetMachine.
extern let LLVMDisposeTargetMachine(*LLVMOpaqueTargetMachine);

# Get a triple for the host machine as a string. The result needs to be
# disposed with LLVMDisposeMessage.
extern let LLVMGetDefaultTargetTriple() -> str;

# Finds the target corresponding to the given triple and stores it in \p T.
# Returns 0 on success. Optionally returns any error in ErrorMessage.
# Use LLVMDisposeMessage to dispose the message.
extern let LLVMGetTargetFromTriple(str, *LLVMTarget, *str) -> int32;

# Returns the llvm::DataLayout used for this llvm:TargetMachine.
extern let LLVMGetTargetMachineData(*LLVMOpaqueTargetMachine)
    -> *LLVMOpaqueTargetData;

# Target.h
# -----------------------------------------------------------------------------

struct LLVMOpaqueTargetData { }

extern let LLVMInitializeX86Target();
extern let LLVMInitializeX86TargetInfo();

# Converts target data to a target layout string.
extern let LLVMCopyStringRepOfTargetData(*LLVMOpaqueTargetData) -> str;

# Computes the ABI size of a type in bytes for a target.
extern let LLVMABISizeOfType(*LLVMOpaqueTargetData, *LLVMOpaqueType)
    -> uint128;
