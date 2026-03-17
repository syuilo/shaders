<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
<button id="menuButton" :class="hideMenuButton ? 'hide' : null" @click="showMenu = !showMenu">MENU</button>
<div v-if="showMenu" id="menu">
	<XMedia @updated="onMediaUpdated" />
	<label>
		<b>blurStrength:</b>
		<input type="range" min="0" max="5" step="0.1" v-model="blurStrength" /> {{ blurStrength }}
	</label>
</div>
</template>

<script lang="ts" setup>
import { onMounted, onUnmounted, ref, useTemplateRef } from 'vue';
import code from './shader.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';
import { makeShaderDataDefinitions, makeStructuredView, createTextureFromSource } from 'webgpu-utils';
import { debouncePromise, getUrlParam } from '@/utils.ts';
import XMedia from '@/media.vue';

const showMenu = ref(false);

const canvas = useTemplateRef('canvas');
let _dispose: (() => void) | null = null;

const scale = ref(getUrlParam('scale', 'float') ?? 1.0);
const timeFactor = ref(getUrlParam('timeFactor', 'float') ?? 1.0);
const turbulenceEnabled = ref(getUrlParam('turbulenceEnabled', 'bool') ?? true);
const turbulenceScale = ref(getUrlParam('turbulenceScale', 'float') ?? 1.5);
const discardThreshold = ref(getUrlParam('discardThreshold', 'float') ?? -0.2);
const blurStrength = ref(getUrlParam('blurStrength', 'float') ?? 1.0);
const blurTurbulenceEnabled = ref(getUrlParam('blurTurbulenceEnabled', 'bool') ?? true);
const blurQuality = ref(getUrlParam('blurQuality', 'int') ?? 64);
const fps = ref(getUrlParam('fps', 'float') ?? null);

const hideMenuButton = ref(false);

let media: HTMLImageElement | HTMLVideoElement | null = null;

async function init() {
	console.log('Initializing WebGPU...');

	if (_dispose) _dispose();

	const { start, device, sampler, dispose } = await initWebGPU(canvas.value!, { fps: fps.value });
	_dispose = dispose;

	const shaderModule = device.createShaderModule({
		code: code,
	});

	const sourceTexture = createTextureFromSource(device, media ?? [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], {
		mips: media != null && media.tagName === 'VIDEO' ? false : true,
	});

	const defs = makeShaderDataDefinitions(code);

	const buffer = device.createTexture({
		size: { width: canvas.value!.width, height: canvas.value!.height, depthOrArrayLayers: 1 },
		format: navigator.gpu.getPreferredCanvasFormat(),
		usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
	});

	const blurLqPipeline = device.createRenderPipeline({
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

	const blurHorizontalUniformValues = makeStructuredView(defs.uniforms.uniforms);
	const blurHorizontalUniformBuffer = device.createBuffer({
		size: blurHorizontalUniformValues.arrayBuffer.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});

	const blurVerticalUniformValues = makeStructuredView(defs.uniforms.uniforms);
	const blurVerticalUniformBuffer = device.createBuffer({
		size: blurVerticalUniformValues.arrayBuffer.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});

	start(ctx => {
		if (media != null && media.tagName === 'video' && media.readyState >= 4) {
			ctx.device.queue.copyExternalImageToTexture(
				{ source: media, flipY: true, },
				{ texture: sourceTexture },
				{ width: sourceTexture.width, height: sourceTexture.height },
			);
		}

		{
			blurHorizontalUniformValues.set({
				time: ctx.time * timeFactor.value,
				aspectRatio: canvas.value!.width / canvas.value!.height,
				scale: scale.value,
				isHorizontal: 1.0,
				turbulenceEnabled: blurTurbulenceEnabled.value ? 1.0 : 0.0,
				turbulenceScale: parseFloat(turbulenceScale.value),
				strength: parseFloat(blurStrength.value),
				quality: parseInt(blurQuality.value),
			});
			ctx.device.queue.writeBuffer(blurHorizontalUniformBuffer, 0, blurHorizontalUniformValues.arrayBuffer);

			const passEncoder = ctx.commandEncoder.beginRenderPass({
				colorAttachments: [{
					view: buffer.createView(),
					clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
					loadOp: 'clear',
					storeOp: 'store',
				}],
			});
			passEncoder.setPipeline(blurLqPipeline);
			passEncoder.setBindGroup(0, device.createBindGroup({
				layout: blurLqPipeline.getBindGroupLayout(0),
				entries: [
					{ binding: 1, resource: { buffer: blurHorizontalUniformBuffer }},
					{ binding: 2, resource: sampler },
					{ binding: 3, resource: sourceTexture.createView() }
				],
			}));
			passEncoder.draw(6);
			passEncoder.end();
		}

		{
			blurVerticalUniformValues.set({
				time: ctx.time * timeFactor.value,
				aspectRatio: canvas.value!.width / canvas.value!.height,
				scale: scale.value,
				isHorizontal: 0.0,
				turbulenceEnabled: blurTurbulenceEnabled.value ? 1.0 : 0.0,
				turbulenceScale: parseFloat(turbulenceScale.value),
				strength: parseFloat(blurStrength.value),
				quality: parseInt(blurQuality.value),
			});
			ctx.device.queue.writeBuffer(blurVerticalUniformBuffer, 0, blurVerticalUniformValues.arrayBuffer);

			const passEncoder = ctx.commandEncoder.beginRenderPass({
				colorAttachments: [{
					view: ctx.context.getCurrentTexture().createView(),
					clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
					loadOp: 'clear',
					storeOp: 'store',
				}],
			});
			passEncoder.setPipeline(blurLqPipeline);
			passEncoder.setBindGroup(0, device.createBindGroup({
				layout: blurLqPipeline.getBindGroupLayout(0),
				entries: [
					{ binding: 1, resource: { buffer: blurVerticalUniformBuffer }},
					{ binding: 2, resource: sampler },
					{ binding: 3, resource: buffer.createView() }
				],
			}));
			passEncoder.draw(6);
			passEncoder.end();
		}
	});
}

const debouncedInit = debouncePromise(init, 500);

onMounted(async () => {
	debouncedInit();

	const observer = new ResizeObserver(entries => {
		for (const entry of entries) {
			if (entry.target === canvas.value) {
				debouncedInit();
			}
		}
	});
	observer.observe(canvas.value!);
});

function onMediaUpdated(x: HTMLImageElement | HTMLVideoElement) {
	media = x;
	debouncedInit();
}

onUnmounted(() => {
	if (_dispose) _dispose();
});
</script>

<style scoped>

</style>
