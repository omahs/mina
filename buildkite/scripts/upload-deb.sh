#!/bin/bash

set -eo pipefail

DEBS='mina-*.deb'
mkdir ${BUILDKITE_BUILD_ID}

cd _build

for entry in $DEBS; do
  cp $entry ${BUILDKITE_BUILD_ID}/$entry
   
  ./buildkite/scripts/cache-through.sh ${BUILDKITE_BUILD_ID}/$entry "echo \" cannot upload file $entry \" "
done

cd ../