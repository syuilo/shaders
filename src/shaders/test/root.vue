<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
</template>

<script lang="ts" setup>
import { onMounted, useTemplateRef } from 'vue';
import code from './shader.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';

const canvas = useTemplateRef('canvas');

onMounted(async () => {
	const { start, device, pipeline } = await initWebGPU(canvas.value!, code);

	start(ctx => {

	});
});
</script>

<style scoped>

</style>
