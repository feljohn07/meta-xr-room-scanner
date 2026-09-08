# Controls & User Guide

This guide describes all hardware controller mappings, on-screen visual helpers, and step-by-step operational workflows when wearing a Meta Quest headset.

---

## 1. Controller Mapping Reference

```
             LEFT CONTROLLER                          RIGHT CONTROLLER
       +-------------------------+              +-------------------------+
       | [Y] Toggle Passthrough  |              | [B] Toggle Depth Occl.  |
       | [X] Toggle Anchor Vis.  |              | [A] Place Floating Anch.|
       | [Menu] Open Layout Hub  |              | [Trig] Place/Del/UI/Tape|
       +-------------------------+              +-------------------------+
```

### Detailed Button Mapping

| Hand | Button Name | Input Action | Function & Behavior |
| :--- | :--- | :--- | :--- |
| **Left** | **[Y] Button** | `by_button` | **Toggle Passthrough**: Toggles between real-world Mixed Reality passthrough and a virtual gray VR background. |
| **Left** | **[X] Button** | `ax_button` | **Toggle Scene & Anchor Visibility**: Shows or hides all room meshes, spatial anchors, and the right-hand laser pointer. |
| **Left** | **[Menu] Button** | `menu_button` | **Toggle Hub Menu**: Spawns or dismisses the floating **XR Space & Measurement Hub** directly 1.2m in front of the player's view. |
| **Right** | **[Trigger]** | `trigger` / `trigger_click` | **Contextual Action**: <br>• **Over UI**: Clicks buttons/inputs.<br>• **Tape Mode**: Sets Point A (1st click) and Point B (2nd click).<br>• **Over Anchor**: Deletes the targeted anchor.<br>• **Over Surface**: Places a normal-aligned spatial anchor. |
| **Right** | **[A] Button** | `ax_button` | **Place Floating Anchor**: Places a spatial anchor floating in mid-air at the controller's current 3D position. |
| **Right** | **[B] Button** | `by_button` | **Toggle Depth Occlusion**: Toggles real-time environment depth testing on the test cube attached to the right controller. |

---

## 2. Interactive Menu: XR Space & Measurement Hub

The floating menu is opened by pressing the **[Menu]** button on the left controller. It provides two main tabs:

### Tab 1: 📋 Layouts Manager
- **Active Layout Status**: Shows current layout name and count of tracked anchors.
- **Preset Quick-Select**: One-click naming for `"Living Room"`, `"Office"`, `"Workspace"`, `"Play Area"`, or `"Custom Layout"`.
- **Save Layout**: Serializes all placed anchors to disk under the typed or selected name.
- **Switch To / Delete**: Instant switching between different saved room configurations with automatic anchor repopulation.
- **Clear Anchors**: Removes all currently placed anchors from the world.
- **Capture Room**: Triggers Meta Quest's native Room Space Setup wizard.

### Tab 2: 📐 Measurements & Room Bounds
- **Live Room Dimensions**: Automatically displays scanned room **Height**, **Width**, **Length**, **Floor Area**, and **Volume**.
- **Unit Toggle**: Instant conversion between **Metric (meters, m², m³)** and **Imperial (feet, sq ft, cu ft)**.
- **3D Tape Measure Mode**: Activate point-to-point measurement laser.
- **Clear Measurements**: Clears all pinned measurement lines from the world.

---

## 3. Operational Workflows

### Workflow 1: First-Time Room Scanning
1. Put on the headset and launch the application.
2. Press the **[Menu]** button on the left hand to open the Hub.
3. Switch to the **📐 Measurements** tab. If surfaces show `0 scanned`, click **Capture Room**.
4. The Meta OS Space Setup modal will launch. Follow the system instructions to scan your walls, floor, ceiling, and major furniture.
5. Upon returning to the app, the room geometry will automatically render with color-coded semantic materials, and the room dimensions will be calculated.

### Workflow 2: Point-to-Point 3D Distance Measurement
1. Open the Hub and switch to **📐 Measurements**.
2. Click **📏 Start Tape Measure**.
3. Point your right controller laser at the starting corner/surface (Point A) and press **[Trigger]**. A cyan glow sphere will lock to that position.
4. Move your laser to the destination surface (Point B). A real-time preview cylinder and dynamic distance readout will follow your cursor.
5. Press **[Trigger]** again to pin the measurement.
6. The pinned measurement displays the total Euclidean distance plus separate width (X), length (Z), and height (Y) breakdowns.

### Workflow 3: Saving and Switching Layouts
1. Place spatial anchors on your desk, monitors, or walls using the right controller **[Trigger]** or floating **[A]** button.
2. Open the Hub and navigate to **📋 Layouts**.
3. Select a preset (e.g., **Office**) or type a custom name in the input box, then click **Save Layout**.
4. To create another layout, click **Clear Room Anchors**, place new anchors (e.g., for **Play Area**), and save again.
5. Use the **Switch To** buttons in the list to transition between layouts seamlessly.
