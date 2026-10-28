import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme
import qs.ui

// The Vista weather gadget: a glass sky panel that takes the colour of the
// weather (blue when clear, slate when cloudy or wet, navy at night) with the
// condition, temperature, today's high and low, and the next three days.
// Click for the full forecast in the clock dropdown.
Gadget {
  id: root

  implicitWidth: 172
  implicitHeight: content.implicitHeight + 20

  readonly property var current: Weather.ready ? Weather.forecast.current : null
  readonly property bool day: current !== null && current.is_day === 1
  readonly property int code: current !== null ? current.weather_code : 0
  // Overcast, fog, rain, snow and storms (WMO codes 3 and up).
  readonly property bool grey: code >= 3
  readonly property var today: Weather.days.length > 0 ? Weather.days[0] : null
  readonly property var ahead: Weather.days.slice(1, 4)

  readonly property color skyTop: !day ? "#1d3466" : grey ? "#8ea4b8" : "#5fb6f2"
  readonly property color skyBottom: !day ? "#0a1530" : grey ? "#3f5468" : "#1e6fc0"

  // The weather service only fetches when asked (the clock popup asks when
  // it opens), so the gadget asks too, and again every half hour.
  Component.onCompleted: Weather.refresh()
  Timer {
    interval: 30 * 60 * 1000
    running: true
    repeat: true
    onTriggered: Weather.refresh()
  }

  // The sky.
  Rectangle {
    anchors.fill: parent
    anchors.margins: 3
    radius: root.radius - 2
    gradient: Gradient {
      GradientStop { position: 0; color: root.skyTop }
      GradientStop { position: 1; color: root.skyBottom }
    }
    Behavior on opacity { NumberAnimation { duration: 300 } }
    Rectangle {
      width: parent.width
      height: parent.height * 0.4
      radius: parent.radius
      gradient: Gradient {
        GradientStop { position: 0; color: Theme.alpha("#ffffff", 0.32) }
        GradientStop { position: 1; color: Theme.alpha("#ffffff", 0.02) }
      }
    }
  }

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 10
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      SkyText {
        text: Weather.ready ? Weather.icon : ""
        color: root.day && !root.grey ? "#ffe680" : "#eef3fa"
        font.family: Theme.iconFamily
        font.pixelSize: 36
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: -2
        SkyText {
          text: Weather.ready ? Weather.temperature : Weather.failed ? "--" : "…"
          font.pixelSize: 28
          font.weight: Font.Light
        }
        SkyText {
          Layout.fillWidth: true
          text: Weather.ready ? Weather.condition : Weather.failed ? "Unavailable" : "Checking…"
          font.pixelSize: 11
          font.bold: true
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      SkyText {
        Layout.fillWidth: true
        text: Weather.placeName
        color: Theme.alpha("#ffffff", 0.85)
        font.pixelSize: 11
      }
      SkyText {
        visible: root.today !== null
        text: root.today ? "H " + root.today.high + "  L " + root.today.low : ""
        color: Theme.alpha("#ffffff", 0.9)
        font.pixelSize: 11
        elide: Text.ElideNone
      }
    }

    // The next three days on a darker strip of glass.
    Rectangle {
      visible: root.ahead.length > 0
      Layout.fillWidth: true
      Layout.topMargin: 4
      implicitHeight: days.implicitHeight + 8
      radius: 4
      color: Theme.alpha("#000000", 0.22)
      border.width: 1
      border.color: Theme.alpha("#ffffff", 0.12)

      Row {
        id: days
        anchors.centerIn: parent
        width: parent.width - 8

        Repeater {
          model: root.ahead
          Column {
            required property var modelData
            width: days.width / Math.max(1, root.ahead.length)
            spacing: 1
            SkyText {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.day
              color: Theme.alpha("#ffffff", 0.8)
              font.pixelSize: 10
            }
            SkyText {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.icon
              font.family: Theme.iconFamily
              font.pixelSize: 15
            }
            SkyText {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.high + " / " + modelData.low
              color: Theme.alpha("#ffffff", 0.85)
              font.pixelSize: 10
            }
          }
        }
      }
    }
  }

  // Click for the full forecast, in the clock dropdown.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: PopupState.request("clock")
  }
}
