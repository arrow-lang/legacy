
# Core.h
# -----------------------------------------------------------------------------

# The top-level container for all LLVM global data. See the LLVMContext class.
struct LLVMOpaqueContext { }

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

# Obtain the global context instance.
extern let LLVMGetGlobalContext() -> *LLVMOpaqueContext;

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

# Obtain a Function value from a Module by its name.
extern let LLVMGetNamedFunction(*LLVMOpaqueModule, str)
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

# Create a fixed size array type that refers to a specific type.
extern let LLVMArrayType(*LLVMOpaqueType, uint32) -> *LLVMOpaqueType;

# Create a pointer type that points to a defined type.
extern let LLVMPointerType(*LLVMOpaqueType, uint32) -> *LLVMOpaqueType;

# Obtain a function type consisting of a specified signature.
extern let LLVMFunctionType(*LLVMOpaqueType, **LLVMOpaqueType, uint32, uint32)
    -> *LLVMOpaqueType;

# Obtain the parameter at the specified index.
extern let LLVMGetParam(*LLVMOpaqueValue, index: uint) -> *LLVMOpaqueValue;

# Append a basic block to the end of a function using the global context.
extern let LLVMAppendBasicBlock(*LLVMOpaqueValue, name: str)
    -> *LLVMOpaqueBasicBlock;

# Obtain the terminator instruction for a basic block.
extern let LLVMGetBasicBlockTerminator(*LLVMOpaqueBasicBlock) -> *LLVMOpaqueValue;

# Obtain the number of basic blocks in a function.
extern let LLVMCountBasicBlocks(*LLVMOpaqueValue) -> uint32;

# Obtain the last basic block in a function.
extern let LLVMGetLastBasicBlock(*LLVMOpaqueValue) -> *LLVMOpaqueBasicBlock;

# Move a basic block to after another one.
extern let LLVMMoveBasicBlockAfter(*LLVMOpaqueBasicBlock, *LLVMOpaqueBasicBlock);

# Obtain the function to which a basic block belongs.
extern let LLVMGetBasicBlockParent(*LLVMOpaqueBasicBlock) -> *LLVMOpaqueValue;

# Obtain the type of a value.
extern let LLVMTypeOf(*LLVMOpaqueValue) -> *LLVMOpaqueType;

# Constant expressions.
extern let LLVMConstInt(*LLVMOpaqueType, uint128, bool) -> *LLVMOpaqueValue;
extern let LLVMSizeOf(*LLVMOpaqueType) -> *LLVMOpaqueValue;
extern let LLVMIsConstant(*LLVMOpaqueValue) -> int64;

# Create a ConstantArray from values.
extern let LLVMConstArray(*LLVMOpaqueType,
                          *LLVMOpaqueValue, uint32) -> *LLVMOpaqueValue;

# Create a non-anonymous ConstantStruct from values.
extern let LLVMConstNamedStruct(*LLVMOpaqueType,
                                *LLVMOpaqueValue,
                                uint32) -> *LLVMOpaqueValue;

# Obtain a constant value for an integer parsed from a string.
extern let LLVMConstIntOfString(*LLVMOpaqueType, str, uint8) -> *LLVMOpaqueValue;
extern let LLVMConstRealOfString(*LLVMOpaqueType, str) -> *LLVMOpaqueValue;

# Create an empty structure in a context having a specified name.
extern let LLVMStructCreateNamed(*LLVMOpaqueContext, str) -> *LLVMOpaqueType;

# Create a new structure type in the global context.
extern let LLVMStructType(*LLVMOpaqueType, uint32, int64) -> *LLVMOpaqueType;

# Create a ConstantStruct in the global Context.
extern let LLVMConstStruct(*LLVMOpaqueValue, uint32, bool) -> *LLVMOpaqueValue;

# Obtain a constant value referring to the null instance of a type.
extern let LLVMConstNull(*LLVMOpaqueType) -> *LLVMOpaqueValue;

# Obtain the zero extended value for an integer constant value.
extern let LLVMConstIntGetZExtValue(*LLVMOpaqueValue) -> uint128;

# Obtain a constant value referring to an undefined value of a type.
extern let LLVMGetUndef(*LLVMOpaqueType) -> *LLVMOpaqueValue;

# This group contains functions that operate on global values.
extern let LLVMGetLinkage(*LLVMOpaqueValue) -> int32;
extern let LLVMSetLinkage(*LLVMOpaqueValue, int32);
extern let LLVMGetSection(*LLVMOpaqueValue) -> str;
extern let LLVMSetSection(*LLVMOpaqueValue, str);
extern let LLVMGetVisibility(*LLVMOpaqueValue) -> int32;
extern let LLVMSetVisibility(*LLVMOpaqueValue, int32);

# This group contains functions that operate on global variables values.
extern let LLVMAddGlobal(*LLVMOpaqueModule, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMGetInitializer(*LLVMOpaqueValue) -> *LLVMOpaqueValue;
extern let LLVMSetInitializer(*LLVMOpaqueValue, *LLVMOpaqueValue);
extern let LLVMSetGlobalConstant(*LLVMOpaqueValue, bool);

# Set the contents of a structure type.
extern let LLVMStructSetBody(*LLVMOpaqueType, *LLVMOpaqueType, uint32, bool);

# Obtain the code opcode for an individual instruction.
extern let LLVMGetInstructionOpcode(*LLVMOpaqueValue) -> uint32;

# Remove and delete an instruction.
extern let LLVMInstructionEraseFromParent(*LLVMOpaqueValue);

# Obtain an operand at a specific index in a llvm::User value.
extern let LLVMGetOperand(*LLVMOpaqueValue, uint32) -> *LLVMOpaqueValue;

# Add an incoming value to the end of a PHI list.
extern let LLVMAddIncoming(*LLVMOpaqueValue, *LLVMOpaqueValue,
                           *LLVMOpaqueBasicBlock, uint32);

# Instruction builders
extern let LLVMCreateBuilder() -> *LLVMOpaqueBuilder;
extern let LLVMDisposeBuilder(*LLVMOpaqueBuilder);
extern let LLVMPositionBuilderAtEnd(*LLVMOpaqueBuilder, *LLVMOpaqueBasicBlock);
extern let LLVMGetInsertBlock(*LLVMOpaqueValue) -> *LLVMOpaqueBasicBlock;
extern let LLVMBuildAlloca(*LLVMOpaqueBuilder, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;
extern let LLVMBuildLoad(*LLVMOpaqueBuilder, *LLVMOpaqueValue, str) -> *LLVMOpaqueValue;
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

extern let LLVMBuildPhi(*LLVMOpaqueBuilder, *LLVMOpaqueType, str) -> *LLVMOpaqueValue;

extern let LLVMBuildNeg(*LLVMOpaqueBuilder, *LLVMOpaqueValue, str) -> *LLVMOpaqueValue;
extern let LLVMBuildNot(*LLVMOpaqueBuilder, *LLVMOpaqueValue, str) -> *LLVMOpaqueValue;


extern let LLVMBuildICmp(*LLVMOpaqueBuilder, int32,
                         *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildFCmp(*LLVMOpaqueBuilder, int32,
                         *LLVMOpaqueValue, *LLVMOpaqueValue,
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
extern let LLVMBuildInsertValue(*LLVMOpaqueBuilder, *LLVMOpaqueValue,
                                *LLVMOpaqueValue, uint32, str) -> *LLVMOpaqueValue;
extern let LLVMBuildStructGEP(*LLVMOpaqueBuilder, *LLVMOpaqueValue,
                              uint32, str) -> *LLVMOpaqueValue;
extern let LLVMBuildInBoundsGEP(*LLVMOpaqueBuilder, *LLVMOpaqueValue,
                                *LLVMOpaqueValue, uint32, str) -> *LLVMOpaqueValue;

extern let LLVMBuildGEP(*LLVMOpaqueBuilder, *LLVMOpaqueValue,
                        *LLVMOpaqueValue, uint32,
                        str) -> *LLVMOpaqueValue;

extern let LLVMBuildGlobalStringPtr(*LLVMOpaqueBuilder, str, str) -> *LLVMOpaqueValue;

extern let LLVMBuildSub(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                        str) -> *LLVMOpaqueValue;

extern let LLVMBuildAnd(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                        str) -> *LLVMOpaqueValue;

extern let LLVMBuildOr(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                       str) -> *LLVMOpaqueValue;

extern let LLVMBuildXor(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                        str) -> *LLVMOpaqueValue;

extern let LLVMBuildAdd(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                        str) -> *LLVMOpaqueValue;

extern let LLVMBuildFAdd(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildFSub(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildMul(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                        str) -> *LLVMOpaqueValue;

extern let LLVMBuildFMul(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildFDiv(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildFRem(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildSDiv(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildExactSDiv(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                              str) -> *LLVMOpaqueValue;

extern let LLVMBuildUDiv(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildSRem(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;

extern let LLVMBuildURem(*LLVMOpaqueBuilder, *LLVMOpaqueValue, *LLVMOpaqueValue,
                         str) -> *LLVMOpaqueValue;


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
