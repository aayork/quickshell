import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme
import qs.ui

// Now Playing, in a gadget frame: the cover with a mirror reflection under
// it, the track, and back / play / next with a gel play button.
Gadget {
  id: root

  implicitWidth: 172
  implicitHeight: 96
  visible: Media.hasMedia

  RowLayout {
    anchors.fill: parent
    anchors.margins: 9
    spacing: 9

    Item {
      Layout.preferredWidth: 54
      Layout.preferredHeight: 78
      Layout.alignment: Qt.AlignTop

      Image {
        id: cover
        width: 54
        height: 54
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 108
      }
      // Reflection: the bottom of the cover mirrored just under it, kept to
      // a short strip that fades out, like a cover standing on glass.
      Item {
        y: 56
        width: 54
        height: 22
        clip: true
        Image {
          width: 54
          height: 54
          source: Media.artUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: 108
          opacity: 0.4
          transform: Scale { yScale: -1; origin.y: 27 }
        }
        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha("#05090d", 0.25) }
            GradientStop { position: 1; color: Theme.alpha("#05090d", 1) }
          }
        }
      }
      // Click the cover to bring the player to the front.
      MouseArea {
        width: 54
        height: 54
        cursorShape: Media.player && Media.player.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (Media.player && Media.player.canRaise) Media.player.raise()
      }
      Rectangle {
        width: 54
        height: 54
        color: "transparent"
        border.width: 1
        border.color: Theme.alpha("#ffffff", 0.3)
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      spacing: 1

      Text {
        Layout.fillWidth: true
        text: Media.title
        color: "#ffffff"
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true
        text: Media.artist
        color: Theme.alpha("#ffffff", 0.7)
        font.family: Theme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
      }

      RowLayout {
        Layout.topMargin: 8
        spacing: 6

        GlyphButton { text: String.fromCodePoint(0xF04AE); onClicked: Media.previous() }
        Gel {
          implicitWidth: 28
          implicitHeight: 28
          Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Media.playing ? 0 : 1
            text: String.fromCodePoint(Media.playing ? 0xF03E4 : 0xF040A)
            color: "#ffffff"
            font.family: Theme.iconFamily
            font.pixelSize: 15
            style: Text.Raised
            styleColor: Theme.alpha("#000000", 0.3)
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Media.toggle()
          }
        }
        GlyphButton { text: String.fromCodePoint(0xF04AD); onClicked: Media.next() }
      }
    }
  }
}
