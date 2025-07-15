shader_type canvas_item;

varying vec4 vertex_color; 

void vertex() {
	vertex_color = COLOR;
}


void fragment() {
	
	vec4 main_texture = texture(TEXTURE, UV);
	main_texture.r = vertex_color.a;
	main_texture.g = vertex_color.a;
	main_texture.b = 1.0;
	main_texture.a = main_texture.a * vertex_color.a;
	COLOR = main_texture;
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
