<template>
<XPlayground v-if="name != null" :name="name"/>
<div v-else>
	<h1>syuilo's Shader Playground</h1>
	<!-- TODO: render list of shaders -->
</div>
</template>

<script lang="ts" setup>
import { defineAsyncComponent, ref } from 'vue';
import XPlayground from './playground.vue';

const name = ref(window.location.search.match(/\?([^&]+)/)?.[1] ?? null);
</script>

<style scoped>

</style>
