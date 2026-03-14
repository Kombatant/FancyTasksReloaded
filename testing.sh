#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGE_ID="org.kombatant.fancytasks"
LEGACY_PACKAGE_ID="alexankitty.fancytasks"
PACKAGE_PATH="$SCRIPT_DIR/package"
LOCAL_PACKAGE_DIR="$HOME/.local/share/plasma/plasmoids/$PACKAGE_ID"
LEGACY_LOCAL_PACKAGE_DIR="$HOME/.local/share/plasma/plasmoids/$LEGACY_PACKAGE_ID"

kpackagetool6 --type Plasma/Applet --remove "$LEGACY_PACKAGE_ID" >/dev/null 2>&1 || true
rm -rf "$LEGACY_LOCAL_PACKAGE_DIR"

if ! kpackagetool6 --type Plasma/Applet --upgrade "$PACKAGE_PATH"; then
	kpackagetool6 --type Plasma/Applet --remove "$PACKAGE_ID" >/dev/null 2>&1 || true
	rm -rf "$LOCAL_PACKAGE_DIR"
	kpackagetool6 --type Plasma/Applet --install "$PACKAGE_PATH"
fi

QML_DISABLE_DISK_CACHE=true plasmawindowed -a org.kombatant.fancytasks
