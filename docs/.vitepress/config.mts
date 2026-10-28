import { readdirSync, readFileSync } from 'node:fs'
import { defineConfig, type DefaultTheme } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

// Two levels (ADR-0068): "Uso" is the app's guide, copied from App/Resources/Guide by scripts/docs-sync-guide.mjs,
// plus a few site-only pages; "Tecnico" is docs/tecnica with the ADRs, measurements and project documents.

const heading = (url: URL) => readFileSync(url, 'utf8').match(/^# (.+)$/m)?.[1] ?? ''

// Guide chapters, titles read from the app's guide.
const guideDir = new URL('../../App/Resources/Guide/', import.meta.url)
const chapters: Record<string, DefaultTheme.SidebarItem> = Object.fromEntries(
  readdirSync(guideDir)
    .filter((f) => /^\d\d-.+\.md$/.test(f))
    .map((f) => {
      const slug = f.replace(/^\d\d-/, '').replace(/\.md$/, '')
      return [slug, { text: heading(new URL(f, guideDir)), link: `/guida/${slug}` }]
    })
)
const group = (text: string, slugs: string[]): DefaultTheme.SidebarItem => ({
  text,
  collapsed: false,
  items: slugs.filter((s) => chapters[s]).map((s) => chapters[s])
})

// ADRs, numbered, with the title from each file.
const adrDir = new URL('../adr/', import.meta.url)
const adrs: DefaultTheme.SidebarItem[] = readdirSync(adrDir)
  .filter((f) => /^\d{4}-.+\.md$/.test(f))
  .sort()
  .map((f) => ({
    text: heading(new URL(f, adrDir)).replace(/^ADR-(\d{4}) — /, '$1 · '),
    link: `/adr/${f.replace(/\.md$/, '')}`
  }))

const usoSidebar: DefaultTheme.SidebarItem[] = [
  {
    text: 'Iniziare',
    items: [{ text: 'Installare IAGO', link: '/installazione' }, chapters['primi-passi'], chapters['installazione']].filter(Boolean)
  },
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
]

const tecnicoSidebar: DefaultTheme.SidebarItem[] = [
  { text: 'Panoramica tecnica', link: '/tecnica/' },
  {
    text: 'Come è fatto',
    items: [
      { text: 'Architettura', link: '/tecnica/architettura' },
      { text: 'Dati e archivio', link: '/tecnica/dati' },
      { text: 'Cattura e riunioni', link: '/tecnica/cattura' },
      { text: 'Trascrizione', link: '/tecnica/trascrizione' },
      { text: 'Importazione', link: '/tecnica/importazione' },
      { text: 'Intelligenza', link: '/tecnica/intelligenza' },
      { text: 'Motore locale', link: '/tecnica/motore' },
      { text: 'Claude e MCP', link: '/tecnica/claude-mcp' },
      { text: 'Privacy e rete', link: '/tecnica/privacy-rete' },
      { text: 'Distribuzione e aggiornamenti', link: '/tecnica/distribuzione' }
    ]
  },
  {
    text: 'Lavorare su IAGO',
    items: [
      { text: 'Sviluppo', link: '/tecnica/sviluppo' },
      { text: 'Qualità e misure', link: '/tecnica/qualita' },
      { text: 'Stato e roadmap', link: '/stato' },
      { text: 'Prove per i tester', link: '/prove-tester' },
      { text: 'Licenze e crediti', link: '/licenses' }
    ]
  },
  { text: 'Decisioni (ADR)', collapsed: true, items: [{ text: 'Indice e stato', link: '/adr/' }, ...adrs] },
  {
    text: 'Progetti e misure',
    collapsed: true,
    items: [
      { text: 'Lavoro aperto: Traccia e Gestisci (proposta)', link: '/design/lavoro-aperto' },
      { text: 'Progetti condivisi (proposta)', link: '/design/sync-cartella-condivisa' },
      { text: 'Benchmark trascrizione', link: '/benchmarks/2026-10-phase0' },
      { text: 'Prova sintesi e glossario', link: '/benchmarks/2026-10-21-sintesi-e-glossario' }
    ]
  },
  {
    text: 'Storia delle fasi',
    collapsed: true,
    items: [0, 1, 2, 3].map((n) => ({ text: `Fase ${n}`, link: `/phase-${n}` }))
  }
]

// Repository giovannilombi/iago → site at https://giovannilombi.github.io/iago/
const repo = 'iago'

export default withMermaid(defineConfig({
  lang: 'it-IT',
  title: 'IAGO',
  description: 'La memoria interrogabile del tuo lavoro, per macOS: call, email, documenti e decisioni, con le fonti.',
  base: `/${repo}/`,
  appearance: 'dark',
  cleanUrls: true,
  lastUpdated: true,
  rewrites: { 'adr/README.md': 'adr/index.md' },
  srcExclude: ['testing/**'],
  // Project documents link files outside the site (CLAUDE.md, README.md, sources): they live on GitHub.
  ignoreDeadLinks: [/^\.\.\//, /CLAUDE/, /README-collaborators/, /\/README$/, /^\.\/README/, /\.(swift|sh|yml|json|svg|png)$/],
  head: [['link', { rel: 'icon', type: 'image/svg+xml', href: `/${repo}/icona.svg` }]],
  themeConfig: {
    logo: '/logo.svg',
    nav: [
      { text: 'Installazione', link: '/installazione' },
      { text: 'Guida', link: '/guida/primi-passi', activeMatch: '^/(guida|installazione|scorciatoie|problemi-e-log)' },
      { text: 'Tecnica', link: '/tecnica/', activeMatch: '^/(tecnica|adr|benchmarks|design|phase-|stato|prove-tester|licenses)' },
      { text: 'Decisioni', link: '/adr/' },
      { text: 'GitHub', link: 'https://github.com/giovannilombi/iago' }
    ],
    sidebar: {
      '/tecnica/': tecnicoSidebar,
      '/adr/': tecnicoSidebar,
      '/benchmarks/': tecnicoSidebar,
      '/design/': tecnicoSidebar,
      '/phase-': tecnicoSidebar,
      '/stato': tecnicoSidebar,
      '/prove-tester': tecnicoSidebar,
      '/licenses': tecnicoSidebar,
      '/': usoSidebar
    },
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
}))
