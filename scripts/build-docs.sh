#!/usr/bin/env bash
# Copyright Kani Contributors
# SPDX-License-Identifier: Apache-2.0 OR MIT

# Build all our documentation and place them under book/ directory.
# The user facing doc is built into book/
# RFCs are placed under book/rfcs/

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd $SCRIPT_DIR

# Download mdbook release (vs spending time building it via cargo install)
MDBOOK_VERSION=v0.4.18
FILE="mdbook-${MDBOOK_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
URL="https://github.com/rust-lang/mdBook/releases/download/${MDBOOK_VERSION}/$FILE"
EXPECTED_HASH="d276b0e594d5980de6a7917ce74c348f28d3cb8b353ca4eaae344ae8a4c40bea"
if [ ! -x mdbook ]; then
    curl -sSL -o "$FILE" "$URL"
    echo "$EXPECTED_HASH $FILE" | sha256sum -c -
    tar zxf $FILE
fi

# Publish bookrunner report into our documentation
KANI_DIR=$SCRIPT_DIR/..
DOCS_DIR=$KANI_DIR/docs
RFCS_DIR=$KANI_DIR/rfcs
HTML_DIR=$KANI_DIR/build/output/latest/html/

cd $DOCS_DIR

if [ -d $HTML_DIR ]; then
    # Litani run is copied into `src` to avoid deletion by `mdbook`
    cp -r $HTML_DIR src/bookrunner/
    # Replace artifacts by examples under test
    BOOKS_DIR=$KANI_DIR/tests/bookrunner/books
    rm -r src/bookrunner/artifacts
    cp -r $BOOKS_DIR src/bookrunner/artifacts
    # Update paths in HTML report
    python $KANI_DIR/scripts/ci/update_bookrunner_report.py src/bookrunner/index.html new_index.html
    mv new_index.html src/bookrunner/index.html

    # rm src/bookrunner/run.json
else
    echo "WARNING: Could not find the latest bookrunner run."
fi

echo "Building use documentation..."
# Build the book into ./book/
mkdir -p book
mkdir -p book/rfcs
$SCRIPT_DIR/mdbook build
touch book/.nojekyll

echo "Building RFCs book..."
cd $RFCS_DIR
$SCRIPT_DIR/mdbook build -d $KANI_DIR/docs/book/rfcs

# Testing of the code in the documentation is done via the usual
# ./scripts/kani-regression.sh script. A note on running just the
# doc tests is in README.md. We don't run them here because
# that would cause CI to run these tests twice.

echo "Finished documentation build successfully."
