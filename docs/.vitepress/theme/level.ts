// The two levels of the site (ADR-0068) and the bridge from each guide chapter to its technical page, in both
// languages (ADR-0077: Italian at the root, English under /en/).
export const technicalPrefixes = ['/tecnica', '/adr', '/benchmarks', '/design', '/phase-', '/stato', '/prove-tester', '/licenses']

/** "/en" for an English page, "" otherwise; `path` without the site base. */
export function localeOf(path: string): '' | '/en' {
  return path === '/en' || path.startsWith('/en/') ? '/en' : ''
}

export function levelOf(path: string): 'uso' | 'tecnico' {
  const bare = path.slice(localeOf(path).length)
  return technicalPrefixes.some((prefix) => bare.startsWith(prefix)) ? 'tecnico' : 'uso'
}

/** Guide chapter → technical page that explains how it is built (Italian anchors; English pages link the page). */
export const technicalPageFor: Record<string, { link: string; text: string; en: string }> = {
  'primi-passi': { link: '/tecnica/', text: 'Panoramica tecnica', en: 'Technical overview' },
  installazione: { link: '/tecnica/distribuzione', text: 'Distribuzione e aggiornamenti', en: 'Distribution and updates' },
  registrare: { link: '/tecnica/cattura', text: 'Cattura e riunioni', en: 'Capture and meetings' },
  riunioni: { link: '/tecnica/cattura#riunioni', text: 'Rilevamento delle riunioni', en: 'Meeting detection' },
  trascrizione: { link: '/tecnica/trascrizione', text: 'Trascrizione', en: 'Transcription' },
  organizzare: { link: '/tecnica/dati', text: 'Dati e archivio', en: 'Data and archive' },
  scheda: { link: '/tecnica/dati', text: 'Dati e archivio', en: 'Data and archive' },
  sintesi: { link: '/tecnica/intelligenza#sintesi-per-categoria-adr-0054', text: 'Come si costruisce una sintesi', en: 'How a summary is built' },
  'punti-chiave': { link: '/tecnica/intelligenza#punti-chiave-adr-0046-adr-0052-adr-0074', text: 'Punti chiave e lavoro aperto', en: 'Key points and open work' },
  proposte: { link: '/tecnica/intelligenza#proposte-adr-0009-adr-0049', text: 'Proposte', en: 'Suggestions' },
  'cercare-chiedere': { link: '/tecnica/intelligenza#ricerca', text: 'Ricerca e Chiedi', en: 'Search and Ask' },
  'email-documenti': { link: '/tecnica/importazione', text: 'Importazione', en: 'Import' },
  claude: { link: '/tecnica/claude-mcp', text: 'Claude e MCP', en: 'Claude and MCP' },
  attivita: { link: '/tecnica/architettura#coda-dei-lavori-e-reattivita', text: 'Coda dei lavori', en: 'Job queue' },
  motore: { link: '/tecnica/motore', text: 'Motore locale', en: 'Local engine' },
  impostazioni: { link: '/tecnica/architettura', text: 'Architettura', en: 'Architecture' },
  'privacy-backup': { link: '/tecnica/privacy-rete', text: 'Privacy e rete', en: 'Privacy and network' },
  aggiornamenti: { link: '/tecnica/distribuzione#aggiornamenti-con-sparkle-adr-0056', text: 'Aggiornamenti con Sparkle', en: 'Updates with Sparkle' },
  problemi: { link: '/problemi-e-log', text: 'Risoluzione problemi e log', en: 'Troubleshooting and logs' }
}
