#!/bin/bash
# Checks that everything the desktop needs is installed. install.sh runs it
# at the end; run it by itself any time: install/check.sh

check_all() {
  local missing=() line cmd why
  step "Checking dependencies"

  # Programs linked into /usr/local/bin and ~/.local/bin count, as they will
  # be on Hyprland's PATH even if this shell's PATH lacks them.
  local path_save=$PATH
  PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

  for line in "${REQUIRED_CMDS[@]}"; do
    cmd=${line%%|*}; why=${line#*|}
    have "$cmd" || missing+=("$cmd ($why)")
  done

  local mod
  for line in "${REQUIRED_PY[@]}"; do
    mod=${line%%|*}; why=${line#*|}
    python3 -c "import $mod" 2>/dev/null || missing+=("python: $mod ($why)")
  done

  font_installed || missing+=("font: $REQUIRED_FONT")
  [[ -d $HOME/.local/share/icons/$REQUIRED_ICON_THEME || -d /usr/share/icons/$REQUIRED_ICON_THEME ]] \
    || missing+=("icon theme: $REQUIRED_ICON_THEME")

  # Versions that matter: the config is Lua (Hyprland 0.56+).
  local v
  if have Hyprland; then
    v=$(Hyprland --version 2>/dev/null | grep -oE 'Hyprland [0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk '{print $2}')
    if [[ -n $v ]] && ! version_ge "$v" "$MIN_HYPRLAND"; then missing+=("Hyprland $MIN_HYPRLAND+ (found $v)"); fi
  fi
  if have quickshell; then
    v=$(quickshell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ -n $v ]] && ! version_ge "$v" "$MIN_QUICKSHELL"; then missing+=("Quickshell $MIN_QUICKSHELL+ (found $v)"); fi
  fi

  # A portal backend for screenshots, screen sharing and file pickers.
  local portals=/usr/share/xdg-desktop-portal/portals
  [[ -e $portals/hyprland.portal || -e $portals/wlr.portal ]] \
    || missing+=("xdg-desktop-portal-hyprland or -wlr (screen sharing)")
  [[ -e $portals/gtk.portal ]] || missing+=("xdg-desktop-portal-gtk (file picker)")
  # A login screen entry.
  compgen -G "/usr/share/wayland-sessions/hyprland*.desktop" >/dev/null \
    || missing+=("a Hyprland entry in /usr/share/wayland-sessions")

  # Optional extras the user asked for.
  if ${WITH_RAZER:-false}; then
    python3 -c "import openrazer.client" 2>/dev/null || missing+=("python: openrazer (--with-razer)")
  fi
  if ${WITH_THINGS:-false}; then
    have things-cli || [[ -x $HOME/go/bin/things-cli ]] || missing+=("things-cli (--with-things)")
  fi
  if ${WITH_TAILSCALE:-false}; then have tailscale || missing+=("tailscale (--with-tailscale)"); fi

  PATH=$path_save

  if ((${#missing[@]})); then
    printf '\n%sMissing:%s\n' "$c_red" "$c_off"
    printf '    - %s\n' "${missing[@]}"
    return 1
  fi
  ok "all ${#REQUIRED_CMDS[@]} programs, ${#REQUIRED_PY[@]} Python modules, the font, icon theme, portals and session entry are in place"
}

# Run directly: load the helpers and check.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  INSTALL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
  source "$INSTALL_DIR/lib.sh"
  source "$INSTALL_DIR/deps.sh"
  check_all
fi
