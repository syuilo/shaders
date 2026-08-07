import code from './shader.wgsl?raw';
import { metadata } from './meta.ts';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground } from '@/utils.ts';

export const playground = definePlayground({
	...metadata,
	params: {
		divisions: { type: 'range', min: 8, max: 512, step: 1, label: 'Cell Divisions' },
		test: { type: 'boolean', label: 'Test' },
	},
	getDefaultParams: () => ({
		divisions: 8,
		test: false,
	}),
	init: async ({ width, height, wgpu, params, canvas }) => {
		const shaderModule = wgpu.device.createShaderModule({
			code: code,
		});

		const pipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
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
