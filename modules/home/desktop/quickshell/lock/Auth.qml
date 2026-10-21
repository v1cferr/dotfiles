// The lock's ONE password buffer and PAM conversation, shared by every screen: typing on either
// monitor fills the same field. The PAM service comes from NixOS (security.pam.services).
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick

Scope {
    id: auth

    property string buffer: ""
    property int fails: 0
    readonly property bool busy: pam.active
    property string pending: ""
    property bool answered: false
    signal unlocked
    signal failed

    function type(text) {
        if (!pam.active)
            auth.buffer += text;
    }
    function erase() {
        if (!pam.active)
            auth.buffer = auth.buffer.slice(0, -1);
    }
    function clear() {
        if (!pam.active)
            auth.buffer = "";
    }
    function submit() {
        if (pam.active || auth.buffer === "")
            return;
        auth.pending = auth.buffer;
        auth.answered = false;
        pam.start();
    }
    function markSecure() {
        const p = Quickshell.env("LOCK_SECURE_FILE");
        if (p)
            secureFile.setText("secure");
    }

    PamContext {
        id: pam
        config: Quickshell.env("LOCK_PAM_CONFIG") || "quickshell-lock"
        configDirectory: Quickshell.env("LOCK_PAM_DIR") || "/etc/pam.d"
        // One answer per attempt: a second prompt (a module asking for more) ends the attempt.
        onResponseRequiredChanged: {
            if (!pam.responseRequired)
                return;
            if (auth.answered) {
                pam.abort();
                return;
            }
            auth.answered = true;
            pam.respond(auth.pending);
        }
        onCompleted: result => {
            auth.pending = "";
            auth.buffer = "";
            if (result === PamResult.Success) {
                // The launcher reads this: an exit without it means the lock died locked.
                if (Quickshell.env("LOCK_SECURE_FILE"))
                    secureFile.setText("unlocked");
                auth.unlocked();
            } else {
                auth.fails += 1;
                auth.failed();
            }
        }
    }

    FileView {
        id: secureFile
        path: Quickshell.env("LOCK_SECURE_FILE") || ""
        printErrors: false
    }
}
