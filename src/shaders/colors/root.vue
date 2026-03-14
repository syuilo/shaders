<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
</template>

<script lang="ts" setup>
import { onMounted, ref, useTemplateRef } from 'vue';
import code from './shader.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';
import { makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';
import { getUrlParam } from '@/utils.ts';

const canvas = useTemplateRef('canvas');
let _dispose: (() => void) | null = null;

const scale = ref(getUrlParam('scale', 'float') ?? 1.0);

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
		});

		ctx.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

		ctx.passEncoder.setBindGroup(0, bindGroup);
	});
});
</script>

<style scoped>

</style>
