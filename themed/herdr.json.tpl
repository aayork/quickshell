{
  "background": "{{ background }}",
  "foreground": "{{ foreground }}",
  "selection": "{{ selection }}",
  "cursor": "{{ bright_foreground }}",
  "ansi": [
    "{{ dark_background }}", "{{ red }}", "{{ green }}", "{{ yellow }}", "{{ blue }}", "{{ magenta }}", "{{ cyan }}", "{{ foreground }}",
    "{{ muted }}", "{{ bright_red }}", "{{ bright_green }}", "{{ bright_yellow }}", "{{ bright_blue }}", "{{ bright_magenta }}", "{{ bright_cyan }}", "{{ bright_foreground }}"
  ],
  "colors": {
    "surface": "{{ background }}",
    "chrome": "{{ dark_background }}",
    "canvas": "{{ darker_background }}",
    "popover": "{{ lighter_background }}",
    "raised": "{{ lighter_background }}",
    "input": "{{ dark_background }}",
    "hover": "{{ lighter_background }}",
    "selected": "{{ selection }}",
    "border": "{{ lighter_background }}",
    "muted": "{{ dark_foreground }}",
    "dim": "{{ muted }}",
    "accent": "{{ accent }}",
    "accent_foreground": "{{ darker_background }}",
    "working": "{{ yellow }}",
    "blocked": "{{ red }}",
    "done": "{{ green }}",
    "idle": "{{ dark_foreground }}"
  }
}
