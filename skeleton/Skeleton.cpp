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
    errs() << "[debug] SkeletonPass running on module: "
       << M.getName() << "\n";
    bool modified = false;

    auto &Ctx = M.getContext();
    // Declare: void log_fdiv(void);
    auto logFdiv = M.getOrInsertFunction("log_fdiv", Type::getVoidTy(Ctx));

    for (auto &F : M) {
      if (F.isDeclaration()) continue;
      for (auto &B : F) {
        for (auto I = B.begin(), E = B.end(); I != E; /* increment below */) {
          auto &Inst = *I++;
          if (auto *BO = dyn_cast<BinaryOperator>(&Inst)) {
            if (BO->getOpcode() == Instruction::FDiv) {
              IRBuilder<> builder(&Inst);
              builder.SetInsertPoint(&B, I); // insert after fdiv
              builder.CreateCall(logFdiv, {});
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
