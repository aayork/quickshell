import QtQuick
import qs.theme

// An Aero switch: a sunken groove that fills with blue gel when on, and a
// glossy white knob.
Item {
  id: root

  property bool checked: false
  signal toggled()

  implicitWidth: 36
  implicitHeight: 18
  opacity: enabled ? 1 : 0.4

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.28)
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.alpha(Theme.foreground, 0.16) }
      GradientStop { position: 1; color: Theme.alpha(Theme.foreground, 0.05) }
    }
  }

  Gel {
    anchors.fill: parent
    opacity: root.checked ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }
  }

  Rectangle {
    y: 1
    x: root.checked ? parent.width - width - 1 : 1
    width: parent.height - 2
    height: width
    radius: width / 2
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.3)
    gradient: Gradient {
      GradientStop { position: 0; color: "#ffffff" }
      GradientStop { position: 1; color: "#d9e6f0" }
    }
    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.toggled()
  }
}
