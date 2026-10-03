#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Build Script for Teeworlds 0.6.5 (Surface RT / Windows RT - ARM32)
# ==============================================================================

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/src"
DATA="$ROOT/data"
LIBS="$ROOT/libs"
LIBSARM="$LIBS/arm32"
INCLUDE_DIR="$LIBS/include"
RUNTIME_DIR="$LIBS/runtime"

BUILD_DIR="$ROOT/build"
OBJ_DIR="$BUILD_DIR/obj"
DIST_DIR="$ROOT/dist"

JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
BUILD_TARGET="${1:-all}"

# Find LLVM-MinGW Toolchain
find_toolchain() {
    if [[ -n "${LLVM_MINGW_ROOT:-}" && -x "$LLVM_MINGW_ROOT/bin/armv7-w64-mingw32-clang++" ]]; then
        echo "$LLVM_MINGW_ROOT"
        return 0
    fi

    if command -v armv7-w64-mingw32-clang++ >/dev/null 2>&1; then
        dirname "$(dirname "$(command -v armv7-w64-mingw32-clang++)")"
        return 0
    fi

    local candidate_dirs=(
        "/opt/llvm-mingw"
        "/usr/local/llvm-mingw"
        "$HOME/llvm-mingw"
        "$ROOT/toolchain"
    )

    for dir in "${candidate_dirs[@]}"; do
        if [[ -x "$dir/bin/armv7-w64-mingw32-clang++" ]]; then
            echo "$dir"
            return 0
        fi
    done

    return 1
}

TOOLCHAIN="$(find_toolchain || true)"
if [[ -z "$TOOLCHAIN" || ! -x "$TOOLCHAIN/bin/armv7-w64-mingw32-clang++" ]]; then
    echo "ERROR: llvm-mingw toolchain with armv7-w64-mingw32-clang++ not found." >&2
    echo "Please set LLVM_MINGW_ROOT environment variable or add it to PATH." >&2
    exit 1
fi

CC="$TOOLCHAIN/bin/armv7-w64-mingw32-clang"
CXX="$TOOLCHAIN/bin/armv7-w64-mingw32-clang++"
AR="$TOOLCHAIN/bin/armv7-w64-mingw32-ar"

echo "==> Using toolchain: $TOOLCHAIN"
echo "==> Target: ARMv7 (Windows RT / Surface RT)"
echo "==> Building: $BUILD_TARGET"

mkdir -p "$OBJ_DIR" "$DIST_DIR"

COMMON_FLAGS=(
    -O2
    -ffunction-sections
    -fdata-sections
    -I"$SRC"
    -I"$INCLUDE_DIR"
    -I"$INCLUDE_DIR/SDL"
    -I"$SRC/engine/external/wavpack"
    -I"$SRC/engine/external/zlib"
    -include "$INCLUDE_DIR/winrt_compat.h"
)

CXX_FLAGS=(
    "${COMMON_FLAGS[@]}"
    -fno-exceptions
    -fno-rtti
    -Wno-deprecated-non-prototype
    -Wno-unknown-warning-option
)

# 1. External libraries
build_ext_libs() {
    echo "==> [1/4] Compiling external libraries..."
    mkdir -p "$OBJ_DIR/ext/zlib" "$OBJ_DIR/ext/pnglite" "$OBJ_DIR/ext/md5" "$OBJ_DIR/ext/wavpack"

    for f in "$SRC"/engine/external/zlib/*.c; do
        "$CC" "${COMMON_FLAGS[@]}" -c "$f" -o "$OBJ_DIR/ext/zlib/$(basename "$f" .c).o"
    done
    for f in "$SRC"/engine/external/pnglite/*.c; do
        "$CC" "${COMMON_FLAGS[@]}" -c "$f" -o "$OBJ_DIR/ext/pnglite/$(basename "$f" .c).o"
    done
    for f in "$SRC"/engine/external/md5/*.c; do
        "$CC" "${COMMON_FLAGS[@]}" -c "$f" -o "$OBJ_DIR/ext/md5/$(basename "$f" .c).o"
    done
    for f in "$SRC"/engine/external/wavpack/*.c; do
        "$CC" "${COMMON_FLAGS[@]}" -c "$f" -o "$OBJ_DIR/ext/wavpack/$(basename "$f" .c).o"
    done

    "$AR" rcs "$BUILD_DIR/lib_ext.a" \
        "$OBJ_DIR"/ext/zlib/*.o \
        "$OBJ_DIR"/ext/pnglite/*.o \
        "$OBJ_DIR"/ext/md5/*.o \
        "$OBJ_DIR"/ext/wavpack/*.o
}

# 2. Client
build_client() {
    echo "==> [2/4] Compiling client sources..."
    mkdir -p "$OBJ_DIR/shared" "$OBJ_DIR/game" "$OBJ_DIR/base" "$OBJ_DIR/client" "$OBJ_DIR/gcli" "$OBJ_DIR/editor"

    CLIENT_OBJS=()

    for f in "$SRC"/engine/shared/*.cpp; do
        o="$OBJ_DIR/shared/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        CLIENT_OBJS+=("$o")
    done

    "$CXX" "${CXX_FLAGS[@]}" -c "$SRC/game/generated/protocol.cpp" -o "$OBJ_DIR/game/protocol.o"
    CLIENT_OBJS+=("$OBJ_DIR/game/protocol.o")

    "$CXX" "${CXX_FLAGS[@]}" -c "$SRC/game/generated/client_data.cpp" -o "$OBJ_DIR/game/client_data.o"
    CLIENT_OBJS+=("$OBJ_DIR/game/client_data.o")

    "$CC" "${COMMON_FLAGS[@]}" -c "$SRC/base/system.c" -o "$OBJ_DIR/base/system.o"
    CLIENT_OBJS+=("$OBJ_DIR/base/system.o")

    for f in "$SRC"/game/*.cpp; do
        o="$OBJ_DIR/game/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        CLIENT_OBJS+=("$o")
    done

    if [[ -f "$SRC/game/generated/git_revision.cpp" ]]; then
        "$CXX" "${CXX_FLAGS[@]}" -c "$SRC/game/generated/git_revision.cpp" -o "$OBJ_DIR/game/git_revision.o"
        CLIENT_OBJS+=("$OBJ_DIR/game/git_revision.o")
    fi

    for f in "$SRC"/engine/client/*.cpp; do
        o="$OBJ_DIR/client/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        CLIENT_OBJS+=("$o")
    done

    if [[ -f "$SRC/engine/client/glu_compat.c" ]]; then
        "$CC" "${COMMON_FLAGS[@]}" -c "$SRC/engine/client/glu_compat.c" -o "$OBJ_DIR/client/glu_compat.o"
        CLIENT_OBJS+=("$OBJ_DIR/client/glu_compat.o")
    fi

    for f in "$SRC"/game/client/components/*.cpp "$SRC"/game/client/*.cpp; do
        o="$OBJ_DIR/gcli/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        CLIENT_OBJS+=("$o")
    done

    for f in "$SRC"/game/editor/*.cpp; do
        o="$OBJ_DIR/editor/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        CLIENT_OBJS+=("$o")
    done

    echo "==> Linking teeworlds.exe..."
    "$CXX" -mwindows -o "$DIST_DIR/teeworlds.exe" \
        "${CLIENT_OBJS[@]}" \
        "$BUILD_DIR/lib_ext.a" \
        "$LIBSARM/libfreetype.a" \
        "$LIBSARM/libSDL.a" \
        -Wl,-Bstatic -lc++ -lc++abi -lunwind -Wl,-Bdynamic \
        -lopengl32 -lwinmm -lws2_32 -luser32 -lgdi32 -ladvapi32 -lshell32 \
        -s
}

# 3. Server
build_server() {
    echo "==> [3/4] Compiling server sources..."
    mkdir -p "$OBJ_DIR/sv_shared" "$OBJ_DIR/sv_esrv" "$OBJ_DIR/sv_game" "$OBJ_DIR/sv_gsrv" "$OBJ_DIR/sv_gen" "$OBJ_DIR/sv_base"

    SERVER_OBJS=()

    for f in "$SRC"/engine/shared/*.cpp; do
        o="$OBJ_DIR/sv_shared/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        SERVER_OBJS+=("$o")
    done

    for f in "$SRC"/engine/server/*.cpp; do
        o="$OBJ_DIR/sv_esrv/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        SERVER_OBJS+=("$o")
    done

    for f in "$SRC"/game/*.cpp; do
        o="$OBJ_DIR/sv_game/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        SERVER_OBJS+=("$o")
    done

    for f in "$SRC"/game/server/*.cpp "$SRC"/game/server/entities/*.cpp "$SRC"/game/server/gamemodes/*.cpp; do
        o="$OBJ_DIR/sv_gsrv/$(basename "$f" .cpp).o"
        "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
        SERVER_OBJS+=("$o")
    done

    for f in "$SRC/game/generated/protocol.cpp" "$SRC/game/generated/nethash.cpp" "$SRC/game/generated/server_data.cpp"; do
        if [[ -f "$f" ]]; then
            o="$OBJ_DIR/sv_gen/$(basename "$f" .cpp).o"
            "$CXX" "${CXX_FLAGS[@]}" -c "$f" -o "$o"
            SERVER_OBJS+=("$o")
        fi
    done

    "$CC" "${COMMON_FLAGS[@]}" -c "$SRC/base/system.c" -o "$OBJ_DIR/sv_base/system.o"
    SERVER_OBJS+=("$OBJ_DIR/sv_base/system.o")

    echo "==> Linking teeworlds_server.exe..."
    "$CXX" -o "$DIST_DIR/teeworlds_server.exe" \
        "${SERVER_OBJS[@]}" \
        "$BUILD_DIR/lib_ext.a" \
        "$LIBSARM/libfreetype.a" \
        -Wl,-Bstatic -lc++ -lc++abi -lunwind -Wl,-Bdynamic \
        -lws2_32 -lwinmm -luser32 -lgdi32 -ladvapi32 -lshell32 \
        -s
}

# 4. Package distribution bundle
package_dist() {
    echo "==> [4/4] Packaging distribution bundle..."
    if [[ -d "$RUNTIME_DIR" ]]; then
        cp -af "$RUNTIME_DIR"/* "$DIST_DIR/" 2>/dev/null || true
    fi

    if [[ ! -d "$DIST_DIR/data" && -d "$DATA" ]]; then
        cp -a "$DATA" "$DIST_DIR/"
    fi
}

build_ext_libs

case "$BUILD_TARGET" in
    client)
        build_client
        ;;
    server)
        build_server
        ;;
    all|*)
        build_client
        build_server
        ;;
esac

package_dist

echo "==> Build finished successfully!"
echo "    Output directory: $DIST_DIR"
