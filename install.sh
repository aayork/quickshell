#!/bin/bash
# Installs the aayork-quickshell desktop: Hyprland + this Quickshell shell,
# with everything they depend on, on Arch-based or Debian/Ubuntu-based
# distros.
#
#   ./install.sh                     install (safe to re-run; it skips what is done)
#   ./install.sh --with-bose ...     add the hardware/account extras (see --help)
#   ./install.sh --check             only check that every dependency is there
#   ./install.sh --remove-builds     Debian/Ubuntu: delete the source builds in /opt
#
# Or without cloning first:
#   bash <(curl -fsSL https://raw.githubusercontent.com/aayork/quickshell/main/install.sh)

set -Eeuo pipefail
# Any unexpected stop says where, instead of exiting silently.
trap 'rc=$?; printf "\n\e[31merror:\e[0m the installer stopped at %s line %s (exit %s)\n" "$(basename "${BASH_SOURCE[0]}")" "$LINENO" "$rc" >&2' ERR

REPO_URL=${REPO_URL:-https://github.com/aayork/quickshell.git}
DEFAULT_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/aayork-quickshell

usage() {
  cat <<EOF
Usage: install.sh [options]

Installs Hyprland, the aayork-quickshell shell and all their dependencies,
then sets up your user: font, icons, Hyprland config, app configs, theme.

Supported: Arch and Arch-based (CachyOS, EndeavourOS, Manjaro...),
Debian 13+, Ubuntu 24.04+ and distros built on them (Zorin OS, Linux Mint,
Pop!_OS...). On Debian/Ubuntu, Hyprland and Quickshell are built from source
into /opt/aayork-desktop, which takes a while (longest on 24.04-based
releases, where Qt is built too).

Extras, off unless asked for:
  --with-bose         Bose headphone controls on the bar
  --with-razer        Razer mouse DPI/polling settings (installs OpenRazer)
  --with-things       Things 3 to-dos on the bar (installs Go and things-cli)
  --with-tailscale    Tailscale (the bar shows it whenever it is installed)
  --with-greeter      the Quickshell login screen on greetd (Arch only)

Options:
  --theme NAME        starting theme (default: tokyo-night); see themes/
  --overwrite-config  replace existing configs (hyprland.lua, ghostty...) after
                      backing each one up; by default yours are kept
  --skip-packages     only do the per-user setup
  --check             only check dependencies, change nothing
  --remove-builds     delete /opt/aayork-desktop and what it linked (Debian/Ubuntu)
  -y, --yes           do not ask before starting
  -h, --help          this help
EOF
}

WITH_BOSE=false WITH_RAZER=false WITH_THINGS=false WITH_TAILSCALE=false WITH_GREETER=false
OVERWRITE_CONFIG=false SKIP_PACKAGES=false ONLY_CHECK=false REMOVE_BUILDS=false ASSUME_YES=false
THEME=tokyo-night THEME_CHOSEN=
ARGS=("$@")

while (($#)); do
  case $1 in
    --with-bose) WITH_BOSE=true ;;
    --with-razer) WITH_RAZER=true ;;
    --with-things) WITH_THINGS=true ;;
    --with-tailscale) WITH_TAILSCALE=true ;;
    --with-greeter) WITH_GREETER=true ;;
    --theme) THEME=${2:?--theme needs a name}; THEME_CHOSEN=1; shift ;;
    --overwrite-config) OVERWRITE_CONFIG=true ;;
    --skip-packages) SKIP_PACKAGES=true ;;
    --check) ONLY_CHECK=true ;;
    --remove-builds) REMOVE_BUILDS=true ;;
    -y|--yes) ASSUME_YES=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# Run through curl: fetch the repo, then run its own copy of this script.
SELF="${BASH_SOURCE[0]}"
if [[ ! -f "$(dirname "$SELF")/install/lib.sh" ]]; then
  command -v git >/dev/null || { echo "git is needed: install it first." >&2; exit 1; }
  if [[ -d $DEFAULT_DIR/.git ]]; then
    git -C "$DEFAULT_DIR" pull --ff-only
  else
    git clone "$REPO_URL" "$DEFAULT_DIR"
  fi
  exec bash "$DEFAULT_DIR/install.sh" "${ARGS[@]}"
fi

SHELL_DIR="$(cd "$(dirname "$(readlink -f "$SELF")")" && pwd)"
INSTALL_DIR="$SHELL_DIR/install"
export SHELL_DIR INSTALL_DIR

source "$INSTALL_DIR/lib.sh"
source "$INSTALL_DIR/deps.sh"
source "$INSTALL_DIR/check.sh"
source "$INSTALL_DIR/setup.sh"

[[ $EUID -ne 0 ]] || die "Run this as your own user, not root; it asks for sudo when it needs it."

detect_distro

if $ONLY_CHECK; then
  [[ -d /opt/aayork-desktop ]] && export PATH="/opt/aayork-desktop/bin:$PATH"
  check_all
  exit
fi

if $REMOVE_BUILDS; then
  source "$INSTALL_DIR/build.sh"
  keep_sudo_alive
  remove_builds
  exit
fi

[[ -d $SHELL_DIR/themes/$THEME ]] || die "No theme named '$THEME' in $SHELL_DIR/themes."

cat <<EOF

${c_bold}aayork-quickshell installer${c_off}
  System:  $DISTRO_NAME ($DISTRO_FAMILY)
  Shell:   $SHELL_DIR
  Extras:  $( $WITH_BOSE && printf 'bose '; $WITH_RAZER && printf 'razer '; $WITH_THINGS && printf 'things '; $WITH_TAILSCALE && printf 'tailscale '; $WITH_GREETER && printf 'greeter '; true)
EOF
if [[ $DISTRO_FAMILY == debian ]] && ! $SKIP_PACKAGES; then
  echo "  Note:    Hyprland and Quickshell get built from source; this can take 15 to 90 minutes."
fi
if ! $ASSUME_YES; then
  read -r -p "Continue? [Y/n] " answer
  [[ -z $answer || $answer =~ ^[Yy] ]] || exit 0
fi

USE_XDPW=false
if ! $SKIP_PACKAGES; then
  keep_sudo_alive
  case $DISTRO_FAMILY in
    arch)
      source "$INSTALL_DIR/arch.sh"
      install_arch
      ;;
    debian)
      source "$INSTALL_DIR/debian.sh"
      install_debian
      ;;
    *)
      die "Unsupported distro: $DISTRO_NAME. Arch-based and Debian/Ubuntu-based systems are supported."
      ;;
  esac
else
  keep_sudo_alive
fi

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
setup_user

if check_all; then
  cat <<EOF

${c_green}${c_bold}Done.${c_off} Log out, pick ${c_bold}Hyprland${c_off} on the login screen, and log in.
  SUPER+Space        launcher          SUPER+Return   terminal
  SUPER+SHIFT+Space  settings          SUPER+Escape   power menu
  Logs: journalctl --user -t aayork-quickshell
  Group changes (i2c, video) apply after logging out and back in.
EOF
else
  echo
  warn "Installed, but something is missing (above). Fix it and run: $0 --check"
  exit 1
fi
