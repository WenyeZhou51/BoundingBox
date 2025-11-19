shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.0, 1.0, 0.0, 1.0); // Green
uniform vec4 color2 : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Black
uniform float stripe_width : hint_range(0.01, 0.2) = 0.05; // Width of each stripe
uniform float stripe_angle : hint_range(0.0, 180.0) = 45.0; // Angle of diagonal stripes

void fragment() {
	// Convert angle to radians (pre-calculated for efficiency)
	float angle_rad = stripe_angle * 0.017453292519943295; // PI/180
	
	// Calculate diagonal distance using dot product (very fast)
	// This creates parallel diagonal lines
	float diagonal_distance = dot(UV, vec2(cos(angle_rad), sin(angle_rad)));
	
	// Create repeating pattern using modulo (faster than fract for this use case)
	float pattern = mod(diagonal_distance / stripe_width, 2.0);
	
	// Create binary pattern (either color1 or color2)
	float stripe = step(1.0, pattern);
	
	// Mix colors based on diagonal stripe pattern
	COLOR = mix(color1, color2, stripe);
}

