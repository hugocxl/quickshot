// Vendor the P9 design system and the artwork the site uses from sibling checkouts.
// The copies are committed because CI has no sibling checkouts.
//   node scripts/sync-design-system.mjs          copy ../design-system/system verbatim into website/system,
//                                                and every {{icon}} and {{vector}} the pages name into website/artwork
//   node scripts/sync-design-system.mjs --check  fail if a vendored copy has drifted
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { dirname, join } from "node:path";

const root = new URL("../", import.meta.url).pathname;
const repos = new URL("../../", import.meta.url).pathname;
const website = join(root, "website");

// Artwork named by the templates: {{icon NAME}} (Stroke icons) and {{vector NAME}}.
const templates = [
  ...readdirSync(website).filter((name) => name.endsWith(".html")).map((name) => join(website, name)),
  ...readdirSync(join(website, "partials")).map((name) => join(website, "partials", name)),
];
const named = (kind) =>
  [...new Set(templates.flatMap((path) => [...readFileSync(path, "utf8").matchAll(new RegExp(`\\{\\{${kind} ([\\w-]+)\\}\\}`, "g"))].map((m) => m[1])))].sort();

const copies = [
  { label: "website/system", source: join(repos, "design-system/system"), target: join(website, "system"), checkout: "hugocxl/design-system" },
  { label: "website/artwork/icons", source: join(repos, "icons/icons/styles/stroke"), target: join(website, "artwork/icons"), checkout: "hugocxl/icons", only: named("icon") },
  { label: "website/artwork/vectors", source: join(repos, "vectors/figures"), target: join(website, "artwork/vectors"), checkout: "hugocxl/vectors", only: named("vector") },
];

const files = (dir) =>
  existsSync(dir)
    ? readdirSync(dir, { recursive: true }).map(String).filter((path) => statSync(join(dir, path)).isFile() && !path.endsWith(".DS_Store")).sort()
    : [];
const wanted = (copy) => (copy.only ? copy.only.map((name) => `${name}.svg`) : files(copy.source));

let failed = false;
for (const copy of copies) {
  if (!existsSync(copy.source)) {
    console.error(`No checkout at ${copy.source}. Clone ${copy.checkout} next to this repository.`);
    process.exit(1);
  }
  const want = wanted(copy);
  const missing = want.filter((path) => !existsSync(join(copy.source, path)));
  if (missing.length) {
    console.error(`${copy.checkout} has no ${missing.join(", ")}.`);
    process.exit(1);
  }
  if (process.argv.includes("--check")) {
    const have = files(copy.target);
    const drift = [
      ...want.filter((path) => !have.includes(path) || !readFileSync(join(copy.source, path)).equals(readFileSync(join(copy.target, path)))),
      ...have.filter((path) => !want.includes(path)),
    ];
    if (drift.length) {
      console.error(`${copy.label} differs from ${copy.checkout}: ${drift.join(", ")}. Run node scripts/sync-design-system.mjs.`);
      failed = true;
    } else console.log(`${copy.label} matches ${copy.checkout} (${want.length} files).`);
  } else {
    rmSync(copy.target, { recursive: true, force: true });
    mkdirSync(copy.target, { recursive: true });
    for (const path of want) {
      mkdirSync(dirname(join(copy.target, path)), { recursive: true });
      cpSync(join(copy.source, path), join(copy.target, path));
    }
    console.log(`Copied ${want.length} files from ${copy.checkout} to ${copy.label}.`);
  }
}
if (failed) process.exit(1);
