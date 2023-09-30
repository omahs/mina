#!/bin/bash
set -eo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-tag>"
  exit 1
fi

NEW_TAG=$1
DOCKER_REGISTRY="gcr.io/o1labs-192920"

SERVICES=('mina-archive', 'mina-daemon' 'mina-rosetta' 'mina-logproc' 'mina-batch-txn' 'mina-zkapp-test-transaction')

source buildkite/scripts/export-git-env-vars.sh

## now loop through the above array
for SERVICE in "${SERVICES[@]}"
do
    MINA_DEB_VERSION="${GITHASH}-${MINA_DEB_CODENAME}-${GITBRANCH}"
    IMAGE="${DOCKER_REGISTRY}/${SERVICE}:${MINA_DEB_VERSION}"

    IMAGE_AFTER="${DOCKER_REGISTRY}/${SERVICE}:${NEW_TAG}"

    docker pull ${IMAGE}
    docker tag ${IMAGE} $IMAGE_AFTER

    docker push $IMAGE_AFTER
done