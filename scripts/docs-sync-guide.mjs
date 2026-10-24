// Copies the in-app guide (App/Resources/Guide, the single source of the user documentation) into the
// documentation site: docs/guida/<chapter>.md with its screenshots, plus the logo and the menu bar icon.
// The generated files are ignored by git; `npm run docs:build` runs this first.
import { copyFileSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = new URL('..', import.meta.url).pathname
const guide = join(root, 'App/Resources/Guide')
const out = join(root, 'docs/guida')
const publicDir = join(root, 'docs/public')

rmSync(out, { recursive: true, force: true })
mkdirSync(join(out, 'img'), { recursive: true })
mkdirSync(publicDir, { recursive: true })

for (const file of readdirSync(guide).filter((f) => /^\d\d-.+\.md$/.test(f)).sort()) {
  const text = readFileSync(join(guide, file), 'utf8')
    .replace(/^<!-- icona: .* -->\n/, '')
    .replaceAll('{{icona}}', '![icona di IAGO](/icona.svg)')
  writeFileSync(join(out, file.replace(/^\d\d-/, '')), text)
}
for (const image of readdirSync(join(guide, 'img'))) copyFileSync(join(guide, 'img', image), join(out, 'img', image))
copyFileSync(join(root, 'Design/iago-logo.svg'), join(publicDir, 'logo.svg'))
copyFileSync(join(root, 'Design/iago-menubar-colors.svg'), join(publicDir, 'icona.svg'))
console.log('Guide copied to docs/guida')
