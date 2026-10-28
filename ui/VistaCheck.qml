import QtQuick
import qs.theme

// A Vista check box: a small glossy well, blue edged under the pointer.
Rectangle {
  id: root

  property bool hovered: false
  property bool checked: false

  implicitWidth: 14
  implicitHeight: 14
  radius: 2
  border.width: 1
  border.color: hovered ? "#3c7fb1" : "#8e8f8f"
  gradient: Gradient {
    GradientStop { position: 0; color: root.hovered ? "#dff2fc" : "#e6e6e6" }
    GradientStop { position: 1; color: root.hovered ? "#bfe4f8" : "#ffffff" }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: 2
    radius: 1
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha("#000000", 0.08)
  }

  Text {
    anchors.centerIn: parent
    visible: root.checked || root.hovered
    text: String.fromCodePoint(0xF012C)
    color: root.checked ? "#1f6fb2" : Theme.alpha("#1f6fb2", 0.6)
    font.family: Theme.iconFamily
    font.pixelSize: 11
  }
}
