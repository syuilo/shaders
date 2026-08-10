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

fn getPixelatedAspectUv(aspectUv: vec2f, aspectCellSize: vec2f) -> vec2f {
	return (aspectCellSize * floor(aspectUv / aspectCellSize)) + (aspectCellSize / 2.0);
}

fn getScreenNdcToAspectScale(aspectRatio: f32) -> vec2f {
	return vec2f(min(1.0, aspectRatio), min(1.0, 1.0 / aspectRatio));
}

fn screenNdcUvToAspectUv(screenNdcUv: vec2f, aspectRatio: f32) -> vec2f {
	return screenNdcUv * getScreenNdcToAspectScale(aspectRatio);
}

fn screenNdcVectorToAspectVector(screenNdcVector: vec2f, aspectRatio: f32) -> vec2f {
	return screenNdcVector * getScreenNdcToAspectScale(aspectRatio);
}

fn aspectUvToScreenNdcUv(aspectUv: vec2f, aspectRatio: f32) -> vec2f {
	return aspectUv / getScreenNdcToAspectScale(aspectRatio);
}

fn aspectVectorToScreenNdcVector(aspectVector: vec2f, aspectRatio: f32) -> vec2f {
	return aspectVector / getScreenNdcToAspectScale(aspectRatio);
}

fn linearRisePulse(
	phase: f32, // 0.0～1.0
	riseLength: f32,
) -> f32 {
	let _phase = fract(phase);
	let riseStart = 1.0 - riseLength; // 1周期の最後の riseLength 区間で 0→1
	return clamp((_phase - riseStart) / riseLength, 0.0, 1.0);
}

fn getV(aspectUv: vec2f) -> f32 {
	let divisions = uniforms.divisions;

	let lengthField = ((aspectUv.x * 0.5) + (aspectUv.y * 0.5) * divisions) / (divisions * divisions);
	let phaseField = ((aspectUv.x * 4.0) + (aspectUv.y * 4.0) * divisions) / (divisions * divisions);

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
	@location(0) screenNdcUv: vec2f,
};

@fragment
fn fs(fragData: FragmentIn) -> @location(0) vec4f {
	let aspectUv = screenNdcUvToAspectUv(fragData.screenNdcUv, uniforms.aspectRatio);
	let aspectCellSize = vec2f(1.0 / (uniforms.divisions * 0.5));
	let cellLocalUv = modVec2f(aspectUv, aspectCellSize);
	let aspectCellUv = getPixelatedAspectUv(aspectUv, aspectCellSize);

	let v = getV(aspectCellUv + 1.0);

	var color = vec3f(0.0, 0.0, 0.0);
	let dist = distance(cellLocalUv, aspectCellSize * 0.5);
	let radius = v;
	if (dist < radius * (aspectCellSize.x * 0.5)) { color = vec3f(1.0, 1.0, 1.0); }

	return vec4f(color, 1.0);
	//return vec4f(aspectUv + 1.0, 0.0, 1.0);
}
