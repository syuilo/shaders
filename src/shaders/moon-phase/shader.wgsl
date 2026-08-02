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
	color: vec3f,
	outlineWidth: f32,
	outlineColor: vec3f,
	test: u32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;

fn premultiplyAlpha(color: vec4f) -> vec4f {
	return vec4f(color.rgb * color.a, color.a);
}

// https://docs.arduino.cc/language-reference/en/functions/math/map/
fn remap(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
	return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
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
	let phase = fract(uniforms.time * 0.00015 * dutyCycle);
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

	var color = vec4f(0.0, 0.0, 0.0, 0.0);
	let dist = distance(modUv, cellSize * 0.5);
	let radiusMain = v - uniforms.outlineWidth;
	let subDelay = 0.25;
	let subFactor = 1.05;
	let subPosOffset = vec2f(0.07, -0.07);
	let subPosOffsetRotation = (rand(cellUv) * TWO_PI) + (uniforms.time * 0.0001);
	let subPosOffsetRotated = vec2f(subPosOffset.x * cos(subPosOffsetRotation) - subPosOffset.y * sin(subPosOffsetRotation), subPosOffset.x * sin(subPosOffsetRotation) + subPosOffset.y * cos(subPosOffsetRotation));
	let subDist = distance(modUv, (cellSize * 0.5) + (subPosOffsetRotated * (cellSize * 0.5)));
	let radiusSub = (((v - subDelay) / (1.0 - subDelay)) * subFactor) + uniforms.outlineWidth;
	if (dist < radiusMain * (cellSize.x * 0.5)) { color = vec4f(uniforms.color, 1.0); }
	if (subDist < radiusSub * (cellSize.x * 0.5)) { color = vec4f(0.0, 0.0, 0.0, 0.0); }

	let mainOutline = dist < (radiusMain + uniforms.outlineWidth) * (cellSize.x * 0.5) && dist > (radiusMain - uniforms.outlineWidth) * (cellSize.x * 0.5);
	let isSubInSide = subDist < radiusSub * (cellSize.x * 0.5);
	if (mainOutline && !isSubInSide) {
		color = vec4f(uniforms.outlineColor, 0.5);
	}

	let subOutline = subDist < (radiusSub + uniforms.outlineWidth) * (cellSize.x * 0.5) && subDist > (radiusSub - uniforms.outlineWidth) * (cellSize.x * 0.5);
	let isMainInSide = dist < radiusMain * (cellSize.x * 0.5);
	if (subOutline && isMainInSide) {
		color = vec4f(uniforms.outlineColor, 0.5);
	}

	let transparencyDelay = 0.75;
	let transparency = max(0.0, v - transparencyDelay) / (1.0 - transparencyDelay);

	color.a = color.a * (1.0 - transparency);

	return premultiplyAlpha(color);
}
