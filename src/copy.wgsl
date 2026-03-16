struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) uv: vec2f,
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
	let pos = vertices[vertexIndex];
	var output: VertexOut;
	output.position = vec4f(pos, 0.0, 1.0);
	output.uv = pos.xy;
	return output;
}

// テクスチャ座標(0~1、+Yが下)に変換
fn convertTexCoords(uv: vec2f) -> vec2f {
	return vec2f(uv.x, -uv.y) * 0.5 + vec2f(0.5);
}

@group(0) @binding(1) var targetSampler: sampler;
@group(0) @binding(2) var targetTexture: texture_2d<f32>;

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	//return textureSample(targetTexture, targetSampler, vec2f(fragData.uv.x, 1.0 - fragData.uv.y));
	//return textureSample(targetTexture, targetSampler, fragData.uv);
	//return mix(textureSample(targetTexture, targetSampler, sampleUv), vec4f(fragData.uv, 0.0, 1.0), 0.9);
	return textureSample(targetTexture, targetSampler, convertTexCoords(fragData.uv));
}
