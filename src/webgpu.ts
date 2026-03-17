export async function initWebGPU(canvas: HTMLCanvasElement, opts: {
	fps?: number | null;
	pixelRatio?: number | null;
} = {}) {
	const pixelRatio = opts.pixelRatio ?? window.devicePixelRatio;

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

	canvas.width = Math.max(1, Math.min(canvas.offsetWidth * pixelRatio, device.limits.maxTextureDimension2D));
	canvas.height = Math.max(1, Math.min(canvas.offsetHeight * pixelRatio, device.limits.maxTextureDimension2D));

	context.configure({
		device,
		format: navigator.gpu.getPreferredCanvasFormat(),
		alphaMode: 'premultiplied',
		colorSpace: 'display-p3',
	});

	const sampler = device.createSampler({
		magFilter: 'linear',
		minFilter: 'linear',
		mipmapFilter: 'linear',
		addressModeU: 'mirror-repeat',
		addressModeV: 'mirror-repeat',
		addressModeW: 'mirror-repeat',
	});

	let disposed = false;

	function start(renderCb) {
		// 誰が見ても同じレンダリング結果になるように、開いた時間を基準にする
		// ただそのままUNIX時間を入れると、秒数が大きすぎて浮動小数点数の関係で精度が落ちるため、1日間隔でループ
		const initialTime = Date.now() % (1000 * 60 * 60 * 24);

		function render(timeStamp: number) {
			if (disposed) return;

			const time = initialTime + Math.floor(timeStamp);

			const commandEncoder = device.createCommandEncoder();

			renderCb({ context, device, commandEncoder, time, width: canvas.width, height: canvas.height });

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
	}

	function dispose() {
		disposed = true;
		device.destroy();
		context.unconfigure();
	}

	return { start, device, sampler, dispose };
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
