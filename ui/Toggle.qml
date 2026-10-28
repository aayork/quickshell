import QtQuick
import qs.theme

// An Aero switch: a sunken glass groove that fills with glossy blue gel when
// on, and a pearly knob with a soft shadow and a glint.
Item {
  id: root

  property bool checked: false
  signal toggled()

  implicitWidth: 38
  implicitHeight: 20
  opacity: enabled ? 1 : 0.4

  // The groove: darker along the top edge, like it is pressed into the glass.
  Rectangle {
    anchors.fill: parent
    radius: height / 2
    border.width: 1
    border.color: Theme.alpha(Theme.foreground, 0.3)
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.alpha(Theme.foreground, 0.22) }
      GradientStop { position: 0.4; color: Theme.alpha(Theme.foreground, 0.08) }
      GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.5) }
    }
  }

  Gel {
    anchors.fill: parent
    opacity: root.checked ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
  }

  // A faint glow round the groove while on.
  Rectangle {
    anchors.fill: parent
    anchors.margins: -2
    radius: height / 2
    color: "transparent"
    border.width: 2
    border.color: Theme.alpha(Theme.accent, 0.18)
    opacity: root.checked ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
  }

  Item {
    id: knob
    y: 1
    x: root.checked ? root.width - width - 1 : 1
    width: root.height - 2
    height: width
    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    // Soft shadow under the knob.
    Rectangle {
      x: 0
      y: 1.5
      width: parent.width
      height: parent.height
      radius: width / 2
      color: Theme.alpha("#0b2540", 0.25)
    }
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      border.width: 1
      border.color: Theme.alpha("#0b2540", 0.28)
      gradient: Gradient {
        GradientStop { position: 0; color: "#ffffff" }
        GradientStop { position: 0.5; color: "#f3f8fc" }
        GradientStop { position: 1; color: "#cfdeeb" }
      }
    }
    // The glint.
    Rectangle {
      x: parent.width * 0.22
      y: parent.height * 0.12
      width: parent.width * 0.56
      height: parent.height * 0.36
      radius: height / 2
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.95) }
        GradientStop { position: 1; color: Theme.alpha("#ffffff", 0) }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
