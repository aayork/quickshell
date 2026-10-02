import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.ui

// The clock, and behind it the day at a glance: a calendar, the weather, and
// the notifications that came in.
BarButton {
  id: root

  readonly property alias popup: popup

  // Fri Oct 2 9:45 AM
  property string format: "ddd MMM d h:mm AP"
  // Other places worth knowing the time in.
  property var zones: [{ zone: "Asia/Seoul", label: "Seoul" }]
  // label -> minutes ahead of UTC, filled in when the popup opens.
  property var zoneOffsets: ({})
  // Months away from the current one the calendar is showing.
  property int monthOffset: 0

  readonly property date now: clock.date
  readonly property date shownMonth: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
  // Six weeks of days covering the shown month.
  readonly property var cells: {
    var first = shownMonth
    var lead = (first.getDay() - Qt.locale().firstDayOfWeek + 7) % 7
    var list = []
    for (var i = 0; i < 42; i++) {
      var day = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i)
      list.push({
        number: day.getDate(),
        inMonth: day.getMonth() === first.getMonth(),
        today: day.toDateString() === now.toDateString()
      })
    }
    // Drop a trailing week that belongs wholly to next month.
    return list[35].inMonth ? list : list.slice(0, 35)
  }
  readonly property var weekdays: {
    var names = []
    for (var i = 0; i < 7; i++) names.push(Qt.locale().dayName((Qt.locale().firstDayOfWeek + i) % 7, Locale.NarrowFormat))
    return names
  }

  function zoneTime(label) {
    var offset = zoneOffsets[label]
    if (offset === undefined) return ""
    var there = new Date(now.getTime() + (offset + now.getTimezoneOffset()) * 60000)
    var days = Math.round((new Date(there.getFullYear(), there.getMonth(), there.getDate())
      - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000)
    return Qt.formatTime(there, "h:mm AP") + (days > 0 ? " tomorrow" : days < 0 ? " yesterday" : "")
  }

  function ago(time) {
    var minutes = Math.floor((now.getTime() - time) / 60000)
    if (minutes < 1) return "now"
    if (minutes < 60) return minutes + "m"
    if (minutes < 1440) return Math.floor(minutes / 60) + "h"
    return Math.floor(minutes / 1440) + "d"
  }

  text: Qt.formatDateTime(now, format)
  fontSize: Theme.fontSize
  active: popup.open
  onClicked: popup.toggle()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // `date` knows every zone's current offset, daylight saving included.
  Process {
    id: offsets
    command: ["sh", "-c", root.zones.map(z => "printf '%s|%s\\n' \"$1\" \"$(TZ=\"$2\" date +%z)\"; shift 2").join("; "), "sh"]
      .concat(root.zones.reduce((all, z) => all.concat([z.label, z.zone]), []))
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = {}
        var lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          var match = lines[i].match(/^(.*)\|([+-])(\d\d)(\d\d)$/)
          if (match) parsed[match[1]] = (match[2] === "-" ? -1 : 1) * (Number(match[3]) * 60 + Number(match[4]))
        }
        root.zoneOffsets = parsed
      }
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 320
    contentHeight: column.implicitHeight

    onOpenChanged: {
      if (!open) return
      root.monthOffset = 0
      offsets.running = true
      Weather.refresh()
    }

    ColumnLayout {
      id: column
      width: parent.width
      spacing: 10

      RowLayout {
        Layout.fillWidth: true
        Label {
          text: Qt.formatDate(root.now, "dddd, MMMM d")
          font.bold: true
          font.pixelSize: Theme.fontLarge
          Layout.fillWidth: true
        }
      }

      Repeater {
        model: root.zones

        RowLayout {
          required property var modelData
          Layout.fillWidth: true
          Layout.topMargin: -6
          Label { text: modelData.label; color: Theme.dim; Layout.fillWidth: true }
          Label { text: root.zoneTime(modelData.label); color: Theme.dim; elide: Text.ElideNone }
        }
      }

      Separator { Layout.fillWidth: true }

      RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Label {
          text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
          Layout.fillWidth: true
          MouseArea {
            anchors.fill: parent
            onClicked: root.monthOffset = 0
          }
        }
        IconButton { icon: Icons.chevronLeft; onClicked: root.monthOffset -= 1 }
        IconButton { icon: Icons.chevronRight; onClicked: root.monthOffset += 1 }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
          model: root.weekdays

          Label {
            required property string modelData
            text: modelData
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            Layout.preferredHeight: 22
          }
        }

        Repeater {
          model: root.cells

          Item {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 26

            Rectangle {
              anchors.centerIn: parent
              width: 24
              height: 22
              radius: Theme.controlRadius
              color: modelData.today ? Theme.accent : "transparent"
            }

            Label {
              anchors.centerIn: parent
              text: modelData.number
              color: modelData.today ? Theme.background : modelData.inMonth ? Theme.foreground : Theme.muted
              font.bold: modelData.today
            }
          }
        }
      }

      Separator { Layout.fillWidth: true }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Label {
          visible: Weather.ready
          text: Weather.icon
          font.pixelSize: 26
          color: Theme.accent
          elide: Text.ElideNone
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Label {
            text: Weather.ready ? Weather.temperature + "  " + Weather.condition
              : Weather.failed ? "Weather unavailable" : "Checking the weather…"
            color: Weather.ready ? Theme.foreground : Theme.dim
            Layout.fillWidth: true
          }
          Label {
            visible: Weather.ready
            text: Weather.placeName
            color: Theme.dim
            font.pixelSize: Theme.fontSmall
            Layout.fillWidth: true
          }
        }
      }

      RowLayout {
        visible: Weather.ready
        Layout.fillWidth: true
        spacing: 0
        uniformCellSizes: true

        Repeater {
          model: Weather.days

          ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 2

            Label { text: modelData.day; color: Theme.dim; font.pixelSize: Theme.fontSmall; Layout.alignment: Qt.AlignHCenter }
            Label { text: modelData.icon; font.pixelSize: Theme.iconLarge; Layout.alignment: Qt.AlignHCenter; elide: Text.ElideNone }
            Label { text: modelData.high + " " + modelData.low; font.pixelSize: Theme.fontSmall; Layout.alignment: Qt.AlignHCenter }
          }
        }
      }

      Separator { Layout.fillWidth: true }

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing

        SectionHeader { text: "NOTIFICATIONS"; Layout.fillWidth: true }
        Label {
          text: Notifs.dnd ? "Silenced" : "Silence"
          color: Notifs.dnd ? Theme.accent : dndMouse.containsMouse ? Theme.foreground : Theme.dim
          font.pixelSize: Theme.fontSmall
          MouseArea {
            id: dndMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: Notifs.dnd = !Notifs.dnd
          }
        }
        Label {
          visible: Notifs.history.length > 0
          text: "Clear"
          color: clearMouse.containsMouse ? Theme.foreground : Theme.dim
          font.pixelSize: Theme.fontSmall
          MouseArea {
            id: clearMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: Notifs.clearHistory()
          }
        }
      }

      Label {
        visible: Notifs.history.length === 0
        text: "Nothing new"
        color: Theme.dim
      }

      Flickable {
        id: list
        visible: Notifs.history.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.min(entries.implicitHeight, 220)
        contentHeight: entries.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: entries
          width: list.width
          spacing: 2

          Repeater {
            model: Notifs.history

            Rectangle {
              id: entry
              required property var modelData

              Layout.fillWidth: true
              implicitHeight: text.implicitHeight + 10
              radius: Theme.controlRadius
              color: entryHover.hovered ? Theme.hover : "transparent"

              HoverHandler { id: entryHover }

              ColumnLayout {
                id: text
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 0

                RowLayout {
                  Layout.fillWidth: true
                  Label { text: entry.modelData.summary; Layout.fillWidth: true }
                  Label {
                    text: entryHover.hovered ? Icons.close : root.ago(entry.modelData.time)
                    color: Theme.dim
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideNone
                    MouseArea {
                      anchors.fill: parent
                      anchors.margins: -6
                      onClicked: Notifs.removeEntry(entry.modelData.id)
                    }
                  }
                }
                Label {
                  visible: text !== ""
                  text: [entry.modelData.app, entry.modelData.body.split("\n")[0]].filter(s => s !== "").join(" · ")
                  color: Theme.dim
                  font.pixelSize: Theme.fontSmall
                  Layout.fillWidth: true
                }
              }
            }
          }
        }
      }
    }
  }
}
