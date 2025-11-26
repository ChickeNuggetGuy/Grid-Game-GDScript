shader_type spatial;

uniform sampler2D foliage_texture;
uniform sampler2D foliage_normal;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() 
{
	vec3 texture_color = texture(foliage_texture, UV).rgb;
	float alpha = texture(foliage_texture, UV).a;
	ALBEDO = texture_color;
	ALPHA = alpha;
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
