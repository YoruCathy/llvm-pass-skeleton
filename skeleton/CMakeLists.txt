# Keep ONLY the original skeleton pass here
add_llvm_pass_plugin(SkeletonPass
    Skeleton.cpp
)

# Add LICM subdirectory (separate target lives there)
add_subdirectory(licm)