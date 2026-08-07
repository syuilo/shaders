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

// equivalent to GLSL's mod function
fn modVec2f(a: vec2f, b: vec2f) -> vec2f {
	return a - b * floor(a / b);
}

fn premultiplyAlpha(color: vec4f) -> vec4f {
	return vec4f(color.rgb * color.a, color.a);
}

// テクスチャ座標(0~1、+Yが下)に変換
fn convertTexCoords(uv: vec2f) -> vec2f {
	return vec2f(uv.x, -uv.y) * 0.5 + vec2f(0.5);
}

struct Uniforms {
	aspectRatio: f32,
	time: f32,
	divisions: f32,
	margin: f32,
	symbolTexturesCount: u32,
	symbolTexturesRangeMin: f32,
	symbolTexturesRangeMax: f32,
	pointerPosition: vec2f,
	sourceAspectRatio: f32,
	discardBrightPixels: u32,
	coverSource: u32,
	bgColor: vec3f,
	colorA: vec3f,
	colorB: vec3f,
	colorC: vec3f,
	test: u32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;
@group(0) @binding(2) var mySampler: sampler;
@group(0) @binding(3) var symbolTextures: texture_2d_array<f32>;
@group(0) @binding(4) var sourceTexture: texture_2d<f32>;
@group(0) @binding(5) var pointerTrailTexture: texture_2d<f32>;

// https://docs.arduino.cc/language-reference/en/functions/math/map/
fn remap(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
	return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
}

fn getPixelatedUv(uv: vec2f, cellSize: vec2f) -> vec2f {
	return (cellSize * floor(uv / cellSize)) + (cellSize / 2.0);
}

fn getSourceColor(uv: vec2f) -> vec4f {
	let sourceScale = select(
		select(1.0, uniforms.sourceAspectRatio / uniforms.aspectRatio, uniforms.sourceAspectRatio < uniforms.aspectRatio),
		select(1.0, uniforms.sourceAspectRatio / uniforms.aspectRatio, uniforms.sourceAspectRatio > uniforms.aspectRatio),
		uniforms.coverSource == 1);
	var sourceUv = uv * vec2f(1.0, uniforms.sourceAspectRatio) / sourceScale;

	let pointerTrailColor = getPointerTrailColor(uv);
	sourceUv.x -= pointerTrailColor.r;
	sourceUv.y -= pointerTrailColor.g;
	sourceUv.x += pointerTrailColor.b;
	sourceUv.y += pointerTrailColor.a;

	return textureSample(sourceTexture, mySampler, convertTexCoords(sourceUv));
}

fn getPointerTrailColor(uv: vec2f) -> vec4f {
	return textureSample(pointerTrailTexture, mySampler, convertTexCoords(unscaleUvToCoverGivenAspectRatio(uv, uniforms.aspectRatio)));
}

const discardBrightPixelsThreshold = 0.7;

fn discardSourceColor(c: vec4f) -> bool {
	var visible = select(false, true, (c.r + c.g + c.b) / 3.0 > 0.1);
	if (uniforms.discardBrightPixels == 1 && (c.r + c.g + c.b) / 3.0 > discardBrightPixelsThreshold) {
		visible = false;
	}
	return !visible;
}

fn isSimilar(a: vec4f, b: vec4f, c: vec4f, d: vec4f, threshold: f32) -> bool {
	return (
		abs(a.r - b.r) < threshold && abs(a.g - b.g) < threshold && abs(a.b - b.b) < threshold &&
		abs(a.r - c.r) < threshold && abs(a.g - c.g) < threshold && abs(a.b - c.b) < threshold &&
		abs(a.r - d.r) < threshold && abs(a.g - d.g) < threshold && abs(a.b - d.b) < threshold
	);
}

fn scaleUvToCoverGivenAspectRatio(uv: vec2f, aspectRatio: f32) -> vec2f {
	return uv / vec2f(1.0, aspectRatio) * select(1.0, aspectRatio, 1.0 > aspectRatio);
}

fn unscaleUvToCoverGivenAspectRatio(uv: vec2f, aspectRatio: f32) -> vec2f {
	return uv * vec2f(1.0, aspectRatio) / select(1.0, aspectRatio, 1.0 > aspectRatio);
}

struct FragmentIn {
	@location(0) uv: vec2f,
};

@fragment
fn fs(fragData: FragmentIn) -> @location(0) vec4f {
	let time = uniforms.time;
	let scroll = vec2f(0.0, -time * 0.0001);
	let uv = scaleUvToCoverGivenAspectRatio(fragData.uv, uniforms.aspectRatio);
	var cellSize = vec2f(1.0 / (uniforms.divisions * 0.5));
	var border = uniforms.margin;
	var modUv = modVec2f(uv, cellSize);

	let cellUv2 = getPixelatedUv(uv, cellSize * 2.0);
	let a2 = cellUv2 + vec2f(-(cellUv2.x / 2.0 / 2.0), -(cellUv2.y / 2.0 / 2.0));
	let b2 = cellUv2 + vec2f((cellUv2.x / 2.0 / 2.0), -(cellUv2.y / 2.0 / 2.0));
	let c2 = cellUv2 + vec2f(-(cellUv2.x / 2.0 / 2.0), (cellUv2.y / 2.0 / 2.0));
	let d2 = cellUv2 + vec2f((cellUv2.x / 2.0 / 2.0), (cellUv2.y / 2.0 / 2.0));
	let sourceColorA2 = getSourceColor(a2);
	let sourceColorB2 = getSourceColor(b2);
	let sourceColorC2 = getSourceColor(c2);
	let sourceColorD2 = getSourceColor(d2);
	let similar2 = !discardSourceColor(getSourceColor(cellUv2)) && isSimilar(sourceColorA2, sourceColorB2, sourceColorC2, sourceColorD2, 0.1);

	let cellUv4 = getPixelatedUv(uv, cellSize * 4.0);
	let a4 = cellUv4 + vec2f(-(cellUv4.x / 4.0 / 2.0), -(cellUv4.y / 4.0 / 2.0));
	let b4 = cellUv4 + vec2f((cellUv4.x / 4.0 / 2.0), -(cellUv4.y / 4.0 / 2.0));
	let c4 = cellUv4 + vec2f(-(cellUv4.x / 4.0 / 2.0), (cellUv4.y / 4.0 / 2.0));
	let d4 = cellUv4 + vec2f((cellUv4.x / 4.0 / 2.0), (cellUv4.y / 4.0 / 2.0));
	let sourceColorA4 = getSourceColor(a4);
	let sourceColorB4 = getSourceColor(b4);
	let sourceColorC4 = getSourceColor(c4);
	let sourceColorD4 = getSourceColor(d4);
	let similar4 = !discardSourceColor(getSourceColor(cellUv4)) && isSimilar(sourceColorA4, sourceColorB4, sourceColorC4, sourceColorD4, 0.025);

	if (similar4) {
		modUv = modVec2f(uv, cellSize * 4.0);
		cellSize = cellSize * 4.0;
		border /= 4.0;
	} else if (similar2) {
		modUv = modVec2f(uv, cellSize * 2.0);
		cellSize = cellSize * 2.0;
		border /= 2.0;
	}

	let cellUv = getPixelatedUv(uv, cellSize);

	let sourceColor = getSourceColor(cellUv);
	let sourceColorLuminance = (sourceColor.r + sourceColor.g + sourceColor.b) / 3.0;

	let visibilityNoiseA = snoise0to1(vec3f(cellUv + scroll, time * 0.00000625));
	let visibilityNoiseB = snoise0to1(vec3f(cellUv * 8.0, time * 0.00000625));
	var threshold = 0.65;
	var visibility = select(0.0, 1.0, mix(visibilityNoiseA, visibilityNoiseB, 0.5) > threshold);
	visibility = select(0.0, 1.0, !discardSourceColor(sourceColor));

	var texSelector = select(sourceColorLuminance, remap(sourceColorLuminance, 0.0, discardBrightPixelsThreshold, 0.0, 1.0), uniforms.discardBrightPixels == 1); // discardBrightPixelsでスキップした範囲の分だけ範囲を圧縮する
	texSelector = remap(texSelector, 0.0, 1.0, uniforms.symbolTexturesRangeMin, uniforms.symbolTexturesRangeMax);

	var scale = min(1.0, 1.0 - border);

	let margin = (1.0 - (0.5 + (scale * 0.5))) * cellSize;
	let transformedCoords = (modUv - margin) / (cellSize - (margin * 2.0));
	var out_color = textureSample(symbolTextures, mySampler, transformedCoords, u32(texSelector * f32(uniforms.symbolTexturesCount)));

	// background dots and blocks
	if (visibility == 0.0) {
		//return sourceColor;
		let n = mix(visibilityNoiseA, visibilityNoiseB, 0.2);
		if (n > 0.75) {
			return premultiplyAlpha(vec4f(mix(uniforms.bgColor, uniforms.colorA, 0.05), 1.0));
		} else if (n > 0.5) {
			if (distance(modUv / cellSize, vec2(0.5, 0.5)) < 0.05) {
				return premultiplyAlpha(vec4f(mix(uniforms.bgColor, uniforms.colorA, 0.25), 1.0));
			}
		}
	}

	let isIn = (
		(modUv.x / cellSize.x) > (1.0 - scale) / 2.0 &&
		(modUv.x / cellSize.x) < 0.5 + (scale / 2.0) &&
		(modUv.y / cellSize.y) > (1.0 - scale) / 2.0 &&
		(modUv.y / cellSize.y) < 0.5 + (scale / 2.0)
	);

	if (!isIn) {
		return premultiplyAlpha(vec4f(vec3f(uniforms.bgColor), 1.0));
	}

	if ((sourceColor.r + sourceColor.g + sourceColor.b) / 3.0 > 0.7) { // apply colorA
		out_color = vec4f(uniforms.colorA.rgb, out_color.a);
	} else if (sourceColor.r > 0.75) { // apply colorC
		out_color = vec4f(uniforms.colorC.rgb, out_color.a);
	} else if (sourceColor.g > 0.4) { // apply colorB
		out_color = vec4f(uniforms.colorB.rgb, out_color.a);
	} else if ((sourceColor.r + sourceColor.g + sourceColor.b) / 3.0 < 0.2) { // apply colorA with lower opacity
		out_color = vec4f(uniforms.colorA.rgb, out_color.a * 0.7);
	} else { // apply colorA
		out_color = vec4f(uniforms.colorA.rgb, out_color.a);
	}

	if (visibility == 0.0) {
		out_color = vec4f(1.0, 1.0, 1.0, 0.0);
	}

	out_color.r = mix(uniforms.bgColor.r, out_color.r, out_color.a);
	out_color.g = mix(uniforms.bgColor.g, out_color.g, out_color.a);
	out_color.b = mix(uniforms.bgColor.b, out_color.b, out_color.a);
	out_color.a = 1.0;

	return premultiplyAlpha(out_color);
}

struct PointerTrailUniforms {
	aspectRatio: f32,
	timeDelta: f32,
	pointerPosition: vec2f,
	pointerVector: vec2f,
};

@group(1) @binding(1) var<uniform> pointerTrailUniforms: PointerTrailUniforms;
@group(1) @binding(2) var pointerTrailSampler: sampler;
@group(1) @binding(3) var pointerTrailBeforeTexture: texture_2d<f32>;

fn getPointerForceColor(uv: vec2f) -> vec4f {
	if (pointerTrailUniforms.pointerPosition.x <= -999.0 && pointerTrailUniforms.pointerPosition.y <= -999.0) {
		return vec4f(0.0);
	}

	var v = vec4f(0.0);
	let radius = 0.3;

	let pos = scaleUvToCoverGivenAspectRatio(pointerTrailUniforms.pointerPosition, pointerTrailUniforms.aspectRatio);
	let d = distance(uv, pos);
	if (d < radius) {
		let gradate = 1.0 - (d / radius);
		v.r = (gradate * gradate) * (pointerTrailUniforms.pointerVector.x * 32.0);
		v.g = (gradate * gradate) * (pointerTrailUniforms.pointerVector.y * 32.0);
		v.b = (gradate * gradate) * (-pointerTrailUniforms.pointerVector.x * 32.0);
		v.a = (gradate * gradate) * (-pointerTrailUniforms.pointerVector.y * 32.0);
	}

	v.r = max(v.r, 0.0);
	v.g = max(v.g, 0.0);
	v.b = max(v.b, 0.0);
	v.a = max(v.a, 0.0);

	return v;
}

@fragment
fn fsPointerTrail(fragData: FragmentIn) -> @location(0) vec4f {
	var uv = scaleUvToCoverGivenAspectRatio(fragData.uv, pointerTrailUniforms.aspectRatio);
	var before = textureSample(pointerTrailBeforeTexture, pointerTrailSampler, convertTexCoords(fragData.uv));
	before -= 1.0 * (pointerTrailUniforms.timeDelta / 2000.0); // 2000msで1.0減る
	before = max(before, vec4f(0.0));
	let v = getPointerForceColor(uv) * 0.3;
	return vec4f(before.r + v.r, before.g + v.g, before.b + v.b, before.a + v.a);
}
