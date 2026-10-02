import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.services

// The lock screen. The compositor keeps the session locked until this says
// otherwise, so a crash here leaves the screen locked rather than open.
Scope {
  id: root

  property bool locked: false
  // "", "checking" or "failed".
  property string status: ""
  property string pending: ""

  Binding {
    target: Session
    property: "locked"
    value: root.locked
  }

  function lock() {
    if (locked) return
    status = ""
    locked = true
  }

  function submit(password) {
    if (pam.active || password === "") return
    pending = password
    status = "checking"
    if (!pam.start()) {
      pending = ""
      status = "failed"
    }
  }

  // Password check only; the stack is the one installed for Roseshell.
  PamContext {
    id: pam
    config: "roseshell-lock-password"

    onResponseRequiredChanged: if (responseRequired) respond(root.pending)
    onCompleted: function(result) {
      root.pending = ""
      if (result === PamResult.Success) {
        root.status = ""
        root.locked = false
        root.previewing = false
      } else {
        root.status = "failed"
      }
    }
    onError: function(error) {
      root.pending = ""
      root.status = "failed"
    }
  }

  WlSessionLock {
    locked: root.locked

    WlSessionLockSurface {
      color: "black"

      LockSurface {
        anchors.fill: parent
        lock: root
      }
    }
  }

  Connections {
    target: Session
    function onLockRequested() { root.lock() }
  }

  IpcHandler {
    target: "lock"
    function lock(): void { root.lock() }
    function isLocked(): bool { return root.locked }
  }

  // The lock surface in an ordinary window, for working on its looks without
  // locking anything: `qs ipc call lockPreview toggle`. A correct password closes it.
  property bool previewing: false
  IpcHandler {
    target: "lockPreview"
    function toggle(): void { root.previewing = !root.previewing }
  }

  LazyLoader {
    active: root.previewing

    FloatingWindow {
      implicitWidth: 900
      implicitHeight: 600
      color: "black"
      onClosed: root.previewing = false

      LockSurface {
        anchors.fill: parent
        lock: root
      }
    }
  }
}
