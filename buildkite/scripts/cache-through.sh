#!/bin/bash

set -eou pipefail
set +x

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <path-to-file> <miss-in-docker-cmd>"
  exit 1
fi

UPLOAD_BIN=gsutil
PREFIX=gs://buildkite_k8s/coda/shared
FILE="$1"
MISS_CMD="$2"

set +e
if [[ -f "${FILE}" ]] || $UPLOAD_BIN cp "${PREFIX}/${FILE}" .; then
  set -e
  echo "*** Cache Hit -- skipping step ***"
else
  set -e
  echo "*** Cache miss -- executing step ***"
  bash -c "$MISS_CMD"
  $UPLOAD_BIN cp "${FILE}" "${PREFIX}/${FILE}"
fi

