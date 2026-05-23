#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  Blendable Build Script
#  Target:  2012 MacBook Pro (Intel HD 4000, OCLP macOS Ventura)
#  Base:    Blender 3.6.x
#  Author:  Blendable Fork
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
BLU='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

header() { echo -e "\n${BLU}${BOLD}▸ $1${NC}"; }
ok()     { echo -e "${GRN}✓ $1${NC}"; }
warn()   { echo -e "${YLW}⚠ $1${NC}"; }
die()    { echo -e "${RED}✗ $1${NC}"; exit 1; }

# ── Paths ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORK_NAME="blendable"
BLENDER_VERSION="v3.6.0"
BLENDER_REPO="https://projects.blender.org/blender/blender.git"
SRC_DIR="${SCRIPT_DIR}/blender-src"
BUILD_DIR="${SCRIPT_DIR}/build"
PATCH_DIR="${SCRIPT_DIR}/patches"
INSTALL_DIR="/Applications/Blendable.app"

# ── System checks ─────────────────────────────────────────────────────────
header "Checking your system"

# macOS version
MACOS_VER=$(sw_vers -productVersion)
echo "  macOS: $MACOS_VER"

# Architecture (2012 MBP is always Intel x86_64)
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
  warn "Expected x86_64 (Intel), got $ARCH. Continuing anyway."
else
  ok "Intel x86_64 confirmed"
fi

# Xcode / Command Line Tools
if ! xcode-select -p &>/dev/null; then
  die "Xcode Command Line Tools not found. Run: xcode-select --install"
fi
ok "Xcode tools found at $(xcode-select -p)"

# CMake
if ! command -v cmake &>/dev/null; then
  die "CMake not found. Install via: brew install cmake"
fi
ok "CMake $(cmake --version | head -1)"

# Homebrew
if ! command -v brew &>/dev/null; then
  warn "Homebrew not found — you may need it for dependencies."
else
  ok "Homebrew found"
fi

# Check for required brew packages
header "Checking build dependencies"
REQUIRED_BREW=(python@3.11 ninja pkg-config jpeg libpng openexr)
MISSING=()
for pkg in "${REQUIRED_BREW[@]}"; do
  if brew list "$pkg" &>/dev/null; then
    ok "$pkg"
  else
    MISSING+=("$pkg")
    warn "$pkg — MISSING"
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  warn "Missing packages. Install with:"
  echo "  brew install ${MISSING[*]}"
  read -rp "Install now? [y/N] " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    brew install "${MISSING[@]}"
  else
    die "Cannot continue without required packages."
  fi
fi

# ── Clone Blender 3.6 ─────────────────────────────────────────────────────
header "Getting Blender $BLENDER_VERSION source"

if [[ -d "$SRC_DIR/.git" ]]; then
  ok "Source already cloned at $SRC_DIR"
  cd "$SRC_DIR"
  git fetch origin --tags
else
  echo "  Cloning from $BLENDER_REPO ..."
  echo "  (this may take a few minutes on slow connections)"
  git clone --depth=1 --branch "$BLENDER_VERSION" "$BLENDER_REPO" "$SRC_DIR"
  ok "Cloned $BLENDER_VERSION"
fi

cd "$SRC_DIR"

# ── Download Blender precompiled libs ─────────────────────────────────────
header "Fetching precompiled libraries"
echo "  Running make update (downloads ~1.5 GB of macOS libs)..."
make update || warn "make update had warnings — usually OK"
ok "Libraries ready"

# ── Apply Blendable patches ───────────────────────────────────────────────
header "Applying Blendable patches"

PATCHES=(
  "01_apple_widgets.patch"
  "02_sf_pro_font.patch"
  "03_apple_colors.patch"
  "04_cocoa_vibrancy.patch"
  "05_layout_spacing.patch"
)

for patch in "${PATCHES[@]}"; do
  PATCH_PATH="${PATCH_DIR}/${patch}"
  if [[ ! -f "$PATCH_PATH" ]]; then
    warn "Patch not found: $patch — skipping"
    continue
  fi

  echo -n "  Applying $patch ... "
  if git apply --check "$PATCH_PATH" &>/dev/null; then
    git apply "$PATCH_PATH"
    ok "applied"
  else
    warn "patch failed to apply cleanly — check $patch manually"
    echo "    Run: git apply --reject $PATCH_PATH"
    echo "    Then fix .rej files and continue"
  fi
done

# ── CMake configuration ───────────────────────────────────────────────────
header "Configuring CMake for Intel HD 4000 / macOS Ventura (OCLP)"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Key flags explained:
#   WITH_METAL_BACKEND=OFF       Intel HD 4000 doesn't support Metal (it's OpenGL only)
#   WITH_OPENGL_BACKEND=ON       Force OpenGL renderer
#   WITH_CYCLES_EMBREE=OFF       AVX2 required; HD 4000 era (Ivy Bridge) has AVX1 only
#   WITH_OIDN=OFF                Intel Open Image Denoise needs AVX2
#   WITH_OPENMP=OFF              Avoids Clang/libomp conflicts on older Xcode
#   DEPLOYMENT_TARGET=10.15      Ventura OCLP still reports 10.15+ ABI for this
#   WITH_CYCLES_OSL=OFF          Reduces compile time; OSL rarely needed
#   WITH_GHOST_WAYLAND=OFF       macOS doesn't use Wayland
#   WITH_HEADLESS=OFF            Keep the GUI (obviously)
#   WITH_PYTHON_MODULE=OFF       We want the .app, not a Python module
#   BLENDER_VERSION_SUFFIX       Brand it as Blendable

cmake ../blender-src \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  \
  -DWITH_METAL_BACKEND=OFF \
  -DWITH_OPENGL_BACKEND=ON \
  \
  -DWITH_CYCLES_EMBREE=OFF \
  -DWITH_OIDN=OFF \
  -DWITH_CYCLES_OSL=OFF \
  -DWITH_OPENMP=OFF \
  \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DWITH_GHOST_WAYLAND=OFF \
  -DWITH_HEADLESS=OFF \
  -DWITH_PYTHON_MODULE=OFF \
  \
  -DWITH_INTERNATIONAL=ON \
  -DWITH_AUDASPACE=ON \
  -DWITH_CODEC_FFMPEG=ON \
  \
  -DBLENDER_VERSION_SUFFIX="-blendable" \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  \
  -DCMAKE_C_FLAGS="-march=ivybridge -O2" \
  -DCMAKE_CXX_FLAGS="-march=ivybridge -O2"
  # ivybridge = 2012 MacBook Pro's CPU (3rd gen Intel Core)
  # This enables the right SSE/AVX1 optimizations without requiring AVX2

ok "CMake configured"
echo ""
echo "  Config written to: $BUILD_DIR"
echo "  Inspect: $BUILD_DIR/CMakeCache.txt"

# ── Build ─────────────────────────────────────────────────────────────────
header "Building Blendable"

# Use all cores minus 1 to keep machine responsive
CORES=$(( $(sysctl -n hw.ncpu) - 1 ))
CORES=$(( CORES < 1 ? 1 : CORES ))

echo "  Using $CORES cores (out of $(sysctl -n hw.ncpu))"
echo "  This takes 20–60 min on a 2012 MBP. Go make a coffee ☕"
echo ""

ninja -j"$CORES"
ok "Build complete"

# ── Install ───────────────────────────────────────────────────────────────
header "Installing to $INSTALL_DIR"

ninja install
ok "Installed"

# Rename binary
if [[ -d "/Applications/Blender.app" && ! -d "/Applications/Blendable.app" ]]; then
  mv /Applications/Blender.app /Applications/Blendable.app
  ok "Renamed to Blendable.app"
fi

# ── Done ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}${BOLD}═══════════════════════════════════════════════════${NC}"
echo -e "${GRN}${BOLD}  Blendable built and installed successfully! 🎉${NC}"
echo -e "${GRN}${BOLD}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  Open with:  open /Applications/Blendable.app"
echo "  Or drag to your Dock from Applications."
echo ""
echo -e "${YLW}  If the app shows a security warning:${NC}"
echo "  System Settings → Privacy & Security → Open Anyway"
echo ""
