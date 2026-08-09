import code from './shader.wgsl?raw';
import { metadata } from './meta.ts';
import { createTextureFromImages, createTextureFromSource, makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground } from '@/utils.ts';
import { isVideoFrameAvailable } from '@/video.ts';

export const playground = definePlayground({
	...metadata,
	params: {
		source: { type: 'media', needReinit: true, label: 'Source' },
		coverSource: { type: 'boolean', label: 'Cover Source' },
		sourceContrast: { type: 'range', min: 0, max: 2, step: 0.01, label: 'Source Contrast' },
		highlightClipThreshold: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Highlight Clip Threshold' },
		shadowClipThreshold: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Shadow Clip Threshold' },
		divisions: { type: 'range', min: 8, max: 512, step: 1, label: 'Cell Divisions' },
		margin: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Cell Margin' },
		withNumbers: { type: 'boolean', needReinit: true, label: 'With Numbers' },
		symbolTexturesRangeMin: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Symbol Textures Range Min' },
		symbolTexturesRangeMax: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Symbol Textures Range Max' },
		bgColor: { type: 'color', label: 'Background Color' },
		colorA: { type: 'color', label: 'Color A' },
		colorB: { type: 'color', label: 'Color B' },
		colorC: { type: 'color', label: 'Color C' },
		similarityThresholdFactor: { type: 'range', min: 0, max: 32, step: 0.1, label: 'Similarity Threshold Factor' },
		pointerTrailShift: { type: 'boolean', label: 'Pointer Trail Shift' },
		pointerTrailWarp: { type: 'boolean', label: 'Pointer Trail Warp' },
		test: { type: 'boolean', label: 'Test' },
	},
	getDefaultParams: () => ({
		source: null,
		coverSource: true,
		sourceContrast: 1.0,
		highlightClipThreshold: 0.8,
		shadowClipThreshold: 0.2,
		divisions: 64,
		margin: 0.25,
		withNumbers: false,
		symbolTexturesRangeMin: 0.0,
		symbolTexturesRangeMax: 1.0,
		bgColor: [0, 0, 0],
		colorA: [1, 1, 1],
		colorB: [0.8, 1, 0],
		colorC: [1, 0.3, 0],
		similarityThresholdFactor: 2.0,
		pointerTrailShift: true,
		pointerTrailWarp: true,
		test: false,
	}),
	init: async ({ width, height, wgpu, params, canvas }) => {
		const shaderModule = wgpu.device.createShaderModule({
			code: code,
		});

		const shaderDataDefinitions = makeShaderDataDefinitions(code);
		const pointerTrailTextureFormat: GPUTextureFormat = 'rg16float';

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
			layout: pointerTrailPipeline.getBindGroupLayout(1),
			entries: [
				{ binding: 1, resource: { buffer: pointerTrailUniformBuffer }},
				{ binding: 2, resource: wgpu.sampler },
				{ binding: 3, resource: pointerTrailBuffer.createView() }
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
			if (ev.deltaY > 0) {
				params.divisions = Math.floor(params.divisions * 1.2);
			} else if (ev.deltaY < 0) {
				params.divisions = Math.floor(params.divisions / 1.2);
			}
			params.divisions = Math.min(512, Math.max(8, params.divisions));
		};

		canvas.addEventListener('wheel', onWheel);

		const pipeline = wgpu.device.createRenderPipeline({
			vertex: {
				module: wgpu.defaultVertexShaderModule,
			},
			fragment: {
				module: shaderModule,
				entryPoint: params.source != null ? 'fsWithSource' : 'fsWithoutSource',
				targets: [{
					format: navigator.gpu.getPreferredCanvasFormat(),
				}],
			},
			primitive: {
				topology: 'triangle-list',
			},
			layout: 'auto',
		});

		const symbolTextureUrls = [
			'./assets/symbols/dot.png',
			'./assets/symbols/dot.png',
			'./assets/symbols/dot.png',
			'./assets/symbols/dots.png',
			'./assets/symbols/dots3.png',

			'./assets/symbols/o1.png',
			'./assets/symbols/o2.png',
			'./assets/symbols/o3.png',
			'./assets/symbols/o4.png',
			'./assets/symbols/x1.png',
			'./assets/symbols/x2.png',
			'./assets/symbols/cross1.png',
			'./assets/symbols/cross2.png',
			'./assets/symbols/slash1.png',
			'./assets/symbols/slash2.png',
			'./assets/symbols/corner.png',
			'./assets/symbols/circle-slash.png',
			'./assets/symbols/square-slash.png',

			...(params.withNumbers ? [
				'./assets/chars/0.png',
				'./assets/chars/1.png',
				'./assets/chars/2.png',
				'./assets/chars/3.png',
				'./assets/chars/4.png',
				'./assets/chars/5.png',
				'./assets/chars/6.png',
				'./assets/chars/7.png',
				'./assets/chars/8.png',
				'./assets/chars/9.png',
			] : []),

			'./assets/symbols/block.png',

			//'./assets/symbols/square-slash.png',
			//'./assets/symbols/stripe.png',
			//'./assets/symbols/fill.png',
		];

		const symbolTextures = await createTextureFromImages(wgpu.device, symbolTextureUrls, {
			mips: false, // 有効にすると綺麗になるしパフォーマンス上も益があるけど特定条件下(marginが0)で画像の端に線が入ってしまう
		});

		const sourceTexture = createTextureFromSource(wgpu.device, params.source?.element ?? [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], {
			mips: params.source != null && params.source.type === 'video' ? false : true,
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
				{ binding: 3, resource: symbolTextures.createView({ dimension: '2d-array' }) },
				{ binding: 4, resource: sourceTexture.createView() },
				{ binding: 5, resource: pointerTrailBuffer.createView() },
			],
		}));

		/*

		window.addEventListener('keydown', (ev: KeyboardEvent) => {
			if (ev.key === 'Escape') {
				showMenu.value = false;
				ev.preventDefault();
			} else if (ev.key === ' ') {
				videoElement.paused ? videoElement.play() : videoElement.pause();
				ev.preventDefault();
			} else if (ev.key === 'ArrowLeft') {
				videoElement.currentTime = Math.max(0, videoElement.currentTime - 0.01);
				ev.preventDefault();
			} else if (ev.key === 'ArrowRight') {
				videoElement.currentTime = Math.min(videoElement.duration, videoElement.currentTime + 0.01);
				ev.preventDefault();
			}
		});
	*/

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
						//scale: params.scale,
						aspectRatio: width / height,
						timeDelta: ctx.timeDelta,
						pointerPosition: [pointerX, -pointerY],
						pointerVector: [pointerVectorX, -pointerVectorY],
					});
					wgpu.device.queue.writeBuffer(pointerTrailUniformBuffer, 0, pointerTrailUniformValues.arrayBuffer);

					const passEncoder = ctx.commandEncoder.beginRenderPass({
						colorAttachments: [{
							view: pointerTrailWriteBuffer.createView(),
							clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
							loadOp: 'clear',
							storeOp: 'store',
						}],
					});
					passEncoder.setPipeline(pointerTrailPipeline);
					passEncoder.setBindGroup(1, pointerTrailBindGroups[pointerTrailReadBufferIndex]);
					passEncoder.draw(6);
					passEncoder.end();
				}
				currentPointerTrailBufferIndex = pointerTrailWriteBufferIndex;

				uniformValues.set({
					aspectRatio: width / height,
					time: ctx.time,
					sourceAspectRatio: sourceTexture.width / sourceTexture.height,
					coverSource: params.coverSource ? 1 : 0,
					sourceContrast: params.sourceContrast,
					highlightClipThreshold: params.highlightClipThreshold,
					shadowClipThreshold: params.shadowClipThreshold,
					divisions: params.divisions,
					margin: params.margin,
					symbolTexturesCount: symbolTextureUrls.length,
					symbolTexturesRangeMin: params.symbolTexturesRangeMin,
					symbolTexturesRangeMax: params.symbolTexturesRangeMax,
					bgColor: params.bgColor,
					colorA: params.colorA,
					colorB: params.colorB,
					colorC: params.colorC,
					similarityThresholdFactor: params.similarityThresholdFactor,
					pointerTrailShift: params.pointerTrailShift ? 1 : 0,
					pointerTrailWarp: params.pointerTrailWarp ? 1 : 0,
					pointerPosition: [pointerX, -pointerY],
					test: params.test ? 1 : 0,
				});
				wgpu.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

				const passEncoder = ctx.createPassEncoder(ctx.commandEncoder);
				passEncoder.setPipeline(pipeline);
				passEncoder.setBindGroup(0, bindGroups[currentPointerTrailBufferIndex]);
				passEncoder.draw(6);
				passEncoder.end();
			},
			dispose() {
				window.removeEventListener('pointermove', onPointerMove);
				canvas.removeEventListener('wheel', onWheel);
				for (const pointerTrailBuffer of pointerTrailBuffers) pointerTrailBuffer.destroy();
				uniformBuffer.destroy();
				sourceTexture.destroy();
				symbolTextures.destroy();
			},
		};
	},
});
