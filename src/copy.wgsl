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

@group(0) @binding(1) var targetSampler: sampler;
@group(0) @binding(2) var targetTexture: texture_2d<f32>;

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	//return textureSample(targetTexture, targetSampler, vec2f(fragData.uv.x, 1.0 - fragData.uv.y));
	return textureSample(targetTexture, targetSampler, fragData.uv);
}
