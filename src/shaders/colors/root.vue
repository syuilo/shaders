<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
</template>

<script lang="ts" setup>
import { onMounted, useTemplateRef } from 'vue';
import code from './shader.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';

const canvas = useTemplateRef('canvas');

onMounted(async () => {
	const { start, device, pipeline } = await initWebGPU(canvas.value!, code);

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
			aspectRatio: ctx.aspectRatioMin,
			time: ctx.time,
		});

		ctx.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

		ctx.passEncoder.setBindGroup(0, bindGroup);
	});
});
</script>

<style scoped>

</style>
