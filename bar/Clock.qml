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
  readonly property string format: Config.clock.format
  // Other places worth knowing the time in, from the config file.
  readonly property var zones: Config.clock.zones || []
  // Adding a time zone: the search box is open, and what it has found.
  property bool addingZone: false
  property var allZones: []
  // Day whose events are listed; today unless another is clicked.
  property date selectedDay: new Date()
  // The new-event form is open.
  property bool addingEvent: false
  // Calendar the next new event goes to.
  property string eventCalendar: ""
  // uid of the event waiting for a second click to delete.
  property string deleting: ""
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
        date: day,
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

  function addZone(zone) {
    var label = zone.replace(/^.*\//, "").replace(/_/g, " ")
    if (zones.some(z => z.zone === zone)) return
    Config.clock.zones = zones.concat([{ zone: zone, label: label }])
    addingZone = false
  }

  function removeZone(zone) {
    Config.clock.zones = zones.filter(z => z.zone !== zone)
  }

  onZonesChanged: if (popup.open) offsets.running = true

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
    command: ["sh", "-c", root.zones.map(z => "printf '%s|%s\\n' \"$1\" \"$(TZ=\"$2\" date +%z)\"; shift 2").concat(["true"]).join("; "), "sh"]
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

  // Every zone name the system knows, for the add box.
  Process {
    id: zoneList
    command: ["timedatectl", "list-timezones", "--no-pager"]
    stdout: StdioCollector {
      onStreamFinished: root.allZones = text.split("\n").filter(l => l !== "")
    }
  }

  Popup {
    id: popup
    anchorItem: root
    contentWidth: 340
    contentHeight: column.implicitHeight

    onOpenChanged: {
      root.addingZone = false
      root.addingEvent = false
      root.deleting = ""
      if (!open) return
      root.monthOffset = 0
      root.selectedDay = new Date()
      offsets.running = true
      Weather.refresh()
      Calendar.refresh()
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
          id: zoneRow
          required property var modelData
          Layout.fillWidth: true
          Layout.topMargin: -6

          HoverHandler { id: zoneHover }

          Label { text: zoneRow.modelData.label; color: Theme.dim; Layout.fillWidth: true }
          Label {
            text: zoneHover.hovered ? "Remove" : root.zoneTime(zoneRow.modelData.label)
            color: zoneHover.hovered && removeMouse.containsMouse ? Theme.red : Theme.dim
            elide: Text.ElideNone
            MouseArea {
              id: removeMouse
              anchors.fill: parent
              anchors.margins: -4
              hoverEnabled: true
              onClicked: root.removeZone(zoneRow.modelData.zone)
            }
          }
        }
      }

      Label {
        visible: !root.addingZone
        Layout.topMargin: -6
        text: "+ Add a time zone"
        color: addZoneMouse.containsMouse ? Theme.foreground : Theme.muted
        font.pixelSize: Theme.fontSmall
        MouseArea {
          id: addZoneMouse
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          onClicked: {
            if (root.allZones.length === 0) zoneList.running = true
            root.addingZone = true
            zoneFilter.text = ""
            zoneFilter.focusInput()
          }
        }
      }

      ColumnLayout {
        visible: root.addingZone
        Layout.fillWidth: true
        spacing: 2

        readonly property var matches: {
          var needle = zoneFilter.text.trim().toLowerCase().replace(/ /g, "_")
          if (needle.length < 2) return []
          return root.allZones.filter(z => z.toLowerCase().indexOf(needle) !== -1).slice(0, 6)
        }

        Field {
          id: zoneFilter
          Layout.fillWidth: true
          placeholder: "City, like Tokyo or London"
          onAccepted: if (parent.matches.length > 0) root.addZone(parent.matches[0])
          onCancelled: root.addingZone = false
        }

        Repeater {
          model: parent.matches

          Rectangle {
            required property string modelData
            Layout.fillWidth: true
            implicitHeight: Theme.rowHeight - 4
            radius: Theme.controlRadius
            color: matchMouse.containsMouse ? Theme.hover : "transparent"

            Label {
              anchors.fill: parent
              anchors.leftMargin: 8
              text: parent.modelData.replace(/_/g, " ")
            }
            MouseArea {
              id: matchMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.addZone(parent.modelData)
            }
          }
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
            id: cell
            required property var modelData

            readonly property bool selected: modelData.date.toDateString() === root.selectedDay.toDateString()

            Layout.fillWidth: true
            Layout.preferredHeight: 28

            Rectangle {
              anchors.centerIn: parent
              width: 26
              height: 24
              radius: Theme.controlRadius
              color: cell.modelData.today ? Theme.accent : cellMouse.containsMouse ? Theme.hover : "transparent"
              border.width: cell.selected && !cell.modelData.today ? 1 : 0
              border.color: Theme.accent
            }

            Label {
              anchors.centerIn: parent
              text: cell.modelData.number
              color: cell.modelData.today ? Theme.background : cell.modelData.inMonth ? Theme.foreground : Theme.muted
              font.bold: cell.modelData.today
            }

            // Something is on that day.
            Rectangle {
              visible: Calendar.hasEvents(cell.modelData.date)
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 2
              width: 3
              height: 3
              radius: 2
              color: cell.modelData.today ? Theme.background : Theme.accent
            }

            MouseArea {
              id: cellMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.selectedDay = cell.modelData.date
            }
          }
        }
      }

      // The selected day's events.
      ColumnLayout {
        visible: Calendar.connected
        Layout.fillWidth: true
        spacing: 2

        readonly property var dayEvents: Calendar.eventsOn(root.selectedDay)

        SectionHeader {
          text: (root.selectedDay.toDateString() === root.now.toDateString() ? "TODAY" : Qt.formatDate(root.selectedDay, "dddd, MMM d").toUpperCase())
        }

        Label {
          visible: parent.dayEvents.length === 0
          text: "Nothing scheduled"
          color: Theme.dim
        }

        Repeater {
          model: parent.dayEvents

          RowLayout {
            id: eventRow
            required property var modelData

            readonly property bool deleting: root.deleting === modelData.uid

            Layout.fillWidth: true
            spacing: 8

            HoverHandler { id: eventHover }

            Rectangle {
              implicitWidth: 3
              implicitHeight: 16
              radius: 2
              color: eventRow.modelData.color || Theme.accent
            }
            Label { text: eventRow.modelData.title; Layout.fillWidth: true }
            // The time, or on hover the way to delete it (two clicks).
            Label {
              readonly property bool offer: eventHover.hovered && Calendar.canDelete(eventRow.modelData)
              text: eventRow.deleting ? "Click again to delete" : offer ? "Delete" : Calendar.timeText(eventRow.modelData)
              color: eventRow.deleting || (offer && deleteMouse.containsMouse) ? Theme.red : Theme.dim
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
              MouseArea {
                id: deleteMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                enabled: parent.offer || eventRow.deleting
                onClicked: {
                  if (!eventRow.deleting) {
                    root.deleting = eventRow.modelData.uid
                    return
                  }
                  root.deleting = ""
                  Calendar.deleteEvent(eventRow.modelData)
                }
              }
            }
          }
        }

        Label {
          visible: !root.addingEvent && Calendar.writable.length > 0
          text: Calendar.busy && Calendar.status !== "" ? Calendar.status : "+ New event"
          color: newEventMouse.containsMouse ? Theme.foreground : Theme.muted
          font.pixelSize: Theme.fontSmall
          MouseArea {
            id: newEventMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            enabled: !Calendar.busy
            onClicked: {
              if (!Calendar.writable.some(c => c.url === root.eventCalendar)) root.eventCalendar = Calendar.writable[0].url
              root.addingEvent = true
              eventTitle.text = ""
              eventTime.text = ""
              eventTitle.focusInput()
            }
          }
        }

        Label {
          visible: !root.addingEvent && !Calendar.busy && Calendar.status !== ""
          text: Calendar.status
          color: Theme.red
          font.pixelSize: Theme.fontSmall
          wrapMode: Text.Wrap
          elide: Text.ElideNone
          Layout.fillWidth: true
        }

        // New event on the selected day: a title, an optional time, a calendar.
        ColumnLayout {
          id: eventForm
          visible: root.addingEvent
          Layout.fillWidth: true
          Layout.topMargin: 4
          spacing: 6

          readonly property var times: Calendar.parseTimes(eventTime.text)
          readonly property bool valid: eventTitle.text.trim() !== "" && times !== undefined

          function submit() {
            if (!valid) return
            var calendar = Calendar.writable.find(c => c.url === root.eventCalendar) ?? Calendar.writable[0]
            Calendar.createEvent(calendar, root.selectedDay, eventTitle.text.trim(), times)
            root.addingEvent = false
          }

          Field {
            id: eventTitle
            Layout.fillWidth: true
            placeholder: "Event title"
            onAccepted: eventTime.focusInput()
            onCancelled: root.addingEvent = false
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Field {
              id: eventTime
              Layout.fillWidth: true
              placeholder: "Time, like 3pm or 9-10:30am. Empty for all day"
              border.color: eventForm.times === undefined ? Theme.red : Theme.alpha(Theme.foreground, 0.25)
              onAccepted: eventForm.submit()
              onCancelled: root.addingEvent = false
            }
            TextButton {
              text: "Add"
              enabled: eventForm.valid
              onClicked: eventForm.submit()
            }
          }

          Select {
            Layout.fillWidth: true
            visible: Calendar.writable.length > 1
            options: Calendar.writable.map(c => ({ label: c.name, value: c.url }))
            current: root.eventCalendar
            onPicked: function(value) { root.eventCalendar = value }
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

      // The week: each day gets an equal share of the width, set outright
      // so the columns cannot crowd each other.
      Row {
        id: week
        visible: Weather.ready
        Layout.fillWidth: true
        Layout.topMargin: 6

        Repeater {
          model: Weather.days

          Column {
            required property var modelData
            required property int index
            width: week.width / Math.max(1, Weather.days.length)
            spacing: 5

            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              text: index === 0 ? "Today" : modelData.day
              color: index === 0 ? Theme.foreground : Theme.dim
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
            }
            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.icon
              font.pixelSize: Theme.iconLarge
              elide: Text.ElideNone
            }
            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.high
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
            }
            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.low
              color: Theme.dim
              font.pixelSize: Theme.fontSmall
              elide: Text.ElideNone
            }
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
