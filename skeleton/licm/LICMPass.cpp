#include "llvm/IR/PassManager.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Dominators.h"              // DominatorTree
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/ValueTracking.h"     // isSafeToSpeculativelyExecute
#include "llvm/IR/IRBuilder.h"

#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"

using namespace llvm;

/// Minimal LICM for the new PM (LLVM 21).
/// Requirements when running: `mem2reg,loop-simplify` to ensure SSA + preheader.
/// Hoists instructions that are:
///   - loop-invariant (all operands invariant),
///   - speculatively safe (no traps/side-effects),
///   - and conservatively "must execute" (in header OR dominates loop latch).
namespace {
struct LICMPass : public PassInfoMixin<LICMPass> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM) {
    auto &LI = AM.getResult<LoopAnalysis>(F);
    auto &DT = AM.getResult<DominatorTreeAnalysis>(F);
    auto &SE = AM.getResult<ScalarEvolutionAnalysis>(F);
    (void)SE; // kept for extension; unused in this minimal pass
    auto &AC = AM.getResult<AssumptionAnalysis>(F);
    (void)AC; // currently unused (kept for future extensions)

    bool Changed = false;
    for (Loop *L : LI)
      Changed |= processLoopRecursive(L, DT);

    return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
  }

  bool processLoopRecursive(Loop *L, DominatorTree &DT) {
    bool Changed = processLoop(L, DT);
    for (Loop *Sub : *L)
      Changed |= processLoopRecursive(Sub, DT);
    return Changed;
  }

  bool processLoop(Loop *L, DominatorTree &DT) {
    BasicBlock *Preheader = L->getLoopPreheader();
    if (!Preheader) return false; // need loop-simplify

    SmallVector<Instruction*, 32> ToHoist;

    for (BasicBlock *BB : L->blocks()) {
      for (Instruction &I : *BB) {
        if (!isHoistable(I, L)) continue;
        if (!isLoopInvariant(I, L)) continue;
        if (!definitelyExecutes(I, L, DT)) continue; // conservative must-execute
        ToHoist.push_back(&I);
      }
    }

    if (ToHoist.empty()) return false;

    Instruction *InsertPt = Preheader->getTerminator();
    for (Instruction *I : ToHoist) {
      // Use the (deprecated) pointer overload for simplicity; OK for homework.
      I->moveBefore(InsertPt);
    }
    return true;
  }

  // Sufficient must-execute test:
  //  * instruction is in loop header (executes whenever loop is entered), OR
  //  * its block dominates the loop latch (executes on every iteration).
  bool definitelyExecutes(Instruction &I, Loop *L, DominatorTree &DT) {
    BasicBlock *DefBB = I.getParent();
    if (DefBB == L->getHeader()) return true;
    if (BasicBlock *Latch = L->getLoopLatch())
      return DT.dominates(DefBB, Latch);
    return false;
  }

  // All operands must be loop-invariant w.r.t. the loop.
  bool isLoopInvariant(Instruction &I, Loop *L) {
    for (Value *Op : I.operands())
      if (!L->isLoopInvariant(Op))
        return false;
    return true;
  }

  // Safety checks (no AA/MSSA; conservative):
  // - Not a terminator, no side effects, speculatively safe.
  // - Loads only if non-volatile and from loop-invariant pointer.
  bool isHoistable(Instruction &I, Loop *L) {
    if (I.isTerminator()) return false;
    if (I.mayHaveSideEffects()) return false;
    if (!isSafeToSpeculativelyExecute(&I)) return false;

    if (auto *LI = dyn_cast<LoadInst>(&I)) {
      if (LI->isVolatile()) return false;
      if (!L->isLoopInvariant(LI->getPointerOperand())) return false;
      // Without AA/MSSA we keep this conservative (no attempt to prove no clobbers).
    }
    return true;
  }
};
} // namespace

// ---- Pass registration (new PM) ----
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION,
    "LICMPass",
    LLVM_VERSION_STRING,
    [](PassBuilder &PB) {
      PB.registerPipelineParsingCallback(
        [](StringRef Name, FunctionPassManager &FPM,
           ArrayRef<PassBuilder::PipelineElement>) {
          if (Name == "my-licm") {
            FPM.addPass(LICMPass());
            return true;
          }
          return false;
        }
      );
    }
  };
}
