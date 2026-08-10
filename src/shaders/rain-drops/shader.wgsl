// equivalent to GLSL's mod function
fn modVec2f(a: vec2f, b: vec2f) -> vec2f {
	return a - b * floor(a / b);
}

fn hslToRgb(hsl: vec3f) -> vec3f {
	let h = hsl.x;
	let s = hsl.y;
	let l = hsl.z;

	let c = (1.0 - abs(2.0 * l - 1.0)) * s;
	let x = c * (1.0 - abs(fract(h * 6.0) - 1.0));
	let m = l - c * 0.5;

	var rgb = vec3f(0.0, 0.0, 0.0);
	if (h < 1.0 / 6.0) {
		rgb = vec3f(c, x, 0.0);
	} else if (h < 2.0 / 6.0) {
		rgb = vec3f(x, c, 0.0);
	} else if (h < 3.0 / 6.0) {
		rgb = vec3f(0.0, c, x);
	} else if (h < 4.0 / 6.0) {
		rgb = vec3f(0.0, x, c);
	} else if (h < 5.0 / 6.0) {
		rgb = vec3f(x, 0.0, c);
	} else {
		rgb = vec3f(c, 0.0, x);
	}

	return rgb + vec3f(m);
}

fn premultiplyAlpha(color: vec4f) -> vec4f {
	return vec4f(color.rgb * color.a, color.a);
}

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

fn hashU32(value: u32) -> u32 {
	var x = value;
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return x;
}

fn rand(seed: vec2f) -> f32 {
	let bits = bitcast<vec2u>(seed);
	let hash = hashU32(bits.x ^ hashU32(bits.y + 0x9e3779b9u));
	return f32(hash >> 8u) * (1.0 / 16777216.0);
}

fn rotateAspectUv(aspectUv: vec2f, angle: f32) -> vec2f {
	let cosAngle = cos(angle);
	let sinAngle = sin(angle);
	return vec2f(
		aspectUv.x * cosAngle - aspectUv.y * sinAngle,
		aspectUv.x * sinAngle + aspectUv.y * cosAngle
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

struct Uniforms {
	aspectRatio: f32,
	time: f32,
	divisions: f32,
	dutyCycle: f32,
	colorful: u32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;

fn getPhaseProgressAndPhaseCount(aspectUv: vec2f) -> vec2f {
	let dutyCycleFactor = uniforms.dutyCycle;
	let dutyCycle = max(rand(aspectUv), 0.1) * dutyCycleFactor;
	let t = uniforms.time * 0.001 * dutyCycle;
	let progress = linearRisePulse(fract(t), dutyCycle);
	let count = floor(t);
	return vec2f(progress, count);
}

fn drawLayer(bg: vec4f, aspectUv: vec2f, rotation: f32, aspectOffsetVector: vec2f, seed: f32) -> vec4f {
	let aspectCellSize = vec2f(1.0 / (uniforms.divisions * 0.5));
	let innerDelay = 0.125;
	let transparencyDelay = 0.0;
	let rotatedAspectUv = rotateAspectUv(aspectUv, rotation);
	let cellLocalUv = modVec2f(rotatedAspectUv + (aspectCellSize * aspectOffsetVector), aspectCellSize);
	let aspectCellUv = getPixelatedAspectUv(rotatedAspectUv + (aspectCellSize * aspectOffsetVector), aspectCellSize);
	let progressAndCount = getPhaseProgressAndPhaseCount(aspectCellUv + seed);
	let progress= progressAndCount.x;
	let cycleCount = progressAndCount.y;
	let dist = distance(cellLocalUv, aspectCellSize * 0.5);
	let radiusMain = progress;
	let radiusInner = (progress - innerDelay) / (1.0 - innerDelay);
	let transparency = max(0.0, progress - transparencyDelay) / (1.0 - transparencyDelay);
	let h = rand(aspectCellUv + seed + cycleCount);
	let color = select(vec3f(1.0, 1.0, 1.0), hslToRgb(vec3f(h, 1.0, 0.5)), uniforms.colorful == 1);
	return select(
		bg,
		vec4f(color, min(1.0, bg.a + (1.0 - transparency))),
		dist < radiusMain * (aspectCellSize.x * 0.5) && dist > radiusInner * (aspectCellSize.x * 0.5)
	);
}

struct FragmentIn {
	@location(0) screenNdcUv: vec2f,
};

@fragment
fn fs(fragData: FragmentIn) -> @location(0) vec4f {
	let aspectUv = screenNdcUvToAspectUv(fragData.screenNdcUv, uniforms.aspectRatio);

	var color = vec4f(0.0, 0.0, 0.0, 0.0);

	// 複数のレイヤー(格子)をずらして重ねることで格子感を薄める
	color = drawLayer(color, aspectUv, radians(0.0), vec2f(0.0, 0.0), 1.0);
	color = drawLayer(color, aspectUv, radians(22.5), vec2f(0.25, 0.25), 3.0);
	color = drawLayer(color, aspectUv, radians(45.0), vec2f(0.5, 0.5), 5.0);

	return premultiplyAlpha(color);
}
