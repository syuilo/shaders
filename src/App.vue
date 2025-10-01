<template>
<ShadersTest v-if="shader === 'test'" />
<ShadersColors v-else-if="shader === 'colors'" />
<ShadersCyber v-else-if="shader === 'cyber'" />
</template>

<script lang="ts" setup>
import ShadersTest from './shaders/test/root.vue';
import ShadersColors from './shaders/colors/root.vue';
import ShadersCyber from './shaders/cyber/root.vue';
import { getUrlParam } from './utils.ts';

const shader = getUrlParam('shader', 'string');
</script>

<style scoped>

</style>
