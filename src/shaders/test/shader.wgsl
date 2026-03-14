struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) uv: vec2f,
};

@vertex
fn vs(@builtin(vertex_index) vertexIndex: u32) -> VertexOut {
	let pos = array(
    vec2f(-1, -1),
    vec2f( 3, -1),
    vec2f(-1,  3),
  );

	let xy = pos[vertexIndex];

	var output: VertexOut;
	output.position = vec4f(xy, 0, 1);
	output.uv = (xy.xy + 1.0) / 2.0;
	return output;
}

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	return vec4f(0.0, 1.0, 0.0, 1.0);
}
