# Step 2: 3D Premade Item Catalog & Spawner with Smart Surface Snapping

## Overview
This specification details the architecture, data models, interaction flow, and persistence pipelines for **Step 2** of the **Space Reimagining Engine** within the [Meta Scene XR Sample](https://github.com/feljohn07/meta-xr-room-scanner).

The objective is to allow users to select from a rich catalog of 3D architectural furniture and decor items, preview them dynamically with smart surface snapping (floor, wall, ceiling), place them in the scanned room environment, and persist them into the room's architectural profile.

---

## 1. System Architecture

```
                                  Hand Tablet UI
                            (scene_selector_ui.tscn)
                         [ New Tab: "🛋️ Item Catalog" ]
                         - Seating, Bedroom, Wall, Lights
                         - Item Spec Cards & Spawn Buttons
                                       │
                         select_item_to_spawn(item_id)
                                       │
                                       ▼
                                    main.gd
                         [ Item Spawner State Machine ]
                         - Active Ghost Preview Instance
                         - Real-Time Pointer Ray Tracking
                                       │
                 ┌─────────────────────┴─────────────────────┐
                 │                                           │
       Surface Snapping Engine                     Pointer Trigger / Pinch
     (Floor / Wall / Ceiling Snapping)               Confirm 3D Placement
                 │                                           │
                 ▼                                           ▼
       RoomDataManager Queries                    ReimaginedItem (Node3D)
  - get_floor_elevation()                     - Procedural 3D Mesh
  - get_nearest_wall()                        - Area3D Hover & Delete
  - get_ceiling_elevation()                   - Billboard Info Label
                                              - Persisted to Room Spec
```

---

## 2. Component Breakdown

### 2.1 Item Catalog Manager (`item_catalog_manager.gd`)
The centralized catalog data provider and procedural 3D model generator.

* **Item Specification Structure**:
  * `id`: Unique identifier (e.g., `"sofa_3seater"`, `"queen_bed"`, `"tv_flat_65"`, `"minimal_pendant"`, `"desk_modern"`).
  * `name`: Display title.
  * `category`: `"seating"`, `"bedroom_storage"`, `"tables"`, `"wall_decor"`, `"lighting"`.
  * `placement_type`:
    * `"floor"`: Snaps down to floor plane, upright, yaw rotation.
    * `"wall"`: Snaps flush against nearest wall face, aligns with wall normal vector.
    * `"ceiling"`: Snaps up to ceiling plane, hangs downward.
  * `dimensions`: `Vector3(width, height, depth)` in meters.
  * `color_primary` & `color_secondary`: Palette for procedural styling.

* **Catalog Items**:
  | Category | ID | Name | Placement | Dimensions ($W \times H \times D$) |
  | :--- | :--- | :--- | :--- | :--- |
  | **Seating** | `sofa_3seater` | Modern 3-Seater Sofa | Floor | $2.20\text{m} \times 0.85\text{m} \times 0.95\text{m}$ |
  | **Seating** | `armchair_accent` | Accent Armchair | Floor | $0.85\text{m} \times 0.80\text{m} \times 0.85\text{m}$ |
  | **Tables** | `coffee_table` | Low Coffee Table | Floor | $1.20\text{m} \times 0.45\text{m} \times 0.60\text{m}$ |
  | **Tables** | `desk_modern` | Minimalist Work Desk | Floor | $1.40\text{m} \times 0.75\text{m} \times 0.70\text{m}$ |
  | **Bedroom** | `queen_bed` | Queen Size Bed | Floor | $1.60\text{m} \times 1.00\text{m} \times 2.10\text{m}$ |
  | **Storage** | `bookshelf_tall` | Tall Bookshelf | Floor / Wall | $0.90\text{m} \times 1.90\text{m} \times 0.35\text{m}$ |
  | **Wall Decor** | `tv_flat_65` | 65" Ultra-Thin Smart TV | Wall | $1.45\text{m} \times 0.85\text{m} \times 0.08\text{m}$ |
  | **Wall Decor** | `art_canvas_large` | Framed Canvas Painting | Wall | $1.20\text{m} \times 0.90\text{m} \times 0.05\text{m}$ |
  | **Wall Decor** | `mirror_vanity` | Architectural Wall Mirror | Wall | $0.70\text{m} \times 1.10\text{m} \times 0.04\text{m}$ |
  | **Lighting** | `minimal_pendant` | Minimalist Pendant Light | Ceiling | $0.40\text{m} \times 0.75\text{m} \times 0.40\text{m}$ |
  | **Lighting** | `ceiling_fan` | Modern 3-Blade Ceiling Fan | Ceiling | $1.20\text{m} \times 0.40\text{m} \times 1.20\text{m}$ |
  | **Lighting** | `floor_lamp_arc` | Arc Floor Lamp | Floor | $0.50\text{m} \times 1.80\text{m} \times 0.90\text{m}$ |

* **Procedural Mesh Builder (`build_item_mesh(item_spec) -> Node3D`)**:
  * Constructs clean, stylized low-poly 3D furniture assemblies using primitives (`BoxMesh`, `CylinderMesh`) and standard PBR materials.
  * Adds corresponding collision shapes for XR laser hover, direct poke interaction, and grab handles.

---

### 2.2 Reimagined Item Entity (`reimagined_item.gd` & `reimagined_item.tscn`)
The interactive 3D node representing a placed virtual furniture entity in the room:

* **Node Hierarchy**:
  ```
  ReimaginedItem (Node3D)
  ├── MeshContainer (Node3D)
  │   └── [Procedural Mesh Primitives]
  ├── SelectionArea (Area3D - Layers 1 & 3)
  │   └── CollisionShape3D (Bounding Box)
  ├── BoundingBoxGizmo (MeshInstance3D - Wireframe Box)
  └── Label3D (Midpoint Billboard Label)
  ```

* **Interactive Features**:
  * **Hover Effect**: Glow outline or badge highlight when laser hovers over the item.
  * **Delete Mode / Badge Click**: Aiming at the midpoint badge turns it red; pulling the trigger deletes the item with haptic confirmation.
  * **Serialization APIs**:
    * `to_dict() -> Dictionary`: Returns `{id, catalog_id, name, placement_type, position, rotation, dimensions}`.
    * `from_dict(data: Dictionary)`: Restores visual mesh, collision, and transform from saved JSON.

---

### 2.3 Smart Surface Snapping Spawner (`main.gd`)
The spawner state machine running during live XR interaction:

* **State Variables**:
  * `item_spawner_active: bool = false`
  * `active_catalog_item: Dictionary = {}`
  * `ghost_preview_node: Node3D = null`
  * `placed_reimagined_items: Array[ReimaginedItem] = []`

* **Surface Snapping Algorithms**:
  1. **Floor Snapping (`placement_type == "floor"`)**:
     * Raycasts against the scanned room collision mesh.
     * Snaps $Y$ elevation to `RoomDataManager.get_floor_elevation(current_room_spec)` (or detected floor collision point).
     * Orientation: Keeps upright ($\vec{Y} = [0, 1, 0]$), yaw rotates to face the player or auto-aligns with the nearest wall plane.
  2. **Wall Snapping (`placement_type == "wall"`)**:
     * Intersects scanned wall meshes via `active_raycast.get_collision_normal()`.
     * Queries `RoomDataManager.get_nearest_wall(ray_point, current_room_spec)`.
     * Snaps item back plane flush against the wall surface ($\vec{Z}_{\text{item}} = \vec{N}_{\text{wall}}$).
     * Clamps vertical height within scanned wall limits ($Y \in [\text{floor\_y} + 0.3\text{m}, \text{ceiling\_y} - 0.3\text{m}]$).
  3. **Ceiling Snapping (`placement_type == "ceiling"`)**:
     * Snaps top surface flush against `RoomDataManager.get_ceiling_elevation(current_room_spec)`.
     * Hangs vertically downwards into the room volume.

* **Ghost Preview Visual Feedback**:
  * Semi-transparent cyan glow material (`Color(0.2, 0.8, 1.0, 0.45)`) when aiming at a compatible surface.
  * Soft amber/red glow when the surface is incompatible (e.g., trying to drop a wall TV onto the floor).

* **Placement Confirmation**:
  * Pulling the trigger (or optical bare-hand pinch tap) instantiates the permanent `ReimaginedItem`.
  * Haptic confirmation profile: $150\text{Hz}$ / $0.65$ amplitude for $60\text{ms}$.
  * Appends item to `current_room_spec["reimagined_items"]` and auto-saves to disk.

---

### 2.4 Hand Tablet Catalog Tab (`scene_selector_ui.tscn` & `scene_selector_ui.gd`)
* **Header Tab**: Dedicated `TabCatalogBtn` ("🛋️ Catalog").
* **Category Filter Pills**: Quick filter bar for "All", "🛋️ Seating", "🛏️ Bedroom", "🖼️ Wall Decor", "💡 Lighting".
* **Scrollable Item Grid**: Renders item cards with:
  * Category icon + Item name.
  * Physical dimensions ($W \times H \times D$).
  * Placement requirement badge ("Floor", "Wall", "Ceiling").
  * One-tap `Spawn` button.
* **Placed Items Management Card**:
  * Shows count of placed virtual items.
  * One-tap `Clear All Items` button.

---

### 2.5 Architectural Room Spec Integration (`room_data_manager.gd`)
* **Schema Extension**:
  ```json
  {
    "reimagined_items": [
      {
        "id": "item_0",
        "catalog_id": "sofa_3seater",
        "name": "Modern 3-Seater Sofa",
        "placement_type": "floor",
        "position": [0.0, -0.05, 1.50],
        "rotation": [0.0, 0.0, 0.0],
        "dimensions": {"width": 2.20, "height": 0.85, "depth": 0.95}
      }
    ]
  }
  ```
* Seamless multi-room persistence under `user://room_scans/<room_name>.json`.

---

## 3. Verification & Quality Gates
1. **GDScript Syntax Check**: `python verify_syntax.py` passes with zero errors.
2. **Godot 4.7 Headless Import**: `Godot_v4.7.2-stable_win64_console.exe --headless --import` completes cleanly with zero parse errors or missing UID warnings.
3. **XR Ergonomics**: Ghost preview and surface snapping behave reliably at 90/120 FPS without jitter or Z-fighting.
4. **Git Sync**: All new scripts, scenes, and documentation are committed and pushed to `feljohn07/meta-xr-room-scanner`.
