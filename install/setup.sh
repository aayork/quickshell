# Per-user setup, the same on every distro: fonts, icon theme, the Hyprland
# config, app configs, the shell's settings, a starting theme, and the
# system services the shell talks to. Sourced by install.sh.

V_COLLOID=2026-08-10
V_NERD_FONTS=v3.4.0

STAMP=$(date +%Y%m%d-%H%M%S)

# Writes $2 to file $1 unless the user already has one. With
# --overwrite-config an existing file is kept as <file>.bak-<time> first.
write_config() { # path content
  local path=$1 content=$2
  if [[ -e $path ]] && ! $OVERWRITE_CONFIG; then
    info "kept your $path"
    return 1
  fi
  mkdir -p "$(dirname "$path")"
  if [[ -e $path ]]; then
    cp -a "$path" "$path.bak-$STAMP"
    info "backed up $path to $path.bak-$STAMP"
  fi
  printf '%s\n' "$content" >"$path"
  ok "wrote $path"
}

setup_font() {
  step "Font: $REQUIRED_FONT"
  if font_installed; then
    ok "already installed"
  else
    local dir="$HOME/.local/share/fonts/BlexMonoNerdFont" tmp
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/IBMPlexMono.tar.xz" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/$V_NERD_FONTS/IBMPlexMono.tar.xz"
    mkdir -p "$dir"
    tar -xJf "$tmp/IBMPlexMono.tar.xz" -C "$dir" --wildcards '*.ttf'
    rm -rf "$tmp"
    fc-cache -f "$dir" >/dev/null
    ok "installed to $dir"
  fi
  # The shell and terminals ask for "monospace"; point it at the Nerd Font.
  write_config "$HOME/.config/fontconfig/fonts.conf" '<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any">
      <string>monospace</string>
    </test>
    <edit name="family" mode="prepend_first" binding="strong">
      <string>'"$REQUIRED_FONT"'</string>
    </edit>
  </match>
</fontconfig>' && fc-cache -f >/dev/null || true
}

setup_icons() {
  step "Icon theme: $REQUIRED_ICON_THEME"
  if [[ -d $HOME/.local/share/icons/$REQUIRED_ICON_THEME || -d /usr/share/icons/$REQUIRED_ICON_THEME ]]; then
    ok "already installed"
    return
  fi
  local tmp
  tmp=$(mktemp -d)
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$V_COLLOID" \
    https://github.com/vinceliuice/Colloid-icon-theme.git "$tmp/colloid"
  mkdir -p "$HOME/.local/share/icons"
  (cd "$tmp/colloid" && ./install.sh -d "$HOME/.local/share/icons" >/dev/null)
  rm -rf "$tmp"
  ok "installed to ~/.local/share/icons"
}

setup_hyprland_config() {
  step "Hyprland config"
  local file_manager=nautilus
  have nautilus || file_manager="xdg-open $HOME"
  local content
  content=$(sed -e "s|@SHELL_DIR@|$SHELL_DIR|g" -e "s|@TERMINAL@|ghostty|g" -e "s|@FILE_MANAGER@|$file_manager|g" \
    "$INSTALL_DIR/hyprland.lua")
  if write_config "$HOME/.config/hypr/hyprland.lua" "$content"; then :; else
    if ! grep -qF "$SHELL_DIR" "$HOME/.config/hypr/hyprland.lua"; then
      warn "Your hyprland.lua does not start this shell. Re-run with --overwrite-config to replace it"
      warn "(it is backed up first), or add the lines from $INSTALL_DIR/hyprland.lua yourself."
    fi
  fi
  # A hyprland.conf next to it would be read instead on older setups; leave it, Lua wins on 0.56.
}

setup_apps() {
  step "App configs"
  write_config "$HOME/.config/ghostty/config.ghostty" '# Colours follow the shell theme (regenerated on theme change).
background-opacity = 0.90
background-blur = 20
font-family = "'"$REQUIRED_FONT"'"

# Hyprland handles window management; no GTK chrome.
window-decoration = none
gtk-titlebar = false
window-theme = ghostty
gtk-toolbar-style = flat
gtk-wide-tabs = false
window-padding-x = 8
window-padding-y = 8
gtk-custom-css = ~/.local/state/aayork-quickshell/current/theme/ghostty-gtk.css
config-file = ?~/.local/state/aayork-quickshell/current/theme/ghostty.conf

# Fullscreen is SUPER+F in Hyprland.
keybind = ctrl+enter=unbind' || true

  write_config "$HOME/.config/xdg-terminals.list" "com.mitchellh.ghostty.desktop" || true

  local portal="hyprland;gtk"
  ${USE_XDPW:-false} && portal="wlr;gtk"
  write_config "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf" "[preferred]
default=$portal" || true
}

# The shell's own settings: hardware and account widgets follow the --with flags.
setup_shell_config() {
  step "Shell settings"
  local cfg="$HOME/.config/aayork-quickshell/config.json"
  mkdir -p "$(dirname "$cfg")"
  [[ -s $cfg ]] || echo '{}' >"$cfg"
  local tmp
  tmp=$(mktemp)
  # Off on a first install; a --with flag turns one on; a re-run without
  # flags leaves whatever was switched in Settings alone.
  jq --argjson bose "$WITH_BOSE" --argjson mouse "$WITH_RAZER" --argjson things "$WITH_THINGS" \
    '.features = ({bose: false, mouse: false, things: false} + (.features // {})
       + (if $bose then {bose: true} else {} end)
       + (if $mouse then {mouse: true} else {} end)
       + (if $things then {things: true} else {} end))' "$cfg" >"$tmp" && mv "$tmp" "$cfg"
  ok "extras: $(jq -r '.features | to_entries | map("\(.key)=\(.value)") | join(" ")' "$cfg") (switch in Settings › Shell › Extras)"
}

setup_theme() {
  step "Theme"
  local state="$HOME/.local/state/aayork-quickshell"
  if [[ -e $state/current/theme/colors.toml ]] && [[ -z ${THEME_CHOSEN:-} ]]; then
    ok "keeping your current theme ($(cat "$state/current/theme.name" 2>/dev/null || echo custom))"
    return
  fi
  mkdir -p "$state"
  "$SHELL_DIR/bin/theme-set" "$THEME" >/dev/null 2>&1 || warn "theme-set $THEME reported a problem"
  [[ -e $state/current/theme/colors.toml ]] && ok "$THEME" || warn "No theme applied; pick one in Settings › Appearance."
  gsettings set org.gnome.desktop.interface icon-theme "$REQUIRED_ICON_THEME" 2>/dev/null || true
}

setup_services() {
  step "System services"
  local s
  for s in NetworkManager bluetooth; do
    if systemctl list-unit-files "$s.service" >/dev/null 2>&1; then
      as_root systemctl enable --now "$s.service" >/dev/null 2>&1 && ok "$s enabled" || warn "could not enable $s"
    fi
  done
  # File search in the launcher.
  systemctl list-unit-files plocate-updatedb.timer >/dev/null 2>&1 \
    && as_root systemctl enable --now plocate-updatedb.timer >/dev/null 2>&1 || true
  # Audio runs per user; usually already on.
  systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1 || true

  # Brightness of external monitors over DDC needs the i2c-dev module and group.
  if ! grep -qs '^i2c-dev' /etc/modules-load.d/*.conf; then
    echo i2c-dev | as_root tee /etc/modules-load.d/i2c-dev.conf >/dev/null
    as_root modprobe i2c-dev 2>/dev/null || true
  fi
  getent group i2c >/dev/null || as_root groupadd --system i2c
  if as_root usermod -aG i2c,video "$USER"; then ok "added $USER to the i2c and video groups"; else warn "could not add $USER to the i2c and video groups"; fi
}

setup_things() {
  $WITH_THINGS || return 0
  step "Things 3 (things-cli)"
  if have things-cli || [[ -x $HOME/go/bin/things-cli ]]; then ok "already installed"; return; fi
  if go install github.com/arthursoares/things-cloud-sdk/cmd/things-cli@v0.6.0; then ok "installed to ~/go/bin"; else warn "go install things-cli failed"; fi
  info "Sign in from the Things button on the bar."
}

setup_greeter() {
  $WITH_GREETER || return 0
  step "Login screen (greetd)"
  if [[ $DISTRO_FAMILY != arch ]]; then
    warn "The Quickshell login screen is only set up on Arch for now; keeping your current login screen."
    return
  fi
  as_root "$SHELL_DIR/bin/greeter-install"
  local dm
  dm=$(systemctl show -p Id --value display-manager.service 2>/dev/null)
  if [[ -n $dm && $dm != greetd.service ]]; then
    warn "$dm is your login screen. To switch: sudo systemctl disable $dm && sudo systemctl enable greetd"
  else
    if as_root systemctl enable greetd.service >/dev/null 2>&1; then ok "greetd enabled"; else warn "could not enable greetd"; fi
  fi
}

setup_user() {
  setup_font
  setup_icons
  setup_hyprland_config
  setup_apps
  setup_shell_config
  setup_theme
  setup_services
  setup_things
  setup_greeter
}
