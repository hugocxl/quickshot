// Stroke icons from @hugocxl/icons and vectors from @hugocxl/vectors, as the inline
// markup the design system asks for, so they draw in ink through currentColor.
// Shared by build-site.mjs and check-site.mjs.
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

const svg = async (specifier) => Object.values(await import(specifier))[0];

export const icon = async (name) =>
  (await svg(`@hugocxl/icons/js/stroke/${name}`))
    .trim()
    .replace(/<svg[^>]*>/, `<svg class="ds-icon" data-icon="${name}" viewBox="0 0 16 16" fill="none" aria-hidden="true">`)
    .replace(/>\s+</g, "><");

export const vector = async (name) =>
  (await svg(`@hugocxl/vectors/js/${name}`))
    .trim()
    .replace(/<svg ([^>]*)>/, (_, attributes) =>
      `<svg class="ds-vector" data-vector="${name}" ${attributes.replace(/\s*xmlns="[^"]*"/, "").replace(/\s*color="[^"]*"/, "").trim()}>`,
    )
    .replace(/>\s+</g, "><");

// The design system's system/ folder: ds.css, ds.js, theme.js, fonts and images.
export const designSystem = join(dirname(createRequire(import.meta.url).resolve("@hugocxl/design-system/package.json")), "system");
