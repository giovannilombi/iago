import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import LevelToggle from './LevelToggle.vue'
import TechnicalLink from './TechnicalLink.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  Layout: () =>
    h(DefaultTheme.Layout, null, {
      'nav-bar-content-before': () => h(LevelToggle),
      'doc-before': () => h(TechnicalLink)
    })
}
