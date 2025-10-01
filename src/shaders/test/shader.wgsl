struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) uv: vec2f,
};

@vertex
fn vs(@location(0) position: vec4f) -> VertexOut {
	var output: VertexOut;
	output.position = position;
	output.uv = (position.xy + 1.0) / 2.0;
	return output;
}

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	return vec4f(0.0, 1.0, 0.0, 1.0);
}
