extends Area3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = get_node_or_null("Label3D")

var color: Color
var label_text: String = ""
var selected := false


func setup_scene(spatial_entity: OpenXRFbSpatialEntity) -> void:
	var data: Dictionary = spatial_entity.custom_data

	color = Color(data.get("color", "#FFFFFF"))
	label_text = str(data.get("label", ""))

	var material: StandardMaterial3D = mesh_instance.get_surface_override_material(0)
	material.albedo_color = color
	mesh_instance.set_surface_override_material(0, material)

	if label_3d and not label_text.is_empty():
		label_3d.text = label_text
		label_3d.visible = true

	spatial_entity.save_to_storage(OpenXRFbSpatialEntity.STORAGE_CLOUD)


func set_selected(p_selected: bool) -> void:
	selected = p_selected

	var material: StandardMaterial3D = mesh_instance.get_surface_override_material(0)
	if selected:
		material.albedo_color = Color(0.5, 0.5, 0.5)
	else:
		material.albedo_color = color
	mesh_instance.set_surface_override_material(0, material)

	if label_3d and not label_text.is_empty():
		label_3d.modulate = Color(1.0, 0.35, 0.35) if selected else Color(1, 1, 1)
