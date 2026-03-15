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

	function setCanvasSize(width: number, height: number) {
		canvas.width = Math.max(1, Math.min(width, device.limits.maxTextureDimension2D));
		canvas.height = Math.max(1, Math.min(height, device.limits.maxTextureDimension2D));
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

	const pipeline = device.createRenderPipeline({
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

	let disposed = false;

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
			if (disposed) return;

			const time = initialTime + Math.floor(timeStamp);

			renderPassDescriptor.colorAttachments[0].view = context.getCurrentTexture().createView();

			const commandEncoder = device.createCommandEncoder();
			const passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor);
			passEncoder.setPipeline(pipeline);

			renderCb({ device, passEncoder, time, width: canvas.width, height: canvas.height });

			passEncoder.draw(3);
			passEncoder.end();
			device.queue.submit([commandEncoder.finish()]);
		}

		let then = 0;
		const interval = 1000 / (opts.fps ?? 30);

		function renderLoop(timeStamp: number) {
			if (disposed) return;

			window.requestAnimationFrame(renderLoop);

			if (opts.fps != null) {
				const delta = timeStamp - then;
				if (delta <= interval) return;
				then = timeStamp - (delta % interval);
			}

			render(timeStamp);
		}

		window.requestAnimationFrame(renderLoop);

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

	function dispose() {
		disposed = true;
		device.destroy();
		context.unconfigure();
	}

	return { start, device, pipeline, dispose };
}

export function setupWebcam() {
	return new Promise((resolve, reject) => {
		navigator.mediaDevices.getUserMedia({
			video: true,
			audio: false
		}).then(localMediaStream => {
			resolve(localMediaStream);
		}).catch(err => {
			// 取得に失敗した原因を調査
			if(err.name === 'PermissionDeniedError'){
				// ユーザーによる利用の拒否
				alert('denied permission');
			}else{
				// デバイスが見つからない場合など
				alert('can not be used webcam');
			}

			reject(err);
		});
	});
}
