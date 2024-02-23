#!/usr/bin/env bash

set -eo pipefail

NIX_OPTS=( --accept-flake-config --experimental-features 'nix-command flakes' --print-build-logs )

INIT_DIR="$PWD"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ $# -gt 0 ]]; then
  # Branch is specified, this is a CI run
  chown -R "${USER}" /workdir
  git config --global --add safe.directory /workdir
  git fetch
fi

if [[ ! -L compatible-devnet ]]; then
  if [[ $# == 0 ]]; then
    compatible_build=$(mktemp -d)
    git clone -b compatible --single-branch "https://github.com/MinaProtocol/mina.git" "$compatible_build"
    cd "$compatible_build"
  else
    git checkout $1
    git checkout compatible
    git checkout $1 -- scripts/hardfork
    compatible_build="$INIT_DIR"
  fi
  git submodule sync --recursive
  git submodule update --init --recursive
  git apply "$SCRIPT_DIR"/localnet-patches/compatible-{1,2}.patch
  nix "${NIX_OPTS[@]}" build "$compatible_build?submodules=1#devnet" --out-link "$INIT_DIR/compatible-devnet"
  git apply -R "$SCRIPT_DIR"/localnet-patches/compatible-{1,2}.patch
  if [[ $# == 0 ]]; then
    cd -
    rm -Rf "$compatible_build"
  fi
fi

if [[ ! -L fork-devnet ]]; then
  if [[ $# -gt 0 ]]; then
    # Branch is specified, this is a CI run
    git checkout $1
    git submodule sync --recursive
    git submodule update --init --recursive
  fi
  git apply "$SCRIPT_DIR"/localnet-patches/berkeley-{1,2,3}.patch
  nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet" --out-link "$INIT_DIR/fork-devnet"
  git apply -R "$SCRIPT_DIR"/localnet-patches/berkeley-{1,2,3}.patch
fi

"$SCRIPT_DIR"/test.sh compatible-devnet/bin/mina fork-devnet/bin/{mina,runtime_genesis_ledger}
