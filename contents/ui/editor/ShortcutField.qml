import QtQuick
import org.kde.kquickcontrols as KQC

// Records the global shortcut (loaded through a Loader, so a missing
// kquickcontrols module only hides this control).
KQC.KeySequenceItem {
    id: ks
    property var app
    keySequence: app ? app.shortcutText : ""
    modifierlessAllowed: false
    onKeySequenceModified: {
        var t = String(keySequence);
        var m = /QKeySequence,\s*(.*)\)$/.exec(t);
        if (m)
            t = m[1];
        if (app)
            app.setShortcut(keySequence, t);
    }
}
