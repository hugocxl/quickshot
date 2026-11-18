// Check the built site in _site/: links, anchors, assets and the P9 page contract.
// Dependency-free: a small HTML tree parser is enough for the pages build-site.mjs writes.
// Run from the repository root after node scripts/build-site.mjs.
import { existsSync, readFileSync } from "node:fs";
import assert from "node:assert/strict";

const site = "_site";
const pages = ["index.html", "docs.html", "changelog.html"];

// ─── A minimal HTML tree ────────────────────────────────────────────────
const VOID = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"]);
function parse(html) {
  const root = { tag: "#root", attrs: {}, children: [], parent: null };
  let node = root;
  const re = /<!--[\s\S]*?-->|<!doctype[^>]*>|<(script|style)\b([^>]*)>([\s\S]*?)<\/\1>|<(\/?)([a-zA-Z][\w-]*)((?:\s+[^\s=>/]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(\/?)>|([^<]+)/gi;
  const attributes = (text = "") =>
    Object.fromEntries([...text.matchAll(/([^\s=>/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)].map((m) => [m[1].toLowerCase(), m[2] ?? m[3] ?? m[4] ?? ""]));
  for (const m of html.matchAll(re)) {
    if (m[1]) node.children.push({ tag: m[1].toLowerCase(), attrs: attributes(m[2]), children: [{ text: m[3] }], parent: node });
    else if (m[5] && m[4]) {
      const tag = m[5].toLowerCase();
      let open = node;
      while (open && open.tag !== tag) open = open.parent;
      assert.ok(open, `unexpected </${tag}>`);
      node = open.parent;
    } else if (m[5]) {
      const element = { tag: m[5].toLowerCase(), attrs: attributes(m[6]), children: [], parent: node };
      node.children.push(element);
      if (!m[7] && !VOID.has(element.tag)) node = element;
    } else if (m[8]) node.children.push({ text: m[8] });
  }
  assert.equal(node, root, "unclosed elements");
  return root;
}
const elements = (node) => (node.children ?? []).filter((child) => child.tag);
const all = (node) => elements(node).flatMap((child) => [child, ...all(child)]);
const has = (element, name) => (element.attrs?.class ?? "").split(/\s+/).includes(name);
const text = (node) => (node.text !== undefined ? node.text : (node.children ?? []).map(text).join(""));
const find = (node, test) => all(node).filter(test);

const docs = new Map(pages.map((name) => [name, parse(readFileSync(`${site}/${name}`, "utf8"))]));
const ids = (doc) => new Set(all(doc).map((el) => el.attrs.id).filter(Boolean));
const local = (href) => !/^(https?:|mailto:|data:)/.test(href);
let links = 0;

for (const [name, doc] of docs) {
  // Links and anchors resolve, and assets exist.
  for (const a of find(doc, (el) => el.tag === "a")) {
    const href = a.attrs.href;
    assert.ok(href, `${name}: link without href`);
    if (!local(href)) continue;
    links++;
    const [path, hash] = href.split("#");
    const target = !path ? name : path === "./" ? "index.html" : path;
    assert.ok(existsSync(`${site}/${target}`), `${name}: missing ${href}`);
    if (hash) assert.ok(docs.has(target) && ids(docs.get(target)).has(hash), `${name}: missing anchor ${href}`);
  }
  for (const el of find(doc, (el) => el.attrs.src || (el.tag === "link" && el.attrs.href))) {
    const path = (el.attrs.src || el.attrs.href).split(/[?#]/)[0];
    if (local(path)) assert.ok(existsSync(`${site}/${path}`), `${name}: missing asset ${path}`);
  }
  const allIds = all(doc).map((el) => el.attrs.id).filter(Boolean);
  assert.equal(new Set(allIds).size, allIds.length, `${name}: duplicate id`);

  // Every page is a plain P9 page with the shared masthead and footer.
  const head = find(doc, (el) => el.tag === "head")[0];
  const body = find(doc, (el) => el.tag === "body")[0];
  assert.ok(find(head, (el) => el.tag === "link" && el.attrs.rel === "stylesheet" && el.attrs.href === "system/ds.css").length, `${name}: ds.css`);
  assert.ok(find(head, (el) => el.tag === "script" && el.attrs.src === "system/theme.js" && !el.attrs.type).length, `${name}: theme.js`);
  assert.ok(find(head, (el) => el.tag === "script" && el.attrs.src === "system/ds.js" && el.attrs.type === "module").length, `${name}: ds.js`);
  assert.ok(find(head, (el) => el.tag === "title").length === 1, `${name}: title`);
  assert.ok(has(body, "ds"), `${name}: body.ds`);
  assert.equal(body.attrs["data-layout"], "plain", `${name}: plain layout`);
  assert.ok(!find(doc, (el) => el.attrs["data-layout"] && el.attrs["data-layout"] !== "plain").length, `${name}: only the plain layout`);
  const [first, ...rest] = elements(body);
  assert.ok(first.tag === "header" && has(first, "ds-masthead"), `${name}: masthead first`);
  assert.ok(rest.at(-1).tag === "footer" && has(rest.at(-1), "ds-footer"), `${name}: footer last`);
  assert.deepEqual(rest.map((el) => el.tag), ["main", "footer"], `${name}: body is masthead, main, footer`);

  const linkList = (root) => find(root, (el) => el.tag === "a").map((a) => `${text(a).trim()} ${a.attrs.href}`);
  assert.deepEqual(linkList(first), [
    "Quickshot ./",
    "Docs docs.html",
    "Changelog changelog.html",
    "GitHub https://github.com/hugocxl/quickshot",
  ]);
  const theme = elements(first).at(-1);
  assert.ok(theme.tag === "button" && has(theme, "ds-theme") && "data-ds-theme" in theme.attrs && theme.attrs["aria-label"], `${name}: theme button`);
  assert.equal(elements(theme)[0]?.attrs["data-icon"], "contrast", `${name}: theme icon`);
  assert.deepEqual(linkList(rest.at(-1)), [
    "Tab https://hugocxl.github.io/tab/",
    "Quickshot https://hugocxl.github.io/quickshot/",
    "AgentKit https://hugocxl.github.io/agentkit/",
    "GitHub https://github.com/hugocxl/quickshot",
    "License https://github.com/hugocxl/quickshot/blob/main/LICENSE",
    "@hugocxl https://github.com/hugocxl",
  ]);

  // Accent budget, one filled button, one column.
  const accents = find(doc, (el) => has(el, "ds-accent") || has(el, "ds-dot"));
  assert.ok(accents.length <= 2, `${name}: accent budget`);
  assert.ok(find(doc, (el) => has(el, "ds-dot")).every((dot) => has(dot.parent, "ds-label") && dot.parent.children.find((c) => c.tag) === dot), `${name}: dot leads a label`);
  assert.ok(find(doc, (el) => has(el, "ds-button")).length <= 1, `${name}: one filled button`);
  const main = rest[0];
  const articles = find(main, (el) => el.tag === "article");
  assert.equal(articles.length, 1, `${name}: one article`);
  assert.ok(has(articles[0], "ds-column") && has(articles[0], "ds-opening"), `${name}: ds-column ds-opening`);

  // Artwork: Stroke icons and vectors only, never in the accent, never glyphs.
  for (const svg of find(body, (el) => el.tag === "svg")) {
    assert.ok(!find(doc, (el) => has(el, "ds-accent")).some((accent) => all(accent).includes(svg)), `${name}: artwork in accent`);
    if (has(svg, "ds-icon")) {
      assert.ok(existsSync(`website/artwork/icons/${svg.attrs["data-icon"]}.svg`), `${name}: unknown icon ${svg.attrs["data-icon"]}`);
      assert.equal(svg.attrs["aria-hidden"], "true", `${name}: icon aria-hidden`);
      assert.equal(svg.attrs.viewbox, "0 0 16 16", `${name}: icon viewBox`);
    } else {
      assert.ok(has(svg, "ds-vector"), `${name}: svg is neither an icon nor a vector`);
      assert.ok(existsSync(`website/artwork/vectors/${svg.attrs["data-vector"]}.svg`), `${name}: unknown vector ${svg.attrs["data-vector"]}`);
      assert.ok(!("xmlns" in svg.attrs) && !("color" in svg.attrs), `${name}: vector root attributes`);
      assert.equal(svg.attrs.role, "img", `${name}: vector role`);
      assert.ok(elements(svg).some((el) => el.tag === "title" && text(el).trim()), `${name}: vector title`);
    }
  }
  for (const img of find(body, (el) => el.tag === "img")) assert.ok(img.attrs.alt, `${name}: img alt`);
  const words = text(body);
  assert.doesNotMatch(words, /[←-⇿⌀-⏿■-◿☀-➿⬀-⯿]|\p{Extended_Pictographic}/u, `${name}: symbol or emoji used as an icon`);
  for (const button of find(body, (el) => el.tag === "button")) {
    assert.ok(text(button).trim() || button.attrs["aria-label"], `${name}: button without a name`);
  }
  for (const table of find(body, (el) => el.tag === "table")) {
    assert.ok(has(table, "ds-table") && has(table.parent, "ds-table-scroll") && table.parent.attrs.tabindex === "0", `${name}: table wrapper`);
  }
  for (const pre of find(body, (el) => el.tag === "pre")) {
    assert.ok(has(pre.parent, "ds-code") && pre.attrs.tabindex === "0", `${name}: code block`);
  }
}

// ─── Recipe order ───────────────────────────────────────────────────────
const component = (el) =>
  has(el, "ds-statement") ? "statement"
  : has(el, "ds-title") ? "title"
  : has(el, "ds-meta") ? "meta"
  : has(el, "ds-section") ? "section"
  : el.tag === "figure" && has(el, "ds-wide") ? "figure-wide"
  : has(el, "ds-grid") ? "figure-grid"
  : has(el, "ds-index") ? "index"
  : has(el, "ds-table-scroll") ? "table"
  : has(el, "ds-button") ? "button"
  : has(el, "ds-form") ? "form"
  : `?${el.tag}`;
const recipes = {
  "index.html": /^statement( meta)? section (figure-wide|figure-grid)( section)*( button| form)?$/,
  "docs.html": /^title( meta)? section( section| figure-wide)*$/,
  "changelog.html": /^title( section)? index$/,
};
for (const [name, recipe] of Object.entries(recipes)) {
  const article = find(docs.get(name), (el) => el.tag === "article")[0];
  const sequence = elements(article).map(component).join(" ");
  assert.match(sequence, recipe, `${name} recipe order: ${sequence}`);
  // The lead section has no heading; every later section has one.
  const sections = elements(article).filter((el) => has(el, "ds-section"));
  assert.ok(!elements(sections[0]).some((el) => el.tag === "h2"), `${name}: lead section has no heading`);
  for (const section of sections.slice(1)) assert.equal(elements(section)[0]?.tag, "h2", `${name}: section heading`);
}

// Home: the version comes from the changelog, the action is the download.
const home = docs.get("index.html");
const [, latest] = readFileSync("CHANGELOG.md", "utf8").match(/^## (\d+\.\d+\.\d+) /m);
assert.match(text(find(home, (el) => has(el, "ds-meta"))[0]), new RegExp(`Version ${latest.replaceAll(".", "\\.")}`));
assert.equal(find(home, (el) => has(el, "ds-accent")).length, 1, "home: one accent phrase");
assert.equal(find(home, (el) => has(el, "ds-button"))[0].attrs.href, "https://github.com/hugocxl/quickshot/releases");
const grid = find(home, (el) => has(el, "ds-grid"))[0];
assert.equal(String(elements(grid).length), grid.attrs["data-columns"], "home: grid columns");

// Changelog: one row per version in CHANGELOG.md.
const versions = [...readFileSync("CHANGELOG.md", "utf8").matchAll(/^## (\d+\.\d+\.\d+) - (\d{4}-\d{2}-\d{2})$/gm)];
const rows = elements(find(docs.get("changelog.html"), (el) => has(el, "ds-index"))[0]);
assert.equal(rows.length, versions.length, "changelog: one row per version");
rows.forEach((row, i) => {
  assert.equal(find(row, (el) => el.tag === "time")[0].attrs.datetime, versions[i][2]);
  assert.equal(text(find(row, (el) => el.tag === "h3")[0]), `Version ${versions[i][1]}`);
});

// Site CSS stays inside the design system's tokens.
const css = readFileSync("website/site.css", "utf8").replace(/\/\*[\s\S]*?\*\//g, "");
assert.doesNotMatch(css, /#[0-9a-f]{3,8}\b|rgba?\(|hsla?\(|oklch\(/i, "site.css: literal color");
assert.doesNotMatch(css, /box-shadow|text-shadow|gradient|font-family|font-weight|border-radius:\s*\d|\d+px/i, "site.css: off-token style");
for (const [, property] of css.matchAll(/var\((--[\w-]+)/g)) assert.match(property, /^--ds-/, `site.css: ${property}`);

console.log(`Site verified: ${pages.length} pages, ${links} local links, ${rows.length} changelog versions.`);
