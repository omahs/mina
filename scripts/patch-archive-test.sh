#!/bin/bash

# test replayer on known archive db

DUMP=src/test/archive/archive-patch-test/data/dump.sql
PRECOMPUTED_BLOCKS_FILTER=src/test/archive/archive-patch-test/data/precomputed-*.json
PATCH_ARCHIVE_TEST_APP=${PATCH_ARCHIVE_TEST_APP:-src/test/archive/patch_archive_test/patch_archive_test.exe}
EXTRACT_BLOCK_APP=${EXTRACT_BLOCK_APP:-_build/default/src/app/extract_blocks/extract_blocks.exe}
ARCHIVE_BLOCK_APP=${ARCHIVE_BLOCK_APP:-_build/default/src/app/archive_blocks/archive-blocks.exe}
PG_CONN=${PG_CONN:-postgres://postgres:postgres@localhost:5433/archive}

function report () {
 if [[ $1 == 0 ]]; then
     echo SUCCEEDED
 else
     echo FAILED
 fi
}

echo "Running replayer"
$PATCH_ARCHIVE_TEST_APP --archive-uri $PG_CONN \
                        --num-blocks-to-patch 3 \
                        --archive-blocks-path $ARCHIVE_BLOCK_APP \
                        --extract-blocks-path $EXTRACT_BLOCK_APP \
                        --precomputed
                        $(find $PRECOMPUTED_BLOCKS_FILTER -type f -printf "%p ")

RESULT=$?

report $RESULT

exit $RESULT
