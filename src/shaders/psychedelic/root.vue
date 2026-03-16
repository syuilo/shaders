<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
<button id="menuButton" :class="hideMenuButton ? 'hide' : null" @click="showMenu = !showMenu">MENU</button>
<div v-if="showMenu" id="menu">
	<h1>WebGPU - PSYCHEDELIC SHADER by syuilo</h1>
	<label>
		<b>scale:</b>
		<input type="range" min="0.125" max="8" step="0.1" v-model="scale" />
	</label>
	<label>
		<b>channelAFactor:</b>
		<input type="range" min="0" max="8" step="0.1" v-model="channelAFactor" />
	</label>
	<label>
		<b>channelBFactor:</b>
		<input type="range" min="0" max="8" step="0.1" v-model="channelBFactor" />
	</label>
	<label>
		<b>channelCFactor:</b>
		<input type="range" min="0" max="8" step="0.1" v-model="channelCFactor" />
	</label>
	<label>
		<b>turbulenceEnabled:</b>
		<input type="checkbox" v-model="turbulenceEnabled" />
	</label>
	<label>
		<b>turbulenceScale:</b>
		<input type="range" min="0" max="32" step="0.1" v-model="turbulenceScale" />
	</label>
	<label>
		<b>selfModulo:</b>
		<input type="checkbox" v-model="selfModulo" />
	</label>
	<label>
		<b>mirror:</b>
		<input type="checkbox" v-model="mirror" />
	</label>
	<label>
		<b>blurStrength:</b>
		<input type="range" min="0" max="1" step="0.01" v-model="blurStrength" />
	</label>
	<label>
		<b>test:</b>
		<input type="checkbox" v-model="test" />
	</label>
	<label>
		<b>Hide menu button:</b>
		<input type="checkbox" v-model="hideMenuButton" />
	</label>
</div>
</template>

<script lang="ts" setup>
import { onMounted, ref, useTemplateRef } from 'vue';
import code from './shader.wgsl?raw';
import blurShaderCode from './blur.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { debouncePromise, getUrlParam, isIos } from '@/utils.ts';

const showMenu = ref(false);

const canvas = useTemplateRef('canvas');
let _dispose: (() => void) | null = null;

const scale = ref(getUrlParam('scale', 'float') ?? 1.0);
const turbulenceEnabled = ref(getUrlParam('turbulenceEnabled', 'bool') ?? true);
const turbulenceScale = ref(getUrlParam('turbulenceScale', 'float') ?? 1.5);
const channelAFactor = ref(getUrlParam('channelAFactor', 'float') ?? 2.0);
const channelBFactor = ref(getUrlParam('channelBFactor', 'float') ?? 1.5);
const channelCFactor = ref(getUrlParam('channelCFactor', 'float') ?? 4.0);
const selfModulo = ref(getUrlParam('selfModulo', 'bool') ?? true);
const mirror = ref(getUrlParam('mirror', 'bool') ?? false);
const blurStrength = ref(getUrlParam('blurStrength', 'float') ?? 0.05);
const test = ref(getUrlParam('test', 'bool') ?? false);
const fps = ref(getUrlParam('fps', 'float') ?? null);

const hideMenuButton = ref(false);

async function init() {
	console.log('Initializing WebGPU...');

	if (_dispose) _dispose();

	const { start, device, sampler, dispose } = await initWebGPU(canvas.value!, { fps: fps.value });
	_dispose = dispose;

	const shaderModule = device.createShaderModule({
		code: code,
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

	const defs = makeShaderDataDefinitions(code);
	const uniformValues = makeStructuredView(defs.uniforms.uniforms);

	const uniformBuffer = device.createBuffer({
		size: uniformValues.arrayBuffer.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});

	const bindGroup = device.createBindGroup({
		layout: pipeline.getBindGroupLayout(0),
		entries: [
			{ binding: 1, resource: { buffer: uniformBuffer }},
		],
	});

	const buffer = device.createTexture({
		size: { width: canvas.value!.width, height: canvas.value!.height, depthOrArrayLayers: 1 },
		format: navigator.gpu.getPreferredCanvasFormat(),
		usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
	});

	const blurShaderModule = device.createShaderModule({
		code: blurShaderCode,
	});

	const blurPipeline = device.createRenderPipeline({
		vertex: {
			module: blurShaderModule,
			entryPoint: 'vs',
		},
		fragment: {
			module: blurShaderModule,
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

	const blurDefs = makeShaderDataDefinitions(blurShaderCode);
	const blurUniformValues = makeStructuredView(blurDefs.uniforms.uniforms);

	const blurUniformBuffer = device.createBuffer({
		size: blurUniformValues.arrayBuffer.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});

	const blurBindGroup = device.createBindGroup({
		layout: blurPipeline.getBindGroupLayout(0),
		entries: [
			{ binding: 1, resource: { buffer: blurUniformBuffer }},
			{ binding: 2, resource: sampler },
			{ binding: 3, resource: buffer.createView() }
		],
	});

	start(ctx => {
		{
			uniformValues.set({
				scale: parseFloat(scale.value),
				aspectRatio: ctx.width / ctx.height,
				time: ctx.time,
				turbulenceEnabled: turbulenceEnabled.value ? 1.0 : 0.0,
				turbulenceScale: parseFloat(turbulenceScale.value),
				channelAFactor: parseFloat(channelAFactor.value),
				channelBFactor: parseFloat(channelBFactor.value),
				channelCFactor: parseFloat(channelCFactor.value),
				selfModulo: selfModulo.value ? 1.0 : 0.0,
				mirror: mirror.value ? 1.0 : 0.0,
				test: test.value ? 1.0 : 0.0,
			});
			ctx.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

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

		{
			blurUniformValues.set({
				scale: parseFloat(scale.value),
				aspectRatio: ctx.width / ctx.height,
				time: ctx.time,
				turbulenceEnabled: turbulenceEnabled.value ? 1.0 : 0.0,
				turbulenceScale: parseFloat(turbulenceScale.value),
				strength: parseFloat(blurStrength.value),
				isIos: isIos ? 1.0 : 0.0,
				mirror: mirror.value ? 1.0 : 0.0,
				test: test.value ? 1.0 : 0.0,
			});
			ctx.device.queue.writeBuffer(blurUniformBuffer, 0, blurUniformValues.arrayBuffer);

			const passEncoder = ctx.commandEncoder.beginRenderPass({
				colorAttachments: [{
					view: ctx.renderTarget.createView(),
					clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
					loadOp: 'clear',
					storeOp: 'store',
				}],
			});
			passEncoder.setPipeline(blurPipeline);
			passEncoder.setBindGroup(0, blurBindGroup);
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
</script>

<style scoped>

</style>
