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
│  Step 3: Interactive 3D Transformation Gizmos & Collision   │  ⏳ UPCOMING
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│  Step 4: CAD Dollhouse Real-Time Reimagined Item Sync       │  ⏳ UPCOMING
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

---

## Upcoming Phases

### 🔄 Step 3: Interactive 3D Transformation Gizmos & Collision Detection
* Full 6-DOF translation, yaw rotation handles, and scale clamping.
* Real-time collision detection preventing placed furniture from clipping through physical scanned walls or other virtual objects.

### 🏢 Step 4: CAD Dollhouse Real-Time Virtual Items Sync
* Bidirectional synchronization between the real-scale room and the miniature CAD blueprint dollhouse viewer (`mini_cad_viewer.gd`).
* Miniaturized furniture models rendered in dollhouse mode with blueprint styling.
