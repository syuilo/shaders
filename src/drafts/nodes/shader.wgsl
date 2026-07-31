struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) uv: vec2f,
};

const vertices = array(
	vec2f(-1, -1),
	vec2f( 3, -1),
	vec2f(-1,  3),
);

@vertex
fn vs(@builtin(vertex_index) vertexIndex: u32) -> VertexOut {
	let pos = vertices[vertexIndex];
	var output: VertexOut;
	output.position = vec4f(pos, 0, 1);
	output.uv = ((pos.xy * uniforms.scale) + 1.0) / 2.0; // -1 ~ +1 -> 0 ~ 1
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

const u_nodes_x_count = 5;
const u_nodes_y_count = 5;

fn circleShape(uv: vec2f, radius: f32, position: vec2f) -> f32 {
	let value = distance(uv * vec2f(1.0, uniforms.aspectRatio), position * vec2f(1.0, uniforms.aspectRatio));
	return step(value, radius);
}

fn lineShape(uv: vec2f, p1: vec2f, p2: vec2f, width: f32) -> f32 {
	let a = abs(distance(p1, uv));
	let b = abs(distance(p2, uv));
	let c = abs(distance(p1, p2));

	if (a >= c || b >= c) {
		return 0.0;
	}

	let p = (a + b + c) * 0.5;

	// median to (p1, p2) vector
	let h = 2.0 / c * sqrt(p * (p - a) * (p - b) * (p - c));

	return mix(1.0, 0.0, smoothstep(0.5 * width, 1.5 * width, h));
}

// progress: -1.0 ~ +1.0
// -1.0: (start)      (end)
// -0.5: (start)---   (end)
//  0.0: (start)------(end)
// +0.5: (start)   ---(end)
// +1.0: (start)      (end)
fn lineShapeProgress(uv: vec2f, p1: vec2f, p2: vec2f, width: f32, progress: f32) -> f32 {
	if (progress < 0.0) {
		let currentP = mix(p1, p2, progress + 1.0);
		return lineShape(uv, p1, currentP, width);
	} else {
		let currentP = mix(p1, p2, progress);
		return lineShape(uv, currentP, p2, width);
	}
}

fn getNodePosition(x: u32, y: u32) -> vec2f {
	return vec2f(f32(x) / f32(u_nodes_x_count + 1), f32(y) / f32(u_nodes_y_count + 1));
}

fn easeInOutCubic(t: f32) -> f32 {
	return select(4.0 * t * t * t, 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0, t > 0.5);
}

struct Uniforms {
	scale: f32,
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
	let seed = 1000.0;
	let particlesCount = 4;
	var uv = fragData.uv;

	let step = floor(uniforms.time * 0.001);
	let stepProgress = fract(uniforms.time * 0.001);

	let prevX1 = u32(floor(snoise0to1(vec3f(1.0, 0.0, step - 1.0)) * f32(u_nodes_x_count)));
	let prevY1 = u32(floor(snoise0to1(vec3f(0.0, 1.0, step - 1.0)) * f32(u_nodes_y_count)));
	let prevX2 = u32(floor(snoise0to1(vec3f(1.0, 0.0, step - 2.0)) * f32(u_nodes_x_count)));
	let prevY2 = u32(floor(snoise0to1(vec3f(0.0, 1.0, step - 2.0)) * f32(u_nodes_y_count)));
	let prevX3 = u32(floor(snoise0to1(vec3f(1.0, 0.0, step - 3.0)) * f32(u_nodes_x_count)));
	let prevY3 = u32(floor(snoise0to1(vec3f(0.0, 1.0, step - 3.0)) * f32(u_nodes_y_count)));

	let currentX = u32(floor(snoise0to1(vec3f(1.0, 0.0, step)) * f32(u_nodes_x_count)));
	let currentY = u32(floor(snoise0to1(vec3f(0.0, 1.0, step)) * f32(u_nodes_y_count)));

	var v = 0.0;

	for (var i: u32 = 0; i < u_nodes_x_count; i++) {
		for (var j: u32 = 0; j < u_nodes_y_count; j++) {
			let radius = 0.015;
			if ((i == currentX && j == currentY)) {
				v += max(0.0, circleShape(uv, radius * min((easeInOutCubic(stepProgress) * 2.0), 1.0), getNodePosition(i + 1, j + 1)));
			} else if ((i == prevX1 && j == prevY1) || (i == prevX2 && j == prevY2) || (i == prevX3 && j == prevY3)) {
				v += max(0.0, circleShape(uv, radius, getNodePosition(i + 1, j + 1)));
			} else {
				v += max(0.0, circleShape(uv, radius, getNodePosition(i + 1, j + 1))) * 0.125;
			}
		}
	}

	v += lineShapeProgress(uv, getNodePosition(prevX1 + 1, prevY1 + 1), getNodePosition(currentX + 1, currentY + 1), 0.0025, easeInOutCubic(stepProgress) * 2.0 - 1.0);


	return vec4f(v, v, v, 1.0);
}
