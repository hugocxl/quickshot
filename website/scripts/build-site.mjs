// Build the GitHub Pages site from website/ into _site/.
// Pages follow the P9 design system from @hugocxl/design-system, with Stroke icons
// from @hugocxl/icons and vectors from @hugocxl/vectors (npm devDependencies).
// Run from the repository root after npm ci: node scripts/build-site.mjs
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { designSystem, icon, vector } from "./site-artwork.mjs";

const out = "_site";
const read = (path) => readFileSync(path, "utf8");
const escape = (text) =>
  String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

// ─── Changelog: CHANGELOG.md is the version source ─────────────────────
const releases = [];
for (const line of read("../CHANGELOG.md").split("\n")) {
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

// ─── Artwork the templates name, from the packages ──────────────────────
const templates = [
  ...readdirSync(".").filter((name) => name.endsWith(".html")),
  ...readdirSync("partials").map((name) => `partials/${name}`),
];
const artwork = async (kind, markup) => {
  const names = new Set(templates.flatMap((path) => [...read(path).matchAll(new RegExp(`\\{\\{${kind} ([\\w-]+)\\}\\}`, "g"))].map((m) => m[1])));
  return new Map(await Promise.all([...names].map(async (name) => [name, await markup(name)])));
};
const icons = await artwork("icon", icon);
const vectors = await artwork("vector", vector);

// ─── Templates ──────────────────────────────────────────────────────────
const partial = (name) => read(`partials/${name}.html`).replace(/\n$/, "");
function render(template, values) {
  const html = template
    .replace(/\{\{head ([^}]*)\}\}/, (_, args) => {
      const attributes = Object.fromEntries([...args.matchAll(/(\w+)="([^"]*)"/g)].map((m) => [m[1], m[2]]));
      return partial("head").replace(/\{\{(\w+)\}\}/g, (__, key) => attributes[key] ?? "");
    })
    .replace("{{masthead}}", partial("masthead"))
    .replace("{{footer}}", partial("footer"))
    .replace(/\{\{icon ([\w-]+)\}\}/g, (_, name) => icons.get(name))
    .replace(/\{\{vector ([\w-]+)\}\}/g, (_, name) => vectors.get(name))
    .replace(/\{\{([\w-]+)\}\}/g, (match, key) => (key in values ? values[key] : match));
  const unknown = html.match(/\{\{[^}]*\}\}/);
  if (unknown) throw new Error(`Unknown template value ${unknown[0]}`);
  return html;
}

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
cpSync(designSystem, `${out}/system`, { recursive: true, filter: (path) => !path.endsWith(".DS_Store") });
cpSync("site.css", `${out}/site.css`);
cpSync("../media/icon.png", `${out}/icon.png`);

const values = { version: releases[0].version, changelog };
for (const page of ["index.html", "docs.html", "changelog.html"]) {
  writeFileSync(`${out}/${page}`, render(read(page), values));
}
writeFileSync(`${out}/.nojekyll`, "");
console.log(`Built the Quickshot site for version ${releases[0].version} with ${releases.length} changelog entries.`);
