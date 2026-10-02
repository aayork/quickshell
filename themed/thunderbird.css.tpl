/* Thunderbird, recoloured from the current theme.
   Generated into ~/.local/state/aayork-quickshell/current/theme/thunderbird.css by
   bin/theme-set-templates; bin/theme-set-thunderbird copies it into
   each Thunderbird profile as chrome/desktop-theme.css, imported by userChrome.css
   and userContent.css.

   Thunderbird paints nearly everything from a small set of tokens
   (layout.css, colors.css and shared/variables.css in its own skin), so this
   sets those rather than chasing individual panes. */

:root {
  color-scheme: {{ mode }} !important;
  accent-color: {{ accent }} !important;

  /* The three-pane window: message list, folder pane and toolbars, cards. */
  --layout-background-0: {{ background }} !important;
  --layout-background-1: {{ dark_background }} !important;
  --layout-background-2: {{ lighter_background }} !important;
  --layout-background-3: {{ mix lighter_background foreground 8% }} !important;
  --layout-background-4: {{ mix lighter_background foreground 18% }} !important;

  --layout-color-0: {{ bright_foreground }} !important;
  --layout-color-1: {{ foreground }} !important;
  --layout-color-2: {{ dark_foreground }} !important;
  --layout-color-3: {{ mix background foreground 45% }} !important;

  --layout-border-0: {{ mix lighter_background foreground 15% }} !important;
  --layout-border-1: {{ mix lighter_background foreground 25% }} !important;
  --layout-border-2: {{ mix lighter_background foreground 35% }} !important;

  /* The newer design tokens, used by dialogs, the account hub and settings. */
  --color-surface-base: {{ background }} !important;
  --color-surface-raised: {{ lighter_background }} !important;
  --color-surface-subtle: {{ dark_background }} !important;
  --color-surface-lower: {{ dark_background }} !important;
  --color-surface-deep: {{ darker_background }} !important;
  --color-surface-border: {{ mix lighter_background foreground 15% }} !important;
  --color-surface-border-intense: {{ mix lighter_background foreground 35% }} !important;
  --color-neutral-200: {{ mix lighter_background foreground 15% }} !important;

  --color-text-base: {{ foreground }} !important;
  --color-text-secondary: {{ dark_foreground }} !important;
  --color-text-muted: {{ mix background foreground 45% }} !important;
  --color-text-brand: {{ accent }} !important;
  --color-text-highlight: {{ accent }} !important;
  --color-text-critical: {{ red }} !important;
  --color-text-warning: {{ yellow }} !important;
  --color-text-success: {{ green }} !important;

  --color-primary-soft: {{ selection }} !important;
  --color-primary-default: {{ accent }} !important;
  --color-primary-hover: {{ mix accent background 12% }} !important;
  --color-primary-pressed: {{ mix accent background 24% }} !important;

  /* The grey ramp the tokens above are normally cut from, for the places that
     reach past them and use a grey directly. */
  --color-gray-05: light-dark({{ background }}, {{ bright_foreground }}) !important;
  --color-gray-10: light-dark({{ mix background foreground 6% }}, {{ foreground }}) !important;
  --color-gray-20: light-dark({{ mix background foreground 12% }}, {{ mix background foreground 85% }}) !important;
  --color-gray-30: light-dark({{ mix background foreground 20% }}, {{ mix background foreground 72% }}) !important;
  --color-gray-40: light-dark({{ mix background foreground 32% }}, {{ mix background foreground 58% }}) !important;
  --color-gray-50: {{ mix background foreground 45% }} !important;
  --color-gray-60: light-dark({{ mix background foreground 58% }}, {{ mix background foreground 26% }}) !important;
  --color-gray-70: light-dark({{ mix background foreground 72% }}, {{ lighter_background }}) !important;
  --color-gray-80: light-dark({{ mix background foreground 85% }}, {{ dark_background }}) !important;
  --color-gray-90: light-dark({{ foreground }}, {{ background }}) !important;

  /* Selection is the theme's selection colour, the way the launcher and the
     terminal draw it; the accent is kept for what asks to be pressed. */
  --selected-item-color: {{ selection }} !important;
  --selected-item-text-color: {{ bright_foreground }} !important;
  --sidebar-highlight-background-color: {{ selection }} !important;
  --sidebar-highlight-text-color: {{ bright_foreground }} !important;

  --button-primary-background-color: {{ accent }} !important;
  --button-primary-hover-background-color: {{ mix accent background 12% }} !important;
  --button-primary-active-background-color: {{ mix accent background 24% }} !important;
  --button-primary-text-color: {{ background }} !important;
  --button-primary-border-color: {{ accent }} !important;

  /* The message list. Its cards tint themselves with a fifth of the selection
     colour, which works for a loud accent and vanishes with a quiet one, so
     the selected states are given outright. */
  --tree-view-bg: {{ background }} !important;
  --tree-pane-background: {{ dark_background }} !important;
  --tree-card-background: {{ background }} !important;
  --tree-card-border: {{ mix lighter_background foreground 8% }} !important;
  --tree-card-border-hover: {{ mix lighter_background foreground 35% }} !important;
  --tree-card-border-focus: {{ accent }} !important;
  --tree-card-background-current: {{ lighter_background }} !important;
  --tree-card-background-selected: {{ selection }} !important;
  --tree-card-background-selected-current: {{ selection }} !important;
  --tree-card-border-selected: {{ mix selection accent 45% }} !important;
  --tree-card-background-current-unfocused: {{ lighter_background }} !important;
  --tree-card-background-selected-unfocused: {{ lighter_background }} !important;
  --tree-card-background-selected-current-unfocused: {{ lighter_background }} !important;
  --tree-card-border-selected-unfocused: {{ mix lighter_background foreground 25% }} !important;
  --listbox-selected-bg: {{ lighter_background }} !important;
  --listbox-hover: {{ mix background lighter_background 60% }} !important;
  --tree-view-header-hover-bg: {{ lighter_background }} !important;
  --tree-view-header-hover-active-bg: {{ selection }} !important;
  --unread-color: {{ bright_foreground }} !important;

  /* The title bar strip that holds the search box and the tabs. */
  --toolbox-background-color: {{ dark_background }} !important;
  --toolbox-background-color-inactive: {{ dark_background }} !important;
  --toolbox-text-color: {{ foreground }} !important;
  --toolbox-text-color-inactive: {{ dark_foreground }} !important;
  --lwt-accent-color: {{ dark_background }} !important;

  --tabline-color: {{ accent }} !important;
  --focus-outline-color: {{ accent }} !important;
  --toolbar-field-focus-border-color: {{ accent }} !important;
  --toolbarbutton-icon-fill-attention: {{ accent }} !important;
  --new-folder-color: {{ accent }} !important;
  --button-link-text-color: {{ accent }} !important;
  --button-link-active-text-color: {{ mix accent background 20% }} !important;
  --link-color: {{ accent }} !important;
  --link-color-hover: {{ accent }} !important;
  --link-color-active: {{ mix accent background 20% }} !important;
  --link-color-visited: {{ accent }} !important;

  --button-destructive-background-color: {{ red }} !important;
  --button-destructive-text-color: {{ background }} !important;

  /* Flat, to match Hyprland's rounding = 0. */
  --button-border-radius: 0 !important;
  --border-radius-medium: 0 !important;
  --input-text-border-radius: 0 !important;
  --input-search-border-radius: 0 !important;
  --autocomplete-item-radius: 0 !important;
}

:root :is(menupopup, panel):not(.autoscroller) {
  --panel-background-color: {{ dark_background }} !important;
  --panel-text-color: {{ foreground }} !important;
  --panel-border-color: {{ mix lighter_background foreground 25% }} !important;
  --panel-border-radius: 0 !important;
}

/* The strip at the top takes GTK's headerbar colour directly rather than
   through a variable, so it is the one surface that needs a rule of its own. */
#navigation-toolbox,
#navigation-toolbox:-moz-window-inactive {
  background-color: {{ dark_background }} !important;
  color: {{ foreground }} !important;
  border-radius: 0 !important;
}

button,
select,
input:not([type="checkbox"], [type="radio"]),
menupopup,
panel {
  border-radius: 0 !important;
}

/* Minimise, maximise and close are Hyprland's job, and it has no title bars to
   put them in. */
.titlebar-buttonbox-container {
  display: none !important;
}
