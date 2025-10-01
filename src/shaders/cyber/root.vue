<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
</template>

<script lang="ts" setup>
import { onMounted, useTemplateRef } from 'vue';
import code from './shader.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';
import { getUrlParam } from '@/utils.ts';
import { createTextureFromImages, makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';

const canvas = useTemplateRef('canvas');

const textureUrls = [
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
	'./assets/symbols/block.png',

	...(getUrlParam('numbers', 'bool') ? [
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

	'./assets/symbols/square-slash.png',
	'./assets/symbols/stripe.png',
	'./assets/symbols/fill.png',
];

const divisions = getUrlParam('divisions', 'int') ?? 40;
const timeFactor = getUrlParam('timeFactor', 'float') ?? 1.0;

onMounted(async () => {
	const { start, device, pipeline } = await initWebGPU(canvas.value!, code, {
		fps: 30,
	});

	const sampler = device.createSampler({
		magFilter: 'linear',
		minFilter: 'linear',
		mipmapFilter: 'linear',
	});

	const texture = await createTextureFromImages(device, textureUrls, {
		mips: true,
		flipY: true,
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
			{ binding: 2, resource: sampler },
			{ binding: 3, resource: texture.createView({ dimension: '2d-array' }) },
		],
	});

	start(ctx => {
		uniformValues.set({
			aspectRatio: ctx.aspectRatioMax,
			time: ctx.time,
			timeFactor: timeFactor,
			divisions: divisions,
			texturesCount: textureUrls.length,
		});
		ctx.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

		ctx.passEncoder.setBindGroup(0, bindGroup);
	});
});
</script>

<style scoped>

</style>
