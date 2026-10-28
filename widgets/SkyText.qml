import QtQuick
import qs.theme

// White text with a soft shadow, for lettering on the weather gadget's sky.
Text {
  color: "#ffffff"
  font.family: Theme.fontFamily
  style: Text.Raised
  styleColor: Theme.alpha("#000000", 0.35)
  elide: Text.ElideRight
}
