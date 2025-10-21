#include "llvm/IR/PassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"

using namespace llvm;

namespace {

struct SkeletonPass : public PassInfoMixin<SkeletonPass> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) {
    bool modified = false;
    auto &Ctx = M.getContext();


    auto *PtrTy = PointerType::get(Ctx, /*addrspace*/ 0);

    // fdiv logging and div-zero check
    FunctionCallee logFdiv =
        M.getOrInsertFunction("log_fdiv", Type::getVoidTy(Ctx));
    FunctionCallee logDivZero =
        M.getOrInsertFunction("log_divzero_check",
                              Type::getVoidTy(Ctx),
                              Type::getDoubleTy(Ctx));

    // Small-int
    FunctionCallee getSmall =
        M.getOrInsertFunction("get_small_int", PtrTy, Type::getInt64Ty(Ctx));
    FunctionCallee boxI64 =
        M.getOrInsertFunction("box_i64", PtrTy, Type::getInt64Ty(Ctx));

    const int64_t SMALL_MIN = -5;
    const int64_t SMALL_MAX = 256;

    errs() << "[debug] SkeletonPass running on module: " << M.getName() << "\n";

    for (auto &F : M) {
      if (F.isDeclaration())
        continue;

      for (auto &B : F) {
        for (auto I = B.begin(), E = B.end(); I != E; ) {
          Instruction &Inst = *I++;

          // A) Small-int interning for constants:
          if (auto *CB = dyn_cast<CallBase>(&Inst)) {
            Value *CalleeOp = CB->getCalledOperand();
            if (auto *CalleeF = dyn_cast<Function>(CalleeOp->stripPointerCasts())) {
              if (CalleeF->getName() == "box_i64" && CB->arg_size() == 1) {
                if (auto *CInt = dyn_cast<ConstantInt>(CB->getArgOperand(0))) {
                  int64_t v = CInt->getSExtValue();
                  if (v >= SMALL_MIN && v <= SMALL_MAX) {
                    IRBuilder<> b(CB);
                    CallInst *fast = b.CreateCall(getSmall, {CInt});
                    CB->replaceAllUsesWith(fast);
                    CB->eraseFromParent();
                    modified = true;
                    continue; // continue instruction walk
                  }
                }
              }
            }
          }

          // ------------------------------------------------------------------
          // B) Division handling
          // ------------------------------------------------------------------
          if (auto *BO = dyn_cast<BinaryOperator>(&Inst)) {
            unsigned opc = BO->getOpcode();

            // log floating-point divisions at runtime
            if (opc == Instruction::FDiv) {
              IRBuilder<> builder(&Inst);
              builder.SetInsertPoint(BO->getNextNode());
              builder.CreateCall(logFdiv, {});
              modified = true;
            }

            // Divide-by-zero detection:
            if (opc == Instruction::FDiv || opc == Instruction::SDiv || opc == Instruction::UDiv) {
              Value *rhs = BO->getOperand(1);

              // Compile-time warnings for constant zero divisors
              if (auto *CFP = dyn_cast<ConstantFP>(rhs)) {
                if (CFP->isZeroValue()) {
                  errs() << "Potential floating-point divide by zero in function "
                         << F.getName() << "\n";
                  continue; 
                }
              } else if (auto *CI = dyn_cast<ConstantInt>(rhs)) {
                if (CI->isZero()) {
                  errs() << "Potential integer divide by zero in function "
                         << F.getName() << "\n";
                  continue;
                }
                continue;
              }

              // Runtime check for non-constant divisors:
              IRBuilder<> b2(&Inst);
              b2.SetInsertPoint(BO->getNextNode());

              // Safely convert rhs to double for the logger call
              Value *rhsCast = rhs;
              if (rhs->getType()->isFloatTy()) {
                rhsCast = b2.CreateFPExt(rhs, Type::getDoubleTy(Ctx));
              } else if (rhs->getType()->isDoubleTy()) {
                // use as-is
              } else if (rhs->getType()->isIntegerTy()) {
                rhsCast = b2.CreateSIToFP(rhs, Type::getDoubleTy(Ctx));
              } else if (rhs->getType()->isPointerTy()) {
                // unexpected as a divisor, but avoid crashing if present
                auto *i64 = Type::getInt64Ty(Ctx);
                Value *asI64 = b2.CreatePtrToInt(rhs, i64);
                rhsCast = b2.CreateSIToFP(asI64, Type::getDoubleTy(Ctx));
              } else {
                // Fallback: bitcast to i64 then to double
                auto *i64 = Type::getInt64Ty(Ctx);
                Value *asI64 = b2.CreateBitCast(rhs, i64->getPointerTo());
                asI64 = b2.CreatePtrToInt(asI64, i64);
                rhsCast = b2.CreateSIToFP(asI64, Type::getDoubleTy(Ctx));
              }

              b2.CreateCall(logDivZero, rhsCast);
              modified = true;
            }
          } 
        } 
      }  
    }     

    return modified ? PreservedAnalyses::none() : PreservedAnalyses::all();
  }
};

} // namespace

llvm::PassPluginLibraryInfo getSkeletonPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "SkeletonPass", LLVM_VERSION_STRING,
    [](PassBuilder &PB) {
      PB.registerPipelineParsingCallback(
        [](StringRef Name, ModulePassManager &MPM,
           ArrayRef<PassBuilder::PipelineElement>) {
          if (Name == "skeleton-pass") {
            MPM.addPass(SkeletonPass());
            return true;
          }
          return false;
        });
    }
  };
}

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getSkeletonPassPluginInfo();
}
