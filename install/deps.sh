# What the desktop needs, in one place. install.sh installs these and
# check.sh verifies them afterwards. Sourced, not run.

# ---- Commands that must exist when the install is done -------------------
# "command|what uses it". Every one of these is checked at the end.
REQUIRED_CMDS=(
  "Hyprland|the compositor"
  "hyprctl|the shell, keybinds and scripts"
  "quickshell|the shell itself"
  "qs|keybinds (shell IPC)"
  "hyprsunset|night light"
  "hyprpicker|colour picker in the screenshot editor"
  "Xwayland|X11 apps"
  "ghostty|terminal"
  "xdg-terminal-exec|opening terminal apps from the launcher"
  "wpctl|volume keys"
  "pactl|audio devices"
  "playerctl|media keys fallback"
  "nmcli|network menu"
  "bluetoothctl|bluetooth menu"
  "brightnessctl|brightness keys"
  "ddcutil|external monitor brightness"
  "grim|screenshots"
  "slurp|screenshot area fallback"
  "wl-copy|clipboard"
  "wl-paste|clipboard history"
  "magick|screenshot editing"
  "ffmpeg|GIF recording"
  "gpu-screen-recorder|screen recording"
  "zbarimg|QR codes in screenshots"
  "tesseract|text recognition in screenshots"
  "jq|scripts"
  "curl|weather, scripts"
  "git|updates"
  "python3|scripts"
  "secret-tool|calendar login storage"
  "notify-send|scripts"
  "xdg-open|opening files and links"
  "xdg-mime|default apps"
  "wtype|typing into windows (emoji, snippets)"
  "fd|file search"
  "locate|file search"
  "qalc|calculator"
  "mpv|screensaver"
  "xsettingsd|Xwayland DPI hint"
  "xrdb|Xwayland settings"
  "fc-list|fonts"
  "gsettings|GTK theme"
  "pkexec|admin prompts"
  "setpriv|Taildrop receiver"
  "timedatectl|night light schedule"
  "systemctl|session"
  "loginctl|session"
)

# Python modules the scripts import: "module|what uses it".
REQUIRED_PY=(
  "gi|file picker"
  "numpy|scrolling capture"
  "PIL|scrolling capture"
  "caldav|calendar"
  "icalendar|calendar"
  "recurring_ical_events|calendar"
)

# Fonts and themes the shell expects.
REQUIRED_FONT="BlexMono Nerd Font"
REQUIRED_ICON_THEME="Colloid"
MIN_HYPRLAND=0.56.0
MIN_QUICKSHELL=0.3.0

# ---- Arch ------------------------------------------------------------------
# Installed with pacman; anything pacman cannot find comes from the AUR.
ARCH_PKGS=(
  # Compositor and shell
  hyprland quickshell qt6-base qt6-declarative qt6-svg qt6-wayland qt6-imageformats
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xorg-xwayland hyprsunset hyprpicker
  polkit gnome-keyring libsecret
  # Audio, network, bluetooth
  pipewire pipewire-pulse pipewire-alsa wireplumber libpulse playerctl
  networkmanager bluez bluez-utils
  # Display
  brightnessctl ddcutil
  # Screenshots and recording
  grim slurp wl-clipboard imagemagick ffmpeg gpu-screen-recorder zbar tesseract tesseract-data-eng
  # Scripts
  jq curl git python python-gobject gtk4 python-numpy python-pillow
  python-caldav python-icalendar python-recurring-ical-events
  libnotify xdg-utils xdg-terminal-exec wtype fd plocate libqalculate mpv
  xsettingsd xorg-xrdb fontconfig libcanberra util-linux procps-ng psmisc unzip
  # Apps and look
  ghostty nautilus firefox
  ttf-ibmplex-mono-nerd noto-fonts noto-fonts-emoji adwaita-cursors
)

# ---- Debian / Ubuntu -------------------------------------------------------
# Runtime packages, by apt name. Anything not available on a release is
# skipped with a warning and either built from source (build.sh) or reported
# by the final check.
DEB_PKGS=(
  # Session plumbing
  dbus-user-session polkitd pkexec gnome-keyring libsecret-tools xwayland
  xdg-desktop-portal xdg-desktop-portal-gtk
  # Audio, network, bluetooth
  pipewire pipewire-pulse pipewire-alsa wireplumber pulseaudio-utils playerctl
  network-manager bluez
  # Display
  brightnessctl ddcutil
  # Screenshots and recording
  grim slurp wl-clipboard imagemagick ffmpeg zbar-tools tesseract-ocr tesseract-ocr-eng
  # Scripts
  jq curl git python3 python3-gi gir1.2-gtk-4.0 python3-numpy python3-pil
  python3-caldav python3-icalendar python3-recurring-ical-events
  libnotify-bin xdg-utils xdg-terminal-exec wtype fd-find plocate qalc mpv
  xsettingsd x11-xserver-utils fontconfig libglib2.0-bin gnome-session-canberra util-linux procps psmisc unzip xz-utils
  # Apps and look
  nautilus fonts-noto-core fonts-noto-color-emoji adwaita-icon-theme
  # Libraries the source-built programs link against at runtime
  libqt6svg6 qt6-wayland
)

# Everything needed to compile the pieces build.sh may have to build.
DEB_BUILD_PKGS=(
  build-essential pkg-config ninja-build meson cmake git curl ca-certificates xz-utils
  python3-pip python3-setuptools bison flex
  # Hyprland and its libraries
  libwayland-dev wayland-protocols libxkbcommon-dev libinput-dev libudev-dev libevdev-dev libmtdev-dev
  libpixman-1-dev libcairo2-dev libpango1.0-dev libdrm-dev libgbm-dev libegl-dev libgles-dev libgl-dev
  libseat-dev libdisplay-info-dev hwdata libliftoff-dev
  libxcb1-dev libxcb-composite0-dev libxcb-errors-dev libxcb-icccm4-dev libxcb-render0-dev
  libxcb-res0-dev libxcb-xfixes0-dev libxcb-ewmh-dev libxcb-util-dev libxcb-present-dev libxcursor-dev libx11-xcb-dev
  libtomlplusplus-dev libzip-dev librsvg2-dev libmagic-dev libjpeg-dev libpng-dev libwebp-dev libheif-dev libjxl-dev
  libre2-dev libmuparser-dev liblcms2-dev glslang-dev glslang-tools libffi-dev uuid-dev libgtest-dev
  liblua5.5-dev libeis-dev libpipewire-0.3-dev libspa-0.2-dev libsdbus-c++-dev libglib2.0-dev
  libgles2-mesa-dev libvulkan-dev
  # Quickshell
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev
  qt6-wayland-dev qt6-wayland-private-dev qt6-shadertools-dev qt6-svg-dev libqt6svg6-dev
  spirv-tools libcli11-dev libjemalloc-dev libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev
  libunwind-dev libdwarf-dev libzstd-dev
  # Qt itself, when the system one is too old (Ubuntu 24.04 bases)
  libfontconfig1-dev libfreetype-dev libharfbuzz-dev libdbus-1-dev libssl-dev libicu-dev
  libxkbcommon-x11-dev libxcb-cursor-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-image0-dev
  libxcb-shm0-dev libxcb-randr0-dev libxcb-shape0-dev libxcb-sync-dev libxcb-xinerama0-dev
  libxcb-xkb-dev libxcb-render-util0-dev libxcb-xinput-dev libmd4c-dev libdouble-conversion-dev libpcre2-dev
  # gpu-screen-recorder
  libavcodec-dev libavformat-dev libavfilter-dev libavutil-dev libswresample-dev libva-dev libcap-dev
  libpulse-dev libxcomposite-dev libxrandr-dev libxfixes-dev libxdamage-dev libdbus-1-dev
  # hyprpicker, hyprsunset
  libjpeg-dev
)

# ---- Optional extras (--with-...) ------------------------------------------
ARCH_PKGS_BOSE=(bluez-utils)
DEB_PKGS_BOSE=(bluez)
ARCH_PKGS_RAZER=(openrazer-daemon python-openrazer python-dbus)
DEB_PKGS_RAZER=(openrazer-meta python3-openrazer python3-dbus)
ARCH_PKGS_THINGS=(go)
DEB_PKGS_THINGS=(golang-go)
ARCH_PKGS_TAILSCALE=(tailscale)
ARCH_PKGS_GREETER=(greetd greetd-tuigreet)
