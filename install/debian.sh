# Debian, Ubuntu, and distros built on them (Zorin, Mint, Pop!_OS...): apt
# for everything it has, source builds (build.sh) for Hyprland, Quickshell
# and whatever else the release is too old for. Sourced by install.sh.

# Ubuntu release number behind this system, from os-release. Derivatives
# report their own VERSION_ID, so go by the Ubuntu codename they carry.
ubuntu_release() {
  case "${UBUNTU_BASE:-}" in
    noble) echo 24.04 ;;
    plucky) echo 25.04 ;;
    questing) echo 25.10 ;;
    resolute) echo 26.04 ;;
    "") if [[ $DISTRO_ID == ubuntu ]]; then echo "$DISTRO_VERSION"; fi ;;
    *) echo "" ;;
  esac
  return 0
}

check_debian_release() {
  local rel
  rel=$(ubuntu_release)
  if [[ -n $rel ]]; then
    version_ge "$rel" 24.04 || die "Ubuntu $rel is too old. Ubuntu 24.04 or newer (or a distro based on it) is needed."
    UBUNTU_RELEASE=$rel
    info "Ubuntu base: $rel"
  elif [[ $DISTRO_ID == debian || " $DISTRO_LIKE " == *" debian "* ]]; then
    local major=${DISTRO_VERSION%%.*}
    if [[ -n $major ]] && ((major < 13)); then
      die "Debian $DISTRO_VERSION is too old. Debian 13 (trixie) or newer is needed."
    fi
    info "Debian base: ${VERSION_CODENAME:-$DISTRO_VERSION}"
  fi
}

apt_has() {
  [[ -n "$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate/ && $2 != "(none)"')" ]]
}

# Installs the packages this release actually has; notes the rest. One
# apt-cache call for the whole list (per package it takes most of a minute).
apt_install() {
  local p avail pkgs=()
  avail=$(apt-cache policy "$@" 2>/dev/null \
    | awk '/^[^ ]/ { name = $1; sub(/:$/, "", name) } /Candidate:/ && $2 != "(none)" { print name }')
  for p in "$@"; do
    if grep -qxF -- "$p" <<<"$avail"; then pkgs+=("$p"); else SKIPPED_PKGS+=("$p"); fi
  done
  ((${#pkgs[@]})) || return 0
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
}

# Ghostty: apt when the release has it, else the community package Ghostty's
# own docs point to (github.com/mkasberg/ghostty-ubuntu).
install_ghostty() {
  have ghostty && { ok "ghostty already installed"; return; }
  if apt_has ghostty; then
    apt_install ghostty
    return
  fi
  local target arch url tmp
  case "${UBUNTU_RELEASE:-}" in
    "") target=${VERSION_CODENAME:-trixie} ;;
    *) target=$UBUNTU_RELEASE ;;
  esac
  arch=$(dpkg --print-architecture)
  url=$(curl -fsSL https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest \
    | jq -r --arg s "_${arch}_${target}.deb" '.assets[] | select(.name | endswith($s)) | .browser_download_url' | head -1)
  if [[ -z $url ]]; then
    warn "No Ghostty package for $target/$arch; install Ghostty by hand (ghostty.org)."
    return
  fi
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/ghostty.deb" "$url"
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp/ghostty.deb"
  rm -rf "$tmp"
}

install_debian() {
  check_debian_release
  SKIPPED_PKGS=()

  step "Updating package lists"
  as_root apt-get update -q

  step "Installing runtime packages with apt"
  local pkgs=("${DEB_PKGS[@]}")
  $WITH_BOSE && pkgs+=("${DEB_PKGS_BOSE[@]}")
  $WITH_RAZER && pkgs+=("${DEB_PKGS_RAZER[@]}")
  $WITH_THINGS && pkgs+=("${DEB_PKGS_THINGS[@]}")
  # Firefox: Debian ships it as firefox-esr, Ubuntu as firefox.
  if apt_has firefox; then
    pkgs+=(firefox)
  else
    pkgs+=(firefox-esr)
  fi
  apt_install "${pkgs[@]}"

  step "Installing build tools and libraries"
  # On newer releases a compiler new enough for C++26 is the default; on
  # 24.04 it is the g++-14 package.
  apt_install "${DEB_BUILD_PKGS[@]}" g++-14 libpugixml-dev libexpat1-dev libxml2-dev xkb-data

  step "Installing Ghostty"
  install_ghostty

  # Debian names fd "fdfind".
  if ! have fd && have fdfind; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi

  if ((${#SKIPPED_PKGS[@]})); then
    info "Not available on this release (built from source or optional): ${SKIPPED_PKGS[*]}"
  fi

  # shellcheck source=build.sh
  source "$INSTALL_DIR/build.sh"
  USE_XDPW=false
  build_all
  if $USE_XDPW; then
    apt_install xdg-desktop-portal-wlr
  fi

  if $WITH_TAILSCALE && ! have tailscale; then
    step "Installing Tailscale (tailscale.com/install.sh)"
    curl -fsSL https://tailscale.com/install.sh | as_root sh
  fi
  if $WITH_RAZER; then
    as_root gpasswd -a "$USER" plugdev >/dev/null 2>&1 || true
    as_root gpasswd -a "$USER" openrazer >/dev/null 2>&1 || true
  fi
}
