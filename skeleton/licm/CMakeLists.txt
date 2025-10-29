# Minimal, clean plugin in its own dir
add_llvm_pass_plugin(LICMPass
    LICMPass.cpp
)

# (Optional) If you see unresolved symbols at link time, uncomment:
# set(LLVM_LINK_COMPONENTS
#   Core
#   Support
#   Analysis
#   TransformUtils
# )
