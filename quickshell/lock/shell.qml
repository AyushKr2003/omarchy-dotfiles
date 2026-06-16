pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

ShellRoot {
    id: root

    readonly property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    Auth {
        id: pamAuth
        user: root.currentUser
        onSucceeded: {
            sessionLock.locked = false;
            Cava.enabled = false;
            Pw.text = "";
        }
    }


    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"

            LockSurface {
                anchors.fill: parent
                s: lockSurface.screen ? lockSurface.screen.height / 1080 : 1
                screenName: lockSurface.screen ? lockSurface.screen.name : ""
                auth: pamAuth
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            Pw.text = "";
            sessionLock.locked = true;
            Cava.enabled = true;
        }
    }
}
