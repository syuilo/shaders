struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) uv: vec2f,
};

@vertex
fn vs(@location(0) position: vec4f) -> VertexOut {
	var output: VertexOut;
	output.position = position;
	output.uv = (position.xy + 1.0) / 2.0;
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
	timeFactor: f32,
	divisions: f32,
	symbolTexturesCount: u32,
	pointerPosition: vec2f,
	useSource: u32,
	sourceTextureAspectRatio: f32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;
@group(0) @binding(2) var symbolSampler: sampler;
@group(0) @binding(3) var symbolTextures: texture_2d_array<f32>;
@group(0) @binding(4) var sourceTexture: texture_2d<f32>;

fn getPointerForce(uv: vec2f) -> f32 {
	if (uniforms.pointerPosition.x == -1.0 && uniforms.pointerPosition.y == -1.0) {
		return 0.0;
	}

	var v = 0.0;
	let thickness = 0.05;
	let radius = 0.1;

	let d = distance(uv, (uniforms.pointerPosition + vec2f(-0.5, 0.5)) / vec2f(1.0, uniforms.aspectRatio));
	if (d < radius + thickness && d > radius - thickness) {
		let gradate = abs(d - radius + thickness) / thickness;
		v += ((1.0 - radius) * gradate);
	}

	return v;
}

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	let time = uniforms.time * uniforms.timeFactor;
	let u_seed = 1000.0;
	let scroll = vec2f(0.0, -time * 0.0001);
	let useSource = uniforms.useSource == 1;

	let uv = (fragData.uv - 0.5) / vec2f(1.0, uniforms.aspectRatio);

	var cellSize = vec2f(1.0 / uniforms.divisions);

	var border = 0.25;

	var modUv = modVec2f(uv - 0.5, cellSize);

	let cellSize2 = cellSize * 2.0;
	let modUv2 = modVec2f(uv - 0.5, cellSize2);
	let cellSize4 = cellSize * 4.0;
	let modUv4 = modVec2f(uv - 0.5, cellSize4);

	let cellUv2 = (cellSize2 * floor((uv - 0.5) / cellSize2))
		+ cellSize2 / 2.0
		+ 0.5;

	let cellUv4 = (cellSize4 * floor((uv - 0.5) / cellSize4))
		+ cellSize4 / 2.0
		+ 0.5;

	let cellMultiplier2Noise = snoise0to1(vec3f(cellUv2.x * 3.0, cellUv2.y * 3.0, time * 0.000025));
	let cellMultiplier4Noise = snoise0to1(vec3f(cellUv4.x * 3.0, cellUv4.y * 3.0, time * 0.000025));
	if (cellMultiplier4Noise > 0.9) {
		modUv = modUv4;
		cellSize = cellSize4;
		border /= 4.0;
	} else if (cellMultiplier2Noise > 0.75) {
		modUv = modUv2;
		cellSize = cellSize2;
		border /= 2.0;
	}

	let cellUv = (cellSize * floor((uv - 0.5) / cellSize))
		+ cellSize / 2.0
		+ 0.5;

	let sourceScale = select(1.0, uniforms.sourceTextureAspectRatio / uniforms.aspectRatio, uniforms.sourceTextureAspectRatio > uniforms.aspectRatio);
	let sourceUv = cellUv * vec2f(1.0, uniforms.sourceTextureAspectRatio) / sourceScale;

	let sourceColor = textureSample(sourceTexture, symbolSampler, sourceUv + 0.5);
	//return sourceColor;

	//float ripple = getRipple(cellUv);
	let pointerForce = getPointerForce(cellUv);

	var texSelector = select(
		snoise0to1(vec3f((cellUv * 3.0) + scroll, time * 0.00001)),
		(sourceColor.r + sourceColor.g + sourceColor.b) / 3.0,
		useSource);

	//if (ripple > 0.5) {
	//	texSelector += 0.25;
	//	//texSelector *= 1.5;
	//	texSelector = min(texSelector, 1.0);
	//}
	if (pointerForce > 0.0) {
		texSelector += pointerForce * 0.25;
		texSelector = min(texSelector, 1.0);
	}

	let scaleNoise = snoise0to1(vec3f(cellUv * 0.7, time * 0.0000125));
	var scale = select(0.4, 1.0, scaleNoise > 0.25);
	scale = min(scale, 1.0 - border);
	//if (ripple > 0.5) {
	//	scale = 1.0;
	//}

	let margin = (1.0 - (0.5 + (scale / 2.0))) * cellSize;
	let transformedCoords = (modUv - margin) / (cellSize - (margin * 2.0));
	var out_color = textureSample(symbolTextures, symbolSampler, transformedCoords, u32(texSelector * f32(uniforms.symbolTexturesCount)));

	let visibilityNoiseA = snoise0to1(vec3f(cellUv + scroll, time * 0.00000625));
	let visibilityNoiseB = snoise0to1(vec3f(cellUv * 8.0, time * 0.00000625));
	var threshold = 0.65;
	//if (ripple > 0.5) threshold -= 0.1;
	var visibility = select(0.0, 1.0, mix(visibilityNoiseA, visibilityNoiseB, 0.5) > threshold);
	if (useSource) {
		visibility = select(0.0, 1.0, (sourceColor.r + sourceColor.g + sourceColor.b) / 3.0 < threshold);
	}

	let colorNoise = snoise0to1(vec3f((cellUv * 8.0) + scroll, time * 0.000025));

	// background dots and blocks
	if (visibility == 0.0) {
		//return sourceColor;
		let n = mix(visibilityNoiseA, visibilityNoiseB, 0.2);
		if (n > 0.75) {
			return premultiplyAlpha(vec4f(1.0, 1.0, 1.0, 0.05));
		} else if (n > 0.5) {
			if (distance(modUv / cellSize, vec2(0.5, 0.5)) < 0.05) {
				return premultiplyAlpha(vec4f(1.0, 1.0, 1.0, 0.25));
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
		return premultiplyAlpha(vec4f(vec3f(0.0), 0.0));
	}

	if (useSource) {
		if ((sourceColor.r + sourceColor.g + sourceColor.b) / 3.0 > 0.7) {
			out_color.r = 1.0;
			out_color.g = 1.0;
			out_color.b = 1.0;
		} else if (sourceColor.r > 0.75) {
			out_color.g *= 0.4;
			out_color.b = 0.0;
		//} else if (colorNoise > 0.85) {
		//	out_color.b = 0.0;
		} else if (sourceColor.g > 0.4) {
			out_color.r /= 1.25;
			out_color.b = 0.0;
		} else if ((sourceColor.r + sourceColor.g + sourceColor.b) / 3.0 < 0.2) {
			out_color.r = 1.0;
			out_color.g = 1.0;
			out_color.b = 1.0;
			out_color.a *= 0.7;
		} else {
			out_color.r = 1.0;
			out_color.g = 1.0;
			out_color.b = 1.0;
		}
	} else {
		if (colorNoise > 0.9) {
			out_color.g *= 0.4;
			out_color.b = 0.0;
		//} else if (colorNoise > 0.85) {
		//	out_color.b = 0.0;
		} else if (colorNoise > 0.7) {
			out_color.r /= 1.25;
			out_color.b = 0.0;
		} else if (colorNoise > 0.35) {
			out_color.r = 1.0;
			out_color.g = 1.0;
			out_color.b = 1.0;
		} else {
			out_color.r = 1.0;
			out_color.g = 1.0;
			out_color.b = 1.0;
			out_color.a *= 0.3;
		}
	}

	if (visibility == 0.0) {
		out_color = vec4f(1.0, 1.0, 1.0, 0.0);
	}

	return premultiplyAlpha(out_color);
}
