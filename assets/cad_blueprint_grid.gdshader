shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 bg_color : source_color = vec4(0.04, 0.07, 0.12, 0.95);
uniform vec4 grid_major_color : source_color = vec4(0.0, 0.85, 1.0, 0.9);
uniform vec4 grid_minor_color : source_color = vec4(0.12, 0.35, 0.6, 0.5);
uniform vec4 axis_x_color : source_color = vec4(1.0, 0.25, 0.25, 0.95);
uniform vec4 axis_z_color : source_color = vec4(0.25, 1.0, 0.4, 0.95);

uniform float major_spacing : hint_range(0.01, 1.0) = 0.1;
uniform float subdivisions : hint_range(1.0, 20.0) = 5.0;
uniform float line_thickness : hint_range(0.001, 0.05) = 0.003;
uniform float border_thickness : hint_range(0.001, 0.1) = 0.015;
uniform vec4 border_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = local_pos.xz;
	
	float minor_spacing = major_spacing / subdivisions;
	
	// Major grid lines
	vec2 major_grid = abs(fract(uv / major_spacing + 0.5) - 0.5) * major_spacing;
	float major_line = min(major_grid.x, major_grid.y);
	float major_factor = 1.0 - smoothstep(0.0, line_thickness * 1.5, major_line);
	
	// Minor grid lines
	vec2 minor_grid = abs(fract(uv / minor_spacing + 0.5) - 0.5) * minor_spacing;
	float minor_line = min(minor_grid.x, minor_grid.y);
	float minor_factor = 1.0 - smoothstep(0.0, line_thickness, minor_line);
	
	// Center Axes (X axis and Z axis)
	float dist_x_axis = abs(local_pos.z);
	float dist_z_axis = abs(local_pos.x);
	float axis_x_factor = 1.0 - smoothstep(0.0, line_thickness * 2.0, dist_x_axis);
	float axis_z_factor = 1.0 - smoothstep(0.0, line_thickness * 2.0, dist_z_axis);
	
	// Outer Border
	vec2 half_size = vec2(0.5, 0.5); // assumes 1x1 baseplate mesh normalized
	vec2 dist_to_edge = half_size - abs(local_pos.xz);
	float edge_dist = min(dist_to_edge.x, dist_to_edge.y);
	float border_factor = 1.0 - smoothstep(0.0, border_thickness, edge_dist);
	
	// Composite colors
	vec4 col = bg_color;
	col = mix(col, grid_minor_color, minor_factor * grid_minor_color.a);
	col = mix(col, grid_major_color, major_factor * grid_major_color.a);
	col = mix(col, axis_x_color, axis_x_factor * axis_x_color.a);
	col = mix(col, axis_z_color, axis_z_factor * axis_z_color.a);
	col = mix(col, border_color, border_factor * border_color.a);
	
	ALBEDO = col.rgb;
	ALPHA = col.a;
	EMISSION = mix(vec3(0.0), border_color.rgb * 0.5, border_factor) + (major_factor * grid_major_color.rgb * 0.2);
}
