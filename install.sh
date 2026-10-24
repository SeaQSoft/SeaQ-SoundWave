#!/bin/sh
# SeaQ SoundWave – install or update the widget and its translations.
# Usage:  sh install.sh            (install / update)
#         sh install.sh --remove   (uninstall)
set -e
ID="com.seaq.soundwave"
DOMAIN="plasma_applet_$ID"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOCALE="${XDG_DATA_HOME:-$HOME/.local/share}/locale"

if [ "$1" = "--remove" ]; then
    kpackagetool6 -t Plasma/Applet -r "$ID" || true
    find "$LOCALE" -name "$DOMAIN.mo" -delete 2>/dev/null || true
    find "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" -name "seaq-soundwave.png" -delete 2>/dev/null || true
    # desktop file and KWin rule that give the settings window its icon
    rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/seaq-soundwave.desktop"
    if command -v kwriteconfig6 >/dev/null; then
        for k in Description title titlematch wmclass wmclassmatch wmclasscomplete desktopfile desktopfilerule; do
            kwriteconfig6 --file kwinrulesrc --group seaq-soundwave-editor --key "$k" --delete
        done
        rules="$(kreadconfig6 --file kwinrulesrc --group General --key rules | tr ',' '\n' | grep -v '^seaq-soundwave-editor$' | paste -sd, -)"
        kwriteconfig6 --file kwinrulesrc --group General --key rules "$rules"
        kwriteconfig6 --file kwinrulesrc --group General --key count "$(printf '%s' "$rules" | tr ',' '\n' | grep -c .)"
    fi
    echo "SeaQ SoundWave removed."
    exit 0
fi

if kpackagetool6 -t Plasma/Applet -l | grep -q "^$ID$"; then
    kpackagetool6 -t Plasma/Applet -u "$HERE"
else
    kpackagetool6 -t Plasma/Applet -i "$HERE"
fi

# Translations: Plasma also reads them from the package, copying them to the
# user's locale folder makes sure every Plasma version finds them.
for mo in "$HERE"/contents/locale/*/LC_MESSAGES/"$DOMAIN".mo; do
    lang="$(basename "$(dirname "$(dirname "$mo")")")"
    mkdir -p "$LOCALE/$lang/LC_MESSAGES"
    cp "$mo" "$LOCALE/$lang/LC_MESSAGES/"
done

# Icon for the widget list
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
for n in 48 64 128 256; do
    mkdir -p "$ICONS/${n}x${n}/apps"
    cp "$HERE/contents/icons/seaq-soundwave-$n.png" "$ICONS/${n}x${n}/apps/seaq-soundwave.png"
done

echo "SeaQ SoundWave installed. Add it via right click on the desktop → Add Widgets…"
echo "Restart Plasma to see a new language right away:  systemctl --user restart plasma-plasmashell"
