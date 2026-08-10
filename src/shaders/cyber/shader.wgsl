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

struct Uniforms {
	aspectRatio: f32,
	time: f32,
	divisions: f32,
	margin: f32,
	symbolTexturesCount: u32,
	symbolTexturesRangeMin: f32,
	symbolTexturesRangeMax: f32,
	useOriginalColor: u32,
	sourceAspectRatio: f32,
	sourceContrast: f32,
	highlightClipThreshold: f32,
	shadowClipThreshold: f32,
	enableClippedAreaFill: u32,
	coverSource: u32,
	bgColor: vec3f,
	colorA: vec3f,
	colorB: vec3f,
	colorC: vec3f,
	similarityThresholdFactor: f32,
	pointerTrailShift: u32,
	pointerTrailWarp: u32,
	pointerPosition: vec2f,
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

fn screenNdcUvToTextureUv(screenNdcUv: vec2f) -> vec2f {
	return vec2f(screenNdcUv.x, -screenNdcUv.y) * 0.5 + vec2f(0.5);
}

fn sourceNdcUvToTextureUv(sourceNdcUv: vec2f) -> vec2f {
	return vec2f(sourceNdcUv.x, -sourceNdcUv.y) * 0.5 + vec2f(0.5);
}

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

fn getAdaptiveCellSampleOffset(baseAspectCellSize: f32, multiplier: f32) -> vec2f {
	return vec2f(baseAspectCellSize * ((multiplier - 1.0) * 0.5));
}

fn getSourceColor(screenNdcUv: vec2f) -> vec4f {
	var sourceNdcUv = screenNdcUvToSourceNdcUv(screenNdcUv);
	if (uniforms.pointerTrailWarp == 1) {
		let pointerTrailScreenNdcVector = getPointerTrailScreenNdcVector(screenNdcUv);
		let pointerTrailSourceNdcVector = screenNdcVectorToSourceNdcVector(pointerTrailScreenNdcVector);
		sourceNdcUv -= pointerTrailSourceNdcVector;
	}
	let color = textureSample(sourceTexture, mySampler, sourceNdcUvToTextureUv(sourceNdcUv));
	return vec4f(pow(color.rgb, vec3f(uniforms.sourceContrast)), color.a);
}

fn getPointerTrailScreenNdcVector(screenNdcUv: vec2f) -> vec2f {
	return textureSample(pointerTrailTexture, mySampler, screenNdcUvToTextureUv(screenNdcUv)).rg;
}

fn getSymbolShiftAspectVector(
	pointerTrailScreenNdcVector: vec2f,
	aspectCellSize: vec2f,
) -> vec2f {
	return -pointerTrailScreenNdcVector * aspectCellSize;
}

fn getShiftedCellLocalAspectUv(
	cellLocalAspectUv: vec2f,
	symbolShiftAspectVector: vec2f,
) -> vec2f {
	return cellLocalAspectUv + symbolShiftAspectVector;
}

fn isSimilar(a: vec4f, b: vec4f, c: vec4f, d: vec4f, threshold: f32) -> bool {
	return (
		abs(a.r - b.r) < threshold && abs(a.g - b.g) < threshold && abs(a.b - b.b) < threshold &&
		abs(a.r - c.r) < threshold && abs(a.g - c.g) < threshold && abs(a.b - c.b) < threshold &&
		abs(a.r - d.r) < threshold && abs(a.g - d.g) < threshold && abs(a.b - d.b) < threshold
	);
}

struct FragmentIn {
	@location(0) screenNdcUv: vec2f,
};

@fragment
fn fsWithSource(fragData: FragmentIn) -> @location(0) vec4f {
	let time = uniforms.time;
	let scrollAspectVector = vec2f(0.0, -time * 0.0001);
	let aspectUv = screenNdcUvToAspectUv(fragData.screenNdcUv, uniforms.aspectRatio);
	let baseAspectCellSize = 1.0 / (uniforms.divisions * 0.5);
	var aspectCellSize = vec2f(baseAspectCellSize);
	var border = uniforms.margin;
	var cellLocalAspectUv = modVec2f(aspectUv, aspectCellSize);

	let aspectCellUv2 = getPixelatedAspectUv(aspectUv, aspectCellSize * 2.0);
	let sampleAspectVector2 = getAdaptiveCellSampleOffset(baseAspectCellSize, 2.0);
	let sampleAspectUvA2 = aspectCellUv2 + vec2f(-sampleAspectVector2.x, -sampleAspectVector2.y);
	let sampleAspectUvB2 = aspectCellUv2 + vec2f(sampleAspectVector2.x, -sampleAspectVector2.y);
	let sampleAspectUvC2 = aspectCellUv2 + vec2f(-sampleAspectVector2.x, sampleAspectVector2.y);
	let sampleAspectUvD2 = aspectCellUv2 + vec2f(sampleAspectVector2.x, sampleAspectVector2.y);
	let sourceColorA2 = getSourceColor(aspectUvToScreenNdcUv(sampleAspectUvA2, uniforms.aspectRatio));
	let sourceColorB2 = getSourceColor(aspectUvToScreenNdcUv(sampleAspectUvB2, uniforms.aspectRatio));
	let sourceColorC2 = getSourceColor(aspectUvToScreenNdcUv(sampleAspectUvC2, uniforms.aspectRatio));
	let sourceColorD2 = getSourceColor(aspectUvToScreenNdcUv(sampleAspectUvD2, uniforms.aspectRatio));
	let similar2 = isSimilar(sourceColorA2, sourceColorB2, sourceColorC2, sourceColorD2, 0.1 * uniforms.similarityThresholdFactor);

	let aspectCellUv4 = getPixelatedAspectUv(aspectUv, aspectCellSize * 4.0);
	let sampleAspectVector4 = getAdaptiveCellSampleOffset(baseAspectCellSize, 4.0);
	let sampleAspectUvA4 = aspectCellUv4 + vec2f(-sampleAspectVector4.x, -sampleAspectVector4.y);
	let sampleAspectUvB4 = aspectCellUv4 + vec2f(sampleAspectVector4.x, -sampleAspectVector4.y);
	let sampleAspectUvC4 = aspectCellUv4 + vec2f(-sampleAspectVector4.x, sampleAspectVector4.y);
	let sampleAspectUvD4 = aspectCellUv4 + vec2f(sampleAspectVector4.x, sampleAspectVector4.y);
	let sourceColorA4 = getSourceColor(aspectUvToScreenNdcUv(sampleAspectUvA4, uniforms.aspectRatio));
	let sourceColorB4 = getSourceColor(aspectUvToScreenNdcUv(sampleAspectUvB4, uniforms.aspectRatio));
	let sourceColorC4 = getSourceColor(aspectUvToScreenNdcUv(sampleAspectUvC4, uniforms.aspectRatio));
	let sourceColorD4 = getSourceColor(aspectUvToScreenNdcUv(sampleAspectUvD4, uniforms.aspectRatio));
	let similar4 = isSimilar(sourceColorA4, sourceColorB4, sourceColorC4, sourceColorD4, 0.025 * uniforms.similarityThresholdFactor);

	if (similar4) {
		cellLocalAspectUv = modVec2f(aspectUv, aspectCellSize * 4.0);
		aspectCellSize = aspectCellSize * 4.0;
		border /= 4.0;
	} else if (similar2) {
		cellLocalAspectUv = modVec2f(aspectUv, aspectCellSize * 2.0);
		aspectCellSize = aspectCellSize * 2.0;
		border /= 2.0;
	}

	let aspectCellUv = getPixelatedAspectUv(aspectUv, aspectCellSize);

	let sourceColor = getSourceColor(aspectUvToScreenNdcUv(aspectCellUv, uniforms.aspectRatio));
	let sourceColorLuminance = (sourceColor.r + sourceColor.g + sourceColor.b) / 3.0;

	var texSelector = remap(sourceColorLuminance, uniforms.shadowClipThreshold, uniforms.highlightClipThreshold, 0.0, 1.0); // クリップする範囲の分だけ範囲を圧縮する
	texSelector = remap(texSelector, 0.0, 1.0, uniforms.symbolTexturesRangeMin, uniforms.symbolTexturesRangeMax);

	let scale = min(1.0, 1.0 - border);
	let pointerTrailScreenNdcVector = getPointerTrailScreenNdcVector(aspectUvToScreenNdcUv(aspectCellUv, uniforms.aspectRatio));
	let symbolShiftAspectVector = select(vec2f(0.0), getSymbolShiftAspectVector(pointerTrailScreenNdcVector, aspectCellSize), uniforms.pointerTrailShift == 1);
	let shiftedCellLocalAspectUv = getShiftedCellLocalAspectUv(cellLocalAspectUv, symbolShiftAspectVector);
	let symbolMarginAspectVector = (1.0 - (0.5 + (scale * 0.5))) * aspectCellSize;
	let symbolTextureUv = (shiftedCellLocalAspectUv - symbolMarginAspectVector) / (aspectCellSize - (symbolMarginAspectVector * 2.0));
	var out_color = textureSample(symbolTextures, mySampler, vec2f(symbolTextureUv.x, 1.0 - symbolTextureUv.y), u32(texSelector * f32(uniforms.symbolTexturesCount)));
	if (symbolTextureUv.x < 0.0 || symbolTextureUv.x > 1.0 || symbolTextureUv.y < 0.0 || symbolTextureUv.y > 1.0) {
		out_color = vec4f(0.0); // 範囲外の参照は無として扱う
	}

	if (sourceColorLuminance > uniforms.highlightClipThreshold) {
		return premultiplyAlpha(vec4f(uniforms.bgColor, 1.0));
	}

	// fill background dots and blocks
	if (uniforms.enableClippedAreaFill == 1) {
		if (sourceColorLuminance < uniforms.shadowClipThreshold * 0.3) {
			return premultiplyAlpha(vec4f(uniforms.bgColor, 1.0));
		} else if (sourceColorLuminance < uniforms.shadowClipThreshold * 0.7) {
			if (distance(shiftedCellLocalAspectUv / aspectCellSize, vec2(0.5, 0.5)) < 0.05) {
				return premultiplyAlpha(vec4f(mix(uniforms.bgColor, uniforms.colorA, 0.25), 1.0));
			} else {
				return premultiplyAlpha(vec4f(uniforms.bgColor, 1.0));
			}
		} else if (sourceColorLuminance < uniforms.shadowClipThreshold) {
			return premultiplyAlpha(vec4f(mix(uniforms.bgColor, uniforms.colorA, 0.05), 1.0));
		}
	} else {
		if (sourceColorLuminance < uniforms.shadowClipThreshold) {
			return premultiplyAlpha(vec4f(uniforms.bgColor, 1.0));
		}
	}

	let isIn = (
		(cellLocalAspectUv.x / aspectCellSize.x) > (1.0 - scale) / 2.0 &&
		(cellLocalAspectUv.x / aspectCellSize.x) < 0.5 + (scale / 2.0) &&
		(cellLocalAspectUv.y / aspectCellSize.y) > (1.0 - scale) / 2.0 &&
		(cellLocalAspectUv.y / aspectCellSize.y) < 0.5 + (scale / 2.0)
	);

	if (!isIn) {
		return premultiplyAlpha(vec4f(vec3f(uniforms.bgColor), 1.0));
	}

	if (uniforms.useOriginalColor == 0) {
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
	}

	out_color.r = mix(uniforms.bgColor.r, out_color.r, out_color.a);
	out_color.g = mix(uniforms.bgColor.g, out_color.g, out_color.a);
	out_color.b = mix(uniforms.bgColor.b, out_color.b, out_color.a);
	out_color.a = 1.0;

	return premultiplyAlpha(out_color);
}

@fragment
fn fsWithoutSource(fragData: FragmentIn) -> @location(0) vec4f {
	let time = uniforms.time;
	let scrollAspectVector = vec2f(0.0, -time * 0.0001);
	let aspectUv = screenNdcUvToAspectUv(fragData.screenNdcUv, uniforms.aspectRatio);
	var aspectCellSize = vec2f(1.0 / (uniforms.divisions * 0.5));
	var border = uniforms.margin;
	var cellLocalAspectUv = modVec2f(aspectUv, aspectCellSize);

	let aspectCellUv2 = getPixelatedAspectUv(aspectUv, aspectCellSize * 2.0);
	let aspectCellUv4 = getPixelatedAspectUv(aspectUv, aspectCellSize * 4.0);

	let cellMultiplier2Noise = snoise0to1(vec3f(aspectCellUv2.x * 3.0, aspectCellUv2.y * 3.0, time * 0.000025));
	let cellMultiplier4Noise = snoise0to1(vec3f(aspectCellUv4.x * 3.0, aspectCellUv4.y * 3.0, time * 0.000025));
	if (cellMultiplier4Noise > 0.9) {
		cellLocalAspectUv = modVec2f(aspectUv, aspectCellSize * 4.0);
		aspectCellSize = aspectCellSize * 4.0;
		border /= 4.0;
	} else if (cellMultiplier2Noise > 0.75) {
		cellLocalAspectUv = modVec2f(aspectUv, aspectCellSize * 2.0);
		aspectCellSize = aspectCellSize * 2.0;
		border /= 2.0;
	}

	var aspectCellUv = getPixelatedAspectUv(aspectUv, aspectCellSize);

	if (uniforms.pointerTrailWarp == 1) {
		let pointerTrailScreenNdcVector = getPointerTrailScreenNdcVector(aspectUvToScreenNdcUv(aspectCellUv, uniforms.aspectRatio));
		aspectCellUv -= screenNdcVectorToAspectVector(pointerTrailScreenNdcVector, uniforms.aspectRatio);
	}

	let visibilityNoiseA = snoise0to1(vec3f(aspectCellUv + scrollAspectVector, time * 0.00000625));
	let visibilityNoiseB = snoise0to1(vec3f(aspectCellUv * 8.0, time * 0.00000625));
	let threshold = 0.65;
	let visibility = select(0.0, 1.0, mix(visibilityNoiseA, visibilityNoiseB, 0.5) > threshold);

	var texSelector = snoise0to1(vec3f((aspectCellUv * 3.0) + scrollAspectVector, time * 0.00001));
	texSelector = remap(texSelector, 0.0, 1.0, uniforms.symbolTexturesRangeMin, uniforms.symbolTexturesRangeMax);

	let scaleNoise = snoise0to1(vec3f(aspectCellUv * 0.7, time * 0.0000125));
	var scale = select(0.4, 1.0, scaleNoise > 0.25);
	scale = min(scale, 1.0 - border);

	let pointerTrailScreenNdcVector = getPointerTrailScreenNdcVector(aspectUvToScreenNdcUv(aspectCellUv, uniforms.aspectRatio));
	let symbolShiftAspectVector = select(vec2f(0.0), getSymbolShiftAspectVector(pointerTrailScreenNdcVector, aspectCellSize), uniforms.pointerTrailShift == 1);
	let shiftedCellLocalAspectUv = getShiftedCellLocalAspectUv(cellLocalAspectUv, symbolShiftAspectVector);
	let symbolMarginAspectVector = (1.0 - (0.5 + (scale * 0.5))) * aspectCellSize;
	let symbolTextureUv = (shiftedCellLocalAspectUv - symbolMarginAspectVector) / (aspectCellSize - (symbolMarginAspectVector * 2.0));
	var out_color = textureSample(symbolTextures, mySampler, vec2f(symbolTextureUv.x, 1.0 - symbolTextureUv.y), u32(texSelector * f32(uniforms.symbolTexturesCount)));
	if (symbolTextureUv.x < 0.0 || symbolTextureUv.x > 1.0 || symbolTextureUv.y < 0.0 || symbolTextureUv.y > 1.0) {
		out_color = vec4f(0.0); // 範囲外の参照は無として扱う
	}

	let colorNoise = snoise0to1(vec3f((aspectCellUv * 8.0) + scrollAspectVector, time * 0.000025));

	// background dots and blocks
	if (visibility == 0.0 && uniforms.enableClippedAreaFill == 1) {
		let n = mix(visibilityNoiseA, visibilityNoiseB, 0.2);
		if (n > 0.75) {
			return premultiplyAlpha(vec4f(mix(uniforms.bgColor, uniforms.colorA, 0.05), 1.0));
		} else if (n > 0.5) {
			if (distance(shiftedCellLocalAspectUv / aspectCellSize, vec2(0.5, 0.5)) < 0.05) {
				return premultiplyAlpha(vec4f(mix(uniforms.bgColor, uniforms.colorA, 0.25), 1.0));
			}
		}
	}

	let isIn = (
		(cellLocalAspectUv.x / aspectCellSize.x) > (1.0 - scale) / 2.0 &&
		(cellLocalAspectUv.x / aspectCellSize.x) < 0.5 + (scale / 2.0) &&
		(cellLocalAspectUv.y / aspectCellSize.y) > (1.0 - scale) / 2.0 &&
		(cellLocalAspectUv.y / aspectCellSize.y) < 0.5 + (scale / 2.0)
	);

	if (!isIn) {
		return premultiplyAlpha(vec4f(vec3f(uniforms.bgColor), 1.0));
	}

	if (uniforms.useOriginalColor == 0) {
		if (colorNoise > 0.9) { // apply colorC
			out_color = vec4f(uniforms.colorC.rgb, out_color.a);
		} else if (colorNoise > 0.7) { // apply colorB
			out_color = vec4f(uniforms.colorB.rgb, out_color.a);
		} else if (colorNoise > 0.35) { // apply colorA
			out_color = vec4f(uniforms.colorA.rgb, out_color.a);
		} else { // apply colorA with lower opacity
			out_color = vec4f(uniforms.colorA.rgb, out_color.a * 0.3);
		}
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
	let aspectUv = screenNdcUvToAspectUv(fragData.screenNdcUv, pointerTrailUniforms.aspectRatio);
	var beforeScreenNdcVector = textureSample(pointerTrailBeforeTexture, pointerTrailSampler, screenNdcUvToTextureUv(fragData.screenNdcUv)).rg;
	beforeScreenNdcVector *= exp2(-pointerTrailUniforms.timeDelta / 300.0);
	let pointerForceScreenNdcVector = getPointerForceScreenNdcVector(aspectUv) * 0.3;
	return vec4f(clamp(beforeScreenNdcVector + pointerForceScreenNdcVector, vec2f(-1.0), vec2f(1.0)), 0.0, 1.0);
}
