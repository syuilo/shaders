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

fn rotate(uv: vec2f, angle: f32) -> vec2f {
	let cosAngle = cos(angle);
	let sinAngle = sin(angle);
	return vec2f(
		uv.x * cosAngle - uv.y * sinAngle,
		uv.x * sinAngle + uv.y * cosAngle
	);
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
	let dutyCycleFactor = 0.25;
	let dutyCycle = max(rand(uv), 0.1) * dutyCycleFactor;
	let phase = fract(uniforms.time * 0.001 * dutyCycle);
	return linearRisePulse(phase, dutyCycle);
}

fn drawLayer(color: vec4f, uv: vec2f, rotation: f32, offset: vec2f, seed: f32) -> vec4f {
	let cellSize = vec2f(1.0 / (uniforms.divisions * 0.5));
	let innerDelay = 0.125;
	let transparencyDelay = 0.0;

	let _uv = rotate(uv, rotation);
	let modUv = modVec2f(_uv + (cellSize * offset), cellSize);
	let cellUv = getPixelatedUv(_uv + (cellSize * offset), cellSize);
	let v = getV(cellUv + seed);
	let dist = distance(modUv, cellSize * 0.5);
	let radiusMain = v;
	let radiusInner = (v - innerDelay) / (1.0 - innerDelay);
	let transparency = max(0.0, v - transparencyDelay) / (1.0 - transparencyDelay);

	return select(
		color,
		vec4f(1.0, 1.0, 1.0, min(1.0, color.a + (1.0 - transparency))),
		dist < radiusMain * (cellSize.x * 0.5) && dist > radiusInner * (cellSize.x * 0.5)
	);
}

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	let uv = scaleUvToCoverGivenAspectRatio(fragData.uv, uniforms.aspectRatio);

	var color = vec4f(0.0, 0.0, 0.0, 0.0);

	// 複数のレイヤー(格子)をずらして重ねることで格子感を薄める
	color = drawLayer(color, uv, radians(0.0), vec2f(0.0, 0.0), 1.0);
	color = drawLayer(color, uv, radians(22.5), vec2f(0.25, 0.25), 3.0);
	color = drawLayer(color, uv, radians(45.0), vec2f(0.5, 0.5), 5.0);

	return premultiplyAlpha(color);
}
