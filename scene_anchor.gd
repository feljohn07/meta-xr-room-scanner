extends Node3D

const MATERIAL = preload("res://assets/cross-grid-material.tres")

@onready var label: Label3D = $Label3D
@onready var static_body: StaticBody3D = $StaticBody3D

var mesh_instance: MeshInstance3D


func setup_scene(entity: OpenXRFbSpatialEntity) -> void:
	var semantic_labels: PackedStringArray = entity.get_semantic_labels()

	label.text = ", ".join(Array(semantic_labels).map(func(x): return x.capitalize()))

	var collision_shape = entity.create_collision_shape()
	if collision_shape:
		static_body.add_child(collision_shape)

	mesh_instance = entity.create_mesh_instance()
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.1, 0.1, 0.1)
		mesh_instance.mesh = box_mesh

	# Adjust the material for the entity type.
	var material: StandardMaterial3D = MATERIAL.duplicate()
	if semantic_labels.size() > 0:
		material.albedo_color = _get_color_for_label(semantic_labels[0])
	if mesh_instance.mesh is BoxMesh:
		material.uv1_scale = Vector3(3, 2, 1)
	mesh_instance.set_surface_override_material(0, material)
	add_child(mesh_instance)

	# Add vibrant blue glowing wireframe bounding box overlay (as seen in Meta Quest room scan review)
	var aabb = mesh_instance.get_aabb()
	if aabb.size.length() > 0.05:
		var wire_color = Color(0.0, 0.85, 1.0) # Vibrant Meta cyan
		var wire_overlay = _create_wireframe_box(aabb.size, wire_color)
		wire_overlay.position = aabb.position + aabb.size * 0.5
		add_child(wire_overlay)


func _create_wireframe_box(size: Vector3, color: Color) -> MeshInstance3D:
	var wire = MeshInstance3D.new()
	wire.name = "WireframeBoundingBox"
	var im = ImmediateMesh.new()
	var h = size * 0.5

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var pts = [
		# Bottom 4 edges
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z),
		# Top 4 edges
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
		Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z),
		# 4 vertical corner edges
		Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for p in pts:
		im.surface_add_vertex(p)
	im.surface_end()

	wire.mesh = im
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	wire.material_override = mat

	return wire


func _get_color_for_label(semantic_label) -> Color:
	match semantic_label:
		"ceiling", "floor":
			return Color(0.02, 0.05, 0.1, 0.3)
		"wall_face", "invisible_wall_face":
			return Color(0.0, 0.3, 0.6, 0.35)
		"window_frame", "door_frame":
			return Color(0.0, 0.6, 0.9, 0.4)
		"couch", "table", "bed", "lamp", "plant", "screen", "storage":
			return Color(0.0, 0.5, 0.8, 0.35)

	return Color(0.1, 0.4, 0.7, 0.3)

