<template>
<div>
	<label>
		<b>image/video:</b>
		<input type="file" accept="image/*,video/*" @change="onFileSelected"/> or <button @click="useWebcam">Use webcamera</button>
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
	<button @click="clear">x</button>
</div>
</template>

<script lang="ts" setup>
import { onMounted, ref, useTemplateRef, watch } from 'vue';
import { setupWebcam } from '@/webgpu.ts';
import { getUrlParam, Media } from '@/utils.ts';

const emit = defineEmits<{
	(ev: 'updated', v: Media | null): void;
}>();

const imageElement = document.createElement('img');
const videoElement = document.createElement('video');
videoElement.loop = true;
videoElement.preload = 'auto';

const sorceType = ref<'image' | 'video' | null>(null);

function sourceUpdated() {
	if (sorceType.value === 'image') {
		emit('updated', { type: 'image', element: imageElement });
	} else if (sorceType.value === 'video') {
		emit('updated', { type: 'video', element: videoElement });
	} else {
		emit('updated', null);
	}
}

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

async function onFileSelected(ev: Event) {
	const input = ev.target as HTMLInputElement;
	if (!input.files || input.files.length == 0) return;
	const file = input.files[0];
	if (file.type.startsWith('image/')) {
		imageElement.src = URL.createObjectURL(file);
		await imageElement.decode();
		sorceType.value = 'image';
	} else if (file.type.startsWith('video/')) {
		videoElement.src = URL.createObjectURL(file);
		await videoElement.play();
		sorceType.value = 'video';
	}
	sourceUpdated()
}

async function useWebcam() {
	const camera = await setupWebcam();
	videoElement.srcObject = camera;
	await videoElement.play();
	sorceType.value = 'video';
	sourceUpdated()
}

function clear() {
	videoElement.pause();
	videoElement.src = '';
	imageElement.src = '';
	sorceType.value = null;
	sourceUpdated()
}
</script>

<style scoped>

</style>
