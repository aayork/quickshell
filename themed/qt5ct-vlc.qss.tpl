/* VLC (Qt5) styled like the shell: flat controls, soft hover, accent for
   what is active. Loaded by qt5ct for bin/vlc-themed only; written by
   theme-set-templates. VLC's own icons and its seek/volume sliders are
   drawn by VLC and keep their shapes; they take the palette colours. */

/* Buttons as in the shell (ui/TextButton.qml): the text colour at 4% over
   the background, a 1px border at 20%, 2px corners; 8% on hover, 16%
   pressed. VLC's icons are drawn in one colour, so an on toggle (repeat,
   shuffle) is shown by an accent border rather than the accent fill. */
QToolButton, QPushButton {
  background: {{ mix background foreground 4% }};
  border: 1px solid {{ mix background foreground 20% }};
  border-radius: 2px;
  padding: 3px;
}
QPushButton { padding: 4px 12px; }
QToolButton:hover, QPushButton:hover { background: {{ mix background foreground 8% }}; }
QToolButton:pressed, QPushButton:pressed { background: {{ mix background foreground 16% }}; }
QToolButton:checked { background: {{ mix background foreground 16% }}; border-color: {{ accent }}; }
QPushButton:default { border-color: {{ accent }}; }

/* VLC's button groups as one segmented control (vlc/preload.cpp sets the
   "segment" property): inner corners square, one divider between buttons. */
QToolButton[segment="first"] { border-top-right-radius: 0; border-bottom-right-radius: 0; border-right: none; }
QToolButton[segment="middle"] { border-radius: 0; border-right: none; }
QToolButton[segment="last"] { border-top-left-radius: 0; border-bottom-left-radius: 0; }
QToolButton[segment="first"], QToolButton[segment="middle"], QToolButton[segment="last"] { margin: 0; }

QMenuBar { background: {{ background }}; }
QMenuBar::item { padding: 4px 9px; border-radius: 6px; background: transparent; }
QMenuBar::item:selected { background: {{ lighter_background }}; }

QMenu {
  background: {{ dark_background }};
  border: 1px solid {{ lighter_background }};
  border-radius: 8px;
  padding: 5px;
}
QMenu::item { padding: 5px 24px 5px 10px; border-radius: 5px; }
QMenu::item:selected { background: {{ accent }}; color: {{ darker_background }}; }
QMenu::item:disabled { color: {{ muted }}; }
QMenu::separator { height: 1px; background: {{ lighter_background }}; margin: 5px 6px; }
QMenu::icon { padding-left: 6px; }

QToolTip {
  background: {{ dark_background }};
  color: {{ foreground }};
  border: 1px solid {{ lighter_background }};
  border-radius: 6px;
  padding: 4px 8px;
}

QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox {
  background: {{ dark_background }};
  border: 1px solid {{ lighter_background }};
  border-radius: 6px;
  padding: 3px 6px;
  selection-background-color: {{ accent }};
  selection-color: {{ darker_background }};
}
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus { border-color: {{ accent }}; }
QComboBox::drop-down { border: none; width: 18px; }
QComboBox QAbstractItemView {
  background: {{ dark_background }};
  border: 1px solid {{ lighter_background }};
  selection-background-color: {{ accent }};
  selection-color: {{ darker_background }};
}

/* Lists select with a soft tint and keep their text colour, like the
   shell's lists: VLC's sidebar draws its labels as separate widgets in the
   normal text colour, which a gold fill would wash out. */
QTreeView, QListView, QTableView {
  background: {{ dark_background }};
  alternate-background-color: {{ background }};
  border: none;
  selection-background-color: {{ mix dark_background foreground 16% }};
  selection-color: {{ foreground }};
}
QTreeView::item, QListView::item { padding: 2px 0; }
QTreeView::item:hover, QListView::item:hover { background: {{ mix dark_background foreground 8% }}; }
QTreeView::item:selected, QListView::item:selected {
  background: {{ mix dark_background foreground 16% }};
  color: {{ foreground }};
}
QHeaderView::section {
  background: {{ background }};
  color: {{ dark_foreground }};
  border: none;
  border-bottom: 1px solid {{ lighter_background }};
  padding: 4px 6px;
}

QTabBar::tab {
  background: transparent;
  color: {{ dark_foreground }};
  padding: 5px 12px;
  border-radius: 6px;
}
QTabBar::tab:hover { background: {{ lighter_background }}; }
QTabBar::tab:selected { background: {{ lighter_background }}; color: {{ foreground }}; }
QTabWidget::pane { border: 1px solid {{ lighter_background }}; border-radius: 8px; }

QGroupBox {
  border: 1px solid {{ lighter_background }};
  border-radius: 8px;
  margin-top: 12px;
  padding-top: 6px;
}
QGroupBox::title { subcontrol-origin: margin; left: 10px; color: {{ dark_foreground }}; }

QScrollBar:vertical { background: transparent; width: 10px; margin: 0; }
QScrollBar:horizontal { background: transparent; height: 10px; margin: 0; }
QScrollBar::handle { background: {{ mix lighter_background foreground 20% }}; border-radius: 4px; margin: 2px; }
QScrollBar::handle:hover { background: {{ mix lighter_background foreground 35% }}; }
QScrollBar::handle:vertical { min-height: 24px; }
QScrollBar::handle:horizontal { min-width: 24px; }
QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }
QScrollBar::add-page, QScrollBar::sub-page { background: transparent; }

/* Sliders like the shell's: a track in the button-border colour, the
   accent up to the value, a round handle in the text colour. VLC's seek bar
   and volume are plain QSliders thanks to vlc/plain-sliders. */
QSlider { min-height: 16px; }
QSlider::groove:horizontal { height: 4px; background: {{ mix background foreground 20% }}; border-radius: 2px; }
QSlider::sub-page:horizontal { background: {{ accent }}; border-radius: 2px; }
QSlider::add-page:horizontal { background: {{ mix background foreground 20% }}; border-radius: 2px; }
QSlider::handle:horizontal {
  background: {{ foreground }};
  width: 12px; height: 12px; margin: -4px 0; border-radius: 6px;
}
QSlider::handle:horizontal:hover { background: {{ bright_foreground }}; }
QSlider::sub-page:horizontal:disabled { background: {{ mix background foreground 20% }}; }
QSlider::handle:horizontal:disabled { background: {{ muted }}; }

QStatusBar { background: {{ background }}; color: {{ dark_foreground }}; }
QSplitter::handle { background: {{ lighter_background }}; }
