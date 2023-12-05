#!/bin/bash
set -eo pipefail

for entry in **/mina-*.deb; do
  ./buildkite/scripts/buildkite-artifact-helper.sh $entry 
done
