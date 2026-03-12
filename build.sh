#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

cd "$SCRIPT_DIR/package/translate/"
sh ./merge
sh ./build

rm -rf "$SCRIPT_DIR/build" "$SCRIPT_DIR/release"
mkdir -p "$SCRIPT_DIR/build" "$SCRIPT_DIR/release"
cp -r "$SCRIPT_DIR/package/contents" "$SCRIPT_DIR/build"
cp "$SCRIPT_DIR/package/metadata.json" "$SCRIPT_DIR/build"
cp "$SCRIPT_DIR/package/FancyTasks.png" "$SCRIPT_DIR/build"

cd "$SCRIPT_DIR/build"
tar cf "$SCRIPT_DIR/release/FancyTasks.tar.gz" .
rm -rf "$SCRIPT_DIR/build"