#!/bin/bash
set -eo pipefail

DEBS='_build/mina-*.deb'

for entry in "$DEBS"/*
do
  buildkite/scripts/cache-through $entry