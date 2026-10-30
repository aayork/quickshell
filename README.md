# aayork-quickshell

A Hyprland desktop built on [Quickshell](https://quickshell.org): bar, launcher,
notifications, lock screen, screenshots and recording, settings, and 20+ themes
that recolour the shell, Hyprland borders, the terminal and other apps.

## Install

```sh
git clone https://github.com/aayork/quickshell.git ~/.local/share/aayork-quickshell
~/.local/share/aayork-quickshell/install.sh
```

Then log out, pick **Hyprland** on the login screen, and log in.

The installer installs every dependency, sets up your user (font, icon theme,
Hyprland config, Ghostty config, a starting theme), enables NetworkManager and
Bluetooth, and finishes by checking that everything is in place. It is safe
to run again; finished steps are skipped and your existing configs are kept
unless you pass `--overwrite-config` (which backs each one up first).

| System | How |
| --- | --- |
| Arch, CachyOS, EndeavourOS, Manjaro… | pacman (AUR only for anything the repos lack) |
| Ubuntu 26.04 and distros based on it | apt, plus Hyprland and Quickshell built from source |
| Debian 13+ | apt, plus Hyprland, Quickshell and a few newer libraries built from source |
| Ubuntu 24.04 bases: Zorin OS 18, Linux Mint 22, Pop!_OS 24.04… | apt, plus the above and Qt built from source (long first install) |

On Debian and Ubuntu the source builds go into `/opt/aayork-desktop`, linked so
that they never replace the system's own libraries. `./install.sh --remove-builds`
deletes them again.

### Extras

Off unless asked for, and switchable later in Settings › Shell › Extras:

```
--with-bose        Bose headphone controls on the bar
--with-razer       Razer mouse DPI and polling (installs OpenRazer)
--with-things      Things 3 to-dos on the bar (installs things-cli)
--with-tailscale   Tailscale (shown on the bar whenever it is installed)
--with-greeter     Quickshell login screen on greetd (Arch only)
```

Other options: `--theme NAME`, `--check` (only verify dependencies),
`--skip-packages`, `-y`. See `./install.sh --help`.

## Keys

| | |
| --- | --- |
| `SUPER+Space` | launcher |
| `SUPER+SHIFT+Space` | settings |
| `SUPER+Escape` | power menu |
| `SUPER+Return` | terminal |
| `SUPER+L` | lock |
| `ALT+SHIFT+3 / 4 / 5` | screenshot: screen / area / all-in-one |
| `ALT+A` | Jot scratchpad |

The full list is in `~/.config/hypr/hyprland.lua`. Put your own additions in
`~/.config/hypr/local.lua`; it is loaded last and the installer never touches it.

Logs: `journalctl --user -t aayork-quickshell`
