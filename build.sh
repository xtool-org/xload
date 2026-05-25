#!/bin/bash

set -euo pipefail

rm -rf out
mkdir -p out

function build {
    echo "Building for $1..."
    "$(xcrun -f swift)" build -c release --product XLoadDynamic --swift-sdk "$1"
    cp -a ".build/$1/release/libXLoadDynamic.dylib" "out/libXLoadDynamic.$2.dylib"
}

build arm64-apple-ios-simulator "iphonesimulator"
build arm64-apple-macosx "macosx-arm64"
build x86_64-apple-macosx "macosx-x86_64"
