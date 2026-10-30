import QtQuick

// Slides a bar icon to its new place while icons are being rearranged
// (bar/Bar.qml's row sets `animate`). The icon being dragged follows the
// pointer without lag.
Behavior {
  readonly property var icon: targetProperty.object
  enabled: !!icon && !!icon.parent && icon.parent.animate === true && !icon.moving
  NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
}
