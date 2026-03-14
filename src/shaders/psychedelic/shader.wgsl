struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) uv: vec2f,
};

@vertex
fn vs(@builtin(vertex_index) vertexIndex: u32) -> VertexOut {
	let pos = array(
    vec2f(-1, -1),
    vec2f( 3, -1),
    vec2f(-1,  3),
  );

	let xy = pos[vertexIndex];

	var output: VertexOut;
	output.position = vec4f(xy, 0, 1);
	output.uv = (xy.xy + 1.0) / 2.0;
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

// https://docs.arduino.cc/language-reference/en/functions/math/map/
fn remap(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
	return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
}

struct Uniforms {
	aspectRatio: f32,
	time: f32,
	noiseAEnabled: u32,
	noiseAScale: f32,
	selfModulo: u32,
	mirror: u32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	let time = uniforms.time * 0.0001;
	let u_seed = 1000.0;
	let u_scale = 48.0;
	let noiseScale = 64.0;

	var uv = (fragData.uv - vec2(0.5, 0.5)) / vec2f(1.0, uniforms.aspectRatio);

	if (uniforms.mirror == 1 && uv.x > 0.0) {
		uv = vec2f(-uv.x, uv.y);
	}

	let warpedUv = uv + vec2f(
		snoise(vec3f((uv + u_seed + 4.0) * (u_scale / 48.0), time)),
		snoise(vec3f((uv + u_seed + 5.0) * (u_scale / 48.0), time))) * 2.0;

	let n = snoise(vec3f((warpedUv + u_seed + 6.0) * (u_scale / uniforms.noiseAScale), time * 0.5));

	var noiseR: f32;
	var noiseG: f32;
	var noiseB: f32;

	if (uniforms.noiseAEnabled == 1) {
		noiseR = snoise(vec3f((warpedUv + u_seed + 1.0 + n) * (u_scale / noiseScale), time * 0.5));
		noiseG = snoise(vec3f((warpedUv + u_seed + 2.0 + n) * (u_scale / noiseScale), time * 0.4));
		noiseB = snoise(vec3f((warpedUv + u_seed + 3.0 + n) * (u_scale / noiseScale), time * 0.3));
	} else {
		noiseR = snoise(vec3f((warpedUv + u_seed + 1.0) * (u_scale / noiseScale), time * 0.5));
		noiseG = snoise(vec3f((warpedUv + u_seed + 2.0) * (u_scale / noiseScale), time * 0.4));
		noiseB = snoise(vec3f((warpedUv + u_seed + 3.0) * (u_scale / noiseScale), time * 0.3));
	}

	var c = vec3f(0.0, 0.0, 0.6);
	//c = mix(c, vec3f(1.0, 0.0, 1.0), remap(noiseR % 0.1, 0.0, 0.1, 0.0, 1.0));
	//c = mix(c, vec3f(1.0, 0.7, 0.0), remap(noiseG % 0.1, 0.0, 0.1, 0.0, 1.0));
	//c = mix(c, vec3f(0.0, 0.5, 0.0), remap(noiseB % 0.1, 0.0, 0.1, 0.0, 1.0));

	//if (noiseR > 0.3) {
	//	c = blendLightenVec3f(c, mix(vec3f(1.0, 0.0, 1.0), vec3f(1.0, 0.3, 0.0), remap(noiseR % 0.1, 0.0, 0.1, 0.0, 1.0)));
	//}
	//if (noiseG > 0.2) {
	//	c = blendLightenVec3f(c, mix(vec3f(0.3, 0.3, 0.0), vec3f(0.0, 0.5, 0.0), remap(noiseG % 0.1, 0.0, 0.1, 0.0, 1.0)));
	//}
	//if (noiseB > 0.1) {
	//	c = blendLightenVec3f(c, mix(vec3f(1.0, 1.0, 0.0), vec3f(1.0, 0.5, 0.0), remap(noiseB % 0.1, 0.0, 0.1, 0.0, 1.0)));
	//}


	if (uniforms.selfModulo == 1) {
		c = mix(c, blendLightenVec3f(c, mix(vec3f(1.0, 0.0, 1.0), vec3f(1.0, 0.3, 0.0), remap(noiseR % (1.0 - noiseR), 0.0, (1.0 - noiseR), 0.0, 1.0))), noiseR * 2.0);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(0.3, 0.3, 0.0), vec3f(0.0, 0.5, 0.0), remap(noiseG % (1.0 - noiseG), 0.0, (1.0 - noiseG), 0.0, 1.0))), noiseG);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(0.8, 0.8, 0.0), vec3f(0.8, 0.4, 0.0), remap(noiseB % (1.0 - noiseB), 0.0, (1.0 - noiseB), 0.0, 1.0))), noiseB * 4.0);
	} else {
		c = mix(c, blendLightenVec3f(c, mix(vec3f(1.0, 0.0, 1.0), vec3f(1.0, 0.3, 0.0), remap(noiseR % 0.1, 0.0, 0.1, 0.0, 1.0))), noiseR * 2.0);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(0.3, 0.3, 0.0), vec3f(0.0, 0.5, 0.0), remap(noiseG % 0.1, 0.0, 0.1, 0.0, 1.0))), noiseG);
		c = mix(c, blendLightenVec3f(c, mix(vec3f(0.8, 0.8, 0.0), vec3f(0.8, 0.4, 0.0), remap(noiseB % 0.1, 0.0, 0.1, 0.0, 1.0))), noiseB * 4.0);
	}

	c = mix(c, normalize(c), snoise(vec3f((uv + u_seed + 4.0) * (u_scale / 48.0), time)));
	//c = normalize(c);

	c = blendSubtractVec3f(c, vec3f(0.5));

	c = clamp(c, vec3f(0.0), vec3f(1.0));

	return vec4f(c, 1.0);
}
