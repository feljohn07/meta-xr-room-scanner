# Project Configuration & Deployment Guide

This document outlines the engine configurations, export presets, hardware targets, and build steps for compiling and deploying the project to Meta Quest headsets.

---

## 1. Engine & Project Settings (`project.godot`)

### Core Graphics & XR Settings
- **Godot Compatibility**: Requires Godot 4.3 or later (configured for Godot 4.7).
- **Rendering Backend**: `gl_compatibility` (OpenGL ES 3.0 / Mobile GL). This profile is specifically chosen for maximum battery life, sustained frame rates, and low thermal overhead on Meta Quest's Qualcomm Snapdragon XR2 Gen 1/2 chipsets.
- **Texture Compression**: `textures/vram_compression/import_etc2_astc = true` ensures textures are packaged in ASTC format for mobile GPUs.

### OpenXR Vendor Configuration
```ini
[xr]
openxr/enabled=true
openxr/reference_space=1                  ; 1 = XR_REFERENCE_SPACE_TYPE_STAGE
shaders/enabled=true
openxr/extensions/meta/passthrough=true
openxr/extensions/meta/render_model=true
openxr/extensions/meta/anchor_api=true
openxr/extensions/meta/scene_api=true
openxr/extensions/meta/environment_depth=true
```

### Global Shader Variables for Environment Depth
In `project.godot`, the following shader globals are declared to pass depth buffers from C++ to the visual shaders:
- `META_ENVIRONMENT_DEPTH_AVAILABLE` (`bool`)
- `META_ENVIRONMENT_DEPTH_TEXTURE` (`sampler2DArray`)
- `META_ENVIRONMENT_DEPTH_PROJECTION_VIEW_LEFT` (`mat4`)
- `META_ENVIRONMENT_DEPTH_PROJECTION_VIEW_RIGHT` (`mat4`)
- `META_ENVIRONMENT_DEPTH_TEXEL_SIZE` (`vec2`)

---

## 2. Meta Quest Export Configuration (`export_presets.cfg`)

The project includes an Android export preset named `"Meta Quest"` configured for device deployment:

### Key Export Flags
| Setting Category | Property Name | Value | Purpose |
| :--- | :--- | :--- | :--- |
| **Architecture** | `architectures/arm64-v8a` | `true` | Required 64-bit ARM architecture for Quest OS. |
| **Build System** | `gradle_build/use_gradle_build` | `true` | Required to merge Android manifest permissions and vendor plugins. |
| **XR Mode** | `xr_features/xr_mode` | `1` | Sets OpenXR runtime initialization. |
| **Vendor Plugin** | `xr_features/enable_meta_plugin` | `true` | Activates `godotopenxrvendors` Meta extension module. |
| **Passthrough** | `meta_xr_features/passthrough` | `2` (Required) | Enables hardware passthrough composition. |
| **Render Models** | `meta_xr_features/render_model` | `2` (Required) | Enables dynamic runtime controller 3D meshes. |
| **Target Devices** | `meta_xr_features/quest_2_support` <br> `meta_xr_features/quest_3_support` <br> `meta_xr_features/quest_pro_support` | `true` <br> `true` <br> `true` | Declares manifest compatibility for Meta Quest 2, Quest 3, and Quest Pro. |

---

## 3. Addon Dependencies

```text
res://addons/
├── common/
│   ├── start_xr.gd                  ; XR lifecycle & refresh rate synchronization
│   ├── viewport_2d_in_3d/           ; 2D UI projected onto 3D quad with ray picking
│   ├── hand_pinch_detector/         ; Hand tracking pinch gestures
│   └── axis3d/, hud/, view_pivot/   ; Spatial helper components
├── godotopenxrvendors/
│   ├── meta/                        ; Meta GDExtension binaries & android libraries (.aar)
│   ├── androidxr/, pico/, etc.      ; Multi-vendor fallback packages
│   └── plugin.gdextension           ; Native extension manifest
└── godot_ai/                        ; Godot AI / MCP editor tooling runtime
```

---

## 4. Build & Deployment Procedure

### Prerequisites
1. **Android SDK & NDK**: Installed via Android Studio (NDK r25c or recommended version for Godot 4.x).
2. **OpenJDK 17**: Configured in Godot's Editor Settings (`Export > Android > Java SDK Path`).
3. **Meta Quest Headset in Developer Mode**: Connected via USB-C or Quest Link/ADB over Wi-Fi.

### Step-by-Step Deployment
1. Connect Meta Quest to computer and confirm authorization:
   ```powershell
   adb devices
   ```
2. In Godot Editor:
   - Select **Project > Export**.
   - Choose the **Meta Quest** preset.
   - Click **Export Project** (or use the one-click **Remote Deploy / Run on Android** button in the upper right corner of the editor).
3. Alternatively, compile and install via command line:
   ```powershell
   godot --headless --export-debug "Meta Quest" ../builds/MetaSceneSample.apk
   adb install -r ../builds/MetaSceneSample.apk
   adb shell am start -n com.godotopenxrvendors.metascenesample/com.godot.game.GodotApp
   ```
