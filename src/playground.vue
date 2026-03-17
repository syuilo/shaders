<template>
<canvas ref="canvas" style="display: block; width: 100%; height: 100%;"></canvas>
<button id="menuButton" :class="hideMenuButton ? 'hide' : null" @click="showMenu = !showMenu">MENU</button>
<div v-if="showMenu && playgroundDef != null" id="menu">
	<h1>WebGPU - {{ playgroundDef.title }} SHADER by syuilo</h1>

	<label v-for="[k, s] in Object.entries(playgroundDef.params)" :key="k">
		<b>{{ s.label }}</b>
		<template v-if="s.type === 'color'">
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
			<input type="range" :min="s.min" :max="s.max" :step="s.step" v-model="params[k]" /> {{ params[k] }}
		</template>
		<template v-else-if="s.type === 'image'">
		</template>
	</label>

	<hr>

	<label>
		<b>pixelRatioFactor:</b>
		<select v-model="pixelRatioFactor">
			<option :value="0.25">0.25</option>
			<option :value="0.5">0.5</option>
			<option :value="1.0">1.0</option>
			<option :value="2.0">2.0</option>
			<option :value="4.0">4.0</option>
		</select>
	</label>
	<label>
		<b>fps:</b>
		<select v-model="fps">
			<option :value="null">device default</option>
			<option :value="15">(up to) 15 FPS</option>
			<option :value="30">(up to) 30 FPS</option>
			<option :value="60">(up to) 60 FPS</option>
			<option :value="120">(up to) 120 FPS</option>
		</select>
	</label>
	<label>
		<b>Hide menu button:</b>
		<input type="checkbox" v-model="hideMenuButton" />
	</label>
</div>
</template>

<script lang="ts" setup>
import { onMounted, onUnmounted, reactive, ref, shallowRef, useTemplateRef, watch } from 'vue';
import { debouncePromise, getUrlParam, isIos, Playground } from '@/utils.ts';

const props = defineProps<{
	name: string;
}>();

const canvas = useTemplateRef('canvas');
const playgroundDef = shallowRef<Playground | null>(null);
let params = reactive<Record<string, any>>({});
let dispose: (() => void) | null = null;

async function init() {
	console.log(`Initializing ${props.name}...`);

	if (dispose != null) dispose();
	if (canvas.value == null) return;
	if (playgroundDef.value == null) return;

	const pixelRatio = window.devicePixelRatio * pixelRatioFactor.value;

	const adapter = await navigator.gpu?.requestAdapter({
		powerPreference: 'low-power',
	});
	const _device = await adapter?.requestDevice();
	if (!_device) {
		window.alert('need a browser that supports WebGPU');
		throw new Error('need a browser that supports WebGPU');
	}
	const device = _device as GPUDevice;

	const _context = canvas.value.getContext('webgpu');
	if (!_context) {
		window.alert('cannot get webgpu context');
		throw new Error('cannot get webgpu context');
	}
	const context = _context as GPUCanvasContext;

	canvas.value.width = Math.max(1, Math.min(canvas.value.offsetWidth * pixelRatio, device.limits.maxTextureDimension2D));
	canvas.value.height = Math.max(1, Math.min(canvas.value.offsetHeight * pixelRatio, device.limits.maxTextureDimension2D));

	context.configure({
		device,
		format: navigator.gpu.getPreferredCanvasFormat(),
		alphaMode: 'premultiplied',
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

	// 誰が見ても同じレンダリング結果になるように、開いた時間を基準にする
	// ただそのままUNIX時間を入れると、秒数が大きすぎて浮動小数点数の関係で精度が落ちるため、1日間隔でループ
	const initialTime = Date.now() % (1000 * 60 * 60 * 24);

	const playgroundInstance = playgroundDef.value.init({
		width: canvas.value.width,
		height: canvas.value.height,
		wgpu: { device, context, sampler },
		params: params,
	});

	let disposed = false;

	function render(timeStamp: number) {
		if (disposed) return;
		const time = (initialTime + Math.floor(timeStamp)) * timeFactor.value;
		const commandEncoder = device.createCommandEncoder();
		playgroundInstance.render({ commandEncoder, time });
		device.queue.submit([commandEncoder.finish()]);
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

const debouncedInit = debouncePromise(init, 500);

watch(
	() => props.name,
	async name => {
		playgroundDef.value = await import(`./shaders/${name}/main.ts`).then(module => module.playground);
		params = reactive(playgroundDef.value.getDefaultParams());

		debouncedInit();
	},
	{ immediate: true }
);

const showMenu = ref(false);

const timeFactor = ref(getUrlParam('_timeFactor', 'float') ?? 1.0);
const pixelRatioFactor = ref(getUrlParam('_pixelRatioFactor', 'number') ?? (isIos ? 0.5 : 1.0));
const fps = ref(getUrlParam('_fps', 'float') ?? null);

const hideMenuButton = ref(false);

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

watch([pixelRatioFactor, fps], () => {
	debouncedInit();
});

onUnmounted(() => {
	if (dispose != null) dispose();
});
</script>

<style scoped>

</style>
