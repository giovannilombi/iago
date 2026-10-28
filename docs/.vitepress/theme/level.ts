// The two levels of the site (ADR-0068) and the bridge from each guide chapter to its technical page.
export const technicalPrefixes = ['/tecnica', '/adr', '/benchmarks', '/design', '/phase-', '/stato', '/prove-tester', '/licenses']

export function levelOf(path: string): 'uso' | 'tecnico' {
  return technicalPrefixes.some((prefix) => path.startsWith(prefix)) ? 'tecnico' : 'uso'
}

/** Guide chapter → technical page that explains how it is built. */
export const technicalPageFor: Record<string, { link: string; text: string }> = {
  'primi-passi': { link: '/tecnica/', text: 'Panoramica tecnica' },
  installazione: { link: '/tecnica/distribuzione', text: 'Distribuzione e aggiornamenti' },
  registrare: { link: '/tecnica/cattura', text: 'Cattura e riunioni' },
  riunioni: { link: '/tecnica/cattura#riunioni', text: 'Rilevamento delle riunioni' },
  trascrizione: { link: '/tecnica/trascrizione', text: 'Trascrizione' },
  organizzare: { link: '/tecnica/dati', text: 'Dati e archivio' },
  scheda: { link: '/tecnica/dati', text: 'Dati e archivio' },
  sintesi: { link: '/tecnica/intelligenza#sintesi-per-categoria-adr-0054', text: 'Come si costruisce una sintesi' },
  'punti-chiave': { link: '/tecnica/intelligenza#punti-chiave-adr-0046-adr-0052-adr-0074', text: 'Punti chiave e lavoro aperto' },
  proposte: { link: '/tecnica/intelligenza#proposte-adr-0009-adr-0049', text: 'Proposte' },
  'cercare-chiedere': { link: '/tecnica/intelligenza#ricerca', text: 'Ricerca e Chiedi' },
  'email-documenti': { link: '/tecnica/importazione', text: 'Importazione' },
  claude: { link: '/tecnica/claude-mcp', text: 'Claude e MCP' },
  attivita: { link: '/tecnica/architettura#coda-dei-lavori-e-reattivita', text: 'Coda dei lavori' },
  motore: { link: '/tecnica/motore', text: 'Motore locale' },
  impostazioni: { link: '/tecnica/architettura', text: 'Architettura' },
  'privacy-backup': { link: '/tecnica/privacy-rete', text: 'Privacy e rete' },
  aggiornamenti: { link: '/tecnica/distribuzione#aggiornamenti-con-sparkle-adr-0056', text: 'Aggiornamenti con Sparkle' },
  problemi: { link: '/problemi-e-log', text: 'Risoluzione problemi e log' }
}
