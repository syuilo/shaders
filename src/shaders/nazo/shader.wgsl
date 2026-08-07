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

fn linearRisePulse(
	phase: f32, // 0.0～1.0
	riseLength: f32,
) -> f32 {
	let _phase = fract(phase);
	let riseStart = 1.0 - riseLength; // 1周期の最後の riseLength 区間で 0→1
	return clamp((_phase - riseStart) / riseLength, 0.0, 1.0);
}

fn getV(uv: vec2f) -> f32 {
	let divisions = uniforms.divisions;

	let lengthField = ((uv.x * 0.5) + (uv.y * 0.5) * divisions) / (divisions * divisions);
	let phaseField = ((uv.x * 4.0) + (uv.y * 4.0) * divisions) / (divisions * divisions);

	let phase = fract(
		uniforms.time * 0.001
		* lengthField
	);

	let pulseFrequency = 1.0;

	return linearRisePulse(
		phase * pulseFrequency,
		lengthField
	);
}

struct FragmentIn {
	@location(0) uv: vec2f,
};

@fragment
fn fs(fragData: FragmentIn) -> @location(0) vec4f {
	let uv = scaleUvToCoverGivenAspectRatio(fragData.uv, uniforms.aspectRatio);
	//let uv = fragData.uv;
	let cellSize = vec2f(1.0 / (uniforms.divisions * 0.5));
	let modUv = modVec2f(uv, cellSize);
	let cellUv = getPixelatedUv(uv, cellSize);

	let v = getV(cellUv + 1.0);

	var color = vec3f(0.0, 0.0, 0.0);
	let dist = distance(modUv, cellSize * 0.5);
	let radius = v;
	if (dist < radius * (cellSize.x * 0.5)) { color = vec3f(1.0, 1.0, 1.0); }

	return vec4f(color, 1.0);
	//return vec4f(uv + 1.0, 0.0, 1.0);
}
