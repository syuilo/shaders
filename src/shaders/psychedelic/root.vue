<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
<button id="menuButton" @click="showMenu = !showMenu">MENU</button>
<div v-if="showMenu" id="menu">
	<h1>WebGPU - PSYCHEDELIC SHADER by syuilo</h1>
	<label>
		<b>noiseAEnabled:</b>
		<input type="checkbox" v-model="noiseAEnabled" />
	</label>
	<label>
		<b>noiseAScale:</b>
		<input type="range" min="2" max="256" step="1" v-model="noiseAScale" />
	</label>
	<label>
		<b>mirror:</b>
		<input type="checkbox" v-model="mirror" />
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

const noiseAEnabled = ref(getUrlParam('noiseAEnabled', 'bool') ?? true);
const noiseAScale = ref(getUrlParam('noiseAScale', 'int') ?? 64);
const mirror = ref(getUrlParam('mirror', 'bool') ?? false);

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
			aspectRatio: ctx.width / ctx.height,
			time: ctx.time,
			noiseAEnabled: noiseAEnabled.value ? 1.0 : 0.0,
			noiseAScale: parseFloat(noiseAScale.value),
			mirror: mirror.value ? 1.0 : 0.0,
		});

		ctx.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

		ctx.passEncoder.setBindGroup(0, bindGroup);
	});
});
</script>

<style scoped>

</style>
