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

fn mod289_3(x: vec3f) -> vec3f {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

fn mod289_4(x: vec4f) -> vec4f {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

fn permute(x: vec4f) -> vec4f {
	return mod289_4(((x * 34.0) + 10.0) * x);
}

fn taylorInvSqrt(r: vec4f) -> vec4f {
	return 1.79284291400159 - 0.85373472095314 * r;
}

// -1.0 ~ +1.0
fn snoise(v: vec3f) -> f32 {
	const C = vec2f(1.0 / 6.0, 1.0 / 3.0);
	const D = vec4f(0.0, 0.5, 1.0, 2.0);

	var i = floor(v + dot(v, C.yyy));
	var x0 = v - i + dot(i, C.xxx);

	var g = step(x0.yzx, x0.xyz);
	var l = 1.0 - g;
	var i1 = min(g.xyz, l.zxy);
	var i2 = max(g.xyz, l.zxy);

	var x1 = x0 - i1 + C.xxx;
	var x2 = x0 - i2 + C.yyy;
	var x3 = x0 - D.yyy;

	i = mod289_3(i);
	var p = permute(permute(permute(
						i.z + vec4f(0.0, i1.z, i2.z, 1.0))
					+ i.y + vec4f(0.0, i1.y, i2.y, 1.0))
					+ i.x + vec4f(0.0, i1.x, i2.x, 1.0));

	var n_ = 0.142857142857;
	var ns = n_ * D.wyz - D.xzx;

	var j = p - 49.0 * floor(p * ns.z * ns.z);

	var x_ = floor(j * ns.z);
	var y_ = floor(j - 7.0 * x_);

	var x = x_ * ns.x + ns.yyyy;
	var y = y_ * ns.x + ns.yyyy;
	var h = 1.0 - abs(x) - abs(y);

	var b0 = vec4f(x.xy, y.xy);
	var b1 = vec4f(x.zw, y.zw);

	var s0 = floor(b0) * 2.0 + 1.0;
	var s1 = floor(b1) * 2.0 + 1.0;
	var sh = -step(h, vec4f(0.0));

	var a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	var a1 = b1.xzyw + s1.xzyw * sh.zzww;

	var p0 = vec3f(a0.xy, h.x);
	var p1 = vec3f(a0.zw, h.y);
	var p2 = vec3f(a1.xy, h.z);
	var p3 = vec3f(a1.zw, h.w);

	var norm = taylorInvSqrt(vec4f(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;

	var m = max(0.5 - vec4f(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), vec4f(0.0));
	m = m * m;
	return 105.0 * dot(m * m, vec4f(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// +0.0 ~ +1.0
fn snoise0to1(v: vec3f) -> f32 {
	return (snoise(v) + 1.0) / 2.0;
}

fn snoiseFractal(v: vec3f) -> f32 {
	return (snoise(v) + (snoise(v * 2.0) / 2.0) + (snoise(v * 4.0) / 4.0) + (snoise(v * 8.0) / 8.0)) / (1.0 + 0.5 + 0.25 + 0.125);
	//return (snoise(v) + (snoise(v * 2.0) / 2.0) + (snoise(v * 4.0) / 4.0) + (snoise(v * 8.0) / 8.0));
	//return snoise(v);
}

fn snoiseFractal0to1(v: vec3f) -> f32 {
	return (snoise0to1(v) + (snoise0to1(v * 2.0) / 2.0) + (snoise0to1(v * 4.0) / 4.0) + (snoise0to1(v * 8.0) / 8.0)) / (1.0 + 0.5 + 0.25 + 0.125);
}

// equivalent to GLSL's mod function
fn modVec2f(a: vec2f, b: vec2f) -> vec2f {
	return a - b * floor(a / b);
}

fn modf32(a: f32, b: f32) -> f32 {
	return a - b * floor(a / b);
}

fn premultiplyAlpha(color: vec4f) -> vec4f {
	return vec4f(color.rgb * color.a, color.a);
}

// https://docs.arduino.cc/language-reference/en/functions/math/map/
fn remap(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
	return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
}

fn rand(seed: vec2f) -> f32 {
	return fract(sin(dot(seed, vec2f(12.9898, 78.233))) * 43758.5453);
}

// テクスチャ座標(0~1、+Yが下)に変換
fn convertTexCoords(uv: vec2f) -> vec2f {
	return vec2f(uv.x, -uv.y) * 0.5 + vec2f(0.5);
}

struct Uniforms {
	time: f32,
	aspectRatio: f32,
	scale: f32,
	turbulenceEnabled: u32,
	turbulenceScale: f32,
	strength: f32,
	quality: i32,
	isHorizontal: u32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;
@group(0) @binding(2) var targetSampler: sampler;
@group(0) @binding(3) var targetTexture: texture_2d<f32>;

const goldenAngle = 2.399963229728653; // radians

fn getBlurRadius(_uv: vec2f) -> f32 {
	let time = uniforms.time * 0.00005;
	let seed = 1000.0;
	var uv = _uv / vec2f(1.0, uniforms.aspectRatio);
	uv *= uniforms.scale;

	let warpedUv = uv + (vec2f(
		snoise(vec3f((uv + seed + 4.0), time)),
		snoise(vec3f((uv + seed + 5.0), time))) * 2.0);

	let turbulenceScale = 0.75 * uniforms.turbulenceScale;
	let turbulence = select(0.0, snoise(vec3f((warpedUv + seed + 6.0) * turbulenceScale, time * 0.5)), uniforms.turbulenceEnabled == 1);

	var r = (((warpedUv.x - uv.x) + (warpedUv.y - uv.y) + turbulence) / 3.0) * uniforms.strength;
	r = max(r, 0.0);
	r = min(r, 1.0);

	return r;
}

@fragment
fn fsBlurLight(fragData: VertexOut) -> @location(0) vec4f {
	let r = getBlurRadius(fragData.uv);

	let sampleCount = 16;
	var result = textureSample(targetTexture, targetSampler, convertTexCoords(fragData.uv));
	var totalWeight = 1.0;

	if (uniforms.isHorizontal == 1) {
		for (var i = 1; i <= sampleCount; i++) {
			let jitter = rand(fragData.uv + f32(i)) * 0.25;
			let v = (cos((f32(i) / f32(sampleCount + 1)) * PI) + 1.0) * 0.5;
			var sampleUv = fragData.uv;
			let offset = (f32(i) / f32(sampleCount)) + jitter;
			result += textureSample(targetTexture, targetSampler, convertTexCoords(vec2(sampleUv.x + (offset * r), sampleUv.y + (jitter * r)))) * v;
			result += textureSample(targetTexture, targetSampler, convertTexCoords(vec2(sampleUv.x - (offset * r), sampleUv.y + (jitter * r)))) * v;
			totalWeight += v * 2.0;
		}
	} else {
		//return textureSample(targetTexture, targetSampler, convertTexCoords(fragData.uv));
		for (var i = 1; i <= sampleCount; i++) {
			let jitter = rand(fragData.uv + f32(i)) * 0.25;
			let v = (cos((f32(i) / f32(sampleCount + 1)) * PI) + 1.0) * 0.5;
			var sampleUv = fragData.uv;
			let offset = (f32(i) / f32(sampleCount)) + jitter;
			result += textureSample(targetTexture, targetSampler, convertTexCoords(vec2(sampleUv.x + (jitter * r), sampleUv.y + (offset * r)))) * v;
			result += textureSample(targetTexture, targetSampler, convertTexCoords(vec2(sampleUv.x + (jitter * r), sampleUv.y - (offset * r)))) * v;
			totalWeight += v * 2.0;
		}
	}

	return result / totalWeight;
}
