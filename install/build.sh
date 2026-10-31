# Source builds for Debian and Ubuntu, whose packages are too old for
# Hyprland 0.56 (Lua config) and Quickshell. Sourced by install.sh.
#
# Everything lands in $PREFIX (/opt/aayork-desktop), linked with an rpath so
# the system's own libraries are never replaced: GNOME or KDE on the same
# machine keep using the distro's libinput, Qt and so on. Only what the
# system lacks, or has too old, is built. Programs are linked into
# /usr/local/bin, and the few files other programs look for (the session
# entry, the portal's D-Bus files) are copied where those programs look;
# every file placed outside $PREFIX is listed in $PREFIX/placed-files.
#
# Versions match a known-good Arch install (October 2026).

PREFIX=${PREFIX:-/opt/aayork-desktop}
BUILD_ROOT=${BUILD_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/aayork-desktop-build}
JOBS=${JOBS:-$(nproc)}

V_CMAKE=3.31.12
V_GCC=16.2.0
V_LUA=5.5.1
V_WAYLAND=1.24.0
V_WAYLAND_PROTOCOLS=1.49
V_XKBCOMMON=1.13.1
V_LIBINPUT=1.31.3
V_DISPLAY_INFO=0.3.0
V_XCB_ERRORS=1.0.1
V_QT=6.10.2
V_CPPTRACE=v1.0.4-unwind
V_HYPRWAYLAND_SCANNER=v0.4.6
V_HYPRLAND_PROTOCOLS=v0.7.0
V_HYPRUTILS=v0.14.3
V_HYPRLANG=v0.6.8
V_HYPRCURSOR=v0.1.13
V_HYPRGRAPHICS=v0.5.1
V_HYPRWIRE=v0.3.1
V_AQUAMARINE=v0.15.1
V_HYPRLAND=v0.56.2
V_HYPRSUNSET=v0.4.0
V_HYPRPICKER=v0.4.7
V_XDPH=v1.4.1
V_QUICKSHELL=v0.3.2
V_GSR=6.1.5

build_env() {
  local triplet
  triplet=$(gcc -dumpmachine 2>/dev/null || echo x86_64-linux-gnu)
  export PATH="$PREFIX/bin:$BUILD_ROOT/tools/bin:$PATH"
  export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:$PREFIX/lib/$triplet/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  export CMAKE_PREFIX_PATH="$PREFIX"
  # RUNPATH, so the built programs find each other's libraries in $PREFIX
  # without LD_LIBRARY_PATH leaking into everything they start.
  export LDFLAGS="-Wl,-rpath,$PREFIX/lib ${LDFLAGS:-}"
  mkdir -p "$BUILD_ROOT/src" "$BUILD_ROOT/tools"
}

# Hyprland 0.56 uses C++23/26 library features (vector::append_range,
# ranges::starts_with...) that only GCC 16's libstdc++ has. Use the system
# GCC if it is 16+, else the g++-16 package (Ubuntu 26.04), else GCC 16
# built once into $PREFIX/toolchain (Debian 13, Ubuntu 24.04).
gcc_major() { "$1" -dumpversion 2>/dev/null | cut -d. -f1; }

need_gcc() {
  local v; v=$(gcc_major g++)
  [[ -n $v ]] && ((v >= 16)) && return 1
  have g++-16 && (( $(gcc_major g++-16) >= 16 )) && return 1
  [[ -x $PREFIX/toolchain/bin/g++ ]] && (( $(gcc_major "$PREFIX/toolchain/bin/g++") >= 16 )) && return 1
  return 0
}
build_gcc() {
  progress "This one takes a while (20 minutes to over an hour, depending on the machine)."
  local src; src=$(fetch_tar gcc "https://ftp.gnu.org/gnu/gcc/gcc-$1/gcc-$1.tar.xz")
  mkdir -p "$src/build"
  # Built by the system compiler, with none of the $PREFIX link flags.
  (cd "$src/build" && env -u LDFLAGS -u CC -u CXX ../configure --prefix="$PREFIX/toolchain" \
    --enable-languages=c,c++ --disable-multilib --disable-bootstrap --disable-libsanitizer \
    --disable-nls --with-system-zlib >/dev/null)
  env -u LDFLAGS make -C "$src/build" -j "$JOBS" >/dev/null
  as_root env -u LDFLAGS make -C "$src/build" install >/dev/null
}

pick_compiler() {
  local v; v=$(gcc_major g++)
  if [[ -n $v ]] && ((v >= 16)); then
    export CC=gcc CXX=g++
  elif have g++-16 && (( $(gcc_major g++-16) >= 16 )); then
    export CC=gcc-16 CXX=g++-16
  elif [[ -x $PREFIX/toolchain/bin/g++ ]]; then
    export CC="$PREFIX/toolchain/bin/gcc" CXX="$PREFIX/toolchain/bin/g++"
  else
    die "No GCC 16 to build Hyprland with."
  fi
  info "Compiler: $($CXX --version | head -1)"
  # Programs built by it need its libstdc++ at run time: put a copy beside
  # them in $PREFIX/lib, where their RUNPATH looks first. Everything else on
  # the system keeps using the distro's own.
  local dir lib
  dir=$(dirname "$($CXX -print-file-name=libstdc++.so.6)")
  as_root mkdir -p "$PREFIX/lib"
  for lib in "$dir"/libstdc++.so.6* "$dir"/libgcc_s.so.1; do
    [[ -e $lib && $lib != *.py ]] && as_root cp -a "$lib" "$PREFIX/lib/"
  done
  # Build-time helpers run from the build tree before they are installed.
  export LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
}

# Recorded so a re-run skips what is already built at the same version.
built_at() { [[ "$(cat "$PREFIX/.built/$1" 2>/dev/null)" == "$2" ]]; }
mark_built() { as_root mkdir -p "$PREFIX/.built"; echo "$2" | as_root tee "$PREFIX/.built/$1" >/dev/null; }

fetch_git() { # name url tag [--recursive]
  local dir="$BUILD_ROOT/src/$1"
  rm -rf "$dir"
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$3" ${4:+--recurse-submodules --shallow-submodules} "$2" "$dir"
  echo "$dir"
}

fetch_tar() { # name url
  local dir="$BUILD_ROOT/src/$1"
  rm -rf "$dir" "$dir.tar"; mkdir -p "$dir"
  curl -fsSL -o "$dir.tar" "$2"
  tar -xf "$dir.tar" -C "$dir" --strip-components=1
  rm -f "$dir.tar"
  echo "$dir"
}

# CMake's pkg-config lookup can resolve a library to the distro's copy even
# when pkg-config names ours (a system -L from another module comes first).
# Point any such cache entry at the copy in $PREFIX/lib. Returns 0 if it
# changed something, so the caller knows to configure again.
prefer_prefix_libs() { # builddir
  local cache="$1/CMakeCache.txt" line var path lib changed=1
  [[ -f $cache ]] || return 1
  while IFS= read -r line; do
    var=${line%%:FILEPATH=*}; path=${line#*:FILEPATH=}
    lib=$(basename "$path")
    if [[ $path != "$PREFIX"/* && -e $PREFIX/lib/$lib ]]; then
      sed -i "s|^$var:FILEPATH=.*|$var:FILEPATH=$PREFIX/lib/$lib|" "$cache"
      changed=0
    fi
  done < <(grep -E '^pkgcfg_lib_[^:]+:FILEPATH=/' "$cache")
  return $changed
}

cmake_build() { # srcdir [cmake args...]
  local src=$1; shift
  local args=(-S "$src" -B "$src/build" -G Ninja
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib
    -DCMAKE_INSTALL_RPATH="$PREFIX/lib" -DCMAKE_PREFIX_PATH="$PREFIX" -DBUILD_TESTING=OFF "$@")
  cmake "${args[@]}" >/dev/null
  if prefer_prefix_libs "$src/build"; then cmake "${args[@]}" >/dev/null; fi
  cmake --build "$src/build" -j "$JOBS"
  as_root env PATH="$PATH" cmake --install "$src/build" >/dev/null
}

meson_build() { # srcdir [meson args...]
  local src=$1; shift
  meson setup "$src/build" "$src" --prefix="$PREFIX" --libdir=lib --buildtype=release \
    -Dc_link_args="-Wl,-rpath,$PREFIX/lib" -Dcpp_link_args="-Wl,-rpath,$PREFIX/lib" "$@" >/dev/null
  ninja -C "$src/build" -j "$JOBS"
  as_root env PATH="$PATH" ninja -C "$src/build" install >/dev/null
}

# A line on the terminal from inside a build (whose output goes to its log).
progress() { printf '    %s\n' "$*" >&3; }

# One component: skip it if the system or an earlier run already has it.
component() { # name version need-check-function build-function
  local name=$1 version=$2 needed=$3 builder=$4
  if built_at "$name" "$version"; then ok "$name $version (built earlier)"; return; fi
  if ! "$needed"; then ok "$name: the system's is new enough"; return; fi
  step "Building $name $version"
  local log="$BUILD_ROOT/logs/$name.log" rc
  mkdir -p "$BUILD_ROOT/logs"
  # Not inside an || list, so set -e still stops the build at the first error.
  # The ERR trap would report the subshell's failure a second time.
  trap - ERR
  set +e
  # fd 3 stays on the terminal for progress lines; the rest goes to the log.
  ( set -e; "$builder" "$version" ) 3>&1 >"$log" 2>&1
  rc=$?
  set -e
  trap "$ERR_TRAP" ERR
  if ((rc != 0)); then
    tail -n 25 "$log" >&2
    die "Building $name $version failed. Full log: $log"
  fi
  mark_built "$name" "$version"
  ok "$name $version"
}

# ---- Build tools ---------------------------------------------------------

need_cmake() { ! version_ge "$(cmake --version 2>/dev/null | awk 'NR==1{print $3}')" 3.30; }
build_cmake() {
  local arch; arch=$(uname -m)
  local dir="$BUILD_ROOT/tools"
  curl -fsSL "https://cmake.org/files/v${1%.*}/cmake-$1-linux-$arch.tar.gz" | tar -xz -C "$dir" --strip-components=1
  hash -r
}
# Lives in the build cache, not $PREFIX: only the build needs it.
cmake_tool() {
  if [[ -x $BUILD_ROOT/tools/bin/cmake ]] && version_ge "$("$BUILD_ROOT/tools/bin/cmake" --version | awk 'NR==1{print $3}')" 3.30; then
    ok "cmake (build tool, downloaded earlier)"; return
  fi
  if need_cmake; then step "Downloading CMake $V_CMAKE (build tool only)"; build_cmake "$V_CMAKE"; fi
  ok "cmake $(cmake --version | awk 'NR==1{print $3}')"
}

# ---- Libraries the distro may have too old -------------------------------

need_lua() { ! pkg-config --exists lua5.5 lua-5.5 2>/dev/null && ! pc_ge lua 5.5; }
build_lua() {
  local src; src=$(fetch_tar lua "https://www.lua.org/ftp/lua-$1.tar.gz")
  make -C "$src" -j "$JOBS" linux MYCFLAGS="-fPIC" >/dev/null
  as_root make -C "$src" install INSTALL_TOP="$PREFIX" >/dev/null
  as_root mkdir -p "$PREFIX/lib/pkgconfig"
  as_root tee "$PREFIX/lib/pkgconfig/lua5.5.pc" >/dev/null <<EOF
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: Lua
Description: Lua language engine
Version: $1
Libs: -L\${libdir} -llua -lm -ldl
Cflags: -I\${includedir}
EOF
}

need_wayland() { ! pc_ge wayland-server 1.22.91; }
build_wayland() {
  local src; src=$(fetch_git wayland https://gitlab.freedesktop.org/wayland/wayland.git "$1")
  meson_build "$src" -Ddocumentation=false -Dtests=false -Ddtd_validation=false
}

need_wayland_protocols() { ! pc_ge wayland-protocols 1.49; }
build_wayland_protocols() {
  local src; src=$(fetch_git wayland-protocols https://gitlab.freedesktop.org/wayland/wayland-protocols.git "$1")
  # Its optional C enum headers need wayland-scanner 1.25+. Nothing here uses
  # them (Hyprland and Quickshell read the XML), so skip them on older systems.
  if ! pc_ge wayland-scanner 1.25.0; then
    sed -i "s|^\tsubdir('include/wayland-protocols')|\t# enum headers skipped: wayland-scanner too old|" "$src/meson.build"
  fi
  meson_build "$src" -Dtests=false
}

need_xkbcommon() { ! pc_ge xkbcommon 1.11.0; }
build_xkbcommon() {
  local src; src=$(fetch_git libxkbcommon https://github.com/xkbcommon/libxkbcommon.git "xkbcommon-$1")
  # Keymaps stay the system's: point at /usr/share, not $PREFIX/share.
  meson_build "$src" -Denable-docs=false -Denable-tools=false -Denable-wayland=false \
    -Denable-bash-completion=false -Dxkb-config-root=/usr/share/X11/xkb -Dx-locale-root=/usr/share/X11/locale
}

need_libinput() { ! pc_ge libinput 1.29; }
build_libinput() {
  local src; src=$(fetch_git libinput https://gitlab.freedesktop.org/libinput/libinput.git "$1")
  meson_build "$src" -Dlibwacom=false -Ddebug-gui=false -Dtests=false -Ddocumentation=false \
    -Dudev-dir="$PREFIX/lib/udev" -Dzshcompletiondir=no
}

need_display_info() { ! pc_ge libdisplay-info 0.2.0; }
build_display_info() {
  local src; src=$(fetch_git libdisplay-info https://gitlab.freedesktop.org/emersion/libdisplay-info.git "$1")
  meson_build "$src"
}

# The shell needs Qt 6.9+ (RectangularShadow, among others).
qt_version() { pkg-config --modversion Qt6Core 2>/dev/null || qmake6 -query QT_VERSION 2>/dev/null || echo 0; }
# Hyprland's X11 support; Ubuntu 24.04 does not package it.
need_xcb_errors() { ! pkg-config --exists xcb-errors; }
build_xcb_errors() {
  local src; src=$(fetch_tar xcb-util-errors "https://xorg.freedesktop.org/releases/individual/lib/xcb-util-errors-$1.tar.xz")
  (cd "$src" && ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib" >/dev/null)
  make -C "$src" -j "$JOBS" >/dev/null
  as_root make -C "$src" install >/dev/null
}

need_qt() { ! version_ge "$(qt_version)" 6.9; }
build_qt() {
  # Only the modules Quickshell uses. Takes a while (20-60 minutes). Built
  # with the distro's own compiler, which Qt's release was tested with.
  local m src base="https://download.qt.io/archive/qt/${1%.*}/$1/submodules"
  for m in qtbase qtshadertools qtsvg qtdeclarative qtwayland qtimageformats; do
    progress "Qt: $m ($(date +%H:%M))"
    src=$(fetch_tar "qt-$m" "$base/$m-everywhere-src-$1.tar.xz")
    if [[ $m == qtbase ]]; then
      CC=gcc CXX=g++ cmake_build "$src" -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DFEATURE_sql=OFF \
        -DFEATURE_printsupport=OFF -DFEATURE_xcb=OFF -DFEATURE_xlib=OFF -DINPUT_opengl=desktop \
        -DFEATURE_system_textmarkdownreader=OFF -DCMAKE_DISABLE_FIND_PACKAGE_md4c=ON  # Ubuntu 24.04's md4c CMake files are broken; use Qt's copy
    else
      CC=gcc CXX=g++ cmake_build "$src" -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF
    fi
  done
}

# No Debian or Ubuntu release packages cpptrace, so it is always ours.
build_cpptrace() {
  local src; src=$(fetch_git cpptrace https://github.com/jeremy-rifkin/cpptrace.git "${1%-unwind}")
  # Quickshell's crash handler needs it to unwind with libunwind.
  cmake_build "$src" -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCPPTRACE_UNWIND_WITH_LIBUNWIND=ON
}

# ---- The Hyprland stack (always ours on Debian/Ubuntu) -------------------

always() { true; }

hypr_cmake() { # repo tag [cmake args]
  local repo=$1 tag=$2; shift 2
  local src; src=$(fetch_git "$repo" "https://github.com/hyprwm/$repo.git" "$tag")
  cmake_build "$src" "$@"
}

build_hyprwayland_scanner() { hypr_cmake hyprwayland-scanner "$1"; }
build_hyprland_protocols() {
  local src; src=$(fetch_git hyprland-protocols https://github.com/hyprwm/hyprland-protocols.git "$1")
  meson_build "$src"
}
build_hyprutils()    { hypr_cmake hyprutils "$1"; }
build_hyprlang()     { hypr_cmake hyprlang "$1"; }
build_hyprcursor()   { hypr_cmake hyprcursor "$1"; }
build_hyprgraphics() { hypr_cmake hyprgraphics "$1"; }
build_hyprwire()     { hypr_cmake hyprwire "$1"; }
build_aquamarine()   { hypr_cmake aquamarine "$1"; }
build_hyprland() {
  local src; src=$(fetch_git Hyprland https://github.com/hyprwm/Hyprland.git "$1" --recursive)
  cmake_build "$src" -DNO_HYPRPM=OFF
}
build_hyprsunset() { hypr_cmake hyprsunset "$1"; }
build_hyprpicker() { hypr_cmake hyprpicker "$1"; }

# The Hyprland portal needs PipeWire 1.1.82+ and sdbus-c++ 2. Older releases
# (Ubuntu 24.04) use xdg-desktop-portal-wlr from apt instead, which handles
# screenshots and screen sharing on Hyprland as well.
can_xdph() { pc_ge libpipewire-0.3 1.1.82 && pc_ge sdbus-c++ 2.0.0; }
build_xdph() { hypr_cmake xdg-desktop-portal-hyprland "$1" -DCMAKE_INSTALL_LIBEXECDIR=lib; }

build_quickshell() {
  local src; src=$(fetch_git quickshell https://git.outfoxxed.me/quickshell/quickshell.git "${1%%-qt*}")
  cmake_build "$src" -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DDISTRIBUTOR="aayork-quickshell installer (source build)" -DINSTALL_QML_PREFIX=lib/qt6/qml \
    -DX11=OFF  # X11 panels only; this desktop is Wayland (and our Qt is built without xcb)
}

need_gsr() { ! have gpu-screen-recorder; }
build_gsr() {
  local src; src=$(fetch_git gpu-screen-recorder https://repo.dec05eba.com/gpu-screen-recorder "$1")
  # Plain C; the distro's compiler is fine and more forgiving than GCC 16.
  CC=gcc CXX=g++ meson_build "$src" -Dsystemd=false -Dnvidia_suspend_fix=false -Dcapabilities=true
}

# ---- Placing the results where the rest of the system looks --------------

place() { # source target
  as_root mkdir -p "$(dirname "$2")"
  as_root ln -sfn "$1" "$2"
  grep -qxF "$2" "$PREFIX/placed-files" 2>/dev/null || echo "$2" | as_root tee -a "$PREFIX/placed-files" >/dev/null
}

place_files() {
  step "Linking the built programs into /usr/local/bin"
  local b
  for b in Hyprland hyprctl hyprpm start-hyprland quickshell qs hyprsunset hyprpicker \
           gpu-screen-recorder gsr-kms-server hyprwayland-scanner; do
    [[ -x $PREFIX/bin/$b ]] && place "$PREFIX/bin/$b" "/usr/local/bin/$b"
  done
  ok "linked"

  # Display managers (GDM, LightDM, SDDM) read sessions from /usr/share only.
  local session=/usr/share/wayland-sessions/hyprland.desktop
  if [[ ! -e $session ]] || grep -q "$PREFIX\|/usr/local/bin" "$session"; then
    local exec=/usr/local/bin/Hyprland
    [[ -x $PREFIX/bin/start-hyprland ]] && exec=/usr/local/bin/start-hyprland
    as_root mkdir -p /usr/share/wayland-sessions
    as_root tee "$session" >/dev/null <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland with aayork-quickshell
Exec=$exec
Type=Application
DesktopNames=Hyprland
EOF
    grep -qxF "$session" "$PREFIX/placed-files" 2>/dev/null || echo "$session" | as_root tee -a "$PREFIX/placed-files" >/dev/null
    ok "login screen entry: $session"
  fi

  # The Hyprland portal: D-Bus activation file, portal description, user unit.
  if [[ -e $PREFIX/share/xdg-desktop-portal/portals/hyprland.portal ]]; then
    place "$PREFIX/share/xdg-desktop-portal/portals/hyprland.portal" /usr/share/xdg-desktop-portal/portals/hyprland.portal
    local f
    for f in "$PREFIX"/share/dbus-1/services/*hyprland*.service; do
      [[ -e $f ]] && place "$f" "/usr/share/dbus-1/services/$(basename "$f")"
    done
    for f in "$PREFIX"/lib/systemd/user/*.service; do
      [[ -e $f ]] && place "$f" "/usr/local/lib/systemd/user/$(basename "$f")"
    done
    ok "screen sharing portal registered"
  fi
}

build_all() {
  build_env
  as_root mkdir -p "$PREFIX"

  cmake_tool
  component gcc               "$V_GCC"               need_gcc               build_gcc
  pick_compiler
  component lua               "$V_LUA"               need_lua               build_lua
  component wayland           "$V_WAYLAND"           need_wayland           build_wayland
  component wayland-protocols "$V_WAYLAND_PROTOCOLS" need_wayland_protocols build_wayland_protocols
  component libxkbcommon      "$V_XKBCOMMON"         need_xkbcommon         build_xkbcommon
  component libinput          "$V_LIBINPUT"          need_libinput          build_libinput
  component libdisplay-info   "$V_DISPLAY_INFO"      need_display_info      build_display_info
  component xcb-util-errors   "$V_XCB_ERRORS"        need_xcb_errors        build_xcb_errors
  component qt                "$V_QT"                need_qt                build_qt
  component cpptrace          "$V_CPPTRACE"          always                 build_cpptrace

  component hyprwayland-scanner "$V_HYPRWAYLAND_SCANNER" always build_hyprwayland_scanner
  component hyprland-protocols  "$V_HYPRLAND_PROTOCOLS"  always build_hyprland_protocols
  component hyprutils           "$V_HYPRUTILS"           always build_hyprutils
  component hyprlang            "$V_HYPRLANG"            always build_hyprlang
  component hyprcursor          "$V_HYPRCURSOR"          always build_hyprcursor
  component hyprgraphics        "$V_HYPRGRAPHICS"        always build_hyprgraphics
  component hyprwire            "$V_HYPRWIRE"            always build_hyprwire
  component aquamarine          "$V_AQUAMARINE"          always build_aquamarine
  component hyprland            "$V_HYPRLAND"            always build_hyprland
  component hyprsunset          "$V_HYPRSUNSET"          always build_hyprsunset
  component hyprpicker          "$V_HYPRPICKER"          always build_hyprpicker
  if can_xdph; then
    component xdg-desktop-portal-hyprland "$V_XDPH" always build_xdph
  else
    info "PipeWire or sdbus-c++ is too old for the Hyprland portal; using xdg-desktop-portal-wlr."
    USE_XDPW=true
  fi
  # Quickshell uses Qt's private API, so it is rebuilt whenever Qt changes.
  component quickshell          "$V_QUICKSHELL-qt$(qt_version)" always build_quickshell
  component gpu-screen-recorder "$V_GSR"                 need_gsr build_gsr

  place_files
}

# Takes out everything build_all put on the system.
remove_builds() {
  [[ -d $PREFIX ]] || { info "Nothing built in $PREFIX."; return; }
  local f
  while read -r f; do [[ -n $f ]] && as_root rm -f "$f"; done <"$PREFIX/placed-files" 2>/dev/null
  as_root rm -rf "$PREFIX"
  ok "removed $PREFIX and the files it placed"
}
