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

// equivalent to GLSL's mod function
fn modVec2f(a: vec2f, b: vec2f) -> vec2f {
	return a - b * floor(a / b);
}

fn premultiplyAlpha(color: vec4f) -> vec4f {
	return vec4f(color.rgb * color.a, color.a);
}

/* glsl
float hue2rgb(float f1, float f2, float hue) {
    if (hue < 0.0)
        hue += 1.0;
    else if (hue > 1.0)
        hue -= 1.0;
    float res;
    if ((6.0 * hue) < 1.0)
        res = f1 + (f2 - f1) * 6.0 * hue;
    else if ((2.0 * hue) < 1.0)
        res = f2;
    else if ((3.0 * hue) < 2.0)
        res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
    else
        res = f1;
    return res;
}

vec3 hsl2rgb(vec3 hsl) {
    vec3 rgb;

    if (hsl.y == 0.0) {
        rgb = vec3(hsl.z); // Luminance
    } else {
        float f2;

        if (hsl.z < 0.5)
            f2 = hsl.z * (1.0 + hsl.y);
        else
            f2 = hsl.z + hsl.y - hsl.y * hsl.z;

        float f1 = 2.0 * hsl.z - f2;

        rgb.r = hue2rgb(f1, f2, hsl.x + (1.0/3.0));
        rgb.g = hue2rgb(f1, f2, hsl.x);
        rgb.b = hue2rgb(f1, f2, hsl.x - (1.0/3.0));
    }
    return rgb;
}

vec3 hsl2rgb(float h, float s, float l) {
    return hsl2rgb(vec3(h, s, l));
}
 */

fn hue2rgb(f1: f32, f2: f32, hue: f32) -> f32 {
	var _hue = hue;
	if (_hue < 0.0) {
		_hue += 1.0;
	} else if (_hue > 1.0) {
		_hue -= 1.0;
	}

	var res = 0.0;
	if ((6.0 * _hue) < 1.0) {
		res = f1 + (f2 - f1) * 6.0 * _hue;
	} else if ((2.0 * _hue) < 1.0) {
		res = f2;
	} else if ((3.0 * _hue) < 2.0) {
		res = f1 + (f2 - f1) * ((2.0 / 3.0) - _hue) * 6.0;
	} else {
		res = f1;
	}
	return res;
}

fn hslToRgb(hsl: vec3f) -> vec3f {
	if (hsl.y == 0.0) {
		return vec3f(hsl.z); // Luminance
	} else {
		var f2 = 0.0;
		if (hsl.z < 0.5) {
			f2 = hsl.z * (1.0 + hsl.y);
		} else {
			f2 = hsl.z + hsl.y - hsl.y * hsl.z;
		}
		var f1 = 2.0 * hsl.z - f2;
		return vec3f(
			hue2rgb(f1, f2, hsl.x + (1.0 / 3.0)),
			hue2rgb(f1, f2, hsl.x),
			hue2rgb(f1, f2, hsl.x - (1.0 / 3.0)),
		);
	}
}

fn rgbToHsl(rgb: vec3f) -> vec3f {
	var hsl: vec3f;
	var max = max(rgb.r, max(rgb.g, rgb.b));
	var min = min(rgb.r, min(rgb.g, rgb.b));
	hsl.z = (max + min) / 2.0;

	if (max == min) {
		hsl.x = 0.0;
		hsl.y = 0.0;
	} else {
		var d = max - min;
		if (hsl.z > 0.5) {
			hsl.y = d / (2.0 - max - min);
		} else {
			hsl.y = d / (max + min);
		}
		if (max == rgb.r) {
			hsl.x = (rgb.g - rgb.b) / d + select(0.0, 6.0, rgb.g < rgb.b);
		} else if (max == rgb.g) {
			hsl.x = (rgb.b - rgb.r) / d + 2.0;
		} else if (max == rgb.b) {
			hsl.x = (rgb.r - rgb.g) / d + 4.0;
		}
		hsl.x /= 6.0;
	}
	return hsl;
}

fn remap(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
	return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
}

struct Uniforms {
	scale: f32,
	aspectRatio: f32,
	time: f32,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;

@fragment
fn fs(fragData: VertexOut) -> @location(0) vec4f {
	let time = uniforms.time * 0.1;
	let uv = (fragData.uv + 1.0) / 2.0;
/*
	var h = 0.15 - (uv.x * uv.x * uv.x * uv.x);
	var s = 1.0;
	var l = 0.5;

	//l -= uv.x;
	//s += 1.0 - uv.x;

	var c = hslToRgb(vec3f(h, s, l));
	h = rgbToHsl(c).x;
	s = rgbToHsl(c).y;
	l = rgbToHsl(c).z;

	c = hslToRgb(vec3f(h, s, uv.x));
	 */

	let frequency = 8.0;

	var phaseR = uv.x * PI * frequency;
	var phaseG = uv.x * PI * frequency * 1.5;
	var phaseB = uv.x * PI * frequency * 2.0;

	//phaseG += PI / 3.0;
	//phaseB += (PI / 3.0) * 2.0;


	var r = remap(sin(HALF_PI + phaseR), 0.0, 1.0, 0.5, 1.0);
	var g = remap(sin(HALF_PI + phaseG), 0.0, 1.0, 0.5, 1.0);
	var b = remap(sin(HALF_PI + phaseB), 0.0, 1.0, 0.5, 1.0);

	var c = vec3f(r, g, b);

	return vec4f(c, 1.0);
}
