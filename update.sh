#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACKAGE_ID="alexankitty.fancytasks"
PACKAGE_PATH="$SCRIPT_DIR/package"
LOCAL_PACKAGE_DIR="$HOME/.local/share/plasma/plasmoids/$PACKAGE_ID"

if ! kpackagetool6 --type Plasma/Applet --upgrade "$PACKAGE_PATH"; then
	kpackagetool6 --type Plasma/Applet --remove "$PACKAGE_ID" >/dev/null 2>&1 || true
	rm -rf "$LOCAL_PACKAGE_DIR"
	kpackagetool6 --type Plasma/Applet --install "$PACKAGE_PATH"
fi

kquitapp6 plasmashell || true
nohup plasmashell --replace >/tmp/plasmashell.log 2>&1 &

sh "$SCRIPT_DIR/iconinstall.sh"