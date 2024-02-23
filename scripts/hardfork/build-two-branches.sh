#!/usr/bin/env bash

set -eo pipefail

INIT_DIR="$PWD"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

compatible_build=$(mktemp -d)
git clone -b compatible --single-branch "https://github.com/MinaProtocol/mina.git" "$compatible_build"
cd "$compatible_build"
git submodule init
git submodule sync --recursive
git submodule update --init --recursive
git apply "$SCRIPT_DIR"/localnet-patches/compatible-{1,2}.patch
rm -Rf "$INIT_DIR/compatible-devnet"
nix build "$compatible_build?submodules=1#devnet" --out-link "$INIT_DIR/compatible-devnet"
cd -
rm -Rf "$compatible_build"

rm -Rf "$INIT_DIR/berkeley-devnet"
git apply "$SCRIPT_DIR"/localnet-patches/berkeley-{1,2,3}.patch
nix build "$INIT_DIR?submodules=1#devnet" --out-link "$INIT_DIR/berkeley-devnet"
git apply -R "$SCRIPT_DIR"/localnet-patches/berkeley-{1,2,3}.patch
