import code from './shader.wgsl?raw';
import { createTextureFromImages, createTextureFromSource, makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { definePlayground } from '@/utils.ts';

export const playground = definePlayground({
	title: 'Cyber',
	params: {
		source: { type: 'media', needReinit: true, label: 'Source' },
		coverSource: { type: 'boolean', label: 'Cover Source' },
		discardBrightPixels: { type: 'boolean', label: 'Discard Bright Pixels' },
		enableSampledCellJoining: { type: 'boolean', label: 'Enable Sampled Cell Joining' },
		divisions: { type: 'range', min: 8, max: 512, step: 1, label: 'Cell Divisions' },
		margin: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Cell Margin' },
		withNumbers: { type: 'boolean', needReinit: true, label: 'With Numbers' },
		symbolTexturesRangeMin: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Symbol Textures Range Min' },
		symbolTexturesRangeMax: { type: 'range', min: 0, max: 1, step: 0.01, label: 'Symbol Textures Range Max' },
		bgColor: { type: 'color', label: 'Background Color' },
		colorA: { type: 'color', label: 'Color A' },
		colorB: { type: 'color', label: 'Color B' },
		colorC: { type: 'color', label: 'Color C' },
		test: { type: 'boolean', label: 'Test' },
	},
	getDefaultParams: () => ({
		source: null,
		coverSource: true,
		discardBrightPixels: true,
		enableSampledCellJoining: true,
		divisions: 64,
		margin: 0.25,
		withNumbers: false,
		symbolTexturesRangeMin: 0.0,
		symbolTexturesRangeMax: 1.0,
		bgColor: [0, 0, 0],
		colorA: [1, 1, 1],
		colorB: [0.8, 1, 0],
		colorC: [1, 0.3, 0],
		test: false,
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
				{ binding: 2, resource: wgpu.sampler },
				{ binding: 3, resource: symbolTextures.createView({ dimension: '2d-array' }) },
				{ binding: 4, resource: sourceTexture.createView() },
			],
		});

		let pointerX = -1.0;
		let pointerY = -1.0;
		let lastPointerMovedAt = 0;

		/*
		window.addEventListener('pointermove', (ev: PointerEvent) => {
			if (!canvas.value) return;
			const rect = canvas.value.getBoundingClientRect();
			const w = rect.width;
			const h = rect.height;
			const x = (ev.clientX - rect.left) / w;
			const y = (ev.clientY - rect.top) / h;
			pointerX = x;
			pointerY = y;
			lastPointerMovedAt = performance.now();
		});

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

		function onWheel(ev: WheelEvent) {
			if (ev.deltaY > 0) {
				divisions.value = Math.floor(divisions.value * 1.2);
			} else if (ev.deltaY < 0) {
				divisions.value = Math.floor(divisions.value / 1.2);
			}
			divisions.value = Math.min(512, Math.max(8, divisions.value));
		}
			*/

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
					pointerX = -1.0;
					pointerY = -1.0;
				}

				uniformValues.set({
					aspectRatio: width / height,
					time: ctx.time,
					hasSource: params.source != null ? 1.0 : 0.0,
					sourceAspectRatio: sourceTexture.width / sourceTexture.height,
					coverSource: params.coverSource ? 1 : 0,
					discardBrightPixels: params.discardBrightPixels ? 1 : 0,
					enableSampledCellJoining: params.enableSampledCellJoining ? 1 : 0,
					divisions: params.divisions,
					margin: params.margin,
					symbolTexturesCount: symbolTextureUrls.length,
					symbolTexturesRangeMin: params.symbolTexturesRangeMin,
					symbolTexturesRangeMax: params.symbolTexturesRangeMax,
					bgColor: params.bgColor,
					colorA: params.colorA,
					colorB: params.colorB,
					colorC: params.colorC,
					pointerPosition: [pointerX, -pointerY],
					test: params.test ? 1 : 0,
				});
				wgpu.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

				const passEncoder = ctx.commandEncoder.beginRenderPass({
					colorAttachments: [{
						view: wgpu.context.getCurrentTexture().createView(),
						clearValue: { r: params.bgColor[0], g: params.bgColor[1], b: params.bgColor[2], a: 1.0 },
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
