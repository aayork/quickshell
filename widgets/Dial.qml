import QtQuick
import qs.theme

// One dashboard dial for the meter gadget: a chrome rim, a black face with
// white ticks and numbers, a red needle and a small readout, Vista style.
Item {
  id: root

  property real value: 0        // 0..1
  property string label: ""
  property string readout: ""

  readonly property real sweep: 240
  readonly property real start: -120

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    border.width: 1
    border.color: Theme.alpha("#000000", 0.6)
    gradient: Gradient {
      GradientStop { position: 0; color: "#f4f6f8" }
      GradientStop { position: 0.5; color: "#8c959d" }
      GradientStop { position: 1; color: "#3d454c" }
    }
  }

  Rectangle {
    id: face
    anchors.fill: parent
    anchors.margins: Math.max(3, root.width * 0.05)
    radius: width / 2
    gradient: Gradient {
      GradientStop { position: 0; color: "#2b3239" }
      GradientStop { position: 1; color: "#06080a" }
    }

    // Ticks every 10 %, longer every 50 %.
    Repeater {
      model: 11
      Item {
        required property int index
        anchors.fill: parent
        rotation: root.start + root.sweep * index / 10
        Rectangle {
          x: (parent.width - width) / 2
          y: 3
          width: parent.index % 5 === 0 ? 2 : 1
          height: parent.index % 5 === 0 ? root.width * 0.09 : root.width * 0.05
          color: parent.index >= 8 ? "#ff5a4a" : "#e8eef3"
          antialiasing: true
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.28
      text: root.label
      color: "#9fd2ff"
      font.family: Theme.fontFamily
      font.pixelSize: Math.max(7, root.width * 0.12)
      font.bold: true
    }

    // Readout in a little lit window at the bottom.
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.7
      width: parent.width * 0.42
      height: Math.max(10, parent.height * 0.16)
      radius: 2
      color: "#0b1a10"
      border.width: 1
      border.color: Theme.alpha("#ffffff", 0.15)
      Text {
        anchors.centerIn: parent
        text: root.readout
        color: "#8cf08c"
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(7, root.width * 0.1)
      }
    }

    // Needle.
    Item {
      anchors.fill: parent
      rotation: root.start + root.sweep * Math.max(0, Math.min(1, root.value))
      Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
      Rectangle {
        x: (parent.width - width) / 2
        y: parent.height * 0.1
        width: 2
        height: parent.height * 0.48
        radius: 1
        color: "#ff3b2f"
        antialiasing: true
      }
    }
    Rectangle {
      anchors.centerIn: parent
      width: root.width * 0.12
      height: width
      radius: width / 2
      gradient: Gradient {
        GradientStop { position: 0; color: "#c8cdd2" }
        GradientStop { position: 1; color: "#4a5158" }
      }
    }

    // Glass glint.
    Rectangle {
      x: parent.width * 0.15
      y: 2
      width: parent.width * 0.7
      height: parent.height * 0.42
      radius: width / 2
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.3) }
        GradientStop { position: 1; color: Theme.alpha("#ffffff", 0) }
      }
    }
  }
}
