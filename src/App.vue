<template>
<Suspense v-if="name != null">
	<XPlayground :name="name" :key="name"/>
</Suspense>
<div v-else>
	<h1>syuilo's Shader Playground (WebGPU)</h1>
	<ul>
		<li v-for="shader in shaders" :key="shader.name">
			<a :href="`?${shader.name}`">{{ shader.title }}</a>
		</li>
	</ul>
</div>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import type { PlaygroundMetadata } from './utils.ts';
import XPlayground from './playground.vue';

type ShaderListItem = {
	name: string;
	title: string;
};

const metadataModules = import.meta.glob<PlaygroundMetadata>('./shaders/*/meta.ts', {
	eager: true,
	import: 'metadata',
});

const shaders: ShaderListItem[] = Object.entries(metadataModules)
	.filter(([, metadata]) => metadata.isPublic)
	.map(([path, metadata]) => ({
		name: path.split('/')[2],
		title: metadata.title,
	}))
	.sort((a, b) => a.title.localeCompare(b.title) || a.name.localeCompare(b.name));

const name = ref(window.location.search.match(/\?([^&]+)/)?.[1] ?? null);
</script>

<style scoped>

</style>
