<script setup lang="ts">
// The version of the app these docs describe, read from project.yml at build time.
declare const __IAGO_VERSION__: string
const version = __IAGO_VERSION__
import { computed } from 'vue'
import { useRoute } from 'vitepress'
const route = useRoute()
const title = computed(() =>
  route.path.includes('/en/') ? 'IAGO version described by these docs' : 'Versione di IAGO descritta da questa documentazione'
)
</script>

<template>
  <span v-if="version" class="version-badge" :title="title">{{ version }}</span>
</template>

<style scoped>
.version-badge {
  margin-left: 8px;
  padding: 0 7px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 999px;
  font-family: var(--vp-font-family-mono);
  font-size: 11px;
  font-weight: 500;
  line-height: 18px;
  color: var(--vp-c-text-2);
}
</style>
