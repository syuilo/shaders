<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%; touch-action: none;"></canvas>
<button id="menuButton" @click="showMenu = !showMenu">MENU</button>
<div v-if="showMenu" id="menu">
	<h1>WebGPU - CYBER SHADER by syuilo</h1>
	<label>
		<b>limit fps to 30:</b>
		<input type="checkbox" v-model="limitFpsTo30" />
	</label>
	<label>
		<b>source image/video:</b>
		<input type="file" accept="image/*,video/*" @change="onFileSelected"/>
	</label>
	<label>
		<b>audio volume:</b>
		<input type="range" min="0" max="1" step="0.01" v-model="videoAudioVolume" />
	</label>
	<label>
		<b>video control:</b>
		<button @click="videoElement.play()">play</button>
		<button @click="videoElement.pause()">pause</button>
		<input type="range" min="0" :max="videoDuration" step="0.01" :value="videoCurrentTime" @input="seekVideoTo($event.target.value)" />
	</label>
	<label>
		<b>discard bright pixels:</b>
		<input type="checkbox" v-model="discardBrightPixels" />
	</label>
	<label>
		<b>enable sampled cell joining:</b>
		<input type="checkbox" v-model="enableSampledCellJoining" />
	</label>
	<label>
		<b>time factor:</b>
		<input type="range" min="0" max="16" step="0.01" v-model="timeFactor" />
	</label>
	<label>
		<b>divisions:</b>
		<input type="range" min="8" max="512" step="1" v-model="divisions" />
	</label>
	<label>
		<b>with numbers:</b>
		<input type="checkbox" v-model="withNumbers" />
	</label>
	<label>
		<b>symbol variations range min:</b>
		<input type="range" min="0" max="1" step="0.01" v-model="symbolTexturesRangeMin" />
	</label>
	<label>
		<b>symbol variations range max:</b>
		<input type="range" min="0" max="1" step="0.01" v-model="symbolTexturesRangeMax" />
	</label>
</div>
</template>

<script lang="ts" setup>
import { onMounted, ref, useTemplateRef, watch } from 'vue';
import code from './shader.wgsl?raw';
import { initWebGPU } from '@/webgpu.ts';
import { getUrlParam } from '@/utils.ts';
import { createTextureFromImages, createTextureFromSource, makeShaderDataDefinitions, makeStructuredView } from 'webgpu-utils';

const showMenu = ref(false);

const canvas = useTemplateRef('canvas');

const imageElement = document.createElement('img');
const videoElement = document.createElement('video');
videoElement.loop = true;
videoElement.preload = 'auto';
let sorceType: 'image' | 'video' | null = null;

const videoAudioVolume = ref(0.3);
watch(videoAudioVolume, (v) => {
	videoElement.volume = v;
}, { immediate: true });

const videoDuration = ref(0);
const videoCurrentTime = ref(0);
videoElement.addEventListener('loadedmetadata', () => {
	videoDuration.value = videoElement.duration;
});
videoElement.addEventListener('timeupdate', () => {
	videoCurrentTime.value = videoElement.currentTime;
});

function seekVideoTo(v: number) {
	videoElement.currentTime = v;
}

const limitFpsTo30 = ref(getUrlParam('limitFpsTo30', 'bool') ?? true);
watch(limitFpsTo30, () => {
	init();
});
const timeFactor = ref(getUrlParam('timeFactor', 'float') ?? 1.0);
const divisions = ref(getUrlParam('divisions', 'int') ?? 64);
const discardBrightPixels = ref(getUrlParam('discardBrightPixels', 'bool') ?? true);
const enableSampledCellJoining = ref(getUrlParam('enableSampledCellJoining', 'bool') ?? true);
const symbolTexturesRangeMin = ref(getUrlParam('symbolTexturesRangeMin', 'float') ?? 0.0);
const symbolTexturesRangeMax = ref(getUrlParam('symbolTexturesRangeMax', 'float') ?? 1.0);
const withNumbers = ref(getUrlParam('numbers', 'bool') ?? false);
watch(withNumbers, () => {
	init();
});

let _dispose: (() => void) | null = null;
let pointerX = -1.0;
let pointerY = -1.0;
let lastPointerMovedAt = 0;

async function init() {
	if (_dispose) _dispose();

	const { start, device, pipeline, dispose } = await initWebGPU(canvas.value!, code, {
		fps: limitFpsTo30.value ? 30 : null,
	});
	_dispose = dispose;

	const symbolTextureUrls = [
		'./assets/symbols/dot.png',
		'./assets/symbols/dot.png',
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
		'./assets/symbols/square-slash.png',

		...(withNumbers.value ? [
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

		'./assets/symbols/block.png',

		//'./assets/symbols/square-slash.png',
		//'./assets/symbols/stripe.png',
		//'./assets/symbols/fill.png',
	];

	const sampler = device.createSampler({
		magFilter: 'linear',
		minFilter: 'linear',
		mipmapFilter: 'linear',
	});

	const symbolTextures = await createTextureFromImages(device, symbolTextureUrls, {
		mips: true,
		flipY: true,
	});

	const sourceTexture = createTextureFromSource(device, sorceType === 'video' ? videoElement : sorceType === 'image' ? imageElement : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], {
		mips: sorceType === 'video' ? false : true,
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
			{ binding: 3, resource: symbolTextures.createView({ dimension: '2d-array' }) },
			{ binding: 4, resource: sourceTexture.createView() },
		],
	});

	start(ctx => {
		if (lastPointerMovedAt + 30 < performance.now()) {
			pointerX = -1.0;
			pointerY = -1.0;
		}

		uniformValues.set({
			aspectRatio: ctx.width / ctx.height,
			useSource: sorceType == null ? 0 : 1,
			sourceTextureAspectRatio: sourceTexture.width / sourceTexture.height,
			discardBrightPixels: discardBrightPixels.value ? 1 : 0,
			enableSampledCellJoining: enableSampledCellJoining.value ? 1 : 0,
			time: ctx.time,
			timeFactor: parseFloat(timeFactor.value),
			divisions: parseInt(divisions.value),
			symbolTexturesCount: symbolTextureUrls.length,
			symbolTexturesRangeMin: parseFloat(symbolTexturesRangeMin.value),
			symbolTexturesRangeMax: parseFloat(symbolTexturesRangeMax.value),
			pointerPosition: [pointerX, -pointerY],
		});
		ctx.device.queue.writeBuffer(uniformBuffer, 0, uniformValues.arrayBuffer);

		ctx.passEncoder.setBindGroup(0, bindGroup);

		if (sorceType === 'video' && videoElement.readyState >= 4) {
			ctx.device.queue.copyExternalImageToTexture(
				{ source: videoElement, flipY: true, },
				{ texture: sourceTexture },
				{ width: sourceTexture.width, height: sourceTexture.height },
			);
		}
	});
}

onMounted(() => {
	init();

	window.addEventListener('pointermove', (ev: PointerEvent) => {
		if (!canvas.value) return;
		const rect = canvas.value.getBoundingClientRect();
		const w = rect.width;
		const h = rect.height;
		const x = (ev.clientX - rect.left) / w;
		const y = (ev.clientY - rect.top) / h;
		pointerX = x;
		pointerY = y;
		lastPointerMovedAt = performance.now();
	});

	window.addEventListener('wheel', (ev: WheelEvent) => {
		if (ev.deltaY > 0) {
			divisions.value = Math.floor(divisions.value * 1.2);
		} else if (ev.deltaY < 0) {
			divisions.value = Math.floor(divisions.value / 1.2);
		}
		divisions.value = Math.min(512, Math.max(8, divisions.value));
	}, { passive: false });

	window.addEventListener('keydown', (ev: KeyboardEvent) => {
		if (ev.key === 'Escape') {
			showMenu.value = false;
			ev.preventDefault();
		} else if (ev.key === ' ') {
			videoElement.paused ? videoElement.play() : videoElement.pause();
			ev.preventDefault();
		} else if (ev.key === 'ArrowLeft') {
			videoElement.currentTime = Math.max(0, videoElement.currentTime - 0.01);
			ev.preventDefault();
		} else if (ev.key === 'ArrowRight') {
			videoElement.currentTime = Math.min(videoElement.duration, videoElement.currentTime + 0.01);
			ev.preventDefault();
		}
	});
});

async function onFileSelected(ev: Event) {
	const input = ev.target as HTMLInputElement;
	if (!input.files || input.files.length == 0) return;
	const file = input.files[0];
	if (file.type.startsWith('image/')) {
		imageElement.src = URL.createObjectURL(file);
		await imageElement.decode();
		sorceType = 'image';
	} else if (file.type.startsWith('video/')) {
		videoElement.src = URL.createObjectURL(file);
		await videoElement.play();
		sorceType = 'video';
	}
	init();
}
</script>

<style scoped>

</style>
