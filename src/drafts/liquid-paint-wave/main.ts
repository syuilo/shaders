import code from './shader.wgsl?raw';
import { metadata } from './meta.ts';
import { createTextureFromSource, makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground, isIos, remap } from '@/utils.ts';
import { isVideoFrameAvailable } from '@/video.ts';

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
		blurMethod: isIos ? 'twoPass' : 'standard',
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

		const pointerTrailUniformValues = makeStructuredView(shaderDataDefinitions.uniforms.pointerTrailUniforms);
		const pointerTrailUniformBuffer = wgpu.device.createBuffer({
			size: pointerTrailUniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const pointerTrailBindGroups = pointerTrailBuffers.map(pointerTrailBuffer => wgpu.device.createBindGroup({
			layout: pointerTrailPipeline.getBindGroupLayout(2),
			entries: [
				{ binding: 1, resource: { buffer: pointerTrailUniformBuffer }},
				{ binding: 2, resource: wgpu.sampler },
				{ binding: 3, resource: pointerTrailBuffer.createView() }
			],
		}));
		let currentPointerTrailBufferIndex = 0;

		const waveSimulationScale = Math.min(1, 256 / Math.max(width, height));
		const waveWidth = Math.max(1, Math.round(width * waveSimulationScale));
		const waveHeight = Math.max(1, Math.round(height * waveSimulationScale));

		const waveStatePipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fsWaveState',
				targets: [{
					format: pointerTrailTextureFormat,
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const waveVectorPipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
			},
			fragment: {
				module: shaderModule,
				entryPoint: 'fsWaveVector',
				targets: [{
					format: pointerTrailTextureFormat,
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const waveStateBuffers = [0, 1].map(() => wgpu.device.createTexture({
			size: { width: waveWidth, height: waveHeight },
			format: pointerTrailTextureFormat,
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
		}));

		const waveVectorTexture = wgpu.device.createTexture({
			size: { width: waveWidth, height: waveHeight },
			format: pointerTrailTextureFormat,
			usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
		});

		const waveUniformValues = makeStructuredView(shaderDataDefinitions.uniforms.waveUniforms);
		const waveUniformBuffer = wgpu.device.createBuffer({
			size: waveUniformValues.arrayBuffer.byteLength,
			usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
		});

		const waveStateBindGroups = waveStateBuffers.map(waveStateBuffer => wgpu.device.createBindGroup({
			layout: waveStatePipeline.getBindGroupLayout(3),
			entries: [
				{ binding: 1, resource: { buffer: waveUniformBuffer }},
				{ binding: 2, resource: waveStateBuffer.createView() },
			],
		}));

		const waveVectorBindGroups = waveStateBuffers.map(waveStateBuffer => wgpu.device.createBindGroup({
			layout: waveVectorPipeline.getBindGroupLayout(3),
			entries: [
				{ binding: 2, resource: waveStateBuffer.createView() },
			],
		}));
		let currentWaveStateBufferIndex = 0;

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

		const bindGroups = pointerTrailBuffers.map(pointerTrailBuffer => wgpu.device.createBindGroup({
			layout: pipeline.getBindGroupLayout(0),
			entries: [
				{ binding: 1, resource: { buffer: uniformBuffer }},
				{ binding: 2, resource: wgpu.sampler },
				{ binding: 3, resource: sourceTexture.createView() },
				{ binding: 4, resource: pointerTrailBuffer.createView() },
				{ binding: 5, resource: waveVectorTexture.createView() },
			],
		}));

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
				const pointerTrailWriteBuffer = pointerTrailBuffers[pointerTrailWriteBufferIndex];

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
							view: pointerTrailWriteBuffer.createView(),
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

				const waveStateReadBufferIndex = currentWaveStateBufferIndex;
				const waveStateWriteBufferIndex = 1 - waveStateReadBufferIndex;
				const waveStateWriteBuffer = waveStateBuffers[waveStateWriteBufferIndex];

				waveUniformValues.set({
					timeDelta: ctx.timeDelta,
					aspectRatio: width / height,
					pointerPosition: [pointerX, -pointerY],
					pointerVector: [pointerVectorX, -pointerVectorY],
				});
				wgpu.device.queue.writeBuffer(waveUniformBuffer, 0, waveUniformValues.arrayBuffer);

				{ // wave state pass
					const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
						colorAttachments: [{
							view: waveStateWriteBuffer.createView(),
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}],
					});
					passEncoder.setPipeline(waveStatePipeline);
					passEncoder.setBindGroup(3, waveStateBindGroups[waveStateReadBufferIndex]);
					passEncoder.draw(6);
					passEncoder.end();
				}
				currentWaveStateBufferIndex = waveStateWriteBufferIndex;

				{ // wave vector pass
					const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
						colorAttachments: [{
							view: waveVectorTexture.createView(),
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}],
					});
					passEncoder.setPipeline(waveVectorPipeline);
					passEncoder.setBindGroup(3, waveVectorBindGroups[currentWaveStateBufferIndex]);
					passEncoder.draw(6);
					passEncoder.end();
				}

				{ // main pass
					uniformValues.set({
						scale: params.scale,
						aspectRatio: width / height,
						time: ctx.time,
						scrollFactor: params.scrollFactor,
						turbulenceScale: params.turbulenceScale,
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
						pointerTrailWeight: 0.7,
						test: params.test ? 1.0 : 0.0,
					});
					wgpu.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

					const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
						colorAttachments: [{
							view: buffer.createView(),
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}],
					});
					passEncoder.setPipeline(pipeline);
					passEncoder.setBindGroup(0, bindGroups[currentPointerTrailBufferIndex]);
					passEncoder.draw(6);
					passEncoder.end();
				}

				if (params.blurMethod === 'twoPass') {
					{ // two-pass blur pass - horizontal
						blurHorizontalUniformValues.set({
							isHorizontal: 1.0,
							turbulenceScale: params.turbulenceScale,
							strength: params.blurStrength,
							extend: params.blurExtend,
							quality: Math.round(remap(params.blurQuality, 0, 1, 1, 32)),
							isIos: isIos ? 1.0 : 0.0,
						});
						wgpu.device.queue.writeBuffer(blurHorizontalUniformBuffer, 0, blurHorizontalUniformValues.arrayBuffer);

						const passEncoder = ctx.createPassEncoder(ctx.commandEncoder, {
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
								{ binding: 5, resource: pointerTrailWriteBuffer.createView() },
								{ binding: 6, resource: waveVectorTexture.createView() },
							],
						}));
						passEncoder.draw(6);
						passEncoder.end();
					}

					{ // two-pass blur pass - vertical
						blurVerticalUniformValues.set({
							isHorizontal: 0.0,
							turbulenceScale: params.turbulenceScale,
							strength: params.blurStrength,
							extend: params.blurExtend,
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
						passEncoder.setBindGroup(1, wgpu.device.createBindGroup({
							layout: blurLqPipeline.getBindGroupLayout(1),
							entries: [
								{ binding: 1, resource: { buffer: uniformBuffer }},
								{ binding: 2, resource: { buffer: blurVerticalUniformBuffer }},
								{ binding: 3, resource: wgpu.sampler },
								{ binding: 4, resource: buffer2.createView() },
								{ binding: 5, resource: pointerTrailWriteBuffer.createView() },
								{ binding: 6, resource: waveVectorTexture.createView() },
							],
						}));
						passEncoder.draw(6);
						passEncoder.end();
					}
				} else {
					{ // blur pass
						blurUniformValues.set({
							turbulenceScale: params.turbulenceScale,
							strength: params.blurStrength,
							extend: params.blurExtend,
							quality: Math.round(remap(params.blurQuality, 0, 1, 1, 512)),
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
						passEncoder.setBindGroup(1, wgpu.device.createBindGroup({
							layout: blurPipeline.getBindGroupLayout(1),
							entries: [
								{ binding: 1, resource: { buffer: uniformBuffer }},
								{ binding: 2, resource: { buffer: blurUniformBuffer }},
								{ binding: 3, resource: wgpu.sampler },
								{ binding: 4, resource: buffer.createView() },
								{ binding: 5, resource: pointerTrailWriteBuffer.createView() },
								{ binding: 6, resource: waveVectorTexture.createView() },
							],
						}));
						passEncoder.draw(6);
						passEncoder.end();
					}
				}
			},
			dispose() {
				window.removeEventListener('pointermove', onPointerMove);
				canvas.removeEventListener('wheel', onWheel);
				for (const pointerTrailBuffer of pointerTrailBuffers) pointerTrailBuffer.destroy();
				for (const waveStateBuffer of waveStateBuffers) waveStateBuffer.destroy();
				waveVectorTexture.destroy();
				pointerTrailUniformBuffer.destroy();
				waveUniformBuffer.destroy();
				uniformBuffer.destroy();
				sourceTexture.destroy();
				buffer.destroy();
				buffer2.destroy();
				blurUniformBuffer.destroy();
				blurHorizontalUniformBuffer.destroy();
				blurVerticalUniformBuffer.destroy();
			},
		}
	},
});
