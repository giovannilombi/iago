<script setup lang="ts">
// On a guide chapter: a link to the page that explains how that part is built.
import { computed } from 'vue'
import { useRoute } from 'vitepress'
import { technicalPageFor } from './level'

const route = useRoute()
const target = computed(() => {
  const match = route.path.match(/\/guida\/([^/.]+)/)
  return match ? technicalPageFor[match[1]] : undefined
})
</script>

<template>
  <div v-if="target" class="technical-link">
    <span>Livello tecnico:</span>
    <a :href="'/iago' + target.link">{{ target.text }} →</a>
  </div>
</template>

<style scoped>
.technical-link {
  display: flex;
  gap: 6px;
  justify-content: flex-end;
  font-size: 13px;
  color: var(--vp-c-text-2);
  margin-bottom: 8px;
}
.technical-link a {
  color: var(--vp-c-brand-1);
  font-weight: 500;
}
</style>
