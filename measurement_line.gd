extends Node3D

signal delete_requested(line_node: Node3D)

@onready var start_sphere: MeshInstance3D = $StartSphere
@onready var end_sphere: MeshInstance3D = $EndSphere
@onready var cylinder_mesh_instance: MeshInstance3D = $CylinderLine
@onready var label_3d: Label3D = $Label3D
@onready var badge_area: Area3D = get_node_or_null("BadgeArea")

var point_a := Vector3.ZERO
var point_b := Vector3.ZERO
var distance: float = 0.0
var use_imperial := false
var is_highlighted := false


func _ready() -> void:
	if cylinder_mesh_instance and cylinder_mesh_instance.mesh:
		cylinder_mesh_instance.mesh = cylinder_mesh_instance.mesh.duplicate()
	if point_a != Vector3.ZERO or point_b != Vector3.ZERO:
		update_points(point_a, point_b, use_imperial)


func update_points(p_a: Vector3, p_b: Vector3, p_use_imperial: bool = false) -> void:
	point_a = p_a
	point_b = p_b
	use_imperial = p_use_imperial

	if not is_inside_tree():
		return

	if start_sphere:
		start_sphere.global_position = p_a
		start_sphere.visible = true

	var diff = p_b - p_a
	var dist = diff.length()

	distance = dist

	# Component breakdown: width (X), height (Y), length (Z)
	var dx = absf(diff.x)
	var dy = absf(diff.y)
	var dz = absf(diff.z)

	if dist > 0.005:
		if end_sphere:
			end_sphere.global_position = p_b
			end_sphere.visible = true

		if cylinder_mesh_instance:
			cylinder_mesh_instance.visible = true
			var mid_point = (p_a + p_b) / 2.0

			var dir = diff.normalized()
			var up_vec = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			var x_vec = dir.cross(up_vec).normalized()
			var z_vec = x_vec.cross(dir).normalized()
			cylinder_mesh_instance.global_transform = Transform3D(Basis(x_vec, dir, z_vec), mid_point)

			if cylinder_mesh_instance.mesh is CylinderMesh:
				cylinder_mesh_instance.mesh.height = dist

		if label_3d:
			label_3d.visible = true
			var badge_pos = (p_a + p_b) / 2.0 + Vector3(0, 0.08, 0)
			label_3d.global_position = badge_pos
			if badge_area:
				badge_area.global_position = badge_pos

			if use_imperial:
				var ft_total = dist * 3.28084
				var ft_w = dx * 3.28084
				var ft_l = dz * 3.28084
				var ft_h = dy * 3.28084
				label_3d.text = "%.2f ft\n[W: %.2fft | L: %.2fft | H: %.2fft]" % [ft_total, ft_w, ft_l, ft_h]
			else:
				label_3d.text = "%.2f m\n[W: %.2fm | L: %.2fm | H: %.2fm]" % [dist, dx, dz, dy]
	else:
		if end_sphere:
			end_sphere.visible = false
		if cylinder_mesh_instance:
			cylinder_mesh_instance.visible = false
		if label_3d:
			label_3d.visible = false
		if badge_area:
			badge_area.visible = false


func set_highlight(value: bool) -> void:
	is_highlighted = value
	if not label_3d:
		return
	if is_highlighted:
		label_3d.modulate = Color(1.0, 0.35, 0.35)
		label_3d.outline_modulate = Color(0.6, 0.0, 0.0)
	else:
		label_3d.modulate = Color(0.2, 1.0, 1.0)
		label_3d.outline_modulate = Color(0.0, 0.0, 0.0)
