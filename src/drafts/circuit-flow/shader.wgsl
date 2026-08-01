struct VertexOut {
	@builtin(position) position: vec4f,
	@location(0) uv: vec2f,
};

const vertices = array(
	vec2f(-1.0, -1.0),
	vec2f( 1.0, -1.0),
	vec2f(-1.0,  1.0),
	vec2f(-1.0,  1.0),
	vec2f( 1.0, -1.0),
	vec2f( 1.0,  1.0),
);

struct Uniforms {
	aspectRatio: f32,
	time: f32,
	scale: f32,
	seed: f32,
	density: f32,
	flowSpeed: f32,
	lineWidth: f32,
	flowDensity: f32,
	backgroundColor: vec3f,
	traceColor: vec3f,
	flowColor: vec3f,
};

@group(0) @binding(1) var<uniform> uniforms: Uniforms;

@vertex
fn vs(@builtin(vertex_index) vertexIndex: u32) -> VertexOut {
	let position = vertices[vertexIndex];
	var output: VertexOut;
	output.position = vec4f(position, 0.0, 1.0);
	output.uv = position;
	return output;
}

fn hash21(position: vec2f, seed: f32) -> f32 {
	var value = fract(vec3f(position.x, position.y, position.x) * 0.1031);
	let offset = vec3f(33.33 + seed * 0.0137);
	let perturbation = dot(value, value.yzx + offset);
	value += vec3f(perturbation);
	return fract((value.x + value.y) * value.z);
}

fn canonicalEdgeKey(node: vec2f, edgeIndex: u32) -> vec3f {
	var anchor = node;
	var orientation = 0.0;
	if (edgeIndex == 1u) {
		anchor.x -= 1.0;
	} else if (edgeIndex == 2u) {
		orientation = 1.0;
	} else if (edgeIndex == 3u) {
		anchor.y -= 1.0;
		orientation = 1.0;
	}
	return vec3f(anchor, orientation);
}

fn edgeHash(node: vec2f, edgeIndex: u32) -> f32 {
	let key = canonicalEdgeKey(node, edgeIndex);
	let keyedAnchor = key.xy + vec2f(key.z * 19.19, key.z * 41.73);
	return hash21(keyedAnchor, uniforms.seed);
}

fn flowEdgeHash(node: vec2f, edgeIndex: u32) -> f32 {
	let key = canonicalEdgeKey(node, edgeIndex);
	let keyedAnchor = key.xy
		+ vec2f(157.31, 283.17)
		+ vec2f(key.z * 71.13, key.z * 43.79);
	return hash21(keyedAnchor, uniforms.seed + 211.0);
}

const PULSE_SPACING = 5.0;

fn nodePhase(node: vec2f) -> f32 {
	let phasePosition = node + vec2f(113.5, 271.9);
	return hash21(phasePosition, uniforms.seed + 97.0) * PULSE_SPACING;
}

fn wrappedPhaseDelta(from_: f32, to: f32) -> f32 {
	let delta = to - from_;
	return delta - round(delta / PULSE_SPACING) * PULSE_SPACING;
}

fn distanceToSegment(point: vec2f, start: vec2f, end: vec2f) -> f32 {
	let segment = end - start;
	let progress = clamp(dot(point - start, segment) / dot(segment, segment), 0.0, 1.0);
	return distance(point, start + segment * progress);
}

fn lineMask(distanceFromLine: f32, radius: f32, antialias: f32) -> f32 {
	return 1.0 - smoothstep(radius, radius + antialias, distanceFromLine);
}

fn pulseMask(phase: f32) -> f32 {
	let pulseDistance = abs(fract(phase) - 0.5);
	return 1.0 - smoothstep(0.025, 0.10, pulseDistance);
}

@fragment
fn fs(fragment: VertexOut) -> @location(0) vec4f {
	let aspectScale = select(
		vec2f(1.0, 1.0 / uniforms.aspectRatio),
		vec2f(uniforms.aspectRatio, 1.0),
		uniforms.aspectRatio >= 1.0,
	);
	let gridPosition = fragment.uv * aspectScale * uniforms.scale * 4.0;
	let node = floor(gridPosition + 0.5);
	let localPosition = gridPosition - node;
	let directions = array(
		vec2f( 1.0,  0.0),
		vec2f(-1.0,  0.0),
		vec2f( 0.0,  1.0),
		vec2f( 0.0, -1.0),
	);

	let antialias = max(fwidth(gridPosition.x), fwidth(gridPosition.y)) * 0.75;
	let timeSeconds = uniforms.time * 0.001;
	let currentNodePhase = nodePhase(node);
	var activeEdgeCount = 0u;
	var flowEdgeCount = 0u;
	var trace = 0.0;
	var flowCore = 0.0;
	var flowGlow = 0.0;

	for (var edgeIndex = 0u; edgeIndex < 4u; edgeIndex++) {
		if (edgeHash(node, edgeIndex) >= uniforms.density) {
			continue;
		}

		activeEdgeCount += 1u;
		let edgeDirection = directions[edgeIndex];
		let distanceFromEdge = distanceToSegment(
			localPosition,
			vec2f(0.0),
			edgeDirection * 0.5,
		);
		trace = max(trace, lineMask(distanceFromEdge, uniforms.lineWidth, antialias));

		if (flowEdgeHash(node, edgeIndex) >= uniforms.flowDensity) {
			continue;
		}

		flowEdgeCount += 1u;
		let edgeProgress = clamp(dot(localPosition, edgeDirection), 0.0, 0.5);
		let neighborPhase = nodePhase(node + edgeDirection);
		let phaseDelta = wrappedPhaseDelta(currentNodePhase, neighborPhase);
		let phaseAlongEdge = currentNodePhase + phaseDelta * edgeProgress;
		let pulse = pulseMask((phaseAlongEdge - timeSeconds * uniforms.flowSpeed) / PULSE_SPACING);

		flowCore = max(flowCore, pulse * lineMask(distanceFromEdge, uniforms.lineWidth * 0.4, antialias));
		flowGlow = max(flowGlow, pulse * lineMask(distanceFromEdge, uniforms.lineWidth * 4.0, antialias));
	}

	var padRadius = 0.0;
	if (activeEdgeCount == 1u) {
		padRadius = uniforms.lineWidth * 2.25;
	} else if (activeEdgeCount >= 3u) {
		padRadius = uniforms.lineWidth * 1.75;
	}
	if (padRadius > 0.0) {
		let distanceFromNode = length(localPosition);
		trace = max(trace, lineMask(distanceFromNode, padRadius, antialias));

		if (flowEdgeCount > 0u) {
			let nodePulse = pulseMask((currentNodePhase - timeSeconds * uniforms.flowSpeed) / PULSE_SPACING);
			flowCore = max(flowCore, nodePulse * lineMask(distanceFromNode, padRadius * 0.45, antialias));
			flowGlow = max(flowGlow, nodePulse * lineMask(distanceFromNode, padRadius * 2.5, antialias));
		}
	}

	var color = mix(uniforms.backgroundColor, uniforms.traceColor, trace);
	color += uniforms.flowColor * flowGlow * 0.22;
	color = mix(color, uniforms.flowColor, flowCore);
	return vec4f(color, 1.0);
}
