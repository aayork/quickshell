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

/* Tab bar: a see-through strip in the terminal's own colour, so it reads as
   part of the window rather than a black band on top. Tabs share the width
   evenly with centred titles; the active tab is a soft raised pill, the
   others are plain text that lights up on hover. Close buttons show only on
   the active tab and on hover. libadwaita rounds and pads tabboxchild (the
   tab's wrapper), not just tab, so both are styled. */
tabbar .box,
tabbar .box:backdrop {
  background-color: alpha({{ background }}, 0.9);
  box-shadow: inset 0 -1px alpha({{ foreground }}, 0.06);
  padding: 0;
}
tabbar tabbox,
toolbarview > .top-bar .collapse-spacing tabbar tabbox,
toolbarview > .bottom-bar .collapse-spacing tabbar tabbox {
  /* Horizontal gaps come from libadwaita's own 5px spacing around every
     tab (it is fixed in code), so tabs and the bar add none of their own:
     both ends and every gap between tabs match. Vertically 4px clear above
     and below the tabs; the bottom gets one more pixel for the bar's
     hairline. */
  padding: 4px 0 5px;
  min-height: 26px; /* whole bar is 35px tall */
}
tabbar tabbox > tabboxchild { border-radius: 7px; outline-offset: -1px; padding: 0; margin: 0; }
/* No dividers: they would add a pixel between tabs that the ends lack. */
tabbar tabbox > separator,
tabbar tabbox > separator.hidden {
  margin: 0;
  min-width: 0;
  background: none;
}
tabbar tab,
tabbar tab:backdrop {
  min-height: 26px;
  margin: 0;
  padding: 0 8px;
  border-radius: 7px;
  background: none;
  box-shadow: none;
  color: alpha({{ foreground }}, 0.55);
  transition: background-color 120ms ease-out, color 120ms ease-out;
}
tabbar tab label { font-size: 0.85em; font-weight: 500; }
tabbar tab:hover,
tabbar tab:active {
  background-color: alpha({{ foreground }}, 0.06);
  color: alpha({{ foreground }}, 0.85);
}
tabbar tab:selected,
tabbar tab:selected:hover,
tabbar tab:selected:active,
tabbar tab:selected:backdrop,
tabbar tabbox.single-tab tab,
tabbar tabbox.single-tab tab:backdrop {
  background-color: alpha({{ foreground }}, 0.11);
  color: {{ bright_foreground }};
  box-shadow: inset 0 0 0 1px alpha({{ foreground }}, 0.07);
}

/* Close button: a small round button, hidden until wanted. */
tabbar tab button.image-button,
tabbar tab button.image-button:backdrop {
  min-width: 18px;
  min-height: 18px;
  padding: 0;
  margin: 0;
  border-radius: 99px;
  background: none;
  box-shadow: none;
  color: inherit;
  opacity: 0;
  transition: opacity 120ms ease-out, background-color 120ms ease-out;
}
tabbar tab:hover button.image-button,
tabbar tab:selected button.image-button { opacity: 0.6; }
tabbar tab button.image-button:hover {
  opacity: 1;
  background-color: alpha({{ foreground }}, 0.14);
}
tabbar tab button.image-button image { -gtk-icon-size: 11px; }

/* Activity dot / needs-attention line */
tabbar tab indicator, tabbar tabbox > revealer > indicator {
  border-radius: 99px;
  background: {{ accent }};
}
tabbar .start-action, tabbar .end-action { padding: 0; }
tabbar .start-action button, tabbar .end-action button,
tabbar .start-action button:backdrop, tabbar .end-action button:backdrop {
  border-radius: 7px;
  margin: 4px 2px;
  min-height: 26px;
  min-width: 26px;
  background: none;
  box-shadow: none;
  color: alpha({{ foreground }}, 0.55);
}
tabbar .start-action button:hover, tabbar .end-action button:hover {
  background-color: alpha({{ foreground }}, 0.08);
  color: {{ foreground }};
}
tabbar undershoot { background: none; }

/* Unfocused window: libadwaita fades the whole top bar to 50% opacity,
   which halves the bar's tint and lets the wallpaper glare through, so it
   looks lighter than the terminal. Keep the bar solid and dim only the
   tab contents instead. */
toolbarview > .top-bar:backdrop > windowhandle,
tabbar .box:backdrop > scrolledwindow,
tabbar .box:backdrop > .start-action,
tabbar .box:backdrop > .end-action { filter: none; }
tabbar .box:backdrop > scrolledwindow,
tabbar .box:backdrop > .start-action,
tabbar .box:backdrop > .end-action { opacity: 0.6; }

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

/* Hyprland's rounding is 0: square off every widget, popups included.
   The tab bar's pills above are the one exception. */
* { border-radius: 0; }
tabbar tab, tabbar tabbox > tabboxchild,
tabbar .start-action button, tabbar .end-action button { border-radius: 7px; }
tabbar tab button.image-button, tabbar indicator { border-radius: 99px; }
