# btop theme generated from the desktop theme (themed/btop.theme.tpl).
# A theme that ships its own btop.theme replaces this one.

theme[main_bg]="{{ background }}"
theme[main_fg]="{{ foreground }}"
theme[title]="{{ foreground }}"
theme[hi_fg]="{{ accent }}"
theme[selected_bg]="{{ selection }}"
theme[selected_fg]="{{ bright_foreground }}"
theme[inactive_fg]="{{ muted }}"
theme[graph_text]="{{ dark_foreground }}"
theme[meter_bg]="{{ lighter_background }}"
theme[proc_misc]="{{ accent }}"

theme[cpu_box]="{{ mix lighter_background foreground 25% }}"
theme[mem_box]="{{ mix lighter_background foreground 25% }}"
theme[net_box]="{{ mix lighter_background foreground 25% }}"
theme[proc_box]="{{ mix lighter_background foreground 25% }}"
theme[div_line]="{{ lighter_background }}"

theme[temp_start]="{{ green }}"
theme[temp_mid]="{{ yellow }}"
theme[temp_end]="{{ red }}"

theme[cpu_start]="{{ mix background accent 55% }}"
theme[cpu_mid]="{{ accent }}"
theme[cpu_end]="{{ mix accent red 60% }}"

theme[free_start]="{{ mix background green 50% }}"
theme[free_mid]="{{ green }}"
theme[free_end]="{{ bright_green }}"

theme[cached_start]="{{ mix background cyan 50% }}"
theme[cached_mid]="{{ cyan }}"
theme[cached_end]="{{ bright_cyan }}"

theme[available_start]="{{ mix background blue 50% }}"
theme[available_mid]="{{ blue }}"
theme[available_end]="{{ bright_blue }}"

theme[used_start]="{{ mix background yellow 50% }}"
theme[used_mid]="{{ yellow }}"
theme[used_end]="{{ red }}"

theme[download_start]="{{ mix background blue 50% }}"
theme[download_mid]="{{ blue }}"
theme[download_end]="{{ bright_blue }}"

theme[upload_start]="{{ mix background magenta 50% }}"
theme[upload_mid]="{{ magenta }}"
theme[upload_end]="{{ bright_magenta }}"

theme[process_start]="{{ accent }}"
theme[process_mid]="{{ mix accent red 50% }}"
theme[process_end]="{{ red }}"
