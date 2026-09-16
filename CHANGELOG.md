# Changelog

All notable changes, architectural features, fixes, and documentation for the **Meta Scene XR Sample** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.1] - 2026-09-16

### Fixed
- **Optical Joint-Distance Pinch Recognition (`hand_pinch_detector.gd`)**:
  - Replaced controller action reliance with real-time Euclidean distance tracking between `HAND_JOINT_THUMB_TIP` and `HAND_JOINT_INDEX_FINGER_TIP` ($d \le 0.024\text{m}$ pinch trigger, $d \ge 0.040\text{m}$ release).
  - Enables 100% reliable bare-hand pinch detection on Meta Quest without requiring OpenXR action map controller emulation bindings.
- **Physical Hand Anchoring for Tablet & Wrist HUD (`main.gd`, `hand_visuals.gd`)**:
  - Dynamically updates `wrist_menu` and `scene_menu_viewport` transforms in `_physics_process()` using `HAND_JOINT_WRIST` and `HAND_JOINT_PALM` when optical tracking is active.
  - Fixes frozen menu positioning caused by stationary `XRController3D` nodes when controllers are placed down.
- **Bare-Hand Aim Ray Alignment (`hand_visuals.gd`, `main.gd`)**:
  - Dynamically calculates the pointer origin from the thumb/index pinch midpoint with forward vector projecting from the wrist through the fingers.

---

## [1.6.0] - 2026-09-16

### Added
- **Phase 3: Optical Hand Tracking & Gesture Interaction**:
  - **OpenXR Hand Tracking Extension (`project.godot`)**: Enabled `openxr/extensions/hand_tracking=true` paired with Meta Quest high-frequency optical hand tracking (`meta_xr_features/hand_tracking=1`, `meta_xr_features/hand_tracking_frequency=1`).
  - **Pinch Gesture Detection (`hand_pinch_detector.gd`, `hand_pinch_detector.tscn`)**:
    - Expanded multi-action detection supporting standard OpenXR triggers, Meta FB hand tracking aim (`index_pinch`, `index_pinch_strength`), and simulated pinches.
    - Continuous pinch strength tracking and signal emission (`pinch_strength_changed(strength)`).
    - Tapped, held, and released gesture routing for far-field distance ray interactions.
    - Off-hand pinch tap opens/closes the Hand-Anchored Digital Tablet with one gesture.
  - **Direct Hand Poke & Near-Field Touch (`hand_poke_interactor.gd`, `hand_poke_interactor.tscn`)**:
    - Index fingertip tracking using OpenXR `XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP` with automatic fallback to controller forward offset.
    - Near-field direct touch API (`poke_at()` and `poke_leave()`) integrated into `viewport_2d_in_3d.gd` allowing direct finger-to-surface interaction on the Hand-Anchored Tablet (`SceneMenuViewport`), Palm/Wrist Watch HUD (`WristMenu`), and CAD workstation controls.
    - Dynamic fingertip proximity indicator (glowing cyan aura that brightens and changes to emerald green upon UI contact).
    - 3D `Area3D` touch collider for direct physical interaction with 3D objects.
  - **Stylized Optical Hand Visuals (`hand_visuals.gd`)**:
    - Dynamically detects and instantiates `OpenXRFbHandTrackingMesh` if Meta runtime hand mesh extension is present.
    - Visual fingertip joint indicators on thumb and index fingers.
    - Dynamic pinch indicator ring (`TorusMesh`) between thumb and index fingertips that animates and scales with pinch proximity.
  - **Seamless Dynamic Controller / Bare Hand Switching**:
    - Real-time detection of hand tracking state without requiring app restart.
    - Automatically hides Quest Touch controller models (`LeftControllerFbRenderModel`, `RightControllerFbRenderModel`) and displays hand visuals when controllers are put down.
    - Ergonomic adaptive mounting for the Hand-Anchored Tablet and Wrist Watch HUD, positioning flush to the wrist joint when bare hands are active.

---

## [1.5.0] - 2026-09-16

### Added
- **Interactive Palm/Wrist Watch HUD (`wrist_menu.tscn`, `wrist_menu.gd`, `wrist_menu_panel.tscn`, `wrist_menu_panel.gd`)**:
  - Compact 2D-in-3D viewport HUD ($360 \times 240$, $0.0004$ pixel scale) mounted on the non-dominant wrist.
  - Glance-angle orientation detection ($\vec{V}_{\text{wrist}} \cdot \vec{V}_{\text{to\_cam}} > 0.35$ with $0.20$ hysteresis) automatically displaying the watch face only when turned toward the user's headset.
  - Quick action controls: Passthrough toggle, Mini CAD dollhouse toggle, Tape measure activate/stop, Undo last measurement, Layout Hub summon, Anchor Color cycling preview, and Dominant Hand switch.
  - Real-time status display showing active layout name, anchor count, and cumulative measurement distance with segment count.
- **Surface-Normal Snapping Laser Reticle Ring (`ReticleRing`)**:
  - 3D Torus mesh with glow unshaded cyan material (`TorusMesh_reticle`, inner radius 0.026m, outer radius 0.034m) attached to `SceneCollidingMesh`.
  - Orthogonal surface-normal alignment in `_physics_process()` with $+3\text{mm}$ offset along the surface normal, eliminating Z-fighting and projecting flush visual feedback on walls, floors, and slanted obstacles.
- **Advanced 3D Measurement Tools & Metric Accumulator**:
  - **Undo Last Segment**: Quick one-tap rollback of the most recently placed 3D measurement segment without clearing the entire session.
  - **Individual Badge Hover & Deletion**: Interactive `BadgeArea` collider ($0.09\text{m}$ radius sphere) on measurement lines with red hover highlight styling and click-to-delete support.
  - **Cumulative Distance Metrics**: Real-time summation of total measured line lengths with unit conversion ($m$ and $\text{ft}$) piped directly into the Wrist HUD and UI Hub.
- **Dominant Hand Preference Toggle & Symmetrical Pointers**:
  - Dynamic `dominant_hand` switching (`"right"` vs `"left"`).
  - Symmetrical `LeftHandPointer` under `XROrigin3D` matching `RightHandPointer` with independent `FunctionPointer`, `ScenePointerMesh`, `SceneCollidingMesh`, `ReticleRing`, and `RayCast3D`.
  - Automatic wrist menu reparenting and transform mirroring to the opposing hand when dominant hand is toggled.
- **Hand-Anchored Scene Menu Tablet (`SceneMenuViewport`)**:
  - Replaced world-fixed 1.2m spawn with an ergonomic handheld tablet anchored directly to the non-dominant controller.
  - Automatically transfers and mirrors between hands when dominant hand is toggled.
  - Scaled pixel size to $0.0005$ ($45\text{cm} \times 30\text{cm}$ handheld clipboard) tilted $-40^\circ$ toward user eyes.
- **Spatial Anchor Customization & Labeling**:
  - Anchor color palette cycling across 8 distinct architectural hues.
  - Active color preview indicator on the wrist HUD.
  - Billboarded `Label3D` node on anchors displaying semantic text labels above pins with red selection highlight styling.
  - Persistent serialization of custom anchor label data in `user://saved_anchor_scenes.json`.

---

## [1.4.0] - 2026-09-16

### Added
- **Tactile Haptic Feedback System**:
  - Integrated `trigger_haptic()` utilizing native OpenXR `"haptic"` vibration output.
  - Distinct vibration profiles for UI button clicks (150Hz / 0.25 amp), anchor creation (120Hz / 0.6 amp), anchor deletion (100Hz / 0.5 amp), tape measure Point A and B locking (120Hz-160Hz), and CAD workstation grab/release (100Hz / 80Hz).
- **Spatial Anchor Coordinate Serialization**:
  - Extended multi-layout storage (`user://saved_anchor_scenes.json`) to persist 3D position (`pos`) and rotation (`rot`) vectors alongside entity custom data.
  - Reconstructed physical anchor positions in `mini_cad_viewer.gd` when previewing inactive saved scenes, preventing dollhouse anchor collapse at the origin.

### Fixed
- **Mini CAD Workstation Grab Hit Testing**:
  - Expanded pointer `RayCast3D.collision_mask` from `6` to `7` (including Layer 1: Virtual Environment), enabling the laser to hit the front handle bar Area3D and pick up the workstation.
- **Environment Depth Material Inversion**:
  - Corrected inverted material assignment in `main.gd` where unoccluded `BLUE_MATERIAL` was erroneously applied when depth occlusion was enabled.
  - Initialized `DepthTestingMesh` on startup with `environment_depth_material.tres` matching initial enabled state.
- **Baseplate Grid Shader Border Alignment**:
  - Replaced hardcoded $0.5\text{m}$ border in `assets/cad_blueprint_grid.gdshader` with dynamic `baseplate_half_size = vec2(0.6, 0.6)` matching the $1.2\text{m}$ baseplate mesh in `mini_cad_viewer.tscn`.
- **Right Controller Input Deduplication**:
  - Removed duplicate scene-level and script-level signal connections from `RightHand`, routing all trigger and action events strictly through `RightHandPointer` to prevent double-firing.
- **Cleaned Orphaned UIDs**:
  - Removed dangling `test_scene_persistence.gd.uid`.

---

## [1.3.0] - 2026-09-08

### Added
- **Mini CAD / Dollhouse Prototype Viewer (`mini_cad_viewer.tscn` / `mini_cad_viewer.gd`)**:
  - Miniature 3D architectural workstation projecting scanned physical rooms, furniture, and spatial anchors.
  - Normalized centering math positioning the miniature room flush on the CAD baseplate.
  - Two custom CAD shaders:
    - `assets/cad_blueprint_grid.gdshader`: Technical blueprint baseplate with major/minor grid lines, coordinate axes ($X, Z$), and glowing borders.
    - `assets/cad_blueprint_surface.gdshader`: Holographic Fresnel edge-glow shader with semantic color classifications (cyan walls, emerald furniture, red portals, deep navy floors).
  - Spatial grab & drag repositioning via front handle bar collider (`Area3D`), allowing users to pick up and place the workstation on physical tables or floating in mid-air.
  - Standard architectural scale presets: **1:10**, **1:20**, **1:25** (default), **1:50**, and **1:100** with smooth scale tweening.
  - CAD viewing perspectives:
    - **3D Isometric View**: Axonometric dollhouse angle ($32^\circ, -45^\circ$).
    - **2D Floorplan View**: Orthogonal top-down blueprint plan view ($90^\circ$).
    - **360° Turntable Orbit**: Continuous hands-free rotation ($0.6\,\text{rad/s}$).
  - Self-contained 2D-in-3D control bezel (`mini_cad_viewer_controls.tscn` / `mini_cad_viewer_controls.gd`).
  - Integration with multi-layout system to preview saved room layouts without altering real-world anchor tracking.
- **UI & Controller Integration**:
  - Added **"🏢 CAD Dollhouse"** button to the main hub menu header (`scene_selector_ui.tscn`).
  - Integrated raycast laser hit testing and grab handling in `main.gd` with automatic synchronization on room scans.
- **Documentation**:
  - Added dedicated documentation in `documentation/mini_cad_viewer.md` and updated navigation index and user workflows.

---

## [1.2.0] - 2026-09-08

### Added
- **Full Project Documentation Suite (`documentation/`)**:
  - `documentation/README.md`: Master documentation hub and component navigation map.
  - `documentation/architecture_overview.md`: Complete system architecture, scene hierarchy, script responsibilities, lifecycle sequence, and 3D collision layer matrices.
  - `documentation/meta_xr_features.md`: Deep dive into Meta OpenXR vendor extensions (Passthrough blend modes, Scene Understanding API, Spatial Anchors, PCF 3x3 Environment Depth Occlusion, and dynamic controller render models).
  - `documentation/systems_and_subsystems.md`: Mathematical and architectural analysis of the 3D tape measure, room dimension estimator, JSON multi-layout persistence hub, and adaptive raycasting.
  - `documentation/project_configuration_and_deployment.md`: Godot engine configurations, Android Quest Gradle export presets, OpenXR Action Map, and addon dependency mapping.
  - `documentation/controls_and_user_guide.md`: Headset controller button mappings, floating UI reference, and step-by-step testing workflows.
- **Git Tracking & Repository Baseline**:
  - Initialized Git repository tracking codebase state and documentation.
  - Enhanced `.gitignore` with Godot 4+ rules, Android APK/AAB build artifact exclusions, and OS temporary file filters.

---

## [1.1.0] - 2026-09-08

### Added
- **Interactive 3D Point-to-Point Tape Measure**:
  - Millimeter-accurate spatial measurement connecting two 3D points in space (`measurement_line.tscn` / `measurement_line.gd`).
  - Real-time laser preview line dynamically tracking right controller pointer position before locking Point B.
  - Dynamic orientation matrix constructing a continuous cylinder between Point A and Point B regardless of arbitrary 3D angles.
  - Billboarded 3D text label displaying total distance with unit-aware conversion (Meters vs Feet).
  - Axis-aligned dimensional delta breakdown: $[W: \Delta X \mid L: \Delta Z \mid H: \Delta Y]$ for evaluating spatial clearances.
- **Automated Room Dimension & Volumetric Estimator**:
  - Automated room bounds calculation in `main.gd` (`calculate_room_dimensions()`).
  - Semantic label extraction identifying physical `"floor"` and `"ceiling"` anchors to compute true room height.
  - Multi-surface world-space AABB corner transformation and collision bounding box fallback.
  - Computed floor area ($m^2$ or $\text{sq ft}$) and total room volume ($m^3$ or $\text{cu ft}$).
- **Multi-Layout Spatial Anchor Persistence Hub**:
  - JSON-based multi-scene management system stored at `user://saved_anchor_scenes.json`.
  - Preset naming shortcuts (*Living Room*, *Office*, *Workspace*, *Play Area*, *Custom Layout*).
  - Dynamic layout switching allowing users to clear the room and repopulate stored anchor sets seamlessly.
  - Legacy backward-compatibility parser migrating existing `user://openxr_fb_spatial_anchors.json` files.
- **Interactive In-Headset UI Hub (`scene_selector_ui.tscn`)**:
  - 2D-in-3D floating interface projected on a QuadMesh via `Viewport2DIn3D`.
  - Two-tab layout separating **📋 Layouts** management from **📐 Measurements & Diagnostics**.
  - Interactive hover animations with directional status hints and tactile button feedback.

### Fixed & Optimized
- **Trigger Input Debouncing**: Added a 250ms hardware gate (`_last_trigger_press_msec`) to prevent accidental double-anchor placement or unintended duplicate clicks.
- **Raycast Target Prioritization**: Implemented UI intersection testing before world anchor raycasting so laser pointer clicks accurately interact with floating menus without spawning or deleting anchors in the background.
- **Layout Switch Guard**: Added `_is_switching_layout` flag during anchor clearance and restoration to prevent untracking events from prematurely overwriting saved layout files on disk.

---

## [1.0.0] - Initial Foundation

### Added
- **Meta Scene Understanding**:
  - Integration with `OpenXRFbSceneManager`.
  - Semantic surface instantiation with color-coded classification materials (`scene_anchor.gd`).
  - Room triangle mesh extraction with unrolled barycentric coordinates for wireframe rendering (`scene_global_mesh.gd`).
- **Spatial Anchors**:
  - World-locked spatial anchor creation and local/cloud storage persistence (`spatial_anchor.gd`).
  - Surface normal alignment for horizontal floors/ceilings and vertical walls.
- **Environment Depth & Occlusion**:
  - `OpenXRMetaEnvironmentDepth` integration with custom shader (`environment_depth.gdshader`).
  - Soft occlusion using 3x3 Percentage-Closer Filtering (PCF) and bilinear depth texture sampling.
- **Dynamic Meta Controller Models**:
  - `OpenXRFbRenderModel` for runtime Quest 2, 3, and Pro controller mesh loading.
  - Controller material render priority set to `-100` to render beneath depth occlusion buffers.
