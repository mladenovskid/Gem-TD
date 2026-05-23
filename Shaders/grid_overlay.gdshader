shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// ---------------------------------------------------------------
// Uniforms — updated each frame from GDScript
// ---------------------------------------------------------------

// World-space XZ position of the cursor (Y is ignored)
uniform vec3  cursor_world_pos = vec3(0.0);

// Overall opacity of the entire grid (0 = invisible, 1 = full)
// Animated by GDScript for smooth fade in/out on placement mode change
uniform float grid_opacity : hint_range(0.0, 1.0) = 0.0;

// How many world units from cursor the grid is fully visible
uniform float fade_radius : hint_range(1.0, 20.0) = 3.0;

// How many extra units the fade takes to go from full to zero
uniform float fade_softness : hint_range(0.5, 10.0) = 2.0;

// Grid line thickness (fraction of a tile — 0.04 = 4% of tile width)
uniform float line_thickness : hint_range(0.01, 0.2) = 0.04;

// Core line color (cyan/blue glow)
uniform vec4  line_color : source_color = vec4(0.0, 0.85, 1.0, 1.0);

// Glow intensity multiplier
uniform float glow_intensity : hint_range(1.0, 6.0) = 2.5;

// Tile size in world units
uniform float tile_size : hint_range(0.1, 10.0) = 1.0;

// ---------------------------------------------------------------
// Varying
// ---------------------------------------------------------------
varying vec3 world_pos;

// ---------------------------------------------------------------
void vertex() {
	// Pass world-space position to fragment shader
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// ---------------------------------------------------------------
void fragment() {
	// --- Grid lines ---
	// Compute position within tile (0..1 range per tile)
	vec2 tile_uv = fract(vec2(world_pos.x, world_pos.z) / tile_size);

	// Distance from each edge of the tile (0 = on a line, 0.5 = centre)
	vec2 edge_dist = min(tile_uv, 1.0 - tile_uv);
	float min_edge = min(edge_dist.x, edge_dist.y);

	// Is this fragment on a grid line?
	float on_line = 1.0 - smoothstep(line_thickness - 0.01, line_thickness + 0.01, min_edge);

	// --- Radial fade from cursor ---
	float dist_from_cursor = length(vec2(world_pos.x - cursor_world_pos.x,
	                                     world_pos.z - cursor_world_pos.z));

	// 1.0 inside fade_radius, falls to 0.0 over fade_softness units beyond it
	float radial_fade = 1.0 - smoothstep(fade_radius, fade_radius + fade_softness, dist_from_cursor);

	// --- Combine ---
	float final_alpha = on_line * radial_fade * grid_opacity;

	// Glow: brighten the color at line centres
	float glow = (1.0 - smoothstep(0.0, line_thickness * 2.0, min_edge)) * glow_intensity;
	vec3  final_color = line_color.rgb * (1.0 + glow);

	ALBEDO = final_color;
	ALPHA  = final_alpha;
}
