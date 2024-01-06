#!/usr/bin/env bash
# Copyright Kani Contributors
# SPDX-License-Identifier: Apache-2.0 OR MIT

# Collect some metrics related to the crates that compose the standard library.
#
# Files generates so far:
#
#  - ${crate}_scan_overall.csv: Summary of function metrics, such as safe vs unsafe.
#  - ${crate}_scan_input_tys.csv: Detailed information about the inputs' type of each
#    function found in this crate.
#
# How we collect metrics:
#
# - Compile the standard library using the `scan` tool to collect some metrics.
# - After compilation, move all CSV files that were generated by the scanner,
#   to the results folder.
set -eu

# Test for platform
PLATFORM=$(uname -sp)
if [[ $PLATFORM == "Linux x86_64" ]]
then
  TARGET="x86_64-unknown-linux-gnu"
  # 'env' necessary to avoid bash built-in 'time'
  WRAPPER="env time -v"
elif [[ $PLATFORM == "Darwin i386" ]]
then
  TARGET="x86_64-apple-darwin"
  # mac 'time' doesn't have -v
  WRAPPER="time"
elif [[ $PLATFORM == "Darwin arm" ]]
then
  TARGET="aarch64-apple-darwin"
  # mac 'time' doesn't have -v
  WRAPPER="time"
else
  echo
  echo "Std-Lib codegen regression only works on Linux or OSX x86 platforms, skipping..."
  echo
  exit 0
fi

# Get Kani root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
KANI_DIR=$(dirname "$SCRIPT_DIR")

echo "-------------------------------------------------------"
echo "-- Starting analysis of the Rust standard library... --"
echo "-------------------------------------------------------"

echo "-- Build scanner"
cd $KANI_DIR
cargo build -p scanner

echo "-- Build std"
cd /tmp
if [ -d std_lib_analysis ]
then
    rm -rf std_lib_analysis
fi
cargo new std_lib_analysis --lib
cd std_lib_analysis

echo '
pub fn dummy() {
}
' > src/lib.rs

# Use same nightly toolchain used to build Kani
cp ${KANI_DIR}/rust-toolchain.toml .

export RUST_BACKTRACE=1
export RUSTC_LOG=error

RUST_FLAGS=(
    "-Cpanic=abort"
    "-Zalways-encode-mir"
)
export RUSTFLAGS="${RUST_FLAGS[@]}"
export RUSTC="$KANI_DIR/target/debug/scan"
# Compile rust with our extension
$WRAPPER cargo build --verbose -Z build-std --lib --target $TARGET

echo "-- Process results"

# Move files to results folder
results=/tmp/std_lib_analysis/results
mkdir $results
find /tmp/std_lib_analysis/target -name "*.csv" -exec mv {} $results \;

# Create a summary table
summary=$results/summary.csv

# write header
echo -n "crate," > $summary
tr -d [:digit:], < $results/alloc_scan_overall.csv \
    | tr -s '\n' ',' >> $summary
echo "" >> $summary

# write body
for f in $results/*overall.csv; do
    # Join all crate summaries into one table
    fname=$(basename $f)
    crate=${fname%_scan_overall.csv}
    echo -n "$crate," >> $summary
    tr -d [:alpha:]_, < $f | tr -s '\n' ',' \
        >> $summary
    echo "" >> $summary
done

echo "-------------------------------------------------------"
echo "Finished analysis successfully..."
echo "- See results at ${results}"
echo "-------------------------------------------------------"
