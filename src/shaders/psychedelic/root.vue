<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
<button id="menuButton" @click="showMenu = !showMenu">MENU</button>
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
		<b>test:</b>
		<input type="checkbox" v-model="test" />
	</label>
</div>
</template>

<script lang="ts" setup>
import { onMounted, ref, useTemplateRef } from 'vue';
import code from './shader.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { getUrlParam } from '@/utils.ts';

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
const test = ref(getUrlParam('test', 'bool') ?? false);

onMounted(async () => {
		if (_dispose) _dispose();

	const { start, device, pipeline, dispose } = await initWebGPU(canvas.value!, code, { fps: null });
	_dispose = dispose;

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

	start(ctx => {
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

		ctx.passEncoder.setBindGroup(0, bindGroup);
	});
});
</script>

<style scoped>

</style>
