#!/bin/sh
# Compiles po/<lang>.po into contents/locale/<lang>/LC_MESSAGES/*.mo
# Needs gettext (msgfmt):  sudo dnf install gettext   /   sudo apt install gettext
set -e
cd "$(dirname "$0")/.."
DOMAIN="plasma_applet_com.seaq.soundwave"
for po in po/*.po; do
    lang="$(basename "$po" .po)"
    mkdir -p "contents/locale/$lang/LC_MESSAGES"
    msgfmt --check -o "contents/locale/$lang/LC_MESSAGES/$DOMAIN.mo" "$po"
    echo "✓ $lang"
done
