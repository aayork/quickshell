# Arch and Arch-based (CachyOS, EndeavourOS, Manjaro...): pacman, then the
# AUR for anything the repos do not carry. Sourced by install.sh.

# yay or paru if one is already there; otherwise yay is built from the AUR.
aur_helper() {
  if have paru; then echo paru; return; fi
  if have yay; then echo yay; return; fi
  step "Installing yay (AUR helper) for packages the repos do not carry"
  as_root pacman -S --needed --noconfirm base-devel git
  local dir
  dir=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$dir/yay-bin"
  (cd "$dir/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$dir"
  have yay || die "yay did not install."
  echo yay
}

install_arch() {
  local pkgs=("${ARCH_PKGS[@]}")
  $WITH_BOSE && pkgs+=("${ARCH_PKGS_BOSE[@]}")
  $WITH_RAZER && pkgs+=("${ARCH_PKGS_RAZER[@]}")
  $WITH_THINGS && pkgs+=("${ARCH_PKGS_THINGS[@]}")
  $WITH_TAILSCALE && pkgs+=("${ARCH_PKGS_TAILSCALE[@]}")
  $WITH_GREETER && pkgs+=("${ARCH_PKGS_GREETER[@]}")

  step "Updating package databases"
  as_root pacman -Sy --noconfirm

  # Split into what the repos have and what must come from the AUR.
  local repo=() aur=() p
  for p in "${pkgs[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1 || pacman -Sg "$p" >/dev/null 2>&1; then
      repo+=("$p")
    else
      aur+=("$p")
    fi
  done

  step "Installing ${#repo[@]} packages with pacman"
  # --needed skips what is already installed, so re-running is cheap.
  as_root pacman -S --needed --noconfirm "${repo[@]}"

  if ((${#aur[@]})); then
    step "Installing from the AUR: ${aur[*]}"
    local helper
    helper=$(aur_helper)
    "$helper" -S --needed --noconfirm "${aur[@]}"
  fi

  if $WITH_RAZER; then
    as_root gpasswd -a "$USER" plugdev >/dev/null 2>&1 || true
    as_root gpasswd -a "$USER" openrazer >/dev/null 2>&1 || true
  fi
}
