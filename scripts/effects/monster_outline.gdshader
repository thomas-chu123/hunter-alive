shader_type canvas_item;
render_mode unshaded;

uniform sampler2D silhouette : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 outline_color : source_color;
uniform float width_px = 2.0;

void fragment() {
	vec4 body = textureLod(silhouette, SCREEN_UV, 0.0);
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * TAU / 8.0;
		vec2 offset = vec2(cos(angle), sin(angle)) * SCREEN_PIXEL_SIZE * width_px;
		edge = max(edge, textureLod(silhouette, SCREEN_UV + offset, 0.0).a);
	}
	// The CanvasGroup backbuffer contains premultiplied sprite colors.
	float border_alpha = max(0.0, edge - body.a) * outline_color.a;
	float alpha = body.a + border_alpha;
	vec3 rgb = (body.rgb + outline_color.rgb * border_alpha) / max(alpha, 0.0001);
	COLOR *= vec4(rgb, alpha);
}
