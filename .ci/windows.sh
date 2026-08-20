#!/bin/sh -ex

mkdir build && cd build

if [ "$GITHUB_REF_TYPE" == "tag" ]; then
	export EXTRA_CMAKE_FLAGS=(-DENABLE_QT_UPDATE_CHECKER=ON)
fi

if [ "$TARGET" == "msvc" ]; then
	# Resolve zlib via a standalone vcpkg manifest install rather than the CMake
	# toolchain file: the toolchain file globally overrides add_library(), which
	# collides with vendored submodules that already define targets of their own
	# (e.g. dynarmic's bundled Zydis). CMAKE_PREFIX_PATH lets find_package(ZLIB)
	# discover the installed package without that global hook.
	"$VCPKG_ROOT/vcpkg.exe" install --triplet x64-windows --x-manifest-root=..
	vcpkg_zlib_header="$(find .. -path '*/vcpkg_installed/*/include/zlib.h' -print -quit)"
	if [ -z "$vcpkg_zlib_header" ]; then
		echo "::error ::Could not locate vcpkg-installed zlib after 'vcpkg install'"
		exit 1
	fi
	vcpkg_prefix="$(dirname "$(dirname "$vcpkg_zlib_header")")"
	EXTRA_CMAKE_FLAGS+=(-DCMAKE_PREFIX_PATH="$vcpkg_prefix")
fi

cmake .. -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DENABLE_DISCORD_RPC=ON \
	"${EXTRA_CMAKE_FLAGS[@]}"
ninja
ninja bundle
strip -s bundle/*.exe

ccache -s -v

ctest -VV -C Release || echo "::error ::Test error occurred on Windows build"
