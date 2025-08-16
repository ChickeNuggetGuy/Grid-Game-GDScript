shader_type spatial;

uniform sampler2D ground_texture : source_color, filter_linear_mipmap,
    repeat_enable;

global uniform sampler2D fog_map : source_color, filter_nearest,
    repeat_disable;
global uniform vec2 fog_dims;    // texture size in pixels (grid W,H)
global uniform vec2 map_origin;  // world-space XZ of grid origin
global uniform vec2 cell_size;   // world units per cell (X,Z)
global uniform int fog_debug = 0; // 0=normal, 1=UV, 2=fog RG
uniform vec4 explored_tint : source_color =
    vec4(0.5, 0.5, 0.5, 1.0);
uniform vec3 unseen_color : source_color = vec3(0.0);

varying vec3 v_world_pos;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec4 base = texture(ground_texture, UV);

    // World -> grid -> fog texture UV (sample pixel centers)
    vec2 grid_xy = (v_world_pos.xz - map_origin) / cell_size;
    vec2 uv = (floor(grid_xy) + 0.5) / fog_dims;
    uv = clamp(uv, vec2(0.0), vec2(1.0));

    vec2 rg = texture(fog_map, uv).rg; // R=visible, G=explored
    float vis = rg.r;
    float explored = rg.g;

    // Discard fragment if not visible AND not previously seen
    if (vis < 0.5 && explored < 0.5) {
        discard;
    }

    // Color based on visibility state
    vec3 col = base.rgb;
    if (vis >= 0.5) {
        // Visible cell - use base color
        col = base.rgb;
    } else if (explored >= 0.5) {
        // Previously seen cell - apply tint
        col = base.rgb * explored_tint.rgb;
    } else {
        // Unseen cell - should be discarded above, but just in case
        col = unseen_color;
    }

    ALBEDO = col;
}