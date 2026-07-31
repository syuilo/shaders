<template>
<XPlayground v-if="name != null" :name="name"/>
<div v-else>
	<h1>syuilo's Shader Playground</h1>
	<ul>
		<li v-for="shader in shaders" :key="shader">
			<a :href="`?${shader}`">{{ shader }}</a>
		</li>
	</ul>
</div>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import XPlayground from './playground.vue';

const shaders = Object.keys(import.meta.glob('./shaders/*/main.ts'))
	.map(path => path.split('/')[2])
	.sort();

const name = ref(window.location.search.match(/\?([^&]+)/)?.[1] ?? null);
</script>

<style scoped>

</style>
