#!/bin/bash

set -eo pipefail

DEBS='_build/mina-*.deb'
mkdir ${BUILDKITE_BUILD_ID}

for entry in $DEBS; do
  cp $entry ${BUILDKITE_BUILD_ID}/$entry
   
  ./buildkite/scripts/cache-through.sh ${BUILDKITE_BUILD_ID}/$entry "echo \" cannot upload file $entry \" "
done