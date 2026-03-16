import { getUrlParam } from './utils.ts';
import copyShaderCode from './copy.wgsl?raw';

export async function initWebGPU(canvas: HTMLCanvasElement, opts = {}) {
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

	canvas.width = Math.max(1, Math.min(canvas.offsetWidth * pixelRatio, device.limits.maxTextureDimension2D));
	canvas.height = Math.max(1, Math.min(canvas.offsetHeight * pixelRatio, device.limits.maxTextureDimension2D));

	context.configure({
		device,
		format: navigator.gpu.getPreferredCanvasFormat(),
		alphaMode: 'premultiplied',
		colorSpace: 'display-p3',
	});

	const copyShaderModule = device.createShaderModule({
		code: copyShaderCode,
	});

	const copyPipeline = device.createRenderPipeline({
		vertex: {
			module: copyShaderModule,
		},
		fragment: {
			module: copyShaderModule,
			targets: [{
				format: navigator.gpu.getPreferredCanvasFormat(),
			}],
		},
		primitive: {
			topology: 'triangle-list',
		},
		layout: 'auto',
	});

	const sampler = device.createSampler({
		magFilter: 'linear',
		minFilter: 'linear',
		mipmapFilter: 'linear',
		addressModeU: 'mirror-repeat',
		addressModeV: 'mirror-repeat',
		addressModeW: 'mirror-repeat',
	});

	const renderTarget = device.createTexture({
		size: { width: canvas.width, height: canvas.height, depthOrArrayLayers: 1 },
		format: navigator.gpu.getPreferredCanvasFormat(),
		usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
	});

	const copyBindGroup = device.createBindGroup({
		layout: copyPipeline.getBindGroupLayout(0),
		entries: [
			{ binding: 1, resource: sampler },
			{ binding: 2, resource: renderTarget.createView() }
		],
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

			renderCb({ device, renderTarget, commandEncoder, time, width: canvas.width, height: canvas.height });

			{
				const passEncoder = commandEncoder.beginRenderPass({
					colorAttachments: [{
						view: context.getCurrentTexture().createView(),
						clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
						loadOp: 'clear',
						storeOp: 'store',
					}],
				});
				passEncoder.setPipeline(copyPipeline);
				passEncoder.setBindGroup(0, copyBindGroup);
				passEncoder.draw(6);
				passEncoder.end();
			}

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
