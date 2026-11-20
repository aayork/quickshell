/* Strawberry (music player), recoloured from the current theme.
   Generated into ~/.local/state/aayork-quickshell/current/theme/strawberry.qss
   by bin/theme-set-templates; bin/strawberry-themed loads it through qt6ct
   on Qt's Fusion style, with the palette from qt6ct-colors.conf.tpl.

   NEVER style plain `QWidget`, `*`, `QMainWindow` or `QDialog`: a property
   on a whole window (or every widget) makes Strawberry re-polish forever at
   startup (hangs at 100% CPU, found 2026-11-20). Window colours come from
   the palette; style named control types only, and test any change
   headless before shipping. */

QMainWindow::separator, QSplitter::handle {
  background-color: {{ dark_background }};
  width: 1px;
  height: 1px;
}

/* ---- menus and bars */
QMenuBar {
  background-color: {{ dark_background }};
  padding: 2px 4px;
}
QMenuBar::item { background: transparent; padding: 4px 10px; border-radius: 2px; }
QMenuBar::item:selected { background-color: {{ lighter_background }}; }

QMenu {
  background-color: {{ dark_background }};
  border: 1px solid {{ mix lighter_background foreground 15% }};
  padding: 4px;
}
QMenu::item { padding: 5px 24px 5px 22px; border-radius: 2px; }
QMenu::item:selected { background-color: {{ selection }}; color: {{ bright_foreground }}; }
QMenu::separator { height: 1px; background: {{ lighter_background }}; margin: 4px 6px; }
QMenu::icon { padding-left: 6px; }

QToolBar {
  background-color: {{ dark_background }};
  border: 0;
  padding: 4px;
  spacing: 4px;
}

QStatusBar {
  background-color: {{ dark_background }};
  color: {{ dark_foreground }};
}
QStatusBar::item { border: 0; }

QToolTip {
  background-color: {{ darker_background }};
  color: {{ foreground }};
  border: 1px solid {{ mix lighter_background foreground 15% }};
  padding: 4px 6px;
}

/* ---- buttons */
QPushButton {
  background-color: {{ lighter_background }};
  color: {{ foreground }};
  border: 1px solid {{ mix lighter_background foreground 12% }};
  border-radius: 2px;
  padding: 5px 14px;
}
QPushButton:hover { background-color: {{ mix lighter_background foreground 8% }}; }
QPushButton:pressed, QPushButton:checked { background-color: {{ selection }}; }
QPushButton:default { border-color: {{ accent }}; }

QToolButton {
  background: transparent;
  border: 1px solid transparent;
  border-radius: 2px;
  padding: 4px;
}
QToolButton:hover { background-color: {{ lighter_background }}; }
QToolButton:pressed, QToolButton:checked { background-color: {{ selection }}; }

/* ---- text fields, combos, spin boxes */
QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QDoubleSpinBox, QComboBox {
  background-color: {{ dark_background }};
  color: {{ foreground }};
  border: 1px solid {{ mix lighter_background foreground 12% }};
  border-radius: 2px;
  padding: 4px 6px;
  selection-background-color: {{ selection }};
  selection-color: {{ bright_foreground }};
}
/* The Context tab's title and lyrics are text boxes that Strawberry sizes
   to their text assuming no frame; a border or padding clips the last line. */
ResizableTextEdit, ResizableTextEdit:focus {
  background-color: transparent;
  border: 0;
  padding: 0;
}

QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus, QSpinBox:focus, QComboBox:focus {
  border-color: {{ accent }};
}
QComboBox::drop-down { border: 0; width: 18px; }
QComboBox QAbstractItemView {
  background-color: {{ dark_background }};
  border: 1px solid {{ mix lighter_background foreground 15% }};
  selection-background-color: {{ selection }};
}

/* ---- lists: collection tree, playlist, files */
QAbstractItemView {
  background-color: {{ background }};
  alternate-background-color: {{ mix background lighter_background 45% }};
  border: 0;
  selection-background-color: {{ selection }};
  selection-color: {{ bright_foreground }};
}

/* The collection tree: striped, airy rows so songs read apart. */
CollectionView {
  qproperty-alternatingRowColors: true;
  qproperty-indentation: 16;
}
CollectionView::item {
  padding: 4px 2px;
  border: 0;
}
CollectionView::item:hover { background-color: {{ mix background lighter_background 80% }}; }
CollectionView::item:selected {
  background-color: {{ selection }};
  color: {{ bright_foreground }};
}

/* Playlist and queue rows: a little air, and a flat accent-tinted
   selection instead of the stock block. (The glossy now-playing pill is
   switched off in strawberry.conf: [Playlist] show_bars/glow_effect.) */
PlaylistView::item, QueueView::item {
  padding: 3px 2px;
  border: 0;
}
/* Playlist: Strawberry fills a selected/playing row with the palette's
   Highlight (qt6ct-colors: the accent tint), draws the now-playing marker,
   then the cells. Clear cells keep that solid bar with the marker on top. */
PlaylistView::item:hover { background-color: rgba({{ foreground_rgb }}, 0.06); }
PlaylistView::item:selected {
  background-color: transparent;
  color: {{ bright_foreground }};
}
QueueView::item:hover { background-color: {{ mix background lighter_background 80% }}; }
QueueView::item:selected {
  background-color: {{ mix background accent 30% }};
  color: {{ bright_foreground }};
}

QHeaderView { background-color: {{ dark_background }}; }
QHeaderView::section {
  background-color: {{ dark_background }};
  color: {{ dark_foreground }};
  border: 0;
  border-right: 1px solid {{ background }};
  border-bottom: 1px solid {{ lighter_background }};
  padding: 5px 8px;
}
QHeaderView::section:hover { color: {{ foreground }}; }

QTableCornerButton::section { background-color: {{ dark_background }}; border: 0; }

/* ---- tabs (sidebar, playlist tabs, settings pages) */
QTabWidget::pane { border: 0; border-top: 1px solid {{ lighter_background }}; }
QTabBar { background-color: {{ dark_background }}; }
QTabBar::tab {
  background-color: {{ dark_background }};
  color: {{ dark_foreground }};
  padding: 6px 14px;
  border: 0;
  border-bottom: 2px solid transparent;
}
QTabBar::tab:hover { color: {{ foreground }}; }
QTabBar::tab:selected {
  background-color: {{ background }};
  color: {{ bright_foreground }};
  border-bottom-color: {{ accent }};
}

/* ---- sliders: seek bar and volume */
QSlider { background: transparent; }
QSlider::groove:horizontal {
  height: 4px;
  background-color: {{ lighter_background }};
  border-radius: 2px;
}
QSlider::sub-page:horizontal {
  background-color: {{ accent }};
  border-radius: 2px;
}
QSlider::handle:horizontal {
  background-color: {{ bright_foreground }};
  width: 10px;
  height: 10px;
  margin: -3px 0;
  border-radius: 5px;
}
QSlider::handle:horizontal:hover { background-color: {{ accent }}; }

QProgressBar {
  background-color: {{ lighter_background }};
  border: 0;
  border-radius: 2px;
  text-align: center;
  color: {{ foreground }};
  max-height: 14px;
}
QProgressBar::chunk { background-color: {{ accent }}; border-radius: 2px; }

/* ---- check boxes and radios */
QCheckBox, QRadioButton { background: transparent; spacing: 8px; }
QCheckBox::indicator, QRadioButton::indicator {
  width: 12px;
  height: 12px;
  background-color: {{ dark_background }};
  border: 1px solid {{ dark_foreground }};
}
QCheckBox::indicator { border-radius: 2px; }
QRadioButton::indicator { border-radius: 7px; }
QCheckBox::indicator:checked, QRadioButton::indicator:checked {
  background-color: {{ accent }};
  border-color: {{ accent }};
}

QGroupBox {
  border: 1px solid {{ lighter_background }};
  border-radius: 2px;
  margin-top: 14px;
  padding-top: 8px;
}
QGroupBox::title {
  subcontrol-origin: margin;
  left: 8px;
  padding: 0 4px;
  color: {{ dark_foreground }};
}

/* ---- scroll bars: thin, no arrows */
QScrollBar:vertical { background: transparent; width: 8px; margin: 0; }
QScrollBar:horizontal { background: transparent; height: 8px; margin: 0; }
QScrollBar::handle:vertical { background-color: {{ mix background foreground 22% }}; min-height: 30px; border-radius: 2px; margin: 1px; }
QScrollBar::handle:horizontal { background-color: {{ mix background foreground 22% }}; min-width: 30px; border-radius: 2px; margin: 1px; }
QScrollBar::handle:hover { background-color: {{ mix background foreground 40% }}; }
QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; border: 0; background: none; }
QScrollBar::add-page, QScrollBar::sub-page { background: none; }
