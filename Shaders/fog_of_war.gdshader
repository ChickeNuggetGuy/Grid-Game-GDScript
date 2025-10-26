shader_type spatial;
render_mode blend_mix, depth_draw_opaque, world_vertex_coords; // For transparency

// All these uniforms will be set globally by RenderingServer
uniform sampler3D visibility_texture : filter_nearest;
uniform vec3 grid_origin_world;             // Global grid origin
uniform vec2 cell_size_world;               // Global cell size (Correctly a vec2 now)
uniform vec3 texture_resolution;            // Global texture resolution

varying vec3 world_pos_interp;

void vertex() {
    world_pos_interp = VERTEX;
}

void fragment() 
{
    // 1. Offset by grid origin to get position relative to grid
    vec3 relative_pos = world_pos_interp - grid_origin_world;

    // 2. Convert world units to grid cell units
    vec3 grid_coords_float;
    grid_coords_float.x = relative_pos.x / cell_size_world.x; 
    grid_coords_float.y = relative_pos.y / cell_size_world.y; 
    grid_coords_float.z = relative_pos.z / cell_size_world.x; 

    // 3. Normalize to UVW (0.0 to 1.0) for texture sampling
    vec3 uvw = grid_coords_float / texture_resolution;

    // 4. Ensure UVW is within [0,1] range
    uvw = clamp(uvw, vec3(0.0), vec3(1.0)); 

    // 5. Sample your 3D texture
    // We only need one channel (e.g., .r) since R=G=B
    float visibility = texture(visibility_texture, uvw).r; 

    // 6. Set the material's alpha based on visibility (Corrected Logic)
    // VISIBLE (White, ~1.0) -> ALPHA = 0.0 (Transparent)
    // PREVIOUSLY_SEEN (Grey, ~0.5) -> ALPHA = 0.5 (Semi-Transparent)
    // UNSEEN (Black, ~0.0) -> ALPHA = 1.0 (Opaque)

    if (visibility > 0.9) {         // Approximately 1.0 (White)
        ALBEDO = vec3(1.0, 1.0, 1.0);
    } else if (visibility > 0.4) {  // Approximately 0.5 (Grey)
        ALBEDO = vec3(0.5, 0.5, 0.5);               // You can make this 0.7 for a darker "explored" fog
    } else {                        // Approximately 0.0 (Black)
        ALPHA =0.0;
    }
}