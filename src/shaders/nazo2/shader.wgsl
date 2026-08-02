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
	//let uv = fragData.uv;
	let cellSize = vec2f(1.0 / (uniforms.divisions * 0.5));
	let modUv = modVec2f(uv, cellSize);
	let cellUv = getPixelatedUv(uv, cellSize);

	let v = getV(cellUv + 1.0);

	var color = vec3f(0.0, 0.0, 0.0);
	let dist = distance(modUv, cellSize * 0.5);
	let radiusMain = v;
	let subDelay = 0.25;
	let radiusSub = (v - subDelay) / (1.0 - subDelay);
	if (dist < radiusMain * (cellSize.x * 0.5)) { color = vec3f(1.0, 1.0, 1.0); }
	if (dist < radiusSub * (cellSize.x * 0.5)) { color = vec3f(0.0, 0.0, 0.0); }

	return vec4f(color, 1.0);
	//return vec4f(uv + 1.0, 0.0, 1.0);
}
