import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { getUrlParam } from './utils.ts';

export async function initWebGPU(canvas: HTMLCanvasElement, code: string, opts = {}) {
	const pixelRatio = getUrlParam('pixelRatio', 'number') ?? window.devicePixelRatio;

	const adapter = await navigator.gpu?.requestAdapter({
		powerPreference: 'low-power',
	});
	const _device = await adapter?.requestDevice();
	if (!_device) {
		window.alert('need a browser that supports WebGPU');
		throw new Error('need a browser that supports WebGPU');
	}
	const device = _device as GPUDevice;

	const _context = canvas.getContext('webgpu');
	if (!_context) {
		window.alert('cannot get webgpu context');
		throw new Error('cannot get webgpu context');
	}
	const context = _context as GPUCanvasContext;

	let aspectRatioMin = [1.0, 1.0];
	let aspectRatioMax = [1.0, 1.0];

	function setCanvasSize(width: number, height: number) {
		canvas.width = Math.max(1, Math.min(width, device.limits.maxTextureDimension2D));
		canvas.height = Math.max(1, Math.min(height, device.limits.maxTextureDimension2D));
		aspectRatioMin = [Math.min(width / height, 1.0), Math.min(height / width, 1.0)];
		aspectRatioMax = [Math.max(width / height, 1.0), Math.max(height / width, 1.0)];
	}

	setCanvasSize(canvas.offsetWidth * pixelRatio, canvas.offsetHeight * pixelRatio);

	const shaderModule = device.createShaderModule({
		code: code,
	});

	context.configure({
		device,
		format: navigator.gpu.getPreferredCanvasFormat(),
		alphaMode: 'premultiplied',
		colorSpace: 'display-p3',
	});

	const vertices = new Float32Array([-1, -1, -1, 1, 1, 1, -1, -1, 1, 1, 1, -1]);

	const vertexBuffer = device.createBuffer({
		size: vertices.byteLength, // make it big enough to store vertices in
		usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
	});

	device.queue.writeBuffer(vertexBuffer, 0, vertices, 0, vertices.length);

	const vertexBuffers = [{
		arrayStride: 2 * 4, // 2 floats per vertex, 4 bytes per float
		attributes: [{
			shaderLocation: 0,
			offset: 0,
			format: 'float32x2',
		}],
	}];

	const pipeline = device.createRenderPipeline({
		vertex: {
			module: shaderModule,
			entryPoint: 'vs',
			buffers: vertexBuffers,
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

	function start(renderCb) {
		// 誰が見ても同じレンダリング結果になるように、開いた時間を基準にする
		// ただそのままUNIX時間を入れると、秒数が大きすぎて浮動小数点数の関係で精度が落ちるため、1日間隔でループ
		const initialTime = Date.now() % (1000 * 60 * 60 * 24);

		const renderPassDescriptor: GPURenderPassDescriptor = {
			colorAttachments: [{
				view: context.getCurrentTexture().createView(),
				clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
				loadOp: 'clear',
				storeOp: 'store',
			}],
		};

		function render(timeStamp: number) {
			const time = initialTime + Math.floor(timeStamp);

			renderPassDescriptor.colorAttachments[0].view = context.getCurrentTexture().createView();

			const commandEncoder = device.createCommandEncoder();
			const passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor);
			passEncoder.setPipeline(pipeline);
			passEncoder.setVertexBuffer(0, vertexBuffer);

			renderCb({ device, passEncoder, time, aspectRatioMin, aspectRatioMax });

			passEncoder.draw(6);
			passEncoder.end();
			device.queue.submit([commandEncoder.finish()]);

			if (opts.fps == null) {
				window.requestAnimationFrame(render);
			}
		}

		if (opts.fps) {
			window.setInterval(() => {
				render(performance.now());
			}, 1000 / opts.fps);
		} else {
			window.requestAnimationFrame(render);
		}

		const observer = new ResizeObserver(entries => {
			for (const entry of entries) {
				const canvas = entry.target;
				const width = entry.contentBoxSize[0].inlineSize * pixelRatio;
				const height = entry.contentBoxSize[0].blockSize * pixelRatio;
				setCanvasSize(width, height);
				render(performance.now());
			}
		});
		observer.observe(canvas);
	}

	return { start, device, pipeline };
}
