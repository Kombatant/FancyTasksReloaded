#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
cp "$SCRIPT_DIR/package/FancyTasks.png" "$HOME/.local/share/icons/hicolor/256x256/apps/FancyTasks.png"