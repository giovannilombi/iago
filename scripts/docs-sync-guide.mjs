// Copies the in-app guide (App/Resources/Guide, the single source of the user documentation) into the
// documentation site: docs/guida/<chapter>.md with its screenshots, plus the logo and the menu bar icon.
// The generated files are ignored by git; `npm run docs:build` runs this first.
import { copyFileSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = new URL('..', import.meta.url).pathname
const guide = join(root, 'App/Resources/Guide')
const out = join(root, 'docs/guida')
const publicDir = join(root, 'docs/public')

// Italian at the root, English under /en/ (ADR-0077); the English guide has its own screenshots in Guide/en/img.
function copyGuide(from, to) {
  rmSync(to, { recursive: true, force: true })
  mkdirSync(join(to, 'img'), { recursive: true })
  for (const file of readdirSync(from).filter((f) => /^\d\d-.+\.md$/.test(f)).sort()) {
    const text = readFileSync(join(from, file), 'utf8')
      .replace(/^<!-- icona: .* -->\n/, '')
      .replaceAll('{{icona}}', '![icona di IAGO](/icona.svg)')
    writeFileSync(join(to, file.replace(/^\d\d-/, '')), text)
  }
  for (const image of readdirSync(join(from, 'img'))) copyFileSync(join(from, 'img', image), join(to, 'img', image))
}
mkdirSync(publicDir, { recursive: true })
copyGuide(guide, out)
copyGuide(join(guide, 'en'), join(root, 'docs/en/guida'))
copyFileSync(join(root, 'Design/iago-logo.svg'), join(publicDir, 'logo.svg'))
copyFileSync(join(root, 'Design/iago-menubar-colors.svg'), join(publicDir, 'icona.svg'))
console.log('Guide copied to docs/guida')
