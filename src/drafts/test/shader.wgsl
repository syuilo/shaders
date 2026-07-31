struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) uv: vec2f,
};

const vertices = array(
	vec2f(-1, -1),
	vec2f( 3, -1),
	vec2f(-1,  3),
);

@vertex
fn vs(@builtin(vertex_index) vertexIndex: u32) -> VertexOut {
	let pos = vertices[vertexIndex];
	var output: VertexOut;
	output.position = vec4f(pos, 0, 1);
	output.uv = (pos.xy + 1.0) / 2.0; // -1 ~ +1 -> 0 ~ 1
	return output;
}

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	return vec4f(0.0, 1.0, 0.0, 1.0);
}
