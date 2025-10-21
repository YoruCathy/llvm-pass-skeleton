; ModuleID = 'example_divzero.ll'
source_filename = "example_divzero.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx15.0.0"

@.str = private unnamed_addr constant [28 x i8] c"Results: %f %f %f %f %d %d\0A\00", align 1

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define float @fdivf(float noundef %0, float noundef %1) #0 {
  %3 = alloca float, align 4
  %4 = alloca float, align 4
  store float %0, ptr %3, align 4
  store float %1, ptr %4, align 4
  %5 = load float, ptr %3, align 4
  %6 = load float, ptr %4, align 4
  %7 = fdiv float %5, %6
  %8 = fpext float %6 to double
  call void @log_divzero_check(double %8)
  call void @log_fdiv()
  ret float %7
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define double @fdivd(double noundef %0, double noundef %1) #0 {
  %3 = alloca double, align 8
  %4 = alloca double, align 8
  store double %0, ptr %3, align 8
  store double %1, ptr %4, align 8
  %5 = load double, ptr %3, align 8
  %6 = load double, ptr %4, align 8
  %7 = fdiv double %5, %6
  call void @log_divzero_check(double %6)
  call void @log_fdiv()
  ret double %7
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define i32 @idiv(i32 noundef %0, i32 noundef %1) #0 {
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  store i32 %0, ptr %3, align 4
  store i32 %1, ptr %4, align 4
  %5 = load i32, ptr %3, align 4
  %6 = load i32, ptr %4, align 4
  %7 = sdiv i32 %5, %6
  %8 = sitofp i32 %6 to double
  call void @log_divzero_check(double %8)
  ret i32 %7
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define i32 @main() #0 {
  %1 = alloca i32, align 4
  %2 = alloca float, align 4
  %3 = alloca float, align 4
  %4 = alloca double, align 8
  %5 = alloca double, align 8
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  store i32 0, ptr %1, align 4
  %8 = call float @fdivf(float noundef 7.000000e+00, float noundef 3.500000e+00)
  store float %8, ptr %2, align 4
  %9 = call float @fdivf(float noundef 2.000000e+00, float noundef 0.000000e+00)
  store float %9, ptr %3, align 4
  %10 = call double @fdivd(double noundef 1.000000e+01, double noundef 4.000000e+00)
  store double %10, ptr %4, align 8
  %11 = call double @fdivd(double noundef 1.000000e+01, double noundef 0.000000e+00)
  store double %11, ptr %5, align 8
  %12 = call i32 @idiv(i32 noundef 8, i32 noundef 2)
  store i32 %12, ptr %6, align 4
  %13 = call i32 @idiv(i32 noundef 8, i32 noundef 0)
  store i32 %13, ptr %7, align 4
  %14 = load float, ptr %2, align 4
  %15 = fpext float %14 to double
  %16 = load float, ptr %3, align 4
  %17 = fpext float %16 to double
  %18 = load double, ptr %4, align 8
  %19 = load double, ptr %5, align 8
  %20 = load i32, ptr %6, align 4
  %21 = load i32, ptr %7, align 4
  %22 = call i32 (ptr, ...) @printf(ptr noundef @.str, double noundef %15, double noundef %17, double noundef %18, double noundef %19, i32 noundef %20, i32 noundef %21)
  ret i32 0
}

declare i32 @printf(ptr noundef, ...) #1

declare void @log_fdiv()

declare void @log_divzero_check(double)

attributes #0 = { noinline nounwind optnone ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 2, !"SDK Version", [2 x i32] [i32 15, i32 5]}
!1 = !{i32 1, !"wchar_size", i32 4}
!2 = !{i32 8, !"PIC Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 1}
!4 = !{i32 7, !"frame-pointer", i32 1}
!5 = !{!"Homebrew clang version 21.1.3"}
