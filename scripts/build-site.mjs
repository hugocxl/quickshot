// Build the GitHub Pages site from website/ into _site/.
// Pages follow the P9 design system vendored in website/system, with Stroke icons
// and vectors vendored in website/artwork (see scripts/sync-design-system.mjs).
// Run from the repository root: node scripts/build-site.mjs
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";

const out = "_site";
const read = (path) => readFileSync(path, "utf8");
const escape = (text) =>
  String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

// ─── Changelog: CHANGELOG.md is the version source ─────────────────────
const releases = [];
for (const line of read("CHANGELOG.md").split("\n")) {
  const heading = line.match(/^## (\d+\.\d+\.\d+) - (\d{4}-\d{2}-\d{2})$/);
  if (heading) releases.push({ version: heading[1], date: heading[2], entries: [] });
  else if (line.startsWith("- ")) releases.at(-1).entries.push(line.slice(2));
  else if (/^ {2}\S/.test(line) && releases.at(-1)?.entries.length) releases.at(-1).entries.push(`${releases.at(-1).entries.pop()} ${line.trim()}`);
}
if (!releases.length) throw new Error("CHANGELOG.md has no versions");

const inline = (text) =>
  escape(text)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
const day = (iso) =>
  new Date(`${iso}T00:00:00Z`).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });
const changelog = [
  '      <ol class="ds-index">',
  ...releases.map(
    (release) =>
      `        <li id="v${release.version}"><span class="ds-label"><time datetime="${release.date}">${day(release.date)}</time></span><div><h3>Version ${release.version}</h3><p>${release.entries.map(inline).join(" ")}</p></div></li>`,
  ),
  "      </ol>",
].join("\n");

// ─── Artwork, inlined so it draws in ink through currentColor ───────────
const icon = (name) =>
  read(`website/artwork/icons/${name}.svg`)
    .trim()
    .replace(/<svg[^>]*>/, `<svg class="ds-icon" data-icon="${name}" viewBox="0 0 16 16" fill="none" aria-hidden="true">`)
    .replace(/>\s+</g, "><");
const vector = (name) =>
  read(`website/artwork/vectors/${name}.svg`)
    .trim()
    .replace(/<svg ([^>]*)>/, (_, attributes) =>
      `<svg class="ds-vector" data-vector="${name}" ${attributes.replace(/\s*xmlns="[^"]*"/, "").replace(/\s*color="[^"]*"/, "").trim()}>`,
    )
    .replace(/>\s+</g, "><");

// ─── Templates ──────────────────────────────────────────────────────────
const partial = (name) => read(`website/partials/${name}.html`).replace(/\n$/, "");
function render(template, values) {
  const html = template
    .replace(/\{\{head ([^}]*)\}\}/, (_, args) => {
      const attributes = Object.fromEntries([...args.matchAll(/(\w+)="([^"]*)"/g)].map((m) => [m[1], m[2]]));
      return partial("head").replace(/\{\{(\w+)\}\}/g, (__, key) => attributes[key] ?? "");
    })
    .replace("{{masthead}}", partial("masthead"))
    .replace("{{footer}}", partial("footer"))
    .replace(/\{\{icon ([\w-]+)\}\}/g, (_, name) => icon(name))
    .replace(/\{\{vector ([\w-]+)\}\}/g, (_, name) => vector(name))
    .replace(/\{\{([\w-]+)\}\}/g, (match, key) => (key in values ? values[key] : match));
  const unknown = html.match(/\{\{[^}]*\}\}/);
  if (unknown) throw new Error(`Unknown template value ${unknown[0]}`);
  return html;
}

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
cpSync("website/system", `${out}/system`, { recursive: true, filter: (path) => !path.endsWith(".DS_Store") });
cpSync("website/site.css", `${out}/site.css`);
cpSync("media/icon.png", `${out}/icon.png`);

const values = { version: releases[0].version, changelog };
for (const page of ["index.html", "docs.html", "changelog.html"]) {
  writeFileSync(`${out}/${page}`, render(read(`website/${page}`), values));
}
writeFileSync(`${out}/.nojekyll`, "");
console.log(`Built the Quickshot site for version ${releases[0].version} with ${releases.length} changelog entries.`);
