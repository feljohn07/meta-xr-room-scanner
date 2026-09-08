# Changelog

All notable changes, architectural features, fixes, and documentation for the **Meta Scene XR Sample** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
