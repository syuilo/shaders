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

// https://docs.arduino.cc/language-reference/en/functions/math/map/
fn remap(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
	return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
}

// 0.0 ~ 1.0
fn rand(seed: vec2f) -> f32 {
	return fract(sin(dot(seed, vec2f(12.9898, 78.233))) * 43758.5453);
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

fn screenNdcUvToTextureUv(screenNdcUv: vec2f) -> vec2f {
	return vec2f(screenNdcUv.x, -screenNdcUv.y) * 0.5 + vec2f(0.5);
}

fn sourceNdcUvToTextureUv(sourceNdcUv: vec2f) -> vec2f {
	return vec2f(sourceNdcUv.x, -sourceNdcUv.y) * 0.5 + vec2f(0.5);
}

fn hslToRgb(hsl: vec3f) -> vec3f {
	let c = (1.0 - abs((hsl.x * 6.0) % 2.0 - 1.0)) * hsl.y;
	let x = c * (1.0 - abs((hsl.x * 6.0) % 2.0 - 1.0));
	let m = hsl.z - c * 0.5;

	var rgb = vec3f(0.0);
	if (hsl.x < 1.0 / 6.0) {
		rgb = vec3f(c, x, 0.0);
	} else if (hsl.x < 2.0 / 6.0) {
		rgb = vec3f(x, c, 0.0);
	} else if (hsl.x < 3.0 / 6.0) {
		rgb = vec3f(0.0, c, x);
	} else if (hsl.x < 4.0 / 6.0) {
		rgb = vec3f(0.0, x, c);
	} else if (hsl.x < 5.0 / 6.0) {
		rgb = vec3f(x, 0.0, c);
	} else {
		rgb = vec3f(c, 0.0, x);
	}

	return rgb + vec3f(m);
}

struct Uniforms {
	scale: f32,
	aspectRatio: f32,
	time: f32,
	scrollFactor: f32,
	turbulenceScale: f32,
	blurStrength: f32,
	blurExtend: f32,
	pallette: u32,
	discardThreshold: f32,
	channelAFactor: f32,
	channelBFactor: f32,
	channelCFactor: f32,
	test: u32,
	hasSource: u32,
	coverSource: u32,
	sourceAspectRatio: f32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;
@group(0) @binding(2) var sourceSampler: sampler;
@group(0) @binding(3) var sourceTexture: texture_2d<f32>;
@group(0) @binding(4) var pointerTrailTexture: texture_2d<f32>;

fn getScreenNdcToSourceNdcScale(
	screenAspectRatio: f32,
	sourceAspectRatio: f32,
	coverSource: bool,
) -> vec2f {
	let fitWidth = vec2f(screenAspectRatio / sourceAspectRatio, 1.0);
	let fitHeight = vec2f(1.0, sourceAspectRatio / screenAspectRatio);
	let containScale = select(fitHeight, fitWidth, sourceAspectRatio < screenAspectRatio);
	let coverScale = select(fitHeight, fitWidth, sourceAspectRatio > screenAspectRatio);
	return select(containScale, coverScale, coverSource);
}

fn screenNdcUvToSourceNdcUv(screenNdcUv: vec2f) -> vec2f {
	return screenNdcUv * getScreenNdcToSourceNdcScale(
		uniforms.aspectRatio,
		uniforms.sourceAspectRatio,
		uniforms.coverSource == 1,
	);
}

fn screenNdcVectorToSourceNdcVector(screenNdcVector: vec2f) -> vec2f {
	return screenNdcVector * getScreenNdcToSourceNdcScale(
		uniforms.aspectRatio,
		uniforms.sourceAspectRatio,
		uniforms.coverSource == 1,
	);
}

fn getSourceColor(screenNdcUv: vec2f) -> vec4f {
	let sourceNdcUv = screenNdcUvToSourceNdcUv(screenNdcUv);
	return textureSample(sourceTexture, sourceSampler, sourceNdcUvToTextureUv(sourceNdcUv));
}

fn getWarpedSourceAspectUv(
	sourceBaseAspectUv: vec2f,
	proceduralBaseAspectUv: vec2f,
	warpedProceduralAspectUv: vec2f,
	turbulence: f32,
) -> vec2f {
	let warpedAspectVector = warpedProceduralAspectUv - proceduralBaseAspectUv;
	return sourceBaseAspectUv + ((warpedAspectVector + vec2f(turbulence)) * 0.125);
}

struct FragmentIn {
	@location(0) screenNdcUv: vec2f,
};

struct FragmentOut {
	@location(0) color: vec4f,
	@location(1) blurRadius: f32,
};

fn makeFragmentOut(color: vec4f, blurRadius: f32) -> FragmentOut {
	return FragmentOut(color, blurRadius);
}

@fragment
fn fs(fragData: FragmentIn) -> FragmentOut {
	let time = uniforms.time * 0.00005;
	let scrollAspectVector = vec2f(0.0, uniforms.time * 0.0001 * uniforms.scrollFactor);
	let noiseScale = 0.75;
	let turbulenceScale = 0.75 * uniforms.turbulenceScale;

	let screenNdcUv = fragData.screenNdcUv;
	let aspectUv = screenNdcUvToAspectUv(screenNdcUv, uniforms.aspectRatio);
	let sourceBaseAspectUv = aspectUv;
	let proceduralBaseAspectUv = aspectUv * uniforms.scale;
	let pointerTrailScreenNdcVector = textureSample(
		pointerTrailTexture,
		sourceSampler,
		screenNdcUvToTextureUv(screenNdcUv),
	).rg;
	let pointerTrailAspectVector = screenNdcVectorToAspectVector(
		pointerTrailScreenNdcVector,
		uniforms.aspectRatio,
	);

	var warpedProceduralAspectUv = proceduralBaseAspectUv + (vec2f(
		snoise(vec3f((proceduralBaseAspectUv + scrollAspectVector + 4.0), time)),
		snoise(vec3f((proceduralBaseAspectUv + scrollAspectVector + 5.0), time))) * 2.0);

	warpedProceduralAspectUv -= pointerTrailAspectVector;

	let turbulence = snoise(vec3f((warpedProceduralAspectUv + 6.0) * turbulenceScale, time * 0.5));

	let power = ((warpedProceduralAspectUv.x - proceduralBaseAspectUv.x) + (warpedProceduralAspectUv.y - proceduralBaseAspectUv.y) + turbulence) / 3.0; // 3つの成分を混ぜるので-1 ~ +1の範囲にするために3で割る
	var blurRadius = clamp((power + uniforms.blurExtend) * uniforms.blurStrength, 0.0, 1.0);
	let pointerForce = (abs(pointerTrailScreenNdcVector.x) + abs(pointerTrailScreenNdcVector.y)) / 4.0;
	blurRadius += max(pointerForce - 0.3, 0.0) * uniforms.blurStrength * 0.7;
	blurRadius = clamp(blurRadius, 0.0, 1.0);

	let sourceColor = select(vec4f(0.0), getSourceColor(screenNdcUv), uniforms.hasSource == 1);
	let warpedSourceAspectUv = getWarpedSourceAspectUv(
		sourceBaseAspectUv,
		proceduralBaseAspectUv,
		warpedProceduralAspectUv,
		turbulence,
	);
	let warpedSourceScreenNdcUv = aspectUvToScreenNdcUv(warpedSourceAspectUv, uniforms.aspectRatio);
	let sourceColorWarped = select(vec4f(0.0), getSourceColor(warpedSourceScreenNdcUv), uniforms.hasSource == 1);

	var noiseA = snoiseFractal(vec3f((warpedProceduralAspectUv + 1.0 + turbulence) * noiseScale, time * 0.5));
	var noiseB = snoiseFractal(vec3f((warpedProceduralAspectUv + 2.0 + turbulence) * noiseScale, time * 0.4));
	var noiseC = snoiseFractal(vec3f((warpedProceduralAspectUv + 3.0 + turbulence) * noiseScale, time * 0.3));

	if (uniforms.pallette == 0) {
		var c = select(vec3f(1.0, 1.0, 1.0), vec3f(sourceColorWarped.r, sourceColorWarped.g, sourceColorWarped.b), uniforms.hasSource == 1);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return makeFragmentOut(select(vec4f(1.0, 1.0, 1.0, 1.0), sourceColor, uniforms.hasSource == 1), blurRadius);
		}

		if (noiseA < -0.35) {
			c = blendNormalVec3f(c, vec3f(1.0, 0.0, 0.0));
		}
		if (noiseB < -0.35) {
			c = blendNormalVec3f(c, vec3f(0.0, 1.0, 0.0));
		}
		if (noiseC < -0.35) {
			c = blendNormalVec3f(c, vec3f(0.0, 0.0, 1.0));
		}

		c = mix(c, blendNormalVec3f(c, vec3f(1.0, 0.0, 0.0)), noiseA * uniforms.channelAFactor);
		c = mix(c, blendNormalVec3f(c, vec3f(0.0, 1.0, 0.0)), noiseB * uniforms.channelBFactor);
		c = mix(c, blendNormalVec3f(c, vec3f(0.0, 0.0, 1.0)), noiseC * uniforms.channelCFactor);

		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return makeFragmentOut(vec4f(c, 1.0), blurRadius);
	} else if (uniforms.pallette == 1) {
		var c = select(vec3f(1.0, 1.0, 1.0), vec3f(sourceColorWarped.r, sourceColorWarped.g, sourceColorWarped.b), uniforms.hasSource == 1);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return makeFragmentOut(select(vec4f(c, 1.0), sourceColor, uniforms.hasSource == 1), blurRadius);
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
		return makeFragmentOut(vec4f(c, 1.0), blurRadius);
	} else if (uniforms.pallette == 2) {
		var c = select(vec3f(0.0, 0.0, 0.6), vec3f(sourceColorWarped.r, sourceColorWarped.g, sourceColorWarped.b), uniforms.hasSource == 1);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return makeFragmentOut(select(vec4f(0.0, 0.0, 0.0, 1.0), sourceColor, uniforms.hasSource == 1), blurRadius);
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

		c = mix(c, normalize(c), snoise(vec3f((proceduralBaseAspectUv + 4.0), time)));
		//c = normalize(c);

		c = blendSubtractVec3f(c, vec3f(0.5));

		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return makeFragmentOut(vec4f(c, 1.0), blurRadius);
	} else if (uniforms.pallette == 3) {
		var c = select(vec3f(1.0, 1.0, 1.0), vec3f(sourceColorWarped.r, sourceColorWarped.g, sourceColorWarped.b), uniforms.hasSource == 1);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return makeFragmentOut(select(vec4f(1.0, 1.0, 1.0, 1.0), sourceColor, uniforms.hasSource == 1), blurRadius);
		}

		c = blendAddVec3f(c, vec3f(1.0, 0.0, 0.0) * noiseA * uniforms.channelAFactor);
		c = blendAddVec3f(c, vec3f(0.0, 1.0, 0.0) * noiseB * uniforms.channelBFactor);
		c = blendAddVec3f(c, vec3f(0.0, 0.0, 1.0) * noiseC * uniforms.channelCFactor);
		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return makeFragmentOut(vec4f(c, 1.0), blurRadius);
	} else if (uniforms.pallette == 4) {
		var c = select(vec3f(0.0, 0.0, 0.0), vec3f(sourceColorWarped.r, sourceColorWarped.g, sourceColorWarped.b), uniforms.hasSource == 1);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return makeFragmentOut(select(vec4f(0.0, 0.0, 0.0, 1.0), sourceColor, uniforms.hasSource == 1), blurRadius);
		}

		//if (noiseA < -0.35) {
		//	c = blendNormalVec3f(c, mix(vec3f(1.0, 0.0, 0.0), vec3f(0.0, 0.0, 0.0), remap(noiseA % 0.1, 0.0, 0.1, 0.0, 1.0)));
		//}
		//if (noiseB < -0.35) {
		//	c = blendNormalVec3f(c, mix(vec3f(0.0, 1.0, 0.0), vec3f(0.0, 0.0, 0.0), remap(noiseB % 0.1, 0.0, 0.1, 0.0, 1.0)));
		//}
		//if (noiseC < -0.35) {
		//	c = blendNormalVec3f(c, mix(vec3f(0.0, 0.0, 1.0), vec3f(0.0, 0.0, 0.0), remap(noiseC % 0.1, 0.0, 0.1, 0.0, 1.0)));
		//}

		//let _a = snoise0to1(vec3f((proceduralBaseAspectUv + 4.0), time)) + (power * 0.7);
		let _a = max(0.03, 0.3 + (power * 0.8));
		let _b = 0.4 + (power * 0.8);
		let _c = 0.5 + (power * 0.8);

		c = mix(c, blendLightenVec3f(c, hslToRgb(vec3f(((remap(noiseA, -1.0, 1.0, 0.0, 1.0) % _a) / _a), 0.5, 0.2))), noiseA * uniforms.channelAFactor);
		//c = mix(c, blendLightenVec3f(c, hslToRgb(vec3f(((remap(noiseB, -1.0, 1.0, 0.0, 1.0) % _b) / _b), 1.0, 0.75))), noiseB * uniforms.channelBFactor);
		//c = mix(c, blendLightenVec3f(c, hslToRgb(vec3f(((remap(noiseC, -1.0, 1.0, 0.0, 1.0) % _c) / _c), 1.0, 0.75))), noiseC * uniforms.channelCFactor);

		//c = normalize(c);

		//c = mix(c, normalize(c), 0.5);

		c = mix(c, normalize(c), power * 3.0);

		//c = blendSubtractVec3f(c, vec3f(0.5));

		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return makeFragmentOut(vec4f(c, 1.0), blurRadius);
	} else if (uniforms.pallette == 5) {
		var c = select(vec3f(0.0, 0.0, 0.6), vec3f(sourceColorWarped.r, sourceColorWarped.g, sourceColorWarped.b), uniforms.hasSource == 1);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return makeFragmentOut(select(vec4f(0.0, 0.0, 0.0, 1.0), sourceColor, uniforms.hasSource == 1), blurRadius);
		}

		if (noiseA < -0.35) {
			c = blendNormalVec3f(c, mix(vec3f(1.0, 0.5, 0.0), vec3f(0.0, 0.0, 0.0), remap(noiseA % 0.1, 0.0, 0.1, 0.0, 1.0)));
		}
		//if (noiseB < -0.35) {
		//	c = blendOverlayVec3f(c, vec3f(0.0, 0.0, 0.0));
		//}
		//if (noiseC < -0.35) {
		//	c = blendOverlayVec3f(c, vec3f(0.0, 0.0, 0.0));
		//}

		c = mix(c, hslToRgb(vec3f(0.1, 1.0, 0.5)), noiseA * 4.0 * uniforms.channelAFactor);
		//c = mix(c, blendLightenVec3f(c, mix(vec3f(0.3, 0.3, 0.0), vec3f(0.0, 0.5, 0.0), remap(noiseB % (1.0 - noiseB), 0.0, (1.0 - noiseB), 0.0, 1.0))), noiseB * 2.0 * uniforms.channelBFactor);
		//c = mix(c, blendLightenVec3f(c, mix(vec3f(0.8, 0.8, 0.0), vec3f(0.8, 0.4, 0.0), remap(noiseC % (1.0 - noiseC), 0.0, (1.0 - noiseC), 0.0, 1.0))), noiseC * 6.0 * uniforms.channelCFactor);

		//c = mix(c, normalize(c), snoise(vec3f((proceduralBaseAspectUv + 4.0), time)));
		//c = normalize(c);

		c = blendSubtractVec3f(c, vec3f(0.5));

		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return makeFragmentOut(vec4f(c, 1.0), blurRadius);
	} else if (uniforms.pallette == 6) {
		var c = select(vec3f(1.0, 1.0, 1.0), vec3f(sourceColorWarped.r, sourceColorWarped.g, sourceColorWarped.b), uniforms.hasSource == 1);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return makeFragmentOut(select(vec4f(c, 1.0), sourceColor, uniforms.hasSource == 1), blurRadius);
		}

		//if (noiseA < -0.35) {
		//	c = blendNormalVec3f(c, mix(vec3f(1.0, 1.0, 0.0), vec3f(0.0, 0.0, 0.0), remap(noiseA % 0.1, 0.0, 0.1, 0.0, 1.0)));
		//}
		//if (noiseB < -0.35) {
		//	c = blendOverlayVec3f(c, vec3f(1.0, 1.0, 1.0));
		//}
		//if (noiseC < -0.35) {
		//	c = blendOverlayVec3f(c, vec3f(1.0, 1.0, 1.0));
		//}

		c = mix(c, blendNormalVec3f(c, mix(vec3f(1.0, 1.0, 0.2), vec3f(0.8, 0.9, 0.3), remap(noiseA % (1.0 - noiseA), 0.0, (1.0 - noiseA), 0.0, 1.0))), noiseA * 6.0 * uniforms.channelAFactor);
		c = mix(c, blendNormalVec3f(c, mix(vec3f(0.1, 0.9, 0.0), vec3f(0.1, 0.7, 0.0), remap(noiseB % (1.0 - noiseB), 0.0, (1.0 - noiseB), 0.0, 1.0))), noiseB * 2.0 * uniforms.channelBFactor);
		c = mix(c, blendNormalVec3f(c, mix(vec3f(0.0, 1.0, 0.5), vec3f(0.0, 1.0, 1.0), remap(noiseC % (1.0 - noiseC), 0.0, (1.0 - noiseC), 0.0, 1.0))), noiseC * 4.0 * uniforms.channelCFactor);

		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return makeFragmentOut(vec4f(c, 1.0), blurRadius);
	} else {
		var c = select(vec3f(0.0, 0.03, 0.1), vec3f(sourceColorWarped.r, sourceColorWarped.g, sourceColorWarped.b), uniforms.hasSource == 1);

		if (uniforms.discardThreshold > -1.0 && power < uniforms.discardThreshold) {
			return makeFragmentOut(select(vec4f(c, 1.0), sourceColor, uniforms.hasSource == 1), blurRadius);
		}

		if (noiseA < -0.4) {
			c = blendNormalVec3f(c, vec3f(1.0, 0.6, 0.2));
		}
		if (noiseB < -0.3) {
			c = blendNormalVec3f(c, vec3f(0.0, 0.4, 0.6));
		}
		if (noiseC < -0.35) {
			c = blendNormalVec3f(c, vec3f(0.6, 0.3, 0.6));
		}

		let _noiseA = remap(noiseA, -1.0, 1.0, 0.5, 1.0);
		let _noiseB = remap(noiseB, -1.0, 1.0, 0.5, 1.0);
		let _noiseC = remap(noiseC, -1.0, 1.0, 0.5, 1.0);

		c = mix(c, blendLightenVec3f(c, mix(vec3f(1.0, 0.6, 0.0), vec3f(1.0, 0.7, 0.0), _noiseA % (1.0 - _noiseA))), noiseA * 2.0 * uniforms.channelAFactor);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(0.0, 0.7, 1.0), vec3f(0.3, 0.8, 1.0), _noiseB % (1.0 - _noiseA))), noiseB * uniforms.channelBFactor);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(1.0, 0.5, 1.0), vec3f(1.0, 0.7, 1.0), _noiseC % (1.0 - _noiseA))), noiseC * 0.5 * uniforms.channelCFactor);

		//c = mix(c, normalize(c), power * 3.0);
		c = clamp(c, vec3f(0.0), vec3f(1.0));
		return makeFragmentOut(vec4f(c, 1.0), blurRadius);
	}
}

struct BlurUniforms {
	quality: i32,
	isIos: u32,
	isHorizontal: u32,
	monteCarlo: u32,
	test: u32,
};

@group(1) @binding(1) var<uniform> blurCommonUniforms: Uniforms;
@group(1) @binding(2) var<uniform> blurUniforms: BlurUniforms;
@group(1) @binding(3) var targetSampler: sampler;
@group(1) @binding(4) var targetTexture: texture_2d<f32>;
@group(1) @binding(5) var blurRadiusTexture: texture_2d<f32>;

const goldenAngle = 2.399963229728653; // radians

fn getBlurRadius(screenNdcUv: vec2f) -> f32 {
	return textureSampleLevel(blurRadiusTexture, targetSampler, screenNdcUvToTextureUv(screenNdcUv), 0.0).r;
}

@fragment
fn fsBlur(fragData: FragmentIn) -> @location(0) vec4f {
	let screenNdcUv = fragData.screenNdcUv;
	let centerTextureUv = screenNdcUvToTextureUv(screenNdcUv);

	let r = getBlurRadius(screenNdcUv);
	if (r <= 0.0) {
		return textureSampleLevel(targetTexture, targetSampler, centerTextureUv, 0.0);
	}

	if (blurUniforms.monteCarlo == 1) {
		let sampleCount = blurUniforms.quality;
		var result = vec4f(0.0);
		for (var i = 0; i < sampleCount; i++) {
			let x = remap(rand(vec2f(screenNdcUv.x + f32(i), screenNdcUv.y + f32(i))), 0.0, 1.0, -1.0, 1.0);
			let y = remap(rand(vec2f(screenNdcUv.y + f32(i), screenNdcUv.x + f32(i))), 0.0, 1.0, -1.0, 1.0);
			let aspectVector = vec2f(x, y) * r;
			let sampleScreenNdcUv = screenNdcUv + aspectVectorToScreenNdcVector(aspectVector, blurCommonUniforms.aspectRatio);
			let sampleTextureUv = clamp(screenNdcUvToTextureUv(sampleScreenNdcUv), vec2f(0.0), vec2f(1.0));
			result += textureSampleLevel(targetTexture, targetSampler, sampleTextureUv, 0.0);
		}

		return result / f32(sampleCount);
	} else {
		var result = vec4f(0.0);
		var totalSamples = 0.0;
		//let sampleCount = 256;
		let sampleCount = blurUniforms.quality;
		let aspectUv = screenNdcUvToAspectUv(screenNdcUv, blurCommonUniforms.aspectRatio);
		let jitter = rand(aspectUv) * 4.0;

		for (var i = 0; i < sampleCount; i++) {
			let radius = sqrt((f32(i) + 0.5) / f32(sampleCount));
			let theta = (f32(i) + jitter) * goldenAngle;
			let aspectDirectionVector = vec2f(cos(theta), sin(theta));
			let aspectVector = aspectDirectionVector * (r * radius);
			let weight = exp(-radius * radius * 4.0);
			var sampleScreenNdcUv = screenNdcUv + aspectVectorToScreenNdcVector(aspectVector, blurCommonUniforms.aspectRatio);
			if (blurUniforms.isIos == 1) { // iOSではなぜか範囲外のサンプリングが異様に重いのでクランプ
				sampleScreenNdcUv.x = clamp(sampleScreenNdcUv.x, -1.0, 1.0);
				sampleScreenNdcUv.y = clamp(sampleScreenNdcUv.y, -1.0, 1.0);
			}
			result += textureSampleLevel(targetTexture, targetSampler, screenNdcUvToTextureUv(sampleScreenNdcUv), 0.0) * weight;
			totalSamples += weight;
		}

		return result / totalSamples;
	}

	/*
	var result = vec4f(0.0);
	let sampleCount = 64;
	let textureUv = screenNdcUvToTextureUv(fragData.screenNdcUv);
	for (var i = 0; i < sampleCount; i++) {
		var textureUvOffset = vec2(cos(degrees(f32(i / sampleCount) * 360.0)), sin(degrees(f32(i / sampleCount) * 360.0))) * (rand(vec2(f32(i), textureUv.x + textureUv.y)) + r);
		var sampleTextureUv = textureUv + (textureUvOffset * r);
		result += textureSample(targetTexture, targetSampler, sampleTextureUv) / 2.0;
		textureUvOffset = vec2(cos(degrees(f32(i / sampleCount) * 360.)), sin(degrees(f32(i / sampleCount) * 360.))) * (rand(vec2(f32(i) + 2., textureUv.x + textureUv.y + 24.)) + r);
		sampleTextureUv = textureUv + (textureUvOffset * r);
		result += textureSample(targetTexture, targetSampler, sampleTextureUv) / 2.0;
	}

	return result / f32(sampleCount);
	*/
}

@fragment
fn fsBlurLight(fragData: FragmentIn) -> @location(0) vec4f {
	let screenNdcUv = fragData.screenNdcUv;
	let r = getBlurRadius(screenNdcUv);

	let sampleCount = blurUniforms.quality;
	var result = textureSample(targetTexture, targetSampler, screenNdcUvToTextureUv(screenNdcUv));
	var totalWeight = 1.0;

	if (blurUniforms.isHorizontal == 1) {
		for (var i = 1; i <= sampleCount; i++) {
			let v = (cos((f32(i) / f32(sampleCount + 1)) * PI) + 1.0) * 0.5;
			let jitter = rand(screenNdcUv + f32(i)) * 0.25;
			let offset = (f32(i) / f32(sampleCount)) + jitter;
			var aspectVector = vec2f(offset, jitter) * r;
			var sampleScreenNdcUv = screenNdcUv + aspectVectorToScreenNdcVector(aspectVector, blurCommonUniforms.aspectRatio);
			result += textureSample(targetTexture, targetSampler, clamp(screenNdcUvToTextureUv(sampleScreenNdcUv), vec2f(0.0), vec2f(1.0))) * v;
			aspectVector = vec2f(-offset, jitter) * r;
			sampleScreenNdcUv = screenNdcUv + aspectVectorToScreenNdcVector(aspectVector, blurCommonUniforms.aspectRatio);
			result += textureSample(targetTexture, targetSampler, clamp(screenNdcUvToTextureUv(sampleScreenNdcUv), vec2f(0.0), vec2f(1.0))) * v;
			totalWeight += v * 2.0;
		}
	} else {
		for (var i = 1; i <= sampleCount; i++) {
			let v = (cos((f32(i) / f32(sampleCount + 1)) * PI) + 1.0) * 0.5;
			let jitter = rand(screenNdcUv + f32(i)) * 0.25;
			let offset = (f32(i) / f32(sampleCount)) + jitter;
			var aspectVector = vec2f(jitter, offset) * r;
			var sampleScreenNdcUv = screenNdcUv + aspectVectorToScreenNdcVector(aspectVector, blurCommonUniforms.aspectRatio);
			result += textureSample(targetTexture, targetSampler, clamp(screenNdcUvToTextureUv(sampleScreenNdcUv), vec2f(0.0), vec2f(1.0))) * v;
			aspectVector = vec2f(jitter, -offset) * r;
			sampleScreenNdcUv = screenNdcUv + aspectVectorToScreenNdcVector(aspectVector, blurCommonUniforms.aspectRatio);
			result += textureSample(targetTexture, targetSampler, clamp(screenNdcUvToTextureUv(sampleScreenNdcUv), vec2f(0.0), vec2f(1.0))) * v;
			totalWeight += v * 2.0;
		}
	}

	return result / totalWeight;
}

struct PointerTrailUniforms {
	aspectRatio: f32,
	timeDelta: f32,
	pointerPosition: vec2f,
	pointerVector: vec2f,
};

@group(2) @binding(1) var<uniform> pointerTrailUniforms: PointerTrailUniforms;
@group(2) @binding(2) var pointerTrailSampler: sampler;
@group(2) @binding(3) var pointerTrailBeforeTexture: texture_2d<f32>;

fn getPointerForceScreenNdcVector(aspectUv: vec2f) -> vec2f {
	if (pointerTrailUniforms.pointerPosition.x <= -999.0 && pointerTrailUniforms.pointerPosition.y <= -999.0) {
		return vec2f(0.0);
	}

	var pointerForceScreenNdcVector = vec2f(0.0);
	let radius = 0.3;

	let pointerAspectUv = screenNdcUvToAspectUv(pointerTrailUniforms.pointerPosition, pointerTrailUniforms.aspectRatio);
	let d = distance(aspectUv, pointerAspectUv);
	if (d < radius) {
		let gradate = 1.0 - (d / radius);
		pointerForceScreenNdcVector = (gradate * gradate) * (pointerTrailUniforms.pointerVector * 32.0);
	}

	return pointerForceScreenNdcVector;
}

@fragment
fn fsPointerTrail(fragData: FragmentIn) -> @location(0) vec4f {
	let screenNdcUv = fragData.screenNdcUv;
	let aspectUv = screenNdcUvToAspectUv(screenNdcUv, pointerTrailUniforms.aspectRatio);
	var previousScreenNdcVector = textureSample(pointerTrailBeforeTexture, pointerTrailSampler, screenNdcUvToTextureUv(screenNdcUv)).rg;
	previousScreenNdcVector *= exp2(-pointerTrailUniforms.timeDelta / 300.0);
	let pointerForceScreenNdcVector = getPointerForceScreenNdcVector(aspectUv) * 0.3;
	return vec4f(clamp(previousScreenNdcVector + pointerForceScreenNdcVector, vec2f(-1.0), vec2f(1.0)), 0.0, 1.0);
}
