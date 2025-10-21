Run divzero
# Compile to LLVM IR
"$(brew --prefix llvm)/bin/clang" -O0 -S -emit-llvm example_divzero.c -o example_divzero.ll

# Run your pass
"$(brew --prefix llvm)/bin/opt" -load-pass-plugin ./build/skeleton/SkeletonPass.dylib \
  -passes=skeleton-pass example_divzero.ll -S -o instrumented_divzero.ll

# Compile to object and link
"$(brew --prefix llvm)/bin/llc" -filetype=obj instrumented_divzero.ll -o instrumented_divzero.o
cc instrumented_divzero.o logger.o -o a.out
./a.out 2>&1
