import QtQuick
import qs.services

// Text inside Jot's note: Antinote's font, and the note theme's ink,
// whatever the shell uses.
Label {
  color: JotStore.ink
  font.family: "GeistMono Nerd Font Mono"
}
