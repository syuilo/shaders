<template>
<div v-if="playgroundDef.alpha" id="bg" :class="{ 'animatedBg': animatedBg }"></div>
<canvas id="canvas" ref="canvas" :class="{ 'animatedBg': animatedBg }"></canvas>
<button id="menuButton" :class="hideMenuButton ? 'hide' : null" @click="showMenu = !showMenu">MENU</button>
<div id="stats" :class="!enableStats ? 'hide' : null">
	<div>
		<div>Short avg</div>
		<div>Long avg</div>
	</div>
	<div>
		<div>{{ gpuAverageDisplayFast.toFixed(1) }}µs</div>
		<div>{{ gpuAverageDisplaySlow.toFixed(1) }}µs</div>
	</div>
	<div>
		<div>{{ (gpuAverageDisplayFast / 1000).toFixed(1) }}ms</div>
		<div>{{ (gpuAverageDisplaySlow / 1000).toFixed(1) }}ms</div>
	</div>
</div>
<div v-show="showMenu" id="menu">
	<h1><a href="./">syuilo's Shader Playground</a> - "{{ playgroundDef.title }}"</h1>

	<label v-for="[k, s] in Object.entries(playgroundDef.params)" :key="k">
		<b>{{ s.label }}</b>
		<template v-if="s.type === 'color'">
			<input type="color" :value="getHex(params[k])" @input="v => { params[k] = getRgb(v.target.value); }" />
		</template>
		<template v-else-if="s.type === 'boolean'">
			<input type="checkbox" v-model="params[k]" />
		</template>
		<template v-else-if="s.type === 'enum'">
			<select v-model="params[k]">
				<option v-for="option in s.enum" :value="option.value">{{ option.label }}</option>
			</select>
		</template>
		<template v-else-if="s.type === 'range'">
			<input type="range" :min="s.min" :max="s.max" :step="s.step" v-model.number="params[k]" /> {{ params[k] }}
		</template>
		<template v-else-if="s.type === 'media'">
			<XMedia @updated="params[k] = $event != null ? markRaw($event) : null" />
		</template>
	</label>

	<hr>

	<template v-if="playgroundDef.alpha">
		<label>
			<b>Background color:</b>
			<input type="color" :value="bgColor" @input="v => { bgColor = v.target.value; }" />
		</label>
		<label>
			<b>Animated background:</b>
			<input type="checkbox" v-model="animatedBg" />
		</label>
	</template>

	<label>
		<b>Time speed:</b>
		<input type="range" min="-4" max="4" step="0.1" v-model="timeFactor" /> {{ timeFactor }}
	</label>
	<label>
		<b>Pixel ratio:</b>
		<select v-model="pixelRatio">
			<option :value="null">native</option>
			<option :value="0.25">0.25</option>
			<option :value="0.5">0.5</option>
			<option :value="1">1</option>
			<option :value="2">2</option>
			<option :value="4">4</option>
		</select>
		<span>({{ resolutionDisplay.width }} x {{ resolutionDisplay.height }})</span>
	</label>
	<label>
		<b>FPS:</b>
		<select v-model="fps">
			<option :value="null">native</option>
			<option :value="15">(up to) 15 FPS</option>
			<option :value="30">(up to) 30 FPS</option>
			<option :value="60">(up to) 60 FPS</option>
			<option :value="120">(up to) 120 FPS</option>
		</select>
		<span>({{ fpsDisplay.toFixed(1) }} FPS)</span>
	</label>
	<label>
		<b>Hide menu button:</b>
		<input type="checkbox" v-model="hideMenuButton" />
	</label>
	<button type="button" @click="copyUrl">Copy URL</button>

	<hr>

	<label>
		<b>Show debug menu:</b>
		<input type="checkbox" v-model="showDebugMenu" />
	</label>

	<template v-if="showDebugMenu">
		<label>
			<b>Enable stats:</b>
			<input type="checkbox" v-model="enableStats" />
		</label>
		<label>
			<b>Time specified:</b>
			<input type="number" v-model.number="timeSpecified" /> (ms)
		</label>
		<label>
			<b>Benchmark mode:</b>
			<input type="checkbox" v-model="benchmarkMode" />
		</label>
	</template>

</div>
</template>

<script lang="ts" setup>
import { markRaw, onMounted, onUnmounted, reactive, ref, useTemplateRef, watch } from 'vue';
import { debouncePromise, getHex, getRgb, Playground } from '@/utils.ts';
import XMedia from './media.vue';
import TimingHelper from './TimingHelper.ts';
import { NonNegativeRollingAverage } from './NonNegativeRollingAverage.ts';
import defaultVertexShaderCode from './vertex.wgsl?raw';

const props = defineProps<{
	name: string;
}>();

const tryParseJson = (value: string | null, defa: any) => {
	if (value == null) return defa;
	return JSON.parse(value);
};

const canvas = useTemplateRef('canvas');
const urlParams = new URLSearchParams(window.location.search);
const playgroundDef = await import(`./shaders/${props.name}/main.ts`).then(module => module.playground as Playground);
const params = reactive(playgroundDef.getDefaultParams());
let dispose: (() => void) | null = null;
const benchmarkMode = ref(false);
const fpsAverage = new NonNegativeRollingAverage(30);
const fpsDisplay = ref(0);
const resolutionDisplay = ref({ width: 0, height: 0 });
const enableStats = ref(false);
const gpuAverageFast = new NonNegativeRollingAverage(10);
const gpuAverageMedium = new NonNegativeRollingAverage(100);
const gpuAverageSlow = new NonNegativeRollingAverage(1000);
const gpuAverageDisplayFast = ref(0);
const gpuAverageDisplayMedium = ref(0);
const gpuAverageDisplaySlow = ref(0);
const showMenu = ref(false);
const showDebugMenu = ref(false);
const hideMenuButton = ref(tryParseJson(urlParams.get('_hideMenuButton'), false));
const timeFactor = ref(tryParseJson(urlParams.get('_timeFactor'), 1.0));
const timeSpecified = ref(tryParseJson(urlParams.get('_timeSpecified'), null));
const pixelRatio = ref(tryParseJson(urlParams.get('_pixelRatio'), 1));
const fps = ref(tryParseJson(urlParams.get('_fps'), 60));
const bgColor = ref(tryParseJson(urlParams.get('_bgColor'), playgroundDef?.backgroundColor ?? '#000000'));
const animatedBg = ref(tryParseJson(urlParams.get('_animatedBg'), false));

async function copyUrl() {
	const nextUrlParams = new URLSearchParams(window.location.search);
	nextUrlParams.delete(props.name);

	for (const [key, schema] of Object.entries(playgroundDef.params)) {
		if (schema.type === 'media') {
			nextUrlParams.delete(key);
			continue;
		}

		nextUrlParams.set(key, JSON.stringify(params[key]));
	}

	for (const [key, value] of [
		['_hideMenuButton', hideMenuButton.value],
		['_timeFactor', timeFactor.value],
		['_timeSpecified', timeSpecified.value],
		['_pixelRatio', pixelRatio.value],
		['_fps', fps.value],
		['_bgColor', bgColor.value],
		['_animatedBg', animatedBg.value],
	] as const) {
		nextUrlParams.set(key, JSON.stringify(value));
	}

	const serializedParams = nextUrlParams.toString();
	const query = serializedParams === '' ? props.name : `${props.name}&${serializedParams}`;
	const url = new URL(window.location.href);
	url.search = query;

	try {
		await navigator.clipboard.writeText(url.toString());
	} catch {
		window.alert('Failed to copy URL');
	}
}

async function init() {
	console.log(`Initializing ${props.name}...`);

	if (dispose != null) dispose();
	if (canvas.value == null) return;
	if (playgroundDef == null) return;

	const adapter = await navigator.gpu?.requestAdapter({
		//powerPreference: 'low-power',
	});
	const _device = await adapter?.requestDevice({
		requiredFeatures: [
			...(enableStats.value ? ['timestamp-query'] as const : []),
		],
	});
	if (!_device) {
		window.alert('need a browser that supports WebGPU');
		throw new Error('need a browser that supports WebGPU');
	}
	const device = _device as GPUDevice;

	const timingHelper = new TimingHelper(device);

	const _context = canvas.value.getContext('webgpu');
	if (!_context) {
		window.alert('cannot get webgpu context');
		throw new Error('cannot get webgpu context');
	}
	const context = _context as GPUCanvasContext;

	canvas.value.width = benchmarkMode.value ? 1024 * (pixelRatio.value ?? 1) : Math.max(1, Math.min(canvas.value.offsetWidth * (pixelRatio.value ?? window.devicePixelRatio), device.limits.maxTextureDimension2D));
	canvas.value.height = benchmarkMode.value ? 1024 * (pixelRatio.value ?? 1) : Math.max(1, Math.min(canvas.value.offsetHeight * (pixelRatio.value ?? window.devicePixelRatio), device.limits.maxTextureDimension2D));

	resolutionDisplay.value.width = canvas.value.width;
	resolutionDisplay.value.height = canvas.value.height;

	context.configure({
		device,
		format: navigator.gpu.getPreferredCanvasFormat(),
		alphaMode: playgroundDef.alpha ? 'premultiplied' : 'opaque',
		colorSpace: 'display-p3',
	});

	const sampler = device.createSampler({
		magFilter: 'linear',
		minFilter: 'linear',
		mipmapFilter: 'linear',
		addressModeU: 'mirror-repeat',
		addressModeV: 'mirror-repeat',
		addressModeW: 'mirror-repeat',
	});

	const defaultVertexShaderModule = device.createShaderModule({
		code: defaultVertexShaderCode,
	});

	// 誰が見ても同じレンダリング結果になるように、開いた時間を基準にする
	// ただそのままUNIX時間を入れると、秒数が大きすぎて浮動小数点数の関係で精度が落ちるため、1日間隔でループ
	const initialTime = (Date.now() % (1000 * 60 * 60 * 24));

	const playgroundInstance = await playgroundDef.init({
		width: canvas.value.width,
		height: canvas.value.height,
		wgpu: { device, context, sampler, defaultVertexShaderModule },
		params: params,
		canvas: canvas.value,
	});

	let disposed = false;
	let latestTimestamp = performance.now();
	let time = initialTime;

	const createPassEncoder = (commandEncoder: GPUCommandEncoder, descriptor?: GPURenderPassDescriptor) => {
		const _descriptor = descriptor ?? {
			colorAttachments: [{
				view: context.getCurrentTexture().createView(),
				clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
				loadOp: 'clear',
				storeOp: 'store',
			}],
		} satisfies GPURenderPassDescriptor;
		return enableStats.value ? timingHelper.beginRenderPass(commandEncoder, _descriptor) : commandEncoder.beginRenderPass(_descriptor);
	};

	function render(timeStamp: number) {
		if (disposed) return;
		const timeDelta = timeStamp - latestTimestamp;
		time += Math.floor(timeDelta * timeFactor.value);
		const commandEncoder = device.createCommandEncoder();
		playgroundInstance.render({
			commandEncoder,
			createPassEncoder,
			time: timeSpecified.value != null && timeSpecified.value != '' ? timeSpecified.value : time,
			timeDelta: timeSpecified.value != null && timeSpecified.value != '' ? 0 : timeDelta,
		});
		device.queue.submit([commandEncoder.finish()]);
		latestTimestamp = timeStamp;

		fpsAverage.addSample(1000 / timeDelta);
		fpsDisplay.value = fpsAverage.get();

		if (enableStats.value) {
			timingHelper.getResult().then(gpuTime => {
				gpuAverageFast.addSample(gpuTime / 1000);
				gpuAverageMedium.addSample(gpuTime / 1000);
				gpuAverageSlow.addSample(gpuTime / 1000);
			});

			gpuAverageDisplayFast.value = gpuAverageFast.get();
			gpuAverageDisplayMedium.value = gpuAverageMedium.get();
			gpuAverageDisplaySlow.value = gpuAverageSlow.get();
		}
	}

	let then = 0;
	const interval = 1000 / (fps.value ?? 30);

	function renderLoop(timeStamp: number) {
		if (disposed) return;

		window.requestAnimationFrame(renderLoop);

		if (fps.value != null) {
			const delta = timeStamp - then;
			if (delta <= interval) return;
			then = timeStamp - (delta % interval);
		}

		render(timeStamp);
	}

	window.requestAnimationFrame(renderLoop);

	dispose = () => {
		disposed = true;
		device.destroy();
		context.unconfigure();
		playgroundInstance.dispose?.();
	};
}

const debouncedInit = debouncePromise(init, 100);

for (const k of Object.keys(playgroundDef.params)) {
	const urlValue = urlParams.getAll(k);
	for (const v of urlValue) {
		if (v != '') {
			params[k] = JSON.parse(v);
		}
	}
}

for (const [k, v] of Object.entries(playgroundDef.params)) {
	if (v.needReinit) {
		watch(() => params[k], () => {
			debouncedInit();
		});
	}
}

debouncedInit();

onMounted(async () => {
	const observer = new ResizeObserver(entries => {
		for (const entry of entries) {
			if (entry.target === canvas.value) {
				debouncedInit();
			}
		}
	});
	observer.observe(canvas.value!);
});

watch([pixelRatio, fps, enableStats, benchmarkMode], () => {
	debouncedInit();
});

onUnmounted(() => {
	if (dispose != null) dispose();
});
</script>

<style scoped>
#canvas {
	position: relative;
	display: block;
	width: 100%;
	height: 100%;
	touch-action: none;
}

#bg {
	position: absolute;
	top: 0;
	left: 0;
	width: 100%;
	height: 100%;
	background-color: v-bind("bgColor");
}

@keyframes bg {
	0% { background-position: 0 0; }
	100% { background-position: -30px -30px; }
}

.animatedBg {
	--colorA: v-bind("bgColor");
	--colorB: hsl(from var(--colorA) h s calc(l - 10));
	background-image: repeating-conic-gradient(var(--colorA) 0% 25%, var(--colorB) 0% 50%);
	background-size: 30px 30px;
	animation: bg 1.2s linear infinite;
}
</style>
