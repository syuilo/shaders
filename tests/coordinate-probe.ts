import colorsShader from '../src/shaders/colors/shader.wgsl?raw';
import cyberShader from '../src/shaders/cyber/shader.wgsl?raw';
import liquidPaintShader from '../src/shaders/liquid-paint/shader.wgsl?raw';
import moonPhaseShader from '../src/shaders/moon-phase/shader.wgsl?raw';
import nazoShader from '../src/shaders/nazo/shader.wgsl?raw';
import rainDropsShader from '../src/shaders/rain-drops/shader.wgsl?raw';
import wavingDotsShader from '../src/shaders/waving-dots/shader.wgsl?raw';
import wavingDots2Shader from '../src/shaders/waving-dots-2/shader.wgsl?raw';
import wavingDots3Shader from '../src/shaders/waving-dots-3/shader.wgsl?raw';
import vertexShader from '../src/vertex.wgsl?raw';
import { createCyberMainBindGroupEntries } from '../src/shaders/cyber/bind-group-entries.ts';
import { createLiquidPaintBlurLightBindGroupEntries } from '../src/shaders/liquid-paint/bind-group-entries.ts';
import { assertProbeValues } from './coordinate-probe-values.mjs';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';

type Vec2 = readonly [number, number];

type Probe = {
	name: string;
	shader: string;
	expected: readonly Vec2[];
	probeBody?: string;
};

const result = document.querySelector<HTMLPreElement>('#result');

if (!result) {
	throw new Error('Missing #result element');
}

const commonExpected = [
	[1, 0.5625],
	[0.28125, -0.25],
	[0.5, -0.25],
	[-0.75, 0.28125],
	[-0.75, 0.5],
] as const satisfies readonly Vec2[];

const probes: readonly Probe[] = [
	{ name: 'colors', shader: colorsShader, expected: commonExpected },
	{
		name: 'cyber',
		shader: cyberShader,
		expected: [
			...commonExpected,
			[0.421875, 1],
			[1, 0.75],
			[4 / 3, 1],
			[1, 64 / 27],
			[0.015625, 0.015625],
			[0.046875, 0.046875],
			[0.421875, -0.75],
			[0.421875, -0.75],
			[0.265625, -0.515625],
			[-0.734375, 0.109375],
			[0.203125, -0.453125],
			[-0.796875, 0.171875],
			[-0.05, 0.0625],
			[0.0125, 0.1875],
		],
		probeBody: `
	probeOutput[5] = getScreenNdcToSourceNdcScale(9.0 / 16.0, 4.0 / 3.0, true);
	probeOutput[6] = getScreenNdcToSourceNdcScale(16.0 / 9.0, 4.0 / 3.0, true);
	probeOutput[7] = getScreenNdcToSourceNdcScale(16.0 / 9.0, 4.0 / 3.0, false);
	probeOutput[8] = getScreenNdcToSourceNdcScale(9.0 / 16.0, 4.0 / 3.0, false);
	probeOutput[9] = getAdaptiveCellSampleOffset(2.0 / 64.0, 2.0);
	probeOutput[10] = getAdaptiveCellSampleOffset(2.0 / 64.0, 4.0);
	probeOutput[11] = screenNdcUvToSourceNdcUv(vec2f(0.75, -0.5))
		- screenNdcUvToSourceNdcUv(vec2f(-0.25, 0.25));
	probeOutput[12] = screenNdcVectorToSourceNdcVector(vec2f(1.0, -0.75));
	let adaptiveOffset2 = getAdaptiveCellSampleOffset(2.0 / 64.0, 2.0);
	let adaptiveOffset4 = getAdaptiveCellSampleOffset(2.0 / 64.0, 4.0);
	probeOutput[13] = vec2f(0.25, -0.5) + vec2f(adaptiveOffset2.x, -adaptiveOffset2.y);
	probeOutput[14] = vec2f(-0.75, 0.125) + vec2f(adaptiveOffset2.x, -adaptiveOffset2.y);
	probeOutput[15] = vec2f(0.25, -0.5) + vec2f(-adaptiveOffset4.x, adaptiveOffset4.y);
	probeOutput[16] = vec2f(-0.75, 0.125) + vec2f(-adaptiveOffset4.x, adaptiveOffset4.y);
	let symbolShiftAspectVector = getSymbolShiftAspectVector(
		vec2f(0.4, -0.25),
		vec2f(0.125, 0.25),
	);
	probeOutput[17] = symbolShiftAspectVector;
	probeOutput[18] = getShiftedCellLocalAspectUv(
		vec2f(0.0625, 0.125),
		symbolShiftAspectVector,
	);`,
	},
	{
		name: 'liquid-paint',
		shader: liquidPaintShader,
		expected: [...commonExpected, [0.25, -0.5]],
		probeBody: `
	probeOutput[5] = getWarpedSourceAspectUv(
		vec2f(0.25, -0.5),
		vec2f(0.5, -1.0),
		vec2f(0.5, -1.0),
		0.0,
	);`,
	},
	{ name: 'moon-phase', shader: moonPhaseShader, expected: commonExpected },
	{ name: 'nazo', shader: nazoShader, expected: commonExpected },
	{ name: 'rain-drops', shader: rainDropsShader, expected: commonExpected },
	{ name: 'waving-dots', shader: wavingDotsShader, expected: commonExpected },
	{ name: 'waving-dots-2', shader: wavingDots2Shader, expected: commonExpected },
	{ name: 'waving-dots-3', shader: wavingDots3Shader, expected: commonExpected },
];

const makeProbeShader = (probe: Probe) => `${probe.shader}

@group(3) @binding(0) var<storage, read_write> probeOutput: array<vec2f>;

@compute @workgroup_size(1)
fn probeCoordinates() {
	probeOutput[0] = getScreenNdcToAspectScale(16.0 / 9.0);
	probeOutput[1] = screenNdcUvToAspectUv(vec2f(0.5, -0.25), 9.0 / 16.0);
	probeOutput[2] = aspectUvToScreenNdcUv(vec2f(0.28125, -0.25), 9.0 / 16.0);
	probeOutput[3] = screenNdcVectorToAspectVector(vec2f(-0.75, 0.5), 16.0 / 9.0);
	probeOutput[4] = aspectVectorToScreenNdcVector(vec2f(-0.75, 0.28125), 16.0 / 9.0);
${probe.probeBody ?? ''}
}
`;

const formatCompilationErrors = async (module: GPUShaderModule) => {
	const compilationInfo = await module.getCompilationInfo();
	const errors = compilationInfo.messages.filter((message) => message.type === 'error');
	return errors.map((message) => message.message).join('\n');
};

const runWithValidationScope = async (
	device: GPUDevice,
	name: string,
	operation: () => Promise<void>,
) => {
	device.pushErrorScope('validation');
	let operationError: unknown;
	try {
		await operation();
	} catch (error) {
		operationError = error;
	}
	const validationError = await device.popErrorScope();
	if (operationError) {
		throw new Error(`${name}: ${operationError instanceof Error ? operationError.message : String(operationError)}`);
	}
	if (validationError) {
		throw new Error(`${name}: ${validationError.message}`);
	}
};

const validateCyberWithoutSourceLayout = async (device: GPUDevice) => {
	const resources: Array<{ destroy(): void }> = [];
	await runWithValidationScope(device, 'cyber fsWithoutSource production layout', async () => {
		const vertexModule = device.createShaderModule({ code: vertexShader });
		const fragmentModule = device.createShaderModule({ code: cyberShader });
		const pipeline = await device.createRenderPipelineAsync({
			layout: 'auto',
			vertex: { module: vertexModule },
			fragment: {
				module: fragmentModule,
				entryPoint: 'fsWithoutSource',
				targets: [{ format: 'rgba8unorm' }],
			},
		});
		const uniformBuffer = device.createBuffer({
			size: 1024,
			usage: GPUBufferUsage.UNIFORM,
		});
		const symbolTexture = device.createTexture({
			size: { width: 1, height: 1, depthOrArrayLayers: 1 },
			format: 'rgba8unorm',
			usage: GPUTextureUsage.TEXTURE_BINDING,
		});
		const sourceTexture = device.createTexture({
			size: [1, 1],
			format: 'rgba8unorm',
			usage: GPUTextureUsage.TEXTURE_BINDING,
		});
		const pointerTrailTexture = device.createTexture({
			size: [1, 1],
			format: 'rgba8unorm',
			usage: GPUTextureUsage.TEXTURE_BINDING,
		});
		const outputTexture = device.createTexture({
			size: [1, 1],
			format: 'rgba8unorm',
			usage: GPUTextureUsage.RENDER_ATTACHMENT,
		});
		resources.push(uniformBuffer, symbolTexture, sourceTexture, pointerTrailTexture, outputTexture);
		const bindGroup = device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: createCyberMainBindGroupEntries({
				uniformBuffer,
				sampler: device.createSampler(),
				symbolTexturesView: symbolTexture.createView({ dimension: '2d-array' }),
				sourceTextureView: sourceTexture.createView(),
				pointerTrailBufferView: pointerTrailTexture.createView(),
				hasSource: false,
			}),
		});
		const encoder = device.createCommandEncoder();
		const pass = encoder.beginRenderPass({
			colorAttachments: [{
				view: outputTexture.createView(),
				loadOp: 'clear',
				storeOp: 'store',
			}],
		});
		pass.setPipeline(pipeline);
		pass.setBindGroup(0, bindGroup);
		pass.draw(6);
		pass.end();
		device.queue.submit([encoder.finish()]);
		await device.queue.onSubmittedWorkDone();
	});
	for (const resource of resources) resource.destroy();
};

const validateLiquidPaintBlurLightLayout = async (device: GPUDevice) => {
	const resources: Array<{ destroy(): void }> = [];
	await runWithValidationScope(device, 'liquid-paint fsBlurLight production layout', async () => {
		const vertexModule = device.createShaderModule({ code: vertexShader });
		const fragmentModule = device.createShaderModule({ code: liquidPaintShader });
		const pipeline = await device.createRenderPipelineAsync({
			layout: 'auto',
			vertex: { module: vertexModule },
			fragment: {
				module: fragmentModule,
				entryPoint: 'fsBlurLight',
				targets: [{ format: 'rgba8unorm' }],
			},
		});
		const commonUniformBuffer = device.createBuffer({
			size: 1024,
			usage: GPUBufferUsage.UNIFORM,
		});
		const blurUniformBuffer = device.createBuffer({
			size: 32,
			usage: GPUBufferUsage.UNIFORM,
		});
		const targetTexture = device.createTexture({
			size: [1, 1],
			format: 'rgba8unorm',
			usage: GPUTextureUsage.TEXTURE_BINDING,
		});
		const blurRadiusTexture = device.createTexture({
			size: [1, 1],
			format: 'rgba8unorm',
			usage: GPUTextureUsage.TEXTURE_BINDING,
		});
		const outputTexture = device.createTexture({
			size: [1, 1],
			format: 'rgba8unorm',
			usage: GPUTextureUsage.RENDER_ATTACHMENT,
		});
		resources.push(commonUniformBuffer, blurUniformBuffer, targetTexture, blurRadiusTexture, outputTexture);
		const bindGroup = device.createBindGroup({
			layout: pipeline.getBindGroupLayout(1),
			entries: createLiquidPaintBlurLightBindGroupEntries({
				commonUniformBuffer,
				blurUniformBuffer,
				sampler: device.createSampler(),
				targetTextureView: targetTexture.createView(),
				blurRadiusTextureView: blurRadiusTexture.createView(),
			}),
		});
		const encoder = device.createCommandEncoder();
		const pass = encoder.beginRenderPass({
			colorAttachments: [{
				view: outputTexture.createView(),
				loadOp: 'clear',
				storeOp: 'store',
			}],
		});
		pass.setPipeline(pipeline);
		pass.setBindGroup(1, bindGroup);
		pass.draw(6);
		pass.end();
		device.queue.submit([encoder.finish()]);
		await device.queue.onSubmittedWorkDone();
	});
	for (const resource of resources) resource.destroy();
};

const readProbe = async (device: GPUDevice, probe: Probe) => {
	const module = device.createShaderModule({ code: makeProbeShader(probe) });
	const compilationErrors = await formatCompilationErrors(module);
	if (compilationErrors) {
		throw new Error(`${probe.name}: compilation failed: ${compilationErrors}`);
	}

	const pipeline = await device.createComputePipelineAsync({
		layout: 'auto',
		compute: { module, entryPoint: 'probeCoordinates' },
	});
	const byteLength = probe.expected.length * Float32Array.BYTES_PER_ELEMENT * 2;
	const outputBuffer = device.createBuffer({
		size: byteLength,
		usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
	});
	const readbackBuffer = device.createBuffer({
		size: byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ,
	});
	const encoder = device.createCommandEncoder();
	const pass = encoder.beginComputePass();
	pass.setPipeline(pipeline);
	let uniformBuffer: GPUBuffer | undefined;
	if (probe.name === 'cyber') {
		const definitions = makeShaderDataDefinitions(probe.shader);
		const uniformValues = makeStructuredView(definitions.uniforms.uniforms);
		uniformValues.set({
			aspectRatio: 9 / 16,
			sourceAspectRatio: 4 / 3,
			coverSource: 1,
		});
		uniformBuffer = device.createBuffer({
			size: uniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});
		device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);
		pass.setBindGroup(0, device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [{ binding: 1, resource: { buffer: uniformBuffer } }],
		}));
	}
	pass.setBindGroup(3, device.createBindGroup({
		layout: pipeline.getBindGroupLayout(3),
		entries: [{ binding: 0, resource: { buffer: outputBuffer } }],
	}));
	pass.dispatchWorkgroups(1);
	pass.end();
	encoder.copyBufferToBuffer(outputBuffer, 0, readbackBuffer, 0, byteLength);
	device.queue.submit([encoder.finish()]);

	await readbackBuffer.mapAsync(GPUMapMode.READ);
	const values = new Float32Array(readbackBuffer.getMappedRange().slice(0));
	readbackBuffer.unmap();
	outputBuffer.destroy();
	readbackBuffer.destroy();
	uniformBuffer?.destroy();

	const actual = probe.expected.map((_, index) => [values[index * 2], values[(index * 2) + 1]] as const);
	assertProbeValues(probe.name, actual, probe.expected);
};

const run = async () => {
	if (!navigator.gpu) {
		throw new Error('WebGPU is unavailable in this browser');
	}
	const adapter = await navigator.gpu.requestAdapter();
	if (!adapter) {
		throw new Error('WebGPU adapter is unavailable');
	}
	const device = await adapter.requestDevice();
	for (const probe of probes) {
		await readProbe(device, probe);
	}
	const layoutErrors: string[] = [];
	for (const check of [validateCyberWithoutSourceLayout, validateLiquidPaintBlurLightLayout]) {
		try {
			await check(device);
		} catch (error) {
			layoutErrors.push(error instanceof Error ? error.message : String(error));
		}
	}
	if (layoutErrors.length > 0) {
		throw new Error(layoutErrors.join('\n'));
	}
};

void run().then(
	() => {
		result.textContent = 'PASS';
	},
	(error: unknown) => {
		result.textContent = `FAIL\n${error instanceof Error ? error.message : String(error)}`;
	},
);
