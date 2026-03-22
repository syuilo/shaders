import code from './shader.wgsl?raw';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground } from '@/utils.ts';

export const playground = definePlayground({
	title: 'Colors',
	params: {
		scale: { type: 'range', min: 0.1, max: 4, step: 0.1, label: 'Scale' },
	},
	getDefaultParams: () => ({
		scale: 1.0,
	}),
	init: async ({ width, height, wgpu, params }) => {
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
					scale: params.scale,
				});
				wgpu.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

				const passEncoder = ctx.commandEncoder.beginRenderPass({
					colorAttachments: [{
						view: wgpu.context.getCurrentTexture().createView(),
						clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
						loadOp: 'clear',
						storeOp: 'store',
					}],
				});
				passEncoder.setPipeline(pipeline);
				passEncoder.setBindGroup(0, bindGroup);
				passEncoder.draw(6);
				passEncoder.end();
			},
		};
	},
});
