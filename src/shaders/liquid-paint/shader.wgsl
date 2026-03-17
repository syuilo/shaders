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

fn blendNormal(base: f32, blend: f32) -> f32 {
	return blend;
}
fn blendNormalVec3f(base: vec3f, blend: vec3f) -> vec3f {
	return blend;
}

fn blendAdd(base: f32, blend: f32) -> f32 {
	return min(base + blend, 1.0);
}
fn blendAddVec3f(base: vec3f, blend: vec3f) -> vec3f {
	return min(base + blend, vec3f(1.0));
}

fn blendSubtract(base: f32, blend: f32) -> f32 {
	return max(base + blend - 1.0, 0.0);
}
fn blendSubtractVec3f(base: vec3f, blend: vec3f) -> vec3f {
	return max(base + blend - vec3f(1.0), vec3f(0.0));
}

fn blendMultiply(base: f32, blend: f32) -> f32 {
	return base * blend;
}
fn blendMultiplyVec3f(base: vec3f, blend: vec3f) -> vec3f {
	return base * blend;
}

fn blendDarken(base: f32, blend: f32) -> f32 {
	return min(blend, base);
}
fn blendDarkenVec3f(base: vec3f, blend: vec3f) -> vec3f {
	return vec3f(blendDarken(base.r, blend.r), blendDarken(base.g, blend.g), blendDarken(base.b, blend.b));
}

fn blendLighten(base: f32, blend: f32) -> f32 {
	return max(blend, base);
}
fn blendLightenVec3f(base: vec3f, blend: vec3f) -> vec3f {
	return vec3f(blendLighten(base.r, blend.r), blendLighten(base.g, blend.g), blendLighten(base.b, blend.b));
}

fn blendScreen(base: f32, blend: f32) -> f32 {
	return 1.0 - ((1.0 - base) * (1.0 - blend));
}
fn blendScreenVec3f(base: vec3f, blend: vec3f) -> vec3f {
	return vec3f(blendScreen(base.r, blend.r), blendScreen(base.g, blend.g), blendScreen(base.b, blend.b));
}

fn blendOverlay(base: f32, blend: f32) -> f32 {
	return select(1.0 - 2.0 * (1.0 - base) * (1.0 - blend), 2.0 * base * blend, base < 0.5);
}
fn blendOverlayVec3f(base: vec3f, blend: vec3f) -> vec3f {
	return vec3f(blendOverlay(base.r, blend.r), blendOverlay(base.g, blend.g), blendOverlay(base.b, blend.b));
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

fn convertTexCoordsClamp(uv: vec2f) -> vec2f {
	return clamp(convertTexCoords(uv), vec2f(0.0), vec2f(1.0));
}

struct Uniforms {
	scale: f32,
	aspectRatio: f32,
	time: f32,
	turbulenceEnabled: u32,
	turbulenceScale: f32,
	pallette: u32,
	discardThreshold: f32,
	channelAFactor: f32,
	channelBFactor: f32,
	channelCFactor: f32,
	selfModulo: u32,
	mirror: u32,
	test: u32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	let time = uniforms.time * 0.0001;
	let seed = 1000.0;
	let noiseScale = 0.75;
	let turbulenceScale = 0.75 * uniforms.turbulenceScale;

	var uv = fragData.uv / vec2f(1.0, uniforms.aspectRatio);
	uv *= uniforms.scale;

	if (uniforms.mirror == 1 && uv.x > 0.0) {
		uv = vec2f(-uv.x, uv.y);
	}

	let warpedUv = uv + (vec2f(
		snoise(vec3f((uv + seed + 4.0), time)),
		snoise(vec3f((uv + seed + 5.0), time))) * 2.0);

	let turbulence = select(0.0, snoise(vec3f((warpedUv + seed + 6.0) * turbulenceScale, time * 0.5)), uniforms.turbulenceEnabled == 1);

	let power = ((warpedUv.x - uv.x) + (warpedUv.y - uv.y) + turbulence) / 3.0; // 3つの成分を混ぜるので-1 ~ +1の範囲にするために3で割る

	var noiseA = snoiseFractal(vec3f((warpedUv + seed + 1.0 + turbulence) * noiseScale, time * 0.5));
	var noiseB = snoiseFractal(vec3f((warpedUv + seed + 2.0 + turbulence) * noiseScale, time * 0.4));
	var noiseC = snoiseFractal(vec3f((warpedUv + seed + 3.0 + turbulence) * noiseScale, time * 0.3));

	if (uniforms.pallette == 0) {
		var c = vec3f(1.0, 1.0, 1.0);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return vec4f(1.0, 1.0, 1.0, 1.0);
		}

		if (noiseA < -0.35) {
			c = blendOverlayVec3f(c, vec3f(1.0, 0.0, 0.0));
		}
		if (noiseB < -0.35) {
			c = blendOverlayVec3f(c, vec3f(0.0, 1.0, 0.0));
		}
		if (noiseC < -0.35) {
			c = blendOverlayVec3f(c, vec3f(0.0, 0.0, 1.0));
		}

		c = mix(c, blendNormalVec3f(c, vec3f(1.0, 0.0, 0.0)), noiseA * uniforms.channelAFactor);
		c = mix(c, blendNormalVec3f(c, vec3f(0.0, 1.0, 0.0)), noiseB * uniforms.channelBFactor);
		c = mix(c, blendNormalVec3f(c, vec3f(0.0, 0.0, 1.0)), noiseC * uniforms.channelCFactor);

		if (c.r < 0.25 && c.g < 0.25 && c.b < 0.25) {
			c = vec3f(1.0, 1.0, 1.0);
		}

		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return vec4f(c, 1.0);
	} else if (uniforms.pallette == 1) {
		var c = vec3f(1.0, 1.0, 1.0);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return vec4f(c, 1.0);
		}

		if (noiseA < -0.35) {
			c = blendNormalVec3f(c, mix(vec3f(0.0, 0.0, 1.0), vec3f(0.0, 0.0, 0.0), remap(noiseA % 0.1, 0.0, 0.1, 0.0, 1.0)));
		}
		if (noiseB < -0.35) {
			c = blendOverlayVec3f(c, vec3f(1.0, 1.0, 1.0));
		}
		if (noiseC < -0.35) {
			c = blendOverlayVec3f(c, vec3f(1.0, 1.0, 1.0));
		}

		c = mix(c, blendDarkenVec3f(c, mix(vec3f(0.0, 0.5, 1.0), vec3f(0.0, 0.7, 1.0), remap(noiseA % (1.0 - noiseA), 0.0, (1.0 - noiseA), 0.0, 1.0))), noiseA * 4.0 * uniforms.channelAFactor);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(1.0, 0.3, 0.0), vec3f(0.0, 0.0, 0.5), remap(noiseB % (1.0 - noiseB), 0.0, (1.0 - noiseB), 0.0, 1.0))), noiseB * 2.0 * uniforms.channelBFactor);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(0.5, 0.1, 0.3), vec3f(0.0, 1.0, 0.2), remap(noiseC % (1.0 - noiseC), 0.0, (1.0 - noiseC), 0.0, 1.0))), noiseC * 6.0 * uniforms.channelCFactor);

		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return vec4f(c, 1.0);
	} else if (uniforms.pallette == 2) {
		var c = vec3f(0.0, 0.0, 0.6);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return vec4f(0.0, 0.0, 0.0, 1.0);
		}

		if (noiseA < -0.35) {
			c = blendNormalVec3f(c, mix(vec3f(0.0, 0.0, 1.0), vec3f(0.0, 0.0, 0.0), remap(noiseA % 0.1, 0.0, 0.1, 0.0, 1.0)));
		}
		if (noiseB < -0.35) {
			c = blendOverlayVec3f(c, vec3f(0.0, 0.0, 0.0));
		}
		if (noiseC < -0.35) {
			c = blendOverlayVec3f(c, vec3f(0.0, 0.0, 0.0));
		}

		c = mix(c, blendLightenVec3f(c, mix(vec3f(1.0, 0.0, 1.0), vec3f(1.0, 0.3, 0.0), remap(noiseA % (1.0 - noiseA), 0.0, (1.0 - noiseA), 0.0, 1.0))), noiseA * 4.0 * uniforms.channelAFactor);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(0.3, 0.3, 0.0), vec3f(0.0, 0.5, 0.0), remap(noiseB % (1.0 - noiseB), 0.0, (1.0 - noiseB), 0.0, 1.0))), noiseB * 2.0 * uniforms.channelBFactor);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(0.8, 0.8, 0.0), vec3f(0.8, 0.4, 0.0), remap(noiseC % (1.0 - noiseC), 0.0, (1.0 - noiseC), 0.0, 1.0))), noiseC * 6.0 * uniforms.channelCFactor);

		c = mix(c, normalize(c), snoise(vec3f((uv + seed + 4.0), time)));
		//c = normalize(c);

		c = blendSubtractVec3f(c, vec3f(0.5));

		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return vec4f(c, 1.0);
	} else {
		var c = vec3f(1.0, 1.0, 1.0);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return vec4f(1.0, 1.0, 1.0, 1.0);
		}

		c = blendAddVec3f(c, vec3f(1.0, 0.0, 0.0) * noiseA * uniforms.channelAFactor);
		c = blendAddVec3f(c, vec3f(0.0, 1.0, 0.0) * noiseB * uniforms.channelBFactor);
		c = blendAddVec3f(c, vec3f(0.0, 0.0, 1.0) * noiseC * uniforms.channelCFactor);
		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return vec4f(c, 1.0);
	}
}

struct BlurUniforms {
	turbulenceEnabled: u32,
	turbulenceScale: f32,
	strength: f32,
	quality: i32,
	isIos: u32,
	isHorizontal: u32,
	test: u32,
};

@group(1) @binding(1) var<uniform> blurCommonUniforms: Uniforms;
@group(1) @binding(2) var<uniform> blurUniforms: BlurUniforms;
@group(1) @binding(3) var targetSampler: sampler;
@group(1) @binding(4) var targetTexture: texture_2d<f32>;

const goldenAngle = 2.399963229728653; // radians

fn getBlurRadius(_uv: vec2f) -> f32 {
	let time = blurCommonUniforms.time * 0.0001;
	let seed = 1000.0;
	var uv = _uv / vec2f(1.0, blurCommonUniforms.aspectRatio);
	uv *= blurCommonUniforms.scale;

	let warpedUv = uv + (vec2f(
		snoise(vec3f((uv + seed + 4.0), time)),
		snoise(vec3f((uv + seed + 5.0), time))) * 2.0);

	let turbulenceScale = 0.75 * blurUniforms.turbulenceScale;
	let turbulence = select(0.0, snoise(vec3f((warpedUv + seed + 6.0) * turbulenceScale, time * 0.5)), blurUniforms.turbulenceEnabled == 1);

	var r = (((warpedUv.x - uv.x) + (warpedUv.y - uv.y) + turbulence) / 3.0) * blurUniforms.strength;
	r = max(r, 0.0);
	r = min(r, 1.0);

	return r;
}

@fragment
fn fsBlur(fragData: VertexOut) -> @location(0) vec4f {
	if (blurUniforms.strength == 0.0) {
		return textureSample(targetTexture, targetSampler, convertTexCoords(fragData.uv));
	}

	let r = getBlurRadius(fragData.uv);

	///*
	var result = vec4f(0.0);
	var totalSamples = 0.0;
	//let sampleCount = 256;
	let sampleCount = blurUniforms.quality;
	let jitter = rand(fragData.uv / vec2f(1.0, blurCommonUniforms.aspectRatio)) * 4.0;

	for (var i = 0; i < sampleCount; i++) {
		let radius = sqrt((f32(i) + 0.5) / f32(sampleCount));
		let theta = (f32(i) + jitter) * goldenAngle;
		let direction = vec2f(cos(theta), sin(theta));
		let offset = direction * (r * radius);
		let weight = exp(-radius * radius * 4.0);
		var sampleUv = fragData.uv + (offset * vec2f(1.0, blurCommonUniforms.aspectRatio));
		if (blurUniforms.isIos == 1) { // iOSではなぜか範囲外のサンプリングが異様に重いのでクランプ
			sampleUv.x = clamp(sampleUv.x, -1.0, 1.0);
			sampleUv.y = clamp(sampleUv.y, -1.0, 1.0);
		}
		result += textureSample(targetTexture, targetSampler, convertTexCoords(sampleUv)) * weight;
		//result += vec3f(snoiseFractal(vec3f((uv + offset + seed + 1.0) * 0.75, time * 0.5))) * weight;
		totalSamples += weight;
	}

	return result / totalSamples;
	// */

	/*
	var result = vec4f(0.0);
	let sampleCount = 64;
	for (var i = 0; i < sampleCount; i++) {
		var q = vec2(cos(degrees(f32(i / sampleCount) * 360.0)), sin(degrees(f32(i / sampleCount) * 360.0))) * (rand(vec2(f32(i), uv.x + uv.y)) + r);
		var uv2 = uv + (q * r);
		result += textureSample(targetTexture, targetSampler, uv2) / 2.0;
		q = vec2(cos(degrees(f32(i / sampleCount) * 360.)), sin(degrees(f32(i / sampleCount) * 360.))) * (rand(vec2(f32(i) + 2., uv.x + uv.y + 24.)) + r);
		uv2 = uv + (q * r);
		result += textureSample(targetTexture, targetSampler, uv2) / 2.0;
	}

	return result / f32(sampleCount);
	*/
}

@fragment
fn fsBlurLight(fragData: VertexOut) -> @location(0) vec4f {
	if (blurUniforms.strength == 0.0) {
		return textureSample(targetTexture, targetSampler, convertTexCoords(fragData.uv));
	}

	let r = getBlurRadius(fragData.uv);

	let sampleCount = 16;
	let t = 1.0 / f32((sampleCount * 2) + 1);
	var result = textureSample(targetTexture, targetSampler, convertTexCoords(fragData.uv)) * t;
	//let jitter = rand(uv) * 0.25;
	let jitter = 0.0;

	if (blurUniforms.isHorizontal == 1) {
		for (var i = 1; i < sampleCount; i++) {
			let v = (cos(f32(i / (sampleCount + 1)) / PI) + 1) * 0.5;
			var sampleUv = fragData.uv;
			result += textureSample(targetTexture, targetSampler, convertTexCoordsClamp(vec2(sampleUv.x + (((f32(i) / f32(sampleCount)) + jitter) * r), sampleUv.y))) * v * t;
			result += textureSample(targetTexture, targetSampler, convertTexCoordsClamp(vec2(sampleUv.x - (((f32(i) / f32(sampleCount)) + jitter) * r), sampleUv.y))) * v * t;
		}
	} else {
		for (var i = 1; i < sampleCount; i++) {
			let v = (cos(f32(i / (sampleCount + 1)) / PI) + 1) * 0.5;
			var sampleUv = fragData.uv;
			result += textureSample(targetTexture, targetSampler, convertTexCoordsClamp(vec2(sampleUv.x, sampleUv.y + (((f32(i) / f32(sampleCount)) + jitter) * r)))) * v * t;
			result += textureSample(targetTexture, targetSampler, convertTexCoordsClamp(vec2(sampleUv.x, sampleUv.y - (((f32(i) / f32(sampleCount)) + jitter) * r)))) * v * t;
		}
	}

	return result;
}
