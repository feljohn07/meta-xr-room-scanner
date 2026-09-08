shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 albedo_color : source_color = vec4(0.05, 0.25, 0.45, 0.75);
uniform vec4 edge_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;
uniform float edge_intensity : hint_range(0.0, 5.0) = 1.8;

void fragment() {
	// Fresnel effect for glowing architectural CAD edges
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	
	vec3 final_color = mix(albedo_color.rgb, edge_color.rgb, fresnel * 0.8);
	float final_alpha = mix(albedo_color.a, 1.0, fresnel);
	
	ALBEDO = final_color;
	ALPHA = final_alpha;
	EMISSION = edge_color.rgb * (fresnel * edge_intensity);
}
