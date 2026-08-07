const PI = 3.141592653589793;
const TWO_PI = 6.283185307179586;
const HALF_PI = 1.5707963267948966;

// equivalent to GLSL's mod function
fn modVec2f(a: vec2f, b: vec2f) -> vec2f {
	return a - b * floor(a / b);
}

struct Uniforms {
	aspectRatio: f32,
	time: f32,
	divisions: f32,
	dutyCycle: f32,
	color: vec3f,
	outlineWidth: f32,
	outlineColor: vec3f,
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
	let dutyCycleFactor = uniforms.dutyCycle;
	let dutyCycle = max(rand(uv), 0.1) * dutyCycleFactor;
	let phase = fract(uniforms.time * 0.00015 * dutyCycle);
	return linearRisePulse(phase, dutyCycle);
}

fn drawLayer(_color: vec4f, uv: vec2f, rotation: f32, offset: vec2f, seed: f32) -> vec4f {
	var color = _color;
	let cellSize = vec2f(1.0 / (uniforms.divisions * 0.5));
	let innerDelay = 0.25;
	let innerFactor = 1.05;
	let innerPosOffset = vec2f(0.07, -0.07);
	let transparencyDelay = 0.75;

	let _uv = rotate(uv, rotation);
	let modUv = modVec2f(_uv + (cellSize * offset), cellSize);
	let cellUv = getPixelatedUv(_uv + (cellSize * offset), cellSize);
	let v = getV(cellUv + seed);
	let transparency = max(0.0, v - transparencyDelay) / (1.0 - transparencyDelay);

	let innerPosOffsetRotation = (rand(cellUv) * TWO_PI) + (uniforms.time * 0.0001);
	let innerPosOffsetRotated = vec2f(innerPosOffset.x * cos(innerPosOffsetRotation) - innerPosOffset.y * sin(innerPosOffsetRotation), innerPosOffset.x * sin(innerPosOffsetRotation) + innerPosOffset.y * cos(innerPosOffsetRotation));
	let innerDist = distance(modUv, (cellSize * 0.5) + (innerPosOffsetRotated * (cellSize * 0.5)));
	let radiusInner = (((v - innerDelay) / (1.0 - innerDelay)) * innerFactor) + uniforms.outlineWidth;

	let mainDist = distance(modUv, cellSize * 0.5);
	let radiusMain = v - uniforms.outlineWidth;
	if (mainDist < radiusMain * (cellSize.x * 0.5) && innerDist > radiusInner * (cellSize.x * 0.5)) { color = vec4f(uniforms.color, min(1.0, color.a + (1.0 - transparency))); }

	let mainOutline = mainDist < (radiusMain + uniforms.outlineWidth) * (cellSize.x * 0.5) && mainDist > (radiusMain - uniforms.outlineWidth) * (cellSize.x * 0.5);
	let isInnerInside = innerDist < radiusInner * (cellSize.x * 0.5);
	if (mainOutline && !isInnerInside) { color = vec4f(uniforms.outlineColor, max(0.0, color.a - 0.5)); }

	let innerOutline = innerDist < (radiusInner + uniforms.outlineWidth) * (cellSize.x * 0.5) && innerDist > (radiusInner - uniforms.outlineWidth) * (cellSize.x * 0.5);
	let isMainInside = mainDist < radiusMain * (cellSize.x * 0.5);
	if (innerOutline && isMainInside) { color = vec4f(uniforms.outlineColor, max(0.0, color.a - 0.5)); }

	return color;
}

struct FragmentIn {
	@location(0) uv: vec2f,
};

@fragment
fn fs(fragData: FragmentIn) -> @location(0) vec4f {
	let uv = scaleUvToCoverGivenAspectRatio(fragData.uv, uniforms.aspectRatio);

	var color = vec4f(0.0, 0.0, 0.0, 0.0);

	// 複数のレイヤー(格子)をずらして重ねることで格子感を薄める
	color = drawLayer(color, uv, radians(0.0), vec2f(0.0, 0.0), 1.0);
	color = drawLayer(color, uv, radians(22.5), vec2f(0.25, 0.25), 3.0);
	color = drawLayer(color, uv, radians(45.0), vec2f(0.5, 0.5), 5.0);

	return premultiplyAlpha(color);
}
