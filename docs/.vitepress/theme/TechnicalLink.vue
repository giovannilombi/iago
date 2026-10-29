<script setup lang="ts">
// On a guide chapter: a link to the page that explains how that part is built.
import { computed } from 'vue'
import { useRoute } from 'vitepress'
import { localeOf, technicalPageFor } from './level'

const route = useRoute()
const en = computed(() => localeOf(route.path.replace(/^\/iago/, '')) === '/en')
const target = computed(() => {
  const match = route.path.match(/\/guida\/([^/.]+)/)
  const page = match ? technicalPageFor[match[1]] : undefined
  if (!page) return undefined
  // English headings have their own anchors: the English link goes to the page.
  return en.value ? { link: '/en' + page.link.split('#')[0], text: page.en } : page
})
</script>

<template>
  <div v-if="target" class="technical-link">
    <span>{{ en ? 'Technical level:' : 'Livello tecnico:' }}</span>
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
