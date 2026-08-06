import code from './shader.wgsl?raw';
import { metadata } from './meta.ts';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground } from '@/utils.ts';

export const playground = definePlayground({
	...metadata,
	alpha: true,
	backgroundColor: '#f7fcff',
	params: {
		divisions: { type: 'range', min: 1, max: 64, step: 1, label: 'Cell Divisions' },
		dutyCycle: { type: 'range', min: 0.0, max: 1.0, step: 0.01, label: 'Duty Cycle' },
		color: { type: 'color', label: 'Color' },
		outlineWidth: { type: 'range', min: 0.0, max: 0.05, step: 0.001, label: 'Outline Width' },
		outlineColor: { type: 'color', label: 'Outline Color' },
		test: { type: 'boolean', label: 'Test' },
	},
	getDefaultParams: () => ({
		divisions: 4,
		dutyCycle: 0.3,
		color: [0.88, 0.98, 1.0],
		outlineWidth: 0.005,
		outlineColor: [0.78, 0.88, 0.90],
		test: false,
	}),
	init: async ({ width, height, wgpu, params, canvas }) => {
		const shaderModule = wgpu.device.createShaderModule({
			code: code,
		});

		const pipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: shaderModule,
			},
			fragment: {
				module: shaderModule,
				targets: [{
					format: navigator.gpu.getPreferredCanvasFormat(),
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const defs = makeShaderDataDefinitions(code);
		const uniformValues = makeStructuredView(defs.uniforms.uniforms);

		const uniformBuffer = wgpu.device.createBuffer({
			size: uniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const bindGroup = wgpu.device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [
				{ binding: 1, resource: { buffer: uniformBuffer }},
			],
		});

		return {
			render: ctx => {
				uniformValues.set({
					aspectRatio: width / height,
					time: ctx.time,
					divisions: params.divisions,
					dutyCycle: params.dutyCycle,
					color: params.color,
					outlineWidth: params.outlineWidth,
					outlineColor: params.outlineColor,
					test: params.test ? 1 : 0,
				});
				wgpu.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

				const passEncoder = ctx.createPassEncoder(ctx.commandEncoder);
				passEncoder.setPipeline(pipeline);
				passEncoder.setBindGroup(0, bindGroup);
				passEncoder.draw(6);
				passEncoder.end();
			},
		};
	},
});
