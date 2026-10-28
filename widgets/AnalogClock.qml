import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.theme
import qs.ui

// A wall clock in the Vista gadget spirit, built like an object: a polished
// chrome case with a bevel, a cream dial sunk under it with a shadow along
// its top edge, numerals, tapered hands that cast a shadow, a red sweep
// second hand on a jewelled cap, and a domed glass front catching the light.
// Click for the calendar in the clock dropdown.
Item {
  id: root

  implicitWidth: 156
  implicitHeight: 156

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  readonly property real hours: clock.hours % 12 + clock.minutes / 60
  readonly property real minutes: clock.minutes + clock.seconds / 60
  readonly property real size: Math.min(width, height)

  // Shadow the whole clock casts on the desktop.
  Rectangle {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: 5
    width: root.size - 8
    height: width
    radius: width / 2
    color: Theme.alpha("#000000", 0.5)
    layer.enabled: true
    layer.effect: MultiEffect { blurEnabled: true; blur: 0.6; blurMax: 24 }
  }

  // The case: polished chrome, light from above.
  Rectangle {
    id: caseRing
    anchors.centerIn: parent
    width: root.size - 6
    height: width
    radius: width / 2
    border.width: 1
    border.color: "#2a3036"
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#ffffff" }
      GradientStop { position: 0.18; color: "#d9dee3" }
      GradientStop { position: 0.48; color: "#7d868f" }
      GradientStop { position: 0.52; color: "#a9b1b8" }
      GradientStop { position: 0.85; color: "#4f5861" }
      GradientStop { position: 1.0; color: "#8c959d" }
    }
  }

  // The bevel: a ring lit from below, so the case reads as rounded metal.
  Rectangle {
    id: bevel
    anchors.centerIn: parent
    width: caseRing.width - 10
    height: width
    radius: width / 2
    gradient: Gradient {
      GradientStop { position: 0; color: "#3c444b" }
      GradientStop { position: 1; color: "#f2f4f6" }
    }
  }

  // The dial, sunk inside the bevel.
  Rectangle {
    id: dial
    anchors.centerIn: parent
    width: bevel.width - 6
    height: width
    radius: width / 2
    gradient: Gradient {
      GradientStop { position: 0; color: "#fbf8ef" }
      GradientStop { position: 0.6; color: "#f3efe4" }
      GradientStop { position: 1; color: "#ddd7c8" }
    }

    // Shadow the case throws onto the top of the dial.
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.alpha("#000000", 0.28) }
        GradientStop { position: 0.12; color: Theme.alpha("#000000", 0.0) }
      }
    }

    // Minute track and hour batons.
    Repeater {
      model: 60
      Item {
        required property int index
        anchors.fill: parent
        rotation: index * 6
        Rectangle {
          readonly property bool hour: parent.index % 5 === 0
          x: (parent.width - width) / 2
          y: 5
          width: hour ? 2.6 : 1
          height: hour ? 8 : 3.5
          radius: 0.5
          color: hour ? "#23282d" : "#7d7a70"
          antialiasing: true
        }
      }
    }

    // Numerals.
    Repeater {
      model: 12
      Item {
        required property int index
        readonly property real angle: (index + 1) * 30 * Math.PI / 180
        readonly property real r: dial.width / 2 - 22
        x: dial.width / 2 + Math.sin(angle) * r - width / 2
        y: dial.height / 2 - Math.cos(angle) * r - height / 2
        width: 20
        height: 16
        Text {
          anchors.centerIn: parent
          text: String(parent.index + 1)
          color: "#2a2f34"
          font.family: "serif"
          font.pixelSize: (parent.index + 1) % 3 === 0 ? 14 : 11
          font.bold: (parent.index + 1) % 3 === 0
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.62
      text: "AERO"
      color: "#8a8579"
      font.family: Theme.fontFamily
      font.pixelSize: 7
      font.letterSpacing: 2
    }

    // Hands, drawn tapered, casting a shadow onto the dial.
    Item {
      id: hands
      anchors.fill: parent
      visible: false

      ClockHand { angle: root.hours * 30; length: 0.5; base: 7 }
      ClockHand { angle: root.minutes * 6; length: 0.76; base: 5 }

      // Sweep second hand with a counterweight.
      Item {
        anchors.fill: parent
        rotation: clock.seconds * 6
        Behavior on rotation {
          RotationAnimation { duration: 180; direction: RotationAnimation.Clockwise; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
        Rectangle {
          x: (parent.width - width) / 2
          y: parent.height / 2 - parent.height * 0.42
          width: 1.4
          height: parent.height * 0.54
          color: "#c8201e"
          antialiasing: true
        }
        Rectangle {
          x: (parent.width - width) / 2
          y: parent.height / 2 + parent.height * 0.08
          width: 5
          height: 9
          radius: 2.5
          color: "#c8201e"
        }
      }
    }

    MultiEffect {
      anchors.fill: hands
      source: hands
      shadowEnabled: true
      shadowColor: Theme.alpha("#000000", 0.45)
      shadowBlur: 0.3
      shadowHorizontalOffset: 1.5
      shadowVerticalOffset: 2.5
    }

    // Jewelled centre cap.
    Rectangle {
      anchors.centerIn: parent
      width: 9
      height: 9
      radius: 4.5
      border.width: 1
      border.color: "#5c0d0c"
      gradient: Gradient {
        GradientStop { position: 0; color: "#ff8a80" }
        GradientStop { position: 1; color: "#9e1512" }
      }
      Rectangle { x: 2; y: 1.5; width: 3; height: 2; radius: 1; color: Theme.alpha("#ffffff", 0.8) }
    }
  }

  // Domed glass: a broad reflection over the top and a thin bright crescent
  // along the lower rim where the dome curves away. Both are clipped to the
  // dial's circle so they meet the rim exactly, with no gap.
  Item {
    anchors.fill: dial
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: domeMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }
    Rectangle {
      x: -parent.width * 0.1
      y: -parent.height * 0.32
      width: parent.width * 1.2
      height: parent.height * 0.8
      radius: height / 2
      gradient: Gradient {
        GradientStop { position: 0.4; color: Theme.alpha("#ffffff", 0.6) }
        GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.0) }
      }
    }
    Rectangle {
      x: parent.width * 0.1
      y: parent.height * 0.82
      width: parent.width * 0.8
      height: parent.height * 0.3
      radius: height / 2
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.0) }
        GradientStop { position: 0.6; color: Theme.alpha("#ffffff", 0.3) }
      }
    }
  }
  Item {
    id: domeMask
    anchors.fill: dial
    visible: false
    layer.enabled: true
    Rectangle { anchors.fill: parent; radius: width / 2 }
  }

  MouseArea {
    anchors.centerIn: parent
    width: caseRing.width
    height: caseRing.height
    cursorShape: Qt.PointingHandCursor
    onClicked: PopupState.request("clock")
  }
}
