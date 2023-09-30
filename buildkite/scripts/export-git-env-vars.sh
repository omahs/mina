#!/bin/bash
set -euo pipefail

echo "Exporting Variables: "

function find_most_recent_numeric_tag() {
    TAG=$(git describe --always --abbrev=0 $1 | sed 's!/!-!g; s!_!-!g')
    if [[ $TAG != [0-9]* ]]; then
        TAG=$(find_most_recent_numeric_tag $TAG~)
    fi
    echo $TAG
}

export GITHASH=$(git rev-parse --short=7 HEAD)
export GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!g; s!_!-!g' )
# GITTAG is the closest tagged commit to this commit, while THIS_COMMIT_TAG only has a value when the current commit is tagged
export GITTAG=$(find_most_recent_numeric_tag HEAD)
export PROJECT="mina"

set +u
export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}
set -u

export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}

[[ -n "$BUILDKITE_BRANCH" ]] && export GITBRANCH=$(echo "$BUILDKITE_BRANCH" | sed 's!/!-!g; s!_!-!g')

export MINA_DEB_VERSION="${GITTAG}-${GITBRANCH}-${GITHASH}"
export MINA_DOCKER_TAG="$(echo "${MINA_DEB_VERSION}-${MINA_DEB_CODENAME}" | sed 's!/!-!g; s!_!-!g')"

RELEASE=${RELEASE:=unstable}

# Determine the packages to build (mainnet y/N)
case $GITBRANCH in
    compatible|master|release/1*) # whitelist of branches that are "mainnet-like"
      MINA_BUILD_MAINNET=true ;;
    *) # Other branches
      MINA_BUILD_MAINNET=false ;;
esac

echo "Publishing on release channel \"${RELEASE}\""
export MINA_DEB_RELEASE="${RELEASE}"