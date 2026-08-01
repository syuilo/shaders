import code from './shader.wgsl?raw';
import { metadata } from './meta.ts';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground } from '@/utils.ts';

export const playground = definePlayground({
	...metadata,
	params: {
		scale: { type: 'range', min: 0.25, max: 8, step: 0.05, label: 'Scale' },
		seed: { type: 'range', min: 0, max: 10000, step: 1, label: 'Seed' },
		density: { type: 'range', min: 0.2, max: 0.9, step: 0.01, label: 'Circuit Density' },
		flowDensity: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Flow Density' },
		flowSpeed: { type: 'range', min: 0, max: 4, step: 0.05, label: 'Flow Speed' },
		lineWidth: { type: 'range', min: 0.01, max: 0.15, step: 0.005, label: 'Line Width' },
		backgroundColor: { type: 'color', label: 'Background Color' },
		traceColor: { type: 'color', label: 'Trace Color' },
		flowColor: { type: 'color', label: 'Flow Color' },
	},
	getDefaultParams: () => ({
		scale: 2,
		seed: 1,
		density: 0.62,
		flowDensity: 0.5,
		flowSpeed: 1,
		lineWidth: 0.045,
		backgroundColor: [0.004, 0.012, 0.018],
		traceColor: [0.03, 0.18, 0.20],
		flowColor: [0.55, 1, 1],
	}),
	init: async ({ width, height, wgpu, params }) => {
		const shaderModule = wgpu.device.createShaderModule({ code });
		const pipeline = wgpu.device.createRenderPipeline({
			vertex: { module: shaderModule, entryPoint: 'vs' },
			fragment: {
				module: shaderModule,
				entryPoint: 'fs',
				targets: [{ format: navigator.gpu.getPreferredCanvasFormat() }],
			},
			primitive: { topology: 'triangle-list' },
			layout: 'auto',
		});

		const definitions = makeShaderDataDefinitions(code);
		const uniformValues = makeStructuredView(definitions.uniforms.uniforms);
		const uniformBuffer = wgpu.device.createBuffer({
			size: uniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});
		const bindGroup = wgpu.device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [{ binding: 1, resource: { buffer: uniformBuffer } }],
		});

		return {
			render: ctx => {
				uniformValues.set({
					aspectRatio: width / height,
					time: ctx.time,
					scale: params.scale,
					seed: params.seed,
					density: params.density,
					flowDensity: params.flowDensity,
					flowSpeed: params.flowSpeed,
					lineWidth: params.lineWidth,
					backgroundColor: params.backgroundColor,
					traceColor: params.traceColor,
					flowColor: params.flowColor,
				});
				wgpu.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

				const passEncoder = ctx.commandEncoder.beginRenderPass({
					colorAttachments: [{
						view: wgpu.context.getCurrentTexture().createView(),
						clearValue: {
							r: params.backgroundColor[0],
							g: params.backgroundColor[1],
							b: params.backgroundColor[2],
							a: 1,
						},
						loadOp: 'clear',
						storeOp: 'store',
					}],
				});
				passEncoder.setPipeline(pipeline);
				passEncoder.setBindGroup(0, bindGroup);
				passEncoder.draw(6);
				passEncoder.end();
			},
			dispose: () => uniformBuffer.destroy(),
		};
	},
});
