/* Ghostty's GTK/libadwaita chrome, recoloured from the current theme.
   Generated into ~/.local/state/aayork-quickshell/current/theme/ghostty-gtk.css by
   bin/theme-set-templates; loaded via ghostty's gtk-custom-css. */

:root {
  --accent-color: {{ accent }};
  --accent-bg-color: {{ accent }};
  --accent-fg-color: {{ background }};

  --window-bg-color: {{ background }};
  --window-fg-color: {{ foreground }};
  --view-bg-color: {{ background }};
  --view-fg-color: {{ foreground }};

  --headerbar-bg-color: {{ dark_background }};
  --headerbar-fg-color: {{ foreground }};
  --headerbar-backdrop-color: {{ dark_background }};
  --headerbar-shade-color: {{ darker_background }};

  --popover-bg-color: {{ dark_background }};
  --popover-fg-color: {{ foreground }};
  --dialog-bg-color: {{ dark_background }};
  --dialog-fg-color: {{ foreground }};
  --card-bg-color: {{ lighter_background }};
  --card-fg-color: {{ foreground }};

  --destructive-color: {{ red }};
  --destructive-bg-color: {{ red }};
  --destructive-fg-color: {{ background }};
  --success-color: {{ green }};
  --warning-color: {{ yellow }};
  --error-color: {{ red }};

  --border-color: {{ mix lighter_background foreground 15% }};
  --window-radius: 0;
}

/* Right-click menu */
popover > contents {
  background-color: {{ dark_background }};
  color: {{ foreground }};
  border: 1px solid {{ lighter_background }};
  border-radius: 0;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.35);
}
popover > arrow { background-color: {{ dark_background }}; border-color: {{ lighter_background }}; }
popover modelbutton { border-radius: 0; }
popover modelbutton:hover,
popover modelbutton:selected { background-color: {{ selection }}; color: {{ bright_foreground }}; }
popover separator { background-color: {{ lighter_background }}; }
popover label.accelerator { color: {{ dark_foreground }}; }

/* Tab bar: flat, square, compact tabs with borders between them, like a
   terminal multiplexer. Hyprland's rounding is 0, so nothing here is rounded.
   libadwaita rounds and pads tabboxchild (the tab's wrapper), not just tab. */
tabbar .box {
  background-color: {{ darker_background }};
  box-shadow: inset 0 -1px {{ lighter_background }};
  padding: 0;
}
tabbar tabbox,
toolbarview > .top-bar .collapse-spacing tabbar tabbox,
toolbarview > .bottom-bar .collapse-spacing tabbar tabbox {
  padding: 0;
  min-height: 30px; /* whole bar is 30px tall */
}
tabbar tabbox > tabboxchild { border-radius: 0; outline-offset: -1px; }
tabbar tabbox > separator,
tabbar tabbox > separator.hidden {
  margin: 0;
  min-width: 1px;
  opacity: 1;
  background-color: {{ lighter_background }};
}
tabbar tab,
tabbar tabbox.single-tab tab {
  min-height: 30px;
  padding: 0 6px;
  border-radius: 0;
  background: none;
  box-shadow: none;
  color: {{ dark_foreground }};
  transition: none;
}
tabbar tab:hover,
tabbar tab:active { background-color: {{ dark_background }}; color: {{ foreground }}; }
tabbar tab:selected,
tabbar tab:selected:hover,
tabbar tab:selected:active,
tabbar tabbox.single-tab tab {
  background-color: {{ background }};
  color: {{ bright_foreground }};
  box-shadow: inset 0 2px {{ accent }};
}
tabbar tab label { font-size: 0.85em; }
tabbar tab button.image-button {
  min-width: 16px;
  min-height: 16px;
  padding: 0;
  margin: 0;
  border-radius: 0;
  background: none;
  box-shadow: none;
  color: inherit;
  opacity: 0.5;
}
tabbar tab button.image-button:hover { opacity: 1; background-color: {{ lighter_background }}; }
tabbar tab button.image-button image { -gtk-icon-size: 12px; }
tabbar tab indicator, tabbar tabbox > revealer > indicator { border-radius: 0; background: {{ accent }}; }
tabbar .start-action, tabbar .end-action { padding: 0; }
tabbar .start-action button, tabbar .end-action button {
  border-radius: 0;
  margin: 0;
  min-height: 0;
  background: none;
  box-shadow: none;
  color: {{ dark_foreground }};
}
tabbar .start-action button:hover, tabbar .end-action button:hover {
  background-color: {{ dark_background }};
  color: {{ foreground }};
}
tabbar undershoot { background: none; }

/* Unfocused (backdrop): libadwaita swaps the tab bar to its lighter backdrop
   colour with a more specific :backdrop rule, so the bar brightened whenever
   the window lost focus. Keep it exactly as it is when focused. */
tabbar .box:backdrop {
  background-color: {{ darker_background }};
  box-shadow: inset 0 -1px {{ lighter_background }};
}
tabbar tab:backdrop { background: none; color: {{ dark_foreground }}; }
tabbar tab:selected:backdrop,
tabbar tabbox.single-tab tab:backdrop {
  background-color: {{ background }};
  color: {{ bright_foreground }};
  box-shadow: inset 0 2px {{ accent }};
}
tabbar .start-action button:backdrop,
tabbar .end-action button:backdrop { background: none; color: {{ dark_foreground }}; }
tabbar tab button.image-button:backdrop { background: none; color: inherit; }

/* Dialogs: close confirmation, clipboard confirmation, config errors,
   change-title */
dialog.alert .dialog-contents,
floating-sheet > sheet,
dialog > .dialog-contents {
  background-color: {{ dark_background }};
  color: {{ foreground }};
  border: 1px solid {{ lighter_background }};
}
dialog.alert .response-area { border-top: 1px solid {{ lighter_background }}; }
dialog.alert .response-area button { color: {{ foreground }}; background: none; }
dialog.alert .response-area button:hover { background-color: {{ lighter_background }}; }
dialog.alert .response-area button.suggested { color: {{ accent }}; }
dialog.alert .response-area button.destructive { color: {{ red }}; }
dialog.alert .response-area separator { background-color: {{ lighter_background }}; }
.clipboard-confirmation-dialog .clipboard-overlay,
.clipboard-confirmation-dialog .clipboard-contents {
  background-color: {{ darker_background }};
  color: {{ foreground }};
}

/* Command palette */
.command-palette-search { background-color: {{ dark_background }}; }
list.rich-list > row:selected { background-color: {{ selection }}; }

/* Floating overlays on the terminal (Ghostty's own class names) */
.search-overlay,
.key-state-overlay,
label.resize-overlay,
label.url-overlay,
.readonly_overlay,
toast {
  background-color: {{ dark_background }};
  color: {{ foreground }};
  outline: none;
  border: 1px solid {{ lighter_background }};
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}
.search-overlay { padding: 4px; margin: 6px; }
.search-overlay entry {
  background-color: {{ darker_background }};
  min-height: 26px;
}
.search-overlay entry:focus-within { outline: 1px solid {{ accent }}; outline-offset: -1px; }
.search-overlay button { background: none; min-height: 26px; min-width: 26px; }
.search-overlay button:hover { background-color: {{ lighter_background }}; }
.search-overlay .dim-label { color: {{ dark_foreground }}; }
label.url-overlay { color: {{ accent }}; }
.readonly_overlay { color: {{ yellow }}; }
.surface .bell-overlay { border-color: {{ accent }}; }
.child-exited.normal revealer widget { background-color: {{ green }}; color: {{ background }}; }
.child-exited.abnormal revealer widget { background-color: {{ red }}; color: {{ background }}; }

/* Split dividers */
.window .split paned > separator { background-color: {{ lighter_background }}; }

entry, text { caret-color: {{ accent }}; }
selection, text selection { background-color: {{ selection }}; color: {{ bright_foreground }}; }

/* Hyprland's rounding is 0: square off every widget, popups included */
* { border-radius: 0; }
