import QtQuick
import qs.services
import qs.theme

// Text inside Jot's note: the shell's font, in the note's ink.
Label {
  color: JotStore.ink
  font.family: Theme.fontFamily
}
