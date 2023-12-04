#!/bin/bash
set -x
set -eo pipefail

for entry in '_build/mina-*.deb'; do
  ./buildkite/scripts/cache-artifact.sh $entry ${BUILDKITE_BUILD_ID}
done
