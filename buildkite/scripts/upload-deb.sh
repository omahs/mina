#!/bin/bash
set -eo pipefail

for entry in **/mina-*.deb; do
  ./buildkite/scripts/cache-artifact.sh $entry ${BUILDKITE_BUILD_ID}
done
