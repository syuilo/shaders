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

// equivalent to GLSL's mod function
fn modVec2f(a: vec2f, b: vec2f) -> vec2f {
	return a - b * floor(a / b);
}

struct Uniforms {
	aspectRatio: f32,
	time: f32,
	divisions: f32,
	test: u32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;

fn premultiplyAlpha(color: vec4f) -> vec4f {
	return vec4f(color.rgb * color.a, color.a);
}

fn getPixelatedUv(uv: vec2f, cellSize: vec2f) -> vec2f {
	return (cellSize * floor(uv / cellSize)) + (cellSize / 2.0);
}

fn scaleUvToCoverGivenAspectRatio(uv: vec2f, aspectRatio: f32) -> vec2f {
	return uv / vec2f(1.0, aspectRatio) * select(1.0, aspectRatio, 1.0 > aspectRatio);
}

fn rand(uv: vec2<f32>) -> f32 {
	var p3 = fract(vec3<f32>(uv.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

fn linearRisePulse(
	phase: f32, // 0.0～1.0
	riseLength: f32,
) -> f32 {
	let _phase = fract(phase);
	let riseStart = 1.0 - riseLength; // 1周期の最後の riseLength 区間で 0→1
	return clamp((_phase - riseStart) / riseLength, 0.0, 1.0);
}

fn getV(uv: vec2f) -> f32 {
	//let divisions = uniforms.divisions;
	//let lengthField = ((uv.x * 0.5) + (uv.y * 0.5) * divisions) / (divisions * divisions);
	let dutyCycleFactor = 0.25;
	let dutyCycle = max(rand(uv), 0.1) * dutyCycleFactor;
	let phase = fract(uniforms.time * 0.001 * dutyCycle);
	return linearRisePulse(phase, dutyCycle);
}

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	let uv = scaleUvToCoverGivenAspectRatio(fragData.uv, uniforms.aspectRatio);
	let cellSize = vec2f(1.0 / (uniforms.divisions * 0.5));

	let innerDelay = 0.125;
	let transparencyDelay = 0.0;

	var color = vec4f(0.0, 0.0, 0.0, 0.0);

	// ふたつのグリッドを少しずらして重ねることで格子感を薄める
	// NOTE: 3つにするとか、単にオフセットするのではなく回転させるとより不規則になるかもしれない

	let a_modUv = modVec2f(uv, cellSize);
	let a_cellUv = getPixelatedUv(uv, cellSize);
	let a_v = getV(a_cellUv + 1.0);
	let a_dist = distance(a_modUv, cellSize * 0.5);
	let a_radiusMain = a_v;
	let a_radiusInner = (a_v - innerDelay) / (1.0 - innerDelay);
	let a_transparency = max(0.0, a_v - transparencyDelay) / (1.0 - transparencyDelay);
	if (a_dist < a_radiusMain * (cellSize.x * 0.5) && a_dist > a_radiusInner * (cellSize.x * 0.5)) { color = vec4f(1.0, 1.0, 1.0, (1.0 - a_transparency)); }

	let b_modUv = modVec2f(uv + (cellSize * 0.5), cellSize);
	let b_cellUv = getPixelatedUv(uv + (cellSize * 0.5), cellSize);
	let b_v = getV(b_cellUv + 2.0);
	var b_color = vec3f(0.0, 0.0, 0.0);
	let b_dist = distance(b_modUv, cellSize * 0.5);
	let b_radiusMain = b_v;
	let b_radiusInner = (b_v - innerDelay) / (1.0 - innerDelay);
	let b_transparency = max(0.0, b_v - transparencyDelay) / (1.0 - transparencyDelay);
	if (b_dist < b_radiusMain * (cellSize.x * 0.5) && b_dist > b_radiusInner * (cellSize.x * 0.5)) { color = vec4f(1.0, 1.0, 1.0, (1.0 - b_transparency)); }

	return premultiplyAlpha(color);
}
