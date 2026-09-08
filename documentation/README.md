# Meta Scene XR Sample — Documentation

Welcome to the technical documentation for the **Meta Scene XR Sample** project built with **Godot Engine** (Godot 4.3+ / 4.7) and the **Godot OpenXR Vendors plugin** (`godotopenxrvendors`).

This project demonstrates an enterprise-grade Mixed Reality (MR) application utilizing Meta Quest's advanced spatial computing features, including Scene Understanding, Spatial Anchors, Environment Depth Occlusion, Passthrough, and an interactive 3D measurement and layout management suite.

---

## 📚 Documentation Index

| Document | Description |
| :--- | :--- |
| [**Architecture Overview**](architecture_overview.md) | High-level system architecture, scene tree hierarchy, node responsibilities, and runtime lifecycle. |
| [**Meta XR Features Deep Dive**](meta_xr_features.md) | In-depth breakdown of Meta OpenXR vendor extensions: Passthrough, Scene API, Spatial Anchors, Environment Depth, and Dynamic Render Models. |
| [**Systems & Subsystems Analysis**](systems_and_subsystems.md) | Detailed technical analysis of the 3D Tape Measure, Room Dimension Estimator, Layout Persistence Hub, and Raycast Pointer Interaction. |
| [**Project Configuration & Deployment**](project_configuration_and_deployment.md) | Godot project settings, OpenXR Action Map, Android export presets for Meta Quest, and addon dependencies. |
| [**Controls & User Guide**](controls_and_user_guide.md) | Headset controller bindings, interactive UI instructions, and operational workflows for users and testers. |
| [**Project Changelog**](../CHANGELOG.md) | Detailed version history of all features, enhancements, architecture changes, and bug fixes. |

---

## 🚀 Key Project Capabilities

```
+-------------------------------------------------------------------------------+
|                             Meta Scene XR Sample                              |
+-------------------------------------------------------------------------------+
         |                           |                          |
         v                           v                          v
+------------------+       +-------------------+       +------------------+
| Mixed Reality    |       | Spatial Anchors   |       | Measurement Hub  |
| & Passthrough    |       | & Persistence     |       | & Diagnostics    |
+------------------+       +-------------------+       +------------------+
| - Alpha Blend MR |       | - Point Placement |       | - Live Room Size |
| - Env Depth PCF3 |       | - Cloud/Local I/O |       | - 3D Tape Metric |
| - FB Controllers |       | - Multi-Layout UI |       | - Axis Delta W/L |
+------------------+       +-------------------+       +------------------+
```

1. **Passthrough & Dynamic Occlusion**: Seamlessly toggle between full VR and color passthrough with real-time environment depth occlusion (PCF 3x3 soft filtering) preventing virtual objects from improperly clipping over real-world furniture or hands.
2. **Meta Scene Understanding**: Automatically queries and parses room geometry captured by Meta's Space Setup (walls, floor, ceiling, doors, windows, tables, couches, global triangle mesh).
3. **Spatial Anchor Management**: Create, delete, and persist custom spatial entities in 3D space with local and cloud storage capabilities.
4. **Layout Saving & Switching**: Save anchor configurations under multiple named layout presets (e.g., *Living Room*, *Office*, *Workspace*) with disk persistence (`user://saved_anchor_scenes.json`).
5. **Real-time Room Dimension Estimator**: Automatically calculates room height, width, length, floor area, and volume based on detected semantic bounding boxes and surface meshes.
6. **Point-to-Point 3D Tape Measure**: Interactive laser-guided measurement system allowing users to pin measurements in 3D space with dual metric/imperial readouts and axis-aligned delta breakdowns.
