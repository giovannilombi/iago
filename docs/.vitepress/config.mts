import { readdirSync, readFileSync } from 'node:fs'
import { defineConfig, type DefaultTheme } from 'vitepress'

// The guide chapters come from the app (App/Resources/Guide, copied by scripts/docs-sync-guide.mjs): the sidebar
// reads their titles from there, grouped like the guide inside IAGO.
const guideDir = new URL('../../App/Resources/Guide/', import.meta.url)
const chapters = Object.fromEntries(
  readdirSync(guideDir)
    .filter((f) => /^\d\d-.+\.md$/.test(f))
    .map((f) => {
      const slug = f.replace(/^\d\d-/, '').replace(/\.md$/, '')
      const title = readFileSync(new URL(f, guideDir), 'utf8').match(/^# (.+)$/m)?.[1] ?? slug
      return [slug, { text: title, link: `/guida/${slug}` }]
    })
)
const group = (text: string, slugs: string[]): DefaultTheme.SidebarItem => ({
  text,
  collapsed: false,
  items: slugs.filter((s) => chapters[s]).map((s) => chapters[s])
})

// Repository giovannilombi/iago → site at https://giovannilombi.github.io/iago/
const repo = 'iago'

export default defineConfig({
  lang: 'it-IT',
  title: 'IAGO',
  description: 'La memoria interrogabile del tuo lavoro, per macOS: call, email, documenti e decisioni, con le fonti.',
  base: `/${repo}/`,
  appearance: 'dark',
  cleanUrls: true,
  lastUpdated: true,
  // Internal documents of the team stay on GitHub, not on the site.
  srcExclude: [
    'adr/**', 'design/**', 'benchmarks/**', 'testing/**', 'phase-*.md', 'stato.md', 'prove-tester.md', 'licenses.md'
  ],
  head: [['link', { rel: 'icon', type: 'image/svg+xml', href: `/${repo}/icona.svg` }]],
  themeConfig: {
    logo: '/logo.svg',
    nav: [
      { text: 'Installazione', link: '/installazione' },
      { text: 'Guida', link: '/guida/primi-passi' },
      { text: 'Scorciatoie', link: '/scorciatoie' },
      { text: 'Problemi e log', link: '/problemi-e-log' },
      { text: 'GitHub', link: 'https://github.com/giovannilombi/iago' }
    ],
    sidebar: [
      { text: 'Iniziare', items: [{ text: 'Installare IAGO', link: '/installazione' }, chapters['primi-passi'], chapters['installazione']].filter(Boolean) },
      group('Registrare e trascrivere', ['registrare', 'riunioni', 'trascrizione']),
      group('Organizzare e capire', ['organizzare', 'scheda', 'sintesi', 'punti-chiave', 'proposte']),
      group('Cercare e raccogliere', ['cercare-chiedere', 'email-documenti', 'claude']),
      group("L'app", ['attivita', 'motore', 'impostazioni', 'privacy-backup', 'aggiornamenti']),
      {
        text: 'Aiuto',
        items: [
          { text: 'Scorciatoie da tastiera', link: '/scorciatoie' },
          chapters['problemi'],
          { text: 'Risoluzione problemi e log', link: '/problemi-e-log' }
        ].filter(Boolean)
      }
    ],
    search: {
      provider: 'local',
      options: {
        translations: {
          button: { buttonText: 'Cerca', buttonAriaLabel: 'Cerca' },
          modal: {
            noResultsText: 'Nessun risultato per',
            resetButtonTitle: 'Cancella',
            footer: { selectText: 'apri', navigateText: 'scorri', closeText: 'chiudi' }
          }
        }
      }
    },
    outline: { level: [2, 3], label: 'In questa pagina' },
    docFooter: { prev: 'Precedente', next: 'Successivo' },
    lastUpdated: { text: 'Aggiornato il' },
    darkModeSwitchLabel: 'Aspetto',
    sidebarMenuLabel: 'Menu',
    returnToTopLabel: 'Torna su',
    socialLinks: [{ icon: 'github', link: 'https://github.com/giovannilombi/iago' }],
    footer: {
      message: 'Licenza CC BY-NC-SA 4.0. I tuoi dati restano tuoi: IAGO non contiene né raccoglie contenuti.',
      copyright: '© 2026 Giovanni Lombi e Gianluca Sestito'
    }
  }
})
