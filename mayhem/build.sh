#!/usr/bin/env bash
#
# mayhem/build.sh — builds Gosu (C++ library) sanitized + the fuzz harnesses, and the GoogleTest suite
# with normal flags. Runs in the commit image as `mayhem` in /mayhem; re-runnable and offline.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# 1) Tests first, with the project's NORMAL flags: the GoogleTest runner lands at test/GosuTests
#    (gitignored upstream; recreated here, so a `git clean -ffdX` tree still builds + tests).
cmake -S . -B build/tests -G "Unix Makefiles" \
    -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$COVERAGE_FLAGS" -DCMAKE_SHARED_LINKER_FLAGS="$COVERAGE_FLAGS"
cmake --build build/tests -j"$MAYHEM_JOBS" --target GosuTests

# 2) The project itself (libgosu.a), sanitized, DWARF 3.
cmake -S . -B build/fuzz -G "Unix Makefiles" \
    -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="-O1 $SANITIZER_FLAGS $DEBUG_FLAGS" \
    -DCMAKE_CXX_FLAGS="-O1 $SANITIZER_FLAGS $DEBUG_FLAGS"
cmake --build build/fuzz -j"$MAYHEM_JOBS" --target gosu

# 3) Harnesses: a libFuzzer binary and a run-once -standalone reproducer each.
OUT="$SRC/build/harness"
mkdir -p "$OUT"
LIBS="$(pkg-config --libs sdl3 fontconfig gl) -lpthread -ldl"
CXXFLAGS_H="-std=c++20 -O1 $SANITIZER_FLAGS $DEBUG_FLAGS -DGOSU_DEPRECATED= \
    -I$SRC/include -I$SRC/src -I$SRC/dependencies/mojoAL/AL -I$SRC/dependencies/stb"

$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$OUT/lsan_off.o"
$CC  $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$OUT/standalone_main.o"

for h in fuzz_image fuzz_audio fuzz_markup fuzz_utf8 fuzz_ttf; do
    $CXX $CXXFLAGS_H -c "$SRC/mayhem/harnesses/$h.cpp" -o "$OUT/$h.o"
    $CXX $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE "$OUT/$h.o" "$OUT/lsan_off.o" \
        "$SRC/build/fuzz/libgosu.a" $LIBS -o "$SRC/$h"
    $CXX $SANITIZER_FLAGS $DEBUG_FLAGS "$OUT/$h.o" "$OUT/standalone_main.o" "$OUT/lsan_off.o" \
        "$SRC/build/fuzz/libgosu.a" $LIBS -o "$SRC/$h-standalone"
done
