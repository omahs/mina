#!/usr/bin/env bash

set -eo pipefail

init_dir="$PWD"

compatible_build=$(mktemp -d)
git clone -b georgeee/compatible-for-local-testing --single-branch "https://github.com/MinaProtocol/mina.git" "$compatible_build"
cd "$compatible_build"
git submodule init
git submodule sync --recursive
git submodule update --init --recursive
rm -Rf "$init_dir/compatible-devnet"
nix build "$compatible_build?submodules=1#devnet" --out-link "$init_dir/compatible-devnet"
cd -
rm -Rf "$compatible_build"

berkeley_build=$(mktemp -d)
git clone -b georgeee/berkeley-for-local-testing --single-branch "https://github.com/MinaProtocol/mina.git" "$berkeley_build"
cd "$berkeley_build"
git submodule init
git submodule sync --recursive
git submodule update --init --recursive
rm -Rf "$init_dir/berkeley-devnet"
nix build "$berkeley_build?submodules=1#devnet" --out-link "$init_dir/berkeley-devnet"
cd -
rm -Rf "$berkeley_build"
