<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
<button id="menuButton" :class="hideMenuButton ? 'hide' : null" @click="showMenu = !showMenu">MENU</button>
<div v-if="showMenu" id="menu">
	<h1>WebGPU - PSYCHEDELIC SHADER by syuilo</h1>
	<label>
		<b>scale:</b>
		<input type="range" min="0.1" max="2" step="0.1" v-model="scale" /> {{ scale }}
	</label>
	<label>
		<b>timeFactor:</b>
		<input type="range" min="0" max="4" step="0.1" v-model="timeFactor" /> {{ timeFactor }}
	</label>
	<label>
		<b>pallette:</b>
		<select v-model="pallette">
			<option value="colorful">colorful</option>
			<option value="cider">cider</option>
			<option value="psyche">psyche</option>
			<option value="pastel">pastel</option>
		</select>
	</label>
	<label>
		<b>discardThreshold:</b>
		<input type="range" min="-1" max="1" step="0.1" v-model="discardThreshold" /> {{ discardThreshold }}
	</label>
	<label>
		<b>channelAFactor:</b>
		<input type="range" min="-4" max="4" step="0.1" v-model="channelAFactor" /> {{ channelAFactor }}
	</label>
	<label>
		<b>channelBFactor:</b>
		<input type="range" min="-4" max="4" step="0.1" v-model="channelBFactor" /> {{ channelBFactor }}
	</label>
	<label>
		<b>channelCFactor:</b>
		<input type="range" min="-4" max="4" step="0.1" v-model="channelCFactor" /> {{ channelCFactor }}
	</label>
	<label>
		<b>turbulenceEnabled:</b>
		<input type="checkbox" v-model="turbulenceEnabled" />
	</label>
	<label>
		<b>turbulenceScale:</b>
		<input type="range" min="0" max="32" step="0.1" v-model="turbulenceScale" /> {{ turbulenceScale }}
	</label>
	<label>
		<b>mirror:</b>
		<input type="checkbox" v-model="mirror" />
	</label>
	<label>
		<b>blurStrength:</b>
		<input type="range" min="0" max="3" step="0.01" v-model="blurStrength" /> {{ blurStrength }}
	</label>
	<label>
		<b>blurTurbulenceEnabled:</b>
		<input type="checkbox" v-model="blurTurbulenceEnabled" />
	</label>
	<label>
		<b>blurQuality:</b>
		<input type="range" min="4" max="512" step="1" v-model="blurQuality" /> {{ blurQuality }}
	</label>
	<label>
		<b>lowQualityBlur:</b>
		<input type="checkbox" v-model="lowQualityBlur" />
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
import { onMounted, onUnmounted, ref, useTemplateRef } from 'vue';
import code from './shader.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { debouncePromise, getUrlParam, isIos } from '@/utils.ts';

const showMenu = ref(false);

const canvas = useTemplateRef('canvas');
let _dispose: (() => void) | null = null;

const scale = ref(getUrlParam('scale', 'float') ?? 1.0);
const timeFactor = ref(getUrlParam('timeFactor', 'float') ?? 1.0);
const turbulenceEnabled = ref(getUrlParam('turbulenceEnabled', 'bool') ?? true);
const turbulenceScale = ref(getUrlParam('turbulenceScale', 'float') ?? 1.5);
const pallette = ref(getUrlParam('pallette', 'string') ?? 'colorful');
const discardThreshold = ref(getUrlParam('discardThreshold', 'float') ?? -0.2);
const channelAFactor = ref(getUrlParam('channelAFactor', 'float') ?? 1.0);
const channelBFactor = ref(getUrlParam('channelBFactor', 'float') ?? 1.0);
const channelCFactor = ref(getUrlParam('channelCFactor', 'float') ?? 1.0);
const selfModulo = ref(getUrlParam('selfModulo', 'bool') ?? true);
const mirror = ref(getUrlParam('mirror', 'bool') ?? false);
const blurStrength = ref(getUrlParam('blurStrength', 'float') ?? 1.0);
const blurTurbulenceEnabled = ref(getUrlParam('blurTurbulenceEnabled', 'bool') ?? true);
const blurQuality = ref(getUrlParam('blurQuality', 'int') ?? 64);
const lowQualityBlur = ref(getUrlParam('lowQualityBlur', 'bool') ?? isIos);
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

	const buffer2 = device.createTexture({
		size: { width: canvas.value!.width, height: canvas.value!.height, depthOrArrayLayers: 1 },
		format: navigator.gpu.getPreferredCanvasFormat(),
		usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
	});

	const blurPipeline = device.createRenderPipeline({
		vertex: {
			module: shaderModule,
			entryPoint: 'vs',
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

	const blurUniformValues = makeStructuredView(defs.uniforms.blurUniforms);
	const blurUniformBuffer = device.createBuffer({
		size: blurUniformValues.arrayBuffer.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});

	const blurHorizontalUniformValues = makeStructuredView(defs.uniforms.blurUniforms);
	const blurHorizontalUniformBuffer = device.createBuffer({
		size: blurHorizontalUniformValues.arrayBuffer.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});

	const blurVerticalUniformValues = makeStructuredView(defs.uniforms.blurUniforms);
	const blurVerticalUniformBuffer = device.createBuffer({
		size: blurVerticalUniformValues.arrayBuffer.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});

	start(ctx => {
		{
			uniformValues.set({
				scale: parseFloat(scale.value),
				aspectRatio: ctx.width / ctx.height,
				time: ctx.time * parseFloat(timeFactor.value),
				turbulenceEnabled: turbulenceEnabled.value ? 1.0 : 0.0,
				turbulenceScale: parseFloat(turbulenceScale.value),
				pallette: pallette.value === 'colorful' ? 0.0 : pallette.value === 'cider' ? 1.0 : pallette.value === 'psyche' ? 2.0 : pallette.value === 'pastel' ? 3.0 : 0.0,
				discardThreshold: parseFloat(discardThreshold.value),
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

		if (lowQualityBlur.value) {
			{
				blurHorizontalUniformValues.set({
					isHorizontal: 1.0,
					turbulenceEnabled: blurTurbulenceEnabled.value ? 1.0 : 0.0,
					turbulenceScale: parseFloat(turbulenceScale.value),
					strength: parseFloat(blurStrength.value),
					quality: parseInt(blurQuality.value),
					isIos: isIos ? 1.0 : 0.0,
					test: test.value ? 1.0 : 0.0,
				});
				ctx.device.queue.writeBuffer(blurHorizontalUniformBuffer, 0, blurHorizontalUniformValues.arrayBuffer);

				const passEncoder = ctx.commandEncoder.beginRenderPass({
					colorAttachments: [{
						view: buffer2.createView(),
						clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
						loadOp: 'clear',
						storeOp: 'store',
					}],
				});
				passEncoder.setPipeline(blurLqPipeline);
				passEncoder.setBindGroup(1, device.createBindGroup({
					layout: blurLqPipeline.getBindGroupLayout(1),
					entries: [
						{ binding: 1, resource: { buffer: uniformBuffer }},
						{ binding: 2, resource: { buffer: blurHorizontalUniformBuffer }},
						{ binding: 3, resource: sampler },
						{ binding: 4, resource: buffer.createView() }
					],
				}));
				passEncoder.draw(6);
				passEncoder.end();
			}

			{
				blurVerticalUniformValues.set({
					isHorizontal: 0.0,
					turbulenceEnabled: blurTurbulenceEnabled.value ? 1.0 : 0.0,
					turbulenceScale: parseFloat(turbulenceScale.value),
					strength: parseFloat(blurStrength.value),
					quality: parseInt(blurQuality.value),
					isIos: isIos ? 1.0 : 0.0,
					test: test.value ? 1.0 : 0.0,
				});
				ctx.device.queue.writeBuffer(blurVerticalUniformBuffer, 0, blurVerticalUniformValues.arrayBuffer);

				const passEncoder = ctx.commandEncoder.beginRenderPass({
					colorAttachments: [{
						view: ctx.renderTarget.createView(),
						clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
						loadOp: 'clear',
						storeOp: 'store',
					}],
				});
				passEncoder.setPipeline(blurLqPipeline);
				passEncoder.setBindGroup(1, device.createBindGroup({
					layout: blurLqPipeline.getBindGroupLayout(1),
					entries: [
						{ binding: 1, resource: { buffer: uniformBuffer }},
						{ binding: 2, resource: { buffer: blurVerticalUniformBuffer }},
						{ binding: 3, resource: sampler },
						{ binding: 4, resource: buffer2.createView() }
					],
				}));
				passEncoder.draw(6);
				passEncoder.end();
			}
		} else {
			{
				blurUniformValues.set({
					turbulenceEnabled: blurTurbulenceEnabled.value ? 1.0 : 0.0,
					turbulenceScale: parseFloat(turbulenceScale.value),
					strength: parseFloat(blurStrength.value),
					quality: parseInt(blurQuality.value),
					isIos: isIos ? 1.0 : 0.0,
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
				passEncoder.setBindGroup(1, device.createBindGroup({
					layout: blurPipeline.getBindGroupLayout(1),
					entries: [
						{ binding: 1, resource: { buffer: uniformBuffer }},
						{ binding: 2, resource: { buffer: blurUniformBuffer }},
						{ binding: 3, resource: sampler },
						{ binding: 4, resource: buffer.createView() }
					],
				}));
				passEncoder.draw(6);
				passEncoder.end();
			}
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

onUnmounted(() => {
	if (_dispose) _dispose();
});
</script>

<style scoped>

</style>
