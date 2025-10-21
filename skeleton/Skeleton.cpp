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

    // Declare runtime hooks
    FunctionCallee logFdiv = M.getOrInsertFunction(
        "log_fdiv", Type::getVoidTy(Ctx));
    FunctionCallee logDivZero = M.getOrInsertFunction(
        "log_divzero_check",
        Type::getVoidTy(Ctx), Type::getDoubleTy(Ctx));

    errs() << "[debug] SkeletonPass running on module: "
           << M.getName() << "\n";

    for (auto &F : M) {
        if (F.isDeclaration()) continue;

        for (auto &B : F) {
            for (auto I = B.begin(), E = B.end(); I != E; ) {
                Instruction &Inst = *I++;
                if (auto *BO = dyn_cast<BinaryOperator>(&Inst)) {
                    unsigned op = BO->getOpcode();

                    // Handle floating-point division
                    if (op == Instruction::FDiv) {
                        // Always call log_fdiv
                        IRBuilder<> builder(&Inst);
                        builder.SetInsertPoint(BO->getNextNode());
                        builder.CreateCall(logFdiv, {});
                        modified = true;

                        // Check for constant zero divisor
                        Value *rhs = BO->getOperand(1);
                        if (auto *constVal = dyn_cast<ConstantFP>(rhs)) {
                            if (constVal->isZeroValue()) {
                                errs() << "Potential floating-point divide by zero in function "
                                       << F.getName() << "\n";
                            }
                        } else {
                            // Insert runtime check for variable divisor
                            IRBuilder<> b2(BO);
                            b2.SetInsertPoint(BO->getNextNode());
                            Value *rhsCast = rhs;
                            if (rhs->getType()->isFloatTy())
                                rhsCast = b2.CreateFPExt(rhs, Type::getDoubleTy(Ctx));
                            else if (rhs->getType()->isDoubleTy())
                                rhsCast = rhs;
                            else if (rhs->getType()->isIntegerTy())
                                rhsCast = b2.CreateSIToFP(rhs, Type::getDoubleTy(Ctx));

                            b2.CreateCall(logDivZero, rhsCast);
                        }
                    }

                    // Handle integer divisions
                    else if (op == Instruction::SDiv || op == Instruction::UDiv) {
                        Value *rhs = BO->getOperand(1);
                        if (auto *constInt = dyn_cast<ConstantInt>(rhs)) {
                            if (constInt->isZero()) {
                                errs() << "Potential integer divide by zero in function "
                                       << F.getName() << "\n";
                            }
                        } else {
                            IRBuilder<> b3(BO);
                            b3.SetInsertPoint(BO->getNextNode());
                            Value *rhsCast = b3.CreateSIToFP(rhs, Type::getDoubleTy(Ctx));
                            b3.CreateCall(logDivZero, rhsCast);
                        }
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
