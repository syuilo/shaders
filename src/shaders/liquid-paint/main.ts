import code from './shader.wgsl?raw';
import { metadata } from './meta.ts';
import { createTextureFromSource, makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground, isIos, remap } from '@/utils.ts';
import { isVideoFrameAvailable } from '@/video.ts';
import { getBlurSampleCount, getMipLevelCount, shouldGenerateBlurMipmaps } from './blur-settings.ts';

export const playground = definePlayground({
	...metadata,
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
		}, {
			value: 'melon', label: 'Melon'
		}, {
			value: 'dawn', label: 'Dawn'
		}] },
		discardThreshold: { type: 'range', min: -1, max: 1, step: 0.1, label: 'Discard Threshold' },
		channelAFactor: { type: 'range', min: -4, max: 4, step: 0.1, label: 'Channel A Factor' },
		channelBFactor: { type: 'range', min: -4, max: 4, step: 0.1, label: 'Channel B Factor' },
		channelCFactor: { type: 'range', min: -4, max: 4, step: 0.1, label: 'Channel C Factor' },
		turbulenceScale: { type: 'range', min: 0, max: 32, step: 0.1, label: 'Turbulence Scale' },
		blurStrength: { type: 'range', min: 0, max: 3, step: 0.1, label: 'Blur Strength' },
		blurExtend: { type: 'range', min: -1, max: 1, step: 0.01, label: 'Blur Extend' },
		blurQuality: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Blur Quality' },
		blurMethod: { type: 'enum', label: 'Blur Method', enum: [{
			value: 'standardMip', label: 'Standard Mip'
		}, {
			value: 'standard', label: 'Standard'
		}, {
			value: 'monteCarlo', label: 'Monte Carlo'
		}, {
			value: 'twoPass', label: 'Two Pass'
		}]},
		scrollFactor: { type: 'range', min: -2, max: 2, step: 0.1, label: 'Scroll Factor' },
		test: { type: 'boolean', label: 'Test' },
	},
	getDefaultParams: () => ({
		source: null,
		scale: 1.0,
		turbulenceScale: 1.5,
		pallette: 'cider',
		discardThreshold: -0.2,
		channelAFactor: 1.0,
		channelBFactor: 1.0,
		channelCFactor: 1.0,
		blurStrength: 1.0,
		blurExtend: 0.0,
		blurQuality: 0.25,
		blurMethod: 'standardMip',
		scrollFactor: 0.0,
		test: false,
	}),
	init: async ({ width, height, wgpu, params, canvas }) => {
		const shaderModule = wgpu.device.createShaderModule({
			code: code,
		});

		const shaderDataDefinitions = makeShaderDataDefinitions(code);
		const pointerTrailTextureFormat: GPUTextureFormat = 'rg16float';

		const sourceTexture = createTextureFromSource(wgpu.device, params.source?.element ?? [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], {
			mips: params.source != null && params.source.type === 'video' ? false : true,
		});

		const pointerTrailPipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fsPointerTrail',
				targets: [{
					format: pointerTrailTextureFormat,
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const pointerTrailBuffers = [0, 1].map(() => wgpu.device.createTexture({
			size: { width, height },
			format: pointerTrailTextureFormat,
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
		}));
		const pointerTrailBufferViews = pointerTrailBuffers.map(pointerTrailBuffer => pointerTrailBuffer.createView());

		const pointerTrailUniformValues = makeStructuredView(shaderDataDefinitions.uniforms.pointerTrailUniforms);
		const pointerTrailUniformBuffer = wgpu.device.createBuffer({
			size: pointerTrailUniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const pointerTrailBindGroups = pointerTrailBufferViews.map(pointerTrailBufferView => wgpu.device.createBindGroup({
			layout: pointerTrailPipeline.getBindGroupLayout(2),
			entries: [
				{ binding: 1, resource: { buffer: pointerTrailUniformBuffer }},
				{ binding: 2, resource: wgpu.sampler },
				{ binding: 3, resource: pointerTrailBufferView }
			],
		}));
		let currentPointerTrailBufferIndex = 0;

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

		const onWheel = (ev: WheelEvent) => {
			if (ev.deltaY < 0) {
				params.scale = Math.max(0.1, params.scale - 0.1);
			} else if (ev.deltaY > 0) {
				params.scale = Math.min(2.0, params.scale + 0.1);
			}
		};

		canvas.addEventListener('wheel', onWheel);

		const pipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fs',
				targets: [{
					format: navigator.gpu.getPreferredCanvasFormat(),
				}, {
					format: 'r16float',
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
		const sourceTextureView = sourceTexture.createView();

		const bindGroups = pointerTrailBufferViews.map(pointerTrailBufferView => wgpu.device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [
				{ binding: 1, resource: { buffer: uniformBuffer }},
				{ binding: 2, resource: wgpu.sampler },
				{ binding: 3, resource: sourceTextureView },
				{ binding: 4, resource: pointerTrailBufferView },
			],
		}));

		const mipLevelCount = getMipLevelCount(width, height);
		const buffer = wgpu.device.createTexture({
			size: { width, height },
			mipLevelCount,
			format: navigator.gpu.getPreferredCanvasFormat(),
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
		});
		const bufferView = buffer.createView();
		const bufferMipViews = Array.from({ length: mipLevelCount }, (_, mipLevel) => buffer.createView({
			baseMipLevel: mipLevel,
			mipLevelCount: 1,
		}));

		const downsamplePipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fsDownsample',
				targets: [{
					format: navigator.gpu.getPreferredCanvasFormat(),
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const downsampleBindGroups = bufferMipViews.slice(0, -1).map(bufferMipView => wgpu.device.createBindGroup({
			layout: downsamplePipeline.getBindGroupLayout(3),
			entries: [
				{ binding: 1, resource: wgpu.sampler },
				{ binding: 2, resource: bufferMipView },
			],
		}));

		const blurRadiusTexture = wgpu.device.createTexture({
			size: { width, height },
			format: 'r16float',
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
		});
		const blurRadiusTextureView = blurRadiusTexture.createView();

		const buffer2 = wgpu.device.createTexture({
			size: { width, height },
			format: navigator.gpu.getPreferredCanvasFormat(),
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
		});
		const buffer2View = buffer2.createView();

		const blurPipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
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

		const blurMipPipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fsBlurMip',
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
				module: wgpu.defaultVertexShaderModule,
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

		const blurHorizontalBindGroup = wgpu.device.createBindGroup({
			layout: blurLqPipeline.getBindGroupLayout(1),
			entries: [
				{ binding: 2, resource: { buffer: blurHorizontalUniformBuffer }},
				{ binding: 3, resource: wgpu.sampler },
				{ binding: 4, resource: bufferView },
				{ binding: 5, resource: blurRadiusTextureView },
			],
		});

		const blurVerticalBindGroup = wgpu.device.createBindGroup({
			layout: blurLqPipeline.getBindGroupLayout(1),
			entries: [
				{ binding: 2, resource: { buffer: blurVerticalUniformBuffer }},
				{ binding: 3, resource: wgpu.sampler },
				{ binding: 4, resource: buffer2View },
				{ binding: 5, resource: blurRadiusTextureView },
			],
		});

		const blurBindGroup = wgpu.device.createBindGroup({
			layout: blurPipeline.getBindGroupLayout(1),
			entries: [
				{ binding: 1, resource: { buffer: uniformBuffer }},
				{ binding: 2, resource: { buffer: blurUniformBuffer }},
				{ binding: 3, resource: wgpu.sampler },
				{ binding: 4, resource: bufferView },
				{ binding: 5, resource: blurRadiusTextureView },
			],
		});

		const blurMipBindGroup = wgpu.device.createBindGroup({
			layout: blurMipPipeline.getBindGroupLayout(1),
			entries: [
				{ binding: 1, resource: { buffer: uniformBuffer }},
				{ binding: 2, resource: { buffer: blurUniformBuffer }},
				{ binding: 3, resource: wgpu.sampler },
				{ binding: 4, resource: bufferView },
				{ binding: 5, resource: blurRadiusTextureView },
			],
		});

		return {
			render: ctx => {
				if (params.source != null && params.source.type === 'video' && isVideoFrameAvailable(params.source.element)) {
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
				const pointerTrailReadBufferIndex = currentPointerTrailBufferIndex;
				const pointerTrailWriteBufferIndex = 1 - pointerTrailReadBufferIndex;

				{ // pointer trail pass
					pointerTrailUniformValues.set({
						scale: params.scale,
						aspectRatio: width / height,
						timeDelta: ctx.timeDelta,
						pointerPosition: [pointerX, -pointerY],
						pointerVector: [pointerVectorX, -pointerVectorY],
					});
					wgpu.device.queue.writeBuffer(pointerTrailUniformBuffer, 0, pointerTrailUniformValues.arrayBuffer);

					const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
						colorAttachments: [{
							view: pointerTrailBufferViews[pointerTrailWriteBufferIndex],
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}],
					});
					passEncoder.setPipeline(pointerTrailPipeline);
					passEncoder.setBindGroup(2, pointerTrailBindGroups[pointerTrailReadBufferIndex]);
					passEncoder.draw(6);
					passEncoder.end();
				}
				currentPointerTrailBufferIndex = pointerTrailWriteBufferIndex;

				{ // main pass
					uniformValues.set({
						scale: params.scale,
						aspectRatio: width / height,
						time: ctx.time,
						scrollFactor: params.scrollFactor,
						turbulenceScale: params.turbulenceScale,
						blurStrength: params.blurStrength,
						blurExtend: params.blurExtend,
						pallette:
							params.pallette === 'colorful' ? 0.0 :
							params.pallette === 'cider' ? 1.0 :
							params.pallette === 'psyche' ? 2.0 :
							params.pallette === 'pastel' ? 3.0 :
							params.pallette === 'iridescence' ? 4.0 :
							params.pallette === 'lava' ? 5.0 :
							params.pallette === 'melon' ? 6.0 :
							params.pallette === 'dawn' ? 7.0 :
							0.0,
						discardThreshold: params.discardThreshold,
						channelAFactor: params.channelAFactor,
						channelBFactor: params.channelBFactor,
						channelCFactor: params.channelCFactor,
						hasSource: params.source != null ? 1.0 : 0.0,
						coverSource: 1.0,
						sourceAspectRatio: sourceTexture.width / sourceTexture.height,
						test: params.test ? 1.0 : 0.0,
					});
					wgpu.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

					const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
						colorAttachments: [{
							view: bufferMipViews[0],
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}, {
							view: blurRadiusTextureView,
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 0.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}],
					});
					passEncoder.setPipeline(pipeline);
					passEncoder.setBindGroup(0, bindGroups[currentPointerTrailBufferIndex]);
					passEncoder.draw(6);
					passEncoder.end();
				}

				if (shouldGenerateBlurMipmaps(params.blurStrength, params.blurMethod)) {
					for (let mipLevel = 1; mipLevel < mipLevelCount; mipLevel++) {
						const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
							colorAttachments: [{
								view: bufferMipViews[mipLevel],
								clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
								loadOp: 'clear',
								storeOp: 'store',
							}],
						});
						passEncoder.setPipeline(downsamplePipeline);
						passEncoder.setBindGroup(3, downsampleBindGroups[mipLevel - 1]);
						passEncoder.draw(6);
						passEncoder.end();
					}
				}

				if (params.blurMethod === 'twoPass') {
					{ // two-pass blur pass - horizontal
						blurHorizontalUniformValues.set({
							isHorizontal: 1.0,
							quality: Math.round(remap(params.blurQuality, 0, 1, 1, 32)),
							isIos: isIos ? 1.0 : 0.0,
						});
						wgpu.device.queue.writeBuffer(blurHorizontalUniformBuffer, 0, blurHorizontalUniformValues.arrayBuffer);

						const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
							colorAttachments: [{
								view: buffer2View,
								clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
								loadOp: 'clear',
								storeOp: 'store',
							}],
						});
						passEncoder.setPipeline(blurLqPipeline);
						passEncoder.setBindGroup(1, blurHorizontalBindGroup);
						passEncoder.draw(6);
						passEncoder.end();
					}

					{ // two-pass blur pass - vertical
						blurVerticalUniformValues.set({
							isHorizontal: 0.0,
							quality: Math.round(remap(params.blurQuality, 0, 1, 1, 32)),
							isIos: isIos ? 1.0 : 0.0,
						});
						wgpu.device.queue.writeBuffer(blurVerticalUniformBuffer, 0, blurVerticalUniformValues.arrayBuffer);

						const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
							colorAttachments: [{
								view: wgpu.context.getCurrentTexture().createView(),
								clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
								loadOp: 'clear',
								storeOp: 'store',
							}],
						});
						passEncoder.setPipeline(blurLqPipeline);
						passEncoder.setBindGroup(1, blurVerticalBindGroup);
						passEncoder.draw(6);
						passEncoder.end();
					}
				} else if (params.blurMethod === 'standardMip') {
					{ // blur pass
						blurUniformValues.set({
							quality: getBlurSampleCount(params.blurQuality, params.blurMethod),
							isIos: isIos ? 1.0 : 0.0,
							monteCarlo: 0.0,
						});
						wgpu.device.queue.writeBuffer(blurUniformBuffer, 0, blurUniformValues.arrayBuffer);

						const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
							colorAttachments: [{
								view: wgpu.context.getCurrentTexture().createView(),
								clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
								loadOp: 'clear',
								storeOp: 'store',
							}],
						});
						passEncoder.setPipeline(blurMipPipeline);
						passEncoder.setBindGroup(1, blurMipBindGroup);
						passEncoder.draw(6);
						passEncoder.end();
					}
				} else {
					{ // blur pass
						blurUniformValues.set({
							quality: getBlurSampleCount(params.blurQuality, params.blurMethod),
							isIos: isIos ? 1.0 : 0.0,
							monteCarlo: params.blurMethod === 'monteCarlo' ? 1.0 : 0.0,
						});
						wgpu.device.queue.writeBuffer(blurUniformBuffer, 0, blurUniformValues.arrayBuffer);

						const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
							colorAttachments: [{
								view: wgpu.context.getCurrentTexture().createView(),
								clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
								loadOp: 'clear',
								storeOp: 'store',
							}],
						});
						passEncoder.setPipeline(blurPipeline);
						passEncoder.setBindGroup(1, blurBindGroup);
						passEncoder.draw(6);
						passEncoder.end();
					}
				}
			},
			dispose() {
				window.removeEventListener('pointermove', onPointerMove);
				canvas.removeEventListener('wheel', onWheel);
				for (const pointerTrailBuffer of pointerTrailBuffers) pointerTrailBuffer.destroy();
				uniformBuffer.destroy();
				sourceTexture.destroy();
				buffer.destroy();
				blurRadiusTexture.destroy();
				buffer2.destroy();
				blurUniformBuffer.destroy();
				blurHorizontalUniformBuffer.destroy();
				blurVerticalUniformBuffer.destroy();
			},
		}
	},
});
