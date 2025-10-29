#include "llvm/IR/PassManager.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Dominators.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"

using namespace llvm;

namespace {
struct LICMPass : public PassInfoMixin<LICMPass> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM) {
    auto &LI = AM.getResult<LoopAnalysis>(F);
    auto &DT = AM.getResult<DominatorTreeAnalysis>(F);
    (void)AM.getResult<ScalarEvolutionAnalysis>(F);
    (void)AM.getResult<AssumptionAnalysis>(F);

    bool Changed = false;
    for (Loop *L : LI)
      Changed |= processLoopRecursive(L, DT);

    return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
  }

  bool processLoopRecursive(Loop *L, DominatorTree &DT) {
    bool C = processLoop(L, DT);
    for (Loop *Sub : *L) C |= processLoopRecursive(Sub, DT);
    return C;
  }

  bool processLoop(Loop *L, DominatorTree &DT) {
    BasicBlock *Preheader = L->getLoopPreheader();
    if (!Preheader) return false;

    SmallVector<Instruction*, 32> ToHoist;
    for (BasicBlock *BB : L->blocks()) {
      for (Instruction &I : *BB) {
        if (!isHoistable(I, L)) continue;
        if (!isLoopInvariant(I, L)) continue;
        if (!definitelyExecutes(I, L, DT)) continue;
        ToHoist.push_back(&I);
      }
    }
    if (ToHoist.empty()) return false;

    Instruction *InsertPt = Preheader->getTerminator();
    for (Instruction *I : ToHoist)
      I->moveBefore(InsertPt);

    return true;
  }

  bool definitelyExecutes(Instruction &I, Loop *L, DominatorTree &DT) {
    if (I.getParent() == L->getHeader()) return true;
    if (BasicBlock *Latch = L->getLoopLatch())
      return DT.dominates(I.getParent(), Latch);
    return false;
  }

  bool isLoopInvariant(Instruction &I, Loop *L) {
    for (Value *Op : I.operands())
      if (!L->isLoopInvariant(Op)) return false;
    return true;
  }

  bool isHoistable(Instruction &I, Loop *L) {
    if (I.isTerminator()) return false;
    if (I.mayHaveSideEffects()) return false;
    if (!isSafeToSpeculativelyExecute(&I)) return false;

    if (auto *LI = dyn_cast<LoadInst>(&I)) {
      if (LI->isVolatile()) return false;
      if (!L->isLoopInvariant(LI->getPointerOperand())) return false;
    }
    return true;
  }
};
} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION,
    "LICMPass",
    LLVM_VERSION_STRING,
    [](PassBuilder &PB) {
      PB.registerPipelineParsingCallback(
        [](StringRef Name, FunctionPassManager &FPM,
           ArrayRef<PassBuilder::PipelineElement>) {
          if (Name == "my-licm") { FPM.addPass(LICMPass()); return true; }
          return false;
        }
      );
    }
  };
}
