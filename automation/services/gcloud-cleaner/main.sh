#!/bin/bash

set -e

echo "==== CLEANING SINKS ===="
scripts/clean_old_sinks.sh --age=${AGE} --dryrun=${DRYRUN}
echo "==== CLEANING IMAGES ===="
python3 scripts/clean_old_images.py ${AGE} ${DRYRUN}