import { readdirSync, readFileSync } from 'node:fs'
import { defineConfig, type DefaultTheme } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

// Two levels (ADR-0068): "Uso" is the app's guide, copied from App/Resources/Guide by scripts/docs-sync-guide.mjs,
// plus a few site-only pages; "Tecnico" is docs/tecnica with the ADRs, measurements and project documents.

const heading = (url: URL) => readFileSync(url, 'utf8').match(/^# (.+)$/m)?.[1] ?? ''

// Two languages (ADR-0077): Italian at the root, English under /en/. Each sidebar is built from that language's
// guide (App/Resources/Guide, App/Resources/Guide/en) and ADRs (docs/adr, docs/en/adr).
type Lang = 'it' | 'en'
const t = (lang: Lang, it: string, en: string) => (lang === 'en' ? en : it)
const prefix = (lang: Lang) => (lang === 'en' ? '/en' : '')

// Guide chapters, titles read from the app's guide.
function chaptersOf(lang: Lang): Record<string, DefaultTheme.SidebarItem> {
  const guideDir = new URL(lang === 'en' ? '../../App/Resources/Guide/en/' : '../../App/Resources/Guide/', import.meta.url)
  return Object.fromEntries(
    readdirSync(guideDir)
      .filter((f) => /^\d\d-.+\.md$/.test(f))
      .map((f) => {
        const slug = f.replace(/^\d\d-/, '').replace(/\.md$/, '')
        return [slug, { text: heading(new URL(f, guideDir)), link: `${prefix(lang)}/guida/${slug}` }]
      })
  )
}

// ADRs, numbered, with the title from each file.
function adrsOf(lang: Lang): DefaultTheme.SidebarItem[] {
  const adrDir = new URL(lang === 'en' ? '../en/adr/' : '../adr/', import.meta.url)
  return readdirSync(adrDir)
    .filter((f) => /^\d{4}-.+\.md$/.test(f))
    .sort()
    .map((f) => ({
      text: heading(new URL(f, adrDir)).replace(/^ADR-(\d{4}) — /, '$1 · '),
      link: `${prefix(lang)}/adr/${f.replace(/\.md$/, '')}`
    }))
}

function usoSidebar(lang: Lang): DefaultTheme.SidebarItem[] {
  const chapters = chaptersOf(lang)
  const p = prefix(lang)
  const group = (text: string, slugs: string[]): DefaultTheme.SidebarItem => ({
    text,
    collapsed: false,
    items: slugs.filter((s) => chapters[s]).map((s) => chapters[s])
  })
  return [
    {
      text: t(lang, 'Iniziare', 'Getting started'),
      items: [
        { text: t(lang, 'Installare IAGO', 'Installing IAGO'), link: `${p}/installazione` },
        chapters['primi-passi'],
        chapters['installazione']
      ].filter(Boolean)
    },
    group(t(lang, 'Registrare e trascrivere', 'Recording and transcribing'), ['registrare', 'riunioni', 'trascrizione']),
    group(t(lang, 'Organizzare e capire', 'Organizing and understanding'), [
      'organizzare',
      'scheda',
      'sintesi',
      'punti-chiave',
      'proposte'
    ]),
    group(t(lang, 'Cercare e raccogliere', 'Searching and collecting'), ['cercare-chiedere', 'email-documenti', 'claude']),
    group(t(lang, "L'app", 'The app'), ['attivita', 'motore', 'impostazioni', 'privacy-backup', 'aggiornamenti']),
    {
      text: t(lang, 'Aiuto', 'Help'),
      items: [
        { text: t(lang, 'Scorciatoie da tastiera', 'Keyboard shortcuts'), link: `${p}/scorciatoie` },
        chapters['problemi'],
        { text: t(lang, 'Risoluzione problemi e log', 'Troubleshooting and logs'), link: `${p}/problemi-e-log` }
      ].filter(Boolean)
    }
  ]
}

function tecnicoSidebar(lang: Lang): DefaultTheme.SidebarItem[] {
  const p = prefix(lang)
  return [
    { text: t(lang, 'Panoramica tecnica', 'Technical overview'), link: `${p}/tecnica/` },
    {
      text: t(lang, 'Come è fatto', 'How it is built'),
      items: [
        { text: t(lang, 'Architettura', 'Architecture'), link: `${p}/tecnica/architettura` },
        { text: t(lang, 'Dati e archivio', 'Data and archive'), link: `${p}/tecnica/dati` },
        { text: t(lang, 'Cattura e riunioni', 'Capture and meetings'), link: `${p}/tecnica/cattura` },
        { text: t(lang, 'Trascrizione', 'Transcription'), link: `${p}/tecnica/trascrizione` },
        { text: t(lang, 'Importazione', 'Import'), link: `${p}/tecnica/importazione` },
        { text: t(lang, 'Intelligenza', 'Intelligence'), link: `${p}/tecnica/intelligenza` },
        { text: t(lang, 'Motore locale', 'Local engine'), link: `${p}/tecnica/motore` },
        { text: t(lang, 'Claude e MCP', 'Claude and MCP'), link: `${p}/tecnica/claude-mcp` },
        { text: t(lang, 'Privacy e rete', 'Privacy and network'), link: `${p}/tecnica/privacy-rete` },
        { text: t(lang, 'Distribuzione e aggiornamenti', 'Distribution and updates'), link: `${p}/tecnica/distribuzione` }
      ]
    },
    {
      text: t(lang, 'Lavorare su IAGO', 'Working on IAGO'),
      items: [
        { text: t(lang, 'Sviluppo', 'Development'), link: `${p}/tecnica/sviluppo` },
        { text: t(lang, 'Qualità e misure', 'Quality and measurements'), link: `${p}/tecnica/qualita` },
        { text: t(lang, 'Stato e roadmap', 'Status and roadmap'), link: `${p}/stato` },
        { text: t(lang, 'Prove per i tester', 'Tester checklist'), link: `${p}/prove-tester` },
        { text: t(lang, 'Licenze e crediti', 'Licenses and credits'), link: `${p}/licenses` }
      ]
    },
    {
      text: t(lang, 'Decisioni (ADR)', 'Decisions (ADR)'),
      collapsed: true,
      items: [{ text: t(lang, 'Indice e stato', 'Index and status'), link: `${p}/adr/` }, ...adrsOf(lang)]
    },
    {
      text: t(lang, 'Progetti e misure', 'Designs and measurements'),
      collapsed: true,
      items: [
        { text: t(lang, 'Lavoro aperto: Traccia e Gestisci', 'Open work: Track and Manage'), link: `${p}/design/lavoro-aperto` },
        {
          text: t(lang, 'Progetti condivisi (proposta)', 'Shared projects (proposal)'),
          link: `${p}/design/sync-cartella-condivisa`
        },
        { text: t(lang, 'ClickUp (idea)', 'ClickUp (idea)'), link: `${p}/design/clickup` },
        { text: t(lang, 'Benchmark trascrizione', 'Transcription benchmark'), link: `${p}/benchmarks/2026-10-phase0` },
        {
          text: t(lang, 'Prova sintesi e glossario', 'Summary and glossary test'),
          link: `${p}/benchmarks/2026-10-21-sintesi-e-glossario`
        }
      ]
    },
    {
      text: t(lang, 'Storia delle fasi', 'History of the phases'),
      collapsed: true,
      items: [0, 1, 2, 3].map((n) => ({ text: t(lang, `Fase ${n}`, `Phase ${n}`), link: `${p}/phase-${n}` }))
    }
  ]
}

function sidebarOf(lang: Lang): DefaultTheme.Sidebar {
  const p = prefix(lang)
  const tecnico = tecnicoSidebar(lang)
  return {
    ...Object.fromEntries(
      ['/tecnica/', '/adr/', '/benchmarks/', '/design/', '/phase-', '/stato', '/prove-tester', '/licenses'].map(
        (path) => [`${p}${path}`, tecnico]
      )
    ),
    [`${p}/`]: usoSidebar(lang)
  }
}

function themeOf(lang: Lang): DefaultTheme.Config {
  const p = prefix(lang)
  return {
    nav: [
      { text: t(lang, 'Installazione', 'Installation'), link: `${p}/installazione` },
      {
        text: t(lang, 'Guida', 'Guide'),
        link: `${p}/guida/primi-passi`,
        activeMatch: `^${p}/(guida|installazione|scorciatoie|problemi-e-log)`
      },
      {
        text: t(lang, 'Tecnica', 'Technical'),
        link: `${p}/tecnica/`,
        activeMatch: `^${p}/(tecnica|adr|benchmarks|design|phase-|stato|prove-tester|licenses)`
      },
      { text: t(lang, 'Decisioni', 'Decisions'), link: `${p}/adr/` },
      { text: 'GitHub', link: 'https://github.com/giovannilombi/iago' }
    ],
    sidebar: sidebarOf(lang),
    outline: { level: [2, 3], label: t(lang, 'In questa pagina', 'On this page') },
    docFooter: { prev: t(lang, 'Precedente', 'Previous'), next: t(lang, 'Successivo', 'Next') },
    lastUpdated: { text: t(lang, 'Aggiornato il', 'Updated on') },
    darkModeSwitchLabel: t(lang, 'Aspetto', 'Appearance'),
    sidebarMenuLabel: 'Menu',
    returnToTopLabel: t(lang, 'Torna su', 'Back to top'),
    langMenuLabel: t(lang, 'Lingua', 'Language'),
    footer: {
      message: t(
        lang,
        'Licenza CC BY-NC-SA 4.0. I tuoi dati restano tuoi: IAGO non contiene né raccoglie contenuti.',
        'License CC BY-NC-SA 4.0. Your data stays yours: IAGO neither contains nor collects content.'
      ),
      // Who holds the rights for which versions is in the README (ADR-0065).
      copyright: t(
        lang,
        '© 2026 Giovanni Lombi e Gianluca Sestito · <a href="https://github.com/giovannilombi/iago/blob/main/README.md#crediti-e-licenze">Crediti e licenze</a>',
        '© 2026 Giovanni Lombi and Gianluca Sestito · <a href="https://github.com/giovannilombi/iago/blob/main/README.en.md#credits-and-licenses">Credits and licenses</a>'
      )
    }
  }
}

// Repository giovannilombi/iago → site at https://giovannilombi.github.io/iago/
const repo = 'iago'

// The site shows the version of the app it documents (project.yml): going back to a version brings its docs back too.
const appVersion =
  readFileSync(new URL('../../project.yml', import.meta.url), 'utf8').match(/CFBundleShortVersionString: "([^"]+)"/)?.[1] ??
  ''

export default withMermaid(defineConfig({
  vite: { define: { __IAGO_VERSION__: JSON.stringify(appVersion) } },
  title: 'IAGO',
  description: 'La memoria interrogabile del tuo lavoro, per macOS: call, email, documenti e decisioni, con le fonti.',
  base: `/${repo}/`,
  appearance: 'dark',
  cleanUrls: true,
  lastUpdated: true,
  rewrites: { 'adr/README.md': 'adr/index.md', 'en/adr/README.md': 'en/adr/index.md' },
  srcExclude: ['testing/**', 'en/testing/**'],
  // Project documents link files outside the site (CLAUDE.md, README.md, sources): they live on GitHub.
  ignoreDeadLinks: [/^\.\.\//, /CLAUDE/, /README-collaborators/, /\/README$/, /\/README\.en$/, /^\.\/README/, /\.(swift|sh|yml|json|svg|png)$/],
  head: [['link', { rel: 'icon', type: 'image/svg+xml', href: `/${repo}/icona.svg` }]],
  locales: {
    root: {
      label: 'Italiano',
      lang: 'it-IT',
      description: 'La memoria interrogabile del tuo lavoro, per macOS: call, email, documenti e decisioni, con le fonti.',
      themeConfig: themeOf('it')
    },
    en: {
      label: 'English',
      lang: 'en-US',
      link: '/en/',
      description: 'The searchable memory of your work, for macOS: calls, emails, documents and decisions, with their sources.',
      themeConfig: themeOf('en')
    }
  },
  themeConfig: {
    logo: '/logo.svg',
    socialLinks: [{ icon: 'github', link: 'https://github.com/giovannilombi/iago' }],
    search: {
      provider: 'local',
      options: {
        locales: {
          root: {
            translations: {
              button: { buttonText: 'Cerca nella documentazione', buttonAriaLabel: 'Cerca nella documentazione' },
              modal: {
                noResultsText: 'Nessun risultato per',
                resetButtonTitle: 'Cancella',
                footer: { selectText: 'apri', navigateText: 'scorri', closeText: 'chiudi' }
              }
            }
          }
        }
      }
    }
  }
}))
