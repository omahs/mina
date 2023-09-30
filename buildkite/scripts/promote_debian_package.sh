#!/bin/bash

set -eou pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <from-channel> <to-channel> <codename>"
  exit 1
fi

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

#sudo apt-get update
#sudo apt-get install -y git apt-transport-https ca-certificates tzdata curl python3

case "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" in
  rampup|berkeley|release/2.0.0|develop)
    TESTNET_NAME="berkeley"
  ;;
  *)
    TESTNET_NAME="mainnet"
esac

FROM_RELEASE=$1
RELEASE=$2
MINA_DEB_CODENAME=$3

source buildkite/scripts/export-git-env-vars.sh

echo "Installing mina daemon package: mina-${TESTNET_NAME}=${MINA_DEB_VERSION}"
#echo "deb [trusted=yes] http://packages.o1test.net $MINA_DEB_CODENAME $FROM_RELEASE" | sudo tee /etc/apt/sources.list.d/mina.list
#sudo apt-get update
sudo apt-get install --allow-downgrades -y --download-only "mina-${TESTNET_NAME}=${MINA_DEB_VERSION}" \
 --download-only "mina-archive=${MINA_DEB_VERSION}" \
 --download-only "mina-logproc=${MINA_DEB_VERSION}" \
 --download-only "mina-batch-txn=${MINA_DEB_VERSION}" \
 --download-only "mina-zkapp-test-transaction=${MINA_DEB_VERSION}"

mkdir -p _build
cp /var/cache/apt/archives/mina-*.deb _build

buildkite/scripts/publish-deb.sh