; ModuleID = 'test_smallint_bench.ll'
source_filename = "test_smallint_bench.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx15.0.0"

@.str = private unnamed_addr constant [12 x i8] c"const_range\00", align 1
@.str.1 = private unnamed_addr constant [6 x i8] c"mixed\00", align 1
@.str.2 = private unnamed_addr constant [11 x i8] c"large_only\00", align 1
@__stderrp = external global ptr, align 8
@.str.3 = private unnamed_addr constant [50 x i8] c"usage: %s {const_range|mixed|large_only} [iters]\0A\00", align 1
@sink = internal global i64 0, align 8
@.str.4 = private unnamed_addr constant [11 x i8] c"sink=%llu\0A\00", align 1

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define i32 @main(i32 noundef %0, ptr noundef %1) #0 {
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  %5 = alloca ptr, align 8
  %6 = alloca ptr, align 8
  %7 = alloca i64, align 8
  store i32 0, ptr %3, align 4
  store i32 %0, ptr %4, align 4
  store ptr %1, ptr %5, align 8
  %8 = load i32, ptr %4, align 4
  %9 = icmp sgt i32 %8, 1
  br i1 %9, label %10, label %14

10:                                               ; preds = %2
  %11 = load ptr, ptr %5, align 8
  %12 = getelementptr inbounds ptr, ptr %11, i64 1
  %13 = load ptr, ptr %12, align 8
  br label %15

14:                                               ; preds = %2
  br label %15

15:                                               ; preds = %14, %10
  %16 = phi ptr [ %13, %10 ], [ @.str, %14 ]
  store ptr %16, ptr %6, align 8
  %17 = load i32, ptr %4, align 4
  %18 = icmp sgt i32 %17, 2
  br i1 %18, label %19, label %23

19:                                               ; preds = %15
  %20 = load ptr, ptr %5, align 8
  %21 = getelementptr inbounds ptr, ptr %20, i64 2
  %22 = load ptr, ptr %21, align 8
  br label %24

23:                                               ; preds = %15
  br label %24

24:                                               ; preds = %23, %19
  %25 = phi ptr [ %22, %19 ], [ null, %23 ]
  %26 = call i64 @parse_or_default(ptr noundef %25, i64 noundef 1000000)
  store i64 %26, ptr %7, align 8
  %27 = load ptr, ptr %6, align 8
  %28 = icmp ne ptr %27, null
  br i1 %28, label %29, label %35

29:                                               ; preds = %24
  %30 = load ptr, ptr %6, align 8
  %31 = call i32 @strcmp(ptr noundef %30, ptr noundef @.str) #3
  %32 = icmp ne i32 %31, 0
  br i1 %32, label %35, label %33

33:                                               ; preds = %29
  %34 = load i64, ptr %7, align 8
  call void @bench_const_range(i64 noundef %34)
  br label %61

35:                                               ; preds = %29, %24
  %36 = load ptr, ptr %6, align 8
  %37 = icmp ne ptr %36, null
  br i1 %37, label %38, label %44

38:                                               ; preds = %35
  %39 = load ptr, ptr %6, align 8
  %40 = call i32 @strcmp(ptr noundef %39, ptr noundef @.str.1) #3
  %41 = icmp ne i32 %40, 0
  br i1 %41, label %44, label %42

42:                                               ; preds = %38
  %43 = load i64, ptr %7, align 8
  call void @bench_mixed(i64 noundef %43)
  br label %60

44:                                               ; preds = %38, %35
  %45 = load ptr, ptr %6, align 8
  %46 = icmp ne ptr %45, null
  br i1 %46, label %47, label %53

47:                                               ; preds = %44
  %48 = load ptr, ptr %6, align 8
  %49 = call i32 @strcmp(ptr noundef %48, ptr noundef @.str.2) #3
  %50 = icmp ne i32 %49, 0
  br i1 %50, label %53, label %51

51:                                               ; preds = %47
  %52 = load i64, ptr %7, align 8
  call void @bench_large_only(i64 noundef %52)
  br label %59

53:                                               ; preds = %47, %44
  %54 = load ptr, ptr @__stderrp, align 8
  %55 = load ptr, ptr %5, align 8
  %56 = getelementptr inbounds ptr, ptr %55, i64 0
  %57 = load ptr, ptr %56, align 8
  %58 = call i32 (ptr, ptr, ...) @fprintf(ptr noundef %54, ptr noundef @.str.3, ptr noundef %57) #3
  store i32 2, ptr %3, align 4
  br label %68

59:                                               ; preds = %51
  br label %60

60:                                               ; preds = %59, %42
  br label %61

61:                                               ; preds = %60, %33
  %62 = load volatile i64, ptr @sink, align 8
  %63 = icmp eq i64 %62, 3735928559
  br i1 %63, label %64, label %67

64:                                               ; preds = %61
  %65 = load volatile i64, ptr @sink, align 8
  %66 = call i32 (ptr, ...) @printf(ptr noundef @.str.4, i64 noundef %65)
  br label %67

67:                                               ; preds = %64, %61
  store i32 0, ptr %3, align 4
  br label %68

68:                                               ; preds = %67, %53
  %69 = load i32, ptr %3, align 4
  ret i32 %69
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define internal i64 @parse_or_default(ptr noundef %0, i64 noundef %1) #0 {
  %3 = alloca i64, align 8
  %4 = alloca ptr, align 8
  %5 = alloca i64, align 8
  %6 = alloca ptr, align 8
  %7 = alloca i64, align 8
  store ptr %0, ptr %4, align 8
  store i64 %1, ptr %5, align 8
  %8 = load ptr, ptr %4, align 8
  %9 = icmp ne ptr %8, null
  br i1 %9, label %12, label %10

10:                                               ; preds = %2
  %11 = load i64, ptr %5, align 8
  store i64 %11, ptr %3, align 8
  br label %31

12:                                               ; preds = %2
  store ptr null, ptr %6, align 8
  %13 = load ptr, ptr %4, align 8
  %14 = call i64 @strtoull(ptr noundef %13, ptr noundef %6, i32 noundef 10)
  store i64 %14, ptr %7, align 8
  %15 = load ptr, ptr %6, align 8
  %16 = icmp ne ptr %15, null
  br i1 %16, label %17, label %27

17:                                               ; preds = %12
  %18 = load ptr, ptr %6, align 8
  %19 = load i8, ptr %18, align 1
  %20 = sext i8 %19 to i32
  %21 = icmp eq i32 %20, 0
  br i1 %21, label %22, label %27

22:                                               ; preds = %17
  %23 = load i64, ptr %7, align 8
  %24 = icmp ugt i64 %23, 0
  br i1 %24, label %25, label %27

25:                                               ; preds = %22
  %26 = load i64, ptr %7, align 8
  br label %29

27:                                               ; preds = %22, %17, %12
  %28 = load i64, ptr %5, align 8
  br label %29

29:                                               ; preds = %27, %25
  %30 = phi i64 [ %26, %25 ], [ %28, %27 ]
  store i64 %30, ptr %3, align 8
  br label %31

31:                                               ; preds = %29, %10
  %32 = load i64, ptr %3, align 8
  ret i64 %32
}

; Function Attrs: nounwind
declare i32 @strcmp(ptr noundef, ptr noundef) #1

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define internal void @bench_const_range(i64 noundef %0) #0 {
  %2 = alloca i64, align 8
  %3 = alloca i64, align 8
  %4 = alloca ptr, align 8
  %5 = alloca ptr, align 8
  %6 = alloca ptr, align 8
  store i64 %0, ptr %2, align 8
  store i64 0, ptr %3, align 8
  br label %7

7:                                                ; preds = %27, %1
  %8 = load i64, ptr %3, align 8
  %9 = load i64, ptr %2, align 8
  %10 = icmp ult i64 %8, %9
  br i1 %10, label %11, label %30

11:                                               ; preds = %7
  %12 = call ptr @get_small_int(i64 -5)
  store ptr %12, ptr %4, align 8
  %13 = call ptr @get_small_int(i64 42)
  store ptr %13, ptr %5, align 8
  %14 = call ptr @get_small_int(i64 256)
  store ptr %14, ptr %6, align 8
  %15 = load ptr, ptr %4, align 8
  %16 = ptrtoint ptr %15 to i64
  %17 = load volatile i64, ptr @sink, align 8
  %18 = add i64 %17, %16
  store volatile i64 %18, ptr @sink, align 8
  %19 = load ptr, ptr %5, align 8
  %20 = ptrtoint ptr %19 to i64
  %21 = load volatile i64, ptr @sink, align 8
  %22 = add i64 %21, %20
  store volatile i64 %22, ptr @sink, align 8
  %23 = load ptr, ptr %6, align 8
  %24 = ptrtoint ptr %23 to i64
  %25 = load volatile i64, ptr @sink, align 8
  %26 = add i64 %25, %24
  store volatile i64 %26, ptr @sink, align 8
  br label %27

27:                                               ; preds = %11
  %28 = load i64, ptr %3, align 8
  %29 = add i64 %28, 1
  store i64 %29, ptr %3, align 8
  br label %7, !llvm.loop !6

30:                                               ; preds = %7
  ret void
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define internal void @bench_mixed(i64 noundef %0) #0 {
  %2 = alloca i64, align 8
  %3 = alloca i64, align 8
  %4 = alloca i64, align 8
  %5 = alloca ptr, align 8
  store i64 %0, ptr %2, align 8
  store i64 0, ptr %3, align 8
  br label %6

6:                                                ; preds = %20, %1
  %7 = load i64, ptr %3, align 8
  %8 = load i64, ptr %2, align 8
  %9 = icmp ult i64 %7, %8
  br i1 %9, label %10, label %23

10:                                               ; preds = %6
  %11 = load i64, ptr %3, align 8
  %12 = urem i64 %11, 1000
  %13 = sub nsw i64 %12, 100
  store i64 %13, ptr %4, align 8
  %14 = load i64, ptr %4, align 8
  %15 = call ptr @box_i64(i64 noundef %14)
  store ptr %15, ptr %5, align 8
  %16 = load ptr, ptr %5, align 8
  %17 = ptrtoint ptr %16 to i64
  %18 = load volatile i64, ptr @sink, align 8
  %19 = add i64 %18, %17
  store volatile i64 %19, ptr @sink, align 8
  br label %20

20:                                               ; preds = %10
  %21 = load i64, ptr %3, align 8
  %22 = add i64 %21, 1
  store i64 %22, ptr %3, align 8
  br label %6, !llvm.loop !8

23:                                               ; preds = %6
  ret void
}

; Function Attrs: noinline nounwind optnone ssp uwtable(sync)
define internal void @bench_large_only(i64 noundef %0) #0 {
  %2 = alloca i64, align 8
  %3 = alloca i64, align 8
  %4 = alloca i64, align 8
  %5 = alloca ptr, align 8
  store i64 %0, ptr %2, align 8
  store i64 0, ptr %3, align 8
  br label %6

6:                                                ; preds = %20, %1
  %7 = load i64, ptr %3, align 8
  %8 = load i64, ptr %2, align 8
  %9 = icmp ult i64 %7, %8
  br i1 %9, label %10, label %23

10:                                               ; preds = %6
  %11 = load i64, ptr %3, align 8
  %12 = and i64 %11, 1023
  %13 = add nsw i64 1000000, %12
  store i64 %13, ptr %4, align 8
  %14 = load i64, ptr %4, align 8
  %15 = call ptr @box_i64(i64 noundef %14)
  store ptr %15, ptr %5, align 8
  %16 = load ptr, ptr %5, align 8
  %17 = ptrtoint ptr %16 to i64
  %18 = load volatile i64, ptr @sink, align 8
  %19 = add i64 %18, %17
  store volatile i64 %19, ptr @sink, align 8
  br label %20

20:                                               ; preds = %10
  %21 = load i64, ptr %3, align 8
  %22 = add i64 %21, 1
  store i64 %22, ptr %3, align 8
  br label %6, !llvm.loop !9

23:                                               ; preds = %6
  ret void
}

; Function Attrs: nounwind
declare i32 @fprintf(ptr noundef, ptr noundef, ...) #1

declare i32 @printf(ptr noundef, ...) #2

declare i64 @strtoull(ptr noundef, ptr noundef, i32 noundef) #2

declare ptr @box_i64(i64 noundef) #2

declare void @log_fdiv()

declare void @log_divzero_check(double)

declare ptr @get_small_int(i64)

attributes #0 = { noinline nounwind optnone ssp uwtable(sync) "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #1 = { nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #2 = { "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8a" }
attributes #3 = { nounwind }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 2, !"SDK Version", [2 x i32] [i32 15, i32 5]}
!1 = !{i32 1, !"wchar_size", i32 4}
!2 = !{i32 8, !"PIC Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 1}
!4 = !{i32 7, !"frame-pointer", i32 1}
!5 = !{!"Homebrew clang version 21.1.3"}
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
!8 = distinct !{!8, !7}
!9 = distinct !{!9, !7}
