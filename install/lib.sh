# Shared helpers for install.sh and the scripts beside this file.
# Sourced, not run.

if [[ -t 1 ]]; then
  c_bold=$'\e[1m' c_dim=$'\e[2m' c_red=$'\e[31m' c_green=$'\e[32m' c_yellow=$'\e[33m' c_blue=$'\e[34m' c_off=$'\e[0m'
else
  c_bold= c_dim= c_red= c_green= c_yellow= c_blue= c_off=
fi

step() { printf '\n%s==>%s %s%s%s\n' "$c_blue" "$c_off" "$c_bold" "$*" "$c_off"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓%s %s\n' "$c_green" "$c_off" "$*"; }
warn() { printf '    %s!%s %s\n' "$c_yellow" "$c_off" "$*" >&2; }
die()  { printf '\n%serror:%s %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# True when version $1 >= $2 (dotted numbers; "1.22.91" style).
version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

# True when pkg-config finds module $1 at version $2 or newer.
pc_ge() {
  local v
  v=$(pkg-config --modversion "$1" 2>/dev/null) || return 1
  version_ge "$v" "$2"
}

# Root commands go through sudo, asked for once up front.
as_root() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

keep_sudo_alive() {
  [[ $EUID -eq 0 ]] && return
  sudo -v || die "sudo is needed to install packages."
  ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
  SUDO_KEEPALIVE=$!
  trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT
}

# Reads /etc/os-release into DISTRO_ID, DISTRO_LIKE, DISTRO_VERSION, DISTRO_NAME
# and sets DISTRO_FAMILY to "arch" or "debian".
detect_distro() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO_ID=${ID:-}
  DISTRO_LIKE=${ID_LIKE:-}
  DISTRO_VERSION=${VERSION_ID:-}
  DISTRO_NAME=${PRETTY_NAME:-$DISTRO_ID}
  # Derivatives (Zorin, Mint, Pop!_OS, elementary...) name their Ubuntu base here.
  UBUNTU_BASE=${UBUNTU_CODENAME:-}
  case " $DISTRO_ID $DISTRO_LIKE " in
    *" arch "*|*" archlinux "*) DISTRO_FAMILY=arch ;;
    *" debian "*|*" ubuntu "*) DISTRO_FAMILY=debian ;;
    *) DISTRO_FAMILY=unknown ;;
  esac
  if [[ $DISTRO_FAMILY == unknown ]]; then
    have pacman && DISTRO_FAMILY=arch
    have apt-get && DISTRO_FAMILY=debian
  fi
}

# fc-list piped into grep -q trips pipefail (SIGPIPE), so read it all first.
font_installed() {
  local fonts
  fonts=$(fc-list : family 2>/dev/null)
  [[ ${fonts,,} == *"${REQUIRED_FONT,,}"* ]]
}
