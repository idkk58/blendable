# Blendable
### Blender 3.6 — Apple-native UI fork for macOS

> A full code-level reskin of Blender 3.6 to match macOS Ventura's design language.  
> Targeted at 2012 MacBook Pro running macOS Ventura via OCLP.

---

## What's different from stock Blender

| Area | Stock Blender | Blendable |
|------|--------------|-----------|
| Corner radius | 4px, boxy | 10px, Apple-style rounded |
| Button fill | Dark gradient bevel | Flat, off-white, no gradient |
| Font | DroidSans | SF Pro (system font) |
| Button height | 20px | 26px (HIG minimum touch target) |
| Item spacing | 2px | 5px |
| Colors | Dark theme default | Light mode, Apple system palette |
| Accent color | Orange | Apple Blue `#0A84FF` |
| Window | Blender chrome | Unified title bar, traffic lights |
| Sidebar | Solid color | NSVisualEffectView frosted glass blur |
| Separators | Heavy black line | Hairline `#C6C6C8` @ 50% opacity |
| Checkboxes | Hard square | Rounded square, accent-filled |
| Sliders | Blender default | Pill track, white circular thumb |
| Menu popups | Opaque dark | Translucent, Ventura menu style |
| Shadows | Blocky | Feathered, 10% alpha |
| GPU renderer | Metal (default) | OpenGL (Intel HD 4000 compatible) |

---

## Requirements

- **Machine:** 2012 MacBook Pro (any model — 13", 15", Retina or non-Retina)
- **CPU:** Intel Core i5/i7 (Ivy Bridge, 3rd gen) — the patches target `ivybridge` arch
- **GPU:** Intel HD 4000 (or NVIDIA 650M if 15") — OpenGL 4.1 supported, Metal is NOT
- **macOS:** Ventura 13.x via [OpenCore Legacy Patcher](https://dortania.github.io/OpenCore-Legacy-Patcher/)
- **Xcode:** 14.x or 13.x (from App Store or developer.apple.com)
- **Homebrew:** [brew.sh](https://brew.sh)
- **Disk space:** ~8 GB for source + build
- **Time:** 20–60 min to compile

---

## Quick Start

```bash
# 1. Clone this fork
git clone https://github.com/YOUR_USERNAME/blendable.git
cd blendable

# 2. Make build script executable
chmod +x build.sh

# 3. Build (the script handles everything)
./build.sh
```

The script will:
1. Check your system and install missing brew packages
2. Clone Blender 3.6 source
3. Download precompiled macOS libraries (~1.5 GB)
4. Apply all 5 patches
5. Configure CMake with Intel HD 4000–safe flags
6. Build with all available CPU cores
7. Install to `/Applications/Blendable.app`

---

## Patch Files Explained

```
patches/
├── 01_apple_widgets.patch    # Rounded corners, flat buttons, pill sliders, 
│                             # Apple-style checkboxes, soft shadows
│
├── 02_sf_pro_font.patch      # Replace DroidSans with SF Pro (system font).
│                             # Falls back gracefully if SF Pro isn't at the
│                             # expected path (OCLP installs vary).
│
├── 03_apple_colors.patch     # Full Apple Ventura light-mode color palette
│                             # baked into C defaults. No .xml theme needed.
│
├── 04_cocoa_vibrancy.patch   # GHOST/Cocoa window patches:
│                             # - NSVisualEffectView blur in sidebar
│                             # - Unified transparent title bar
│                             # - Traffic light preserved (close/min/max)
│                             # - Rounded window corners
│
└── 05_layout_spacing.patch   # Apple HIG spacing: taller buttons (26px),
                              # wider sidebar, more item padding, lighter
                              # separator lines, slightly larger icons
```

---

## Applying Patches Manually

If `build.sh` fails on a patch, you can apply manually:

```bash
cd blender-src

# Apply a single patch
git apply ../patches/01_apple_widgets.patch

# If it fails, apply with rejection files to see what conflicted
git apply --reject ../patches/01_apple_widgets.patch
# Fix the .rej files, then:
git add -A && git apply --cached ../patches/01_apple_widgets.patch
```

---

## Performance Notes for Intel HD 4000

The 2012 MBP's GPU is old but capable enough for Blender 3.6 with some caveats:

**Works great:**
- Eevee (real-time renderer) — OpenGL 4.1 compatible ✓
- Workbench renderer ✓
- Viewport solid + material preview ✓
- Compositing ✓

**Works but slow:**
- Cycles CPU rendering — use it, just slow
- Cycles GPU (OpenCL) — Blender 3.6 drops OpenCL; use CPU instead

**Not available:**
- Cycles GPU via Metal — Intel HD 4000 has no Metal support
- OIDN denoiser — requires AVX2 (HD 4000's Ivy Bridge has AVX1 only)

**Tip:** In Render Properties, set Cycles Device to **CPU** and enable the
**NLM denoiser** (it runs on CPU and works fine).

---

## Troubleshooting

### "Blendable.app is damaged and can't be opened"
```bash
xattr -cr /Applications/Blendable.app
```
Then try opening again.

### Blender crashes on launch (GPU error)
Make sure the build used `WITH_METAL_BACKEND=OFF`. Check:
```bash
grep METAL build/CMakeCache.txt
# Should show: WITH_METAL_BACKEND:BOOL=OFF
```

### SF Pro font not loading (console says "falling back to DroidSans")
Check if SFNS.ttf exists:
```bash
ls /System/Library/Fonts/SFNS.ttf
```
If missing (some OCLP configs differ):
```bash
ls /Library/Fonts/ | grep -i SF
# Copy the path it shows into patches/02_sf_pro_font.patch
# and rebuild
```

### Build fails: "AVX2 instructions not supported"
This means a dependency was compiled with AVX2 by mistake. Make sure:
```cmake
-DWITH_CYCLES_EMBREE=OFF
-DWITH_OIDN=OFF
-DCMAKE_C_FLAGS="-march=ivybridge -O2"
```
are all set in CMake (they should be via `build.sh`).

### Vibrancy/blur not showing
The `04_cocoa_vibrancy.patch` requires macOS 11+. Ventura via OCLP satisfies this.
Check the OCLP post-install patches are applied (especially the GPU drivers patch).

---

## Building with Just Specific Patches

Want the font and colors but not the Cocoa vibrancy (which requires Obj-C changes)?

```bash
# Only apply patches 01, 02, 03, 05 — skip 04
for p in 01 02 03 05; do
  git apply ../patches/0${p}_*.patch
done
```

---

## License

Blendable's patches are released under **GPL-2.0-or-later**, matching Blender itself.

Blender is © Blender Foundation. Blendable is an unofficial fork and is not affiliated
with or endorsed by the Blender Foundation or Blender Institute.

SF Pro is © Apple Inc. It is used as a system font accessed via macOS system paths
and is not redistributed by this project.

---

## Credits

Built for the 2012 MacBook Pro community keeping their machines alive with OCLP. ❤️
