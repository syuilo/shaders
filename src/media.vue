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
import { ref, watch } from 'vue';
import { setupWebcam, Media } from '@/utils.ts';
import { playVideoAfterFirstFrameIsReady } from '@/video.ts';

const emit = defineEmits<{
	(ev: 'updated', v: Media | null): void;
}>();

const imageElement = document.createElement('img');
const videoElement = document.createElement('video');
videoElement.loop = true;
videoElement.preload = 'auto';
videoElement.playsInline = true;

const sourceType = ref<'image' | 'video' | null>(null);
let imageObjectUrl: string | null = null;
let videoObjectUrl: string | null = null;

function sourceUpdated() {
	if (sourceType.value === 'image') {
		emit('updated', { type: 'image', element: imageElement });
	} else if (sourceType.value === 'video') {
		emit('updated', { type: 'video', element: videoElement });
	} else {
		emit('updated', null);
	}
}

const videoAudioVolume = ref(0);
watch(videoAudioVolume, (v) => {
	videoElement.volume = v;
	videoElement.muted = v === 0;
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

function resetVideoElement() {
	videoElement.pause();
	videoElement.srcObject = null;
	videoElement.removeAttribute('src');
	videoElement.load();
	if (videoObjectUrl !== null) {
		URL.revokeObjectURL(videoObjectUrl);
		videoObjectUrl = null;
	}
}

async function onFileSelected(ev: Event) {
	const input = ev.target as HTMLInputElement;
	if (!input.files || input.files.length == 0) return;
	const file = input.files[0];
	if (file.type.startsWith('image/')) {
		resetVideoElement();
		if (imageObjectUrl !== null) URL.revokeObjectURL(imageObjectUrl);
		imageObjectUrl = URL.createObjectURL(file);
		imageElement.src = imageObjectUrl;
		await imageElement.decode();
		sourceType.value = 'image';
	} else if (file.type.startsWith('video/')) {
		resetVideoElement();
		videoObjectUrl = URL.createObjectURL(file);
		videoElement.src = videoObjectUrl;
		await playVideoAfterFirstFrameIsReady(videoElement);
		sourceType.value = 'video';
	}
	sourceUpdated();
}

async function useWebcam() {
	const camera = await setupWebcam();
	resetVideoElement();
	videoElement.srcObject = camera;
	await playVideoAfterFirstFrameIsReady(videoElement);
	sourceType.value = 'video';
	sourceUpdated();
}

function clear() {
	resetVideoElement();
	imageElement.removeAttribute('src');
	if (imageObjectUrl !== null) {
		URL.revokeObjectURL(imageObjectUrl);
		imageObjectUrl = null;
	}
	sourceType.value = null;
	sourceUpdated();
}
</script>

<style scoped>

</style>
