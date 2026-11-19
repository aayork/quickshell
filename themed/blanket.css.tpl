/* Blanket (white noise app), recoloured from the current theme.
   Generated into ~/.local/state/aayork-quickshell/current/theme/blanket.css by
   bin/theme-set-templates; loaded at user priority by bin/blanket, which
   re-reads it when the theme changes. Matches the shell: square windows,
   2px controls, the shell's monospace font, flat glass-free surfaces. */

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
  --headerbar-shade-color: transparent;

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

window, popover, dialog { font-family: monospace; }

/* Header and footer: one flat strip each, hairline toward the grid. */
headerbar, headerbar:backdrop {
  background-color: {{ dark_background }};
  box-shadow: inset 0 -1px alpha({{ foreground }}, 0.06);
  min-height: 38px;
}
headerbar .title { font-weight: 600; letter-spacing: 0.02em; }
actionbar > revealer > box, actionbar > revealer > box:backdrop {
  background-color: {{ dark_background }};
  box-shadow: inset 0 1px alpha({{ foreground }}, 0.06);
  padding: 6px 8px;
}
toolbarview > .top-bar:backdrop > windowhandle,
toolbarview > .bottom-bar:backdrop > actionbar { filter: none; }

/* Buttons: plain glyphs that light up on hover, like the bar. */
headerbar button, actionbar button {
  background: none;
  box-shadow: none;
  color: {{ foreground }};
  min-height: 28px;
  min-width: 28px;
}
headerbar button:hover, actionbar button:hover,
headerbar button:checked, actionbar button:checked {
  background-color: alpha({{ foreground }}, 0.08);
  color: {{ bright_foreground }};
}

/* Play/pause: the one accent block in the window. */
button.playpause, button.playpause:backdrop {
  background-color: {{ accent }};
  color: {{ background }};
  padding: 8px;
  min-width: 36px;
  min-height: 36px;
}
button.playpause:hover { background-color: {{ mix accent bright_foreground 20% }}; color: {{ background }}; }
button.playpause:disabled { filter: none; opacity: 0.85; color: {{ background }}; }
button.playpause:active { background-color: {{ mix accent background 20% }}; }

/* Sound grid */
.sound-view { background: {{ background }}; padding: 10px; }
flowbox.sound-view > flowboxchild.sound-item {
  margin: 3px;
  padding: 12px 10px 6px;
  background-color: alpha({{ foreground }}, 0.045);
  box-shadow: inset 0 0 0 1px alpha({{ foreground }}, 0.07);
  transition: background-color 120ms ease-out, box-shadow 120ms ease-out;
}
flowbox.sound-view > flowboxchild.sound-item:hover {
  background-color: alpha({{ foreground }}, 0.08);
  box-shadow: inset 0 0 0 1px alpha({{ foreground }}, 0.12);
}
flowbox.sound-view > flowboxchild.sound-item:focus-visible {
  outline: 1px solid {{ accent }};
  outline-offset: -1px;
}
.sound-item image {
  padding: 12px;
  color: {{ foreground }};
  background: none;
  transition: background-color 150ms ease-out, color 150ms ease-out;
}
.sound-item image.accent {
  background-color: alpha({{ accent }}, 0.16);
  color: {{ accent }};
}
.sound-item label { color: {{ light_foreground }}; font-size: 0.9em; }
.sound-item image, .sound-item label, .sound-item:disabled,
.sound-item image:disabled, .sound-item label:disabled { opacity: 1; filter: none; }

/* Sliders: thin track, accent fill, small square thumb on hover. */
scale trough {
  min-height: 3px;
  background-color: alpha({{ foreground }}, 0.18);
}
scale trough highlight { background-color: {{ accent }}; }
scale trough slider {
  min-width: 12px;
  min-height: 12px;
  margin: -5px;
  background-color: {{ bright_foreground }};
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.35);
  outline: none;
}
.sound-item > box scale trough highlight { min-height: 3px; min-width: 3px; }
.sound-item > box scale trough highlight:disabled {
  background: alpha({{ foreground }}, 0.45);
}

/* Popovers: preset chooser, volumes, menus */
popover > contents {
  background-color: {{ dark_background }};
  color: {{ foreground }};
  border: 1px solid {{ lighter_background }};
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.35);
}
popover > arrow { background-color: {{ dark_background }}; border-color: {{ lighter_background }}; }
popover modelbutton:hover,
popover modelbutton:selected,
popover list > row:hover,
popover list > row:selected { background-color: {{ selection }}; color: {{ bright_foreground }}; }
popover list { background: none; }
popover separator { background-color: {{ lighter_background }}; }
popover label.accelerator { color: {{ dark_foreground }}; }
.preset-row.selected label { color: {{ accent }}; }
.volume-row label { color: {{ light_foreground }}; }

/* Dialogs: presets, rename, preferences, about */
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
.boxed-list, list.boxed-list {
  background-color: {{ lighter_background }};
  box-shadow: inset 0 0 0 1px alpha({{ foreground }}, 0.06);
}
button.suggested-action { background-color: {{ accent }}; color: {{ background }}; }
switch:checked { background-color: {{ accent }}; }
switch slider { background-color: {{ bright_foreground }}; }

toast {
  background-color: {{ dark_background }};
  color: {{ foreground }};
  border: 1px solid {{ lighter_background }};
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

entry, text { caret-color: {{ accent }}; }
entry:focus-within { outline: 1px solid {{ accent }}; outline-offset: -1px; }
selection, text selection { background-color: {{ selection }}; color: {{ bright_foreground }}; }
scrollbar slider { background-color: alpha({{ foreground }}, 0.25); }
undershoot { background: none; }

/* Hyprland's rounding is 0: square windows and popups; controls get the
   shell's 2px radius, and the play button and switches stay round. */
* { border-radius: 0; }
button, entry, flowboxchild.sound-item, .sound-item image, popover modelbutton,
popover list > row, .boxed-list, list.boxed-list, toast, scale trough { border-radius: 2px; }
scale trough slider { border-radius: 2px; }
button.playpause, switch, switch slider { border-radius: 999px; }
