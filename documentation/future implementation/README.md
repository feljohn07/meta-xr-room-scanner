# Future Implementations Roadmap

This directory tracks specifications, architectural designs, and implementation plans for forthcoming phases of the **Meta Scene XR Sample** project.

---

## Roadmap Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1 & Phase 2: Engine Fixes, Wrist HUD, 3D Tape, CAD  │  ✅ COMPLETED
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Phase 3: Optical Hand Tracking, Pinches & Direct Poke      │  ✅ COMPLETED
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Step 1: Architectural Room Data Model & Persistence        │  ✅ COMPLETED
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Step 2: 3D Item Catalog & Smart Surface Snapping Spawner   │  📋 PLANNED (READY)
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Step 3: Advanced Hand Tracking Gestures & Ergonomics       │  📋 PLANNED (READY)
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Step 4: Interactive 3D Transformation Gizmos & Collision   │  ⏳ UPCOMING
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Step 5: CAD Dollhouse Real-Time Reimagined Item Sync       │  ⏳ UPCOMING
└─────────────────────────────────────────────────────────────┘
```

---

## Available Specifications

### 🛋️ [Step 2: 3D Premade Item Catalog & Spawner with Smart Surface Snapping](step_2_item_catalog_and_spawner.md)
* **Status**: Specification Finalized / Ready for Implementation
* **Deliverables**:
  1. `item_catalog_manager.gd`: Central item database and procedural 3D furniture generator.
  2. `reimagined_item.gd` & `reimagined_item.tscn`: Interactive 3D placed item node with hover highlights and deletion.
  3. `main.gd` Spawner State Machine: Smart surface snapping (floor elevation drop, wall-flush alignment, ceiling hanging) and ghost preview.
  4. Hand Tablet UI: "🛋️ Catalog" tab with category filtering and item cards.
  5. Multi-Room JSON Persistence: Stores virtual placed items under `reimagined_items` in room profile scans.

### 🖐️ [Step 3: Advanced Hand Tracking Gestures & Ergonomics](step_3_advanced_hand_tracking_gestures.md)
* **Status**: Specification Finalized / Ready for Implementation
* **Deliverables**:
  1. `hand_pinch_detector.gd`: Primary & secondary pinch chords, anti-Heisenberg pre-pinch latching, Euclidean hysteresis.
  2. `pseudo_haptics_audio.gd`: Procedural acoustic transient synthesizer replacing hardware rumble with zero asset dependencies.
  3. `mini_cad_viewer.gd`: Bimanual two-handed pinch-to-scale ($1:100$ to $1:10$) and steering yaw rotation.
  4. `measurement_line.gd`: Two-handed elastic pull-cord 3D tape measure.
  5. `wrist_menu.gd`: Palm-up normal glance tracking with angular hysteresis and spring-damper stabilization.

---

## Upcoming Phases

### 🔄 Step 4: Interactive 3D Transformation Gizmos & Collision Detection
* Full 6-DOF translation, yaw rotation handles, and scale clamping.
* Real-time collision detection preventing placed furniture from clipping through physical scanned walls or other virtual objects.

### 🏢 Step 5: CAD Dollhouse Real-Time Virtual Items Sync
* Bidirectional synchronization between the real-scale room and the miniature CAD blueprint dollhouse viewer (`mini_cad_viewer.gd`).
* Miniaturized furniture models rendered in dollhouse mode with blueprint styling.
