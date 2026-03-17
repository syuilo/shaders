<template>
<component :is="c" v-if="component" />
</template>

<script lang="ts" setup>
import { defineAsyncComponent } from 'vue';
import { getUrlParam } from './utils.ts';

const shader = getUrlParam('shader', 'string');

let component;
switch (shader) {
	case 'test': component = import('./shaders/test/root.vue'); break;
	case 'test3': component = import('./shaders/test3/root.vue'); break;
	case 'colors': component = import('./shaders/colors/root.vue'); break;
	case 'liquid-paint': component = import('./shaders/liquid-paint/root.vue'); break;
	case 'cyber': component = import('./shaders/cyber/root.vue'); break;
	case 'nodes': component = import('./shaders/nodes/root.vue'); break;
	case 'tilesort': component = import('./shaders/tilesort/root.vue'); break;
}

const c = defineAsyncComponent(() => component);
</script>

<style scoped>

</style>
