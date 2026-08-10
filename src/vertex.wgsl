struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) screenNdcUv: vec2f,
};

const vertices = array(
	// 1st triangle
	vec2f(-1.0, -1.0),  // center
	vec2f( 1.0, -1.0),  // right, center
	vec2f(-1.0,  1.0),  // center, top

	// 2st triangle
	vec2f(-1.0,  1.0),  // center, top
	vec2f( 1.0, -1.0),  // right, center
	vec2f( 1.0,  1.0),  // right, top
);

@vertex
fn vs(@builtin(vertex_index) vertexIndex: u32) -> VertexOut {
	let screenNdcUv = vertices[vertexIndex];
	var output: VertexOut;
	output.position = vec4f(screenNdcUv, 0.0, 1.0);
	output.screenNdcUv = screenNdcUv;
	return output;
}
