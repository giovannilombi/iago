<script setup lang="ts">
// "Uso | Tecnico": who reads the site chooses the level of detail. The last page of each level is remembered.
import { computed } from 'vue'
import { useRoute, useRouter, withBase } from 'vitepress'
import { levelOf } from './level'

const route = useRoute()
const router = useRouter()
const current = computed(() => levelOf(route.path.replace(/^\/iago/, '')))

function relative(path: string) {
  return path.replace(/^\/iago/, '')
}

function go(level: 'uso' | 'tecnico') {
  if (level === current.value) return
  try {
    localStorage.setItem(`iago-level-${current.value}`, relative(route.path))
  } catch {}
  let target = level === 'uso' ? '/guida/primi-passi' : '/tecnica/'
  try {
    target = localStorage.getItem(`iago-level-${level}`) ?? target
  } catch {}
  router.go(withBase(target))
}
</script>

<template>
  <div class="level-toggle" role="group" aria-label="Livello di dettaglio">
    <button :aria-pressed="current === 'uso'" @click="go('uso')" title="Come si usa IAGO">Uso</button>
    <button :aria-pressed="current === 'tecnico'" @click="go('tecnico')" title="Come è fatto IAGO: architettura, scelte, modelli">Tecnico</button>
  </div>
</template>

<style scoped>
.level-toggle {
  display: inline-flex;
  margin-right: 12px;
  padding: 2px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  background: var(--vp-c-bg-soft);
}
.level-toggle button {
  font-size: 13px;
  font-weight: 500;
  padding: 2px 12px;
  border-radius: 6px;
  color: var(--vp-c-text-2);
}
.level-toggle button[aria-pressed='true'] {
  background: var(--vp-c-brand-3);
  color: #0d1714;
  font-weight: 600;
}
.level-toggle button:focus-visible {
  outline: 2px solid var(--vp-c-brand-1);
  outline-offset: 1px;
}
</style>
