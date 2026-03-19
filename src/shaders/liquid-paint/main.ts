import code from './shader.wgsl?raw';
import { createTextureFromSource, makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground, isIos, remap } from '@/utils.ts';

export const playground = definePlayground({
	title: 'Liquid Paint',
	params: {
		source: { type: 'media', needReinit: true, label: 'Source' },
		scale: { type: 'range', min: 0.1, max: 2, step: 0.1, label: 'Scale' },
		pallette: { type: 'enum', label: 'Pallette', enum: [{
			value: 'colorful', label: 'Colorful'
		}, {
			value: 'cider', label: 'Cider'
		}, {
			value: 'psyche', label: 'Psyche'
		}, {
			value: 'pastel', label: 'Pastel'
		}, {
			value: 'iridescence', label: 'Iridescence'
		}, {
			value: 'lava', label: 'Lava'
		}] },
		discardThreshold: { type: 'range', min: -1, max: 1, step: 0.1, label: 'Discard Threshold' },
		channelAFactor: { type: 'range', min: -4, max: 4, step: 0.1, label: 'Channel A Factor' },
		channelBFactor: { type: 'range', min: -4, max: 4, step: 0.1, label: 'Channel B Factor' },
		channelCFactor: { type: 'range', min: -4, max: 4, step: 0.1, label: 'Channel C Factor' },
		turbulenceEnabled: { type: 'boolean', label: 'Turbulence Enabled' },
		turbulenceScale: { type: 'range', min: 0, max: 32, step: 0.1, label: 'Turbulence Scale' },
		blurTurbulenceEnabled: { type: 'boolean', label: 'Blur Turbulence Enabled' },
		blurStrength: { type: 'range', min: 0, max: 3, step: 0.1, label: 'Blur Strength' },
		blurExtend: { type: 'range', min: -1, max: 1, step: 0.01, label: 'Blur Extend' },
		blurQuality: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Blur Quality' },
		blurMethod: { type: 'enum', label: 'Blur Method', enum: [{
			value: 'standard', label: 'Standard'
		}, {
			value: 'monteCarlo', label: 'Monte Carlo'
		}, {
			value: 'twoPass', label: 'Two Pass'
		}]},
	},
	getDefaultParams: () => ({
		source: null,
		scale: 1.0,
		turbulenceEnabled: true,
		turbulenceScale: 1.5,
		pallette: 'cider',
		discardThreshold: -0.2,
		channelAFactor: 1.0,
		channelBFactor: 1.0,
		channelCFactor: 1.0,
		blurTurbulenceEnabled: true,
		blurStrength: 1.0,
		blurExtend: 0.0,
		blurQuality: 0.25,
		blurMethod: isIos ? 'twoPass' : 'standard',
	}),
	init: async ({ width, height, wgpu, params, canvas }) => {
		const shaderModule = wgpu.device.createShaderModule({
			code: code,
		});

		const shaderDataDefinitions = makeShaderDataDefinitions(code);

		const sourceTexture = createTextureFromSource(wgpu.device, params.source?.element ?? [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], {
			mips: params.source != null && params.source.type === 'video' ? false : true,
		});

		const pointerTrailPipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: shaderModule,
				entryPoint: 'vs',
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fsPointerTrail',
				targets: [{
					format: navigator.gpu.getPreferredCanvasFormat(),
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const pointerTrailBufferBefore = wgpu.device.createTexture({
			size: { width, height },
			format: navigator.gpu.getPreferredCanvasFormat(),
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC | GPUTextureUsage.COPY_DST,
		});

		const pointerTrailBufferAfter = wgpu.device.createTexture({
			size: { width, height },
			format: navigator.gpu.getPreferredCanvasFormat(),
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC | GPUTextureUsage.COPY_DST,
		});

		const pointerTrailUniformValues = makeStructuredView(shaderDataDefinitions.uniforms.pointerTrailUniforms);
		const pointerTrailUniformBuffer = wgpu.device.createBuffer({
			size: pointerTrailUniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const pointerTrailBindGroup = wgpu.device.createBindGroup({
			layout: pointerTrailPipeline.getBindGroupLayout(2),
			entries: [
				{ binding: 1, resource: { buffer: pointerTrailUniformBuffer }},
				{ binding: 2, resource: wgpu.sampler },
				{ binding: 3, resource: pointerTrailBufferBefore.createView() }
			],
		});

		let pointerX = -99999.0;
		let pointerY = -99999.0;
		let pointerXPrev = pointerX;
		let pointerYPrev = pointerY;
		let lastPointerMovedAt = 0;

		const onPointerMove = (ev: PointerEvent) => {
			const rect = canvas.getBoundingClientRect();
			const w = rect.width;
			const h = rect.height;
			const x = (ev.clientX - rect.left) / w;
			const y = (ev.clientY - rect.top) / h;
			// 0~1 -> -1~1
			pointerX = x * 2 - 1;
			pointerY = y * 2 - 1;
			lastPointerMovedAt = performance.now();
		};

		window.addEventListener('pointermove', onPointerMove);

		const pipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: shaderModule,
				entryPoint: 'vs',
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fs',
				targets: [{
					format: navigator.gpu.getPreferredCanvasFormat(),
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const uniformValues = makeStructuredView(shaderDataDefinitions.uniforms.uniforms);

		const uniformBuffer = wgpu.device.createBuffer({
			size: uniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const bindGroup = wgpu.device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [
				{ binding: 1, resource: { buffer: uniformBuffer }},
				{ binding: 2, resource: wgpu.sampler },
				{ binding: 3, resource: sourceTexture.createView() },
				{ binding: 4, resource: pointerTrailBufferAfter.createView() },
			],
		});

		const buffer = wgpu.device.createTexture({
			size: { width, height },
			format: navigator.gpu.getPreferredCanvasFormat(),
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
		});

		const buffer2 = wgpu.device.createTexture({
			size: { width, height },
			format: navigator.gpu.getPreferredCanvasFormat(),
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
		});

		const blurPipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: shaderModule,
				entryPoint: 'vs',
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fsBlur',
				targets: [{
					format: navigator.gpu.getPreferredCanvasFormat(),
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const blurLqPipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: shaderModule,
				entryPoint: 'vs',
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fsBlurLight',
				targets: [{
					format: navigator.gpu.getPreferredCanvasFormat(),
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const blurUniformValues = makeStructuredView(shaderDataDefinitions.uniforms.blurUniforms);
		const blurUniformBuffer = wgpu.device.createBuffer({
			size: blurUniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const blurHorizontalUniformValues = makeStructuredView(shaderDataDefinitions.uniforms.blurUniforms);
		const blurHorizontalUniformBuffer = wgpu.device.createBuffer({
			size: blurHorizontalUniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const blurVerticalUniformValues = makeStructuredView(shaderDataDefinitions.uniforms.blurUniforms);
		const blurVerticalUniformBuffer = wgpu.device.createBuffer({
			size: blurVerticalUniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		return {
			render: ctx => {
				if (params.source != null && params.source.type === 'video' && params.source.element.readyState >= 4) {
					wgpu.device.queue.copyExternalImageToTexture(
						{ source: params.source.element },
						{ texture: sourceTexture },
						{ width: sourceTexture.width, height: sourceTexture.height },
					);
				}

				if (lastPointerMovedAt + 30 < performance.now()) {
					pointerX = -99999.0;
					pointerY = -99999.0;
				}

				const pointerVectorX = pointerXPrev === -99999.0 ? 0 : pointerX - pointerXPrev;
				const pointerVectorY = pointerYPrev === -99999.0 ? 0 : pointerY - pointerYPrev;

				pointerXPrev = pointerX;
				pointerYPrev = pointerY;

				{ // pointer trail pass
					ctx.commandEncoder.copyTextureToTexture({ texture: pointerTrailBufferAfter }, { texture: pointerTrailBufferBefore }, { width, height });

					pointerTrailUniformValues.set({
						scale: params.scale,
						aspectRatio: width / height,
						timeDelta: ctx.timeDelta,
						pointerPosition: [pointerX, -pointerY],
						pointerVector: [pointerVectorX, -pointerVectorY],
					});
					wgpu.device.queue.writeBuffer(pointerTrailUniformBuffer, 0, pointerTrailUniformValues.arrayBuffer);

					const passEncoder = ctx.commandEncoder.beginRenderPass({
						colorAttachments: [{
							view: pointerTrailBufferAfter.createView(),
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}],
					});
					passEncoder.setPipeline(pointerTrailPipeline);
					passEncoder.setBindGroup(2, pointerTrailBindGroup);
					passEncoder.draw(6);
					passEncoder.end();
				}

				{ // main pass
					uniformValues.set({
						scale: params.scale,
						aspectRatio: width / height,
						time: ctx.time,
						turbulenceEnabled: params.turbulenceEnabled ? 1.0 : 0.0,
						turbulenceScale: params.turbulenceScale,
						pallette: params.pallette === 'colorful' ? 0.0 : params.pallette === 'cider' ? 1.0 : params.pallette === 'psyche' ? 2.0 : params.pallette === 'pastel' ? 3.0 : params.pallette === 'iridescence' ? 4.0 : params.pallette === 'lava' ? 5.0 : 0.0,
						discardThreshold: params.discardThreshold,
						channelAFactor: params.channelAFactor,
						channelBFactor: params.channelBFactor,
						channelCFactor: params.channelCFactor,
						hasSource: params.source != null ? 1.0 : 0.0,
						coverSource: 1.0,
						sourceAspectRatio: sourceTexture.width / sourceTexture.height,
					});
					wgpu.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

					const passEncoder = ctx.commandEncoder.beginRenderPass({
						colorAttachments: [{
							view: buffer.createView(),
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}],
					});
					passEncoder.setPipeline(pipeline);
					passEncoder.setBindGroup(0, bindGroup);
					passEncoder.draw(6);
					passEncoder.end();
				}

				if (params.blurMethod === 'twoPass') {
					{ // two-pass blur pass - horizontal
						blurHorizontalUniformValues.set({
							isHorizontal: 1.0,
							turbulenceEnabled: params.blurTurbulenceEnabled ? 1.0 : 0.0,
							turbulenceScale: params.turbulenceScale,
							strength: params.blurStrength,
							extend: params.blurExtend,
							quality: Math.round(remap(params.blurQuality, 0, 1, 1, 32)),
							isIos: isIos ? 1.0 : 0.0,
						});
						wgpu.device.queue.writeBuffer(blurHorizontalUniformBuffer, 0, blurHorizontalUniformValues.arrayBuffer);

						const passEncoder = ctx.commandEncoder.beginRenderPass({
							colorAttachments: [{
								view: buffer2.createView(),
								clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
								loadOp: 'clear',
								storeOp: 'store',
							}],
						});
						passEncoder.setPipeline(blurLqPipeline);
						passEncoder.setBindGroup(1, wgpu.device.createBindGroup({
							layout: blurLqPipeline.getBindGroupLayout(1),
							entries: [
								{ binding: 1, resource: { buffer: uniformBuffer }},
								{ binding: 2, resource: { buffer: blurHorizontalUniformBuffer }},
								{ binding: 3, resource: wgpu.sampler },
								{ binding: 4, resource: buffer.createView() },
								{ binding: 5, resource: pointerTrailBufferAfter.createView() },
							],
						}));
						passEncoder.draw(6);
						passEncoder.end();
					}

					{ // two-pass blur pass - vertical
						blurVerticalUniformValues.set({
							isHorizontal: 0.0,
							turbulenceEnabled: params.blurTurbulenceEnabled ? 1.0 : 0.0,
							turbulenceScale: params.turbulenceScale,
							strength: params.blurStrength,
							extend: params.blurExtend,
							quality: Math.round(remap(params.blurQuality, 0, 1, 1, 32)),
							isIos: isIos ? 1.0 : 0.0,
						});
						wgpu.device.queue.writeBuffer(blurVerticalUniformBuffer, 0, blurVerticalUniformValues.arrayBuffer);

						const passEncoder = ctx.commandEncoder.beginRenderPass({
							colorAttachments: [{
								view: wgpu.context.getCurrentTexture().createView(),
								clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
								loadOp: 'clear',
								storeOp: 'store',
							}],
						});
						passEncoder.setPipeline(blurLqPipeline);
						passEncoder.setBindGroup(1, wgpu.device.createBindGroup({
							layout: blurLqPipeline.getBindGroupLayout(1),
							entries: [
								{ binding: 1, resource: { buffer: uniformBuffer }},
								{ binding: 2, resource: { buffer: blurVerticalUniformBuffer }},
								{ binding: 3, resource: wgpu.sampler },
								{ binding: 4, resource: buffer2.createView() },
								{ binding: 5, resource: pointerTrailBufferAfter.createView() },
							],
						}));
						passEncoder.draw(6);
						passEncoder.end();
					}
				} else {
					{ // blur pass
						blurUniformValues.set({
							turbulenceEnabled: params.blurTurbulenceEnabled ? 1.0 : 0.0,
							turbulenceScale: params.turbulenceScale,
							strength: params.blurStrength,
							extend: params.blurExtend,
							quality: Math.round(remap(params.blurQuality, 0, 1, 1, 512)),
							isIos: isIos ? 1.0 : 0.0,
							monteCarlo: params.blurMethod === 'monteCarlo' ? 1.0 : 0.0,
						});
						wgpu.device.queue.writeBuffer(blurUniformBuffer, 0, blurUniformValues.arrayBuffer);

						const passEncoder = ctx.commandEncoder.beginRenderPass({
							colorAttachments: [{
								view: wgpu.context.getCurrentTexture().createView(),
								clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
								loadOp: 'clear',
								storeOp: 'store',
							}],
						});
						passEncoder.setPipeline(blurPipeline);
						passEncoder.setBindGroup(1, wgpu.device.createBindGroup({
							layout: blurPipeline.getBindGroupLayout(1),
							entries: [
								{ binding: 1, resource: { buffer: uniformBuffer }},
								{ binding: 2, resource: { buffer: blurUniformBuffer }},
								{ binding: 3, resource: wgpu.sampler },
								{ binding: 4, resource: buffer.createView() },
								{ binding: 5, resource: pointerTrailBufferAfter.createView() },
							],
						}));
						passEncoder.draw(6);
						passEncoder.end();
					}
				}
			},
			dispose() {
				window.removeEventListener('pointermove', onPointerMove);
			},
		}
	},
});
