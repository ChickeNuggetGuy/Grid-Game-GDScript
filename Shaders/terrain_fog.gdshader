// terrain_fog.gdshader
shader_type spatial;

uniform sampler2D visibility_texture : hint_default_white;
uniform sampler2D terrain_texture : hint_default_white; // Your original terrain texture
uniform vec2 world_offset = vec2(0.0, 0.0); // Offset of this terrain chunk in world space
uniform vec2 grid_size = vec2(32.0, 32.0);
uniform float cell_size = 1.0;
uniform vec4 fog_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float fog_blend : hint_range(0.0, 1.0) = 0.8;

varying vec3 world_position;

void vertex() {
    world_position = VERTEX;
}

void fragment() {
    // Convert world position to grid coordinates
    vec2 world_pos_2d = vec2(world_position.x, world_position.z);
    vec2 grid_coord = (world_pos_2d - world_offset) / cell_size;
    
    // Normalize to texture coordinates (0-1)
    vec2 visibility_uv = grid_coord / grid_size;
    
    // Sample visibility if within bounds
    float visibility = 1.0;
    if (visibility_uv.x >= 0.0 && visibility_uv.x <= 1.0 && 
        visibility_uv.y >= 0.0 && visibility_uv.y <= 1.0) {
        visibility = texture(visibility_texture, visibility_uv).r;
    }
    
    // Sample original terrain texture
    vec3 terrain_color = texture(terrain_texture, UV).rgb;
    
    // Blend with fog based on visibility
    ALBEDO = mix(fog_color.rgb, terrain_color, visibility);
    
    // Optional: Add some transparency for fog effect
    ALPHA = mix(fog_blend, 1.0, visibility);
}