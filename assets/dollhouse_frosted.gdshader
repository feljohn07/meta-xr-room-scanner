shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Frosted holographic material replicating Meta Quest room capture review aesthetic
uniform vec4 albedo_color : source_color = vec4(0.92, 0.95, 1.0, 0.32);
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.0;
uniform float edge_intensity : hint_range(0.0, 5.0) = 2.2;
uniform float inner_glow : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	// Two-sided fresnel: abs(dot(NORMAL, VIEW)) ensures glowing silhouette on both front and back faces
	float cos_angle = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fresnel = pow(1.0 - clamp(cos_angle, 0.0, 1.0), fresnel_power);

	vec3 final_color = mix(albedo_color.rgb, edge_color.rgb, fresnel * 0.85);
	float final_alpha = clamp(albedo_color.a + fresnel * 0.65, 0.0, 1.0);

	ALBEDO = final_color;
	ALPHA = final_alpha;
	EMISSION = edge_color.rgb * (fresnel * edge_intensity + inner_glow);
}
