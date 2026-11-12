#!/usr/bin/env bash
# Build MapLibre.xcframework from this repo (with GEBETA: patches) and place it
# where gebeta/Package.swift expects it. macOS + Xcode only.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[[ "$(uname)" == "Darwin" ]] || { echo "Requires macOS with Xcode." >&2; exit 1; }

git submodule update --init --recursive --depth 1
BUILD_TYPE="${BUILD_TYPE:-Release}"   # Release | Debug

# Same Bazel target the upstream release workflow uses.
mode="$( [[ $BUILD_TYPE == Release ]] && echo opt || echo dbg )"
bazel build --compilation_mode="$mode" --//:renderer=metal //platform/ios:MapLibre.dynamic

out="$(bazel info --compilation_mode="$mode" bazel-bin)/platform/ios/MapLibre.dynamic.xcframework.zip"
rm -rf gebeta/Frameworks/MapLibre.xcframework
mkdir -p gebeta/Frameworks
unzip -q "$out" -d gebeta/Frameworks
echo "Built gebeta/Frameworks/MapLibre.xcframework"
